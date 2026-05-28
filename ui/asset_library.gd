extends Node

signal library_updated

const SAVE_PATH = "user://asset_library.json"

var library = {
	"tokens": [],
	"props": [],
	"walls": [],
	"floors": [],
	"nature": [],
	"monsters": []
}

func _ready():
	load_library()

func add_asset_button(container, asset, category):
	print("add_asset_button called: ", asset.name)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.custom_minimum_size = Vector2(50, 50)
	var thumb = TextureRect.new()
	thumb.custom_minimum_size = Vector2(50, 50)
	thumb.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(thumb)

	# Load thumbnail — call directly not deferred
	load_thumbnail(thumb, asset.path)

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

func load_thumbnail(thumb: TextureRect, model_path: String):
	print("load_thumbnail called for: ", model_path)
	var generator = get_tree().get_root().get_node_or_null("World/UI/ThumbnailStudio")
	if not generator:
		print("NO GENERATOR FOUND")
		return
	var tex = await generator.generate_thumbnail(model_path)
	print("tex received: ", tex)
	if tex and is_instance_valid(thumb):
		thumb.texture = tex
		print("texture set!")

func remove_asset(category: String, path: String):
	for i in range(library[category].size()):
		if library[category][i].path == path:
			library[category].remove_at(i)
			break
	save_library()
	emit_signal("library_updated")

func add_asset(category: String, asset_name: String, path: String):
	if not library.has(category):
		library[category] = []
	
	library[category].append({
		"name": asset_name,
		"path": path
	})
	save_library()
	emit_signal("library_updated")

func save_library():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(library))
		file.close()

func load_library():
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var text = file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(text)
			if parsed:
				library = parsed
				_migrate_library()
			save_library()
			return

	# Fallback: load manifest generated at build time (exported game)
	if FileAccess.file_exists("res://imported_assets.json"):
		var file = FileAccess.open("res://imported_assets.json", FileAccess.READ)
		if file:
			var text = file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(text)
			if parsed:
				library = parsed
				_migrate_library()


func _migrate_library():
	if not library.has("walls"):
		library["walls"] = []
	if not library.has("floors"):
		library["floors"] = []
	if not library.has("props"):
		library["props"] = []
	if not library.has("tokens"):
		library["tokens"] = []
	if not library.has("nature"):
		library["nature"] = []
	if not library.has("monsters"):
		library["monsters"] = []
