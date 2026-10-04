shader_type spatial;
// Unda de lumină care pleacă din cazan spre cer când vraja e gata (cazan.gd). Se pune pe un cilindru înalt,
// deschis la capete. Strălucește singură (nu o luminează nimic), se adună peste ce e în spate, nu o acoperă ceața,
// iar pe ea urcă dungi mai luminoase; jos e mai groasă și mai albă, sus se pierde.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec4 culoare : source_color = vec4(0.45, 1.0, 0.35, 1.0);
// 0 = stinsă, 1 = toată puterea
uniform float putere : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// marginile cilindrului (unde îl vezi pieziș) mai slabe decât mijlocul
	float mijloc = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);
	// dungi care urcă
	float dungi = 0.75 + 0.25 * sin(UV.y * 500.0 + TIME * 14.0);
	// jos tare, sus se stinge (pe CylinderMesh, UV.y = 0 sus și 1 jos)
	float jos = smoothstep(0.85, 1.0, UV.y);
	float sus = smoothstep(0.0, 0.6, UV.y);
	vec3 c = mix(culoare.rgb, vec3(1.0), 0.35 * jos);
	ALBEDO = c * mijloc * dungi * putere * (0.8 + 2.4 * jos) * sus;
}
