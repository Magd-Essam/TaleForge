extends Node3D

# ─────────────────────────────────────────────────────────────────────────────
# world.gd — thin coordinator
#
# Owns:
#   • The two shared dictionaries every handler needs
#   • @onready refs to scene nodes
#   • get_world_hit() and world_to_cell() — used by every handler
#   • sync_floor() and update_fog() — orchestration calls
#
# Does NOT own: input, placement logic, drag state, tool state, token logic.
# Those all live in their dedicated handler scripts (children of this node).
# ─────────────────────────────────────────────────────────────────────────────

# ── shared state ─────────────────────────────────────────────────────────────
# Every handler reads and writes these two dictionaries.
# Keys are strings like "floor_3_7", "3_7_N", "token_3_7", "token_free_12345"
var placed_pieces : Dictionary = {}
var placed_tokens  : Dictionary = {}
var placed_props   : Dictionary = {}
var piece_floors   : Dictionary = {}

const FLOOR_HEIGHT: float = 3.0

var snap_enabled : bool = true
var placed_aoes  : Dictionary = {}
var _has_received_state: bool = false

# Tile grid for neighbor lookups (Phase 1 tile fusion)
var tile_grid : Dictionary = {}

# ── scene node refs ───────────────────────────────────────────────────────────
@onready var grid             = $grid
@onready var terrain_holder   = $TerrainHolder
@onready var token_holder     = $TokenHolder
@onready var prop_holder      = $PropHolder
@onready var fog              = $FogOfWar
@onready var terraform_manager = $ModularTerraformManager
@onready var ruler_manager      = $RulerManager
@onready var aoe_manager        = $AoeManager
@onready var plane              = $StaticBody3D/MeshInstance3D
# ── UI refs ───────────────────────────────────────────────────────────────────
@onready var library_panel  = $UI/LibraryPanel
@onready var context_menu   = $UI/ContextMenu
@onready var token_editor   = $UI/TokenEditor
@onready var player_window  = $UI/PlayerWindow
@onready var log_panel      = $UI/LogPanel
@onready var dice_panel     = $UI/DicePanel
@onready var library_handle = $UI/LibraryPanel/LibraryHandle
@onready var pw_handle      = $UI/PlayerWindow/PwHandle
@onready var log_handle     = $UI/LogPanel/LogHandle

var _panel_collapsed := { "library": false, "pw": false, "log": false }


# ── handler refs (child nodes added in the scene) ─────────────────────────────
@onready var grid_system       = $grid
@onready var input_handler     = $InputHandler
@onready var terrain_placer    = $TerrainPlacer
@onready var prop_placer       = $PropPlacer
@onready var token_manager     = $TokenManager
@onready var drag_controller   = $DragController
@onready var selection_manager = $SelectionManager
@onready var tile_fusion = $TileFusion
@onready var slab_manager = $SlabManager
@onready var floor_manager = $FloorManager
@onready var layer_slider = $LayerSlider
@onready var water_slider = $WaterSlider
@onready var movement_controller = $MovementController
@onready var initiative_tracker = $InitiativeTracker
@onready var point_indicator = $PointIndicator
var network_manager: Node

# ── preloaded scenes ──────────────────────────────────────────────────────────
var token_scene = preload("res://tokens/token.tscn")
var prop_scene  = preload("res://props/prop.tscn")
var pieces = {
	"wall":        preload("res://terrain/pieces/wall.tscn"),
	"floor_stone": preload("res://terrain/pieces/floor_stone.tscn"),
	"floor_grass": preload("res://terrain/pieces/floor_grass.tscn"),
	"floor_water": preload("res://terrain/pieces/floor_water.tscn"),
}


func _ready():
	fog.build_fog(grid.grid_size, grid.cell_size)
	sync_floor()
	network_manager = $NetworkManager
	_connect_signals()
	_connect_network()
	if get_viewport():
		get_viewport().gui_focus_changed.connect(_on_focus_changed)
	_handle_pending_menu_action()


func _connect_network():
	if network_manager and not network_manager.game_started.is_connected(_on_game_started):
		network_manager.game_started.connect(_on_game_started)
		if network_manager.is_host:
			_on_game_started()
	if network_manager and not network_manager.player_disconnected.is_connected(_on_player_disconnected):
		network_manager.player_disconnected.connect(_on_player_disconnected)
	if network_manager and not network_manager.player_connected.is_connected(_on_any_player_connected):
		network_manager.player_connected.connect(_on_any_player_connected)
	if network_manager and not network_manager.server_disconnected.is_connected(_on_server_disconnected):
		network_manager.server_disconnected.connect(_on_server_disconnected)
	if network_manager and not network_manager.reconnecting.is_connected(_on_reconnecting):
		network_manager.reconnecting.connect(_on_reconnecting)
	if network_manager and not network_manager.reconnected.is_connected(_on_reconnected):
		network_manager.reconnected.connect(_on_reconnected)
	if network_manager and not network_manager.reconnect_failed.is_connected(_on_reconnect_failed):
		network_manager.reconnect_failed.connect(_on_reconnect_failed)


func _handle_pending_menu_action():
	var action = GameManager.pending_action
	GameManager.pending_action = GameManager.MenuAction.NONE
	if action == GameManager.MenuAction.HOST:
		network_manager.my_name = GameManager.pending_name
		network_manager.my_color = GameManager.pending_color
		if network_manager.host_game(network_manager.DEFAULT_PORT):
			var lobby = $UI/Lobby
			lobby.visible = true
			lobby.refresh()
	elif action == GameManager.MenuAction.JOIN:
		network_manager.my_name = GameManager.pending_name
		network_manager.my_color = GameManager.pending_color
		network_manager.join_game(GameManager.pending_ip, GameManager.pending_port)
		var lobby = $UI/Lobby
		lobby.visible = true
		lobby.refresh()

func _connect_signals():
	if library_panel.asset_selected.is_connected(selection_manager._on_asset_selected):
		return
	library_panel.asset_selected.connect(selection_manager._on_asset_selected)
	context_menu.on_delete.connect(token_manager._on_token_delete)
	context_menu.on_edit.connect(token_manager._on_token_edit)
	context_menu.on_cycle_wall.connect(terrain_placer._on_wall_cycle)
	if aoe_manager:
		if not aoe_manager.mode_changed.is_connected($UI/ToolPanel._on_aoe_mode_changed):
			aoe_manager.mode_changed.connect($UI/ToolPanel._on_aoe_mode_changed)
		if not aoe_manager.mode_changed.is_connected(player_window._on_aoe_mode_changed):
			aoe_manager.mode_changed.connect(player_window._on_aoe_mode_changed)
	if library_handle and not library_handle.pressed.is_connected(_toggle_library):
		library_handle.pressed.connect(_toggle_library)
	if pw_handle and not pw_handle.pressed.is_connected(_toggle_pw):
		pw_handle.pressed.connect(_toggle_pw)
	if log_handle and not log_handle.pressed.is_connected(_toggle_log):
		log_handle.pressed.connect(_toggle_log)

func find_token_key(token: Node) -> String:
	for key in placed_tokens:
		if placed_tokens[key] == token:
			return key
	return ""

func find_prop_key(prop: Node) -> String:
	for key in placed_props:
		if placed_props[key] == prop:
			return key
	return ""


func _on_game_started():
	var mp = multiplayer.multiplayer_peer
	if mp and not multiplayer.is_server():
		library_panel.visible = false
		player_window.visible = true

	if mp and multiplayer.is_server():
		_do_sync_full_state()


func _on_player_disconnected(id: int):
	if not multiplayer.is_server():
		return
	for key in placed_tokens:
		var token = placed_tokens[key]
		if token.owner_id == id:
			token.owner_id = -1


func _on_server_disconnected():
	_clear_all_placed()
	_has_received_state = false
	if network_manager and network_manager.is_reconnecting:
		return
	GameManager.return_message = "Server disconnected"
	get_tree().change_scene_to_file("res://ui/main_menu.tscn")


func _clear_all_placed():
	for t in placed_tokens.values():
		if is_instance_valid(t):
			t.queue_free()
	placed_tokens.clear()
	for p in placed_pieces.values():
		if is_instance_valid(p):
			p.queue_free()
	placed_pieces.clear()
	tile_grid.clear()
	for p in placed_props.values():
		if is_instance_valid(p):
			p.queue_free()
	placed_props.clear()
	for a in placed_aoes.values():
		if is_instance_valid(a):
			a.queue_free()
	placed_aoes.clear()
	update_fog()


func _on_any_player_connected(id: int, _name: String):
	var mp = multiplayer.multiplayer_peer
	if not mp or multiplayer.is_server():
		return
	if id != multiplayer.get_unique_id():
		return
	rpc_id(1, "request_full_state")


func _do_sync_full_state():
	var tdata = {}
	for key in placed_tokens:
		tdata[key] = placed_tokens[key].serialize()
	var pdata = {}
	for key in placed_pieces:
		var p = placed_pieces[key]
		pdata[key] = {
			"type": p.piece_type,
			"cell_x": int(p.cell.x) if p.piece_type == "wall" else int(p.grid_position.x),
			"cell_y": int(p.cell.y) if p.piece_type == "wall" else int(p.grid_position.y),
			"dir": p.direction if p.piece_type == "wall" else "",
			"model_path": p.get("custom_model_path", ""),
			"floor": piece_floors.get(key, 0)
		}
	var prdata = {}
	for key in placed_props:
		var p = placed_props[key]
		var cell = world_to_cell(p.position.x, p.position.z)
		prdata[key] = {
			"data": {"name": "Prop", "model_path": p.model_path, "free_placement": true, "position_y": p.position.y},
			"cell_x": int(cell.x),
			"cell_y": int(cell.y),
			"scale_multiplier": p.scale_multiplier
		}
	var adata = {}
	for key in placed_aoes:
		var a = placed_aoes[key]
		if not is_instance_valid(a):
			continue
		adata[key] = aoe_manager._serialize_aoe(key)
	var gdata = {
		"grid_size": grid.grid_size,
		"color_r": grid.grid_color.r,
		"color_g": grid.grid_color.g,
		"color_b": grid.grid_color.b,
		"color_a": grid.grid_color.a
	}
	var cdata = {}
	var tracker = $InitiativeTracker
	if tracker:
		cdata = tracker.serialize()
	rpc("sync_full_state", tdata, pdata, prdata, adata, gdata, cdata)


# ── sync helpers (call RPC or direct in single-player) ────────────────────────

func _sync_place_token(key: String, data: Dictionary):
	sync_place_token(key, data)
	if multiplayer.multiplayer_peer:
		rpc("sync_place_token", key, data)

func _sync_remove_token(key: String):
	sync_remove_token(key)
	if multiplayer.multiplayer_peer:
		rpc("sync_remove_token", key)

func _sync_move_token(old_key: String, new_key: String, data: Dictionary):
	sync_move_token(old_key, new_key, data)
	if multiplayer.multiplayer_peer:
		rpc("sync_move_token", old_key, new_key, data)

func _sync_place_piece(key: String, type_name: String, cell_x: int, cell_y: int, dir: String, model_path: String, floor: int = 0):
	sync_place_piece(key, type_name, cell_x, cell_y, dir, model_path, floor)
	if multiplayer.multiplayer_peer:
		rpc("sync_place_piece", key, type_name, cell_x, cell_y, dir, model_path, floor)

func _sync_remove_piece(key: String):
	sync_remove_piece(key)
	if multiplayer.multiplayer_peer:
		rpc("sync_remove_piece", key)

func _sync_place_prop(key: String, data: Dictionary, cell_x: int, cell_y: int):
	sync_place_prop(key, data, cell_x, cell_y)
	if multiplayer.multiplayer_peer:
		rpc("sync_place_prop", key, data, cell_x, cell_y)

func _sync_remove_prop(key: String):
	sync_remove_prop(key)
	if multiplayer.multiplayer_peer:
		rpc("sync_remove_prop", key)

func _sync_update_token_field(key: String, field: String, value):
	sync_update_token_field(key, field, value)
	if multiplayer.multiplayer_peer:
		if multiplayer.is_server():
			rpc("sync_update_token_field", key, field, value)
		else:
			rpc_id(1, "request_update_token_field", key, field, value)

func _sync_move_piece(old_key: String, new_key: String, cell_x: int, cell_y: int, dir: String):
	sync_move_piece(old_key, new_key, cell_x, cell_y, dir)
	if multiplayer.multiplayer_peer:
		rpc("sync_move_piece", old_key, new_key, cell_x, cell_y, dir)

func _sync_move_prop(old_key: String, new_key: String, pos_x: float, pos_y: float, pos_z: float):
	sync_move_prop(old_key, new_key, pos_x, pos_y, pos_z)
	if multiplayer.multiplayer_peer:
		rpc("sync_move_prop", old_key, new_key, pos_x, pos_y, pos_z)


# ── RPC: place token ──────────────────────────────────────────────────────────

@rpc("authority", "call_local", "reliable")
func sync_place_token(key: String, data: Dictionary):
	if placed_tokens.has(key):
		return
	var token = token_scene.instantiate()
	token_holder.add_child(token)
	token.init_from_data(data, grid.cell_size, grid.grid_size)
	var cell_x = int(data.get("cell_x", 0))
	var cell_y = int(data.get("cell_y", 0))
	var base_y = get_cell_surface_y(cell_x, cell_y)
	if data.get("free_placement", false) and data.has("position_y"):
		base_y = max(base_y, data.position_y)
	token.set_terrain_height(base_y)
	placed_tokens[key] = token
	update_fog()


@rpc("authority", "call_local", "reliable")
func sync_remove_token(key: String):
	if placed_tokens.has(key):
		placed_tokens[key].queue_free()
		placed_tokens.erase(key)
		update_fog()


@rpc("authority", "call_local", "reliable")
func sync_move_token(old_key: String, new_key: String, data: Dictionary):
	if not placed_tokens.has(old_key):
		return
	var token = placed_tokens[old_key]
	placed_tokens.erase(old_key)
	token.init_from_data(data, grid.cell_size, grid.grid_size)
	var cell_x = int(data.get("cell_x", 0))
	var cell_y = int(data.get("cell_y", 0))
	var base_y = get_cell_surface_y(cell_x, cell_y)
	if data.get("free_placement", false) and data.has("position_y"):
		base_y = max(base_y, data.position_y)
	token.set_terrain_height(base_y)
	placed_tokens[new_key] = token
	update_fog()


@rpc("authority", "call_local", "reliable")
func sync_place_piece(key: String, type_name: String, cell_x: int, cell_y: int, dir: String, model_path: String, floor: int = 0):
	if placed_pieces.has(key):
		return
	var cell_pos = Vector2(cell_x, cell_y)
	var piece: Node
	if type_name == "wall":
		if model_path != "":
			piece = preload("res://terrain/pieces/custom_wall.tscn").instantiate()
			piece.custom_model_path = model_path
		else:
			piece = pieces["wall"].instantiate()
		piece.init(cell_pos, dir, grid.cell_size, grid.grid_size)
	elif type_name.begins_with("floor_"):
		if model_path != "":
			piece = preload("res://terrain/pieces/custom_floor.tscn").instantiate()
			piece.custom_model_path = model_path
		elif pieces.has(type_name):
			piece = pieces[type_name].instantiate()
		else:
			return
		piece.init(cell_pos, grid.cell_size, grid.grid_size)
	if piece.has_method("set_tile_type"):
		piece.set_tile_type(type_name)
	terrain_holder.add_child(piece)
	piece.position.y += _get_stack_height_at(cell_pos) + floor * FLOOR_HEIGHT
	piece.set_meta("floor", floor)
	placed_pieces[key] = piece
	piece_floors[key] = floor
	tile_grid[key] = piece
	if tile_fusion:
		tile_fusion.on_tile_placed(piece, cell_pos)
	update_fog()
	if floor_manager:
		piece.visible = floor == floor_manager.current_floor


@rpc("authority", "call_local", "reliable")
func sync_remove_piece(key: String):
	if placed_pieces.has(key):
		placed_pieces[key].queue_free()
		placed_pieces.erase(key)
		piece_floors.erase(key)
		if key.begins_with("floor_") and tile_fusion:
			var parts = key.split("_")
			if parts.size() >= 3:
				var cell_pos = Vector2(float(parts[1]), float(parts[2]))
				tile_fusion.on_tile_removed(cell_pos)
		tile_grid.erase(key)
		update_fog()


@rpc("authority", "call_local", "reliable")
func sync_place_prop(key: String, data: Dictionary, cell_x: int, cell_y: int):
	if placed_props.has(key):
		return
	var cell_pos = Vector2(cell_x, cell_y)
	var prop = prop_scene.instantiate()
	prop_holder.add_child(prop)
	prop.init(data, cell_pos, grid.cell_size, grid.grid_size)
	var base_y = get_cell_surface_y(cell_x, cell_y)
	if data.has("free_placement") and data.has("position_y"):
		base_y = max(base_y, data.position_y)
	prop.position.y = base_y
	placed_props[key] = prop
	update_fog()


@rpc("authority", "call_local", "reliable")
func sync_remove_prop(key: String):
	if placed_props.has(key):
		placed_props[key].queue_free()
		placed_props.erase(key)
		update_fog()


@rpc("authority", "call_local", "reliable")
func sync_update_token_field(key: String, field: String, value):
	if placed_tokens.has(key):
		var token = placed_tokens[key]
		token.set(field, value)
		token.update_visuals()
		update_fog()


@rpc("any_peer", "call_remote", "reliable")
func request_update_token_field(key: String, field: String, value):
	if not multiplayer.is_server():
		return
	_sync_update_token_field(key, field, value)


@rpc("authority", "call_local", "reliable")
func sync_move_piece(old_key: String, new_key: String, cell_x: int, cell_y: int, dir: String):
	if not placed_pieces.has(old_key):
		return
	var piece = placed_pieces[old_key]
	var floor = piece_floors.get(old_key, 0)
	placed_pieces.erase(old_key)
	piece_floors.erase(old_key)
	tile_grid.erase(old_key)
	var cell_pos = Vector2(cell_x, cell_y)
	if piece is Node and piece.has_method("init"):
		if piece.piece_type == "wall":
			piece.init(cell_pos, dir, grid.cell_size, grid.grid_size)
		else:
			piece.init(cell_pos, grid.cell_size, grid.grid_size)
	piece.position.y = _get_stack_height_at(cell_pos) + floor * FLOOR_HEIGHT
	piece.set_meta("floor", floor)
	placed_pieces[new_key] = piece
	piece_floors[new_key] = floor
	tile_grid[new_key] = piece
	if old_key.begins_with("floor_") and tile_fusion:
		var old_parts = old_key.split("_")
		if old_parts.size() >= 3:
			var old_cell = Vector2(float(old_parts[1]), float(old_parts[2]))
			tile_fusion.on_tile_moved(piece, old_cell, cell_pos)
	update_fog()


@rpc("authority", "call_local", "reliable")
func sync_move_prop(old_key: String, new_key: String, pos_x: float, pos_y: float, pos_z: float):
	if not placed_props.has(old_key):
		return
	var prop = placed_props[old_key]
	placed_props.erase(old_key)
	prop.position = Vector3(pos_x, pos_y, pos_z)
	placed_props[new_key] = prop
	update_fog()


@rpc("authority", "call_local", "reliable")
func sync_scale_prop(key: String, multiplier: float):
	if placed_props.has(key):
		placed_props[key].apply_scale(multiplier)


func _sync_scale_prop(key: String, multiplier: float):
	sync_scale_prop(key, multiplier)
	if multiplayer.multiplayer_peer:
		rpc("sync_scale_prop", key, multiplier)


@rpc("any_peer", "call_remote", "reliable")
func request_move_token(old_key: String, new_key: String, data: Dictionary):
	if not multiplayer.is_server():
		return
	var sender = multiplayer.get_remote_sender_id()
	if not placed_tokens.has(old_key):
		return
	if placed_tokens[old_key].owner_id not in [-1, sender]:
		return
	_sync_move_token(old_key, new_key, data)


# ── dice sync ──────────────────────────────────────────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func report_dice_result(result: int, die_type: int, custom_text: String, roller_name: String, roller_id: int):
	if not multiplayer.is_server():
		return
	rpc("sync_dice_result", result, die_type, custom_text, roller_name, roller_id)


@rpc("authority", "call_local", "reliable")
func sync_dice_result(result: int, die_type: int, custom_text: String, roller_name: String, roller_id: int):
	var my_id = multiplayer.get_unique_id() if multiplayer.multiplayer_peer else 1
	if roller_id == my_id:
		return
	var result_ui = preload("res://ui/dice_result.tscn").instantiate()
	$UI.add_child(result_ui)
	result_ui.show_result(result, die_type, custom_text)
	var lp = $UI/LogPanel if has_node("UI/LogPanel") else null
	if lp and lp.has_method("add_dice_entry"):
		lp.add_dice_entry(result, die_type, custom_text, roller_name)


# ── chat sync ──────────────────────────────────────────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func report_chat_message(text: String, sender_name: String, sender_id: int):
	if not multiplayer.is_server():
		return
	rpc("sync_chat_message", text, sender_name, sender_id)


@rpc("authority", "call_local", "reliable")
func sync_chat_message(text: String, sender_name: String, sender_id: int):
	var lp = $UI/LogPanel if has_node("UI/LogPanel") else null
	if lp and lp.has_method("add_chat_entry"):
		lp.add_chat_entry(text, sender_name, sender_id)


# ── AoE sync ──────────────────────────────────────────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func request_place_aoe(key: String, data_json: String):
	if not multiplayer.is_server():
		return
	rpc("sync_place_aoe", key, data_json)


@rpc("any_peer", "call_remote", "reliable")
func request_remove_aoe(key: String):
	if not multiplayer.is_server():
		return
	rpc("sync_remove_aoe", key)


@rpc("authority", "call_local", "reliable")
func sync_place_aoe(key: String, data_json: String):
	var data = JSON.parse_string(data_json)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var node = aoe_manager._spawn_aoe(data)
	placed_aoes[key] = node


@rpc("authority", "call_local", "reliable")
func sync_remove_aoe(key: String):
	if not placed_aoes.has(key):
		return
	var node = placed_aoes[key] as Node3D
	if node:
		node.queue_free()
	placed_aoes.erase(key)


@rpc("any_peer", "call_remote", "reliable")
func request_clear_all_aoes():
	if not multiplayer.is_server():
		return
	_clear_aoes()
	rpc("sync_clear_all_aoes")


@rpc("authority", "call_local", "reliable")
func sync_clear_all_aoes():
	_clear_aoes()


func _clear_aoes():
	for key in placed_aoes.keys():
		var node = placed_aoes[key] as Node3D
		if node:
			node.queue_free()
	placed_aoes.clear()


# ── full state request (for reconnect) ─────────────────────────────────────────

@rpc("any_peer", "call_remote", "reliable")
func request_full_state():
	if not multiplayer.is_server():
		return
	_do_sync_full_state()


@rpc("authority", "call_local", "reliable")
func sync_full_state(tokens: Dictionary, pieces: Dictionary, props: Dictionary, aoes: Dictionary = {}, grid_params: Dictionary = {}, combat_state: Dictionary = {}):
	_clear_all_placed()

	if not grid_params.is_empty():
		grid.grid_size = int(grid_params.grid_size)
		grid.grid_color = Color(grid_params.color_r, grid_params.color_g, grid_params.color_b, grid_params.color_a)
		grid.draw_grid()

	for key in tokens:
		sync_place_token(key, tokens[key])
	for key in pieces:
		var d = pieces[key]
		sync_place_piece(key, d.type, d.cell_x, d.cell_y, d.dir, d.model_path, d.get("floor", 0))
	for key in props:
		var d = props[key]
		sync_place_prop(key, d.data, d.cell_x, d.cell_y)
		if d.has("scale_multiplier"):
			var prop = placed_props.get(key)
			if prop:
				prop.apply_scale(float(d.scale_multiplier))
	for key in aoes:
		var d = aoes[key]
		if typeof(d) == TYPE_DICTIONARY:
			var node = aoe_manager._spawn_aoe(d)
			placed_aoes[key] = node
	update_fog()
	if not combat_state.is_empty():
		var tracker = $InitiativeTracker
		if tracker:
			tracker.deserialize(combat_state)
			tracker.turn_order_changed.emit(tracker.turn_order)
			if tracker.is_active and tracker.current_turn_index >= 0:
				tracker.turn_changed.emit(tracker.turn_order[tracker.current_turn_index].key)
	if not _has_received_state:
		_has_received_state = true
		if tokens.size() > 0 or pieces.size() > 0 or props.size() > 0:
			var mp = multiplayer.multiplayer_peer
			if mp and not multiplayer.is_server():
				library_panel.visible = false
				player_window.visible = true
				var lobby = $UI/Lobby
				if lobby:
					lobby.visible = false


# ── tool helpers (called by selection_manager, used by library_panel) ─────────
func set_tool_move():
	selection_manager.set_tool_move()

func set_tool_demolish():
	selection_manager.set_tool_demolish()

func set_tool_ruler():
	selection_manager.set_tool_ruler()

func set_tool_select():
	selection_manager.set_tool_select()

func select_piece(type: String):
	selection_manager.select_piece(type)

func toggle_point_indicator():
	point_indicator.toggle()


# ── world hit + coordinate math ───────────────────────────────────────────────
# These live here because they depend on the camera and physics world,
# and every handler needs them.

func get_world_hit(mouse_pos: Vector2, exclude_rid: RID = RID()) -> Variant:
	var cam        = $Camera/Camera3D
	var ray_origin = cam.project_ray_origin(mouse_pos)
	var ray_end    = ray_origin + cam.project_ray_normal(mouse_pos) * 1000
	var space      = get_world_3d().direct_space_state
	var query      = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	if exclude_rid.is_valid():
		query.exclude = [exclude_rid]
	var result = space.intersect_ray(query)
	if result.is_empty():
		return null
	return result

func world_to_cell(world_x: float, world_z: float) -> Vector2:
	var cell = grid.cell_size
	var half = (grid.grid_size * cell) / 2.0
	var cx   = floor((world_x + half) / cell)
	var cz   = floor((world_z + half) / cell)
	cx = clamp(cx, 0, grid.grid_size - 1)
	cz = clamp(cz, 0, grid.grid_size - 1)
	return Vector2(cx, cz)

func get_closest_edge(world_x: float, world_z: float, cell_pos: Vector2) -> String:
	var cell  = grid.cell_size
	var half  = (grid.grid_size * cell) / 2.0
	var cx    = (cell_pos.x * cell) - half + cell / 2.0
	var cz    = (cell_pos.y * cell) - half + cell / 2.0
	var dist_n = abs(world_z - (cz - cell / 2.0))
	var dist_s = abs(world_z - (cz + cell / 2.0))
	var dist_e = abs(world_x - (cx + cell / 2.0))
	var dist_w = abs(world_x - (cx - cell / 2.0))
	var min_d  = min(dist_n, min(dist_s, min(dist_e, dist_w)))
	if min_d == dist_n: return "N"
	if min_d == dist_s: return "S"
	if min_d == dist_e: return "E"
	return "W"


# ── floor sync ────────────────────────────────────────────────────────────────
# Floor plane + collision are now sized in the editor (massive, like TaleSpire's
# infinite board). This function only syncs fog & grid.
func sync_floor():
	fog.build_fog(grid.grid_size, grid.cell_size)
	update_fog()
	if floor_manager:
		floor_manager._apply_floor_filter()


# ── grid sync ─────────────────────────────────────────────────────────────────
@rpc("authority", "call_local", "reliable")
func sync_grid_params(grid_size: int, color_r: float, color_g: float, color_b: float, color_a: float):
	grid.grid_size = grid_size
	grid.grid_color = Color(color_r, color_g, color_b, color_a)
	grid.draw_grid()
	if grid_size > 0:
		sync_floor()


# ── fog coordination ──────────────────────────────────────────────────────────
@rpc("authority", "call_local", "reliable")
func sync_fog_params(fog_enabled: bool, vision_radius: float, feather: float, darkness: float, color_r: float, color_g: float, color_b: float):
	fog.fog_enabled = fog_enabled
	fog.global_vision_radius = vision_radius
	fog.feather = feather
	fog.darkness = darkness
	fog.fog_color = Color(color_r, color_g, color_b)
	update_fog()


func update_fog():
	if not fog:
		return
	var token_list = []
	for key in placed_tokens:
		token_list.append(placed_tokens[key])
	fog.update_fog(token_list)

func update_fog_with_preview(preview_pos: Vector3):
	if not fog:
		return
	var dragged = drag_controller.dragged_piece
	var token_list = []
	for key in placed_tokens:
		var token = placed_tokens[key]
		if token == dragged:
			token_list.append({
				"token_type":    token.token_type,
				"position":      preview_pos,
				"move_speed":    token.move_speed,
				"blinded":       token.blinded,
				"vision_radius": token.vision_radius
			})
		else:
			token_list.append(token)
	fog.update_fog(token_list)


# ── UI guard ──────────────────────────────────────────────────────────────────
func is_mouse_over_ui() -> bool:
	return _is_control_under_point($UI, get_viewport().get_mouse_position())

var text_input_focused := false

func is_text_input_focused() -> bool:
	return text_input_focused

func _on_focus_changed(control: Control):
	text_input_focused = control != null and (control is LineEdit or control is TextEdit)

func _is_control_under_point(node: Node, point: Vector2) -> bool:
	for child in node.get_children():
		if child is Control:
			if not child.visible:
				continue
			if child.mouse_filter == Control.MOUSE_FILTER_STOP:
				var rect = Rect2(child.global_position, child.size)
				if rect.has_point(point):
					return true
		if _is_control_under_point(child, point):
			return true
	return false


# ── stack height helper (used by terrain_placer) ──────────────────────────────
func _get_stack_height_at(cell_pos: Vector2) -> float:
	if terraform_manager:
		return terraform_manager.get_stack_height(cell_pos)
	return 0.0

# Compute the top surface Y at a grid cell from game state (no physics raycast).
# Accounts for terraform blocks, floor tiles, and stacked props in order.
func get_cell_surface_y(cell_x: int, cell_y: int) -> float:
	var cell_pos = Vector2(cell_x, cell_y)
	var y = _get_stack_height_at(cell_pos)
	var floor_key = "floor_%d_%d" % [cell_x, cell_y]
	if placed_pieces.has(floor_key):
		y = max(y, placed_pieces[floor_key].position.y + 0.1)
	var prop_prefix = "prop_%d_%d" % [cell_x, cell_y]
	for pk in placed_props:
		if pk == prop_prefix or pk.begins_with(prop_prefix + "_"):
			var existing = placed_props[pk]
			if existing.has_method("get_top_surface_y") and existing.mesh_instance:
				y = max(y, existing.get_top_surface_y())
			else:
				y = max(y, existing.position.y + 0.5)
	return y

# Vertical raycast to find the top surface Y at any world (x,z) position.
# Accounts for floor tiles and the ground plane whose collision shapes
# don't match their visual surface.
func get_surface_height_at(world_x: float, world_z: float, exclude: Array = []) -> float:
	var space = get_world_3d().direct_space_state
	var origin = Vector3(world_x, 500.0, world_z)
	var end = Vector3(world_x, -500.0, world_z)
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	if exclude.size() > 0:
		query.exclude = exclude
	var result = space.intersect_ray(query)
	if result:
		var col = result.collider
		if col is Node and col.get("piece_type") == "floor":
			return col.position.y + 0.1
		if col is ModularBlock:
			var cell = world_to_cell(world_x, world_z)
			return _get_stack_height_at(cell)
		# If the collider is the ground plane StaticBody3D, return 0.
		if col == get_node_or_null("StaticBody3D"):
			return 0.0
		return result.position.y
	return 0.0


func _toggle_library():
	_panel_collapsed.library = not _panel_collapsed.library
	var collapsed = _panel_collapsed.library
	var tween = create_tween()
	if collapsed:
		tween.tween_property(library_panel, "offset_left", -249.0, 0.2)
		tween.parallel().tween_property(library_panel, "offset_right", 0.0, 0.2)
		library_handle.text = "▶"
	else:
		tween.tween_property(library_panel, "offset_left", 13.0, 0.2)
		tween.parallel().tween_property(library_panel, "offset_right", 262.0, 0.2)
		library_handle.text = "◀"

func _toggle_pw():
	_panel_collapsed.pw = not _panel_collapsed.pw
	var collapsed = _panel_collapsed.pw
	var tween = create_tween()
	if collapsed:
		tween.tween_property(player_window, "offset_left", 0.0, 0.2)
		tween.parallel().tween_property(player_window, "offset_right", 260.0, 0.2)
		pw_handle.text = "◀"
	else:
		tween.tween_property(player_window, "offset_left", -260.0, 0.2)
		tween.parallel().tween_property(player_window, "offset_right", 0.0, 0.2)
		pw_handle.text = "▶"

func _toggle_log():
	_panel_collapsed.log = not _panel_collapsed.log
	var collapsed = _panel_collapsed.log
	var tween = create_tween()
	if collapsed:
		tween.tween_property(log_panel, "offset_top", 0.0, 0.2)
		tween.parallel().tween_property(log_panel, "offset_bottom", 346.0, 0.2)
		log_handle.text = "▲"
	else:
		tween.tween_property(log_panel, "offset_top", -346.0, 0.2)
		tween.parallel().tween_property(log_panel, "offset_bottom", 0.0, 0.2)
		log_handle.text = "▼"


# ── initiative combat RPCs (client → server) ──────────────────────

@rpc("any_peer", "call_remote", "reliable")
func request_end_turn_from_client():
	if not multiplayer.is_server():
		return
	$InitiativeTracker.end_turn()

@rpc("any_peer", "call_remote", "reliable")
func request_end_combat_from_client():
	if not multiplayer.is_server():
		return
	$InitiativeTracker.end_combat()

@rpc("any_peer", "call_remote", "reliable")
func request_add_to_combat_from_client(token_key: String, total: int):
	if not multiplayer.is_server():
		return
	$InitiativeTracker.add_to_combat(token_key, total)



func _on_reconnecting(attempt: int, max_attempts: int):
	_has_received_state = false
	var overlay = $UI/ReconnectOverlay
	if overlay:
		overlay.visible = true
		overlay.get_node("Label").text = "Reconnecting..."
		overlay.get_node("AttemptLabel").text = "Attempt %d/%d" % [attempt, max_attempts]


func _on_reconnected():
	var overlay = $UI/ReconnectOverlay
	if overlay:
		overlay.visible = false


func _on_reconnect_failed():
	var overlay = $UI/ReconnectOverlay
	if overlay:
		overlay.get_node("Label").text = "Reconnection Failed"
		overlay.get_node("AttemptLabel").text = "Press Escape to return to menu"
