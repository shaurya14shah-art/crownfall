shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx, depth_draw_always;

// The sea: four Gerstner swells, clear turquoise shallows you can see the
// sand through, deep teal offshore, white foam where the water meets land
// and on the steepest crests, and the sky and sun in its surface.

uniform vec3 shallow : source_color = vec3(0.22, 0.78, 0.74);
uniform vec3 deep : source_color = vec3(0.02, 0.20, 0.34);
uniform vec3 foam_col : source_color = vec3(0.96, 0.98, 1.0);
uniform float clarity = 0.16;           // how fast light dies with depth
uniform float wave_scale = 1.0;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

// direction (xy), amplitude, wavelength
const vec4 W0 = vec4(1.0, 0.25, 0.32, 41.0);
const vec4 W1 = vec4(0.6, -0.8, 0.20, 23.0);
const vec4 W2 = vec4(-0.4, 0.9, 0.11, 12.0);
const vec4 W3 = vec4(0.9, 0.45, 0.06, 6.5);

varying vec3 wpos;
varying float crest;

vec3 gerstner(vec4 w, vec2 p, inout vec3 tangent, inout vec3 binormal) {
	vec2 d = normalize(w.xy);
	float k = 6.28318 / w.w;
	float c = sqrt(9.81 / k);
	float a = w.z * wave_scale;
	float steep = 0.55 / (k * a * 4.0 + 0.001);
	float f = k * (dot(d, p) - c * TIME);
	float q = clamp(steep * k * a, 0.0, 0.9);
	tangent += vec3(-d.x * d.x * q * sin(f), d.x * k * a * cos(f), -d.x * d.y * q * sin(f));
	binormal += vec3(-d.x * d.y * q * sin(f), d.y * k * a * cos(f), -d.y * d.y * q * sin(f));
	return vec3(d.x * (q / k) * cos(f), a * sin(f), d.y * (q / k) * cos(f));
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = length(world.xz - CAMERA_POSITION_WORLD.xz);
	float fade = 1.0 - smoothstep(250.0, 900.0, dist);
	vec3 tangent = vec3(1.0, 0.0, 0.0);
	vec3 binormal = vec3(0.0, 0.0, 1.0);
	vec3 disp = vec3(0.0);
	disp += gerstner(W0, world.xz, tangent, binormal);
	disp += gerstner(W1, world.xz, tangent, binormal);
	disp += gerstner(W2, world.xz, tangent, binormal);
	disp += gerstner(W3, world.xz, tangent, binormal);
	disp *= fade;
	VERTEX += disp;
	vec3 n = normalize(cross(binormal, tangent));
	NORMAL = normalize(mix(vec3(0.0, 1.0, 0.0), n, fade));
	crest = disp.y;
	wpos = world + disp;
}

void fragment() {
	// How much water lies between the surface and whatever is behind it.
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	float scene_depth = -view.z / view.w;
	float surf_depth = -VERTEX.z;
	float thick = max(scene_depth - surf_depth, 0.0);

	// Ripples on top of the swell, from two drifting noise layers.
	vec2 r1 = texture(foam_noise, wpos.xz / 23.0 + TIME * vec2(0.012, 0.008)).rg;
	vec2 r2 = texture(foam_noise, wpos.xz / 9.0 - TIME * vec2(0.010, 0.017)).rg;
	vec2 ripple = (r1 + r2 - 1.0) * 0.22;
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(ripple.x, 0.0, ripple.y, 0.0)).xyz);

	// Looking through the water: refracted, then tinted by depth.
	vec2 refr_uv = SCREEN_UV + ripple * 0.03 * clamp(thick / 3.0, 0.0, 1.0);
	float refr_raw = texture(depth_tex, refr_uv).r;
	vec4 refr_view = INV_PROJECTION_MATRIX * vec4(refr_uv * 2.0 - 1.0, refr_raw, 1.0);
	if (-refr_view.z / refr_view.w < surf_depth) {
		refr_uv = SCREEN_UV;    // don't refract things in front of the water
	}
	vec3 behind = textureLod(screen_tex, refr_uv, 0.0).rgb;
	float through = exp(-thick * clarity);
	vec3 water = mix(deep, shallow, exp(-thick * 0.09));
	vec3 col = mix(water, behind * mix(vec3(1.0), shallow, 0.35), through * 0.85);

	// Foam: a lacy band at the shore, and on the highest crests.
	float n = texture(foam_noise, wpos.xz / 6.0 + vec2(TIME * 0.03, 0.0)).r;
	float shore = 1.0 - smoothstep(0.0, 1.4, thick);
	float band = smoothstep(0.45, 0.62, n + shore * 0.55 + sin(thick * 6.0 - TIME * 2.2) * 0.12) * shore;
	float top = smoothstep(0.40, 0.70, crest + n * 0.25);
	float foam = clamp(band + top * 0.55, 0.0, 1.0);

	ALBEDO = mix(col * 0.12, foam_col, foam);
	EMISSION = col * (1.0 - foam) * 0.9;
	ROUGHNESS = mix(0.06, 0.85, foam);
	SPECULAR = 0.55;
	ALPHA = 1.0;
}
