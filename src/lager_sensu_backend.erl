-module(lager_sensu_backend).

-author('mhald@mac.com').

-behaviour(gen_event).

-export([init/1,
         handle_call/2,
         handle_event/2,
         handle_info/2,
         terminate/2,
         code_change/3
]).

-record(state, {socket :: pid(),
                lager_level_type :: 'mask' | 'number' | 'unknown',
                level :: atom(),
                sensu_host :: string(),
                sensu_port :: number(),
                sensu_address :: inet:ip_address()
}).

init(Params) ->
  %% we need the lager version, but we aren't loaded, so... let's try real hard
  %% this is obviously too fragile
  {ok, Properties}     = application:get_all_key(),
  {vsn, Lager_Version} = proplists:lookup(vsn, Properties),
  Lager_Level_Type =
    case string:to_float(Lager_Version) of
      {V1, _} when V1 < 2.0 ->
        'number';
      {V2, _} when V2 =:= 2.0 ->
        'mask';
      {_, _} ->
        'unknown'
    end,

  Level = lager_util:level_to_num(proplists:get_value(level, Params, critical)),
  Popcorn_Host = proplists:get_value(sensu_host, Params, "localhost"),
  Popcorn_Port = proplists:get_value(sensu_port, Params, 3030),

 {Socket, Address} =
   case inet:getaddr(Popcorn_Host, inet) of
     {ok, Addr} ->
       {ok, Sock} = gen_udp:open(0, [list]),
       {Sock, Addr};
     {error, _Err} ->
       {undefined, undefined}
   end,

  {ok, #state{socket = Socket,
              lager_level_type = Lager_Level_Type,
              level = Level,
              sensu_host = Popcorn_Host,
              sensu_port = Popcorn_Port,
              sensu_address = Address}}.

handle_call({set_loglevel, Level}, State) ->
  {ok, ok, State#state{level=lager_util:level_to_num(Level)}};

handle_call(get_loglevel, State) ->
  {ok, State#state.level, State};

handle_call(_Request, State) ->
  {ok, ok, State}.

handle_event({log, _}, #state{socket=S}=State) when S =:= undefined ->
  {ok, State};
handle_event({log, {lager_msg, Q, _Metadata, Severity, {Date, Time}, _, Message}}, State) ->
  handle_event({log, {lager_msg, Q, _Metadata, Severity, {Date, Time}, Message}}, State);

handle_event({log, {lager_msg, _, _Metadata, Severity, {Date, Time}, Message}}, #state{level=L}=State) ->
  Level_Num = lager_util:level_to_num(Severity),
  case Level_Num =< L of
    true ->
      Encoded_Message = encode_json_event(State#state.lager_level_type,
                                                  node(),
                                                  Level_Num,
                                                  Date,
                                                  Time,
                                                  Message),
      gen_udp:send(State#state.socket,
                   State#state.sensu_address,
                   State#state.sensu_port,
                   Encoded_Message);
    _ ->
      ok
  end,
  {ok, State};

handle_event(_Event, State) ->
  {ok, State}.

handle_info(_Info, State) ->
  {ok, State}.

terminate(_Reason, #state{socket=S}=_State) ->
  gen_udp:close(S),
  ok;
terminate(_Reason, _State) ->
  ok.

code_change(_OldVsn, State, _Extra) ->
  {ok, State}.

encode_json_event('mask', Node, Severity, _Date, _Time, Message) ->
  jiffy:encode({[
                {<<"name">>, list_to_binary(atom_to_list(Node))},
                {<<"type">>, <<"metric">>},
                {<<"output">>, safe_list_to_binary(Message)},
                {<<"status">>, Severity},
                {<<"handler">>, <<"production_critical">>}
            ]
  }).

safe_list_to_binary(L) when is_list(L) ->
  unicode:characters_to_binary(L);
safe_list_to_binary(L) when is_binary(L) ->
  unicode:characters_to_binary(L).
