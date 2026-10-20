shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;
// Painted low-poly look for environment props, shared by both timelines (see EnvPalette).
// Future ageing (grime, settled dust, darker low walls) is procedural in world space, so the same
// mesh and texture serve the intact lab and its ruin. GL Compatibility friendly: no extra passes.

uniform vec4 paint_color : source_color = vec4(1.0);
uniform bool use_texture = false;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform bool emission_from_texture = false;
// 0 = steady glow; 1 = broken flicker. Each object gets its own phase from its position.
uniform float flicker = 0.0;
uniform float age = 0.0;
uniform float desaturate = 0.0;
uniform vec4 grime_color : source_color = vec4(0.07, 0.1, 0.11, 1.0);

varying vec3 world_position;
varying vec3 object_origin;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	object_origin = MODEL_MATRIX[3].xyz;
}

void fragment() {
	vec3 texel = use_texture ? texture(albedo_texture, UV).rgb : vec3(1.0);
	vec3 base = paint_color.rgb * texel;
	float luma = dot(base, vec3(0.299, 0.587, 0.114));
	base = mix(base, vec3(luma), desaturate);
	if (age > 0.0) {
		float n = noise(world_position * 1.35) * 0.62 + noise(world_position * 5.3) * 0.38;
		float dirt = smoothstep(0.5, 0.95, n) * age;
		vec3 world_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		float up = clamp(world_normal.y, 0.0, 1.0);
		base = mix(base, grime_color.rgb, dirt * 0.55);
		base = mix(base, base * 0.7 + vec3(0.06, 0.07, 0.07), up * age * 0.4);
		base *= 1.0 - (1.0 - smoothstep(0.0, 1.4, world_position.y)) * 0.28 * age;
	}
	ALBEDO = base;
	ROUGHNESS = 1.0;
	if (emission_energy > 0.0) {
		float level = 1.0;
		if (flicker > 0.0) {
			float t = TIME * 6.0 + hash(floor(object_origin * 3.1)) * 40.0;
			float gate = step(0.32, noise(vec3(t, t * 0.37, 1.7)));
			level = mix(1.0, gate * (0.8 + 0.2 * sin(TIME * 37.0)), flicker);
		}
		vec3 glow = emission_color.rgb * emission_energy * level;
		EMISSION = emission_from_texture ? glow * texel : glow;
	}
}
