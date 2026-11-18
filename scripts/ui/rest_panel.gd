class_name RestPanel
extends Control
## Resting at a Waystone. The stone's name, what resting did, and a short
## column of choices; the chosen one opens on the right: the stones you can
## travel to, or the Flask and what you can do for it.

signal closed
signal travel(id: String)
signal forge
signal wait(to_night: bool)
signal call_ship

const FLASK_CAP := 8
const POTENCY_CAP := 6

var waystone: Waystone
var world: World
var _side: VBoxContainer
var _flask_line: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Kit.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.04, 0.84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var left := VBoxContainer.new()
	left.position = Vector2(90, 70)
	left.custom_minimum_size = Vector2(520, 0)
	left.add_theme_constant_override("separation", 14)
	add_child(left)
	left.add_child(_tag("WAYSTONE"))
	left.add_child(Kit.title(waystone.title.to_upper() if waystone != null else "WAYSTONE", 46, Kit.IVORY, 6))
	var said := Kit.para("You rest. Your wounds close, the Flask fills, and the fallen rise again.", 16)
	said.custom_minimum_size = Vector2(500, 0)
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(said)
	_flask_line = Kit.label("", 17, Kit.GOLD_LIGHT)
	left.add_child(_flask_line)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	left.add_child(gap)
	var night := world != null and world.sky.is_night()
	var choices := [["Travel", _show_travel], ["Forge", _to_forge], ["The Flask", _show_flask]]
	if waystone != null and waystone.mooring != Vector3.INF:
		choices.append(["Call your ship here", _call_ship])
	choices.append_array([
		["Wait for morning" if night else "Wait for nightfall", _wait], ["Leave", _leave]])
	for b in choices:
		var cb := ChunkyButton.new(str(b[0]), b[0] == "Travel", 18)
		cb.custom_minimum_size = Vector2(320, 54)
		cb.pressed.connect(b[1] as Callable)
		left.add_child(cb)
	var panel := PanelContainer.new()
	var box := HUD.chip(Kit.INK, Kit.GOLD_DEEP)
	box.set_content_margin_all(26)
	panel.add_theme_stylebox_override("panel", box)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-700, 150)
	panel.custom_minimum_size = Vector2(600, 520)
	add_child(panel)
	_side = VBoxContainer.new()
	_side.add_theme_constant_override("separation", 12)
	panel.add_child(_side)
	Run.changed.connect(func(what: String) -> void:
		if what in ["flask", "bag"] and is_inside_tree():
			_refresh_flask())
	_refresh_flask()
	_show_travel()

func _call_ship() -> void:
	call_ship.emit()
	closed.emit()

func _to_forge() -> void:
	forge.emit()

func _leave() -> void:
	closed.emit()

## Sits out the hours: to nightfall by day, to morning by night.
func _wait() -> void:
	wait.emit(not (world != null and world.sky.is_night()))
	Audio.ui("confirm", -8.0)
	closed.emit()

func _tag(text: String) -> Control:
	var p := PanelContainer.new()
	var st := HUD.chip(Kit.GOLD, Kit.GOLD_DEEP)
	st.set_content_margin_all(6)
	st.content_margin_left = 12
	st.content_margin_right = 12
	p.add_theme_stylebox_override("panel", st)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add_child(Kit.label(text, 13, Kit.INK))
	return p

func _refresh_flask() -> void:
	_flask_line.text = "Flask  %d / %d   ·   each draught heals %d" % [Run.flask, Run.flask_max, int(Run.flask_heal())]

func _clear() -> void:
	for c in _side.get_children():
		c.queue_free()

func _show_travel() -> void:
	_clear()
	_side.add_child(Kit.label("TRAVEL", 14, Kit.GOLD))
	_side.add_child(Kit.para("To any stone you have kindled.", 15))
	var here := waystone.global_position if waystone != null else Vector3.ZERO
	var any := false
	for n in get_tree().get_nodes_in_group("waystones"):
		var ws := n as Waystone
		if not ws.kindled():
			continue
		any = true
		var same := waystone != null and ws.id == waystone.id
		var metres := int(ws.global_position.distance_to(here))
		var cb := ChunkyButton.new("%s   ·   %s" % [ws.title, "you are here" if same else "%d m" % metres], false, 16)
		cb.custom_minimum_size = Vector2(540, 48)
		cb.disabled = same
		var id := ws.id
		cb.pressed.connect(func() -> void: travel.emit(id))
		_side.add_child(cb)
	if not any:
		_side.add_child(Kit.para("No other stone is kindled yet.", 15))

func _show_flask() -> void:
	_clear()
	_side.add_child(Kit.label("THE FLASK", 14, Kit.GOLD))
	var about := Kit.para("Hearthseeds give it another draught. Bright Tears make each draught heal more. "
		+ "Both are found on the great dead and in the Gates.", 15)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size = Vector2(540, 0)
	_side.add_child(about)
	_flask_row("hearth_seed", "Draughts  %d / %d" % [Run.flask_max, FLASK_CAP], "Plant a Hearthseed",
		Run.flask_max < FLASK_CAP, func() -> void:
			if Run.remove_item("hearth_seed", 1):
				Run.flask_max += 1
				Run.flask = Run.flask_max
				Run.changed.emit("flask")
				Audio.ui("confirm", -4.0)
				_show_flask())
	_flask_row("bright_tear", "Potency  %d / %d" % [Run.flask_potency, POTENCY_CAP], "Pour a Bright Tear",
		Run.flask_potency < POTENCY_CAP, func() -> void:
			if Run.remove_item("bright_tear", 1):
				Run.flask_potency += 1
				Run.changed.emit("flask")
				Audio.ui("confirm", -4.0)
				_show_flask())

func _flask_row(item_id: String, now: String, verb: String, room: bool, act: Callable) -> void:
	var p := PanelContainer.new()
	var st := HUD.chip(Kit.INK_2, Kit.LINE)
	st.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var slot := ItemSlot.new(56.0)
	slot.role = "shop"
	slot.set_item(item_id, Run.count(item_id))
	h.add_child(slot)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(Kit.label(str(Run.item(item_id).get("name", item_id)) + "   ×%d" % Run.count(item_id), 16, Kit.IVORY))
	v.add_child(Kit.label(now, 14, Kit.MUTED))
	h.add_child(v)
	var b := ChunkyButton.new(verb, true, 14)
	b.disabled = not room or Run.count(item_id) <= 0
	b.pressed.connect(act)
	h.add_child(b)
	_side.add_child(p)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("inventory"):
		closed.emit()
		get_viewport().set_input_as_handled()
