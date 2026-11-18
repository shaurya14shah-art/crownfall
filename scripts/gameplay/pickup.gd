class_name Pickup
extends Node3D
## Loot on the ground: the thing itself, turning slowly above a column of
## light in its rarity's colour. Walk near and it flies to you.

const RARITY := {"common": Color(0.85, 0.85, 0.85), "fine": Color(0.40, 0.75, 1.0), "rare": Color(0.75, 0.45, 1.0),
	"relic": Color(1.0, 0.78, 0.30), "silver": Color(1.0, 0.86, 0.40)}
const LOOKS := {"silver": "res://assets/props/Coin_Pile.gltf", "red_potion": "res://assets/props/Potion_1.gltf",
	"bread": "res://assets/props/Bag.gltf", "bone_shard": "res://assets/enemy_gear/Skeleton_Arrow_Broken.gltf",
	"grave_dust": "res://assets/props/Pouch_Large.gltf", "iron_scrap": "res://assets/props/Chain_Coil.gltf",
	"bell_clapper": "res://assets/props/CandleStick.gltf", "orrery_disc": "res://assets/props/Coin.gltf",
	"ember_coal": "res://assets/props/Pot_1.gltf", "rime_salt": "res://assets/props/SmallBottle.gltf",
	"star_iron": "res://assets/props/Whetstone.gltf", "hearth_seed": "res://assets/props/Potion_4.gltf",
	"bright_tear": "res://assets/props/Potion_2.gltf"}

var id := "silver"
var amount := 1
var _t := 0.0
var _flying := false
var _player: Node3D
var _item: Node3D

static func spawn(parent: Node, at: Vector3, item_id: String, n: int) -> Pickup:
	var p := Pickup.new()
	p.id = item_id
	p.amount = n
	parent.add_child(p)
	p.global_position = at
	return p

func _ready() -> void:
	var col := _colour()
	_item = Node3D.new()
	add_child(_item)
	var path := str(LOOKS.get(id, ""))
	var def := Run.item(id)
	if path == "" and def.has("look"):
		path = str(def["look"])
	if path == "" and def.has("model"):
		path = "res://assets/gear/%s.gltf" % def["model"]
	if path != "" and ResourceLoader.exists(path):
		var n := (load(path) as PackedScene).instantiate() as Node3D
		_item.add_child(n)
		var box := _bounds(n)
		var s := 0.55 / maxf(box.size.length(), 0.01)
		n.scale = Vector3.ONE * clampf(s, 0.2, 3.0)
		n.position = -box.get_center() * n.scale
	else:
		var crystal := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.12
		cm.height = 0.45
		cm.radial_segments = 6
		crystal.mesh = cm
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 2.0
		crystal.material_override = m
		_item.add_child(crystal)
	# The column of light.
	var beam := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.02
	bm.bottom_radius = 0.18
	bm.height = 2.6
	bm.cap_top = false
	bm.cap_bottom = false
	beam.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(col, 0.35)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	beam.material_override = mat
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.position.y = 1.0
	add_child(beam)

func _colour() -> Color:
	if id == "silver":
		return RARITY["silver"]
	return RARITY.get(str(Run.item(id).get("rarity", "common")), Color.WHITE)

static func _bounds(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box

func _process(delta: float) -> void:
	_t += delta
	_item.rotation.y += delta * 1.6
	_item.position.y = 0.15 + sin(_t * 2.5) * 0.08
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node3D
		return
	var to := _player.global_position + Vector3.UP - global_position
	if _t > 0.6 and to.length() < 3.5:
		_flying = true
	if _flying:
		global_position += to.normalized() * minf(to.length(), delta * (6.0 + _t * 6.0))
		if to.length() < 0.6:
			_collect()

func _collect() -> void:
	if id == "silver":
		Run.add_silver(amount)
		Audio.play("coin", global_position, -2.0)
	else:
		if Run.add_item(id, amount) <= 0:
			_flying = false
			_t = -2.0
			return
		Audio.play("coin", global_position, -8.0, 1.4)
	queue_free()
