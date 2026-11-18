class_name Kit
extends RefCounted
## "Heraldry", the interface's look. Opaque ink cards with a gold rim and a
## hard drop shadow (no glass, no blur); chunky buttons with a thick lip
## that lift under the cursor and squash when pressed; engraved Cinzel for
## names and titles, heavy Inter for everything you act on. One accent
## colour (gold) for what matters; colour otherwise only means something
## (rarity, health, a Law).

const INK := Color("15171d")
const INK_2 := Color("1e2129")
const INK_3 := Color("2a2e38")
const LINE := Color("3a3f4b")
const GOLD := Color("e3b252")
const GOLD_DEEP := Color("9c7426")
const GOLD_LIGHT := Color("f6d68a")
const IVORY := Color("f3ece0")
const MUTED := Color("a39d92")
const RED := Color("d9473d")
const GREEN := Color("6fbf73")
const SHADOW := Color(0, 0, 0, 0.45)

const RARITY := {"common": Color("c9c4bb"), "fine": Color("5fb3ff"), "rare": Color("c084fc"), "relic": Color("f2c14e")}

static func title_font(spacing: int = 4) -> Font:
	var f := FontVariation.new()
	f.base_font = Game.title_font
	f.spacing_glyph = spacing
	return f

static func heavy() -> Font:
	return Game.ui_bold

## A card: opaque, gold-rimmed, with a hard shadow under it.
static func card(fill: Color = INK, rim: Color = GOLD_DEEP, radius: int = 8, rim_w: int = 2) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = rim
	b.set_border_width_all(rim_w)
	b.set_corner_radius_all(radius)
	b.corner_detail = 6
	b.anti_aliasing = true
	b.shadow_color = SHADOW
	b.shadow_size = 1
	b.shadow_offset = Vector2(0, 6)
	b.set_content_margin_all(18)
	return b

static func label(text: String, size: int = 16, col: Color = IVORY, bold: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Game.ui_bold if bold else Game.ui_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

static func title(text: String, size: int = 40, col: Color = IVORY, spacing: int = 6) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font(spacing))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.add_theme_constant_override("shadow_offset_x", 0)
	return l

static func para(text: String, size: int = 15, col: Color = MUTED) -> Label:
	var l := label(text, size, col, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = Game.ui_font
	t.default_font_size = 16
	t.set_color("font_color", "Label", IVORY)
	var track := StyleBoxFlat.new()
	track.bg_color = INK_3
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	t.set_stylebox("slider", "HSlider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = GOLD
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _knob(9, IVORY, GOLD_DEEP))
	t.set_icon("grabber_highlight", "HSlider", _knob(10, GOLD_LIGHT, GOLD_DEEP))
	t.set_stylebox("focus", "HSlider", StyleBoxEmpty.new())
	var tip := card(INK, GOLD_DEEP, 6)
	tip.set_content_margin_all(10)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", IVORY)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.05)
	sb.set_corner_radius_all(4)
	t.set_stylebox("scroll", "VScrollBar", sb)
	var grab := StyleBoxFlat.new()
	grab.bg_color = LINE
	grab.set_corner_radius_all(4)
	t.set_stylebox("grabber", "VScrollBar", grab)
	var grab2 := grab.duplicate() as StyleBoxFlat
	grab2.bg_color = GOLD_DEEP
	t.set_stylebox("grabber_highlight", "VScrollBar", grab2)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab2)
	return t

static func _knob(r: int, col: Color, rim: Color) -> ImageTexture:
	var d := r * 2 + 2
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(d, d) * 0.5)
			var c := rim if dist > float(r) - 2.0 else col
			c.a *= clampf(float(r) - dist + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

## Draws a keyboard key: a light cap with a dark lip.
static func keycap(ci: CanvasItem, centre: Vector2, key: String, size: int = 14) -> void:
	var w := maxf(Game.ui_bold.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 14.0, float(size) + 12.0)
	var h := float(size) + 12.0
	var r := Rect2(centre - Vector2(w, h) * 0.5, Vector2(w, h))
	ci.draw_rect(Rect2(r.position + Vector2(0, 3), r.size), Color("8c8577"))
	ci.draw_rect(r, IVORY)
	ci.draw_string(Game.ui_bold, Vector2(r.position.x, r.position.y + h * 0.5 + float(size) * 0.36), key,
		HORIZONTAL_ALIGNMENT_CENTER, w, size, INK)

## Text with a hard 2 px shadow (not a blur), centred on x if `width` > 0.
static func text(ci: CanvasItem, at: Vector2, s: String, size: int, col: Color, font: Font = null,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var f: Font = font if font != null else Game.ui_bold
	ci.draw_string(f, at + Vector2(0, 2), s, align, width, size, Color(0, 0, 0, 0.6 * col.a))
	ci.draw_string(f, at, s, align, width, size, col)
