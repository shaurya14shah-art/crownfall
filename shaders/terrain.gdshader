shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// The island's ground, painted rather than textured: two greens that drift
// across the hills, sun-dried meadow patches, a darker forest floor, wet and
// dry sand, cobbled roads, and rock wherever the ground is too steep to hold
// soil. The paint map (from Island) says where each belongs; noise breaks
// every edge so nothing reads as a stencil.

uniform sampler2D paint_map : filter_linear, repeat_disable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D path_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_tex : filter_linear_mipmap, repeat_enable;
uniform float island_size = 2048.0;

uniform vec3 grass_dark : source_color = vec3(0.24, 0.42, 0.11);
uniform vec3 grass_light : source_color = vec3(0.45, 0.63, 0.19);
uniform vec3 grass_dry : source_color = vec3(0.66, 0.66, 0.28);
uniform vec3 forest_floor : source_color = vec3(0.19, 0.28, 0.09);
uniform vec3 alpine : source_color = vec3(0.44, 0.50, 0.33);
uniform vec3 sand_dry : source_color = vec3(0.90, 0.82, 0.60);
uniform vec3 sand_wet : source_color = vec3(0.60, 0.53, 0.38);
uniform vec3 road_tint : source_color = vec3(0.92, 0.84, 0.72);
uniform vec3 rock_tint : source_color = vec3(0.80, 0.78, 0.76);

varying vec3 wpos;
varying vec3 wnorm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 triplanar(sampler2D tex, vec3 p, vec3 n, float scale) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(tex, p.zy * scale).rgb * w.x
		+ texture(tex, p.xz * scale).rgb * w.y
		+ texture(tex, p.xy * scale).rgb * w.z;
}

void fragment() {
	vec2 uv = (wpos.xz + island_size * 0.5) / island_size;
	vec4 paint = texture(paint_map, uv);
	float macro = texture(noise_tex, wpos.xz / 260.0).r;
	float mid = texture(noise_tex, wpos.xz / 61.0 + vec2(0.37, 0.11)).r;
	float detail = texture(detail_tex, wpos.xz / 5.0).r;
	float h = wpos.y;
	vec3 n = normalize(wnorm);
	float slope = 1.0 - n.y;

	// Grass: two greens drifting over the land, sun-dried meadows on top.
	vec3 col = mix(grass_dark, grass_light, smoothstep(0.30, 0.72, macro * 0.7 + mid * 0.3));
	float dry = smoothstep(0.60, 0.80, paint.a + (mid - 0.5) * 0.25) * 0.7;
	col = mix(col, grass_dry, dry);
	col = mix(col, forest_floor, smoothstep(0.15, 0.85, paint.b + (mid - 0.5) * 0.3));
	col = mix(col, alpine, smoothstep(85.0, 150.0, h + (macro - 0.5) * 30.0));

	// Sand: dry up the beach, darker and wet at the waterline and below.
	float sand = smoothstep(0.25, 0.75, paint.r + (detail - 0.5) * 0.35);
	sand = max(sand, smoothstep(0.9, -0.3, h));
	vec3 sandc = mix(sand_wet, sand_dry, smoothstep(0.15, 1.3, h));
	sandc *= 0.92 + detail * 0.16;
	col = mix(col, sandc, sand);

	// Roads: worn cobbles fading into packed earth at the edges.
	float road = smoothstep(0.10, 0.70, paint.g + (detail - 0.5) * 0.4);
	vec3 cobbles = texture(path_tex, wpos.xz / 3.2).rgb;
	cobbles = mix(cobbles * road_tint * 1.25, vec3(0.50, 0.42, 0.32), 0.25);
	vec3 earth = vec3(0.47, 0.36, 0.23) * (0.85 + detail * 0.3);
	col = mix(col, mix(earth, cobbles, smoothstep(0.6, 0.95, paint.g)), road);

	// Rock on anything steep, and on the high peaks.
	float rock = smoothstep(0.34, 0.50, slope + (macro - 0.5) * 0.14);
	rock = max(rock, smoothstep(175.0, 205.0, h + (mid - 0.5) * 25.0));
	vec3 rockc = triplanar(rock_tex, wpos, n, 1.0 / 9.0) * rock_tint;
	rockc = mix(rockc, rockc * vec3(0.86, 0.9, 1.0), smoothstep(120.0, 200.0, h));
	col = mix(col, rockc, rock * (1.0 - road));

	// Fine breakup everywhere, so close ground never reads as flat colour.
	col *= 0.86 + detail * 0.22 + (mid - 0.5) * 0.10;

	ALBEDO = col;
	ROUGHNESS = mix(0.92, 0.55, smoothstep(0.4, -0.6, h)) ;
	SPECULAR = 0.18;
}
