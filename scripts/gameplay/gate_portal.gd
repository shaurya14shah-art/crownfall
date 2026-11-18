class_name GatePortal
extends Node3D
## A Gate, as you meet it in the world: a broken ring of rune-cut stones on
## a round dais, and inside the ring a hole in the world in its Law's
## colour, a swirling rim around a dark depth with stars in it. Motes drift
## into it; a rune circle turns on the ground; shards of the ring hang in the
## air. Open, a faint column of light stands over it so it can be found from
## far off. Closed, it is only a crack of light in the ring.

var gate_id := ""
var _disc: MeshInstance3D
var _light: OmniLight3D
var _mat: ShaderMaterial
var _runes: StandardMaterial3D
var _floor: StandardMaterial3D
var _beam: StandardMaterial3D
var _glyph: MeshInstance3D
var _motes: CPUParticles3D
var _shards: Array[Node3D] = []
var _open := 0.0
var _t := 0.0

const RING_R := 3.5
const CENTRE := 4.1
const SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec3 colour : source_color = vec3(0.3, 0.6, 1.0);
uniform float open = 1.0;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = h21(i);
	float b = h21(i + vec2(1.0, 0.0));
	float c = h21(i + vec2(0.0, 1.0));
	float d = h21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float ang = atan(p.y, p.x);
	float t = TIME;
	float sw = ang + r * 4.5 - t * 0.7;
	vec2 q = vec2(cos(sw), sin(sw)) * r * 3.0;
	float n = fbm(q + vec2(t * 0.25, -t * 0.18));
	float bands = sin(ang * 6.0 + r * 13.0 - t * 2.6 + n * 5.0) * 0.5 + 0.5;
	float rim = smoothstep(0.72, 0.97, r) * (0.65 + 0.7 * n);
	float fire = smoothstep(0.86, 1.0, r + (n - 0.5) * 0.18);
	vec2 sp = p * 20.0 + vec2(t * 0.15, t * 0.05);
	float star = step(0.986, h21(floor(sp))) * smoothstep(0.7, 0.0, r);
	vec3 deep = mix(vec3(0.01, 0.0, 0.025), colour * 0.22, smoothstep(0.05, 0.85, r));
	vec3 lit = deep + colour * (bands * 0.4 * smoothstep(0.25, 0.9, r) + rim * 2.0 + fire * 1.4) + vec3(star);
	lit += vec3(1.0) * pow(smoothstep(0.86, 0.985, r), 3.0) * 0.55;
	float body = smoothstep(1.0, 0.95, r) * 0.94;
	float crack = smoothstep(0.07, 0.0, abs(p.x + sin(p.y * 7.0 + t) * 0.05)) * smoothstep(1.0, 0.25, abs(p.y));
	float o = smoothstep(0.1, 0.6, open);
	ALBEDO = mix(colour * crack * 2.2, lit, o);
	ALPHA = clamp(max(crack * 0.9 * (1.0 - o), body * o), 0.0, 1.0);
}
"""

func _ready() -> void:
	add_to_group("interactables")
	add_to_group("gates")
	var def: Dictionary = Story.GATES[gate_id]
	var col := Law.colour(str(def["law"]))
	var stone := StandardMaterial3D.new()
	stone.albedo_texture = load("res://assets/village/T_RockTrim_BaseColor.png")
	stone.uv1_triplanar = true
	stone.uv1_scale = Vector3.ONE * 0.6
	stone.albedo_color = Color(0.82, 0.8, 0.78)
	stone.roughness = 0.95
	_runes = StandardMaterial3D.new()
	_runes.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_runes.albedo_color = col
	# The dais: two stacked round steps.
	for step in [[4.6, 0.35, 0.0], [3.9, 0.3, 0.35]]:
		var d := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = float(step[0])
		cm.bottom_radius = float(step[0]) + 0.15
		cm.height = float(step[1])
		cm.radial_segments = 20
		d.mesh = cm
		d.material_override = stone
		d.position.y = float(step[2]) + float(step[1]) * 0.5
		add_child(d)
	# The ring, cut into stones; two at the top-left are missing (they hang
	# in the air nearby as shards).
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(gate_id)
	var segs := 16
	for k in segs:
		var a := TAU * float(k) / float(segs)
		var missing := k == 5 or k == 6
		var at := Vector3(cos(a) * RING_R, CENTRE + sin(a) * RING_R, 0.0)
		var blk := MeshInstance3D.new()
		var bm := BoxMesh.new()
		# Local X runs along the ring, local Y points in toward the hole.
		bm.size = Vector3(1.28 + rng.randf_range(-0.08, 0.1), 1.3 + rng.randf_range(-0.1, 0.25), 1.15)
		blk.mesh = bm
		blk.material_override = stone
		blk.rotation.z = a + PI * 0.5 + rng.randf_range(-0.04, 0.04)
		var inlay := MeshInstance3D.new()
		var im := BoxMesh.new()
		im.size = Vector3(0.8, 0.08, 1.2)
		inlay.mesh = im
		inlay.material_override = _runes
		inlay.position = Vector3(0, bm.size.y * 0.5, 0)
		inlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blk.add_child(inlay)
		if missing:
			var holder := Node3D.new()
			holder.position = at + Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(0.6, 1.6), rng.randf_range(-1.4, 1.4))
			holder.set_meta("base", holder.position)
			holder.set_meta("phase", rng.randf() * TAU)
			add_child(holder)
			blk.scale = Vector3.ONE * 0.7
			holder.add_child(blk)
			_shards.append(holder)
		else:
			blk.position = at
			add_child(blk)
	# The hole in the world.
	_disc = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(RING_R * 2.0 - 0.5, RING_R * 2.0 - 0.5)
	_disc.mesh = quad
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_mat.set_shader_parameter("colour", col)
	_disc.material_override = _mat
	_disc.position = Vector3(0, CENTRE, 0)
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_disc)
	# A rune circle turning on the dais.
	_glyph = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8.6, 8.6)
	_glyph.mesh = pm
	_floor = StandardMaterial3D.new()
	_floor.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_floor.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_floor.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_floor.albedo_texture = GroundMessage._runes()
	_floor.albedo_color = Color(col, 0.0)
	_glyph.material_override = _floor
	_glyph.position.y = 0.68
	_glyph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glyph)
	# Motes drawn in toward the hole.
	_motes = CPUParticles3D.new()
	_motes.amount = 40
	_motes.lifetime = 2.4
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	_motes.emission_ring_axis = Vector3(0, 0, 1)
	_motes.emission_ring_radius = RING_R + 2.5
	_motes.emission_ring_inner_radius = RING_R + 0.6
	_motes.emission_ring_height = 2.0
	_motes.gravity = Vector3.ZERO
	_motes.radial_accel_min = -3.5
	_motes.radial_accel_max = -2.0
	_motes.tangential_accel_min = 1.5
	_motes.tangential_accel_max = 3.0
	_motes.scale_amount_min = 0.6
	_motes.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.albedo_color = col.lightened(0.3)
	q.material = qm
	_motes.mesh = q
	_motes.position = Vector3(0, CENTRE, 0)
	add_child(_motes)
	# A faint column of light over an open Gate, to find it by.
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.3
	cyl.bottom_radius = 1.4
	cyl.height = 90.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	beam.mesh = cyl
	_beam = StandardMaterial3D.new()
	_beam.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam.albedo_color = Color(col, 0.0)
	beam.material_override = _beam
	beam.position.y = CENTRE + 45.0
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	_light = OmniLight3D.new()
	_light.light_color = col
	_light.omni_range = 16.0
	_light.position = Vector3(0, CENTRE, 1.2)
	add_child(_light)

func is_open() -> bool:
	return Story.gate_open(gate_id)

func prompt_text() -> String:
	if not is_open():
		return ""
	return ("Enter " if not Story.gate_cleared(gate_id) else "Enter again: ") + str(Story.GATES[gate_id]["name"])

func interact(_player: Node3D) -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main != null and main.has_method("enter_gate"):
		main.call("enter_gate", gate_id)

func _process(delta: float) -> void:
	_t += delta
	var want := 1.0 if is_open() else 0.12
	if Story.gate_cleared(gate_id):
		want = 0.65
	_open = move_toward(_open, want, delta * 0.6)
	_mat.set_shader_parameter("open", _open)
	_light.light_energy = 0.4 + 3.4 * _open + 0.3 * sin(_t * 4.0) * _open
	var pulse := 0.75 + 0.25 * sin(_t * 2.2)
	_runes.albedo_color = Law.colour(str(Story.GATES[gate_id]["law"])).lerp(Color(0.12, 0.12, 0.14), 1.0 - _open) * pulse
	_floor.albedo_color.a = 0.75 * _open
	_glyph.rotation.y += delta * 0.12
	_beam.albedo_color.a = 0.09 * smoothstep(0.5, 1.0, _open)
	_motes.emitting = _open > 0.4
	for s in _shards:
		var base: Vector3 = s.get_meta("base")
		var ph := float(s.get_meta("phase"))
		s.position = base + Vector3(0, sin(_t * 0.9 + ph) * 0.25, 0)
		s.rotation = Vector3(sin(_t * 0.3 + ph) * 0.4, _t * 0.25 + ph, cos(_t * 0.4 + ph) * 0.3)
