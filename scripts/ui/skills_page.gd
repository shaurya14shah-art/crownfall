class_name SkillsPage
extends Control
## Skills: the five skills down the left with their level and progress; the
## chosen skill's tree on the right, nodes joined by lines. A node you can
## afford pulses gold; click it to take it. Points come from using the
## skill; a new knight starts with one each in Guard, Agility and Vitality,
## to learn those trees' Arts.

var world: World
var _chosen := "blade"
var _list: VBoxContainer
var _tree: SkillTree

func _ready() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 40)
	add_child(row)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(360, 0)
	_list.add_theme_constant_override("separation", 12)
	row.add_child(_list)
	_tree = SkillTree.new()
	_tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_tree)
	Run.changed.connect(func(what: String) -> void:
		if what == "skills" and is_inside_tree():
			_build())
	_build()

func _build() -> void:
	for c in _list.get_children():
		c.queue_free()
	for k in Run.skill_defs.keys():
		var r := SkillRow.new()
		r.skill = k
		r.selected = k == _chosen
		var key: String = k
		r.pressed.connect(func() -> void:
			_chosen = key
			_build())
		_list.add_child(r)
	_tree.skill = _chosen
	_tree.queue_redraw()

class SkillRow extends Button:
	var skill := ""
	var selected := false
	var _hover := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(360, 78)
		focus_mode = Control.FOCUS_NONE
		for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			add_theme_stylebox_override(s, StyleBoxEmpty.new())
		mouse_entered.connect(func() -> void:
			_hover = 1.0
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = 0.0
			queue_redraw())

	func _draw() -> void:
		var def: Dictionary = Run.skill_defs[skill]
		var s: Dictionary = Run.skills[skill]
		var r := Rect2(Vector2(0, 4 - _hover * 2.0), size - Vector2(0, 4))
		draw_rect(Rect2(Vector2(0, 6), size - Vector2(0, 6)), Color("0b0c10"))
		draw_style_box(HUD.chip(Kit.INK_3 if selected else Kit.INK_2, Kit.GOLD if selected else Kit.LINE.lerp(Kit.GOLD, _hover)), r)
		Glyphs.draw(self, str(def["icon"]), r.position + Vector2(38, 38), 34.0, Kit.GOLD if selected else Kit.IVORY)
		Kit.text(self, r.position + Vector2(74, 32), str(def["name"]).to_upper(), 18, Kit.IVORY)
		var level := int(s["level"])
		var need := Run.xp_for(level)
		var f := float(s["xp"]) / need
		if skill == "law":
			f = float(Run.law.get("mastery", 0.0)) / 100.0
			level = int(float(Run.law.get("mastery", 0.0)) / 10.0) + 1
		Kit.text(self, r.position + Vector2(0, 32), "LV %d" % level, 16, Kit.GOLD_LIGHT, Game.ui_bold,
			HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 18)
		HUD.bar(self, Rect2(r.position + Vector2(74, 48), Vector2(r.size.x - 96, 7)), f, 0.0, Kit.GOLD, Kit.GOLD_LIGHT)
		var pts := int(s["points"])
		if pts > 0:
			var c := r.position + Vector2(r.size.x - 8, 6)
			draw_circle(c, 13.0, Kit.GOLD, true, -1.0, true)
			draw_string(Game.ui_bold, c + Vector2(-13, 5), str(pts), HORIZONTAL_ALIGNMENT_CENTER, 26, 14, Kit.INK)

## The tree itself, drawn; clicking a node takes it.
class SkillTree extends Control:
	var skill := "blade"
	var _hover_id := ""
	var _burst := {}

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _nodes() -> Array:
		return Run.trees.get(skill, [])

	func _pos(n: Dictionary) -> Vector2:
		var p: Array = n["pos"]
		var rows := 1
		for m in _nodes():
			rows = maxi(rows, int(m["pos"][1]) + 1)
		var step := clampf((size.y - 140.0 - 170.0) / maxf(float(rows - 1), 1.0), 112.0, 170.0)
		return Vector2(size.x * 0.5 + float(p[0]) * 190.0, 140.0 + float(p[1]) * step)

	func _process(delta: float) -> void:
		for k in _burst.keys():
			_burst[k] = float(_burst[k]) + delta
			if float(_burst[k]) > 0.6:
				_burst.erase(k)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			_hover_id = ""
			for n in _nodes():
				if _pos(n).distance_to((event as InputEventMouseMotion).position) < 40.0:
					_hover_id = str(n["id"])
		elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and _hover_id != "":
			if Run.unlock(_hover_id):
				_burst[_hover_id] = 0.0
				Audio.ui("confirm", -4.0)
			else:
				Audio.ui("back", -10.0)

	func _draw() -> void:
		var def: Dictionary = Run.skill_defs.get(skill, {})
		Kit.text(self, Vector2(0, 40), str(def.get("name", "")).to_upper(), 36, Kit.IVORY, Kit.title_font(6))
		Kit.text(self, Vector2(0, 70), str(def.get("text", "")), 16, Kit.MUTED, Game.ui_font)
		var pts := int(Run.skills[skill]["points"])
		var pt_text := "%d POINT%s TO SPEND" % [pts, "" if pts == 1 else "S"]
		Kit.text(self, Vector2(0, 40), pt_text, 16, Kit.GOLD if pts > 0 else Kit.MUTED, Game.ui_bold,
			HORIZONTAL_ALIGNMENT_RIGHT, size.x)
		if Run.renown_points > 0:
			Kit.text(self, Vector2(0, 64), "+ %d RENOWN POINT%s, FOR ANY TREE" % [Run.renown_points,
				"" if Run.renown_points == 1 else "S"], 13, Kit.GOLD_LIGHT, Game.ui_bold, HORIZONTAL_ALIGNMENT_RIGHT, size.x)
		var nodes := _nodes()
		for n in nodes:
			for need in n.get("needs", []):
				for m in nodes:
					if m["id"] == need:
						var on := Run.unlocked.has(need)
						draw_line(_pos(m), _pos(n), Kit.GOLD if on else Kit.LINE, 4.0, true)
		var t := Time.get_ticks_msec() * 0.004
		for n in nodes:
			var id := str(n["id"])
			var c := _pos(n)
			var owned := Run.unlocked.has(id)
			var can := Run.can_unlock(id)
			var hov := id == _hover_id
			var r := 36.0 + (3.0 if hov else 0.0)
			var fill := Kit.GOLD if owned else (Kit.INK_3 if can else Kit.INK_2)
			var rim := Kit.GOLD_LIGHT if owned else (Kit.GOLD.lerp(Kit.GOLD_LIGHT, 0.5 + 0.5 * sin(t)) if can else Kit.LINE)
			if str(n.get("effect", "")) == "art":
				_draw_art(n, c, r + 8.0, fill, rim, owned, can)
			else:
				draw_circle(c + Vector2(0, 5), r, Color("0b0c10"), true, -1.0, true)
				draw_circle(c, r, fill, true, -1.0, true)
				draw_arc(c, r, 0, TAU, 48, rim, 3.0, true)
				Glyphs.draw(self, "check" if owned else ("star" if can else "lock"), c, 30.0,
					Kit.INK if owned else (Kit.GOLD_LIGHT if can else Kit.MUTED))
			Kit.text(self, c + Vector2(-110, r + 26), str(n["name"]).to_upper(), 15, Kit.IVORY if owned or can else Kit.MUTED,
				Game.ui_bold, HORIZONTAL_ALIGNMENT_CENTER, 220)
			if _burst.has(id):
				var b := float(_burst[id]) / 0.6
				draw_arc(c, r + 50.0 * b, 0, TAU, 48, Color(Kit.GOLD_LIGHT, 1.0 - b), 4.0, true)
		# What the hovered node does.
		if _hover_id != "":
			var n := Run.perk_node(_hover_id)
			var box := Rect2(Vector2(size.x * 0.5 - 260, size.y - 96), Vector2(520, 80))
			draw_style_box(HUD.chip(Kit.INK, Kit.GOLD_DEEP), box)
			Kit.text(self, box.position + Vector2(20, 32), str(n["name"]).to_upper(), 17, Kit.GOLD_LIGHT)
			draw_string(Game.ui_font, box.position + Vector2(20, 60), str(n["text"]), HORIZONTAL_ALIGNMENT_LEFT, 480, 16,
				Kit.IVORY)

	## An Art is a diamond, not a circle: its own glyph, its key below, and
	## an ART tag, so the basics read apart from the passive perks.
	func _draw_art(n: Dictionary, c: Vector2, r: float, fill: Color, rim: Color, owned: bool, can: bool) -> void:
		var dia := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
		var shadow := PackedVector2Array()
		for q in dia:
			shadow.append(q + Vector2(0, 5))
		draw_colored_polygon(shadow, Color("0b0c10"))
		draw_colored_polygon(dia, fill)
		var loop := dia.duplicate()
		loop.append(dia[0])
		draw_polyline(loop, rim, 3.0, true)
		var glyph := str(Arts.ALL.get(str(n["id"]), {}).get("glyph", "star"))
		Glyphs.draw(self, glyph, c, 30.0, Kit.INK if owned else (Kit.GOLD_LIGHT if can else Kit.MUTED))
		var tag := Rect2(c + Vector2(r - 20, -r + 2), Vector2(40, 20))
		draw_style_box(HUD.chip(Kit.RED if not owned else Kit.INK, Kit.GOLD_DEEP), tag)
		Kit.text(self, tag.position + Vector2(0, 15), "ART", 11, Kit.IVORY, Game.ui_bold, HORIZONTAL_ALIGNMENT_CENTER, 40)
		Kit.keycap(self, c + Vector2(-r - 4, -r + 12), str(n.get("key", "")), 12)
