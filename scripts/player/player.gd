class_name Player
extends CharacterBody3D
## The knight. Moves relative to the camera; rolls through danger; blocks
## (and, with the perk, parries); swings a combo whose shape depends on what
## is in his hands. What he holds, how hard he hits and how long he lasts
## all come from Run (gear and perks). Everything he does is noticed:
## skills grow with use and the behaviour profile leans with habit.

signal health_changed(value: float, max_value: float)
signal died
signal crisis                 ## badly hurt in a fight, with enough latent potential to awaken

const WALK := 3.2
const RUN := 7.4
const SPRINT := 11.2
const ACCEL := 26.0
const TURN := 15.0
const JUMP := 7.2
const GRAVITY := 21.0
const ROLL_SPEED := 12.5
const MAX_HEALTH := 150.0          ## before perks; see max_health()
const ONE_HAND := ["1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal", "1H_Melee_Attack_Chop"]
const TWO_HAND := ["2H_Melee_Attack_Slice", "2H_Melee_Attack_Spin", "2H_Melee_Attack_Chop"]
const COMBO_MULT := [1.0, 1.1, 1.6]

enum S { MOVE, ATTACK, ROLL, HIT, DEAD, ART, CHARGE, SWIM, CLIMB }

const SWIM := 3.4
const SWIM_FAST := 5.4
const FLOAT_DEPTH := 1.35          ## how far the feet hang below the surface when swimming

var state := S.MOVE
var health := MAX_HEALTH
var stamina := 100.0
var model: CharacterModel
var rig: CameraRig
var powers: LawPowers
var arts: Arts
var blocking := false
var _state_t := 0.0
var _clip_len := 0.0
var _combo := 0
var _queued := false
var _hit_done := false
var _roll_dir := Vector3.ZERO
var _stamina_wait := 0.0
var _sprinting := false
var _air_t := 0.0
var _step_t := 0.0
var _block_t := 0.0          ## seconds the shield has been up (a parry is the first 0.25)
var _riposte_t := 0.0
var _dash_t := 0.0
var _combat_t := 0.0          ## seconds since last fighting, for Regrowth and crisis
var _gear_nodes: Array[Node] = []
var _heavy := false           ## this swing was charged (held attack)
var _charge_t := 0.0
var _jump_atk := false        ## this swing started in the air and lands on the ground
var _crit := false            ## this swing is a critical blow on a broken foe
var helm: Ship                ## the ship whose wheel you hold, if any
var _climb_from := Vector3.ZERO
var _climb_to := Vector3.ZERO

func _ready() -> void:
	add_to_group("player")
	collision_layer = 4
	collision_mask = 1 | 2 | 16       ## 16: ships' decks
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(48.0)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.8
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3.UP * 0.9
	add_child(cs)
	model = CharacterModel.new()
	model.setup("res://assets/characters/Knight.glb", [])
	add_child(model)
	model.play("Idle")
	powers = LawPowers.new()
	powers.player = self
	add_child(powers)
	arts = Arts.new()
	arts.player = self
	add_child(arts)
	Run.level_up.connect(_on_level_up)
	Run.changed.connect(func(what: String) -> void:
		if what == "gear":
			_apply_gear()
		elif what == "skills":
			health = minf(health, max_health()))
	_apply_gear()
	health = max_health()

func max_health() -> float:
	return MAX_HEALTH + Run.perk("max_health") + float(Run.renown_level - 1) * Renown.HEALTH_PER_LEVEL

func max_stamina() -> float:
	return 100.0

func is_sprinting() -> bool:
	return _sprinting

func weapon() -> Dictionary:
	return Run.item(str(Run.gear.get("weapon", "")))

func shield() -> Dictionary:
	return Run.item(str(Run.gear.get("shield", "")))

func two_handed() -> bool:
	return bool(weapon().get("two_handed", false))

## Puts what Run says is equipped into the knight's hands.
func _apply_gear() -> void:
	for n in _gear_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_gear_nodes.clear()
	var slots := {"weapon": "handslot_r", "shield": "handslot_l"}
	for slot in slots.keys():
		var att := model.find_child(slots[slot], true, false) as Node3D
		if att == null:
			continue
		var def := Run.item(str(Run.gear.get(slot, "")))
		if def.is_empty():
			continue
		var ps := load("res://assets/gear/%s.gltf" % def["model"]) as PackedScene
		if ps == null:
			continue
		var n := ps.instantiate()
		att.add_child(n)
		_gear_nodes.append(n)
		if slot == "weapon":
			_dress_weapon(n, def)

func _physics_process(delta: float) -> void:
	_state_t += delta
	_riposte_t -= delta
	_combat_t += delta
	if velocity.length() > 40.0:
		velocity = velocity.limit_length(12.0)       # a moving deck jumped; never fling the knight
	if helm != null:
		# At the wheel: stand there, face the bow, let the ship do the moving.
		global_position = helm.helm_point()
		velocity = Vector3.ZERO
		model.rotation = Vector3(0, helm.heading, 0)
		model.play("Idle", 0.25)
		_regen(delta)
		return
	if state == S.DEAD:
		velocity.x = 0.0
		velocity.z = 0.0
		_gravity(delta)
		move_and_slide()
		return
	if state == S.CLIMB:
		_climbing()
		return
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back") if Game.playing else Vector2.ZERO
	var fwd := rig.forward_flat() if rig != null else Vector3.FORWARD
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var wish := (right * input.x - fwd * input.y)
	if wish.length() > 1.0:
		wish = wish.normalized()
	var was_blocking := blocking
	blocking = Game.playing and Input.is_action_pressed("block") and state == S.MOVE and is_on_floor() \
		and stamina > 1.0 and not two_handed() and not shield().is_empty()
	_block_t = _block_t + delta if blocking else 0.0
	if blocking and not was_blocking:
		_block_t = 0.0
	if _dash_t > 0.0:
		_dash_t -= delta
		move_and_slide()
		return
	_water(delta)
	match state:
		S.SWIM:
			_swim(delta, wish)
			return
		S.MOVE: _move(delta, wish)
		S.ATTACK: _attack(delta, wish)
		S.ROLL: _roll(delta)
		S.HIT: _hit(delta)
		S.CHARGE: _charging(delta, wish)
		S.ART:
			velocity.x = move_toward(velocity.x, 0.0, 40.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 40.0 * delta)
			if _state_t >= _clip_len:
				state = S.MOVE
	_gravity(delta)
	move_and_slide()
	_regen(delta)
	_watch_crisis()

# --- Water and ledges ------------------------------------------------------------------------------

func _ground(x: float, z: float) -> float:
	var w := get_parent() as World
	return w.ground(x, z) if w != null else -INF

## In over your chest: you swim. Feet back on the bottom: you walk out.
func _water(_delta: float) -> void:
	var depth := Sea.LEVEL - global_position.y
	if state == S.SWIM:
		if _ground(global_position.x, global_position.z) > Sea.LEVEL - FLOAT_DEPTH + 0.15:
			state = S.MOVE
			model.rotation.x = 0.0
		return
	if depth > FLOAT_DEPTH + 0.1 and state in [S.MOVE, S.ATTACK, S.ROLL, S.HIT, S.ART, S.CHARGE] \
			and get_parent() is World and not (get_parent() as World).in_gate():
		state = S.SWIM
		_state_t = 0.0
		velocity.y = maxf(velocity.y, -2.0)
		blocking = false
		Fx.sparks(get_parent(), Vector3(global_position.x, Sea.LEVEL + 0.2, global_position.z), Color(0.85, 0.95, 1.0), 24)
		Audio.play("roll", global_position, 0.0, 0.6)
		Run.flags["swam"] = true

func _swim(delta: float, wish: Vector3) -> void:
	var fast := Game.playing and Input.is_action_pressed("sprint") and stamina > 5.0 and wish.length() > 0.1
	var top := SWIM_FAST if fast else SWIM
	if fast:
		stamina -= 9.0 * delta
		_stamina_wait = 0.8
	var flat := Vector3(velocity.x, 0.0, velocity.z).move_toward(wish * top, 10.0 * delta)
	velocity.x = flat.x
	velocity.z = flat.z
	# Float with the head out of the water.
	velocity.y = (Sea.LEVEL - FLOAT_DEPTH + sin(_state_t * 2.2) * 0.06 - global_position.y) * 5.0
	var moving := wish.length() > 0.1
	if moving:
		_face(wish, delta)
	model.rotation.x = lerpf(model.rotation.x, 0.95 if moving else 0.15, clampf(delta * 5.0, 0.0, 1.0))
	model.play("Running_A" if moving else "Idle", 0.25, 0.55 if moving else 1.0)
	move_and_slide()
	_regen(delta)
	Run.lean("seafaring", delta * 0.02)
	# A shore or rock lip ahead, low enough to haul yourself up onto.
	var ahead := global_position + (wish if moving else model.global_basis.z).normalized() * 1.2
	var h := _ground(ahead.x, ahead.z)
	if h > Sea.LEVEL - 0.6 and h < Sea.LEVEL + 2.6 and moving and (Input.is_action_just_pressed("jump") or h < Sea.LEVEL + 0.9):
		_climb(Vector3(ahead.x, h + 0.05, ahead.z))

## Haul up onto a ledge: half a second, then you stand on it.
func _climb(to: Vector3) -> void:
	state = S.CLIMB
	_state_t = 0.0
	_climb_from = global_position
	_climb_to = to
	velocity = Vector3.ZERO
	model.rotation.x = 0.0
	model.play("Interact", 0.1, 1.6, true)
	Audio.play("roll", global_position, -6.0, 0.9)

func _climbing() -> void:
	var t := clampf(_state_t / 0.55, 0.0, 1.0)
	var up := clampf(t / 0.6, 0.0, 1.0)
	var over := clampf((t - 0.45) / 0.55, 0.0, 1.0)
	var p := _climb_from.lerp(_climb_to, over)
	p.y = lerpf(_climb_from.y, _climb_to.y + 0.1, ease(up, 0.5))
	global_position = p
	if t >= 1.0:
		state = S.MOVE
		velocity = Vector3.ZERO

## On land: jumping at a ledge you can reach pulls you up it.
func _try_mantle(wish: Vector3) -> bool:
	if wish.length() < 0.1:
		return false
	var ahead := global_position + wish.normalized() * 1.0
	var h := _ground(ahead.x, ahead.z)
	var rise := h - global_position.y
	if rise > 1.0 and rise < 2.6:
		_climb(Vector3(ahead.x, h + 0.05, ahead.z))
		return true
	return false

func _gravity(delta: float) -> void:
	if is_on_floor():
		_air_t = 0.0
		if velocity.y < 0.0:
			velocity.y = -0.5
	else:
		_air_t += delta
		velocity.y -= GRAVITY * delta

func _move(delta: float, wish: Vector3) -> void:
	var moving := wish.length() > 0.1
	_sprinting = moving and Input.is_action_pressed("sprint") and stamina > 5.0 and not blocking
	var speed_mult := (1.0 + Run.perk("speed")) * (1.0 - float(shield().get("slow", 0.0)))
	var top := (SPRINT if _sprinting else (WALK if blocking or Input.is_action_pressed("walk_toggle") else RUN)) * speed_mult
	var target := wish * top
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	flat = flat.move_toward(target, ACCEL * delta * (1.6 if target.length() < flat.length() else 1.0))
	velocity.x = flat.x
	velocity.z = flat.z
	if _sprinting:
		stamina -= 7.0 * delta * (1.0 + Run.perk("sprint_cost"))
		_stamina_wait = 0.8
		Run.gain("agility", delta * 0.6)
	if moving and not blocking:
		_face(wish, delta)
	elif blocking and rig != null:
		_face(rig.forward_flat(), delta)
	var speed := flat.length()
	var two := two_handed()
	if not is_on_floor() and _air_t > 0.15:
		model.play("Jump_Idle", 0.2)
	elif blocking:
		model.play("Blocking", 0.15)
	elif speed < 0.25:
		model.play("2H_Melee_Idle" if two else "Idle", 0.25)
	elif speed < 4.2:
		model.play("Walking_A", 0.2, clampf(speed / 2.4, 0.8, 1.7))
	else:
		model.play("Running_A", 0.18, clampf(speed / 6.0, 0.9, 1.75))
	if speed > 1.0 and is_on_floor():
		_step_t -= delta * speed
		if _step_t <= 0.0:
			_step_t = 2.6
			Audio.footstep(global_position)
	if not Game.playing:
		return
	if Input.is_action_just_pressed("jump") and is_on_floor() and _try_mantle(wish):
		return
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP
		model.play("Jump_Start", 0.08, 1.0, true)
	if Input.is_action_just_pressed("attack"):
		if not is_on_floor() and _air_t > 0.12:
			_start_jump_attack()
		else:
			_start_attack(0, wish)
	elif Input.is_action_just_pressed("dodge") and stamina >= 12.0 and is_on_floor():
		_start_roll(wish if moving else model.global_basis.z)
	elif Input.is_action_just_pressed("heal"):
		drink_flask()
	for i in Run.HOTBAR:
		if Input.is_action_just_pressed("hotbar_%d" % (i + 1)) and str(Run.hotbar[i]) != "":
			use_item(str(Run.hotbar[i]))

## Uses an item from the bag: drinks or eats it, or equips it.
func use_item(id: String) -> void:
	var def := Run.item(id)
	if def.is_empty() or Run.count(id) <= 0:
		if id == "red_potion":
			Run.toast.emit("No draughts left", "warn")
		return
	match str(def.get("kind", "")):
		"consumable":
			if health >= max_health():
				return
			Run.remove_item(id, 1)
			heal(float(def.get("heal", 0.0)) * (1.0 + Run.perk("potion")))
			model.play("Use_Item", 0.12, 1.4, true)
			Run.gain("vitality", 5.0)
			Run.lean("mercy", 0.4)
			if _combat_t < 6.0:
				_law_notice("heals")
		"weapon", "shield":
			Run.equip(id)
			Audio.play("door", global_position, -12.0, 1.6)
		"upgrade":
			Run.toast.emit("Use it at a Waystone, to strengthen your Flask", "warn")
		"map":
			Run.toast.emit("The X is on %s. It shows on your compass and map." % Treasure.where(int(def.get("site", 0))), "place")

## R: a draught from the Flask. It refills when you rest at a Waystone.
func drink_flask() -> void:
	if state != S.MOVE or not is_on_floor():
		return
	if Run.flask <= 0:
		Run.toast.emit("The Flask is empty. Rest at a Waystone.", "warn")
		return
	Run.flask -= 1
	Run.changed.emit("flask")
	play_art("Use_Item", 1.5, 0.5)
	heal(Run.flask_heal() * (1.0 + Run.perk("potion")))
	Run.gain("vitality", 5.0)
	Run.lean("mercy", 0.4)
	if _combat_t < 6.0:
		_law_notice("heals")

## Renown rose: a ring of gold, and whole again.
func _on_level_up(_level: int, _reward: String) -> void:
	health = max_health()
	health_changed.emit(health, max_health())
	var ring := LawRing.new()
	ring.colour = Color(1.0, 0.82, 0.4)
	ring.radius = 3.5
	ring.life = 0.8
	ring.expanding = true
	get_parent().add_child(ring)
	ring.global_position = global_position + Vector3.UP * 0.1
	Fx.sparks(get_parent(), global_position + Vector3.UP * 1.2, Color(1.0, 0.85, 0.45), 50)
	Audio.play("heal", global_position, 4.0, 0.8)
	Audio.ui("confirm", 0.0)

## Resting at a Waystone: whole again, and the Flask full.
func rest_full() -> void:
	health = max_health()
	stamina = max_stamina()
	Run.flask = Run.flask_max
	Run.rest()
	Run.changed.emit("flask")
	health_changed.emit(health, max_health())

## A forged weapon shows what it is: its metal's sheen, its etching's glow.
func _dress_weapon(n: Node, def: Dictionary) -> void:
	var col := Color(0, 0, 0, 0)
	var et := str(def.get("etch", ""))
	if Forge.ETCH_COLOURS.has(et):
		col = Color(Forge.ETCH_COLOURS[et], 0.42)
	elif def.has("tint"):
		col = Color(Color(str(def["tint"])), 0.2)
	if col.a <= 0.0:
		return
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = col
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = m
	if et != "":
		var glow := OmniLight3D.new()
		glow.light_color = Color(col, 1.0)
		glow.light_energy = 0.7
		glow.omni_range = 1.8
		glow.shadow_enabled = false
		(n as Node3D).add_child(glow)

func _face(dir: Vector3, delta: float) -> void:
	var want := atan2(dir.x, dir.z)
	model.rotation.y = lerp_angle(model.rotation.y, want, clampf(TURN * delta, 0.0, 1.0))

func _combo_clips() -> Array:
	return TWO_HAND if two_handed() else ONE_HAND

func _start_attack(step: int, wish: Vector3) -> void:
	if stamina < 8.0:
		return
	state = S.ATTACK
	_state_t = 0.0
	_combo = step
	_queued = false
	_hit_done = false
	_heavy = false
	_jump_atk = false
	_crit = step == 0 and _broken_foe(2.9) != null
	stamina -= 7.0 * (1.4 if two_handed() else 1.0)
	_stamina_wait = 0.5
	var aim := wish
	var foe := _broken_foe(2.9) if _crit else nearest_enemy(5.0)
	if foe != null:
		aim = (foe.global_position - global_position) * Vector3(1, 0, 1)
	if aim.length() > 0.1:
		model.rotation.y = atan2(aim.x, aim.z)
	var clip: String = _combo_clips()[step]
	if _crit:
		clip = "2H_Melee_Attack_Stab" if two_handed() else "1H_Melee_Attack_Stab"
	var spd := float(weapon().get("speed", 1.35))
	_clip_len = model.length_of(clip) / spd
	model.play(clip, 0.08, spd, true)
	Audio.play("swing", global_position, -4.0, 0.95 + 0.1 * step)

func _attack(delta: float, wish: Vector3) -> void:
	var t := _state_t / maxf(_clip_len, 0.01)
	var fwd := model.global_basis.z
	if _jump_atk:
		# Falling onto them: keep the leap's momentum, drop hard, strike on landing.
		velocity.y -= 16.0 * delta
		if not _hit_done and ((is_on_floor() and _state_t > 0.08) or t >= 0.95):
			_hit_done = true
			_strike()
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		if t >= 1.0:
			state = S.MOVE
		return
	var lunge := (4.6 if _heavy else 3.2) * (1.0 - smoothstep(0.0, 0.45, t))
	velocity.x = fwd.x * lunge
	velocity.z = fwd.z * lunge
	# Still holding the button as the swing begins: it becomes a charged blow.
	if _combo == 0 and not _heavy and not _crit and not _hit_done and _state_t > 0.15 \
			and Input.is_action_pressed("attack") and stamina >= 6.0 and Game.playing:
		_begin_charge()
		return
	if Input.is_action_just_pressed("attack") and t > 0.25:
		_queued = true
	if not _hit_done and t >= 0.38:
		_hit_done = true
		_strike()
	if _queued and t >= 0.62 and _combo < 2 and not _heavy and not _crit:
		_start_attack(_combo + 1, wish)
		return
	if Input.is_action_just_pressed("dodge") and t > 0.35 and stamina >= 12.0:
		_start_roll(wish if wish.length() > 0.1 else fwd)
		return
	if t >= 1.0:
		state = S.MOVE

## Hold the attack: the blade is drawn back, slower and slower to let go.
func _begin_charge() -> void:
	state = S.CHARGE
	_charge_t = 0.0
	_heavy = true
	var clip := "2H_Melee_Attack_Chop" if two_handed() else "1H_Melee_Attack_Chop"
	model.play(clip, 0.1, 0.12, true)
	Audio.play("swing", global_position, -12.0, 0.55)

func _charging(delta: float, wish: Vector3) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
	_charge_t += delta
	var foe := nearest_enemy(5.0)
	if foe != null:
		_face((foe.global_position - global_position) * Vector3(1, 0, 1), delta)
	elif wish.length() > 0.1:
		_face(wish, delta)
	if _charge_t > 1.1 * 0.95 and int(_charge_t * 20.0) % 4 == 0:
		Fx.sparks(get_parent(), global_position + Vector3.UP * 1.3 + model.global_basis.z * 0.5, Color(1, 0.8, 0.4), 3)
	if not Input.is_action_pressed("attack") or _charge_t >= 1.1 or not Game.playing:
		_release_heavy()

func _release_heavy() -> void:
	state = S.ATTACK
	_state_t = 0.0
	_hit_done = false
	stamina -= 9.0
	_stamina_wait = 0.7
	var clip := "2H_Melee_Attack_Chop" if two_handed() else "1H_Melee_Attack_Chop"
	var left := model.length_of(clip)
	if model.anim != null:
		left -= model.anim.current_animation_position
		model.anim.speed_scale = 1.5
	_clip_len = maxf(left, 0.3) / 1.5
	Audio.play("swing", global_position, 0.0, 0.7)

## A leap and a blow on landing: harder than a swing, and it shakes a stance.
func _start_jump_attack() -> void:
	if stamina < 8.0:
		return
	state = S.ATTACK
	_state_t = 0.0
	_combo = 0
	_queued = false
	_hit_done = false
	_heavy = false
	_crit = false
	_jump_atk = true
	stamina -= 12.0
	_stamina_wait = 0.6
	var clip := "2H_Melee_Attack_Chop" if two_handed() else "1H_Melee_Attack_Chop"
	_clip_len = model.length_of(clip) / 1.15
	model.play(clip, 0.06, 1.15, true)
	velocity.y = minf(velocity.y, 1.5)
	Audio.play("swing", global_position, -2.0, 0.8)

## The nearest foe whose stance is broken, in front and close enough to finish.
func _broken_foe(reach: float) -> Node3D:
	for e in get_tree().get_nodes_in_group("enemies"):
		var n := e as Node3D
		if n != null and n.has_method("is_broken") and bool(n.call("is_broken")) \
				and n.global_position.distance_to(global_position) < reach:
			return n
	return null

## A critical blow: the foe whose stance broke takes three times the hurt.
func _critical(base: float) -> void:
	var foe := _broken_foe(3.2)
	if foe == null:
		return
	var boss := bool(foe.call("is_boss"))
	var d := base * (2.2 if boss else 3.0)
	foe.call("critical", d, self)
	_apply_etch(foe, d)
	_combat_t = 0.0
	Fx.hit_stop(0.22)
	if rig != null:
		rig.shake(1.0)
	Audio.play("hit", foe.global_position, 4.0, 0.7)
	Fx.sparks(get_parent(), foe.global_position + Vector3.UP * 1.1, Color(1.0, 0.9, 0.55), 40)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.call("pop_text", foe.global_position + Vector3.UP * 2.6, "CRITICAL", Kit.GOLD_LIGHT)
	Run.gain("blade", 14.0)
	Run.flags["critical"] = true
	Run.record("critical")
	Run.renown(6.0)

## What an etched weapon does to whatever it hits.
func _apply_etch(n: Node3D, dealt: float) -> void:
	match str(weapon().get("etch", "")):
		"ember":
			if n.has_method("burn_for"):
				n.call("burn_for", 3.0, 4.0)
		"rime":
			if n.has_method("chill_for"):
				n.call("chill_for", 1.2)
		"grave":
			health = minf(max_health(), health + dealt * 0.07)
			health_changed.emit(health, max_health())

func _strike() -> void:
	var fwd := model.global_basis.z
	var centre := global_position + Vector3.UP * 1.0 + fwd * 1.2
	var damage := float(weapon().get("damage", 10.0)) * float(COMBO_MULT[_combo]) * (1.0 + Run.perk("damage"))
	var stance := 0.8
	if _heavy:
		var f := clampf(_charge_t / 1.1, 0.0, 1.0)
		damage *= 1.5 + 0.9 * f
		stance = 2.4 + 1.0 * f
	elif _jump_atk:
		damage *= 1.7
		stance = 2.2
		centre = global_position + Vector3.UP * 0.8 + fwd * 0.9
		Fx.sparks(get_parent(), global_position + fwd * 0.9, Color(0.9, 0.8, 0.6), 18)
	stance *= Forge.posture_of(weapon())
	if _crit:
		if arts.rally_t > 0.0:
			damage *= 1.25
		_critical(damage)
		return
	if arts.rally_t > 0.0:
		damage *= 1.25
	if _combo == 2:
		damage *= 1.0 + Run.perk("finisher")
	if _riposte_t > 0.0:
		damage *= 1.0 + Run.perk("riposte")
		_riposte_t = 0.0
	var empowered := powers.empower_t > 0.0
	if empowered:
		damage *= 2.5
		powers.empower_t = 0.0
	var cleave := Run.has_perk("cleave") or two_handed() or _jump_atk
	var reach := (2.0 if cleave else 1.7) + (0.3 if _heavy else 0.0)
	var targets: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		var n := e as Node3D
		if n == null or not n.has_method("take_hit") or bool(n.call("is_dead")):
			continue
		var to := n.global_position + Vector3.UP - centre
		if to.length() < reach and fwd.dot((n.global_position - global_position).normalized()) > (-0.4 if cleave else -0.1):
			targets.append(n)
	if not cleave and targets.size() > 1:
		targets.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position))
		targets = [targets[0]]
	for n in targets:
		var d := damage
		if bool(n.call("is_staggered")):
			d *= 1.0 + Run.perk("execute")
		n.call("take_hit", d, self, d * stance)
		_apply_etch(n, d)
		if empowered and n.has_method("stagger"):
			n.call("stagger")
	if not targets.is_empty():
		_combat_t = 0.0
		if _heavy:
			Run.record("heavy")
		elif _jump_atk:
			Run.record("jump")
		var hard := _heavy or _jump_atk or _combo == 2
		Fx.hit_stop(0.14 if _heavy else (0.11 if hard else 0.07))
		if rig != null:
			rig.shake(0.9 if _heavy else (0.7 if hard else 0.35))
		Audio.play("hit", centre, 0.0, randf_range(0.9, 1.1))
		Fx.sparks(get_parent(), centre, Color(1.0, 0.85, 0.5))
		Run.gain("blade", 6.0 * targets.size())
		Run.lean("violence", 0.3)
		if health < max_health() * 0.4:
			Run.lean("boldness", 0.6)

func _start_roll(dir: Vector3) -> void:
	state = S.ROLL
	_state_t = 0.0
	_roll_dir = dir.normalized()
	stamina -= 14.0 * (1.0 + Run.perk("roll_cost"))
	_stamina_wait = 0.5
	model.rotation.y = atan2(_roll_dir.x, _roll_dir.z)
	_clip_len = model.length_of("Dodge_Forward") / 1.5
	model.play("Dodge_Forward", 0.05, 1.5, true)
	Audio.play("roll", global_position, -6.0)
	Run.gain("agility", 4.0)
	Run.lean("caution", 0.3)
	if _combat_t < 6.0:
		_law_notice("rolls")

func _roll(_delta: float) -> void:
	var t := _state_t / maxf(_clip_len, 0.01)
	var v := ROLL_SPEED * (1.0 - smoothstep(0.55, 1.0, t))
	velocity.x = _roll_dir.x * v
	velocity.z = _roll_dir.z * v
	if t >= 1.0:
		state = S.MOVE

## An Art's moment: the clip plays and the knight is committed for `lock`
## seconds.
func play_art(clip: String, speed: float, lock: float) -> void:
	state = S.ART
	_state_t = 0.0
	_clip_len = lock
	model.play(clip, 0.06, speed, true)

## Borrowed Step: carried forward, untouchable, for `seconds`.
func dash(seconds: float) -> void:
	_dash_t = seconds
	model.play("Dodge_Forward", 0.04, 1.8, true)

func invulnerable() -> bool:
	if _dash_t > 0.0:
		return true
	return state == S.ROLL and _state_t < _clip_len * minf(0.95, 0.8 * (1.0 + Run.perk("iframes")))

func _hit(_delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 0.5)
	velocity.z = move_toward(velocity.z, 0.0, 0.5)
	if _state_t >= 0.45:
		state = S.MOVE

## Damage from an enemy. Returns false if it did not land.
func take_hit(damage: float, from: Node3D) -> bool:
	if state == S.DEAD:
		return false
	_combat_t = 0.0
	if invulnerable():
		_law_notice("dodges")
		return false
	if powers.negate:
		powers.negate = false
		Fx.sparks(get_parent(), global_position + Vector3.UP, Law.colour("sequence"), 24)
		return false
	var dir := (global_position - from.global_position) * Vector3(1, 0, 1)
	var facing_it := model.global_basis.z.dot(-dir.normalized()) > 0.3
	if blocking and facing_it:
		if Run.has_perk("parry") and _block_t < 0.35:
			# A perfect block: the attacker's stance cracks (ordinary foes break
			# outright, open to a critical blow), and the next strike is a riposte.
			if from.has_method("add_posture"):
				var full := float(from.get("max_posture"))
				from.call("add_posture", full * (0.4 if bool(from.call("is_boss")) else 1.0))
			elif from.has_method("stagger"):
				from.call("stagger")
			_riposte_t = 1.2
			Fx.hit_stop(0.12)
			Fx.sparks(get_parent(), global_position + Vector3.UP * 1.2 + model.global_basis.z * 0.6, Color(1, 0.95, 0.6), 30)
			Audio.play("block", global_position, 2.0, 1.3)
			Run.gain("guard", 14.0)
			_law_notice("blocks")
			return false
		var cost := damage * 0.8 * (1.0 + Run.perk("block_cost"))
		stamina -= cost
		_stamina_wait = 1.0 * (1.0 + Run.perk("stamina_delay"))
		model.play("Block_Hit", 0.05, 1.2, true)
		Audio.play("block", global_position)
		Fx.sparks(get_parent(), global_position + Vector3.UP * 1.2 + model.global_basis.z * 0.6, Color(0.9, 0.95, 1.0))
		var thorns := Run.perk("thorns") + float(shield().get("thorns", 0.0))
		if thorns > 0.0 and from.has_method("take_hit"):
			from.call("take_hit", damage * thorns, self)
		if rig != null:
			rig.shake(0.25)
		Run.gain("guard", 8.0)
		Run.lean("caution", 0.25)
		Run.lean("patience", 0.2)
		_law_notice("blocks")
		if stamina > 0.0:
			return false
		damage *= 1.0 - minf(0.95, float(shield().get("block", 0.7)) + Run.perk("block"))
	damage *= 1.0 - Run.perk("armour")
	if powers.stone_t > 0.0:
		damage *= 0.4
	if powers.reflect_t > 0.0 and from.has_method("take_hit"):
		from.call("take_hit", damage, self)
		damage *= 0.3
	health = maxf(0.0, health - damage)
	if health <= 0.0 and Run.use_last_stand():
		health = 1.0
		Run.toast.emit("Last Stand", "skill")
	health_changed.emit(health, max_health())
	if rig != null:
		rig.shake(0.6)
	Audio.play("hurt", global_position)
	velocity += dir.normalized() * 5.0
	Run.gain("vitality", damage * 0.4)
	Run.lean("endurance", 0.3)
	_law_notice("hits_taken")
	if health <= 0.0:
		state = S.DEAD
		model.play("Death_A", 0.1, 1.0, true)
		died.emit()
	else:
		state = S.HIT
		_state_t = 0.0
		model.play("Hit_A", 0.05, 1.3, true)
	return true

func heal(amount: float) -> void:
	health = minf(max_health(), health + amount)
	health_changed.emit(health, max_health())
	Audio.play("heal", global_position)

func revive(at: Vector3) -> void:
	helm = null
	model.rotation = Vector3.ZERO
	global_position = at
	velocity = Vector3.ZERO
	health = max_health()
	stamina = max_stamina()
	state = S.MOVE
	model.play("Idle", 0.0, 1.0, true)
	health_changed.emit(health, max_health())
	Run.rest()

func _regen(delta: float) -> void:
	_stamina_wait -= delta
	if _stamina_wait <= 0.0:
		stamina = minf(max_stamina(), stamina + 48.0 * delta * (1.0 + Run.perk("stamina_regen")))
	stamina = maxf(stamina, 0.0)
	if Run.has_perk("regen") and _combat_t > 8.0 and health < max_health():
		health = minf(max_health(), health + Run.perk("regen") * delta)
		health_changed.emit(health, max_health())

## A hidden use of the Inscription may reveal itself through what you do.
func _law_notice(counter: String) -> void:
	if Run.law.is_empty():
		return
	var found := Law.notice(Run.law, counter)
	if not found.is_empty():
		Run.toast.emit("Your Inscription reveals: %s" % found["name"], "law")
		Run.add_clue("found_" + str(found["id"]), found["name"], str(found["text"]))
		Run.changed.emit("law")

## Badly hurt with an enemy close and enough potential: the moment of awakening.
func _watch_crisis() -> void:
	if not Run.law.is_empty() or Run.potential < 35.0:
		return
	if health < max_health() * 0.5 and nearest_enemy(10.0) != null:
		crisis.emit()

func nearest_enemy(reach: float) -> Node3D:
	var best: Node3D = null
	var best_d := reach
	for e in get_tree().get_nodes_in_group("enemies"):
		var n := e as Node3D
		if n == null or (n.has_method("is_dead") and bool(n.call("is_dead"))):
			continue
		var d := n.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = n
	return best
