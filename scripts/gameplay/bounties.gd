class_name Bounties
extends RefCounted
## Bounties: three short goals at a time, never the same kind twice at
## once, a little bigger as your Renown grows. Finish one and its reward
## lands at once (Renown, silver, a material, sometimes a weapon) and a new
## one takes its place, so there is always one nearly done.
##
## A bounty counts a kind of deed reported through Run.record:
## "kill", "kill:<kind>", "break", "critical", "heavy", "jump", "art",
## "chain" (the best chain reached), "elite", "night_kill", "forge", "loot",
## "thief".

const ACTIVE := 3
const KINDS := [
	{"kind": "kill", "text": "Put down %d risen", "base": 6.0, "grow": 0.6},
	{"kind": "kill:rogue", "text": "Put down %d Risen Rogues", "base": 3.0, "grow": 0.25},
	{"kind": "kill:warrior", "text": "Put down %d Risen Warriors", "base": 3.0, "grow": 0.25},
	{"kind": "break", "text": "Break %d stances", "base": 3.0, "grow": 0.3},
	{"kind": "critical", "text": "Land %d critical blows", "base": 2.0, "grow": 0.2},
	{"kind": "heavy", "text": "Land %d charged blows", "base": 4.0, "grow": 0.3},
	{"kind": "jump", "text": "Land %d leaping blows", "base": 3.0, "grow": 0.2},
	{"kind": "art", "text": "Use your Arts %d times", "base": 6.0, "grow": 0.4},
	{"kind": "chain", "text": "Reach a kill chain of %d", "base": 4.0, "grow": 0.25},
	{"kind": "elite", "text": "Put down %d Elites", "base": 1.0, "grow": 0.08, "from": 3},
	{"kind": "night_kill", "text": "Put down %d risen after dark", "base": 5.0, "grow": 0.4},
	{"kind": "forge", "text": "Forge or temper %d times", "base": 1.0, "grow": 0.1, "from": 2},
	{"kind": "loot", "text": "Take %d weapons from the risen", "base": 1.0, "grow": 0.1},
	{"kind": "thief", "text": "Catch a Grave Thief", "base": 1.0, "grow": 0.0, "from": 4},
	{"kind": "treasure", "text": "Dig up %d buried treasures", "base": 1.0, "grow": 0.05, "from": 2},
	{"kind": "kill:corsair", "text": "Put down %d Drowned Corsairs", "base": 4.0, "grow": 0.3, "from": 3},
	{"kind": "ship", "text": "Sink the Drowned Galleon", "base": 1.0, "grow": 0.0, "from": 5},
]
const MATERIALS := [["iron_scrap", 3], ["bone_shard", 4], ["grave_dust", 2], ["ember_coal", 1], ["rime_salt", 1]]

## Keeps three going.
static func ensure() -> void:
	while Run.bounties.size() < ACTIVE:
		Run.bounties.append(_new())
		Run.changed.emit("bounties")

static func _new() -> Dictionary:
	var lvl := Run.renown_level
	var busy := []
	for b in Run.bounties:
		busy.append(str(b["kind"]))
	var pool := []
	for k in KINDS:
		if not str(k["kind"]) in busy and lvl >= int(k.get("from", 1)):
			pool.append(k)
	var t: Dictionary = pool.pick_random()
	var need := maxi(1, int(float(t["base"]) + float(t["grow"]) * float(lvl - 1)))
	var text := str(t["text"]) % need if str(t["text"]).contains("%d") else str(t["text"])
	return {"kind": t["kind"], "text": text, "need": need, "have": 0,
		"xp": 50 + 14 * lvl, "silver": 25 + 8 * lvl}

## A deed happened: count it toward any bounty of that kind (`as_max`: the
## deed is a level reached, like a chain, not a count).
static func progress(kind: String, n: int, as_max: bool) -> void:
	var finished := []
	for b in Run.bounties:
		if str(b["kind"]) != kind:
			continue
		b["have"] = maxi(int(b["have"]), n) if as_max else int(b["have"]) + n
		if int(b["have"]) >= int(b["need"]):
			finished.append(b)
	if finished.is_empty():
		if not Run.bounties.is_empty():
			Run.changed.emit("bounties")
		return
	for b in finished:
		Run.bounties.erase(b)
		_reward(b)
	ensure()

static func _reward(b: Dictionary) -> void:
	Run.bounties_done += 1
	var parts: Array[String] = []
	Run.add_silver(int(b["silver"]), true)
	parts.append("%d silver" % int(b["silver"]))
	var m: Array = MATERIALS.pick_random()
	Run.add_item(str(m[0]), int(m[1]), true)
	parts.append("%d %s" % [int(m[1]), str(Run.item(str(m[0])).get("name", m[0]))])
	var r := randf()
	if r < 0.12:
		Run.add_item("star_iron", 1, true)
		parts.append("Star-Iron")
	elif r < 0.17:
		var up := "hearth_seed" if randf() < 0.5 else "bright_tear"
		Run.add_item(up, 1, true)
		parts.append(str(Run.item(up)["name"]))
	if randf() < 0.15:
		var mp := Treasure.roll_map()
		Run.add_item(mp, 1, true)
		parts.append("a treasure map")
	if randf() < 0.3:
		var id := Loot.roll_weapon("rare" if randf() < 0.25 else "fine")
		Run.add_item(id, 1, true)
		parts.append(str(Run.item(id)["name"]))
	parts.push_front("%d renown" % int(b["xp"]))
	Run.bounty_done.emit(str(b["text"]), ", ".join(parts))
	Run.renown(float(b["xp"]))

## The bounty nearest to done, for the HUD.
static func closest() -> Dictionary:
	var best := {}
	var best_f := -1.0
	for b in Run.bounties:
		var f := float(b["have"]) / maxf(float(b["need"]), 1.0)
		if f > best_f:
			best_f = f
			best = b
	return best
