extends Control


@onready var opt_resolution = $Center/Panel/VBoxContainer/ScrollContainer/Content/RowResolution/OptResolution
@onready var chk_fullscreen = $Center/Panel/VBoxContainer/ScrollContainer/Content/RowFullscreen/ChkFullscreen
@onready var chk_borderless = $Center/Panel/VBoxContainer/ScrollContainer/Content/RowBorderless/ChkBorderless
@onready var opt_quality = $Center/Panel/VBoxContainer/ScrollContainer/Content/RowQuality/OptQuality
@onready var opt_msaa = $Center/Panel/VBoxContainer/ScrollContainer/Content/RowMSAA/OptMSAA
@onready var opt_shadow = $Center/Panel/VBoxContainer/ScrollContainer/Content/RowShadows/OptShadows
@onready var chk_vsync = $Center/Panel/VBoxContainer/ScrollContainer/Content/RowVSync/ChkVSync
@onready var sld_master = $Center/Panel/VBoxContainer/ScrollContainer/Content/RowMasterVol/SliderMaster
@onready var lbl_master = $Center/Panel/VBoxContainer/ScrollContainer/Content/RowMasterVol/LblMasterVol
@onready var sld_sfx = $Center/Panel/VBoxContainer/ScrollContainer/Content/RowSFXVol/SliderSFX
@onready var lbl_sfx = $Center/Panel/VBoxContainer/ScrollContainer/Content/RowSFXVol/LblSFXVol
@onready var sld_music = $Center/Panel/VBoxContainer/ScrollContainer/Content/RowMusicVol/SliderMusic
@onready var lbl_music = $Center/Panel/VBoxContainer/ScrollContainer/Content/RowMusicVol/LblMusicVol
@onready var chk_grid_snap = $Center/Panel/VBoxContainer/ScrollContainer/Content/RowGridSnap/ChkGridSnap
@onready var sld_cam_sens = $Center/Panel/VBoxContainer/ScrollContainer/Content/RowCamSens/SliderCamSens
@onready var lbl_cam_sens = $Center/Panel/VBoxContainer/ScrollContainer/Content/RowCamSens/LblCamSens
@onready var chk_invert_y = $Center/Panel/VBoxContainer/ScrollContainer/Content/RowInvertY/ChkInvertY
@onready var spn_port = $Center/Panel/VBoxContainer/ScrollContainer/Content/RowPort/SpnPort
@onready var txt_name = $Center/Panel/VBoxContainer/ScrollContainer/Content/RowName/TxtName
@onready var apply_btn = $Center/Panel/VBoxContainer/Buttons/ApplyBtn
@onready var cancel_btn = $Center/Panel/VBoxContainer/Buttons/CancelBtn

const CUSTOM := 4

const RESOLUTIONS := [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

const PRESET_DEFAULTS := [
	{ "msaa": 0, "shadow": 0 },  # Low
	{ "msaa": 1, "shadow": 1 },  # Medium
	{ "msaa": 2, "shadow": 2 },  # High
	{ "msaa": 3, "shadow": 2 },  # Ultra
]

var _setting_preset := false


func _ready():
	apply_btn.pressed.connect(_on_apply)
	cancel_btn.pressed.connect(_on_cancel)

	for r in RESOLUTIONS:
		opt_resolution.add_item("%dx%d" % [r.x, r.y])
	for item in ["Low", "Medium", "High", "Ultra", "Custom"]:
		opt_quality.add_item(item)
	for item in ["Off", "2x", "4x", "8x"]:
		opt_msaa.add_item(item)
	for item in ["Low", "Medium", "High"]:
		opt_shadow.add_item(item)

	sld_master.value_changed.connect(func(v): lbl_master.text = "%d%%" % v)
	sld_sfx.value_changed.connect(func(v): lbl_sfx.text = "%d%%" % v)
	sld_music.value_changed.connect(func(v): lbl_music.text = "%d%%" % v)
	sld_cam_sens.value_changed.connect(_update_cam_sens_label)

	opt_quality.item_selected.connect(_on_quality_changed)
	opt_msaa.item_selected.connect(_on_msaa_or_shadow_changed)
	opt_shadow.item_selected.connect(_on_msaa_or_shadow_changed)
	chk_fullscreen.toggled.connect(func(t): chk_borderless.disabled = not t)

	load_values()


func _on_msaa_or_shadow_changed(_index: int):
	if _setting_preset:
		return
	opt_quality.select(CUSTOM)


func _on_quality_changed(index: int):
	if index >= PRESET_DEFAULTS.size():
		return
	_setting_preset = true
	var d = PRESET_DEFAULTS[index]
	opt_msaa.select(d.msaa)
	opt_shadow.select(d.shadow)
	_setting_preset = false


func load_values():
	var s = SettingsManager

	var best = 1
	for i in RESOLUTIONS.size():
		if RESOLUTIONS[i] == s.resolution:
			best = i
			break
	opt_resolution.select(best)
	chk_fullscreen.button_pressed = s.fullscreen
	chk_borderless.button_pressed = s.borderless
	chk_borderless.disabled = not s.fullscreen

	opt_quality.select(s.quality_preset)
	opt_msaa.select(s.msaa)
	opt_shadow.select(s.shadow_quality)
	chk_vsync.button_pressed = s.vsync

	sld_master.value = s.master_volume * 100
	sld_sfx.value = s.sfx_volume * 100
	sld_music.value = s.music_volume * 100

	chk_grid_snap.button_pressed = s.grid_snap
	sld_cam_sens.value = _sens_to_value(s.camera_sensitivity)
	chk_invert_y.button_pressed = s.camera_invert_y

	spn_port.value = s.default_port
	txt_name.text = s.player_name


func _on_apply():
	var s = SettingsManager

	var sel = opt_resolution.selected
	if sel >= 0 and sel < RESOLUTIONS.size():
		s.resolution = RESOLUTIONS[sel]
	s.fullscreen = chk_fullscreen.button_pressed
	s.borderless = chk_borderless.button_pressed

	s.quality_preset = opt_quality.selected
	s.msaa = opt_msaa.selected
	s.shadow_quality = opt_shadow.selected
	s.vsync = chk_vsync.button_pressed

	s.master_volume = sld_master.value / 100.0
	s.sfx_volume = sld_sfx.value / 100.0
	s.music_volume = sld_music.value / 100.0

	s.grid_snap = chk_grid_snap.button_pressed
	s.camera_sensitivity = _value_to_sens(sld_cam_sens.value)
	s.camera_invert_y = chk_invert_y.button_pressed

	s.default_port = int(spn_port.value)
	s.player_name = txt_name.text

	s.save()
	s.apply()

	visible = false


func _on_cancel():
	visible = false


func _update_cam_sens_label(_v = 0):
	lbl_cam_sens.text = "%.1fx" % _value_to_sens(sld_cam_sens.value)


static func _value_to_sens(v: float) -> float:
	return lerp(0.1, 2.0, v / 100.0)


static func _sens_to_value(v: float) -> float:
	return inverse_lerp(0.1, 2.0, v) * 100.0
