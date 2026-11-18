class_name CameraRig
extends Node3D
## Third-person camera: follows a little behind and over the right shoulder,
## eases after the player rather than being bolted to them, pulls in when a
## wall or hill is in the way, widens a touch at a sprint, and shakes on a
## heavy hit. With a lock-on target it swings to keep both in frame.

var target: Node3D
var yaw := 0.0
var pitch := -0.30
var distance := 5.8
var lock_target: Node3D = null
var camera: Camera3D
var _arm: SpringArm3D
var _shake := 0.0
var _fov_kick := 0.0
var _follow := Vector3.ZERO

const SHOULDER := Vector3(0.55, 0.0, 0.0)

func _ready() -> void:
	top_level = true
	add_to_group("camera_rig")
	_arm = SpringArm3D.new()
	_arm.spring_length = distance
	_arm.collision_mask = 1 | 2
	_arm.margin = 0.25
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	_arm.shape = probe
	add_child(_arm)
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.1
	camera.far = 4000.0
	_arm.add_child(camera)
	camera.make_current()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Game.playing:
		var m := event as InputEventMouseMotion
		yaw -= m.relative.x * Game.mouse_sensitivity
		pitch = clampf(pitch - m.relative.y * Game.mouse_sensitivity * (-1.0 if Game.invert_y else 1.0), -1.25, 0.75)

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func kick_fov(amount: float) -> void:
	_fov_kick = amount

## The direction the camera looks, flattened onto the ground.
func forward_flat() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))

func snap() -> void:
	if target != null:
		_follow = target.global_position + Vector3.UP * 1.7
		global_position = _follow

func _process(delta: float) -> void:
	if target == null:
		return
	var want := target.global_position + Vector3.UP * 1.7
	_follow = _follow.lerp(want, clampf(delta * 16.0, 0.0, 1.0))
	if _follow.distance_to(want) > 6.0:
		_follow = want
	if lock_target != null and is_instance_valid(lock_target):
		var to := lock_target.global_position - target.global_position
		var want_yaw := atan2(-to.x, -to.z)
		yaw = lerp_angle(yaw, want_yaw, clampf(delta * 6.0, 0.0, 1.0))
		pitch = lerpf(pitch, -0.36, clampf(delta * 3.0, 0.0, 1.0))
	global_position = _follow
	rotation = Vector3(pitch, yaw, 0.0)
	_arm.position = SHOULDER
	var want_len := distance + (1.6 if lock_target != null else 0.0)
	_arm.spring_length = lerpf(_arm.spring_length, want_len, clampf(delta * 4.0, 0.0, 1.0))
	_shake = move_toward(_shake, 0.0, delta * 2.5)
	var t := Time.get_ticks_msec() * 0.001
	# Shake through the lens offsets: the spring arm owns the camera's position.
	camera.h_offset = sin(t * 61.0) * _shake * 0.12
	camera.v_offset = cos(t * 53.0) * _shake * 0.12
	_fov_kick = move_toward(_fov_kick, 0.0, delta * 8.0)
	var sprinting := target.has_method("is_sprinting") and bool(target.call("is_sprinting"))
	camera.fov = lerpf(camera.fov, Game.fov + (6.0 if sprinting else 0.0) + _fov_kick, clampf(delta * 4.0, 0.0, 1.0))
