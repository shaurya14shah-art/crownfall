extends Node
## Runs the real game flow and photographs every screen. Opens a window.
##   Godot --path . scenes/tools/CaptureUI.tscn -- <out_dir>

var _out := "/tmp/cf/ui"
var main: Node

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1600, 900)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	while main.get("_menu") == null:
		await get_tree().process_frame
	await _wait(150)
	await _shot("01_title")
	main.call("_begin", -1)
	await _wait(100)
	var world: World = main.get("world")
	# Some things to show: loot, a level, a clue, a place.
	Run.add_item("hand_axe", 1)
	Run.add_item("bone_shard", 4)
	Run.add_item("crest_shield", 1)
	Run.gain("blade", 60.0)
	Run.add_clue("elder_barrow", "The Dead of the Barrow", "Elder Maren says the dead walk out of the Barrow of Ash.")
	await _wait(20)
	await _shot("02_play")
	main.call("_open_codex", "inventory")
	await _wait(40)
	await _shot("03_inventory")
	(main.get("_overlay") as Codex).open("skills")
	await _wait(30)
	await _shot("04_skills")
	(main.get("_overlay") as Codex).open("law")
	await _wait(30)
	await _shot("05_law_dormant")
	(main.get("_overlay") as Codex).open("map")
	await _wait(30)
	await _shot("06_map")
	(main.get("_overlay") as Codex).open("archive")
	await _wait(30)
	await _shot("07_archive")
	main.call("_overlay_close")
	await _wait(10)
	main.call("_open_shop")
	await _wait(40)
	await _shot("08_shop")
	main.call("_overlay_close")
	await _wait(10)
	# Awaken (with a combative profile) and show the result.
	Run.lean("violence", 8.0)
	Run.lean("boldness", 6.0)
	main.call("_awaken")
	await _wait_real(4.2)
	await _shot("09_awakening")
	var aw := main.get("_overlay") as Control
	if aw != null:
		aw.emit_signal("done")
		aw.queue_free()
	Engine.time_scale = 1.0
	await _wait(20)
	await _shot("10_play_awakened")
	main.call("_open_codex", "law")
	await _wait(40)
	await _shot("11_law_awakened")
	main.call("_overlay_close")
	await _wait(10)
	main.call("_open_pause")
	await _wait(20)
	await _shot("12_pause")
	get_tree().quit(0)

func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame

func _wait_real(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_out, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("   wrote " + path)
