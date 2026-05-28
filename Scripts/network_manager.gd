extends Node

signal player_connected(id: int, name: String)
signal player_disconnected(id: int)
signal connection_failed()
signal server_disconnected()
signal game_started()
signal reconnecting(attempt: int, max_attempts: int)
signal reconnected()
signal reconnect_failed()

var is_host: bool = false
var my_id: int = 1
var my_name: String = "Player"
var my_color: Color = Color.WHITE
var players: Dictionary = {}  # { id: { name: String, color: Color } }
var host_address: String = "127.0.0.1"
var host_port: int = 4789
var game_active: bool = false

var is_reconnecting: bool = false

const DEFAULT_PORT := 4789
const RECONNECT_MAX_ATTEMPTS: int = 10
const RECONNECT_BACKOFF_BASE: float = 1.0
const RECONNECT_BACKOFF_MAX: float = 30.0

var _reconnect_attempts: int = 0
var _reconnect_timer: float = 0.0
var _reconnect_wait: float = 0.0


func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_disconnected)


func host_game(port: int = DEFAULT_PORT):
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, 8)
	if err != OK:
		push_error("Failed to host: ", err)
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	my_id = 1
	players[1] = {"name": my_name, "color": my_color}
	return true


func join_game(address: String, port: int = DEFAULT_PORT):
	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(address, port)
	if err != OK:
		push_error("Failed to join: ", err)
		connection_failed.emit()
		return false
	multiplayer.multiplayer_peer = peer
	is_host = false
	host_address = address
	return true


func disconnect_from_server():
	multiplayer.multiplayer_peer = null
	is_host = false
	my_id = 1
	players.clear()


@rpc("any_peer", "call_remote", "reliable")
func request_register(name: String, color: Vector3):
	if not multiplayer.is_server():
		return
	var id = multiplayer.get_remote_sender_id()
	players[id] = {"name": name, "color": Color(color.x, color.y, color.z)}
	rpc("_on_registered", id, players)


@rpc("authority", "call_local", "reliable")
func _on_registered(id: int, updated_players: Dictionary):
	players = updated_players
	player_connected.emit(id, players[id].name)


@rpc("authority", "call_local", "reliable")
func start_game():
	game_active = true
	game_started.emit()


@rpc("authority", "call_local", "reliable")
func sync_player_list(updated_players: Dictionary):
	players = updated_players


func _on_peer_connected(id: int):
	if multiplayer.is_server():
		players[id] = {"name": "Unknown", "color": Color.WHITE}


func _on_peer_disconnected(id: int):
	players.erase(id)
	player_disconnected.emit(id)


func _on_connected_to_server():
	my_id = multiplayer.get_unique_id()
	rpc_id(1, "request_register", my_name, Vector3(my_color.r, my_color.g, my_color.b))
	if is_reconnecting:
		is_reconnecting = false
		reconnected.emit()


func _on_connection_failed():
	connection_failed.emit()
	multiplayer.multiplayer_peer = null


func _process(delta: float):
	if is_reconnecting:
		_reconnect_timer += delta
		if _reconnect_timer >= _reconnect_wait:
			_try_reconnect()


func _start_reconnect():
	if is_host or is_reconnecting:
		return
	is_reconnecting = true
	_reconnect_attempts = 0
	_reconnect_timer = 0.0
	_reconnect_wait = 0.0
	_try_reconnect()


func _try_reconnect():
	_reconnect_attempts += 1
	_reconnect_timer = 0.0

	if _reconnect_attempts > RECONNECT_MAX_ATTEMPTS:
		is_reconnecting = false
		reconnect_failed.emit()
		return

	_reconnect_wait = min(RECONNECT_BACKOFF_BASE * pow(2, _reconnect_attempts - 1), RECONNECT_BACKOFF_MAX)
	reconnecting.emit(_reconnect_attempts, RECONNECT_MAX_ATTEMPTS)

	var peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(host_address, host_port)
	if err != OK:
		_reconnect_timer = _reconnect_wait
		return

	multiplayer.multiplayer_peer = peer


func stop_reconnect():
	is_reconnecting = false
	_reconnect_timer = 0.0
	_reconnect_wait = 0.0
	_reconnect_attempts = 0


func _on_disconnected():
	var was_host = is_host
	multiplayer.multiplayer_peer = null
	players.clear()
	is_host = false
	my_id = 1
	if was_host:
		server_disconnected.emit()
	else:
		_start_reconnect()
