// Efectul pus peste tot ecranul (post-procesare):
// puține culori + dithering (punctulețele alea în gradient), vignetă și puțin "grăunte".
shader_type canvas_item;

uniform sampler2D ecran : hint_screen_texture, filter_nearest;
// Câte nuanțe pe canal de culoare. PS2 ~ 32; mai mic = mai "vechi".
uniform float nuante = 24.0;
uniform float putere_dither : hint_range(0.0, 2.0) = 1.0;
uniform float vigneta : hint_range(0.0, 1.0) = 0.5;
uniform float graunte : hint_range(0.0, 0.2) = 0.03;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

float zgomot(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(ecran, SCREEN_UV).rgb;

	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float prag = BAYER[p.y * 4 + p.x] / 16.0 - 0.5;
	c += prag * putere_dither / nuante;
	c = floor(c * nuante + 0.5) / nuante;

	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - dot(d, d) * vigneta * 2.0;
	c += (zgomot(FRAGCOORD.xy + fract(TIME) * 100.0) - 0.5) * graunte;

	COLOR = vec4(c, 1.0);
}
