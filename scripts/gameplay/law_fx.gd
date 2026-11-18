class_name LawRing
extends Node3D
## A ring on the ground in a principle's colour: as a burst it races outward
## and fades; as a barrier (The Drawn Line) it holds for a while and shoves
## back any foe that tries to cross it.

var colour := Color.WHITE
var radius := 5.0
var life := 5.0
var expanding := false
var _t := 0.0
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D

func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	_mesh.mesh = torus
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.albedo_color = colour
	_mat.no_depth_test = false
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.scale = Vector3(radius, 1.0, radius)
	_mesh.position.y = 0.15
	add_child(_mesh)
	if not expanding:
		var light := OmniLight3D.new()
		light.light_color = colour
		light.light_energy = 1.5
		light.omni_range = radius + 2.0
		light.position.y = 1.0
		add_child(light)

func _process(delta: float) -> void:
	_t += delta
	var k := _t / life
	if expanding:
		var r := lerpf(0.5, radius * 2.2, ease(k, 0.4))
		_mesh.scale = Vector3(r, 1.0, r)
		_mat.albedo_color = Color(colour, 1.0 - k)
	else:
		_mat.albedo_color = Color(colour, (0.6 + 0.3 * sin(_t * 6.0)) * (1.0 - smoothstep(0.85, 1.0, k)))
		_mesh.rotation.y += delta * 0.6
		for e in get_tree().get_nodes_in_group("enemies"):
			var n := e as Node3D
			var to := (n.global_position - global_position) * Vector3(1, 0, 1)
			if to.length() < radius + 0.6 and n.has_method("knock"):
				n.call("knock", to.normalized() * 9.0)
	if k >= 1.0:
		queue_free()
