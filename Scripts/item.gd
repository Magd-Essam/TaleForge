extends StaticBody3D

var piece_type = "item"
var item_name = "Item"
var item_type = "misc"
var model_path = ""
var mesh_instance: Node = null

func init(data: Dictionary, pos: Vector3):
	item_name = data.get("name", "Item")
	item_type = data.get("type", "misc")
	model_path = data.get("model_path", "")
	position = pos
	if model_path != "":
		call_deferred("load_model", model_path)
	else:
		_make_default_mesh()

func _make_default_mesh():
	var mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	mesh.mesh = sphere
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.8, 0.2)
	mat.emission = Color(1, 0.8, 0.2)
	mat.emission_energy_multiplier = 0.5
	mesh.material_override = mat
	add_child(mesh)
	mesh_instance = mesh

func load_model(path: String):
	for child in get_children():
		if child is MeshInstance3D or (child is Node3D and not child is CollisionShape3D):
			child.queue_free()
	var model_scene = load(path)
	if model_scene:
		var new_mesh = model_scene.instantiate()
		add_child(new_mesh)
		mesh_instance = new_mesh

func show_outline():
	if mesh_instance and mesh_instance is MeshInstance3D:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.4, 1.2, 0.6, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if mesh_instance.get_surface_override_material(0) == null:
			mesh_instance.set_surface_override_material(0, mat)

func hide_outline():
	if mesh_instance and mesh_instance is MeshInstance3D:
		mesh_instance.set_surface_override_material(0, null)
