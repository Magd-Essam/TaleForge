extends Node

var world: Node

var clip_height: float = 100.0
var is_active: bool = false

signal clip_height_changed(height: float)

func _ready():
	world = get_parent()

func set_clip_height(height: float):
	clip_height = height
	is_active = height < 100.0
	emit_signal("clip_height_changed", clip_height)
	_apply_clip()

func toggle():
	is_active = not is_active
	if not is_active:
		clip_height = 100.0
	else:
		clip_height = 5.0
	emit_signal("clip_height_changed", clip_height)
	_apply_clip()

func _apply_clip():
	for key in world.placed_pieces:
		var piece = world.placed_pieces[key]
		if is_instance_valid(piece):
			var hide = piece.position.y > clip_height
			piece.visible = not hide
	for key in world.placed_tokens:
		var token = world.placed_tokens[key]
		if is_instance_valid(token):
			var hide = token.position.y > clip_height
			token.visible = not hide
	for key in world.placed_props:
		var prop = world.placed_props[key]
		if is_instance_valid(prop):
			var hide = prop.position.y > clip_height
			prop.visible = not hide
