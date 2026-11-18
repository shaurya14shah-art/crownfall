class_name Ship
extends AnimatableBody3D
## A ship you can stand on, steer and fight. The hull is the model's own
## mesh as collision, so you can walk its decks while it sails; it moves as
## a kinematic body, carrying whoever stands on it.
##
## At the helm: W and S set the sails (furled, half, full), A and D the
## rudder, Space the anchor, left mouse fires a broadside toward the side
## you are looking at. Speed comes from the wind (Sea). It cannot sail onto
## land: the keel finds the shallows and stops.
##
## A hostile ship (the Drowned Galleon) sails a round of the isles and,
## when it sees your ship, circles it and fires as it passes.

signal sank

const SCALE := 1.6
const SINK := 1.95                  ## keel below the water, metres
const DECK := 2.1                   ## main deck, model units
const HELM := Vector3(0.0, 3.5, -4.5)
const MAX_SPEED := 15.0
const SAILS := [0.0, 0.55, 1.0]

var hostile := false
var model_name := "ship-pirate-medium"
var title := "The Gull"
var max_hull := 100.0
var hull := 100.0
var sail := 0
var speed := 0.0
var heading := 0.0
var rudder := 0.0
var steering := false
var anchored := true
var sunk := false
var home := Vector3.ZERO
var home_heading := 0.0
var route: Array[Vector3] = []      ## a hostile ship's round
var _route_i := 0
var _pos := Vector3.ZERO
var _t := 0.0
var _cool := {1: 0.0, -1: 0.0}
var _since_hit := 99.0
var _sink_t := 0.0
var _helm: ShipHelm
var _world: World
var cam_point: Node3D

func _ready() -> void:
	add_to_group("ships")
	add_to_group("enemy_ships" if hostile else "player_ship")
	collision_layer = 16
	collision_mask = 0
	sync_to_physics = true
	var ps := load("res://assets/ships/%s.glb" % model_name) as PackedScene
	var model := ps.instantiate() as Node3D
	model.scale = Vector3.ONE * SCALE
	add_child(model)
	# The hull (not the sails and flags) as walkable collision.
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if str(m.name) != model_name:
			continue
		var xf := m.transform
		var p := m.get_parent()
		while p != model and p is Node3D:
			xf = (p as Node3D).transform * xf
			p = p.get_parent()
		xf = Transform3D(Basis.from_scale(Vector3.ONE * SCALE), Vector3.ZERO) * xf
		var faces := m.mesh.get_faces()
		for i in faces.size():
			faces[i] = xf * faces[i]
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		add_child(cs)
	cam_point = Node3D.new()
	cam_point.position = Vector3(0, 7.0, 0)
	add_child(cam_point)
	if not hostile:
		_helm = ShipHelm.new()
		_helm.ship = self
		_helm.position = HELM * SCALE
		add_child(_helm)
		add_to_group("interactables")
	else:
		var glow := OmniLight3D.new()
		glow.light_color = Color(0.45, 1.0, 0.75)
		glow.light_energy = 2.0
		glow.omni_range = 18.0
		glow.position = Vector3(0, 8, 0)
		add_child(glow)
	hull = max_hull
	_pos = Vector3(home.x, 0.0, home.z)
	heading = home_heading
	_place()

func world() -> World:
	if _world == null:
		_world = get_tree().get_first_node_in_group("world") as World
	return _world

func forward() -> Vector3:
	return Vector3(sin(heading), 0.0, cos(heading))

## Where the one at the helm stands.
func helm_point() -> Vector3:
	return to_global(HELM * SCALE + Vector3(0, 0.1, 0))

## A spot on the main deck nearest `near` (for climbing aboard).
func deck_point(near: Vector3) -> Vector3:
	var l := to_local(near)
	return to_global(Vector3(clampf(l.x, -2.0, 2.0), DECK * SCALE + 0.3, clampf(l.z, -4.0, 3.5)))

func on_deck(p: Vector3) -> bool:
	var l := to_local(p)
	return absf(l.x) < 3.9 and absf(l.z) < 8.6 and l.y > DECK * SCALE - 0.6 and l.y < 9.0

# --- Interaction: climbing aboard ---------------------------------------------------------------

## How far `p` is from being able to climb aboard (from the pier or the water).
func interact_distance(p: Vector3) -> float:
	if hostile or sunk or on_deck(p):
		return INF
	var l := to_local(p)
	var dx := maxf(absf(l.x) - 3.8, 0.0)
	var dz := maxf(absf(l.z) - 8.0, 0.0)
	return Vector2(dx, dz).length() + (0.0 if l.y > -1.0 else 2.0)

func prompt_text() -> String:
	return "Climb aboard %s" % title

func interact(player: Node3D) -> void:
	player.global_position = deck_point(player.global_position)
	(player as Player).velocity = Vector3.ZERO
	(player as Player).reset_physics_interpolation()
	Run.flags["boarded"] = true
	Audio.play("door", global_position, -4.0, 0.7)

# --- Sailing --------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_t += delta
	if sunk:
		_sink_t += delta
		_pos.y -= delta * 1.4
		_place()
		return
	for k in _cool.keys():
		_cool[k] = maxf(0.0, float(_cool[k]) - delta)
	_since_hit += delta
	if steering:
		_helmsman(delta)
	elif hostile:
		_captain(delta)
	else:
		rudder = move_toward(rudder, 0.0, delta)
	var want := 0.0 if anchored else MAX_SPEED * float(SAILS[sail]) * Sea.efficiency(forward())
	speed = move_toward(speed, want, (2.2 if want > speed else (6.0 if anchored else 1.6)) * delta)
	heading += rudder * lerpf(0.16, 0.5, clampf(speed / 8.0, 0.0, 1.0)) * delta
	var next := _pos + forward() * speed * delta
	# The keel finds the shallows: no further that way.
	var bow := next + forward() * 8.0
	if world() != null and world().ground(bow.x, bow.z) > -2.4:
		if speed > 4.0:
			Audio.play("door", global_position, 4.0, 0.4)
			if steering:
				world().rig.shake(0.5)
		speed = 0.0
	else:
		_pos = next
	if not hostile and _since_hit > 12.0 and hull < max_hull:
		hull = minf(max_hull, hull + 1.5 * delta)
	_place()

func _place() -> void:
	var bob := sin(_t * 0.9) * 0.2 + sin(_t * 1.7 + 1.0) * 0.07
	var roll := sin(_t * 0.7) * 0.03 - rudder * clampf(speed / MAX_SPEED, 0.0, 1.0) * 0.07
	var pitch := sin(_t * 0.8 + 0.5) * 0.018
	var b := Basis(Vector3.UP, heading) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)
	if sunk:
		b = b * Basis(Vector3.BACK, minf(_sink_t * 0.08, 0.5))
	global_transform = Transform3D(b, Vector3(_pos.x, Sea.LEVEL - SINK + bob + _pos.y, _pos.z))

## The player's hands on the wheel.
func _helmsman(delta: float) -> void:
	if not Game.playing:
		return
	if Input.is_action_just_pressed("move_forward"):
		sail = mini(sail + 1, 2)
		anchored = false
		Audio.play("roll", global_position, -6.0, 0.8)
	elif Input.is_action_just_pressed("move_back"):
		sail = maxi(sail - 1, 0)
		Audio.play("roll", global_position, -6.0, 0.7)
	var turn := Input.get_axis("move_right", "move_left")
	rudder = move_toward(rudder, turn, delta * 1.6)
	if Input.is_action_just_pressed("jump"):
		anchored = not anchored
		Audio.play("door", global_position, -2.0, 0.5)
		Run.toast.emit("Anchor dropped" if anchored else "Anchor up", "item")
	if Input.is_action_just_pressed("attack"):
		var rig := world().rig
		var side := 1 if rig.forward_flat().dot(global_basis.x) > 0.0 else -1
		var lift := clampf(9.0 + (-rig.pitch - 0.25) * 22.0, 4.0, 18.0)
		fire(side, lift)
	Run.lean("seafaring", delta * 0.05)

## Three balls from one side, `lift` the upward speed (higher goes further).
func fire(side: int, lift: float = 9.0, aim: Vector3 = Vector3.INF) -> bool:
	if float(_cool[side]) > 0.0 or sunk:
		return false
	_cool[side] = 3.2 if not hostile else 4.5
	var out := global_basis.x * float(side)
	for k in 3:
		var at := to_global(Vector3(float(side) * 3.7, 3.4, -2.4 + k * 2.4))
		var b := Cannonball.new()
		b.from = self
		b.damage = 10.0 if not hostile else 8.0
		var dir := out
		if aim != Vector3.INF:
			dir = ((aim - at) * Vector3(1, 0, 1)).normalized()
		b.velocity = dir * 34.0 + Vector3.UP * lift + forward() * speed + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
		get_parent().add_child(b)
		b.global_position = at
		Fx.sparks(get_parent(), at, Color(0.9, 0.85, 0.7), 10)
	Audio.play("hit", global_position, 8.0, 0.45)
	if steering:
		world().rig.shake(0.4)
	return true

func damage(n: float) -> void:
	if sunk:
		return
	hull -= n
	_since_hit = 0.0
	if hull <= 0.0:
		_sink()

func _sink() -> void:
	sunk = true
	_sink_t = 0.0
	hull = 0.0
	speed = 0.0
	Audio.play("door", global_position, 6.0, 0.35)
	sank.emit()

## Back afloat where it belongs (after it sank, or when called to a stone).
func refloat(at: Vector3, yaw: float) -> void:
	sunk = false
	hull = max_hull
	speed = 0.0
	sail = 0
	anchored = true
	rudder = 0.0
	# A jump, not a voyage: whoever stands on deck comes along, gently.
	var p := get_tree().get_first_node_in_group("player") as Player
	var rider := p != null and on_deck(p.global_position)
	var local := to_local(p.global_position) if rider else Vector3.ZERO
	_pos = Vector3(at.x, 0.0, at.z)
	heading = yaw
	_place()
	reset_physics_interpolation()
	if rider:
		p.global_position = to_global(local)
		p.velocity = Vector3.ZERO
		p.reset_physics_interpolation()

# --- The Drowned Galleon's captain ------------------------------------------------------------------

func _captain(delta: float) -> void:
	anchored = false
	var mine := get_tree().get_first_node_in_group("player_ship") as Ship
	var engage := mine != null and not mine.sunk and mine.global_position.distance_to(global_position) < 150.0
	var goal: Vector3
	if engage:
		# Circle the prey at about 45 m, broadside on.
		var to := (mine.global_position - global_position) * Vector3(1, 0, 1)
		var tangent := Vector3(-to.z, 0, to.x).normalized()
		goal = mine.global_position - to.normalized() * 45.0 + tangent * 30.0
		sail = 2 if to.length() > 80.0 else 1
		var d := to.length()
		var side := 1 if to.dot(global_basis.x) > 0.0 else -1
		if d > 25.0 and d < 95.0 and absf(to.normalized().dot(forward())) < 0.45:
			var t := d / 34.0
			fire(side, Cannonball.GRAVITY * t * 0.5, mine.global_position + mine.forward() * mine.speed * t)
	else:
		if route.is_empty():
			return
		goal = route[_route_i]
		sail = 1
		if Vector2(goal.x, goal.z).distance_to(Vector2(_pos.x, _pos.z)) < 40.0:
			_route_i = (_route_i + 1) % route.size()
	var want := atan2(goal.x - _pos.x, goal.z - _pos.z)
	var diff := wrapf(want - heading, -PI, PI)
	# Keep off the land: turn hard if the way ahead is shallow.
	var probe := _pos + forward() * 30.0
	if world() != null and world().ground(probe.x, probe.z) > -4.0:
		diff = PI * 0.5
	rudder = move_toward(rudder, clampf(diff * 2.0, -1.0, 1.0), delta * 1.5)


## The wheel: take it, or let go of it.
class ShipHelm extends Node3D:
	var ship: Ship

	func _ready() -> void:
		add_to_group("interactables")

	func prompt_text() -> String:
		if ship.sunk:
			return ""
		return "Leave the helm" if ship.steering else "Take the helm"

	func interact(_player: Node3D) -> void:
		var main := get_tree().get_first_node_in_group("main")
		if main != null:
			main.call("leave_helm" if ship.steering else "take_helm", ship)
