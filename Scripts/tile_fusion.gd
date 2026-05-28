extends Node

var world: Node

func _ready():
	world = get_parent()

func on_tile_placed(tile: Node, cell_pos: Vector2):
	if not tile or not tile.has_method("get_tile_type"):
		return
	_check_neighbors(tile, cell_pos)

func on_tile_moved(tile: Node, old_cell: Vector2, new_cell: Vector2):
	_restore_edges_for_cell(old_cell)
	on_tile_placed(tile, new_cell)

func on_tile_removed(cell_pos: Vector2):
	_restore_edges_for_cell(cell_pos)
	for dir in ["N", "S", "E", "W"]:
		var neighbor_cell = _neighbor_cell(cell_pos, dir)
		var neighbor = _get_tile_at(neighbor_cell)
		if neighbor and neighbor.has_method("set_edge_visible"):
			_neighbor_check(neighbor, neighbor_cell)

func _check_neighbors(tile: Node, cell_pos: Vector2):
	for dir in ["N", "S", "E", "W"]:
		var neighbor_cell = _neighbor_cell(cell_pos, dir)
		var neighbor = _get_tile_at(neighbor_cell)
		if neighbor and neighbor.has_method("get_tile_type") and neighbor.get_tile_type() == tile.get_tile_type():
			var opposite = _opposite_dir(dir)
			tile.set_edge_visible(dir, false)
			neighbor.set_edge_visible(opposite, false)

func _neighbor_check(tile: Node, cell_pos: Vector2):
	for dir in ["N", "S", "E", "W"]:
		var neighbor_cell = _neighbor_cell(cell_pos, dir)
		var neighbor = _get_tile_at(neighbor_cell)
		if neighbor and neighbor.has_method("get_tile_type") and neighbor.get_tile_type() == tile.get_tile_type():
			var opposite = _opposite_dir(dir)
			tile.set_edge_visible(dir, false)
			neighbor.set_edge_visible(opposite, false)
		else:
			tile.set_edge_visible(dir, true)

func _restore_edges_for_cell(cell_pos: Vector2):
	var tile = _get_tile_at(cell_pos)
	if tile and tile.has_method("set_edge_visible"):
		for dir in ["N", "S", "E", "W"]:
			tile.set_edge_visible(dir, true)

func _get_tile_at(cell_pos: Vector2) -> Node:
	var key = "floor_" + str(int(cell_pos.x)) + "_" + str(int(cell_pos.y))
	if world.placed_pieces.has(key):
		var piece = world.placed_pieces[key]
		if piece.has_method("get_tile_type"):
			return piece
	return null

func _neighbor_cell(cell_pos: Vector2, dir: String) -> Vector2:
	match dir:
		"N": return cell_pos + Vector2(0, -1)
		"S": return cell_pos + Vector2(0, 1)
		"E": return cell_pos + Vector2(1, 0)
		"W": return cell_pos + Vector2(-1, 0)
	return cell_pos

func _opposite_dir(dir: String) -> String:
	match dir:
		"N": return "S"
		"S": return "N"
		"E": return "W"
		"W": return "E"
	return ""
