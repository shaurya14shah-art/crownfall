class_name Village
extends Node3D
## Brightwater: half-timbered houses assembled from the Medieval Village kit
## (2 m wall modules, 3 m storeys, tiled gable roofs), set in two rings
## round a market square, with stalls, barrels, crates, lamps and a well of
## life in between. Each house is merged into one mesh per material, so a
## whole street is a few dozen draw calls rather than thousands.

const KIT := "res://assets/village/"
const PROPS := "res://assets/props/"
const STOREY := 3.0
## Roof sizes the kit has, by width (m) -> depths (m).
const ROOFS := {4: [4, 6, 8], 6: [4, 6, 8, 10, 12], 8: [8, 10, 12]}

var island: Island
var centre := Vector3.ZERO
var houses: Array[Dictionary] = []     ## {pos, rot, w, d, floors}
var _scenes := {}
var _rng := RandomNumberGenerator.new()

func build(isl: Island) -> void:
	island = isl
	_rng.seed = isl.seed_value + 77
	centre = isl.site_pos("village")
	var road_dirs: Array[float] = []
	for other in ["harbour", "crossroads", "tower"]:
		var p := isl.site_pos(other)
		road_dirs.append(atan2(p.x - centre.x, p.z - centre.z))
	_ring(22.0, 7, road_dirs, 1)
	_ring(42.0, 11, road_dirs, 2)
	_ring(62.0, 12, road_dirs, 2)
	_square()
	_lanes()
	print("[Village] %d houses" % houses.size())

## Cobbled lanes from each front door to the square, and the square itself.
func _lanes() -> void:
	var c := Vector2(centre.x, centre.z)
	for k in 24:
		var a := TAU * float(k) / 24.0
		island.paint_road(c, c + Vector2(sin(a), cos(a)) * 15.0, 4.0)
	for h in houses:
		var p: Vector3 = h["pos"]
		var rot: float = h["rot"]
		var front := Vector3(sin(rot), 0, cos(rot))
		var door := p + front * (float(h["d"]) * 0.5 + 0.6)
		island.paint_road(Vector2(door.x, door.z), c.lerp(Vector2(door.x, door.z), 0.45), 2.6)

func _ring(radius: float, count: int, road_dirs: Array[float], max_floors: int) -> void:
	var offset := _rng.randf() * TAU
	for k in count:
		var a := offset + TAU * float(k) / float(count) + _rng.randf_range(-0.1, 0.1)
		var blocked := false
		for rd in road_dirs:
			if absf(angle_difference(a, rd)) < 0.26 + 6.0 / radius:
				blocked = true
		if blocked:
			continue
		var w := [4, 6, 6, 8][_rng.randi() % 4] as int
		var depths: Array = ROOFS[w]
		var d: int = depths[_rng.randi() % depths.size()]
		var r := radius + _rng.randf_range(-2.0, 2.0)
		var pos := centre + Vector3(sin(a), 0.0, cos(a)) * r
		pos.y = island.height_at(pos.x, pos.z)
		# Facing the square.
		var rot := a + PI
		var floors := 1 + int(_rng.randf() < 0.6) if max_floors >= 2 else 1
		build_house(pos, rot, w, d, floors)

## One house: footprint w x d metres (multiples of 2), `floors` storeys.
func build_house(pos: Vector3, rot: float, w: int, d: int, floors: int) -> void:
	var house := Node3D.new()
	var parts := Node3D.new()
	var nx := w / 2
	var nz := d / 2
	var brick := _rng.randf() < 0.5
	var ground_wall := "Wall_UnevenBrick_Straight" if brick else "Wall_Plaster_Straight_Base"
	var ground_window := "Wall_UnevenBrick_Window_Wide_Round" if brick else "Wall_Plaster_Window_Wide_Round"
	var ground_door := "Wall_UnevenBrick_Door_Round" if brick else "Wall_Plaster_Door_Round"
	var upper_walls := ["Wall_Plaster_WoodGrid", "Wall_Plaster_Window_Wide_Flat", "Wall_Plaster_Straight",
		"Wall_Plaster_Window_Thin_Round"]
	var door_at := nx / 2
	for f in floors:
		var y := float(f) * STOREY
		# Front (+z) and back (-z) walls, then the sides.
		for i in nx:
			var x := -float(w) * 0.5 + 1.0 + 2.0 * float(i)
			var front := ground_door if (f == 0 and i == door_at) else \
				(ground_window if f == 0 and i % 2 == 1 else (ground_wall if f == 0 else _any(upper_walls)))
			_add(parts, front, Vector3(x, y, float(d) * 0.5), 0.0)
			var back := ground_wall if f == 0 else _any(upper_walls)
			_add(parts, back, Vector3(x, y, -float(d) * 0.5), PI)
			if f == 0 and i == door_at:
				_add(parts, "Door_1_Round", Vector3(x, y, float(d) * 0.5), 0.0)
		for j in nz:
			var z := -float(d) * 0.5 + 1.0 + 2.0 * float(j)
			var side := (ground_window if j % 2 == 0 else ground_wall) if f == 0 else _any(upper_walls)
			_add(parts, side, Vector3(-float(w) * 0.5, y, z), -PI * 0.5)
			side = (ground_wall if j % 2 == 0 else ground_window) if f == 0 else _any(upper_walls)
			_add(parts, side, Vector3(float(w) * 0.5, y, z), PI * 0.5)
		var corner := ("Corner_Exterior_Brick" if (brick and f == 0) else "Corner_Exterior_Wood")
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				_add(parts, corner, Vector3(cx * float(w) * 0.5, y, cz * float(d) * 0.5),
					atan2(cx, cz) - PI * 0.25)
		# Floor under each storey.
		for i in nx:
			for j in nz:
				_add(parts, "Floor_WoodDark" if f > 0 else "Floor_Brick",
					Vector3(-float(w) * 0.5 + 1.0 + 2.0 * i, y + 0.02, -float(d) * 0.5 + 1.0 + 2.0 * j), 0.0)
	var top := float(floors) * STOREY
	_add(parts, "Roof_RoundTiles_%dx%d" % [w, d], Vector3(0, top, 0), 0.0)
	_add(parts, "Roof_Front_Brick%d" % w, Vector3(0, top, float(d) * 0.5), 0.0)
	_add(parts, "Roof_Front_Brick%d" % w, Vector3(0, top, -float(d) * 0.5), PI)
	if _rng.randf() < 0.75:
		_add(parts, "Prop_Chimney", Vector3(float(w) * 0.25, top - 0.5, -float(d) * 0.25), 0.0)
	# A plinth so the house sits on sloping ground without floating.
	var plinth := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(float(w) + 0.5, 1.6, float(d) + 0.5)
	plinth.mesh = bm
	plinth.position = Vector3(0, -0.8, 0)
	var stone := StandardMaterial3D.new()
	stone.albedo_texture = load(KIT + "T_RockTrim_BaseColor.png")
	stone.uv1_triplanar = true
	stone.uv1_scale = Vector3(0.5, 0.5, 0.5)
	stone.roughness = 0.9
	plinth.material_override = stone
	parts.add_child(plinth)
	house.add_child(_merge(parts))
	parts.free()
	# Solid to walk into.
	var body := StaticBody3D.new()
	body.collision_layer = 2
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(float(w) + 0.3, top + 1.0, float(d) + 0.3)
	cs.shape = box
	cs.position = Vector3(0, top * 0.5, 0)
	body.add_child(cs)
	house.add_child(body)
	house.position = pos + Vector3(0, 0.12, 0)
	house.rotation.y = rot
	add_child(house)
	houses.append({"pos": pos, "rot": rot, "w": w, "d": d, "floors": floors})
	_dress(house, w, d)

## Life round a house: barrels and crates by the walls, a lamp by the door,
## sometimes a fenced garden out back with a tree in it.
func _dress(house: Node3D, w: int, d: int) -> void:
	var yard := Node3D.new()
	var hw := float(w) * 0.5
	var hd := float(d) * 0.5
	for k in _rng.randi_range(2, 4):
		var side := _rng.randi() % 3
		var at := Vector3.ZERO
		match side:
			0: at = Vector3(_rng.randf_range(-hw + 0.8, hw - 0.8), 0, hd + 0.7)
			1: at = Vector3(-hw - 0.7, 0, _rng.randf_range(-hd + 0.8, hd - 0.8))
			2: at = Vector3(hw + 0.7, 0, _rng.randf_range(-hd + 0.8, hd - 0.8))
		if side == 0 and absf(at.x) < 1.6:
			at.x = 1.8 * signf(at.x + 0.01)
		_add(yard, _any(["Barrel", "Barrel", "Crate_Wooden", "Bucket_Wooden_1", "Bench", "FarmCrate_Empty"]),
			at, _rng.randf() * TAU, PROPS)
	_add(yard, "Lantern_Wall", Vector3(1.3, 2.2, hd + 0.15), 0.0, PROPS)
	if _rng.randf() < 0.55:
		var gx := float(w) * 0.5 + 0.5
		var depth := 5.0
		for k in int(ceil(float(w) / 2.0)) + 1:
			var x := -gx + float(k) * 2.06
			if x <= gx + 0.1:
				_add(yard, "Prop_WoodenFence_Single", Vector3(x, 0, -hd - depth), 0.0, KIT)
		for k in 3:
			var z := -hd - 1.0 - float(k) * 2.06
			_add(yard, "Prop_WoodenFence_Single", Vector3(-gx, 0, z), PI * 0.5, KIT)
			_add(yard, "Prop_WoodenFence_Single", Vector3(gx, 0, z), PI * 0.5, KIT)
		for k in _rng.randi_range(2, 5):
			_add(yard, _any(["Flower_3_Group", "Flower_4_Group", "Bush_Common_Flowers", "Plant_1"]),
				Vector3(_rng.randf_range(-gx + 1.0, gx - 1.0), 0, -hd - _rng.randf_range(1.2, depth - 1.0)),
				_rng.randf() * TAU, "res://assets/nature/")
		if _rng.randf() < 0.7:
			var t := _add(yard, "CommonTree_%d" % _rng.randi_range(1, 5),
				Vector3(_rng.randf_range(-gx + 1.5, gx - 1.5), 0, -hd - depth * 0.6), _rng.randf() * TAU,
				"res://assets/nature/")
			if t != null:
				t.scale = Vector3.ONE * _rng.randf_range(1.0, 1.4)
	# Sit everything on the ground, in the house's frame, then fold the lot
	# into one mesh (a few dozen loose props per house were a draw call each).
	house.add_child(yard)
	for c in yard.get_children():
		var n := c as Node3D
		if n.name.begins_with("Lantern"):
			continue
		var g := house.to_global(n.position)
		n.position.y = island.height_at(g.x, g.z) - house.global_position.y
	var merged := _merge(yard)
	house.remove_child(yard)
	yard.free()
	house.add_child(merged)

func _any(list: Array) -> String:
	return str(list[_rng.randi() % list.size()])

func _scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]

func _add(parent: Node3D, piece: String, at: Vector3, rot: float, dir: String = KIT) -> Node3D:
	var ps := _scene(dir + piece + ".gltf")
	if ps == null:
		push_warning("missing kit piece " + piece)
		return null
	var n := ps.instantiate() as Node3D
	n.position = at
	n.rotation.y = rot
	parent.add_child(n)
	return n

## Every mesh under `root`, merged into one ArrayMesh with a surface per
## material, in root's space.
static func _merge(root: Node3D) -> MeshInstance3D:
	var tools := {}
	var mats := {}
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var n: Node = item[0]
		var xf: Transform3D = item[1]
		for c in n.get_children():
			var cx := xf
			if c is Node3D:
				cx = xf * (c as Node3D).transform
			stack.append([c, cx])
		if n is MeshInstance3D and n != root:
			var mi := n as MeshInstance3D
			var mesh := mi.mesh
			if mesh == null:
				continue
			for s in mesh.get_surface_count():
				# Skinned pieces (a cloth banner) cannot be merged into static
				# geometry; they are left out of the batch.
				if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_format(s) & Mesh.ARRAY_FORMAT_BONES:
					continue
				var mat := mi.get_active_material(s)
				# By name: each kit file imports its own copy of the same
				# material, and keying by instance merged nothing.
				var key: Variant = 0
				if mat != null:
					key = mat.resource_name if mat.resource_name != "" else mat.get_instance_id()
				if not tools.has(key):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					tools[key] = st
					mats[key] = mat
				(tools[key] as SurfaceTool).append_from(mesh, s, xf)
	var out := ArrayMesh.new()
	for key in tools.keys():
		var st: SurfaceTool = tools[key]
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, mats[key])
	var result := MeshInstance3D.new()
	result.mesh = out
	return result

# --- The square ------------------------------------------------------------------

func _square() -> void:
	var props := Node3D.new()
	add_child(props)
	_square_props(props)
	# Keep the lamps' lights; merge everything else into one mesh.
	var lights: Array[Node] = []
	for l in props.find_children("*", "OmniLight3D", true, false):
		lights.append(l)
	var keep := Node3D.new()
	add_child(keep)
	for l in lights:
		var gp := (l as Node3D).global_position
		l.get_parent().remove_child(l)
		keep.add_child(l)
		(l as Node3D).global_position = gp
	var merged := _merge(props)
	remove_child(props)
	props.free()
	add_child(merged)

func _square_props(props: Node3D) -> void:
	# Market stalls in a loose arc, with goods around them.
	for k in 5:
		var a := TAU * float(k) / 5.0 + 0.3
		var p := centre + Vector3(sin(a), 0, cos(a)) * 11.0
		_prop(props, ["Stall_Empty", "Stall_Cart_Empty"][k % 2], p, a + PI)
		for g in 3:
			var off := Vector3(_rng.randf_range(-2.2, 2.2), 0, _rng.randf_range(-2.2, 2.2))
			_prop(props, ["Barrel", "Barrel_Apples", "Crate_Wooden", "FarmCrate_Apple", "FarmCrate_Carrot",
				"Bag"][_rng.randi() % 6], p + off, _rng.randf() * TAU)
	# Benches and lamps round the middle.
	for k in 6:
		var a := TAU * float(k) / 6.0
		_prop(props, "Bench", centre + Vector3(sin(a), 0, cos(a)) * 5.5, a + PI * 0.5)
	_prop(props, "WeaponStand", centre + Vector3(16, 0, -3), 0.4)
	_prop(props, "Anvil_Log", centre + Vector3(17, 0, -1), 0.0)
	_prop(props, "Dummy", centre + Vector3(-15, 0, 6), 0.7)
	_prop(props, "Prop_Wagon", centre + Vector3(-12, 0, -12), 0.9, KIT)
	for k in 8:
		var a := TAU * float(k) / 8.0 + 0.2
		var lamp := _prop(props, "Torch_Metal", centre + Vector3(sin(a), 0, cos(a)) * 17.0, 0.0)
		if lamp != null:
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.72, 0.42)
			light.light_energy = 0.0          # lit at dusk by World
			light.omni_range = 9.0
			light.position = Vector3(0, 2.2, 0)
			light.add_to_group("night_lights")
			lamp.add_child(light)

func _prop(parent: Node3D, name: String, at: Vector3, rot: float, dir: String = PROPS) -> Node3D:
	var n := _add(parent, name, Vector3(at.x, island.height_at(at.x, at.z), at.z), rot, dir)
	return n
