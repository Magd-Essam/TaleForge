extends Node3D
class_name ModularTerraformManager

const ModularBlock = preload("res://Scripts/block_tile.gd")
const MAX_STACK_HEIGHT := 12
const TOGGLE_KEY := KEY_T
const HIGHLIGHT_SAFE_RENDER_PRIORITY_MAX := 127
const HIGHLIGHT_SHADER: Shader = preload("res://terraform/highlight_plane.gdshader")
const HIGHLIGHT_RENDER_PRIORITY := 126

# Highlight colours per mode
const HIGHLIGHT_COLOR        : Color = Color(0.0,  0.85, 1.0,  0.35)   # place  — blue
const HIGHLIGHT_COLOR_DRAG   : Color = Color(1.0,  0.6,  0.0,  0.45)   # drag   — orange
const HIGHLIGHT_COLOR_REMOVE : Color = Color(1.0,  0.2,  0.1,  0.45)   # remove — red
const HIGHLIGHT_COLOR_LIMIT  : Color = Color(1.0,  0.2,  0.1,  0.6)    # stack full flash

@export var custom_block_scene: PackedScene

var stack_map: Dictionary = {}
var is_active: bool = false

# Sub-mode: what a left-click does
enum TerraMode { PLACE, DRAG, REMOVE }
var terra_mode: TerraMode = TerraMode.PLACE

@onready var world_node: Node3D = get_parent()
@onready var grid               = world_node.get_node("grid")
@onready var terrain_holder     = world_node.get_node("TerrainHolder")
@onready var token_holder       = world_node.get_node_or_null("TokenHolder")

var block_height     := 1.0
var dragging_block   : ModularBlock = null
var drag_origin_cell : Vector2      = Vector2.ZERO
var highlight_plane  : MeshInstance3D = null
var highlight_material : ShaderMaterial = null
var _last_highlight_cell : Vector2 = Vector2(-9999, -9999)

# Signal so library_panel can update button labels when state changes
signal mode_changed(is_active: bool, terra_mode: int)


# ─── lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	if grid:
		grid.visible = true
		block_height = grid.cell_size
	else:
		push_warning("[Terraform] Grid node missing — defaulting block height to 1.")
	set_process(true)
	_build_stack_map_from_existing_blocks()
	_create_highlight_plane()


# ─── input ────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	# Keyboard toggle / escape — always listened to
	if event is InputEventKey and not event.echo and event.pressed:
		if event.keycode == TOGGLE_KEY:
			toggle_active()
			get_viewport().set_input_as_handled()
			return
		if is_active and event.keycode == KEY_ESCAPE:
			_set_active(false)
			get_viewport().set_input_as_handled()
			return

	# Everything else only matters when active
	if not is_active:
		return
	if not _can_process_input():
		return

	if event is InputEventMouseMotion:
		if dragging_block:
			_update_drag_position(event.position)
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _handle_left_press(event):
					get_viewport().set_input_as_handled()
			else:
				if dragging_block:
					_handle_left_release(event)
					get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not dragging_block:
			_handle_right_click(event)
			get_viewport().set_input_as_handled()


# ─── public API (called by library_panel UI buttons) ─────────────────────────

func toggle_active() -> void:
	_set_active(not is_active)

func set_terra_mode(mode: TerraMode) -> void:
	terra_mode = mode
	_last_highlight_cell = Vector2(-9999, -9999)
	_update_highlight_color()
	emit_signal("mode_changed", is_active, terra_mode)


# ─── private state ────────────────────────────────────────────────────────────

func _set_active(on: bool) -> void:
	is_active = on
	_hide_highlight()
	_last_highlight_cell = Vector2(-9999, -9999)
	if not on and dragging_block:
		# Cancel any drag in progress when terraform is turned off
		_insert_block(drag_origin_cell, dragging_block)
		_reset_drag_state()
	emit_signal("mode_changed", is_active, terra_mode)

func _update_highlight_color() -> void:
	if not highlight_material:
		return
	match terra_mode:
		TerraMode.PLACE:
			highlight_material.set_shader_parameter("highlight_color", HIGHLIGHT_COLOR)
		TerraMode.DRAG:
			highlight_material.set_shader_parameter("highlight_color", HIGHLIGHT_COLOR_DRAG)
		TerraMode.REMOVE:
			highlight_material.set_shader_parameter("highlight_color", HIGHLIGHT_COLOR_REMOVE)

func _can_process_input() -> bool:
	if not world_node:
		return false
	if world_node.has_method("is_mouse_over_ui") and world_node.is_mouse_over_ui():
		return false
	return true


# ─── raycasting helpers ───────────────────────────────────────────────────────

func _get_hovered_cell(mouse_pos: Vector2) -> Variant:
	var result :Variant = _get_hovered_result(mouse_pos)
	if not result:
		return null
	if not world_node.has_method("world_to_cell"):
		return null
	return world_node.world_to_cell(result.position.x, result.position.z)

func _get_hovered_result(mouse_pos: Vector2) -> Variant:
	if not world_node or not world_node.has_method("get_world_hit"):
		return null
	var result = world_node.get_world_hit(mouse_pos)
	if not result or not result.has("position"):
		return null
	return result


# ─── block placement / removal ───────────────────────────────────────────────

func place_block(cell_pos: Vector2) -> void:
	var block = ModularBlock.new()
	if custom_block_scene:
		block.apply_custom_model(custom_block_scene)
	block.configure(block_height)
	if terrain_holder:
		terrain_holder.add_child(block)
	else:
		add_child(block)
	if not _insert_block(cell_pos, block):
		block.queue_free()
		_show_limit_flash()
	else:
		_update_tokens_at_cell(cell_pos)

func remove_block(cell_pos: Vector2) -> void:
	var key = _cell_key(cell_pos)
	if not stack_map.has(key):
		return
	var column: Array = stack_map[key]
	if column.is_empty():
		stack_map.erase(key)
		return
	var block = column.pop_back()
	block.queue_free()
	if column.is_empty():
		stack_map.erase(key)
	else:
		stack_map[key] = column
		_refresh_column_overlay(column)
	_update_tokens_at_cell(cell_pos)


# ─── input handlers ───────────────────────────────────────────────────────────

func _handle_left_press(event: InputEventMouseButton) -> bool:
	var hit_result = _get_hovered_result(event.position)
	if not hit_result:
		return false
	var cell_pos: Vector2 = world_node.world_to_cell(
		hit_result.position.x, hit_result.position.z
	)
	match terra_mode:
		TerraMode.PLACE:
			place_block(cell_pos)
			return true
		TerraMode.DRAG:
			# Drag mode: any left click picks up the top block, no normal-angle check needed
			_attempt_start_drag(cell_pos, event.position)
			return true
		TerraMode.REMOVE:
			remove_block(cell_pos)
			return true
	return false

func _handle_right_click(_event: InputEventMouseButton) -> void:
	var cell_pos = _get_hovered_cell(_event.position)
	if not cell_pos:
		return
	# Right click always removes as a quick shortcut in any sub-mode
	remove_block(cell_pos)

func _attempt_start_drag(cell_pos: Vector2, mouse_pos: Vector2) -> bool:
	var key = _cell_key(cell_pos)
	var column: Array = stack_map.get(key, [])
	if column.size() == 0:
		return false
	dragging_block = column.pop_back()
	drag_origin_cell = cell_pos
	if column.is_empty():
		stack_map.erase(key)
	else:
		stack_map[key] = column
		_refresh_column_overlay(column)
	_update_drag_position(mouse_pos)
	return true

func _handle_left_release(event: InputEventMouseButton) -> void:
	if not dragging_block:
		return
	var cell_pos = _get_hovered_cell(event.position)
	var dropped := false
	if cell_pos:
		dropped = _insert_block(cell_pos, dragging_block)
		if dropped:
			_update_tokens_at_cell(cell_pos)
	if not dropped:
		# Put it back where it came from
		dropped = _insert_block(drag_origin_cell, dragging_block)
		if dropped:
			_update_tokens_at_cell(drag_origin_cell)
	if not dropped:
		dragging_block.queue_free()
	_reset_drag_state()

func _reset_drag_state() -> void:
	dragging_block = null
	drag_origin_cell = Vector2.ZERO

func _update_drag_position(mouse_pos: Vector2) -> void:
	if not dragging_block:
		return
	var cell_pos = _get_hovered_cell(mouse_pos)
	if not cell_pos:
		return
	var column: Array = stack_map.get(_cell_key(cell_pos), [])
	dragging_block.global_position = _cell_center(cell_pos, column.size())


# ─── stack map helpers ────────────────────────────────────────────────────────

func _insert_block(cell_pos: Vector2, block: ModularBlock) -> bool:
	var key = _cell_key(cell_pos)
	var column: Array = stack_map.get(key, [])
	if column.size() >= MAX_STACK_HEIGHT:
		return false
	block.global_position = _cell_center(cell_pos, column.size())
	column.append(block)
	stack_map[key] = column
	_refresh_column_overlay(column)
	return true

func _refresh_column_overlay(column: Array) -> void:
	if column.is_empty():
		return
	var top_index := column.size() - 1
	for i in column.size():
		var block := column[i] as ModularBlock
		if block:
			block.set_grid_overlay_visible(i == top_index)

func get_stack_height(cell_pos: Vector2) -> float:
	var column: Array = stack_map.get(_cell_key(cell_pos), [])
	return float(column.size()) * block_height

func _update_tokens_at_cell(cell_pos: Vector2) -> void:
	if not token_holder:
		return
	var new_height := get_stack_height(cell_pos)
	if world_node and world_node.has_method("get_surface_height_at"):
		var cell_center = _cell_ground_position(cell_pos)
		new_height = max(new_height, world_node.get_surface_height_at(cell_center.x, cell_center.z))
	for token in token_holder.get_children():
		if not token or not world_node or not world_node.has_method("world_to_cell"):
			continue
		var token_cell :Vector2= world_node.world_to_cell(token.position.x, token.position.z)
		if token_cell == cell_pos:
			if token.has_method("set_terrain_height"):
				token.set_terrain_height(new_height)
			else:
				token.position.y = new_height

func _cell_ground_position(cell_pos: Vector2) -> Vector3:
	if not grid:
		return Vector3.ZERO
	var total  := float(grid.grid_size) * block_height
	var half   := total / 2.0
	return Vector3(
		(cell_pos.x * block_height) - half + block_height * 0.5,
		0.0,
		(cell_pos.y * block_height) - half + block_height * 0.5
	)

func _cell_center(cell_pos: Vector2, stack_index: int) -> Vector3:
	var base := _cell_ground_position(cell_pos)
	base.y    = (float(stack_index) + 0.5) * block_height
	return base

func _cell_key(cell_pos: Vector2) -> String:
	return "%d_%d" % [int(cell_pos.x), int(cell_pos.y)]

func _build_stack_map_from_existing_blocks() -> void:
	stack_map.clear()
	if not terrain_holder or not world_node or not world_node.has_method("world_to_cell"):
		return
	var temp_columns: Dictionary = {}
	for child in terrain_holder.get_children():
		if child is ModularBlock:
			var cell_pos :Vector2= world_node.world_to_cell(child.global_position.x, child.global_position.z)
			var key      := _cell_key(cell_pos)
			if not temp_columns.has(key):
				temp_columns[key] = []
			temp_columns[key].append(child)
	for key in temp_columns.keys():
		var column: Array = temp_columns[key]
		column.sort_custom(func(a, b): return a.global_position.y < b.global_position.y)
		stack_map[key] = column
		_refresh_column_overlay(column)


# ─── highlight plane ──────────────────────────────────────────────────────────

func _show_limit_flash() -> void:
	if not highlight_material:
		return
	highlight_material.set_shader_parameter("highlight_color", HIGHLIGHT_COLOR_LIMIT)
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(highlight_material):
		_update_highlight_color()

func _create_highlight_plane() -> void:
	if highlight_plane:
		return
	highlight_plane = MeshInstance3D.new()
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2(block_height, block_height)
	highlight_plane.mesh = plane_mesh
	highlight_material = ShaderMaterial.new()
	highlight_material.shader = HIGHLIGHT_SHADER
	highlight_material.render_priority = min(HIGHLIGHT_RENDER_PRIORITY, HIGHLIGHT_SAFE_RENDER_PRIORITY_MAX)
	highlight_material.set_shader_parameter("highlight_color", HIGHLIGHT_COLOR)
	highlight_plane.material_override = highlight_material
	highlight_plane.visible = false
	add_child(highlight_plane)   # attached to manager, not terrain_holder

func _show_highlight(cell_pos: Vector2, stack_height: int) -> void:
	if not highlight_plane:
		return
	var base := _cell_ground_position(cell_pos)
	highlight_plane.global_position = Vector3(base.x, float(stack_height) * block_height + 0.01, base.z)
	var pm := highlight_plane.mesh as PlaneMesh
	if pm:
		pm.size = Vector2(block_height, block_height)
	highlight_plane.visible = true

func _hide_highlight() -> void:
	if highlight_plane:
		highlight_plane.visible = false

func _update_highlight_visual() -> void:
	if not highlight_plane or not grid or not is_active:
		_hide_highlight()
		return
	var cell_pos = _get_hovered_cell(get_viewport().get_mouse_position())
	if not cell_pos:
		_hide_highlight()
		_last_highlight_cell = Vector2(-9999, -9999)
		return
	if cell_pos == _last_highlight_cell:
		return
	_last_highlight_cell = cell_pos
	var column: Array = stack_map.get(_cell_key(cell_pos), [])
	_show_highlight(cell_pos, column.size())

func _process(_delta: float) -> void:
	_update_highlight_visual()
