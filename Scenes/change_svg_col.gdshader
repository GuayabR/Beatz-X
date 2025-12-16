shader_type canvas_item;

uniform vec4 tint_color : source_color;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// Keep alpha but replace color
	COLOR = vec4(tint_color.rgb, c.a * tint_color.a);
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
