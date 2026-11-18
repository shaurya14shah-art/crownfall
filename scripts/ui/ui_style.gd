class_name UIStyle
extends RefCounted
## The interface's look in one place. Cinzel (engraved capitals) for names
## and titles, Inter for everything you read; warm ivory text, aged gold for
## the accents and for what is selected; deep blue-black glass behind
## anything that needs a backing. Built in code so there is exactly one
## definition of it.

const IVORY := Color(0.96, 0.93, 0.86)
const IVORY_DIM := Color(0.80, 0.77, 0.70, 0.85)
const GOLD := Color(0.93, 0.76, 0.42)
const GOLD_BRIGHT := Color(1.0, 0.88, 0.58)
const GOLD_DEEP := Color(0.62, 0.46, 0.20)
const INK := Color(0.035, 0.045, 0.065)
const GLASS := Color(0.035, 0.045, 0.065, 0.72)
const HEALTH := Color(0.80, 0.16, 0.14)
const HEALTH_HI := Color(1.0, 0.42, 0.34)
const STAMINA := Color(0.88, 0.72, 0.30)

static func title(text: String, size: int = 64, col: Color = IVORY, spacing: int = 6) -> Label:
	var l := Label.new()
	l.text = text
	var f := FontVariation.new()
	f.base_font = Game.title_font
	f.spacing_glyph = spacing
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	shadow(l, 3)
	return l

static func text(s: String, size: int = 16, col: Color = IVORY, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", Game.ui_bold if bold else Game.ui_font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

static func shadow(l: Label, blur: int = 2) -> Label:
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", blur)
	return l

static func glass(radius: int = 6, fill: Color = GLASS, edge: Color = Color(GOLD, 0.35)) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = edge
	b.set_border_width_all(1)
	b.set_corner_radius_all(radius)
	b.corner_detail = 8
	b.anti_aliasing = true
	b.set_content_margin_all(18)
	b.shadow_color = Color(0, 0, 0, 0.35)
	b.shadow_size = 18
	return b

## A thin ornamental rule with a diamond in the middle: ——◆——
static func rule(width: float = 260.0, col: Color = GOLD) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(width, 14)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var mid := c.size * 0.5
		var w := c.size.x * 0.5
		c.draw_line(Vector2(mid.x - w, mid.y), Vector2(mid.x - 9, mid.y), Color(col, 0.0), 1.0)
		for k in 12:
			var t0 := float(k) / 12.0
			var t1 := float(k + 1) / 12.0
			var a := Vector2(mid.x - w + (w - 9.0) * t0, mid.y)
			var b := Vector2(mid.x - w + (w - 9.0) * t1, mid.y)
			c.draw_line(a, b, Color(col, t1 * 0.8), 1.0, true)
			c.draw_line(Vector2(c.size.x - a.x, mid.y), Vector2(c.size.x - b.x, mid.y), Color(col, t1 * 0.8), 1.0, true)
		c.draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -4.5), mid + Vector2(4.5, 0),
			mid + Vector2(0, 4.5), mid + Vector2(-4.5, 0)]), col))
	return c

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = Game.ui_font
	t.default_font_size = 16
	t.set_color("font_color", "Label", IVORY)
	t.set_stylebox("panel", "PanelContainer", glass())
	# Sliders: hairline track, gold fill, ivory knob.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.15)
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	t.set_stylebox("slider", "HSlider", track)
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = GOLD
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _dot(7, IVORY))
	t.set_icon("grabber_highlight", "HSlider", _dot(8, GOLD_BRIGHT))
	t.set_stylebox("focus", "HSlider", StyleBoxEmpty.new())
	return t

static func _dot(r: int, col: Color) -> ImageTexture:
	var d := r * 2 + 2
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(d, d) * 0.5)
			var c := col
			c.a *= clampf(float(r) - dist + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
