shader_type canvas_item;

uniform float hue_offset : hint_range(0.0, 1.0) = 0.0; // 0-1 full rotation
uniform float brightness : hint_range(0.0, 2.0) = 1.0; // 1 = original, >1 = blend toward white, <1 = darken
uniform float red_threshold : hint_range(0.0, 1.0) = 0.4; // how red a pixel must be to recolor

vec3 rgb2hsv(vec3 c) {
	float cmax = max(max(c.r, c.g), c.b);
	float cmin = min(min(c.r, c.g), c.b);
	float delta = cmax - cmin;

	float h = 0.0;
	if (delta > 0.00001) {
		if (cmax == c.r) h = mod((c.g - c.b)/delta, 6.0);
		else if (cmax == c.g) h = ((c.b - c.r)/delta) + 2.0;
		else h = ((c.r - c.g)/delta) + 4.0;
		h /= 6.0;
		if (h < 0.0) h += 1.0;
	}

	float s = (cmax == 0.0) ? 0.0 : delta / cmax;
	float v = cmax;
	return vec3(h, s, v);
}

vec3 hsv2rgb(vec3 c) {
	float h = c.x * 6.0;
	float s = c.y;
	float v = c.z;

	float r=0.0, g=0.0, b=0.0;

	if (s < 0.0001) {
		r = g = b = v;
	} else {
		int i = int(floor(h));
		float f = h - float(i);
		float p = v * (1.0 - s);
		float q = v * (1.0 - s * f);
		float t = v * (1.0 - s * (1.0 - f));

		if(i==0){ r=v; g=t; b=p; }
		else if(i==1){ r=q; g=v; b=p; }
		else if(i==2){ r=p; g=v; b=t; }
		else if(i==3){ r=p; g=q; b=v; }
		else if(i==4){ r=t; g=p; b=v; }
		else { r=v; g=p; b=q; }
	}
	return vec3(r,g,b);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);

	// detect red pixels
	float is_red = tex.r - max(tex.g, tex.b);

	if (is_red > red_threshold) {
		// Convert to HSV
		vec3 hsv = rgb2hsv(tex.rgb);

		// Hue rotation
		hsv.x = mod(hsv.x + hue_offset, 1.0);

		// Convert back to RGB
		vec3 rgb = hsv2rgb(hsv);

		// Brightness: <1 darkens, >1 linearly blend toward white
		if (brightness <= 1.0) {
			rgb *= brightness; // darker
		} else {
			float t = brightness - 1.0; // 0-1
			rgb = mix(rgb, vec3(1.0), t); // blend toward white
		}

		COLOR = vec4(rgb, tex.a);
	} else {
		COLOR = tex; // non-red pixels stay untouched
	}
}