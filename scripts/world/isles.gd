class_name Isles
extends Node3D
## The islands out at sea, beyond Aldermere's shore: small worlds of their
## own, reached by ship. Each is a dome of land with a beach round it,
## shaped by one height function (used for its mesh, its collision, the
## ship's keel and the swimmer's footing), with palms and rocks from the
## pirate kit, a Waystone at its landing, a camp of the Drowned, and places
## where something is buried.
##
##   Skull Key     a corsair camp under a watchtower
##   Wreck Shoals  a sandbar with a galleon's bones on it
##   Sable Isle    a high green island with a ruined fort on top

## id -> name, bearing from the centre (unit vector), distance, radius, peak height
const ISLES := {
	"skull_key": {"name": "Skull Key", "dir": Vector2(0.84, 0.54), "dist": 860.0, "r": 72.0, "peak": 13.0, "seed": 11},
	"wreck_shoals": {"name": "Wreck Shoals", "dir": Vector2(0.1, 1.0), "dist": 900.0, "r": 50.0, "peak": 6.0, "seed": 23},
	"sable_isle": {"name": "Sable Isle", "dir": Vector2(0.95, -0.33), "dist": 880.0, "r": 88.0, "peak": 26.0, "seed": 37},
}
## Where each isle actually is, after being pushed clear of Aldermere's shelf.
static var centres := {}
static var _noise: FastNoiseLite

var world: World

## Finds a clear patch of sea for each isle, along its bearing.
static func place(isl: Island) -> void:
	centres.clear()
	for id in ISLES.keys():
		var d: Dictionary = ISLES[id]
		var dir: Vector2 = (d["dir"] as Vector2).normalized()
		var dist := float(d["dist"])
		var r := float(d["r"])
		for k in 60:
			var c := dir * dist
			var clear := true
			for s in 16:
				var p := c + Vector2(cos(TAU * s / 16.0), sin(TAU * s / 16.0)) * (r * 1.35)
				if isl.height_at(p.x, p.y) > -6.0:
					clear = false
					break
			if clear and isl.height_at(c.x, c.y) < -6.0:
				break
			dist += 25.0
		centres[id] = dir * dist

## The ground of any isle under (x, z), or -INF where there is only sea.
static func height_at(x: float, z: float) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 404
		_noise.frequency = 0.035
	var best := -INF
	for id in centres.keys():
		var c: Vector2 = centres[id]
		var d: Dictionary = ISLES[id]
		var r := float(d["r"])
		var t := Vector2(x, z).distance_to(c) / r
		if t > 1.3:
			continue
		var h := lerpf(-7.0, float(d["peak"]), smoothstep(1.15, 0.5, t))
		h += _noise.get_noise_2d(x, z) * 2.2 * clampf(1.0 - t, 0.0, 1.0)
		best = maxf(best, h)
	return best

static func centre(id: String) -> Vector3:
	var c: Vector2 = centres.get(id, Vector2.ZERO)
	return Vector3(c.x, 0.0, c.y)

## The isle you are on or near, or "".
static func isle_at(x: float, z: float, slack: float = 1.0) -> String:
	for id in centres.keys():
		if Vector2(x, z).distance_to(centres[id]) < float(ISLES[id]["r"]) * slack:
			return id
	return ""

## A point on an isle at `frac` of its radius, toward `angle`, on its ground.
static func spot(id: String, angle: float, frac: float) -> Vector3:
	var c: Vector2 = centres[id]
	var p := c + Vector2(cos(angle), sin(angle)) * float(ISLES[id]["r"]) * frac
	return Vector3(p.x, height_at(p.x, p.y), p.y)

## The beach on the side facing Aldermere, where a ship can come in.
static func landing(id: String) -> Vector3:
	var c: Vector2 = centres[id]
	var a := (-c).angle()
	for k in 30:
		var p := spot(id, a, 0.95 - k * 0.02)
		if p.y > 0.6:
			return p
	return spot(id, a, 0.7)

## Deep water off the landing, where a ship rides at anchor.
static func mooring(id: String) -> Vector3:
	var c: Vector2 = centres[id]
	var a := (-c).angle()
	return Vector3(c.x, 0, c.y) + Vector3(cos(a), 0, sin(a)) * float(ISLES[id]["r"]) * 1.5

# --- Building -----------------------------------------------------------------------------------

func build(w: World) -> void:
	world = w
	place(w.island)
	for id in ISLES.keys():
		_land(id)
		_dress(id)
	print("[Isles] %s" % str(centres))

func _land(id: String) -> void:
	var c: Vector2 = centres[id]
	var r := float(ISLES[id]["r"])
	var half := r * 1.25
	var step := 2.0
	var n := int(half * 2.0 / step) + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ISLES[id]["seed"])
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for j in n:
		for i in n:
			var x := c.x - half + i * step
			var z := c.y - half + j * step
			hs[j * n + i] = height_at(x, z)
	var col := func(h: float, slope: float, x: float, z: float) -> Color:
		var v := 0.92 + 0.08 * sin(x * 0.7 + z * 0.4)
		if h < -0.4:
			return Color(0.62, 0.56, 0.4) * v
		if slope < 0.72:
			return Color(0.52, 0.49, 0.45) * v
		if h < 1.7:
			return Color(0.9, 0.81, 0.58) * v
		return Color(0.4, 0.6, 0.27).lerp(Color(0.5, 0.66, 0.3), 0.5 + 0.5 * sin(x * 0.13 + z * 0.09)) * v
	for j in n - 1:
		for i in n - 1:
			var quad := [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]
			var pts: Array[Vector3] = []
			for q in quad:
				pts.append(Vector3(c.x - half + q[0] * step, hs[q[1] * n + q[0]], c.y - half + q[1] * step))
			if pts[0].y < -6.5 and pts[1].y < -6.5 and pts[2].y < -6.5 and pts[3].y < -6.5:
				continue
			for tri in [[0, 2, 1], [0, 3, 2]]:
				var a := pts[tri[0]]
				var b := pts[tri[1]]
				var cc := pts[tri[2]]
				var nrm := (b - a).cross(cc - a).normalized()
				if nrm.y < 0.0:
					nrm = -nrm
				var mid := (a + b + cc) / 3.0
				st.set_color(col.call(mid.y, nrm.y, mid.x, mid.z))
				st.set_normal(nrm)
				st.add_vertex(a)
				st.set_normal(nrm)
				st.add_vertex(b)
				st.set_normal(nrm)
				st.add_vertex(cc)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mi.material_override = m
	add_child(mi)
	# Collision: a height field at a metre a cell.
	var hn := int(half * 2.0) + 1
	var data := PackedFloat32Array()
	data.resize(hn * hn)
	for j in hn:
		for i in hn:
			data[j * hn + i] = maxf(height_at(c.x - half + i, c.y - half + j), -10.0)
	var shape := HeightMapShape3D.new()
	shape.map_width = hn
	shape.map_depth = hn
	shape.map_data = data
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	body.global_position = Vector3(c.x - half + (hn - 1) * 0.5, 0, c.y - half + (hn - 1) * 0.5)

func _prop(path: String, at: Vector3, sc: float, yaw: float) -> Node3D:
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	n.scale = Vector3.ONE * sc
	add_child(n)
	n.global_position = at
	n.rotation.y = yaw
	return n

func _dress(id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ISLES[id]["seed"]) * 7
	var palms := ["palm-bend", "palm-straight", "palm-detailed-bend", "palm-detailed-straight"]
	var count := int(float(ISLES[id]["r"]) * 0.32)
	for k in count:
		var p := spot(id, rng.randf() * TAU, rng.randf_range(0.2, 0.85))
		if p.y > 0.8:
			_prop("res://assets/ships/%s.glb" % palms[rng.randi() % palms.size()], p, rng.randf_range(1.9, 2.6),
				rng.randf() * TAU)
	for k in int(count * 0.6):
		var p := spot(id, rng.randf() * TAU, rng.randf_range(0.6, 1.0))
		if p.y > -0.5:
			_prop("res://assets/ships/%s.glb" % ["rocks-sand-a", "rocks-sand-b", "rocks-sand-c", "rocks-a"][rng.randi() % 4],
				p + Vector3.DOWN * 0.2, rng.randf_range(1.6, 2.8), rng.randf() * TAU)
	for k in int(count * 0.8):
		var p := spot(id, rng.randf() * TAU, rng.randf_range(0.1, 0.8))
		if p.y > 1.8:
			_prop("res://assets/ships/%s.glb" % ["patch-grass-foliage", "grass-plant", "patch-grass"][rng.randi() % 3],
				p, rng.randf_range(1.6, 2.4), rng.randf() * TAU)
	var land := landing(id)
	var face := atan2(-land.x, -land.z)
	match id:
		"skull_key":
			var camp := spot(id, (-centres[id]).angle() + 0.6, 0.35)
			_prop("res://assets/ships/tower-watch.glb", camp + Vector3(6, 0, -4), 2.4, 0.3)
			_prop("res://assets/ships/flag-pirate-high.glb", camp + Vector3(-4, 0, 3), 2.4, 1.0)
			_prop("res://assets/ships/structure.glb", camp + Vector3(-7, 0, -6), 2.4, 0.8)
			for k in 6:
				_prop("res://assets/ships/%s.glb" % ["barrel", "crate", "crate-bottles"][k % 3],
					camp + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5)), 2.0, rng.randf() * TAU)
			_fire(camp)
			_crew(id, camp, 5)
		"wreck_shoals":
			var wreck := spot(id, (-centres[id]).angle() + PI, 0.55)
			_prop("res://assets/ships/ship-wreck.glb", wreck + Vector3.DOWN * 0.6, 1.7, 0.9)
			_prop("res://assets/ships/flag-pirate-pennant.glb", wreck + Vector3(5, 0, 3), 2.0, 0.3)
			_crew(id, spot(id, 0.0, 0.2), 4)
		"sable_isle":
			var top := spot(id, 0.0, 0.0)
			_prop("res://assets/ships/tower-complete-small.glb", top + Vector3(4, -0.5, 2), 2.6, 0.2)
			_prop("res://assets/ships/flag-high.glb", top + Vector3(-5, 0, -3), 2.4, 0.0)
			for k in 4:
				_prop("res://assets/ships/cannon.glb", spot(id, k * 1.4, 0.18) + Vector3.DOWN * 0.1, 2.0, k * 1.4)
			_fire(top + Vector3(-2, 0, 5))
			_crew(id, top, 5)
	# A Waystone at the landing, a little inland.
	var ws := Waystone.new()
	ws.id = "isle_" + id
	ws.title = "%s Landing" % str(ISLES[id]["name"])
	ws.mooring = mooring(id)
	var inland := spot(id, (-centres[id]).angle(), 0.6)
	add_child(ws)
	ws.global_position = inland
	ws.rotation.y = face

## A cooking fire: a light that flickers and a few sparks.
func _fire(at: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.light_energy = 2.0
	l.omni_range = 9.0
	add_child(l)
	l.global_position = at + Vector3.UP * 1.0
	l.add_to_group("fires")
	_prop("res://assets/dungeon/torch_lit.glb", at, 1.4, 0.0)

func _crew(id: String, at: Vector3, n: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(ISLES[id]["seed"]) * 13
	for k in n:
		var sk := Skeleton.new()
		sk.kind = "corsair" if k % 3 != 2 else "warrior"
		sk.camp = id
		var p := at + Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8))
		p.y = maxf(height_at(p.x, p.z), 0.5) + 0.4
		sk.home = p
		add_child(sk)
		sk.global_position = p

var _seen_t := 0.0
var galleon: Ship
var _galleon_t := 40.0

## The Drowned Galleon: a ghost ship on a round of the isles. It first sails
## once you have found an isle, and comes back five minutes after you sink it.
func _fleet() -> void:
	if galleon != null and is_instance_valid(galleon):
		return
	var found := false
	for id in ISLES.keys():
		if Run.archive["places"].has("isle_" + id):
			found = true
	if not found:
		return
	_galleon_t -= 0.5
	if _galleon_t > 0.0:
		return
	var route: Array[Vector3] = []
	for id in ISLES.keys():
		route.append(mooring(id) + (mooring(id) - centre(id)).normalized() * 60.0)
	var p := world.player.global_position
	var start := route[0]
	for r in route:
		if r.distance_to(p) > start.distance_to(p):
			start = r
	galleon = Ship.new()
	galleon.hostile = true
	galleon.model_name = "ship-ghost"
	galleon.title = "The Drowned Galleon"
	galleon.max_hull = 160.0
	galleon.route = route
	galleon.home = start
	add_child(galleon)
	galleon.sank.connect(_galleon_sank)
	Run.flags["galleon_seen"] = true
	Run.toast.emit("A ghost ship is on the water", "law")

func _galleon_sank() -> void:
	var at := galleon.global_position
	var g := galleon
	galleon = null
	_galleon_t = 300.0
	Run.flags["galleon_sunk"] = true
	Run.record("ship")
	Run.renown(400.0)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.call("show_banner", "The Drowned Galleon", "SUNK", "Its hold floats free. Swim for it.")
	var spill := [["silver", int(260 * Run.gain_mult())], ["star_iron", 2], [Treasure.roll_map(), 1],
		[Loot.roll_weapon("relic" if randf() < 0.2 else "rare"), 1], ["rime_salt", 2]]
	for k in spill.size():
		var a := TAU * float(k) / float(spill.size())
		Pickup.spawn(self, Vector3(at.x, 0.5, at.z) + Vector3(cos(a), 0, sin(a)) * 6.0, str(spill[k][0]), int(spill[k][1]))
	await get_tree().create_timer(12.0).timeout
	if is_instance_valid(g):
		g.queue_free()

func _process(delta: float) -> void:
	for l in get_tree().get_nodes_in_group("fires"):
		(l as OmniLight3D).light_energy = 1.8 + 0.4 * sin(Time.get_ticks_msec() * 0.013 + l.get_instance_id())
	_seen_t -= delta
	if _seen_t > 0.0 or world == null or world.player == null:
		return
	_seen_t = 0.5
	_fleet()
	var p := world.player.global_position
	var here := isle_at(p.x, p.z)
	if here != "" and Run.discover("isle_" + here):
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null:
			hud.call("show_banner", str(ISLES[here]["name"]), "NEW ISLE")
