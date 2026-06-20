shader_type canvas_item;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// Compute brightness (luminance)
	float brightness = dot(tex.rgb, vec3(0.299, 0.587, 0.114));

	COLOR = vec4(tex.rgb, brightness);
}