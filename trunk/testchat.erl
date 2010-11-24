-module(testchat).
-export([listen/1]).
-import(rfc4627,[encode/1,decode/1]).
-author("peaceflash <peaceflash@gmail.com>").
-define(TCP_OPTIONS,[list, {packet, 0}, {active, false}, {reuseaddr, true}]).
-record(player, {name=none, room=0,socket, mode}).
%% Ҫ���ܽ������ӣ��������� TCP �˿ڡ�
%% ��Ҳ����������������ڵ㡣
listen(Port) ->  
case gen_tcp:listen(Port, ?TCP_OPTIONS) of       
	{ok,LSocket} -> 
	io:fwrite("Socket listen :success ~n",[]),
	register(client_manager_pid, spawn(fun() -> client_manager([]) end)),    %%ע��ͻ���
	do_accept(LSocket);
	{error, Reason} -> 
   io:fwrite("Socket listen : error ~s~n", [Reason])    
  end.

 %% ��������ʱ���յ��´����� socket��
 %% ��ΪҪ���ܶ�����ӣ���ÿ��socket����һ�����̣�
 %% Ȼ��ص�����socket�ϵȴ���һ�����ӡ�
 
 do_accept(LSocket) ->
 	 case gen_tcp:accept(LSocket) of        
  {ok, Socket} -> 
   io:fwrite("Socket accept:success~n"),
   
   spawn(fun() -> handle_client(Socket) end), %% �������̽�������
 	 client_manager_pid ! {connect, Socket};  
  {error, Reason} -> 
   io:fwrite("Socket accept : error ~s~n", [Reason])    
   end,   
 do_accept(LSocket). %%�����ȴ�
 
 
 %% ������������һ����ʲô������ͻ��˶Ͽ��˵ȵ�
 handle_client(Socket) ->
  case gen_tcp:recv(Socket, 0) of       
     {ok, Data} -> 
     %% io:fwrite("client socket send data ~n"), 
      io:fwrite("client socket send data ~p ~n",[Data]), 
      client_manager_pid ! {data, Socket, Data},   
     handle_client(Socket);
     {error, closed} ->
     				client_manager_pid ! {disconnect, Socket} ,        
             io:fwrite("client Socket closed ~n")    
               end. 
               
               
%% �ͻ��˴����������ݴ���
client_data(Data,Socket) ->
 {ok, D, []} = rfc4627:decode(Data),
 {ok,UserName}=rfc4627:get_field(D,"username"),
  {ok,RoomId}=rfc4627:get_field(D,"roomid"),
   {ok,Talk}=rfc4627:get_field(D,"talk"),
	_Resp = rfc4627:encode({obj, [{"roomid", RoomId}, {"username", UserName},{"talk",Talk}]}),   
	%%gen_tcp:send(Socket,_Resp).
	client_manager_pid ! {data,Socket,_Resp}.

 				
                                   
%%%�ͻ��˹���
client_manager(UserList)->
	%%lists:foreach(fun(P) -> io:fwrite(">>> ~w~n", [P]) end, UserList),
	 io:format("num:~w~n", [length(UserList)]),
	receive
        {connect, Socket} ->
			{ok, {IP, Port}} = inet:peername(Socket),
						Player = #player{socket=Socket, mode=connect}, 
						send_client(Player),
						NewPlayers =  [Player | UserList],
            io:format("[connect_manager][~p] -> connect from ~p:~p~n", [time(),IP,Port]);
      {disconnect, Socket} ->
        		Player = find_user(Socket, UserList), 
        		NewPlayers = lists:delete(Player, UserList),
            io:format("[connect_manager][~p] -> disconnect!~n", [time()]);
            
        {timeout, Socket} ->
        		Player = find_user(Socket, UserList), 
        		NewPlayers = lists:delete(Player, UserList),
            io:format("[connect_manager][~p] -> timeout!~n", [time()]);
        {data, Socket, Data} ->
        		
        		 Player = find_user(Socket, UserList),
        		 NewPlayers = UserList,
        		 send_date_client(Player, UserList, Data);
           %% lists:foreach(fun(P) -> gen_tcp:send(P#player.socket,Data) end,UserList);
        Other ->
        		NewPlayers = UserList,
            io:format("[connect_manager][~p] -> Other: ~p~n", [time(), Other])
    end,
client_manager(NewPlayers).
		 
		 
%%%���ͻ�ӭ������Ϣ
send_client(Player) ->
		case Player#player.mode of     
         connect ->            
         			gen_tcp:send(Player#player.socket,  rfc4627:encode({obj, [{"welcome", ["welcome"]}]})); %% ������SOCKET���ͻ�ӭ��Ϣ                                                                 
				 active ->            ok     end.
				
%%������Ϣ
send_date_client(Player, UserList, Data)->
	%%{ok, D, []} = rfc4627:decode(Data),
 	%%{ok,UserName}=rfc4627:get_field(D,"username"),
 %% {ok,RoomId}=rfc4627:get_field(D,"roomid"),
 %% {ok,Talk}=rfc4627:get_field(D,"talk"),
	%%_Resp = rfc4627:encode({obj, [{"roomid", RoomId}, {"username", UserName},{"talk",Talk}]}),
	ActivePlayers = lists:filter(fun(P) -> P#player.mode == active end,     UserList),  
	lists:foreach(fun(P) -> gen_tcp:send(P#player.socket,Data) end,UserList).
	 
	 


%%%�����û�
find_user(Socket, UserList) -> 
            {value, Player} = lists:keysearch(Socket, #player.socket, UserList),
             Player.
%%%ɾ���û�
%%delete_user(Player, UserList) ->   
%%             lists:keydelete(Player#player.socket, #player.socket, UserList),
%%            UserList.