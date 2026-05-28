extends Node3D

var local_active: bool = false
var _pointers: Dictionary = {}
var _last_sync_time: float = 0.0
const SYNC_INTERVAL: float = 0.1

const PLAYER_COLORS = [
	Color(0.95, 0.75, 0.2),
	Color(0.2, 0.7, 0.95),
	Color(0.95, 0.3, 0.3),
	Color(0.3, 0.85, 0.3),
	Color(0.85, 0.3, 0.85),
	Color(0.95, 0.55, 0.2),
	Color(0.2, 0.6, 0.9),
	Color(0.95, 0.2, 0.6),
]


func _ready():
	var nm = get_node_or_null("../NetworkManager")
	if nm:
		nm.player_disconnected.connect(_on_player_disconnected)


func toggle():
	if local_active:
		deactivate()
	else:
		activate()


func activate():
	local_active = true


func deactivate():
	local_active = false
	var pid = _my_id()
	_remove_pointer(pid)
	if multiplayer.multiplayer_peer:
		if multiplayer.is_server():
			rpc("sync_point_deactivate", pid)
		else:
			rpc_id(1, "request_point_deactivate")


func update_position(world_pos: Vector3):
	if not local_active:
		return
	var pid = _my_id()
	var root = _ensure_pointer(pid)
	root.position = world_pos
	_send_position_rpc(world_pos)


func _my_id() -> int:
	if multiplayer.multiplayer_peer:
		return multiplayer.get_unique_id()
	return 1


func _get_player_color(id: int) -> Color:
	var nm = get_node_or_null("../NetworkManager")
	if nm and nm.players.has(id) and nm.players[id].has("color"):
		return nm.players[id].color
	return PLAYER_COLORS[id % PLAYER_COLORS.size()]


func _ensure_pointer(player_id: int) -> Node3D:
	if _pointers.has(player_id):
		return _pointers[player_id]
	var root = Node3D.new()
	root.name = "Pointer_%d" % player_id
	var color = _get_player_color(player_id)

	var ring = MeshInstance3D.new()
	ring.mesh = TorusMesh.new()
	ring.mesh.inner_radius = 0.06
	ring.mesh.outer_radius = 0.16
	var rmat = StandardMaterial3D.new()
	rmat.albedo_color = color; rmat.emission = color
	rmat.emission_energy_multiplier = 4.0
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.render_priority = 2
	ring.material_override = rmat
	ring.position.y = 0.02
	root.add_child(ring)

	var beam = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.000
	cyl.bottom_radius = 0.25
	cyl.height = 12.0
	var bmat = StandardMaterial3D.new()
	var grad = Gradient.new()
	grad.add_point(0.0, Color(color.r, color.g, color.b, 0.0))
	grad.add_point(0.10, Color(color.r, color.g, color.b, 0.005))
	grad.add_point(1.0, Color(color.r, color.g, color.b, 0.05))
	var gtex = GradientTexture2D.new()
	gtex.gradient = grad
	gtex.width = 4
	gtex.height = 64
	gtex.fill = GradientTexture2D.FILL_LINEAR
	gtex.fill_from = Vector2(0.5, 0.0)
	gtex.fill_to = Vector2(0.5, 0.9)
	bmat.albedo_texture = gtex
	bmat.albedo_color = Color.WHITE
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bmat.render_priority = 1
	beam.material_override = bmat
	beam.mesh = cyl
	beam.position.y = 3.0
	root.add_child(beam)

	var spot = SpotLight3D.new()
	spot.light_color = color
	spot.light_energy = 20.0
	spot.spot_angle = 15
	spot.spot_attenuation = 0.5
	spot.shadow_enabled = false
	spot.position = Vector3(0, 6.0, 0)
	spot.look_at(Vector3(0, 0, 0))
	root.add_child(spot)

	add_child(root)
	_pointers[player_id] = root
	return root


func _update_pointer_position(player_id: int, world_pos: Vector3):
	if _pointers.has(player_id):
		_pointers[player_id].position = world_pos


func _remove_pointer(player_id: int):
	if _pointers.has(player_id):
		_pointers[player_id].queue_free()
		_pointers.erase(player_id)


func _clear_all_pointers():
	for pid in _pointers:
		if is_instance_valid(_pointers[pid]):
			_pointers[pid].queue_free()
	_pointers.clear()


func _send_position_rpc(world_pos: Vector3):
	if not multiplayer.multiplayer_peer:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_sync_time < SYNC_INTERVAL:
		return
	_last_sync_time = now
	if multiplayer.is_server():
		rpc("sync_point_position", _my_id(), world_pos.x, world_pos.y, world_pos.z)
	else:
		rpc_id(1, "request_point_position", world_pos.x, world_pos.y, world_pos.z)


func _on_player_disconnected(id: int):
	_remove_pointer(id)


@rpc("any_peer", "call_remote", "reliable")
func request_point_position(x: float, y: float, z: float):
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	rpc("sync_point_position", sender_id, x, y, z)


@rpc("any_peer", "call_remote", "reliable")
func request_point_deactivate():
	if not multiplayer.is_server():
		return
	var sender_id = multiplayer.get_remote_sender_id()
	rpc("sync_point_deactivate", sender_id)


@rpc("authority", "call_local", "reliable")
func sync_point_position(sender_id: int, x: float, y: float, z: float):
	if sender_id == _my_id():
		return
	var root = _ensure_pointer(sender_id)
	root.position = Vector3(x, y, z)


@rpc("authority", "call_local", "reliable")
func sync_point_deactivate(sender_id: int):
	if sender_id == _my_id():
		return
	_remove_pointer(sender_id)
