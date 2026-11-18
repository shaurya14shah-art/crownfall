class_name SaveSystem
extends RefCounted
## Three save slots, each one JSON file: the whole Run (bag, gear, skills,
## Inscription, Archive, flags) plus where you are standing, the time of day
## and how long you have played.

const SLOTS := 3
const VERSION := 1

static func path(slot: int) -> String:
	return "user://save_%d.json" % slot

static func save(slot: int, world: World, play_seconds: float) -> bool:
	var p := world.player.global_position
	var here := "The wilds"
	for id in Island.SITES.keys():
		var s: Dictionary = Island.SITES[id]
		if Vector2(p.x, p.z).distance_to(s["pos"]) < float(s["radius"]) * 1.3:
			here = str(s["name"])
	var data := {
		"version": VERSION,
		"saved": Time.get_datetime_string_from_system(false, true),
		"place": here,
		"play_seconds": play_seconds,
		"player": [p.x, p.y, p.z],
		"health": world.player.health,
		"time": world.sky.time_of_day,
		"run": Run.to_dict(),
	}
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	return true

static func read(slot: int) -> Dictionary:
	if not FileAccess.file_exists(path(slot)):
		return {}
	var f := FileAccess.open(path(slot), FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

## Puts a save into the running world.
static func apply(data: Dictionary, world: World) -> float:
	Run.from_dict(data.get("run", {}))
	var p: Array = data.get("player", [])
	if p.size() == 3:
		world.player.global_position = Vector3(float(p[0]), float(p[1]) + 0.3, float(p[2]))
		world.player.reset_physics_interpolation()
	world.player.health = minf(float(data.get("health", 100.0)), world.player.max_health())
	world.player.health_changed.emit(world.player.health, world.player.max_health())
	world.sky.time_of_day = float(data.get("time", 0.37))
	if world.wilds != null:
		world.wilds.sync()
	world.rig.snap()
	return float(data.get("play_seconds", 0.0))

static func latest() -> int:
	var best := -1
	var best_time := ""
	for i in SLOTS:
		var d := read(i)
		if d.is_empty():
			continue
		if str(d.get("saved", "")) > best_time:
			best_time = str(d.get("saved", ""))
			best = i
	return best

static func describe(slot: int) -> String:
	var d := read(slot)
	if d.is_empty():
		return ""
	var mins := int(float(d.get("play_seconds", 0.0)) / 60.0)
	return "%s  ·  %dh %02dm" % [d.get("place", "?"), mins / 60, mins % 60]
