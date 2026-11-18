class_name Impostors
extends RefCounted
## Far trees as pictures of themselves. Each tree model is photographed once
## at load (side-on, orthographic, albedo-lit, transparent background) into
## a texture; past ~140 m a tree is one camera-facing card with that
## picture on it instead of hundreds of overlapping leaf cards. Fog does the
## rest. The single biggest cost on a Retina screen was leaf overdraw.

const SHADER := """
shader_type spatial;
render_mode skip_vertex_transform, cull_disabled, diffuse_lambert, specular_disabled;
uniform sampler2D picture : source_color, filter_linear_mipmap;
uniform float cut = 0.5;
varying float shade;
void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 to_cam = CAMERA_POSITION_WORLD - origin;
	to_cam.y = 0.0;
	to_cam = normalize(to_cam + vec3(0.0001));
	vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), to_cam));
	vec3 world = origin + right * VERTEX.x * sx + vec3(0.0, 1.0, 0.0) * VERTEX.y * sy;
	VERTEX = (VIEW_MATRIX * vec4(world, 1.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(to_cam + vec3(0.0, 0.6, 0.0)), 0.0)).xyz);
	shade = 0.85 + 0.15 * fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);
}
void fragment() {
	vec4 c = texture(picture, UV);
	if (c.a < cut) {
		discard;
	}
	ALBEDO = c.rgb * shade;
	ROUGHNESS = 0.9;
	BACKLIGHT = c.rgb * 0.25;
}
"""

static var _shader: Shader

## Photographs `mesh` side-on. Returns [texture, card size (w, h)].
static func bake(host: Node, mesh: Mesh) -> Array:
	var aabb := mesh.get_aabb()
	var w := maxf(aabb.size.x, aabb.size.z) * 1.04
	var h := (aabb.size.y + maxf(aabb.position.y, 0.0)) * 1.04
	if DisplayServer.get_name() == "headless":
		# Nothing is ever drawn headless (tests): a blank card, no waiting.
		var blank := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		return [ImageTexture.create_from_image(blank), Vector2(w, h)]
	var vp := SubViewport.new()
	vp.size = Vector2i(192, int(192.0 * h / maxf(w, 0.01)))
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	host.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(-0.7, 0.3, 0)
	key.light_energy = 0.55
	vp.add_child(key)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	vp.add_child(mi)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = h
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.position = Vector3(aabb.get_center().x, h * 0.5, aabb.get_center().z + 60.0)
	cam.far = 200.0
	vp.add_child(cam)
	cam.make_current()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	img.generate_mipmaps()
	return [ImageTexture.create_from_image(img), Vector2(w, h)]

static func material(tex: Texture2D) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("picture", tex)
	return m

static func card(size: Vector2, tex: Texture2D) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = size
	q.center_offset = Vector3(0, size.y * 0.5, 0)
	q.material = material(tex)
	return q
