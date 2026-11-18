class_name Foliage
extends Node3D
## Trees, bushes and rocks over the whole island, from the Stylized Nature
## kit. Placed once from the island's paint map (forests where the map says
## forest, a scattering in the meadows, pines up the mountain, dead trees
## around the barrow) and drawn as one batch per species per 160 m region,
## so a region out of sight costs nothing and a forest is a few draw calls.

const REGION := 128.0
const KIT := "res://assets/nature/"

## species -> models, spacing jitter, scale range, wind strength
const SPECIES := {
	"common": {"models": ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5"],
		"scale": [1.3, 2.0], "wind": 0.30},
	"pine": {"models": ["Pine_1", "Pine_2", "Pine_3", "Pine_4", "Pine_5"], "scale": [1.3, 2.2], "wind": 0.20},
	"twisted": {"models": ["TwistedTree_1", "TwistedTree_3", "TwistedTree_5"], "scale": [0.8, 1.05], "wind": 0.15},
	"dead": {"models": ["DeadTree_1", "DeadTree_2", "DeadTree_3"], "scale": [0.7, 1.0], "wind": 0.0},
	"bush": {"models": ["Bush_Common", "Bush_Common_Flowers"], "scale": [0.9, 1.6], "wind": 0.18},
	"rock": {"models": ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"], "scale": [0.6, 2.4], "wind": 0.0},
	"fern": {"models": ["Fern_1", "Plant_1_Big", "Plant_1"], "scale": [0.8, 1.4], "wind": 0.25},
}

var island: Island
var _meshes := {}            ## model name -> Mesh with wind materials
var _rng := RandomNumberGenerator.new()
var trunks: Array[Vector3] = []   ## tree positions, for colliders and clearance
var _casters: Array = []          ## [model, Transform3D] of every tree and bush
var _shadow_root: Node3D
var _shadow_at := Vector3(INF, 0, INF)
const SHADOW_RADIUS := 75.0

## Near a tree you see the model, swaying; past ~140 m you see its picture
## on a card (Impostors). Bushes and ferns stop at a third of the distance;
## rocks are cheap and stay models.
const MESH_RANGE := 150.0
const CARD_FROM := 130.0

var _cards := {}             ## model -> [texture, size]

func build(isl: Island, draw_distance: float) -> void:
	island = isl
	_rng.seed = isl.seed_value + 501
	var placed := {}         # "model|rx|rz" -> Array[Transform3D]
	_scatter_trees(placed)
	_scatter_small(placed)
	var batches := 0
	for key in placed.keys():
		var parts := str(key).split("|")
		var model := parts[0]
		var mesh := _mesh(model)
		if mesh == null:
			continue
		var xfs: Array = placed[key]
		var small := model.begins_with("Fern") or model.begins_with("Plant") or model.begins_with("Bush")
		var rock := model.begins_with("Rock")
		var tree := not small and not rock
		var mmi := _batch(mesh, xfs)
		mmi.lod_bias = 0.35
		# The forest itself casts no shadow: a region-sized batch drew all its
		# trees into every shadow split. Shadow-only copies of the trees near
		# the camera stand in (see _process).
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if small:
			mmi.visibility_range_end = draw_distance * 0.35
		elif rock:
			mmi.visibility_range_end = draw_distance * 0.7
		else:
			mmi.visibility_range_end = MESH_RANGE
		if not small:
			for xf in xfs:
				_casters.append([model, xf])
		add_child(mmi)
		batches += 1
		if tree:
			if not _cards.has(model):
				_cards[model] = await Impostors.bake(self, mesh)
			var card := Impostors.card(_cards[model][1], _cards[model][0])
			var far := _batch(card, xfs)
			far.visibility_range_begin = CARD_FROM
			far.visibility_range_end = draw_distance
			far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(far)
			batches += 1
	_build_trunk_colliders()
	print("[Foliage] %d trees, %d batches" % [trunks.size(), batches])

func _batch(mesh: Mesh, xfs: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for k in xfs.size():
		mm.set_instance_transform(k, xfs[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	return mmi

func _ok_ground(x: float, z: float, max_slope: float) -> bool:
	var h := island.height_at(x, z)
	if h < 2.2:
		return false
	if 1.0 - island.normal_at(x, z).y > max_slope:
		return false
	var p := island.paint_at(x, z)
	if p.y > 0.08 or p.x > 0.3:
		return false
	for id in Island.SITES.keys():
		var s: Dictionary = Island.SITES[id]
		if Vector2(x, z).distance_to(s["pos"]) < float(s["radius"]) * 1.15:
			return false
	return true

func _put(placed: Dictionary, model: String, x: float, z: float, scale: float, sink: float = 0.15) -> void:
	var y := island.height_at(x, z) - sink * scale
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * scale)
	var key := "%s|%d|%d" % [model, int(floor(x / REGION)), int(floor(z / REGION))]
	if not placed.has(key):
		placed[key] = []
	(placed[key] as Array).append(Transform3D(basis, Vector3(x, y, z)))

func _pick(species: String) -> String:
	var list: Array = SPECIES[species]["models"]
	return str(list[_rng.randi() % list.size()])

func _scale(species: String) -> float:
	var r: Array = SPECIES[species]["scale"]
	return _rng.randf_range(float(r[0]), float(r[1]))

func _scatter_trees(placed: Dictionary) -> void:
	var step := 7.0
	var half := Island.SIZE * 0.5
	var barrow: Vector2 = Island.SITES["barrow"]["pos"]
	var z := -half
	while z < half:
		var x := -half
		while x < half:
			var px := x + _rng.randf_range(-step * 0.45, step * 0.45)
			var pz := z + _rng.randf_range(-step * 0.45, step * 0.45)
			x += step
			if not _ok_ground(px, pz, 0.42):
				continue
			var paint := island.paint_at(px, pz)
			var h := island.height_at(px, pz)
			var near_barrow := Vector2(px, pz).distance_to(barrow) < 150.0
			var chance := paint.z * 0.95 + 0.02
			if near_barrow:
				chance = 0.25
			if _rng.randf() > chance:
				continue
			var species := "common"
			if near_barrow and _rng.randf() < 0.7:
				species = "dead"
			elif h > 55.0 or (paint.z > 0.6 and _rng.randf() < 0.35):
				species = "pine"
			elif paint.z < 0.2 and _rng.randf() < 0.08:
				species = "twisted"
			var s := _scale(species)
			_put(placed, _pick(species), px, pz, s)
			if species != "dead":
				trunks.append(Vector3(px, island.height_at(px, pz), pz))
		z += step

func _scatter_small(placed: Dictionary) -> void:
	var step := 9.0
	var half := Island.SIZE * 0.5
	var z := -half
	while z < half:
		var x := -half
		while x < half:
			var px := x + _rng.randf_range(-step * 0.5, step * 0.5)
			var pz := z + _rng.randf_range(-step * 0.5, step * 0.5)
			x += step
			var h := island.height_at(px, pz)
			if h < 1.5:
				continue
			var slope := 1.0 - island.normal_at(px, pz).y
			var paint := island.paint_at(px, pz)
			# Rocks: on slopes, on the mountain, and the odd boulder anywhere.
			var rock_chance := 0.012 + smoothstep(0.2, 0.5, slope) * 0.18 + smoothstep(80.0, 160.0, h) * 0.06
			if paint.y < 0.05 and _rng.randf() < rock_chance and _ok_rock(px, pz):
				_put(placed, _pick("rock"), px, pz, _scale("rock"), 0.3)
				continue
			if not _ok_ground(px, pz, 0.35):
				continue
			if _rng.randf() < 0.05 + paint.z * 0.12:
				_put(placed, _pick("bush"), px, pz, _scale("bush"), 0.1)
			elif paint.z > 0.4 and _rng.randf() < 0.25:
				_put(placed, _pick("fern"), px, pz, _scale("fern"), 0.05)
		z += step

func _ok_rock(x: float, z: float) -> bool:
	for id in ["village", "harbour", "castle"]:
		var s: Dictionary = Island.SITES[id]
		if Vector2(x, z).distance_to(s["pos"]) < float(s["radius"]) * 1.2:
			return false
	return true

## The model's mesh, with leaf materials swapped for the wind shader.
func _mesh(model: String) -> Mesh:
	if _meshes.has(model):
		return _meshes[model]
	var ps := load(KIT + model + ".gltf") as PackedScene
	if ps == null:
		return null
	var root := ps.instantiate()
	var mi: MeshInstance3D = null
	for n in root.find_children("*", "MeshInstance3D", true, false):
		mi = n as MeshInstance3D
		break
	if mi == null:
		root.free()
		return null
	var src: Mesh = mi.mesh
	var mesh := src.duplicate() as Mesh
	var species_wind := 0.25
	for sp in SPECIES.keys():
		for m in SPECIES[sp]["models"]:
			if m == model:
				species_wind = float(SPECIES[sp]["wind"])
	for s in mesh.get_surface_count():
		var mat := mi.get_active_material(s)
		if mat is BaseMaterial3D:
			var bm := mat as BaseMaterial3D
			if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and bm.albedo_texture != null:
				var sm := ShaderMaterial.new()
				sm.shader = load("res://shaders/foliage.gdshader")
				sm.set_shader_parameter("albedo_tex", bm.albedo_texture)
				sm.set_shader_parameter("wind", species_wind)
				sm.set_shader_parameter("sway_height", maxf(src.get_aabb().size.y, 1.0))
				sm.set_shader_parameter("tint", Color(1.0, 1.0, 1.0))
				mesh.surface_set_material(s, sm)
			else:
				var copy := bm.duplicate() as BaseMaterial3D
				copy.roughness = maxf(copy.roughness, 0.8)
				mesh.surface_set_material(s, copy)
	root.free()
	_meshes[model] = mesh
	return mesh

## Shadow-only copies of the trees within SHADOW_RADIUS of the camera,
## rebuilt every 20 m of travel.
func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _casters.is_empty():
		return
	var p := cam.global_position
	if Vector2(p.x, p.z).distance_to(Vector2(_shadow_at.x, _shadow_at.z)) < 20.0:
		return
	_shadow_at = p
	if _shadow_root != null:
		_shadow_root.queue_free()
	_shadow_root = Node3D.new()
	add_child(_shadow_root)
	var by_model := {}
	var r2 := SHADOW_RADIUS * SHADOW_RADIUS
	for c in _casters:
		var xf: Transform3D = c[1]
		var dx := xf.origin.x - p.x
		var dz := xf.origin.z - p.z
		if dx * dx + dz * dz > r2:
			continue
		if not by_model.has(c[0]):
			by_model[c[0]] = []
		(by_model[c[0]] as Array).append(xf)
	for model in by_model.keys():
		var xfs: Array = by_model[model]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _meshes[model]
		mm.instance_count = xfs.size()
		for k in xfs.size():
			mm.set_instance_transform(k, xfs[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		_shadow_root.add_child(mmi)

## Trunks you cannot walk through: one static body of cylinders.
func _build_trunk_colliders() -> void:
	var body := StaticBody3D.new()
	body.name = "Trunks"
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 6.0
	for p in trunks:
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = p + Vector3(0, 3.0, 0)
		body.add_child(cs)
	add_child(body)
