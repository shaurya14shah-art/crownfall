class_name Awakening
extends Control
## The moment the Inscription wakes. The world slows almost to a stop and
## washes into the Law's colour; the words come up; then the card that says
## what woke in you. Any key to go on.

signal done

var _t := 0.0
var _col := Color.WHITE
var _ready_to_close := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_col = Law.colour(str(Run.law.get("principle", "")))
	Engine.time_scale = 0.08

var _start := 0

func _process(_delta: float) -> void:
	# Real time: the world itself is slowed almost to a stop.
	if _start == 0:
		_start = Time.get_ticks_msec()
	_t = float(Time.get_ticks_msec() - _start) / 1000.0
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if _t > 3.0 and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		Engine.time_scale = 1.0
		done.emit()
		queue_free()
		get_viewport().set_input_as_handled()

func _draw() -> void:
	var vp := get_viewport_rect().size
	var t := _t
	var wash := smoothstep(0.0, 0.8, t)
	draw_rect(Rect2(Vector2.ZERO, vp), Color(_col.darkened(0.7), 0.55 * wash))
	# Rings going out from the centre.
	for k in 4:
		var rr := fmod(t * 260.0 + float(k) * 180.0, 900.0)
		draw_arc(vp * 0.5, rr, 0, TAU, 96, Color(_col, 0.5 * (1.0 - rr / 900.0) * wash), 3.0, true)
	var a1 := smoothstep(0.6, 1.4, t) * (1.0 - smoothstep(2.4, 3.0, t))
	if a1 > 0.0:
		var f := Kit.title_font(14)
		var s := "YOUR INSCRIPTION AWAKENS"
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
		Kit.text(self, Vector2(vp.x * 0.5 - w * 0.5, vp.y * 0.5), s, 52, Color(Kit.IVORY, a1), f)
	var a2 := smoothstep(2.8, 3.5, t)
	if a2 <= 0.0:
		return
	var l := Run.law
	var cw := 760.0
	var r := Rect2(vp.x * 0.5 - cw * 0.5, vp.y * 0.5 - 220 + (1.0 - a2) * 30.0, cw, 440)
	draw_style_box(HUD.chip(Color(Kit.INK, a2), Color(_col, a2)), r)
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(cw - 4, 6)), Color(_col, a2))
	var c := Vector2(vp.x * 0.5, r.position.y + 100)
	draw_circle(c, 52.0, Color(_col, 0.2 * a2), true, -1.0, true)
	Glyphs.draw(self, "sigil", c, 80.0, Color(_col.lightened(0.2), a2))
	var name := str(l.get("name", "")).to_upper()
	var f2 := Kit.title_font(6)
	var nw := f2.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
	Kit.text(self, Vector2(vp.x * 0.5 - nw * 0.5, r.position.y + 200), name, 38, Color(Kit.IVORY, a2), f2)
	draw_string(Game.ui_font, Vector2(r.position.x, r.position.y + 236), "It shows itself as %s." % l.get("expression", ""),
		HORIZONTAL_ALIGNMENT_CENTER, cw, 16, Color(Kit.MUTED, a2))
	var parts := [["LAW", Law.principle_name(str(l["principle"]))], ["WHEN", str(Law.condition_def(str(l["condition"])).get("name", ""))],
		["PRICE", str(Law.price_def(str(l["price"])).get("name", ""))]]
	for i in 3:
		var pr := Rect2(r.position + Vector2(40 + i * 232, 262), Vector2(216, 70))
		draw_style_box(HUD.chip(Color(Kit.INK_2, a2), Color(Kit.LINE, a2)), pr)
		draw_string(Game.ui_bold, pr.position + Vector2(16, 26), str(parts[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(Kit.GOLD, a2))
		draw_string(Game.ui_bold, pr.position + Vector2(16, 52), str(parts[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 19,
			Color(Kit.IVORY, a2))
	var p0: Dictionary = Law.powers_of(l)[0]
	Kit.keycap(self, Vector2(r.position.x + 60, r.end.y - 56), "F", 15)
	draw_string(Game.ui_bold, Vector2(r.position.x + 86, r.end.y - 50), str(p0["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT,
		-1, 18, Color(Kit.IVORY, a2))
	draw_string(Game.ui_font, Vector2(r.position.x + 86, r.end.y - 28), str(p0["text"]), HORIZONTAL_ALIGNMENT_LEFT, cw - 120,
		14, Color(Kit.MUTED, a2))
	if t > 3.0:
		draw_string(Game.ui_bold, Vector2(0, r.end.y + 40), "PRESS ANY KEY", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 14,
			Color(Kit.GOLD_LIGHT, 0.5 + 0.5 * sin(t * 4.0)))
