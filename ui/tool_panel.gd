extends Control

var world: Node3D

var _ruler_btn: Button
var _aoe_activate: Button
var _aoe_shape_btns: Dictionary = {}
var _aoe_mode_btns: Dictionary = {}


func _ready():
	world = get_parent().get_parent()
	position = Vector2(get_viewport().size.x - 230, 10)
	build_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)


func _on_viewport_resized():
	position = Vector2(get_viewport().size.x - 230, 10)


func build_ui():
	build_ruler_section()
	build_aoe_section()


func build_ruler_section():
	var label = Label.new()
	label.text = "📏 Ruler"
	label.position = Vector2(8, 0)
	label.size = Vector2(204, 24)
	add_child(label)

	_ruler_btn = Button.new()
	_ruler_btn.text = "Ruler ON/OFF"
	_ruler_btn.position = Vector2(8, 26)
	_ruler_btn.size = Vector2(204, 30)
	_ruler_btn.pressed.connect(_on_ruler_pressed)
	add_child(_ruler_btn)


func build_aoe_section():
	var ay = 70

	var label = Label.new()
	label.text = "🎯 AoE Templates"
	label.position = Vector2(8, ay)
	label.size = Vector2(204, 24)
	add_child(label)
	ay += 28

	_aoe_activate = Button.new()
	_aoe_activate.text = "AoE OFF"
	_aoe_activate.position = Vector2(8, ay)
	_aoe_activate.size = Vector2(204, 30)
	_aoe_activate.pressed.connect(_on_aoe_toggle)
	add_child(_aoe_activate)
	ay += 34

	var shape_names = ["◉ Sphere", "△ Cone", "▤ Line", "▣ Cube"]
	var shape_keys = ["sphere", "cone", "line", "cube"]
	var sx = 8
	for i in range(shape_names.size()):
		var btn = Button.new()
		btn.text = shape_names[i]
		btn.position = Vector2(sx, ay)
		btn.size = Vector2(48, 30)
		var sk = shape_keys[i]
		btn.pressed.connect(func(): _on_aoe_shape(sk))
		add_child(btn)
		_aoe_shape_btns[sk] = btn
		sx += 52
	ay += 34

	_aoe_mode_btns["place"] = Button.new()
	_aoe_mode_btns["place"].text = "＋ Place"
	_aoe_mode_btns["place"].position = Vector2(8, ay)
	_aoe_mode_btns["place"].size = Vector2(98, 30)
	_aoe_mode_btns["place"].pressed.connect(func(): _on_aoe_mode("place"))
	add_child(_aoe_mode_btns["place"])

	_aoe_mode_btns["delete"] = Button.new()
	_aoe_mode_btns["delete"].text = "✖ Delete"
	_aoe_mode_btns["delete"].position = Vector2(114, ay)
	_aoe_mode_btns["delete"].size = Vector2(98, 30)
	_aoe_mode_btns["delete"].pressed.connect(func(): _on_aoe_mode("delete"))
	add_child(_aoe_mode_btns["delete"])

	ay += 34

	size = Vector2(220, ay)

	var am = _get_aoe()
	if am:
		_refresh_aoe_ui(false, AoeManager.AoeShape.SPHERE, AoeManager.AoeMode.PLACE)


func _get_aoe():
	return world.get_node_or_null("AoeManager")


func _on_ruler_pressed():
	if world.has_method("set_tool_ruler"):
		world.set_tool_ruler()


func _on_aoe_toggle():
	var am = _get_aoe()
	if am:
		am.toggle_active()


func _on_aoe_shape(shape_key: String):
	var am = _get_aoe()
	if not am:
		return
	var map = {"sphere": AoeManager.AoeShape.SPHERE, "cone": AoeManager.AoeShape.CONE, "line": AoeManager.AoeShape.LINE, "cube": AoeManager.AoeShape.CUBE}
	if map.has(shape_key):
		am.set_shape(map[shape_key])


func _on_aoe_mode(mode_key: String):
	var am = _get_aoe()
	if not am:
		return
	var map = {"place": AoeManager.AoeMode.PLACE, "delete": AoeManager.AoeMode.DELETE}
	if map.has(mode_key):
		am.set_mode(map[mode_key])


func _on_aoe_mode_changed(active: bool, shape: int, mode: int):
	_refresh_aoe_ui(active, shape, mode)


func _refresh_aoe_ui(active: bool, shape: int, mode: int):
	if _aoe_activate:
		_aoe_activate.text = "🎯 AoE " + ("ON" if active else "OFF")

	var shape_map = {AoeManager.AoeShape.SPHERE: "sphere", AoeManager.AoeShape.CONE: "cone", AoeManager.AoeShape.LINE: "line", AoeManager.AoeShape.CUBE: "cube"}
	for key in _aoe_shape_btns:
		var btn = _aoe_shape_btns[key]
		btn.modulate = Color(1, 1, 1) if key == shape_map[shape] else Color(0.55, 0.55, 0.55)

	var mode_map = {AoeManager.AoeMode.PLACE: "place", AoeManager.AoeMode.DELETE: "delete"}
	for key in _aoe_mode_btns:
		var btn = _aoe_mode_btns[key]
		btn.modulate = Color(1, 1, 1) if key == mode_map[mode] else Color(0.55, 0.55, 0.55)
