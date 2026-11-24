// Cerul de noapte: albastru-negru, mai deschis la orizont, cu stele care sclipesc și luna
// (în direcția luminii DirectionalLight3D). Ceața îl acoperă cât vrea Environment.fog_sky_affect:
// în pădure aproape tot, pe platou deloc.
shader_type sky;

uniform vec3 culoare_sus : source_color = vec3(0.02, 0.025, 0.05);
uniform vec3 culoare_orizont : source_color = vec3(0.09, 0.1, 0.14);
// Câte stele: fracția de „celule” de pe cer care au o stea.
uniform float densitate_stele = 0.035;
// Cât de dese sunt celulele (mai mare = stele mai mici și mai multe).
uniform float marime_celule = 110.0;
uniform float luminozitate_stele = 2.4;
uniform vec3 culoare_luna : source_color = vec3(0.85, 0.88, 0.95);
uniform float marime_luna = 0.035;
// Steaua căzătoare (owner 24.11): o pornește stele_cazatoare.gd (pe platou), care alege de unde (`sc_start`) și
// încotro (`sc_dir`, tangent la cer) și mișcă `sc_progres` de la 0 la 1; sub 0 nu se desenează nimic.
uniform float sc_progres = -1.0;
uniform vec3 sc_start = vec3(0.0, 0.7, -0.7);
uniform vec3 sc_dir = vec3(1.0, -0.4, 0.0);
// Cât de lung e drumul ei pe cer (radiani), cât din el e coada, cât de tare strălucește.
uniform float drum_stele_cazatoare = 0.45;
uniform float coada_stele_cazatoare = 0.4;
uniform float luminozitate_stele_cazatoare = 2.4;
uniform vec3 culoare_stele_cazatoare : source_color = vec3(0.9, 0.95, 1.0);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Cât de tare luminează steaua căzătoare direcția `d` (0 = nu e pe acolo).
float stea_cazatoare(vec3 d) {
	float t = sc_progres;
	if (t < 0.0 || t > 1.0) {
		return 0.0;
	}
	vec3 a = normalize(sc_start);
	vec3 dir = normalize(sc_dir);
	vec3 cap = normalize(a + dir * drum_stele_cazatoare * t);
	vec3 coada = normalize(a + dir * drum_stele_cazatoare * max(t - coada_stele_cazatoare, 0.0));
	vec3 ab = cap - coada;
	float f = clamp(dot(d - coada, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
	float dist = length(d - (coada + ab * f));
	// miezul subțire (cât un pixel la 480×270) + o strălucire slabă; mai tare spre cap, se aprinde și se stinge
	float urma = smoothstep(0.006, 0.0015, dist) + 0.3 * smoothstep(0.02, 0.0, dist);
	return urma * f * f * sin(t * 3.1416);
}

void sky() {
	vec3 d = EYEDIR;
	float h = clamp(d.y, 0.0, 1.0);
	vec3 c = mix(culoare_orizont, culoare_sus, pow(h, 0.45));
	if (d.y > 0.0) {
		vec3 g = d * marime_celule;
		vec3 celula = floor(g);
		float r = hash(celula);
		if (r < densitate_stele) {
			vec3 centru = celula + vec3(hash(celula + 1.3), hash(celula + 2.7), hash(celula + 5.1)) * 0.6 + 0.2;
			float dist = length(g - centru);
			float sclipire = 0.55 + 0.45 * sin(TIME * (1.5 + r * 60.0) + r * 1000.0);
			float marime = 0.35 + 0.4 * hash(celula + 9.9);
			vec3 culoare = mix(vec3(1.0, 0.92, 0.8), vec3(0.8, 0.9, 1.0), hash(celula + 4.4));
			c += culoare * smoothstep(marime, 0.0, dist) * luminozitate_stele * sclipire * smoothstep(0.02, 0.2, h);
		}
		if (sc_progres >= 0.0) {
			c += culoare_stele_cazatoare * stea_cazatoare(d) * luminozitate_stele_cazatoare * smoothstep(0.0, 0.12, h);
		}
	}
	// luna, cu un halou slab
	vec3 spre_luna = LIGHT0_DIRECTION;
	float unghi = distance(d, spre_luna);
	c += culoare_luna * smoothstep(marime_luna, marime_luna * 0.8, unghi);
	c += culoare_luna * 0.12 * smoothstep(marime_luna * 8.0, 0.0, unghi);
	COLOR = c;
}
