@tool
extends Node


const ASSET_FOLDERS = {
	"walls": "res://assets/walls/",
	"floors": "res://assets/floors/",
	"props": "res://assets/props/",
	"nature": "res://assets/nature/",
	"tokens": "res://assets/tokens/",
	"monsters": "res://assets/tokens/monsters/",
}
const MANIFEST_PATH = "res://builtin_assets.json"


func _ready():
	if Engine.is_editor_hint():
		call_deferred("_regenerate_manifest")


func _regenerate_manifest():
	get_default_assets()
	_generate_imported_manifest()


func _generate_imported_manifest():
	if not Engine.is_editor_hint():
		return
	for cat in AssetLibrary.library.values():
		if cat.size() > 0:
			var file = FileAccess.open("res://imported_assets.json", FileAccess.WRITE)
			if file:
				file.store_string(JSON.stringify(AssetLibrary.library, "\t"))
				file.close()
			return


func get_default_assets():
	if not Engine.is_editor_hint():
		var loaded = _load_manifest()
		if loaded != null:
			return loaded

	var result = {
		"walls": [], "floors": [], "props": [],
		"nature": [], "tokens": [], "monsters": [],
	}
	for category in ASSET_FOLDERS:
		scan_folder(ASSET_FOLDERS[category], category, result)
	_save_manifest(result)
	return result


func _load_manifest():
	var file = FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if not file:
		return null
	var text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return null
	# Mark all as builtin (the JSON doesn't store this)
	for cat in data:
		if typeof(data[cat]) == TYPE_ARRAY:
			for entry in data[cat]:
				if typeof(entry) == TYPE_DICTIONARY:
					entry["builtin"] = true
	return data


func _save_manifest(data: Dictionary):
	var file = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func scan_folder(path: String, category: String, result: Dictionary):
	var dir = DirAccess.open(path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		var full_path = path + file_name
		if dir.current_is_dir():
			if category == "tokens" and file_name == "monsters":
				file_name = dir.get_next()
				continue
			scan_folder(full_path + "/", category, result)
		elif file_name.ends_with(".glb") or file_name.ends_with(".gltf"):
			var asset_name = file_name.get_basename()
			result[category].append({
				"name": asset_name,
				"path": full_path,
				"builtin": true
			})
		file_name = dir.get_next()
	dir.list_dir_end()
