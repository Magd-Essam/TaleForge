extends Control

signal on_edit(token)
signal on_delete(token)

var target_token = null

signal on_cycle_wall(piece)

@onready var btn_cycle_wall = $BtnCycleWall
@onready var btn_edit = $BtnEdit
@onready var btn_delete = $BtnDelete
@onready var btn_conditions = $BtnConditions
@onready var popup_conditions = $PopupConditions
@onready var label_size = $LabelSize
@onready var slider_size = $SliderSize


func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	btn_edit.pressed.connect(_on_edit)
	btn_delete.pressed.connect(_on_delete)
	btn_conditions.pressed.connect(_on_conditions)
	popup_conditions.index_pressed.connect(_on_conditions_index)
	slider_size.value_changed.connect(_on_size_changed)

	btn_cycle_wall.pressed.connect(_on_cycle_wall)


func show_at(pos: Vector2, target):
	target_token = target
	
	var is_gm = not multiplayer.multiplayer_peer or multiplayer.is_server()
	
	var is_wall = target.get("piece_type") == "wall"
	btn_cycle_wall.visible = is_wall
	btn_edit.visible = not is_wall and is_gm
	btn_delete.visible = is_gm

	btn_conditions.visible = is_gm and target.has_method("toggle_condition")

	if is_wall:
		var type_names = ["Wall", "Door (closed)", "Door (open)", "Window"]
		btn_cycle_wall.text = type_names[target.wall_type] + " → next"
	
	if target.has_method("apply_scale"):
		slider_size.value = snappedf(target.scale_multiplier, 0.1)
		label_size.text = "Size: " + str(slider_size.value)
	
	position = pos
	visible = true
	var screen_size = get_viewport().get_visible_rect().size
	if position.x + 180 > screen_size.x:
		position.x = screen_size.x - 185
	if position.y + 178 > screen_size.y:
		position.y = screen_size.y - 183

func _on_conditions():
	if not target_token or not target_token.has_method("toggle_condition"):
		return
	popup_conditions.clear()
	var idx = 0
	for cname in target_token.CONDITION_NAMES:
		var is_active = target_token.conditions.has(cname)
		popup_conditions.add_check_item(cname, idx)
		popup_conditions.set_item_checked(idx, is_active)
		idx += 1
	popup_conditions.reset_size()
	var global_pos = get_global_mouse_position()
	popup_conditions.popup(Rect2i(global_pos.x, global_pos.y, 200, 0))

func _on_conditions_index(index: int):
	if not target_token or not target_token.has_method("toggle_condition"):
		return
	var name = target_token.CONDITION_NAMES[index]
	target_token.toggle_condition(name)
	var world = get_parent().get_parent()
	var key = world.find_token_key(target_token)
	if key != "":
		world._sync_update_token_field(key, "conditions", target_token.conditions)

func _on_cycle_wall():
	emit_signal("on_cycle_wall", target_token)
	hide_menu()
func hide_menu():
	visible = false
	popup_conditions.hide()
	target_token = null

func _on_edit():
	emit_signal("on_edit", target_token)
	hide_menu()

func _on_delete():
	emit_signal("on_delete", target_token)
	hide_menu()

func _on_size_changed(value):
	label_size.text = "Size: " + str(snappedf(value, 0.1))
	if not target_token or not target_token.has_method("apply_scale"):
		return
	target_token.apply_scale(value)
	var w = get_parent().get_parent()
	if target_token.get("piece_type") == "prop":
		var key = w.find_prop_key(target_token)
		if key != "":
			w._sync_scale_prop(key, value)
	else:
		var key = w.find_token_key(target_token)
		if key != "":
			w._sync_update_token_field(key, "scale_multiplier", value)

func _input(event):
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()):
				hide_menu()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			hide_menu()
