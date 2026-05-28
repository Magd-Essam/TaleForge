extends Node

const SETTINGS_PATH := "user://settings.cfg"

var resolution: Vector2i = Vector2i(1600, 900)
var fullscreen: bool = false
var borderless: bool = false
var vsync: bool = true
var quality_preset: int = 2
var shadow_quality: int = 1
var msaa: int = 2
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var grid_snap: bool = true
var camera_sensitivity: float = 1.0
var camera_invert_y: bool = false
var default_port: int = 4789
var player_name: String = "Player"




func _ready():
	load_settings()


func load_settings():
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	resolution = config.get_value("display", "resolution", resolution)
	fullscreen = config.get_value("display", "fullscreen", fullscreen)
	borderless = config.get_value("display", "borderless", borderless)
	vsync = config.get_value("graphics", "vsync", vsync)
	quality_preset = config.get_value("graphics", "quality_preset", quality_preset)
	shadow_quality = config.get_value("graphics", "shadow_quality", shadow_quality)
	msaa = config.get_value("graphics", "msaa", msaa)
	master_volume = config.get_value("audio", "master_volume", master_volume)
	sfx_volume = config.get_value("audio", "sfx_volume", sfx_volume)
	music_volume = config.get_value("audio", "music_volume", music_volume)
	grid_snap = config.get_value("gameplay", "grid_snap", grid_snap)
	camera_sensitivity = config.get_value("gameplay", "camera_sensitivity", camera_sensitivity)
	camera_invert_y = config.get_value("gameplay", "camera_invert_y", camera_invert_y)
	default_port = config.get_value("network", "default_port", default_port)
	player_name = config.get_value("network", "player_name", player_name)


func save():
	var config = ConfigFile.new()
	config.set_value("display", "resolution", resolution)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("display", "borderless", borderless)
	config.set_value("graphics", "vsync", vsync)
	config.set_value("graphics", "quality_preset", quality_preset)
	config.set_value("graphics", "shadow_quality", shadow_quality)
	config.set_value("graphics", "msaa", msaa)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("gameplay", "grid_snap", grid_snap)
	config.set_value("gameplay", "camera_sensitivity", camera_sensitivity)
	config.set_value("gameplay", "camera_invert_y", camera_invert_y)
	config.set_value("network", "default_port", default_port)
	config.set_value("network", "player_name", player_name)
	config.save(SETTINGS_PATH)


func apply():
	apply_graphics()
	apply_audio()


func apply_graphics():
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if borderless else DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		call_deferred("_apply_windowed_size")

	var msaa_values = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X]
	var vp = get_viewport()
	if vp:
		vp.set("msaa_3d", msaa_values[msaa])


func _apply_windowed_size():
	DisplayServer.window_set_size(resolution)
	var ss = DisplayServer.screen_get_size()
	DisplayServer.window_set_position(Vector2i(
		maxi(0, (ss.x - resolution.x) / 2),
		maxi(0, (ss.y - resolution.y) / 2)
	))


func apply_audio():
	var idx = AudioServer.get_bus_index("Master")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(master_volume))
	idx = AudioServer.get_bus_index("SFX")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(sfx_volume))
	idx = AudioServer.get_bus_index("Music")
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(music_volume))
