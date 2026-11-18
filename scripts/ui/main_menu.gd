class_name MainMenu
extends Control
## The title screen, over the live island: a slow flight round Brightwater
## at golden hour, a dark band on the left, the name engraved, and chunky
## buttons. Continue picks up the latest save.

signal begin(slot: int)          ## -1 for a new journey
signal quit_game

var _column: VBoxContainer
var _side: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Kit.theme()
	var band := ColorRect.new()
	band.color = Color(0.03, 0.035, 0.05, 0.82)
	band.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	band.offset_right = 560
	add_child(band)
	var edge := ColorRect.new()
	edge.color = Kit.GOLD_DEEP
	edge.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	edge.offset_left = 560
	edge.offset_right = 563
	add_child(edge)
	_column = VBoxContainer.new()
	_column.position = Vector2(80, 150)
	_column.custom_minimum_size = Vector2(400, 0)
	_column.add_theme_constant_override("separation", 12)
	add_child(_column)
	_column.add_child(Kit.label("THE SHATTERED REALMS", 15, Kit.GOLD))
	_column.add_child(Kit.title("CROWNFALL", 76, Kit.IVORY, 10))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	_column.add_child(gap)
	var latest := SaveSystem.latest()
	if latest >= 0:
		var c := ChunkyButton.new("Continue", true, 20)
		c.pressed.connect(func() -> void: begin.emit(latest))
		_column.add_child(c)
		var where := Kit.label(SaveSystem.describe(latest), 13, Kit.MUTED, false)
		_column.add_child(where)
	var n := ChunkyButton.new("New Journey", latest < 0, 20)
	n.pressed.connect(func() -> void: begin.emit(-1))
	_column.add_child(n)
	for entry in [["Load", "load"], ["Settings", "settings"], ["Credits", "credits"], ["Quit", "quit"]]:
		var b := ChunkyButton.new(entry[0], false, 18)
		var action: String = entry[1]
		b.pressed.connect(func() -> void: _on(action))
		_column.add_child(b)
	var foot := Kit.label("Art: Quaternius, Kay Lousberg, Kenney (CC0)  ·  Godot", 12, Color(Kit.MUTED, 0.7), false)
	foot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	foot.position = Vector2(80, -44)
	add_child(foot)
	# The column rises in.
	var k := 0
	for c in _column.get_children():
		(c as Control).modulate.a = 0.0
		var tw := create_tween()
		tw.tween_interval(0.2 + 0.07 * k)
		tw.tween_property(c, "modulate:a", 1.0, 0.45)
		k += 1

func _on(action: String) -> void:
	match action:
		"quit":
			quit_game.emit()
		"settings":
			var s := SettingsPanel.new()
			s.back.connect(_close_side)
			_show_side(s)
		"load":
			var p := SavePanel.new()
			p.saving = false
			p.back.connect(_close_side)
			p.chosen.connect(func(slot: int) -> void: begin.emit(slot))
			_show_side(p)
		"credits":
			var c := PanelContainer.new()
			c.add_theme_stylebox_override("panel", Kit.card(Kit.INK, Kit.GOLD_DEEP, 10))
			var col := VBoxContainer.new()
			col.add_theme_constant_override("separation", 10)
			c.add_child(col)
			col.add_child(Kit.title("CREDITS", 32, Kit.IVORY, 6))
			for line in [["NATURE, VILLAGE, PROPS", "Quaternius"], ["ADVENTURERS, SKELETONS", "Kay Lousberg (KayKit)"],
					["SHIPS, SOUNDS", "Kenney"], ["TYPE", "Cinzel (Natanael Gama), Inter (Rasmus Andersson)"],
					["ENGINE", "Godot"]]:
				col.add_child(Kit.label(line[0], 12, Kit.GOLD))
				col.add_child(Kit.label(line[1], 17, Kit.IVORY, false))
			var b := ChunkyButton.new("Back", true, 15)
			b.pressed.connect(_close_side)
			col.add_child(b)
			_show_side(c)

func _show_side(c: Control) -> void:
	_close_side()
	_side = c
	c.position = Vector2(660, 150)
	add_child(c)
	c.modulate.a = 0.0
	create_tween().tween_property(c, "modulate:a", 1.0, 0.15)

func _close_side() -> void:
	if _side != null and is_instance_valid(_side):
		_side.queue_free()
	_side = null
