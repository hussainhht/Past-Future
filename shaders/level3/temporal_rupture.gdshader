shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.24, 0.88, 1.0, 1.0);
uniform float clock = 0.0;
uniform float strength = 0.0;
uniform float reveal = 1.0;
uniform bool fissure = false;
void fragment() {
	float edge = pow(max(0.0, 1.0 - abs(UV.x * 2.0 - 1.0)), 2.0);
	float veins = 0.58 + 0.42 * sin(UV.y * 63.0 - clock * 3.0 + sin(UV.y * 21.0));
	float grow = 1.0 - smoothstep(reveal - 0.08, reveal + 0.02, UV.y);
	float filament = fissure ? edge : pow(edge, 4.0) + edge * veins * 0.38;
	vec3 color = mix(tint.rgb, vec3(0.8, 0.55, 1.0), UV.y);
	ALBEDO = color * filament * grow * strength;
}
