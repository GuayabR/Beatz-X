shader_type canvas_item;

uniform float radius = 4.0;

void fragment() {
	vec2 texel = TEXTURE_PIXEL_SIZE * radius;
	vec3 col = vec3(0.0);

	col += texture(TEXTURE, UV).rgb * 0.227027;

	col += texture(TEXTURE, UV + vec2(texel.x, 0.0)).rgb * 0.1945946;
	col += texture(TEXTURE, UV - vec2(texel.x, 0.0)).rgb * 0.1945946;

	col += texture(TEXTURE, UV + vec2(0.0, texel.y)).rgb * 0.1945946;
	col += texture(TEXTURE, UV - vec2(0.0, texel.y)).rgb * 0.1945946;

	COLOR = vec4(col, 1.0);
}