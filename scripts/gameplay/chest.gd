class_name Chest
extends Node3D
## A chest somebody left behind: glows until opened, then spills its loot.
## Opened chests stay opened (Run.flags, saved).

var id := ""
var loot: Array = []           ## [[item, n], ...]; "silver" for coin
var _glow: OmniLight3D

func _ready() -> void:
	add_to_group("interactables")
	var model := (load("res://assets/props/Chest_Wood.gltf") as PackedScene).instantiate() as Node3D
	model.scale = Vector3.ONE * 1.3
	add_child(model)
	if not opened():
		_glow = OmniLight3D.new()
		_glow.light_color = Color(1.0, 0.82, 0.45)
		_glow.light_energy = 1.4
		_glow.omni_range = 4.0
		_glow.position = Vector3(0, 1.2, 0)
		add_child(_glow)

func opened() -> bool:
	return Run.flags.has("chest_" + id)

func prompt_text() -> String:
	return "" if opened() else "Open"

func interact(_player: Node3D) -> void:
	if opened():
		return
	Run.flags["chest_" + id] = true
	Run.lean("curiosity", 1.0)
	Audio.play("door", global_position, 0.0, 0.8)
	Audio.play("coin", global_position)
	for l in loot:
		Pickup.spawn(get_parent(), global_position + Vector3(randf_range(-0.8, 0.8), 1.0, randf_range(-0.8, 0.8)),
			str(l[0]), int(l[1]))
	Pickup.spawn(get_parent(), global_position + Vector3(0, 1.2, 0.8), Loot.roll_weapon(Loot.tier_roll(5.0)), 1)
	Run.renown(25.0)
	if _glow != null:
		var tw := create_tween()
		tw.tween_property(_glow, "light_energy", 0.0, 0.8)
