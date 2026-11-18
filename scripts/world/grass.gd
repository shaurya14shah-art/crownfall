class_name Grass
extends Node3D
## A field of grass around whoever is watching: 12 m cells of blade clumps
## within `radius`, built a few per frame as you move and dropped behind
## you. Where the ground is sand, road, rock or forest floor, there is less
## or none.

const CELL := 12.0
const PER_CELL := 600
const BUILD_PER_FRAME := 3

var island: Island
var radius := 55.0
var material: ShaderMaterial
var _mesh: ArrayMesh
var _cells := {}             ## Vector2i -> MultiMeshInstance3D
var _rng := RandomNumberGenerator.new()

func setup(isl: Island, terrain_mat: ShaderMaterial, r: float) -> void:
	island = isl
	radius = r
	_mesh = _clump_mesh()
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/grass.gdshader")
	material.set_shader_parameter("paint_map", terrain_mat.get_shader_parameter("paint_map"))
	material.set_shader_parameter("noise_tex", terrain_mat.get_shader_parameter("noise_tex"))
	material.set_shader_parameter("radius", radius)
	_mesh.surface_set_material(0, material)

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or island == null:
		return
	var p := cam.global_position
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		material.set_shader_parameter("player_pos", player.global_position)
		p = player.global_position
	var centre := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
	var reach := int(ceil(radius / CELL))
	# Drop what is out of reach.
	for key in _cells.keys():
		var k: Vector2i = key
		if absi(k.x - centre.x) > reach + 1 or absi(k.y - centre.y) > reach + 1:
			(_cells[key] as Node).queue_free()
			_cells.erase(key)
	# Build what is missing, nearest first.
	var wanted: Array[Vector2i] = []
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var k := centre + Vector2i(dx, dz)
			if _cells.has(k):
				continue
			if Vector2(dx, dz).length() * CELL > radius + CELL:
				continue
			wanted.append(k)
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - centre).length_squared() < (b - centre).length_squared())
	for i in mini(BUILD_PER_FRAME, wanted.size()):
		_build_cell(wanted[i])

## Builds every cell around a point at once (for loading and screenshots).
func warm(at: Vector3) -> void:
	var centre := Vector2i(floori(at.x / CELL), floori(at.z / CELL))
	var reach := int(ceil(radius / CELL))
	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var k := centre + Vector2i(dx, dz)
			if not _cells.has(k) and Vector2(dx, dz).length() * CELL <= radius + CELL:
				_build_cell(k)

func _build_cell(k: Vector2i) -> void:
	_rng.seed = hash(k)
	var xfs: Array[Transform3D] = []
	for i in PER_CELL:
		var x := (float(k.x) + _rng.randf()) * CELL
		var z := (float(k.y) + _rng.randf()) * CELL
		var h := island.height_at(x, z)
		if h < 1.4:
			continue
		var n := island.normal_at(x, z)
		if n.y < 0.8:
			continue
		var paint := island.paint_at(x, z)
		var density := 1.0 - paint.y * 1.4 - paint.x * 1.6 - paint.z * 0.55
		if _rng.randf() > density:
			continue
		var s := _rng.randf_range(0.7, 1.1) * (1.0 + paint.w * 0.3)
		var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.8, 1.25), s))
		xfs.append(Transform3D(basis, Vector3(x, h - 0.05, z)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_cells[k] = mmi

## Nine curved, tapering blades leaning out from a common root.
func _clump_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for b in 8:
		var a := rng.randf() * TAU
		var out := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-out.z, 0, out.x)
		var root := out * rng.randf_range(0.0, 0.14)
		var tall := rng.randf_range(0.14, 0.34)
		var lean := rng.randf_range(0.06, 0.2)
		var w := rng.randf_range(0.05, 0.08)
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for seg in 3:
			var t := float(seg) / 2.0
			var c := root + out * lean * t * t + Vector3(0, tall * t, 0)
			var half := w * (1.0 - t * 0.92)
			var l := c - side * half
			var r := c + side * half
			if seg > 0:
				for v in [prev_l, prev_r, l, prev_r, r, l]:
					st.set_normal(Vector3(0, 1, 0).lerp(out, 0.25).normalized())
					st.add_vertex(v)
			prev_l = l
			prev_r = r
	return st.commit()
