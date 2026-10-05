// Materialul "de PS2" pentru tot ce e 3D în joc.
// Face trei lucruri care dau senzația de consolă veche:
//  1. vârfurile modelelor "sar" pe o grilă mică de pe ecran (tremurul ăla tipic)
//  2. texturile se deformează puțin când te uiți pieziș (affine mapping)
//  3. texturile nu sunt netezite (filter_nearest) -> pixeli mari, clari
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_lambert, specular_disabled;

// filter_nearest_mipmap: pixeli clari de aproape, dar de departe folosește versiuni
// mai mici ale texturii, altfel podeaua "fâlfâie" (moiré) când te miști.
uniform sampler2D textura : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 culoare : source_color = vec4(1.0);
uniform vec2 repetare_uv = vec2(1.0);
// Bifat = textura se pune după poziția în lume (bun pentru pereți/podele făcute din CSG,
// altfel se întinde pe pereții lungi). repetare_uv înseamnă atunci "de câte ori pe metru".
uniform bool uv_din_lume = false;
// Cât de fină e grila pe care sar vârfurile. Mai mic = tremură mai tare. 0 = deloc.
uniform float rezolutie_tremur = 0.0;
// 0 = texturi stabile, 1 = deformate ca pe PS1 (pe pereții mari din CSG arată foarte rău).
uniform float deformare_textura : hint_range(0.0, 1.0) = 0.0;

// Cât de tare „arde” obiectul singur (sticla becului). Se schimbă din cod, separat pe fiecare
// obiect, cu set_instance_shader_parameter("stralucire", ...). 0 = deloc.
instance uniform float stralucire = 0.0;

// Dispariția „pe pixeli”, ca la jocurile vechi (fără transparență adevărată, deci fără probleme de ordine):
// 0 = obiectul întreg, 1 = dispărut de tot. Pixelii pleacă după un model Bayer 4×4. Se schimbă din cod cu
// ModelPS2.disparitie(nod, valoare).
instance uniform float disparitie = 0.0;

// Metalul încins la roșu (ceaunul de acasă, înainte să explodeze; ceaun_acasa.gd): rgb = culoarea jarului,
// a = cât de încins (0..1). Se încinge de jos în sus, după înălțimea vârfului în model (originea = podeaua):
// la a = 0,5 arde doar fundul, la 1 tot ceaunul. Pete mai calde și mai reci, după textura de murdărie.
instance uniform vec4 incins = vec4(0.0);

varying vec3 uv_afin;
varying float inaltime_model;

void vertex() {
	if (uv_din_lume) {
		vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 n = abs((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
		UV = n.y > max(n.x, n.z) ? p.xz : (n.x > n.z ? p.zy : p.xy);
		UV.y = -UV.y;
	}
	UV = UV * repetare_uv;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	if (rezolutie_tremur > 0.0) {
		vec2 grila = vec2(rezolutie_tremur, rezolutie_tremur * VIEWPORT_SIZE.y / VIEWPORT_SIZE.x);
		clip.xy = round(clip.xy / clip.w * grila) / grila * clip.w;
	}
	inaltime_model = VERTEX.y;
	POSITION = clip;
	uv_afin = vec3(UV * clip.w, clip.w);
}

void fragment() {
	if (disparitie > 0.0) {
		ivec2 p = ivec2(FRAGCOORD.xy) % 4;
		int bayer[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
		if ((float(bayer[p.y * 4 + p.x]) + 0.5) / 16.0 < disparitie) {
			discard;
		}
	}
	vec2 uv = mix(UV, uv_afin.xy / uv_afin.z, deformare_textura);
	// COLOR = culorile vârfurilor din modelele făcute în Blender (albe la pereții din CSG).
	ALBEDO = texture(textura, uv).rgb * culoare.rgb * COLOR.rgb;
	EMISSION = ALBEDO * stralucire;
	if (incins.a > 0.0) {
		float jar = clamp(incins.a * 1.7 - inaltime_model * 1.3, 0.0, 1.0);
		jar *= mix(0.6, 1.25, texture(textura, uv * 3.0).r);
		ALBEDO = mix(ALBEDO, incins.rgb, jar * 0.6);
		EMISSION += incins.rgb * jar * jar * 3.0;
	}
}
