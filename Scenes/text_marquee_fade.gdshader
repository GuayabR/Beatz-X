shader_type canvas_item;

uniform float left_edge = 0.0;
uniform float right_edge = 1.0;
uniform float fade_width = 0.01;
uniform bool fade_enabled = true;

void fragment() {
	if (fade_enabled) {
		float fade_in = smoothstep(left_edge, left_edge + fade_width, SCREEN_UV.x);
		float fade_out = 1.0 - smoothstep(right_edge - fade_width, right_edge, SCREEN_UV.x);
		COLOR.a *= fade_in * fade_out;
	}
}
