shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// One small additive shell; Compatibility-safe, no screen/depth textures or particles.
uniform vec4 primary_color : source_color = vec4(0.3, 0.9, 0.95, 1.0);
uniform vec4 secondary_color : source_color = vec4(0.65, 0.4, 0.95, 1.0);
uniform float clock = 0.0;
uniform float intensity = 0.5;
uniform float instability = 0.0;
uniform float flow_speed = 1.0;
void fragment() {
	float t = clock * flow_speed;
	float wave = sin(UV.y * 35.0 - t * 2.7 + sin(UV.x * 19.0 + t) * 1.8);
	float current = pow(max(0.0, wave), 7.0);
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.2);
	float filaments = pow(max(0.0, sin(UV.x * 58.0 + UV.y * 12.0 + t)), 18.0);
	float pulse = 0.9 + 0.1 * sin(clock * 1.7);
	vec3 color = mix(primary_color.rgb, secondary_color.rgb, 0.5 + 0.5 * sin(UV.y * 12.0 + t * 0.4));
	ALBEDO = color * (0.12 + current * 0.60 + rim * 0.75 + filaments * instability * 0.35) * intensity * pulse;
}
