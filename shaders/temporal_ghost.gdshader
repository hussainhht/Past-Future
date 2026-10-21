shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_back;

uniform vec3 echo_center = vec3(0.0);
uniform float echo_radius = 4.5;
uniform float opacity = 0.18;
uniform vec4 echo_color : source_color = vec4(0.40, 0.86, 0.94, 1.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 offset = world_position.xz - echo_center.xz;
	float distance_squared = dot(offset, offset);
	if (distance_squared >= echo_radius * echo_radius) { discard; }
	float distance_from_character = sqrt(distance_squared);
	float edge = 1.0 - smoothstep(echo_radius * 0.72, echo_radius, distance_from_character);
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float scan = 0.95 + 0.05 * sin(world_position.y * 36.0 - TIME * 1.4);
	ALBEDO = echo_color.rgb * (0.65 + rim * 0.65);
	ALPHA = edge * opacity * (0.38 + rim * 0.62) * scan;
}
