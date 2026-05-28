extends StaticBody3D

var piece_type = "floor"
var tile_type = "stone"
var grid_position = Vector2.ZERO
var custom_model_path = ""
var mesh_instance = null
var is_hovered = false
var _model_loaded = false

# Edge visibility for tile fusion (N/S/E/W)
var edge_visible = {"N": true, "S": true, "E": true, "W": true}
var _edge_border_nodes = {}

func _ready():
	for child in get_children():
		if child is MeshInstance3D:
			mesh_instance = child
			break
	if custom_model_path != "" and not _model_loaded:
		_model_loaded = true
		load_custom_model()

func set_tile_type(type_name: String):
	tile_type = type_name

func init(cell_pos: Vector2, cell_size: float, grid_size: int):
	grid_position = cell_pos
	var half_grid = cell_size * grid_size / 2.0
	var cx = (cell_pos.x * cell_size) - half_grid + cell_size / 2.0
	var cz = (cell_pos.y * cell_size) - half_grid + cell_size / 2.0
	position = Vector3(cx, 0.05, cz)
	scale = Vector3(cell_size, cell_size, cell_size)
	if custom_model_path != "" and not _model_loaded:
		_model_loaded = true
		load_custom_model()

func set_edge_visible(dir: String, visible: bool):
	edge_visible[dir] = visible
	_update_edge_visual(dir)

func _update_edge_visual(dir: String):
	var visible = edge_visible[dir]
	if _edge_border_nodes.has(dir) and is_instance_valid(_edge_border_nodes[dir]):
		_edge_border_nodes[dir].visible = visible

func get_neighbor_key(dir: String) -> Vector2:
	match dir:
		"N": return grid_position + Vector2(0, -1)
		"S": return grid_position + Vector2(0, 1)
		"E": return grid_position + Vector2(1, 0)
		"W": return grid_position + Vector2(-1, 0)
	return grid_position

func get_tile_type() -> String:
	return tile_type

func load_custom_model():
	for child in get_children():
		if not child is CollisionShape3D:
			child.queue_free()
	var model_scene = load(custom_model_path)
	if model_scene:
		var new_mesh = model_scene.instantiate()
		add_child(new_mesh)
		mesh_instance = new_mesh
		# No scaling — use original Blender size

func _get_aabb(node: Node) -> AABB:
	if not is_instance_valid(AabbUtil):
		return AABB()
	return AabbUtil.compute(node)

func show_outline():
	if not is_hovered:
		is_hovered = true
		var real_mesh = _find_mesh(mesh_instance)
		if real_mesh:
			var mat = real_mesh.get_active_material(0)
			if mat:
				var dup = mat.duplicate()
				real_mesh.set_surface_override_material(0, dup)
				dup.albedo_color = Color(1.4, 1.2, 0.6)

func hide_outline():
	if is_hovered:
		is_hovered = false
		var real_mesh = _find_mesh(mesh_instance)
		if real_mesh:
			real_mesh.set_surface_override_material(0, null)

func _find_mesh(node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	if node:
		for child in node.get_children():
			var result = _find_mesh(child)
			if result:
				return result
	return null
