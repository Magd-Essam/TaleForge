extends Control

var _world: Node
var _nm: Node
var _leaving := false


func _ready():
	_world = get_parent().get_parent()
	_nm = _world.get_node("NetworkManager")

	_nm.player_connected.connect(_on_player_connected)
	_nm.player_disconnected.connect(_on_player_disconnected)
	_nm.connection_failed.connect(_on_connection_failed)
	_nm.server_disconnected.connect(_on_server_disconnected)
	_nm.game_started.connect(_on_game_started)

	$StartBtn.pressed.connect(_on_start_pressed)
	$LeaveBtn.pressed.connect(_on_leave_pressed)

	visible = false


func refresh():
	var is_host = _nm.is_host and multiplayer.multiplayer_peer != null
	var is_connected = _nm.players.size() > 0
	$StartBtn.visible = is_host
	$Title.text = "LOBBY" + (" (Host)" if is_host else "")

	if is_host:
		$StatusLabel.text = "Hosting on port " + str(_nm.host_port)
	elif is_connected:
		$StatusLabel.text = "Connected as " + _nm.my_name
	else:
		$StatusLabel.text = "Connecting..."

	_refresh_player_list()


func _refresh_player_list():
	for child in $PlayerList.get_children():
		child.queue_free()

	for id in _nm.players:
		var entry = _nm.players[id]
		var label = Label.new()
		var is_host_player = id == 1
		label.text = "  [" + str(id) + "] " + entry.name + (" (Host)" if is_host_player else "")
		label.size = Vector2(360, 26)
		label.add_theme_font_size_override("font_size", 16)
		$PlayerList.add_child(label)


func _on_start_pressed():
	_nm.rpc("start_game")


func _on_leave_pressed():
	_leaving = true
	_nm.disconnect_from_server()
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _on_game_started():
	visible = false


func _on_player_connected(_id: int, _name: String):
	refresh()


func _on_player_disconnected(_id: int):
	refresh()


func _on_connection_failed():
	if _leaving:
		return
	$StatusLabel.text = "Connection failed"
	await get_tree().create_timer(1.5).timeout
	GameManager.return_message = "Connection failed"
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _on_server_disconnected():
	if _leaving:
		return
	$StatusLabel.text = "Server disconnected"
	await get_tree().create_timer(1.5).timeout
	GameManager.return_message = "Server disconnected"
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")
