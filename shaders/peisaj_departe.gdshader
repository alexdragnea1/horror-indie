// Dealurile și muntele din jurul blocului (peisaj_departe.gd), cu **ceața adevărată a scenei** (owner 10.11: „cum sunt
// blocurile de lângă, în ceață, au filtrul ăla, așa vreau să fie și dealurile și muntele”).
// Ceața scenei e foarte deasă (la 100 m nu se mai vede nimic), așa că pentru ceață fiecare vârf e adus pe raza lui
// de privire mai aproape de cameră, la `ceata_aproape`…`ceata_departe` m (cât blocurile din jur): pe ecran rămâne exact
// în același loc (e pe aceeași rază), dar primește ceața și ceața volumetrică a scenei ca un bloc de la distanța aceea —
// aceeași culoare peste tot, lângă felinare și în colțuri, și strălucirea spre soare de la apus. Adâncimea scrisă
// (DEPTH) e cea adevărată, ca dealurile să rămână în spatele blocurilor și al copacilor.
// Lumina e făcută de mână (un singur soare/lună, fațete plate, ca pe PS2); zăpada stă pe vârful muntelui.
shader_type spatial;
render_mode unshaded, cull_back, skip_vertex_transform;

uniform vec3 culoare_baza : source_color = vec3(0.2, 0.18, 0.2);
uniform vec3 culoare_lumina : source_color = vec3(1.0, 0.56, 0.3);
uniform vec3 directie_lumina = vec3(-1.0, 0.035, 0.32);
uniform float putere_lumina = 0.5;
uniform vec3 culoare_zapada : source_color = vec3(0.86, 0.86, 0.92);
uniform float inaltime_zapada = 190.0;
// Cât de luminoasă e zăpada (noaptea doar se ghicește).
uniform float lumina_zapada = 1.0;
// La ce distanță (m) „stă în ceață” ce e cel mai aproape (la `raza_aproape`) și ce e cel mai departe (la
// `raza_departe`); între ele crește lin.
uniform float ceata_aproape = 30.0;
uniform float ceata_departe = 60.0;
uniform float raza_aproape = 160.0;
uniform float raza_departe = 1700.0;
// Ceața din văi: cu cât mai jos, cu atât mai „departe” în ceață (m în plus la înălțimea 0).
uniform float ceata_vale = 22.0;
uniform float inaltime_ceata = 30.0;
// În plus pentru tot obiectul (turnul de antenă, mai pierdut în ceață).
uniform float ceata_extra = 0.0;

varying vec3 poz;
varying vec3 normala;
varying vec3 vedere_reala;

void vertex() {
	poz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normala = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vedere_reala = v;
	float r = length(v);
	float t = pow(clamp((r - raza_aproape) / (raza_departe - raza_aproape), 0.0, 1.0), 0.7);
	float d = mix(ceata_aproape, ceata_departe, t) + ceata_vale * exp(-max(poz.y, 0.0) / inaltime_ceata) + ceata_extra;
	// pe aceeași rază de privire, mai aproape: același loc pe ecran, altă ceață
	VERTEX = v * (min(d, r) / max(r, 0.001));
	NORMAL = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(normala);
	vec3 l = normalize(directie_lumina);
	float lam = max(dot(n, l), 0.0);
	// fața dinspre lumină se aprinde, cea din spate rămâne în culoarea serii
	vec3 c = culoare_baza * (0.75 + 0.25 * n.y) + culoare_lumina * lam * putere_lumina;
	// zăpada: sus, pe fețele nu prea abrupte; coboară în limbi pe văi (marginea zimțată de fațete)
	float limbi = sin(poz.x * 0.045 + poz.z * 0.02) * 28.0 + sin(poz.z * 0.11) * 12.0;
	float zapada = smoothstep(inaltime_zapada, inaltime_zapada + 30.0, poz.y + n.x * 14.0 + limbi) * smoothstep(0.3, 0.55, n.y);
	vec3 cz = culoare_zapada * (0.55 + 0.25 * n.y) * lumina_zapada + culoare_lumina * lam * (putere_lumina * 1.6);
	ALBEDO = mix(c, cz, zapada);
	// adâncimea adevărată (nu cea „din ceață”), ca să stea în spatele a tot ce e mai aproape
	vec4 clip = PROJECTION_MATRIX * vec4(vedere_reala, 1.0);
	DEPTH = clip.z / clip.w;
}
