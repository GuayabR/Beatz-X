shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;

uniform float brightness : hint_range(0.0, 2.0) = 1.0;
uniform float contrast : hint_range(0.0, 2.0) = 1.0;
uniform float gamma : hint_range(0.1, 3.0) = 1.0;

uniform int colourblind_mode = 0;
uniform float colourblind_strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;

	vec4 col = texture(SCREEN_TEXTURE, uv);

	// prevent hard black if screen texture not ready
	col.rgb = max(col.rgb, vec3(0.001));

	// Brightness
	col.rgb *= brightness;

	// Contrast
	col.rgb = ((col.rgb - 0.5) * contrast) + 0.5;

	// Gamma
	col.rgb = pow(max(col.rgb, vec3(0.0)), vec3(1.0 / gamma));

	mat3 filter = mat3(
		vec3(1.0, 0.0, 0.0),
		vec3(0.0, 1.0, 0.0),
		vec3(0.0, 0.0, 1.0)
	);

	if (colourblind_mode == 1) {
		filter = mat3(
			vec3(0.625, 0.375, 0.0),
			vec3(0.700, 0.300, 0.0),
			vec3(0.000, 0.300, 0.700)
		);
	}
	else if (colourblind_mode == 2) {
		filter = mat3(
			vec3(0.567, 0.433, 0.0),
			vec3(0.558, 0.442, 0.0),
			vec3(0.000, 0.242, 0.758)
		);
	}
	else if (colourblind_mode == 3) {
		filter = mat3(
			vec3(0.950, 0.050, 0.0),
			vec3(0.000, 0.433, 0.567),
			vec3(0.000, 0.475, 0.525)
		);
	}

	vec3 cb = filter * col.rgb;

	col.rgb = mix(col.rgb, cb, colourblind_strength);

	COLOR = col;
}