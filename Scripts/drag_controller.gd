extends Node

var world : Node
var dragged_piece : Node   = null
var dragged_key   : String = ""
var is_dragging   : bool   = false
var drag_start_cell : Vector2 = Vector2.ZERO
var _fog_update_accumulator : float = 0.0
var _drag_reachability_markers : Array = []


func _ready():
	world = get_parent()


func _can_drag(token: Node) -> bool:
	if not multiplayer.multiplayer_peer:
		return true
	if multiplayer.is_server():
		return true
	var tracker = world.get_node_or_null("InitiativeTracker")
	if tracker and tracker.is_active:
		var current_key = tracker.get_current_token_key()
		var token_key = world.find_token_key(token)
		if token_key != current_key:
			return false
	if token.owner_id == -1:
		return true
	return token.owner_id == multiplayer.get_unique_id()


func _show_reachable_radius(cell_pos: Vector2, move_speed: float):
	if world.movement_controller and world.movement_controller.movement_grid_visible:
		return
	var max_cells = ceil(move_speed / 5.0)
	for x in range(-max_cells, max_cells + 1):
		for y in range(-max_cells, max_cells + 1):
			if abs(x) + abs(y) > max_cells:
				continue
			if x == 0 and y == 0:
				continue
			var target = cell_pos + Vector2(x, y)
			if target.x < 0 or target.x >= world.grid.grid_size or target.y < 0 or target.y >= world.grid.grid_size:
				continue
			var half_grid = world.grid.cell_size * world.grid.grid_size / 2.0
			var cx = (target.x * world.grid.cell_size) - half_grid + world.grid.cell_size / 2.0
			var cz = (target.y * world.grid.cell_size) - half_grid + world.grid.cell_size / 2.0
			var mesh = MeshInstance3D.new()
			var plane = PlaneMesh.new()
			plane.size = Vector2(world.grid.cell_size * 0.85, world.grid.cell_size * 0.85)
			mesh.mesh = plane
			var mat = StandardMaterial3D.new()
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.render_priority = 1
			var dist = max(abs(target.x - cell_pos.x), abs(target.y - cell_pos.y))
			if dist <= ceil(max_cells / 3.0):
				mat.albedo_color = Color(0.2, 0.8, 0.2, 0.3)
			elif dist <= ceil(max_cells * 2.0 / 3.0):
				mat.albedo_color = Color(0.9, 0.7, 0.1, 0.3)
			else:
				mat.albedo_color = Color(0.9, 0.3, 0.1, 0.3)
			mesh.material_override = mat
			mesh.position = Vector3(cx, 0.06, cz)
			mesh.rotation_degrees = Vector3(-90, 0, 0)
			world.add_child(mesh)
			if not _drag_reachability_markers:
				_drag_reachability_markers = []
			_drag_reachability_markers.append(mesh)

func _clear_reachability_markers():
	if _drag_reachability_markers:
		for m in _drag_reachability_markers:
			if is_instance_valid(m):
				m.queue_free()
		_drag_reachability_markers.clear()

func start_drag(mouse_pos: Vector2):
	var result = world.get_world_hit(mouse_pos)
	if not result:
		world.token_manager.deselect_all()
		return
	var cell_pos = world.world_to_cell(result.position.x, result.position.z)

	# First check: if the ray directly hit a token (body or child), use it
	var hit_token = _find_hit_token(result.collider)
	if hit_token:
		if not _can_drag(hit_token):
			world.token_manager.select_token_node(hit_token)
			return
		dragged_piece   = hit_token
		dragged_key     = world.find_token_key(hit_token)
		drag_start_cell = cell_pos
		is_dragging     = true
		if dragged_piece.has_method("start_grab_animation"):
			dragged_piece.start_grab_animation()
		world.token_manager.select_token_node(hit_token)
		_show_reachable_radius(cell_pos, hit_token.move_speed)
		return

	var closest_token  : Node   = null
	var closest_key    : String = ""
	var closest_dist   : float  = 1.5

	for key in world.placed_tokens:
		var token = world.placed_tokens[key]
		var dist  = Vector2(result.position.x, result.position.z).distance_to(
			Vector2(token.position.x, token.position.z)
		)
		if dist < closest_dist:
			closest_dist  = dist
			closest_token = token
			closest_key   = key

	if closest_token:
		if not _can_drag(closest_token):
			world.token_manager.select_token_node(closest_token)
			return
		dragged_piece   = closest_token
		dragged_key     = closest_key
		drag_start_cell = cell_pos
		is_dragging     = true
		if dragged_piece.has_method("start_grab_animation"):
			dragged_piece.start_grab_animation()
		world.token_manager.select_token_node(closest_token)
		return

	var closest_wall      : Node   = null
	var closest_wall_key  : String = ""
	var closest_wall_dist : float  = world.grid.cell_size * 0.35

	for check_cell in [
		cell_pos,
		cell_pos + Vector2(1,  0),
		cell_pos + Vector2(-1, 0),
		cell_pos + Vector2(0,  1),
		cell_pos + Vector2(0, -1),
	]:
		for dir in ["N", "S", "E", "W"]:
			var wall_key = str(check_cell.x) + "_" + str(check_cell.y) + "_" + dir
			if world.placed_pieces.has(wall_key):
				var wall = world.placed_pieces[wall_key]
				var dist = Vector2(result.position.x, result.position.z).distance_to(
					Vector2(wall.position.x, wall.position.z)
				)
				if dist < closest_wall_dist:
					closest_wall_dist = dist
					closest_wall      = wall
					closest_wall_key  = wall_key

	if closest_wall:
		dragged_piece = closest_wall
		dragged_key   = closest_wall_key
		is_dragging   = true
		dragged_piece.position.y += 0.3
		return

	var floor_key = "floor_" + str(cell_pos.x) + "_" + str(cell_pos.y)
	if world.placed_pieces.has(floor_key):
		dragged_piece = world.placed_pieces[floor_key]
		dragged_key   = floor_key
		is_dragging   = true
		dragged_piece.position.y += 0.3
		return

	# Check if the raycast directly hit a prop (by collider)
	var hit_prop = _find_hit_prop(result.collider)
	if hit_prop:
		var hit_key = world.find_prop_key(hit_prop)
		if hit_key != "":
			world.selection_manager.select_prop_node(hit_prop)
			dragged_piece = hit_prop
			dragged_key   = hit_key
			is_dragging   = true
			dragged_piece.position.y += 0.3
			return

	# Fallback: find topmost prop at the clicked cell
	var base_prop_prefix = "prop_" + str(cell_pos.x) + "_" + str(cell_pos.y)
	var top_prop  : Node = null
	var top_key   : String = ""
	var top_y     : float = -9999.0
	for pk in world.placed_props:
		if pk == base_prop_prefix or pk.begins_with(base_prop_prefix + "_"):
			var prop = world.placed_props[pk]
			if prop.position.y > top_y:
				top_y = prop.position.y
				top_prop = prop
				top_key = pk
	if top_prop:
		world.selection_manager.select_prop_node(top_prop)
		dragged_piece = top_prop
		dragged_key   = top_key
		is_dragging   = true
		dragged_piece.position.y += 0.3
		return

	world.selection_manager.deselect_prop()
	world.token_manager.deselect_all()


func _find_hit_token(collider: Node) -> Node:
	var node = collider
	while node:
		if node.has_method("place_at_cell"):
			return node
		node = node.get_parent()
	return null

func _find_hit_prop(collider: Node) -> Node:
	var node = collider
	while node:
		if node.get("piece_type") == "prop":
			return node
		node = node.get_parent()
	return null


func preview_drag(mouse_pos: Vector2):
	var exclude_rid: RID
	if dragged_piece is PhysicsBody3D:
		exclude_rid = dragged_piece.get_rid()
	var result = world.get_world_hit(mouse_pos, exclude_rid)
	if not result or not dragged_piece:
		return

	if dragged_key.begins_with("token_"):
		var exclude = [exclude_rid] if exclude_rid.is_valid() else []
		var surface_y = world.get_surface_height_at(result.position.x, result.position.z, exclude)
		var target = Vector3(result.position.x, surface_y + 0.1, result.position.z)
		dragged_piece.set_drag_target(target)
		var current_cell = world.world_to_cell(result.position.x, result.position.z)
		dragged_piece.show_distance(drag_start_cell, current_cell)
		if dragged_piece.token_type == 0:
			var now = Time.get_ticks_msec()
			if now - _fog_update_accumulator > 50:
				_fog_update_accumulator = now
				world.update_fog_with_preview(result.position)
	else:
		if world.snap_enabled:
			var cell = world.world_to_cell(result.position.x, result.position.z)
			var cs = world.grid.cell_size
			var gs = world.grid.grid_size
			var half = cs * gs / 2.0
			dragged_piece.position.x = (cell.x * cs) - half + cs / 2.0
			dragged_piece.position.z = (cell.y * cs) - half + cs / 2.0
		else:
			dragged_piece.position.x = result.position.x
			dragged_piece.position.z = result.position.z


func finish_drag(mouse_pos: Vector2):
	if not dragged_piece:
		is_dragging = false
		return

	# Exclude the dragged piece from the release raycast too
	var exclude_rid: RID
	if dragged_piece is PhysicsBody3D:
		exclude_rid = dragged_piece.get_rid()
	var result = world.get_world_hit(mouse_pos, exclude_rid)
	if not result:
		cancel_drag()
		return

	if dragged_key.begins_with("token_"):
		_do_finish_token_drag(result)
		return

	if dragged_key.begins_with("prop_"):
		_do_finish_prop_drag(result)
		return

	_do_finish_piece_drag(result)


func _do_finish_token_drag(result: Dictionary):
	if dragged_piece.has_method("start_drop_animation"):
		dragged_piece.start_drop_animation()
	dragged_piece.stop_drag()
	dragged_piece.hide_distance()
	var exclude_rid_token: RID
	if dragged_piece is PhysicsBody3D:
		exclude_rid_token = dragged_piece.get_rid()
	var exclude_arr = [exclude_rid_token] if exclude_rid_token.is_valid() else []
	world.placed_tokens.erase(dragged_key)

	var data = dragged_piece.serialize()
	var new_key: String

	if not world.snap_enabled:
		new_key = "token_free_" + str(Time.get_ticks_msec())
		var drop_cell = world.world_to_cell(result.position.x, result.position.z)
		var base_y = world.get_cell_surface_y(int(drop_cell.x), int(drop_cell.y))
		if base_y <= 0:
			base_y = world.get_surface_height_at(result.position.x, result.position.z, exclude_arr)
		dragged_piece.set_terrain_height(base_y)
		dragged_piece.position.x = result.position.x
		dragged_piece.position.z = result.position.z
		dragged_piece.call_deferred("fix_floor_position")
		data["free_placement"] = true
		data["cell_x"] = int(drop_cell.x)
		data["cell_y"] = int(drop_cell.y)
		data["position_x"] = dragged_piece.position.x
		data["position_y"] = dragged_piece.position.y
		data["position_z"] = dragged_piece.position.z
	else:
		var new_cell = world.world_to_cell(result.position.x, result.position.z)
		new_key = "token_" + str(new_cell.x) + "_" + str(new_cell.y)
		if world.placed_tokens.has(new_key):
			cancel_drag()
			return
		dragged_piece.place_at_cell(new_cell, world.grid.cell_size, world.grid.grid_size)
		var base_y = world.get_cell_surface_y(int(new_cell.x), int(new_cell.y))
		dragged_piece.set_terrain_height(base_y)
		data["cell_x"] = int(new_cell.x)
		data["cell_y"] = int(new_cell.y)

	world.placed_tokens[new_key] = dragged_piece

	var mp = multiplayer.multiplayer_peer
	if mp and not multiplayer.is_server():
		world.rpc_id(1, "request_move_token", dragged_key, new_key, data)
	else:
		world._sync_move_token(dragged_key, new_key, data)

	_reset()
	world.update_fog()
	world.token_manager.deselect_all()


func _do_finish_prop_drag(result: Dictionary):
	world.placed_props.erase(dragged_key)
	var new_cell = world.world_to_cell(result.position.x, result.position.z)
	var base_key = "prop_" + str(new_cell.x) + "_" + str(new_cell.y)
	var new_key  = base_key
	var n = 0
	while world.placed_props.has(new_key):
		n += 1
		new_key = base_key + "_" + str(n)
	var exclude_rid: RID
	if dragged_piece is PhysicsBody3D:
		exclude_rid = dragged_piece.get_rid()
	var surface_y = world.get_surface_height_at(result.position.x, result.position.z, [exclude_rid] if exclude_rid.is_valid() else [])
	var final_pos: Vector3
	if world.snap_enabled:
		var cs = world.grid.cell_size
		var gs = world.grid.grid_size
		var half = cs * gs / 2.0
		final_pos = Vector3(
			(new_cell.x * cs) - half + cs / 2.0,
			max(surface_y, 0.0),
			(new_cell.y * cs) - half + cs / 2.0
		)
	else:
		final_pos = Vector3(result.position.x, max(surface_y, 0.0), result.position.z)
	dragged_piece.position = final_pos
	world._sync_move_prop(dragged_key, new_key, final_pos.x, final_pos.y, final_pos.z)
	world.placed_props[new_key] = dragged_piece
	_reset()
	world.update_fog()


func _do_finish_piece_drag(result: Dictionary):
	var cell_pos = world.world_to_cell(result.position.x, result.position.z)
	var old_cell_pos = Vector2.ZERO
	if dragged_key.begins_with("floor_"):
		var old_parts = dragged_key.split("_")
		if old_parts.size() >= 3:
			old_cell_pos = Vector2(float(old_parts[1]), float(old_parts[2]))
	world.placed_pieces.erase(dragged_key)
	world.tile_grid.erase(dragged_key)

	if dragged_piece.piece_type == "wall":
		var dir     = world.get_closest_edge(result.position.x, result.position.z, cell_pos)
		var new_key = str(cell_pos.x) + "_" + str(cell_pos.y) + "_" + dir
		if world.placed_pieces.has(new_key):
			cancel_drag()
			return
		dragged_piece.init(cell_pos, dir, world.grid.cell_size, world.grid.grid_size)
		dragged_piece.position.y += world._get_stack_height_at(cell_pos)
		world._sync_move_piece(dragged_key, new_key, int(cell_pos.x), int(cell_pos.y), dir)
		world.placed_pieces[new_key] = dragged_piece
	else:
		var new_key = "floor_" + str(cell_pos.x) + "_" + str(cell_pos.y)
		if world.placed_pieces.has(new_key):
			cancel_drag()
			return
		dragged_piece.init(cell_pos, world.grid.cell_size, world.grid.grid_size)
		dragged_piece.position.y += world._get_stack_height_at(cell_pos)
		world._sync_move_piece(dragged_key, new_key, int(cell_pos.x), int(cell_pos.y), "")
		world.placed_pieces[new_key] = dragged_piece
		world.tile_grid[new_key] = dragged_piece
		if world.tile_fusion and old_cell_pos != Vector2.ZERO:
			world.tile_fusion.on_tile_moved(dragged_piece, old_cell_pos, cell_pos)

	_reset()
	world.update_fog()


func cancel_drag():
	if not dragged_piece:
		_reset()
		return

	if dragged_key.begins_with("token_"):
		var data = dragged_piece.serialize()
		if dragged_piece.has_method("start_drop_animation"):
			dragged_piece.start_drop_animation()
		dragged_piece.stop_drag()
		dragged_piece.hide_distance()
		if dragged_piece.free_placement:
			world.placed_tokens[dragged_key] = dragged_piece
		else:
			var parts    = dragged_key.split("_")
			var cell_pos = Vector2(float(parts[1]), float(parts[2]))
			dragged_piece.place_at_cell(cell_pos, world.grid.cell_size, world.grid.grid_size)
			world.placed_tokens[dragged_key] = dragged_piece
		world._sync_move_token("", dragged_key, data)
		_reset()
		world.token_manager.deselect_all()
		return

	if dragged_key.begins_with("prop_"):
		world.placed_props[dragged_key] = dragged_piece
		_reset()
		return

	if dragged_piece.piece_type == "wall":
		var parts    = dragged_key.split("_")
		var cell_pos = Vector2(float(parts[0]), float(parts[1]))
		var dir      = parts[2]
		dragged_piece.init(cell_pos, dir, world.grid.cell_size, world.grid.grid_size)
		dragged_piece.position.y += world._get_stack_height_at(cell_pos)
	else:
		var parts    = dragged_key.split("_")
		var cell_pos = Vector2(float(parts[1]), float(parts[2]))
		dragged_piece.init(cell_pos, world.grid.cell_size, world.grid.grid_size)
		dragged_piece.position.y += world._get_stack_height_at(cell_pos)

	world.placed_pieces[dragged_key] = dragged_piece
	_reset()


func _reset():
	_clear_reachability_markers()
	dragged_piece = null
	dragged_key   = ""
	is_dragging   = false
