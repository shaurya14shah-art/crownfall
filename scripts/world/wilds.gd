class_name Wilds
extends Node3D
## What makes the island more than a map: Waystones along the roads, the
## field bosses (the Drowned Captain on the harbour shore; the Grave Knight,
## who walks the Crossroads road only at night), words left on the ground,
## and bloodstains where other knights died.

## [id, name, road index (Island.ROADS order), how far along it, side]
const WAYSTONES := [
	["harbour_road", "Harbour Road", 0, 0.5, 1.0],
	["brightwater", "Brightwater Gate", 1, 0.1, -1.0],
	["crossroads", "Old Crossroads", 2, 0.05, 1.0],
	["barrow_edge", "Barrow's Edge", 3, 0.84, -1.0],
	["highmoor", "Highmoor Approach", 2, 0.86, 1.0],
	["gulls_watch", "Gull's Watch", 4, 0.86, -1.0],
]

## [road, along, side metres, text]
const MESSAGES := [
	[0, 0.56, 4.0, "Rest at the stone. The dead get up again. So do you."],
	[0, 0.7, -5.0, "Hold the attack to strike hard. Hard blows break a stance."],
	[1, 0.35, 5.0, "Iron scrap? Take it to the anvil. Make your own blade."],
	[1, 0.6, -5.0, "Stance broken? Strike now. Critical."],
	[1, 0.62, 5.0, "This road is safe... by day."],
	[3, 0.55, 4.5, "Fell? Your silver waits where you fell. Go and get it."],
	[3, 0.92, -4.0, "Something big ahead. Bring a shield, and patience."],
	[3, 0.8, 5.0, "Ember coal and a blade: fire. Rime salt: cold."],
	[2, 0.6, -5.0, "Try jumping. Strike as you land."],
	[2, 0.95, 4.5, "Ring the bell, but only after dark."],
	[4, 0.94, 4.0, "Look up. At night."],
	[4, 0.5, -5.0, "Be wary of the left... no, the right."],
	[0, 0.2, 5.0, "Captain ahead, on the shore. Mind the crew."],
	[2, 0.3, 5.0, "No rest without a stone. Kindle every one you find."],
]

## [road, along, side, facing offset, [[clip, seconds, metres], ...]]
const STAINS := [
	[3, 0.95, 2.0, 0.0, [["Running_A", 1.1, 5.0], ["1H_Melee_Attack_Chop", 0.8, 0.5], ["Hit_A", 0.5, -0.3],
		["Death_A", 1.8, 0.0]]],
	[2, 0.72, -3.5, 1.2, [["Running_A", 1.2, 6.0], ["Jump_Start", 0.35, 1.5], ["Jump_Idle", 0.7, 2.0],
		["Death_B", 1.8, 0.0]]],
	[0, 0.12, 3.0, 2.0, [["Blocking", 1.2, 0.0], ["Block_Hit", 0.5, -0.3], ["Hit_B", 0.5, -0.4],
		["Death_A", 1.8, 0.0]]],
	[1, 0.56, 2.5, 0.0, [["Walking_A", 1.6, 2.4], ["Hit_A", 0.4, -0.5], ["Hit_B", 0.4, -0.5], ["Death_B", 1.8, 0.0]]],
	[4, 0.97, 2.5, 0.5, [["Idle", 0.8, 0.0], ["Use_Item", 0.9, 0.0], ["Death_A", 1.8, 0.0]]],
]

var world: World
var _knight: Skeleton
var _check_t := 0.0
var _was_night := false
var _thief_t := 75.0            ## seconds until the next Grave Thief (the first comes early)
var _thief: Skeleton

func build(w: World) -> void:
	world = w
	for d in WAYSTONES:
		var ws := Waystone.new()
		ws.id = str(d[0])
		ws.title = str(d[1])
		var at := _road_spot(int(d[2]), float(d[3]), 4.5 * float(d[4]))
		add_child(ws)
		ws.global_position = at
		ws.rotation.y = _road_yaw(int(d[2]), float(d[3])) + (PI * 0.5 if float(d[4]) < 0.0 else -PI * 0.5)
	for i in MESSAGES.size():
		var m: Array = MESSAGES[i]
		var g := GroundMessage.new()
		g.index = i
		g.text = str(m[3])
		add_child(g)
		_lay_flat(g, _road_spot(int(m[0]), float(m[1]), float(m[2])))
	for i in STAINS.size():
		var s: Array = STAINS[i]
		var b := Bloodstain.new()
		b.index = i
		b.steps = s[4]
		add_child(b)
		_lay_flat(b, _road_spot(int(s[0]), float(s[1]), float(s[2])))
		b.rotate_object_local(Vector3.UP, _road_yaw(int(s[0]), float(s[1])) + float(s[3]))
	sync()

var _captain: Skeleton

## After a new game or a load: the stones lit or dark, the Captain there
## or not, your dropped silver where it lies.
func sync() -> void:
	for n in get_tree().get_nodes_in_group("waystones"):
		(n as Waystone).refresh()
	var dead := Run.flags.has("fb_drowned_captain")
	var here := _captain != null and is_instance_valid(_captain)
	if dead and here and not _captain.is_dead():
		_captain.queue_free()
		_captain = null
	elif not dead and not here:
		_captain = _spawn_boss("drowned_captain", boss_spot("drowned_captain"))
	if _knight != null and is_instance_valid(_knight):
		_knight.queue_free()
		_knight = null
	sync_lost()

# --- Places along the roads ---------------------------------------------------------------------

func _road(i: int) -> PackedVector2Array:
	return world.island.road_paths[clampi(i, 0, world.island.road_paths.size() - 1)]

func _road_spot(i: int, along: float, side: float) -> Vector3:
	var r := _road(i)
	var k := clampi(int(along * float(r.size() - 1)), 0, r.size() - 2)
	var dir := (r[k + 1] - r[k]).normalized()
	var p := r[k] + dir.orthogonal() * side
	return Vector3(p.x, world.island.height_at(p.x, p.y), p.y)

func _road_yaw(i: int, along: float) -> float:
	var r := _road(i)
	var k := clampi(int(along * float(r.size() - 1)), 0, r.size() - 2)
	var dir := r[k + 1] - r[k]
	return atan2(dir.x, dir.y)

## Sets a flat thing on the ground, tilted to the slope.
func _lay_flat(n: Node3D, at: Vector3) -> void:
	var isl := world.island
	var nrm := Vector3(isl.height_at(at.x - 0.8, at.z) - isl.height_at(at.x + 0.8, at.z), 1.6,
		isl.height_at(at.x, at.z - 0.8) - isl.height_at(at.x, at.z + 0.8)).normalized()
	var x := Vector3.RIGHT.slide(nrm).normalized()
	n.global_transform = Transform3D(Basis(x, nrm, x.cross(nrm).normalized()), at)

func waystone(id: String) -> Waystone:
	for n in get_tree().get_nodes_in_group("waystones"):
		if (n as Waystone).id == id:
			return n as Waystone
	return null

## Where a field boss stands (or walks, at night).
func boss_spot(kind: String) -> Vector3:
	var isl := world.island
	match kind:
		"drowned_captain":
			var h := isl.site_pos("harbour")
			var to_sea := (Vector3(430, 0, 610) - h) * Vector3(1, 0, 1)
			var side := Vector3(-to_sea.z, 0, to_sea.x).normalized()
			# Down the shore from the pier, stepping back until it is dry.
			var p := h + side * 34.0 + to_sea.normalized() * 30.0
			for k in 40:
				if isl.height_at(p.x, p.z) > 0.8:
					break
				p -= to_sea.normalized() * 2.0
			p.y = isl.height_at(p.x, p.z)
			return p
		"grave_knight":
			return _road_spot(1, 0.6, 0.0)
	return Vector3.INF

func _spawn_boss(kind: String, at: Vector3) -> Skeleton:
	var b := Skeleton.new()
	b.kind = kind
	b.respawns = false
	b.home = at + Vector3.UP * 0.5
	add_child(b)
	b.global_position = at + Vector3.UP * 0.5
	b.slain.connect(func(_c: String) -> void: _boss_down(kind))
	return b

func _boss_down(kind: String) -> void:
	Run.flags["fb_" + kind] = true
	var title := str(Skeleton.KINDS[kind]["name"])
	Run.add_clue("fb_" + kind, title, "%s is down. It left behind something worth carrying." % title)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.call("show_banner", title, "GREAT FOE FELLED")
	if kind == "grave_knight":
		_knight = null

# --- Your silver ------------------------------------------------------------------------------------

## Puts the silver you dropped back on the ground (after a load).
func sync_lost() -> void:
	for old in get_tree().get_nodes_in_group("lost_silver"):
		old.queue_free()
	var p: Array = Run.lost.get("pos", [])
	if p.size() == 3 and int(Run.lost.get("silver", 0)) > 0:
		LostSilver.place(self, Vector3(float(p[0]), float(p[1]), float(p[2])), int(Run.lost["silver"]))

## You fell here: whatever silver you carried stays behind.
func drop_silver(at: Vector3) -> void:
	if not Run.lost.is_empty():
		Run.toast.emit("The silver you left before is gone", "warn")
	Run.lost = {}
	for old in get_tree().get_nodes_in_group("lost_silver"):
		old.queue_free()
	if Run.silver <= 0:
		return
	Run.lost = {"pos": [at.x, at.y, at.z], "silver": Run.silver}
	Run.silver = 0
	Run.changed.emit("silver")
	LostSilver.place(self, at, int(Run.lost["silver"]))

## Rest: everything that fell gets up again.
func rest() -> void:
	for n in get_tree().get_nodes_in_group("fallen"):
		n.call("rise")

# --- The Grave Knight keeps to the night ---------------------------------------------------------

func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t > 0.0 or world == null or world.player == null or world.in_gate():
		return
	_check_t = 1.0
	_nightfall()
	_thieves()
	if Run.flags.has("fb_grave_knight"):
		return
	var spot := boss_spot("grave_knight")
	var far := world.player.global_position.distance_to(spot) > 70.0
	var alive := _knight != null and is_instance_valid(_knight) and not _knight.is_dead()
	if world.sky.is_night() and not alive and far:
		_knight = _spawn_boss("grave_knight", spot)
	elif not world.sky.is_night() and alive and far:
		_knight.queue_free()
		_knight = null

# --- Nights, surges and thieves ---------------------------------------------------------------

## Nightfall counts; every third night from the second the Rift surges:
## Elites walk more often, and Renown, silver and loot run rich till dawn.
func _nightfall() -> void:
	var night := world.sky.is_night()
	if night and not _was_night:
		Run.nights += 1
		Run.surge = Run.nights % 3 == 2
		if Run.surge:
			var hud := get_tree().get_first_node_in_group("hud")
			if hud != null:
				hud.call("show_banner", "The Rift Surges", "TONIGHT", "Elites walk. Renown and loot run rich until dawn.")
			Audio.ui("open", 0.0)
	elif not night and _was_night:
		Run.day += 1
		if Run.surge:
			Run.surge = false
			Run.toast.emit("The surge passes with the dawn", "law")
	_was_night = night

## Now and then a Grave Thief turns up somewhere near you, out in the wilds.
func _thieves() -> void:
	if _thief != null and is_instance_valid(_thief):
		return
	_thief = null
	_thief_t -= 1.0 * (2.0 if Run.surge else 1.0)
	if _thief_t > 0.0:
		return
	var p := world.player.global_position
	if Vector2(p.x, p.z).distance_to(Island.SITES["village"]["pos"]) < 110.0:
		_thief_t = 20.0
		return
	for k in 12:
		var a := randf() * TAU
		var at := p + Vector3(cos(a), 0, sin(a)) * randf_range(26.0, 40.0)
		at.y = world.island.height_at(at.x, at.z)
		if at.y > 1.5 and absf(at.y - p.y) < 8.0:
			_thief = Skeleton.new()
			_thief.kind = "thief"
			_thief.respawns = false
			_thief.home = at + Vector3.UP * 0.5
			add_child(_thief)
			_thief.global_position = at + Vector3.UP * 0.5
			_thief_t = randf_range(170.0, 260.0)
			return
	_thief_t = 15.0
