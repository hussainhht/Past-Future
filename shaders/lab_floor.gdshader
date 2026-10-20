shader_type spatial;
render_mode diffuse_lambert_wrap, specular_disabled;
// Lab floor tiles, lit by the room. Past: clean tiles and a hazard ring painted around the
// temporal rift. Future: grime, cracked tiles (world-space Voronoi edges, densest where the room
// took damage) and a scorch around the rift whose cracks still glow violet.

uniform bool future = false;
// Signal Laboratory layout: the rift and the spots where the Future floor broke.
uniform vec2 rift_center = vec2(9.2, 2.3);
uniform vec4 damage_a = vec4(-1.9, -1.4, 3.2, 0.0);  // xz centre, radius: fallen ceiling panel
uniform vec4 damage_b = vec4(6.2, -6.4, 2.6, 0.0);   // in front of the security door
uniform vec4 damage_c = vec4(-9.6, 1.6, 3.4, 0.0);   // west wall breach

varying vec3 world_position;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Distance to the nearest Voronoi cell edge: thin dark lines read as cracks.
float crack_edges(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	float first = 8.0;
	float second = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			float d = length(offset + hash2(cell + offset) - local);
			if (d < first) {
				second = first;
				first = d;
			} else if (d < second) {
				second = d;
			}
		}
	}
	return second - first;
}

float damage(vec2 p, vec4 spot) {
	return 1.0 - smoothstep(spot.z * 0.35, spot.z, distance(p, spot.xy));
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cells = UV * vec2(16.0, 13.0);
	vec2 cell_uv = fract(cells);
	float grout = step(0.98, max(cell_uv.x, cell_uv.y));
	float checker = mod(floor(cells.x) + floor(cells.y), 2.0);
	vec3 base = future ? vec3(0.15, 0.24, 0.27) : vec3(0.34, 0.36, 0.29);
	base *= (1.0 + checker * 0.045) * (1.0 - grout * 0.30);
	vec2 p = world_position.xz;
	float rift = distance(p, rift_center);
	if (!future) {
		float ring = step(2.05, rift) * step(rift, 2.32);
		float stripe = step(0.5, fract((p.x + p.y) * 2.4));
		base = mix(base, mix(vec3(0.86, 0.66, 0.27), vec3(0.13, 0.12, 0.1), stripe), ring * 0.9);
	} else {
		float grime = smoothstep(0.45, 0.95, noise(p * 0.7) * 0.6 + noise(p * 3.1) * 0.4);
		base = mix(base, vec3(0.06, 0.09, 0.1), grime * 0.5);
		float near_rift = 1.0 - smoothstep(1.6, 5.0, rift);
		float broken = max(max(damage(p, damage_a), damage(p, damage_b)), max(damage(p, damage_c), near_rift));
		broken *= smoothstep(0.2, 0.55, noise(p * 0.9 + 3.7));
		float crack = (1.0 - smoothstep(0.0, 0.045, crack_edges(p * 1.25))) * broken;
		float scorch = 1.0 - smoothstep(1.3, 3.4, rift + (noise(p * 2.0) - 0.5) * 0.9);
		base = mix(base, vec3(0.035, 0.045, 0.07), scorch * 0.8);
		base *= 1.0 - crack * 0.75;
		EMISSION = vec3(0.55, 0.41, 0.76) * crack * near_rift * (0.7 + 0.3 * sin(TIME * 2.0 + rift * 3.0)) * 1.4;
	}
	ALBEDO = base;
	ROUGHNESS = 1.0;
}
