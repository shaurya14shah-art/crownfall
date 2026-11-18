class_name PauseMenu
extends Control
## Paused: the world dims (not frosted) and a column of chunky buttons
## stands on the left. Settings and the save slots open beside it.

signal resume
signal to_title
signal save_to(slot: int)
signal load_from(slot: int)

var _column: VBoxContainer
var _side: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = Kit.theme()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.035, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_column = VBoxContainer.new()
	_column.position = Vector2(110, 180)
	_column.custom_minimum_size = Vector2(340, 0)
	_column.add_theme_constant_override("separation", 12)
	add_child(_column)
	_column.add_child(Kit.title("PAUSED", 60, Kit.IVORY, 12))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 16)
	_column.add_child(gap)
	for entry in [["Resume", "resume", true], ["Save", "save", false], ["Load", "load", false],
			["Settings", "settings", false], ["Return to Title", "title", false]]:
		var b := ChunkyButton.new(entry[0], entry[2], 18)
		var action: String = entry[1]
		b.pressed.connect(func() -> void: _on(action))
		_column.add_child(b)

func _on(action: String) -> void:
	match action:
		"resume":
			resume.emit()
		"title":
			to_title.emit()
		"settings":
			var s := SettingsPanel.new()
			s.back.connect(_close_side)
			_show_side(s)
		"save", "load":
			var p := SavePanel.new()
			p.saving = action == "save"
			p.back.connect(_close_side)
			p.chosen.connect(func(slot: int) -> void:
				if action == "save":
					save_to.emit(slot)
					Audio.ui("confirm", -4.0)
					_close_side()
				else:
					load_from.emit(slot))
			_show_side(p)

func _show_side(c: Control) -> void:
	_close_side()
	_side = c
	c.position = Vector2(560, 160)
	add_child(c)
	c.modulate.a = 0.0
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(c, "modulate:a", 1.0, 0.15)

func _close_side() -> void:
	if _side != null and is_instance_valid(_side):
		_side.queue_free()
	_side = null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _side != null:
			_close_side()
		else:
			resume.emit()
		get_viewport().set_input_as_handled()

func open() -> void:
	visible = true
	modulate.a = 0.0
	create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(self, "modulate:a", 1.0, 0.15)
	Audio.ui("open", -10.0)
