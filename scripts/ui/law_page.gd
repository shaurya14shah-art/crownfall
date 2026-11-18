class_name LawPage
extends Control
## Inscription. Before it wakes: an empty seal, filling as potential
## gathers, and one line of what you feel. After: the seal in your Law's
## colour, its name, how it shows itself, its three parts (the Law it acts
## on, when it works, what it costs), its two powers (one perhaps still
## hidden), mastery and rank, and the way to ascend when you are ready.

var world: World
var _choosing := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	Run.changed.connect(func(what: String) -> void:
		if what in ["law", "bag"] and is_inside_tree():
			_rebuild())
	_rebuild()

func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	var l := Run.law
	if l.is_empty():
		var hint := Kit.para("Something in you is listening. It stirs most near the Barrow of Ash, and when the risen fall.", 17,
			Kit.MUTED)
		hint.position = Vector2(470, 300)
		hint.size = Vector2(560, 80)
		add_child(hint)
		return
	var right := VBoxContainer.new()
	right.position = Vector2(470, 0)
	right.size = Vector2(size.x - 470, size.y)
	right.add_theme_constant_override("separation", 14)
	add_child(right)
	right.add_child(Kit.title(str(l["name"]).to_upper(), 40, Law.colour(str(l["principle"])).lightened(0.25), 6))
	var expr := Kit.para("It shows itself as %s." % l["expression"], 16, Kit.MUTED)
	right.add_child(expr)
	var parts := HBoxContainer.new()
	parts.add_theme_constant_override("separation", 12)
	right.add_child(parts)
	parts.add_child(_part("LAW", Law.principle_name(str(l["principle"])), "Acts on " + Law.principle_name(str(l["principle"])).to_lower()))
	var cd := Law.condition_def(str(l["condition"]))
	parts.add_child(_part("WHEN", str(cd.get("name", "")), str(cd.get("text", ""))))
	var pd := Law.price_def(str(l["price"]))
	parts.add_child(_part("PRICE", str(pd.get("name", "")), str(pd.get("text", ""))))
	var powers := HBoxContainer.new()
	powers.add_theme_constant_override("separation", 12)
	right.add_child(powers)
	var ps := Law.powers_of(l)
	for i in 2:
		var found := Law.found(l, i)
		powers.add_child(_part("F" if i == 0 else "G", str(ps[i]["name"]) if found else "???",
			str(ps[i]["text"]) if found else "Not yet found. Some uses reveal themselves only in the doing.", 390.0))
	var ascend_row := HBoxContainer.new()
	ascend_row.add_theme_constant_override("separation", 16)
	right.add_child(ascend_row)
	var nr := Law.next_rank(l)
	if Law.RANKS.has(nr):
		right.add_child(_part("NEXT: %s" % Law.RANK_TITLES[nr].to_upper(),
			"Mastery %d  ·  %s" % [int(Law.RANKS[nr]["mastery"]), str(Run.item(str(Law.RANKS[nr]["catalyst"])).get("name", ""))],
			str(Law.RANKS[nr]["unlock"]), 790.0))
	var why := Law.can_ascend(l)
	var b := ChunkyButton.new("Begin the Trial", true, 18)
	b.disabled = why != ""
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		var main := get_tree().get_first_node_in_group("main")
		if main != null:
			main.call("start_trial", nr))
	ascend_row.add_child(b)
	var reason := Kit.para(why if why != "" else "The catalyst is spent when the trial begins. Survive it to rise.", 15, Kit.MUTED)
	reason.custom_minimum_size = Vector2(520, 0)
	reason.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ascend_row.add_child(reason)

func _part(head: String, title: String, body: String, w: float = 255.0) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(w, 150)
	var box := HUD.chip(Kit.INK_2, Kit.LINE)
	box.set_content_margin_all(16)
	p.add_theme_stylebox_override("panel", box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	p.add_child(col)
	col.add_child(Kit.label(head, 12, Kit.GOLD))
	col.add_child(Kit.label(title, 20, Kit.IVORY))
	var t := Kit.para(body, 14, Kit.MUTED)
	t.custom_minimum_size = Vector2(w - 34, 0)
	col.add_child(t)
	return p

func _draw() -> void:
	var c := Vector2(210, 240)
	var r := 150.0
	var l := Run.law
	if l.is_empty():
		HUD.draw_sigil(self, c, r)
		Kit.text(self, Vector2(c.x - 200, c.y + r + 60), "DORMANT", 26, Kit.MUTED, Kit.title_font(8),
			HORIZONTAL_ALIGNMENT_CENTER, 400)
		Kit.text(self, Vector2(c.x - 200, c.y + r + 90), "POTENTIAL  %d%%" % int(Run.potential), 15, Kit.GOLD_LIGHT,
			Game.ui_bold, HORIZONTAL_ALIGNMENT_CENTER, 400)
		return
	HUD.draw_sigil(self, c, r)
	var rank := int(l["rank"])
	Kit.text(self, Vector2(c.x - 200, c.y + r + 60), Law.RANK_TITLES[rank].to_upper(), 26, Kit.IVORY, Kit.title_font(8),
		HORIZONTAL_ALIGNMENT_CENTER, 400)
	Kit.text(self, Vector2(c.x - 200, c.y + r + 90), "RANK %s  ·  MASTERY %d" % [["", "I", "II", "III", "IV", "V", "VI", "VII"][rank],
		int(l["mastery"])], 15, Kit.GOLD_LIGHT, Game.ui_bold, HORIZONTAL_ALIGNMENT_CENTER, 400)

func _process(_delta: float) -> void:
	queue_redraw()

## Ascension: the catalyst is spent and the Inscription grows a dimension.
func choose_dimension() -> void:
	if _choosing:
		return
	_choosing = true
	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.025, 0.035, 0.94)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var t := Kit.title("CHOOSE HOW IT GROWS", 34, Kit.IVORY, 6)
	t.position = Vector2(0, 40)
	t.size = Vector2(size.x, 50)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(t)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.position = Vector2(size.x * 0.5 - 560, 160)
	overlay.add_child(row)
	for k in Law.DIMENSIONS.keys():
		var d: Dictionary = Law.DIMENSIONS[k]
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(260, 0)
		col.add_theme_constant_override("separation", 10)
		row.add_child(col)
		col.add_child(Kit.title(str(d["name"]).to_upper(), 24, Kit.GOLD_LIGHT, 4))
		col.add_child(Kit.para(str(d["text"]), 16, Kit.IVORY))
		var b := ChunkyButton.new("Choose", true, 16)
		var key: String = k
		b.pressed.connect(func() -> void:
			Run.law["rank"] = int(Run.law["rank"]) + 1
			Run.law["dims"][key] = int(Run.law["dims"].get(key, 0)) + 1
			Run.add_clue("ascended_%d" % int(Run.law["rank"]), "Ascended",
				"I held the shard until it stopped being a shard. Afterward my Inscription had grown in %s." % str(d["name"]).to_lower())
			Run.toast.emit("Rank %s: %s" % [Run.law["rank"], Law.RANK_TITLES[int(Run.law["rank"])]], "law")
			_choosing = false
			Run.changed.emit("law"))
		col.add_child(b)
