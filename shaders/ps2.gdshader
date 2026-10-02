// Materialul "de PS2" pentru tot ce e 3D în joc.
// Face trei lucruri care dau senzația de consolă veche:
//  1. vârfurile modelelor "sar" pe o grilă mică de pe ecran (tremurul ăla tipic)
//  2. texturile se deformează puțin când te uiți pieziș (affine mapping)
//  3. texturile nu sunt netezite (filter_nearest) -> pixeli mari, clari
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_lambert, specular_disabled;

uniform sampler2D textura : source_color, filter_nearest, repeat_enable;
uniform vec4 culoare : source_color = vec4(1.0);
uniform vec2 repetare_uv = vec2(1.0);
// Bifat = textura se pune după poziția în lume (bun pentru pereți/podele făcute din CSG,
// altfel se întinde pe pereții lungi). repetare_uv înseamnă atunci "de câte ori pe metru".
uniform bool uv_din_lume = false;
// Cât de fină e grila pe care sar vârfurile. Mai mic = tremură mai tare.
uniform float rezolutie_tremur = 160.0;
// 0 = texturi corecte, 1 = deformate ca pe PS1. 0.3 e un compromis de PS2.
uniform float deformare_textura : hint_range(0.0, 1.0) = 0.3;

varying vec3 uv_afin;

void vertex() {
	if (uv_din_lume) {
		vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 n = abs((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
		UV = n.y > max(n.x, n.z) ? p.xz : (n.x > n.z ? p.zy : p.xy);
		UV.y = -UV.y;
	}
	UV = UV * repetare_uv;
	vec4 clip = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec2 grila = vec2(rezolutie_tremur, rezolutie_tremur * VIEWPORT_SIZE.y / VIEWPORT_SIZE.x);
	clip.xy = round(clip.xy / clip.w * grila) / grila * clip.w;
	POSITION = clip;
	uv_afin = vec3(UV * clip.w, clip.w);
}

void fragment() {
	vec2 uv = mix(UV, uv_afin.xy / uv_afin.z, deformare_textura);
	ALBEDO = texture(textura, uv).rgb * culoare.rgb;
}
