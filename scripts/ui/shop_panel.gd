class_name ShopPanel
extends Control
## Tobin's forge: what he sells on the left, what you could sell him on the
## right. He pays a third of what he charges.

signal closed
signal to_forge

const STOCK := ["red_potion", "bread", "iron_scrap", "ember_coal", "rime_salt", "hand_axe", "barrow_dagger",
	"quarterstaff", "knights_greatsword", "bearded_axe", "crest_shield", "spiked_shield", "tower_shield"]

var _left: VBoxContainer
var _right: VBoxContainer
var _card: ItemCard

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Kit.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.05, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var t := Kit.title("TOBIN'S FORGE", 44, Kit.IVORY, 8)
	t.position = Vector2(80, 40)
	add_child(t)
	var row := HBoxContainer.new()
	row.position = Vector2(80, 130)
	row.add_theme_constant_override("separation", 40)
	add_child(row)
	_left = _column(row, "FOR SALE")
	_right = _column(row, "SELL")
	var done := ChunkyButton.new("Leave", false, 16)
	done.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	done.position = Vector2(-220, -110)
	done.pressed.connect(func() -> void: closed.emit())
	add_child(done)
	var anvil := ChunkyButton.new("Use the Anvil", true, 16)
	anvil.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	anvil.position = Vector2(-470, -110)
	anvil.pressed.connect(func() -> void: to_forge.emit())
	add_child(anvil)
	_card = ItemCard.new()
	add_child(_card)
	Run.changed.connect(func(what: String) -> void:
		if what in ["bag", "silver"] and is_inside_tree():
			_fill())
	_fill()

func _column(parent: Node, head: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	parent.add_child(col)
	col.add_child(Kit.label(head, 14, Kit.GOLD))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 600)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	return list

func _fill() -> void:
	for c in _left.get_children():
		c.queue_free()
	for c in _right.get_children():
		c.queue_free()
	for id in STOCK:
		var price := int(Run.item(id).get("price", 0))
		_left.add_child(_row(id, price, "Buy", Run.silver >= price, func() -> void:
			if Run.spend(price):
				Run.add_item(id, 1)
				Run.flags["bought"] = true
				Audio.play("coin", Vector3.ZERO, -4.0)))
	var seen := {}
	for s in Run.bag:
		var id := str(s["id"])
		if id == "" or seen.has(id):
			continue
		seen[id] = true
		var def := Run.item(id)
		if def.get("kind", "") == "relic" or int(def.get("price", 0)) <= 0:
			continue
		if Run.gear.get("weapon", "") == id or Run.gear.get("shield", "") == id:
			if Run.count(id) <= 1:
				continue
		var pay := maxi(1, int(int(def["price"]) / 3))
		_right.add_child(_row(id, pay, "Sell", true, func() -> void:
			if Run.remove_item(id, 1):
				Run.add_silver(pay, true)
				Audio.play("coin", Vector3.ZERO, -6.0, 1.2), Run.count(id)))

func _row(id: String, price: int, verb: String, can: bool, act: Callable, have: int = 0) -> Control:
	var p := PanelContainer.new()
	var box := HUD.chip(Kit.INK_2, Kit.LINE)
	box.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var slot := ItemSlot.new(60.0)
	slot.role = "shop"
	slot.set_item(id, have)
	slot.hovered.connect(func(i: String, _s: ItemSlot) -> void: _card.show_item(i, ""))
	h.add_child(slot)
	var name := Kit.label(str(Run.item(id).get("name", id)), 17, Kit.RARITY.get(str(Run.item(id).get("rarity", "common")), Kit.IVORY))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(name)
	var cost := Kit.label("%d" % price, 18, Kit.GOLD_LIGHT)
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(cost)
	var b := ChunkyButton.new(verb, verb == "Buy", 15)
	b.disabled = not can
	b.pressed.connect(act)
	h.add_child(b)
	return p

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("inventory"):
		closed.emit()
		get_viewport().set_input_as_handled()
