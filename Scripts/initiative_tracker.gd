extends Node

var world: Node
var turn_order: Array = []
var current_turn_index: int = -1
var is_active: bool = false
var current_round: int = 1

signal turn_order_changed(order: Array)
signal turn_changed(token_key: String)
signal combat_ended()


func _ready():
	world = get_parent()


func start_combat(results: Dictionary):
	turn_order.clear()
	for key in results:
		var token = world.placed_tokens.get(key)
		if not token:
			continue
		var r = results[key]
		var owner_id = token.owner_id
		var player_color = Color(0.5, 0.5, 0.5)
		if owner_id > 0 and world.network_manager and world.network_manager.players.has(owner_id):
			player_color = world.network_manager.players[owner_id].get("color", Color(0.5, 0.5, 0.5))
		turn_order.append({
			"key": key,
			"initiative_base": token.initiative,
			"rolled": r.get("rolled", 0),
			"total": r.get("total", token.initiative),
			"token_name": token.token_name,
			"owner_id": owner_id,
			"conditions": token.get_condition_list(),
			"player_color": player_color
		})
	turn_order.sort_custom(func(a, b): return a.total > b.total)
	is_active = turn_order.size() > 0
	current_turn_index = 0 if is_active else -1
	current_round = 1
	_broadcast_state()


func end_turn():
	if not is_active or turn_order.size() == 0:
		return
	var prev_index = current_turn_index
	current_turn_index = (current_turn_index + 1) % turn_order.size()
	if current_turn_index == 0 and turn_order.size() > 0:
		current_round += 1
	_broadcast_state()


func end_combat():
	if not is_active:
		return
	is_active = false
	turn_order.clear()
	current_turn_index = -1
	current_round = 1
	_broadcast_state()


func add_to_combat(token_key: String, total: int):
	if not is_active:
		return
	var token = world.placed_tokens.get(token_key)
	if not token:
		return
	var owner_id = token.owner_id
	var player_color = Color(0.5, 0.5, 0.5)
	if owner_id > 0 and world.network_manager and world.network_manager.players.has(owner_id):
		player_color = world.network_manager.players[owner_id].get("color", Color(0.5, 0.5, 0.5))
	var entry = {
		"key": token_key,
		"initiative_base": token.initiative,
		"rolled": 0,
		"total": total,
		"token_name": token.token_name,
		"owner_id": owner_id,
		"conditions": token.get_condition_list(),
		"player_color": player_color
	}
	turn_order.append(entry)
	turn_order.sort_custom(func(a, b): return a.total > b.total)
	var new_index = 0
	for i in range(turn_order.size()):
		if turn_order[i].key == token_key:
			new_index = i
			break
	if new_index <= current_turn_index:
		current_turn_index = (current_turn_index + 1) % turn_order.size()
	_broadcast_state()


func edit_initiative(token_key: String, new_total: int):
	if not is_active:
		return
	for entry in turn_order:
		if entry.key == token_key:
			entry.total = new_total
			break
	turn_order.sort_custom(func(a, b): return a.total > b.total)
	var new_index = 0
	for i in range(turn_order.size()):
		if turn_order[i].key == token_key:
			new_index = i
			break
	if new_index <= current_turn_index:
		current_turn_index = (current_turn_index + 1) % turn_order.size()
	_broadcast_state()


func remove_from_combat(token_key: String):
	if not is_active:
		return
	var remove_index = -1
	for i in range(turn_order.size()):
		if turn_order[i].key == token_key:
			remove_index = i
			break
	if remove_index < 0:
		return
	turn_order.remove_at(remove_index)
	if turn_order.size() == 0:
		end_combat()
		return
	if remove_index < current_turn_index:
		current_turn_index -= 1
	elif remove_index == current_turn_index:
		if current_turn_index >= turn_order.size():
			current_turn_index = 0
	_broadcast_state()


func get_current_token_key() -> String:
	if is_active and current_turn_index >= 0 and current_turn_index < turn_order.size():
		return turn_order[current_turn_index].key
	return ""


func is_current_turn(token_key: String) -> bool:
	return is_active and get_current_token_key() == token_key


func serialize() -> Dictionary:
	var safe_order = []
	for entry in turn_order:
		var e = entry.duplicate()
		if typeof(e.get("player_color")) == TYPE_OBJECT and e.player_color is Color:
			e.player_color = { "r": e.player_color.r, "g": e.player_color.g, "b": e.player_color.b, "a": e.player_color.a }
		safe_order.append(e)
	return {
		"turn_order": safe_order,
		"current_turn_index": current_turn_index,
		"is_active": is_active,
		"current_round": current_round
	}


func deserialize(data: Dictionary):
	turn_order.clear()
	for entry in data.get("turn_order", []):
		var e = entry.duplicate()
		var pc = e.get("player_color", {})
		if typeof(pc) == TYPE_DICTIONARY:
			e.player_color = Color(pc.get("r", 0.5), pc.get("g", 0.5), pc.get("b", 0.5), pc.get("a", 1.0))
		turn_order.append(e)
	current_turn_index = data.get("current_turn_index", -1)
	is_active = data.get("is_active", false)
	current_round = data.get("current_round", 1)


@rpc("authority", "call_local", "reliable")
func sync_state(turn_order_data: Array, current_index: int, active: bool, round: int):
	turn_order.clear()
	for entry in turn_order_data:
		var e = entry.duplicate()
		var pc = e.get("player_color", {})
		if typeof(pc) == TYPE_DICTIONARY:
			e.player_color = Color(pc.get("r", 0.5), pc.get("g", 0.5), pc.get("b", 0.5), pc.get("a", 1.0))
		turn_order.append(e)
	current_turn_index = current_index
	is_active = active
	current_round = round
	turn_order_changed.emit(turn_order)
	if is_active and current_turn_index >= 0 and current_turn_index < turn_order.size():
		turn_changed.emit(turn_order[current_turn_index].key)
	elif not is_active:
		combat_ended.emit()


func _broadcast_state():
	var safe_order = []
	for entry in turn_order:
		var e = entry.duplicate()
		if typeof(e.get("player_color")) == TYPE_OBJECT and e.player_color is Color:
			e.player_color = { "r": e.player_color.r, "g": e.player_color.g, "b": e.player_color.b, "a": e.player_color.a }
		safe_order.append(e)
	rpc("sync_state", safe_order, current_turn_index, is_active, current_round)
