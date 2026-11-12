shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float crt_intensity : hint_range(0.0, 1.0) = 0.72;
uniform float scanline_count : hint_range(100.0, 900.0) = 420.0;
uniform float aberration_amount : hint_range(0.0, 0.006) = 0.0014;
uniform float vhs_noise_amount : hint_range(0.0, 0.08) = 0.018;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 curve_uv(vec2 uv) {
	vec2 centered = uv * 2.0 - 1.0;
	vec2 offset = centered.yx / 6.5;
	centered = centered + centered * offset * offset * crt_intensity;
	return centered * 0.5 + 0.5;
}

void fragment() {
	vec2 uv = curve_uv(SCREEN_UV);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.02, 0.02, 0.03, 1.0);
	} else {
		// Banda sutil de tracking VHS
		float vhs_band = smoothstep(0.985, 1.0, sin(uv.y * 5.0 + TIME * 1.4));
		float jitter = (hash(vec2(TIME, uv.y)) - 0.5) * 0.003 * vhs_band * crt_intensity;
		vec2 sample_uv = vec2(clamp(uv.x + jitter, 0.0, 1.0), uv.y);

		float shift = aberration_amount * crt_intensity;
		float r = texture(screen_texture, vec2(clamp(sample_uv.x + shift, 0.0, 1.0), sample_uv.y)).r;
		float g = texture(screen_texture, sample_uv).g;
		float b = texture(screen_texture, vec2(clamp(sample_uv.x - shift, 0.0, 1.0), sample_uv.y)).b;
		vec3 col = vec3(r, g, b);

		// Scanlines estilo monitor CRT analógico
		float scanline = sin(uv.y * scanline_count * 3.14159) * 0.075 * crt_intensity;
		col -= scanline;

		// Ruido magnético VHS sutil
		float grain = (hash(uv + vec2(TIME * 0.37, TIME * 0.13)) - 0.5) * vhs_noise_amount * crt_intensity;
		col += grain;

		// Viñeta de tubo de rayos catódicos
		vec2 vig_uv = uv * (1.0 - uv.yx);
		float vig = pow(max(vig_uv.x * vig_uv.y * 16.0, 0.0), 0.16 * crt_intensity);
		col *= mix(1.0, vig, crt_intensity);

		COLOR = vec4(col, 1.0);
	}
}
