class_name ChunkyButton
extends Button
## A button you want to press: a solid face on a thick lip, so it looks
## like a key. Under the cursor it lifts (the lip grows) and brightens;
## pressed, it sinks onto the lip. Primary buttons are gold, the rest ink.
## Draws its own caption (the Button's text stays empty).

var caption := ""
var primary := false
var font_size := 18
var _lift := 0.0
var _want := 0.0
var _down := false

func _init(label_text: String = "", is_primary: bool = false, size_px: int = 18) -> void:
	caption = label_text.to_upper()
	primary = is_primary
	font_size = size_px
	focus_mode = Control.FOCUS_NONE
	var w := Game.ui_bold.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	custom_minimum_size = Vector2(w + 56.0, font_size * 2.9)
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())
	mouse_entered.connect(func() -> void:
		if not disabled:
			_want = 1.0
			Audio.ui("hover", -16.0))
	mouse_exited.connect(func() -> void: _want = 0.0)
	button_down.connect(func() -> void:
		_down = true
		queue_redraw())
	button_up.connect(func() -> void:
		_down = false
		queue_redraw())
	pressed.connect(func() -> void: Audio.ui("click", -6.0))

func set_caption(s: String) -> void:
	caption = s.to_upper()
	queue_redraw()

func _process(delta: float) -> void:
	var was := _lift
	_lift = move_toward(_lift, _want if not disabled else 0.0, delta * 9.0)
	if was != _lift:
		queue_redraw()

func _draw() -> void:
	var lip := 1.0 if _down else 5.0 + 2.0 * _lift
	var face_top := 7.0 - lip
	var r := Rect2(Vector2(0, face_top), Vector2(size.x, size.y - 7.0))
	var face: Color
	var under: Color
	var rim: Color
	var ink: Color
	if disabled:
		face = Kit.INK_2
		under = Color("0c0d11")
		rim = Kit.LINE
		ink = Color(Kit.MUTED, 0.6)
	elif primary:
		face = Kit.GOLD.lightened(0.12 * _lift)
		under = Kit.GOLD_DEEP
		rim = Kit.GOLD_LIGHT
		ink = Kit.INK
	else:
		face = Kit.INK_3.lightened(0.07 * _lift)
		under = Color("0c0d11")
		rim = Kit.LINE.lerp(Kit.GOLD, _lift)
		ink = Kit.IVORY
	var lip_box := StyleBoxFlat.new()
	lip_box.bg_color = under
	lip_box.set_corner_radius_all(10)
	lip_box.anti_aliasing = true
	lip_box.shadow_color = Kit.SHADOW
	lip_box.shadow_size = 1
	lip_box.shadow_offset = Vector2(0, 4)
	draw_style_box(lip_box, Rect2(Vector2(0, face_top + lip), r.size))
	var face_box := StyleBoxFlat.new()
	face_box.bg_color = face
	face_box.border_color = rim
	face_box.set_border_width_all(2)
	face_box.set_corner_radius_all(10)
	face_box.anti_aliasing = true
	draw_style_box(face_box, r)
	var ty := r.position.y + r.size.y * 0.5 + font_size * 0.36
	draw_string(Game.ui_bold, Vector2(0, ty), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, ink)
