class_name Law
extends RefCounted
## The Laws and Inscriptions (data/laws.json, data/inscription_parts.json).
## An Inscription is Principle + Condition + Price. Nobody chooses one: it
## awakens in a crisis, shaped by the behaviour profile Run has been keeping,
## and must pass the balance rule — an easy condition carries a heavy price.
##
## Each principle has a manifest power (F, from the moment of awakening) and
## a hidden second use (G) that reveals itself only when the circumstance
## that suits it has come round often enough.

const COLOURS := {
	"momentum": Color(0.95, 0.60, 0.29), "structure": Color(0.78, 0.64, 0.42), "boundary": Color(0.34, 0.80, 0.95),
	"sequence": Color(0.61, 0.55, 0.95), "renewal": Color(0.44, 0.81, 0.59), "reflection": Color(0.88, 0.90, 0.94),
	"oath": Color(0.95, 0.79, 0.30), "current": Color(0.18, 0.61, 0.86),
}

## Per principle: the manifest power and the hidden one. `kind` is what
## LawPowers does; `discover` is "counter:times" for the hidden one.
const POWERS := {
	"momentum": [{"id": "borrowed_step", "name": "Borrowed Step", "cd": 7.0, "kind": "dash_strike",
			"text": "Lunge through your foes, striking all you pass."},
		{"id": "redirect", "name": "Redirect", "cd": 12.0, "kind": "reflect", "discover": "blocks:6",
			"text": "For a few breaths, blows that land on you are handed back."}],
	"structure": [{"id": "unmake_the_joint", "name": "Unmake the Joint", "cd": 8.0, "kind": "empower",
			"text": "Your next strike finds the seam and breaks it open."},
		{"id": "brace", "name": "Brace", "cd": 14.0, "kind": "stoneskin", "discover": "hits_taken:8",
			"text": "Set like stone: you take far less for a time."}],
	"boundary": [{"id": "the_drawn_line", "name": "The Drawn Line", "cd": 12.0, "kind": "barrier",
			"text": "Draw a ring nothing hostile may cross."},
		{"id": "closed_door", "name": "Closed Door", "cd": 7.0, "kind": "blink", "discover": "rolls:10",
			"text": "Step through a door that was not there."}],
	"sequence": [{"id": "half_a_beat", "name": "Half a Beat", "cd": 14.0, "kind": "slow",
			"text": "Everything near you falls half a beat behind."},
		{"id": "afterimage", "name": "Afterimage", "cd": 10.0, "kind": "negate", "discover": "dodges:5",
			"text": "The next blow strikes where you were, not where you are."}],
	"renewal": [{"id": "knit", "name": "Knit", "cd": 14.0, "kind": "heal",
			"text": "Wounds close over a few heartbeats."},
		{"id": "second_wind", "name": "Second Wind", "cd": 18.0, "kind": "surge", "discover": "heals:3",
			"text": "Breath and strength come flooding back."}],
	"reflection": [{"id": "mirror_sight", "name": "Mirror Sight", "cd": 12.0, "kind": "expose",
			"text": "See every foe near you as it truly is: they take more harm."},
		{"id": "false_image", "name": "False Image", "cd": 14.0, "kind": "decoy", "discover": "rolls:8",
			"text": "Leave an image of yourself for them to fight."}],
	"oath": [{"id": "spoken_terms", "name": "Spoken Terms", "cd": 10.0, "kind": "bind",
			"text": "Name terms to a foe; it is bound to them and cannot act."},
		{"id": "oathbreakers_due", "name": "Oathbreaker's Due", "cd": 12.0, "kind": "burst", "discover": "bound_kills:3",
			"text": "Collect what is owed from everything you have bound."}],
	"current": [{"id": "pull_of_water", "name": "Pull of Water", "cd": 7.0, "kind": "pull",
			"text": "Draw a foe to you like a wave drawing back."},
		{"id": "undertow", "name": "Undertow", "cd": 12.0, "kind": "wave", "discover": "pulls:5",
			"text": "A surge that throws everything before you off its feet."}],
}

const RANK_TITLES := ["", "Dormant", "Awakened", "Ascendant", "Exalted", "Sovereign", "Transcendent", "Eternal"]
const DIMENSIONS := {
	"depth": {"name": "Depth", "text": "Every use is 15% stronger."},
	"reach": {"name": "Reach", "text": "Your powers reach 25% further."},
	"complexity": {"name": "Complexity", "text": "Your powers recover 15% sooner."},
	"expression": {"name": "Expression", "text": "Hidden uses reveal themselves in half the time."},
}

static var _laws := {}
static var _parts := {}

static func _load() -> void:
	if _laws.is_empty():
		_laws = Run._read("res://data/laws.json")
		_parts = Run._read("res://data/inscription_parts.json")

static func principle_name(p: String) -> String:
	_load()
	return str(_laws["principles"].get(p, {}).get("name", p.capitalize()))

static func condition_def(c: String) -> Dictionary:
	_load()
	return _parts["conditions"].get(c, {})

static func price_def(p: String) -> Dictionary:
	_load()
	return _parts["prices"].get(p, {})

static func colour(p: String) -> Color:
	return COLOURS.get(p, Color.WHITE)

## A new Inscription from a behaviour profile. Weighted toward the principle
## the profile leans to, never locked to it.
static func generate(profile: Dictionary, seed_value: int) -> Dictionary:
	_load()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var aff: Dictionary = _parts["profile_affinity"]
	var weights := {}
	var total := 0.0
	for p in POWERS.keys():
		var w := 1.0
		for axis in (aff.get(p, {}) as Dictionary).keys():
			w += maxf(float(profile.get(axis, 0.0)), 0.0) * float(aff[p][axis]) * 0.08
		w *= rng.randf_range(0.85, 1.15)
		weights[p] = w
		total += w
	var roll := rng.randf() * total
	var principle := "momentum"
	for p in weights.keys():
		roll -= float(weights[p])
		if roll <= 0.0:
			principle = p
			break
	# Condition and price that pass the balance rule.
	var power := float(_laws["principles"][principle]["power"])
	var bal: Dictionary = _parts["balance"]
	var options: Array = []
	for c in _parts["conditions"].keys():
		for pr in _parts["prices"].keys():
			var pd: Dictionary = _parts["prices"][pr]
			if pd.has("principles") and not principle in pd["principles"]:
				continue
			var ratio := power * float(_parts["conditions"][c]["power_mod"]) / float(pd["severity"])
			if ratio >= float(bal["ratio_min"]) and ratio <= float(bal["ratio_max"]):
				options.append([c, pr])
	var pick: Array = options[rng.randi() % options.size()]
	var nouns: Dictionary = _parts["name_nouns"]
	var adj: Array = _parts["name_adjectives"]
	var noun_list: Array = nouns.get(principle, ["Law"])
	var name := "The %s %s" % [adj[rng.randi() % adj.size()], noun_list[rng.randi() % noun_list.size()]]
	var exprs: Array = _parts["expressions"]
	return {
		"principle": principle, "condition": pick[0], "price": pick[1], "name": name,
		"expression": exprs[rng.randi() % exprs.size()],
		"magnitude": 1.0 + rng.randf_range(-float(bal["magnitude_jitter"]), float(bal["magnitude_jitter"])),
		"rank": 2, "mastery": 0.0, "found": {POWERS[principle][0]["id"]: true}, "counters": {}, "uses": {},
		"dims": {}, "mark": 0,
	}

static func powers_of(l: Dictionary) -> Array:
	return POWERS.get(l.get("principle", ""), [])

static func found(l: Dictionary, idx: int) -> bool:
	var ps := powers_of(l)
	return idx < ps.size() and (l.get("found", {}) as Dictionary).has(ps[idx]["id"])

## Counts a circumstance; returns the hidden power if it just revealed itself.
static func notice(l: Dictionary, counter: String, amount: int = 1) -> Dictionary:
	if l.is_empty():
		return {}
	var c: Dictionary = l["counters"]
	c[counter] = int(c.get(counter, 0)) + amount
	var hidden: Dictionary = powers_of(l)[1]
	if (l["found"] as Dictionary).has(hidden["id"]):
		return {}
	var parts := str(hidden["discover"]).split(":")
	var need := int(parts[1])
	if (l["dims"] as Dictionary).has("expression"):
		need = int(ceil(need * 0.5))
	need = int(ceil(need * (1.0 - Run.perk("discovery"))))
	if parts[0] == counter and int(c[counter]) >= need:
		l["found"][hidden["id"]] = true
		return hidden
	return {}

## Mastery from use: each use of the same power teaches less than the last.
static func practise(l: Dictionary, power_id: String) -> void:
	var u: Dictionary = l["uses"]
	var n := int(u.get(power_id, 0))
	u[power_id] = n + 1
	var before := int(float(l["mastery"]) / 10.0)
	l["mastery"] = minf(100.0, float(l["mastery"]) + 1.6 / (1.0 + float(n) / 12.0) * 1.4)
	# A point in the Law's tree for every ten mastery.
	var gained := int(float(l["mastery"]) / 10.0) - before
	if gained > 0:
		Run.skills["law"]["points"] = int(Run.skills["law"]["points"]) + gained
		Run.toast.emit("The Law  +%d point" % gained, "law")
		Run.changed.emit("skills")

## What each rank asks and gives. Catalysts come from the story's keepers.
const RANKS := {
	3: {"mastery": 30.0, "catalyst": "stilled_tide_shard", "unlock": "Chained: using one power halves the other's wait."},
	4: {"mastery": 55.0, "catalyst": "hour_shard", "unlock": "Overflow (H): your Law bursts out around you."},
	5: {"mastery": 75.0, "catalyst": "crown_fragment", "unlock": "Sovereign: your Law colours the air near you; foes in it are weakened."},
}

static func next_rank(l: Dictionary) -> int:
	return int(l.get("rank", 1)) + 1

static func can_ascend(l: Dictionary) -> String:
	if l.is_empty():
		return "Your Inscription has not awakened."
	var nr := next_rank(l)
	if not RANKS.has(nr):
		return "No one knows a path beyond this."
	var need: Dictionary = RANKS[nr]
	if float(l["mastery"]) < float(need["mastery"]):
		return "Mastery %d needed (%d)." % [int(need["mastery"]), int(l["mastery"])]
	if not found(l, 1):
		return "You have not found everything your Inscription can do."
	if Run.count(str(need["catalyst"])) <= 0:
		return "A catalyst is needed: %s." % str(Run.item(str(need["catalyst"])).get("name", "?"))
	return ""

static func strength(l: Dictionary) -> float:
	var s := float(l.get("magnitude", 1.0)) * (1.0 + 0.08 * float(int(l.get("rank", 2)) - 2))
	s *= 1.0 + 0.15 * float(int((l.get("dims", {}) as Dictionary).get("depth", 0)))
	s *= 1.0 + Run.perk("law_power")
	if Run.count("tide_glass") > 0:
		s *= 1.1
	return s
