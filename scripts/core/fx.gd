class_name Fx
extends RefCounted
## Small effects any script can ask for: hit-stop (the world freezing for a
## few hundredths of a second when a blow lands) and bursts of sparks.

static var _stop_until := 0

## Freezes the game for `seconds` of real time, then lets it go.
static func hit_stop(seconds: float) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	Engine.time_scale = 0.04
	_stop_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	var until := _stop_until
	await tree.create_timer(seconds, true, false, true).timeout
	if until == _stop_until:
		Engine.time_scale = 1.0

static func sparks(parent: Node, at: Vector3, col: Color, amount: int = 18) -> void:
	if parent == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.5
	p.gravity = Vector3(0, -14, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 4.0
	quad.material = m
	p.mesh = quad
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	var tree := parent.get_tree()
	await tree.create_timer(1.0).timeout
	if is_instance_valid(p):
		p.queue_free()
