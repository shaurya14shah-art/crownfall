class_name Forge
extends RefCounted
## The Forge (data/forge.json): new weapons from a form, a metal and an
## etching; tempering any weapon +1..+5; etching an old one; and breaking
## gear back down into what it was made of. The hammer's quality (the
## timing strikes in ForgePanel) adds up to 15% to a new weapon.
##
## Costs are {item id: n} with "silver" for coin. Everything here only
## reads and writes Run, so it can be tested without a world.

const MAX_TEMPER := 5
const ETCH_COLOURS := {"ember": Color("ff7a2e"), "rime": Color("7fd3ff"), "grave": Color("8be08f")}

static var _data := {}

static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open("res://data/forge.json", FileAccess.READ)
		var d: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		_data = d if d is Dictionary else {"forms": {}, "metals": {}, "etchings": {}, "temper": []}
	return _data

static func forms() -> Dictionary:
	return data()["forms"]

static func metals() -> Dictionary:
	return data()["metals"]

static func etchings() -> Dictionary:
	return data()["etchings"]

# --- Paying -------------------------------------------------------------------------------

static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	for k in b.keys():
		out[k] = int(out.get(k, 0)) + int(b[k])
	return out

static func have(id: String) -> int:
	return Run.silver if id == "silver" else Run.count(id)

static func can_pay(cost: Dictionary) -> bool:
	for k in cost.keys():
		if have(k) < int(cost[k]):
			return false
	return true

static func pay(cost: Dictionary) -> bool:
	if not can_pay(cost):
		return false
	for k in cost.keys():
		if k == "silver":
			Run.spend(int(cost[k]))
		else:
			Run.remove_item(k, int(cost[k]))
	return true

# --- New weapons --------------------------------------------------------------------------------

static func craft_cost(form: String, metal: String, etching: String) -> Dictionary:
	var c: Dictionary = forms()[form]["cost"]
	c = merge(c, metals()[metal]["cost"])
	return merge(c, etchings()[etching]["cost"])

## The weapon these choices make; `quality` 0..1 from the hammer strikes.
static func design(form: String, metal: String, etching: String, quality: float = 0.0) -> Dictionary:
	var f: Dictionary = forms()[form]
	var m: Dictionary = metals()[metal]
	var e: Dictionary = etchings()[etching]
	var master := quality >= 0.99
	var name := "%s %s" % [m["name"], f["name"]] if metal != "iron" else "Iron %s" % f["name"]
	if str(e["suffix"]) != "":
		name += " " + str(e["suffix"])
	if master:
		name = "Masterwork " + name
	var rarity := str(m["rarity"])
	if etching != "none" and rarity == "common":
		rarity = "fine"
	if master:
		rarity = "rare" if rarity != "rare" else "relic"
	var d := {
		"name": name, "kind": "weapon", "model": f["model"], "icon": f["icon"],
		"damage": roundf(float(f["damage"]) * float(m["mult"]) * (1.0 + 0.15 * quality)),
		"speed": snappedf(float(f["speed"]) * float(m["speed"]), 0.01),
		"posture": float(f["posture"]), "rarity": rarity, "forged": true,
		"recipe": [form, metal, etching],
		"text": "Made at the forge by your own hand. %s" % str(e["text"]) if etching != "none" else
			"Made at the forge by your own hand.",
	}
	if bool(f.get("two_handed", false)):
		d["two_handed"] = true
	if etching != "none":
		d["etch"] = etching
	if m.has("tint"):
		d["tint"] = m["tint"]
	var worth := 0
	var cost := craft_cost(form, metal, etching)
	for k in cost.keys():
		worth += int(cost[k]) if k == "silver" else int(cost[k]) * int(Run.item(k).get("price", 5))
	d["price"] = int(worth * (1.0 + quality * 0.5))
	return d

## Forges it: pays, puts the new weapon in the bag, returns its id ("" if
## you could not pay or had no room).
static func craft(form: String, metal: String, etching: String, quality: float = 0.0) -> String:
	var cost := craft_cost(form, metal, etching)
	if not can_pay(cost) or _bag_full():
		return ""
	pay(cost)
	Run.forge_count += 1
	var id := "forged_%d" % Run.forge_count
	Run.forged[id] = design(form, metal, etching, quality)
	Run.add_item(id, 1, true)
	Run.flags["forged"] = true
	Run.record("forge")
	Run.renown(30.0 + 30.0 * quality)
	Run.gain("blade", 10.0)
	Run.lean("craft", 2.0)
	Run.changed.emit("forge")
	return id

static func _bag_full() -> bool:
	for s in Run.bag:
		if str(s["id"]) == "":
			return false
	return true

# --- Tempering and etching -----------------------------------------------------------------------

static func temper_level(id: String) -> int:
	return int(Run.temper.get(id, 0))

## The cost of the next step, or {} at +5.
static func temper_cost(id: String) -> Dictionary:
	var lvl := temper_level(id)
	if lvl >= MAX_TEMPER:
		return {}
	return data()["temper"][lvl]

static func temper(id: String) -> bool:
	var cost := temper_cost(id)
	if cost.is_empty() or Run.item(id).get("kind", "") != "weapon" or not pay(cost):
		return false
	Run.temper[id] = temper_level(id) + 1
	Run.flags["tempered"] = true
	Run.record("forge")
	Run.renown(10.0)
	Run.lean("craft", 1.0)
	Run.changed.emit("forge")
	Run.changed.emit("gear")
	return true

static func etch_cost(etching: String) -> Dictionary:
	return etchings()[etching]["cost"]

static func etch(id: String, etching: String) -> bool:
	if Run.item(id).get("kind", "") != "weapon" or str(Run.item(id).get("etch", "")) == etching:
		return false
	if not pay(etch_cost(etching)):
		return false
	Run.etch[id] = etching
	Run.lean("craft", 1.0)
	Run.changed.emit("forge")
	Run.changed.emit("gear")
	return true

# --- Salvage --------------------------------------------------------------------------------------

## What breaking one of these down gives back: about half of what it is made of.
static func salvage_yield(id: String) -> Dictionary:
	var d := Run.item(id)
	var out := {}
	if d.has("recipe"):
		var r: Array = d["recipe"]
		var c := craft_cost(str(r[0]), str(r[1]), str(r[2]))
		for k in c.keys():
			if k != "silver" and int(c[k]) >= 2:
				out[k] = int(c[k]) / 2
	else:
		match str(d.get("kind", "")):
			"weapon":
				out["iron_scrap"] = clampi(int(d.get("price", 40)) / 40, 1, 6)
			"shield":
				out["iron_scrap"] = clampi(int(d.get("price", 40)) / 60, 1, 4)
				out["bone_shard"] = 1
	var lvl := temper_level(id)
	if lvl >= 4:
		out["star_iron"] = int(out.get("star_iron", 0)) + 1
	elif lvl > 0:
		out["iron_scrap"] = int(out.get("iron_scrap", 0)) + lvl
	return out

## Whether this can go on the anvil: gear, not the last one you hold, not a relic.
static func can_salvage(id: String) -> bool:
	var d := Run.item(id)
	if not str(d.get("kind", "")) in ["weapon", "shield"] or d.get("rarity", "") == "relic":
		return false
	if (Run.gear.get("weapon", "") == id or Run.gear.get("shield", "") == id) and Run.count(id) <= 1:
		return false
	return Run.count(id) > 0

static func salvage(id: String) -> bool:
	if not can_salvage(id):
		return false
	var got := salvage_yield(id)
	Run.remove_item(id, 1)
	if Run.count(id) <= 0:
		Run.temper.erase(id)
		Run.etch.erase(id)
	for k in got.keys():
		Run.add_item(k, int(got[k]), true)
	Run.changed.emit("forge")
	return true

## How hard this weapon breaks a stance: its own "posture", else by shape.
static func posture_of(d: Dictionary) -> float:
	if d.has("posture"):
		return float(d["posture"])
	if str(d.get("model", "")) == "dagger":
		return 0.7
	return 1.4 if bool(d.get("two_handed", false)) else 1.0
