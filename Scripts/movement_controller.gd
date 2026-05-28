extends Node

var world: Node

var movement_grid_visible: bool = false
var path_preview: Node3D = null
var selected_path: Array = []

var movement_grid: Node = null

signal movement_toggled(visible: bool)

func _ready():
	world = get_parent()

func toggle_movement_grid():
	movement_grid_visible = not movement_grid_visible
	if movement_grid_visible:
		_show_movement_grid()
	else:
		_hide_movement_grid()
	emit_signal("movement_toggled", movement_grid_visible)

func _show_movement_grid():
	var token = world.token_manager.selected_token
	if not token:
		return
	if not movement_grid:
		movement_grid = preload("res://Scripts/movement_grid.gd").new()
		movement_grid.world = world
		add_child(movement_grid)
	var reachable = _compute_reachable_cells(token)
	movement_grid.show_grid(reachable, token)

func _hide_movement_grid():
	if movement_grid and movement_grid.has_method("hide_grid"):
		movement_grid.hide_grid()
	movement_grid_visible = false

func _compute_reachable_cells(token: Node) -> Array:
	var cell = token.grid_position
	var speed = token.get("move_speed")
	var max_cells = ceil(speed / 5.0)
	var reachable = []
	for x in range(-max_cells, max_cells + 1):
		for y in range(-max_cells, max_cells + 1):
			if abs(x) + abs(y) <= max_cells:
				reachable.append(cell + Vector2(x, y))
	return reachable

func find_path(from_cell: Vector2, to_cell: Vector2) -> Array:
	var open_set = [from_cell]
	var came_from = {}
	var g_score = {from_cell: 0}
	var f_score = {from_cell: _heuristic(from_cell, to_cell)}
	while open_set.size() > 0:
		var current = _lowest_f(open_set, f_score)
		if current == to_cell:
			return _reconstruct_path(came_from, current)
		open_set.erase(current)
		for neighbor in _get_neighbors(current):
			var tentative_g = g_score.get(current, 99999) + 1
			if tentative_g < g_score.get(neighbor, 99999):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + _heuristic(neighbor, to_cell)
				if not neighbor in open_set:
					open_set.append(neighbor)
	return []

func _lowest_f(set: Array, f: Dictionary) -> Vector2:
	var best = set[0]
	var best_f = f.get(best, 99999)
	for item in set:
		var f_val = f.get(item, 99999)
		if f_val < best_f:
			best = item
			best_f = f_val
	return best

func _heuristic(a: Vector2, b: Vector2) -> float:
	return abs(a.x - b.x) + abs(a.y - b.y)

func _get_neighbors(cell: Vector2) -> Array:
	var dirs = [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]
	var result = []
	for d in dirs:
		var n = cell + d
		if n.x >= 0 and n.x < world.grid.grid_size and n.y >= 0 and n.y < world.grid.grid_size:
			result.append(n)
	return result

func _reconstruct_path(came_from: Dictionary, current: Vector2) -> Array:
	var path = [current]
	while came_from.has(current):
		current = came_from[current]
		path.append(current)
	path.reverse()
	return path

func show_path_preview(path: Array):
	_clear_path_preview()
	path_preview = Node3D.new()
	world.add_child(path_preview)
	for i in range(path.size() - 1):
		var a = _cell_to_world(path[i])
		var b = _cell_to_world(path[i + 1])
		var dist = a.distance_to(b)
		if dist < 0.01:
			continue
		var mid = (a + b) / 2.0
		var arrow = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.05, 0.01, dist)
		arrow.mesh = box
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.8, 0.2, 0.6)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		arrow.material_override = mat
		arrow.position = mid
		arrow.position.y = 0.1
		arrow.look_at(b, Vector3.UP)
		path_preview.add_child(arrow)

func _clear_path_preview():
	if path_preview:
		path_preview.queue_free()
		path_preview = null

func _cell_to_world(cell: Vector2) -> Vector3:
	var half_grid = world.grid.cell_size * world.grid.grid_size / 2.0
	var cx = (cell.x * world.grid.cell_size) - half_grid + world.grid.cell_size / 2.0
	var cz = (cell.y * world.grid.cell_size) - half_grid + world.grid.cell_size / 2.0
	return Vector3(cx, 0, cz)

func move_token_along_path(token: Node, path: Array):
	if path.size() < 2:
		return
	var key = world.find_token_key(token)
	if key == "":
		return
	var target_cell = path[-1]
	var data = token.serialize()
	var new_key = "token_" + str(int(target_cell.x)) + "_" + str(int(target_cell.y))
	if world.placed_tokens.has(new_key) and new_key != key:
		return
	token.show_distance(token.grid_position, target_cell)
	world._sync_move_token(key, new_key, data)
