extends Node

var world: Node

var current_floor: int = 0
var max_floor: int = 10
var build_mode: bool = false

signal floor_changed(floor_index: int)
signal build_mode_toggled(active: bool)

func _ready():
	world = get_parent()
	floor_changed.connect(_on_floor_changed)

func _on_floor_changed(_floor: int):
	_apply_floor_filter()

func _apply_floor_filter():
	if not world:
		return
	for key in world.placed_pieces:
		var piece = world.placed_pieces[key]
		if is_instance_valid(piece):
			var pf = world.piece_floors.get(key, 0)
			piece.visible = pf == current_floor
	for key in world.placed_tokens:
		var token = world.placed_tokens[key]
		if is_instance_valid(token):
			var tf = int(token.position.y / 3.0 + 0.5)
			token.visible = tf == current_floor
	for key in world.placed_props:
		var prop = world.placed_props[key]
		if is_instance_valid(prop):
			var pf = int(prop.position.y / 3.0 + 0.5)
			prop.visible = pf == current_floor

func set_floor(floor: int):
	current_floor = clamp(floor, 0, max_floor)
	emit_signal("floor_changed", current_floor)

func next_floor():
	if build_mode:
		set_floor(current_floor + 1)

func prev_floor():
	if build_mode:
		set_floor(current_floor - 1)

func toggle_build_mode():
	build_mode = not build_mode
	emit_signal("build_mode_toggled", build_mode)
