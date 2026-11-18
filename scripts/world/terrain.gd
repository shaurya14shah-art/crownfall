class_name Terrain
extends Node3D
## The island's ground: 256 chunks of 128 m, each built at four levels of
## detail (2, 4, 8 and 16 m between vertices) and swapped by distance, with
## a skirt hanging from every edge so neighbouring chunks at different
## detail never show a crack. One height-field collider covers the whole
## island. Mesh data is built on worker threads; only the GPU upload runs
## on the main thread.

const CHUNK_CELLS := 64                      ## cells per chunk side at full detail
const CHUNKS := Island.RES / CHUNK_CELLS     ## chunks per island side
const LOD_STRIDES := [1, 2, 4, 8]
const LOD_END := [210.0, 480.0, 1000.0, 4000.0]

var island: Island
var material: ShaderMaterial
var _jobs: Array = []

func build(isl: Island) -> void:
	island = isl
	material = _make_material()
	_jobs.resize(CHUNKS * CHUNKS)
	var task := WorkerThreadPool.add_group_task(_build_chunk_data, CHUNKS * CHUNKS, -1, true, "terrain chunks")
	WorkerThreadPool.wait_for_group_task_completion(task)
	for idx in _jobs.size():
		var job: Dictionary = _jobs[idx]
		var centre: Vector3 = job["centre"]
		for lod in LOD_STRIDES.size():
			var arrays: Array = job["lods"][lod]
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			mesh.surface_set_material(0, material)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.position = centre
			mi.visibility_range_begin = 0.0 if lod == 0 else float(LOD_END[lod - 1])
			mi.visibility_range_end = float(LOD_END[lod])
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if lod <= 1 \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
	_jobs.clear()
	_build_collider()

func _build_chunk_data(idx: int) -> void:
	var cx := idx % CHUNKS
	var cz := idx / CHUNKS
	var i0 := cx * CHUNK_CELLS
	var j0 := cz * CHUNK_CELLS
	var half := Island.SIZE * 0.5
	# The chunk's centre in the world; vertices are stored relative to it.
	var centre := Vector3(-half + (float(i0) + CHUNK_CELLS * 0.5) * Island.CELL, 0.0,
		-half + (float(j0) + CHUNK_CELLS * 0.5) * Island.CELL)
	var lods: Array = []
	for stride in LOD_STRIDES:
		lods.append(_chunk_arrays(i0, j0, int(stride), centre))
	_jobs[idx] = {"centre": centre, "lods": lods}

## Vertex i, j of the height field (clamped), as a world position.
func _grid_pos(i: int, j: int) -> Vector3:
	var ci := clampi(i, 0, Island.RES - 1)
	var cj := clampi(j, 0, Island.RES - 1)
	var half := Island.SIZE * 0.5
	return Vector3(-half + (float(i) + 0.5) * Island.CELL, island.heights[cj * Island.RES + ci],
		-half + (float(j) + 0.5) * Island.CELL)

func _grid_normal(i: int, j: int, stride: int) -> Vector3:
	var s := maxi(1, stride)
	var hl := island.heights[clampi(j, 0, Island.RES - 1) * Island.RES + clampi(i - s, 0, Island.RES - 1)]
	var hr := island.heights[clampi(j, 0, Island.RES - 1) * Island.RES + clampi(i + s, 0, Island.RES - 1)]
	var hd := island.heights[clampi(j - s, 0, Island.RES - 1) * Island.RES + clampi(i, 0, Island.RES - 1)]
	var hu := island.heights[clampi(j + s, 0, Island.RES - 1) * Island.RES + clampi(i, 0, Island.RES - 1)]
	return Vector3(hl - hr, 2.0 * float(s) * Island.CELL, hd - hu).normalized()

func _chunk_arrays(i0: int, j0: int, stride: int, centre: Vector3) -> Array:
	var n := CHUNK_CELLS / stride + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.resize(n * n)
	norms.resize(n * n)
	for b in n:
		for a in n:
			var gi := i0 + a * stride
			var gj := j0 + b * stride
			verts[b * n + a] = _grid_pos(gi, gj) - centre
			norms[b * n + a] = _grid_normal(gi, gj, stride)
	for b in n - 1:
		for a in n - 1:
			var v0 := b * n + a
			var v1 := v0 + 1
			var v2 := v0 + n
			var v3 := v2 + 1
			idx.append_array([v0, v1, v2, v1, v3, v2])
	# Skirts: each edge copied a few metres down and stitched to the edge.
	var drop := 2.5 * float(stride) + 1.5
	var edges := [[], [], [], []]
	for k in n:
		edges[0].append(k)                    # north row
		edges[1].append((n - 1) * n + k)      # south row
		edges[2].append(k * n)                # west column
		edges[3].append(k * n + n - 1)        # east column
	for e in 4:
		var start := verts.size()
		for k in n:
			var v: int = edges[e][k]
			verts.append(verts[v] - Vector3(0, drop, 0))
			norms.append(norms[v])
		for k in n - 1:
			var a0: int = edges[e][k]
			var a1: int = edges[e][k + 1]
			var b0 := start + k
			var b1 := start + k + 1
			# Both windings, so the skirt shows from either side.
			idx.append_array([a0, b0, a1, a1, b0, b1, a0, a1, b0, a1, b1, b0])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	return arrays

func _build_collider() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	var shape := HeightMapShape3D.new()
	shape.map_width = Island.RES
	shape.map_depth = Island.RES
	shape.map_data = island.heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(Island.CELL, 1.0, Island.CELL)
	body.add_child(cs)
	add_child(body)

func _make_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/terrain.gdshader")
	var tex := ImageTexture.create_from_image(island.paint)
	m.set_shader_parameter("paint_map", tex)
	m.set_shader_parameter("island_size", Island.SIZE)
	m.set_shader_parameter("rock_tex", load("res://assets/nature/Rocks_Diffuse.png"))
	m.set_shader_parameter("path_tex", load("res://assets/nature/PathRocks_Diffuse.png"))
	m.set_shader_parameter("noise_tex", noise_texture(512, 0.012, 4, 11))
	m.set_shader_parameter("detail_tex", noise_texture(256, 0.06, 3, 23))
	return m

## A seamless tiling noise image, generated synchronously (a NoiseTexture2D
## builds on a thread and samples white until it finishes).
static func noise_texture(size: int, freq: float, octaves: int, s: int) -> ImageTexture:
	var n := FastNoiseLite.new()
	n.seed = s
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	var img := n.get_seamless_image(size, size, false, false, 0.1, true)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
