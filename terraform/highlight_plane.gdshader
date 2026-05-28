shader_type spatial;

uniform vec4 highlight_color = vec4(0.0, 0.85, 1.0, 0.35);

render_mode unshaded, blend_mix, cull_back;

void fragment() {
    COLOR = highlight_color;
}
