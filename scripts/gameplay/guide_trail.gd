class_name GuideTrail
extends Node3D
## Press T: a stream of golden wisps runs out along the ground from your
## feet toward where your quest wants you, following the roads when a road
## goes that way, and fades after a few seconds. A way to find the way
## without a line painted on the world.

const WISPS := 70
const LIFE := 6.0
const SPACING := 3.0

var path := PackedVector3Array()
var _t := 0.0
var _mm: MultiMesh

## A path from `from` to `to`: along the nearest road if it heads the right
## way, straight otherwise; every point lifted to the ground.
static func plan(isl: Island, from: Vector3, to: Vector3) -> PackedVector3Array:
	var pts: Array[Vector2] = [Vector2(from.x, from.z)]
	var goal := Vector2(to.x, to.z)
	var best_gain := 0.0
	var best_route: Array[Vector2] = []
	for road in isl.road_paths:
		# Nearest point on this road to us, and to the goal.
		var ia := 0
		var ib := 0
		var da := 1e9
		var db := 1e9
		for k in road.size():
			var d1 := road[k].distance_to(pts[0])
			var d2 := road[k].distance_to(goal)
			if d1 < da:
				da = d1
				ia = k
			if d2 < db:
				db = d2
				ib = k
		if da > 60.0:
			continue
		var straight := pts[0].distance_to(goal)
		var via := da + road[ia].distance_to(road[ib]) * 0.9 + db
		var gain := straight - db - da
		if db < straight * 0.6 and gain > best_gain and via < straight * 1.6:
			best_gain = gain
			best_route = []
			var step := 1 if ib >= ia else -1
			var k := ia
			while true:
				best_route.append(road[k])
				if k == ib:
					break
				k += step
	pts.append_array(best_route)
	pts.append(goal)
	# Resample to even spacing and lift onto the ground.
	var out := PackedVector3Array()
	var carry := 0.0
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var t := carry
		while t < seg:
			var p := a.lerp(b, t / maxf(seg, 0.001))
			out.append(Vector3(p.x, isl.height_at(p.x, p.y) + 0.6, p.y))
			t += SPACING
		carry = t - seg
		if out.size() > 220:
			break
	return out

func _ready() -> void:
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2(1.3, 1.3)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _dot()
	q.material = m
	_mm.mesh = q
	_mm.instance_count = WISPS
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.extra_cull_margin = 4000.0
	add_child(mmi)

static func _dot() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(16, 16)) / 16.0
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)

func _process(delta: float) -> void:
	_t += delta
	if path.size() < 2 or _t > LIFE:
		queue_free()
		return
	var fade := 1.0 - smoothstep(LIFE - 1.0, LIFE, _t)
	var head := _t * 22.0 / SPACING          # how far along the path the stream has run, in points
	for i in WISPS:
		# Wisps flow along the path behind a moving head, in a loose ribbon.
		var along := fmod(head - float(i) * 1.1, float(path.size()) + 30.0)
		var k := clampi(int(along), 0, path.size() - 1)
		var k2 := clampi(k + 1, 0, path.size() - 1)
		var p := path[k].lerp(path[k2], along - float(k))
		p.y += sin(_t * 3.0 + float(i)) * 0.25
		var shown := along >= 0.0 and along < float(path.size())
		var s := 0.0 if not shown else (0.7 + 0.3 * sin(_t * 6.0 + float(i) * 1.7))
		_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * maxf(s, 0.001)), p))
		_mm.set_instance_color(i, Color(1.6, 1.2, 0.5, fade * (1.0 if shown else 0.0)))
