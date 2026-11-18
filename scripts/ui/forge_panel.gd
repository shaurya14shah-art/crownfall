class_name ForgePanel
extends Control
## The anvil. Three tabs:
##   FORGE    choose a form, a metal and an etching; the card on the right
##            shows the weapon they make and what it needs. Strike the
##            anvil: three timed hammer blows (Space or click as the marker
##            crosses the gold) decide its quality, up to a Masterwork.
##   TEMPER   raise a weapon +1..+5, or etch an old one.
##   SALVAGE  break gear you do not need back into what it is made of.

signal closed

const ORDER_FORMS := ["longsword", "axe", "dagger", "greatsword", "great_axe", "war_staff"]
const ORDER_METALS := ["iron", "bone", "grave", "star"]
const ORDER_ETCH := ["none", "ember", "rime", "grave"]

var _tab := "forge"
var _form := "longsword"
var _metal := "iron"
var _etching := "none"
var _etch_open := ""            ## TEMPER: the weapon whose etchings are showing
var _body: Control
var _tabs: HBoxContainer
var _silver: Label
var _card: ItemCard
var _hammer: HammerGame

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Kit.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.05, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var t := Kit.title("THE FORGE", 44, Kit.IVORY, 8)
	t.position = Vector2(80, 36)
	add_child(t)
	_tabs = HBoxContainer.new()
	_tabs.position = Vector2(420, 40)
	_tabs.add_theme_constant_override("separation", 10)
	add_child(_tabs)
	_silver = Kit.label("", 22, Kit.GOLD_LIGHT)
	_silver.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_silver.position = Vector2(-260, 50)
	add_child(_silver)
	var done := ChunkyButton.new("Leave", false, 16)
	done.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	done.position = Vector2(-200, -100)
	done.pressed.connect(func() -> void: closed.emit())
	add_child(done)
	_body = Control.new()
	_body.position = Vector2(80, 128)
	_body.size = Vector2(1500, 720)
	add_child(_body)
	_card = ItemCard.new()
	add_child(_card)
	Run.changed.connect(func(what: String) -> void:
		if what in ["bag", "silver", "forge"] and is_inside_tree() and (_hammer == null or not _hammer.visible):
			_build())
	_build()

func _build() -> void:
	_silver.text = "%d silver" % Run.silver
	for c in _tabs.get_children():
		c.queue_free()
	for tab in ["forge", "temper", "salvage"]:
		var b := ChunkyButton.new(tab, tab == _tab, 15)
		var id: String = tab
		b.pressed.connect(func() -> void:
			_tab = id
			_etch_open = ""
			_build())
		_tabs.add_child(b)
	for c in _body.get_children():
		c.queue_free()
	match _tab:
		"forge": _build_forge()
		"temper": _build_temper()
		"salvage": _build_salvage()

# --- FORGE ----------------------------------------------------------------------------------------

func _build_forge() -> void:
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(640, 0)
	_body.add_child(left)
	_choice_grid(left, "1   FORM", ORDER_FORMS, Forge.forms(), _form, 3, func(k: String) -> void: _form = k)
	_choice_grid(left, "2   METAL", ORDER_METALS, Forge.metals(), _metal, 4, func(k: String) -> void: _metal = k)
	_choice_grid(left, "3   ETCHING", ORDER_ETCH, Forge.etchings(), _etching, 4, func(k: String) -> void: _etching = k)
	var hint := Kit.para("The form is the shape and how it swings. The metal is how hard it hits. "
		+ "The etching is what every hit does besides.", 14)
	hint.custom_minimum_size = Vector2(620, 0)
	left.add_child(hint)
	# The weapon these make.
	var d := Forge.design(_form, _metal, _etching)
	var cost := Forge.craft_cost(_form, _metal, _etching)
	var panel := _panel(Vector2(700, 0), Vector2(660, 560))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	v.add_child(top)
	var slot := ItemSlot.new(112.0)
	slot.role = "shop"
	slot.set_item(str(d["icon"]), 0)
	top.add_child(slot)
	var names := VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(names)
	var nm := Kit.label(str(d["name"]), 24, Kit.RARITY.get(str(d["rarity"]), Kit.IVORY))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(460, 0)
	names.add_child(nm)
	names.add_child(Kit.label("%s  ·  WEAPON" % str(d["rarity"]).to_upper(), 12, Kit.MUTED))
	var held := Run.item(str(Run.gear.get("weapon", "")))
	var diff := int(d["damage"]) - int(held.get("damage", 0))
	_stat(v, "Damage", "%d" % int(d["damage"]), ("+%d on what you hold" % diff) if diff > 0 else
		("%d on what you hold" % diff if diff < 0 else "same as what you hold"), diff >= 0)
	_stat(v, "Speed", "%.2f" % float(d["speed"]), "", true)
	_stat(v, "Grip", "Two hands" if bool(d.get("two_handed", false)) else "One hand, with a shield", "", true)
	_stat(v, "Stance", "%d%%" % int(Forge.posture_of(d) * 100.0), "how hard it breaks a guard", true)
	var etext := Kit.para(str(Forge.etchings()[_etching]["text"]), 15, Kit.IVORY if _etching != "none" else Kit.MUTED)
	etext.custom_minimum_size = Vector2(600, 0)
	v.add_child(etext)
	v.add_child(Kit.label("NEEDS", 13, Kit.GOLD))
	v.add_child(_cost_row(cost))
	var go := ChunkyButton.new("Strike the anvil", true, 20)
	go.disabled = not Forge.can_pay(cost)
	go.pressed.connect(_start_hammer)
	v.add_child(go)
	if not Forge.can_pay(cost):
		v.add_child(Kit.para("You are short of something. Iron Scrap and Bone Shards come off the risen; "
			+ "Tobin sells scrap, coal and salt.", 13))

func _choice_grid(parent: Control, head: String, order: Array, defs: Dictionary, chosen: String, cols: int,
		pick: Callable) -> void:
	parent.add_child(Kit.label(head, 13, Kit.GOLD))
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	parent.add_child(g)
	for k in order:
		var key: String = k
		var b := ChunkyButton.new(str(defs[key]["name"]), key == chosen, 14)
		b.custom_minimum_size = Vector2(620.0 / cols - 10.0, 46)
		b.tooltip_text = ""
		b.pressed.connect(func() -> void:
			pick.call(key)
			_build())
		g.add_child(b)

func _stat(parent: Control, what: String, value: String, note: String, good: bool) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var a := Kit.label(what.to_upper(), 13, Kit.MUTED)
	a.custom_minimum_size = Vector2(110, 0)
	h.add_child(a)
	h.add_child(Kit.label(value, 18, Kit.IVORY))
	if note != "":
		h.add_child(Kit.label(note, 13, Kit.GREEN if good else Kit.RED))
	parent.add_child(h)

## The bag items and silver a cost needs, each green if you have enough.
func _cost_row(cost: Dictionary) -> HFlowContainer:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 16)
	if cost.is_empty():
		h.add_child(Kit.label("Nothing", 15, Kit.MUTED))
	for k in cost.keys():
		var need := int(cost[k])
		var have := Forge.have(k)
		var what := "Silver" if k == "silver" else str(Run.item(k).get("name", k))
		var txt := "%s  %d" % [what, need] if k == "silver" else "%s  %d / %d" % [what, have, need]
		h.add_child(Kit.label(txt, 15, Kit.GREEN if have >= need else Kit.RED))
	return h

func _panel(at: Vector2, size_px: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	var st := HUD.chip(Kit.INK, Kit.GOLD_DEEP)
	st.set_content_margin_all(24)
	p.add_theme_stylebox_override("panel", st)
	p.position = at
	p.custom_minimum_size = size_px
	_body.add_child(p)
	return p

# --- The hammer -------------------------------------------------------------------------------------

func _start_hammer() -> void:
	if not Forge.can_pay(Forge.craft_cost(_form, _metal, _etching)):
		return
	_hammer = HammerGame.new()
	_hammer.finished.connect(_hammer_done)
	add_child(_hammer)

func _hammer_done(quality: float) -> void:
	var id := Forge.craft(_form, _metal, _etching, quality)
	if id == "":
		_hammer.queue_free()
		Run.toast.emit("Your bag is full" if Forge.can_pay(Forge.craft_cost(_form, _metal, _etching)) else
			"You cannot pay for it", "warn")
		_build()
		return
	_hammer.show_result(id)
	_hammer.equip.connect(func() -> void:
		Run.equip(id)
		_hammer.queue_free()
		_build())
	_hammer.again.connect(func() -> void:
		_hammer.queue_free()
		_build())

# --- TEMPER -----------------------------------------------------------------------------------------

func _weapons() -> Array:
	var out := []
	for s in Run.bag:
		var id := str(s["id"])
		if id != "" and not id in out and Run.item(id).get("kind", "") == "weapon":
			out.append(id)
	return out

func _build_temper() -> void:
	var col := _list(Kit.para("Each step of tempering adds a tenth to a weapon's damage, up to +5. "
		+ "The last two steps need Star-Iron, carried by the great dead.", 15))
	for id in _weapons():
		var d := Run.item(id)
		var lvl := Forge.temper_level(id)
		var row := _row(id)
		var mid := VBoxContainer.new()
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(mid)
		mid.add_child(Kit.label(str(d["name"]), 17, Kit.RARITY.get(str(d.get("rarity", "common")), Kit.IVORY)))
		var et := str(d.get("etch", ""))
		var sub := "Damage %d" % int(d.get("damage", 0))
		if lvl < Forge.MAX_TEMPER:
			var base := float(Run.forged.get(id, Run.items.get(id, {})).get("damage", 0))
			sub += "  →  %d" % int(roundf(base * (1.0 + 0.1 * (lvl + 1))))
		if et != "":
			sub += "   ·   " + str(Forge.etchings()[et]["name"]) + " etching"
		mid.add_child(Kit.label(sub, 14, Kit.MUTED))
		if _etch_open == id:
			var eh := HBoxContainer.new()
			eh.add_theme_constant_override("separation", 8)
			mid.add_child(eh)
			for e in ["ember", "rime", "grave"]:
				var ek: String = e
				var eb := ChunkyButton.new(str(Forge.etchings()[ek]["name"]), false, 13)
				eb.disabled = et == ek or not Forge.can_pay(Forge.etch_cost(ek))
				eb.pressed.connect(func() -> void:
					if Forge.etch(id, ek):
						_clang()
						Run.toast.emit("%s etched" % str(Forge.etchings()[ek]["name"]), "item")
					_etch_open = ""
					_build())
				eh.add_child(eb)
			mid.add_child(Kit.label("Ember: 2 Ember Coal  ·  Rime: 2 Rime Salt  ·  Grave: 3 Grave Dust  (and 30 silver)",
				12, Kit.MUTED))
		else:
			if lvl < Forge.MAX_TEMPER:
				mid.add_child(_cost_row(Forge.temper_cost(id)))
		var btns := VBoxContainer.new()
		btns.add_theme_constant_override("separation", 6)
		row.add_child(btns)
		var tb := ChunkyButton.new("Temper" if lvl < Forge.MAX_TEMPER else "+5", true, 14)
		tb.disabled = lvl >= Forge.MAX_TEMPER or not Forge.can_pay(Forge.temper_cost(id))
		tb.pressed.connect(func() -> void:
			if Forge.temper(id):
				_clang()
				Run.toast.emit("%s" % str(Run.item(id)["name"]), "item"))
		btns.add_child(tb)
		var xb := ChunkyButton.new("Back" if _etch_open == id else "Etch", false, 14)
		xb.pressed.connect(func() -> void:
			_etch_open = "" if _etch_open == id else id
			_build())
		btns.add_child(xb)
		col.add_child(row.get_parent())

# --- SALVAGE -----------------------------------------------------------------------------------------

func _build_salvage() -> void:
	var col := _list(Kit.para("Break down gear you no longer need. What you hold, you keep.", 15))
	var seen := {}
	var any := false
	for s in Run.bag:
		var id := str(s["id"])
		if id == "" or seen.has(id) or not Forge.can_salvage(id):
			continue
		seen[id] = true
		any = true
		var row := _row(id)
		var mid := VBoxContainer.new()
		mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(mid)
		var d := Run.item(id)
		mid.add_child(Kit.label(str(d["name"]) + ("   ×%d" % Run.count(id) if Run.count(id) > 1 else ""), 17,
			Kit.RARITY.get(str(d.get("rarity", "common")), Kit.IVORY)))
		var got := Forge.salvage_yield(id)
		var parts: Array[String] = []
		for k in got.keys():
			parts.append("%d %s" % [int(got[k]), str(Run.item(k).get("name", k))])
		mid.add_child(Kit.label("Gives  " + ", ".join(parts), 14, Kit.MUTED))
		var b := ChunkyButton.new("Break down", false, 14)
		b.pressed.connect(func() -> void:
			if Forge.salvage(id):
				_clang()
				Run.toast.emit("Broke down %s" % str(d["name"]), "item"))
		row.add_child(b)
		col.add_child(row.get_parent())
	if not any:
		col.add_child(Kit.para("Nothing to break down. Spare weapons and shields show here.", 15))

func _list(intro: Control) -> VBoxContainer:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	_body.add_child(outer)
	intro.custom_minimum_size = Vector2(900, 0)
	outer.add_child(intro)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1000, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(980, 0)
	scroll.add_child(col)
	return col

## A row for one item: a chip with its icon; the caller adds the rest.
func _row(id: String) -> HBoxContainer:
	var p := PanelContainer.new()
	var box := HUD.chip(Kit.INK_2, Kit.LINE)
	box.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	p.add_child(h)
	var slot := ItemSlot.new(60.0)
	slot.role = "shop"
	slot.set_item(id, Run.count(id))
	slot.hovered.connect(func(i: String, _s: ItemSlot) -> void: _card.show_item(i, ""))
	h.add_child(slot)
	return h

func _clang() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	Audio.play("block", p.global_position if p != null else Vector3.ZERO, 2.0, 0.7)

func _unhandled_input(event: InputEvent) -> void:
	if _hammer != null and is_instance_valid(_hammer):
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("inventory"):
		closed.emit()
		get_viewport().set_input_as_handled()


## The anvil's three blows. A marker swings across a bar; hit Space (or
## click) as it crosses the gold. The narrow bright middle is a perfect
## blow. Each blow is quicker than the last. Three perfect: a Masterwork.
class HammerGame extends Control:
	signal finished(quality: float)
	signal equip
	signal again

	const STRIKES := 3
	var _x := 0.0                 ## marker, 0..1
	var _dir := 1.0
	var _speed := 0.75
	var _scores: Array[float] = []
	var _flash := 0.0
	var _sparks: Array = []        ## [pos, vel, life]
	var _last := ""
	var _done_id := ""
	var _wait := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(delta: float) -> void:
		_flash = maxf(0.0, _flash - delta * 3.0)
		for s in _sparks:
			s[1] += Vector2(0, 900.0) * delta
			s[0] += s[1] * delta
			s[2] -= delta
		_sparks = _sparks.filter(func(s: Array) -> bool: return float(s[2]) > 0.0)
		if _wait > 0.0:
			_wait -= delta
			if _wait <= 0.0 and _scores.size() >= STRIKES:
				var q := 0.0
				for v in _scores:
					q += v
				finished.emit(q / float(STRIKES))
		elif _done_id == "" and _scores.size() < STRIKES:
			_x += _dir * _speed * delta
			if _x > 1.0 or _x < 0.0:
				_dir = -_dir
				_x = clampf(_x, 0.0, 1.0)
		queue_redraw()

	func _input(event: InputEvent) -> void:
		if not visible or _done_id != "" or _wait > 0.0 or _scores.size() >= STRIKES:
			return
		var hit := event.is_action_pressed("jump") or event.is_action_pressed("ui_accept") or \
			(event is InputEventMouseButton and (event as InputEventMouseButton).pressed
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
		if not hit:
			return
		get_viewport().set_input_as_handled()
		var off := absf(_x - 0.5)
		var score := 1.0 if off < 0.045 else (0.5 if off < 0.14 else 0.0)
		_scores.append(score)
		_last = "PERFECT" if score >= 1.0 else ("GOOD" if score > 0.0 else "MISS")
		_flash = 1.0
		_speed *= 1.35
		var n := 40 if score >= 1.0 else (22 if score > 0.0 else 6)
		var c := _anvil_top()
		for k in n:
			_sparks.append([c + Vector2(randf_range(-30, 30), 0),
				Vector2(randf_range(-420, 420), randf_range(-620, -180)), randf_range(0.4, 0.9)])
		var p := get_tree().get_first_node_in_group("player") as Node3D
		Audio.play("block", p.global_position if p != null else Vector3.ZERO, 3.0 if score >= 1.0 else 0.0,
			0.85 if score >= 1.0 else 0.6)
		if _scores.size() >= STRIKES:
			_wait = 0.7

	func show_result(id: String) -> void:
		_done_id = id
		var d := Run.item(id)
		var vp := get_viewport_rect().size
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 14)
		box.position = Vector2(vp.x * 0.5 - 330, vp.y * 0.5 + 40)
		box.custom_minimum_size = Vector2(660, 0)
		add_child(box)
		box.add_child(Kit.label("FORGED", 14, Kit.GOLD))
		var nm := Kit.title(str(d["name"]).to_upper(), 30, Kit.RARITY.get(str(d["rarity"]), Kit.IVORY), 4)
		nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nm.custom_minimum_size = Vector2(660, 0)
		box.add_child(nm)
		box.add_child(Kit.label("Damage %d   ·   Speed %.2f" % [int(d["damage"]), float(d["speed"])], 17, Kit.IVORY))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		box.add_child(row)
		var e := ChunkyButton.new("Equip it", true, 16)
		e.pressed.connect(func() -> void: equip.emit())
		row.add_child(e)
		var a := ChunkyButton.new("Back to the anvil", false, 16)
		a.pressed.connect(func() -> void: again.emit())
		row.add_child(a)

	func _anvil_top() -> Vector2:
		var vp := get_viewport_rect().size
		return Vector2(vp.x * 0.5, vp.y * 0.5 - 70)

	func _draw() -> void:
		var vp := get_viewport_rect().size
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.02, 0.02, 0.03, 0.82))
		var c := _anvil_top()
		# The anvil, and the blade glowing on it.
		var anvil := PackedVector2Array([c + Vector2(-190, 0), c + Vector2(150, 0), c + Vector2(230, -22),
			c + Vector2(140, -40), c + Vector2(-190, -40), c + Vector2(-190, 0)])
		draw_colored_polygon(PackedVector2Array([c + Vector2(-120, 0), c + Vector2(90, 0), c + Vector2(60, 70),
			c + Vector2(120, 110), c + Vector2(-150, 110), c + Vector2(-90, 70)]), Color("2b2d33"))
		draw_colored_polygon(anvil, Color("3a3d45"))
		draw_polyline(anvil, Color("5a5e68"), 3.0, true)
		var heat := Color(1.0, 0.55 + 0.3 * _flash, 0.2 + 0.4 * _flash)
		draw_rect(Rect2(c + Vector2(-150, -54), Vector2(280, 14)), heat)
		draw_rect(Rect2(c + Vector2(-150, -54), Vector2(280, 4)), Color(1, 0.95, 0.7, 0.8))
		for s in _sparks:
			var a := clampf(float(s[2]) * 2.0, 0.0, 1.0)
			draw_line(s[0], s[0] - (s[1] as Vector2) * 0.02, Color(1.0, 0.8, 0.4, a), 2.0, true)
		if _done_id != "":
			return
		# The timing bar.
		var w := 640.0
		var bar := Rect2(vp.x * 0.5 - w * 0.5, c.y + 150, w, 26)
		draw_style_box(HUD.chip(Kit.INK_2, Kit.LINE), bar.grow(6))
		draw_rect(Rect2(bar.position.x + w * (0.5 - 0.14), bar.position.y, w * 0.28, bar.size.y), Color(Kit.GOLD_DEEP, 0.9))
		draw_rect(Rect2(bar.position.x + w * (0.5 - 0.045), bar.position.y, w * 0.09, bar.size.y), Kit.GOLD_LIGHT)
		var mx := bar.position.x + w * _x
		draw_rect(Rect2(mx - 4, bar.position.y - 10, 8, bar.size.y + 20), Kit.IVORY)
		draw_colored_polygon(PackedVector2Array([Vector2(mx - 10, bar.position.y - 18), Vector2(mx + 10, bar.position.y - 18),
			Vector2(mx, bar.position.y - 6)]), Kit.IVORY)
		# Strikes so far.
		for k in STRIKES:
			var pc := Vector2(vp.x * 0.5 + (k - 1) * 46.0, bar.position.y + 80)
			var col := Kit.LINE
			if k < _scores.size():
				col = Kit.GOLD_LIGHT if _scores[k] >= 1.0 else (Kit.GOLD_DEEP if _scores[k] > 0.0 else Kit.RED)
			draw_circle(pc, 14.0, Kit.INK, true, -1.0, true)
			draw_circle(pc, 10.0, col, true, -1.0, true)
		var msg := "Strike %d of %d   ·   Space or click on the gold" % [mini(_scores.size() + 1, STRIKES), STRIKES]
		Kit.text(self, Vector2(0, bar.position.y + 130), msg, 17, Kit.IVORY, Game.ui_bold, HORIZONTAL_ALIGNMENT_CENTER, vp.x)
		if _last != "" and _flash > 0.0:
			var col2 := Kit.GOLD_LIGHT if _last == "PERFECT" else (Kit.IVORY if _last == "GOOD" else Kit.RED)
			Kit.text(self, Vector2(0, c.y - 130), _last, int(40 + 14 * _flash), Color(col2, minf(1.0, _flash * 2.0)),
				Kit.title_font(6), HORIZONTAL_ALIGNMENT_CENTER, vp.x)
