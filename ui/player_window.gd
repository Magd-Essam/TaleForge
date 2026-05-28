extends Control

var world: Node3D
var _selected_token: Node = null
var _aoe_shape_btns: Dictionary = {}
var _aoe_mode_btns: Dictionary = {}

@onready var ruler_btn = $RulerBtn
@onready var pointer_btn = $PointerBtn
@onready var aoe_activate = $AoeActivate
@onready var sheet_container = $SheetContainer
@onready var sheet_name = $SheetContainer/ValueName
@onready var sheet_hp = $SheetContainer/ValueHP
@onready var sheet_ac = $SheetContainer/ValueAC
@onready var sheet_speed = $SheetContainer/ValueSpeed
@onready var sheet_init = $SheetContainer/ValueInit
@onready var sheet_blinded = $SheetContainer/ValueBlinded


func _ready():
	world = get_parent().get_parent()

	$MoveBtn.pressed.connect(func(): world.set_tool_move())
	ruler_btn.pressed.connect(_on_ruler_pressed)
	pointer_btn.pressed.connect(_on_pointer_pressed)
	aoe_activate.pressed.connect(_on_aoe_toggle)

	_aoe_shape_btns = {
		"sphere": $AoeShapeSphere,
		"cone": $AoeShapeCone,
		"line": $AoeShapeLine,
		"cube": $AoeShapeCube,
	}
	_aoe_shape_btns["sphere"].pressed.connect(func(): _on_aoe_shape("sphere"))
	_aoe_shape_btns["cone"].pressed.connect(func(): _on_aoe_shape("cone"))
	_aoe_shape_btns["line"].pressed.connect(func(): _on_aoe_shape("line"))
	_aoe_shape_btns["cube"].pressed.connect(func(): _on_aoe_shape("cube"))

	_aoe_mode_btns = {
		"place": $AoeModePlace,
		"delete": $AoeModeDelete,
	}
	_aoe_mode_btns["place"].pressed.connect(func(): _on_aoe_mode("place"))
	_aoe_mode_btns["delete"].pressed.connect(func(): _on_aoe_mode("delete"))
	$AoeClearAll.pressed.connect(_on_aoe_clear_all)

	_refresh_sheet_position()
	_refresh_aoe_ui(false, 0, 0)


func _process(_delta):
	var tok = world.token_manager.selected_token
	if tok != _selected_token:
		_selected_token = tok
		_update_sheet()


func _update_sheet():
	var tok = _selected_token
	if tok and is_instance_valid(tok):
		sheet_name.text = tok.token_name
		sheet_hp.text = str(tok.hp) + " / " + str(tok.max_hp)
		sheet_ac.text = str(tok.ac)
		sheet_speed.text = str(tok.move_speed) + " ft"
		sheet_init.text = "#" + str(tok.initiative)
		sheet_blinded.text = "Yes" if tok.blinded else "No"
		sheet_container.visible = true
	else:
		sheet_container.visible = false
	_refresh_sheet_position()


func _refresh_sheet_position():
	if sheet_container:
		sheet_container.position.y = size.y + 6


func _get_aoe():
	return world.get_node_or_null("AoeManager")


func _on_ruler_pressed():
	if world.has_method("set_tool_ruler"):
		world.set_tool_ruler()


func _on_pointer_pressed():
	if world.has_method("toggle_point_indicator"):
		world.toggle_point_indicator()
		var pi = world.point_indicator
		pointer_btn.text = "Pointer ON" if pi and pi.local_active else "Pointer OFF"


func _on_aoe_toggle():
	var am = _get_aoe()
	if am:
		am.toggle_active()


func _on_aoe_shape(shape_key: String):
	var am = _get_aoe()
	if not am:
		return
	var map = {"sphere": 0, "cone": 1, "line": 2, "cube": 3}
	if map.has(shape_key):
		am.set_shape(map[shape_key])


func _on_aoe_mode(mode_key: String):
	var am = _get_aoe()
	if not am:
		return
	var map = {"place": 0, "delete": 1}
	if map.has(mode_key):
		am.set_mode(map[mode_key])


func _on_aoe_clear_all():
	var am = _get_aoe()
	if am:
		am.clear_all_aoes()


func _on_aoe_mode_changed(active: bool, shape: int, mode: int):
	_refresh_aoe_ui(active, shape, mode)


func _refresh_aoe_ui(active: bool, shape: int, mode: int):
	if aoe_activate:
		aoe_activate.text = "AoE " + ("ON" if active else "OFF")

	var shape_keys = ["sphere", "cone", "line", "cube"]
	for i in range(shape_keys.size()):
		var key = shape_keys[i]
		if _aoe_shape_btns.has(key):
			_aoe_shape_btns[key].modulate = Color(1, 1, 1) if i == shape else Color(0.55, 0.55, 0.55)

	var mode_keys = ["place", "delete"]
	for i in range(mode_keys.size()):
		var key = mode_keys[i]
		if _aoe_mode_btns.has(key):
			_aoe_mode_btns[key].modulate = Color(1, 1, 1) if i == mode else Color(0.55, 0.55, 0.55)
