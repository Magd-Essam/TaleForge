extends Node

var world: Node
var codec: Node

var is_selecting: bool = false
var select_start: Vector2 = Vector2.ZERO
var select_end: Vector2 = Vector2.ZERO
var selected_cells: Array = []

var clipboard_data: Dictionary = {}
var has_clipboard: bool = false

var paste_preview: Node = null
var is_pasting: bool = false
var paste_rotation: float = 0.0
var paste_offset: Vector2 = Vector2.ZERO

var _selection_overlay: ColorRect = null
var _highlight_nodes: Array = []
var _prev_highlighted_piece_materials: Dictionary = {}

func _ready():
	world = get_parent()
	codec = $SlabCodec if has_node("SlabCodec") else null
	if not codec:
		codec = Node.new()
		codec.set_script(preload("res://Scripts/slab_codec.gd"))
		add_child(codec)

func start_selection(mouse_pos: Vector2):
	if world.is_mouse_over_ui():
		return
	is_selecting = true
	select_start = mouse_pos
	select_end = mouse_pos
	selected_cells.clear()
	_show_selection_rect()

func update_selection(mouse_pos: Vector2):
	if not is_selecting:
		return
	select_end = mouse_pos
	_update_selected_cells()
	_update_selection_rect()

func finish_selection() -> bool:
	if not is_selecting:
		return false
	is_selecting = false
	_update_selected_cells()
	_hide_selection_rect()
	if selected_cells.size() > 0:
		_show_toast("Selected " + str(selected_cells.size()) + " cells — Ctrl+C to copy")
	return selected_cells.size() > 0

func cancel_selection():
	is_selecting = false
	selected_cells.clear()
	_hide_selection_rect()

func _show_selection_rect():
	if not _selection_overlay:
		_selection_overlay = ColorRect.new()
		_selection_overlay.color = Color(0.3, 0.6, 1.0, 0.12)
		_selection_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ui_layer = world.get_node_or_null("UI")
		if ui_layer:
			ui_layer.add_child(_selection_overlay)

func _update_selection_rect():
	if not _selection_overlay:
		return
	var min_x = min(select_start.x, select_end.x)
	var min_y = min(select_start.y, select_end.y)
	var max_x = max(select_start.x, select_end.x)
	var max_y = max(select_start.y, select_end.y)
	_selection_overlay.position = Vector2(min_x, min_y)
	_selection_overlay.size = Vector2(max_x - min_x, max_y - min_y)

func _hide_selection_rect():
	if _selection_overlay:
		_selection_overlay.queue_free()
		_selection_overlay = null
	_clear_all_highlight()

func _update_selected_cells():
	selected_cells.clear()
	_clear_all_highlight()
	var world_start = _screen_to_world(select_start)
	var world_end = _screen_to_world(select_end)
	if world_start == null or world_end == null:
		return
	var min_x = min(world_start.x, world_end.x)
	var max_x = max(world_start.x, world_end.x)
	var min_z = min(world_start.z, world_end.z)
	var max_z = max(world_start.z, world_end.z)
	var min_cell = world.world_to_cell(min_x, min_z)
	var max_cell = world.world_to_cell(max_x, max_z)
	for x in range(int(min_cell.x), int(max_cell.x) + 1):
		for y in range(int(min_cell.y), int(max_cell.y) + 1):
			selected_cells.append(Vector2(x, y))
			_highlight_cell_contents(Vector2(x, y))

func _highlight_cell_contents(cell: Vector2):
	var half_grid = world.grid.cell_size * world.grid.grid_size / 2.0
	var cx = (cell.x * world.grid.cell_size) - half_grid + world.grid.cell_size / 2.0
	var cz = (cell.y * world.grid.cell_size) - half_grid + world.grid.cell_size / 2.0

	# Floor highlight
	var floor_key = "floor_" + str(int(cell.x)) + "_" + str(int(cell.y))
	if world.placed_pieces.has(floor_key):
		var mesh = MeshInstance3D.new()
		var plane = PlaneMesh.new()
		plane.size = Vector2(world.grid.cell_size * 0.95, world.grid.cell_size * 0.95)
		mesh.mesh = plane
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.6, 1.0, 0.3)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.render_priority = 3
		mesh.material_override = mat
		mesh.position = Vector3(cx, 0.1, cz)
		mesh.rotation_degrees = Vector3(-90, 0, 0)
		world.add_child(mesh)
		_highlight_nodes.append(mesh)

	# Wall highlights
	for dir in ["N", "S", "E", "W"]:
		var wall_key = str(int(cell.x)) + "_" + str(int(cell.y)) + "_" + dir
		if world.placed_pieces.has(wall_key):
			var wall = world.placed_pieces[wall_key]
			var box = MeshInstance3D.new()
			box.mesh = BoxMesh.new()
			var wall_pos = _wall_position(cell, dir)
			box.mesh.size = Vector3(world.grid.cell_size * 0.08, 0.5, world.grid.cell_size * 0.8)
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.3, 0.6, 1.0, 0.35)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.render_priority = 3
			box.material_override = mat
			box.position = wall_pos + Vector3(0, 0.02, 0)
			world.add_child(box)
			_highlight_nodes.append(box)

func _clear_all_highlight():
	for node in _highlight_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_highlight_nodes.clear()


# ── screen-to-world raycast ─────────────────────────────────────────────────

func _screen_to_world(screen_pos: Vector2) -> Vector3:
	var cam = world.get_node("Camera/Camera3D")
	var ray_origin = cam.project_ray_origin(screen_pos)
	var ray_end = ray_origin + cam.project_ray_normal(screen_pos) * 1000
	var space = world.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	var result = space.intersect_ray(query)
	if not result.is_empty():
		return result.position
	return Vector3(ray_origin.x, 0, ray_origin.z)


# ── copy ─────────────────────────────────────────────────────────────────────

func copy_selection():
	var tile_keys = []
	var wall_keys = []
	var prop_keys = []
	for cell in selected_cells:
		var floor_key = "floor_" + str(int(cell.x)) + "_" + str(int(cell.y))
		if world.placed_pieces.has(floor_key):
			tile_keys.append(floor_key)
		for dir in ["N", "S", "E", "W"]:
			var wall_key = str(int(cell.x)) + "_" + str(int(cell.y)) + "_" + dir
			if world.placed_pieces.has(wall_key):
				wall_keys.append(wall_key)
		var prop_key = "prop_" + str(int(cell.x)) + "_" + str(int(cell.y))
		if world.placed_props.has(prop_key):
			prop_keys.append(prop_key)
	var raw = codec.slab_from_selection(tile_keys, wall_keys, prop_keys, world)
	clipboard_data = raw
	has_clipboard = true
	var encoded = codec.encode_slab(raw["tiles"], raw["walls"], raw["props"])
	DisplayServer.clipboard_set(encoded)
	_show_toast("Copied " + str(selected_cells.size()) + " cells")


# ── paste ────────────────────────────────────────────────────────────────────

func start_paste():
	if not has_clipboard:
		return
	is_pasting = true
	paste_rotation = 0.0
	paste_offset = Vector2.ZERO
	_show_toast("Paste mode — click to place, R to rotate, Esc to cancel")

func update_paste_preview(mouse_pos: Vector2):
	if not is_pasting or not has_clipboard:
		return
	var result = world.get_world_hit(mouse_pos)
	if not result:
		return
	_clear_paste_preview()
	var cell_pos = world.world_to_cell(result.position.x, result.position.z)
	paste_offset = cell_pos
	_show_paste_preview(cell_pos)

func place_paste(mouse_pos: Vector2):
	if not is_pasting or not has_clipboard:
		return
	var result = world.get_world_hit(mouse_pos)
	if not result:
		return
	var cell_pos = world.world_to_cell(result.position.x, result.position.z)
	_paste_at(cell_pos)
	_clear_paste_preview()
	is_pasting = false
	_show_toast("Pasted")

func cancel_paste():
	_clear_paste_preview()
	is_pasting = false

func rotate_paste():
	paste_rotation += 90.0


func _show_paste_preview(base_cell: Vector2):
	if not paste_preview:
		paste_preview = Node3D.new()
		paste_preview.name = "PastePreview"
		world.add_child(paste_preview)

	for tile in clipboard_data.get("tiles", []):
		var offset = Vector2(tile["cell_x"], tile["cell_y"])
		var target = base_cell + _rotate_offset(offset, paste_rotation)
		var key = "floor_" + str(int(target.x)) + "_" + str(int(target.y))
		if world.placed_pieces.has(key):
			continue
		var type_name = tile.get("type", "floor_stone")
		var preview = _make_preview_piece(type_name, target)
		if preview:
			preview.position.y += 0.05
			paste_preview.add_child(preview)

	for wall in clipboard_data.get("walls", []):
		var offset = Vector2(wall["cell_x"], wall["cell_y"])
		var target = base_cell + _rotate_offset(offset, paste_rotation)
		var dir = _rotate_dir(wall["dir"], paste_rotation)
		var key = str(int(target.x)) + "_" + str(int(target.y)) + "_" + dir
		if world.placed_pieces.has(key):
			continue
		var preview = _make_preview_wall(target, dir)
		if preview:
			paste_preview.add_child(preview)

func _make_preview_piece(type_name: String, cell_pos: Vector2) -> MeshInstance3D:
	var half_grid = world.grid.cell_size * world.grid.grid_size / 2.0
	var cx = (cell_pos.x * world.grid.cell_size) - half_grid + world.grid.cell_size / 2.0
	var cz = (cell_pos.y * world.grid.cell_size) - half_grid + world.grid.cell_size / 2.0
	var scene = world.pieces.get(type_name) if world.pieces.has(type_name) else null
	var instance: MeshInstance3D
	if scene:
		instance = scene.instantiate()
		if instance.has_method("init"):
			instance.init(cell_pos, world.grid.cell_size, world.grid.grid_size)
	else:
		instance = MeshInstance3D.new()
		instance.mesh = PlaneMesh.new()
		instance.mesh.size = Vector2(world.grid.cell_size * 0.9, world.grid.cell_size * 0.9)
		instance.position = Vector3(cx, 0.02, cz)
		instance.rotation_degrees = Vector3(-90, 0, 0)
	instance.name = "PastePreviewTile"
	_set_preview_transparent(instance)
	return instance

func _make_preview_wall(cell_pos: Vector2, dir: String) -> MeshInstance3D:
	var pos = _wall_position(cell_pos, dir)
	var scene = world.pieces.get("wall")
	var instance: MeshInstance3D
	if scene:
		instance = scene.instantiate()
		if instance.has_method("init"):
			instance.init(cell_pos, dir, world.grid.cell_size, world.grid.grid_size)
	else:
		instance = MeshInstance3D.new()
		instance.mesh = BoxMesh.new()
		instance.mesh.size = Vector3(world.grid.cell_size * 0.08, 0.5, world.grid.cell_size * 0.8)
		instance.position = pos
	instance.name = "PastePreviewWall"
	_set_preview_transparent(instance)
	return instance

func _set_preview_transparent(instance: MeshInstance3D):
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.8, 0.3, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 2
	instance.material_override = mat

func _clear_paste_preview():
	if paste_preview:
		paste_preview.queue_free()
		paste_preview = null


# ── actual placement ─────────────────────────────────────────────────────────

func _paste_at(base_cell: Vector2):
	var tiles_data = clipboard_data.get("tiles", [])
	var walls_data = clipboard_data.get("walls", [])
	var props_data = clipboard_data.get("props", [])

	for tile in tiles_data:
		var offset = Vector2(tile["cell_x"], tile["cell_y"])
		var target = base_cell + _rotate_offset(offset, paste_rotation)
		var key = "floor_" + str(int(target.x)) + "_" + str(int(target.y))
		if world.placed_pieces.has(key):
			continue
		var type_name = tile.get("type", "floor_stone")
		var fm = world.floor_manager
		var f = fm.current_floor if (fm and fm.build_mode) else 0
		world._sync_place_piece(key, type_name, int(target.x), int(target.y), "", "", f)

	for wall in walls_data:
		var offset = Vector2(wall["cell_x"], wall["cell_y"])
		var target = base_cell + _rotate_offset(offset, paste_rotation)
		var dir = _rotate_dir(wall["dir"], paste_rotation)
		var key = str(int(target.x)) + "_" + str(int(target.y)) + "_" + dir
		if world.placed_pieces.has(key):
			continue
		var fm = world.floor_manager
		var f = fm.current_floor if (fm and fm.build_mode) else 0
		world._sync_place_piece(key, "wall", int(target.x), int(target.y), dir, "", f)

	for prop in props_data:
		var target = base_cell
		var prop_key = "prop_" + str(int(target.x)) + "_" + str(int(target.y))
		if world.placed_props.has(prop_key):
			continue
		world._sync_place_prop(prop_key, {"name": "Prop", "model_path": prop.get("model_path", "")}, int(target.x), int(target.y))


# ── rotation helpers ─────────────────────────────────────────────────────────

func _rotate_offset(offset: Vector2, degrees: float) -> Vector2:
	if degrees == 0:
		return offset
	var rad = deg_to_rad(degrees)
	var cos_v = cos(rad)
	var sin_v = sin(rad)
	return Vector2(offset.x * cos_v - offset.y * sin_v, offset.x * sin_v + offset.y * cos_v).round()

func _rotate_dir(dir: String, degrees: float) -> String:
	var dirs = ["N", "E", "S", "W"]
	var idx = dirs.find(dir)
	if idx < 0:
		return dir
	var steps = int(round(degrees / 90.0))
	return dirs[(idx + steps) % 4]

func _wall_position(cell_pos: Vector2, dir: String) -> Vector3:
	var half_grid = world.grid.cell_size * world.grid.grid_size / 2.0
	var cx = (cell_pos.x * world.grid.cell_size) - half_grid + world.grid.cell_size / 2.0
	var cz = (cell_pos.y * world.grid.cell_size) - half_grid + world.grid.cell_size / 2.0
	match dir:
		"N": return Vector3(cx, 0.25, cz - world.grid.cell_size / 2.0)
		"S": return Vector3(cx, 0.25, cz + world.grid.cell_size / 2.0)
		"E": return Vector3(cx + world.grid.cell_size / 2.0, 0.25, cz)
		"W": return Vector3(cx - world.grid.cell_size / 2.0, 0.25, cz)
	return Vector3(cx, 0.25, cz)


# ── toast notification ───────────────────────────────────────────────────────

func _show_toast(msg: String):
	var label = Label.new()
	label.text = msg
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1, 1, 0))
	label.add_theme_font_size_override("font_size", 24)
	label.position = Vector2(300, 150)
	label.size = Vector2(400, 40)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.modulate = Color(1, 1, 0, 1)
	var ui = world.get_node_or_null("UI")
	if not ui:
		return
	ui.add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "modulate", Color(1, 1, 0, 0), 1.5).set_ease(Tween.EASE_OUT)
	tween.tween_callback(label.queue_free)
