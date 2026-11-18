class_name QuestPopup
extends Control
## The card that drops in when a quest begins, moves on, or ends. Heraldry
## style: a gold (or green) tag, the quest's name engraved, a line of
## setup, the objective with a diamond, and the keys to follow it. Queued,
## one at a time.

const SHOW := 5.0

var _queue: Array = []        ## [kind, id]
var _cur: Array = []
var _t := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	Run.quest_event.connect(func(kind: String, id: String) -> void: _queue.append([kind, id]))

func _process(delta: float) -> void:
	# Wait, hidden, while a menu is open; the card picks up where it was.
	var main := get_tree().get_first_node_in_group("main")
	visible = main == null or main.get("_overlay") == null
	if not visible:
		return
	if _cur.is_empty() and not _queue.is_empty():
		_cur = _queue.pop_front()
		_t = 0.0
		Audio.ui("confirm" if _cur[0] != "step" else "open", -2.0)
	if _cur.is_empty():
		return
	_t += delta
	var dur := SHOW if _cur[0] != "step" else 3.5
	if _t > dur:
		_cur = []
	queue_redraw()

func _draw() -> void:
	if _cur.is_empty():
		return
	var kind: String = _cur[0]
	var id: String = _cur[1]
	var q: Dictionary = Quests.ALL.get(id, {})
	if q.is_empty():
		return
	var vp := get_viewport_rect().size
	var dur := SHOW if kind != "step" else 3.5
	var a := ease(clampf(_t / 0.3, 0.0, 1.0), 0.4) * (1.0 - smoothstep(dur - 0.5, dur, _t))
	var drop := (1.0 - ease(clampf(_t / 0.35, 0.0, 1.0), 0.3)) * -40.0
	var w := 720.0
	var big := kind != "step"
	var h := 196.0 if kind == "new" else (130.0 if big else 108.0)
	var r := Rect2(vp.x * 0.5 - w * 0.5, 120.0 + drop, w, h)
	var main: bool = q["kind"] == "main"
	var accent := Kit.GREEN if kind == "done" else Kit.GOLD
	draw_style_box(HUD.chip(Color(Kit.INK, a), Color(accent.darkened(0.3), a)), r)
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(w - 4, 5)), Color(accent, a))
	var tag: String = {"new": "MAIN QUEST" if main else "NEW QUEST", "step": "QUEST UPDATED", "done": "QUEST COMPLETE"}[kind]
	var tw := Game.ui_bold.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 26.0
	draw_style_box(HUD.chip(Color(accent, a), Color(accent.darkened(0.4), a)), Rect2(vp.x * 0.5 - tw * 0.5, r.position.y - 14, tw, 28))
	draw_string(Game.ui_bold, Vector2(vp.x * 0.5 - tw * 0.5, r.position.y + 5), tag, HORIZONTAL_ALIGNMENT_CENTER, tw, 13,
		Color(Kit.INK, a))
	var f := Kit.title_font(6)
	var title := str(q["title"]).to_upper()
	var tiw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	Kit.text(self, Vector2(vp.x * 0.5 - tiw * 0.5, r.position.y + 54), title, 34, Color(Kit.IVORY, a), f)
	var y := r.position.y + 54.0
	if big and kind == "new":
		draw_multiline_string(Game.ui_font, Vector2(r.position.x + 40, y + 28), str(q["text"]), HORIZONTAL_ALIGNMENT_CENTER,
			w - 80, 15, 2, Color(Kit.MUTED, a))
		y += 44.0
	var line := Quests.step_text(id) if kind != "done" else "Reward: %s" % q.get("reward", "")
	var lw := Game.ui_bold.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	var lx := vp.x * 0.5 - lw * 0.5 + 10.0
	if kind != "done":
		var d := Vector2(lx - 16, y + 38)
		draw_colored_polygon(PackedVector2Array([d + Vector2(0, -6), d + Vector2(6, 0), d + Vector2(0, 6), d + Vector2(-6, 0)]),
			Color(Kit.GOLD, a))
	else:
		Glyphs.draw(self, "check", Vector2(lx - 16, y + 38), 18.0, Color(Kit.GREEN, a))
	Kit.text(self, Vector2(lx, y + 44), line, 17, Color(Kit.IVORY, a))
	if big and kind == "new":
		var hx := vp.x * 0.5 - 150.0
		var hy := r.end.y - 22.0
		Kit.keycap(self, Vector2(hx, hy), "T", 12)
		draw_string(Game.ui_bold, Vector2(hx + 18, hy + 5), "SHOW THE WAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Kit.MUTED, a))
		Kit.keycap(self, Vector2(hx + 170, hy), "TAB", 12)
		draw_string(Game.ui_bold, Vector2(hx + 196, hy + 5), "JOURNEY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Kit.MUTED, a))
