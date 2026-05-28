extends Control

var _loading_world: bool = false
var _load_tween: Tween

@onready var join_panel = $Center/MenuPanel/VBoxContainer/JoinPanel
@onready var input_name = $Center/MenuPanel/VBoxContainer/InputName
@onready var color_picker = $Center/MenuPanel/VBoxContainer/ColorHBox/ColorPicker
@onready var input_ip = $Center/MenuPanel/VBoxContainer/JoinPanel/HBoxContainer/InputIP
@onready var input_port = $Center/MenuPanel/VBoxContainer/JoinPanel/HBoxContainer/InputPort
@onready var host_btn = $Center/MenuPanel/VBoxContainer/HostBtn
@onready var join_btn = $Center/MenuPanel/VBoxContainer/JoinBtn
@onready var connect_btn = $Center/MenuPanel/VBoxContainer/JoinPanel/ConnectBtn
@onready var settings_btn = $Center/MenuPanel/VBoxContainer/SettingsBtn
@onready var quit_btn = $Center/MenuPanel/VBoxContainer/QuitBtn
@onready var status_label = $Center/MenuPanel/VBoxContainer/StatusLabel
@onready var settings_panel = $SettingsPanel
@onready var loading_overlay = $LoadingOverlay
@onready var loading_icon = $LoadingOverlay/LoadingIcon
@onready var progress_label = $LoadingOverlay/ProgressLabel


func _ready():
	host_btn.pressed.connect(_on_host_pressed)
	join_btn.pressed.connect(_on_join_toggle)
	settings_btn.pressed.connect(_on_settings_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)
	connect_btn.pressed.connect(_on_connect_pressed)

	join_panel.visible = false

	if GameManager.return_message:
		status_label.text = GameManager.return_message
		GameManager.return_message = ""


func _start_load_world():
	_loading_world = true
	loading_overlay.visible = true
	loading_icon.pivot_offset = loading_icon.size / 2.0
	progress_label.text = "Loading..."
	_load_tween = create_tween().set_loops()
	_load_tween.tween_property(loading_icon, "rotation", deg_to_rad(-360), 1.0).as_relative()
	var err = ResourceLoader.load_threaded_request("res://world.tscn")
	if err != OK:
		_finish_load_world()


func _finish_load_world():
	if _load_tween:
		_load_tween.kill()
		_load_tween = null
	_loading_world = false
	loading_overlay.visible = false
	get_tree().change_scene_to_file("res://world.tscn")


func _process(delta):
	if not _loading_world:
		return
	var progress = []
	var status = ResourceLoader.load_threaded_get_status("res://world.tscn", progress)
	if progress.size() > 0:
		var pct = progress[0] * 100
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			progress_label.text = "Loading... %d%%" % pct
		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			if pct >= 50.0:
				_finish_load_world()
		elif status == ResourceLoader.THREAD_LOAD_FAILED:
			_finish_load_world()


func _on_host_pressed():
	GameManager.pending_action = GameManager.MenuAction.HOST
	GameManager.pending_name = input_name.text if input_name.text else "Host"
	GameManager.pending_color = color_picker.color
	_start_load_world()


func _on_join_toggle():
	join_panel.visible = not join_panel.visible
	join_btn.text = "CANCEL" if join_panel.visible else "JOIN GAME"


func _on_connect_pressed():
	GameManager.pending_action = GameManager.MenuAction.JOIN
	GameManager.pending_name = input_name.text if input_name.text else "Player"
	GameManager.pending_color = color_picker.color
	GameManager.pending_ip = input_ip.text if input_ip.text else "127.0.0.1"
	GameManager.pending_port = int(input_port.text) if input_port.text.is_valid_int() else GameManager.pending_port
	_start_load_world()


func _on_settings_pressed():
	settings_panel.load_values()
	settings_panel.visible = true


func _on_quit_pressed():
	get_tree().quit()
