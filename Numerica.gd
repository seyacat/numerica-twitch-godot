extends Node

var number = 0
var last_username = ""
var highscore = 0
var highscore_username = ""
var highscore_data = null
var old_highscore_data = null
var settings
# Called when the node enters the scene tree for the first time.
func _refreshSettings():
	settings = {
		"minBanTime": $"../Game/Panel2/VBoxContainer/HBoxContainer/minBanTime".value,
		"banTimeMultiplier": $"../Game/Panel2/VBoxContainer/HBoxContainer2/banTimeMultiplier".value,
		"banPlayerWithCurrentNumber":$"../Game/Panel2/VBoxContainer/HBoxContainer3/banPlayerWithCurrentNumber".pressed,
		"allowBanMods":$"../Game/Panel2/VBoxContainer/HBoxContainer4/allowBanMods".pressed,
		"temporalVip":$"../Game/Panel2/VBoxContainer/HBoxContainer5/temporalVip".pressed,
		"allowModsPlay":$"../Game/Panel2/VBoxContainer/HBoxContainer8/allowModsPlay".pressed,
		"banPlayerWithCurrentNumberTime":$"../Game/Panel2/VBoxContainer/HBoxContainer9/banPlayerWithCurrentNumberTime".value
	}
func _ready():
	$"../TwitchChat".connect("new_message",self,"_get_message")

func _process(delta):
	if $"../TwitchChat".anonimous_connected:
		$"../Game/Panel2/VBoxContainer/HBoxContainer7/connectionStatus".color = Color.gray;
		$"../Game/Panel2/VBoxContainer/HBoxContainer6/anonimousConnectionStatus".color = Color.green;
	if $"../TwitchChat".auth_connected:
		$"../Game/Panel2/VBoxContainer/HBoxContainer7/connectionStatus".color = Color.green;
		$"../Game/Panel2/VBoxContainer/HBoxContainer6/anonimousConnectionStatus".color = Color.gray;
	

func _show_settings():
	#$"../Game/Panel/Sprite".connect()
	pass

func _get_message(data):
	print(data)
	if(!data.has('msg') 
		|| !data.has('cmd') 
		|| data.cmd != 'PRIVMSG' 
		|| !data.has('user-id') 
		|| !data.has('username') 
		|| !data.has('room-id')
		):
		return
	_refreshSettings();
	var punishTime = settings.minBanTime + number * settings.banTimeMultiplier
	
	#allowBanMods
	var canBeBanned = true;
	if data.has("badges") && "moderator" in data.badges: 
		if(!settings.allowBanMods):
			canBeBanned = false;

	var regex = RegEx.new()
	regex.compile("^([0-9]{1,}).*$")
	var result = regex.search(data.msg)
	
	if result && result.get_string() == result.get_string(1):
		var testNumber = int( data.msg );
		
		#COMENZAR SOLO CON 1
		if( number == 0 && testNumber != 1 ):
			return
		#banPlayerWithCurrentNumber
		if(last_username == data["username"]):
			if settings.banPlayerWithCurrentNumber && canBeBanned:
				$"../TwitchChat"._ban(data,settings.banPlayerWithCurrentNumberTime,"Cheater")
			return
		#allowModeratorsPlay
		if data.has("badges") && "moderator" in data.badges: 
			if(!settings.allowModsPlay):
				return
		
		if( testNumber == number+1 ):
			#hit
			number += 1
			if( highscore < number ):
				highscore = number
				highscore_username = data["username"]
				highscore_data = data
				$"../Game/Panel/label_highscore".text = "HIGH SCORE: "+ str(highscore)
				$"../Game/Panel/label_by".text = "by "+ highscore_username
			last_username = data["username"]
			$"../Game/Panel/label_username".text = last_username
		else:
			#ENDGAME
			number = 0;
			last_username = ""
			$"../Game/Panel/label_username".text = "Pierde: "+ data["username"]
			#record vips
			if settings.temporalVip:
				if(old_highscore_data &&  data['user-id'] != old_highscore_data['user-id'] ):
					$"../TwitchChat"._unvip(old_highscore_data)
				old_highscore_data = highscore_data
				$"../TwitchChat"._vip(highscore_data)
			
			if canBeBanned:
				$"../TwitchChat"._ban(data,punishTime,"Loser")
			
			
	$"../Game/Panel/number".text = str(number)
	

