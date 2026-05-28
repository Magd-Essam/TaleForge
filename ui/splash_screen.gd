extends Control

@onready var loading_icon = $LoadingIcon
@onready var timer = $Timer


func _ready():
	loading_icon.pivot_offset = loading_icon.size / 2.0
	var tween = create_tween().set_loops()
	tween.tween_property(loading_icon, "rotation", deg_to_rad(-360), 1.0).as_relative()
	timer.start()


func _on_timer_timeout():
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")