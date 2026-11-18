class_name Ocean
extends MeshInstance3D
## The sea around the island: a radial mesh centred under the camera, a
## vertex every half metre close in and every hundred far out, so waves are
## detailed where you can see them and the horizon costs nothing.

const RINGS := 130
const SEGMENTS := 192
const FIRST := 0.5
const GROWTH := 1.072

func _ready() -> void:
	mesh = _radial_mesh()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ocean.gdshader")
	m.set_shader_parameter("foam_noise", Terrain.noise_texture(256, 0.04, 3, 41))
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var p := cam.global_position
		global_position = Vector3(snappedf(p.x, 1.0), 0.0, snappedf(p.z, 1.0))

static func _radial_mesh() -> ArrayMesh:
	var verts := PackedVector3Array([Vector3.ZERO])
	var idx := PackedInt32Array()
	var r := FIRST
	for ring in RINGS:
		for s in SEGMENTS:
			var a := TAU * float(s) / float(SEGMENTS)
			verts.append(Vector3(cos(a) * r, 0.0, sin(a) * r))
		r *= GROWTH
	for s in SEGMENTS:
		idx.append_array([0, 1 + (s + 1) % SEGMENTS, 1 + s])
	for ring in RINGS - 1:
		var a0 := 1 + ring * SEGMENTS
		var b0 := a0 + SEGMENTS
		for s in SEGMENTS:
			var s1 := (s + 1) % SEGMENTS
			idx.append_array([a0 + s, a0 + s1, b0 + s, a0 + s1, b0 + s1, b0 + s])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var norms := PackedVector3Array()
	norms.resize(verts.size())
	norms.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
