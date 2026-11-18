class_name ItemSlot
extends Control
## One square in the bag, the hotbar or the equipment column: the item's
## rendered icon, a rim in its rarity's colour, its count; lifts under the
## cursor. Drag it onto another slot to move it; click to use or equip;
## right-click to put it on the hotbar (or, on the hotbar, to clear it).

signal hovered(id: String, slot: ItemSlot)
signal clicked(slot: ItemSlot)
signal right_clicked(slot: ItemSlot)
signal dropped(from: ItemSlot, to: ItemSlot)

var item_id := ""
var count := 0
var index := -1                ## position in its container (bag slot, hotbar slot)
var role := "bag"              ## bag | hotbar | weapon | shield | shop
var label := ""                ## shown when empty ("WEAPON")
var highlight := false
var _hover := 0.0
var _want := 0.0

func _init(size_px: float = 72.0) -> void:
	custom_minimum_size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_STOP
	Icons.updated.connect(func(id: String) -> void:
		if id == item_id:
			queue_redraw())
	mouse_entered.connect(func() -> void:
		_want = 1.0
		hovered.emit(item_id, self)
		if item_id != "":
			Audio.ui("hover", -18.0))
	mouse_exited.connect(func() -> void:
		_want = 0.0
		hovered.emit("", self))

func set_item(id: String, n: int) -> void:
	item_id = id
	count = n
	queue_redraw()

func _process(delta: float) -> void:
	var was := _hover
	_hover = move_toward(_hover, _want, delta * 10.0)
	if was != _hover:
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and not get_viewport().gui_is_dragging():
			clicked.emit(self)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			right_clicked.emit(self)

func _get_drag_data(_at: Vector2) -> Variant:
	if item_id == "" or role == "shop":
		return null
	var preview := TextureRect.new()
	preview.texture = Icons.get_icon(item_id)
	preview.custom_minimum_size = Vector2(64, 64)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(64, 64)
	preview.position = -Vector2(32, 32)
	var holder := Control.new()
	holder.add_child(preview)
	set_drag_preview(holder)
	return self

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is ItemSlot and data != self and role != "shop"

func _drop_data(_at: Vector2, data: Variant) -> void:
	dropped.emit(data as ItemSlot, self)

func _draw() -> void:
	var lift := _hover * 3.0
	var r := Rect2(Vector2(0, 4 - lift), size - Vector2(0, 4))
	draw_rect(Rect2(Vector2(2, 6), size - Vector2(4, 4)), Color("0b0c10"))
	var rim := Kit.LINE
	if item_id != "":
		rim = Kit.RARITY.get(str(Run.item(item_id).get("rarity", "common")), Kit.LINE).darkened(0.25)
	if highlight:
		rim = Kit.GOLD
	rim = rim.lerp(Kit.GOLD_LIGHT, _hover * 0.6)
	draw_style_box(HUD.chip(Kit.INK_2.lightened(0.04 * _hover), rim), r)
	if item_id == "":
		if label != "":
			Kit.text(self, Vector2(0, r.get_center().y + 5), label, 11, Color(Kit.MUTED, 0.6), Game.ui_bold,
				HORIZONTAL_ALIGNMENT_CENTER, size.x)
		return
	var tex := Icons.get_icon(item_id)
	if tex != null:
		draw_texture_rect(tex, r.grow(-7), false)
	if count > 1:
		Kit.text(self, Vector2(0, r.end.y - 8), str(count), 15, Kit.IVORY, Game.ui_bold, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 9)
	if highlight:
		Glyphs.draw(self, "check", r.position + Vector2(14, 14), 16.0, Kit.GOLD)
