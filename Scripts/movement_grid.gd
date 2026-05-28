extends Node

var world: Node
var grid_nodes: Array = []

func _ready():
	pass

func show_grid(reachable_cells: Array, token: Node):
	hide_grid()
	var cell_size = world.grid.cell_size
	var half_grid = cell_size * world.grid.grid_size / 2.0
	var max_speed = token.get("move_speed") if token.has_method("get") else token.move_speed
	var max_cells = ceil(max_speed / 5.0)

	for cell in reachable_cells:
		var cx = (cell.x * cell_size) - half_grid + cell_size / 2.0
		var cz = (cell.y * cell_size) - half_grid + cell_size / 2.0
		var dist = max(abs(cell.x - token.grid_position.x), abs(cell.y - token.grid_position.y))

		var mesh = MeshInstance3D.new()
		var plane = PlaneMesh.new()
		plane.size = Vector2(cell_size * 0.9, cell_size * 0.9)
		mesh.mesh = plane

		var mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.render_priority = 1
		if dist <= ceil(max_cells / 3.0):
			mat.albedo_color = Color(0.2, 0.8, 0.2, 0.3)
		elif dist <= ceil(max_cells * 2.0 / 3.0):
			mat.albedo_color = Color(0.9, 0.7, 0.1, 0.3)
		else:
			mat.albedo_color = Color(0.9, 0.3, 0.1, 0.3)
		mesh.material_override = mat

		mesh.position = Vector3(cx, 0.06, cz)
		mesh.rotation_degrees = Vector3(-90, 0, 0)
		world.add_child(mesh)
		grid_nodes.append(mesh)

func hide_grid():
	for node in grid_nodes:
		if is_instance_valid(node):
			node.queue_free()
	grid_nodes.clear()
