extends SceneTree
## Builds the island headless and prints timing and a few heights.
func _init() -> void:
	var t := Time.get_ticks_msec()
	var isl := Island.new(7351)
	isl.generate()
	print("island built in %d ms" % (Time.get_ticks_msec() - t))
	for id in Island.SITES.keys():
		print("  %-10s %s" % [id, isl.site_pos(id).snapped(Vector3.ONE * 0.1)])
	var hi := -1e9
	var land := 0
	for h in isl.heights:
		hi = maxf(hi, h)
		if h > 0.4:
			land += 1
	print("  peak %.0f m, land %.0f%%" % [hi, 100.0 * land / isl.heights.size()])
	quit()
