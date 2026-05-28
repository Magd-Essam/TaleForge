extends Node

# ─────────────────────────────────────────────────────────────────────────────
# input_handler.gd
#
# Routes all raw input to the correct handler.
# Rules:
#   RIGHT click → context menu only (tokens first, then walls)
#   LEFT click  → depends on active tool:
#                   MOVE    → select token if clicked, then start drag
#                   PLACE   → place wall / floor / token
#                   DEMOLISH→ remove piece
#   Mouse motion → drag preview OR hover highlight
#   Scroll wheel → rotate selected token (MOVE tool only)
#   Shift key    → toggle snap
# ─────────────────────────────────────────────────────────────────────────────

var world : Node


func _ready():
	world = get_parent()


# ── accessors (never cached — avoids init-order null crashes) ─────────────────
func _sel(): return world.selection_manager
func _tp():  return world.terrain_placer
func _pp():  return world.prop_placer
func _tm():  return world.token_manager
func _dc():  return world.drag_controller
func _rm():  return world.ruler_manager


# ── main input entry ──────────────────────────────────────────────────────────

func _input(event: InputEvent):
	# Terraform mode owns all input while active — step aside completely
	if world.terraform_manager and world.terraform_manager.is_active:
		return

	# AoE mode owns all input while active — consume scroll immediately so
	# camera._unhandled_input never sees it, then step aside for AoeManager
	if world.aoe_manager and world.aoe_manager.is_active:
		if event is InputEventMouseButton:
			var b = event.button_index
			if b == MOUSE_BUTTON_WHEEL_UP or b == MOUSE_BUTTON_WHEEL_DOWN:
				get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventKey:
		_handle_key(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _unhandled_input(event: InputEvent):
	if event is InputEventKey:
		_handle_key(event)

# ── mouse button ──────────────────────────────────────────────────────────────

func _handle_mouse_button(event: InputEventMouseButton):

	# ── RIGHT CLICK: cancel drag first, then context menu ─────────────────────
	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		get_viewport().set_input_as_handled()
		if world.is_mouse_over_ui():
			return
		if _dc().is_dragging:
			_dc().cancel_drag()
		# RULER tool: right-click clears measurement, don't open context menu
		if _sel().current_tool == _sel().Tool.RULER:
			if _rm(): _rm().clear()
			return
		_handle_right_click(event.position)
		return

	# ── LEFT CLICK ────────────────────────────────────────────────────────────
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if world.is_mouse_over_ui():
				return
			_handle_left_press(event.position)
		else:
			# Finish slab selection on release
			if _sel().current_tool == _sel().Tool.SELECT and world.slab_manager and world.slab_manager.is_selecting:
				world.slab_manager.finish_selection()
				return
			# Always finish drags even if cursor is over UI
			if _dc().is_dragging:
				_dc().finish_drag(event.position)
		return

	# ── CTRL+SCROLL: resize selected prop or token ────────────────────────
	if event.ctrl_pressed and _sel().selected_prop and _sel().selected_prop.has_method("apply_scale"):
		var step = 0.1
		var p = _sel().selected_prop
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			p.apply_scale(snappedf(p.scale_multiplier + step, 0.1))
			get_viewport().set_input_as_handled()
			var key = world.find_prop_key(p)
			if key != "":
				world._sync_scale_prop(key, p.scale_multiplier)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			p.apply_scale(max(0.1, snappedf(p.scale_multiplier - step, 0.1)))
			get_viewport().set_input_as_handled()
			var key = world.find_prop_key(p)
			if key != "":
				world._sync_scale_prop(key, p.scale_multiplier)
			return

	if event.ctrl_pressed and _tm().selected_token and _tm().selected_token.has_method("apply_scale"):
		var step = 0.1
		var t = _tm().selected_token
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			t.apply_scale(snappedf(t.scale_multiplier + step, 0.1))
			get_viewport().set_input_as_handled()
			var key = world.find_token_key(t)
			if key != "":
				world._sync_update_token_field(key, "scale_multiplier", t.scale_multiplier)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			t.apply_scale(max(0.1, snappedf(t.scale_multiplier - step, 0.1)))
			get_viewport().set_input_as_handled()
			var key = world.find_token_key(t)
			if key != "":
				world._sync_update_token_field(key, "scale_multiplier", t.scale_multiplier)
			return

	# ── SCROLL WHEEL: rotate/height selected prop (MOVE tool only) ─────────
	if _sel().current_tool == _sel().Tool.MOVE and _sel().selected_prop:
		if event.shift_pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_sel().selected_prop.position.y += 0.25
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_sel().selected_prop.position.y -= 0.25
				get_viewport().set_input_as_handled()
				return
		else:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_sel().selected_prop.rotation.y += deg_to_rad(22.5)
				_sel().selected_prop.rotation.y = wrapf(_sel().selected_prop.rotation.y, -PI, PI)
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_sel().selected_prop.rotation.y -= deg_to_rad(22.5)
				_sel().selected_prop.rotation.y = wrapf(_sel().selected_prop.rotation.y, -PI, PI)
				get_viewport().set_input_as_handled()
				return

	# ── SCROLL WHEEL: rotate selected token (MOVE tool only) ─────────────────
	if _sel().current_tool == _sel().Tool.MOVE and _tm().selected_token:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_tm().selected_token.rotate_by(-22.5)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_tm().selected_token.rotate_by(22.5)
			get_viewport().set_input_as_handled()

	# ── SCROLL WHEEL: adjust ruler height ──────────────────────────────────
	if _sel().current_tool == _sel().Tool.RULER:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if _rm(): _rm().adjust_height(1)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _rm(): _rm().adjust_height(-1)
			get_viewport().set_input_as_handled()
			return


# ── right click ───────────────────────────────────────────────────────────────

func _handle_right_click(mouse_pos: Vector2):
	# Tokens take priority over walls
	var token = _tm().get_token_at_mouse(mouse_pos)
	if token:
		world.context_menu.show_at(mouse_pos, token)
		return

	# Check for a wall near the click point
	var result = world.get_world_hit(mouse_pos)
	if not result:
		return

	var cell_pos = world.world_to_cell(result.position.x, result.position.z)
	for check_cell in [
		cell_pos,
		cell_pos + Vector2( 1,  0),
		cell_pos + Vector2(-1,  0),
		cell_pos + Vector2( 0,  1),
		cell_pos + Vector2( 0, -1),
	]:
		for dir in ["N", "S", "E", "W"]:
			var key = str(check_cell.x) + "_" + str(check_cell.y) + "_" + dir
			if world.placed_pieces.has(key):
				var wall = world.placed_pieces[key]
				var dist = Vector2(result.position.x, result.position.z).distance_to(
					Vector2(wall.position.x, wall.position.z)
				)
				if dist < 0.5:
					world.context_menu.show_at(mouse_pos, wall)
					return


# ── left press ────────────────────────────────────────────────────────────────

func _is_gm() -> bool:
	var mp = multiplayer.multiplayer_peer
	return not mp or multiplayer.is_server()


func _handle_left_press(mouse_pos: Vector2):
	var tool = _sel().current_tool

	# SELECT tool — start rubber-band selection ──────────────────────────────
	if tool == _sel().Tool.SELECT:
		if world.slab_manager:
			world.slab_manager.start_selection(mouse_pos)
		return

	# MOVE tool ────────────────────────────────────────────────────────────────
	if tool == _sel().Tool.MOVE:
		_dc().start_drag(mouse_pos)
		return

	# PLACE tool (GM only) ────────────────────────────────────────────────────
	if tool == _sel().Tool.PLACE:
		if not _is_gm():
			return
		# If pasting, place the slab instead
		if world.slab_manager and world.slab_manager.is_pasting:
			world.slab_manager.place_paste(mouse_pos)
			return
		var piece = _sel().selected_piece
		if piece == "wall" or piece == "wall_custom":
			_tp().place_wall_at_mouse(mouse_pos)
		elif piece == "token":
			_tm().place_token_at_mouse(mouse_pos)
		elif piece == "prop":
			_pp().place_prop_at_mouse(mouse_pos)
		else:
			_tp().place_floor_at_mouse(mouse_pos)
		return

	# DEMOLISH tool (GM only) ─────────────────────────────────────────────────
	if tool == _sel().Tool.DEMOLISH:
		if not _is_gm():
			return
		_tp().remove_at_mouse(mouse_pos)
		return

	# RULER tool ───────────────────────────────────────────────────────────────
	if tool == _sel().Tool.RULER:
		if _rm(): _rm().handle_left_press(mouse_pos)
		return


# ── keyboard ──────────────────────────────────────────────────────────────────

func _handle_key(event: InputEventKey):
	# Shift — toggle on both press AND release (temporary snap inversion while held)
	if event.keycode == KEY_SHIFT or event.physical_keycode == KEY_SHIFT:
		world.snap_enabled = not world.snap_enabled
		var snap_btn = world.library_panel.get_node_or_null("SnapBtn")
		if snap_btn:
			snap_btn.text = "Snap " + ("ON" if world.snap_enabled else "OFF")
		get_viewport().set_input_as_handled()
		return

	# For all other keys: process on press only, skip repeats and releases
	if not event.pressed or event.is_echo():
		return

	var kc = event.keycode
	if kc == KEY_NONE:
		kc = event.physical_keycode
	if kc == KEY_NONE:
		kc = event.unicode

	# Ignore if a text input field is focused (so typing in fields works)
	if world.is_text_input_focused():
		return

	# Ctrl+C — copy slab selection
	if kc == KEY_C and event.ctrl_pressed:
		if world.slab_manager and world.slab_manager.selected_cells.size() > 0:
			world.slab_manager.copy_selection()
		get_viewport().set_input_as_handled()
		return

	# Ctrl+V — paste slab
	if kc == KEY_V and event.ctrl_pressed:
		if world.slab_manager and world.slab_manager.has_clipboard:
			world.slab_manager.start_paste()
		get_viewport().set_input_as_handled()
		return

	# R — rotate slab paste
	if kc == KEY_R:
		if world.slab_manager and world.slab_manager.is_pasting:
			world.slab_manager.rotate_paste()
		get_viewport().set_input_as_handled()
		return

	# Escape — exit menu / cancel paste / reconnect cancel
	if kc == KEY_ESCAPE:
		# AoE just handled ESC this frame (deactivated itself) — don't open exit menu
		if world.aoe_manager and world.aoe_manager.escape_handled_this_frame:
			get_viewport().set_input_as_handled()
			return
		# Reconnecting — stop and go to main menu
		var nm = world.network_manager
		if nm and nm.is_reconnecting:
			nm.stop_reconnect()
			GameManager.return_message = "Cancelled reconnection"
			get_tree().change_scene_to_file("res://ui/main_menu.tscn")
			return
		var exit_menu = world.get_node_or_null("UI/ExitMenu")
		var settings_panel = world.get_node_or_null("UI/SettingsPanel")
		if exit_menu and exit_menu.visible:
			exit_menu.hide_menu()
		elif settings_panel and settings_panel.visible:
			settings_panel.visible = false
		elif world.slab_manager and world.slab_manager.is_pasting:
			world.slab_manager.cancel_paste()
		elif world.slab_manager and world.slab_manager.is_selecting:
			world.slab_manager.cancel_selection()
		else:
			if exit_menu:
				exit_menu.show_menu()
		get_viewport().set_input_as_handled()
		return

	# B — toggle build mode
	if kc == KEY_B:
		if world.floor_manager:
			world.floor_manager.toggle_build_mode()
		get_viewport().set_input_as_handled()
		return

	# N / P — switch floor levels
	if kc == KEY_N:
		if world.floor_manager:
			world.floor_manager.next_floor()
		get_viewport().set_input_as_handled()
		return
	if kc == KEY_P:
		if world.floor_manager:
			world.floor_manager.prev_floor()
		get_viewport().set_input_as_handled()
		return

	# M — toggle movement grid
	if kc == KEY_M:
		if world.movement_controller:
			world.movement_controller.toggle_movement_grid()
		get_viewport().set_input_as_handled()
		return


# ── mouse motion ──────────────────────────────────────────────────────────────

func _handle_mouse_motion(event: InputEventMouseMotion):
	var tool = _sel().current_tool

	# Drag preview takes priority — never block during active drag
	if tool == _sel().Tool.MOVE and _dc().is_dragging and _dc().dragged_piece:
		_dc().preview_drag(event.position)
		return

	# SELECT tool — update rubber-band selection
	if tool == _sel().Tool.SELECT:
		if world.slab_manager and world.slab_manager.is_selecting:
			world.slab_manager.update_selection(event.position)
		return

	# Paste preview
	if world.slab_manager and world.slab_manager.is_pasting:
		world.slab_manager.update_paste_preview(event.position)
		return

	# Non-drag mouse motion blocked when over UI
	if world.is_mouse_over_ui():
		return

	# RULER tool: update live preview
	if tool == _sel().Tool.RULER:
		if _rm(): _rm().update_preview(event.position)
		return

	# Hover highlight in MOVE, PLACE, and DEMOLISH modes
	if tool == _sel().Tool.MOVE or tool == _sel().Tool.PLACE or tool == _sel().Tool.DEMOLISH:
		_tp().update_hover(event.position)
	if tool == _sel().Tool.MOVE:
		_tm().update_token_hover(event.position)

	# Point indicator follows mouse in real-time when active
	if world.point_indicator and world.point_indicator.local_active:
		var result = world.get_world_hit(event.position)
		if result:
			world.point_indicator.update_position(result.position)
