extends Node
## Frame-time benchmark: builds the world, puts the camera at the player in
## the village and at an overlook, and reports fps and draw calls for each.
##   Godot --path . scenes/tools/Bench.tscn
func _ready() -> void:
	get_window().size = Vector2i(3420, 2084) if OS.get_cmdline_user_args().has("--retina") else Vector2i(1600, 900)
	await get_tree().process_frame
	Game.apply_viewport()
	Game.playing = true
	var w := World.new()
	add_child(w)
	await w.build()
	w.sky.time_of_day = 0.4
	w.rig.camera.make_current()
	print("window %s scale %.2f quality %s" % [get_window().size, get_viewport().scaling_3d_scale, Game.quality])
	if OS.get_cmdline_user_args().has("--overlook"):
		var cam0 := Camera3D.new()
		cam0.far = 4000.0
		add_child(cam0)
		var c0 := w.island.site_pos("village")
		cam0.global_position = c0 + Vector3(80, 60, 120)
		cam0.look_at(c0, Vector3.UP)
		cam0.make_current()
		await _measure("overlook warm-up")
		await _measure("overlook")
		get_tree().quit()
		return
	await _measure("village warm-up")
	await _measure("village (player view)")
	if OS.get_cmdline_user_args().has("--quick"):
		get_tree().quit()
		return
	w.grass.visible = false
	await _measure("  grass off")
	w.grass.visible = true
	w.foliage.visible = false
	await _measure("  trees off")
	w.foliage.visible = true
	for mmi in w.foliage.get_children():
		if mmi is GeometryInstance3D:
			(mmi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await _measure("  tree shadows off")
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	await _measure("  + msaa off")
	get_viewport().msaa_3d = Viewport.MSAA_2X
	w.sky.sun.shadow_enabled = false
	await _measure("  sun shadows off")
	w.sky.sun.shadow_enabled = true
	w.sky.env.ssao_enabled = false
	await _measure("  ssao off")
	w.sky.env.ssao_enabled = true
	w.ocean.visible = false
	await _measure("  ocean off")
	w.ocean.visible = true
	w.village.visible = false
	await _measure("  village off")
	w.village.visible = true
	get_viewport().scaling_3d_scale = 0.5
	await _measure("  half resolution")
	get_viewport().scaling_3d_scale = 1.0
	var cam := Camera3D.new()
	cam.far = 4000.0
	add_child(cam)
	var c := w.island.site_pos("village")
	cam.global_position = c + Vector3(80, 60, 120)
	cam.look_at(c, Vector3.UP)
	cam.make_current()
	await _measure("overlook")
	get_tree().quit()

func _measure(label: String) -> void:
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for i in 60:
		await get_tree().process_frame
	var cpu := 0.0
	var gpu := 0.0
	var proc := 0.0
	var phys := 0.0
	for i in 30:
		await get_tree().process_frame
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	print("   %s: render cpu %.1f ms, gpu %.1f ms, process %.1f ms, physics %.1f ms" % [label, cpu / 30.0, gpu / 30.0, proc / 30.0, phys / 30.0])
	var t0 := Time.get_ticks_usec()
	var worst := 0.0
	var last := t0
	var frames := 180
	for i in frames:
		DisplayServer.window_move_to_foreground()
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, float(now - last) / 1000.0)
		last = now
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / frames
	print("BENCH %-24s %6.2f ms  %5.1f fps  worst %5.1f ms  draws %d  prims %dk" % [label, ms, 1000.0 / ms, worst,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000])
