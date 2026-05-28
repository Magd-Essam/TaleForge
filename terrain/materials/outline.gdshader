shader_type spatial;
render_mode cull_front, unshaded;

uniform float outline_size : hint_range(0.0, 0.3) = 0.04;
uniform vec4 outline_color : source_color = vec4(1.0, 0.85, 0.0, 1.0);

void vertex() {
	VERTEX += NORMAL * outline_size;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}