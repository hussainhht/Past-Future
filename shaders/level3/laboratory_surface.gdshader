shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;

// Opaque painted alloy. No textures, screen reads, transparency or bloom dependency.
uniform vec4 paint : source_color = vec4(0.4, 0.45, 0.4, 1.0);
uniform float aged = 0.0;
uniform float glow = 0.0;
uniform float flicker = 0.0;
uniform bool effects_enabled = true;
varying vec3 world_point;

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float grain = fract(sin(dot(floor(world_point * vec3(21.0, 17.0, 24.0)), vec3(12.9898, 78.233, 39.43))) * 43758.5453);
	float patina = smoothstep(0.28, 0.9, sin(world_point.x * 2.7 + sin(world_point.z * 1.7)) * 0.5 + 0.5);
	float edge = 1.0 - smoothstep(0.006, 0.027, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)));
	vec3 color = paint.rgb * (0.97 + grain * 0.045);
	color = mix(color, color * vec3(0.64, 0.70, 0.73), patina * aged * 0.35);
	ALBEDO = color + edge * (0.025 + aged * 0.012);
	ROUGHNESS = 0.83;
	METALLIC = 0.18;
	float level = 1.0;
	if (effects_enabled && flicker > 0.0) {
		// Gentle local auxiliary-light fluctuation; never a full off/on flash.
		level -= flicker * pow(0.5 + 0.5 * sin(TIME * 3.2 + world_point.x), 8.0) * 0.38;
	}
	EMISSION = paint.rgb * glow * level;
}
