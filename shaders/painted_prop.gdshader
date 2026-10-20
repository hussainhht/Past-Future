shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;
// Painted greybox furniture. Lit by the room's lights like the environment props, so lamps,
// screens and the Future emergency lights fall on it too. `age` adds the Future's world-space grime.

uniform vec4 paint_color : source_color = vec4(0.6, 0.65, 0.55, 1.0);
uniform float age = 0.0;
uniform vec4 grime_color : source_color = vec4(0.07, 0.1, 0.11, 1.0);
varying vec3 world_position;

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
}

void fragment() {
	vec3 base = paint_color.rgb;
	if (age > 0.0) {
		float n = noise(world_position * 1.6) * 0.6 + noise(world_position * 6.1) * 0.4;
		base = mix(base, grime_color.rgb, smoothstep(0.52, 0.9, n) * age * 0.6);
	}
	ALBEDO = base;
	ROUGHNESS = 1.0;
}
