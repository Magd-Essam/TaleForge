extends Node

var world          : Node
var selected_token : Node = null
var _hovered_token : Node = null


func _ready():
	world = get_parent()


func _build_token_data(sel) -> Dictionary:
	var d = {
		"token_name": sel.selected_token_data.get("name", "Unknown"),
		"token_type": sel.selected_token_data.get("type", 0),
		"hp": sel.selected_token_data.get("hp", 10),
		"max_hp": sel.selected_token_data.get("max_hp", 10),
		"initiative": sel.selected_token_data.get("initiative", 0),
		"move_speed": sel.selected_token_data.get("move_speed", 30),
		"ac": sel.selected_token_data.get("ac", 10),
		"vision_radius": sel.selected_token_data.get("vision_radius", 0.0),
		"blinded": sel.selected_token_data.get("blinded", false),
		"model_path": sel.selected_token_data.get("model_path", ""),
		"free_placement": false,
		"owner_id": multiplayer.get_unique_id() if multiplayer.multiplayer_peer else -1,
		"cell_x": 0, "cell_y": 0,
		"position_x": 0.0, "position_y": 0.0, "position_z": 0.0,
		"rotation_y": 0.0
	}
	return d


func place_token_at_mouse(mouse_pos: Vector2):
	var result = world.get_world_hit(mouse_pos)
	if not result:
		return

	var sel = world.selection_manager
	var data = _build_token_data(sel)
	var key: String

	if world.snap_enabled:
		var cell_pos = world.world_to_cell(result.position.x, result.position.z)
		key = "token_" + str(cell_pos.x) + "_" + str(cell_pos.y)
		if world.placed_tokens.has(key):
			return
		data["cell_x"] = cell_pos.x
		data["cell_y"] = cell_pos.y
	else:
		var free_cell = world.world_to_cell(result.position.x, result.position.z)
		var base_y = world.get_cell_surface_y(int(free_cell.x), int(free_cell.y))
		if base_y <= 0:
			base_y = world.get_surface_height_at(result.position.x, result.position.z)
		var free_pos = Vector3(result.position.x, base_y, result.position.z)
		for k in world.placed_tokens:
			var other = world.placed_tokens[k]
			if free_pos.distance_to(other.position) < 0.5:
				return
		key = "token_free_" + str(Time.get_ticks_msec())
		data["free_placement"] = true
		data["cell_x"] = int(free_cell.x)
		data["cell_y"] = int(free_cell.y)
		data["position_x"] = free_pos.x
		data["position_y"] = free_pos.y
		data["position_z"] = free_pos.z

	world._sync_place_token(key, data)


func select_token_node(token: Node):
	if selected_token and selected_token != token:
		selected_token.deselect()
	selected_token = token
	if token:
		token.select()

func update_token_hover(mouse_pos: Vector2):
	var token = get_token_at_mouse(mouse_pos)
	if token != _hovered_token:
		if _hovered_token:
			_hovered_token.hide_hover()
		if token:
			token.show_hover()
		_hovered_token = token

func deselect_all():
	if selected_token:
		selected_token.deselect()
	selected_token = null


func get_token_at_mouse(mouse_pos: Vector2) -> Variant:
	var cam        = world.get_node("Camera/Camera3D")
	var ray_origin = cam.project_ray_origin(mouse_pos)
	var ray_end    = ray_origin + cam.project_ray_normal(mouse_pos) * 1000
	var space      = world.get_world_3d().direct_space_state
	var query      = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result     = space.intersect_ray(query)
	if not result:
		return null
	var node = result.collider
	while node != null:
		if node.has_method("place_at_cell"):
			return node
		node = node.get_parent()
	return null


func remove_token_at_cell(cell_pos: Vector2):
	var key = "token_" + str(cell_pos.x) + "_" + str(cell_pos.y)
	if world.placed_tokens.has(key):
		world._sync_remove_token(key)

func _on_token_delete(token: Node):
	if not is_instance_valid(token) or token.is_queued_for_deletion():
		return
	var key_to_remove = ""
	for key in world.placed_tokens:
		if world.placed_tokens[key] == token:
			key_to_remove = key
			break
	if key_to_remove != "":
		world._sync_remove_token(key_to_remove)


func _on_token_edit(token: Node):
	world.token_editor.open_for(token)
