extends Node

var number = 0
var last_username = ""
var highscore = 0
var highscore_username = ""
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
	pass # Replace with function body.

func _show_settings():
	#$"../Game/Panel/Sprite".connect()
	pass

func _get_message(data):
	print(data)
	if(!data.has('msg') 
		|| !data.has('cmd') 
		|| data.cmd != 'PRIVMSG' 
		|| !data.has('username') 
		|| !data.has('room-id')
		):
		return
	_refreshSettings();
	var punishTime = settings.minBanTime + number * settings.banTimeMultiplier

	var regex = RegEx.new()
	regex.compile("^([0-9]{1,}).*$")
	var result = regex.search(data.msg.left(data.msg.length()-1))
	
	if result && result.get_string() == result.get_string(1):
		var testNumber = int( data.msg );
		
		#COMENZAR SOLO CON 1
		if( number == 0 && testNumber != 1 ):
			return
		#banPlayerWithCurrentNumber
		if(last_username == data["username"]):
			if( settings.banPlayerWithCurrentNumber):
				$"../TwitchChat"._ban(data["room-id"],data["user-id"],settings.banPlayerWithCurrentNumberTime,"Cheater")
			return
		
		if( testNumber == number+1 ):
			number += 1
			if( highscore < number ):
				$"../Game/Panel/label_highscore".text = "HIGH SCORE: "+ str(number)
				$"../Game/Panel/label_by".text = "by "+ data["username"]
			last_username = data["username"]
			$"../Game/Panel/label_username".text = last_username
		else:
			#ENDGAME
			number = 0;
			last_username = ""
			$"../Game/Panel/label_username".text = "Pierde: "+ data["username"]
			$"../TwitchChat"._ban(data["room-id"],data["user-id"],punishTime,"Loser")
			
	$"../Game/Panel/number".text = str(number)
	

