extends StaticBody3D

var piece_type = "wall"
var cell = Vector2.ZERO
var direction = "N"
var custom_model_path = ""
enum WallType {WALL, DOOR_CLOSED, DOOR_OPEN, WINDOW}
var wall_type = WallType.WALL
var blocks_vision = true
var mesh_instance = null
var is_hovered = false

func _ready():
	for child in get_children():
		if child is MeshInstance3D:
			mesh_instance = child
			break

func init(cell_pos: Vector2, dir: String, cell_size: float, grid_size: int):
	cell = cell_pos
	direction = dir
	var half_grid = cell_size * grid_size / 2.0
	var cx = (cell_pos.x * cell_size) - half_grid + cell_size / 2.0
	var cz = (cell_pos.y * cell_size) - half_grid + cell_size / 2.0
	var half = cell_size / 2.0
	var y_pos = 0.5 if custom_model_path == "" else 0.0
	match dir:
		"N":
			position = Vector3(cx, y_pos, cz - half)
			rotation.y = 0.0
		"S":
			position = Vector3(cx, y_pos, cz + half)
			rotation.y = 0.0
		"E":
			position = Vector3(cx + half, y_pos, cz)
			rotation.y = deg_to_rad(90)
		"W":
			position = Vector3(cx - half, y_pos, cz)
			rotation.y = deg_to_rad(90)
	scale = Vector3(cell_size, cell_size, cell_size)
	# Load custom model if specified
	if custom_model_path != "":
		load_custom_model()

func load_custom_model():
	for child in get_children():
		if child is MeshInstance3D or (child.get_script() == null and child is Node3D and not child is CollisionShape3D):
			child.queue_free()
	var model_scene = load(custom_model_path)
	if model_scene:
		var new_mesh = model_scene.instantiate()
		add_child(new_mesh)
		mesh_instance = new_mesh
		var aabb = _get_aabb(new_mesh)
		print("Wall AABB size: ", aabb.size)
		print("Wall AABB max side: ", max(aabb.size.x, max(aabb.size.y, aabb.size.z)))
		if aabb.size != Vector3.ZERO:
			var max_side = max(aabb.size.x, max(aabb.size.y, aabb.size.z))
			var s = 1.0 / max_side
			print("Scale factor: ", s)
			new_mesh.scale = Vector3(s, s, s)
			print("Final mesh scale: ", new_mesh.scale)
			print("Final mesh position: ", new_mesh.position)
			print("Final body position: ", position)

func _get_aabb(node: Node) -> AABB:
	if not is_instance_valid(AabbUtil):
		return AABB()
	return AabbUtil.compute(node)

func get_real_mesh() -> MeshInstance3D:
	if mesh_instance is MeshInstance3D:
		return mesh_instance
	if mesh_instance:
		for child in mesh_instance.get_children():
			if child is MeshInstance3D:
				return child
	return null

func show_outline():
	if not is_hovered:
		is_hovered = true
		var real_mesh = get_real_mesh()
		if real_mesh:
			var mat = real_mesh.get_active_material(0)
			if mat:
				var dup = mat.duplicate()
				real_mesh.set_surface_override_material(0, dup)
				dup.albedo_color = Color(1.4, 1.2, 0.6)

func hide_outline():
	if is_hovered:
		is_hovered = false
		var real_mesh = get_real_mesh()
		if real_mesh:
			real_mesh.set_surface_override_material(0, null)
		elif mesh_instance:
			mesh_instance.set_surface_override_material(0, null)

func cycle_type():
	match wall_type:
		WallType.WALL:
			wall_type = WallType.DOOR_CLOSED
			blocks_vision = true
			set_tint(Color(0.8, 0.5, 0.2))
		WallType.DOOR_CLOSED:
			wall_type = WallType.DOOR_OPEN
			blocks_vision = false
			set_tint(Color(0.2, 0.8, 0.3))
		WallType.DOOR_OPEN:
			wall_type = WallType.WINDOW
			blocks_vision = false
			set_tint(Color(0.3, 0.6, 1.0))
		WallType.WINDOW:
			wall_type = WallType.WALL
			blocks_vision = true
			set_tint(Color(1.0, 1.0, 1.0))

func set_tint(color: Color):
	var real_mesh = get_real_mesh()
	if real_mesh:
		if color == Color(1.0, 1.0, 1.0):
			real_mesh.set_surface_override_material(0, null)
		else:
			var mat = real_mesh.get_active_material(0)
			if mat:
				var dup = mat.duplicate()
				real_mesh.set_surface_override_material(0, dup)
				dup.albedo_color = color
