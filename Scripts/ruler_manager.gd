extends Node

enum State { IDLE, PLACING, DONE }

var state: int = State.IDLE
var start_cell: Vector2
var end_cell: Vector2
var height_offset: int = 0

var world: Node3D

var start_marker: MeshInstance3D
var end_marker: MeshInstance3D
var line_mesh: MeshInstance3D
var distance_label: Label3D


func _ready():
	world = get_parent() as Node3D
	_create_visuals()


func _create_visuals():
	var col = _get_my_color()

	start_marker = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	start_marker.mesh = sm
	var start_mat = StandardMaterial3D.new()
	start_mat.albedo_color = col
	start_mat.emission_enabled = true
	start_mat.emission = col
	start_marker.material_override = start_mat
	start_marker.visible = false
	add_child(start_marker)

	end_marker = MeshInstance3D.new()
	var em = SphereMesh.new()
	em.radius = 0.25
	em.height = 0.5
	end_marker.mesh = em
	var end_mat = StandardMaterial3D.new()
	end_mat.albedo_color = Color(1, 0, 0)
	end_mat.emission_enabled = true
	end_mat.emission = Color(1, 0, 0)
	end_marker.material_override = end_mat
	end_marker.visible = false
	add_child(end_marker)

	line_mesh = MeshInstance3D.new()
	var line_mat = StandardMaterial3D.new()
	line_mat.albedo_color = col
	line_mat.emission_enabled = true
	line_mat.emission = col
	line_mesh.material_override = line_mat
	line_mesh.visible = false
	add_child(line_mesh)

	distance_label = Label3D.new()
	distance_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	distance_label.font_size = 48
	distance_label.outline_modulate = Color(0, 0, 0)
	distance_label.outline_size = 4
	distance_label.visible = false
	add_child(distance_label)


func handle_left_press(mouse_pos: Vector2):
	var hit = world.get_world_hit(mouse_pos)
	if not hit:
		return
	var cell = world.world_to_cell(hit.position.x, hit.position.z)

	match state:
		State.IDLE:
			height_offset = 0
			start_cell = cell
			state = State.PLACING
			_show_start_marker(start_cell)
			end_marker.visible = false
			line_mesh.visible = false
			distance_label.visible = false
		State.PLACING:
			end_cell = cell
			state = State.DONE
			_update_measurement()
		State.DONE:
			clear()
			height_offset = 0
			start_cell = cell
			state = State.PLACING
			_show_start_marker(start_cell)


func adjust_height(delta: int):
	height_offset = clampi(height_offset + delta, -20, 20)
	if state != State.IDLE:
		_update_measurement()


func update_preview(mouse_pos: Vector2):
	if state != State.PLACING:
		return
	var hit = world.get_world_hit(mouse_pos)
	if not hit:
		return
	var cell = world.world_to_cell(hit.position.x, hit.position.z)
	end_cell = cell
	_update_measurement()


func _update_measurement():
	var dz = abs(height_offset)
	_show_end_marker(end_cell, height_offset)
	_show_line(start_cell, end_cell, height_offset)

	var dx = abs(end_cell.x - start_cell.x)
	var dy = abs(end_cell.y - start_cell.y)
	var dist = max(dx, max(dy, dz)) * 5

	var start_pos = _cell_to_world(start_cell)
	var end_pos = _cell_to_world(end_cell, height_offset)
	var mid = (start_pos + end_pos) / 2.0
	mid.y += 1.0

	distance_label.global_position = mid
	if dz > 0:
		distance_label.text = str(dist) + " ft  (Δ" + str(dz * 5) + " ft)"
	else:
		distance_label.text = str(dist) + " ft"
	distance_label.visible = true

	if dist <= 30:
		distance_label.modulate = Color(0, 1, 0)
	elif dist <= 60:
		distance_label.modulate = Color(1, 1, 0)
	elif dist <= 120:
		distance_label.modulate = Color(1, 0.5, 0)
	else:
		distance_label.modulate = Color(1, 0, 0)


func _show_start_marker(cell: Vector2):
	start_marker.global_position = _cell_to_world(cell)
	start_marker.visible = true

func _show_end_marker(cell: Vector2, height: int = 0):
	end_marker.global_position = _cell_to_world(cell, height)
	end_marker.visible = true

func _show_line(from: Vector2, to: Vector2, height: int = 0):
	var from_pos = _cell_to_world(from)
	var to_pos = _cell_to_world(to, height)
	var mid = (from_pos + to_pos) / 2.0
	var length = from_pos.distance_to(to_pos)

	line_mesh.global_position = mid
	var box = BoxMesh.new()
	box.size = Vector3(0.1, 0.05, length)
	line_mesh.mesh = box
	line_mesh.look_at(to_pos, Vector3.UP)
	line_mesh.visible = true

func _get_my_color() -> Color:
	var nm = get_node_or_null("../NetworkManager")
	if nm and nm.players.has(nm.my_id) and nm.players[nm.my_id].has("color"):
		return nm.players[nm.my_id].color
	return Color(0, 1, 1)


func _cell_to_world(cell: Vector2, height: int = 0) -> Vector3:
	var grid = world.grid
	var cell_size = grid.cell_size
	var half = (grid.grid_size * cell_size) / 2.0
	var x = (cell.x * cell_size) - half + cell_size / 2.0
	var z = (cell.y * cell_size) - half + cell_size / 2.0
	var y = 0.05 + height * cell_size
	return Vector3(x, y, z)

func clear():
	state = State.IDLE
	height_offset = 0
	start_marker.visible = false
	end_marker.visible = false
	line_mesh.visible = false
	distance_label.visible = false
