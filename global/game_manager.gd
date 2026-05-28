extends Node

enum MenuAction { NONE, HOST, JOIN }

var pending_action: int = MenuAction.NONE
var pending_name: String = "Player"
var pending_color: Color = Color.WHITE
var pending_ip: String = "127.0.0.1"
var pending_port: int = 4789
var return_message: String = ""


func clear():
	pending_action = MenuAction.NONE
	pending_name = "Player"
	pending_ip = "127.0.0.1"
	pending_port = 4789
	return_message = ""
