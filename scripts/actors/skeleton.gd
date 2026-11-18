class_name Skeleton
extends CharacterBody3D
## The risen dead. Wanders near where it rose; notices you within sight;
## closes in; winds up a blow you can see coming; staggers when struck hard
## or parried; and falls apart when it dies, dropping what it carried, to
## rise again later. The Barrow Warden is one of them, larger, and does not
## rise again.
##
## Answers every Law: it can be slowed, exposed, bound, pulled and thrown.
##
## Stance: blows fill it (heavy and leaping ones far more); when it is full
## the stance breaks and it reels, open to a critical blow. It recovers if
## left alone. The fallen stay down until you rest at a Waystone.

signal slain(camp: String)

enum S { IDLE, CHASE, WINDUP, STRIKE, STAGGER, DEAD, BROKEN }

const KINDS := {
	"minion": {"model": "Skeleton_Minion", "name": "Risen Minion", "hp": 45.0, "dmg": 7.0, "speed": 3.3,
		"weapon": "Skeleton_Blade", "shield": "", "scale": 1.0},
	"warrior": {"model": "Skeleton_Warrior", "name": "Risen Warrior", "hp": 80.0, "dmg": 12.0, "speed": 3.0,
		"weapon": "Skeleton_Axe", "shield": "Skeleton_Shield_Small_A", "scale": 1.0},
	"rogue": {"model": "Skeleton_Rogue", "name": "Risen Rogue", "hp": 50.0, "dmg": 9.0, "speed": 3.9,
		"weapon": "Skeleton_Blade", "shield": "", "scale": 1.0},
	"warden": {"model": "Skeleton_Warrior", "name": "The Barrow Warden", "hp": 420.0, "dmg": 20.0, "speed": 3.0,
		"weapon": "Skeleton_Axe", "shield": "Skeleton_Shield_Large_A", "scale": 1.65, "boss": true, "slam": true},
	"tidewarden": {"model": "Skeleton_Mage", "name": "The Tidewarden", "hp": 560.0, "dmg": 20.0, "speed": 3.0,
		"weapon": "Skeleton_Staff", "shield": "", "scale": 1.8, "boss": true, "slam": true, "summon": "minion",
		"glow": Color(0.4, 0.8, 1.0)},
	"bellwright": {"model": "Skeleton_Warrior", "name": "The Bellwright", "hp": 800.0, "dmg": 24.0, "speed": 3.1,
		"weapon": "Skeleton_Axe", "shield": "Skeleton_Shield_Large_B", "scale": 1.9, "boss": true, "slam": true,
		"summon": "rogue", "glow": Color(1.0, 0.7, 0.35)},
	"crownless": {"model": "Skeleton_Rogue", "name": "The Crownless King", "hp": 1200.0, "dmg": 28.0, "speed": 3.6,
		"weapon": "Skeleton_Blade", "shield": "", "scale": 2.0, "boss": true, "slam": true, "summon": "warrior",
		"glow": Color(0.8, 0.55, 1.0)},
	# Field bosses: out in the world, not in a Gate.
	"grave_knight": {"model": "Skeleton_Warrior", "name": "The Night's Grave Knight", "hp": 540.0, "dmg": 18.0,
		"speed": 3.4, "weapon": "Skeleton_Axe", "shield": "Skeleton_Shield_Large_B", "scale": 1.45, "boss": true,
		"slam": true, "glow": Color(0.45, 1.0, 0.6),
		"drops": [["night_greatsword", 1], ["star_iron", 2], ["hearth_seed", 1]]},
	"drowned_captain": {"model": "Skeleton_Rogue", "name": "The Drowned Captain", "hp": 480.0, "dmg": 16.0,
		"speed": 3.8, "weapon": "Skeleton_Blade", "shield": "", "scale": 1.5, "boss": true, "slam": true,
		"summon": "rogue", "glow": Color(0.4, 0.85, 1.0),
		"drops": [["tidecaller_buckler", 1], ["star_iron", 2], ["bright_tear", 1], ["rime_salt", 3]]},
	"corsair": {"model": "Skeleton_Rogue", "name": "Drowned Corsair", "hp": 60.0, "dmg": 10.0, "speed": 3.7,
		"weapon": "Skeleton_Blade", "shield": "", "scale": 1.0},
	# A thief with a sack of the dead's silver: runs, never fights, and drops
	# coin every time it is struck. Catch it before it slips into a rift.
	"thief": {"model": "Skeleton_Rogue", "name": "Grave Thief", "hp": 75.0, "dmg": 0.0, "speed": 6.3,
		"weapon": "", "shield": "", "scale": 0.9, "glow": Color(1.0, 0.82, 0.35)},
}
## Renown for putting one down (Elites give three times as much).
const XP := {"minion": 10.0, "rogue": 12.0, "warrior": 16.0, "warden": 250.0, "tidewarden": 400.0, "bellwright": 600.0,
	"crownless": 900.0, "grave_knight": 350.0, "drowned_captain": 300.0, "thief": 70.0, "corsair": 14.0}
## Elite traits. An Elite has one (two, once your Renown is 6).
const AFFIXES := {
	"swift": {"name": "Swift", "colour": Color(0.55, 0.9, 1.0)},
	"hulking": {"name": "Hulking", "colour": Color(1.0, 0.6, 0.35)},
	"brutal": {"name": "Brutal", "colour": Color(1.0, 0.35, 0.3)},
	"warded": {"name": "Warded", "colour": Color(0.85, 0.85, 1.0)},
	"vampiric": {"name": "Vampiric", "colour": Color(0.75, 0.2, 0.45)},
}
const THIEF_TIME := 26.0
const LOOT := [["bone_shard", 0.65, 1, 2], ["grave_dust", 0.22, 1, 1], ["red_potion", 0.10, 1, 1],
	["iron_scrap", 0.4, 1, 2], ["ember_coal", 0.07, 1, 1], ["rime_salt", 0.07, 1, 1]]
const BROKEN_TIME := 2.4
const FALLEN_FOR := 300.0         ## seconds a fallen one waits if you never rest
const SIGHT := 13.0
const GRAVITY := 19.0

var kind := "minion"
var camp := ""
var health_mult := 1.0
var damage_mult := 1.0
var respawns := true
var aggressive := false
var _slam_t := 4.0
var _slamming := -1.0
var _summoned := 0
var home := Vector3.ZERO
var state := S.IDLE
var health := 55.0
var max_health := 55.0
var model: CharacterModel
var _t := 0.0
var _wander := Vector3.ZERO
var _wander_t := 0.0
var _cooldown := 0.0
var _struck := false
var _player: Player
var _slow_t := 0.0
var _expose_t := 0.0
var _bind_t := 0.0
var _knock := Vector3.ZERO
var _was_bound := false
var posture := 0.0
var max_posture := 40.0
var _posture_calm := 0.0          ## seconds since its stance was last struck
var _burn_t := 0.0
var _burn_dps := 0.0
var _burn_tick := 0.0
var _chill_t := 0.0
var elite := false
var affixes: Array = []
var _shape: CapsuleShape3D
var _cs: CollisionShape3D
var _elite_glow: OmniLight3D
var _flee_t := -1.0               ## a thief's time left before it escapes, once seen

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 8
	collision_mask = 1 | 2 | 8
	floor_snap_length = 0.5
	var def: Dictionary = KINDS[kind]
	var sc := float(def["scale"])
	_shape = CapsuleShape3D.new()
	_cs = CollisionShape3D.new()
	_cs.shape = _shape
	add_child(_cs)
	model = CharacterModel.new()
	model.setup("res://assets/enemies/%s.glb" % def["model"], [], 0.85 * sc)
	add_child(model)
	_hold(str(def["weapon"]), "handslot.r")
	if str(def["shield"]) != "":
		_hold(str(def["shield"]), "handslot.l")
	_roll_elite()
	if kind == "thief":
		add_to_group("thieves")
		var gold := OmniLight3D.new()
		gold.light_color = def["glow"]
		gold.light_energy = 1.6
		gold.omni_range = 5.0
		gold.position = Vector3(0, 1.6, 0)
		add_child(gold)
	if is_boss():
		add_to_group("boss")
		var glow := OmniLight3D.new()
		glow.light_color = def.get("glow", Color(0.5, 0.8, 1.0))
		glow.light_energy = 1.2
		glow.omni_range = 6.0
		glow.position = Vector3(0, 2.6, 0)
		add_child(glow)
	_wander = home
	model.play(_clip("Idle_Combat", "Idle"))
	model.rotation.y = randf() * TAU

func is_boss() -> bool:
	return bool(KINDS[kind].get("boss", false))

func kind_name() -> String:
	if not elite:
		return str(KINDS[kind]["name"])
	var words: Array[String] = []
	for a in affixes:
		words.append(str(AFFIXES[a]["name"]))
	return "%s %s" % [" ".join(words), KINDS[kind]["name"]]

## Ordinary camp skeletons are sometimes Elites: tougher, with a trait or
## two, a light about them, and much better loot. Rolled again each time
## one rises. Sets health, stance and size either way.
func _roll_elite() -> void:
	affixes.clear()
	elite = false
	if respawns and not is_boss() and kind != "thief":
		var chance := 0.09 + minf(0.06, Run.renown_level * 0.004)
		if Run.surge:
			chance *= 2.5
		if randf() < chance:
			elite = true
			var keys := AFFIXES.keys()
			keys.shuffle()
			affixes = keys.slice(0, 2 if Run.renown_level >= 6 else 1)
	var def: Dictionary = KINDS[kind]
	var sc := float(def["scale"]) * (1.22 if "hulking" in affixes else (1.1 if elite else 1.0))
	max_health = float(def["hp"]) * health_mult * ((1.6 if elite else 1.0) * (2.0 if "hulking" in affixes else 1.0))
	health = max_health
	max_posture = float(def.get("poise", float(def["hp"]) * (0.5 if bool(def.get("boss", false)) else 0.75)))
	max_posture *= (2.2 if "warded" in affixes else 1.0) * (1.4 if elite else 1.0)
	_shape.radius = 0.38 * sc
	_shape.height = 1.8 * sc
	_cs.position = Vector3.UP * 0.9 * sc
	model.scale = Vector3.ONE * (sc / float(def["scale"]))
	if elite and _elite_glow == null:
		_elite_glow = OmniLight3D.new()
		_elite_glow.light_energy = 1.4
		_elite_glow.omni_range = 4.5
		_elite_glow.position = Vector3(0, 2.2 * sc, 0)
		add_child(_elite_glow)
	if _elite_glow != null:
		_elite_glow.visible = elite
		if elite:
			_elite_glow.light_color = AFFIXES[affixes[0]]["colour"]

func _speed() -> float:
	return float(KINDS[kind]["speed"]) * (1.4 if "swift" in affixes else 1.0)

func _damage() -> float:
	return float(KINDS[kind]["dmg"]) * damage_mult * (1.45 if "brutal" in affixes else (1.15 if elite else 1.0))

## Something it struck was hurt: Vampiric Elites drink from it.
func _dealt(dmg: float) -> void:
	if "vampiric" in affixes:
		health = minf(max_health, health + dmg * 0.6)

func _hold(item: String, bone: String) -> void:
	if item == "":
		return
	if model.skeleton == null or model.skeleton.find_bone(bone) < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	model.skeleton.add_child(att)
	var ps := load("res://assets/enemy_gear/%s.gltf" % item) as PackedScene
	if ps != null:
		att.add_child(ps.instantiate())

func _clip(want: String, fallback: String) -> String:
	return want if model.has(want) else fallback

func is_dead() -> bool:
	return state == S.DEAD

func is_staggered() -> bool:
	return state == S.STAGGER or state == S.BROKEN

func is_broken() -> bool:
	return state == S.BROKEN

func posture_fraction() -> float:
	return posture / maxf(max_posture, 1.0)

## Fills the stance; when it is full the stance breaks.
func add_posture(amount: float) -> void:
	if state == S.DEAD or state == S.BROKEN:
		return
	posture += amount
	_posture_calm = 0.0
	if posture >= max_posture:
		_break_stance()
		Run.record("break")
		Run.renown(4.0)

func _break_stance() -> void:
	posture = 0.0
	state = S.BROKEN
	_t = 0.0
	_slamming = -1.0
	model.play(_clip("Hit_B", "Hit_A"), 0.05, 0.55, true)
	Audio.play("block", global_position, 4.0, 0.55)
	Fx.sparks(get_parent(), global_position + Vector3.UP * 1.4 * float(KINDS[kind]["scale"]), Color(1.0, 0.85, 0.4), 26)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.call("pop_text", global_position + Vector3.UP * 2.4 * float(KINDS[kind]["scale"]), "STANCE BROKEN",
			Color(1.0, 0.8, 0.4))

## A critical blow while its stance is broken.
func critical(damage: float, from: Node3D) -> void:
	if state != S.BROKEN:
		take_hit(damage, from)
		return
	state = S.STAGGER
	_t = 0.0
	health -= damage
	_hud_number(global_position + Vector3.UP * 2.0 * float(KINDS[kind]["scale"]), damage, Color(1.0, 0.8, 0.3), true)
	model.play(_clip("Hit_A", "Hit_B"), 0.04, 1.0, true)
	if not is_boss():
		velocity = ((global_position - from.global_position) * Vector3(1, 0, 1)).normalized() * 6.0
	if health <= 0.0:
		_die()
	elif is_boss():
		_maybe_summon()

func burn_for(t: float, dps: float) -> void:
	if state == S.DEAD:
		return
	_burn_t = maxf(_burn_t, t)
	_burn_dps = maxf(_burn_dps, dps)

func chill_for(t: float) -> void:
	_chill_t = maxf(_chill_t, t)
	slow_for(t * 0.6)

func is_bound() -> bool:
	return _bind_t > 0.0

func health_fraction() -> float:
	return health / max_health

# --- What the Laws do to it ------------------------------------------------------

func slow_for(t: float) -> void:
	_slow_t = maxf(_slow_t, t)

func expose_for(t: float) -> void:
	_expose_t = maxf(_expose_t, t)

func bind_for(t: float) -> void:
	_bind_t = maxf(_bind_t, t)
	_was_bound = true

func knock(v: Vector3) -> void:
	_knock = v * (0.35 if is_boss() else 1.0)

func yank_to(at: Vector3) -> void:
	if is_boss():
		return
	global_position = Vector3(at.x, global_position.y, at.z)
	reset_physics_interpolation()

func stagger() -> void:
	if state == S.DEAD:
		return
	state = S.STAGGER
	_t = 0.0
	model.play(_clip("Hit_B", "Hit_A"), 0.05, 1.0, true)

# --- Behaviour ------------------------------------------------------------------

## Who it is fighting: a False Image if one is near, otherwise you.
func _foe() -> Node3D:
	for d in get_tree().get_nodes_in_group("decoys"):
		if (d as Node3D).global_position.distance_to(global_position) < 14.0:
			return d as Node3D
	return _player

func _physics_process(delta: float) -> void:
	if state == S.DEAD and not visible:
		# Fallen and gone: back when you rest, or after a long while.
		_t += delta
		if _t > FALLEN_FOR:
			_respawn()
		return
	_ailments(delta)
	var time_scale := 0.3 if _slow_t > 0.0 else 1.0
	_slow_t -= delta
	_expose_t -= delta
	_bind_t -= delta
	_t += delta * time_scale
	_cooldown -= delta * time_scale
	_slam_t -= delta * time_scale
	if _slamming > 0.0:
		_slamming -= delta * time_scale
		if _slamming <= 0.0 and state != S.DEAD:
			_land_slam()
	if model.anim != null and state != S.DEAD:
		model.anim.speed_scale = time_scale * (1.3 if state == S.STRIKE else 1.0) * (0.0 if _bind_t > 0.0 else 1.0)
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	var foe := _foe()
	var to := Vector3.ZERO
	var dist := 1e9
	if foe != null:
		to = (foe.global_position - global_position) * Vector3(1, 0, 1)
		dist = to.length()
	var reach := 2.1 * float(KINDS[kind]["scale"])
	var flat := Vector3.ZERO
	if _bind_t > 0.0 and state != S.DEAD:
		state = S.CHASE if state != S.STAGGER else state
	else:
		match state:
			S.IDLE:
				_wander_t -= delta
				if _wander_t <= 0.0:
					_wander_t = randf_range(3.0, 7.0)
					_wander = home + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
				var w := (_wander - global_position) * Vector3(1, 0, 1)
				if w.length() > 1.0:
					flat = w.normalized() * 1.2
					_face(w, delta, 4.0)
					model.play(_clip("Walking_D_Skeletons", "Walking_A"), 0.25)
				else:
					model.play(_clip("Idle_Combat", "Idle"), 0.3)
				if dist < (40.0 if aggressive else (20.0 if kind == "thief" else SIGHT)) and _player.state != Player.S.DEAD \
						and Game.playing:
					state = S.CHASE
					Audio.play("bones", global_position, -4.0)
			S.CHASE:
				if kind == "thief":
					flat = _flee(to, dist, delta)
				elif _player.state == Player.S.DEAD or (dist > SIGHT * 1.8 and not aggressive) or not Game.playing:
					state = S.IDLE
				elif is_boss() and bool(KINDS[kind].get("slam", false)) and _slam_t <= 0.0 and dist < 9.0:
					_start_slam()
				elif dist < reach and _cooldown <= 0.0:
					state = S.WINDUP
					_t = 0.0
					model.play(_clip("2H_Melee_Attack_Chop", "1H_Melee_Attack_Chop") if is_boss() else "1H_Melee_Attack_Chop",
						0.12, 0.45, true)
				else:
					var speed := _speed()
					if dist > reach * 0.8:
						flat = to.normalized() * speed
					_face(to, delta, 8.0)
					model.play(_clip("Running_A", "Walking_A") if dist > 4.0 else _clip("Idle_Combat", "Idle"), 0.2)
			S.WINDUP:
				_face(to, delta, 3.0)
				if _t > (1.0 if is_boss() else 0.8) * (0.72 if "swift" in affixes else 1.0):
					state = S.STRIKE
					_t = 0.0
					_struck = false
			S.STRIKE:
				flat = model.global_basis.z * 2.0 * (1.0 - smoothstep(0.0, 0.25, _t))
				if not _struck and _t > 0.12:
					_struck = true
					if foe != null and dist < reach + 0.6 and model.global_basis.z.dot(to.normalized()) > 0.35:
						var dmg := _damage()
						if foe == _player:
							if _player.take_hit(dmg, self):
								_dealt(dmg)
								_hud_number(_player.global_position + Vector3.UP * 1.9, dmg, Color(1.0, 0.35, 0.3))
						else:
							foe.queue_free()
				if _t > 0.55:
					state = S.CHASE
					_cooldown = randf_range(1.5, 2.6) * (0.8 if is_boss() else 1.0)
			S.STAGGER:
				flat = Vector3(velocity.x, 0, velocity.z) * 0.85
				if _t > 0.7:
					state = S.CHASE
			S.BROKEN:
				flat = Vector3(velocity.x, 0, velocity.z) * 0.8
				if _t > BROKEN_TIME * (1.2 if is_boss() else 1.0):
					state = S.CHASE
					_cooldown = 0.6
			S.DEAD:
				flat = Vector3.ZERO
				if _t > 6.0 and not is_boss():
					position.y -= delta * 0.6
				if _t > 9.0 and not is_boss():
					if respawns:
						visible = false
						add_to_group("fallen")
					else:
						queue_free()
	flat *= time_scale
	if _knock.length() > 0.1:
		flat += _knock
		_knock = _knock.move_toward(Vector3.ZERO, 30.0 * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()

## The boss's slam: a red ring races out on the ground for a second; when it
## lands, anyone inside it who is not rolling is hurt and knocked back.
func _start_slam() -> void:
	_slam_t = randf_range(6.0, 9.0)
	_slamming = 1.35
	state = S.WINDUP
	_t = -0.5
	model.play(_clip("2H_Melee_Attack_Spinning", "1H_Melee_Attack_Jump_Chop"), 0.1, 0.8, true)
	var ring := LawRing.new()
	ring.colour = Color(1.0, 0.25, 0.2)
	ring.radius = 3.4 * float(KINDS[kind]["scale"])
	ring.life = 1.35
	ring.expanding = true
	get_parent().add_child(ring)
	ring.global_position = global_position + Vector3.UP * 0.1

func _land_slam() -> void:
	var reach := 6.5 * float(KINDS[kind]["scale"]) * 0.6
	Fx.sparks(get_parent(), global_position + Vector3.UP * 0.3, Color(1.0, 0.5, 0.3), 40)
	Audio.play("hit", global_position, 4.0, 0.6)
	var cam := get_tree().get_first_node_in_group("camera_rig") as CameraRig
	if cam != null:
		cam.shake(0.8)
	if _player != null and _player.global_position.distance_to(global_position) < reach:
		var dmg := _damage()
		if _player.take_hit(dmg, self):
			_hud_number(_player.global_position + Vector3.UP * 1.9, dmg, Color(1.0, 0.35, 0.3), true)

## At half and a quarter of its health, a boss calls others to it.
func _maybe_summon() -> void:
	var what := str(KINDS[kind].get("summon", ""))
	if what == "":
		return
	var thresholds := [0.5, 0.25]
	if _summoned < thresholds.size() and health / max_health < float(thresholds[_summoned]):
		_summoned += 1
		for k in 2:
			var sk := Skeleton.new()
			sk.kind = what
			sk.health_mult = health_mult
			sk.damage_mult = damage_mult
			sk.respawns = false
			sk.aggressive = true
			var at := global_position + Vector3(sin(float(k) * PI) * 4.0 + 2.0, 0.5, cos(float(k) * PI) * 4.0)
			sk.home = at
			get_parent().add_child(sk)
			sk.global_position = at
		Audio.play("bones", global_position, 6.0, 0.5)

func _face(dir: Vector3, delta: float, rate: float) -> void:
	if dir.length() < 0.01:
		return
	model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), clampf(rate * delta, 0.0, 1.0))

## Burning and chill from etched weapons; the stance settling when left alone.
func _ailments(delta: float) -> void:
	_chill_t -= delta
	_posture_calm += delta
	if _posture_calm > 2.5 and posture > 0.0 and state != S.BROKEN:
		posture = maxf(0.0, posture - max_posture * 0.18 * delta)
	if _burn_t > 0.0 and state != S.DEAD:
		_burn_t -= delta
		_burn_tick -= delta
		if _burn_tick <= 0.0:
			_burn_tick = 1.0
			health -= _burn_dps
			_hud_number(global_position + Vector3.UP * 1.8 * float(KINDS[kind]["scale"]), _burn_dps, Color(1.0, 0.55, 0.2))
			Fx.sparks(get_parent(), global_position + Vector3.UP * 1.0, Color(1.0, 0.5, 0.15), 6)
			if health <= 0.0:
				_die()

## `stance` is how much the blow fills its stance (default: most of the damage).
func take_hit(damage: float, from: Node3D, stance: float = -1.0) -> void:
	if state == S.DEAD:
		return
	if _expose_t > 0.0:
		damage *= 1.25
	if _chill_t > 0.0:
		damage *= 1.15
	if state == S.BROKEN:
		damage *= 1.2
	health -= damage
	if kind == "thief" and health > 0.0:
		Pickup.spawn(get_parent(), global_position + Vector3.UP, "silver", randi_range(2, 6))
	_hud_number(global_position + Vector3.UP * 2.0 * float(KINDS[kind]["scale"]), damage, Color(1, 0.95, 0.85),
		damage >= 30.0)
	var push := (global_position - from.global_position) * Vector3(1, 0, 1)
	if not is_boss():
		velocity = push.normalized() * 4.5
	Audio.play("bones", global_position, -2.0, randf_range(0.9, 1.15))
	if health <= 0.0:
		_die()
		return
	if state != S.BROKEN:
		add_posture(stance if stance >= 0.0 else damage * 0.6)
		if state == S.BROKEN:
			return
	else:
		return
	if (state != S.STRIKE or damage >= 30.0) and not is_boss():
		state = S.STAGGER
		_t = 0.0
		model.play(_clip("Hit_A", "Hit_B"), 0.06, 1.2, true)
	elif is_boss() and damage >= 60.0:
		stagger()
	if is_boss():
		_maybe_summon()
	if state == S.IDLE:
		state = S.CHASE

## A Grave Thief, seen: runs from you, weaving, away from the sea, until
## its time is up and it slips into a rift with everything it carried.
func _flee(to: Vector3, dist: float, delta: float) -> Vector3:
	if _flee_t < 0.0:
		_flee_t = THIEF_TIME
		Run.toast.emit("A Grave Thief! Catch it before it escapes", "skill")
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null:
			hud.call("pop_text", global_position + Vector3.UP * 2.4, "GRAVE THIEF", Color(1.0, 0.82, 0.35))
	_flee_t -= delta
	if _flee_t <= 0.0:
		Fx.sparks(get_parent(), global_position + Vector3.UP, Color(1.0, 0.82, 0.35), 40)
		Audio.play("door", global_position, 0.0, 1.6)
		Run.toast.emit("The Grave Thief slipped away", "warn")
		queue_free()
		return Vector3.ZERO
	var away := (-to.normalized() if dist > 0.1 else Vector3.FORWARD).rotated(Vector3.UP, sin(_t * 1.3) * 0.6)
	var w := get_tree().get_first_node_in_group("world") as World
	if w != null:
		for k in 4:
			var ahead := global_position + away * 5.0
			if w.island.height_at(ahead.x, ahead.z) > 0.8:
				break
			away = away.rotated(Vector3.UP, PI * 0.5)
	_face(away, delta, 10.0)
	model.play(_clip("Running_A", "Walking_A"), 0.15, 1.3)
	return away * _speed() * (0.6 if dist > 28.0 else 1.0)

func _die() -> void:
	state = S.DEAD
	_t = 0.0
	collision_layer = 0
	model.anim.speed_scale = 1.0
	model.play(_clip("Death_C_Skeletons", "Death_A"), 0.1, 1.0, true)
	Run.slew(str(KINDS[kind]["name"]))
	var sky := get_tree().get_first_node_in_group("sky")
	var night := sky != null and bool(sky.call("is_night"))
	Run.on_kill(kind, elite, night)
	if kind == "thief":
		Run.record("thief")
		Run.toast.emit("You caught the Grave Thief", "skill")
	Run.renown(float(XP.get(kind, 10.0)) * (3.0 if elite else 1.0))
	Run.potential = minf(100.0, Run.potential + (10.0 if camp == "barrow" else 5.0))
	if _was_bound and not Run.law.is_empty():
		var found := Law.notice(Run.law, "bound_kills")
		if not found.is_empty():
			Run.toast.emit("Your Inscription reveals: %s" % found["name"], "law")
	_burn_t = 0.0
	_drop_loot()
	slain.emit(camp)

func _drop_loot() -> void:
	var at := global_position + Vector3.UP * 0.6
	var purse := randi_range(3, 9) * (8 if is_boss() else 1) * (4 if elite else 1) * (14 if kind == "thief" else 1)
	Pickup.spawn(get_parent(), at, "silver", int(purse * Run.gain_mult()))
	if kind == "thief":
		Pickup.spawn(get_parent(), at + Vector3(0.8, 0, 0), Loot.roll_weapon("relic" if randf() < 0.1 else "rare"), 1)
		Pickup.spawn(get_parent(), at + Vector3(-0.8, 0, 0), "star_iron", 1 if randf() < 0.6 else 2)
		if randf() < 0.4:
			Pickup.spawn(get_parent(), at + Vector3(0, 0, 0.8), Treasure.roll_map(), 1)
		return
	if kind == "drowned_captain" or (kind == "corsair" and randf() < 0.1):
		Pickup.spawn(get_parent(), at + Vector3(0, 0, -0.8), Treasure.roll_map(), 1)
	if is_boss():
		Pickup.spawn(get_parent(), at + Vector3(-1, 0, -1), Loot.roll_weapon("relic" if randf() < 0.15 else "rare"), 1)
	elif elite:
		Loot.maybe_drop(get_parent(), at, 0.7, 3.5)
		Pickup.spawn(get_parent(), at + Vector3(0.6, 0, 0.6), "iron_scrap", randi_range(2, 4))
	else:
		Loot.maybe_drop(get_parent(), at, 0.06, 1.0)
	if kind == "warden":
		Pickup.spawn(get_parent(), at + Vector3(1, 0, 0), "stilled_tide_shard", 1)
		Pickup.spawn(get_parent(), at + Vector3(-1, 0, 0), "barrow_dagger", 1)
		Pickup.spawn(get_parent(), at + Vector3(0, 0, 1), "star_iron", 1)
		return
	var k := 0
	for d in KINDS[kind].get("drops", []):
		k += 1
		var a := TAU * float(k) / 5.0
		Pickup.spawn(get_parent(), at + Vector3(cos(a), 0, sin(a)) * 1.2, str(d[0]), int(d[1]))
	if is_boss():
		return
	for l in LOOT:
		if randf() < float(l[1]):
			Pickup.spawn(get_parent(), at + Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8)), str(l[0]),
				randi_range(int(l[2]), int(l[3])))

func _respawn() -> void:
	visible = true
	remove_from_group("fallen")
	_t = 0.0
	posture = 0.0
	_burn_t = 0.0
	_chill_t = 0.0
	_roll_elite()
	health = max_health
	global_position = home + Vector3(randf_range(-4, 4), 2.0, randf_range(-4, 4))
	collision_layer = 8
	state = S.IDLE
	_was_bound = false
	model.play(_clip("Skeletons_Awaken_Standing", "Idle"), 0.0, 1.0, true)

## Rest at a Waystone: the fallen rise again.
func rise() -> void:
	if state == S.DEAD and respawns:
		_respawn()

func _hud_number(at: Vector3, amount: float, col: Color, big: bool = false) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("pop_number"):
		hud.call("pop_number", at, amount, col, big)
