shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float blur_radius : hint_range(0.0, 10.0) = 4.0;

void fragment() {
	vec2 texel = SCREEN_PIXEL_SIZE * blur_radius;

	float w0 = 0.227027;
	float w1 = 0.1945946;
	float w2 = 0.1216216;
	float w3 = 0.054054;
	float w4 = 0.016216;

	vec3 col = texture(SCREEN_TEXTURE, SCREEN_UV).rgb * w0;

	col += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, texel.y) * 1.0).rgb * w1;
	col += texture(SCREEN_TEXTURE, SCREEN_UV - vec2(0.0, texel.y) * 1.0).rgb * w1;

	col += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, texel.y) * 2.0).rgb * w2;
	col += texture(SCREEN_TEXTURE, SCREEN_UV - vec2(0.0, texel.y) * 2.0).rgb * w2;

	col += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, texel.y) * 3.0).rgb * w3;
	col += texture(SCREEN_TEXTURE, SCREEN_UV - vec2(0.0, texel.y) * 3.0).rgb * w3;

	col += texture(SCREEN_TEXTURE, SCREEN_UV + vec2(0.0, texel.y) * 4.0).rgb * w4;
	col += texture(SCREEN_TEXTURE, SCREEN_UV - vec2(0.0, texel.y) * 4.0).rgb * w4;

	COLOR = vec4(col, 1.0);
}