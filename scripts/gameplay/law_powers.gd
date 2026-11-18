class_name LawPowers
extends Node
## Your Inscription used in the open world: F for the manifest power, G for
## the hidden one once found. Checks the condition, pays the price, runs the
## effect, counts the use toward mastery. Also tracks the states the powers
## leave on you (stone skin, a reflecting guard, a held afterimage).

signal used(power: Dictionary)
signal refused(reason: String)

var player: Player
var cooldown := [0.0, 0.0, 0.0]
const OVERFLOW_CD := 40.0
var _aura_t := 0.0
var stone_t := 0.0
var reflect_t := 0.0
var empower_t := 0.0
var negate := false
var heal_left := 0.0
var _heal_rate := 0.0
var silence_t := 0.0
var _sigil: MeshInstance3D

func _process(delta: float) -> void:
	for i in 3:
		cooldown[i] = maxf(0.0, cooldown[i] - delta)
	stone_t = maxf(0.0, stone_t - delta)
	reflect_t = maxf(0.0, reflect_t - delta)
	empower_t = maxf(0.0, empower_t - delta)
	silence_t = maxf(0.0, silence_t - delta)
	if heal_left > 0.0:
		var h := minf(heal_left, _heal_rate * delta)
		heal_left -= h
		player.health = minf(player.max_health(), player.health + h)
		player.health_changed.emit(player.health, player.max_health())
	if not Game.playing or Run.law.is_empty() or player.state in [Player.S.DEAD, Player.S.SWIM, Player.S.CLIMB] \
			or player.helm != null:
		return
	if Input.is_action_just_pressed("law_1"):
		cast(0)
	elif Input.is_action_just_pressed("law_2"):
		cast(1)
	elif Input.is_action_just_pressed("law_3"):
		overflow()
	# Sovereign: foes near you are weakened, without your doing anything.
	if int(Run.law.get("rank", 2)) >= 5:
		_aura_t -= delta
		if _aura_t <= 0.0:
			_aura_t = 0.5
			for e in _enemies_within(6.5 * _reach()):
				if e.has_method("expose_for"):
					e.call("expose_for", 0.8)
				if e.has_method("slow_for"):
					e.call("slow_for", 0.6)

func ready_fraction(idx: int) -> float:
	if idx == 2:
		return 1.0 - cooldown[2] / OVERFLOW_CD
	var ps := Law.powers_of(Run.law)
	if idx >= ps.size():
		return 0.0
	return 1.0 - cooldown[idx] / maxf(_cd(ps[idx]), 0.01)

func _cd(p: Dictionary) -> float:
	var cd := float(p["cd"]) * (1.0 + Run.perk("cooldown"))
	if (Run.law.get("dims", {}) as Dictionary).has("complexity"):
		cd *= 0.85
	if Run.law.get("price", "") == "heat":
		cd *= 1.3
	return cd

func _reach() -> float:
	return 1.25 if (Run.law.get("dims", {}) as Dictionary).has("reach") else 1.0

func cast(idx: int) -> void:
	var l := Run.law
	if not Law.found(l, idx):
		return
	var p: Dictionary = Law.powers_of(l)[idx]
	if cooldown[idx] > 0.0:
		return
	var target := _target()
	var why := _condition_fails(str(l["condition"]), target)
	if why != "":
		refused.emit(why)
		return
	cooldown[idx] = _cd(p)
	_pay(str(l["price"]))
	var s := Law.strength(l)
	var col := Law.colour(str(l["principle"]))
	_burst(col)
	match str(p["kind"]):
		"dash_strike": _dash_strike(s)
		"reflect": reflect_t = 5.0 * s
		"empower": empower_t = 5.0
		"stoneskin": stone_t = 6.0 * s
		"barrier": _barrier(s, col)
		"blink": _blink()
		"slow": _slow(s)
		"negate": negate = true
		"heal": _heal_over(35.0 * s, 4.0)
		"surge":
			player.stamina = player.max_stamina()
			stone_t = maxf(stone_t, 4.0)
			_heal_over(15.0 * s, 2.0)
		"expose": _expose(s)
		"decoy": _decoy(col)
		"bind": _bind(target, s)
		"burst": _oath_burst(s)
		"pull": _pull(target, s)
		"wave": _wave(s)
	Law.practise(l, str(p["id"]))
	# Ascendant: one use readies the other.
	if int(l["rank"]) >= 3:
		cooldown[1 - idx] *= 0.5
	Audio.play("heal", player.global_position, -2.0, 0.7)
	used.emit(p)
	Run.changed.emit("law")

## Exalted: the Law spills out of you all at once.
func overflow() -> void:
	if int(Run.law.get("rank", 2)) < 4 or cooldown[2] > 0.0:
		return
	cooldown[2] = OVERFLOW_CD * (1.0 + Run.perk("cooldown"))
	var s := Law.strength(Run.law)
	var col := Law.colour(str(Run.law["principle"]))
	for k in 3:
		var ring := LawRing.new()
		ring.colour = col
		ring.radius = 4.0 + k * 2.0
		ring.life = 0.6 + k * 0.15
		ring.expanding = true
		player.get_parent().add_child(ring)
		ring.global_position = player.global_position + Vector3.UP * 0.1
	for e in _enemies_within(10.0 * _reach()):
		e.call("take_hit", 45.0 * s, player)
		if e.has_method("stagger"):
			e.call("stagger")
		if e.has_method("knock"):
			e.call("knock", ((e as Node3D).global_position - player.global_position).normalized() * 12.0)
	Fx.hit_stop(0.12)
	if player.rig != null:
		player.rig.shake(1.0)
	Law.practise(Run.law, "overflow")
	Run.changed.emit("law")

# --- Conditions and prices ---------------------------------------------------------

func _target() -> Node3D:
	return player.nearest_enemy(14.0 * _reach())

func _condition_fails(c: String, target: Node3D) -> String:
	match c:
		"contact":
			if target == null or target.global_position.distance_to(player.global_position) > 3.2:
				return "You must be touching what you act on"
		"sight":
			if target == null:
				return "There is nothing in sight to act on"
		"stillness":
			if Vector2(player.velocity.x, player.velocity.z).length() > 0.8:
				return "You must be still"
		"spoken":
			if silence_t > 0.0:
				return "You cannot speak"
		"near_water":
			if not _near_water():
				return "There is no water near enough"
		"named":
			if target != null and target.has_method("kind_name"):
				if not Run.archive["bestiary"].has(str(target.call("kind_name"))):
					return "You do not know its name yet"
		"night":
			var sky := player.get_tree().get_first_node_in_group("sky") as SkyRig
			if sky != null and not sky.is_night():
				return "It answers only at night"
	return ""

func _near_water() -> bool:
	var w := player.get_tree().get_first_node_in_group("world") as World
	if w == null:
		return false
	var p := player.global_position
	for k in 12:
		var a := TAU * float(k) / 12.0
		for r in [20.0, 45.0, 70.0]:
			if w.island.height_at(p.x + sin(a) * r, p.z + cos(a) * r) < 0.0:
				return true
	return false

func _pay(price: String) -> void:
	var lighter := 1.0 + Run.perk("price")
	var def := Law.price_def(price)
	var costs: Dictionary = def.get("costs", {})
	if costs.has("stamina"):
		player.stamina = maxf(0.0, player.stamina - float(costs["stamina"]) * lighter)
	if costs.has("health"):
		player.health = maxf(1.0, player.health - float(costs["health"]) * lighter)
		player.health_changed.emit(player.health, player.max_health())
	if Run.law["condition"] == "held_breath":
		player.stamina = maxf(0.0, player.stamina - 10.0)
	match price:
		"mark":
			Run.law["mark"] = int(Run.law["mark"]) + 1
		"silence":
			silence_t = 90.0 * lighter
		"conservation":
			player.health = maxf(1.0, player.health - 5.0 * lighter)
			player.health_changed.emit(player.health, player.max_health())
		"debt":
			player.stamina = maxf(0.0, player.stamina - 12.0 * lighter)
		"memory":
			pass

# --- Effects ------------------------------------------------------------------------

func _enemies_within(r: float) -> Array:
	var out := []
	for e in player.get_tree().get_nodes_in_group("enemies"):
		var n := e as Node3D
		if n.has_method("is_dead") and bool(n.call("is_dead")):
			continue
		if n.global_position.distance_to(player.global_position) <= r:
			out.append(n)
	return out

func _dash_strike(s: float) -> void:
	var fwd := player.model.global_basis.z
	var foe := player.nearest_enemy(9.0)
	if foe != null:
		fwd = ((foe.global_position - player.global_position) * Vector3(1, 0, 1)).normalized()
		player.model.rotation.y = atan2(fwd.x, fwd.z)
	var from := player.global_position
	player.velocity = fwd * 24.0
	player.dash(0.3)
	for e in _enemies_within(10.0):
		var to: Vector3 = (e as Node3D).global_position - from
		if fwd.dot(to.normalized()) > 0.6 and to.length() < 9.0:
			e.call("take_hit", 30.0 * s, player)
	Fx.hit_stop(0.06)

func _barrier(s: float, col: Color) -> void:
	var ring := LawRing.new()
	ring.colour = col
	ring.radius = 5.5 * _reach()
	ring.life = 5.0 * s
	player.get_parent().add_child(ring)
	ring.global_position = player.global_position

func _blink() -> void:
	var dir := Vector3(player.velocity.x, 0, player.velocity.z)
	if dir.length() < 0.5:
		dir = player.model.global_basis.z
	var to := player.global_position + dir.normalized() * 8.0 * _reach()
	var w := player.get_tree().get_first_node_in_group("world") as World
	if w != null:
		to.y = w.island.height_at(to.x, to.z) + 0.2
	_burst(Law.colour("boundary"))
	player.global_position = to
	player.reset_physics_interpolation()

func _slow(s: float) -> void:
	for e in _enemies_within(15.0 * _reach()):
		if e.has_method("slow_for"):
			e.call("slow_for", 4.0 * s)

func _heal_over(amount: float, seconds: float) -> void:
	heal_left += amount * (1.0 + Run.perk("potion") * 0.5)
	_heal_rate = heal_left / seconds

func _expose(s: float) -> void:
	for e in _enemies_within(20.0 * _reach()):
		if e.has_method("expose_for"):
			e.call("expose_for", 8.0 * s)

func _decoy(col: Color) -> void:
	var d := LawDecoy.new()
	d.colour = col
	player.get_parent().add_child(d)
	d.global_position = player.global_position
	d.rotation.y = player.model.rotation.y

func _bind(target: Node3D, s: float) -> void:
	if target != null and target.has_method("bind_for"):
		target.call("bind_for", 4.0 * s)

func _oath_burst(s: float) -> void:
	for e in _enemies_within(25.0 * _reach()):
		if e.has_method("is_bound") and bool(e.call("is_bound")):
			e.call("take_hit", 60.0 * s, player)

func _pull(target: Node3D, s: float) -> void:
	if target == null:
		return
	var to := player.global_position + player.model.global_basis.z * 1.6
	if target.has_method("yank_to"):
		target.call("yank_to", to)
	target.call("take_hit", 12.0 * s, player)
	Law.notice(Run.law, "pulls")

func _wave(s: float) -> void:
	var fwd := player.model.global_basis.z
	for e in _enemies_within(9.0 * _reach()):
		var to: Vector3 = ((e as Node3D).global_position - player.global_position)
		if fwd.dot(to.normalized()) > 0.2:
			e.call("take_hit", 25.0 * s, player)
			if e.has_method("knock"):
				e.call("knock", to.normalized() * 14.0)

## A ring of the principle's colour bursting out from the player.
func _burst(col: Color) -> void:
	var b := LawRing.new()
	b.colour = col
	b.radius = 3.0
	b.life = 0.5
	b.expanding = true
	player.get_parent().add_child(b)
	b.global_position = player.global_position + Vector3.UP * 0.1
