class_name Bell
extends Node3D
## The bell in Highmoor's yard. The fishermen say it rang on its own the
## night the keep emptied. Ring it at night and something answers.

var _swing := 0.0
var _model: Node3D

func _ready() -> void:
	add_to_group("interactables")
	var frame := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.4, 0.25, 0.25)
	frame.mesh = bm
	frame.position = Vector3(0, 3.0, 0)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.35, 0.22, 0.12)
	frame.material_override = wood
	add_child(frame)
	for x in [-1.1, 1.1]:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.22, 3.0, 0.22)
		post.mesh = pm
		post.position = Vector3(x, 1.5, 0)
		post.material_override = wood
		add_child(post)
	_model = Node3D.new()
	_model.position = Vector3(0, 2.9, 0)
	add_child(_model)
	var bell := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.28
	cm.bottom_radius = 0.6
	cm.height = 0.9
	bell.mesh = cm
	bell.position = Vector3(0, -0.5, 0)
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.72, 0.52, 0.25)
	bronze.metallic = 0.85
	bronze.roughness = 0.35
	bell.material_override = bronze
	_model.add_child(bell)

func prompt_text() -> String:
	return "Ring the bell"

func interact(player: Node3D) -> void:
	_swing = 1.0
	Audio.play("block", global_position, 6.0, 0.45)
	var sky := get_tree().get_first_node_in_group("sky") as SkyRig
	if sky != null and sky.is_night() and not Run.flags.has("bell_answered"):
		Run.flags["bell_answered"] = true
		Run.add_clue("bell_night", "The Bell Answered",
			"I rang Highmoor's bell after dark. Something rang back from under the keep, and the clapper came loose in my hand.")
		Run.add_item("bell_clapper", 1)
		Run.lean("curiosity", 2.0)
	elif not Run.has_clue("bell_day"):
		Run.add_clue("bell_day", "Highmoor's Bell",
			"A bell hangs in the keep's yard. In daylight it rings like any bell. The fishermen say it was the night it rang.")

func _process(delta: float) -> void:
	_swing = move_toward(_swing, 0.0, delta * 0.4)
	_model.rotation.x = sin(Time.get_ticks_msec() * 0.006) * 0.5 * _swing
