extends Node
## Game: the one autoload. Owns the input map, the quality settings and
## their effect on the viewport, the fonts, and the world seed. Everything
## else is a scene node that asks it.

const SETTINGS_PATH := "user://settings.cfg"
const SEED := 7351

## Quality presets. `render_height` caps the 3D image in real pixels (a
## Retina window is twice its size); FSR brings it back up to the screen.
const PRESETS := {
	"low": {"shadow_size": 1024, "render_height": 900, "msaa": 0, "shadow_distance": 60.0, "shadow_splits": 2, "ssao": false,
		"grass_radius": 30.0, "tree_distance": 380.0, "glow": true},
	"medium": {"shadow_size": 2048, "render_height": 1080, "msaa": 0, "shadow_distance": 90.0, "shadow_splits": 2, "ssao": false,
		"grass_radius": 40.0, "tree_distance": 450.0, "glow": true},
	"high": {"shadow_size": 4096, "render_height": 1650, "msaa": 1, "shadow_distance": 160.0, "shadow_splits": 4, "ssao": true,
		"grass_radius": 55.0, "tree_distance": 750.0, "glow": true},
}

var quality := "medium"
var playing := false            ## true while the player has control (not on the title screen)
var mouse_sensitivity := 0.0025
var fov := 62.0
var invert_y := false
var master_volume := 0.8
var title_font: Font
var ui_font: Font
var ui_bold: Font

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	_build_input()
	_load_fonts()
	get_window().size_changed.connect(apply_viewport)
	apply_viewport.call_deferred()

func q(key: String) -> Variant:
	return PRESETS[quality][key]

func set_quality(name: String) -> void:
	if not PRESETS.has(name):
		return
	quality = name
	apply_viewport()
	save_settings()

## Puts the quality preset onto the main viewport.
func apply_viewport() -> void:
	var vp := get_viewport()
	var tall := float(get_window().size.y)
	var scale := clampf(float(q("render_height")) / maxf(tall, 1.0), 0.4, 1.0)
	# MetalFX Spatial on a Mac: measured sharper than FSR at a higher scale
	# AND cheaper (a 3420 px Retina window at 0.6 cost less than FSR at
	# 0.42). FSR elsewhere. SMAA instead of FXAA, which smeared the distance.
	var metal := OS.get_name() == "macOS"
	if scale >= 0.98:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	elif metal:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_METALFX_SPATIAL
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	vp.scaling_3d_scale = scale
	vp.fsr_sharpness = 0.2
	vp.msaa_3d = Viewport.MSAA_2X if int(q("msaa")) > 0 else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
	vp.mesh_lod_threshold = 4.0
	RenderingServer.directional_shadow_atlas_set_size(int(q("shadow_size")), true)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	quality = str(cfg.get_value("video", "quality", quality))
	if not PRESETS.has(quality):
		quality = "medium"
	mouse_sensitivity = float(cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity))
	fov = float(cfg.get_value("video", "fov", fov))
	invert_y = bool(cfg.get_value("input", "invert_y", invert_y))
	master_volume = float(cfg.get_value("audio", "master", master_volume))
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "quality", quality)
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("video", "fov", fov)
	cfg.set_value("input", "invert_y", invert_y)
	cfg.set_value("audio", "master", master_volume)
	cfg.save(SETTINGS_PATH)

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))

func _load_fonts() -> void:
	var cinzel := load("res://assets/fonts/Cinzel.ttf") as FontFile
	var inter := load("res://assets/fonts/Inter.ttf") as FontFile
	for f in [cinzel, inter]:
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		f.generate_mipmaps = true
	title_font = _weighted(cinzel, 600)
	ui_font = _weighted(inter, 500)
	ui_bold = _weighted(inter, 700)
	ThemeDB.fallback_font = ui_font
	ThemeDB.fallback_font_size = 16

static func _weighted(base: FontFile, weight: int) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return v

# --- Input ----------------------------------------------------------------

const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"jump": [KEY_SPACE],
	"dodge": [KEY_CTRL, KEY_C],
	"interact": [KEY_E],
	"lock_on": [KEY_Q],
	"heal": [KEY_R],
	"map": [KEY_M],
	"inventory": [KEY_TAB, KEY_I],
	"law_1": [KEY_F],
	"law_2": [KEY_G],
	"law_3": [KEY_H],
	"guide": [KEY_T],
	"art_1": [KEY_Z],
	"art_2": [KEY_X],
	"art_3": [KEY_V],
	"art_4": [KEY_B],
	"hotbar_1": [KEY_1],
	"hotbar_2": [KEY_2],
	"hotbar_3": [KEY_3],
	"hotbar_4": [KEY_4],
	"hotbar_5": [KEY_5],
	"skills": [KEY_K],
	"archive": [KEY_J],
	"pause": [KEY_ESCAPE],
	"walk_toggle": [KEY_ALT],
}

func _build_input() -> void:
	for action in KEYS.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for k in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	for pair in [["attack", MOUSE_BUTTON_LEFT], ["block", MOUSE_BUTTON_RIGHT], ["lock_on", MOUSE_BUTTON_MIDDLE]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0], 0.2)
		var mb := InputEventMouseButton.new()
		mb.button_index = pair[1]
		InputMap.action_add_event(pair[0], mb)
