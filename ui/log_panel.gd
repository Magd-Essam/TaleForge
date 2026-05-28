extends Control

var world: Node
var _nm: Node

@onready var log_list = $Panel/ScrollContainer/LogList
@onready var chat_input = $Panel/ChatInput


func _ready():
	world = get_tree().get_root().get_node("world")
	_nm = world.get_node_or_null("NetworkManager")
	if _nm:
		_nm.player_connected.connect(_on_player_connected)
		_nm.player_disconnected.connect(_on_player_disconnected)

	chat_input.text_submitted.connect(_on_chat_submitted)


func add_dice_entry(result: int, die_type: int, label: String, roller_name: String):
	_add_entry("[b]%s[/b] rolled d%s: %s" % [roller_name, str(die_type), label])


func add_chat_entry(text: String, sender_name: String, sender_id: int):
	var col = Color.WHITE
	if _nm and _nm.players.has(sender_id) and _nm.players[sender_id].has("color"):
		col = _nm.players[sender_id].color
	var hex = "#%02x%02x%02x" % [int(col.r * 255), int(col.g * 255), int(col.b * 255)]
	_add_entry("[color=%s]%s[/color]: %s" % [hex, sender_name, text])


func add_system_entry(text: String):
	_add_entry("[i]%s[/i]" % text)


func _add_entry(bbcode: String):
	var lbl = RichTextLabel.new()
	lbl.fit_content = true
	lbl.bbcode_enabled = true
	lbl.scroll_active = false
	lbl.add_theme_font_size_override("normal_font_size", 13)
	lbl.append_text(bbcode)
	log_list.add_child(lbl)
	# Scroll to bottom
	await get_tree().process_frame
	var sc = $Panel/ScrollContainer
	sc.scroll_vertical = int(sc.get_v_scroll_bar().max_value)


func _on_chat_submitted(text: String):
	if text.strip_edges().is_empty():
		return
	chat_input.text = ""
	var nm = _nm
	if not nm:
		return
	if multiplayer.is_server():
		world.rpc("sync_chat_message", text, nm.my_name, nm.my_id)
	else:
		world.rpc_id(1, "report_chat_message", text, nm.my_name, nm.my_id)


func _on_player_connected(id: int, name: String):
	add_system_entry("%s connected" % name)


func _on_player_disconnected(id: int):
	var name = "Unknown"
	if _nm and _nm.players.has(id):
		name = _nm.players[id].get("name", "Unknown")
	add_system_entry("%s disconnected" % name)
