shader_type spatial;
// Scutul de energie (atacul asupra conacului: scutul mov al lui Head Witch, scutul roșu al Warlock-ului). Se pune pe o
// sferă: strălucește singur (adunat peste ce e în spate), mai tare pe margini (unde îl vezi pieziș), cu o grilă de rune
// care curge; `lovit` = fulgerul unei lovituri (0..1), `crapat` = crăpăturile dinainte să se spargă.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec4 culoare : source_color = vec4(0.7, 0.45, 1.0, 1.0);
uniform float putere : hint_range(0.0, 2.0) = 1.0;
uniform float lovit : hint_range(0.0, 1.0) = 0.0;
uniform float crapat : hint_range(0.0, 1.0) = 0.0;

float zar(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float margine = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.2);
	vec2 uv = UV * vec2(56.0, 28.0);
	vec2 f = fract(uv) - 0.5;
	float grila = smoothstep(0.44, 0.5, max(abs(f.x), abs(f.y)));
	float unda = 0.4 + 0.6 * sin(UV.y * 36.0 - TIME * 5.0);
	// crăpăturile: celule la întâmplare care se aprind albe, tot mai multe
	float crapaturi = step(1.0 - crapat * 0.45, zar(floor(uv))) * max(grila, 0.35);
	// grila e slabă (din interior o vezi peste tot ecranul), marginea e partea care strălucește
	vec3 c = culoare.rgb * (margine * 1.6 + grila * 0.1 * unda + 0.03);
	c += vec3(1.0) * (lovit * (0.25 + margine) + crapaturi * 1.5);
	ALBEDO = c * putere;
}
