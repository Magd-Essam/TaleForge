extends Node

# ─────────────────────────────────────────────────────────────────────────────
# selection_manager.gd
#
# Owns the current tool state:
#   • which tool is active (MOVE / DEMOLISH / PLACE / RULER / SELECT)
#   • which piece/token is selected for placement
#   • the bridge between library_panel and the placement handlers
#   • multi-select support for slab copy/paste
# ─────────────────────────────────────────────────────────────────────────────

enum Tool { MOVE, DEMOLISH, PLACE, RULER, SELECT }

var current_tool         : int    = Tool.MOVE
var selected_piece       : String = ""
var selected_custom_path : String = ""
var selected_token_data  : Dictionary = {}
var selected_prop_data : Dictionary = {}

# Currently selected prop in the world (for moving/rotating/etc)
var selected_prop : Node = null

var world : Node  # set in _ready


func _ready():
	world = get_parent()


# ── tool setters (called by world.gd and library_panel buttons) ───────────────

func set_tool_select():
	current_tool   = Tool.SELECT
	selected_piece = ""
	_clear_ruler()

func set_tool_move():
	current_tool   = Tool.MOVE
	selected_piece = ""
	_clear_ruler()

func set_tool_demolish():
	current_tool   = Tool.DEMOLISH
	selected_piece = ""
	_clear_ruler()

func set_tool_ruler():
	current_tool   = Tool.RULER
	selected_piece = ""
	_clear_ruler()

func select_piece(type: String):
	current_tool   = Tool.PLACE
	selected_piece = type
	_clear_ruler()

func select_token(data: Dictionary):
	current_tool        = Tool.PLACE
	selected_piece      = "token"
	selected_token_data = data
	_clear_ruler()

func select_prop(data: Dictionary):
	current_tool        = Tool.PLACE
	selected_piece      = "prop"
	selected_prop_data  = data
	_clear_ruler()

func select_custom_piece(type: String, model_path: String):
	current_tool         = Tool.PLACE
	selected_custom_path = model_path
	selected_piece       = "wall_custom" if type == "wall" else "floor_custom"
	_clear_ruler()


func select_prop_node(prop: Node):
	selected_prop = prop
	if prop:
		prop.select()


func deselect_prop():
	if selected_prop:
		selected_prop.deselect()
	selected_prop = null


func _clear_ruler():
	if world and world.has_method("get_node") and world.ruler_manager:
		world.ruler_manager.clear()


# ── asset selected signal (connected from library_panel) ─────────────────────

func _on_asset_selected(category: String, asset: Dictionary):
	match category:
		"tokens":
			select_token({
				"name":       asset.name,
				"type":       0,
				"hp":         10,
				"max_hp":     10,
				"initiative": 0,
				"model_path": asset.path
			})
		"props":
			select_prop({
				"name":       asset.name,
				"model_path": asset.path
			})
		"nature":
			select_prop({
				"name":       asset.name,
				"model_path": asset.path
			})
		"monsters":
			select_token({
				"name":       asset.name,
				"type":       1,
				"hp":         15,
				"max_hp":     15,
				"initiative": 0,
				"model_path": asset.path
			})
		"walls":
			select_custom_piece("wall",  asset.path)
		"floors":
			select_custom_piece("floor", asset.path)
