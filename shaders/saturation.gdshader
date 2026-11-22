shader_type canvas_item;

uniform float saturation : hint_range(0.0, 1.0) = 0.0; // 0 = grayscale, 1 = full color

varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114)); // luminance weights
	vec3 result = mix(vec3(gray), tex.rgb, saturation);
	COLOR = vec4(result, tex.a) * v_modulate;
}
