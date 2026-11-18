extends Node
## Tests and photographs the Knight's Arts: each Art against a few
## skeletons (prints PASS/FAIL), the HUD's Arts row, and the skill trees
## with their Art roots. Opens a window.
##   Godot --path . scenes/tools/CaptureArts.tscn -- <out_dir>

var _out := "/tmp/cf/arts"
var main: Node
var world: World
var _fails := 0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1600, 900)
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	while main.get("_menu") == null:
		await get_tree().process_frame
	main.call("_begin", -1)
	await _wait_real(2.0)
	_dismiss()
	await _wait_real(1.0)
	world = main.get("world")
	var p := world.player
	_check("starts knowing Whirlwind", Arts.known("whirlwind"))
	_check("starts with a point in Guard", int(Run.skills["guard"]["points"]) == 1)
	# Whirlwind: three skeletons in a ring.
	var ring := _foes(3, 2.4)
	await _wait_real(0.3)
	var before := _hp(ring)
	p.arts.use("whirlwind")
	await _wait_real(0.24)
	await _shot("01_whirlwind")
	await _wait_real(0.4)
	_check("Whirlwind hits all three", _hit_count(ring, before) == 3)
	_check("Whirlwind goes on cooldown", p.arts.ready_fraction("whirlwind") < 0.95)
	_clear(ring)
	# Unknown Art: refused, no cooldown.
	p.arts.use("charge")
	_check("Charge refused until learned", float(p.arts.cooldown.get("charge", 0.0)) == 0.0)
	_check("learn Charge with the starting point", Run.unlock("charge"))
	_check("learn Shield Bash", Run.unlock("shield_bash"))
	_check("learn Battle Cry", Run.unlock("battle_cry"))
	# Charge: a skeleton 6 m ahead.
	await _wait_real(0.6)
	p.stamina = p.max_stamina()
	var ahead := _foes(1, 0.0, p.global_position + p.model.global_basis.z * 6.0)
	await _wait_real(0.2)
	var start := p.global_position
	before = _hp(ahead)
	p.arts.use("charge")
	await _wait_real(0.15)
	await _shot("02_charge")
	await _wait_real(0.5)
	_check("Charge carries the knight forward (%.1f m)" % start.distance_to(p.global_position),
		start.distance_to(p.global_position) > 4.0)
	_check("Charge hits what's in the way", _hit_count(ahead, before) == 1)
	_clear(ahead)
	# Shield Bash: one in front.
	await _wait_real(0.6)
	var front := _foes(1, 0.0, p.global_position + p.model.global_basis.z * 1.8)
	await _wait_real(0.2)
	before = _hp(front)
	p.arts.use("shield_bash")
	await _wait_real(0.3)
	await _shot("03_shield_bash")
	_check("Shield Bash hits", _hit_count(front, before) == 1)
	_clear(front)
	# Battle Cry.
	await _wait_real(0.6)
	p.health = p.max_health() * 0.4
	var hp0 := p.health
	p.arts.use("battle_cry")
	await _wait_real(0.5)
	await _shot("04_battle_cry")
	await _wait_real(1.5)
	_check("Battle Cry rallies", p.arts.rally_t > 0.0)
	_check("Battle Cry heals (%.0f -> %.0f)" % [hp0, p.health], p.health > hp0 + 5.0)
	await _shot("05_hud_cooldowns")
	# The trees.
	main.call("_open_codex", "skills")
	await _wait(40)
	await _shot("06_blade_tree")
	var page := (main.get("_overlay") as Node).find_children("*", "SkillsPage", true, false)
	if page.size() > 0:
		page[0].set("_chosen", "agility")
		page[0].call("_build")
		await _wait(20)
		await _shot("07_agility_tree")
	main.call("_overlay_close")
	print("ARTS %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)

func _foes(n: int, radius: float, at: Vector3 = Vector3.INF) -> Array:
	var p := world.player
	var out := []
	for k in n:
		var sk := Skeleton.new()
		sk.kind = "minion"
		sk.respawns = false
		var pos := at if at != Vector3.INF else p.global_position + Vector3(cos(TAU * k / n), 0, sin(TAU * k / n)) * radius
		pos.y = p.global_position.y + 0.3
		sk.home = pos
		world.add_child(sk)
		sk.global_position = pos
		out.append(sk)
	return out

func _hp(list: Array) -> Array:
	return list.map(func(s: Skeleton) -> float: return s.health)

func _hit_count(list: Array, before: Array) -> int:
	var n := 0
	for i in list.size():
		var s: Skeleton = list[i]
		if not is_instance_valid(s) or s.health < float(before[i]) or s.is_dead():
			n += 1
	return n

func _clear(list: Array) -> void:
	for s in list:
		if is_instance_valid(s):
			s.queue_free()

func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1

func _dismiss() -> void:
	var o := main.get("_overlay") as Control
	if o != null and o.has_signal("done"):
		o.emit_signal("done")
		o.queue_free()

func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame

func _wait_real(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_out, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("   wrote " + path)
