class_name HUD
extends Control
## The play screen, in the Heraldry style: little on screen, all of it solid
## and readable.
##   top left      the Law sigil and the health and stamina bars
##   top centre    a compass with the places you know
##   top right     silver, and notices sliding in under it
##   bottom        the hotbar, the E prompt, speech, the boss's bar
##   bottom right  your Inscription's powers, once it has woken

var world: World
var prompt := ""
var _trail := 100.0
var _shown_hp := 100.0
var _numbers: Array = []
var _toasts: Array = []
var _banner := ""
var _banner_tag := "NEW PLACE"
var _banner_sub := ""
var _xp_flash := 0.0
var _xp_last := 0.0
var _chain_pop := 0.0
var _chain_seen := 0
var _bounty_flash := {}         ## {text, reward, t} for a moment after one is done
var _banner_t := 99.0
var _last_site := ""
var _dead_t := -1.0
var _say_name := ""
var _say_text := ""
var _say_t := 99.0
var _hot_pop: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]

const PLACES := {"village": "person", "harbour": "pin", "castle": "shield", "barrow": "skull", "tower": "pin",
	"crossroads": "pin"}
const TOAST_LOOK := {"item": ["bag", Color("c9c4bb")], "silver": ["coin", Color("e3b252")],
	"skill": ["star", Color("e3b252")], "law": ["sigil", Color("9b8cf2")], "clue": ["scroll", Color("f3ece0")],
	"place": ["pin", Color("6fbf73")], "warn": ["lock", Color("d9473d")],
	"loot_common": ["sword", Color("c9c4bb")], "loot_fine": ["sword", Color("5fb3ff")],
	"loot_rare": ["sword", Color("c084fc")], "loot_relic": ["sword", Color("f2c14e")]}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("hud")
	Run.toast.connect(_on_toast)
	Run.level_up.connect(func(level: int, reward: String) -> void:
		show_banner("Renown %d" % level, "LEVEL UP", reward))
	Run.bounty_done.connect(func(text: String, reward: String) -> void:
		_bounty_flash = {"text": text, "reward": reward, "t": 0.0}
		Audio.ui("confirm", -2.0))
	Run.changed.connect(func(what: String) -> void:
		if what == "renown":
			_xp_flash = 1.0
			_xp_last = Run.last_gain
		elif what == "chain" and Run.chain > _chain_seen:
			_chain_pop = 1.0
		if what == "chain":
			_chain_seen = Run.chain)
	Icons.updated.connect(func(_id: String) -> void: queue_redraw())

func _on_toast(text: String, kind: String) -> void:
	_toasts.push_front({"text": text, "kind": kind, "t": 0.0})
	if _toasts.size() > 5:
		_toasts.pop_back()
	if kind in ["skill", "law", "clue"]:
		Audio.ui("confirm", -8.0)

func pop_number(at: Vector3, amount: float, col: Color = Color(1, 0.95, 0.85), big: bool = false) -> void:
	_numbers.append({"pos": at, "text": str(int(round(amount))), "t": 0.0, "col": col, "big": big,
		"drift": Vector2(randf_range(-24, 24), 0)})

## Words that float up from something in the world: "CRITICAL", "STANCE BROKEN".
func pop_text(at: Vector3, text: String, col: Color) -> void:
	_numbers.append({"pos": at, "text": text, "t": 0.0, "col": col, "big": true, "drift": Vector2.ZERO})

func say(who: String, text: String) -> void:
	_say_name = who
	_say_text = text
	_say_t = 0.0

func show_banner(text: String, tag: String = "NEW PLACE", sub: String = "") -> void:
	_banner = text
	_banner_tag = tag
	_banner_sub = sub
	_banner_t = 0.0

func on_player_died() -> void:
	_dead_t = 0.0

func clear_death() -> void:
	_dead_t = -1.0

func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	var p := world.player
	_shown_hp = lerpf(_shown_hp, p.health, clampf(delta * 12.0, 0.0, 1.0))
	_trail = p.health if p.health > _trail else move_toward(_trail, p.health, delta * 26.0)
	_banner_t += delta
	_say_t += delta
	_xp_flash = maxf(0.0, _xp_flash - delta * 1.2)
	_chain_pop = maxf(0.0, _chain_pop - delta * 4.0)
	if not _bounty_flash.is_empty():
		_bounty_flash["t"] = float(_bounty_flash["t"]) + delta
		if float(_bounty_flash["t"]) > 4.0:
			_bounty_flash = {}
	if _dead_t >= 0.0:
		_dead_t += delta
	for n in _numbers:
		n["t"] = float(n["t"]) + delta
	_numbers = _numbers.filter(func(n: Dictionary) -> bool: return float(n["t"]) < 1.1)
	for t in _toasts:
		t["t"] = float(t["t"]) + delta
	_toasts = _toasts.filter(func(t: Dictionary) -> bool: return float(t["t"]) < 4.5)
	for i in 5:
		_hot_pop[i] = maxf(0.0, _hot_pop[i] - delta)
		if Game.playing and Input.is_action_just_pressed("hotbar_%d" % (i + 1)):
			_hot_pop[i] = 0.18
	var here := ""
	if world.in_gate():
		queue_redraw()
		return
	for id in Island.SITES.keys():
		var s: Dictionary = Island.SITES[id]
		if Vector2(p.global_position.x, p.global_position.z).distance_to(s["pos"]) < float(s["radius"]):
			here = id
	if here != _last_site:
		_last_site = here
		if here != "" and Run.discover(here):
			show_banner(str(Island.SITES[here]["name"]))
	queue_redraw()

func _draw() -> void:
	if world == null or world.player == null:
		return
	var vp := get_viewport_rect().size
	_draw_vitals()
	_draw_tracker(vp)
	_draw_compass(vp)
	_draw_silver(vp)
	_draw_toasts(vp)
	_draw_enemy_bars()
	_draw_numbers()
	_draw_boss(vp)
	if world.player.helm != null:
		_draw_helm(vp, world.player.helm)
	else:
		_draw_hotbar(vp)
		_draw_arts(vp)
	_draw_enemy_ship(vp)
	_draw_renown(vp)
	_draw_chain(vp)
	_draw_bounty()
	_draw_powers(vp)
	_draw_prompt(vp)
	_draw_dialogue(vp)
	_draw_banner(vp)
	_draw_death(vp)

static func chip(fill: Color, rim: Color = Kit.GOLD_DEEP) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = fill
	b.border_color = rim
	b.set_border_width_all(2)
	b.set_corner_radius_all(8)
	b.anti_aliasing = true
	b.shadow_color = Kit.SHADOW
	b.shadow_size = 1
	b.shadow_offset = Vector2(0, 4)
	return b

# --- Sigil and bars ---------------------------------------------------------------------

func _draw_vitals() -> void:
	var p := world.player
	var c := Vector2(70, 70)
	draw_sigil(self, c, 34.0)
	var x := c.x + 50.0
	var hp_w := minf(260.0 + (p.max_health() - Player.MAX_HEALTH) * 1.4, 480.0)
	bar(self, Rect2(x, c.y - 16, hp_w, 13), _shown_hp / p.max_health(), _trail / p.max_health(), Kit.RED, Color("ff8a7a"))
	bar(self, Rect2(x, c.y + 6, 200, 8), p.stamina / p.max_stamina(), 0.0, Color("e6c15a"), Color("fff0b0"))
	# The Flask: draughts left (R), refilled at a Waystone.
	var pc := Vector2(x + hp_w + 30, c.y - 9)
	var full := Run.flask > 0
	draw_circle(pc + Vector2(0, 5), 9.0, Kit.IVORY, true, -1.0, true)
	draw_circle(pc + Vector2(0, 6), 7.0, Color("e0643a") if full else Kit.INK_3, true, -1.0, true)
	draw_rect(Rect2(pc + Vector2(-3, -9), Vector2(6, 7)), Kit.IVORY)
	draw_rect(Rect2(pc + Vector2(-4, -12), Vector2(8, 4)), Color("8a5a2b"))
	Kit.text(self, pc + Vector2(14, 7), str(Run.flask), 18, Kit.IVORY if full else Kit.RED)

static func bar(ci: CanvasItem, r: Rect2, f: float, trail: float, col: Color, hi: Color) -> void:
	ci.draw_rect(Rect2(r.position + Vector2(0, 3), r.size).grow(2), Color(0, 0, 0, 0.45))
	ci.draw_rect(r.grow(2), Kit.INK)
	ci.draw_rect(r, col.darkened(0.78))
	if trail > f:
		ci.draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(trail, 0, 1), r.size.y)), Color(1, 0.92, 0.8, 0.7))
	var w := r.size.x * clampf(f, 0.0, 1.0)
	ci.draw_rect(Rect2(r.position, Vector2(w, r.size.y)), col)
	ci.draw_rect(Rect2(r.position, Vector2(w, maxf(2.0, r.size.y * 0.3))), Color(hi, 0.6))
	ci.draw_rect(r.grow(2), Kit.GOLD_DEEP, false, 1.0)

## The sigil: before awakening, a dark seal that fills as potential gathers;
## after, the principle's colour, mastery round the rim, a pip per rank.
static func draw_sigil(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c + Vector2(0, 4), r + 4.0, Color(0, 0, 0, 0.5), true, -1.0, true)
	ci.draw_circle(c, r + 4.0, Kit.INK, true, -1.0, true)
	ci.draw_arc(c, r + 4.0, 0, TAU, 48, Kit.GOLD_DEEP, 2.0, true)
	var l := Run.law
	if l.is_empty():
		var f := Run.potential / 100.0
		if f > 0.0:
			ci.draw_arc(c, r - 3.0, -PI * 0.5, -PI * 0.5 + TAU * f, 48, Color(Kit.GOLD_LIGHT, 0.85), 4.0, true)
		Glyphs.draw(ci, "sigil", c, r * 1.1, Color(Kit.MUTED, 0.35 + 0.4 * f))
		return
	var col := Law.colour(str(l["principle"]))
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.003)
	ci.draw_circle(c, r - 2.0, Color(col, 0.18), true, -1.0, true)
	if float(l["mastery"]) > 0.0:
		ci.draw_arc(c, r - 3.0, -PI * 0.5, -PI * 0.5 + TAU * float(l["mastery"]) / 100.0, 48, col, 4.0, true)
	Glyphs.draw(ci, "sigil", c, r * 1.15, Color(col.lightened(0.2), pulse))
	var ranks := int(l["rank"])
	for k in ranks:
		var a := PI * 0.5 + (float(k) - (float(ranks) - 1.0) * 0.5) * 0.32
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * (r + 4.0), 3.5, Kit.GOLD_LIGHT, true, -1.0, true)

# --- Compass and silver --------------------------------------------------------------------

func _draw_compass(vp: Vector2) -> void:
	var rig := world.rig
	if rig == null:
		return
	if world.in_gate():
		_draw_gate_header(vp)
		return
	var w := 520.0
	var c := Vector2(vp.x * 0.5, 40)
	var heading := fposmod(-rig.yaw, TAU)
	var fov := deg_to_rad(150.0)
	draw_rect(Rect2(c.x - w * 0.5, c.y + 13, w, 2), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(c.x - w * 0.5, c.y + 11, w, 2), Color(Kit.IVORY, 0.6))
	var to_x := func(angle: float) -> float:
		return c.x + angle_difference(heading, angle) / (fov * 0.5) * (w * 0.5)
	for k in 8:
		var x: float = to_x.call(TAU * float(k) / 8.0)
		if absf(x - c.x) > w * 0.5:
			continue
		var fade := 1.0 - absf(x - c.x) / (w * 0.5)
		if k % 2 == 0:
			Kit.text(self, Vector2(x - 20, c.y + 4), ["N", "E", "S", "W"][k / 2], 20, Color(Kit.IVORY, fade),
				Kit.title_font(0), HORIZONTAL_ALIGNMENT_CENTER, 40)
		else:
			draw_rect(Rect2(x - 1, c.y + 4, 2, 9), Color(Kit.IVORY, fade * 0.7))
	var p := world.player.global_position
	for id in PLACES.keys():
		if not Run.archive["places"].has(id):
			continue
		var to := world.island.site_pos(id) - p
		if Vector2(to.x, to.z).length() < 40.0:
			continue
		var x: float = to_x.call(atan2(to.x, -to.z))
		if absf(x - c.x) > w * 0.5:
			continue
		var fade := 1.0 - absf(x - c.x) / (w * 0.5)
		draw_circle(Vector2(x, c.y + 34), 11.0, Color(Kit.INK, 0.9 * fade), true, -1.0, true)
		Glyphs.draw(self, PLACES[id], Vector2(x, c.y + 34), 15.0, Color(Kit.GOLD_LIGHT, fade))
	# The isles you have found, your ship, and any X a map of yours marks.
	for id in Isles.ISLES.keys():
		if not Run.archive["places"].has("isle_" + id):
			continue
		var ti := Isles.centre(id) - p
		if Vector2(ti.x, ti.z).length() < float(Isles.ISLES[id]["r"]):
			continue
		var xi: float = to_x.call(atan2(ti.x, -ti.z))
		if absf(xi - c.x) > w * 0.5:
			continue
		var fi := 1.0 - absf(xi - c.x) / (w * 0.5)
		draw_circle(Vector2(xi, c.y + 34), 11.0, Color(Kit.INK, 0.9 * fi), true, -1.0, true)
		Glyphs.draw(self, "map", Vector2(xi, c.y + 34), 15.0, Color(0.6, 0.85, 1.0, fi))
	if world.gull != null and world.player.helm == null and not world.gull.on_deck(p):
		var tg := world.gull.global_position - p
		if Vector2(tg.x, tg.z).length() > 25.0:
			var xg: float = clampf(to_x.call(atan2(tg.x, -tg.z)), c.x - w * 0.5, c.x + w * 0.5)
			_boat(Vector2(xg, c.y + 34), Color(0.6, 0.85, 1.0))
	for d in get_tree().get_nodes_in_group("dig_sites"):
		if not (d as Treasure).index in Treasure.held_sites():
			continue
		var td := (d as Node3D).global_position - p
		var xd: float = clampf(to_x.call(atan2(td.x, -td.z)), c.x - w * 0.5, c.x + w * 0.5)
		var dc := Vector2(xd, c.y + 34)
		draw_circle(dc, 12.0, Kit.INK, true, -1.0, true)
		draw_line(dc + Vector2(-6, -6), dc + Vector2(6, 6), Kit.RED, 3.0, true)
		draw_line(dc + Vector2(-6, 6), dc + Vector2(6, -6), Kit.RED, 3.0, true)
	# Kindled Waystones, and the silver you dropped.
	for ws in get_tree().get_nodes_in_group("waystones"):
		if not (ws as Waystone).kindled():
			continue
		var tw := (ws as Node3D).global_position - p
		if Vector2(tw.x, tw.z).length() < 15.0 or Vector2(tw.x, tw.z).length() > 450.0:
			continue
		var xw: float = to_x.call(atan2(tw.x, -tw.z))
		if absf(xw - c.x) > w * 0.5:
			continue
		var fw := 1.0 - absf(xw - c.x) / (w * 0.5)
		draw_rect(Rect2(xw - 3, c.y + 24, 6, 16), Color(Kit.INK, 0.9 * fw))
		draw_circle(Vector2(xw, c.y + 22), 5.0, Color(1.0, 0.8, 0.45, fw), true, -1.0, true)
	for th in get_tree().get_nodes_in_group("thieves"):
		if bool((th as Node).call("is_dead")) or float(th.get("_flee_t")) < 0.0:
			continue
		var tt := (th as Node3D).global_position - p
		var xt: float = clampf(to_x.call(atan2(tt.x, -tt.z)), c.x - w * 0.5, c.x + w * 0.5)
		draw_circle(Vector2(xt, c.y + 34), 13.0, Kit.GOLD, true, -1.0, true)
		Glyphs.draw(self, "bag", Vector2(xt, c.y + 34), 16.0, Kit.INK)
	if Run.surge:
		var sw := 132.0
		var sr := Rect2(c.x - sw * 0.5, c.y + 56, sw, 24)
		draw_style_box(chip(Color("5a1414"), Color("d9473d")), sr)
		draw_string(Game.ui_bold, sr.position + Vector2(0, 17), "RIFT SURGE", HORIZONTAL_ALIGNMENT_CENTER, sw, 12, Kit.IVORY)
	for ls in get_tree().get_nodes_in_group("lost_silver"):
		var tl := (ls as Node3D).global_position - p
		var xl: float = clampf(to_x.call(atan2(tl.x, -tl.z)), c.x - w * 0.5, c.x + w * 0.5)
		draw_circle(Vector2(xl, c.y + 34), 12.0, Kit.INK, true, -1.0, true)
		Glyphs.draw(self, "coin", Vector2(xl, c.y + 34), 16.0, Color(0.85, 1.0, 0.6))
	# The tracked quest's target, a gold diamond on the strip.
	var tgt := Quests.target_of(Run.tracked, world)
	if tgt != Vector3.INF:
		var to2 := tgt - p
		var x2: float = to_x.call(atan2(to2.x, -to2.z))
		x2 = clampf(x2, c.x - w * 0.5, c.x + w * 0.5)
		var d2 := Vector2(x2, c.y + 34)
		var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.006)
		draw_colored_polygon(PackedVector2Array([d2 + Vector2(0, -13) * pulse, d2 + Vector2(13, 0) * pulse,
			d2 + Vector2(0, 13) * pulse, d2 + Vector2(-13, 0) * pulse]), Kit.INK)
		draw_colored_polygon(PackedVector2Array([d2 + Vector2(0, -10) * pulse, d2 + Vector2(10, 0) * pulse,
			d2 + Vector2(0, 10) * pulse, d2 + Vector2(-10, 0) * pulse]), Kit.GOLD)
	draw_colored_polygon(PackedVector2Array([Vector2(c.x - 7, c.y + 22), Vector2(c.x + 7, c.y + 22),
		Vector2(c.x, c.y + 14)]), Kit.GOLD)

## The tracked quest: its name, what to do now, how far — and a diamond
## over the place itself, or at the screen's edge pointing the way.
func _draw_tracker(vp: Vector2) -> void:
	var id := Run.tracked
	if id == "" or not Run.quests.has(id) or world.in_gate():
		return
	var q: Dictionary = Quests.ALL[id]
	var tgt := Quests.target_of(id, world)
	var dist := -1.0
	if tgt != Vector3.INF:
		dist = Vector2(tgt.x, tgt.z).distance_to(Vector2(world.player.global_position.x, world.player.global_position.z))
	var title := str(q["title"]).to_upper()
	var step := Quests.step_text(id)
	var w := maxf(Game.ui_bold.get_string_size(step, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x,
		Kit.title_font(3).get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x) + 110.0
	var r := Rect2(40.0, 132.0, w, 70)
	draw_style_box(chip(Color(Kit.INK, 0.92), Kit.GOLD_DEEP), r)
	draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(4, r.size.y - 4)), Kit.GOLD)
	Kit.text(self, r.position + Vector2(20, 26), title, 15, Kit.GOLD_LIGHT, Kit.title_font(3))
	var d := r.position + Vector2(24, 48)
	draw_colored_polygon(PackedVector2Array([d + Vector2(0, -5), d + Vector2(5, 0), d + Vector2(0, 5), d + Vector2(-5, 0)]),
		Kit.GOLD)
	Kit.text(self, r.position + Vector2(36, 54), step, 16, Kit.IVORY)
	if dist >= 0.0:
		var ds := "%d m" % int(dist) if dist < 1000.0 else "%.1f km" % (dist / 1000.0)
		Kit.text(self, r.position + Vector2(0, 26), ds, 14, Kit.MUTED, Game.ui_bold, HORIZONTAL_ALIGNMENT_RIGHT, w - 16)
		Kit.keycap(self, Vector2(r.position.x + 14, r.end.y + 20), "T", 11)
		draw_string(Game.ui_bold, Vector2(r.position.x + 30, r.end.y + 25), "SHOW THE WAY", HORIZONTAL_ALIGNMENT_LEFT, -1,
			11, Kit.MUTED)
	_draw_waypoint(vp, tgt, dist)

func _draw_waypoint(vp: Vector2, tgt: Vector3, dist: float) -> void:
	if tgt == Vector3.INF or dist < 6.0:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var at := tgt + Vector3.UP * 7.0
	var on := not cam.is_position_behind(at)
	var s := cam.unproject_position(at) if on else Vector2.ZERO
	var margin := 70.0
	var inside := on and s.x > margin and s.x < vp.x - margin and s.y > margin and s.y < vp.y - margin
	var pulse := 1.0 + 0.1 * sin(Time.get_ticks_msec() * 0.006)
	if inside:
		draw_colored_polygon(PackedVector2Array([s + Vector2(0, -16) * pulse, s + Vector2(16, 0) * pulse,
			s + Vector2(0, 16) * pulse, s + Vector2(-16, 0) * pulse]), Kit.INK)
		draw_colored_polygon(PackedVector2Array([s + Vector2(0, -12) * pulse, s + Vector2(12, 0) * pulse,
			s + Vector2(0, 12) * pulse, s + Vector2(-12, 0) * pulse]), Kit.GOLD)
		draw_circle(s, 4.0, Kit.INK, true, -1.0, true)
		var ds := "%d m" % int(dist) if dist < 1000.0 else "%.1f km" % (dist / 1000.0)
		Kit.text(self, s + Vector2(-60, 36), ds, 15, Kit.IVORY, Game.ui_bold, HORIZONTAL_ALIGNMENT_CENTER, 120)
		return
	# Off screen or behind: pin to the edge on the target's side, with an arrow.
	var centre := vp * 0.5
	var to := tgt - cam.global_position
	var lateral := to.dot(cam.global_basis.x)
	var vertical := to.dot(cam.global_basis.y)
	var dir := (s - centre).normalized() if on else Vector2(signf(lateral) if absf(lateral) > 0.01 else 1.0, 0.0)
	if not on:
		dir = Vector2(dir.x, clampf(-vertical * 0.02, -0.4, 0.4)).normalized()
	var half := vp * 0.5 - Vector2(margin, margin)
	var t := minf(half.x / maxf(absf(dir.x), 0.001), half.y / maxf(absf(dir.y), 0.001))
	var e := centre + dir * t
	draw_circle(e, 20.0 * pulse, Kit.INK, true, -1.0, true)
	draw_arc(e, 20.0 * pulse, 0, TAU, 32, Kit.GOLD, 2.0, true)
	var ang := dir.angle()
	var tip := e + Vector2(cos(ang), sin(ang)) * 12.0
	var sidev := Vector2(-sin(ang), cos(ang)) * 7.0
	var back := e - Vector2(cos(ang), sin(ang)) * 5.0
	draw_colored_polygon(PackedVector2Array([tip, back + sidev, back - sidev]), Kit.GOLD)

## Inside a Gate: its name, and a pip per chamber, gold once cleared.
func _draw_gate_header(vp: Vector2) -> void:
	var run := world.gate_run
	var name := str(run.def.get("name", "")).to_upper()
	var f := Kit.title_font(6)
	var w := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	Kit.text(self, Vector2(vp.x * 0.5 - w * 0.5, 50), name, 24, Kit.IVORY, f)
	var n := run.rooms.size()
	var here := run.room_at(world.player.global_position)
	var x0 := vp.x * 0.5 - float(n - 1) * 13.0
	for i in n:
		var c := Vector2(x0 + i * 26.0, 72)
		var r: Dictionary = run.rooms[i]
		var col := Kit.GOLD if r["done"] else Kit.INK_3
		if r["kind"] in ["boss", "arena"]:
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(9, 0), c + Vector2(0, 9), c + Vector2(-9, 0)]),
				Kit.INK)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 0), c + Vector2(0, 7), c + Vector2(-7, 0)]),
				Kit.RED if not r["done"] else Kit.GOLD)
		else:
			draw_circle(c, 7.0, Kit.INK, true, -1.0, true)
			draw_circle(c, 5.0, col, true, -1.0, true)
		if i == here:
			draw_arc(c, 10.0, 0, TAU, 24, Kit.IVORY, 2.0, true)

func _draw_silver(vp: Vector2) -> void:
	var s := "%d" % Run.silver
	var w := Game.ui_bold.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 58.0
	var r := Rect2(vp.x - 40 - w, 30, w, 40)
	draw_style_box(chip(Kit.INK), r)
	Glyphs.draw(self, "coin", r.position + Vector2(22, 20), 24.0, Kit.GOLD)
	Kit.text(self, r.position + Vector2(40, 27), s, 20, Kit.IVORY)

# --- Notices ---------------------------------------------------------------------------

func _draw_toasts(vp: Vector2) -> void:
	var y := 86.0
	for t in _toasts:
		var k := float(t["t"])
		var slide := 1.0 - ease(clampf(k / 0.25, 0.0, 1.0), 0.3)
		var a := 1.0 - smoothstep(3.8, 4.5, k)
		var text: String = t["text"]
		var w := Game.ui_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 66.0
		var r := Rect2(vp.x - 40 - w + slide * (w + 60), y, w, 42)
		var look: Array = TOAST_LOOK.get(t["kind"], TOAST_LOOK["item"])
		var col: Color = look[1]
		if t["kind"] == "law" and not Run.law.is_empty():
			col = Law.colour(str(Run.law["principle"]))
		draw_style_box(chip(Color(Kit.INK, a), Color(col.darkened(0.3), a)), r)
		draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(40, r.size.y - 4)), Color(col.darkened(0.6), a))
		Glyphs.draw(self, look[0], r.position + Vector2(22, 21), 22.0, Color(col, a))
		Kit.text(self, r.position + Vector2(52, 27), text, 16, Color(Kit.IVORY, a))
		y += 50.0

func _draw_banner(vp: Vector2) -> void:
	if _banner == "" or _banner_t > 5.0:
		return
	var a := smoothstep(0.0, 0.6, _banner_t) * (1.0 - smoothstep(4.0, 5.0, _banner_t))
	var c := Vector2(vp.x * 0.5, vp.y * 0.26)
	var f := Kit.title_font(10)
	var text := _banner.to_upper()
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 50).x
	var tag := _banner_tag
	var tagw := Game.ui_bold.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 24.0
	draw_style_box(chip(Color(Kit.GOLD, a), Color(Kit.GOLD_DEEP, a)), Rect2(c.x - tagw * 0.5, c.y - 76, tagw, 26))
	draw_string(Game.ui_bold, Vector2(c.x - tagw * 0.5, c.y - 58), tag, HORIZONTAL_ALIGNMENT_CENTER, tagw, 13,
		Color(Kit.INK, a))
	Kit.text(self, Vector2(c.x - tw * 0.5, c.y), text, 50, Color(Kit.IVORY, a), f)
	var spread := (tw * 0.5 + 40.0) * ease(clampf(_banner_t / 1.2, 0.0, 1.0), 0.3)
	draw_rect(Rect2(c.x - spread, c.y + 18, spread * 2.0, 2), Color(Kit.GOLD, a))
	if _banner_sub != "":
		Kit.text(self, Vector2(0, c.y + 50), _banner_sub, 18, Color(Kit.GOLD_LIGHT, a), Game.ui_bold,
			HORIZONTAL_ALIGNMENT_CENTER, vp.x)

# --- Combat overlays -----------------------------------------------------------------------

func _draw_enemy_bars() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var lock := world.rig.lock_target if world.rig != null else null
	for e in get_tree().get_nodes_in_group("enemies"):
		var n := e as Node3D
		if n == null or not n.has_method("health_fraction") or bool(n.call("is_boss")):
			continue
		var f := float(n.call("health_fraction"))
		var special := bool(n.get("elite")) or str(n.get("kind")) == "thief"
		var at := n.global_position + Vector3.UP * 2.35
		if cam.is_position_behind(at) or f <= 0.0:
			continue
		if cam.global_position.distance_to(at) > 28.0 or (f >= 1.0 and n != lock and float(n.call("posture_fraction")) <= 0.0 and not special):
			continue
		var s := cam.unproject_position(at)
		var r := Rect2(s - Vector2(38, 0), Vector2(76, 6))
		if special:
			r = Rect2(s - Vector2(55, 0), Vector2(110, 7))
			var nm := str(n.call("kind_name")).to_upper()
			Kit.text(self, Vector2(s.x - 160, s.y - 8), nm, 13, Kit.GOLD_LIGHT, Game.ui_bold, HORIZONTAL_ALIGNMENT_CENTER, 320)
		draw_rect(r.grow(2), Kit.INK)
		draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), Kit.RED)
		_draw_stance(n, Rect2(r.position + Vector2(0, r.size.y + 3), Vector2(r.size.x, 3)))
	if lock != null and is_instance_valid(lock):
		var at2 := lock.global_position + Vector3.UP * 1.2
		if not cam.is_position_behind(at2):
			var s2 := cam.unproject_position(at2)
			for k in 4:
				var a := PI * 0.25 + PI * 0.5 * float(k) + Time.get_ticks_msec() * 0.002
				var d := Vector2(cos(a), sin(a))
				draw_line(s2 + d * 12.0, s2 + d * 20.0, Kit.GOLD_LIGHT, 3.0, true)

func _draw_numbers() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	for n in _numbers:
		var at: Vector3 = n["pos"]
		if cam.is_position_behind(at):
			continue
		var t := float(n["t"])
		var s := cam.unproject_position(at) + Vector2(0, -70.0 * t) + (n["drift"] as Vector2) * t
		var a := 1.0 - smoothstep(0.6, 1.1, t)
		var pop := 1.0 + 0.6 * (1.0 - smoothstep(0.0, 0.14, t))
		Kit.text(self, s - Vector2(60, 0), str(n["text"]), int((32 if n["big"] else 24) * pop), Color(n["col"], a),
			Game.ui_bold, HORIZONTAL_ALIGNMENT_CENTER, 120)

func _draw_boss(vp: Vector2) -> void:
	var boss: Node3D = null
	for b in get_tree().get_nodes_in_group("boss"):
		var n := b as Node3D
		if not bool(n.call("is_dead")) and n.global_position.distance_to(world.player.global_position) < 30.0:
			boss = n
	if boss == null:
		return
	var w := minf(760.0, vp.x * 0.5)
	var r := Rect2(vp.x * 0.5 - w * 0.5, vp.y - 196, w, 12)
	Kit.text(self, r.position + Vector2(0, -12), str(boss.call("kind_name")).to_upper(), 20, Kit.IVORY, Kit.title_font(4))
	bar(self, r, float(boss.call("health_fraction")), 0.0, Kit.RED, Color("ff8a7a"))
	_draw_stance(boss, Rect2(r.position + Vector2(0, 18), Vector2(r.size.x, 5)))

## The thin gold line under a health bar: how close its stance is to
## breaking. Flashes while broken.
func _draw_stance(n: Node3D, r: Rect2) -> void:
	if not n.has_method("posture_fraction"):
		return
	var broken := bool(n.call("is_broken"))
	var f := 1.0 if broken else float(n.call("posture_fraction"))
	if f <= 0.01:
		return
	draw_rect(r.grow(1), Kit.INK)
	var col := Kit.GOLD_LIGHT if not broken else Color(1, 1, 1).lerp(Kit.GOLD, 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02))
	draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), col)

# --- Hotbar and powers ------------------------------------------------------------------------

func _draw_hotbar(vp: Vector2) -> void:
	var size := 64.0
	var gap := 10.0
	var total := size * 5 + gap * 4
	var o := Vector2(vp.x * 0.5 - total * 0.5, vp.y - size - 30)
	for i in 5:
		var id := str(Run.hotbar[i])
		var r := Rect2(o + Vector2((size + gap) * i, 0), Vector2(size, size)).grow(4.0 * _hot_pop[i] / 0.18)
		var held: bool = id != "" and (Run.gear.get("weapon", "") == id or Run.gear.get("shield", "") == id)
		draw_style_box(chip(Kit.INK_2, Kit.GOLD if held else Kit.LINE), r)
		if id != "":
			var tex := Icons.get_icon(id)
			if tex != null:
				draw_texture_rect(tex, r.grow(-6), false)
			if Run.item(id).get("kind", "") == "consumable" or Run.count(id) > 1:
				var n := Run.count(id)
				Kit.text(self, r.position + Vector2(0, r.size.y - 8), str(n), 16, Kit.IVORY if n > 0 else Kit.RED,
					Game.ui_bold, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 8)
		Kit.text(self, r.position + Vector2(7, 19), str(i + 1), 14, Color(Kit.IVORY, 0.65))

## The Knight's Arts, left of the hotbar: a glyph, its key, and a shade
## that drains downward as the Art comes back. Unlearned ones show a lock.
func _draw_arts(vp: Vector2) -> void:
	var size := 54.0
	var gap := 8.0
	var o := Vector2(vp.x * 0.5 - 180.0 - 30.0 - (size * 4 + gap * 3), vp.y - size - 35)
	var arts: Arts = world.player.arts
	for i in 4:
		var id: String = Arts.ORDER[i]
		var def: Dictionary = Arts.ALL[id]
		var known := Arts.known(id)
		var remaining := float(arts.cooldown.get(id, 0.0))
		var since := float(def["cd"]) - remaining
		var pop := clampf(1.0 - since / 0.2, 0.0, 1.0) if remaining > 0.0 else 0.0
		var r := Rect2(o + Vector2((size + gap) * i, 0), Vector2(size, size)).grow(4.0 * pop)
		var lit := id == "battle_cry" and arts.rally_t > 0.0
		draw_style_box(chip(Kit.INK_2, Kit.GOLD if lit else (Kit.GOLD_DEEP if known else Kit.LINE)), r)
		var c := r.get_center()
		if known:
			Glyphs.draw(self, str(def["glyph"]), c, 30.0, Kit.IVORY if remaining <= 0.0 else Color(Kit.IVORY, 0.45))
			if remaining > 0.0:
				var f := remaining / float(def["cd"])
				var inner := r.grow(-3)
				draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * f)), Color(0, 0, 0, 0.55))
				Kit.text(self, r.position + Vector2(0, r.size.y * 0.5 + 8), str(ceili(remaining)), 18, Kit.IVORY,
					Game.ui_bold, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
			elif world.player.stamina < float(def["stamina"]):
				draw_rect(r.grow(-3), Color(0.5, 0.1, 0.08, 0.35))
		else:
			Glyphs.draw(self, "lock", c, 22.0, Kit.MUTED)
		Kit.keycap(self, Vector2(c.x, r.end.y + 2), str(def["label"]), 12)

## Renown: a thin gold bar under the hotbar, your level at its left and
## the next level's reward at its right. Flashes, with the amount, as it fills.
func _draw_renown(vp: Vector2) -> void:
	var left := vp.x * 0.5 - 450.0
	var right := vp.x * 0.5 + 180.0
	var r := Rect2(left + 34, vp.y - 15, right - left - 34, 5)
	var f := clampf(Run.renown_xp / Run.renown_need(Run.renown_level), 0.0, 1.0)
	draw_rect(r.grow(2), Kit.INK)
	draw_rect(Rect2(r.position, Vector2(r.size.x * f, r.size.y)), Kit.GOLD.lerp(Kit.GOLD_LIGHT, _xp_flash))
	if _xp_flash > 0.0:
		draw_rect(Rect2(r.position + Vector2(r.size.x * f - 3, -2), Vector2(4, r.size.y + 4)), Color(1, 1, 1, _xp_flash))
		Kit.text(self, Vector2(r.position.x + r.size.x * f - 40, r.position.y - 6 - 10.0 * (1.0 - _xp_flash)),
			"+%d" % int(round(_xp_last)), 13, Color(Kit.GOLD_LIGHT, _xp_flash), Game.ui_bold, HORIZONTAL_ALIGNMENT_CENTER, 80)
	var c := Vector2(left + 14, r.get_center().y)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -15), c + Vector2(15, 0), c + Vector2(0, 15), c + Vector2(-15, 0)]),
		Kit.INK)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -12), c + Vector2(12, 0), c + Vector2(0, 12), c + Vector2(-12, 0)]),
		Kit.GOLD)
	Kit.text(self, c + Vector2(-20, 5), str(Run.renown_level), 13, Kit.INK, Game.ui_bold, HORIZONTAL_ALIGNMENT_CENTER, 40)
	var next := "NEXT  ·  " + Renown.describe(Renown.reward_for(Run.renown_level + 1)).to_upper()
	draw_string(Game.ui_bold, Vector2(right + 12, r.end.y + 1), next, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Kit.MUTED)

## A little hull shape, for the compass and the sailing panel.
func _boat(at: Vector2, col: Color) -> void:
	draw_circle(at, 12.0, Kit.INK, true, -1.0, true)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-8, 1), at + Vector2(8, 1), at + Vector2(5, 6), at + Vector2(-5, 6)]), col)
	draw_colored_polygon(PackedVector2Array([at + Vector2(-1, -8), at + Vector2(-1, 0), at + Vector2(6, 0)]), col)

## At the helm: the sails, the anchor, how fast and how well you have the
## wind, the hull, and both broadsides loading. Replaces the hotbar.
func _draw_helm(vp: Vector2, ship: Ship) -> void:
	var w := 560.0
	var r := Rect2(vp.x * 0.5 - w * 0.5, vp.y - 128, w, 92)
	draw_style_box(chip(Color(Kit.INK, 0.94), Kit.GOLD_DEEP), r)
	# Sails: three bars, lit to the current setting.
	Kit.text(self, r.position + Vector2(20, 24), "SAILS", 11, Kit.MUTED, Game.ui_bold)
	for k in 2:
		var lit := ship.sail > k
		draw_rect(Rect2(r.position + Vector2(20 + k * 30, 34), Vector2(24, 30)), Kit.GOLD if lit else Kit.INK_3)
	Kit.text(self, r.position + Vector2(20, 82), "ANCHORED" if ship.anchored else ["FURLED", "HALF", "FULL"][ship.sail], 11,
		Kit.RED if ship.anchored else Kit.IVORY, Game.ui_bold)
	# Speed, and the point of sail.
	var knots := int(round(ship.speed * 1.94))
	Kit.text(self, Vector2(r.position.x + 110, r.position.y + 50), "%d" % knots, 36, Kit.IVORY, Kit.title_font(2),
		HORIZONTAL_ALIGNMENT_CENTER, 120)
	Kit.text(self, Vector2(r.position.x + 110, r.position.y + 68), "KNOTS", 11, Kit.MUTED, Game.ui_bold,
		HORIZONTAL_ALIGNMENT_CENTER, 120)
	var pos := Sea.point_of_sail(ship.forward())
	Kit.text(self, Vector2(r.position.x + 110, r.position.y + 84), pos, 11,
		Kit.RED if pos == "IN IRONS" else Kit.GOLD_LIGHT, Game.ui_bold, HORIZONTAL_ALIGNMENT_CENTER, 120)
	# The wind, relative to the bow (up).
	var wc := r.position + Vector2(290, 46)
	draw_circle(wc, 30.0, Kit.INK_2, true, -1.0, true)
	draw_arc(wc, 30.0, 0, TAU, 32, Kit.LINE, 2.0, true)
	_boat(wc, Kit.IVORY)
	var rel := Sea.wind_angle() - ship.heading
	var wd := Vector2(-sin(rel), -cos(rel))
	draw_line(wc - wd * 26.0, wc + wd * 20.0, Color(0.6, 0.85, 1.0), 3.0, true)
	draw_colored_polygon(PackedVector2Array([wc + wd * 27.0, wc + wd * 15.0 + wd.orthogonal() * 7.0,
		wc + wd * 15.0 - wd.orthogonal() * 7.0]), Color(0.6, 0.85, 1.0))
	Kit.text(self, Vector2(wc.x - 40, r.position.y + 90), "WIND", 11, Kit.MUTED, Game.ui_bold, HORIZONTAL_ALIGNMENT_CENTER, 80)
	# Hull, and the two broadsides.
	Kit.text(self, r.position + Vector2(350, 24), ship.title.to_upper(), 12, Kit.GOLD_LIGHT, Kit.title_font(2))
	bar(self, Rect2(r.position + Vector2(350, 34), Vector2(190, 9)), ship.hull / ship.max_hull, 0.0, Color("6fbf73"), Color("b9f0bb"))
	for k in 2:
		var side := -1 if k == 0 else 1
		var ready := 1.0 - float(ship._cool[side]) / 3.2
		var br := Rect2(r.position + Vector2(350 + k * 100, 56), Vector2(90, 6))
		draw_rect(br.grow(1), Kit.INK)
		draw_rect(Rect2(br.position, Vector2(br.size.x * ready, br.size.y)), Kit.GOLD if ready >= 1.0 else Kit.MUTED)
		Kit.text(self, br.position + Vector2(0, 20), "PORT GUNS" if k == 0 else "STARBOARD GUNS", 10, Kit.MUTED, Game.ui_bold)
	var keys := "W / S  SAILS     A / D  RUDDER     SPACE  ANCHOR     LEFT MOUSE  FIRE     E  LEAVE THE HELM"
	Kit.text(self, Vector2(0, vp.y - 18), keys, 11, Kit.MUTED, Game.ui_bold, HORIZONTAL_ALIGNMENT_CENTER, vp.x)

## The Drowned Galleon's hull, when it is close.
func _draw_enemy_ship(vp: Vector2) -> void:
	for g in get_tree().get_nodes_in_group("enemy_ships"):
		var ship := g as Ship
		if ship.sunk or ship.global_position.distance_to(world.player.global_position) > 170.0:
			continue
		var w := minf(640.0, vp.x * 0.42)
		var r := Rect2(vp.x * 0.5 - w * 0.5, 130, w, 10)
		Kit.text(self, r.position + Vector2(0, -10), ship.title.to_upper(), 18, Color(0.6, 1.0, 0.8), Kit.title_font(4))
		bar(self, r, ship.hull / ship.max_hull, 0.0, Color("3fbf8f"), Color("a8f5d6"))
		return

## The kill chain, right of centre: how many, a word for it, and the time
## left to keep it going. Only while there is one.
func _draw_chain(vp: Vector2) -> void:
	if Run.chain < 2:
		return
	var c := Vector2(vp.x - 170, vp.y * 0.44)
	var n := Run.chain
	var col := Kit.IVORY if n < 5 else (Kit.GOLD_LIGHT if n < 10 else (Color("ff9a4a") if n < 15 else Color("ff5a4a")))
	var size := int(54 + 26 * _chain_pop)
	Kit.text(self, Vector2(c.x - 120, c.y), "×%d" % n, size, col, Kit.title_font(2), HORIZONTAL_ALIGNMENT_CENTER, 240)
	var word := "CHAIN" if n < 5 else ("RAMPAGE" if n < 10 else ("MASSACRE" if n < 15 else "LEGEND"))
	Kit.text(self, Vector2(c.x - 120, c.y + 24), word, 13, col, Game.ui_bold, HORIZONTAL_ALIGNMENT_CENTER, 240)
	var r := Rect2(c.x - 60, c.y + 34, 120, 4)
	draw_rect(r.grow(1), Kit.INK)
	draw_rect(Rect2(r.position, Vector2(r.size.x * Run.chain_t / Run.CHAIN_WINDOW, r.size.y)), col)
	Kit.text(self, Vector2(c.x - 120, c.y + 56), "+%d%% RENOWN & SILVER" % int((Run.gain_mult() - 1.0) * 100.0), 11,
		Kit.MUTED, Game.ui_bold, HORIZONTAL_ALIGNMENT_CENTER, 240)

## One bounty under the quest tracker (the nearest to done), or, for a
## moment after one is finished, what it paid.
func _draw_bounty() -> void:
	if world.in_gate():
		return
	var y := 250.0 if Run.tracked != "" and Run.quests.has(Run.tracked) else 132.0
	if not _bounty_flash.is_empty():
		var k := float(_bounty_flash["t"])
		var a := 1.0 - smoothstep(3.4, 4.0, k)
		var txt := str(_bounty_flash["reward"])
		var w := maxf(Game.ui_bold.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 40.0, 300.0)
		var r := Rect2(40, y, w, 60)
		draw_style_box(chip(Color(Kit.GOLD, a), Color(Kit.GOLD_DEEP, a)), r)
		draw_string(Game.ui_bold, r.position + Vector2(18, 22), "BOUNTY COMPLETE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(Kit.INK, a))
		draw_string(Game.ui_bold, r.position + Vector2(18, 44), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(Kit.INK, a))
		return
	var b := Bounties.closest()
	if b.is_empty():
		return
	var text := str(b["text"])
	var prog := "%d / %d" % [mini(int(b["have"]), int(b["need"])), int(b["need"])]
	var w2 := Game.ui_bold.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 130.0
	var r2 := Rect2(40, y, w2, 46)
	draw_style_box(chip(Color(Kit.INK, 0.92), Kit.LINE), r2)
	draw_string(Game.ui_bold, r2.position + Vector2(14, 18), "BOUNTY", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Kit.GOLD)
	draw_string(Game.ui_bold, r2.position + Vector2(14, 34), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Kit.IVORY)
	draw_string(Game.ui_bold, r2.position + Vector2(0, 34), prog, HORIZONTAL_ALIGNMENT_RIGHT, w2 - 14, 14, Kit.GOLD_LIGHT)
	var f := float(b["have"]) / maxf(float(b["need"]), 1.0)
	draw_rect(Rect2(r2.position + Vector2(4, r2.size.y - 6), Vector2((r2.size.x - 8) * f, 3)), Kit.GOLD)

func _draw_powers(vp: Vector2) -> void:
	var l := Run.law
	if l.is_empty():
		return
	var col := Law.colour(str(l["principle"]))
	var ps := Law.powers_of(l)
	if int(l["rank"]) >= 4:
		var c3 := Vector2(vp.x - 230, vp.y - 74)
		var rd := world.player.powers.ready_fraction(2)
		draw_circle(c3 + Vector2(0, 5), 33.0, Color("0c0d11"), true, -1.0, true)
		draw_circle(c3, 33.0, Kit.INK_2, true, -1.0, true)
		draw_arc(c3, 33.0, 0, TAU, 48, Kit.GOLD, 3.0, true)
		Glyphs.draw(self, "star", c3, 34.0, Color(col, 0.5 + 0.5 * rd))
		if rd < 1.0:
			var pts3 := PackedVector2Array([c3])
			for k in 33:
				var a3 := -PI * 0.5 + TAU * rd + TAU * (1.0 - rd) * float(k) / 32.0
				pts3.append(c3 + Vector2(cos(a3), sin(a3)) * 31.0)
			draw_colored_polygon(pts3, Color(0, 0, 0, 0.6))
		Kit.text(self, c3 + Vector2(-70, -44), "Overflow", 12, Color(Kit.IVORY, 0.85), Game.ui_bold,
			HORIZONTAL_ALIGNMENT_CENTER, 140)
		Kit.keycap(self, c3 + Vector2(0, 38), "H", 12)
	for i in 2:
		var c := Vector2(vp.x - 150 + i * 80, vp.y - 74)
		var found := Law.found(l, i)
		draw_circle(c + Vector2(0, 5), 33.0, Color("0c0d11"), true, -1.0, true)
		draw_circle(c, 33.0, Kit.INK_2, true, -1.0, true)
		draw_arc(c, 33.0, 0, TAU, 48, col if found else Kit.LINE, 3.0, true)
		if found:
			var ready := world.player.powers.ready_fraction(i)
			Glyphs.draw(self, "sigil", c, 34.0, Color(col, 0.5 + 0.5 * ready))
			if ready < 1.0:
				var pts := PackedVector2Array([c])
				for k in 33:
					var a := -PI * 0.5 + TAU * ready + TAU * (1.0 - ready) * float(k) / 32.0
					pts.append(c + Vector2(cos(a), sin(a)) * 31.0)
				draw_colored_polygon(pts, Color(0, 0, 0, 0.6))
			Kit.text(self, c + Vector2(-70, -44), str(ps[i]["name"]), 12, Color(Kit.IVORY, 0.85), Game.ui_bold,
				HORIZONTAL_ALIGNMENT_CENTER, 140)
		else:
			Kit.text(self, c - Vector2(20, -8), "?", 24, Kit.MUTED, Game.ui_bold, HORIZONTAL_ALIGNMENT_CENTER, 40)
		Kit.keycap(self, c + Vector2(0, 38), "F" if i == 0 else "G", 12)

func _draw_prompt(vp: Vector2) -> void:
	if prompt == "":
		return
	var w := Game.ui_bold.get_string_size(prompt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 70.0
	var r := Rect2(vp.x * 0.5 - w * 0.5, vp.y - 160, w, 44)
	draw_style_box(chip(Kit.INK), r)
	Kit.keycap(self, r.position + Vector2(26, 21), "E", 14)
	Kit.text(self, r.position + Vector2(50, 28), prompt, 18, Kit.IVORY)

func _draw_dialogue(vp: Vector2) -> void:
	var dur := 2.8 + _say_text.length() * 0.05
	if _say_text == "" or _say_t > dur:
		return
	var a := smoothstep(0.0, 0.15, _say_t) * (1.0 - smoothstep(dur - 0.4, dur, _say_t))
	var w := minf(900.0, vp.x - 200.0)
	var r := Rect2(vp.x * 0.5 - w * 0.5, vp.y - 300, w, 96)
	var shown := _say_text.substr(0, int(_say_t * 60.0))
	draw_style_box(chip(Color(Kit.INK, a), Color(Kit.GOLD_DEEP, a)), r)
	var nm := _say_name.to_upper()
	var nw := Game.ui_bold.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 28.0
	draw_style_box(chip(Color(Kit.GOLD, a), Color(Kit.GOLD_DEEP, a)), Rect2(r.position + Vector2(20, -16), Vector2(nw, 30)))
	draw_string(Game.ui_bold, r.position + Vector2(20, 4), nm, HORIZONTAL_ALIGNMENT_CENTER, nw, 14, Color(Kit.INK, a))
	draw_string(Game.ui_font, r.position + Vector2(28, 58), shown, HORIZONTAL_ALIGNMENT_LEFT, w - 56, 21,
		Color(Kit.IVORY, a))

func _draw_death(vp: Vector2) -> void:
	if _dead_t < 0.0:
		return
	var a := smoothstep(0.0, 1.5, _dead_t)
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.04, 0.0, 0.0, 0.6 * a))
	var f := Kit.title_font(12)
	var text := "YOU HAVE FALLEN"
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 66).x
	draw_rect(Rect2(0, vp.y * 0.5 - 70, vp.x, 110), Color(0, 0, 0, 0.55 * a))
	Kit.text(self, Vector2(vp.x * 0.5 - tw * 0.5, vp.y * 0.5), text, 66, Color(0.86, 0.24, 0.2, a), f)
	var after := "Your silver lies where you fell. Go back for it." if int(Run.lost.get("silver", 0)) > 0 \
		else "The world goes on without you, for a while."
	Kit.text(self, Vector2(0, vp.y * 0.5 + 30), after, 16, Color(Kit.MUTED, a), Game.ui_font, HORIZONTAL_ALIGNMENT_CENTER, vp.x)
	# This life, in three numbers, and how close the next Renown is.
	var l := Run.life
	var tally := "THIS LIFE     %d RISEN     ·     BEST CHAIN %d     ·     +%d RENOWN" % [int(l.get("kills", 0)),
		int(l.get("best_chain", 0)), int(float(l.get("renown", 0.0)))]
	Kit.text(self, Vector2(0, vp.y * 0.5 + 92), tally, 15, Color(Kit.IVORY, a), Game.ui_bold, HORIZONTAL_ALIGNMENT_CENTER, vp.x)
	var f2 := Run.renown_xp / Run.renown_need(Run.renown_level)
	var br := Rect2(vp.x * 0.5 - 180, vp.y * 0.5 + 112, 360, 6)
	draw_rect(br.grow(2), Color(Kit.INK, a))
	draw_rect(Rect2(br.position, Vector2(br.size.x * f2, br.size.y)), Color(Kit.GOLD, a))
	Kit.text(self, Vector2(0, vp.y * 0.5 + 140), "RENOWN %d   ·   %d%% TO %d" % [Run.renown_level, int(f2 * 100.0),
		Run.renown_level + 1], 12, Color(Kit.GOLD_LIGHT, a), Game.ui_bold, HORIZONTAL_ALIGNMENT_CENTER, vp.x)
