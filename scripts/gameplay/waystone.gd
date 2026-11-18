class_name Waystone
extends Node3D
## A Waystone: a weathered obelisk by the road with an anvil at its foot.
## Dark until you kindle it; after that a gold ember hangs over it and it is
## a place to rest (whole again, the Flask full, the fallen risen), to
## travel between, to work the forge, and where you get up after a fall.

var id := ""
var title := ""
var mooring := Vector3.INF        ## where a ship can be called to, if this stone is by the sea
var _ember: MeshInstance3D
var _light: OmniLight3D
var _band: StandardMaterial3D
var _motes: CPUParticles3D
var _t := 0.0

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("waystones")
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("8a867e")
	stone.roughness = 1.0
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("6f6b64")
	dark.roughness = 1.0
	_block(Vector3(1.9, 0.35, 1.9), Vector3(0, 0.1, 0), dark)
	_block(Vector3(1.3, 0.3, 1.3), Vector3(0, 0.42, 0), stone)
	var spire := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.radial_segments = 4
	cm.rings = 1
	cm.top_radius = 0.17
	cm.bottom_radius = 0.42
	cm.height = 2.7
	spire.mesh = cm
	spire.material_override = stone
	spire.position.y = 0.57 + 1.35
	spire.rotation.y = PI * 0.25
	add_child(spire)
	# A ring of runes cut round the spire, lit once kindled.
	var band := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.radial_segments = 4
	bm.rings = 1
	bm.top_radius = 0.31
	bm.bottom_radius = 0.33
	bm.height = 0.12
	band.mesh = bm
	_band = StandardMaterial3D.new()
	_band.albedo_color = Color("3a3630")
	_band.emission_enabled = true
	_band.emission = Color(1.0, 0.75, 0.35)
	band.material_override = _band
	band.position.y = 1.45
	band.rotation.y = PI * 0.25
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(band)
	_ember = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	sm.radial_segments = 12
	sm.rings = 6
	_ember.mesh = sm
	var em := StandardMaterial3D.new()
	em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	em.albedo_color = Color(1.0, 0.82, 0.45)
	_ember.material_override = em
	_ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ember.position.y = 3.55
	add_child(_ember)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.78, 0.45)
	_light.omni_range = 9.0
	_light.position.y = 3.4
	add_child(_light)
	_motes = CPUParticles3D.new()
	_motes.amount = 14
	_motes.lifetime = 2.6
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_motes.emission_sphere_radius = 0.5
	_motes.direction = Vector3.UP
	_motes.spread = 25.0
	_motes.gravity = Vector3(0, 0.35, 0)
	_motes.initial_velocity_min = 0.2
	_motes.initial_velocity_max = 0.5
	_motes.scale_amount_min = 0.5
	_motes.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.albedo_color = Color(1.0, 0.75, 0.35)
	q.material = qm
	_motes.mesh = q
	_motes.position.y = 3.2
	add_child(_motes)
	var anvil_ps := load("res://assets/props/Anvil.gltf") as PackedScene
	if anvil_ps != null:
		var anvil := anvil_ps.instantiate() as Node3D
		anvil.scale = Vector3.ONE * 1.3
		anvil.position = Vector3(1.7, 0.0, 0.9)
		anvil.rotation.y = 0.6
		add_child(anvil)
	_show(kindled())

func _block(size: Vector3, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = at + Vector3(0, size.y * 0.5, 0)
	add_child(mi)

func refresh() -> void:
	_show(kindled())

func kindled() -> bool:
	return Run.flags.has("way_" + id)

func _show(lit: bool) -> void:
	_ember.visible = lit
	_motes.emitting = lit
	_light.light_energy = 1.8 if lit else 0.0
	_band.emission_energy_multiplier = 1.6 if lit else 0.0

## Where you stand when you arrive here or get up after a fall.
func spawn_point() -> Vector3:
	return global_position + global_basis.z * 2.4 + Vector3.UP * 0.3

func prompt_text() -> String:
	return "Rest at the Waystone" if kindled() else "Kindle the Waystone"

func interact(_player: Node3D) -> void:
	if not kindled():
		Run.flags["way_" + id] = true
		_show(true)
		Fx.sparks(get_parent(), global_position + Vector3.UP * 3.5, Color(1.0, 0.8, 0.4), 30)
		Audio.ui("confirm", -2.0)
		Run.toast.emit("Waystone kindled: " + title, "place")
		Run.renown(40.0)
		Run.lean("curiosity", 0.5)
		var hud := get_tree().get_first_node_in_group("hud")
		if hud != null:
			hud.call("show_banner", title, "WAYSTONE KINDLED")
	var main := get_tree().get_first_node_in_group("main")
	if main != null:
		main.call("rest_at", self)

func _process(delta: float) -> void:
	if not _ember.visible:
		return
	_t += delta
	_ember.position.y = 3.55 + sin(_t * 1.6) * 0.08
	var s := 1.0 + 0.1 * sin(_t * 5.0)
	_ember.scale = Vector3.ONE * s
	_light.light_energy = 1.6 + 0.25 * sin(_t * 7.3) + 0.15 * sin(_t * 13.1)
