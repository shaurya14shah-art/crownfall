class_name SavePanel
extends PanelContainer
## Three slots. In save mode each can be written over; in load mode only the
## ones with something in them can be picked.

signal chosen(slot: int)
signal back

var saving := true

func _ready() -> void:
	add_theme_stylebox_override("panel", Kit.card(Kit.INK, Kit.GOLD_DEEP, 10))
	custom_minimum_size = Vector2(560, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	col.add_child(Kit.title("SAVE" if saving else "LOAD", 32, Kit.IVORY, 6))
	for i in SaveSystem.SLOTS:
		var d := SaveSystem.read(i)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		col.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(Kit.label("SLOT %d" % (i + 1), 13, Kit.GOLD))
		info.add_child(Kit.label(SaveSystem.describe(i) if not d.is_empty() else "Empty", 18,
			Kit.IVORY if not d.is_empty() else Kit.MUTED))
		if not d.is_empty():
			info.add_child(Kit.label(str(d.get("saved", "")).replace("T", "  "), 12, Kit.MUTED, false))
		var b := ChunkyButton.new("Save here" if saving else "Load", true, 15)
		b.disabled = not saving and d.is_empty()
		var slot := i
		b.pressed.connect(func() -> void: chosen.emit(slot))
		row.add_child(b)
	var done := ChunkyButton.new("Back", false, 15)
	done.pressed.connect(func() -> void: back.emit())
	col.add_child(done)
