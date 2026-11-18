class_name SettingsPanel
extends PanelContainer
## Settings, shared by the title screen and the pause menu: quality, field
## of view, mouse sensitivity, inverted look, volume, fullscreen. Saved as
## they change.

signal back

func _ready() -> void:
	add_theme_stylebox_override("panel", Kit.card(Kit.INK, Kit.GOLD_DEEP, 10))
	custom_minimum_size = Vector2(520, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	col.add_child(Kit.title("SETTINGS", 32, Kit.IVORY, 6))
	col.add_child(Kit.label("GRAPHICS", 13, Kit.GOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var buttons: Array[ChunkyButton] = []
	for q in ["low", "medium", "high"]:
		var b := ChunkyButton.new(q, Game.quality == q, 15)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.append(b)
		row.add_child(b)
	for b in buttons:
		var me := b
		b.pressed.connect(func() -> void:
			Game.set_quality(me.caption.to_lower())
			for o in buttons:
				o.primary = o == me
				o.queue_redraw())
	col.add_child(Kit.para("Shadows, grass and draw distance change fully on the next start.", 13))
	_slider(col, "FIELD OF VIEW", 50.0, 85.0, Game.fov, func(v: float) -> void: Game.fov = v)
	_slider(col, "MOUSE SENSITIVITY", 0.0008, 0.006, Game.mouse_sensitivity, func(v: float) -> void:
		Game.mouse_sensitivity = v)
	_slider(col, "VOLUME", 0.0, 1.0, Game.master_volume, func(v: float) -> void: Game.set_master_volume(v))
	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation", 10)
	col.add_child(toggles)
	var inv := ChunkyButton.new("Invert look: %s" % ("on" if Game.invert_y else "off"), false, 14)
	inv.pressed.connect(func() -> void:
		Game.invert_y = not Game.invert_y
		inv.set_caption("Invert look: %s" % ("on" if Game.invert_y else "off")))
	toggles.add_child(inv)
	var full := ChunkyButton.new("Fullscreen", false, 14)
	full.pressed.connect(func() -> void:
		var w := get_window()
		w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN)
	toggles.add_child(full)
	var done := ChunkyButton.new("Back", true, 16)
	done.pressed.connect(func() -> void:
		Game.save_settings()
		back.emit())
	col.add_child(done)

func _slider(parent: Node, label: String, lo: float, hi: float, value: float, apply: Callable) -> void:
	parent.add_child(Kit.label(label, 13, Kit.GOLD))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 200.0
	s.value = value
	s.custom_minimum_size = Vector2(0, 26)
	s.value_changed.connect(func(v: float) -> void: apply.call(v))
	parent.add_child(s)
