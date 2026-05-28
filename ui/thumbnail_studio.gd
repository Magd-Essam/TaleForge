extends Node3D

@onready var viewport: SubViewport = $SubViewport
@onready var model_container: Node3D = $SubViewport/ModelContainer
@onready var camera: Camera3D = $SubViewport/Camera3D

func generate_thumbnail(model_path: String) -> ImageTexture:
	# Clear existing models
	for child in model_container.get_children():
		child.queue_free()
	
	# Load and instance the model
	var model_scene = load(model_path)
	if not model_scene:
		push_error("ThumbnailStudio: Failed to load model " + model_path)
		return null
		
	var model = model_scene.instantiate()
	model_container.add_child(model)
	
	# Wait for rendering setup
	await get_tree().process_frame
	if not is_inside_tree():
		return null

	# Perfect Framing
	_apply_perfect_framing(model)

	# Wait for rendering (multiple frames to ensure everything is visible)
	await get_tree().process_frame
	if not is_inside_tree():
		return null
	await get_tree().process_frame
	if not is_inside_tree():
		return null
	
	# Get the texture
	var image = viewport.get_texture().get_image()
	if image:
		return ImageTexture.create_from_image(image)
	
	return null

func _apply_perfect_framing(model: Node3D):
	var aabb = _calculate_total_aabb(model)
	
	# Calculate geometric center and longest side
	var center = aabb.get_center()
	var size = aabb.get_longest_axis_size()
	
	if size <= 0: size = 1.0
	
	# 1. Center the model at the world origin (0,0,0)
	# We move the model so its AABB center is at Vector3.ZERO
	model.position = -center
	
	# 2. Configure Orthogonal Camera
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	
	# The 'size' of an ortho camera is the height of the viewport in world units.
	# We set it to the model's max dimension with 40% extra padding to ensure
	# that diagonal views don't crop the corners.
	camera.size = size * 1.4
	
	# 3. Position camera to look at the origin from a fixed isometric angle
	# We use a distance large enough that the near/far planes can be set easily
	var camera_dist = size * 5.0
	camera.position = Vector3(1, 0.8, 1).normalized() * camera_dist
	camera.look_at(Vector3.ZERO)
	
	# 4. Set clipping planes to encompass the whole model
	camera.near = 0.1
	camera.far = camera_dist * 2.0

func _calculate_total_aabb(node: Node3D) -> AABB:
	var total_aabb = AABB()
	var first = true
	
	var stack = [[node, Transform3D.IDENTITY]]
	while stack.size() > 0:
		var pair = stack.pop_back()
		var current = pair[0]
		var current_transform = pair[1]
		
		var local_transform = current_transform
		if current != node:
			local_transform = current_transform * current.transform
			
		if current is MeshInstance3D:
			var mesh_aabb = current.get_aabb()
			var model_space_aabb = local_transform * mesh_aabb
			if first:
				total_aabb = model_space_aabb
				first = false
			else:
				total_aabb = total_aabb.merge(model_space_aabb)
		
		for child in current.get_children():
			if child is Node3D:
				stack.push_back([child, local_transform])
				
	return total_aabb
