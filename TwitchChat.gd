extends Node

# oauth-dev.seyacat.com client_id integration
var client_id = "qhndxilvmmnsb8xq5jfmbvqk544opx"
var ws = WebSocketClient.new()
var connected = false;
signal new_message(data);
var temp_id
var auth

# Called when the node enters the scene tree for the first time.
func _ready():
	var _timer = Timer.new()
	add_child(_timer)
	_timer.connect("timeout", self, "_tic")
	_timer.set_wait_time(1.0)
	_timer.set_one_shot(false) # Make sure it loops
	_timer.start()
	
	_load_session()
	if(auth):
		_ws_connect()
		pass

func _tic(): 
	if auth:
		$"../Game/Panel2/VBoxContainer/HBoxContainer6/anonimousConnectionStatus".color = Color.gray
		if ws.get_connection_status() == WebSocketClient.CONNECTION_CONNECTED:
			$"../Game/Panel2/VBoxContainer/HBoxContainer7/connectionStatus".color = Color.green
		else:
			$"../Game/Panel2/VBoxContainer/HBoxContainer7/connectionStatus".color = Color.red
	else:
		$"../Game/Panel2/VBoxContainer/HBoxContainer7/connectionStatus".color = Color.gray
		if ws.get_connection_status() == WebSocketClient.CONNECTION_CONNECTED:
			$"../Game/Panel2/VBoxContainer/HBoxContainer6/anonimousConnectionStatus".color = Color.green
		else:
			$"../Game/Panel2/VBoxContainer/HBoxContainer6/anonimousConnectionStatus".color = Color.red
			
func _authenticate():
	auth = null
	temp_id =  str(RandomNumberGenerator.new().randf_range(0,100))+str(RandomNumberGenerator.new().randf_range(0,100));
	OS.shell_open("https://oauth-dev.seyacat.com/twitch/login?&scope=user:read:email+channel:manage:vips+moderator:manage:banned_users+chat:read&temp_id="+temp_id);

func _anon_connection():
	auth = null
	_ws_connect()

func _ws_connect():
	ws = WebSocketClient.new()
	ws.connect("data_received", self, "_on_data")
	ws.connect("connection_established", self, "_connected")
	ws.connect("connection_closed", self, "_closed")
	#var err = ws.connect_to_url("wss://irc-ws.chat.twitch.tv:443");
	
	var err = ws.connect_to_url("ws://irc-ws.chat.twitch.tv:80");
	
	print("err=",err)
	if err != OK:
		print("Unable to connect")
		set_process(false)

func _connected(proto = ""):
	print("Connected with protocol: ", proto)
	connected = true;
	yield(get_tree().create_timer(1), "timeout")
	
	ws.get_peer(1).set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)
	ws.get_peer(1).put_packet("CAP REQ :twitch.tv/membership twitch.tv/tags twitch.tv/commands".to_utf8())
	print(auth)
	if auth && auth.has("accessToken"):
		ws.get_peer(1).put_packet(("PASS oauth:" + auth.accessToken).to_utf8())
		ws.get_peer(1).put_packet(("NICK "+auth.twitchUser.login).to_utf8())
		ws.get_peer(1).put_packet(("JOIN #"+auth.twitchUser.login).to_utf8())
	else:
		var anonimousChannel = $"../Game/Panel2/VBoxContainer/HBoxContainer6/anonimousChannel".text
		ws.get_peer(1).put_packet("NICK justinfan12345".to_utf8())
		ws.get_peer(1).put_packet("PASS kappa".to_utf8())
		ws.get_peer(1).put_packet(("JOIN #"+anonimousChannel).to_utf8())
	
	
	
func _on_data():
	var msg = ws.get_peer(1).get_packet().get_string_from_utf8()
	var data = {}
	var dataPairs = msg.split(";");
	for pair in dataPairs:
		var d = pair.split("=");
		if d.size() == 2:
			data[d[0]]=d[1]
	
	
	var regex = RegEx.new()
	regex.compile("(?:(([a-zA-Z0-9_]*?)!([a-zA-Z0-9_]*?)@[a-zA-Z0-9_]*?.tmi.twitch.tv)|tmi.twitch.tv)\\s([A-Z]*?)?\\s#([^\\s]*)\\s{0,}:?(.*?)?$")
	var result = regex.search(msg)
	if result:
		data["username"] = result.get_string(2)
		data["cmd"] = result.get_string(4)
		data["channel"] = result.get_string(5)
		data["msg"] = result.get_string(6)
	
	if(data.has("cmd") && data.cmd == "PING" ):
		_send("PONG")
		
	emit_signal("new_message",data)
	#Regex regex = new Regex(@"(.*?):(?:(([a-zA-Z0-9_]*?)!([a-zA-Z0-9_]*?)@[a-zA-Z0-9_]*?.tmi.twitch.tv)|tmi.twitch.tv)\s([A-Z]*?)?\s#([^\s]*)\s{0,}:?(.*?)?$", RegexOptions.IgnoreCase);

func _send(msg):
	ws.get_peer(1).set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)
	ws.get_peer(1).put_packet(msg.to_utf8())
	
func _closed(was_clean = false):
	print("Closed, clean: ", was_clean)
	_ws_connect()
	#set_process(false)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if !ws || ws.get_connection_status() == WebSocketClient.CONNECTION_DISCONNECTED:
		return
	ws.poll();
		
func _requestCredentials():
	if(temp_id && !auth):
		$HTTPRequest.connect("request_completed", self,"_processCredentials")
		$HTTPRequest.request("https://oauth-dev.seyacat.com/twitch/tempid?temp_id="+temp_id)
		
func _processCredentials(result, response_code, headers, body):
	$HTTPRequest.disconnect("request_completed", self,"_processCredentials")
	var json = parse_json(body.get_string_from_utf8())
	if(json):
		auth = json
	_save_session()
	_ws_connect()
	
#TODO: ADD TIMER RETRIEVE ACCESS TOKEN
func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_FOCUS_IN :
		print("NOTIFICATION_APPLICATION_FOCUS_IN")
		_requestCredentials()
	if what == MainLoop.NOTIFICATION_WM_FOCUS_OUT :
		print("NOTIFICATION_APPLICATION_FOCUS_OUT")
	pass
			
# Note: This can be called from anywhere inside the tree.  This function is path independent.
# Go through everything in the persist category and ask them to return a dict of relevant variables
func _save_session():
	var file = File.new()
	file.open("user://session.dat", File.WRITE)
	file.store_string( JSON.print(auth) )
	file.close()
	
func _load_session():
	var file = File.new()
	file.open("user://session.dat", File.READ)
	var content = file.get_as_text()
	file.close()
	var temp_auth = parse_json(content)
	if(temp_auth):
		auth = temp_auth
		
func _ban(data,duration,reason="no reason"):
	if !auth || !data.has("room-id") || !data.has("user-id"):
		return
	var headers = ["Content-Type: application/json", 
		'Client-Id: '+client_id, 
		'Authorization: Bearer '+auth.accessToken]
	var json = JSON.print({"data": {"user_id":data["user-id"],"duration":duration,"reason":reason}})
	var httr = _newTemporalHttpRequest()
	httr.request(
		"https://api.twitch.tv/helix/moderation/bans?broadcaster_id="+str(data["room-id"])+"&moderator_id="+str(auth.twitchUser.id),
		headers,true,
		HTTPClient.METHOD_POST, json)
		
func _vip(data):
	print("VIIIIIP")
	if !auth || !data.has("room-id") || !data.has("user-id"):
		return
	print("https://api.twitch.tv/helix/channels/vips?broadcaster_id="+str(data["room-id"])+"&user_id="+str(data["user-id"]))
	var headers = [
		'Client-Id: '+client_id, 
		'Authorization: Bearer '+auth.accessToken]
	var httr = _newTemporalHttpRequest()
	httr.request(
		"https://api.twitch.tv/helix/channels/vips?broadcaster_id="+str(data["room-id"])+"&user_id="+str(data["user-id"]),
		headers,true,
		HTTPClient.METHOD_POST)
func _unvip(data):
	print("UNVIP")
	if !auth || !data.has("room-id") || !data.has("user-id"):
		return
	var headers = [ 
		'Client-Id: '+client_id, 
		'Authorization: Bearer '+auth.accessToken]
	var httr = _newTemporalHttpRequest()
	httr.request(
		"https://api.twitch.tv/helix/channels/vips?broadcaster_id="+str(data["room-id"])+"&user_id="+str(data["user-id"]),
		headers,true,
		HTTPClient.METHOD_DELETE)

func _newTemporalHttpRequest():
	var httr = HTTPRequest.new();
	httr.connect('request_completed',self,'_delTemporalHttpRequest',[httr])
	add_child(httr)
	return httr
	
func _delTemporalHttpRequest(result, response_code, headers, body, httr):
	print(result)
	httr.queue_free()
	
	


