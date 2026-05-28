extends Control

var world: Node
var dragging: bool = false
var drag_offset: Vector2

@onready var drag_handle = $Panel/DragHandle
@onready var build_btn = $Panel/BuildBtn
@onready var floor_lbl = $Panel/FloorLabel
@onready var initiative_btn = $Panel/InitiativeBtn
@onready var end_turn_btn = $Panel/EndTurnBtn

func _ready():
	world = get_parent().get_parent()

	build_btn.pressed.connect(func():
		if world.floor_manager:
			world.floor_manager.toggle_build_mode()
			_update_build_indicator()
	)

	initiative_btn.pressed.connect(func():
		var init_panel = world.get_node_or_null("UI/InitiativePanel")
		if init_panel:
			init_panel.visible = not init_panel.visible
	)

	end_turn_btn.pressed.connect(func():
		var tracker = world.get_node_or_null("InitiativeTracker")
		if not tracker or not tracker.is_active:
			return
		if multiplayer.is_server():
			tracker.end_turn()
		else:
			world.rpc_id(1, "request_end_turn_from_client")
	)

	if world.floor_manager:
		world.floor_manager.build_mode_toggled.connect(_update_build_indicator)
		world.floor_manager.floor_changed.connect(_update_build_indicator)

	_update_build_indicator()

func _update_build_indicator():
	var fm = world.floor_manager
	if not fm:
		return
	build_btn.modulate = Color(1, 1, 0) if fm.build_mode else Color(1, 1, 1)
	build_btn.text = "Build " + ("ON" if fm.build_mode else "OFF")
	floor_lbl.text = "Floor " + str(fm.current_floor)

func _on_drag_handle_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
			drag_offset = event.position
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		position += event.position - drag_offset
		accept_event()
