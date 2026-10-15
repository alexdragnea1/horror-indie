// Vopseaua de pe peretele cu graffiti (graffiti.gd): o placă subțire lipită de perete, cu desenul jucătorului.
// Pixelii nepictați (alfa 0) nu se desenează deloc (discard), deci peretele se vede prin ei, fără probleme de ordine.
// Pixeli mari, clari (filter_nearest), luminați ca peretele: noaptea se vede doar în lanternă și sub felinar.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_lambert, specular_disabled;

uniform sampler2D desen : source_color, filter_nearest;
// Vopseaua lucește puțin singură, cât s-o ghicești și pe întuneric (0 = deloc).
uniform float stralucire = 0.15;

void fragment() {
	vec4 c = texture(desen, UV);
	if (c.a < 0.5) {
		discard;
	}
	ALBEDO = c.rgb;
	EMISSION = c.rgb * stralucire;
}
