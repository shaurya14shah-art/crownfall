shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

// Grass blades. The root takes exactly the colour of the ground under it
// (the same paint and noise the terrain shader reads), so the field grows
// out of the hill instead of sitting on it; the tip is lighter and warmer.
// Wind comes in rolling gusts; blades lean away from the player; and the
// whole field shrinks into the ground at the edge of its radius instead of
// popping (no `discard`: it switches off hidden-surface removal on Apple
// GPUs).

uniform sampler2D paint_map : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float island_size = 2048.0;
uniform vec3 grass_dark : source_color = vec3(0.24, 0.42, 0.11);
uniform vec3 grass_light : source_color = vec3(0.45, 0.63, 0.19);
uniform vec3 grass_dry : source_color = vec3(0.66, 0.66, 0.28);
uniform vec3 forest_floor : source_color = vec3(0.19, 0.28, 0.09);
uniform vec3 tip_tint : source_color = vec3(0.90, 0.95, 0.55);
uniform vec3 player_pos = vec3(0.0, -1000.0, 0.0);
uniform float radius = 55.0;
uniform float wind = 1.0;

varying vec3 base_col;
varying float tip;

vec3 ground_colour(vec2 xz) {
	vec4 paint = texture(paint_map, (xz + island_size * 0.5) / island_size);
	float macro = texture(noise_tex, xz / 260.0).r;
	float mid = texture(noise_tex, xz / 61.0 + vec2(0.37, 0.11)).r;
	vec3 col = mix(grass_dark, grass_light, smoothstep(0.30, 0.72, macro * 0.7 + mid * 0.3));
	col = mix(col, grass_dry, smoothstep(0.60, 0.80, paint.a + (mid - 0.5) * 0.25) * 0.7);
	col = mix(col, forest_floor, smoothstep(0.15, 0.85, paint.b + (mid - 0.5) * 0.3));
	return col;
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	tip = clamp(VERTEX.y / 0.32, 0.0, 1.0);
	// Shrink with distance.
	float d = distance(origin.xz, CAMERA_POSITION_WORLD.xz);
	float keep = 1.0 - smoothstep(radius * 0.72, radius, d);
	VERTEX *= vec3(1.0, keep, 1.0);
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Gusts: a slow wave rolling across the field, plus a quick flutter.
	float gust = sin(dot(world.xz, vec2(0.08, 0.05)) - TIME * 1.6) * 0.5 + 0.5;
	float flutter = sin(TIME * 4.0 + world.x * 1.3 + world.z * 0.9) * 0.08;
	vec2 bend = vec2(0.9, 0.35) * (gust * 0.35 + 0.08) * wind + vec2(flutter, flutter * 0.5);
	// Pushed aside by the player.
	vec2 away = world.xz - player_pos.xz;
	float near = (1.0 - smoothstep(0.0, 1.6, length(away))) * step(abs(world.y - player_pos.y), 2.5);
	bend += normalize(away + vec2(0.0001)) * near * 0.9;
	vec3 offset = vec3(bend.x, -length(bend) * 0.35, bend.y) * tip * tip;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * offset;
	base_col = ground_colour(origin.xz);
}

void fragment() {
	vec3 col = mix(base_col * 0.78, base_col * tip_tint * 1.35, tip);
	ALBEDO = col;
	ROUGHNESS = 0.9;
	BACKLIGHT = col * 0.3;
	AO = mix(0.55, 1.0, tip);
	AO_LIGHT_AFFECT = 0.5;
}
