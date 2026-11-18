class_name World
extends Node3D
## The game world: builds the island and everything on it, spawns the
## player, and keeps the lamps and the grass in step with the day.

signal built

var island: Island
var terrain: Terrain
var sky: SkyRig
var ocean: Ocean
var foliage: Foliage
var grass: Grass
var village: Village
var player: Player
var rig: CameraRig
var ships: Array[Node3D] = []
var wilds: Wilds
var isles: Isles
var gull: Ship                    ## your ship
var harbour_mooring := Vector3.ZERO
var harbour_heading := 0.0

## Builds the world in stages, yielding between them so a loading screen
## can show progress. `report(fraction, text)` is called before each stage.
func _ready() -> void:
	add_to_group("world")

func build(report: Callable = Callable()) -> void:
	var say := func(f: float, t: String) -> void:
		if report.is_valid():
			report.call(f, t)
		await get_tree().process_frame
	await say.call(0.02, "Raising the island")
	island = Island.load_or_generate(Game.SEED)
	await say.call(0.30, "Shaping the land")
	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.build(island)
	await say.call(0.50, "Painting the sky")
	sky = SkyRig.new()
	sky.name = "Sky"
	add_child(sky)
	ocean = Ocean.new()
	ocean.name = "Ocean"
	add_child(ocean)
	await say.call(0.58, "Growing the forests")
	foliage = Foliage.new()
	foliage.name = "Foliage"
	add_child(foliage)
	await foliage.build(island, float(Game.q("tree_distance")))
	await say.call(0.80, "Building Brightwater")
	village = Village.new()
	village.name = "Village"
	add_child(village)
	village.build(island)
	terrain.material.set_shader_parameter("paint_map", ImageTexture.create_from_image(island.paint))
	_harbour()
	var marks := Landmarks.new()
	marks.name = "Landmarks"
	add_child(marks)
	marks.build(island)
	await say.call(0.92, "Waking the knight")
	grass = Grass.new()
	grass.name = "Grass"
	add_child(grass)
	grass.setup(island, terrain.material, float(Game.q("grass_radius")))
	_spawn_player()
	_spawn_enemies()
	_spawn_villagers()
	_spawn_secrets()
	isles = Isles.new()
	isles.name = "Isles"
	add_child(isles)
	isles.build(self)
	wilds = Wilds.new()
	wilds.name = "Wilds"
	add_child(wilds)
	wilds.build(self)
	gull = Ship.new()
	gull.name = "Gull"
	gull.title = "The Gull"
	gull.home = harbour_mooring
	gull.home_heading = harbour_heading
	add_child(gull)
	var hr := wilds.waystone("harbour_road")
	if hr != null:
		hr.mooring = harbour_mooring
	for i in Treasure.SITES.size():
		var t := Treasure.new()
		t.index = i
		add_child(t)
		t.global_position = Treasure.site_pos(i, self)
	grass.warm(player.global_position)
	await say.call(1.0, "Ready")
	built.emit()

## Camps of the risen: a big one at the barrow, smaller ones on the roads.
func _spawn_enemies() -> void:
	var camps := [["barrow", 7, Vector3.ZERO], ["crossroads", 3, Vector3(25, 0, -30)],
		["tower", 3, Vector3(-20, 0, 25)], ["village", 3, Vector3(-150, 0, -110)]]
	var rng := RandomNumberGenerator.new()
	rng.seed = Game.SEED + 13
	for camp in camps:
		var c: Vector3 = island.site_pos(camp[0]) + camp[2]
		for k in int(camp[1]):
			var sk := Skeleton.new()
			sk.kind = ["minion", "minion", "warrior", "rogue"][rng.randi() % 4]
			sk.camp = camp[0]
			var p := c + Vector3(rng.randf_range(-9, 9), 0, rng.randf_range(-9, 9))
			p.y = island.height_at(p.x, p.z) + 0.3
			sk.home = p
			add_child(sk)
			sk.global_position = p

const FOLK := [
	["Elder Maren", ["Knight. Thank the tides you came.", "The dead are walking out of the Barrow of Ash, north-west of here.",
		"Seven of them, at least. Put them back to rest, and Brightwater will remember it."]],
	["Tobin the Smith", ["Mind that sword arm. A blade's only as good as the one swinging it.",
		"Skeletons fall apart if you hit them hard enough. Most things do."]],
	["Wenna", ["The fish haven't come in since the bells rang at Highmoor.", "My husband says the keep is cursed. My husband says a lot."]],
	["Old Fennick", ["I saw a light on Gull's Watch last night. Nobody's kept that tower in twenty years."]],
	["Ysolde", ["Roll out of the way when they raise their blades — they're slow to swing.", "Brightwater bread. Best on the island. Only bread on the island, mind."]],
	["Corwin", ["Hold your shield up and they'll break on it like waves on the pier.",
		"The Gull's tied up at the end of the pier, rigged and nobody's. Take her out. Somebody ought to.",
		"Wind's everything at sea. Run before it, reach across it, never sail straight into it."]],
]

func _spawn_villagers() -> void:
	var c := village.centre
	for i in FOLK.size():
		var v := Villager.new()
		var said: Array[String] = []
		for l in FOLK[i][1]:
			said.append(str(l))
		var a := TAU * float(i) / float(FOLK.size()) + 0.4
		var at := c + Vector3(sin(a), 0, cos(a)) * (6.0 if i == 0 else 9.0)
		at.y = island.height_at(at.x, at.z) + 0.2
		v.setup("", str(FOLK[i][0]), said, at, island)
		add_child(v)
		v.global_position = at

## Chests, the bell, the Warden, and the light on Gull's Watch.
func _spawn_secrets() -> void:
	var chests := [["barrow", Vector3(4, 0, -6), [["silver", 40], ["grave_dust", 3], ["barrow_dagger", 1], ["bright_tear", 1]]],
		["castle", Vector3(-8, 0, -14), [["silver", 60], ["crest_shield", 1], ["hearth_seed", 1], ["star_iron", 1]]],
		["tower", Vector3(5, 0, 3), [["silver", 30], ["hearth_seed", 1], ["rime_salt", 2]]],
		["crossroads", Vector3(-6, 0, 5), [["silver", 18], ["iron_scrap", 4], ["ember_coal", 2]]]]
	for c in chests:
		var ch := Chest.new()
		ch.id = c[0]
		ch.loot = c[2]
		var at: Vector3 = island.site_pos(c[0]) + c[1]
		at.y = island.height_at(at.x, at.z)
		add_child(ch)
		ch.global_position = at
	var bell := Bell.new()
	add_child(bell)
	var k := island.site_pos("castle") + Vector3(6, 0, 10)
	k.y = island.height_at(k.x, k.z) + 0.1
	bell.global_position = k
	if not Run.flags.has("warden_dead"):
		var w := Skeleton.new()
		w.kind = "warden"
		w.camp = "barrow"
		var wp := island.site_pos("barrow") + Vector3(0, 0.5, 2)
		w.home = wp
		add_child(w)
		w.global_position = wp
		w.slain.connect(func(_c: String) -> void:
			Run.flags["warden_dead"] = true
			Run.add_clue("warden", "The Barrow Warden",
				"The great one at the heart of the barrow fell apart like the others, and left a splinter of still water behind."))
	# The Gates: rifts that wake as the story disturbs the Law.
	for id in Story.GATES.keys():
		var g := GatePortal.new()
		g.gate_id = id
		var gd: Dictionary = Story.GATES[id]
		var at := Story.peak_pos(island) if gd["site"] == "peak" else island.site_pos(str(gd["site"])) + \
			Vector3(float(gd["offset"][0]), 0, float(gd["offset"][2]))
		# Never in the sea: walk it back up the shore to dry ground.
		at = dry(at, island.site_pos("village") if gd["site"] == "harbour" else island.site_pos("village").lerp(at, 0.0))
		add_child(g)
		g.global_position = at
		g.rotation.y = atan2(island.site_pos("village").x - at.x, island.site_pos("village").z - at.z)
	_tower_light = OmniLight3D.new()
	_tower_light.light_color = Color(1.0, 0.85, 0.5)
	_tower_light.omni_range = 18.0
	_tower_light.light_energy = 0.0
	add_child(_tower_light)
	_tower_light.global_position = island.site_pos("tower") + Vector3(0, 16.5, 0)

var gate_run: GateRun
var _gate_return := Vector3.ZERO
const POCKET := Vector3(4600, 400, 4600)

## Into a Gate: the island goes dark and still behind you, the pocket is
## built, and you stand at its first chamber.
func enter_gate(id: String, trial_rank: int = 0) -> void:
	_gate_return = player.global_position
	gate_run = GateRun.new()
	gate_run.gate_id = id
	gate_run.trial_rank = trial_rank
	add_child(gate_run)
	gate_run.global_position = POCKET
	gate_run.build(player)
	var th: Dictionary = GateRun.THEMES[gate_run.def["theme"]]
	for n in [terrain, ocean, foliage, grass, village]:
		(n as Node3D).visible = false
	sky.enter_pocket(th["fog"], th["ambient"])
	player.global_position = gate_run.entrance
	player.reset_physics_interpolation()
	rig.snap()

func exit_gate(back_to: Vector3 = Vector3.INF) -> void:
	if gate_run != null:
		gate_run.queue_free()
		gate_run = null
	for n in [terrain, ocean, foliage, grass, village]:
		(n as Node3D).visible = true
	sky.leave_pocket()
	var to := _gate_return if back_to == Vector3.INF else back_to
	to.y = island.height_at(to.x, to.z) + 0.4
	player.global_position = to
	player.reset_physics_interpolation()
	rig.snap()

func in_gate() -> bool:
	return gate_run != null

## The ground under (x, z): Aldermere or one of the isles (the sea floor
## where there is neither).
func ground(x: float, z: float) -> float:
	return maxf(island.height_at(x, z), Isles.height_at(x, z))

## Moves `at` toward `toward` until it stands on dry ground well above the sea.
func dry(at: Vector3, toward: Vector3) -> Vector3:
	var p := at
	for k in 200:
		if ground(p.x, p.z) > 1.6:
			break
		var step := (toward - p) * Vector3(1, 0, 1)
		if step.length() < 2.0:
			break
		p += step.normalized() * 2.0
	p.y = ground(p.x, p.z)
	return p

## Where you went into the Gate you are in (or are coming out of).
func gate_return() -> Vector3:
	return _gate_return

var _tower_light: OmniLight3D
var _barrow_t := 0.0

func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	add_child(player)
	var c := island.site_pos("village")
	var h := island.site_pos("harbour")
	var spot := c.lerp(h, 0.42)
	spot.y = island.height_at(spot.x, spot.z) + 0.2
	player.global_position = spot
	player.model.rotation.y = atan2(c.x - spot.x, c.z - spot.z)
	rig = CameraRig.new()
	rig.name = "CameraRig"
	add_child(rig)
	rig.target = player
	rig.yaw = player.model.rotation.y + PI
	rig.snap()
	player.rig = rig

## The harbour: a pier from the shoreline out into the bay, and ships at
## anchor in deep water, rolling gently on the swell.
func _harbour() -> void:
	var h := island.site_pos("harbour")
	var bay := Vector3(430, 0, 610)
	var dir := ((bay - h) * Vector3(1, 0, 1)).normalized()
	# Walk out from the harbour until the ground drops under the sea.
	var shore := h
	for k in 200:
		var p := h + dir * float(k) * 2.0
		if island.height_at(p.x, p.z) < 0.2:
			shore = p
			break
	var dock := load("res://assets/ships/structure-platform-dock.glb") as PackedScene
	var aabb := _scene_aabb(dock)
	var step := minf(aabb.size.z, aabb.size.x) * 3.0
	for k in 9:
		var p := shore + dir * (float(k) * step - step * 1.5)
		var piece := dock.instantiate() as Node3D
		piece.scale = Vector3.ONE * 3.0
		piece.position = Vector3(p.x, 1.0, p.z)
		piece.rotation.y = atan2(dir.x, dir.z) + PI * 0.5
		add_child(piece)
	var side := Vector3(-dir.z, 0, dir.x)
	# The Gull's mooring: alongside the pier, in deep water, bow to the sea.
	var deep := shore
	for k in 150:
		var p := shore + dir * float(k) * 2.0
		if island.height_at(p.x, p.z) < -6.0:
			deep = p
			break
	harbour_mooring = deep + dir * 6.0 - side * 9.0
	harbour_heading = atan2(dir.x, dir.z)
	var spots := [[shore + dir * 70.0 + side * 25.0, "ship-large", 0.4],
		[shore + dir * 120.0 - side * 40.0, "ship-medium", 1.6],
		[shore + dir * 30.0 + side * 12.0, "boat-row-large", 2.4]]
	for s in spots:
		var p: Vector3 = s[0]
		var ship := (load("res://assets/ships/%s.glb" % s[1]) as PackedScene).instantiate() as Node3D
		ship.scale = Vector3.ONE * (3.2 if str(s[1]).begins_with("ship") else 2.0)
		ship.position = Vector3(p.x, -0.3, p.z)
		ship.rotation.y = float(s[2])
		ship.set_meta("base_y", -0.3)
		add_child(ship)
		ships.append(ship)

static func _scene_aabb(ps: PackedScene) -> AABB:
	var n := ps.instantiate()
	var box := AABB()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		box = box.merge((mi as MeshInstance3D).mesh.get_aabb())
	n.free()
	return box

func _process(_delta: float) -> void:
	if sky == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	for i in ships.size():
		var s := ships[i]
		s.position.y = float(s.get_meta("base_y")) + sin(t * 0.8 + i) * 0.18
		s.rotation.z = sin(t * 0.6 + i * 1.7) * 0.025
		s.rotation.x = sin(t * 0.5 + i) * 0.015
	var lamp := 1.0 - smoothstep(-0.05, 0.12, sky.sun_height())
	if _tower_light != null:
		_tower_light.light_energy = lamp * 6.0
	# Latent potential gathers near the Barrow, where the Law is fractured.
	if player != null and Run.law.is_empty():
		var b := island.site_pos("barrow")
		if player.global_position.distance_to(b) < 90.0:
			Run.potential = minf(100.0, Run.potential + _delta * 1.0)
	# The light on Gull's Watch, seen at night from close by, is a thread.
	if player != null and lamp > 0.5 and not Run.has_clue("tower_light"):
		if player.global_position.distance_to(island.site_pos("tower")) < 70.0:
			Run.add_clue("tower_light", "A Light on Gull's Watch",
				"A lamp burns at the top of the old tower after dark. Nobody has kept it in twenty years. Fennick said so.")
			Pickup.spawn(self, island.site_pos("tower") + Vector3(0, 1.0, -4.5), "orrery_disc", 1)
	for l in get_tree().get_nodes_in_group("night_lights"):
		(l as OmniLight3D).light_energy = lamp * 2.2
		(l as OmniLight3D).visible = lamp > 0.01
