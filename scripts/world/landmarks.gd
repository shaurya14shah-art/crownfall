class_name Landmarks
extends Node3D
## The island's set pieces, assembled from the kits: Highmoor Keep on its
## plateau (curtain walls, four corner towers, a tall keep with a tiled
## spire), the broken ring of the Barrow of Ash with its torches, and the
## old tower on Gull's Watch. Each is merged into a few meshes.

const KIT := "res://assets/village/"
const PROPS := "res://assets/props/"

var island: Island
var _scenes := {}
var _rng := RandomNumberGenerator.new()

func build(isl: Island) -> void:
	island = isl
	_rng.seed = isl.seed_value + 303
	_keep(isl.site_pos("castle"))
	_barrow(isl.site_pos("barrow"))
	_watch(isl.site_pos("tower"))

func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]

func _add(parent: Node3D, piece: String, at: Vector3, rot: float, dir: String = KIT, tilt: Vector3 = Vector3.ZERO) -> Node3D:
	var ps := _scene(dir + piece + (".glb" if dir.ends_with("ships/") else ".gltf"))
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	n.position = at
	n.rotation = Vector3(tilt.x, rot, tilt.z)
	parent.add_child(n)
	return n

func _finish(parts: Node3D, at: Vector3, solid: Array = []) -> void:
	var merged := Village._merge(parts)
	parts.free()
	merged.position = at
	add_child(merged)
	if not solid.is_empty():
		var body := StaticBody3D.new()
		body.collision_layer = 2
		body.position = at
		for box in solid:
			var cs := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = box[1]
			cs.shape = shape
			cs.position = box[0]
			cs.rotation.y = float(box[2]) if box.size() > 2 else 0.0
			body.add_child(cs)
		add_child(body)

## A square tower of `storeys`, `w` metres a side, with a pointed roof.
func _tower(parts: Node3D, c: Vector3, w: int, storeys: int) -> void:
	var n := w / 2
	for f in storeys:
		var y := float(f) * 3.0
		for i in n:
			var x := -float(w) * 0.5 + 1.0 + 2.0 * i
			var piece := "Wall_UnevenBrick_Window_Thin_Round" if (f > 0 and i == n / 2) else "Wall_UnevenBrick_Straight"
			_add(parts, piece, c + Vector3(x, y, float(w) * 0.5), 0.0)
			_add(parts, piece, c + Vector3(x, y, -float(w) * 0.5), PI)
			_add(parts, piece, c + Vector3(-float(w) * 0.5, y, x), -PI * 0.5)
			_add(parts, piece, c + Vector3(float(w) * 0.5, y, x), PI * 0.5)
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				_add(parts, "Corner_Exterior_Brick", c + Vector3(cx * float(w) * 0.5, y, cz * float(w) * 0.5),
					atan2(cx, cz) - PI * 0.25)
	_add(parts, "Roof_Tower_RoundTiles", c + Vector3(0, float(storeys) * 3.0, 0), 0.0)

func _keep(c: Vector3) -> void:
	var parts := Node3D.new()
	var half := 22.0
	var solid := []
	# Curtain walls between four corner towers, a gate arch on the east side.
	for side in 4:
		var rot := float(side) * PI * 0.5
		var out := Vector3(sin(rot), 0, cos(rot))
		var along := Vector3(cos(rot), 0, -sin(rot))
		for k in 18:
			var t := -half + 3.0 + 2.0 * float(k)
			if t > half - 3.0:
				break
			var p := out * half + along * t
			var gate := side == 1 and absf(t) < 2.0
			for f in 2:
				var piece := "Wall_UnevenBrick_Straight"
				if gate and f == 0:
					piece = "Wall_UnevenBrick_Door_Round"
				_add(parts, piece, p + Vector3(0, float(f) * 3.0, 0), rot)
		solid.append([out * half + Vector3(0, 3, 0), Vector3(2.0 * half, 6.0, 1.2) if side % 2 == 0 else
			Vector3(1.2, 6.0, 2.0 * half), 0.0])
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			_tower(parts, Vector3(cx * half, 0, cz * half), 6, 4)
			solid.append([Vector3(cx * half, 6, cz * half), Vector3(6.5, 12, 6.5)])
	# The keep itself.
	_tower(parts, Vector3(0, 0, -4), 10, 6)
	solid.append([Vector3(0, 9, -4), Vector3(10.5, 18, 10.5)])
	# Banners and braziers in the yard.
	for k in 4:
		var a := TAU * float(k) / 4.0 + PI * 0.25
		_add(parts, "Torch_Metal", Vector3(sin(a), 0, cos(a)) * 12.0, 0.0, PROPS)
	_add(parts, "Banner_1", Vector3(-6, 0, 8), 0.0, PROPS)
	_add(parts, "Banner_2", Vector3(6, 0, 8), 0.0, PROPS)
	_add(parts, "WeaponStand", Vector3(10, 0, 4), 0.5, PROPS)
	# A plinth of rock trim under the whole castle so it sits on the hill.
	var plinth := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.0 * half + 8.0, 4.0, 2.0 * half + 8.0)
	plinth.mesh = bm
	plinth.position = Vector3(0, -2.0, 0)
	var stone := StandardMaterial3D.new()
	stone.resource_name = "keep_plinth"
	stone.albedo_texture = load(KIT + "T_RockTrim_BaseColor.png")
	stone.uv1_triplanar = true
	stone.uv1_scale = Vector3(0.35, 0.35, 0.35)
	stone.roughness = 0.9
	plinth.material_override = stone
	parts.add_child(plinth)
	_finish(parts, c + Vector3(0, 0.1, 0), solid)

func _barrow(c: Vector3) -> void:
	var parts := Node3D.new()
	# A broken ring of old walls, leaning, some fallen.
	for k in 14:
		var a := TAU * float(k) / 14.0 + _rng.randf_range(-0.05, 0.05)
		if _rng.randf() < 0.25:
			continue
		var r := 16.0 + _rng.randf_range(-1.0, 1.0)
		var p := Vector3(sin(a), 0, cos(a)) * r
		p.y = island.height_at(c.x + p.x, c.z + p.z) - c.y - 0.3
		var lean := Vector3(_rng.randf_range(-0.12, 0.12), 0, _rng.randf_range(-0.1, 0.1))
		var piece := "Wall_Arch" if k % 5 == 0 else "Wall_UnevenBrick_Straight"
		_add(parts, piece, p, a + PI, KIT, lean)
	# Rubble and grave goods in the middle.
	for k in 10:
		var p := Vector3(_rng.randf_range(-9, 9), 0, _rng.randf_range(-9, 9))
		p.y = island.height_at(c.x + p.x, c.z + p.z) - c.y
		_add(parts, ["Vase_Rubble_Medium", "Prop_Brick1", "Prop_Brick2", "Prop_Brick3", "Vase_2", "Cage_Small"][k % 6],
			p, _rng.randf() * TAU, PROPS if k % 6 in [0, 4, 5] else KIT)
	_add(parts, "Chest_Wood", Vector3(0, island.height_at(c.x, c.z) - c.y, 0), 0.6, PROPS)
	_finish(parts, c)
	# Torches that burn without anyone to tend them.
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.4
		var p := c + Vector3(sin(a), 0, cos(a)) * 11.0
		p.y = island.height_at(p.x, p.z)
		var torch := _add(self, "Torch_Metal", p, 0.0, PROPS)
		var fire := OmniLight3D.new()
		fire.light_color = Color(1.0, 0.55, 0.25)
		fire.light_energy = 2.5
		fire.omni_range = 10.0
		fire.position = Vector3(0, 2.3, 0)
		torch.add_child(fire)
		var flame := _flame()
		flame.position = Vector3(0, 2.2, 0)
		torch.add_child(flame)

## A small flickering flame of additive particles.
static func _flame() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 18
	p.lifetime = 0.6
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.2
	p.gravity = Vector3(0, 1.2, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.55, 0.2)
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.mesh = quad
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	g.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	p.color_ramp = g
	return p

func _watch(c: Vector3) -> void:
	var parts := Node3D.new()
	_tower(parts, Vector3.ZERO, 6, 5)
	_finish(parts, c + Vector3(0, 0.1, 0), [[Vector3(0, 7.5, 0), Vector3(6.5, 15, 6.5)]])
