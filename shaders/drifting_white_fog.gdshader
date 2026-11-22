shader_type canvas_item;

// Heavy rolling volumetric pale-white fog layer
uniform vec4 fog_color : source_color = vec4(0.88, 0.92, 0.93, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.42;
uniform float speed_x : hint_range(-0.2, 0.2) = 0.022;
uniform float speed_y : hint_range(-0.1, 0.1) = -0.004;
uniform float scale_uv : hint_range(0.5, 10.0) = 2.6;
uniform float bottom_weight : hint_range(0.0, 1.0) = 0.65;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * noise(p);
		p *= 2.05;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 drift1 = vec2(TIME * speed_x, TIME * speed_y);
	vec2 drift2 = vec2(-TIME * speed_x * 0.65, TIME * speed_y * 1.3);

	float n1 = fbm(UV * scale_uv + drift1);
	float n2 = fbm(UV * (scale_uv * 1.85) + drift2 + vec2(4.2, 1.7));
	float cloud = smoothstep(0.24, 0.86, mix(n1, n2, 0.45));

	float vertical_grad = mix(1.0, smoothstep(0.05, 0.95, UV.y), bottom_weight);
	float alpha = cloud * vertical_grad * opacity;

	COLOR = vec4(fog_color.rgb, alpha);
}
