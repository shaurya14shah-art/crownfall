extends Node
## Builds the world and photographs it from set viewpoints, writing PNGs and
## a contact sheet. Opens a window.
##   Godot --path . scenes/tools/Capture.tscn -- <out_dir> [shot ...]

const SHOTS := {
	# name: [from site, look at site, height above ground, distance back, time of day]
	"player": ["player", "", 0.0, 0.0, 0.36],
	"village_high": ["village", "village", 45.0, 90.0, 0.40],
	"village_street": ["village", "village", 2.0, 30.0, 0.62],
	"harbour": ["harbour", "village", 14.0, 60.0, 0.70],
	"castle_hill": ["crossroads", "castle", 6.0, 0.0, 0.45],
	"mountains": ["village", "barrow", 120.0, 200.0, 0.33],
	"forest": ["barrow", "crossroads", 22.0, 30.0, 0.55],
	"coast_sunset": ["harbour", "harbour", 30.0, 160.0, 0.74],
	"keep": ["crossroads", "castle", 30.0, -330.0, 0.42],
	"barrow_dusk": ["barrow", "barrow", 9.0, 30.0, 0.77],
	"watch": ["tower", "tower", 6.0, 40.0, 0.58],
}

var _out := "/tmp/cf/shots"
var _world: World

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	var wanted: Array = args.slice(1) if args.size() > 1 else SHOTS.keys()
	get_window().size = Vector2i(1600, 900)
	_world = World.new()
	add_child(_world)
	var t0 := Time.get_ticks_msec()
	await _world.build(func(f: float, text: String) -> void: print("  %3d%% %s" % [int(f * 100), text]))
	print("built in %d ms" % (Time.get_ticks_msec() - t0))
	_world.sky.paused = true
	var cam := Camera3D.new()
	cam.far = 4000.0
	cam.fov = 60.0
	add_child(cam)
	var files: Array[String] = []
	for name in wanted:
		var s: Array = SHOTS[name]
		_world.sky.time_of_day = float(s[4])
		if s[0] == "player":
			_world.rig.camera.make_current()
			_world.grass.warm(_world.player.global_position)
		else:
			var from := _world.island.site_pos(s[0])
			var at := _world.island.site_pos(s[1]) if s[1] != "" else from
			var back := (from - at).normalized() if from.distance_to(at) > 1.0 else Vector3(0.6, 0, 0.8)
			var eye := from + back * float(s[3])
			eye.y = maxf(_world.island.height_at(eye.x, eye.z), 0.5) + float(s[2])
			var look := at + Vector3.UP * 4.0
			if from.distance_to(at) < 1.0:
				look = from
			cam.global_position = eye
			cam.look_at(look, Vector3.UP)
			cam.make_current()
			_world.grass.warm(eye)
		for i in 50:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [_out, name]
		get_viewport().get_texture().get_image().save_png(path)
		files.append(path)
		print("   wrote " + path)
	get_tree().quit(0)
