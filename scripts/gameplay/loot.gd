class_name Loot
extends RefCounted
## Weapons and shields the risen carry, rolled fresh each time: a shape, a
## metal and maybe an etching, chosen by rarity (common, fine, rare, relic),
## with the numbers jittered so no two are quite the same. Relics get a name
## of their own. They live in Run.forged as "loot_<n>", beside what you
## forge, so they temper, etch and salvage the same way.

const EPITHETS := ["Gravesong", "Oathbreaker", "Tidewake", "Last Light", "Ashen Vow", "Crownsplitter",
	"Widow's Hour", "Bellmourn", "Saltmarrow", "Nightglass", "The Quiet Answer", "Barrowheart"]
const SHIELDS := [["shield_round", "Round Shield", 0.0], ["shield_badge", "Crested Shield", 0.02],
	["shield_spikes", "Spiked Shield", -0.02], ["shield_square", "Tower Shield", 0.05],
	["shield_round_barbarian", "Raider's Shield", 0.0]]

## A rarity, luckier with `luck` (1 for an ordinary kill; more for Elites,
## chests and the great dead).
static func tier_roll(luck: float = 1.0) -> String:
	var r := randf()
	if r < 0.008 * luck:
		return "relic"
	if r < 0.07 * luck:
		return "rare"
	if r < 0.32 * luck:
		return "fine"
	return "common"

static func roll_weapon(tier: String) -> String:
	var form: String = Forge.forms().keys().pick_random()
	var metal := "iron"
	var etching := "none"
	var q := 0.0
	match tier:
		"common":
			q = randf_range(0.0, 0.25)
		"fine":
			metal = ["iron", "bone", "grave"].pick_random()
			etching = ["ember", "rime", "grave"].pick_random() if randf() < 0.35 else "none"
			q = randf_range(0.15, 0.5)
		"rare":
			metal = "star" if randf() < 0.4 else "grave"
			etching = ["ember", "rime", "grave"].pick_random() if randf() < 0.75 else "none"
			q = randf_range(0.4, 0.9)
		"relic":
			metal = "star"
			etching = ["ember", "rime", "grave"].pick_random()
			q = 1.0
	var d := Forge.design(form, metal, etching, q)
	d["rarity"] = tier
	d["speed"] = snappedf(float(d["speed"]) * randf_range(0.96, 1.04), 0.01)
	d["text"] = "Taken from the risen." + (" " + str(Forge.etchings()[etching]["text"]) if etching != "none" else "")
	if tier == "relic":
		d["name"] = "%s, %s" % [EPITHETS.pick_random(), str(d["name"]).trim_prefix("Masterwork ")]
		d["damage"] = roundf(float(d["damage"]) * 1.1)
		d["text"] = "A relic. Whoever carried it last was somebody once. " + str(Forge.etchings()[etching]["text"])
	return _store(d)

static func roll_shield(tier: String) -> String:
	var s: Array = SHIELDS.pick_random()
	var lift := {"common": 0.0, "fine": 0.05, "rare": 0.1, "relic": 0.15}
	var d := {"name": str(s[1]), "kind": "shield", "model": s[0], "rarity": tier,
		"block": clampf(0.7 + float(s[2]) + float(lift[tier]) + randf_range(-0.03, 0.03), 0.6, 0.95),
		"price": int(40 * (1.0 + float(lift[tier]) * 20.0)), "text": "Taken from the risen."}
	if tier != "common" and randf() < 0.4:
		d["thorns"] = snappedf(randf_range(0.08, 0.25), 0.01)
	if tier == "relic":
		d["name"] = "%s, %s" % [EPITHETS.pick_random(), str(s[1])]
	elif tier == "rare":
		d["name"] = "Star-iron " + str(s[1])
	elif tier == "fine":
		d["name"] = "Grave-iron " + str(s[1])
	return _store(d)

static func _store(d: Dictionary) -> String:
	Run.loot_count += 1
	var id := "loot_%d" % Run.loot_count
	Run.forged[id] = d
	return id

## Maybe drops something here: `chance` of anything at all, rolled with `luck`.
static func maybe_drop(parent: Node, at: Vector3, chance: float, luck: float) -> void:
	if randf() > chance * (2.0 if Run.surge else 1.0):
		return
	var tier := tier_roll(luck)
	var id := roll_weapon(tier) if randf() < 0.75 else roll_shield(tier)
	Pickup.spawn(parent, at + Vector3(randf_range(-1, 1), 0.2, randf_range(-1, 1)), id, 1)
