%% ---
%%  Excerpted from "Programming Erlang",
%%  published by The Pragmatic Bookshelf.
%%  Copyrights apply to this code. It may not be used to create training material, 
%%  courses, books, articles, and the like. Contact us if you are in doubt.
%%  We make no guarantees that this code is fit for any purpose. 
%%  Visit http://www.pragmaticprogrammer.com/titles/jaerlang for more book information.
%%---

-module(chat_group).
-import(lib_chan_mm, [send/2, controller/2]).
-import(lists, [foreach/2, reverse/2]).

-export([start/2]).

start(C, Nick) ->
    process_flag(trap_exit, true),
    controller(C, self()),
    send(C, ack),
    self() ! {chan, C, {relay, Nick, "I'm starting the group"}},
    group_controller([{C,Nick}]).



delete(Pid, [{Pid,Nick}|T], L) -> {Nick, reverse(T, L)};
delete(Pid, [H|T], L)          -> delete(Pid, T, [H|L]);
delete(_, [], L)               -> {"????", L}.



group_controller([]) ->
    exit(allGone);
group_controller(L) ->
    receive
	{chan, C, {relay, Nick, Str}} ->
	    foreach(fun({Pid,_}) -> send(Pid, {msg,Nick,C,Str}) end, L),
	    group_controller(L);
	{chan, C, {whisper, From, To, Str}} ->
		case lookup(To, L) of
		{ok, Pid} ->
			case lookup(From, L) of
				{ok, FromPid} ->
					send(FromPid, {msg, From, C, Str})
			end,
		    send(Pid, {msg, From, C, Str}),
		    group_controller(L);
		error ->
			send(C, {msg, From, C, "Couldn't find that user!"}),
		    group_controller(L)
	    end;
	{login, C, Nick} ->
	    controller(C, self()),
	    send(C, ack),
		self() ! {chan, C, {relay, Nick, "I'm joining the group"}},
		self() ! {update},
	    group_controller([{C,Nick}|L]);
	{chan_closed, C} ->
	    {Nick, L1} = delete(C, L, []),
		self() ! {chan, C, {relay, Nick, "I'm leaving the group"}},
		self() ! {update},
	    group_controller(L1);
	{update} ->
		foreach(fun({Pid,_}) -> send(Pid, {update, L}) end, L),
		group_controller(L);
	{list_people} ->
		foreach(fun({_, Nick}) -> io:format("~s~n", [Nick]) end, L),
		group_controller(L);
	Any ->
	    io:format("group controller received Msg=~p~n", [Any]),
	    group_controller(L)
	end.
	
	lookup(V, [{Pid,V}|_]) -> {ok, Pid};
	lookup(V, [_|T])       -> lookup(V, T);
	lookup(_,[])           -> error.