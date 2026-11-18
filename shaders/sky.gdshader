shader_type sky;
render_mode use_debanding;

// A painted sky: zenith-to-horizon gradient, a soft sun with a wide glow,
// layered clouds that drift with the wind and catch the sun at their edges,
// and stars once it is dark. The cubemap pass (ambient light, reflections)
// skips the clouds and stars, which keeps the realtime radiance cheap.

uniform vec3 zenith : source_color = vec3(0.20, 0.42, 0.82);
uniform vec3 horizon : source_color = vec3(0.68, 0.83, 0.95);
uniform vec3 below : source_color = vec3(0.30, 0.42, 0.52);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.95, 0.85);
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.98, 0.95);
uniform vec3 cloud_shade : source_color = vec3(0.62, 0.68, 0.80);
uniform float cloud_cover = 0.48;
uniform float cloud_time = 0.0;
uniform float night = 0.0;
uniform float sun_size = 0.9994;
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float clouds(vec2 uv) {
	vec2 drift = vec2(cloud_time * 0.004, cloud_time * 0.0015);
	float n = texture(cloud_noise, uv * 0.11 + drift).r * 0.6;
	n += texture(cloud_noise, uv * 0.31 - drift * 1.7).r * 0.3;
	n += texture(cloud_noise, uv * 0.93 + drift * 2.3).r * 0.1;
	return n;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float up = d.y;
	float t = pow(clamp(up, 0.0, 1.0), 0.45);
	vec3 col = mix(horizon, zenith, t);
	col = mix(col, below, smoothstep(0.0, -0.25, up));

	vec3 sun_dir = LIGHT0_DIRECTION;
	float sd = dot(d, sun_dir);
	// Horizon glow toward the sun, warmer when the sun is low.
	float low = 1.0 - clamp(sun_dir.y * 2.5, 0.0, 1.0);
	col += sun_tint * pow(max(sd, 0.0), 6.0) * (0.25 + low * 0.6) * (1.0 - night);
	col += sun_tint * pow(max(sd, 0.0), 64.0) * 0.6 * (1.0 - night);

	if (!AT_CUBEMAP_PASS) {
		// The sun's disc.
		float disc = smoothstep(sun_size - 0.00025, sun_size + 0.00015, sd);
		col = mix(col, sun_tint * 6.0, disc * (1.0 - night));
		// Stars: hashed points, twinkling, only where the sky is dark.
		if (night > 0.01 && up > 0.0) {
			vec3 cell = floor(d * 240.0);
			float s = hash(cell);
			float star = step(0.9965, s) * smoothstep(0.9, 0.2, length(fract(d * 240.0) - 0.5) * 2.0);
			star *= 0.6 + 0.4 * sin(TIME * (1.0 + s * 4.0) + s * 40.0);
			col += vec3(star) * night * smoothstep(0.0, 0.25, up);
		}
		// Clouds on a flat layer overhead.
		if (up > 0.0) {
			vec2 uv = d.xz / (up + 0.08);
			float c = clouds(uv);
			float cover = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.22, c);
			float thick = smoothstep(1.0 - cloud_cover, 1.0, c);
			// Lit from the sun's side: brighter edges toward it, shaded bellies.
			float toward = clamp(sd * 0.5 + 0.5, 0.0, 1.0);
			vec3 cc = mix(cloud_lit, cloud_shade, thick * 0.85);
			cc += sun_tint * pow(toward, 4.0) * (1.0 - thick) * 0.5;
			cc = mix(cc, horizon * 0.9, 1.0 - smoothstep(0.0, 0.35, up));
			cc *= mix(1.0, 0.18, night);
			col = mix(col, cc, cover * smoothstep(0.0, 0.12, up) * 0.95);
		}
	}
	COLOR = col;
}
