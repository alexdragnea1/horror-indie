// Cerul la „blue hour” (după apus, înainte de noapte): albastru adânc sus, mai deschis spre orizont, o dungă caldă
// (piersică-roz) jos, acolo unde a apus soarele (`directie_apus`), primele stele doar sus și luna (`directie_luna`).
// Ceața (Environment.fog_sky_affect) îl acoperă doar puțin, ca să se vadă degradeul.
// Folosit în fața blocului seara (seara_bloc.gd) și la conac (conac.tscn).
shader_type sky;

uniform vec3 culoare_sus : source_color = vec3(0.03, 0.05, 0.18);
uniform vec3 culoare_mijloc : source_color = vec3(0.08, 0.15, 0.42);
uniform vec3 culoare_orizont : source_color = vec3(0.26, 0.36, 0.66);
uniform vec3 culoare_apus : source_color = vec3(0.66, 0.46, 0.5);
// Încotro a apus soarele (pe orizontală) și cât de tare se mai vede dunga caldă.
uniform vec3 directie_apus = vec3(-1.0, 0.0, 0.25);
uniform float putere_apus = 0.85;
uniform float densitate_stele = 0.014;
uniform float marime_celule = 110.0;
uniform float luminozitate_stele = 1.3;
uniform vec3 directie_luna = vec3(0.45, 0.32, -0.83);
uniform vec3 culoare_luna : source_color = vec3(0.86, 0.88, 0.95);
uniform float marime_luna = 0.03;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 d = EYEDIR;
	float h = clamp(d.y, 0.0, 1.0);
	vec3 c = mix(culoare_orizont, culoare_mijloc, smoothstep(0.0, 0.28, h));
	c = mix(c, culoare_sus, smoothstep(0.22, 0.95, h));
	// dunga caldă: jos pe cer, doar spre apus, largă
	vec2 plan = d.xz;
	if (length(plan) > 0.001) {
		float spre = max(dot(normalize(plan), normalize(directie_apus.xz)), 0.0);
		float jos = 1.0 - smoothstep(0.0, 0.32, h);
		c = mix(c, culoare_apus, pow(spre, 2.5) * jos * jos * putere_apus);
	}
	if (d.y > 0.0) {
		vec3 g = d * marime_celule;
		vec3 celula = floor(g);
		float r = hash(celula);
		if (r < densitate_stele) {
			vec3 centru = celula + vec3(hash(celula + 1.3), hash(celula + 2.7), hash(celula + 5.1)) * 0.6 + 0.2;
			float dist = length(g - centru);
			float sclipire = 0.55 + 0.45 * sin(TIME * (1.5 + r * 60.0) + r * 1000.0);
			float marime = 0.3 + 0.35 * hash(celula + 9.9);
			c += vec3(0.9, 0.93, 1.0) * smoothstep(marime, 0.0, dist) * luminozitate_stele * sclipire * smoothstep(0.3, 0.75, h);
		}
	}
	// luna (încă palidă: cerul e luminos), cu un halou slab
	float unghi = distance(d, normalize(directie_luna));
	c = mix(c, culoare_luna, smoothstep(marime_luna, marime_luna * 0.8, unghi) * 0.85);
	c += culoare_luna * 0.08 * smoothstep(marime_luna * 7.0, 0.0, unghi);
	COLOR = c;
}
