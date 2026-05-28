extends Control

var world: Node
var die_scene = preload("res://ui/die.tscn")
var _tokens: Array = []
var _rolled: Dictionary = {}  # key → {rolled, total}
var _pending_rolls: int = 0
var _results_to_send: Dictionary = {}

signal combat_ready(results: Dictionary)


@onready var entry_list = $Panel/ScrollContainer/EntryList
@onready var roll_all_btn = $Panel/BtnRow/RollAllBtn
@onready var start_btn = $Panel/BtnRow/StartBtn


func _ready():
	world = get_tree().get_root().get_node_or_null("world")
	roll_all_btn.pressed.connect(_on_roll_all)
	start_btn.pressed.connect(_on_start)


func open(tokens: Array):
	_tokens = tokens
	_rolled.clear()
	_pending_rolls = 0
	_results_to_send.clear()
	for child in entry_list.get_children():
		child.queue_free()
	for t in tokens:
		var row = _create_row(t)
		entry_list.add_child(row)
	start_btn.disabled = true
	visible = true


func close():
	visible = false
	queue_free()


func _create_row(t: Dictionary) -> Control:
	var is_player = t.get("owner_id", -1) > 0
	var row = Control.new()
	row.custom_minimum_size = Vector2(0, 34)
	row.size = Vector2(0, 34)
	row.set_meta("data", t)
	var color = t.get("player_color", Color(0.5, 0.5, 0.5))
	var dot = ColorRect.new()
	dot.size = Vector2(12, 12)
	dot.position = Vector2(6, 11)
	dot.color = color
	row.add_child(dot)
	var name_label = Label.new()
	name_label.text = t.get("token_name", "?")
	name_label.position = Vector2(22, 9)
	name_label.size = Vector2(140, 16)
	name_label.add_theme_font_size_override("font_size", 11)
	row.add_child(name_label)
	if is_player:
		var mod_label = Label.new()
		mod_label.text = "Mod:"
		mod_label.position = Vector2(168, 9)
		mod_label.size = Vector2(30, 16)
		mod_label.add_theme_font_size_override("font_size", 10)
		row.add_child(mod_label)
		var mod_edit = LineEdit.new()
		mod_edit.name = "ModEdit"
		mod_edit.text = str(t.get("initiative", 0))
		mod_edit.position = Vector2(196, 6)
		mod_edit.size = Vector2(40, 22)
		mod_edit.add_theme_font_size_override("font_size", 10)
		row.add_child(mod_edit)
		var roll_btn = Button.new()
		roll_btn.name = "RollBtn"
		roll_btn.text = "Roll d20"
		roll_btn.position = Vector2(242, 5)
		roll_btn.size = Vector2(76, 24)
		roll_btn.focus_mode = 0
		roll_btn.pressed.connect(_on_roll_pressed.bind(t.key, row))
		row.add_child(roll_btn)
		var result_label = Label.new()
		result_label.name = "ResultLabel"
		result_label.text = "→ Total: —"
		result_label.position = Vector2(324, 9)
		result_label.size = Vector2(120, 16)
		result_label.add_theme_font_size_override("font_size", 11)
		row.add_child(result_label)
	else:
		var init_label = Label.new()
		init_label.text = "Initiative:"
		init_label.position = Vector2(168, 9)
		init_label.size = Vector2(60, 16)
		init_label.add_theme_font_size_override("font_size", 10)
		row.add_child(init_label)
		var npc_edit = SpinBox.new()
		npc_edit.name = "NpcEdit"
		npc_edit.position = Vector2(230, 5)
		npc_edit.size = Vector2(60, 22)
		npc_edit.min_value = 1
		npc_edit.max_value = 99
		npc_edit.value = max(1, t.get("initiative", 10))
		npc_edit.add_theme_font_size_override("font_size", 10)
		npc_edit.value_changed.connect(func(v): _check_row_done(row))
		row.add_child(npc_edit)
		var done_label = Label.new()
		done_label.name = "ResultLabel"
		done_label.position = Vector2(300, 9)
		done_label.size = Vector2(80, 16)
		done_label.add_theme_font_size_override("font_size", 11)
		row.add_child(done_label)
		done_label.text = "✓ " + str(int(npc_edit.value))
		_rolled[t.key] = {"rolled": 0, "total": int(npc_edit.value)}
		_check_all_done()
	return row


func _on_roll_pressed(token_key: String, row: Control):
	if _rolled.has(token_key):
		return
	var mod_edit = row.get_node_or_null("ModEdit")
	if not mod_edit:
		return
	var modifier = int(mod_edit.text)
	var roll_btn = row.get_node_or_null("RollBtn")
	if roll_btn:
		roll_btn.disabled = true
		roll_btn.text = "Rolling..."
	if world:
		var dice_holder = world.get_node_or_null("DiceHolder")
		if not dice_holder:
			dice_holder = world
		var die = die_scene.instantiate()
		dice_holder.add_child(die)
		_pending_rolls += 1
		var spawn_pos = Vector3(randf_range(-1, 1), 2.0 + randf_range(0, 1), randf_range(-1, 1))
		die.init(20, spawn_pos, func(result, die_type):
			_on_die_settled(token_key, row, modifier, result)
		)


func _on_die_settled(token_key: String, row: Control, modifier: int, result: int):
	_pending_rolls -= 1
	var total = modifier + result
	var result_label = row.get_node_or_null("ResultLabel")
	if result_label:
		result_label.text = "→ " + str(result) + " = " + str(total)
	_rolled[token_key] = {"rolled": result, "total": total}
	var roll_btn = row.get_node_or_null("RollBtn")
	if roll_btn:
		roll_btn.text = "Rolled"
	_check_all_done()


func _on_roll_all():
	for t in _tokens:
		if _rolled.has(t.key):
			continue
		if t.get("owner_id", -1) <= 0:
			continue
		var key = t.key
		for child in entry_list.get_children():
			if child.has_meta("data") and child.get_meta("data").get("key", "") == key:
				_on_roll_pressed(key, child)
				break


func _check_row_done(row: Control):
	var npc_edit = row.get_node_or_null("NpcEdit")
	if npc_edit:
		var key = row.get_meta("data").get("key", "") if row.has_meta("data") else ""
		_rolled[key] = {"rolled": 0, "total": int(npc_edit.value)}
		var result_label = row.get_node_or_null("ResultLabel")
		if result_label:
			result_label.text = "✓ " + str(int(npc_edit.value))
	_check_all_done()


func _check_all_done():
	var all_done = true
	for t in _tokens:
		if not _rolled.has(t.key):
			all_done = false
			break
	start_btn.disabled = not all_done


func _on_start():
	combat_ready.emit(_rolled.duplicate())
	close()
