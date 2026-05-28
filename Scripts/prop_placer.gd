extends Node

var world : Node
var free_form_mode: bool = false
var rotation_snap: float = 15.0

func _ready():
	world = get_parent()

func place_prop_at_mouse(mouse_pos: Vector2):
	var result = world.get_world_hit(mouse_pos)
	if not result:
		return

	var sel = world.selection_manager
	if not sel.selected_prop_data:
		return

	var cell_pos = world.world_to_cell(result.position.x, result.position.z)

	if free_form_mode:
		var key = "prop_free_" + str(Time.get_ticks_msec())
		var data = sel.selected_prop_data.duplicate()
		var base_y = world.get_cell_surface_y(int(cell_pos.x), int(cell_pos.y))
		if base_y <= 0:
			base_y = world.get_surface_height_at(result.position.x, result.position.z)
		data["free_placement"] = true
		data["position_x"] = result.position.x
		data["position_y"] = base_y
		data["position_z"] = result.position.z
		world._sync_place_prop(key, data, int(cell_pos.x), int(cell_pos.y))
	else:
		var base_key = "prop_" + str(cell_pos.x) + "_" + str(cell_pos.y)
		var key = base_key
		var n = 0
		while world.placed_props.has(key):
			n += 1
			key = base_key + "_" + str(n)
		# sync_place_prop computes the surface Y from game state, so we just
		# pass the cell position and let it handle stacking height.
		var data = sel.selected_prop_data.duplicate()
		world._sync_place_prop(key, data, int(cell_pos.x), int(cell_pos.y))

func toggle_free_form():
	free_form_mode = not free_form_mode

func get_rotation_snap() -> float:
	return rotation_snap

func snap_rotation(degrees: float) -> float:
	return round(degrees / rotation_snap) * rotation_snap
