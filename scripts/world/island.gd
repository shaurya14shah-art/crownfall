class_name Island
extends RefCounted
## The island of Aldermere, as data: a 2 km height field at 2 m a sample, a
## paint map that says where the beaches, roads, forests and meadows are,
## the places that matter (village, harbour, castle, barrow) and the roads
## between them. Deterministic from the seed; built once on worker threads
## and then only read.
##
## Coordinates: x east, z south, metres; sea level is y = 0. The island is
## centred on the origin.

const SIZE := 2048.0
const RES := 1024
const CELL := SIZE / RES
const SEA_FLOOR := -30.0

## Places, hand-placed: position (x, z), flatten radius, ground height (NAN
## = keep the natural height at the centre).
const SITES := {
	"village": {"pos": Vector2(230, 250), "radius": 95.0, "height": 7.0, "name": "Brightwater"},
	"harbour": {"pos": Vector2(345, 455), "radius": 48.0, "height": 2.4, "name": "Brightwater Harbour"},
	"castle": {"pos": Vector2(-390, 40), "radius": 62.0, "height": 46.0, "name": "Highmoor Keep"},
	"barrow": {"pos": Vector2(-140, -330), "radius": 48.0, "height": NAN, "name": "The Barrow of Ash"},
	"tower": {"pos": Vector2(520, -140), "radius": 22.0, "height": NAN, "name": "Gull's Watch"},
	"crossroads": {"pos": Vector2(-20, 110), "radius": 18.0, "height": NAN, "name": "Old Crossroads"},
}

const ROADS := [
	["harbour", "village"],
	["village", "crossroads"],
	["crossroads", "castle"],
	["crossroads", "barrow"],
	["village", "tower"],
]

var seed_value := 0
var heights := PackedFloat32Array()
var paint: Image                      ## R sand, G road, B forest, A meadow
var road_paths: Array[PackedVector2Array] = []

var _warp := FastNoiseLite.new()
var _coast := FastNoiseLite.new()
var _hills := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _forest := FastNoiseLite.new()
var _meadow := FastNoiseLite.new()
var _rows: Array = []

func _init(s: int) -> void:
	seed_value = s
	_setup(_warp, s + 1, 0.0016, 3, FastNoiseLite.FRACTAL_FBM)
	_setup(_coast, s + 2, 0.0042, 4, FastNoiseLite.FRACTAL_FBM)
	_setup(_hills, s + 3, 0.0055, 5, FastNoiseLite.FRACTAL_FBM)
	_setup(_ridge, s + 4, 0.0038, 5, FastNoiseLite.FRACTAL_RIDGED)
	_setup(_detail, s + 5, 0.035, 2, FastNoiseLite.FRACTAL_FBM)
	_setup(_forest, s + 6, 0.0075, 3, FastNoiseLite.FRACTAL_FBM)
	_setup(_meadow, s + 7, 0.02, 2, FastNoiseLite.FRACTAL_FBM)

static func _setup(n: FastNoiseLite, s: int, f: float, oct: int, kind: int) -> void:
	n.seed = s
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = f
	n.fractal_type = kind
	n.fractal_octaves = oct

const CACHE_VERSION := 2

## The island for a seed: read from the cache if it was built before (well
## under a second), otherwise generated (several seconds) and cached.
static func load_or_generate(s: int) -> Island:
	var isl := Island.new(s)
	var path := "user://island_%d_v%d.bin" % [s, CACHE_VERSION]
	var f := FileAccess.open(path, FileAccess.READ)
	if f != null:
		var hb := f.get_buffer(f.get_32())
		var pb := f.get_buffer(f.get_32())
		var roads: Variant = f.get_var()
		f.close()
		if hb.size() == RES * RES * 4 and pb.size() == RES * RES * 4 and roads is Array:
			isl.heights = hb.to_float32_array()
			isl.paint = Image.create_from_data(RES, RES, false, Image.FORMAT_RGBA8, pb)
			for r in roads:
				isl.road_paths.append(r as PackedVector2Array)
			return isl
	isl.generate()
	var w := FileAccess.open(path, FileAccess.WRITE)
	if w != null:
		var hb2 := isl.heights.to_byte_array()
		w.store_32(hb2.size())
		w.store_buffer(hb2)
		var pb2 := isl.paint.get_data()
		w.store_32(pb2.size())
		w.store_buffer(pb2)
		w.store_var(isl.road_paths.duplicate())
		w.close()
	return isl

## Builds everything. Takes several seconds; call from a loading screen.
func generate() -> void:
	_rows.resize(RES)
	var task := WorkerThreadPool.add_group_task(_height_row, RES, -1, true, "island heights")
	WorkerThreadPool.wait_for_group_task_completion(task)
	heights.resize(RES * RES)
	for j in RES:
		var row: PackedFloat32Array = _rows[j]
		for i in RES:
			heights[j * RES + i] = row[i]
	_flatten_sites()
	_lay_roads()
	paint = Image.create(RES, RES, false, Image.FORMAT_RGBA8)
	var task2 := WorkerThreadPool.add_group_task(_paint_row, RES, -1, true, "island paint")
	WorkerThreadPool.wait_for_group_task_completion(task2)
	for j in RES:
		var row: PackedByteArray = _rows[j]
		for i in RES:
			paint.set_pixel(i, j, Color8(row[i * 4], row[i * 4 + 1], row[i * 4 + 2], row[i * 4 + 3]))
	_rows.clear()

# --- Shape --------------------------------------------------------------------

func _height_row(j: int) -> void:
	var row := PackedFloat32Array()
	row.resize(RES)
	var z := -SIZE * 0.5 + (float(j) + 0.5) * CELL
	for i in RES:
		var x := -SIZE * 0.5 + (float(i) + 0.5) * CELL
		row[i] = natural_height(x, z)
	_rows[j] = row

## The island before people: coast, beaches, hills and the northern range.
func natural_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var w := Vector2(_warp.get_noise_2d(x, z), _warp.get_noise_2d(x + 517.0, z - 211.0)) * 140.0
	var q := (p + w) / Vector2(830.0, 720.0)
	var r := q.length() + _coast.get_noise_2d(x, z) * 0.16
	# The harbour bay bites into the south-east coast.
	var bay := p.distance_to(Vector2(420, 610))
	r += clampf(1.0 - bay / 210.0, 0.0, 1.0) * 0.32
	var land := 1.0 - smoothstep(0.70, 1.02, r)          # 0 sea .. 1 inland
	var h := lerpf(SEA_FLOOR, 1.1, smoothstep(0.0, 0.16, land))
	var hills := _hills.get_noise_2d(x, z) * 0.5 + 0.5
	h += smoothstep(0.18, 0.62, land) * (5.0 + hills * hills * 34.0)
	# The northern range: ridged, rising toward a peak.
	var peak := p.distance_to(Vector2(60, -540))
	var range_mask := clampf(1.0 - peak / 520.0, 0.0, 1.0)
	range_mask = range_mask * range_mask * (3.0 - 2.0 * range_mask)
	var ridged := _ridge.get_noise_2d(x, z) * 0.5 + 0.5
	h += range_mask * land * (ridged * ridged * 190.0 + range_mask * 60.0)
	h += _detail.get_noise_2d(x, z) * 0.7 * land
	return h

func _flatten_sites() -> void:
	for id in SITES.keys():
		var s: Dictionary = SITES[id]
		var c: Vector2 = s["pos"]
		var radius: float = s["radius"]
		var target: float = s["height"]
		if is_nan(target):
			target = height_at(c.x, c.y)
		var reach := radius * 1.9
		_each_cell_near(c, reach, func(idx: int, d: float) -> void:
			var k := smoothstep(reach, radius * 0.75, d)
			heights[idx] = lerpf(heights[idx], target, k))

## Roads: a winding line between two places, then the ground along it eased
## toward a smoothed version of itself, so a road climbs a hill instead of
## going over every bump.
func _lay_roads() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 99
	for pair in ROADS:
		var a: Vector2 = SITES[pair[0]]["pos"]
		var b: Vector2 = SITES[pair[1]]["pos"]
		var path := PackedVector2Array()
		var steps := int(a.distance_to(b) / 6.0)
		var side := (b - a).normalized().orthogonal()
		var wiggle := rng.randf_range(0.0, 100.0)
		for k in steps + 1:
			var t := float(k) / float(steps)
			var bend := sin(t * PI) * (_warp.get_noise_1d(wiggle + t * 3.0) * 90.0)
			path.append(a.lerp(b, t) + side * bend)
		road_paths.append(path)
		# Smoothed heights along it.
		var hs := PackedFloat32Array()
		for pt in path:
			hs.append(maxf(height_at(pt.x, pt.y), 1.6))
		var smooth := PackedFloat32Array()
		smooth.resize(hs.size())
		for k in hs.size():
			var sum := 0.0
			var n := 0
			for o in range(-6, 7):
				var kk := clampi(k + o, 0, hs.size() - 1)
				sum += hs[kk]
				n += 1
			smooth[k] = sum / float(n)
		for k in path.size() - 1:
			var p0 := path[k]
			var p1 := path[k + 1]
			var h0 := smooth[k]
			var h1 := smooth[k + 1]
			_each_cell_near((p0 + p1) * 0.5, 14.0, func(idx: int, _d: float) -> void:
				var cp := _cell_pos(idx)
				var t := clampf((cp - p0).dot(p1 - p0) / maxf((p1 - p0).length_squared(), 0.001), 0.0, 1.0)
				var dist := cp.distance_to(p0.lerp(p1, t))
				var k2 := smoothstep(9.0, 3.5, dist)
				if k2 > 0.0:
					heights[idx] = lerpf(heights[idx], lerpf(h0, h1, t), k2))

func _cell_pos(idx: int) -> Vector2:
	return Vector2(-SIZE * 0.5 + (float(idx % RES) + 0.5) * CELL, -SIZE * 0.5 + (float(idx / RES) + 0.5) * CELL)

func _each_cell_near(c: Vector2, reach: float, f: Callable) -> void:
	var i0 := maxi(0, int((c.x - reach + SIZE * 0.5) / CELL))
	var i1 := mini(RES - 1, int((c.x + reach + SIZE * 0.5) / CELL))
	var j0 := maxi(0, int((c.y - reach + SIZE * 0.5) / CELL))
	var j1 := mini(RES - 1, int((c.y + reach + SIZE * 0.5) / CELL))
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var idx := j * RES + i
			var d := _cell_pos(idx).distance_to(c)
			if d <= reach:
				f.call(idx, d)

# --- Paint --------------------------------------------------------------------

func _paint_row(j: int) -> void:
	var row := PackedByteArray()
	row.resize(RES * 4)
	var z := -SIZE * 0.5 + (float(j) + 0.5) * CELL
	for i in RES:
		var x := -SIZE * 0.5 + (float(i) + 0.5) * CELL
		var h := heights[j * RES + i]
		var slope := 1.0 - normal_at(x, z).y
		var sand := clampf(1.0 - (h - 1.2) / 1.6, 0.0, 1.0) * clampf(1.0 - slope * 3.0, 0.0, 1.0)
		var road := road_weight(x, z)
		var f := _forest.get_noise_2d(x, z) * 0.5 + 0.5
		var forest := smoothstep(0.44, 0.60, f) * smoothstep(3.0, 8.0, h) * smoothstep(170.0, 120.0, h)
		forest *= 1.0 - _site_weight(x, z, 1.4)
		var meadow := _meadow.get_noise_2d(x, z) * 0.5 + 0.5
		row[i * 4] = int(sand * 255.0)
		row[i * 4 + 1] = int(road * 255.0)
		row[i * 4 + 2] = int(forest * 255.0)
		row[i * 4 + 3] = int(meadow * 255.0)
	_rows[j] = row

## 1 on a road's crown, fading to 0 at its edge.
func road_weight(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var best := 1e9
	for path in road_paths:
		# Cheap reject on the path's rough bounds.
		var a := path[0]
		var b := path[path.size() - 1]
		var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(120, 120)
		var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(120, 120)
		if p.x < lo.x or p.y < lo.y or p.x > hi.x or p.y > hi.y:
			continue
		for k in path.size() - 1:
			var p0 := path[k]
			var p1 := path[k + 1]
			if absf(p.x - p0.x) > 12.0 or absf(p.y - p0.y) > 12.0:
				continue
			var t := clampf((p - p0).dot(p1 - p0) / maxf((p1 - p0).length_squared(), 0.001), 0.0, 1.0)
			best = minf(best, p.distance_to(p0.lerp(p1, t)))
	return smoothstep(3.6, 1.8, best)

## How much a point is inside one of the places (1 at the heart).
func _site_weight(x: float, z: float, scale: float = 1.0) -> float:
	var w := 0.0
	for id in SITES.keys():
		var s: Dictionary = SITES[id]
		var d := Vector2(x, z).distance_to(s["pos"])
		w = maxf(w, smoothstep(float(s["radius"]) * scale, float(s["radius"]) * scale * 0.6, d))
	return w

# --- Queries ------------------------------------------------------------------

func height_at(x: float, z: float) -> float:
	var fx := (x + SIZE * 0.5) / CELL - 0.5
	var fz := (z + SIZE * 0.5) / CELL - 0.5
	var i := clampi(int(floor(fx)), 0, RES - 2)
	var j := clampi(int(floor(fz)), 0, RES - 2)
	var tx := clampf(fx - float(i), 0.0, 1.0)
	var tz := clampf(fz - float(j), 0.0, 1.0)
	var h00 := heights[j * RES + i]
	var h10 := heights[j * RES + i + 1]
	var h01 := heights[(j + 1) * RES + i]
	var h11 := heights[(j + 1) * RES + i + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)

func normal_at(x: float, z: float) -> Vector3:
	var e := CELL
	var dx := height_at(x + e, z) - height_at(x - e, z)
	var dz := height_at(x, z + e) - height_at(x, z - e)
	return Vector3(-dx, 2.0 * e, -dz).normalized()

## Paint channels at a point: x sand, y road, z forest, w meadow (0..1).
func paint_at(x: float, z: float) -> Vector4:
	var i := clampi(int((x + SIZE * 0.5) / CELL), 0, RES - 1)
	var j := clampi(int((z + SIZE * 0.5) / CELL), 0, RES - 1)
	var c := paint.get_pixel(i, j)
	return Vector4(c.r, c.g, c.b, c.a)

## Paints road into the map along a line (for village lanes); `width` in
## metres. Call `paint_changed` users to re-upload afterwards.
func paint_road(a: Vector2, b: Vector2, width: float) -> void:
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2.ONE * width
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2.ONE * width
	var i0 := clampi(int((lo.x + SIZE * 0.5) / CELL), 0, RES - 1)
	var i1 := clampi(int((hi.x + SIZE * 0.5) / CELL), 0, RES - 1)
	var j0 := clampi(int((lo.y + SIZE * 0.5) / CELL), 0, RES - 1)
	var j1 := clampi(int((hi.y + SIZE * 0.5) / CELL), 0, RES - 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			var p := _cell_pos(j * RES + i)
			var t := clampf((p - a).dot(b - a) / maxf((b - a).length_squared(), 0.001), 0.0, 1.0)
			var d := p.distance_to(a.lerp(b, t))
			var w := smoothstep(width * 0.5 + 1.2, width * 0.5 - 0.6, d)
			if w > 0.0:
				var c := paint.get_pixel(i, j)
				c.g = maxf(c.g, w)
				c.b = c.b * (1.0 - w)
				paint.set_pixel(i, j, c)

func site_pos(id: String) -> Vector3:
	var p: Vector2 = SITES[id]["pos"]
	return Vector3(p.x, height_at(p.x, p.y), p.y)

func is_land(x: float, z: float) -> bool:
	return height_at(x, z) > 0.4
