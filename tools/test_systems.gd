extends Node
## Plays through the Elden-Ring-shaped systems headless (no window) and
## prints ok/FAIL for each: Waystones and travel, the Flask, dropping and
## recovering silver, the fallen staying down until a rest, stance breaks
## and critical blows, charged and leaping attacks, etched weapons, the
## Forge (craft, temper, etch, salvage, the hammer), field bosses, messages,
## bloodstains, quests and a save round trip.
##   Godot --headless --path . scenes/tools/TestSystems.tscn

var main: Node
var world: World
var _fails := 0

func _ready() -> void:
	# A watchdog: a stuck await should fail the run, not hang it.
	get_tree().create_timer(420.0, true, false, true).timeout.connect(func() -> void:
		print("SYSTEMS FAIL (timed out)")
		get_tree().quit(99))
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	while main.get("_menu") == null:
		await get_tree().process_frame
	main.call("_begin", -1)
	await _wait_real(2.0)
	_dismiss()
	await _wait_real(0.3)
	world = main.get("world")
	var p := world.player
	print("-- Waystones")
	var stones := get_tree().get_nodes_in_group("waystones")
	_check("nine Waystones placed (six on Aldermere, one per isle)", stones.size() == 9)
	var dry := true
	for n in stones:
		if (n as Node3D).global_position.y < 0.5:
			dry = false
	_check("every Waystone stands on dry land", dry)
	var first := world.wilds.waystone("harbour_road")
	_check("none kindled at the start", not first.kindled())
	p.health = 40.0
	Run.flask = 0
	first.interact(p)
	await _wait(3)
	_check("kindling lights it", first.kindled())
	_check("resting opens the Waystone menu", main.get("_overlay") is RestPanel)
	_check("resting heals and fills the Flask", p.health >= p.max_health() and Run.flask == Run.flask_max)
	_check("it becomes where you get up", Run.last_waystone == "harbour_road")
	var rest := main.get("_overlay") as RestPanel
	rest.call("_show_flask")
	rest.call("_show_travel")
	await _wait(3)
	main.call("_overlay_close")
	await _wait(3)
	print("-- The Flask")
	await _wait_real(0.3)
	p.health = 50.0
	var before := Run.flask
	p.drink_flask()
	_check("a draught heals (50 -> %d)" % int(p.health), p.health > 100.0)
	_check("and uses a charge", Run.flask == before - 1)
	await _wait_real(0.6)
	Run.flask = 0
	var hp := p.health
	p.drink_flask()
	_check("an empty Flask does nothing", p.health == hp)
	print("-- Falling and your silver")
	Run.flask = Run.flask_max
	Run.silver = 120
	var foe_dummy := Node3D.new()
	world.add_child(foe_dummy)
	foe_dummy.global_position = p.global_position + Vector3(0, 0, 3)
	var fell_at := p.global_position
	p.take_hit(9999.0, foe_dummy)
	await _wait(2)
	_check("falling drops the silver", Run.silver == 0 and int(Run.lost.get("silver", 0)) == 120)
	_check("it lies where you fell", get_tree().get_nodes_in_group("lost_silver").size() == 1)
	await _wait_real(6.0)
	_check("you get up at the Waystone", p.global_position.distance_to(first.spawn_point()) < 3.0
		and p.state != Player.S.DEAD)
	p.global_position = fell_at + Vector3.UP * 0.5
	await _wait_real(1.4)
	_check("walking back to it recovers it (%d)" % Run.silver, Run.silver == 120 and Run.lost.is_empty())
	foe_dummy.queue_free()
	print("-- The fallen stay down until you rest")
	var sk := _foe("minion", p.global_position + Vector3(8, 0, 8))
	await _wait_real(0.3)
	sk.take_hit(999.0, p)
	await _wait_real(9.6)
	_check("a fallen skeleton is gone, not back", not sk.visible and sk.is_in_group("fallen"))
	world.wilds.rest()
	await _wait(2)
	_check("rest raises it", sk.visible and not sk.is_dead())
	sk.queue_free()
	print("-- Stance and critical blows")
	await _wait_real(0.6)
	var w := _foe("warrior", p.global_position + p.model.global_basis.z * 1.6)
	await _wait_real(0.2)
	w.health = 2000.0
	w.max_health = 2000.0
	w.take_hit(5.0, p, w.max_posture * 0.5)
	_check("blows fill its stance (%.0f%%)" % (w.posture_fraction() * 100.0), w.posture_fraction() > 0.3)
	w.take_hit(5.0, p, w.max_posture)
	_check("a full stance breaks", w.is_broken())
	await _wait(2)
	var hp0 := w.health
	p.state = Player.S.MOVE
	p.call("_start_attack", 0, Vector3.ZERO)
	_check("the swing becomes a critical", bool(p.get("_crit")))
	await _wait_real(0.8)
	var crit := hp0 - w.health
	_check("a critical blow lands hard (%.0f)" % crit, crit >= float(p.weapon()["damage"]) * 2.5)
	_check("and ends the break", not w.is_broken())
	print("-- Charged and leaping attacks")
	await _wait_real(0.8)
	w.global_position = p.global_position + p.model.global_basis.z * 1.5
	w.posture = 0.0
	w.bind_for(4.0)
	hp0 = w.health
	p.stamina = p.max_stamina()
	p.state = Player.S.MOVE
	Input.action_press("attack")
	p.call("_start_attack", 0, Vector3.ZERO)
	var charged := false
	for k in 40:
		await get_tree().physics_frame
		if p.state == Player.S.CHARGE:
			charged = true
	await _wait_real(0.5)
	Input.action_release("attack")
	await _wait_real(0.9)
	var heavy := hp0 - w.health
	_check("holding the attack charges it", charged)
	_check("the charged blow hits harder (%.0f)" % heavy, heavy >= float(p.weapon()["damage"]) * 1.8)
	await _wait_real(0.6)
	w.global_position = p.global_position + p.model.global_basis.z * 1.4
	w.posture = 0.0
	w.bind_for(4.0)
	hp0 = w.health
	p.velocity.y = 7.0
	await _wait_real(0.25)
	p.call("_start_jump_attack")
	_check("an attack in the air is a leaping blow", bool(p.get("_jump_atk")))
	await _wait_real(1.0)
	_check("it lands on them (%.0f)" % (hp0 - w.health), hp0 - w.health >= float(p.weapon()["damage"]) * 1.5)
	w.queue_free()
	print("-- The Forge")
	Run.bounties = []
	Run.add_silver(3000, true)
	for it in [["iron_scrap", 30], ["star_iron", 8], ["ember_coal", 4], ["grave_dust", 8], ["bone_shard", 10],
			["rime_salt", 4]]:
		Run.add_item(str(it[0]), int(it[1]), true)
	var scrap := Run.count("iron_scrap")
	var id := Forge.craft("greatsword", "star", "ember", 1.0)
	var d := Run.item(id)
	_check("forging makes a weapon (%s)" % str(d.get("name", "")), id != "" and Run.count(id) == 1)
	_check("perfect hammering makes a Masterwork", str(d["name"]).begins_with("Masterwork"))
	_check("star-iron and quality raise its damage (%d)" % int(d["damage"]), int(d["damage"]) == 57)
	_check("it cost the materials", Run.count("iron_scrap") == scrap - 6)
	var lv := 0
	for k in 6:
		if Forge.temper(id):
			lv += 1
	_check("tempering stops at +5", lv == 5 and Forge.temper_level(id) == 5)
	_check("tempered damage (%d)" % int(Run.item(id)["damage"]), int(Run.item(id)["damage"]) == int(roundf(57.0 * 1.5)))
	_check("etching changes it", Forge.etch(id, "rime") and str(Run.item(id)["etch"]) == "rime")
	Run.equip(id)
	await _wait(3)
	_check("an etched weapon glows in the hand", _glowing(p))
	var bone := Forge.craft("dagger", "bone", "none", 0.0)
	var got := Forge.salvage_yield(bone)
	_check("salvage gives something back", not got.is_empty() and Forge.salvage(bone) and Run.count(bone) == 0)
	_check("what you hold cannot be broken down", not Forge.can_salvage(id))
	print("-- Etched hits")
	var e := _foe("minion", p.global_position + p.model.global_basis.z * 1.5)
	await _wait_real(0.3)
	e.health = 900.0
	e.max_health = 900.0
	p.call("_apply_etch", e, 10.0)
	_check("rime chills", float(e.get("_chill_t")) > 0.0)
	e.burn_for(3.0, 4.0)
	hp0 = e.health
	await _wait_real(2.2)
	_check("embers burn over time (%.0f)" % (hp0 - e.health), hp0 - e.health >= 7.0)
	e.queue_free()
	print("-- The Forge screen and the hammer")
	main.call("_open_forge")
	await _wait(4)
	var fp := main.get("_overlay") as ForgePanel
	_check("the anvil opens", fp != null)
	for tab in ["temper", "salvage", "forge"]:
		fp.set("_tab", tab)
		fp.call("_build")
		await _wait(2)
	var n_before := Run.forge_count
	fp.set("_form", "axe")
	fp.set("_metal", "grave")
	fp.set("_etching", "grave")
	fp.call("_start_hammer")
	await _wait(2)
	var hg: Control = fp.get("_hammer")
	for k in 3:
		hg.set("_x", 0.5)
		var ev := InputEventAction.new()
		ev.action = "jump"
		ev.pressed = true
		hg.call("_input", ev)
		await _wait_real(0.15)
	await _wait_real(1.0)
	_check("three blows forge it", Run.forge_count == n_before + 1)
	_check("three perfect blows make a Masterwork",
		str(Run.item("forged_%d" % Run.forge_count).get("name", "")).begins_with("Masterwork"))
	main.call("_overlay_close")
	await _wait(3)
	main.call("_open_shop")
	await _wait(3)
	_check("the shop has a way to the anvil", (main.get("_overlay") as ShopPanel).has_signal("to_forge"))
	main.call("_overlay_close")
	for page in ["map", "inventory", "journey"]:
		main.call("_open_codex", page)
		await _wait(4)
		main.call("_overlay_close")
		await _wait(2)
	print("-- Travel")
	Run.flags["way_crossroads"] = true
	world.wilds.waystone("crossroads").refresh()
	main.call("_travel", "crossroads")
	await _wait_real(1.4)
	_check("travel takes you to the stone", p.global_position.distance_to(world.wilds.waystone("crossroads").spawn_point()) < 3.0)
	_check("and it becomes where you get up", Run.last_waystone == "crossroads")
	print("-- Field bosses")
	var captain: Skeleton = null
	for b in get_tree().get_nodes_in_group("boss"):
		if (b as Skeleton).kind == "drowned_captain":
			captain = b
	_check("the Drowned Captain is on the shore", captain != null and captain.global_position.y > 0.3)
	world.sky.time_of_day = 0.9
	await _wait_real(1.3)
	var knight: Skeleton = world.wilds.get("_knight")
	_check("the Grave Knight walks at night", knight != null and is_instance_valid(knight))
	world.sky.time_of_day = 0.4
	await _wait_real(1.3)
	_check("and is gone by day", not is_instance_valid(knight) or knight.is_queued_for_deletion())
	if captain != null:
		captain.take_hit(99999.0, p)
		await _wait(3)
		var drops := []
		for n in world.wilds.get_children():
			if n is Pickup:
				drops.append((n as Pickup).id)
		_check("the Captain drops his shield and star-iron %s" % str(drops),
			"tidecaller_buckler" in drops and "star_iron" in drops)
		_check("and stays dead", Run.flags.has("fb_drowned_captain"))
	print("-- Messages and bloodstains")
	var msgs := 0
	var stain: Bloodstain = null
	for n in world.wilds.get_children():
		if n is GroundMessage:
			msgs += 1
		elif n is Bloodstain and stain == null:
			stain = n
	_check("words on the ground (%d)" % msgs, msgs >= 12)
	stain.interact(p)
	await _wait(3)
	_check("a bloodstain shows a shade", stain.get_child_count() >= 2)
	await _wait_real(6.5)
	_check("which fades", stain.get_child_count() == 1)
	print("-- The Arts still land")
	var ring := [_foe("minion", p.global_position + Vector3(2, 0, 0)), _foe("minion", p.global_position + Vector3(-2, 0, 0))]
	await _wait_real(0.4)
	for r in ring:
		(r as Skeleton).bind_for(3.0)
	p.state = Player.S.MOVE
	p.stamina = p.max_stamina()
	p.arts.use("whirlwind")
	await _wait_real(0.6)
	var hurt := 0
	for r in ring:
		if (r as Skeleton).is_dead() or (r as Skeleton).health < (r as Skeleton).max_health:
			hurt += 1
		(r as Node).queue_free()
	_check("Whirlwind hits both (%d)" % hurt, hurt == 2)
	print("-- Renown")
	var lvl0 := Run.renown_level
	var mh0 := p.max_health()
	var pts0 := Run.renown_points
	var ups := []
	Run.level_up.connect(func(l: int, r: String) -> void: ups.append([l, r]))
	p.health = 10.0
	Run.renown(Run.renown_need(Run.renown_level) - Run.renown_xp + 1.0)
	_check("enough Renown raises the level (%d -> %d)" % [lvl0, Run.renown_level], Run.renown_level == lvl0 + 1)
	_check("the level-up says what it gave (%s)" % str(ups), ups.size() == 1 and str(ups[0][1]) != "")
	_check("each level adds health", p.max_health() > mh0)
	_check("and heals you whole", p.health >= p.max_health() - 0.5)
	_check("even levels give a Renown point", Renown.reward_for(2)[0] == "point" and Renown.reward_for(4)[0] == "point")
	_check("odd levels give things (%s)" % Renown.describe(Renown.reward_for(3)), Renown.reward_for(3)[0] == "hearth_seed")
	_check("every tenth is a relic", Renown.reward_for(10)[0] == "loot:relic")
	Run.renown_points = 1
	for t in ["blade", "guard", "agility", "vitality"]:
		Run.skills[t]["points"] = 0
	_check("a Renown point buys a perk in any tree", Run.unlock("keen_edge") and Run.renown_points == 0)
	print("-- Chains and bounties")
	Run.chain = 0
	Run.chain_t = 0.0
	var c0 := Run.bounties_done
	_check("three bounties are always up", Run.bounties.size() == 3)
	Run.bounties[0] = {"kind": "kill", "text": "Put down 2 risen", "need": 2, "have": 0, "xp": 50, "silver": 20}
	var xp_before := Run.renown_level * 100000.0 + Run.renown_xp
	for k in 3:
		var m := _foe("minion", p.global_position + Vector3(3 + k, 0, 3))
		await _wait(2)
		m.take_hit(9999.0, p)
	_check("quick kills build a chain (×%d)" % Run.chain, Run.chain == 3)
	_check("a chain raises the gains (%.1f×)" % Run.gain_mult(), Run.gain_mult() > 1.15)
	_check("a finished bounty pays and is replaced", Run.bounties_done >= c0 + 1 and Run.bounties.size() == 3)
	_check("kills give Renown", Run.renown_level * 100000.0 + Run.renown_xp > xp_before)
	_check("this life is tallied (%d kills)" % int(Run.life["kills"]), int(Run.life["kills"]) >= 3)
	Run.chain_t = 0.01
	await _wait_real(0.1)
	_check("the chain breaks when you stop", Run.chain == 0)
	print("-- Loot")
	var tiers_ok := true
	for tier in ["common", "fine", "rare", "relic"]:
		var lid := Loot.roll_weapon(tier)
		var ld := Run.item(lid)
		if str(ld.get("rarity", "")) != tier or float(ld.get("damage", 0)) <= 0.0 or str(ld.get("model", "")) == "":
			tiers_ok = false
	_check("weapons roll in every rarity", tiers_ok)
	var relic := Run.item(Loot.roll_weapon("relic"))
	_check("relics have names of their own (%s)" % str(relic["name"]), str(relic["name"]).contains(","))
	var sh := Run.item(Loot.roll_shield("rare"))
	_check("shields roll too (%s, %d%%)" % [str(sh["name"]), int(float(sh["block"]) * 100.0)], sh["kind"] == "shield")
	var picks := 0
	for n in world.get_children():
		if n is Pickup:
			picks += 1
	Loot.maybe_drop(world, p.global_position + Vector3(4, 0, 0), 1.0, 1.0)
	var picks2 := 0
	for n in world.get_children():
		if n is Pickup:
			picks2 += 1
	_check("the risen can drop it", picks2 == picks + 1)
	var luck := {"common": 0, "fine": 0, "rare": 0, "relic": 0}
	for k in 2000:
		luck[Loot.tier_roll(1.0)] += 1
	_check("rarer is rarer %s" % str(luck), luck["common"] > luck["fine"] and luck["fine"] > luck["rare"] and luck["rare"] > luck["relic"])
	print("-- Elites")
	Run.surge = true
	var el: Skeleton = null
	for k in 80:
		var cand := _foe("warrior", p.global_position + Vector3(10, 0, 10))
		await _wait(1)
		if cand.elite:
			el = cand
			break
		cand.queue_free()
	Run.surge = false
	_check("some of the risen are Elites", el != null)
	if el != null:
		_check("an Elite has a trait in its name (%s)" % el.kind_name(), el.kind_name() != "Risen Warrior")
		_check("and more health (%d)" % int(el.max_health), el.max_health > 80.0 * 1.5)
		var lv_before := Run.renown_level * 100000.0 + Run.renown_xp
		el.take_hit(99999.0, p)
		await _wait(2)
		_check("and is worth more", Run.renown_level * 100000.0 + Run.renown_xp > lv_before + 40.0)
	print("-- The Grave Thief")
	var th := _foe("thief", p.global_position + Vector3(6, 0, 0))
	th.respawns = false
	await _wait_real(0.4)
	var d0 := th.global_position.distance_to(p.global_position)
	await _wait_real(1.2)
	_check("a thief runs once it sees you (%.0f -> %.0f m)" % [d0, th.global_position.distance_to(p.global_position)],
		th.global_position.distance_to(p.global_position) > d0 + 2.0)
	var coins := 0
	for n in world.get_children():
		if n is Pickup and (n as Pickup).id == "silver":
			coins += 1
	th.take_hit(5.0, p)
	var coins2 := 0
	for n in world.get_children():
		if n is Pickup and (n as Pickup).id == "silver":
			coins2 += 1
	_check("striking it shakes coin loose", coins2 > coins)
	Run.bounties[1] = {"kind": "thief", "text": "Catch a Grave Thief", "need": 1, "have": 0, "xp": 50, "silver": 20}
	var bd := Run.bounties_done
	th.take_hit(99999.0, p)
	await _wait(2)
	_check("catching it counts (%d bounties done)" % (Run.bounties_done - bd), Run.bounties_done >= bd + 1)
	print("-- Rift Surge nights")
	world.sky.time_of_day = 0.4
	world.wilds.set("_was_night", false)
	Run.nights = 1
	world.sky.time_of_day = 0.9
	await _wait_real(1.3)
	_check("the second nightfall surges", Run.surge and Run.nights == 2)
	_check("and says so", str((main.get("hud") as HUD).get("_banner")) == "The Rift Surges")
	world.sky.time_of_day = 0.4
	await _wait_real(1.3)
	_check("dawn ends it", not Run.surge)
	print("-- Exploration")
	var ex := Run.explored()
	Run.flags["msg_13"] = true
	_check("Aldermere counts what you find (%d / %d)" % [ex.x, ex.y], ex.y == 56 and Run.explored().x >= ex.x)
	print("-- Gates stand on dry land")
	var dry_gates := true
	for g in get_tree().get_nodes_in_group("gates"):
		var gp := (g as Node3D).global_position
		if world.ground(gp.x, gp.z) < 1.0:
			dry_gates = false
			print("     wet gate at ", gp)
	_check("no Gate is in the sea", dry_gates)
	print("-- The isles")
	for isle in Isles.ISLES.keys():
		var ic := Isles.centre(isle)
		var ok := Isles.height_at(ic.x, ic.z) > 2.0 and world.island.height_at(ic.x, ic.z) < -6.0 \
			and Isles.landing(isle).y > 0.5 and world.wilds.waystone("isle_" + isle) != null
		_check("%s rises out of open sea, with a landing and a stone" % Isles.ISLES[isle]["name"], ok)
	var crew := 0
	for n in world.isles.get_children():
		if n is Skeleton:
			crew += 1
	_check("the isles have crews of the Drowned (%d)" % crew, crew >= 12)
	print("-- Swimming")
	var bay := world.island.site_pos("harbour")
	var out := (Vector3(430, 0, 610) - bay) * Vector3(1, 0, 1)
	out = out.normalized()
	var shore := bay
	for k in 300:
		var q := bay + out * float(k)
		if world.ground(q.x, q.z) < -3.0:
			shore = q
			break
	p.global_position = shore + out * 4.0 + Vector3(0, -0.5, 0)
	p.reset_physics_interpolation()
	await _wait_real(0.8)
	_check("in deep water you swim (%.1f m down)" % p.global_position.y, p.state == Player.S.SWIM)
	_check("with your head out of the water", p.global_position.y > -1.8 and p.global_position.y < -0.8)
	world.rig.yaw = atan2(out.x, out.z)
	Input.action_press("move_forward")
	var out_of_water := false
	for k in 160:
		await get_tree().physics_frame
		if p.state != Player.S.SWIM and p.state != Player.S.CLIMB and p.global_position.y > -0.6:
			out_of_water = true
			break
	await _wait_real(0.6)
	Input.action_release("move_forward")
	_check("swimming to shore gets you out (at %.1f m)" % p.global_position.y, out_of_water)
	print("-- The Gull")
	var gull := world.gull
	_check("your ship rides at the harbour", gull != null and absf(gull.global_position.y + Ship.SINK) < 0.6)
	p.global_position = gull.to_global(Vector3(5.5, Ship.SINK - 1.2, 0))
	p.reset_physics_interpolation()
	await _wait_real(0.5)
	_check("from the water you can climb aboard", gull.interact_distance(p.global_position) < 2.8)
	gull.interact(p)
	await _wait_real(0.5)
	_check("and you stand on her deck", gull.on_deck(p.global_position))
	main.call("take_helm", gull)
	await _wait(3)
	_check("taking the helm", p.helm == gull and world.rig.target == gull.cam_point)
	var start := gull.global_position
	gull.anchored = false
	gull.sail = 2
	await _wait_real(4.0)
	_check("full sail carries her (%.1f m/s, %.0f m)" % [gull.speed, start.distance_to(gull.global_position)],
		gull.speed > 2.0 and start.distance_to(gull.global_position) > 6.0)
	_check("you stay at the wheel", p.global_position.distance_to(gull.helm_point()) < 0.5)
	main.call("leave_helm", gull)
	await _wait_real(2.5)
	_check("let go of the wheel and you ride the deck as she sails", gull.on_deck(p.global_position))
	gull.anchored = true
	print("-- Running aground")
	gull.refloat(shore + out * 20.0, atan2(-out.x, -out.z))
	gull.anchored = false
	gull.sail = 2
	await _wait_real(5.0)
	var keel := world.ground(gull.global_position.x, gull.global_position.z)
	_check("the keel stops her in the shallows (ground %.1f m under her)" % keel, keel < -2.0)
	print("-- Cannons and the Drowned Galleon")
	Run.discover("isle_skull_key")
	world.isles.set("_galleon_t", 0.0)
	await _wait_real(0.8)
	var gal: Ship = world.isles.get("galleon")
	_check("a ghost ship comes once you have found an isle", gal != null and gal.hostile)
	var sea_spot := Isles.mooring("skull_key")
	p.global_position = world.island.site_pos("village") + Vector3.UP
	p.velocity = Vector3.ZERO
	gull.refloat(sea_spot, 0.0)
	var seaward := (sea_spot - Isles.centre("skull_key")) * Vector3(1, 0, 1)
	gal.refloat(sea_spot + seaward.normalized() * 50.0, 0.0)
	await _wait_physics(3)
	gal.set_physics_process(false)
	var gh := gal.hull
	gull.fire(1 if (gal.global_position - gull.global_position).dot(gull.global_basis.x) > 0.0 else -1,
		Cannonball.GRAVITY * (50.0 / 34.0) * 0.5, gal.global_position)
	var closest := 999.0
	var until := Time.get_ticks_msec() + 2600
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame
		for n in world.get_children():
			if n is Cannonball:
				var l := gal.to_local((n as Node3D).global_position)
				closest = minf(closest, absf(l.x) + absf(l.z))
	_check("your broadside holes it (%.0f -> %.0f)" % [gh, gal.hull], gal.hull < gh)
	var my := gull.hull
	gal.set_physics_process(true)
	gal.set("_cool", {1: 0.0, -1: 0.0})
	await _wait_real(9.0)
	_check("it fires back (%.0f -> %.0f)" % [my, gull.hull], gull.hull < my)
	gal.damage(9999.0)
	await _wait(3)
	var flot := 0
	for n in world.isles.get_children():
		if n is Pickup:
			flot += 1
	_check("sunk, it spills its hold (%d)" % flot, flot >= 4 and Run.flags.has("galleon_sunk"))
	print("-- Losing your ship")
	gull.damage(9999.0)
	_check("a holed ship sinks", gull.sunk)
	await _wait_real(21.5)
	_check("and is afloat again at her mooring", not gull.sunk and gull.global_position.distance_to(gull.home) < 25.0)
	print("-- Treasure")
	_check("you start with a map to Skull Key", 0 in Treasure.held_sites())
	var site: Treasure = null
	for ds in get_tree().get_nodes_in_group("dig_sites"):
		if (ds as Treasure).index == 0:
			site = ds
	p.global_position = site.global_position + Vector3.UP * 0.5
	p.reset_physics_interpolation()
	await _wait_real(0.5)
	_check("the X says Dig", site.prompt_text() == "Dig")
	var purse := Run.silver
	var used := ""
	for b in Run.bag:
		if str(b["id"]).begins_with("map_") and int(Run.item(str(b["id"])).get("site", -1)) == 0:
			used = str(b["id"])
	site.interact(p)
	await _wait_real(6.0)
	_check("digging brings up a chest of silver (+%d)" % (Run.silver - purse), Run.silver > purse + 50 and Run.flags.has("dug"))
	_check("and uses the map", used != "" and Run.count(used) == 0)
	print("-- Calling your ship")
	var isle_stone := world.wilds.waystone("isle_skull_key")
	main.call("rest_at", isle_stone)
	await _wait(3)
	(main.get("_overlay") as RestPanel).call("_call_ship")
	await _wait_physics(3)
	_check("a seaside stone calls the Gull to it (%.0f m off)" % gull.global_position.distance_to(isle_stone.mooring),
		Vector2(gull.global_position.x, gull.global_position.z).distance_to(Vector2(isle_stone.mooring.x, isle_stone.mooring.z)) < 15.0)
	Run.update_quests()
	_check("The Open Sea is done", bool(Run.quests.get("open_sea", {}).get("done", false)))
	print("-- Quests and saving")
	Run.update_quests(true)
	_check("the Waystone quest is done", bool(Run.quests.get("kindling", {}).get("done", false)))
	_check("the forge quest is done", bool(Run.quests.get("smiths_fire", {}).get("done", false)))
	var saved := JSON.parse_string(JSON.stringify(Run.to_dict())) as Dictionary
	var name_before := str(Run.item(id)["name"])
	Run.new_run()
	Run.from_dict(saved)
	_check("forged, tempered and etched weapons survive a save (%s)" % str(Run.item(id).get("name", "")),
		str(Run.item(id).get("name", "")) == name_before and str(Run.item(id).get("etch", "")) == "rime")
	_check("the Flask survives a save", Run.flask_max >= 4)
	_check("Renown and bounties survive a save", Run.renown_level > 1 and Run.bounties.size() == 3)
	(main.get("hud") as Control).queue_redraw()
	await _wait(3)
	print("SYSTEMS %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)

func _foe(kind: String, at: Vector3) -> Skeleton:
	var sk := Skeleton.new()
	sk.kind = kind
	sk.respawns = true
	at.y = world.island.height_at(at.x, at.z) + 0.3
	sk.home = at
	world.add_child(sk)
	sk.global_position = at
	return sk

func _glowing(p: Player) -> bool:
	for n in p.model.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).material_overlay != null:
			return true
	return false

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

func _wait_physics(ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame

func _wait_real(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
