extends Node

var world        : Node
var hovered_piece : Node = null


func _ready():
	world = get_parent()


func place_wall_at_mouse(mouse_pos: Vector2):
	var result = world.get_world_hit(mouse_pos)
	if not result:
		return
	var cell_pos = world.world_to_cell(result.position.x, result.position.z)
	var dir      = world.get_closest_edge(result.position.x, result.position.z, cell_pos)
	var key      = str(cell_pos.x) + "_" + str(cell_pos.y) + "_" + dir
	if world.placed_pieces.has(key):
		return

	var sel = world.selection_manager
	var model_path = ""
	if sel.selected_piece == "wall_custom" and sel.selected_custom_path != "":
		model_path = sel.selected_custom_path

	var fm = world.floor_manager
	var place_floor = fm.current_floor if (fm and fm.build_mode) else 0
	world._sync_place_piece(key, "wall", int(cell_pos.x), int(cell_pos.y), dir, model_path, place_floor)


func place_floor_at_mouse(mouse_pos: Vector2):
	var result = world.get_world_hit(mouse_pos)
	if not result:
		return
	var cell_pos = world.world_to_cell(result.position.x, result.position.z)
	var key      = "floor_" + str(cell_pos.x) + "_" + str(cell_pos.y)

	var sel = world.selection_manager
	var type_name = sel.selected_piece
	var model_path = ""
	if type_name == "floor_custom" and sel.selected_custom_path != "":
		model_path = sel.selected_custom_path
	elif not world.pieces.has(type_name):
		return

	var fm = world.floor_manager
	var place_floor = fm.current_floor if (fm and fm.build_mode) else 0
	world._sync_place_piece(key, type_name, int(cell_pos.x), int(cell_pos.y), "", model_path, place_floor)


func remove_at_mouse(mouse_pos: Vector2):
	var result = world.get_world_hit(mouse_pos)
	if not result:
		return
	var cell_pos  = world.world_to_cell(result.position.x, result.position.z)
	var floor_key = "floor_" + str(cell_pos.x) + "_" + str(cell_pos.y)
	if world.placed_pieces.has(floor_key):
		world._sync_remove_piece(floor_key)
	for dir in ["N", "S", "E", "W"]:
		var wall_key = str(cell_pos.x) + "_" + str(cell_pos.y) + "_" + dir
		if world.placed_pieces.has(wall_key):
			world._sync_remove_piece(wall_key)
	var base_prop_prefix = "prop_" + str(cell_pos.x) + "_" + str(cell_pos.y)
	var top_prop_key = ""
	var top_y = -9999.0
	for pk in world.placed_props:
		if pk == base_prop_prefix or pk.begins_with(base_prop_prefix + "_"):
			if world.placed_props[pk].position.y > top_y:
				top_y = world.placed_props[pk].position.y
				top_prop_key = pk
	if top_prop_key != "":
		world._sync_remove_prop(top_prop_key)


func update_hover(mouse_pos: Vector2):
	var result    = world.get_world_hit(mouse_pos)
	var new_hover : Node = null

	if result:
		var cell_pos  = world.world_to_cell(result.position.x, result.position.z)
		var floor_key = "floor_" + str(cell_pos.x) + "_" + str(cell_pos.y)
		if world.placed_pieces.has(floor_key):
			new_hover = world.placed_pieces[floor_key]

		if new_hover == null:
			var dir      = world.get_closest_edge(result.position.x, result.position.z, cell_pos)
			var wall_key = str(cell_pos.x) + "_" + str(cell_pos.y) + "_" + dir
			if world.placed_pieces.has(wall_key):
				new_hover = world.placed_pieces[wall_key]

	if new_hover != hovered_piece:
		if hovered_piece:
			hovered_piece.hide_outline()
		if new_hover:
			new_hover.show_outline()
		hovered_piece = new_hover


func _on_wall_cycle(wall: Node):
	wall.cycle_type()
	world.update_fog()
