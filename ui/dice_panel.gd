extends Control

var die_scene = preload("res://ui/die.tscn")
var result_scene = preload("res://ui/dice_result.tscn")

var world = null
var is_dragging_panel = false
var is_rolling = false
var _roll_counter = 0
var drag_offset = Vector2.ZERO

# Track dice counts and pending results
var dice_counts = {}
var pending_results = {}
var roll_mode = "normal"  # normal, adv, disadv

const DICE = [4, 6, 8, 10, 12, 20]

@onready var count_labels = {
	4: $Panel/Count4,
	6: $Panel/Count6,
	8: $Panel/Count8,
	10: $Panel/Count10,
	12: $Panel/Count12,
	20: $Panel/Count20,
}


func _ready():
	world = get_tree().get_root().get_node("world")

	# Connect all dice row buttons
	for sides in DICE:
		dice_counts[sides] = 1
		$Panel.get_node("Minus" + str(sides)).pressed.connect(func():
			dice_counts[sides] = max(1, dice_counts[sides] - 1)
			update_count_label(sides)
		)
		$Panel.get_node("Plus" + str(sides)).pressed.connect(func():
			dice_counts[sides] = min(10, dice_counts[sides] + 1)
			update_count_label(sides)
		)
		$Panel.get_node("Roll" + str(sides)).pressed.connect(func():
			roll_dice(sides, "normal")
		)

	# d20 special buttons
	$Panel/Adv20.pressed.connect(func(): roll_dice(20, "adv"))
	$Panel/Dis20.pressed.connect(func(): roll_dice(20, "disadv"))


func update_count_label(sides: int):
	var lbl = count_labels.get(sides)
	if lbl:
		lbl.text = str(dice_counts[sides])


func roll_dice(sides: int, mode: String):
	if is_rolling:
		return
	is_rolling = true
	var count = dice_counts[sides]
	
	# For adv/disadv always roll 2 dice
	var actual_count = count
	if mode == "adv" or mode == "disadv":
		actual_count = 2
	
	# Set up pending results tracker
	_roll_counter += 1
	var roll_id = str(sides) + "_" + str(Time.get_ticks_msec()) + "_" + str(_roll_counter)
	pending_results[roll_id] = {
		"sides": sides,
		"mode": mode,
		"count": actual_count,
		"results": [],
		"expected": actual_count
	}
	
	var dice_holder = world.get_node("DiceHolder")
	
	# Spawn dice in a cluster
	for i in range(actual_count):
		var die = die_scene.instantiate()
		dice_holder.add_child(die)
		var spawn_pos = Vector3(
			randf_range(-0.5, 0.5),
			randf_range(1.5, 2.5),
			randf_range(-0.5, 0.5)
		)
		die.init(sides, spawn_pos, func(result, die_type):
			_on_die_result(roll_id, result)
		)
		await get_tree().create_timer(0.1).timeout

func _on_die_result(roll_id: String, result: int):
	if not pending_results.has(roll_id):
		return
	
	pending_results[roll_id].results.append(result)
	
	var data = pending_results[roll_id]
	if data.results.size() >= data.expected:
		show_final_result(data)
		pending_results.erase(roll_id)
		is_rolling = false

func show_final_result(data: Dictionary):
	var results = data.results
	var sides = data.sides
	var mode = data.mode
	var final_value = 0
	var label_text = ""

	match mode:
		"normal":
			for r in results:
				final_value += r
			if results.size() > 1:
				label_text = str(results) + "\nTotal: " + str(final_value)
			else:
				final_value = results[0]
				label_text = str(final_value)
		"adv":
			final_value = results.max()
			label_text = str(results[0]) + " | " + str(results[1]) + "\nAdv: " + str(final_value)
		"disadv":
			final_value = results.min()
			label_text = str(results[0]) + " | " + str(results[1]) + "\nDis: " + str(final_value)

	var result_ui = result_scene.instantiate()
	get_parent().add_child(result_ui)
	result_ui.show_result(final_value, sides, label_text)
	_broadcast_dice_result(final_value, sides, label_text)
	# Also push to local log
	var lp = world.get_node_or_null("UI/LogPanel")
	if lp and lp.has_method("add_dice_entry"):
		lp.add_dice_entry(final_value, sides, label_text.replace("\n", " | "), world.network_manager.my_name)

func _broadcast_dice_result(result: int, die_type: int, custom_text: String):
	var nm = world.get_node_or_null("NetworkManager")
	if not nm:
		return
	var mp = multiplayer.multiplayer_peer
	if not mp:
		return
	var roller_name = nm.my_name
	var roller_id = nm.my_id
	if multiplayer.is_server():
		world.rpc("sync_dice_result", result, die_type, custom_text, roller_name, roller_id)
	else:
		world.rpc_id(1, "report_dice_result", result, die_type, custom_text, roller_name, roller_id)


# Draggable panel
func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_dragging_panel = event.pressed
			drag_offset = get_global_mouse_position() - position
	if event is InputEventMouseMotion and is_dragging_panel:
		position = get_global_mouse_position() - drag_offset
