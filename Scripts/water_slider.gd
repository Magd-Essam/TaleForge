extends Node

var world: Node

var water_height: float = -10.0
var is_visible: bool = false
var water_mesh: MeshInstance3D = null

signal water_level_changed(height: float)

func _ready():
	world = get_parent()

func set_water_level(height: float):
	water_height = height
	is_visible = height > -10.0
	emit_signal("water_level_changed", water_height)
	_update_water_mesh()

func toggle():
	is_visible = not is_visible
	if is_visible:
		water_height = 0.0
	else:
		_remove_water_mesh()
		water_height = -10.0
	emit_signal("water_level_changed", water_height)
	if is_visible:
		_update_water_mesh()

func _update_water_mesh():
	if not is_visible:
		_remove_water_mesh()
		return
	if not water_mesh or not is_instance_valid(water_mesh):
		water_mesh = MeshInstance3D.new()
		water_mesh.name = "WaterSurface"
		var plane_mesh = PlaneMesh.new()
		plane_mesh.size = Vector2(200, 200)
		plane_mesh.material = _make_water_material()
		water_mesh.mesh = plane_mesh
		world.add_child(water_mesh)
	water_mesh.position = Vector3(0, water_height, 0)

func _remove_water_mesh():
	if water_mesh and is_instance_valid(water_mesh):
		water_mesh.queue_free()
		water_mesh = null

func _make_water_material() -> Material:
	var mat = ShaderMaterial.new()
	var shader = preload("res://water.gdshader")
	if shader:
		mat.shader = shader
	else:
		var standard = StandardMaterial3D.new()
		standard.albedo_color = Color(0.0, 0.3, 0.5, 0.5)
		standard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		standard.metallic = 0.3
		standard.roughness = 0.1
		return standard
	return mat
