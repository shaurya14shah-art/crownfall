shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

// Leaves and plants: the art's own cut-out texture, swaying in the wind
// (more toward the tips, out of phase from plant to plant), lit through
// from behind, with a per-instance tint so a wood is not one colour.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(1.0);
uniform float alpha_cut = 0.45;
uniform float wind = 0.35;
uniform float sway_height = 6.0;
uniform float translucency = 0.35;
uniform float rough = 0.85;

varying float shade;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float h = clamp(VERTEX.y / sway_height, 0.0, 1.0);
	float phase = origin.x * 0.13 + origin.z * 0.17;
	float t = TIME;
	float bend = sin(t * 0.9 + phase) * 0.6 + sin(t * 2.1 + phase * 1.7) * 0.25;
	float flutter = sin(t * 5.3 + VERTEX.x * 2.0 + VERTEX.z * 2.0 + phase) * 0.06;
	vec3 push = vec3(1.0, 0.0, 0.35) * (bend * h * h * wind) + vec3(flutter * h, flutter * 0.3 * h, 0.0);
	VERTEX += (inverse(mat3(MODEL_MATRIX)) * push);
	shade = 0.8 + 0.2 * fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	if (c.a < alpha_cut) {
		discard;
	}
	ALBEDO = c.rgb * tint * shade;
	ROUGHNESS = rough;
	SPECULAR = 0.25;
	BACKLIGHT = c.rgb * translucency;
}
