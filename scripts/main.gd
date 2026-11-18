extends Node
## The game's flow: loading while the island is built; the title over a
## slow flight round the village; then play. During play: E to talk, open
## or ring; Tab for the Codex (K skills, M map, J archive); Esc to pause,
## save and load; the awakening when it comes; falling and getting up.

var world: World
var hud: HUD
var _ui: CanvasLayer
var _menu: MainMenu
var _overlay: Control          ## the open Codex, shop, pause or awakening, if any
var _cine: Camera3D
var _cine_t := 0.0
var _fade: ColorRect
var playing := false
var play_seconds := 0.0
var _near: Node3D
var _seen_stage := -1
var _gate_id := ""
var _quest_t := 2.0
var _trial_rank := 0

const BEATS := {
	1: ["The Water Turns", ["The Warden is dust, and something under the island noticed.",
		"At the cove below Brightwater the sea has begun to climb the rocks.", "A Gate has opened there."]],
	2: ["The Bell Wakes", ["The Stair is still. Up at Highmoor, the bell rang once tonight with no one at the rope.",
		"Behind it, in the keep, something has opened."]],
	3: ["A Crown on the Mountain", ["The hours move again. From every door in Brightwater you can see it now:",
		"a light on the peak, the shape of a crown."]],
	4: ["The Sundered Crown", ["The king who was not a king is gone. The splinters of his crown are in all of us who woke.",
		"The Laws will not mend. But they are not hungry now. Not for a while.", "The world goes on. So do you."]],
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("main")
	_ui = CanvasLayer.new()
	_ui.layer = 10
	add_child(_ui)
	var loading := LoadingScreen.new()
	_ui.add_child(loading)
	world = World.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	await world.build(loading.report)
	world.sky.time_of_day = 0.69
	world.player.died.connect(_on_died)
	world.gull.sank.connect(func() -> void: _ship_sank(world.gull))
	world.player.crisis.connect(_awaken)
	_cine = Camera3D.new()
	_cine.far = 4000.0
	_cine.fov = 52.0
	add_child(_cine)
	_cine.make_current()
	hud = HUD.new()
	hud.world = world
	hud.visible = false
	_ui.add_child(hud)
	_ui.move_child(hud, 0)
	var pop := QuestPopup.new()
	pop.name = "QuestPopup"
	_ui.add_child(pop)
	_ui.move_child(pop, 1)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_ui.add_child(_fade)
	_show_menu()
	loading.finish()

# --- Title -----------------------------------------------------------------------------

func _show_menu() -> void:
	playing = false
	Game.playing = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world.sky.time_of_day = 0.69
	_cine.make_current()
	hud.visible = false
	_menu = MainMenu.new()
	_menu.begin.connect(_begin)
	_menu.quit_game.connect(func() -> void: get_tree().quit())
	_ui.add_child(_menu)
	_ui.move_child(_menu, _ui.get_child_count() - 2)

func _begin(slot: int) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.5)
	await tw.finished
	_menu.queue_free()
	_menu = null
	if slot >= 0 and not SaveSystem.read(slot).is_empty():
		play_seconds = SaveSystem.apply(SaveSystem.read(slot), world)
	else:
		Run.new_run()
		play_seconds = 0.0
		world.sky.time_of_day = 0.37
		var c := world.island.site_pos("village").lerp(world.island.site_pos("harbour"), 0.42)
		c.y = world.island.height_at(c.x, c.z) + 0.2
		world.player.revive(c)
	world.wilds.sync()
	world.rig.camera.make_current()
	world.rig.snap()
	hud.visible = true
	playing = true
	Game.playing = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_seen_stage = Story.stage()
	create_tween().tween_property(_fade, "modulate:a", 0.0, 0.9)
	if slot < 0:
		await get_tree().create_timer(1.0).timeout
		story_card("Aldermere", ["The last island to keep its crown, when the Realms broke apart.",
			"You came ashore at Brightwater with a sword, a shield and nothing owed to anyone.",
			"The dead are walking. That is not your problem. Yet."])

# --- Every frame ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if world == null or _cine == null:
		return
	if not playing:
		_cine_t += delta
		var c := world.village.centre
		var a := _cine_t * 0.035 + 2.2
		var eye := c + Vector3(sin(a) * 120.0, 0.0, cos(a) * 120.0)
		eye.y = maxf(world.island.height_at(eye.x, eye.z), 0.0) + 34.0
		_cine.global_position = eye
		_cine.look_at(c + Vector3(-sin(a) * 40.0, 6.0, -cos(a) * 40.0), Vector3.UP)
		return
	if not get_tree().paused:
		play_seconds += delta
		_quest_t -= delta
		if _quest_t <= 0.0 and _overlay == null:
			_quest_t = 0.5
			Run.update_quests()
	_update_interaction()
	# A new chapter of the story, told once.
	var st := Story.stage()
	if _seen_stage >= 0 and st > _seen_stage and _overlay == null and not world.in_gate():
		_seen_stage = st
		var beat: Array = BEATS[st]
		var lines: Array[String] = []
		for l in beat[1]:
			lines.append(str(l))
		story_card(str(beat[0]), lines)
	var lt := world.rig.lock_target
	if lt != null and (not is_instance_valid(lt) or bool(lt.call("is_dead"))
			or lt.global_position.distance_to(world.player.global_position) > 25.0):
		world.rig.lock_target = null

func _update_interaction() -> void:
	_near = null
	hud.prompt = ""
	if _overlay != null:
		return
	var p := world.player.global_position
	var best := 2.8
	for n in get_tree().get_nodes_in_group("interactables"):
		var node := n as Node3D
		if node == null or not node.is_visible_in_tree():
			continue
		var d := float(node.call("interact_distance", p)) if node.has_method("interact_distance") \
			else node.global_position.distance_to(p)
		if d < best and str(node.call("prompt_text")) != "":
			best = d
			_near = node
	if _near != null:
		hud.prompt = str(_near.call("prompt_text"))

# --- Input ------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not playing or _overlay != null:
		return
	if event.is_action_pressed("pause"):
		_open_pause()
	elif event.is_action_pressed("inventory"):
		_open_codex(Codex.last_page)
	elif event.is_action_pressed("skills"):
		_open_codex("skills")
	elif event.is_action_pressed("map"):
		_open_codex("map")
	elif event.is_action_pressed("archive"):
		_open_codex("archive")
	elif event.is_action_pressed("interact") and _near != null:
		_interact(_near)
	elif event.is_action_pressed("guide"):
		_show_the_way()
	elif event.is_action_pressed("lock_on"):
		world.rig.lock_target = null if world.rig.lock_target != null else world.player.nearest_enemy(22.0)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## T: golden wisps run from your feet toward the tracked quest's goal.
func _show_the_way() -> void:
	if world.in_gate():
		return
	var tgt := Quests.target_of(Run.tracked, world)
	if tgt == Vector3.INF:
		Run.toast.emit("Nowhere to point to" if Run.tracked != "" else "No quest is tracked", "warn")
		return
	for old in get_tree().get_nodes_in_group("guide_trails"):
		old.queue_free()
	var trail := GuideTrail.new()
	trail.add_to_group("guide_trails")
	trail.path = GuideTrail.plan(world.island, world.player.global_position, tgt)
	world.add_child(trail)
	Audio.ui("open", -8.0)

func _interact(n: Node3D) -> void:
	if n is Villager:
		var v := n as Villager
		if world.player.powers.silence_t > 0.0:
			Run.toast.emit("Your Inscription has taken your voice", "warn")
			return
		Run.met(v.display_name)
		Run.lean("sociability", 0.5)
		if v.display_name.begins_with("Tobin"):
			hud.say(v.display_name, "Need an edge? Or something to stop one? The anvil's yours if you'd rather make it.")
			_open_shop()
			return
		if v.display_name == "Elder Maren":
			_elder(v)
			return
		var said := Story.line_for(v.display_name)
		hud.say(v.display_name, said if said != "" else v.talk())
	else:
		n.call("interact", world.player)

func _elder(v: Villager) -> void:
	if Run.flags.has("warden_dead") and not Run.flags.has("elder_thanked"):
		Run.flags["elder_thanked"] = true
		hud.say(v.display_name, "The great one is fallen? Then the bells will be quiet tonight. Take these, with our thanks.")
		Run.add_silver(120)
		Run.add_item("red_potion", 3)
		Run.add_clue("elder_thanks", "Brightwater's Thanks", "Elder Maren paid me for the Warden. She did not ask what it was.")
		return
	if not Run.has_clue("elder_barrow"):
		Run.add_clue("elder_barrow", "The Dead of the Barrow",
			"Elder Maren says the dead walk out of the Barrow of Ash, north-west of Brightwater, and that something larger keeps them.")
	hud.say(v.display_name, v.talk())

# --- Overlays ---------------------------------------------------------------------------

func _overlay_open(c: Control) -> void:
	_overlay = c
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.prompt = ""
	hud.visible = false
	_ui.add_child(c)
	_ui.move_child(c, _ui.get_child_count() - 2)

func _overlay_close() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	get_tree().paused = false
	hud.visible = playing
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Audio.ui("close", -12.0)

func _open_codex(page: String) -> void:
	var c := Codex.new()
	c.world = world
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	c.closed.connect(_overlay_close)
	_overlay_open(c)
	c.open(page)

func _open_shop() -> void:
	var s := ShopPanel.new()
	s.process_mode = Node.PROCESS_MODE_ALWAYS
	s.closed.connect(_overlay_close)
	s.to_forge.connect(func() -> void:
		_overlay_close()
		_open_forge())
	_overlay_open(s)

## The forge: from Tobin's shop, or the anvil at any Waystone.
func _open_forge() -> void:
	var f := ForgePanel.new()
	f.process_mode = Node.PROCESS_MODE_ALWAYS
	f.closed.connect(_overlay_close)
	_overlay_open(f)

## Resting at a Waystone: whole again, Flask full, the fallen risen; then
## the stone's menu (travel, forge, the Flask, the hour).
func rest_at(ws: Waystone) -> void:
	if _overlay != null:
		return
	Run.last_waystone = ws.id
	world.player.rest_full()
	world.wilds.rest()
	Run.flags["rested"] = true
	Run.update_quests()
	var r := RestPanel.new()
	r.waystone = ws
	r.world = world
	r.process_mode = Node.PROCESS_MODE_ALWAYS
	r.closed.connect(_overlay_close)
	r.travel.connect(_travel)
	r.forge.connect(func() -> void:
		_overlay_close()
		_open_forge())
	r.call_ship.connect(func() -> void:
		var land := ws.global_position
		var yaw := atan2(ws.mooring.x - land.x, ws.mooring.z - land.z)
		world.gull.refloat(ws.mooring, yaw)
		Run.toast.emit("The Gull rides at anchor off %s" % ws.title, "item"))
	r.wait.connect(func(to_night: bool) -> void:
		world.sky.time_of_day = 0.84 if to_night else 0.3)
	_overlay_open(r)
	Audio.ui("confirm", -6.0)

func _travel(id: String) -> void:
	var ws := world.wilds.waystone(id)
	if ws == null:
		return
	_overlay_close()
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.5)
	await tw.finished
	Run.last_waystone = id
	world.player.global_position = ws.spawn_point()
	world.player.reset_physics_interpolation()
	world.player.model.rotation.y = ws.rotation.y
	world.rig.yaw = ws.rotation.y + PI
	world.rig.snap()
	world.grass.warm(world.player.global_position)
	await get_tree().create_timer(0.3).timeout
	create_tween().tween_property(_fade, "modulate:a", 0.0, 0.8)
	hud.show_banner(ws.title, "WAYSTONE")

## Where you get up after a fall: the last Waystone you rested at, or
## Brightwater's square.
func _respawn_point() -> Vector3:
	var ws := world.wilds.waystone(Run.last_waystone)
	if ws != null:
		return ws.spawn_point()
	var c := world.village.centre + Vector3(0, 0, 8)
	c.y = world.island.height_at(c.x, c.z) + 0.3
	return c

func _open_pause() -> void:
	var p := PauseMenu.new()
	p.resume.connect(_overlay_close)
	p.to_title.connect(func() -> void:
		_overlay_close()
		_show_menu())
	p.save_to.connect(func(slot: int) -> void:
		if world.in_gate():
			Run.toast.emit("You cannot save inside a Gate", "warn")
		elif SaveSystem.save(slot, world, play_seconds):
			Run.toast.emit("Saved", "item"))
	p.load_from.connect(func(slot: int) -> void:
		_overlay_close()
		play_seconds = SaveSystem.apply(SaveSystem.read(slot), world))
	_overlay_open(p)
	p.open()

## The Inscription wakes: generated from how you have played.
func _awaken() -> void:
	if not Run.law.is_empty() or _overlay != null:
		return
	Run.law = Law.generate(Run.profile, Game.SEED * 31 + int(play_seconds))
	Run.add_clue("awakening", "Awakening",
		"At the edge of dying, something in me woke. It calls itself %s, and it shows itself as %s." % [
			Run.law["name"], Run.law["expression"]])
	Run.changed.emit("law")
	world.player.heal(world.player.max_health() * 0.5)
	var a := Awakening.new()
	a.done.connect(func() -> void:
		_overlay = null
		Engine.time_scale = 1.0
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	_overlay = a
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_ui.add_child(a)
	_ui.move_child(a, _ui.get_child_count() - 2)
	Audio.ui("confirm", 0.0)

# --- The sea ----------------------------------------------------------------------------------

## Hands on the wheel: the camera pulls back to take in the ship.
func take_helm(ship: Ship) -> void:
	if ship.sunk:
		return
	ship.steering = true
	world.player.helm = ship
	world.player.state = Player.S.MOVE
	world.rig.target = ship.cam_point
	world.rig.distance = 22.0
	world.rig.lock_target = null
	world.rig.snap()
	Run.flags["helmed"] = true
	Audio.ui("open", -6.0)

func leave_helm(ship: Ship) -> void:
	ship.steering = false
	world.player.helm = null
	world.player.global_position = ship.helm_point() + ship.global_basis.x * 1.3
	world.player.velocity = Vector3.ZERO
	world.player.reset_physics_interpolation()
	world.rig.target = world.player
	world.rig.distance = 5.8
	world.rig.snap()

## Your ship went down: you are in the water, and she will be back at her
## mooring before long.
func _ship_sank(ship: Ship) -> void:
	if world.player.helm == ship:
		leave_helm(ship)
		world.player.global_position = ship.global_position + Vector3(0, Ship.SINK + 0.5, 0) + ship.global_basis.x * 6.0
	Run.toast.emit("%s is lost. She will be back at her mooring." % ship.title, "warn")
	await get_tree().create_timer(20.0).timeout
	ship.refloat(ship.home, ship.home_heading)
	Run.toast.emit("%s is afloat again at Brightwater" % ship.title, "item")

func _on_died() -> void:
	if world.player.helm != null:
		leave_helm(world.player.helm)
	# The silver you carried stays where you fell (at the Gate's mouth, if
	# you fell inside one).
	world.wilds.drop_silver(world.gate_return() if world.in_gate() else world.player.global_position)
	hud.on_player_died()
	await get_tree().create_timer(4.0).timeout
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.8)
	await tw.finished
	if world.in_gate():
		# Fallen inside: the Gate throws you out where you went in.
		if _trial_rank > 0:
			Run.toast.emit("The trial is lost. The catalyst is spent.", "warn")
			Run.add_clue("trial_failed_%d" % _trial_rank, "A Failed Trial",
				"I was not ready. The catalyst burned away in my hand while I lay on the stones.")
		world.exit_gate()
		_trial_rank = 0
		_gate_id = ""
		world.player.revive(_respawn_point() if Run.last_waystone != "" else world.player.global_position)
		world.player.rest_full()
		world.wilds.rest()
		world.rig.snap()
		hud.clear_death()
		create_tween().tween_property(_fade, "modulate:a", 0.0, 1.0)
		return
	world.player.revive(_respawn_point())
	Run.new_life()
	Run.chain = 0
	Run.chain_t = 0.0
	world.player.rest_full()
	world.wilds.rest()
	world.rig.snap()
	world.grass.warm(world.player.global_position)
	hud.clear_death()
	create_tween().tween_property(_fade, "modulate:a", 0.0, 1.0)

# --- Story, Gates and trials ------------------------------------------------------------

## A cinematic card with a title and a few lines; the world waits behind it.
func story_card(title: String, lines: Array[String]) -> void:
	var c := StoryCard.new()
	c.title = title
	c.lines = lines
	c.done.connect(func() -> void:
		_overlay = null
		get_tree().paused = false
		hud.visible = playing
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED)
	_overlay = c
	get_tree().paused = true
	hud.visible = false
	_ui.add_child(c)
	_ui.move_child(c, _ui.get_child_count() - 2)

func enter_gate(id: String, trial_rank: int = 0) -> void:
	_gate_id = id
	_trial_rank = trial_rank
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.6)
	await tw.finished
	world.enter_gate(id, trial_rank)
	world.gate_run.finished.connect(_gate_done)
	world.rig.lock_target = null
	create_tween().tween_property(_fade, "modulate:a", 0.0, 0.8)
	Audio.play("door", world.player.global_position, 2.0, 0.5)
	var first := trial_rank == 0 and not Run.flags.has("seen_" + id)
	if first:
		Run.flags["seen_" + id] = true
		var d: Dictionary = Story.GATES[id]
		story_card(str(d["name"]), [str(d["text"]), "A Gate of %s. Its keeper waits at the far end." % Law.principle_name(str(d["law"]))])
	else:
		hud.show_banner(str(world.gate_run.def["name"]), "GATE")

func _gate_done(cleared: bool) -> void:
	var id := _gate_id
	var trial := _trial_rank
	_gate_id = ""
	_trial_rank = 0
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.6)
	await tw.finished
	world.exit_gate()
	create_tween().tween_property(_fade, "modulate:a", 0.0, 0.8)
	if trial > 0 and cleared:
		Run.toast.emit("The trial is passed", "law")
		_open_codex("law")
		var page := (_overlay as Codex)
		await get_tree().process_frame
		for c in page.find_children("*", "LawPage", true, false):
			(c as LawPage).choose_dimension()
		return
	if cleared and id != "":
		Run.flags["gate_runs_" + id] = int(Run.flags.get("gate_runs_" + id, 0)) + 1
		if not Run.flags.has("gate_" + id):
			Run.flags["gate_" + id] = true
			Run.add_clue("cleared_" + id, str(Story.GATES[id]["name"]),
				"I went through and came out again. The keeper is gone. The Gate is quieter now, but it has not closed. They never do.")

## Ascension: the catalyst is spent, and you face the trial.
func start_trial(rank: int) -> void:
	var need: Dictionary = Law.RANKS.get(rank, {})
	if need.is_empty() or not Run.remove_item(str(need["catalyst"]), 1):
		return
	_overlay_close()
	enter_gate("", rank)
