extends Node3D

var die_type = 6
var is_settled = false
var settle_timer = 0.0
var result_callback = null
var rigid_body = null
var _spawn_pos = Vector3.ZERO

var die_meshes = {
	4: preload("res://ui/dices/d4.glb"),
	6: preload("res://ui/dices/d6.glb"),
	8: preload("res://ui/dices/d8.glb"),
	10: preload("res://ui/dices/d10.glb"),
	12: preload("res://ui/dices/d12.glb"),
	20: preload("res://ui/dices/d20.glb"),
}

func init(sides: int, spawn_pos: Vector3, callback: Callable):
	die_type = sides
	position = Vector3.ZERO
	_spawn_pos = spawn_pos
	result_callback = callback
	load_mesh()

func load_mesh():
	if die_meshes.has(die_type):
		var mesh_scene = die_meshes[die_type].instantiate()
		add_child(mesh_scene)
		rigid_body = find_rigid_body(mesh_scene)
		if rigid_body:
			rigid_body.mass = 1.0
			rigid_body.linear_damp = 0.1
			rigid_body.angular_damp = 1.5
			rigid_body.gravity_scale = 2.0
			rigid_body.physics_material_override = PhysicsMaterial.new()
			rigid_body.physics_material_override.friction = 0.9
			rigid_body.physics_material_override.bounce = 0.35
			rigid_body.rotation = Vector3(randf()*TAU, randf()*TAU, randf()*TAU)
			call_deferred("_throw")

func find_rigid_body(node: Node) -> RigidBody3D:
	if node is RigidBody3D:
		return node
	for child in node.get_children():
		var result = find_rigid_body(child)
		if result:
			return result
	return null

func _throw():
	if not rigid_body:
		return
	
	# Pick a random side to throw from
	var angle = randf() * TAU
	var dist = 4.0
	
	rigid_body.position = Vector3(
		cos(angle) * dist,
		1.5,
		sin(angle) * dist
	)
	
	# Throw toward center with strong upward angle
	var to_center = Vector3(-cos(angle), 0, -sin(angle))
	var throw_dir = (to_center * 8.0) + Vector3(0, 2.0, 0)
	
	rigid_body.linear_velocity = throw_dir
	
	rigid_body.angular_velocity = Vector3(
		randf_range(-30, 30),
		randf_range(-15, 15),
		randf_range(-30, 30)
	)

func _physics_process(delta):
	if is_settled or not rigid_body:
		return
	if rigid_body.linear_velocity.length() < 0.1 and rigid_body.angular_velocity.length() < 0.1:
		settle_timer += delta
		if settle_timer > 0.8:
			is_settled = true
			var result = get_result()
			if result_callback:
				result_callback.call(result, die_type)
			await get_tree().create_timer(0.5).timeout
			queue_free()
	else:
		settle_timer = 0.0

func get_result() -> int:
	var face_nodes = {}
	find_face_nodes(self, face_nodes)
	
	if face_nodes.is_empty():
		push_error("Die " + str(die_type) + ": no FaceN nodes found — cannot determine result")
		return randi() % die_type + 1
	
	var best_face = 1
	var best_dot = -1.0
	for i in range(1, die_type + 1):
		if face_nodes.has("Face" + str(i)):
			var face_node = face_nodes["Face" + str(i)]
			var dot = face_node.global_transform.basis.y.dot(Vector3.UP)
			if dot > best_dot:
				best_dot = dot
				best_face = i
	
	return best_face

func find_face_nodes(node: Node, result: Dictionary):
	for child in node.get_children():
		if child.name.begins_with("Face"):
			result[child.name] = child
		find_face_nodes(child, result)
