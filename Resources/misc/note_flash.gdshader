shader_type canvas_item;

uniform vec4 tint_color : source_color;
uniform float mix_amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 blended = mix(tex.rgb, tint_color.rgb, mix_amount);
	COLOR = vec4(blended, tex.a);
}