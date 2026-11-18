extends Node
## Walks the Gate content and photographs it: the rift, the story card, the
## chambers, the keeper, a trial. Opens a window.
##   Godot --path . scenes/tools/CaptureGate.tscn -- <out_dir>

var _out := "/tmp/cf/gate"
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
	await _wait_real(2.5)
	_dismiss()
	var world: World = main.get("world")
	var p := world.player
	# Open the first Gate and stand before it.
	Run.flags["warden_dead"] = true
	main.set("_seen_stage", 1)
	world.sky.time_of_day = 0.72
	var portal: GatePortal = null
	for g in get_tree().get_nodes_in_group("gates"):
		if (g as GatePortal).gate_id == "drowned_stair":
			portal = g
	var front := portal.global_position + portal.global_basis.z * 9.0
	front.y = world.island.height_at(front.x, front.z) + 0.3
	p.global_position = front
	p.reset_physics_interpolation()
	world.rig.yaw = atan2(front.x - portal.global_position.x, front.z - portal.global_position.z)
	world.rig.pitch = -0.12
	world.rig.snap()
	await _wait(90)
	await _shot("01_rift")
	main.call("enter_gate", "drowned_stair")
	await _wait_real(3.5)
	await _shot("02_story_card")
	_dismiss()
	await _wait(60)
	await _shot("03_inside")
	var run := world.gate_run
	# Into the first fight.
	for i in run.rooms.size():
		var r: Dictionary = run.rooms[i]
		if r["kind"] == "fight":
			p.global_position = r["centre"] + Vector3(0, 0.4, 4)
			p.reset_physics_interpolation()
			world.rig.snap()
			break
	await _wait(80)
	await _shot("04_fight")
	for i in run.rooms.size():
		var r: Dictionary = run.rooms[i]
		if r["kind"] in ["trap", "lore"]:
			r["done"] = true
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.get_parent() == run:
			(e as Node).queue_free()
	for i in run.rooms.size():
		var r: Dictionary = run.rooms[i]
		if r["kind"] == "trap":
			p.global_position = r["centre"] + Vector3(0, 0.4, 7)
			p.reset_physics_interpolation()
			world.rig.snap()
			await _wait(80)
			await _shot("05_trap")
		if r["kind"] == "lore":
			p.global_position = r["centre"] + Vector3(0, 0.4, 3)
			p.reset_physics_interpolation()
			world.rig.snap()
			await _wait(60)
			await _shot("06_lore")
			break
	for i in run.rooms.size():
		var r: Dictionary = run.rooms[i]
		if r["kind"] == "boss":
			p.global_position = r["centre"] + Vector3(0, 0.4, 9)
			p.reset_physics_interpolation()
			world.rig.yaw = 0.0
			world.rig.snap()
	await _wait(120)
	await _shot("07_boss")
	main.call("_gate_done", false)
	await _wait_real(2.0)
	await _shot("08_back")
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
