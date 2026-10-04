shader_type canvas_item;
// Ecranul „de beat” (vezi scripts/efect_beat.gd): vedere dublă care se leagănă, imaginea se unduiește,
// culorile se încălzesc și marginile se întunecă în valuri. `putere` = 0 (treaz) .. 1 (mort de beat).
// Stă peste filtrul PS2 (CanvasLayer 1) și sub HUD (5), deci textul rămâne citibil.

uniform sampler2D ecran : hint_screen_texture, filter_nearest;
uniform float putere : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float t = TIME;
	vec2 uv = SCREEN_UV;
	// unduire lentă, ca și cum imaginea ar pluti
	uv.x += sin(uv.y * 7.0 + t * 1.9) * 0.006 * putere;
	uv.y += cos(uv.x * 5.0 + t * 1.3) * 0.004 * putere;
	// vederea dublă: a doua imagine fuge în lateral și revine
	vec2 dublura = vec2(sin(t * 1.1), cos(t * 0.7) * 0.4) * 0.018 * putere;
	vec3 a = texture(ecran, uv + dublura).rgb;
	vec3 b = texture(ecran, uv - dublura).rgb;
	vec3 c = mix(a, b, 0.5);
	// mai cald și puțin mai spălat
	c = mix(c, c * vec3(1.12, 0.98, 0.84) + vec3(0.03, 0.01, 0.0), putere);
	// marginile se întunecă în valuri (inima bate în urechi)
	float d = distance(SCREEN_UV, vec2(0.5));
	float puls = 0.55 + 0.15 * sin(t * 3.4);
	c *= 1.0 - smoothstep(puls - 0.25, puls + 0.25, d) * 0.6 * putere;
	COLOR = vec4(c, 1.0);
}
