class_name ArchivePage
extends Control
## The Archive: not a quest log. What you have noticed, in your own words
## (clues), where you have been, who you have met, and what you have put
## down. Section tabs on the left, the list, and the chosen entry.

var world: World
var _section := "clues"
var _selected := -1
var _list: VBoxContainer
var _detail: VBoxContainer
var _tabs: HBoxContainer

const SECTIONS := [["clues", "Noticed"], ["fragments", "Fragments"], ["places", "Places"], ["people", "People"],
	["bestiary", "Bestiary"]]

func _ready() -> void:
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 10)
	add_child(_tabs)
	var body := HBoxContainer.new()
	body.position = Vector2(0, 80)
	body.size = Vector2(size.x, size.y - 80)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_top = 80
	body.add_theme_constant_override("separation", 30)
	add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(400, 0)
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_detail = VBoxContainer.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 14)
	body.add_child(_detail)
	_build()

func _entries() -> Array:
	var out := []
	match _section:
		"clues":
			for c in Run.archive["clues"]:
				if not str(c["id"]).begins_with("page_"):
					out.append([str(c["title"]), "Day %d" % int(c["day"]), str(c["text"])])
			out.reverse()
		"fragments":
			for k in Story.PAGES.keys():
				var p: Array = Story.PAGES[k]
				if Run.has_clue(k):
					out.append([str(p[0]), "A page of the Rupture", str(p[1])])
				else:
					out.append(["Unfound", "", "A page you have not found. They are kept in the Gates."])
		"places":
			for id in Run.archive["places"].keys():
				if Island.SITES.has(id):
					out.append([str(Island.SITES[id]["name"]), "Found day %d" % int(Run.archive["places"][id]), _place_text(id)])
		"people":
			for n in Run.archive["people"].keys():
				out.append([str(n), "Met day %d" % int(Run.archive["people"][n]), "Someone of Brightwater."])
		"bestiary":
			for k in Run.archive["bestiary"].keys():
				out.append([str(k), "%d put down" % int(Run.archive["bestiary"][k]),
					"The risen of the Barrow. They do not stay down."])
	return out

static func _place_text(id: String) -> String:
	return {"village": "A fishing village round a market square. The bread is good.",
		"harbour": "Brightwater's harbour: a pier, and ships that have not sailed since the bells.",
		"castle": "Highmoor Keep, empty since the night its bell rang on its own.",
		"barrow": "A ring of fallen stones where the old kings were buried. The dead walk out of it now.",
		"tower": "Gull's Watch: a lighthouse nobody has kept in twenty years.",
		"crossroads": "Where the roads to the keep, the barrow and the village meet."}.get(id, "")

func _build() -> void:
	for c in _tabs.get_children():
		c.queue_free()
	for s in SECTIONS:
		var b := ChunkyButton.new(s[1], s[0] == _section, 15)
		var key: String = s[0]
		b.pressed.connect(func() -> void:
			_section = key
			_selected = 0
			_build())
		_tabs.add_child(b)
	for c in _list.get_children():
		c.queue_free()
	for c in _detail.get_children():
		c.queue_free()
	var e := _entries()
	if e.is_empty():
		_list.add_child(Kit.para("Nothing yet.", 16))
		return
	_selected = clampi(_selected, 0, e.size() - 1)
	for i in e.size():
		var b := ChunkyButton.new(str(e[i][0]), i == _selected, 15)
		b.custom_minimum_size.x = 400
		var idx := i
		b.pressed.connect(func() -> void:
			_selected = idx
			_build())
		_list.add_child(b)
	var cur: Array = e[_selected]
	_detail.add_child(Kit.title(str(cur[0]).to_upper(), 34, Kit.IVORY, 5))
	_detail.add_child(Kit.label(str(cur[1]).to_upper(), 13, Kit.GOLD))
	var body := Kit.para(str(cur[2]), 19, Kit.IVORY)
	body.custom_minimum_size = Vector2(620, 0)
	_detail.add_child(body)
