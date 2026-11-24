shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float blur_radius : hint_range(0.0, 8.0) = 2.6;
uniform vec4 tint_color : source_color = vec4(0.06, 0.05, 0.13, 0.80);
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.45;
uniform float progress : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * blur_radius * progress;

	vec3 blurred = texture(screen_texture, SCREEN_UV).rgb * 0.24;
	blurred += texture(screen_texture, SCREEN_UV + vec2(px.x, 0.0)).rgb * 0.11;
	blurred += texture(screen_texture, SCREEN_UV - vec2(px.x, 0.0)).rgb * 0.11;
	blurred += texture(screen_texture, SCREEN_UV + vec2(0.0, px.y)).rgb * 0.11;
	blurred += texture(screen_texture, SCREEN_UV - vec2(0.0, px.y)).rgb * 0.11;
	blurred += texture(screen_texture, SCREEN_UV + vec2(px.x, px.y)).rgb * 0.08;
	blurred += texture(screen_texture, SCREEN_UV + vec2(-px.x, px.y)).rgb * 0.08;
	blurred += texture(screen_texture, SCREEN_UV + vec2(px.x, -px.y)).rgb * 0.08;
	blurred += texture(screen_texture, SCREEN_UV + vec2(-px.x, -px.y)).rgb * 0.08;

	vec2 centered = UV - vec2(0.5);
	float dist = length(centered * vec2(1.15, 1.0));
	float vig = smoothstep(0.32, 0.85, dist) * vignette_strength * progress;

	float tint_mix = clamp(tint_color.a * progress + vig * 0.35, 0.0, 0.94);
	vec3 col = mix(blurred, tint_color.rgb, tint_mix);
	col *= (1.0 - vig * 0.42);

	COLOR = vec4(col, progress);
}
