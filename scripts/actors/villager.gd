class_name Villager
extends CharacterBody3D
## A person of Brightwater: strolls between spots round the square, stops to
## look about, turns to face you when you come close, and has something to
## say when you press E.

const LOOKS := ["Mage", "Rogue", "Rogue_Hooded", "Barbarian"]

var display_name := "Villager"
var lines: Array[String] = []
var home := Vector3.ZERO
var island: Island
var model: CharacterModel
var _target := Vector3.ZERO
var _wait := 0.0
var _talk_t := 0.0
var _player: Node3D

func setup(look: String, who: String, said: Array[String], at: Vector3, isl: Island) -> void:
	display_name = who
	lines = said
	home = at
	island = isl
	_target = at

func _ready() -> void:
	add_to_group("villagers")
	add_to_group("interactables")
	collision_layer = 16
	collision_mask = 1 | 2
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3.UP * 0.9
	add_child(cs)
	model = CharacterModel.new()
	var look: String = LOOKS[absi(hash(display_name)) % LOOKS.size()]
	model.setup("res://assets/characters/%s.glb" % look, ["Mug"] if look == "Barbarian" else [])
	add_child(model)
	model.play("Idle")
	_wait = randf_range(0.0, 4.0)

func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
	_talk_t -= delta
	var near_player := _player != null and _player.global_position.distance_to(global_position) < 3.2
	var flat := Vector3.ZERO
	if near_player or _talk_t > 0.0:
		var to := (_player.global_position - global_position) * Vector3(1, 0, 1)
		model.rotation.y = lerp_angle(model.rotation.y, atan2(to.x, to.z), clampf(delta * 5.0, 0.0, 1.0))
		model.play("Idle" if _talk_t <= 0.0 else "Interact", 0.3)
	else:
		_wait -= delta
		var to := (_target - global_position) * Vector3(1, 0, 1)
		if to.length() > 0.6 and _wait <= 0.0:
			flat = to.normalized() * 1.25
			model.rotation.y = lerp_angle(model.rotation.y, atan2(to.x, to.z), clampf(delta * 5.0, 0.0, 1.0))
			model.play("Walking_A", 0.3, 0.75)
		else:
			model.play("Idle", 0.4)
			if _wait <= 0.0:
				_wait = randf_range(3.0, 9.0)
				_target = home + Vector3(randf_range(-9, 9), 0, randf_range(-9, 9))
	velocity.x = flat.x
	velocity.z = flat.z
	velocity.y = -0.5 if is_on_floor() else velocity.y - 19.0 * delta
	move_and_slide()

func prompt_text() -> String:
	return ("Trade with " if display_name.begins_with("Tobin") else "Talk to ") + display_name.split(" ")[0]

## What they say when spoken to: the next of their lines.
func talk() -> String:
	_talk_t = 3.0
	if lines.is_empty():
		return "..."
	var line: String = lines[0]
	lines.push_back(lines.pop_front())
	return line
