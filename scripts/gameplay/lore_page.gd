class_name LorePage
extends Node3D
## A page of the Rupture on a lectern, lit by a candle. Read it (E): it goes
## into the Archive, in full, and the story moves on in you.

var page_id := ""

func _ready() -> void:
	add_to_group("interactables")
	var stand := (load("res://assets/props/BookStand.gltf") as PackedScene).instantiate() as Node3D
	stand.scale = Vector3.ONE * 1.4
	add_child(stand)
	var candle := (load("res://assets/dungeon/candle_triple.glb") as PackedScene).instantiate() as Node3D
	candle.position = Vector3(0.9, 0, 0.4)
	add_child(candle)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.5)
	l.light_energy = 1.6
	l.omni_range = 6.0
	l.position = Vector3(0, 1.6, 0.4)
	add_child(l)

func prompt_text() -> String:
	if page_id == "" or Run.has_clue(page_id):
		return ""
	return "Read the page"

func interact(_player: Node3D) -> void:
	if page_id == "" or not Story.PAGES.has(page_id):
		return
	var p: Array = Story.PAGES[page_id]
	Run.add_clue(page_id, str(p[0]), str(p[1]))
	Run.lean("curiosity", 1.5)
	Audio.play("heal", global_position, -4.0, 1.2)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null:
		hud.call("say", str(p[0]), str(p[1]))
