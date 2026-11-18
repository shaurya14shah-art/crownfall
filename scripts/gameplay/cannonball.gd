class_name Cannonball
extends Node3D
## A shot from a ship's broadside: an iron ball on an arc. It holes the
## hull of the first other ship it reaches, knocks down anyone standing
## where it lands, and otherwise throws up water or dirt.

const GRAVITY := 9.8

var velocity := Vector3.ZERO
var from: Node3D
var damage := 9.0
var _t := 0.0

static var _ball: PackedScene

func _ready() -> void:
	if _ball == null:
		_ball = load("res://assets/ships/cannon-ball.glb") as PackedScene
	if _ball != null:
		var b := _ball.instantiate() as Node3D
		b.scale = Vector3.ONE * 0.8
		add_child(b)

func _physics_process(delta: float) -> void:
	_t += delta
	velocity.y -= GRAVITY * delta
	global_position += velocity * delta
	if _t > 8.0:
		queue_free()
		return
	for s in get_tree().get_nodes_in_group("ships"):
		var ship := s as Ship
		if ship == from or ship.sunk:
			continue
		var l := ship.to_local(global_position)
		if absf(l.x) < 3.9 and absf(l.z) < 8.6 and l.y > 0.0 and l.y < 9.0:
			ship.damage(damage)
			_burst(Color(1.0, 0.6, 0.3), 26)
			Audio.play("hit", global_position, 6.0, 0.55)
			_hurt_near(3.5)
			queue_free()
			return
	var w := get_tree().get_first_node_in_group("world") as World
	var ground := w.ground(global_position.x, global_position.z) if w != null else -INF
	if global_position.y < maxf(ground, Sea.LEVEL):
		if ground > Sea.LEVEL:
			_burst(Color(0.6, 0.5, 0.4), 18)
			_hurt_near(3.0)
		else:
			_burst(Color(0.85, 0.95, 1.0), 22)
		Audio.play("roll", global_position, 0.0, 0.6)
		queue_free()

## Whoever is standing where it lands is knocked about.
func _hurt_near(r: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p != null and p.global_position.distance_to(global_position) < r and from != null and from.get("hostile"):
		p.take_hit(16.0, self)

func _burst(col: Color, n: int) -> void:
	Fx.sparks(get_parent(), global_position + Vector3.UP * 0.3, col, n)
	var cam := get_tree().get_first_node_in_group("camera_rig") as CameraRig
	if cam != null and cam.global_position.distance_to(global_position) < 40.0:
		cam.shake(0.35)
