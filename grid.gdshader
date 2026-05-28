shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;

uniform vec4 grid_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 sub_grid_color : source_color = vec4(0.0, 0.45, 0.75, 1.0);
uniform float grid_size = 1.0;
uniform float line_width = 8.0;
uniform float sub_grid_division = 4.0;
uniform float fade_distance = 900.0;
uniform float fade_sharpness = 0.9;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid(vec2 pos, float size, float width) {
	vec2 g = abs(fract(pos / size - 0.5) - 0.5) / fwidth(pos / size);
	float line = min(g.x, g.y);
	return 1.0 - smoothstep(0.0, width, line);
}

void fragment() {
	vec2 pos = world_pos.xz;
	
	float main_grid = grid(pos, grid_size, line_width);
	float sub_grid = grid(pos, grid_size / sub_grid_division, line_width * 0.6);
	
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float fade = pow(clamp(1.0 - dist / fade_distance, 0.0, 1.0), fade_sharpness);
	
	vec3 color = mix(sub_grid_color.rgb, grid_color.rgb, main_grid);
	float alpha = max(main_grid * grid_color.a, sub_grid * sub_grid_color.a) * fade;
	
	ALBEDO = color;
	ALPHA = alpha;
	EMISSION = EMISSION; // Subtle glow
}
