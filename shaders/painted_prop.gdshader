shader_type spatial;
render_mode unshaded;

uniform vec4 paint_color : source_color = vec4(0.6, 0.65, 0.55, 1.0);
varying vec3 world_normal;

void vertex() {
	world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}

void fragment() {
	vec3 light_direction = normalize(vec3(-0.6, 1.0, 0.8));
	float face_tone = 0.65 + 0.35 * max(dot(normalize(world_normal), light_direction), 0.0);
	ALBEDO = paint_color.rgb * face_tone;
}
