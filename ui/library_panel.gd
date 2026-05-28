extends Control

signal asset_selected(category, asset)

@onready var tab_container  = $TabContainer
@onready var tokens_list    = $TabContainer/Tokens/TokensList
@onready var props_list     = $TabContainer/Props/PropsList
@onready var walls_list     = $TabContainer/Walls/WallsList
@onready var floors_list    = $TabContainer/Floors/FloorsList
@onready var btn_import     = $BtnImport
@onready var nature_list    = $TabContainer/Nature/NatureList
@onready var monsters_list  = $TabContainer/Monsters/MonstersList

var current_category = "tokens"
var world            = null
var grid_visible     = false
var fog_visible      = false
var terrain_visible  = false
var grid_nodes       = []
var fog_nodes        = []
var terrain_nodes    = []

var thumb_cache      = {}
var thumb_queue      = []
var is_generating    = false
var thumb_studio     : Node


func _ready():
	world = get_parent().get_parent()
	position = Vector2(10, 10)

	# Tool buttons
	$MoveBtn.pressed.connect(func(): world.set_tool_move())
	$DemolishBtn.pressed.connect(func(): world.set_tool_demolish())
	$SelectBtn.pressed.connect(func(): world.set_tool_select())
	$SnapBtn.pressed.connect(func():
		world.snap_enabled = !world.snap_enabled
		$SnapBtn.text = "Snap " + ("ON" if world.snap_enabled else "OFF")
	)

	# Grid controls
	grid_nodes = [$LabelGridSize, $SliderGridSize, $LabelGridColor, $ColorGridColor]
	$GridToggle.pressed.connect(func():
		grid_visible = !grid_visible
		for node in grid_nodes:
			node.visible = grid_visible
		$GridToggle.text = "Grid Settings " + ("▲" if grid_visible else "▼")
		reflow()
	)
	$SliderGridSize.value_changed.connect(_on_size_changed)
	$ColorGridColor.color_changed.connect(_on_color_changed)

	# Fog controls
	var fog = world.get_node("FogOfWar")
	fog_nodes = [$BtnFogToggle, $BtnGmToggle, $LabelVisionRadius, $SliderVisionRadius,
		$LabelFeather, $SliderFeather, $LabelDarkness, $SliderDarkness,
		$LabelFogColor, $ColorFogColor]

	$BtnFogToggle.pressed.connect(func():
		fog.fog_enabled = !fog.fog_enabled
		$BtnFogToggle.text = "Fog " + ("ON" if fog.fog_enabled else "OFF")
		_sync_fog()
	)
	$BtnGmToggle.pressed.connect(func():
		fog.toggle_gm_mode()
		$BtnGmToggle.text = "GM" if fog.is_gm_mode else "Player"
	)
	$SliderVisionRadius.value = fog.global_vision_radius
	$SliderVisionRadius.value_changed.connect(func(v):
		fog.global_vision_radius = v
		_sync_fog()
	)
	$SliderFeather.value = fog.feather
	$SliderFeather.value_changed.connect(func(v):
		fog.feather = v
		_sync_fog()
	)
	$SliderDarkness.value = fog.darkness
	$SliderDarkness.value_changed.connect(func(v):
		fog.darkness = v
		_sync_fog()
	)
	$ColorFogColor.color = fog.fog_color
	$ColorFogColor.color_changed.connect(func(c):
		fog.fog_color = c
		_sync_fog()
	)
	$FogToggle.pressed.connect(func():
		fog_visible = !fog_visible
		for node in fog_nodes:
			node.visible = fog_visible
		$FogToggle.text = "Fog Settings " + ("▲" if fog_visible else "▼")
		reflow()
	)

	# Terrain controls
	var tm = world.get_node_or_null("ModularTerraformManager")
	terrain_nodes = [$BtnTerraActivate]
	$TerraToggle.pressed.connect(func():
		terrain_visible = !terrain_visible
		for node in terrain_nodes:
			node.visible = terrain_visible
		$BtnTerraPlace.visible = terrain_visible
		$BtnTerraDrag.visible = terrain_visible
		$BtnTerraRemove.visible = terrain_visible
		$TerraToggle.text = "Terrain Blocks " + ("▲" if terrain_visible else "▼")
		reflow()
	)
	$BtnTerraActivate.pressed.connect(func():
		if tm:
			tm.toggle_active()
	)
	$BtnTerraPlace.pressed.connect(func():
		if tm:
			tm.set_terra_mode(ModularTerraformManager.TerraMode.PLACE)
	)
	$BtnTerraDrag.pressed.connect(func():
		if tm:
			tm.set_terra_mode(ModularTerraformManager.TerraMode.DRAG)
	)
	$BtnTerraRemove.pressed.connect(func():
		if tm:
			tm.set_terra_mode(ModularTerraformManager.TerraMode.REMOVE)
	)
	if tm:
		tm.mode_changed.connect(_on_terra_mode_changed)
	_refresh_terra_buttons(false, ModularTerraformManager.TerraMode.PLACE)

	# Library
	btn_import.text = "Import Asset"
	btn_import.pressed.connect(_on_import_pressed)
	tab_container.tab_changed.connect(_on_tab_changed)
	AssetLibrary.library_updated.connect(rebuild_library)

	thumb_studio = get_parent().get_node_or_null("ThumbnailStudio")
	if not thumb_studio:
		for node in get_tree().root.find_children("ThumbnailStudio", "Node3D", true, false):
			if node.has_method("generate_thumbnail"):
				thumb_studio = node
				break
	if not thumb_studio:
		push_error("LibraryPanel: ThumbnailStudio not found in scene tree!")

	call_deferred("reflow")
	call_deferred("rebuild_library")


func _sync_fog():
	var f = world.get_node("FogOfWar")
	world.rpc("sync_fog_params", f.fog_enabled,
		f.global_vision_radius, f.feather, f.darkness,
		f.fog_color.r, f.fog_color.g, f.fog_color.b)


func reflow():
	var grid_toggle_y   = 114
	var grid_content_y  = grid_toggle_y + 38
	var grid_end_y      = grid_content_y + (120 if grid_visible else 0)

	var fog_toggle_y    = grid_end_y + 4
	var fog_content_y   = fog_toggle_y + 38
	var fog_end_y       = fog_content_y + (280 if fog_visible else 0)

	var terra_toggle_y  = fog_end_y + 4
	var terra_content_y = terra_toggle_y + 38
	var terra_end_y     = terra_content_y + (66 if terrain_visible else 0)

	var tab_y           = terra_end_y + 4
	var import_y        = tab_y + 315

	var gt = $GridToggle
	if gt:
		gt.position = Vector2(8, grid_toggle_y)
	var gy = grid_content_y
	for node in grid_nodes:
		node.position = Vector2(8, gy)
		gy += int(node.size.y) + 6

	var ft = $FogToggle
	if ft:
		ft.position = Vector2(8, fog_toggle_y)
	var fy = fog_content_y
	for i in range(fog_nodes.size()):
		var node = fog_nodes[i]
		if i == 0:
			node.position = Vector2(8, fy)
		elif i == 1:
			node.position = Vector2(114, fy)
		else:
			if i == 2:
				fy += int(fog_nodes[0].size.y) + 6
			node.position = Vector2(8, fy)
			fy += int(node.size.y) + 6

	var tt = $TerraToggle
	if tt:
		tt.position = Vector2(8, terra_toggle_y)

	var ty = terra_content_y
	for node in terrain_nodes:
		node.position = Vector2(8, ty)
		ty += int(node.size.y) + 6

	var mode_row_y = terra_content_y + 36
	if $BtnTerraPlace:
		$BtnTerraPlace.position  = Vector2(8,   mode_row_y)
	if $BtnTerraDrag:
		$BtnTerraDrag.position   = Vector2(76,  mode_row_y)
	if $BtnTerraRemove:
		$BtnTerraRemove.position = Vector2(144, mode_row_y)

	tab_container.position = Vector2(4, tab_y + 10)
	btn_import.position    = Vector2(5, import_y + 120)
	size                   = Vector2(220, import_y + 40)


func _on_terra_mode_changed(active: bool, mode: int) -> void:
	_refresh_terra_buttons(active, mode)

func _refresh_terra_buttons(active: bool, mode: int) -> void:
	if $BtnTerraActivate:
		$BtnTerraActivate.text = "Terrain " + ("ON" if active else "OFF")

	if $BtnTerraPlace:
		$BtnTerraPlace.modulate  = Color(1, 1, 1) if mode == ModularTerraformManager.TerraMode.PLACE  else Color(0.55, 0.55, 0.55)
	if $BtnTerraDrag:
		$BtnTerraDrag.modulate   = Color(1, 1, 1) if mode == ModularTerraformManager.TerraMode.DRAG   else Color(0.55, 0.55, 0.55)
	if $BtnTerraRemove:
		$BtnTerraRemove.modulate = Color(1, 1, 1) if mode == ModularTerraformManager.TerraMode.REMOVE else Color(0.55, 0.55, 0.55)


func _on_tab_changed(tab):
	match tab:
		0: current_category = "tokens"
		1: current_category = "props"
		2: current_category = "walls"
		3: current_category = "floors"
		4: current_category = "nature"
		5: current_category = "monsters"

func rebuild_library():
	for child in tokens_list.get_children():
		child.queue_free()
	for child in props_list.get_children():
		child.queue_free()
	for child in walls_list.get_children():
		child.queue_free()
	for child in floors_list.get_children():
		child.queue_free()

	var defaults = DefaultLibrary.get_default_assets()

	add_builtin_button(walls_list,  "Wall (default)", "wall")
	for asset in defaults["walls"]:
		add_asset_button(walls_list, asset, "walls")
	for asset in AssetLibrary.library["walls"]:
		add_asset_button(walls_list, asset, "walls")

	add_builtin_button(floors_list, "Stone Floor", "floor_stone")
	add_builtin_button(floors_list, "Grass Floor", "floor_grass")
	add_builtin_button(floors_list, "Water Floor", "floor_water")
	for asset in defaults["floors"]:
		add_asset_button(floors_list, asset, "floors")
	for asset in AssetLibrary.library["floors"]:
		add_asset_button(floors_list, asset, "floors")

	for asset in defaults["tokens"]:
		add_asset_button(tokens_list, asset, "tokens")
	for asset in AssetLibrary.library["tokens"]:
		add_asset_button(tokens_list, asset, "tokens")

	for asset in defaults["props"]:
		add_asset_button(props_list, asset, "props")
	for asset in AssetLibrary.library["props"]:
		add_asset_button(props_list, asset, "props")

	for child in nature_list.get_children():
		child.queue_free()
	for child in monsters_list.get_children():
		child.queue_free()

	for asset in DefaultLibrary.get_default_assets().get("nature", []):
		add_asset_button(nature_list, asset, "nature")
	for asset in AssetLibrary.library.get("nature", []):
		add_asset_button(nature_list, asset, "nature")

	for asset in DefaultLibrary.get_default_assets().get("monsters", []):
		add_asset_button(monsters_list, asset, "monsters")
	for asset in AssetLibrary.library.get("monsters", []):
		add_asset_button(monsters_list, asset, "monsters")

func add_builtin_button(container, label: String, piece_name: String):
	var btn = Button.new()
	btn.text = label
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(func(): world.select_piece(piece_name))
	container.add_child(btn)

func add_asset_button(container, asset, category):
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var thumb = TextureRect.new()
	thumb.custom_minimum_size  = Vector2(120, 120)
	thumb.expand_mode          = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode         = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(thumb)

	request_thumbnail(thumb, asset.path)

	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn = Button.new()
	btn.text = asset.name
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(func(): emit_signal("asset_selected", category, asset))
	hbox.add_child(btn)

	var del_btn = Button.new()
	del_btn.text = "✖"
	del_btn.custom_minimum_size = Vector2(30, 0)
	del_btn.pressed.connect(func():
		AssetLibrary.remove_asset(category, asset.path)
	)
	hbox.add_child(del_btn)
	vbox.add_child(hbox)
	container.add_child(vbox)


func _on_size_changed(value):
	$LabelGridSize.text = "Grid Size: " + str(int(value))
	var g = world.get_node("grid")
	g.grid_size = int(value)
	g.draw_grid()
	world.sync_floor()
	world.rpc("sync_grid_params", int(value), g.grid_color.r, g.grid_color.g, g.grid_color.b, g.grid_color.a)

func _on_color_changed(color):
	var g = world.get_node("grid")
	g.grid_color = color
	g.draw_grid()
	world.rpc("sync_grid_params", g.grid_size, color.r, color.g, color.b, color.a)


func _on_import_pressed():
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters   = ["*.glb,*.gltf ; 3D Models"]
	dialog.access    = FileDialog.ACCESS_FILESYSTEM
	add_child(dialog)
	dialog.popup_centered(Vector2(800, 600))
	dialog.file_selected.connect(func(path):
		var asset_name  = path.get_file().get_basename()
		if asset_name.to_lower() == "scene":
			asset_name = path.get_base_dir().get_file()
		var src_folder  = path.get_base_dir()
		var dest_folder = ProjectSettings.globalize_path("res://tokens/imported/" + asset_name)
		DirAccess.make_dir_recursive_absolute(dest_folder)
		var dir = DirAccess.open(src_folder)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					var ext = file_name.get_extension().to_lower()
					if ext == "glb" or ext == "gltf":
						DirAccess.copy_absolute(src_folder + "/" + file_name, dest_folder + "/" + file_name)
				file_name = dir.get_next()
			dir.list_dir_end()
		var dest_path = "res://tokens/imported/" + asset_name + "/" + path.get_file()
		AssetLibrary.add_asset(current_category, asset_name, dest_path)
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())


func request_thumbnail(thumb_rect: TextureRect, model_path: String):
	if thumb_cache.has(model_path):
		thumb_rect.texture = thumb_cache[model_path]
		return
	thumb_queue.append({"rect": thumb_rect, "path": model_path})
	if not is_generating:
		process_thumb_queue()

func process_thumb_queue():
	if thumb_queue.is_empty():
		is_generating = false
		return
	if not thumb_studio:
		thumb_studio = get_parent().get_node_or_null("ThumbnailStudio")
		if not thumb_studio:
			await get_tree().process_frame
			if not is_instance_valid(get_tree()):
				is_generating = false
				return
			process_thumb_queue()
			return
	if not thumb_studio.has_method("generate_thumbnail"):
		push_error("LibraryPanel: ThumbnailStudio missing generate_thumbnail()!")
		is_generating = false
		return
	is_generating = true
	var item = thumb_queue.pop_front()
	var tex  = await thumb_studio.generate_thumbnail(item.path)
	if not is_instance_valid(get_tree()):
		is_generating = false
		return
	if tex and is_instance_valid(item.rect):
		thumb_cache[item.path] = tex
		item.rect.texture = tex
	await get_tree().process_frame
	if not is_instance_valid(get_tree()):
		is_generating = false
		return
	process_thumb_queue()
