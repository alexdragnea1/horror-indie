// Cerul la apus (7:24 PM, în fața blocului după mesajul lui Head Witch, vezi apus_bloc.gd). Spre soare, de jos în sus:
// auriu → portocaliu → roz → violet → indigo; în partea opusă, „umbra pământului” (albastru-violet) jos și „centura lui
// Venus” (o dungă roz) deasupra ei. Soarele e un disc mare, turtit, pe jumătate sub orizont, cu un halou larg. Norii
// (dungi de altostratus care curg încet) sunt aprinși portocaliu dedesubt lângă soare, roz mai sus și mov-cenușii în
// partea cealaltă, cu marginea subțire de aur unde îi străbate soarele. Luceafărul (Venus) e singurul punct de pe cer.
shader_type sky;

// Încotro e soarele (y = cât de sus e deasupra orizontului; mic = la apus).
uniform vec3 directie_soare = vec3(-1.0, 0.03, 0.3);
uniform vec3 culoare_sus : source_color = vec3(0.12, 0.13, 0.36);
uniform vec3 culoare_violet : source_color = vec3(0.4, 0.25, 0.52);
uniform vec3 culoare_roz : source_color = vec3(0.93, 0.45, 0.52);
uniform vec3 culoare_portocaliu : source_color = vec3(1.0, 0.5, 0.2);
uniform vec3 culoare_auriu : source_color = vec3(1.0, 0.8, 0.42);
// Partea dinspre răsărit: jos umbra pământului, deasupra ei dunga roz.
uniform vec3 culoare_umbra_pamant : source_color = vec3(0.3, 0.31, 0.55);
uniform vec3 culoare_centura : source_color = vec3(0.86, 0.56, 0.68);
uniform vec3 culoare_soare : source_color = vec3(1.0, 0.6, 0.28);
uniform float marime_soare = 0.05;
uniform float halou_soare = 0.55;
// Norii: cât din cer acoperă (0..1), culorile lor și cât de repede curg.
uniform float acoperire_nori = 0.52;
uniform vec3 nori_aprinsi : source_color = vec3(1.0, 0.52, 0.3);
uniform vec3 nori_roz : source_color = vec3(0.92, 0.42, 0.58);
uniform vec3 nori_umbra : source_color = vec3(0.3, 0.2, 0.36);
uniform vec3 margine_aur : source_color = vec3(1.0, 0.85, 0.5);
uniform float viteza_nori = 0.006;
uniform vec3 directie_luceafar = vec3(-0.9, 0.24, 0.55);

// (hash12 al lui Dave Hoskins: cel vechi dădea gradienți aliniați pe colțuri vecine, deci linii drepte în nori)
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Zgomot cu gradienți (nu cu valori pe colțuri): fără muchiile drepte ale grilei, care făceau norii „bugați”
// (owner 17.11: așchii cu margini tăioase și dungi frânte). Interpolare de gradul 5, fără trepte în pantă.
vec2 gradient(vec2 i) {
	float u = hash(i) * 6.2831853;
	return vec2(cos(u), sin(u));
}

float zgomot(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 w = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(gradient(i), f);
	float b = dot(gradient(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(gradient(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(gradient(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return mix(mix(a, b, w.x), mix(c, d, w.x), w.y) * 0.75 + 0.5;  // ~0..1
}

// `straturi` = câte octave (mai puține spre orizont, unde detaliul fin s-ar strânge în pâlpâit). Fiecare octavă e
// rotită, ca să nu se alinieze nimic pe aceleași direcții.
float fbm(vec2 p, float straturi) {
	float s = 0.0;
	float a = 0.5;
	float total = 0.0;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 6; i++) {
		float k = clamp(straturi - float(i), 0.0, 1.0);
		s += zgomot(p) * a * k;
		total += a * k;
		p = rot * p * 2.02 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return s / max(total, 0.0001);
}

void sky() {
	vec3 d = EYEDIR;
	vec3 s = normalize(directie_soare);
	float h = max(d.y, 0.0);
	// cât de „spre soare” e direcția, pe orizontală (1 = spre soare, -1 = în spate)
	vec2 plan = length(d.xz) > 0.0001 ? normalize(d.xz) : vec2(0.0, 1.0);
	float spre = dot(plan, normalize(s.xz));
	float ks = spre * 0.5 + 0.5;

	// partea dinspre soare: benzile de culoare, de jos în sus
	vec3 c_soare = mix(culoare_auriu, culoare_portocaliu, smoothstep(0.0, 0.07, h));
	c_soare = mix(c_soare, culoare_roz, smoothstep(0.05, 0.2, h));
	c_soare = mix(c_soare, culoare_violet, smoothstep(0.16, 0.42, h));
	c_soare = mix(c_soare, culoare_sus, smoothstep(0.36, 0.9, h));
	// partea opusă: umbra pământului, centura roz, apoi același indigo sus
	vec3 c_opus = mix(culoare_umbra_pamant, culoare_centura, smoothstep(0.02, 0.11, h));
	c_opus = mix(c_opus, mix(culoare_violet, culoare_sus, 0.55), smoothstep(0.12, 0.32, h));
	c_opus = mix(c_opus, culoare_sus, smoothstep(0.3, 0.8, h));
	// jos, căldura se întinde de jur împrejur; sus rămâne doar spre soare
	float w = pow(ks, mix(0.9, 2.6, smoothstep(0.0, 0.3, h)));
	vec3 c = mix(c_opus, c_soare, w);

	// haloul soarelui (lumina împrăștiată în aer) și discul
	float g = max(dot(d, s), 0.0);
	c += culoare_soare * (pow(g, 6.0) * 0.28 + pow(g, 40.0) * 0.5) * halou_soare * 2.0;
	vec3 fata_de_soare = d - s;
	fata_de_soare.y *= 1.3;  // turtit de aer, cum se vede la orizont
	float disc = smoothstep(marime_soare, marime_soare * 0.82, length(fata_de_soare));
	c = mix(c, vec3(1.0, 0.86, 0.6) * 1.6, disc * smoothstep(-0.004, 0.006, d.y));

	// norii: proiectați pe un plafon, dungi întinse, care curg încet
	if (d.y > 0.0) {
		vec2 p = d.xz / (d.y + 0.12) * 0.5;
		// dungile de altostratus: întinse puțin pe o direcție, nu tăiate
		p = vec2(p.x * 0.7 + p.y * 0.15, p.y * 1.25);
		vec2 vant = vec2(TIME * viteza_nori, TIME * viteza_nori * 0.3);
		// spre orizont norii se strâng: acolo mai puține octave (altfel pâlpâie și se fac dungi frânte)
		float straturi = mix(2.5, 5.5, smoothstep(0.03, 0.35, d.y));
		float n = fbm(p + vant, straturi);
		float detaliu = fbm(p * 2.3 - vant * 1.5, straturi - 1.5);
		n = n * 0.82 + detaliu * 0.18;
		float prag = 1.0 - acoperire_nori;
		// margini moi (înainte 0,22: prea tăioase)
		// (+0,08: zgomotul cu gradienți e mai strâns în jurul lui 0,5 decât cel vechi; așa acoperă cam cât înainte)
		float nor = smoothstep(prag + 0.0, prag + 0.28, n);
		float gros = smoothstep(prag + 0.13, prag + 0.42, n);
		nor *= smoothstep(0.015, 0.14, d.y);
		// culoarea: mov-cenușiu în spate, roz deasupra, portocaliu aprins jos spre soare
		vec3 cn = mix(nori_umbra, nori_roz, smoothstep(-0.5, 0.5, spre) * (1.0 - smoothstep(0.55, 0.95, h) * 0.5));
		cn = mix(cn, nori_aprinsi, pow(max(spre, 0.0), 2.0) * (1.0 - smoothstep(0.08, 0.45, h)));
		cn *= mix(1.05, 0.72, gros);  // unde e gros, burta lui e mai întunecată
		// marginea subțire, luminată din spate, de lângă soare
		cn += margine_aur * (nor - gros) * pow(g, 5.0) * 1.4;
		c = mix(c, cn, nor * 0.92);
	}

	// luceafărul
	float l = distance(d, normalize(directie_luceafar));
	c += vec3(1.0, 0.95, 0.85) * smoothstep(0.004, 0.0, l) * 1.2;

	// sub orizont: ceața caldă a orașului
	c = mix(c, mix(culoare_portocaliu, culoare_umbra_pamant, 0.6) * 0.55, smoothstep(0.0, -0.08, d.y));
	COLOR = c;
}
