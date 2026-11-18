class_name Story
extends RefCounted
## The story of Aldermere, as facts in Run.flags and the Gates they open.
## Nothing here is a quest: people say different things as the world
## changes, Gates open when something has disturbed the Law, and what you
## learn goes in the Archive in your own words.
##
##   I    the Barrow — the dead walk; the Warden keeps them
##   II   the Drowned Stair — the cove runs backward once the Warden falls
##   III  the Hall of Still Hours — behind Highmoor's bell, once the Stair is still
##   IV   the Sundered Crown — on the peak, once the bells have stopped
##   end  the truth of the First Rupture

const GATES := {
	"drowned_stair": {
		"name": "The Drowned Stair", "law": "current", "rank": 2, "site": "harbour", "offset": [70, 0, 95],
		"opens": "warden_dead", "theme": "drowned", "rooms": 7,
		"foes": ["minion", "rogue", "warrior"], "boss": "tidewarden",
		"reward": [["silver", 140], ["star_iron", 1], ["hearth_seed", 1], ["rime_salt", 2]], "catalyst": "tide_glass",
		"pages": ["page_1", "page_2", "page_3"],
		"text": "Water runs up these steps, not down them.",
	},
	"still_hours": {
		"name": "The Hall of Still Hours", "law": "sequence", "rank": 3, "site": "castle", "offset": [0, 0, -16],
		"opens": "gate_drowned_stair", "theme": "keep", "rooms": 8,
		"foes": ["warrior", "rogue", "minion", "warrior"], "boss": "bellwright",
		"reward": [["silver", 260], ["star_iron", 2], ["bright_tear", 1], ["ember_coal", 2]], "catalyst": "hour_shard",
		"pages": ["page_4", "page_5", "page_6"],
		"text": "Every clock in here stopped at the same moment.",
	},
	"sundered_crown": {
		"name": "The Sundered Crown", "law": "oath", "rank": 4, "site": "peak", "offset": [0, 0, 0],
		"opens": "gate_still_hours", "theme": "crown", "rooms": 9,
		"foes": ["warrior", "warrior", "rogue", "minion"], "boss": "crownless",
		"reward": [["silver", 500], ["star_iron", 3], ["hearth_seed", 1], ["bright_tear", 1]], "catalyst": "crown_fragment",
		"pages": ["page_7", "page_8", "page_9"],
		"text": "A throne room built for something that never sat down.",
	},
}

## The Fragments of the Rupture, found as pages in the Gates.
const PAGES := {
	"page_1": ["The First Fragment", "Before the Rupture the Laws were one Law, the way a crown is one circle. Nobody now remembers who wore it."],
	"page_2": ["The Second Fragment", "Water was the first to forget. It began to run where it was told, not where it fell."],
	"page_3": ["The Third Fragment", "They built the Stair to carry the sea up to the keep. The sea agreed. Then it would not stop."],
	"page_4": ["The Fourth Fragment", "Highmoor's bell was cast from the crown's clasp. When it rang, the hours held still to listen."],
	"page_5": ["The Fifth Fragment", "The Bellwright rang it once each night so the island would stay whole. One night he did not."],
	"page_6": ["The Sixth Fragment", "What breaks when a promise is not kept? Everything that was holding to it."],
	"page_7": ["The Seventh Fragment", "The crown was not broken by an enemy. It was broken by the one who wore it, on purpose."],
	"page_8": ["The Eighth Fragment", "He wanted each Law to belong to someone, instead of all of them to no one. He called it a gift."],
	"page_9": ["The Ninth Fragment", "Every Inscription is a splinter of that crown. Yours too. That is why it chose you, and why it is hungry."],
}

## Where the peak is (the third Gate stands on it).
static func peak_pos(isl: Island) -> Vector3:
	var best := Vector3.ZERO
	var c := Vector2(60, -540)
	for k in 400:
		var a := float(k) * 2.399
		var r := sqrt(float(k)) * 12.0
		var p := c + Vector2(cos(a), sin(a)) * r
		var h := isl.height_at(p.x, p.y)
		if h > best.y:
			best = Vector3(p.x, h, p.y)
	return best

static func gate_open(id: String) -> bool:
	return Run.flags.has(str(GATES[id]["opens"]))

static func gate_cleared(id: String) -> bool:
	return Run.flags.has("gate_" + id)

## How far the story has come, 0..4, for what people say.
static func stage() -> int:
	if Run.flags.has("gate_sundered_crown"):
		return 4
	if Run.flags.has("gate_still_hours"):
		return 3
	if Run.flags.has("gate_drowned_stair"):
		return 2
	if Run.flags.has("warden_dead"):
		return 1
	return 0

## A line for a villager that knows what has happened.
static func line_for(who: String) -> String:
	var s := stage()
	var lines := {
		"Wenna": ["The fish haven't come in since the bells rang at Highmoor.",
			"Have you seen the cove? The water's running out to the rocks and climbing them.",
			"The tide came back this morning. Proper, the way tides go. Was that you?",
			"Last night the bell didn't ring at all. First time I've slept since spring.",
			"My husband says the island feels lighter. My husband says a lot."],
		"Old Fennick": ["I saw a light on Gull's Watch last night. Nobody's kept that tower in twenty years.",
			"There's a hole in the air down by the cove. Blue. Humming. Don't you go near it. You will, though.",
			"The Bellwright was my grandfather's friend. He went up to the keep one night and never came down.",
			"There's a crown on the mountain now. Up on the peak. I can see it shine from my door.",
			"I dreamed of a king with no head and no crown, saying sorry. Funny, the things you dream."],
		"Ysolde": ["Roll out of the way when they raise their blades — they're slow to swing.",
			"Whatever's in that blue hole, it's colder than the sea. You can feel it from the pier.",
			"If you go into the keep at night, take a light. Take two.",
			"You've the look of someone who's seen the top of the mountain.",
			"Brightwater bread. Best on the island. Only bread on the island, mind."],
		"Corwin": ["Hold your shield up and they'll break on it like waves on the pier.",
			"Those things from the cove hit harder. Keep moving.",
			"Clocks in the keep stopped, they say. All of them, the same minute.",
			"Whatever's up there wears a crown and isn't a king. That's all I know and I don't like it.",
			"Quiet out there now. Strange, the quiet."],
	}
	if lines.has(who):
		var l: Array = lines[who]
		return str(l[mini(s, l.size() - 1)])
	return ""
