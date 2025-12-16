shader_type canvas_item;

uniform float fade_width : hint_range(0.0, 0.5) = 0.08; // how wide to fade on edges
uniform float scroll_offset = 0.0; // will be set by script
uniform bool enable_scroll = false;

void fragment() {
	vec2 uv = UV;
	
	if (enable_scroll) {
		// Scroll UV horizontally
		uv.x = fract(uv.x + scroll_offset);
	}

	vec4 tex_color = texture(TEXTURE, uv);
	
	// Apply fade on left and right edges
	float fade_left = smoothstep(0.0, fade_width, UV.x);
	float fade_right = 1.0 - smoothstep(1.0 - fade_width, 1.0, UV.x);
	float fade = min(fade_left, fade_right);
	
	COLOR = tex_color * fade;
}
