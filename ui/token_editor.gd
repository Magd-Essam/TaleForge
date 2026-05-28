extends Control

var target_token = null
var _owner_ids: Dictionary = {}
var _world: Node

@onready var input_name = $InputName
@onready var input_speed = $InputSpeed
@onready var input_movement_budget = $InputMovementBudget
@onready var input_blind = $InputBlind
@onready var input_vision = $InputVision
@onready var input_owner = $InputOwner
@onready var btn_apply = $BtnApply
@onready var btn_close = $BtnClose


func _ready():
	_world = get_parent().get_parent()
	mouse_filter = Control.MOUSE_FILTER_STOP

	btn_apply.pressed.connect(_on_apply)
	btn_close.pressed.connect(_on_close)

	visible = false


func _grab_name_focus():
	input_name.grab_focus()


func _populate_owner_dropdown():
	input_owner.clear()
	var idx = 0
	var owner_ids = {}
	input_owner.add_item("Unowned", -1)
	owner_ids[-1] = idx
	idx += 1

	var nm = _world.get_node("NetworkManager")
	if nm.players.has(1):
		input_owner.add_item("GM", 1)
		owner_ids[1] = idx
		idx += 1

	for pid in nm.players:
		if pid == 1:
			continue
		input_owner.add_item(nm.players[pid].name + " [" + str(pid) + "]", pid)
		owner_ids[pid] = idx
		idx += 1

	_owner_ids = owner_ids


func open_for(token):
	target_token = token
	input_name.text = token.token_name
	input_speed.value = token.get("move_speed") if token.get("move_speed") != null else 30
	input_movement_budget.value = token.get("movement_budget") if token.get("movement_budget") != null else 30
	var screen = get_viewport().get_visible_rect().size
	position = (screen - size) / 2.0
	visible = true
	input_blind.button_pressed = token.blinded
	input_vision.value = token.vision_radius

	_populate_owner_dropdown()
	call_deferred("_grab_name_focus")
	var oid = token.owner_id
	if _owner_ids.has(oid):
		input_owner.select(_owner_ids[oid])
	else:
		input_owner.select(0)

	var is_decoration = token.token_type == 2
	$LabelSpeed.visible = not is_decoration
	input_speed.visible = not is_decoration
	$LabelBlind.visible = not is_decoration
	input_blind.visible = not is_decoration
	$LabelVision.visible = not is_decoration
	input_vision.visible = not is_decoration


func _on_apply():
	if not target_token:
		return

	var key = _world.find_token_key(target_token)
	if key == "":
		return

	target_token.token_name = input_name.text
	target_token.move_speed = int(input_speed.value)
	target_token.movement_budget = int(input_movement_budget.value)
	target_token.blinded = input_blind.button_pressed
	target_token.vision_radius = int(input_vision.value)
	target_token.owner_id = input_owner.get_selected_id()
	target_token.update_visuals()

	_world._sync_update_token_field(key, "token_name", input_name.text)
	_world._sync_update_token_field(key, "move_speed", int(input_speed.value))
	_world._sync_update_token_field(key, "movement_budget", int(input_movement_budget.value))
	_world._sync_update_token_field(key, "blinded", input_blind.button_pressed)
	_world._sync_update_token_field(key, "vision_radius", int(input_vision.value))
	_world._sync_update_token_field(key, "owner_id", input_owner.get_selected_id())

	visible = false
	target_token = null


func _on_close():
	visible = false
	target_token = null


func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		input_name.grab_focus()
		get_viewport().set_input_as_handled()
