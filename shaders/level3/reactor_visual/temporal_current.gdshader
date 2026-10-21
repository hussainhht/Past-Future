shader_type spatial;
render_mode unshaded, shadows_disabled;
// Opaque current strips follow the actual pipe and ring meshes. No alpha overdraw.
uniform vec4 current_color : source_color = vec4(0.3, 0.9, 0.95, 1.0);
uniform float brightness = 0.5;
uniform float clock = 0.0;
uniform float flow_speed = 1.0;
varying vec3 conduit_position;
void vertex() { conduit_position = VERTEX; }
void fragment() {
	float around = atan(conduit_position.z, conduit_position.x);
	float distance_along = conduit_position.y * 6.0 + around * 4.0;
	float current = pow(0.5 + 0.5 * sin(distance_along - clock * flow_speed * 2.0), 5.0);
	ALBEDO = current_color.rgb * brightness * (0.48 + current * 0.52);
}
