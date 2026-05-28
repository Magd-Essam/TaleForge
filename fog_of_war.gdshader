shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform vec2  light_positions[8];
uniform float light_radii[8];
uniform int   light_count = 0;
uniform vec4  wall_segments[64];
uniform int   wall_count  = 0;
uniform vec4  fog_color : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform float feather      : hint_range(0.1, 5.0) = 1.5;
uniform float fog_darkness : hint_range(0.0, 1.0) = 0.95;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

bool segment_intersects(vec2 p, vec2 q, vec2 a, vec2 b) {
	vec2 r = q - p;
	vec2 s = b - a;
	float denom = r.x * s.y - r.y * s.x;
	if (abs(denom) < 0.0001) return false;
	float t = ((a.x - p.x) * s.y - (a.y - p.y) * s.x) / denom;
	float u = ((a.x - p.x) * r.y - (a.y - p.y) * r.x) / denom;
	return t >= 0.0 && t <= 1.0 && u >= 0.0 && u <= 1.0;
}

bool has_wall_between(vec2 from, vec2 to) {
	for (int i = 0; i < wall_count; i++) {
		vec2 wa = wall_segments[i].xy;
		vec2 wb = wall_segments[i].zw;
		if (segment_intersects(from, to, wa, wb)) return true;
	}
	return false;
}

void fragment() {
	vec2  world_xz   = vec2(world_pos.x, world_pos.z);
	float min_dist   = 999.0;
	bool  any_visible = false;

	for (int i = 0; i < light_count; i++) {
		vec2  lpos = light_positions[i];
		float r    = light_radii[i];
		float d    = distance(world_xz, lpos);
		if (d > r + feather) continue;
		if (!has_wall_between(lpos, world_xz)) {
			min_dist    = min(min_dist, d - r);
			any_visible = true;
		}
	}

	float alpha;
	if (any_visible) {
		alpha = smoothstep(-feather, feather * 0.3, min_dist) * fog_darkness;
	} else {
		alpha = fog_darkness;
	}

	ALBEDO = fog_color.rgb;
	ALPHA  = alpha;
}