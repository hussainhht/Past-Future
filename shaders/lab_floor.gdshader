shader_type spatial;
render_mode unshaded;

uniform bool future = false;

void fragment() {
	vec2 cells = UV * vec2(16.0, 13.0);
	vec2 cell_uv = fract(cells);
	float grout = step(0.98, max(cell_uv.x, cell_uv.y));
	float checker = mod(floor(cells.x) + floor(cells.y), 2.0);
	vec3 base = future ? vec3(0.15, 0.24, 0.27) : vec3(0.34, 0.36, 0.29);
	ALBEDO = base * (1.0 + checker * 0.045) * (1.0 - grout * 0.30);
}
