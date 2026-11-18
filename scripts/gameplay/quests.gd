class_name Quests
extends RefCounted
## Quests: the story and the side errands as steps you can see and track.
## Each step names where to go (a place, a Gate, a person, a thing) and
## the fact in Run that finishes it, so a quest moves on by itself when the
## world changes — kill the Warden however you like and the step is done.
##
## step: {text, target, done}
##   target: "site:<id>", "gate:<id>", "npc:<name>", "way:<waystone>", "fb:<field boss>", "bell", or ""
##   done:   "flag:<name>", "clue:<id>", "law", "rank:<n>", "pages:<n>", "bought", "potential:<n>"

const ALL := {
	"main": {"title": "The Shattered Crown", "kind": "main", "starts": "",
		"text": "Something is wrong with Aldermere. The dead walk, and the bells of Highmoor rang on their own.",
		"steps": [
			{"text": "Speak with Elder Maren in Brightwater", "target": "npc:Elder Maren", "done": "clue:elder_barrow"},
			{"text": "Put down the Barrow Warden", "target": "site:barrow", "done": "flag:warden_dead"},
			{"text": "Enter the Gate at the cove", "target": "gate:drowned_stair", "done": "flag:gate_drowned_stair"},
			{"text": "Find what woke Highmoor's bell", "target": "gate:still_hours", "done": "flag:gate_still_hours"},
			{"text": "Climb to the crown on the peak", "target": "gate:sundered_crown", "done": "flag:gate_sundered_crown"},
		],
		"reward": "The truth of the First Rupture"},
	"warden_bounty": {"title": "Brightwater's Thanks", "kind": "side", "starts": "flag:warden_dead",
		"text": "The Elder will want to hear that the Warden is gone.",
		"steps": [{"text": "Tell Elder Maren the Warden has fallen", "target": "npc:Elder Maren", "done": "flag:elder_thanked"}],
		"reward": "120 silver, 3 draughts"},
	"open_sea": {"title": "The Open Sea", "kind": "side", "starts": "",
		"text": "A sloop called the Gull rides at Brightwater's pier, and a map in your pack has an X on an isle called Skull Key.",
		"steps": [
			{"text": "Board the Gull at Brightwater Harbour", "target": "ship:gull", "done": "flag:boarded"},
			{"text": "Take the helm", "target": "ship:gull", "done": "flag:helmed"},
			{"text": "Sail to Skull Key", "target": "isle:skull_key", "done": "place:isle_skull_key"},
			{"text": "Dig up what is buried on Skull Key", "target": "dig", "done": "flag:dug"},
		],
		"reward": "Treasure, and the sea"},
	"galleon": {"title": "The Drowned Galleon", "kind": "side", "starts": "flag:galleon_seen",
		"text": "A ship of the dead sails a round of the isles, and fires on anything that floats.",
		"steps": [{"text": "Sink the Drowned Galleon", "target": "galleon", "done": "flag:galleon_sunk"}],
		"reward": "Whatever it carries"},
	"kindling": {"title": "A Place to Rest", "kind": "side", "starts": "",
		"text": "Old stones stand along the roads with a cold ember on top. Knights used to rest at them.",
		"steps": [{"text": "Kindle the Waystone on the Harbour Road", "target": "way:harbour_road", "done": "flag:rested"}],
		"reward": "Somewhere to come back to"},
	"smiths_fire": {"title": "Your Own Blade", "kind": "side", "starts": "flag:rested",
		"text": "Every Waystone has an anvil at its foot. Bring scrap from the risen and make something of it.",
		"steps": [
			{"text": "Forge a weapon at a Waystone's anvil", "target": "", "done": "flag:forged"},
			{"text": "Temper a weapon", "target": "", "done": "flag:tempered"},
		],
		"reward": "A weapon nobody else has"},
	"drowned_captain": {"title": "The Drowned Captain", "kind": "side", "starts": "clue:elder_barrow",
		"text": "The fishermen won't walk the shore below the pier. Something in a captain's coat walks it for them.",
		"steps": [{"text": "Put down the Drowned Captain on the harbour shore", "target": "fb:drowned_captain",
			"done": "flag:fb_drowned_captain"}],
		"reward": "Star-Iron, and a captain's shield"},
	"night_knight": {"title": "A Knight on the Road", "kind": "side", "starts": "flag:warden_dead",
		"text": "Travellers say a great armoured dead thing walks the Crossroads road, but only after dark.",
		"steps": [{"text": "Find the Grave Knight on the road, at night", "target": "fb:grave_knight",
			"done": "flag:fb_grave_knight"}],
		"reward": "The Grave Knight's Greatsword"},
	"arm_yourself": {"title": "Arm Yourself", "kind": "side", "starts": "",
		"text": "Tobin the smith sells blades and shields in the square. Iron is cheaper than a grave.",
		"steps": [{"text": "Buy something at Tobin's forge", "target": "npc:Tobin the Smith", "done": "flag:bought"}],
		"reward": "Better odds"},
	"awakening": {"title": "Something Listening", "kind": "side", "starts": "potential:20",
		"text": "Near the Barrow you feel something in you lean toward the fighting, like a dog toward a door.",
		"steps": [
			{"text": "Fight the risen near the Barrow of Ash", "target": "site:barrow", "done": "law"},
		],
		"reward": "Your Inscription"},
	"ascendant": {"title": "Ascendant", "kind": "side", "starts": "law",
		"text": "Your Inscription can grow. Master it, find all it can do, and find a catalyst.",
		"steps": [{"text": "Reach mastery 30, find your hidden power, and pass a trial", "target": "", "done": "rank:3"}],
		"reward": "Rank III"},
	"tower_light": {"title": "A Light on Gull's Watch", "kind": "side", "starts": "clue:elder_barrow",
		"text": "Old Fennick swears there is a lamp burning in the lighthouse nobody has kept for twenty years.",
		"steps": [{"text": "Visit Gull's Watch after dark", "target": "site:tower", "done": "clue:tower_light"}],
		"reward": "Whatever the light is for"},
	"the_bell": {"title": "The Bell at Night", "kind": "side", "starts": "flag:gate_drowned_stair",
		"text": "Highmoor's bell rang on its own. The fishermen say it was only ever the night ringing that mattered.",
		"steps": [{"text": "Ring Highmoor's bell after dark", "target": "bell", "done": "flag:bell_answered"}],
		"reward": "An answer"},
	"fragments": {"title": "Fragments of the Rupture", "kind": "side", "starts": "clue:page_1",
		"text": "Pages left in the Gates by someone who knew what broke the Laws.",
		"steps": [{"text": "Find all nine Fragments of the Rupture", "target": "", "done": "pages:9"}],
		"reward": "The whole story"},
}

## Whether a condition string holds now.
static func holds(cond: String) -> bool:
	if cond == "":
		return true
	var parts := cond.split(":")
	match parts[0]:
		"flag":
			return Run.flags.has(parts[1])
		"clue":
			return Run.has_clue(parts[1])
		"law":
			return not Run.law.is_empty()
		"rank":
			return int(Run.law.get("rank", 1)) >= int(parts[1])
		"pages":
			var n := 0
			for k in Story.PAGES.keys():
				if Run.has_clue(k):
					n += 1
			return n >= int(parts[1])
		"potential":
			return Run.potential >= float(parts[1]) or not Run.law.is_empty()
		"place":
			return Run.archive["places"].has(parts[1])
	return false

## How many of the nine pages are found (for the fragments quest's line).
static func pages_found() -> int:
	var n := 0
	for k in Story.PAGES.keys():
		if Run.has_clue(k):
			n += 1
	return n

static func step_text(id: String) -> String:
	var q: Dictionary = ALL[id]
	var st: Dictionary = Run.quests.get(id, {})
	var i := int(st.get("step", 0))
	if bool(st.get("done", false)) or i >= (q["steps"] as Array).size():
		return "Complete"
	var t := str(q["steps"][i]["text"])
	if id == "fragments":
		t += "  (%d / 9)" % pages_found()
	return t

## Where the current step of a quest wants you, or Vector3.INF.
static func target_of(id: String, world: World) -> Vector3:
	var q: Dictionary = ALL.get(id, {})
	var st: Dictionary = Run.quests.get(id, {})
	if q.is_empty() or bool(st.get("done", false)):
		return Vector3.INF
	var i := int(st.get("step", 0))
	if i >= (q["steps"] as Array).size():
		return Vector3.INF
	var t := str(q["steps"][i]["target"])
	if t == "" or world == null:
		return Vector3.INF
	var parts := t.split(":")
	match parts[0]:
		"site":
			return world.island.site_pos(parts[1])
		"gate":
			for g in world.get_tree().get_nodes_in_group("gates"):
				if (g as GatePortal).gate_id == parts[1]:
					return (g as Node3D).global_position
		"npc":
			for v in world.get_tree().get_nodes_in_group("villagers"):
				if (v as Villager).display_name == parts[1]:
					return (v as Node3D).global_position
		"ship":
			if world.gull != null:
				return world.gull.global_position
		"isle":
			return Isles.landing(parts[1])
		"galleon":
			for g in world.get_tree().get_nodes_in_group("enemy_ships"):
				return (g as Node3D).global_position
		"dig":
			for d in world.get_tree().get_nodes_in_group("dig_sites"):
				if (d as Treasure).index in Treasure.held_sites():
					return (d as Node3D).global_position
		"way":
			if world.wilds != null and world.wilds.waystone(parts[1]) != null:
				return world.wilds.waystone(parts[1]).global_position
		"fb":
			if world.wilds != null:
				return world.wilds.boss_spot(parts[1])
		"bell":
			for b in world.get_tree().get_nodes_in_group("interactables"):
				if b is Bell:
					return (b as Node3D).global_position
	return Vector3.INF
