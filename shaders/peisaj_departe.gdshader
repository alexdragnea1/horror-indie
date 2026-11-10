// Dealurile și muntele din jurul blocului (peisaj_departe.gd). Fără ceața scenei (care le-ar înghiți complet la 60 m):
// își fac singure ceața „de departe”. Aproape (șesul de lângă curte) folosesc aceeași ceață ca scena, ca să nu se vadă
// unde se termină iarba; mai încolo se văd siluetele, tot mai șterse cu distanța, cu ceață lăsată în văi.
// Lumina e făcută de mână (un singur soare/lună, fațete plate, ca pe PS2); zăpada stă pe vârful muntelui.
shader_type spatial;
// Transparent spre depărtare: ceața lor e cerul adevărat din spatele lor (cu ceața volumetrică a scenei, care
// arată altfel lângă felinare și altfel în colțurile curții), nu o culoare măsurată. Inelele de teren sunt desenate
// din afară spre înăuntru (peisaj_departe.gd), ca transparența să iasă corect.
render_mode unshaded, fog_disabled, cull_back, depth_draw_always, blend_mix;

uniform vec3 culoare_baza : source_color = vec3(0.2, 0.18, 0.26);
uniform vec3 culoare_ceata : source_color = vec3(0.66, 0.44, 0.46);
// Spre ce culoare se pierd siluetele cele mai îndepărtate (cerul de la orizont).
uniform vec3 culoare_cer : source_color = vec3(0.66, 0.44, 0.46);
uniform vec3 culoare_lumina : source_color = vec3(1.0, 0.56, 0.3);
uniform vec3 directie_lumina = vec3(-1.0, 0.035, 0.32);
uniform float putere_lumina = 0.5;
// Ceața scenei, pentru șesul de aproape.
uniform float densitate_aproape = 0.018;
// Ceața de departe: cât de repede se șterg siluetele și cât de șterse pot ajunge (0..1).
uniform float densitate_departe = 0.0016;
uniform float ceata_max = 0.75;
// Ceața din văi: cât de groasă e jos și până la ce înălțime urcă (m).
uniform float ceata_vale = 0.6;
uniform float inaltime_ceata = 22.0;
uniform vec3 culoare_zapada : source_color = vec3(0.86, 0.86, 0.92);
uniform float inaltime_zapada = 190.0;
// Cât de luminoasă e zăpada (noaptea doar se ghicește).
uniform float lumina_zapada = 1.0;

varying vec3 poz;
varying vec3 normala;

void vertex() {
	poz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normala = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
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
	c = mix(c, cz, zapada);

	float d = length(poz - CAMERA_POSITION_WORLD);
	float aproape = 1.0 - exp(-d * densitate_aproape);
	float departe = ceata_max * (1.0 - exp(-d * densitate_departe));
	float vale = ceata_vale * exp(-max(poz.y, 0.0) / inaltime_ceata) * smoothstep(80.0, 400.0, d);
	// ceața din văi e opacă, în culoarea ceții de pe iarbă: poalele dealurilor se topesc în dunga de ceață de pe șes
	c = mix(c, culoare_ceata, vale);
	// aproape (șesul) e opac și se pierde în ceața scenei; mai încolo dealurile se lasă văzute prin cerul din spate
	float cat_aproape = 1.0 - smoothstep(100.0, 260.0, d);
	// transparent doar ce stă mai sus de ochi (are cer în spate); mai jos, în spate ar fi cerul de sub orizont (o
	// dungă luminoasă): acolo ceața e culoarea ei, opacă
	float pe_cer = smoothstep(CAMERA_POSITION_WORLD.y - 1.0, CAMERA_POSITION_WORLD.y + 8.0, poz.y);
	c = mix(c, culoare_ceata, departe * (1.0 - pe_cer));
	ALBEDO = mix(c, culoare_ceata, aproape * cat_aproape);
	ALPHA = mix(1.0 - departe * pe_cer, 1.0, cat_aproape);
}
