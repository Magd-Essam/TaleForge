extends Node3D
class_name AoeManager

enum AoeShape { SPHERE, CONE, LINE, CUBE }
enum AoeMode { PLACE, DELETE }

const SHAPE_COLORS := {
	AoeShape.SPHERE: Color(0.2, 0.6, 1.0, 0.4),
	AoeShape.CONE:   Color(1.0, 0.4, 0.2, 0.4),
	AoeShape.LINE:   Color(0.4, 1.0, 0.2, 0.4),
	AoeShape.CUBE:   Color(1.0, 0.8, 0.2, 0.4),
}

var is_active: bool = false
var current_shape: int = AoeShape.SPHERE
var current_mode: int = AoeMode.PLACE

var world: Node3D

var _preview_mesh: MeshInstance3D
var _preview_material: StandardMaterial3D
var _ruler_line: MeshInstance3D
var _distance_label: Label3D
var _size_line: MeshInstance3D
var _size_handle: MeshInstance3D
var _size_label: Label3D
var _origin_marker: MeshInstance3D

var _placing: bool = false
var _dragging: bool = false
var _origin_cell: Vector2
var _distance: float = 2.0
var _size: float = 2.0
var _height_offset: int = 0
var _mouse_dir: Vector2 = Vector2(0, -1)
var _aoe_id_counter: int = 0
var escape_handled_this_frame: bool = false

signal mode_changed(is_active, shape, mode)


func _ready():
	world = get_parent() as Node3D
	_create_visuals()


func _process(_delta):
	escape_handled_this_frame = false


func _create_visuals():
	_preview_material = StandardMaterial3D.new()
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_preview_material.albedo_color = SHAPE_COLORS[current_shape]

	_preview_mesh = MeshInstance3D.new()
	_preview_mesh.material_override = _preview_material
	_preview_mesh.visible = false
	add_child(_preview_mesh)

	_ruler_line = MeshInstance3D.new()
	var lm = StandardMaterial3D.new()
	lm.albedo_color = Color(1, 1, 0)
	lm.emission_enabled = true
	lm.emission = Color(1, 0.8, 0)
	_ruler_line.material_override = lm
	_ruler_line.visible = false
	add_child(_ruler_line)

	_distance_label = Label3D.new()
	_distance_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_distance_label.font_size = 48
	_distance_label.outline_modulate = Color(0, 0, 0)
	_distance_label.outline_size = 4
	_distance_label.visible = false
	add_child(_distance_label)

	_size_line = MeshInstance3D.new()
	var sm = StandardMaterial3D.new()
	sm.albedo_color = Color(0, 1, 1)
	sm.emission_enabled = true
	sm.emission = Color(0, 1, 1)
	_size_line.material_override = sm
	_size_line.visible = false
	add_child(_size_line)

	_size_handle = MeshInstance3D.new()
	var hm = SphereMesh.new()
	hm.radius = 0.35
	hm.height = 0.7
	_size_handle.mesh = hm
	var hmat = StandardMaterial3D.new()
	hmat.albedo_color = Color(0, 1, 1)
	hmat.emission_enabled = true
	hmat.emission = Color(0, 1, 1)
	hmat.emission_energy_multiplier = 2.0
	_size_handle.material_override = hmat
	_size_handle.visible = false
	add_child(_size_handle)

	_size_label = Label3D.new()
	_size_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_size_label.font_size = 48
	_size_label.outline_modulate = Color(0, 0, 0)
	_size_label.outline_size = 4
	_size_label.visible = false
	add_child(_size_label)

	_origin_marker = MeshInstance3D.new()
	var om = SphereMesh.new()
	om.radius = 0.15
	om.height = 0.3
	_origin_marker.mesh = om
	var omat = StandardMaterial3D.new()
	omat.albedo_color = Color(1, 0.8, 0)
	omat.emission_enabled = true
	omat.emission = Color(1, 0.8, 0)
	omat.emission_energy_multiplier = 2.0
	_origin_marker.material_override = omat
	_origin_marker.visible = false
	add_child(_origin_marker)


func _make_mesh(shape: int, sz: float, dist: float = -1.0) -> Mesh:
	match shape:
		AoeShape.SPHERE:
			return AoeShapes.create_sphere(sz)
		AoeShape.CONE:
			return AoeShapes.create_cone(dist if dist >= 0 else sz, sz)
		AoeShape.LINE:
			return AoeShapes.create_line(dist if dist >= 0 else sz, sz)
		AoeShape.CUBE:
			return AoeShapes.create_cube(sz)
	return BoxMesh.new()


func set_active(on: bool):
	is_active = on
	if not on:
		_cancel()
	emit_signal("mode_changed", is_active, current_shape, current_mode)

func toggle_active():
	set_active(not is_active)

func set_shape(shape: int):
	current_shape = shape
	_preview_material.albedo_color = SHAPE_COLORS[shape]
	if _placing:
		_show_placing_preview()
	emit_signal("mode_changed", is_active, current_shape, current_mode)

func set_mode(mode: int):
	current_mode = mode
	if _placing:
		_cancel()
	emit_signal("mode_changed", is_active, current_shape, current_mode)


func _input(event: InputEvent):
	if not is_active:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		escape_handled_this_frame = true
		if _placing or _dragging:
			_cancel()
		else:
			set_active(false)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var is_scroll = event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		if is_scroll and event.pressed:
			get_viewport().set_input_as_handled()
			if not _placing:
				return
			if Input.is_key_pressed(KEY_SHIFT):
				var dir = 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
				_size = max(0.5, _size + dir * 0.5)
			else:
				_height_offset = clampi(_height_offset + 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else _height_offset - 1, -20, 20)
			_show_placing_preview()
			return

	if not _can_process_input():
		return

	if event is InputEventMouseMotion:
		if _dragging:
			_update_drag(event.position)
		elif _placing:
			_update_staged_preview(event.position)
		else:
			_update_hover_preview(event.position)
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_handle_left_press(event.position)
				get_viewport().set_input_as_handled()
			elif _dragging:
				_handle_left_release()
				get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _placing:
				_place()
			else:
				_handle_right_click_delete(event.position)
			get_viewport().set_input_as_handled()


func _can_process_input() -> bool:
	if not world:
		return false
	if world.has_method("is_mouse_over_ui") and world.is_mouse_over_ui():
		return false
	return true


func _get_hovered_cell(mouse_pos: Vector2) -> Variant:
	if not world or not world.has_method("get_world_hit") or not world.has_method("world_to_cell"):
		return null
	var hit = world.get_world_hit(mouse_pos)
	if not hit:
		return null
	return world.world_to_cell(hit.position.x, hit.position.z)

var _last_hovered_cell: Vector2 = Vector2(-9999, -9999)


func _update_hover_preview(mouse_pos: Vector2):
	var cell = _get_hovered_cell(mouse_pos)
	if not cell:
		_hide_preview()
		return
	if cell == _last_hovered_cell:
		return
	_last_hovered_cell = cell
	_preview_mesh.mesh = _make_mesh(current_shape, _size, _distance)
	_preview_mesh.global_position = _cell_to_world(cell)
	_preview_mesh.visible = true
	_ruler_line.visible = false
	_distance_label.visible = false
	_size_line.visible = false
	_size_handle.visible = false
	_size_label.visible = false
	_origin_marker.visible = false


func _update_staged_preview(mouse_pos: Vector2):
	pass


func _handle_left_press(mouse_pos: Vector2):
	if current_mode == AoeMode.DELETE:
		_delete_nearest_aoe(mouse_pos)
		return

	if _placing:
		_place()

	var hit = world.get_world_hit(mouse_pos)
	if not hit:
		return
	var cell = world.world_to_cell(hit.position.x, hit.position.z)

	_origin_cell = cell
	_mouse_dir = Vector2(0, -1)
	_distance = 2.0
	_height_offset = 0
	_dragging = true
	_placing = true
	_show_placing_preview()


func _handle_left_release():
	if _dragging:
		_dragging = false


func _update_drag(mouse_pos: Vector2):
	var hit = world.get_world_hit(mouse_pos)
	if not hit:
		return
	var mouse_cell = world.world_to_cell(hit.position.x, hit.position.z)
	var diff = mouse_cell - _origin_cell
	if diff.length_squared() >= 0.5:
		_mouse_dir = diff
	_distance = max(0.5, diff.length())
	_show_placing_preview()


func _show_placing_preview():
	var dir_n = _mouse_dir.normalized()
	if dir_n.length() < 0.5:
		dir_n = Vector2(0, -1)

	var target_cell = _origin_cell + dir_n * _distance
	var origin_world = _cell_to_world(_origin_cell, _height_offset)
	var ground_origin = _cell_to_world(_origin_cell, 0)

	match current_shape:
		AoeShape.SPHERE:
			var center_world = _cell_to_world(target_cell, _height_offset)
			_preview_mesh.mesh = _make_mesh(AoeShape.SPHERE, _size, _distance)
			_preview_mesh.global_position = center_world
			_preview_mesh.global_rotation = Vector3.ZERO
			_update_ruler(ground_origin, center_world)
			_update_gizmo(center_world, dir_n, _size, "R: " + str(round(_size * 5.0)) + " ft")
			_update_origin_marker(ground_origin)

		AoeShape.CUBE:
			var center_world = _cell_to_world(target_cell, _height_offset)
			_preview_mesh.mesh = _make_mesh(AoeShape.CUBE, _size, _distance)
			_preview_mesh.global_position = center_world
			_preview_mesh.global_rotation = Vector3.ZERO
			_update_ruler(ground_origin, center_world)
			_update_gizmo(center_world, dir_n, _size * 0.5, "Side: " + str(round(_size * 5.0)) + " ft")
			_update_origin_marker(ground_origin)

		AoeShape.CONE:
			var far_world = _cell_to_world(target_cell, _height_offset)
			var angle = atan2(_mouse_dir.x, -_mouse_dir.y)
			_preview_mesh.mesh = _make_mesh(AoeShape.CONE, _size, _distance)
			_preview_mesh.global_position = origin_world
			_preview_mesh.global_rotation = Vector3(0, angle, 0)
			_update_ruler(ground_origin, far_world)
			_update_gizmo(far_world, dir_n, _size * 0.5, "W: " + str(round(_size * 5.0)) + " ft")
			_update_origin_marker(ground_origin)

		AoeShape.LINE:
			var far_world = _cell_to_world(target_cell, _height_offset)
			var angle = atan2(_mouse_dir.x, -_mouse_dir.y)
			var mid = (origin_world + far_world) * 0.5
			_preview_mesh.mesh = _make_mesh(AoeShape.LINE, _size, _distance)
			_preview_mesh.global_position = mid
			_preview_mesh.global_rotation = Vector3(0, angle, 0)
			_update_ruler(ground_origin, far_world)
			_update_gizmo(far_world, dir_n, _size * 0.5, "W: " + str(round(_size * 5.0)) + " ft")
			_update_origin_marker(ground_origin)


func _update_ruler(from: Vector3, to: Vector3):
	var diff = to - from
	var len = diff.length()
	if len < 0.01:
		_ruler_line.visible = false
		_distance_label.visible = false
		return
	var mid = (from + to) * 0.5
	var box = BoxMesh.new()
	box.size = Vector3(0.06, 0.06, len)
	_ruler_line.mesh = box
	_ruler_line.global_position = mid
	_ruler_line.look_at(to, Vector3.UP)
	_ruler_line.visible = true

	var dist_ft = round(len * 5.0 / world.grid.cell_size)
	_distance_label.text = str(dist_ft) + " ft"
	_distance_label.global_position = mid + Vector3(0, 1.5, 0)
	_distance_label.visible = true


func _update_gizmo(shape_world: Vector3, dir_cell: Vector2, extent: float, label_text: String):
	var dir_world = Vector3(dir_cell.x, 0, dir_cell.y).normalized()
	var edge_world = shape_world + dir_world * extent
	var diff = edge_world - shape_world
	var len = diff.length()
	if len < 0.2:
		_size_line.visible = false
		_size_handle.visible = false
		_size_label.visible = false
		return
	var mid = (shape_world + edge_world) * 0.5
	var box = BoxMesh.new()
	box.size = Vector3(0.05, 0.05, len)
	_size_line.mesh = box
	_size_line.global_position = mid
	_size_line.look_at(edge_world, Vector3.UP)
	_size_line.visible = true
	_size_handle.global_position = edge_world
	_size_handle.visible = true
	_size_label.text = label_text
	_size_label.global_position = edge_world + Vector3(0, 0.8, 0)
	_size_label.visible = true


func _spawn_aoe(data: Dictionary) -> Node3D:
	var aoe_node = Node3D.new()
	add_child(aoe_node)

	var shape = int(data.get("shape", current_shape))
	var sz = float(data.get("size", _size))
	var dist = float(data.get("distance", _distance))
	var height_off = float(data.get("height_offset", 0))
	var oc = Vector2(float(data.get("origin_cell_x", 0)), float(data.get("origin_cell_y", 0)))
	var tc = Vector2(float(data.get("target_cell_x", 0)), float(data.get("target_cell_y", 0)))
	var md = Vector2(float(data.get("mouse_dir_x", 0)), float(data.get("mouse_dir_y", -1)))

	var mi = MeshInstance3D.new()
	mi.mesh = _make_mesh(shape, sz, dist)
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = SHAPE_COLORS[shape]
	mi.material_override = mat
	aoe_node.add_child(mi)

	var distance_ft = str(round(dist * 5.0)) + " ft"
	var size_ft = str(round(sz * 5.0)) + " ft"

	match shape:
		AoeShape.SPHERE:
			var pos = _cell_to_world(tc, height_off)
			aoe_node.global_position = pos
			_add_persistent_label(aoe_node, distance_ft, pos + Vector3(0, sz + 1.0, 0))
			_add_persistent_label(aoe_node, "R: " + size_ft, pos + Vector3(0, -0.3, 0))

		AoeShape.CUBE:
			var pos = _cell_to_world(tc, height_off)
			aoe_node.global_position = pos
			_add_persistent_label(aoe_node, distance_ft, pos + Vector3(0, sz * 0.5 + 1.0, 0))
			_add_persistent_label(aoe_node, "Side: " + size_ft, pos + Vector3(0, -0.3, 0))

		AoeShape.CONE:
			var ow = _cell_to_world(oc, height_off)
			var fw = _cell_to_world(tc, height_off)
			var ang = atan2(md.x, -md.y)
			aoe_node.global_position = ow
			aoe_node.global_rotation = Vector3(0, ang, 0)
			_add_persistent_label(aoe_node, distance_ft, fw + Vector3(0, 2.5, 0))
			_add_persistent_label(aoe_node, "W: " + size_ft, fw + Vector3(0, 1.0, 0))

		AoeShape.LINE:
			var ow = _cell_to_world(oc, height_off)
			var fw = _cell_to_world(tc, height_off)
			var mid = (ow + fw) * 0.5
			var ang = atan2(md.x, -md.y)
			aoe_node.global_position = mid
			aoe_node.global_rotation = Vector3(0, ang, 0)
			_add_persistent_label(aoe_node, distance_ft, fw + Vector3(0, 2.5, 0))
			_add_persistent_label(aoe_node, "W: " + size_ft, fw + Vector3(0, 1.0, 0))

	aoe_node.set_meta("aoe_data", data)
	return aoe_node


func _serialize_aoe(key: String) -> Dictionary:
	var node = world.placed_aoes.get(key) as Node3D
	if not node or not node.has_meta("aoe_data"):
		return {}
	return node.get_meta("aoe_data")


func _place():
	if not _placing:
		return

	var dir_n = _mouse_dir.normalized()
	if dir_n.length() < 0.5:
		dir_n = Vector2(0, -1)
	var target_cell = _origin_cell + dir_n * _distance

	var data = {
		"shape": current_shape, "size": _size, "distance": _distance,
		"height_offset": _height_offset,
		"origin_cell_x": _origin_cell.x, "origin_cell_y": _origin_cell.y,
		"target_cell_x": target_cell.x, "target_cell_y": target_cell.y,
		"mouse_dir_x": dir_n.x, "mouse_dir_y": dir_n.y,
	}

	var key = "aoe_%d" % _aoe_id_counter
	_aoe_id_counter += 1

	if multiplayer.is_server():
		world.rpc("sync_place_aoe", key, JSON.stringify(data))
	else:
		world.rpc_id(1, "request_place_aoe", key, JSON.stringify(data))

	_cancel()
	_update_hover_preview(get_viewport().get_mouse_position())


func _add_persistent_label(parent: Node3D, text: String, pos: Vector3):
	var label = Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.outline_modulate = Color(0, 0, 0)
	label.outline_size = 4
	parent.add_child(label)
	label.global_position = pos


func _handle_right_click_delete(mouse_pos: Vector2):
	_delete_nearest_aoe(mouse_pos)


func _get_token_at_mouse(mouse_pos: Vector2):
	var tm = world.get_node_or_null("TokenManager")
	if tm and tm.has_method("get_token_at_mouse"):
		return tm.get_token_at_mouse(mouse_pos)
	return null


func _delete_nearest_aoe(mouse_pos: Vector2):
	var hit = world.get_world_hit(mouse_pos)
	if not hit:
		return
	var world_pos = hit.position
	var nearest_key = null
	var nearest_dist = 9999.0
	for key in world.placed_aoes:
		var node = world.placed_aoes[key] as Node3D
		if not node:
			continue
		var d = node.global_position.distance_to(world_pos)
		if d < nearest_dist:
			nearest_dist = d
			nearest_key = key
	if nearest_key == null or nearest_dist > world.grid.cell_size * 2.0:
		return
	var aoe_node = world.placed_aoes[nearest_key] as Node3D
	if aoe_node:
		aoe_node.queue_free()
	world.placed_aoes.erase(nearest_key)

	if multiplayer.is_server():
		world.rpc("sync_remove_aoe", nearest_key)
	else:
		world.rpc_id(1, "request_remove_aoe", nearest_key)


func clear_all_aoes():
	if multiplayer.is_server():
		world._clear_aoes()
		world.rpc("sync_clear_all_aoes")
	else:
		world.rpc_id(1, "request_clear_all_aoes")


func _clear_all_placed():
	for key in world.placed_aoes.keys():
		var aoe_node = world.placed_aoes[key] as Node3D
		if aoe_node:
			aoe_node.queue_free()
	world.placed_aoes.clear()


func _cancel():
	_placing = false
	_dragging = false
	_height_offset = 0
	_last_hovered_cell = Vector2(-9999, -9999)
	_hide_preview()


func _cell_to_world(cell: Vector2, height: int = 0) -> Vector3:
	var grid = world.grid
	var cs = grid.cell_size
	var half = (grid.grid_size * cs) * 0.5
	var x = cell.x * cs - half + cs * 0.5
	var z = cell.y * cs - half + cs * 0.5
	return Vector3(x, 0.05 + height * cs, z)


func _update_origin_marker(pos: Vector3):
	_origin_marker.global_position = pos
	_origin_marker.visible = true


func _hide_preview():
	_preview_mesh.visible = false
	_ruler_line.visible = false
	_distance_label.visible = false
	_size_line.visible = false
	_size_handle.visible = false
	_size_label.visible = false
	_origin_marker.visible = false
