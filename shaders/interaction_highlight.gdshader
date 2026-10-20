shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, specular_disabled;
// Overlay pass for the interaction target: a soft pulsing rim in the timeline accent colour.

uniform vec4 rim_color : source_color = vec4(0.894, 0.749, 0.498, 1.0);
uniform float strength = 0.55;

void fragment() {
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 2.2);
	float pulse = 0.75 + 0.25 * sin(TIME * 4.0);
	ALBEDO = rim_color.rgb * (rim * 0.85 + 0.12) * strength * pulse;
}
