class_name SkyRig
extends Node3D
## Day and night: the sun and moon, the sky's colours, ambient light, fog and
## exposure, all driven from one clock. A full day lasts DAY_SECONDS; night
## passes twice as fast as day, because nobody wants to wait in the dark.

const DAY_SECONDS := 1200.0

var time_of_day := 0.36            ## 0 midnight, 0.25 sunrise, 0.5 noon, 0.75 sunset
var paused := false
var suspended := false          ## inside a Gate: the pocket has its own light
var env: Environment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var _sky_mat: ShaderMaterial
var _cloud_t := 0.0

# Colours at night / sunrise-sunset / full day.
const ZENITH := [Color(0.03, 0.05, 0.13), Color(0.18, 0.26, 0.50), Color(0.17, 0.40, 0.84)]
const HORIZON := [Color(0.07, 0.10, 0.20), Color(0.98, 0.60, 0.38), Color(0.66, 0.82, 0.96)]
const SUN := [Color(0.5, 0.6, 1.0), Color(1.0, 0.58, 0.32), Color(1.0, 0.95, 0.86)]
const FOG := [Color(0.05, 0.07, 0.13), Color(0.88, 0.62, 0.48), Color(0.70, 0.82, 0.94)]

func _ready() -> void:
	add_to_group("sky")
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://shaders/sky.gdshader")
	_sky_mat.set_shader_parameter("cloud_noise", Terrain.noise_texture(512, 0.008, 5, 77))
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	# Incremental: the lighting probe catches up over a few frames, which is
	# all a slowly turning day needs (realtime forces a 256 px probe a frame).
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.15
	env.glow_enabled = bool(Game.q("glow"))
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = bool(Game.q("ssao"))
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.8
	env.ssao_power = 1.4
	env.fog_enabled = true
	env.fog_density = 0.00045
	env.fog_aerial_perspective = 0.3
	env.fog_sky_affect = 0.15
	env.fog_height = 12.0
	env.fog_height_density = 0.0025
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if int(Game.q("shadow_splits")) >= 4 \
		else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = float(Game.q("shadow_distance"))
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.4
	sun.light_angular_distance = 0.0
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 80.0
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(moon)
	_apply()

func _process(delta: float) -> void:
	_cloud_t += delta
	if not paused:
		var rate := 1.0 / DAY_SECONDS
		if is_night():
			rate *= 2.0
		time_of_day = fmod(time_of_day + delta * rate, 1.0)
	_apply()

func is_night() -> bool:
	return time_of_day < 0.23 or time_of_day > 0.77

## Sun height: -1 at midnight, 0 at sunrise and sunset, 1 at noon.
func sun_height() -> float:
	return -cos(time_of_day * TAU)

func clock_text() -> String:
	var minutes := int(time_of_day * 1440.0)
	return "%02d:%02d" % [minutes / 60, minutes % 60]

## Inside a Gate: no sun or moon, a sky of the Gate's own colour, thick fog.
func enter_pocket(fog: Color, ambient: Color) -> void:
	suspended = true
	sun.visible = false
	moon.visible = false
	env.background_mode = Environment.BG_COLOR
	env.background_color = fog.darkened(0.4)
	env.fog_light_color = fog
	env.fog_density = 0.02
	env.fog_aerial_perspective = 0.0
	env.fog_height_density = 0.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = 0.55
	env.tonemap_exposure = 1.25

func leave_pocket() -> void:
	suspended = false
	env.background_mode = Environment.BG_SKY
	env.fog_density = 0.00045
	env.fog_aerial_perspective = 0.3
	env.fog_height_density = 0.0025
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_apply()

func _apply() -> void:
	if suspended:
		return
	var e := sun_height()
	# The sun's path: rises in the east, crosses south of overhead.
	var angle := time_of_day * TAU - PI * 0.5
	var dir := Vector3(cos(angle), sin(angle) * 0.92, 0.38).normalized()  # toward the sun
	sun.look_at_from_position(Vector3.ZERO, -dir, Vector3.UP)
	moon.look_at_from_position(Vector3.ZERO, dir * Vector3(1, 1, -1) + Vector3(0, 0.3, 0), Vector3.UP)
	# Blend weights: night (0), golden (1), day (2).
	var day := smoothstep(0.05, 0.45, e)
	var golden := smoothstep(-0.12, 0.05, e) * (1.0 - day)
	var night := 1.0 - smoothstep(-0.18, 0.02, e)
	var pick := func(arr: Array) -> Color:
		var c: Color = (arr[0] as Color) * night + (arr[1] as Color) * golden + (arr[2] as Color) * day
		var w := night + golden + day
		return c / maxf(w, 0.001)
	var sun_col: Color = pick.call(SUN)
	sun.light_color = sun_col
	sun.light_energy = clampf((e + 0.05) * 6.0, 0.0, 1.0) * lerpf(1.4, 2.4, day)
	sun.visible = e > -0.08
	moon.visible = e < 0.05
	moon.light_energy = night * 0.5
	_sky_mat.set_shader_parameter("zenith", pick.call(ZENITH))
	_sky_mat.set_shader_parameter("horizon", pick.call(HORIZON))
	_sky_mat.set_shader_parameter("below", (pick.call(HORIZON) as Color).darkened(0.35))
	_sky_mat.set_shader_parameter("sun_tint", sun_col)
	_sky_mat.set_shader_parameter("night", night)
	_sky_mat.set_shader_parameter("cloud_time", _cloud_t)
	_sky_mat.set_shader_parameter("cloud_lit", Color(1, 0.97, 0.93).lerp(Color(1.0, 0.72, 0.55), golden))
	_sky_mat.set_shader_parameter("cloud_shade", Color(0.60, 0.67, 0.80).lerp(Color(0.55, 0.45, 0.55), golden))
	env.fog_light_color = pick.call(FOG)
	env.ambient_light_energy = lerpf(0.6, 0.72, 1.0 - night)
	env.tonemap_exposure = lerpf(2.3, 1.12, 1.0 - night)
