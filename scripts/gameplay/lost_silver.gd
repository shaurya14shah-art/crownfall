class_name LostSilver
extends Node3D
## The silver you carried when you fell, lying where you fell under a pale
## gold column you can see from a long way off. Walk into it to take it
## back. Fall again first, and it is gone for good.

var amount := 0
var _t := 0.0
var _player: Node3D

static func place(parent: Node, at: Vector3, n: int) -> LostSilver:
	for old in parent.get_tree().get_nodes_in_group("lost_silver"):
		old.queue_free()
	var l := LostSilver.new()
	l.amount = n
	parent.add_child(l)
	l.global_position = at
	return l

func _ready() -> void:
	add_to_group("lost_silver")
	var beam := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.05
	bm.bottom_radius = 0.45
	bm.height = 9.0
	bm.cap_top = false
	bm.cap_bottom = false
	beam.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.85, 1.0, 0.6, 0.28)
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position.y = 4.5
	add_child(beam)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	core.mesh = sm
	var cmat := StandardMaterial3D.new()
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cmat.albedo_color = Color(0.9, 1.0, 0.7)
	core.material_override = cmat
	core.position.y = 0.6
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.8, 1.0, 0.6)
	glow.light_energy = 1.2
	glow.omni_range = 5.0
	glow.position.y = 0.8
	add_child(glow)

func _process(delta: float) -> void:
	_t += delta
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	if _t > 1.0 and _player.global_position.distance_to(global_position) < 1.8:
		Run.add_silver(amount, true)
		Run.lost = {}
		Run.toast.emit("Recovered %d silver" % amount, "silver")
		Audio.play("coin", global_position, 2.0, 0.9)
		Fx.sparks(get_parent(), global_position + Vector3.UP, Color(0.85, 1.0, 0.6), 30)
		queue_free()
