class_name JourneyPage
extends Control
## Journey: your quests. The main quest first, then side quests, then what
## you have finished; pick one to read it and track it. Steps you have done
## are ticked, the current one has a diamond, and later ones stay hidden.

var world: World
var _chosen := ""
var _list: VBoxContainer
var _detail: VBoxContainer

func _ready() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 40)
	add_child(row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(440, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(420, 0)
	_list.add_theme_constant_override("separation", 10)
	scroll.add_child(_list)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 14)
	row.add_child(_detail)
	_chosen = Run.tracked if Run.tracked != "" else "main"
	Run.changed.connect(func(what: String) -> void:
		if what in ["quests", "bounties"] and is_inside_tree():
			_build())
	_build()

func _ordered() -> Array:
	var out := []
	for done in [false, true]:
		for kind in ["main", "side"]:
			for id in Quests.ALL.keys():
				if Run.quests.has(id) and bool(Run.quests[id]["done"]) == done and Quests.ALL[id]["kind"] == kind:
					out.append(id)
	return out

func _build() -> void:
	for c in _list.get_children():
		c.queue_free()
	for c in _detail.get_children():
		c.queue_free()
	# Bounties first: three short goals, always replaced when done.
	_list.add_child(Kit.label("BOUNTIES   ·   %d DONE" % Run.bounties_done, 12, Kit.GOLD))
	for b in Run.bounties:
		_list.add_child(_bounty(b))
	var ids := _ordered()
	if ids.is_empty():
		_list.add_child(Kit.para("No quests yet.", 16))
		return
	if not _chosen in ids:
		_chosen = ids[0]
	var last_done := false
	for id in ids:
		var done: bool = Run.quests[id]["done"]
		if done and not last_done:
			_list.add_child(Kit.label("COMPLETED", 12, Kit.MUTED))
		last_done = done
		_list.add_child(_entry(id))
	_show(_chosen)

func _bounty(b: Dictionary) -> Control:
	var p := PanelContainer.new()
	var st := HUD.chip(Kit.INK_2, Kit.LINE)
	st.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	var t := Kit.label(str(b["text"]), 15, Kit.IVORY)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	h.add_child(Kit.label("%d / %d" % [mini(int(b["have"]), int(b["need"])), int(b["need"])], 15, Kit.GOLD_LIGHT))
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 5)
	bar.max_value = float(b["need"])
	bar.value = float(b["have"])
	var bg := StyleBoxFlat.new()
	bg.bg_color = Kit.INK
	var fg := StyleBoxFlat.new()
	fg.bg_color = Kit.GOLD
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	v.add_child(bar)
	v.add_child(Kit.label("%d renown  ·  %d silver  ·  and something more" % [int(b["xp"]), int(b["silver"])], 12,
		Kit.MUTED))
	return p

func _entry(id: String) -> Control:
	var q: Dictionary = Quests.ALL[id]
	var b := QuestEntry.new()
	b.quest_id = id
	b.selected = id == _chosen
	b.pressed.connect(func() -> void:
		_chosen = id
		_build())
	return b

func _show(id: String) -> void:
	var q: Dictionary = Quests.ALL[id]
	var st: Dictionary = Run.quests[id]
	var tag := Kit.label("MAIN QUEST" if q["kind"] == "main" else "SIDE QUEST", 13, Kit.GOLD)
	_detail.add_child(tag)
	_detail.add_child(Kit.title(str(q["title"]).to_upper(), 36, Kit.IVORY, 6))
	var intro := Kit.para(str(q["text"]), 17, Kit.MUTED)
	intro.custom_minimum_size = Vector2(640, 0)
	_detail.add_child(intro)
	var steps: Array = q["steps"]
	for i in steps.size():
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var mark := StepMark.new()
		var state := "done" if i < int(st["step"]) or bool(st["done"]) else ("now" if i == int(st["step"]) else "later")
		mark.state = state
		line.add_child(mark)
		var text := str(steps[i]["text"]) if state != "later" else "???"
		if state == "now" and id == "fragments":
			text = Quests.step_text(id)
		line.add_child(Kit.label(text, 17, Kit.IVORY if state == "now" else (Kit.MUTED if state == "done" else Color(Kit.MUTED, 0.5)),
			state == "now"))
		_detail.add_child(line)
	_detail.add_child(Kit.label("REWARD  ·  %s" % str(q.get("reward", "")).to_upper(), 13, Kit.GOLD_LIGHT))
	if not bool(st["done"]):
		var tracking := Run.tracked == id
		var b := ChunkyButton.new("Tracking" if tracking else "Track this quest", not tracking, 17)
		b.disabled = tracking
		b.pressed.connect(func() -> void:
			Run.track(id)
			Audio.ui("confirm", -6.0))
		_detail.add_child(b)

class QuestEntry extends Button:
	var quest_id := ""
	var selected := false
	var _hover := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(420, 70)
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
		var q: Dictionary = Quests.ALL[quest_id]
		var done: bool = Run.quests[quest_id]["done"]
		var r := Rect2(Vector2(0, 4 - _hover * 2.0), size - Vector2(0, 4))
		draw_rect(Rect2(Vector2(0, 6), size - Vector2(0, 6)), Color("0b0c10"))
		draw_style_box(HUD.chip(Kit.INK_3 if selected else Kit.INK_2, Kit.GOLD if selected else Kit.LINE.lerp(Kit.GOLD, _hover)), r)
		var main: bool = q["kind"] == "main"
		var c := r.position + Vector2(30, r.size.y * 0.5)
		if done:
			Glyphs.draw(self, "check", c, 22.0, Kit.GREEN)
		else:
			var s := 9.0 if main else 7.0
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]),
				Kit.GOLD if main else Kit.IVORY)
		Kit.text(self, r.position + Vector2(56, 30), str(q["title"]).to_upper(), 15, Kit.MUTED if done else Kit.IVORY,
			Kit.title_font(2))
		draw_string(Game.ui_font, r.position + Vector2(56, 52), Quests.step_text(quest_id), HORIZONTAL_ALIGNMENT_LEFT,
			size.x - 90, 13, Kit.MUTED)
		if Run.tracked == quest_id:
			Kit.text(self, r.position + Vector2(0, 30), "TRACKED", 11, Kit.GOLD, Game.ui_bold, HORIZONTAL_ALIGNMENT_RIGHT,
				r.size.x - 14)

class StepMark extends Control:
	var state := "later"

	func _init() -> void:
		custom_minimum_size = Vector2(24, 24)

	func _draw() -> void:
		var c := size * 0.5
		match state:
			"done":
				Glyphs.draw(self, "check", c, 20.0, Kit.GREEN)
			"now":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(8, 0), c + Vector2(0, 8), c + Vector2(-8, 0)]),
					Kit.GOLD)
			_:
				draw_circle(c, 4.0, Kit.LINE, true, -1.0, true)
