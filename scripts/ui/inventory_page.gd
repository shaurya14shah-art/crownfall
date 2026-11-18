class_name InventoryPage
extends Control
## Inventory: the knight on the left in what he is wearing (drag to turn
## him), his two hands as slots, and what those make him; the bag on the
## right; the hotbar along the bottom. Click to use or equip, drag to move,
## right-click to put something on the hotbar.

var world: World
var _bag: Array[ItemSlot] = []
var _hot: Array[ItemSlot] = []
var _weapon: ItemSlot
var _shield: ItemSlot
var _stats: VBoxContainer
var _card: ItemCard

func _ready() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 60)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	# Left: the knight and what he holds.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 14)
	row.add_child(left)
	left.add_child(CharacterPreview.new())
	var hands := HBoxContainer.new()
	hands.add_theme_constant_override("separation", 14)
	hands.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(hands)
	_weapon = _slot("weapon", 0, 84.0)
	_weapon.label = "WEAPON"
	_shield = _slot("shield", 0, 84.0)
	_shield.label = "SHIELD"
	hands.add_child(_weapon)
	hands.add_child(_shield)
	_stats = VBoxContainer.new()
	_stats.add_theme_constant_override("separation", 4)
	left.add_child(_stats)
	# Right: the bag, then the hotbar.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	row.add_child(right)
	right.add_child(Kit.title("BAG", 28, Kit.IVORY, 6))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	right.add_child(grid)
	for i in Run.BAG_SIZE:
		var s := _slot("bag", i, 80.0)
		grid.add_child(s)
		_bag.append(s)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	right.add_child(gap)
	right.add_child(Kit.title("HOTBAR", 22, Kit.IVORY, 5))
	var hot := HBoxContainer.new()
	hot.add_theme_constant_override("separation", 10)
	right.add_child(hot)
	for i in Run.HOTBAR:
		var s := _slot("hotbar", i, 80.0)
		hot.add_child(s)
		_hot.append(s)
	right.add_child(Kit.para("Click to use or equip  ·  Drag to move  ·  Right-click to put on the hotbar", 13))
	_card = ItemCard.new()
	add_child(_card)
	Run.changed.connect(_on_changed)
	_refresh()

func _slot(role: String, i: int, s: float) -> ItemSlot:
	var slot := ItemSlot.new(s)
	slot.role = role
	slot.index = i
	slot.hovered.connect(func(id: String, _sl: ItemSlot) -> void:
		var how := ""
		if id != "":
			match str(Run.item(id).get("kind", "")):
				"weapon", "shield": how = "CLICK  EQUIP"
				"consumable": how = "CLICK  USE"
		_card.show_item(id, how))
	slot.clicked.connect(_on_click)
	slot.right_clicked.connect(_on_right)
	slot.dropped.connect(_on_drop)
	return slot

func _on_changed(what: String) -> void:
	if what in ["bag", "gear", "hotbar", "skills"] and is_inside_tree():
		_refresh()

func _refresh() -> void:
	for i in _bag.size():
		var s: Dictionary = Run.bag[i]
		_bag[i].set_item(str(s["id"]), int(s["n"]))
		var id := str(s["id"])
		_bag[i].highlight = id != "" and (Run.gear.get("weapon", "") == id or Run.gear.get("shield", "") == id)
	for i in _hot.size():
		var id := str(Run.hotbar[i])
		_hot[i].set_item(id, Run.count(id) if id != "" else 0)
	_weapon.set_item(str(Run.gear.get("weapon", "")), 1)
	_shield.set_item(str(Run.gear.get("shield", "")), 1)
	for c in _stats.get_children():
		c.queue_free()
	var w := Run.item(str(Run.gear.get("weapon", "")))
	var sh := Run.item(str(Run.gear.get("shield", "")))
	var p := world.player if world != null else null
	var stat_rows := [
		["Damage", str(int(float(w.get("damage", 0)) * (1.0 + Run.perk("damage"))))],
		["Swing", "%.1f" % float(w.get("speed", 1.0))],
		["Shield", "%d%%" % int((float(sh.get("block", 0.0)) + Run.perk("block")) * 100.0) if not sh.is_empty() else "—"],
		["Health", "%d / %d" % [int(p.health), int(p.max_health())] if p != null else "—"],
	]
	for r in stat_rows:
		var line := HBoxContainer.new()
		var k := Kit.label(str(r[0]).to_upper(), 13, Kit.MUTED)
		k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(k)
		line.add_child(Kit.label(str(r[1]), 17, Kit.IVORY))
		_stats.add_child(line)

func _on_click(slot: ItemSlot) -> void:
	if slot.item_id == "":
		return
	if slot.role in ["weapon", "shield"]:
		Run.unequip(slot.role)
		return
	if world != null and world.player != null:
		world.player.use_item(slot.item_id)

func _on_right(slot: ItemSlot) -> void:
	if slot.role == "hotbar":
		Run.hotbar[slot.index] = ""
		Run.changed.emit("hotbar")
		return
	if slot.item_id == "":
		return
	var free := Run.hotbar.find("")
	Run.set_hotbar(free if free >= 0 else Run.HOTBAR - 1, slot.item_id)
	Audio.ui("confirm", -10.0)

func _on_drop(from: ItemSlot, to: ItemSlot) -> void:
	if to.role == "hotbar":
		Run.set_hotbar(to.index, from.item_id)
	elif to.role == "bag" and from.role == "bag":
		Run.swap_slots(from.index, to.index)
	elif to.role in ["weapon", "shield"]:
		Run.equip(from.item_id)
	Audio.ui("click", -10.0)
