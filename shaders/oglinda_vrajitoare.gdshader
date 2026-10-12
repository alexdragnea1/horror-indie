shader_type spatial;
// Fața din oglinda dormitorului (oglinda_vrajitoare.gd): arată ce vede camera din lumea oglinzii, într-un oval,
// cu sticla care „curge” puțin și o apariție pe pixeli (ca `disparitie` din ps2.gdshader).
render_mode unshaded, cull_back, shadows_disabled;

uniform sampler2D vedere : source_color, filter_nearest;
// 0 = oglinda goală (nu se vede nimic din placă), 1 = fața de tot
uniform float vizibil = 0.0;

void fragment() {
	vec2 c = (UV - 0.5) * 2.0;
	float d = length(c);
	if (d > 0.97) {
		discard;
	}
	// apariția pe pixeli: fiecare pixel mare are pragul lui
	vec2 pix = floor(UV * 48.0);
	float prag = fract(sin(dot(pix, vec2(12.9898, 78.233))) * 43758.5453);
	if (prag > vizibil) {
		discard;
	}
	// sticla „curge” (mai tare cât fața abia se ivește)
	float unda = 0.006 + 0.012 * (1.0 - vizibil);
	vec2 uv = UV + vec2(sin(UV.y * 22.0 + TIME * 2.6), cos(UV.x * 19.0 + TIME * 2.1)) * unda;
	vec3 col = texture(vedere, uv).rgb;
	// marginea ovalului mai întunecată, ca adâncimea unei oglinzi vechi
	col *= 1.0 - 0.55 * smoothstep(0.55, 0.97, d);
	ALBEDO = col;
}
