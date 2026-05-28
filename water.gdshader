shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 water_color : source_color = vec4(0.02, 0.25, 0.45, 0.55);
uniform float wave_speed : hint_range(0.0, 2.0) = 0.5;
uniform float wave_height : hint_range(0.0, 0.5) = 0.05;
uniform float wave_frequency : hint_range(0.0, 10.0) = 4.0;

void vertex() {
	vec2 uv = VERTEX.xz * 0.1;
	float time = TIME * wave_speed;
	float wave = sin(uv.x * wave_frequency + time) * cos(uv.y * wave_frequency + time * 0.7);
	VERTEX.y += wave * wave_height;
}

void fragment() {
	ALBEDO = water_color.rgb;
	METALLIC = 0.3;
	ROUGHNESS = 0.1;
	ALPHA = water_color.a;
}
