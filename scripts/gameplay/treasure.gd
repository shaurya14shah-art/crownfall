class_name Treasure
extends Node3D
## Buried treasure. A Treasure Map in your bag marks one dig site with an
## X (on the map page, on the compass, and on the ground once you are close).
## Stand on the X and dig: a chest comes up out of the sand with silver, a
## weapon, maybe Star-Iron, and sometimes another map.
##
## Each node is one dig site; the sites are fixed places on the isles and on
## Aldermere's shore. Maps are items ("map_<n>") made by roll_map().

## [where, angle, fraction of the isle's radius]; "aldermere" sites are
## [site, x offset, z offset] walked up the shore to dry ground.
const SITES := [
	["skull_key", 0.4, 0.5], ["skull_key", 2.6, 0.62], ["skull_key", 4.4, 0.3],
	["wreck_shoals", 1.0, 0.45], ["wreck_shoals", 3.8, 0.55],
	["sable_isle", 0.9, 0.55], ["sable_isle", 2.7, 0.35], ["sable_isle", 5.0, 0.65],
	["aldermere", "harbour", 40.0, 30.0], ["aldermere", "tower", 30.0, -25.0], ["aldermere", "barrow", -40.0, -30.0],
]

var index := 0
var _mark: MeshInstance3D
var _t := 0.0

static var _x_tex: ImageTexture

## Where site `i` is, on the ground.
static func site_pos(i: int, world: World) -> Vector3:
	var s: Array = SITES[i]
	if str(s[0]) == "aldermere":
		var c := world.island.site_pos(str(s[1]))
		return world.dry(c + Vector3(float(s[2]), 0, float(s[3])), c)
	var p := Isles.spot(str(s[0]), float(s[1]), float(s[2]))
	return Vector3(p.x, maxf(p.y, 0.5), p.z)

static func where(i: int) -> String:
	var s: Array = SITES[i]
	if str(s[0]) == "aldermere":
		return str(Island.SITES[str(s[1])]["name"]) + "'s shore"
	return str(Isles.ISLES[str(s[0])]["name"])

## A new map to a site no map in your bag already points to.
static func roll_map(site: int = -1) -> String:
	if site < 0:
		var held := held_sites()
		var free := []
		for i in SITES.size():
			if not i in held:
				free.append(i)
		site = free.pick_random() if not free.is_empty() else randi() % SITES.size()
	Run.loot_count += 1
	var id := "map_%d" % Run.loot_count
	Run.forged[id] = {"name": "Treasure Map: %s" % where(site), "kind": "map", "site": site, "rarity": "fine",
		"look": "res://assets/props/Scroll_2.gltf", "price": 0,
		"text": "Somebody marked an X on %s and never came back for it. Find the X and dig." % where(site)}
	return id

## Sites the maps in your bag point to.
static func held_sites() -> Array:
	var out := []
	for s in Run.bag:
		var id := str(s["id"])
		if id.begins_with("map_"):
			out.append(int(Run.item(id).get("site", -1)))
	return out

static func _map_for(site: int) -> String:
	for s in Run.bag:
		var id := str(s["id"])
		if id.begins_with("map_") and int(Run.item(id).get("site", -1)) == site:
			return id
	return ""

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("dig_sites")
	_mark = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.4, 2.4)
	_mark.mesh = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _cross()
	m.albedo_color = Color(0.85, 0.12, 0.08, 0.85)
	_mark.material_override = m
	_mark.position.y = 0.06
	_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mark)

static func _cross() -> ImageTexture:
	if _x_tex != null:
		return _x_tex
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n - 0.5
			var v := (y + 0.5) / n - 0.5
			var d := minf(absf(u - v), absf(u + v))
			var a := clampf((0.07 - d) * 30.0, 0.0, 1.0) * clampf((0.42 - maxf(absf(u), absf(v))) * 20.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	_x_tex = ImageTexture.create_from_image(img)
	return _x_tex

func _process(delta: float) -> void:
	_t += delta
	_mark.visible = index in held_sites()
	if _mark.visible:
		_mark.scale = Vector3.ONE * (1.0 + 0.08 * sin(_t * 3.0))

func prompt_text() -> String:
	return "Dig" if index in held_sites() else ""

func interact(player: Node3D) -> void:
	var map := _map_for(index)
	if map == "" or not Run.remove_item(map, 1):
		return
	Run.forged.erase(map)
	(player as Player).play_art("Interact", 0.9, 1.1)
	Audio.play("roll", global_position, 0.0, 0.5)
	await get_tree().create_timer(0.9).timeout
	_unearth()

## The hole, the chest coming up out of it, and what is in it.
func _unearth() -> void:
	var hole := (load("res://assets/ships/hole.glb") as PackedScene).instantiate() as Node3D
	hole.scale = Vector3.ONE * 1.1
	add_child(hole)
	var chest := (load("res://assets/ships/chest.glb") as PackedScene).instantiate() as Node3D
	chest.scale = Vector3.ONE * 1.3
	chest.position = Vector3(0, -1.2, 0)
	add_child(chest)
	var tw := create_tween()
	tw.tween_property(chest, "position:y", 0.05, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	Fx.sparks(get_parent(), global_position + Vector3.UP, Color(1.0, 0.85, 0.4), 40)
	Audio.play("coin", global_position, 4.0)
	var at := global_position + Vector3.UP * 1.0
	var spill := func(id: String, n: int) -> void:
		Pickup.spawn(get_parent(), at + Vector3(randf_range(-1.2, 1.2), 0.3, randf_range(-1.2, 1.2)), id, n)
	spill.call("silver", int(randi_range(120, 260) * Run.gain_mult()))
	spill.call(Loot.roll_weapon(Loot.tier_roll(6.0)), 1)
	if randf() < 0.55:
		spill.call("star_iron", 1)
	if randf() < 0.2:
		spill.call("hearth_seed" if randf() < 0.5 else "bright_tear", 1)
	if randf() < 0.3:
		spill.call(Treasure.roll_map(), 1)
	Run.flags["dug"] = true
	Run.flags["dug_count"] = int(Run.flags.get("dug_count", 0)) + 1
	Run.record("treasure")
	Run.renown(80.0)
	Run.toast.emit("Treasure!", "skill")
	await get_tree().create_timer(20.0).timeout
	hole.queue_free()
	chest.queue_free()
