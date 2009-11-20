%%%-------------------------------------------------------------------
%%% File    : node_manager.erl
%%% Author  : Ari Lerner
%%% Description : 
%%%
%%% Created :  Tue Nov 17 10:29:53 PST 2009
%%%-------------------------------------------------------------------

-module (node_manager).
-include ("common.hrl").
-include ("router.hrl").
-behaviour(gen_server).

%% API
-export([
  start_link/0,
  start_link/2,
  request_to_start_new_backend/1,
  get_host/0, get_seed/0,
  get_routers/0, get_nodes/0,
  dump/1,
  join/1,
  can_deploy_new_app/0
]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record (state, {
  seed,             % seed host
  host              % local host
}).

-define(SERVER, ?MODULE).
-define (ROUTER_SERVERS, 'ROUTER SERVERS').
-define (NODE_SERVERS, 'NODE SERVERS').
-define (APP_HANDLER, app_handler).

%%====================================================================
%% API
%%====================================================================
%%--------------------------------------------------------------------
%% Function: start_link() -> {ok,Pid} | ignore | {error,Error}
%% Description: Starts the server
%%--------------------------------------------------------------------
start_link() -> 
  Seed = apps:search_for_application_value(seed, node(), router),
  case apps:search_for_application_value(node_type, router, router) of
    router -> start_link(router, Seed);
    node -> start_link(node, Seed)
  end.
  
start_link(router, Seed) -> 
  case gen_server:start_link({local, ?MODULE}, ?MODULE, [router, Seed], []) of
    {ok, Pid} ->
      pg2:create(?ROUTER_SERVERS),
      ok = pg2:join(?ROUTER_SERVERS, Pid),
      {ok, Pid};
    Else ->
      ?LOG(error, "Could not start router link: ~p~n", [Else])
  end;
  
start_link(node, Seed) -> 
  case gen_server:start_link({local, ?MODULE}, ?MODULE, [node, Seed], []) of
    {ok, Pid} ->
      pg2:create(?NODE_SERVERS),
      ok = pg2:join(?NODE_SERVERS, Pid),
      {ok, Pid};
    Else ->
      ?LOG(error, "Could not start router link: ~p~n", [Else])
  end.
  
get_host() -> gen_server:call(?SERVER, {get_host}).

join([]) -> ok;
join(SeedNode) ->
  case net_adm:ping(SeedNode) of
    pong -> ok;
    pang -> error
  end.

get_routers() -> 
  pg2:create(?ROUTER_SERVERS),
  pg2:get_members(?ROUTER_SERVERS).
  
get_nodes() -> 
  pg2:create(?NODE_SERVERS),
  pg2:get_members(?NODE_SERVERS).
  
request_to_start_new_backend(Name) -> 
  gen_server:cast(?SERVER, {request_to_start_new_backend, Name}).

dump(Pid) ->
  gen_server:call(?SERVER, {dump, Pid}).

get_seed() ->
  gen_server:call(?SERVER, {get_seed}).

can_deploy_new_app() ->
  gen_server:call(?SERVER, {can_deploy_new_app}).
    
%%====================================================================
%% gen_server callbacks
%%====================================================================

%%--------------------------------------------------------------------
%% Function: init(Args) -> {ok, State} |
%%                         {ok, State, Timeout} |
%%                         ignore               |
%%                         {stop, Reason}
%% Description: Initiates the server
%%--------------------------------------------------------------------
init([Type, Seed]) ->
  process_flag(trap_exit, true),  
  
  case Type of
    router ->
      case Seed of
        [] -> 
          % Initializing root router
          db:init();
        _ -> 
          ?LOG(info, "Initializing slave db: ~p", [Seed]),
          mesh_util:init_db_slave(Seed)
      end;
    node ->
      % Node initialization stuff
      ok
  end,
  
  join(Seed),
  timer:send_interval(timer:seconds(10), {stay_connected_to_seed, Seed}),
  % timer:send_interval(timer:minutes(1), {update_node_pings}),
  
  LocalHost = host:myip(),
  
  {ok, #state{
    seed = Seed,
    host = LocalHost
  }}.

%%--------------------------------------------------------------------
%% Function: %% handle_call(Request, From, State) -> {reply, Reply, State} |
%%                                      {reply, Reply, State, Timeout} |
%%                                      {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, Reply, State} |
%%                                      {stop, Reason, State}
%% Description: Handling call messages
%%--------------------------------------------------------------------
handle_call({can_deploy_new_app}, _From, State) ->
  Nodes = lists:map(fun(N) -> node(N) end, get_nodes()),
  {Responses, _} = rpc:multicall(Nodes, ?APP_HANDLER, can_deploy_new_app, [], timer:seconds(3)),
  Reply = lists:member(true, Responses),
  {reply, Reply, State};
handle_call({get_seed}, _From, #state{seed = Seed} = State) ->
  {reply, Seed, State};
handle_call({get_host}, _From, #state{host = Host} = State) ->
  {reply, Host, State};
handle_call({dump, Pid}, _From, State) ->
  Name = node(Pid),
  Host = rpc:call(Name, host, myip, []),
  Node = #node{ name = Name, host = Host },
  {reply, Node, State};
handle_call(_Request, _From, State) ->
  Reply = ok,
  {reply, Reply, State}.

%%--------------------------------------------------------------------
%% Function: handle_cast(Msg, State) -> {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, State}
%% Description: Handling cast messages
%%--------------------------------------------------------------------
handle_cast({request_to_start_new_backend, Name}, State) ->
  Backends = backend:find_all_by_name(Name),
  % Don't start a new backend if there is a pending one
  PendingBackends = lists:filter(fun(B) -> B#backend.status =:= pending end, Backends),
  case length(PendingBackends) > 0 of
    false -> start_new_instance_by_name(Name);
    true -> ok
  end,
  {noreply, State};
handle_cast(_Msg, State) ->
  {noreply, State}.

%%--------------------------------------------------------------------
%% Function: handle_info(Info, State) -> {noreply, State} |
%%                                       {noreply, State, Timeout} |
%%                                       {stop, Reason, State}
%% Description: Handling all non call/cast messages
%%--------------------------------------------------------------------
handle_info({stay_connected_to_seed, Seed}, State) ->
  join(Seed),
  {noreply, State};
  
handle_info(Info, State) ->
  ?LOG(info, "handle_info: ~p ~p", [?MODULE, Info]),
  {noreply, State}.

%%--------------------------------------------------------------------
%% Function: terminate(Reason, State) -> void()
%% Description: This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any necessary
%% cleaning up. When it returns, the gen_server terminates with Reason.
%% The return value is ignored.
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
  ok.

%%--------------------------------------------------------------------
%% Func: code_change(OldVsn, State, Extra) -> {ok, NewState}
%% Description: Convert process state when code is changed
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------
get_next_available_host() ->
  case (catch mesh_util:get_random_pid(?NODE_SERVERS)) of
    {ok, Pid} ->
      Node = node(Pid),
      case rpc:call(Node, ?MODULE, can_deploy_new_app, []) of
        true ->
          ?LOG(info, "Available host: ~p", [Node]),
          Node;
        false -> get_next_available_host()
      end;
    {'EXIT', _} ->
      ?LOG(error, "Could not start a new backend because there are no nodes to start", []),
      false;
    {error, Reason} ->
      ?LOG(error, "Could not start a new app because: ~p", [Reason]),
      false
  end.

start_new_instance_by_name(Name) ->
  case get_next_available_host() of
    false -> false;
    Host ->
      App = app:find_by_name(Name),
      spawn_to_start_new_instance(App, Host)
  end.
% Start with the app_launcher_fsm
spawn_to_start_new_instance(Name, Host) ->
  {ok, P} = app_launcher_fsm:start_link(Name, Host),
  app_launcher_fsm:launch(P).