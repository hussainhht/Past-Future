shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;
uniform vec4 paint_color : source_color = vec4(0.5, 0.6, 0.55, 1.0);
uniform float weathering = 0.0;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	float grain = sin(local_position.x * 67.0 + sin(local_position.z * 42.0)) * sin(local_position.y * 59.0);
	float stain = smoothstep(0.25, 0.85, sin(local_position.x * 4.8 + local_position.y * 3.0) * sin(local_position.z * 7.0));
	ALBEDO = paint_color.rgb * (0.96 + grain * 0.035) * (1.0 - stain * weathering * 0.42);
	ROUGHNESS = 0.88;
}
