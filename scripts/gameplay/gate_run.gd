class_name GateRun
extends Node3D
## The inside of a Gate: a pocket dimension of stone chambers laid out on a
## winding path, built from the KayKit dungeon kit on its 4 m grid. Rooms
## are fights (the doorways bar shut until the room is clear), spike traps,
## a reading room with a page of the Rupture, a treasure room, and at the
## end the keeper of the Gate. Kill it and the way out opens.
##
## A trial (for ascension) is the same thing with one arena and waves.

signal finished(cleared: bool)

const KIT := "res://assets/dungeon/"
const CELL := 4.0
const ROOM := 5                ## cells per room side
const BOSS_ROOM := 7
const STRIDE := 9              ## cells between room origins
const THEMES := {
	"drowned": {"fog": Color(0.10, 0.26, 0.32), "ambient": Color(0.35, 0.55, 0.65), "torch": Color(0.45, 0.85, 1.0),
		"floor": ["floor_tile_large", "floor_tile_large", "floor_tile_large_rocks", "floor_dirt_large"], "banner": "banner_blue"},
	"keep": {"fog": Color(0.24, 0.16, 0.08), "ambient": Color(0.6, 0.48, 0.35), "torch": Color(1.0, 0.7, 0.38),
		"floor": ["floor_tile_large", "floor_tile_large", "floor_tile_large"], "banner": "banner_patternA_red"},
	"crown": {"fog": Color(0.16, 0.10, 0.24), "ambient": Color(0.55, 0.45, 0.70), "torch": Color(0.85, 0.65, 1.0),
		"floor": ["floor_tile_large", "floor_tile_large_rocks", "floor_tile_large"], "banner": "banner_triple_yellow"},
	"trial": {"fog": Color(0.08, 0.08, 0.12), "ambient": Color(0.5, 0.5, 0.6), "torch": Color(1.0, 0.85, 0.55),
		"floor": ["floor_tile_large"], "banner": "banner_shield_white"},
}

var gate_id := ""
var trial_rank := 0             ## > 0 for an ascension trial
var def: Dictionary = {}
var rooms: Array = []           ## {cell: Vector2i, size, kind, bounds: Rect2, done, door_bars: []}
var entrance := Vector3.ZERO
var player: Player
var _rng := RandomNumberGenerator.new()
var _scenes := {}
var _static: Node3D
var _active := -1
var _alive: Array = []
var _spikes: Array = []
var _spike_t := 0.0
var _waves_left := 0
var _exit: Node3D
var _theme: Dictionary

func build(p: Player) -> void:
	player = p
	_rng.seed = hash(gate_id) + trial_rank * 97 + int(Run.flags.get("gate_runs_" + gate_id, 0))
	if trial_rank > 0:
		def = {"name": "Trial of the %s" % Law.RANK_TITLES[trial_rank], "law": Run.law.get("principle", "momentum"),
			"rank": trial_rank, "theme": "trial", "rooms": 1, "foes": ["warrior", "rogue", "minion"]}
	else:
		def = Story.GATES[gate_id]
	_theme = THEMES[def["theme"]]
	_static = Node3D.new()
	add_child(_static)
	_layout()
	for i in rooms.size():
		_build_room(i)
	for i in rooms.size() - 1:
		_build_corridor(rooms[i], rooms[i + 1])
	var merged := Village._merge(_static)
	_static.free()
	add_child(merged)
	var r0: Dictionary = rooms[0]
	entrance = _cell_world(r0["cell"] + Vector2i(r0["size"] / 2, r0["size"] / 2)) + Vector3(0, 0.3, 0)

# --- Layout ---------------------------------------------------------------------

func _layout() -> void:
	var n := int(def["rooms"])
	var at := Vector2i.ZERO
	var taken := {at: true}
	var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var path: Array[Vector2i] = [at]
	for i in n - 1:
		var options: Array[Vector2i] = []
		for d in dirs:
			if not taken.has(at + d) and d != Vector2i(0, -1):
				options.append(at + d)
		if options.is_empty():
			break
		at = options[_rng.randi() % options.size()]
		taken[at] = true
		path.append(at)
	var kinds := _kinds(path.size())
	for i in path.size():
		var size := BOSS_ROOM if kinds[i] == "boss" else ROOM
		var cell := path[i] * STRIDE + Vector2i((ROOM - size) / 2, (ROOM - size) / 2)
		var r := {"cell": cell, "size": size, "kind": kinds[i], "done": kinds[i] in ["start", "treasure", "lore"],
			"bars": [], "index": i}
		var o := _cell_world(cell) - Vector3(CELL * 0.5, 0, CELL * 0.5)
		r["bounds"] = Rect2(Vector2(o.x, o.z), Vector2(size, size) * CELL)
		rooms.append(r)

func _kinds(n: int) -> Array:
	if trial_rank > 0:
		return ["arena"]
	var mid: Array = []
	for i in n - 2:
		mid.append("fight")
	if mid.size() >= 3:
		mid[1] = "trap"
		mid[mid.size() - 2] = "lore"
	if mid.size() >= 5:
		mid[2] = "treasure"
	if mid.size() >= 7:
		mid[4] = "lore"
	return ["start"] + mid + ["boss"]

func _cell_world(c: Vector2i) -> Vector3:
	return global_position + Vector3(float(c.x) * CELL, 0.0, float(c.y) * CELL)

# --- Building ---------------------------------------------------------------------

func _scene(name: String) -> PackedScene:
	if not _scenes.has(name):
		_scenes[name] = load(KIT + name + ".glb")
	return _scenes[name]

func _put(name: String, at: Vector3, rot: float = 0.0, parent: Node3D = null) -> Node3D:
	var ps := _scene(name)
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	(parent if parent != null else _static).add_child(n)
	n.position = at - global_position if parent == null else at
	n.rotation.y = rot
	return n

func _neighbour_dir(i: int, j: int) -> Vector2i:
	var a: Vector2i = rooms[i]["cell"] + Vector2i(rooms[i]["size"] / 2, rooms[i]["size"] / 2)
	var b: Vector2i = rooms[j]["cell"] + Vector2i(rooms[j]["size"] / 2, rooms[j]["size"] / 2)
	var d := b - a
	return Vector2i(signi(d.x), 0) if absi(d.x) > absi(d.y) else Vector2i(0, signi(d.y))

func _build_room(i: int) -> void:
	var r: Dictionary = rooms[i]
	var c: Vector2i = r["cell"]
	var s: int = r["size"]
	var floors: Array = _theme["floor"]
	for x in s:
		for z in s:
			var f: String = floors[_rng.randi() % floors.size()]
			if r["kind"] == "trap" and (x + z) % 2 == 0 and x > 0 and x < s - 1:
				# A grate in the floor; the spikes come up through it.
				_put("floor_tile_big_grate", _cell_world(c + Vector2i(x, z)))
				_spikes.append({"node": _put("floor_tile_big_spikes", _cell_world(c + Vector2i(x, z)), 0.0, self),
					"pos": _cell_world(c + Vector2i(x, z))})
				continue
			_put(f, _cell_world(c + Vector2i(x, z)))
	# Which sides have a doorway: towards the previous and next rooms.
	var doors := {}
	if i > 0:
		doors[_neighbour_dir(i, i - 1)] = true
	if i < rooms.size() - 1:
		doors[_neighbour_dir(i, i + 1)] = true
	var half := float(s) * 0.5 * CELL
	var centre := _cell_world(c) + Vector3((float(s) - 1.0) * CELL * 0.5, 0, (float(s) - 1.0) * CELL * 0.5)
	r["centre"] = centre
	_atmosphere(centre, half, r["kind"] in ["boss", "arena"])
	var body := StaticBody3D.new()
	body.collision_layer = 2
	add_child(body)
	_box(body, centre + Vector3(0, -0.5, 0), Vector3(float(s) * CELL, 1.0, float(s) * CELL))
	for side in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var rot := atan2(float(side.x), float(side.y))
		var along := Vector3(float(-side.y), 0, float(side.x))
		var out := Vector3(float(side.x), 0, float(side.y)) * half
		for k in s:
			var offs := (float(k) - (float(s) - 1.0) * 0.5) * CELL
			var at := centre + out + along * offs
			var is_door := doors.has(side) and k == s / 2
			if is_door:
				_put("wall_doorway", at, rot)
				var bars := _put("wall_gated", at, rot, self)
				bars.position = at - global_position
				bars.visible = false
				(r["bars"] as Array).append(bars)
				var post := 1.4
				_box(body, at + along * (CELL * 0.5 - post * 0.5) + Vector3(0, 2, 0), _rot_size(Vector3(post, 4, 1), side))
				_box(body, at - along * (CELL * 0.5 - post * 0.5) + Vector3(0, 2, 0), _rot_size(Vector3(post, 4, 1), side))
				var gate_body := StaticBody3D.new()
				gate_body.collision_layer = 0
				add_child(gate_body)
				_box(gate_body, at + Vector3(0, 2, 0), _rot_size(Vector3(CELL, 4, 0.6), side))
				(r["bars"] as Array).append(gate_body)
			else:
				_put("wall" if _rng.randf() < 0.8 else ["wall_cracked", "wall_arched", "wall_broken"][_rng.randi() % 3], at, rot)
				_box(body, at + Vector3(0, 2, 0), _rot_size(Vector3(CELL, 4, 1), side))
				if k % 2 == 1 and _rng.randf() < 0.7:
					_torch(at - out.normalized() * 0.55 + Vector3(0, 2.4, 0), rot + PI)
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_put("pillar", centre + Vector3(cx * half, 0, cz * half))
	# Dressing by kind.
	match str(r["kind"]):
		"boss", "arena":
			for k in 6:
				var a := TAU * float(k) / 6.0
				_put("pillar_decorated", centre + Vector3(sin(a), 0, cos(a)) * half * 0.62, a)
			_put(_theme["banner"], centre + Vector3(0, 0, -half + 0.7))
		"treasure":
			var ch := Chest.new()
			ch.id = "%s_%d_%d" % [gate_id, i, int(Run.flags.get("gate_runs_" + gate_id, 0))]
			ch.loot = [["silver", 40 + 30 * int(def["rank"])], ["red_potion", 1], [["grave_dust", "iron_scrap"][_rng.randi() % 2], 2]]
			add_child(ch)
			ch.global_position = centre
		"lore":
			var page := LorePage.new()
			var pages: Array = def.get("pages", [])
			var idx := mini((r["index"] as int) / 3, pages.size() - 1)
			page.page_id = str(pages[idx]) if not pages.is_empty() else ""
			for p in pages:
				if not Run.has_clue(str(p)):
					page.page_id = str(p)
					break
			add_child(page)
			page.global_position = centre
		_:
			for k in _rng.randi_range(2, 5):
				var spot := centre + Vector3(_rng.randf_range(-half + 2.5, half - 2.5), 0, _rng.randf_range(-half + 2.5, half - 2.5))
				_put(["barrel_large", "barrel_small_stack", "box_stacked", "crates_stacked", "rubble_half", "column",
					"sword_shield_broken", "trunk_medium_A"][_rng.randi() % 8], spot, _rng.randf() * TAU)

func _rot_size(sz: Vector3, side: Vector2i) -> Vector3:
	return sz if side.x == 0 else Vector3(sz.z, sz.y, sz.x)

func _box(body: StaticBody3D, at: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	body.add_child(cs)
	cs.global_position = at

## A chamber's air: a rune circle in the torches' colour on the floor (wider
## and brighter where the keeper waits), and motes drifting in the light.
func _atmosphere(centre: Vector3, half: float, keeper: bool) -> void:
	var col: Color = _theme["torch"]
	var glyph := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2.ONE * (half * (1.3 if keeper else 0.9))
	glyph.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = GroundMessage._runes()
	m.albedo_color = Color(col, 0.55 if keeper else 0.3)
	glyph.material_override = m
	glyph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glyph)
	glyph.global_position = centre + Vector3.UP * 0.07
	var motes := CPUParticles3D.new()
	motes.amount = 36 if keeper else 18
	motes.lifetime = 6.0
	motes.preprocess = 6.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(half * 0.8, 2.0, half * 0.8)
	motes.gravity = Vector3(0, 0.08, 0)
	motes.initial_velocity_min = 0.05
	motes.initial_velocity_max = 0.25
	motes.spread = 180.0
	var q := QuadMesh.new()
	q.size = Vector2(0.07, 0.07)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.albedo_color = col.lightened(0.2)
	q.material = qm
	motes.mesh = q
	add_child(motes)
	motes.global_position = centre + Vector3.UP * 2.4
	if keeper:
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 1.6
		l.omni_range = half * 1.6
		add_child(l)
		l.global_position = centre + Vector3.UP * 5.0

func _torch(at: Vector3, rot: float) -> void:
	_put("torch_mounted", at, rot)
	var l := OmniLight3D.new()
	l.light_color = _theme["torch"]
	l.light_energy = 2.2
	l.omni_range = 11.0
	add_child(l)
	l.global_position = at + Vector3(0, 0.5, 0)
	var flame := Landmarks._flame()
	add_child(flame)
	flame.global_position = at + Vector3(0, 0.45, 0)

func _build_corridor(a: Dictionary, b: Dictionary) -> void:
	var ca: Vector3 = a["centre"]
	var cb: Vector3 = b["centre"]
	var dir := (cb - ca).normalized()
	var ha := float(a["size"]) * 0.5 * CELL
	var hb := float(b["size"]) * 0.5 * CELL
	var from := ca + dir * ha
	var to := cb - dir * hb
	var steps := int(round(from.distance_to(to) / CELL))
	var side := Vector3(-dir.z, 0, dir.x)
	var body := StaticBody3D.new()
	body.collision_layer = 2
	add_child(body)
	var rot := atan2(side.x, side.z)
	for k in steps:
		var at := from + dir * (CELL * 0.5 + float(k) * CELL)
		_put("floor_tile_large", at)
		_put("wall", at + side * CELL * 0.5, rot)
		_put("wall", at - side * CELL * 0.5, rot + PI)
		_box(body, at + side * CELL * 0.5 + Vector3(0, 2, 0), Vector3(absf(side.x) * 1.0 + absf(dir.x) * CELL, 4, absf(side.z) * 1.0 + absf(dir.z) * CELL))
		_box(body, at - side * CELL * 0.5 + Vector3(0, 2, 0), Vector3(absf(side.x) * 1.0 + absf(dir.x) * CELL, 4, absf(side.z) * 1.0 + absf(dir.z) * CELL))
		_box(body, at + Vector3(0, -0.5, 0), Vector3(CELL, 1, CELL))
		if k == steps / 2:
			_torch(at + side * (CELL * 0.5 - 0.55) + Vector3(0, 2.4, 0), rot + PI)

# --- Running ----------------------------------------------------------------------

func room_at(p: Vector3) -> int:
	for i in rooms.size():
		if (rooms[i]["bounds"] as Rect2).grow(-1.0).has_point(Vector2(p.x, p.z)):
			return i
	return -1

func rooms_done() -> int:
	var n := 0
	for r in rooms:
		if r["done"]:
			n += 1
	return n

func _process(delta: float) -> void:
	if player == null:
		return
	# Spikes: up for a beat in every three; hurt whoever stands on them.
	_spike_t += delta
	var up := fmod(_spike_t, 2.4) > 1.6
	for s in _spikes:
		var n: Node3D = s["node"]
		n.position.y = lerpf(n.position.y, 0.0 if up else -2.2, clampf(delta * 14.0, 0.0, 1.0))
		if up and Vector2(player.global_position.x, player.global_position.z).distance_to(
				Vector2(s["pos"].x, s["pos"].z)) < CELL * 0.5 and player.global_position.y < s["pos"].y + 1.0:
			if fmod(_spike_t, 2.4) < 1.7:
				player.take_hit(7.0 * (1.0 + 0.15 * float(def["rank"])), self)
	var here := room_at(player.global_position)
	if here >= 0 and here != _active:
		_enter_room(here)
	if _active >= 0 and not rooms[_active]["done"]:
		_alive = _alive.filter(func(e: Node) -> bool: return is_instance_valid(e) and not bool(e.call("is_dead")))
		if _alive.is_empty():
			if _waves_left > 0:
				_waves_left -= 1
				_spawn_wave(rooms[_active])
			else:
				_clear_room(_active)

func _enter_room(i: int) -> void:
	_active = i
	var r: Dictionary = rooms[i]
	if r["done"]:
		return
	match str(r["kind"]):
		"fight":
			_bars(r, true)
			_spawn_wave(r)
		"trap":
			r["done"] = true
		"boss":
			_bars(r, true)
			_spawn_boss(r)
		"arena":
			_bars(r, true)
			_waves_left = 2
			_spawn_wave(r)

func _bars(r: Dictionary, shut: bool) -> void:
	for b in r["bars"]:
		if b is StaticBody3D:
			(b as StaticBody3D).collision_layer = 2 if shut else 0
		else:
			(b as Node3D).visible = shut
	Audio.play("door", player.global_position, 0.0, 0.6 if shut else 0.9)

func _scale_foe(sk: Skeleton) -> void:
	var rank := int(def["rank"])
	sk.health_mult = 1.0 + 0.3 * float(rank - 1)
	sk.damage_mult = 1.0 + 0.12 * float(rank - 1)

func _spawn_wave(r: Dictionary) -> void:
	var foes: Array = def["foes"]
	var n := 1 + int(def["rank"]) + _rng.randi_range(0, 1)
	var centre: Vector3 = r["centre"]
	for k in n:
		var sk := Skeleton.new()
		sk.kind = str(foes[_rng.randi() % foes.size()])
		_scale_foe(sk)
		var a := TAU * float(k) / float(n)
		var at := centre + Vector3(sin(a), 0.4, cos(a)) * 5.0
		sk.home = at
		sk.camp = "gate"
		sk.respawns = false
		sk.aggressive = true
		add_child(sk)
		sk.global_position = at
		_alive.append(sk)

func _spawn_boss(r: Dictionary) -> void:
	var sk := Skeleton.new()
	sk.kind = str(def["boss"])
	_scale_foe(sk)
	sk.home = r["centre"] + Vector3(0, 0.5, 0)
	sk.camp = "gate"
	sk.respawns = false
	sk.aggressive = true
	add_child(sk)
	sk.global_position = sk.home
	_alive.append(sk)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.call("show_banner", sk.kind_name(), "KEEPER OF THE GATE")

func _clear_room(i: int) -> void:
	var r: Dictionary = rooms[i]
	r["done"] = true
	_bars(r, false)
	Audio.ui("confirm", -6.0)
	if r["kind"] in ["boss", "arena"]:
		_victory(r)

func _victory(r: Dictionary) -> void:
	var at: Vector3 = r["centre"]
	if trial_rank == 0:
		for rw in def.get("reward", []):
			Pickup.spawn(self, at + Vector3(_rng.randf_range(-2, 2), 1.0, _rng.randf_range(-2, 2)), str(rw[0]), int(rw[1]))
		if not Story.gate_cleared(gate_id):
			Pickup.spawn(self, at + Vector3(0, 1.2, 0), str(def["catalyst"]), 1)
		Pickup.spawn(self, at + Vector3(2, 1.0, 0), Loot.roll_weapon("relic" if randf() < 0.12 else "rare"), 1)
		Run.renown(300.0)
	# The way out: a small rift where the keeper stood.
	_exit = GateExit.new()
	_exit.run = self
	add_child(_exit)
	_exit.global_position = at + Vector3(0, 0, 3)

func leave(cleared: bool) -> void:
	finished.emit(cleared)
