class_name GateExit
extends Node3D
## The way out of a Gate, opened where its keeper fell: a small bright rift.

var run: GateRun
var _disc: MeshInstance3D

func _ready() -> void:
	add_to_group("interactables")
	_disc = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.6, 3.8)
	_disc.mesh = quad
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = GatePortal.SHADER
	m.shader = sh
	m.set_shader_parameter("colour", Color(1.0, 0.9, 0.6))
	m.set_shader_parameter("open", 1.0)
	_disc.material_override = m
	_disc.position = Vector3(0, 2.0, 0)
	add_child(_disc)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.9, 0.6)
	l.light_energy = 3.0
	l.omni_range = 10.0
	l.position = Vector3(0, 2.0, 0.5)
	add_child(l)

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var to := cam.global_position - global_position
		_disc.rotation.y = atan2(to.x, to.z)

func prompt_text() -> String:
	return "Leave the Gate"

func interact(_player: Node3D) -> void:
	run.leave(true)
