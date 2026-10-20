shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, specular_disabled, shadows_disabled;
// Temporal rift energy shell. Swirling cyan/violet bands with a bright fresnel rim; `fracture`
// breaks the bands into jagged cells and gaps (the Future rift). `burst` flashes on an echo lock.
// GL Compatibility friendly: one additive pass, value noise only.

uniform vec4 inner_color : source_color = vec4(0.525, 0.788, 0.82, 1.0);
uniform vec4 outer_color : source_color = vec4(0.549, 0.412, 0.757, 1.0);
uniform float intensity = 1.0;
uniform float fracture = 0.0;
uniform float burst = 0.0;
uniform float speed = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	float t = TIME * speed;
	vec2 uv = UV * vec2(6.0, 3.0);
	float swirl = noise(uv + vec2(t * 0.6, -t * 0.25)) * 0.6 + noise(uv * 2.3 - vec2(t * 0.9, t * 0.4)) * 0.4;
	float bands = 0.5 + 0.5 * sin((UV.y * 9.0 + swirl * 4.0 - t * 1.6) * 3.14159);
	// Fractured: break the bands into cells, some of which go dark (gaps in the shell).
	vec2 cell = floor(UV * vec2(14.0, 8.0) + vec2(floor(t * 2.0), 0.0));
	float shard = step(fracture * 0.55, hash(cell));
	float jag = mix(1.0, shard * (0.6 + 0.8 * noise(uv * 4.0 + t * 3.0)), fracture);
	float rim = pow(1.0 - clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 2.0);
	vec3 colour = mix(inner_color.rgb, outer_color.rgb, clamp(swirl + rim * 0.5, 0.0, 1.0));
	float glow = (bands * 0.35 + rim * 1.1) * jag * intensity;
	glow *= 0.8 + 0.2 * sin(TIME * 2.3);
	ALBEDO = colour * glow + vec3(0.8, 0.95, 1.0) * burst * (0.4 + rim);
}
