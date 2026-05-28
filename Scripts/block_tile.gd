extends StaticBody3D
class_name ModularBlock

const BLOCK_COLOR: Color = Color(0.45, 0.38, 0.32)
const GRID_SHADER: Shader = preload("res://grid.gdshader")

var mesh_instance: MeshInstance3D
var collision_shape: CollisionShape3D
var grid_overlay_plane: MeshInstance3D

func _init() -> void:
	_create_collision_shape()
	_create_default_mesh()

func configure(cell_size: float) -> void:
	scale = Vector3(cell_size, cell_size, cell_size)
	_ensure_grid_overlay()

func apply_custom_model(model_scene: PackedScene) -> void:
	if not model_scene:
		return
	_clear_mesh_children()
	var custom_instance: Node3D = model_scene.instantiate() as Node3D
	if not custom_instance:
		return
	add_child(custom_instance)
	mesh_instance = _find_mesh_instance(custom_instance)

func _create_collision_shape() -> void:
	collision_shape = CollisionShape3D.new()
	collision_shape.shape = BoxShape3D.new()
	add_child(collision_shape)

func _create_default_mesh() -> void:
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = BoxMesh.new()
	var base_material = StandardMaterial3D.new()
	base_material.albedo_color = BLOCK_COLOR
	mesh_instance.material_override = base_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(mesh_instance)

func _clear_mesh_children() -> void:
	for child in get_children():
		if child != collision_shape and child != grid_overlay_plane:
			child.queue_free()

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result := _find_mesh_instance(child)
		if result:
			return result
	return null

func _ensure_grid_overlay() -> void:
	if grid_overlay_plane:
		return
	grid_overlay_plane = MeshInstance3D.new()
	var plane_mesh: PlaneMesh = PlaneMesh.new()
	plane_mesh.size = Vector2(1.0, 1.0)
	grid_overlay_plane.mesh = plane_mesh
	grid_overlay_plane.position = Vector3(0.0, 0.5001, 0.0)
	grid_overlay_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grid_overlay_plane.material_override = _create_grid_overlay_material()
	add_child(grid_overlay_plane)
	grid_overlay_plane.visible = true

func _create_grid_overlay_material() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = GRID_SHADER
	material.set_shader_parameter("line_width", 0.6)
	material.set_shader_parameter("sub_grid_division", 0.0)
	material.set_shader_parameter("fade_distance", 9999.0)
	material.set_shader_parameter("fade_sharpness", 1.0)
	material.set_shader_parameter("grid_color", Color(0.0, 0.0, 0.0, 0.95))
	material.set_shader_parameter("sub_grid_color", Color(0.051, 0.0, 0.0, 0.0))
	return material

func set_grid_overlay_visible(visible_state: bool) -> void:
	if grid_overlay_plane:
		grid_overlay_plane.visible = visible_state
