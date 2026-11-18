class_name ItemCard
extends Control
## The card that follows the cursor over an item: name in its rarity's
## colour, what kind of thing it is, the numbers that matter, a line about
## it, and what clicking does. Draws itself; no children.

var item_id := ""
var hint := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	visible = false

func show_item(id: String, how: String) -> void:
	item_id = id
	hint = how
	visible = id != ""
	queue_redraw()

func _process(_delta: float) -> void:
	if visible:
		var m := get_viewport().get_mouse_position()
		var vp := get_viewport_rect().size
		position = Vector2(minf(m.x + 22, vp.x - 330), minf(m.y + 18, vp.y - 230))

func _lines() -> Array:
	var d := Run.item(item_id)
	var out := []
	match str(d.get("kind", "")):
		"weapon":
			out.append(["Damage", str(int(d.get("damage", 0)))])
			out.append(["Speed", "%.1f" % float(d.get("speed", 1.0))])
			out.append(["Stance", "%d%%" % int(Forge.posture_of(d) * 100.0)])
			if bool(d.get("two_handed", false)):
				out.append(["Grip", "Two hands"])
			if int(d.get("temper", 0)) > 0:
				out.append(["Tempered", "+%d of 5" % int(d["temper"])])
			if str(d.get("etch", "")) != "":
				out.append(["Etching", str(Forge.etchings()[str(d["etch"])]["name"])])
		"shield":
			out.append(["Stops", "%d%%" % int(float(d.get("block", 0.0)) * 100.0)])
			if d.has("thorns"):
				out.append(["Thorns", "%d%%" % int(float(d["thorns"]) * 100.0)])
		"consumable":
			out.append(["Heals", str(int(d.get("heal", 0)))])
	if int(d.get("price", 0)) > 0:
		out.append(["Worth", "%d silver" % int(int(d["price"]) / 3)])
	return out

func _draw() -> void:
	if item_id == "":
		return
	var d := Run.item(item_id)
	var col: Color = Kit.RARITY.get(str(d.get("rarity", "common")), Kit.IVORY)
	var lines := _lines()
	var w := 310.0
	var text := str(d.get("text", ""))
	var text_lines := ceili(Game.ui_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x / (w - 36.0))
	var h := 74.0 + lines.size() * 24.0 + text_lines * 19.0 + (26.0 if hint != "" else 0.0)
	draw_style_box(HUD.chip(Kit.INK, col.darkened(0.3)), Rect2(Vector2.ZERO, Vector2(w, h)))
	draw_rect(Rect2(Vector2(2, 2), Vector2(w - 4, 4)), col)
	Kit.text(self, Vector2(18, 34), str(d.get("name", item_id)), 19, col)
	Kit.text(self, Vector2(18, 54), "%s  ·  %s" % [str(d.get("rarity", "")).to_upper(), str(d.get("kind", "")).to_upper()],
		11, Kit.MUTED)
	var y := 82.0
	for l in lines:
		draw_string(Game.ui_font, Vector2(18, y), str(l[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Kit.MUTED)
		draw_string(Game.ui_bold, Vector2(18, y), str(l[1]), HORIZONTAL_ALIGNMENT_RIGHT, w - 36, 15, Kit.IVORY)
		y += 24.0
	draw_multiline_string(Game.ui_font, Vector2(18, y + 4), text, HORIZONTAL_ALIGNMENT_LEFT, w - 36, 14, -1,
		Color(Kit.IVORY, 0.75))
	if hint != "":
		draw_string(Game.ui_bold, Vector2(18, h - 14), hint, HORIZONTAL_ALIGNMENT_LEFT, w - 36, 12, Kit.GOLD)
