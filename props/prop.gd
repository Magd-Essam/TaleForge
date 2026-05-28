extends StaticBody3D

var piece_type = "prop"
var model_path = ""
var grid_position = Vector2.ZERO
var mesh_instance = null
var _collision_pending = false

var is_selected = false
var base_scale = 1.0
var scale_multiplier = 1.0

func init(data: Dictionary, cell_pos: Vector2, cell_size: float, grid_size: int):
	grid_position = cell_pos
	var half_grid = cell_size * grid_size / 2.0
	var cx = (cell_pos.x * cell_size) - half_grid + cell_size / 2.0
	var cz = (cell_pos.y * cell_size) - half_grid + cell_size / 2.0
	position = Vector3(cx, 0.0, cz)
	if data.has("model_path"):
		model_path = data.model_path
		call_deferred("load_model", model_path)

func load_model(path: String):
	for child in get_children():
		if child is MeshInstance3D or (child is Node3D and not child is CollisionShape3D):
			child.queue_free()
	var model_scene = load(path)
	if model_scene:
		var new_mesh = model_scene.instantiate()
		add_child(new_mesh)
		mesh_instance = new_mesh
		_compute_base_scale()
		apply_scale(scale_multiplier)
		if not _collision_pending:
			_collision_pending = true
			call_deferred("_rebuild_collision")

func _rebuild_collision():
	_collision_pending = false
	for child in get_children():
		if child is CollisionShape3D:
			child.queue_free()
	if not mesh_instance:
		return
	var mesh_nodes := []
	_find_mesh_instances(mesh_instance, mesh_nodes)
	for mi in mesh_nodes:
		if not mi.mesh:
			continue
		var shape = mi.mesh.create_trimesh_shape()
		if not shape:
			continue
		var col := CollisionShape3D.new()
		col.shape = shape
		col.transform = global_transform.affine_inverse() * mi.global_transform
		add_child(col)

func _find_mesh_instances(node: Node, result: Array) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_find_mesh_instances(child, result)

func apply_scale(multiplier: float):
	scale_multiplier = max(0.1, multiplier)
	var s = base_scale * scale_multiplier
	for mi in _get_all_mesh_instances():
		mi.scale = Vector3(s, s, s)
	# Scale collision shapes to match — physics raycasts (e.g. drag drop)
	# depend on correct collision bounds.
	for child in get_children():
		if child is CollisionShape3D:
			child.scale = Vector3(s, s, s)

func _compute_base_scale():
	if not mesh_instance:
		return
	var aabb = _get_aabb(mesh_instance)
	if aabb.size != Vector3.ZERO:
		var max_side = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
		base_scale = 0.9 / max_side

func _get_aabb(node: Node) -> AABB:
	if not is_instance_valid(AabbUtil):
		return AABB()
	return AabbUtil.compute(node)


func get_top_surface_y() -> float:
	if not mesh_instance:
		return position.y
	var top_y := position.y
	var mesh_nodes := []
	_find_mesh_instances(mesh_instance, mesh_nodes)
	for mi in mesh_nodes:
		if not mi.mesh:
			continue
		var local_aabb = mi.mesh.get_aabb()
		var mi_global = mi.global_transform
		var center = local_aabb.get_center()
		var extents = local_aabb.size * 0.5
		for sx in [-1.0, 0.0, 1.0]:
			for sz in [-1.0, 0.0, 1.0]:
				var local_p := Vector3(
					center.x + extents.x * sx,
					local_aabb.end.y,
					center.z + extents.z * sz
				)
				var world_p = mi_global * local_p
				if world_p.y > top_y:
					top_y = world_p.y
	return top_y

func _get_all_mesh_instances() -> Array:
	var result := []
	if mesh_instance:
		_find_mesh_instances(mesh_instance, result)
	for child in get_children():
		if child is MeshInstance3D and not result.has(child):
			result.append(child)
	return result

func select():
	is_selected = true
	scale = Vector3(1.1, 1.1, 1.1)
	for mi in _get_all_mesh_instances():
		if not mi.mesh:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var orig = mi.get_surface_override_material(s)
			if not orig:
				orig = mi.mesh.surface_get_material(s)
			if orig:
				var dup = orig.duplicate()
				if dup is StandardMaterial3D:
					dup.emission = Color(0.3, 0.6, 1.0)
					dup.emission_energy_multiplier = 0.5
				mi.set_surface_override_material(s, dup)

func deselect():
	is_selected = false
	scale = Vector3(1.0, 1.0, 1.0)
	for mi in _get_all_mesh_instances():
		if not mi.mesh:
			continue
		for s in range(mi.mesh.get_surface_count()):
			mi.set_surface_override_material(s, null)
