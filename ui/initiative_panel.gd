extends Control

var world: Node
var tracker: Node

var entries: Dictionary = {}
var _is_editing: bool = false
var _editing_key: String = ""
var _current_glow_tween: Tween = null

@onready var title_label = $TitleLabel
@onready var scroll = $ScrollContainer
@onready var roll_btn = $RollBtn
@onready var end_turn_btn = $EndTurnBtn
@onready var end_combat_btn = $EndCombatBtn
@onready var add_btn = $AddBtn

var roll_popup_scene = preload("res://ui/initiative_roll_popup.tscn")


func _ready():
	world = get_parent().get_parent()
	tracker = world.get_node_or_null("InitiativeTracker")
	if tracker:
		tracker.turn_order_changed.connect(_on_turn_order_changed)
		tracker.turn_changed.connect(_on_turn_changed)
		tracker.combat_ended.connect(_on_combat_ended)
	roll_btn.pressed.connect(_on_roll)
	end_turn_btn.pressed.connect(_on_end_turn)
	end_combat_btn.pressed.connect(_on_end_combat)
	add_btn.pressed.connect(_on_add)
	_toggle_gm_visibility()


func _toggle_gm_visibility():
	var is_gm = not multiplayer.multiplayer_peer or multiplayer.is_server()
	roll_btn.visible = is_gm
	end_turn_btn.visible = is_gm
	end_combat_btn.visible = is_gm
	add_btn.visible = is_gm


func _on_turn_order_changed(order: Array):
	for child in scroll.get_node("TurnBox").get_children():
		child.queue_free()
	entries.clear()
	if not tracker or not tracker.is_active:
		title_label.text = "INITIATIVE"
		return
	title_label.text = "INITIATIVE — Round " + str(tracker.current_round)
	var turn_box = scroll.get_node("TurnBox")
	for entry in order:
		var entry_control = _create_turn_entry(entry)
		turn_box.add_child(entry_control)
		entries[entry.key] = entry_control
	call_deferred("_scroll_to_current")


func _on_turn_changed(token_key: String):
	for key in entries:
		var e = entries[key]
		var is_current = key == token_key
		var portrait = e.get_node_or_null("Portrait")
		if portrait:
			if is_current:
				if _current_glow_tween:
					_current_glow_tween.kill()
				_current_glow_tween = create_tween().set_loops()
				_current_glow_tween.tween_method(func(v): portrait.modulate.a = v, 0.6, 1.0, 1.0)
				_current_glow_tween.tween_method(func(v): portrait.modulate.a = v, 1.0, 0.6, 1.0)
			else:
				portrait.modulate.a = 1.0
	call_deferred("_scroll_to_current")


func _on_combat_ended():
	if _current_glow_tween:
		_current_glow_tween.kill()
		_current_glow_tween = null
	_on_turn_order_changed([])


func _create_turn_entry(entry: Dictionary) -> Control:
	var container = Control.new()
	container.custom_minimum_size = Vector2(70, 56)
	container.size = Vector2(70, 56)
	var color = entry.get("player_color", Color(0.5, 0.5, 0.5))
	var portrait = Panel.new()
	portrait.name = "Portrait"
	portrait.size = Vector2(40, 40)
	portrait.position = Vector2(15, 0)
	portrait.mouse_filter = 2
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	portrait.add_theme_stylebox_override("panel", style)
	container.add_child(portrait)
	var conditions = entry.get("conditions", [])
	if conditions.size() > 0:
		var count = conditions.size()
		var angle_step = TAU / count
		for i in range(count):
			var dot = ColorRect.new()
			dot.size = Vector2(6, 6)
			var angle = angle_step * i - PI / 2
			dot.position = Vector2(32 + cos(angle) * 16, 17 + sin(angle) * 16)
			dot.mouse_filter = 2
			var cond_color = Color(0.5, 0.5, 0.5)
			var cond_name = conditions[i]
			var tok = world.placed_tokens.get(entry.get("key", "")) if world else null
			if tok and "CONDITION_COLORS" in tok:
				cond_color = tok.CONDITION_COLORS.get(cond_name, Color(0.5, 0.5, 0.5))
			dot.color = cond_color
			container.add_child(dot)
	var name_label = Label.new()
	name_label.text = entry.get("token_name", "?")
	name_label.size = Vector2(70, 14)
	name_label.position = Vector2(0, 40)
	name_label.horizontal_alignment = 1
	name_label.vertical_alignment = 1
	name_label.add_theme_font_size_override("font_size", 8)
	container.add_child(name_label)
	if not multiplayer.multiplayer_peer or multiplayer.is_server():
		name_label.mouse_filter = 1
		name_label.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
				_start_name_edit(entry.key, name_label)
		)
	var total_label = Label.new()
	total_label.name = "TotalLabel"
	total_label.text = str(entry.get("total", 0))
	total_label.size = Vector2(70, 14)
	total_label.position = Vector2(0, 52)
	total_label.horizontal_alignment = 1
	total_label.vertical_alignment = 1
	total_label.add_theme_font_size_override("font_size", 10)
	var fc = Color(1, 1, 0.6)
	total_label.add_theme_color_override("font_color", fc)
	container.add_child(total_label)
	if not multiplayer.multiplayer_peer or multiplayer.is_server():
		total_label.mouse_filter = 1
		total_label.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.double_click and event.button_index == MOUSE_BUTTON_LEFT:
				_start_edit(entry.key, total_label)
		)
	return container


func _start_edit(token_key: String, label: Label):
	if _is_editing:
		return
	_is_editing = true
	_editing_key = token_key
	var line_edit = LineEdit.new()
	line_edit.text = label.text
	line_edit.size = label.size
	line_edit.position = label.position
	line_edit.horizontal_alignment = 1
	line_edit.add_theme_font_size_override("font_size", 10)
	var orig = label.get_parent()
	orig.remove_child(label)
	orig.add_child(line_edit)
	line_edit.grab_focus()
	line_edit.select_all()
	line_edit.text_submitted.connect(func(new_text):
		_finish_edit(token_key, line_edit, label)
	)
	line_edit.focus_exited.connect(func():
		_finish_edit(token_key, line_edit, label)
	)


func _finish_edit(token_key: String, line_edit: LineEdit, label: Label):
	if not is_instance_valid(line_edit):
		return
	var new_total = int(line_edit.text)
	if new_total <= 0:
		new_total = int(label.text)
	var parent = line_edit.get_parent()
	if parent:
		parent.remove_child(line_edit)
		parent.add_child(label)
	line_edit.queue_free()
	_is_editing = false
	_editing_key = ""
	if tracker and new_total > 0:
		tracker.edit_initiative(token_key, new_total)


func _start_name_edit(token_key: String, label: Label):
	if _is_editing:
		return
	_is_editing = true
	_editing_key = token_key
	var line_edit = LineEdit.new()
	line_edit.text = label.text
	line_edit.size = label.size
	line_edit.position = label.position
	line_edit.horizontal_alignment = 1
	line_edit.add_theme_font_size_override("font_size", 8)
	var orig = label.get_parent()
	orig.remove_child(label)
	orig.add_child(line_edit)
	line_edit.grab_focus()
	line_edit.select_all()
	line_edit.text_submitted.connect(func(new_text):
		_finish_name_edit(token_key, line_edit, label)
	)
	line_edit.focus_exited.connect(func():
		_finish_name_edit(token_key, line_edit, label)
	)


func _finish_name_edit(token_key: String, line_edit: LineEdit, label: Label):
	if not is_instance_valid(line_edit):
		return
	var new_name = line_edit.text.strip_edges()
	if new_name.is_empty():
		new_name = label.text
	var parent = line_edit.get_parent()
	if parent:
		parent.remove_child(line_edit)
		parent.add_child(label)
	line_edit.queue_free()
	_is_editing = false
	_editing_key = ""
	if tracker and new_name != label.text:
		label.text = new_name
		for entry in tracker.turn_order:
			if entry.key == token_key:
				entry.token_name = new_name
				break
		var token = world.placed_tokens.get(token_key) if world else null
		if token:
			token.token_name = new_name


func _scroll_to_current():
	if not tracker or not tracker.is_active or tracker.current_turn_index < 0:
		return
	var current_key = tracker.get_current_token_key()
	if current_key == "":
		return
	var entry_control = entries.get(current_key)
	if entry_control:
		scroll.ensure_control_visible(entry_control)


func _on_roll():
	if not tracker or not world:
		return
	var tokens = []
	for key in world.placed_tokens:
		var token = world.placed_tokens[key]
		if token.token_type == 2:
			continue
		if tracker.is_active:
			var already = false
			for e in tracker.turn_order:
				if e.key == key:
					already = true
					break
			if already:
				continue
		var owner_id = token.owner_id
		var player_color = Color(0.5, 0.5, 0.5)
		if owner_id > 0 and world.network_manager and world.network_manager.players.has(owner_id):
			player_color = world.network_manager.players[owner_id].get("color", Color(0.5, 0.5, 0.5))
		tokens.append({
			"key": key,
			"token_name": token.token_name,
			"token_type": token.token_type,
			"initiative": token.initiative,
			"owner_id": owner_id,
			"player_color": player_color
		})
	if tokens.size() == 0:
		return
	var popup = roll_popup_scene.instantiate()
	add_child(popup)
	popup.combat_ready.connect(func(results):
		tracker.start_combat(results)
	)
	popup.open(tokens)


func _on_end_turn():
	if not tracker:
		return
	if multiplayer.multiplayer_peer and not multiplayer.is_server():
		var nm = world.network_manager
		if nm and nm.my_id:
			rpc_id(1, "request_end_turn_from_client")
	else:
		tracker.end_turn()


func _on_end_combat():
	if not tracker:
		return
	if multiplayer.multiplayer_peer and not multiplayer.is_server():
		rpc_id(1, "request_end_combat_from_client")
	else:
		tracker.end_combat()


func _on_add():
	if not tracker or not tracker.is_active or not world:
		return
	var token = world.token_manager.selected_token
	if not token:
		return
	var key = world.find_token_key(token)
	if key == "":
		return
	for e in tracker.turn_order:
		if e.key == key:
			return
	var owner_id = token.owner_id
	var player_color = Color(0.5, 0.5, 0.5)
	if owner_id > 0 and world.network_manager and world.network_manager.players.has(owner_id):
		player_color = world.network_manager.players[owner_id].get("color", Color(0.5, 0.5, 0.5))
	var tokens = [{
		"key": key,
		"token_name": token.token_name,
		"token_type": token.token_type,
		"initiative": token.initiative,
		"owner_id": owner_id,
		"player_color": player_color
	}]
	var popup = roll_popup_scene.instantiate()
	add_child(popup)
	popup.combat_ready.connect(func(results):
		var r = results.get(key)
		if r:
			tracker.add_to_combat(key, r.total)
	)
	popup.open(tokens)
