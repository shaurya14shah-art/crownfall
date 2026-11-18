class_name StoryCard
extends Control
## A moment of story: black bars slide in from top and bottom, the world
## behind slows, a title is engraved in, and a few lines of narration come
## up one by one. Any key once they have all appeared.

signal done

var title := ""
var lines: Array[String] = []
var colour := Kit.GOLD
var _start := 0
var _t := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start = Time.get_ticks_msec()

func _total() -> float:
	return 1.4 + float(lines.size()) * 1.6

func _process(_delta: float) -> void:
	_t = float(Time.get_ticks_msec() - _start) / 1000.0
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		get_viewport().set_input_as_handled()
		if _t < _total():
			_start -= int((_total() - _t) * 1000.0)       # first press shows everything
		else:
			done.emit()
			queue_free()

func _draw() -> void:
	var vp := get_viewport_rect().size
	var bars := ease(clampf(_t / 0.6, 0.0, 1.0), 0.3)
	var bh := vp.y * 0.16 * bars
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0, 0, 0, 0.45 * bars))
	draw_rect(Rect2(0, 0, vp.x, bh), Color.BLACK)
	draw_rect(Rect2(0, vp.y - bh, vp.x, bh), Color.BLACK)
	var a := smoothstep(0.5, 1.2, _t)
	var f := Kit.title_font(12)
	var tw := f.get_string_size(title.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 54).x
	var y := vp.y * 0.36
	Kit.text(self, Vector2(vp.x * 0.5 - tw * 0.5, y), title.to_upper(), 54, Color(Kit.IVORY, a), f)
	var spread := (tw * 0.5 + 30.0) * ease(clampf((_t - 0.6) / 1.0, 0.0, 1.0), 0.3)
	draw_rect(Rect2(vp.x * 0.5 - spread, y + 20, spread * 2.0, 2), Color(colour, a))
	for i in lines.size():
		var la := smoothstep(1.2 + i * 1.6, 2.0 + i * 1.6, _t)
		if la <= 0.0:
			continue
		draw_string(Game.ui_font, Vector2(vp.x * 0.5 - 450, y + 80 + i * 40 + (1.0 - la) * 8.0), lines[i],
			HORIZONTAL_ALIGNMENT_CENTER, 900, 22, Color(Kit.IVORY, la * 0.92))
	if _t >= _total():
		draw_string(Game.ui_bold, Vector2(0, vp.y - bh * 0.5 + 6), "PRESS ANY KEY", HORIZONTAL_ALIGNMENT_CENTER, vp.x, 13,
			Color(Kit.GOLD_LIGHT, 0.5 + 0.5 * sin(_t * 4.0)))
