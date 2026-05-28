extends Control

@onready var box = $Box
@onready var roll_type_label = $Box/MarginContainer/VBoxContainer/RollTypeLabel
@onready var result_label = $Box/MarginContainer/VBoxContainer/ResultLabel

func show_result(result: int, die_type: int, custom_text: String = ""):
	var screen = get_viewport().get_visible_rect().size

	if custom_text != "":
		var lines = custom_text.split("\n")
		roll_type_label.text = lines[0] if lines.size() > 0 else ""
		result_label.text = lines[1] if lines.size() > 1 else custom_text
	else:
		roll_type_label.text = "d" + str(die_type)
		result_label.text = str(result)

	if result == die_type and custom_text == "":
		result_label.add_theme_color_override("font_color", Color(1, 0.85, 0))
		roll_type_label.text = "CRITICAL HIT"
		roll_type_label.add_theme_color_override("font_color", Color(1, 0.85, 0))
	elif result == 1 and custom_text == "":
		result_label.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
		roll_type_label.text = "CRITICAL FAIL"
		roll_type_label.add_theme_color_override("font_color", Color(0.9, 0.1, 0.1))
	else:
		result_label.add_theme_color_override("font_color", Color(1, 1, 1))

	await get_tree().process_frame

	size = box.size
	position = (screen - size) / 2.0
	position.y = screen.y * 0.35

	visible = true
	modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.8)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)
