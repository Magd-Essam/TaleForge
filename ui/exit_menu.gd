extends Control

var world: Node
var _nm: Node
var _settings_panel: Control
var _player_list: VBoxContainer


func _ready():
	world = get_parent().get_parent()
	_nm = world.get_node("NetworkManager")
	_settings_panel = world.get_node("UI/SettingsPanel")
	_player_list = $Panel/PlayerList
	visible = false

	$Backdrop.gui_input.connect(_on_backdrop_clicked)
	$Panel/ResumeBtn.pressed.connect(_on_resume_pressed)
	$Panel/SettingsBtn.pressed.connect(_on_settings_pressed)
	$Panel/DisconnectBtn.pressed.connect(_on_disconnect_pressed)
	$Panel/QuitBtn.pressed.connect(_on_quit_pressed)
	_settings_panel.visibility_changed.connect(_on_settings_visibility_changed)
	_nm.player_connected.connect(_on_player_connected)
	_nm.player_disconnected.connect(_on_player_disconnected)

	_refresh_player_list()


func show_menu():
	visible = true
	_refresh_player_list()


func hide_menu():
	visible = false


func toggle():
	visible = not visible
	if visible:
		_refresh_player_list()


func _refresh_player_list():
	for c in _player_list.get_children():
		c.queue_free()
	for id in _nm.players:
		var p = _nm.players[id]
		var hbox = HBoxContainer.new()
		var swatch = ColorRect.new()
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size = Vector2(14, 14)
		swatch.color = p.get("color", Color.WHITE)
		var lbl = Label.new()
		var label = p.get("name", "Unknown")
		if id == _nm.my_id:
			label += " (you)"
		lbl.text = label
		lbl.add_theme_font_size_override("font_size", 14)
		hbox.add_child(swatch)
		hbox.add_child(lbl)
		_player_list.add_child(hbox)


func _on_player_connected(id: int, name: String):
	_refresh_player_list()


func _on_player_disconnected(id: int):
	_refresh_player_list()


func _on_backdrop_clicked(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		hide_menu()


func _on_resume_pressed():
	hide_menu()


func _on_settings_pressed():
	visible = false
	_settings_panel.load_values()
	_settings_panel.visible = true


func _on_disconnect_pressed():
	_nm.disconnect_from_server()
	GameManager.return_message = ""
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _on_quit_pressed():
	get_tree().quit()


func _on_settings_visibility_changed():
	if not _settings_panel.visible and not visible:
		show_menu()
