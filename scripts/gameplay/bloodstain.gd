class_name Bloodstain
extends Node3D
## Where another knight died. Touch it and a red shade of them lives out
## their last few seconds in front of you: how they came, what they did,
## how it ended. A warning, mostly.

var steps: Array = []          ## [[clip, seconds, metres forward], ...]
var index := -1
var _busy := false

static var _tex: ImageTexture

func _ready() -> void:
	add_to_group("interactables")
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.7, 1.7)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _splat()
	m.albedo_color = Color(0.75, 0.05, 0.04, 0.9)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.035
	add_child(mi)

static func _splat() -> ImageTexture:
	if _tex != null:
		return _tex
	var n := 96
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.09
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5, y + 0.5) / float(n) - Vector2(0.5, 0.5)
			var r := p.length() * 2.0 + noise.get_noise_2d(x, y) * 0.45
			var a := clampf((0.8 - r) * 5.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	_tex = ImageTexture.create_from_image(img)
	return _tex

func prompt_text() -> String:
	return "" if _busy else "Touch the bloodstain"

func interact(_player: Node3D) -> void:
	if _busy:
		return
	_busy = true
	Audio.ui("open", -6.0)
	if index >= 0 and not Run.flags.has("stain_%d" % index):
		Run.flags["stain_%d" % index] = true
		Run.renown(8.0)
	var shade := CharacterModel.new()
	shade.setup("res://assets/characters/Knight.glb", [])
	add_child(shade)
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	red.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	red.albedo_color = Color(1.0, 0.2, 0.12, 0.55)
	for mi in shade.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = red
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The shade starts back along its path and ends on the stain.
	var travel := 0.0
	for s in steps:
		travel += float(s[2])
	shade.position = Vector3(0, 0, -travel)
	for s in steps:
		var clip := str(s[0])
		var secs := float(s[1])
		shade.play(clip if shade.has(clip) else "Idle", 0.12, 1.0, true)
		var tw := create_tween()
		tw.tween_property(shade, "position:z", shade.position.z + float(s[2]), secs)
		await tw.finished
	var fade := create_tween()
	fade.tween_property(red, "albedo_color:a", 0.0, 1.2)
	await fade.finished
	shade.queue_free()
	_busy = false
