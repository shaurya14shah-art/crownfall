extends Node
## Compares upscalers at a Retina-sized window: frame time and a screenshot
## of a distant view for each.   Godot --path . scenes/tools/BenchScale.tscn -- <out_dir>

const MODES := [
	["old_fsr1_042", Viewport.SCALING_3D_MODE_FSR, 0.42, Viewport.SCREEN_SPACE_AA_FXAA],
	["new_metalfx_s_060", Viewport.SCALING_3D_MODE_METALFX_SPATIAL, 0.6, Viewport.SCREEN_SPACE_AA_SMAA],
	["old_fsr1_042_again", Viewport.SCALING_3D_MODE_FSR, 0.42, Viewport.SCREEN_SPACE_AA_FXAA],
	["new_metalfx_s_060_again", Viewport.SCALING_3D_MODE_METALFX_SPATIAL, 0.6, Viewport.SCREEN_SPACE_AA_SMAA],
]

func _ready() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/cf/scale"
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(3200, 1800)
	Game.playing = true
	var w := World.new()
	add_child(w)
	await w.build()
	w.sky.time_of_day = 0.42
	w.sky.paused = true
	w.rig.camera.make_current()
	w.rig.yaw = w.rig.yaw + 0.4
	w.rig.pitch = -0.08
	for i in 60:
		await get_tree().process_frame
	var vp := get_viewport()
	print("window ", get_window().size)
	for m in MODES:
		vp.scaling_3d_mode = m[1]
		vp.scaling_3d_scale = m[2]
		vp.screen_space_aa = m[3]
		vp.msaa_3d = Viewport.MSAA_DISABLED
		for i in 90:
			DisplayServer.window_move_to_foreground()
			await get_tree().process_frame
		var t0 := Time.get_ticks_usec()
		for i in 120:
			DisplayServer.window_move_to_foreground()
			await get_tree().process_frame
		var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / 120.0
		print("SCALE %-16s %6.2f ms  %5.1f fps" % [m[0], ms, 1000.0 / ms])
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s/%s.png" % [out, m[0]])
	get_tree().quit()
