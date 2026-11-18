class_name CharacterPreview
extends SubViewportContainer
## The knight on a little plinth, lit like a portrait, holding what you have
## equipped. Drag to turn him round; he idles, and swings when you change
## his weapon.

var _vp: SubViewport
var _model: CharacterModel
var _pivot: Node3D
var _gear: Array[Node] = []
var _drag := false
var _spin := 0.0

func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(340, 420)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.6, 0.5, 0)
	key.light_energy = 1.7
	key.shadow_enabled = true
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.2, PI - 0.3, 0)
	rim.light_color = Color(1.0, 0.8, 0.5)
	rim.light_energy = 1.4
	_vp.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0, 1.25, 5.6)
	cam.rotation.x = -0.08
	_vp.add_child(cam)
	# A round plinth.
	var plinth := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.9
	cyl.bottom_radius = 1.0
	cyl.height = 0.18
	plinth.mesh = cyl
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.22, 0.24, 0.29)
	stone.roughness = 0.8
	plinth.material_override = stone
	plinth.position.y = -0.09
	_vp.add_child(plinth)
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	_model = CharacterModel.new()
	_model.setup("res://assets/characters/Knight.glb", [], 0.85)
	_pivot.add_child(_model)
	_model.play("Idle")
	_pivot.rotation.y = 0.5
	Run.changed.connect(func(what: String) -> void:
		if what == "gear":
			_apply_gear()
			_model.play("1H_Melee_Attack_Slice_Diagonal" if not Run.item(str(Run.gear.get("weapon", ""))).get("two_handed", false)
				else "2H_Melee_Attack_Spin", 0.1, 1.2, true))
	_apply_gear()

func _apply_gear() -> void:
	for n in _gear:
		if is_instance_valid(n):
			n.queue_free()
	_gear.clear()
	for slot in {"weapon": "handslot_r", "shield": "handslot_l"}.keys():
		var att := _model.find_child({"weapon": "handslot_r", "shield": "handslot_l"}[slot], true, false) as Node3D
		var def := Run.item(str(Run.gear.get(slot, "")))
		if att == null or def.is_empty():
			continue
		var n := (load("res://assets/gear/%s.gltf" % def["model"]) as PackedScene).instantiate()
		att.add_child(n)
		_gear.append(n)

func _process(delta: float) -> void:
	if not _drag:
		_spin = lerpf(_spin, 0.0, delta * 3.0)
		_pivot.rotation.y += _spin * delta
	if _model.anim != null and not _model.anim.is_playing():
		_model.play("Idle", 0.2, 1.0, true)
	elif _model.anim != null and _model.anim.current_animation != "Idle" and not _model.playing_one_shot():
		_model.play("Idle", 0.2)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drag = (event as InputEventMouseButton).pressed
	elif event is InputEventMouseMotion and _drag:
		var dx := (event as InputEventMouseMotion).relative.x * 0.012
		_pivot.rotation.y += dx
		_spin = dx * 60.0
