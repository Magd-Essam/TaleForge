extends Node

const VERSION = 1

func encode_slab(tiles: Array, walls: Array, props: Array) -> String:
	var data = {
		"version": VERSION,
		"tiles": tiles,
		"walls": walls,
		"props": props
	}
	var json_str = JSON.stringify(data)
	return Marshalls.utf8_to_base64(json_str)

func decode_slab(encoded: String) -> Dictionary:
	if encoded.is_empty():
		return {}
	var json_str = Marshalls.base64_to_utf8(encoded)
	if json_str.is_empty():
		return {}
	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK:
		return {}
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	if data.get("version", 0) != VERSION:
		return {}
	return data

func slab_from_selection(tile_keys: Array, wall_keys: Array, prop_keys: Array, world: Node) -> Dictionary:
	var tiles = []
	for key in tile_keys:
		var piece = world.placed_pieces.get(key)
		if not piece:
			continue
		var parts = key.split("_")
		if parts.size() >= 3:
			var cell_x = int(parts[1])
			var cell_y = int(parts[2])
			tiles.append({
				"type": piece.tile_type if "tile_type" in piece else piece.piece_type,
				"cell_x": cell_x,
				"cell_y": cell_y,
				"rotation": 0
			})

	var walls_arr = []
	for key in wall_keys:
		var piece = world.placed_pieces.get(key)
		if not piece:
			continue
		var parts = key.split("_")
		if parts.size() >= 3:
			var cell_x = int(parts[0])
			var cell_y = int(parts[1])
			var dir = parts[2] if parts.size() >= 3 else "N"
			walls_arr.append({
				"cell_x": cell_x,
				"cell_y": cell_y,
				"dir": dir,
				"wall_type": piece.wall_type if "wall_type" in piece else 0
			})

	var props_arr = []
	for key in prop_keys:
		var prop = world.placed_props.get(key)
		if not prop:
			continue
		props_arr.append({
			"model_path": prop.model_path if "model_path" in prop else "",
			"pos": [prop.position.x, prop.position.y, prop.position.z],
			"rot": prop.rotation.y,
			"scale": prop.scale.x if prop.scale else 1.0
		})

	return {"tiles": tiles, "walls": walls_arr, "props": props_arr}
