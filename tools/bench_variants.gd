extends Node
## At a Retina window, from the overlook, times rendering variants.
const VARIANTS := [
	["medium_now", Viewport.SCALING_3D_MODE_METALFX_SPATIAL, 0.52, Viewport.SCREEN_SPACE_AA_SMAA, 4.0],
	["metalfx060_smaa", Viewport.SCALING_3D_MODE_METALFX_SPATIAL, 0.6, Viewport.SCREEN_SPACE_AA_SMAA, 4.0],
	["metalfx060_fxaa", Viewport.SCALING_3D_MODE_METALFX_SPATIAL, 0.6, Viewport.SCREEN_SPACE_AA_FXAA, 4.0],
	["metalfx060_none", Viewport.SCALING_3D_MODE_METALFX_SPATIAL, 0.6, Viewport.SCREEN_SPACE_AA_DISABLED, 4.0],
	["metalfx050_none", Viewport.SCALING_3D_MODE_METALFX_SPATIAL, 0.5, Viewport.SCREEN_SPACE_AA_DISABLED, 4.0],
	["metalfx060_none_lod10", Viewport.SCALING_3D_MODE_METALFX_SPATIAL, 0.6, Viewport.SCREEN_SPACE_AA_DISABLED, 10.0],
	["fsr042_fxaa", Viewport.SCALING_3D_MODE_FSR, 0.42, Viewport.SCREEN_SPACE_AA_FXAA, 4.0],
]
func _ready() -> void:
	get_window().size = Vector2i(3420, 2084)
	Game.playing = true
	var w := World.new()
	add_child(w)
	await w.build()
	w.sky.time_of_day = 0.42
	w.sky.paused = true
	var cam := Camera3D.new()
	cam.far = 4000.0
	add_child(cam)
	var c := w.island.site_pos("village")
	for view in [["village", w.player.global_position + Vector3(0, 2.2, 6), w.player.global_position + Vector3(0, 1.5, -20)],
			["overlook", c + Vector3(80, 60, 120), c]]:
		cam.global_position = view[1]
		cam.look_at(view[2], Vector3.UP)
		cam.make_current()
		w.grass.warm(cam.global_position)
		for v in VARIANTS:
			var vp := get_viewport()
			vp.scaling_3d_mode = v[1]
			vp.scaling_3d_scale = v[2]
			vp.screen_space_aa = v[3]
			vp.msaa_3d = Viewport.MSAA_DISABLED
			vp.mesh_lod_threshold = v[4]
			for i in 60:
				DisplayServer.window_move_to_foreground()
				await get_tree().process_frame
			var t0 := Time.get_ticks_usec()
			for i in 120:
				DisplayServer.window_move_to_foreground()
				await get_tree().process_frame
			var ms := float(Time.get_ticks_usec() - t0) / 1000.0 / 120.0
			print("VAR %-9s %-24s %6.2f ms %5.1f fps prims %dk" % [view[0], v[0], ms, 1000.0 / ms,
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000])
	get_tree().quit()
