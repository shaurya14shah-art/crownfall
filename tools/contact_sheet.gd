extends SceneTree
## Tiles every PNG in a folder into one image.
##   Godot --headless --script tools/contact_sheet.gd -- <dir> [out.png] [columns] [tile_width]
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := str(args[0])
	var out := str(args[1]) if args.size() > 1 else dir + "/contact_sheet.png"
	var cols := int(args[2]) if args.size() > 2 else 2
	var tw := int(args[3]) if args.size() > 3 else 800
	var files: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png") and not f.begins_with("contact"):
			files.append(dir + "/" + f)
	files.sort()
	var th := tw * 9 / 16
	var rows := int(ceil(float(files.size()) / cols))
	var sheet := Image.create(tw * cols, th * rows, false, Image.FORMAT_RGB8)
	for i in files.size():
		var img := Image.load_from_file(files[i])
		img.convert(Image.FORMAT_RGB8)
		img.resize(tw, th, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(img, Rect2i(0, 0, tw, th), Vector2i((i % cols) * tw, (i / cols) * th))
	sheet.save_png(out)
	print("sheet: %d images -> %s" % [files.size(), out])
	quit()
