extends Node
## Icons (autoload): item thumbnails rendered from the items' own 3D models,
## once each, in a small off-screen studio (three-quarter view, key and rim
## light, transparent background), and cached. Ask with `get_icon(id)`;
## until it is ready you get null, and `updated` fires when it is.

signal updated(id: String)

const SIZE := 128

var _cache := {}
var _queue: Array[String] = []
var _busy := false
var _vp: SubViewport
var _cam: Camera3D
var _stage: Node3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_vp = SubViewport.new()
	_vp.size = Vector2i(SIZE, SIZE)
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.8, 0.6, 0)
	key.light_energy = 1.6
	_vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(-0.3, PI + 0.4, 0)
	rim.light_energy = 1.2
	rim.light_color = Color(1.0, 0.85, 0.6)
	_vp.add_child(rim)
	_cam = Camera3D.new()
	_cam.fov = 28.0
	_vp.add_child(_cam)
	_stage = Node3D.new()
	_vp.add_child(_stage)

func model_path(id: String) -> String:
	var looks: Dictionary = Pickup.LOOKS
	if looks.has(id):
		return looks[id]
	var def := Run.item(id)
	if def.has("look"):
		return str(def["look"])
	if def.has("model"):
		return "res://assets/gear/%s.gltf" % def["model"]
	return ""

## Forged weapons are numbered per playthrough; after a load, forged_1 may
## be a different weapon.
func forget_forged() -> void:
	for k in _cache.keys():
		if str(k).begins_with("forged_") or str(k).begins_with("loot_") or str(k).begins_with("map_"):
			_cache.erase(k)

func get_icon(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	if not id in _queue:
		_queue.append(id)
	if not _busy:
		_next()
	return null

func _next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var id: String = _queue.pop_front()
	for c in _stage.get_children():
		c.free()
	var path := model_path(id)
	if path == "" or not ResourceLoader.exists(path):
		_cache[id] = null
		_next.call_deferred()
		return
	var n := (load(path) as PackedScene).instantiate() as Node3D
	_stage.add_child(n)
	n.rotation = Vector3(0.0, 0.7, -0.5)
	var box := Pickup._bounds(n)
	var centre := n.transform * box.get_center()
	var radius := box.size.length() * 0.5
	_cam.position = centre + Vector3(0, 0.15, 1.0).normalized() * radius / tan(deg_to_rad(_cam.fov * 0.5)) * 1.05
	_cam.look_at(centre, Vector3.UP)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	_cache[id] = ImageTexture.create_from_image(img)
	updated.emit(id)
	_next()
