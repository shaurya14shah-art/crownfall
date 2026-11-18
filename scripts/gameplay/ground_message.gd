class_name GroundMessage
extends Node3D
## Words left on the ground by knights who came this way before: a ring of
## orange runes you can read. Some warn, some point at something hidden,
## and some are not to be trusted.

var text := ""
var index := -1
var _mat: StandardMaterial3D
var _t := 0.0

static var _tex: ImageTexture

func _ready() -> void:
	add_to_group("interactables")
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.5, 1.5)
	mi.mesh = pm
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.albedo_texture = _runes()
	_mat.albedo_color = Color(1.0, 0.55, 0.2)
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.04
	add_child(mi)

## A ring of strokes and a few marks inside it, drawn once and shared.
static func _runes() -> ImageTexture:
	if _tex != null:
		return _tex
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := Vector2(n, n) * 0.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) - c
			var r := p.length() / (n * 0.5)
			var a := 0.0
			# The ring, broken into rune-sized dashes.
			var ang := atan2(p.y, p.x)
			if absf(r - 0.82) < 0.04 and fmod(ang + PI, 0.42) > 0.08:
				a = 1.0
			if absf(r - 0.64) < 0.015:
				a = maxf(a, 0.6)
			# Strokes across the middle.
			if r < 0.55 and (absf(p.x * 0.7 + p.y * 0.3) < 1.6 or absf(p.y - p.x * 0.9) < 1.4 and r < 0.4):
				a = maxf(a, 0.9)
			a *= clampf((0.98 - r) * 6.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	return _tex

func prompt_text() -> String:
	return "Read the message"

func interact(_player: Node3D) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.call("say", "Words on the ground", text)
	Run.lean("curiosity", 0.2)
	if index >= 0 and not Run.flags.has("msg_%d" % index):
		Run.flags["msg_%d" % index] = true
		Run.renown(5.0)
	Audio.ui("open", -10.0)

func _process(delta: float) -> void:
	_t += delta
	_mat.albedo_color.a = 0.65 + 0.25 * sin(_t * 1.7)
