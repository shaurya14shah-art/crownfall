class_name Codex
extends Control
## The one menu: Tab opens it on the page you last used. Big icon tabs along
## the top (Inventory, Skills, Inscription, Map, Archive), the page below,
## silver and the way out in the corner. Opaque ink over a darkened world;
## nothing is frosted.

signal closed

const PAGES := [["journey", "Journey", "pin"], ["inventory", "Inventory", "bag"], ["skills", "Skills", "star"],
	["law", "Inscription", "sigil"], ["map", "Map", "map"], ["archive", "Archive", "scroll"]]

static var last_page := "inventory"

var world: World
var _tabs: Array[Control] = []
var _body: Control
var _page: Control
var _current := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Kit.theme()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.05, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var top := HBoxContainer.new()
	top.position = Vector2(60, 34)
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	for p in PAGES:
		var t := CodexTab.new()
		t.id = p[0]
		t.caption = p[1]
		t.glyph = p[2]
		t.pressed.connect(func() -> void: open(t.id))
		top.add_child(t)
		_tabs.append(t)
	var hint := Kit.label("TAB  CLOSE", 14, Kit.MUTED)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hint.position = Vector2(-150, 48)
	add_child(hint)
	_body = Control.new()
	_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.offset_top = 130
	_body.offset_left = 60
	_body.offset_right = -60
	_body.offset_bottom = -40
	add_child(_body)

func open(id: String) -> void:
	if id == _current:
		return
	_current = id
	last_page = id
	for t in _tabs:
		(t as CodexTab).selected = (t as CodexTab).id == id
		t.queue_redraw()
	if _page != null:
		_page.queue_free()
	match id:
		"journey": _page = JourneyPage.new()
		"inventory": _page = InventoryPage.new()
		"skills": _page = SkillsPage.new()
		"law": _page = LawPage.new()
		"map": _page = MapPage.new()
		"archive": _page = ArchivePage.new()
	_page.set("world", world)
	_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body.add_child(_page)
	_page.modulate.a = 0.0
	_page.position.y = 12
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_page, "modulate:a", 1.0, 0.18)
	tw.tween_property(_page, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Audio.ui("open", -12.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") or event.is_action_pressed("pause"):
		closed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skills"):
		open("skills")
	elif event.is_action_pressed("map"):
		open("map")
	elif event.is_action_pressed("archive"):
		open("archive")

## A tab: a chunky square with a glyph, the page's name under it.
class CodexTab extends Button:
	var id := ""
	var caption := ""
	var glyph := ""
	var selected := false
	var _hover := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(128, 82)
		focus_mode = Control.FOCUS_NONE
		for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			add_theme_stylebox_override(s, StyleBoxEmpty.new())
		mouse_entered.connect(func() -> void:
			_hover = 1.0
			queue_redraw()
			Audio.ui("hover", -18.0))
		mouse_exited.connect(func() -> void:
			_hover = 0.0
			queue_redraw())

	func _draw() -> void:
		var lift := 4.0 if selected else _hover * 2.0
		var r := Rect2(Vector2(0, 6 - lift), Vector2(size.x, size.y - 6))
		draw_rect(Rect2(Vector2(0, 6), Vector2(size.x, size.y - 6)), Color("0b0c10"))
		var fill := Kit.GOLD if selected else Kit.INK_2.lightened(0.05 * _hover)
		var rim := Kit.GOLD_LIGHT if selected else Kit.LINE.lerp(Kit.GOLD, _hover)
		draw_style_box(HUD.chip(fill, rim), r)
		var ink := Kit.INK if selected else Kit.IVORY
		Glyphs.draw(self, glyph, r.position + Vector2(size.x * 0.5, 28), 28.0, ink)
		draw_string(Game.ui_bold, r.position + Vector2(0, r.size.y - 14), caption.to_upper(), HORIZONTAL_ALIGNMENT_CENTER,
			size.x, 13, ink)
