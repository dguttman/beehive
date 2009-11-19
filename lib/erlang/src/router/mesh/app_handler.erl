%%%-------------------------------------------------------------------
%%% File    : app_handler.erl
%%% Author  : Ari Lerner
%%% Description : 
%%%
%%% Created :  Wed Nov 18 16:10:17 PST 2009
%%%-------------------------------------------------------------------

-module (app_handler).
-include ("router.hrl").
-include ("common.hrl").

-export ([
  start_new_instance/3,
  stop_instance/3
]).

% Start a new instance of the application
start_new_instance(App, Port, From) ->
  ?LOG(info, "App ~p", [App]),
  
  TemplateCommand = App#app.start_command,
  ?LOG(info, "start command ~p", [TemplateCommand]),
  
  RealCmd = template_command_string(TemplateCommand, [
                                                        {"[[PORT]]", misc_utils:to_list(Port)},
                                                        {"[[GROUP]]", App#app.group},
                                                        {"[[USER]]", App#app.user}
                                                      ]),
  % START INSTANCE
  % P = spawn(fun() -> os:cmd(NewCmd) end),
  % port_handler:start("thin -R beehive.ru --port 5000 start", "/Users/auser/Development/erlang/mine/router/test/fixtures/apps").
  ?LOG(info, "Starting on port ~p as ~p:~p with ~p", [Port, App#app.group, App#app.user, RealCmd]),
  Pid = port_handler:start(RealCmd, App#app.path),
  Host = host:myip(),
  
  Backend  = #backend{
    id                      = {App#app.name, Host, Port},
    app_name                = App#app.name,
    host                    = Host,
    port                    = Port,
    status                  = pending,
    pid                     = Pid,
    start_time              = date_util:now_to_seconds()
  },
  
  From ! {started_backend, Backend},
  Backend.

% kill the instance of the application  
stop_instance(Backend, App, From) ->
  RealCmd = template_command_string(App#app.stop_command, [
                                                        {"[[PORT]]", erlang:integer_to_list(Backend#backend.port)},
                                                        {"[[GROUP]]", App#app.group},
                                                        {"[[USER]]", App#app.user}
                                                      ]),

  Backend#backend.pid ! {stop, RealCmd},
  os:cmd(RealCmd),
  From ! {stopped_backend, Backend}.

% turn the command string from the comand string with the values
% of [[KEY]] replaced by the corresponding proplist element of
% the format:
%   {[[PORT]], "80"}
template_command_string(OriginalCommand, []) -> OriginalCommand;
template_command_string(OriginalCommand, [{Str, Replace}|T]) ->
  NewCommand = string_utils:gsub(OriginalCommand, Str, Replace),
  template_command_string(NewCommand, T).