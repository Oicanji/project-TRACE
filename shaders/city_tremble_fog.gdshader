shader_type canvas_item;

// Eerie white-fogged city trembling in the background (Project TRACE)
uniform float tremble_strength : hint_range(0.0, 0.015) = 0.0022;
uniform float tremble_speed : hint_range(0.0, 40.0) = 16.0;
uniform float fog_density : hint_range(0.0, 1.0) = 0.42;
uniform float fog_drift_speed : hint_range(0.0, 0.2) = 0.018;
uniform vec4 fog_color : source_color = vec4(0.87, 0.91, 0.92, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * noise(p);
		p *= 2.03;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	// Subtle unsettling micro-tremor that swells and subsides like a dying structure
	float pulse = 0.38 + 0.62 * pow(0.5 + 0.5 * sin(TIME * 0.65 + UV.x * 2.5), 2.0);
	float shake_x = (sin(TIME * tremble_speed + UV.y * 14.0) * 0.6 + sin(TIME * (tremble_speed * 1.73)) * 0.4) * tremble_strength * pulse;
	float shake_y = cos(TIME * (tremble_speed * 0.87) + UV.x * 9.0) * tremble_strength * 0.55 * pulse;

	vec2 uv = UV + vec2(shake_x, shake_y);
	vec4 tex = texture(TEXTURE, uv);

	// Billowing pale white fog washing across the distant city
	float f1 = fbm(vec2(UV.x * 3.5 + TIME * fog_drift_speed, UV.y * 2.4 - TIME * (fog_drift_speed * 0.25)));
	float f2 = fbm(vec2(UV.x * 6.5 - TIME * (fog_drift_speed * 1.4), UV.y * 4.0 + 3.7));
	float mist = mix(f1, f2, 0.45);

	// Heavier white haze near horizon and upper sky
	float height_mist = smoothstep(0.15, 0.95, UV.y) * 0.35 + (1.0 - smoothstep(0.0, 0.45, UV.y)) * 0.3;
	float fog_amt = clamp((mist * 0.72 + height_mist) * fog_density * 1.45, 0.0, 0.92);

	vec3 col = mix(tex.rgb, fog_color.rgb, fog_amt);
	COLOR = vec4(col, tex.a);
}
