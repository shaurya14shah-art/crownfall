extends Node
## Photographs the quest pop-ups, tracker, waypoint, guide trail, Journey
## page and map marker. Opens a window.
##   Godot --path . scenes/tools/CaptureQuest.tscn -- <out_dir>

var _out := "/tmp/cf/quest"
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
	main.call("_begin", -1)
	await _wait_real(2.0)
	_dismiss()
	await _wait_real(1.2)
	await _shot("01_new_quest_popup")
	await _wait_real(10.0)
	await _shot("02_tracker_waypoint")
	var world: World = main.get("world")
	# Look away from the Elder: the waypoint should cling to the screen edge.
	world.rig.yaw += PI * 0.6
	await _wait(30)
	await _shot("03_waypoint_offscreen")
	world.rig.yaw -= PI * 0.6
	main.call("_show_the_way")
	await _wait_real(1.6)
	await _shot("04_guide_trail")
	# Finish the first step: the update card.
	Run.add_clue("elder_barrow", "The Dead of the Barrow", "Elder Maren says the dead walk out of the Barrow of Ash.")
	Run.update_quests()
	await _wait_real(1.0)
	await _shot("05_quest_updated")
	await _wait_real(4.0)
	main.call("_open_codex", "journey")
	await _wait(40)
	await _shot("06_journey")
	(main.get("_overlay") as Codex).open("map")
	await _wait(30)
	await _shot("07_map_marker")
	main.call("_overlay_close")
	await _wait(10)
	Run.flags["bought"] = true
	Run.update_quests()
	await _wait_real(1.2)
	await _shot("08_quest_complete")
	get_tree().quit(0)

func _dismiss() -> void:
	var o := main.get("_overlay") as Control
	if o != null and o.has_signal("done"):
		o.emit_signal("done")
		o.queue_free()

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
