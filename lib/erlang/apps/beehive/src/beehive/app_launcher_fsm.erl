%%%-------------------------------------------------------------------
%%% File    : app_launcher_fsm.erl
%%% Author  : Ari Lerner
%%% Description : 
%%%
%%% Created :  Wed Nov 18 17:30:15 PST 2009
%%%-------------------------------------------------------------------

-module (app_launcher_fsm).
-include ("beehive.hrl").
-include ("common.hrl").
-behaviour(gen_fsm).

%% API
-export([start_link/1]).

% methods
-export ([
  start_new/1,
  launch/1,
  update/1
]).
% states
-export ([
  preparing/2,
  updating/2,
  launching/2,
  pending/2
]).

%% gen_fsm callbacks
-export([init/1, state_name/2, state_name/3, handle_event/3,
         handle_sync_event/4, handle_info/3, terminate/3, code_change/4]).

-define(SERVER, ?MODULE).

-record (state, {
  app,
  latest_sha,
  host,
  port,
  bee,
  updating = false,
  from
}).

%%====================================================================
%% API
%%====================================================================
start_new(Pid) -> gen_fsm:send_event(Pid, {start_new}).
update(Pid) -> gen_fsm:send_event(Pid, {update}).
launch(Pid) -> gen_fsm:send_event(Pid, {launch}).
  
%%--------------------------------------------------------------------
%% Function: start_link() -> ok,Pid} | ignore | {error,Error}
%% Description:Creates a gen_fsm process which calls Module:init/1 to
%% initialize. To ensure a synchronized start-up procedure, this function
%% does not return until Module:init/1 has returned.
%%--------------------------------------------------------------------
start_link(Opts) ->
  gen_fsm:start_link(?MODULE, [Opts], []).

%%====================================================================
%% gen_fsm callbacks
%%====================================================================
%%--------------------------------------------------------------------
%% Function: init(Args) -> {ok, StateName, State} |
%%                         {ok, StateName, State, Timeout} |
%%                         ignore                              |
%%                         {stop, StopReason}
%% Description:Whenever a gen_fsm is started using gen_fsm:start/[3,4] or
%% gen_fsm:start_link/3,4, this function is called by the new process to
%% initialize.
%%--------------------------------------------------------------------
init([Proplist]) ->
  App = proplists:get_value(app, Proplist),
  From = proplists:get_value(caller, Proplist),
  Updating = proplists:get_value(updating, Proplist),
  
  case App#app.latest_error of
    undefined ->
      {ok, preparing, #state{app = App, from = From, updating = Updating, bee = #bee{}}};
    _ ->
      {stop, {error, pending_app_error}}
  end.

%%--------------------------------------------------------------------
%% Function:
%% state_name(Event, State) -> {next_state, NextStateName, NextState}|
%%                             {next_state, NextStateName,
%%                                NextState, Timeout} |
%%                             {stop, Reason, NewState}
%% Description:There should be one instance of this function for each possible
%% state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_event/2, the instance of this function with the same name as
%% the current state name StateName is called to handle the event. It is also
%% called if a timeout occurs.
%%--------------------------------------------------------------------
preparing({update}, #state{app = App} = State) ->
  Pid = node_manager:get_next_available(storage),
  Node = node(Pid),
  Self = self(),
  rpc:cast(Node, beehive_storage_srv, rebuild_bee, [App, Self]),
  {next_state, updating, State};

preparing({launch}, #state{host = Host, app = App} = State) ->
  case Host of
    false -> {stop, no_node_found, State};
    _ ->
      NewState = start_instance(State#state{latest_sha = App#app.sha}),
      {next_state, launching, NewState}
  end;

preparing({start_new}, State) ->
  self() ! {bee_built, []},
  {next_state, updating, State};

preparing(Other, State) ->
  stop_error({preparing, Other}, State).

updating({bee_built, Info}, #state{bee = Bee, app = App} = State) ->
  % Strip off the last newline... stupid bash
  BeeSize = proplists:get_value(bee_size, Info, Bee#bee.bee_size),
  Sha = proplists:get_value(sha, Info, Bee#bee.commit_hash),

  NewApp = App#app{sha = Sha},
  NewBee = Bee#bee{bee_size = BeeSize, commit_hash = Sha},
  % Grr
  NewState0 = State#state{bee = NewBee, app = NewApp, latest_sha = Sha},
  NewState = start_instance(NewState0),
  {next_state, launching, NewState};

updating(Msg, State) ->
  stop_error({updating, Msg}, State).

launching({started_bee, Be}, State) ->
  bees:create(Be),
  Self = self(),
  ?LOG(info, "spawn_update_bee_status: ~p for ~p, ~p", [Be, Self, 20]),
  app_manager:spawn_update_bee_status(Be, Self, 20),
  {next_state, pending, State#state{bee = Be}};

launching({error, Reason}, State) ->
  stop_error({launching, Reason}, State);

launching(Event, State) ->
  ?LOG(info, "Uncaught event: ~p while in state: ~p ~n", [Event, launching]),
  {next_state, launching, State}.

pending({updated_bee_status, broken}, State) ->
  erlang:display({pending, updated_bee_status, broken}),
  stop_error({error, broken_start}, State);
  
pending({updated_bee_status, BackendStatus}, #state{app = App, bee = Bee, from = From, latest_sha = Sha, updating = Updating} = State) ->
  ?LOG(info, "Application started ~p: ~p", [BackendStatus, App#app.name]),
  % App started normally
  case Updating of
    true -> From ! {bee_updated_normally, Bee#bee{status = BackendStatus}, App#app{sha = Sha}};
    false -> From ! {bee_started_normally, Bee#bee{status = BackendStatus}, App#app{sha = Sha}}
  end,
  {stop, normal, State};
  
pending(Event, State) ->
  ?LOG(info, "Got uncaught event in pending state: ~p", [Event]),
  {next_state, pending, State}.
  
state_name(Event, State) ->
  io:format("Uncaught event: ~p while in state: ~p ~n", [Event, state_name]),
  {next_state, state_name, State}.

%%--------------------------------------------------------------------
%% Function:
%% state_name(Event, From, State) -> {next_state, NextStateName, NextState} |
%%                                   {next_state, NextStateName,
%%                                     NextState, Timeout} |
%%                                   {reply, Reply, NextStateName, NextState}|
%%                                   {reply, Reply, NextStateName,
%%                                    NextState, Timeout} |
%%                                   {stop, Reason, NewState}|
%%                                   {stop, Reason, Reply, NewState}
%% Description: There should be one instance of this function for each
%% possible state name. Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_event/2,3, the instance of this function with the same
%% name as the current state name StateName is called to handle the event.
%%--------------------------------------------------------------------
state_name(Event, _From, State) ->
  Reply = ok,
  io:format("Uncaught event: ~p while in state: ~p ~n", [Event, state_name]),
  {reply, Reply, state_name, State}.

%%--------------------------------------------------------------------
%% Function:
%% handle_event(Event, StateName, State) -> {next_state, NextStateName,
%%                                                NextState} |
%%                                          {next_state, NextStateName,
%%                                                NextState, Timeout} |
%%                                          {stop, Reason, NewState}
%% Description: Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_all_state_event/2, this function is called to handle
%% the event.
%%--------------------------------------------------------------------
handle_event(Event, StateName, State) ->
  io:format("Uncaught event: ~p while in state: ~p ~n", [Event, StateName]),
  {next_state, StateName, State}.

%%--------------------------------------------------------------------
%% Function:
%% handle_sync_event(Event, From, StateName,
%%                   State) -> {next_state, NextStateName, NextState} |
%%                             {next_state, NextStateName, NextState,
%%                              Timeout} |
%%                             {reply, Reply, NextStateName, NextState}|
%%                             {reply, Reply, NextStateName, NextState,
%%                              Timeout} |
%%                             {stop, Reason, NewState} |
%%                             {stop, Reason, Reply, NewState}
%% Description: Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_all_state_event/2,3, this function is called to handle
%% the event.
%%--------------------------------------------------------------------
handle_sync_event(_Event, _From, StateName, State) ->
  Reply = ok,
  {reply, Reply, StateName, State}.

%%--------------------------------------------------------------------
%% Function:
%% handle_info(Info,StateName,State)-> {next_state, NextStateName, NextState}|
%%                                     {next_state, NextStateName, NextState,
%%                                       Timeout} |
%%                                     {stop, Reason, NewState}
%% Description: This function is called by a gen_fsm when it receives any
%% other message than a synchronous or asynchronous event
%% (or a system message).
%%--------------------------------------------------------------------
handle_info(Info, StateName, State) ->
  apply(?MODULE, StateName, [Info, State]).
  % {next_state, StateName, State}.

%%--------------------------------------------------------------------
%% Function: terminate(Reason, StateName, State) -> void()
%% Description:This function is called by a gen_fsm when it is about
%% to terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_fsm terminates with
%% Reason. The return value is ignored.
%%--------------------------------------------------------------------
terminate(_Reason, _StateName, _State) ->
  ok.

%%--------------------------------------------------------------------
%% Function:
%% code_change(OldVsn, StateName, State, Extra) -> {ok, StateName, NewState}
%% Description: Convert process state when code is changed
%%--------------------------------------------------------------------
code_change(_OldVsn, StateName, State, _Extra) ->
  {ok, StateName, State}.

%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------
start_instance(#state{from = From, app = App, bee = Bee, latest_sha = Sha} = State) ->
  Pid = node_manager:get_next_available(node),
  Node = node(Pid),
  rpc:cast(Node, app_handler, start_new_instance, [App, Sha, self(), From]),
  State#state{bee = Bee#bee{host_node = Node}}.

stop_error(Msg, #state{from = From, app = App} = State) ->
  Tuple = {?MODULE, error, Msg, App},
  From ! Tuple,
  {stop, Tuple, State}.