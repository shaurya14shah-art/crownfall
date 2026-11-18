class_name MapPage
extends Control
## The map: the island painted from its own height and paint data (sea,
## shallows, sand, grass, forest, rock, roads), framed; the places you have
## found marked and named; you as an arrow. Scroll to zoom, drag to pan.

var world: World
static var _tex: ImageTexture
var _zoom := 1.0
var _pan := Vector2.ZERO
var _drag := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _tex == null and world != null:
		_tex = _paint(world.island)

static func _paint(isl: Island) -> ImageTexture:
	var n := 512
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	var step := Island.SIZE / float(n)
	for j in n:
		for i in n:
			var x := -Island.SIZE * 0.5 + (float(i) + 0.5) * step
			var z := -Island.SIZE * 0.5 + (float(j) + 0.5) * step
			var h := isl.height_at(x, z)
			var c: Color
			if h < -8.0:
				c = Color("1d4f73")
			elif h < 0.0:
				c = Color("2f7c99").lerp(Color("1d4f73"), clampf(-h / 8.0, 0.0, 1.0))
			else:
				var p := isl.paint_at(x, z)
				c = Color("6f9a3e").lerp(Color("4f7a2c"), clampf(h / 60.0, 0.0, 1.0))
				c = c.lerp(Color("2f5321"), p.z * 0.8)
				c = c.lerp(Color("8c8577"), smoothstep(90.0, 170.0, h))
				c = c.lerp(Color("d9c48f"), p.x)
				c = c.lerp(Color("b5915d"), p.y)
				# Hill shading from the north-west.
				var nn := isl.normal_at(x, z)
				c = c.darkened(clampf(-nn.dot(Vector3(-0.5, 0.7, -0.5).normalized()) + 0.75, 0.0, 0.35))
			img.set_pixel(i, j, c)
	return ImageTexture.create_from_image(img)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom = minf(_zoom * 1.15, 4.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom = maxf(_zoom / 1.15, 1.0)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
		queue_redraw()
	elif event is InputEventMouseMotion and _drag:
		_pan += (event as InputEventMouseMotion).relative
		queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _map_rect() -> Rect2:
	var side := minf(size.x - 360.0, size.y) * _zoom
	var c := Vector2((size.x - 340.0) * 0.5, size.y * 0.5) + _pan
	return Rect2(c - Vector2(side, side) * 0.5, Vector2(side, side))

func _to_map(r: Rect2, world_xz: Vector2) -> Vector2:
	return r.position + (world_xz + Vector2(Island.SIZE, Island.SIZE) * 0.5) / Island.SIZE * r.size

func _draw() -> void:
	if _tex == null:
		return
	var r := _map_rect()
	var clip := Rect2(Vector2.ZERO, Vector2(size.x - 340.0, size.y))
	draw_style_box(HUD.chip(Kit.INK_2, Kit.GOLD_DEEP), clip.grow(6))
	# Clip the map to its frame by drawing only the visible part of the texture.
	var vis := r.intersection(clip)
	if vis.size.x > 0.0:
		var src := Rect2((vis.position - r.position) / r.size * 512.0, vis.size / r.size * 512.0)
		draw_texture_rect_region(_tex, vis, src)
	for id in Island.SITES.keys():
		if not Run.archive["places"].has(id):
			continue
		var s: Dictionary = Island.SITES[id]
		var p := _to_map(r, s["pos"])
		if not clip.has_point(p):
			continue
		draw_circle(p + Vector2(0, 3), 15.0, Color(0, 0, 0, 0.5), true, -1.0, true)
		draw_circle(p, 15.0, Kit.INK, true, -1.0, true)
		draw_arc(p, 15.0, 0, TAU, 32, Kit.GOLD, 2.0, true)
		Glyphs.draw(self, HUD.PLACES.get(id, "pin"), p, 20.0, Kit.GOLD_LIGHT)
		Kit.text(self, p + Vector2(-120, 36), str(s["name"]).to_upper(), 14, Kit.IVORY, Game.ui_bold,
			HORIZONTAL_ALIGNMENT_CENTER, 240)
	# The isles out at sea (named once found), any X a map of yours marks,
	# and your ship.
	for id in Isles.ISLES.keys():
		var ic := Isles.centre(id)
		var ip := _to_map(r, Vector2(ic.x, ic.z))
		ip = ip.clamp(clip.position + Vector2(20, 20), clip.end - Vector2(20, 20))
		var rad := maxf(float(Isles.ISLES[id]["r"]) / Island.SIZE * r.size.x, 7.0)
		var found: bool = Run.archive["places"].has("isle_" + id)
		draw_circle(ip, rad + 2.0, Color(0.87, 0.78, 0.55), true, -1.0, true)
		draw_circle(ip, rad * 0.7, Color(0.42, 0.6, 0.3), true, -1.0, true)
		Kit.text(self, ip + Vector2(-100, rad + 18), str(Isles.ISLES[id]["name"]).to_upper() if found else "?", 13,
			Kit.IVORY if found else Kit.MUTED, Game.ui_bold, HORIZONTAL_ALIGNMENT_CENTER, 200)
	if world != null:
		for n in world.get_tree().get_nodes_in_group("dig_sites"):
			if not (n as Treasure).index in Treasure.held_sites():
				continue
			var xp := _to_map(r, Vector2((n as Node3D).global_position.x, (n as Node3D).global_position.z))
			xp = xp.clamp(clip.position + Vector2(14, 14), clip.end - Vector2(14, 14))
			draw_line(xp + Vector2(-9, -9), xp + Vector2(9, 9), Kit.INK, 7.0, true)
			draw_line(xp + Vector2(-9, 9), xp + Vector2(9, -9), Kit.INK, 7.0, true)
			draw_line(xp + Vector2(-8, -8), xp + Vector2(8, 8), Kit.RED, 4.0, true)
			draw_line(xp + Vector2(-8, 8), xp + Vector2(8, -8), Kit.RED, 4.0, true)
		if world.gull != null:
			var gp := _to_map(r, Vector2(world.gull.global_position.x, world.gull.global_position.z))
			gp = gp.clamp(clip.position + Vector2(14, 14), clip.end - Vector2(14, 14))
			draw_circle(gp, 10.0, Kit.INK, true, -1.0, true)
			draw_colored_polygon(PackedVector2Array([gp + Vector2(-7, 1), gp + Vector2(7, 1), gp + Vector2(4, 5),
				gp + Vector2(-4, 5)]), Color(0.6, 0.85, 1.0))
			draw_colored_polygon(PackedVector2Array([gp + Vector2(-1, -7), gp + Vector2(-1, 0), gp + Vector2(5, 0)]),
				Color(0.6, 0.85, 1.0))
	# Waystones (gold ember on a stone) and the silver you dropped.
	if world != null:
		for n in world.get_tree().get_nodes_in_group("waystones"):
			var ws := n as Waystone
			var wp := _to_map(r, Vector2(ws.global_position.x, ws.global_position.z))
			if not clip.has_point(wp):
				continue
			var lit := ws.kindled()
			draw_rect(Rect2(wp - Vector2(4, 2), Vector2(8, 14)), Kit.INK)
			draw_rect(Rect2(wp - Vector2(2.5, 0), Vector2(5, 11)), Color("8a867e") if lit else Kit.LINE)
			draw_circle(wp - Vector2(0, 7), 5.0, Color(1.0, 0.8, 0.45) if lit else Kit.INK_3, true, -1.0, true)
			if lit and _zoom > 1.4:
				Kit.text(self, wp + Vector2(-100, 26), ws.title, 12, Kit.GOLD_LIGHT, Game.ui_bold,
					HORIZONTAL_ALIGNMENT_CENTER, 200)
		for n in world.get_tree().get_nodes_in_group("lost_silver"):
			var lp := _to_map(r, Vector2((n as Node3D).global_position.x, (n as Node3D).global_position.z))
			if clip.has_point(lp):
				draw_circle(lp, 11.0, Kit.INK, true, -1.0, true)
				Glyphs.draw(self, "coin", lp, 15.0, Color(0.85, 1.0, 0.6))
	# The tracked quest's goal.
	var tgt := Quests.target_of(Run.tracked, world) if world != null else Vector3.INF
	if tgt != Vector3.INF:
		var tp := _to_map(r, Vector2(tgt.x, tgt.z))
		if clip.has_point(tp):
			var pulse := 1.0 + 0.15 * sin(Time.get_ticks_msec() * 0.006)
			draw_arc(tp, 22.0 * pulse, 0, TAU, 32, Color(Kit.GOLD, 0.6), 2.0, true)
			draw_colored_polygon(PackedVector2Array([tp + Vector2(0, -12), tp + Vector2(12, 0), tp + Vector2(0, 12),
				tp + Vector2(-12, 0)]), Kit.INK)
			draw_colored_polygon(PackedVector2Array([tp + Vector2(0, -9), tp + Vector2(9, 0), tp + Vector2(0, 9),
				tp + Vector2(-9, 0)]), Kit.GOLD)
			Kit.text(self, tp + Vector2(-140, -24), Quests.step_text(Run.tracked), 13, Kit.GOLD_LIGHT, Game.ui_bold,
				HORIZONTAL_ALIGNMENT_CENTER, 280)
	if world != null and world.player != null:
		var pp := world.player.global_position
		var p := _to_map(r, Vector2(pp.x, pp.z))
		var f := world.player.model.global_basis.z
		var d := Vector2(f.x, f.z).normalized()
		var side := Vector2(-d.y, d.x)
		var pts := PackedVector2Array([p + d * 14.0, p - d * 9.0 + side * 9.0, p - d * 4.0, p - d * 9.0 - side * 9.0])
		draw_colored_polygon(pts, Kit.RED)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Kit.IVORY, 2.0, true)
	# The legend on the right.
	var lx := size.x - 300.0
	Kit.text(self, Vector2(lx, 40), "ALDERMERE", 34, Kit.IVORY, Kit.title_font(6))
	var y := 90.0
	for id in Island.SITES.keys():
		var known: bool = Run.archive["places"].has(id)
		Glyphs.draw(self, HUD.PLACES.get(id, "pin") if known else "lock", Vector2(lx + 14, y - 6), 20.0,
			Kit.GOLD_LIGHT if known else Kit.LINE)
		Kit.text(self, Vector2(lx + 36, y), str(Island.SITES[id]["name"]) if known else "Unknown", 16,
			Kit.IVORY if known else Kit.MUTED, Game.ui_bold)
		y += 36.0
	var ex := Run.explored()
	y += 16.0
	Kit.text(self, Vector2(lx, y), "EXPLORED  %d%%" % int(100.0 * ex.x / ex.y), 16, Kit.GOLD_LIGHT, Game.ui_bold)
	draw_rect(Rect2(lx, y + 10, 240, 5), Kit.INK)
	draw_rect(Rect2(lx, y + 10, 240.0 * ex.x / ex.y, 5), Kit.GOLD)
	Kit.text(self, Vector2(lx, y + 36), "%d of %d: stones, places, chests, words," % [ex.x, ex.y], 12, Kit.MUTED)
	Kit.text(self, Vector2(lx, y + 54), "bloodstains, pages, Gates and great foes", 12, Kit.MUTED)
	Kit.text(self, Vector2(lx, size.y - 20), "SCROLL  ZOOM   ·   DRAG  PAN", 12, Kit.MUTED)
