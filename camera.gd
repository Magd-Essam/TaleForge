extends Node3D

var orbit_speed = 0.005
var zoom_speed = 0.5
var pan_speed = 0.02
var is_orbiting = false
var is_panning = false

const MIN_CAM_HEIGHT = 1.0
const MOVE_ACCEL = 30.0
const MOVE_FRICTION = 12.0
const MOVE_MAX_SPEED = 12.0

var _velocity = Vector3.ZERO

@onready var cam = $Camera3D

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			is_orbiting = event.pressed
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam.position -= cam.transform.basis.z * zoom_speed
			_clamp_camera_height()
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam.position += cam.transform.basis.z * zoom_speed
			_clamp_camera_height()
	if event is InputEventMouseMotion:
		if is_orbiting:
			rotate_y(-event.relative.x * orbit_speed)
			rotate_object_local(Vector3.RIGHT, -event.relative.y * orbit_speed)
			_clamp_camera_height()
		if is_panning:
			position -= transform.basis.x * event.relative.x * pan_speed
			position += transform.basis.y * event.relative.y * pan_speed

func _process(delta):
	var move_dir = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		move_dir -= transform.basis.z
	if Input.is_key_pressed(KEY_S):
		move_dir += transform.basis.z
	if Input.is_key_pressed(KEY_A):
		move_dir -= transform.basis.x
	if Input.is_key_pressed(KEY_D):
		move_dir += transform.basis.x

	if move_dir.length() > 0:
		move_dir = move_dir.normalized()
		_velocity = _velocity.move_toward(move_dir * MOVE_MAX_SPEED, MOVE_ACCEL * delta)
	else:
		_velocity = _velocity.move_toward(Vector3.ZERO, MOVE_FRICTION * delta)

	position += _velocity * delta
	_clamp_camera_height(delta)


func _clamp_camera_height(delta: float = 0.0):
	var target_y = position.y
	if cam.global_position.y < MIN_CAM_HEIGHT:
		target_y += MIN_CAM_HEIGHT - cam.global_position.y
	var speed = 6.0 * delta if delta > 0 else 0.03
	position.y = move_toward(position.y, target_y, speed)
