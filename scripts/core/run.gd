extends Node
## Run: everything about this playthrough that is not the world itself —
## what you carry and hold, your silver, your skills and the perks bought
## with them, the habits the game has watched you form, your Inscription,
## and the Archive of what you have seen. One place, saved and loaded whole.

signal changed(what: String)                  ## "bag", "gear", "hotbar", "silver", "skills", "law", "archive", "flask", "forge"
signal toast(text: String, kind: String)      ## a small notice: "item", "skill", "law", "clue", "place", "warn"
signal quest_event(kind: String, id: String)  ## "new", "step", "done" — for the pop-up card
signal level_up(level: int, reward: String)   ## Renown rose; what it brought
signal bounty_done(text: String, reward: String)

const BAG_SIZE := 30
const HOTBAR := 5
const PROFILE_AXES := ["boldness", "caution", "curiosity", "mercy", "violence", "sociability", "seafaring", "craft",
	"endurance", "patience"]

var items := {}               ## item id -> definition (data/items.json)
var skill_defs := {}
var trees := {}
var bag: Array = []           ## [{id, n}] in slot order; "" ids are empty slots
var gear := {"weapon": "iron_sword", "shield": "round_shield"}
var hotbar: Array = ["red_potion", "bread", "", "", ""]
var silver := 25
var skills := {}              ## skill -> {xp, level, points}
var unlocked := {}            ## perk id -> true
var profile := {}             ## axis -> float
var law := {}                 ## the Inscription, once awakened (see Law)
var potential := 0.0          ## latent potential before awakening, 0..100
var archive := {"clues": [], "places": {}, "people": {}, "bestiary": {}}
var flags := {}               ## story and world facts: opened chests, the warden, threads
var day := 1
var quests := {}              ## id -> {step, done}
var tracked := "main"         ## the quest the tracker follows ("" for none)
var flask := 4                ## draughts left in the Flask; refilled at a Waystone
var flask_max := 4            ## +1 per Hearthseed
var flask_potency := 0        ## +1 per Bright Tear
var last_waystone := ""       ## where you rested last, and get up after a fall
var lost := {}                ## silver dropped where you fell: {pos: [x, y, z], silver}
var forged := {}              ## weapons made at the Forge: id -> definition
var temper := {}              ## item id -> +1..+5
var etch := {}                ## item id -> etching added after it was made
var forge_count := 0
var renown_level := 1         ## the knight's name: rises with everything worth doing
var renown_xp := 0.0
var renown_points := 0        ## spend in any skill tree
var bounties: Array = []      ## three short goals, always replaced when done (see Bounties)
var bounties_done := 0
var loot_count := 0
var nights := 0               ## nightfalls seen; every third one the Rift surges
var surge := false            ## a Rift Surge night: more Elites, richer renown and loot
var chain := 0                ## kills in quick succession (this session only)
var chain_t := 0.0
var last_gain := 0.0          ## the last Renown gained, for the HUD
var life := {}                ## this life so far: kills, renown, best chain
var _explored_seen := -1

const CHAIN_WINDOW := 7.0
var _last_stand_used := false

func _ready() -> void:
	items = _read("res://data/items.json")
	items.erase("_comment")
	var s := _read("res://data/skills.json")
	skill_defs = s.get("skills", {})
	trees = s.get("trees", {})
	new_run()

static func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("missing " + path)
		return {}
	var d: Variant = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

func new_run() -> void:
	bag.clear()
	for i in BAG_SIZE:
		bag.append({"id": "", "n": 0})
	gear = {"weapon": "iron_sword", "shield": "round_shield"}
	hotbar = ["red_potion", "bread", "", "", ""]
	silver = 25
	skills.clear()
	for k in skill_defs.keys():
		skills[k] = {"xp": 0.0, "level": 1, "points": 0}
	unlocked.clear()
	profile.clear()
	for a in PROFILE_AXES:
		profile[a] = 0.0
	law = {}
	potential = 0.0
	archive = {"clues": [], "places": {}, "people": {}, "bestiary": {}}
	flags.clear()
	day = 1
	quests.clear()
	tracked = "main"
	flask_max = 4
	flask = flask_max
	flask_potency = 0
	last_waystone = ""
	lost = {}
	forged.clear()
	temper.clear()
	etch.clear()
	forge_count = 0
	renown_level = 1
	renown_xp = 0.0
	renown_points = 0
	bounties.clear()
	bounties_done = 0
	loot_count = 0
	nights = 0
	surge = false
	chain = 0
	chain_t = 0.0
	new_life()
	_explored_seen = -1
	add_item("red_potion", 3, true)
	# The basics, from the start: Whirlwind known, and a point in each of the
	# other combat trees to learn its Art (or anything else) straight away.
	unlocked["whirlwind"] = true
	for k in ["guard", "agility", "vitality"]:
		skills[k]["points"] = 1
	add_item("bread", 2, true)
	# The first treasure map: the X is on Skull Key. Your ship is at the pier.
	add_item(Treasure.roll_map(0), 1, true)
	add_item("iron_sword", 1, true)
	add_item("round_shield", 1, true)

# --- Items ---------------------------------------------------------------------

## An item's definition: from data, or the Forge, with any tempering and
## etching laid over it.
func item(id: String) -> Dictionary:
	var base: Dictionary = forged.get(id, items.get(id, {}))
	var lvl := int(temper.get(id, 0))
	var et := str(etch.get(id, ""))
	if lvl == 0 and et == "":
		return base
	var d := base.duplicate()
	if lvl > 0:
		d["damage"] = roundf(float(d.get("damage", 0.0)) * (1.0 + 0.1 * lvl))
		d["name"] = "%s +%d" % [d.get("name", id), lvl]
		d["temper"] = lvl
		d["price"] = int(float(d.get("price", 0)) * (1.0 + 0.25 * lvl))
	if et != "":
		d["etch"] = et
	return d

## What one draught from the Flask restores, before perks.
func flask_heal() -> float:
	return 70.0 + 18.0 * flask_potency

func count(id: String) -> int:
	var n := 0
	for s in bag:
		if s["id"] == id:
			n += int(s["n"])
	return n

## Adds to the bag, stacking where it can. Returns how many fitted.
func add_item(id: String, n: int = 1, quiet: bool = false) -> int:
	var def := item(id)
	if def.is_empty():
		return 0
	var cap := int(def.get("stack", 1))
	var left := n
	for s in bag:
		if left <= 0:
			break
		if s["id"] == id and int(s["n"]) < cap:
			var put := mini(cap - int(s["n"]), left)
			s["n"] = int(s["n"]) + put
			left -= put
	for s in bag:
		if left <= 0:
			break
		if s["id"] == "":
			var put := mini(cap, left)
			s["id"] = id
			s["n"] = put
			left -= put
	var got := n - left
	if got > 0:
		changed.emit("bag")
		if id.begins_with("loot_"):
			record("loot")
		if not quiet and id.begins_with("loot_"):
			# Loot speaks in its rarity's colour, and says when it beats what you hold.
			var better := false
			if def.get("kind", "") == "weapon":
				better = float(def.get("damage", 0)) > float(item(str(gear.get("weapon", ""))).get("damage", 0))
			elif def.get("kind", "") == "shield":
				better = float(def.get("block", 0)) > float(item(str(gear.get("shield", ""))).get("block", 0))
			toast.emit(str(def.get("name", id)) + ("   ·   stronger than yours" if better else ""),
				"loot_" + str(def.get("rarity", "common")))
		elif not quiet:
			toast.emit("+%d  %s" % [got, def.get("name", id)] if got > 1 else "+ %s" % def.get("name", id), "item")
	elif not quiet:
		toast.emit("Your bag is full", "warn")
	return got

func remove_item(id: String, n: int = 1) -> bool:
	if count(id) < n:
		return false
	var left := n
	for i in range(bag.size() - 1, -1, -1):
		var s: Dictionary = bag[i]
		if s["id"] == id and left > 0:
			var take := mini(int(s["n"]), left)
			s["n"] = int(s["n"]) - take
			left -= take
			if int(s["n"]) <= 0:
				s["id"] = ""
				s["n"] = 0
	changed.emit("bag")
	return true

func swap_slots(a: int, b: int) -> void:
	var t: Dictionary = bag[a]
	bag[a] = bag[b]
	bag[b] = t
	changed.emit("bag")

## Equips a weapon or shield you carry. Two-handed weapons free the off hand.
func equip(id: String) -> bool:
	var def := item(id)
	if count(id) <= 0:
		return false
	match str(def.get("kind", "")):
		"weapon":
			gear["weapon"] = id
			if bool(def.get("two_handed", false)):
				gear["shield"] = ""
		"shield":
			if bool(item(gear.get("weapon", "")).get("two_handed", false)):
				toast.emit("Your hands are full", "warn")
				return false
			gear["shield"] = id
		_:
			return false
	changed.emit("gear")
	return true

func unequip(slot: String) -> void:
	gear[slot] = ""
	changed.emit("gear")

func set_hotbar(slot: int, id: String) -> void:
	for i in HOTBAR:
		if hotbar[i] == id:
			hotbar[i] = ""
	hotbar[slot] = id
	changed.emit("hotbar")

# --- Silver ----------------------------------------------------------------------

func add_silver(n: int, quiet: bool = false) -> void:
	silver += n
	changed.emit("silver")
	if not quiet and n > 0:
		toast.emit("+%d Silver" % n, "silver")

func spend(n: int) -> bool:
	if silver < n:
		return false
	silver -= n
	changed.emit("silver")
	return true

# --- Skills and perks ----------------------------------------------------------------

static func xp_for(level: int) -> float:
	return 24.0 * pow(float(level), 1.25)

func gain(skill: String, xp: float) -> void:
	if not skills.has(skill):
		return
	var s: Dictionary = skills[skill]
	s["xp"] = float(s["xp"]) + xp
	while float(s["xp"]) >= xp_for(int(s["level"])):
		s["xp"] = float(s["xp"]) - xp_for(int(s["level"]))
		s["level"] = int(s["level"]) + 1
		s["points"] = int(s["points"]) + 1
		toast.emit("%s  %d" % [skill_defs[skill]["name"], s["level"]], "skill")
	changed.emit("skills")

func perk_node(id: String) -> Dictionary:
	for t in trees.keys():
		for n in trees[t]:
			if n["id"] == id:
				var d: Dictionary = (n as Dictionary).duplicate()
				d["tree"] = t
				return d
	return {}

func can_unlock(id: String) -> bool:
	var n := perk_node(id)
	if n.is_empty() or unlocked.has(id):
		return false
	if int(skills[n["tree"]]["points"]) <= 0 and renown_points <= 0:
		return false
	for need in n.get("needs", []):
		if not unlocked.has(need):
			return false
	return true

func unlock(id: String) -> bool:
	if not can_unlock(id):
		return false
	var n := perk_node(id)
	if int(skills[n["tree"]]["points"]) > 0:
		skills[n["tree"]]["points"] = int(skills[n["tree"]]["points"]) - 1
	else:
		renown_points -= 1
	unlocked[id] = true
	changed.emit("skills")
	return true

## The summed value of every unlocked perk with this effect (0 if none).
func perk(effect: String) -> float:
	var v := 0.0
	for id in unlocked.keys():
		var n := perk_node(id)
		if n.get("effect", "") == effect:
			v += float(n.get("value", 0.0))
	return v

func has_perk(effect: String) -> bool:
	return perk(effect) != 0.0

## Last Stand: once between rests, survive a killing blow.
func use_last_stand() -> bool:
	if not has_perk("last_stand") or _last_stand_used:
		return false
	_last_stand_used = true
	return true

func rest() -> void:
	_last_stand_used = false

# --- Behaviour profile ------------------------------------------------------------------

## The game watches how you play; your Inscription will be shaped by it.
func lean(axis: String, amount: float) -> void:
	if profile.has(axis):
		profile[axis] = float(profile[axis]) + amount

# --- Archive --------------------------------------------------------------------------

func add_clue(id: String, title: String, text: String) -> void:
	for c in archive["clues"]:
		if c["id"] == id:
			return
	(archive["clues"] as Array).append({"id": id, "title": title, "text": text, "day": day})
	changed.emit("archive")
	toast.emit(title, "clue")
	renown(10.0)

func has_clue(id: String) -> bool:
	for c in archive["clues"]:
		if c["id"] == id:
			return true
	return false

func discover(place: String) -> bool:
	if archive["places"].has(place):
		return false
	archive["places"][place] = day
	lean("curiosity", 1.0)
	renown(60.0)
	changed.emit("archive")
	return true

func met(name: String) -> void:
	if not archive["people"].has(name):
		archive["people"][name] = day
		changed.emit("archive")

func slew(kind: String) -> void:
	archive["bestiary"][kind] = int(archive["bestiary"].get(kind, 0)) + 1
	changed.emit("archive")

# --- Quests ----------------------------------------------------------------------------

## Starts quests whose moment has come and moves on any whose current step
## the world has finished. Cheap; called twice a second.
func update_quests(quiet: bool = false) -> void:
	for id in Quests.ALL.keys():
		var q: Dictionary = Quests.ALL[id]
		if not quests.has(id):
			if Quests.holds(str(q["starts"])):
				quests[id] = {"step": 0, "done": false}
				if tracked == "" or (tracked != "main" and q["kind"] == "main"):
					tracked = id
				if not quiet:
					quest_event.emit("new", id)
			else:
				continue
		var st: Dictionary = quests[id]
		if bool(st["done"]):
			continue
		var steps: Array = q["steps"]
		var moved := false
		while int(st["step"]) < steps.size() and Quests.holds(str(steps[int(st["step"])]["done"])):
			st["step"] = int(st["step"]) + 1
			moved = true
		if int(st["step"]) >= steps.size():
			st["done"] = true
			if tracked == id:
				tracked = _next_tracked()
			if not quiet:
				quest_event.emit("done", id)
		elif moved and not quiet:
			quest_event.emit("step", id)
		if moved and not quiet:
			renown(120.0 if bool(st["done"]) else 40.0)
		if moved:
			changed.emit("quests")

	# Exploration: a notice each time more of the island is known.
	var ex := explored()
	if _explored_seen >= 0 and ex.x > _explored_seen and not quiet:
		toast.emit("Aldermere  %d%% explored" % int(100.0 * ex.x / ex.y), "place")
	_explored_seen = ex.x
	Bounties.ensure()

func _next_tracked() -> String:
	if quests.has("main") and not bool(quests["main"]["done"]):
		return "main"
	for id in quests.keys():
		if not bool(quests[id]["done"]):
			return id
	return ""

func track(id: String) -> void:
	tracked = id
	changed.emit("quests")

# --- Saving ---------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"bag": bag, "gear": gear, "hotbar": hotbar, "silver": silver, "skills": skills, "unlocked": unlocked,
		"profile": profile, "law": law, "potential": potential, "archive": archive, "flags": flags, "day": day,
		"quests": quests, "tracked": tracked, "flask": flask, "flask_max": flask_max, "flask_potency": flask_potency,
		"last_waystone": last_waystone, "lost": lost, "forged": forged, "temper": temper, "etch": etch,
		"forge_count": forge_count, "renown_level": renown_level, "renown_xp": renown_xp,
		"renown_points": renown_points, "bounties": bounties, "bounties_done": bounties_done, "loot_count": loot_count,
		"nights": nights}

func from_dict(d: Dictionary) -> void:
	new_run()
	bag = d.get("bag", bag)
	while bag.size() < BAG_SIZE:
		bag.append({"id": "", "n": 0})
	gear = d.get("gear", gear)
	hotbar = d.get("hotbar", hotbar)
	silver = int(d.get("silver", silver))
	for k in (d.get("skills", {}) as Dictionary).keys():
		skills[k] = d["skills"][k]
	unlocked = d.get("unlocked", {})
	unlocked["whirlwind"] = true      # older saves predate the Arts
	profile = d.get("profile", profile)
	law = d.get("law", {})
	potential = float(d.get("potential", 0.0))
	archive = d.get("archive", archive)
	flags = d.get("flags", {})
	day = int(d.get("day", 1))
	quests = d.get("quests", {})
	tracked = str(d.get("tracked", "main"))
	flask_max = int(d.get("flask_max", 4))
	flask = int(d.get("flask", flask_max))
	flask_potency = int(d.get("flask_potency", 0))
	last_waystone = str(d.get("last_waystone", ""))
	lost = d.get("lost", {})
	forged = d.get("forged", {})
	temper = d.get("temper", {})
	etch = d.get("etch", {})
	forge_count = int(d.get("forge_count", forged.size()))
	renown_level = int(d.get("renown_level", 1))
	renown_xp = float(d.get("renown_xp", 0.0))
	renown_points = int(d.get("renown_points", 0))
	bounties = d.get("bounties", [])
	bounties_done = int(d.get("bounties_done", 0))
	loot_count = int(d.get("loot_count", 0))
	nights = int(d.get("nights", 0))
	_explored_seen = -1
	Icons.forget_forged()
	update_quests(true)
	for w in ["bag", "gear", "hotbar", "silver", "skills", "law", "archive", "flask", "forge", "renown", "bounties"]:
		changed.emit(w)

# --- Renown, chains and bounties -------------------------------------------------------------

func _process(delta: float) -> void:
	if chain_t > 0.0:
		chain_t -= delta
		if chain_t <= 0.0:
			if chain >= 4:
				toast.emit("Chain of %d" % chain, "skill")
			chain = 0
			changed.emit("chain")

## Renown needed to go from `level` to the next.
static func renown_need(level: int) -> float:
	return roundf(45.0 * pow(float(level), 1.45))

## What a kill chain and a Surge night add to Renown and silver.
func gain_mult() -> float:
	return (1.0 + 0.1 * clampf(chain - 1, 0, 10)) * (1.5 if surge else 1.0)

## Renown: the knight's name growing. Each level brings a reward from the
## track (Renown.reward_for), a little more health, and a full heal.
func renown(xp: float) -> void:
	if xp <= 0.0:
		return
	var got := xp * gain_mult()
	renown_xp += got
	last_gain = got
	life["renown"] = float(life.get("renown", 0.0)) + got
	while renown_xp >= renown_need(renown_level):
		renown_xp -= renown_need(renown_level)
		renown_level += 1
		level_up.emit(renown_level, Renown.grant(renown_level))
	changed.emit("renown")

## A kill: the chain grows, this life's tally, bounties.
func on_kill(kind: String, elite: bool, night: bool) -> void:
	chain = chain + 1 if chain_t > 0.0 else 1
	chain_t = CHAIN_WINDOW
	life["kills"] = int(life.get("kills", 0)) + 1
	life["best_chain"] = maxi(int(life.get("best_chain", 0)), chain)
	record("kill")
	record("kill:" + kind)
	if elite:
		record("elite")
	if night:
		record("night_kill")
	record_max("chain", chain)
	changed.emit("chain")

## Something a bounty might be counting happened.
func record(kind: String, n: int = 1) -> void:
	Bounties.progress(kind, n, false)

func record_max(kind: String, value: int) -> void:
	Bounties.progress(kind, value, true)

func new_life() -> void:
	life = {"kills": 0, "renown": 0.0, "best_chain": 0}

## How much of Aldermere you have found: x of y things.
func explored() -> Vector2i:
	var n: int = (archive["places"] as Dictionary).size()
	for k in flags.keys():
		var key := str(k)
		if key.begins_with("way_") or key.begins_with("msg_") or key.begins_with("stain_") or key.begins_with("chest_") \
				or key.begins_with("fb_") or key == "warden_dead" or (key.begins_with("gate_") and not key.begins_with("gate_runs")):
			n += 1
	for k in Story.PAGES.keys():
		if has_clue(k):
			n += 1
	var total := Island.SITES.size() + Wilds.WAYSTONES.size() + Wilds.MESSAGES.size() + Wilds.STAINS.size() + 4 + 3 \
		+ Story.GATES.size() + Story.PAGES.size() + Isles.ISLES.size() * 2
	return Vector2i(mini(n, total), total)
