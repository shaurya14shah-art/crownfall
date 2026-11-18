class_name Renown
extends RefCounted
## The Renown track: what each level brings, so the next one is always
## worth one more fight. Even levels give a Renown point (spend it in any
## tree); odd ones go round Hearthseed, Star-Iron, Bright Tear, a rare
## weapon and a purse of silver; every tenth is a relic. Every level also
## adds health (Player.max_health) and heals you whole.

const CYCLE := [["hearth_seed", 1], ["star_iron", 1], ["bright_tear", 1], ["loot:rare", 1], ["silver", 200]]
const HEALTH_PER_LEVEL := 3.0

static func reward_for(level: int) -> Array:
	if level % 10 == 0:
		return ["loot:relic", 1]
	if level % 2 == 0:
		return ["point", 1]
	return CYCLE[(maxi(level - 3, 0) / 2) % CYCLE.size()]

static func describe(r: Array) -> String:
	match str(r[0]):
		"point":
			return "A Renown point"
		"silver":
			return "%d silver" % int(r[1])
		"loot:rare":
			return "A rare weapon"
		"loot:relic":
			return "A relic weapon"
	return str(Run.item(str(r[0])).get("name", r[0]))

## Gives the reward for reaching `level`; returns what it was, in words.
static func grant(level: int) -> String:
	var r := reward_for(level)
	match str(r[0]):
		"point":
			Run.renown_points += int(r[1])
			Run.changed.emit("skills")
		"silver":
			Run.add_silver(int(r[1]), true)
		"loot:rare", "loot:relic":
			var id := Loot.roll_weapon("rare" if r[0] == "loot:rare" else "relic")
			Run.add_item(id, 1, true)
			return str(Run.item(id).get("name", "A weapon"))
		_:
			Run.add_item(str(r[0]), int(r[1]), true)
	return describe(r)
