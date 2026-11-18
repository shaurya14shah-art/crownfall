class_name Glyphs
extends RefCounted
## Bold little vector icons for tabs, skills and notices: drawn, not
## textured, so they stay sharp at any size and take any colour.

static func draw(ci: CanvasItem, kind: String, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(2.0, s * 0.12)
	match kind:
		"sword":
			ci.draw_line(c + Vector2(-0.38, 0.38) * s, c + Vector2(0.4, -0.4) * s, col, w * 1.3, true)
			ci.draw_line(c + Vector2(-0.4, 0.12) * s, c + Vector2(-0.12, 0.4) * s, col, w, true)
			ci.draw_line(c + Vector2(-0.46, 0.46) * s, c + Vector2(-0.34, 0.34) * s, col, w * 1.6, true)
		"shield":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.38, -0.4) * s, c + Vector2(0.38, -0.4) * s,
				c + Vector2(0.38, 0.0) * s, c + Vector2(0.0, 0.45) * s, c + Vector2(-0.38, 0.0) * s]), col)
			ci.draw_line(c + Vector2(0, -0.32) * s, c + Vector2(0, 0.3) * s, Color(0, 0, 0, 0.35), w, true)
		"boot":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.25, -0.42) * s, c + Vector2(0.08, -0.42) * s,
				c + Vector2(0.08, 0.1) * s, c + Vector2(0.42, 0.2) * s, c + Vector2(0.42, 0.4) * s,
				c + Vector2(-0.25, 0.4) * s]), col)
		"heart":
			ci.draw_circle(c + Vector2(-0.18, -0.1) * s, 0.22 * s, col, true, -1.0, true)
			ci.draw_circle(c + Vector2(0.18, -0.1) * s, 0.22 * s, col, true, -1.0, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.4, -0.02) * s, c + Vector2(0.4, -0.02) * s,
				c + Vector2(0, 0.42) * s]), col)
		"sigil":
			ci.draw_arc(c, 0.38 * s, 0, TAU, 32, col, w, true)
			var pts := PackedVector2Array()
			for k in 3:
				var a := -PI * 0.5 + TAU * float(k) / 3.0
				pts.append(c + Vector2(cos(a), sin(a)) * 0.3 * s)
			pts.append(pts[0])
			ci.draw_polyline(pts, col, w, true)
			ci.draw_circle(c, 0.07 * s, col, true, -1.0, true)
		"bag":
			ci.draw_circle(c + Vector2(0, 0.1) * s, 0.34 * s, col, true, -1.0, true)
			ci.draw_rect(Rect2(c + Vector2(-0.14, -0.42) * s, Vector2(0.28, 0.22) * s), col)
			ci.draw_line(c + Vector2(-0.2, -0.2) * s, c + Vector2(0.2, -0.2) * s, Color(0, 0, 0, 0.4), w, true)
		"map":
			var p := PackedVector2Array([c + Vector2(-0.42, -0.32) * s, c + Vector2(-0.14, -0.42) * s,
				c + Vector2(0.14, -0.32) * s, c + Vector2(0.42, -0.42) * s, c + Vector2(0.42, 0.32) * s,
				c + Vector2(0.14, 0.42) * s, c + Vector2(-0.14, 0.32) * s, c + Vector2(-0.42, 0.42) * s])
			ci.draw_colored_polygon(p, col)
			ci.draw_line(c + Vector2(-0.14, -0.42) * s, c + Vector2(-0.14, 0.32) * s, Color(0, 0, 0, 0.35), w * 0.7)
			ci.draw_line(c + Vector2(0.14, -0.32) * s, c + Vector2(0.14, 0.42) * s, Color(0, 0, 0, 0.35), w * 0.7)
		"scroll":
			ci.draw_rect(Rect2(c + Vector2(-0.3, -0.38) * s, Vector2(0.6, 0.76) * s), col)
			for k in 3:
				ci.draw_line(c + Vector2(-0.18, -0.18 + 0.16 * k) * s, c + Vector2(0.18, -0.18 + 0.16 * k) * s,
					Color(0, 0, 0, 0.4), w * 0.7)
		"star":
			var st := PackedVector2Array()
			for k in 10:
				var a := -PI * 0.5 + TAU * float(k) / 10.0
				st.append(c + Vector2(cos(a), sin(a)) * (0.44 if k % 2 == 0 else 0.2) * s)
			ci.draw_colored_polygon(st, col)
		"skull":
			ci.draw_circle(c + Vector2(0, -0.06) * s, 0.34 * s, col, true, -1.0, true)
			ci.draw_rect(Rect2(c + Vector2(-0.2, 0.18) * s, Vector2(0.4, 0.22) * s), col)
			ci.draw_circle(c + Vector2(-0.13, -0.06) * s, 0.09 * s, Color(0, 0, 0, 0.75), true, -1.0, true)
			ci.draw_circle(c + Vector2(0.13, -0.06) * s, 0.09 * s, Color(0, 0, 0, 0.75), true, -1.0, true)
		"coin":
			ci.draw_circle(c, 0.38 * s, col.darkened(0.3), true, -1.0, true)
			ci.draw_circle(c, 0.3 * s, col, true, -1.0, true)
		"pin":
			ci.draw_circle(c + Vector2(0, -0.12) * s, 0.26 * s, col, true, -1.0, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.22, 0.0) * s, c + Vector2(0.22, 0.0) * s,
				c + Vector2(0, 0.44) * s]), col)
		"person":
			ci.draw_circle(c + Vector2(0, -0.2) * s, 0.18 * s, col, true, -1.0, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.34, 0.42) * s, c + Vector2(-0.24, 0.05) * s,
				c + Vector2(0.24, 0.05) * s, c + Vector2(0.34, 0.42) * s]), col)
		"lock":
			ci.draw_arc(c + Vector2(0, -0.08) * s, 0.2 * s, PI, TAU, 12, col, w, true)
			ci.draw_rect(Rect2(c + Vector2(-0.28, -0.08) * s, Vector2(0.56, 0.46) * s), col)
		"check":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.32, 0.0) * s, c + Vector2(-0.08, 0.26) * s,
				c + Vector2(0.36, -0.26) * s]), col, w * 1.4, true)
		"gear":
			ci.draw_circle(c, 0.28 * s, col, true, -1.0, true)
			for k in 8:
				var a := TAU * float(k) / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * 0.24 * s, c + Vector2(cos(a), sin(a)) * 0.42 * s, col, w * 1.6)
			ci.draw_circle(c, 0.11 * s, Color(0, 0, 0, 0.6), true, -1.0, true)
		_:
			ci.draw_circle(c, 0.2 * s, col, true, -1.0, true)
