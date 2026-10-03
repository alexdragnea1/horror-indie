# Modelele de afară: blocul comunist, copacii de toamnă și ce e prin curte.
# Le apelează modele.py, dar merg și singure (mai repede, doar astea):
#   blender --background --factory-startup --python tools/blender/afara.py
# Axe Blender: Z în sus, fața modelului spre -Y (în Godot devine +Z). Originea = la sol.
import math
import os
import random
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, text, uneste, exporta, trunchi, inel  # noqa: E402

NEGRU = p("262d2f")
ALB = p("83b3b0")
BETON = p("70706e")
BETON_DESCHIS = p("7e8d87")
BETON_INCHIS = p("5e5356")
VERDE_VOPSIT = p("445d46")
SCOARTA = p("48313b")
CRENGI = p("553e4d")
GEAM = p("2a3c3d")
# frunzele: de la ruginiu la galben uscat
TOAMNA = [p("904a40"), p("a56850"), p("a18463"), p("7b383a"), p("7a7b59")]

# --- blocul: P+4, o scară la mijloc
LUNGIME, ADANCIME = 24.0, 10.0
SOCLU = 0.6  # subsolul care iese din pământ
ETAJ = 2.7
ETAJE = 5
ACOPERIS = SOCLU + ETAJE * ETAJ


def _fereastra(piese, lumini, r, x, z, lat, inalt, rama, aprinsa, gratii=False):
	"""Ramă care iese puțin din perete, geam în față și șprosul din mijloc.
	Geamurile aprinse merg în `lumini` (obiectul care strălucește în joc)."""
	piese.append(cub("Rama", (lat + 0.16, 0.07, inalt + 0.16), (x, -0.035, z), rama))
	piese.append(cub("Pervaz", (lat + 0.3, 0.2, 0.06), (x, -0.1, z - inalt / 2 - 0.1), BETON_DESCHIS))
	if aprinsa:
		lumini.append(cub("Geam", (lat, 0.01, inalt), (x, -0.075, z), aprinsa))
		if r.random() < 0.6:  # perdea trasă pe jumătate
			parte = r.choice((-1, 1))
			piese.append(cub("Perdea", (lat * 0.45, 0.012, inalt), (x + parte * lat * 0.27, -0.082, z),
				r.choice((p("655269"), p("904a40"), p("5e363e")))))
	else:
		piese.append(cub("Geam", (lat, 0.01, inalt), (x, -0.075, z), r.choice((GEAM, NEGRU, GEAM))))
	piese.append(cub("Sprosul", (0.05, 0.02, inalt), (x, -0.09, z), rama))
	if gratii:
		for i in range(5):
			piese.append(cub("Gratie", (0.025, 0.025, inalt + 0.1), (x - lat / 2 + lat * (i + 0.5) / 5, -0.16, z), NEGRU))
		piese.append(cub("Gratie", (lat + 0.1, 0.025, 0.03), (x, -0.16, z + inalt / 2 - 0.05), NEGRU))


def _balcon(piese, lumini, r, x, z):
	"""Balcon cu placă de beton și parapet; unele sunt închise cu geam (cum fac oamenii)."""
	lat, ies = 3.0, 1.15
	piese.append(cub("Placa balcon", (lat, ies, 0.14), (x, -ies / 2, z), BETON_DESCHIS))
	culoare = r.choice((VERDE_VOPSIT, p("7b383a"), BETON, p("295555"), BETON))
	piese.append(cub("Parapet", (lat, 0.08, 0.95), (x, -ies + 0.04, z + 0.55), culoare))
	for s in (-1, 1):
		piese.append(cub("Parapet lateral", (0.08, ies, 0.95), (x + s * (lat / 2 - 0.04), -ies / 2, z + 0.55), culoare))
	inchis = r.random() < 0.5
	if inchis:  # tâmplărie pusă de proprietar, deasupra parapetului
		rama = r.choice((ALB, BETON_DESCHIS, p("5e363e")))
		piese.append(cub("Tamplarie", (lat, 0.06, 0.08), (x, -ies + 0.04, z + 2.5), rama))
		for i in range(4):
			xi = x - lat / 2 + lat * (i + 0.5) / 4
			geam = r.choice((GEAM, GEAM, NEGRU))
			piese.append(cub("Geam balcon", (lat / 4 - 0.06, 0.02, 1.3), (xi, -ies + 0.03, z + 1.75), geam))
			piese.append(cub("Montant", (0.05, 0.07, 1.42), (x - lat / 2 + lat * i / 4, -ies + 0.04, z + 1.75), rama))
		piese.append(cub("Montant", (0.05, 0.07, 1.42), (x + lat / 2, -ies + 0.04, z + 1.75), rama))
	else:
		# ușa și geamul balconului, în perete
		aprinsa = p("a18463") if r.random() < 0.3 else None
		_fereastra(piese, lumini, r, x - 0.5, z + 1.25, 0.8, 2.1, ALB, aprinsa)
		_fereastra(piese, lumini, r, x + 0.65, z + 1.6, 1.1, 1.3, ALB, aprinsa)
		if r.random() < 0.6:  # rufe întinse la uscat
			piese.append(cub("Sfoara", (lat - 0.2, 0.01, 0.01), (x, -ies + 0.25, z + 2.2), NEGRU))
			for i in range(r.randint(3, 6)):
				xi = x - 1.2 + i * 0.45 + r.uniform(-0.05, 0.05)
				h = r.uniform(0.3, 0.6)
				piese.append(cub("Rufe", (r.uniform(0.25, 0.4), 0.02, h), (xi, -ies + 0.25, z + 2.2 - h / 2),
					r.choice((p("655269"), p("904a40"), p("438b88"), ALB, p("a18463")))))
	if r.random() < 0.45:  # antenă de satelit prinsă de parapet
		ob = cilindru("Antena satelit", 0.3, 0.22, 0.08, (x + 1.0, -ies - 0.15, z + 1.25), ALB, laturi=10,
			rot=(1.2, 0, r.uniform(-0.4, 0.4)))
		piese.append(ob)
		piese.append(os_intre("Brat antena", (x + 1.0, -ies - 0.15, z + 1.25), (x + 1.0, -ies - 0.45, z + 1.1), 0.015, NEGRU))


def bloc(cale):
	"""Bloc de panouri P+4, lung de 24 m, cu scara B la mijloc. Fațada (cu intrarea) e spre -Y.
	Geamurile aprinse sunt un obiect separat, „Lumini”, care strălucește în joc."""
	curata()
	r = random.Random(1979)
	piese, lumini = [], []
	piese += [
		cub("Corp", (LUNGIME, ADANCIME, ACOPERIS + 0.4), (0, ADANCIME / 2, (ACOPERIS + 0.4) / 2), BETON),
		cub("Soclu", (LUNGIME + 0.1, ADANCIME + 0.1, SOCLU), (0, ADANCIME / 2, SOCLU / 2), BETON_INCHIS),
		cub("Atic", (LUNGIME + 0.2, ADANCIME + 0.2, 0.18), (0, ADANCIME / 2, ACOPERIS + 0.45), BETON_INCHIS),
		cub("Iesire acoperis", (3.0, 3.0, 2.2), (0, 4.0, ACOPERIS + 1.1), BETON),
	]
	# antene TV vechi pe acoperiș: se văd în ceață ca niște schelete
	for x in (-8.0, -3.0, 5.5, 9.0):
		y = r.uniform(2, 8)
		piese.append(cub("Stalp antena", (0.04, 0.04, 2.2), (x, y, ACOPERIS + 1.5), NEGRU))
		for i in range(4):
			lung = 1.2 - i * 0.2
			piese.append(cub("Bara antena", (lung, 0.03, 0.03), (x, y, ACOPERIS + 2.4 - i * 0.25), NEGRU, rot=(0, 0, 0.3)))
	# benzile dintre etaje și rosturile dintre panouri (pe fațadă și pe spate)
	for fata, y in ((-1, -0.02), (1, ADANCIME + 0.02)):
		for i in range(1, ETAJE + 1):
			piese.append(cub("Banda etaj", (LUNGIME + 0.04, 0.05, 0.12), (0, y, SOCLU + i * ETAJ), p("6f6d7f")))
		for i in range(1, 8):
			piese.append(cub("Rost", (0.04, 0.03, ACOPERIS - SOCLU), (-LUNGIME / 2 + i * 3, y, SOCLU + (ACOPERIS - SOCLU) / 2), BETON_INCHIS))
	# pereții laterali: rosturi și câte o fereastră mică de baie pe etaj
	for s in (-1, 1):
		x = s * (LUNGIME / 2 + 0.02)
		for i in range(1, 4):
			piese.append(cub("Rost", (0.03, 0.04, ACOPERIS - SOCLU), (x, i * 2.5, SOCLU + (ACOPERIS - SOCLU) / 2), BETON_INCHIS))
	# burlane la colțuri
	for x in (-LUNGIME / 2 + 0.15, LUNGIME / 2 - 0.15):
		piese.append(cilindru("Burlan", 0.06, 0.06, ACOPERIS + 0.4, (x, -0.12, (ACOPERIS + 0.4) / 2), BETON_INCHIS, laturi=6))
	# geamurile de la subsol
	for x in (-10.5, -7.5, -4.5, 4.5, 7.5, 10.5):
		piese.append(cub("Geam subsol", (0.6, 0.04, 0.25), (x, -0.06, 0.32), NEGRU))

	coloane = (-10.5, -7.5, -4.5, 4.5, 7.5, 10.5)
	balcoane = (-7.5, 7.5)
	for etaj in range(ETAJE):
		z0 = SOCLU + etaj * ETAJ
		for x in coloane:
			if x in balcoane and etaj > 0:
				_balcon(piese, lumini, r, x, z0)
				continue
			sansa = 0.22 if etaj > 0 else 0.1
			aprinsa = None
			if r.random() < sansa:
				aprinsa = r.choice((p("a18463"), p("a18463"), p("a56850"), p("438b88")))
			rama = r.choice((ALB, ALB, BETON_DESCHIS, p("5e363e")))
			_fereastra(piese, lumini, r, x, z0 + 1.45, 1.3, 1.35, rama, aprinsa, gratii=(etaj == 0))
			# urme de rugină și apă sub pervaz
			if r.random() < 0.35:
				lung = r.uniform(0.6, 1.4)
				piese.append(cub("Pata", (r.uniform(0.15, 0.4), 0.012, lung), (x + r.uniform(-0.4, 0.4), -0.008, z0 + 0.65 - lung / 2), BETON_INCHIS))
			# aparat de aer condiționat lângă geam
			if etaj > 0 and r.random() < 0.3:
				ax = x + r.choice((-1, 1)) * 1.05
				piese.append(cub("Aer conditionat", (0.75, 0.3, 0.5), (ax, -0.17, z0 + 1.0), ALB))
				piese.append(cub("Grila", (0.5, 0.02, 0.4), (ax - 0.08, -0.33, z0 + 1.0), BETON))
				piese.append(cub("Pata AC", (0.12, 0.012, 1.0), (ax + 0.2, -0.008, z0 + 0.3), BETON_INCHIS))
	# geamurile scării: înguste, la jumătatea dintre etaje
	for etaj in range(1, ETAJE):
		z = SOCLU + (etaj + 0.5) * ETAJ
		aprinsa = p("a18463") if etaj == 2 else None
		_fereastra(piese, lumini, r, 0, z, 0.9, 1.5, BETON_DESCHIS, aprinsa)

	# intrarea: podest cu trepte, copertină, ușă metalică dublă, interfon, plăcuțe
	piese += [
		cub("Podest", (2.8, 1.4, 0.45), (0, -0.7, 0.225), BETON),
		cub("Treapta", (2.8, 0.35, 0.3), (0, -1.575, 0.15), BETON),
		cub("Treapta", (2.8, 0.35, 0.15), (0, -1.925, 0.075), BETON),
		cub("Copertina", (3.2, 1.7, 0.16), (0, -0.85, 3.05), BETON_DESCHIS),
		cub("Toc usa bloc", (1.7, 0.1, 2.4), (0, -0.05, 0.45 + 1.2), BETON_INCHIS),
	]
	for s in (-1, 1):  # cele două canaturi
		x = s * 0.39
		piese += [
			cub("Usa bloc", (0.74, 0.06, 2.2), (x, -0.11, 1.55), VERDE_VOPSIT),
			cub("Geam usa bloc", (0.5, 0.02, 0.9), (x, -0.145, 2.05), GEAM),
			cub("Tabla jos", (0.6, 0.02, 0.6), (x, -0.145, 0.95), p("32453b")),
			cub("Maner", (0.04, 0.06, 0.25), (x - s * 0.28, -0.18, 1.5), BETON_DESCHIS),
		]
		for i in range(3):  # plasa de sârmă din geam
			piese.append(cub("Plasa", (0.5, 0.025, 0.02), (x, -0.155, 1.75 + i * 0.3), NEGRU))
	piese += [
		cub("Interfon", (0.22, 0.05, 0.35), (1.1, -0.05, 1.6), p("6f6d7f")),
		cub("Ecran interfon", (0.14, 0.02, 0.06), (1.1, -0.08, 1.72), NEGRU),
		cub("Placuta scara", (0.5, 0.03, 0.3), (0, -0.12, 2.82), p("295555")),
		text("Text scara", "SC. B", (0, -0.14, 2.82), 0.16, ALB),
		cub("Placuta bloc", (0.7, 0.03, 0.4), (-LUNGIME / 2 + 0.8, -0.04, 3.2), p("295555")),
		text("Text bloc", "BL. M7", (-LUNGIME / 2 + 0.8, -0.06, 3.2), 0.18, ALB),
		cub("Cutie bec", (0.2, 0.15, 0.08), (0, -0.25, 2.93), NEGRU),
	]
	for i in range(3):
		for j in range(4):
			piese.append(cub("Buton", (0.03, 0.02, 0.03), (1.05 + i * 0.05, -0.08, 1.6 - j * 0.045), BETON_DESCHIS))
	lumini.append(sfera("Bec scara", 0.06, (0, -0.25, 2.86), p("a18463"), segmente=6, inele=4))
	uneste(piese, "Bloc")
	uneste(lumini, "Lumini")
	exporta(os.path.join(cale, "bloc.glb"))


def _coroana(piese, r, centru, raza, culori, bucati):
	"""Coroana: bulgări de frunze cu fețe mari, fiecare cu altă nuanță de toamnă."""
	for _ in range(bucati):
		u = r.uniform(0, math.tau)
		d = r.uniform(0.2, 0.8) * raza
		loc = (centru[0] + math.cos(u) * d, centru[1] + math.sin(u) * d, centru[2] + r.uniform(-0.5, 0.6) * raza)
		rr = r.uniform(0.45, 0.7) * raza
		piese.append(sfera("Frunze", rr, loc, r.choice(culori), segmente=6, inele=4,
			scara=(1, r.uniform(0.85, 1.15), r.uniform(0.7, 0.9))))


def copac(cale, nume, saminta, inaltime, culori, bucati=9):
	"""Copac de toamnă: trunchi strâmb, câteva crengi groase și o coroană din bulgări de frunze."""
	curata()
	r = random.Random(saminta)
	varf = (r.uniform(-0.25, 0.25), r.uniform(-0.25, 0.25), inaltime * 0.55)
	piese = [
		os_intre("Trunchi", (0, 0, -0.1), varf, 0.17, SCOARTA, laturi=7),
		cilindru("Radacini", 0.32, 0.17, 0.3, (0, 0, 0.1), SCOARTA, laturi=7),
	]
	capete = []
	for i in range(5):
		u = i * math.tau / 5 + r.uniform(-0.3, 0.3)
		lung = r.uniform(0.9, 1.5)
		start = (varf[0] * 0.8, varf[1] * 0.8, varf[2] * r.uniform(0.75, 1.0))
		cap = (start[0] + math.cos(u) * lung, start[1] + math.sin(u) * lung, start[2] + r.uniform(0.8, 1.5))
		piese.append(os_intre("Creanga", start, cap, 0.07, CRENGI, laturi=5))
		capete.append(cap)
	centru = (varf[0], varf[1], inaltime * 0.78)
	_coroana(piese, r, centru, inaltime * 0.28, culori, bucati)
	for cap in capete[:3]:  # bulgări mai mici la capătul crengilor, ca să nu fie o minge perfectă
		_coroana(piese, r, cap, 0.7, culori, 1)
	uneste(piese, "Copac")
	exporta(os.path.join(cale, nume + ".glb"))


def copac_gol(cale):
	"""Copac aproape fără frunze: crengi negre, întortocheate, cu câteva frunze care au rămas."""
	curata()
	r = random.Random(13)
	piese = [
		os_intre("Trunchi", (0, 0, -0.1), (0.3, 0.1, 3.0), 0.15, SCOARTA, laturi=6),
		cilindru("Radacini", 0.3, 0.15, 0.3, (0, 0, 0.1), SCOARTA, laturi=6),
	]

	def ramura(start, directie, lung, raza, nivel):
		cap = (start[0] + directie[0] * lung, start[1] + directie[1] * lung, start[2] + directie[2] * lung)
		piese.append(os_intre("Creanga", start, cap, raza, CRENGI if nivel else SCOARTA, laturi=4))
		if nivel >= 3:
			if r.random() < 0.3:
				piese.append(sfera("Frunze ramase", 0.18, cap, r.choice(TOAMNA), segmente=5, inele=3))
			return
		for _ in range(2):
			d = (directie[0] + r.uniform(-0.7, 0.7), directie[1] + r.uniform(-0.7, 0.7), directie[2] + r.uniform(-0.1, 0.5))
			n = math.sqrt(sum(c * c for c in d))
			ramura(cap, tuple(c / n for c in d), lung * 0.68, raza * 0.6, nivel + 1)

	for i in range(4):
		u = i * math.tau / 4 + 0.4
		ramura((0.3, 0.1, 2.6 + i * 0.15), (math.cos(u) * 0.7, math.sin(u) * 0.7, 0.7), 1.3, 0.08, 0)
	uneste(piese, "CopacGol")
	exporta(os.path.join(cale, "copac_gol.glb"))


def frunze_jos(cale, nume, saminta, raza, numar):
	"""Frunze căzute, împrăștiate pe jos în jurul unui copac (mai dese spre mijloc)."""
	curata()
	r = random.Random(saminta)
	piese = []
	for _ in range(numar):
		u = r.uniform(0, math.tau)
		d = raza * math.sqrt(r.random()) * r.uniform(0.4, 1.0)
		piese.append(cub("Frunza", (r.uniform(0.09, 0.15), r.uniform(0.06, 0.1), 0.006),
			(math.cos(u) * d, math.sin(u) * d, 0.006 + r.uniform(0, 0.01)), r.choice(TOAMNA),
			rot=(r.uniform(-0.15, 0.15), r.uniform(-0.15, 0.15), r.uniform(0, math.tau))))
	uneste(piese, "Frunze")
	exporta(os.path.join(cale, nume + ".glb"))


def gramada_frunze(cale):
	"""Grămadă de frunze strânse de administrator, cu grebla rezemată de ea."""
	curata()
	r = random.Random(5)
	piese = [sfera("Movila", 0.7, (0, 0, -0.15), p("904a40"), segmente=8, inele=5, scara=(1, 0.8, 0.5))]
	for _ in range(60):
		u = r.uniform(0, math.tau)
		d = r.uniform(0, 0.75)
		z = max(0.0, 0.2 * (1 - (d / 0.75) ** 2)) + 0.01
		piese.append(cub("Frunza", (0.12, 0.08, 0.008), (math.cos(u) * d, math.sin(u) * d * 0.8, z), r.choice(TOAMNA),
			rot=(r.uniform(-0.4, 0.4), r.uniform(-0.4, 0.4), r.uniform(0, math.tau))))
	piese.append(os_intre("Coada grebla", (0.55, -0.1, 0.0), (1.0, -0.2, 1.4), 0.018, p("a56850"), laturi=5))
	piese.append(cub("Grebla", (0.45, 0.04, 0.04), (0.55, -0.1, 0.02), NEGRU, rot=(0, 0, 0.2)))
	for i in range(7):
		piese.append(cub("Dinte", (0.012, 0.012, 0.08), (0.35 + i * 0.065, -0.06 + i * 0.013, 0.03), NEGRU))
	uneste(piese, "Gramada")
	exporta(os.path.join(cale, "gramada_frunze.glb"))


def banca(cale):
	"""Bancă de parc: picioare de beton și scânduri vopsite verde, cojite. Lungă pe X, șezutul spre -Y."""
	curata()
	piese = []
	for x in (-0.75, 0.75):
		piese += [
			cub("Picior", (0.12, 0.5, 0.42), (x, 0, 0.21), BETON),
			cub("Spatar suport", (0.1, 0.08, 0.5), (x, 0.24, 0.65), BETON, rot=(-0.2, 0, 0)),
		]
	for i in range(3):
		piese.append(cub("Scandura", (1.8, 0.13, 0.04), (0, -0.18 + i * 0.16, 0.44), VERDE_VOPSIT))
	for i in range(2):
		piese.append(cub("Scandura spatar", (1.8, 0.04, 0.13), (0, 0.27 + i * 0.03, 0.62 + i * 0.17), VERDE_VOPSIT, rot=(-0.2, 0, 0)))
	# unde s-a cojit vopseaua și „scrijelitura”
	piese += [
		cub("Cojit", (0.3, 0.135, 0.042), (0.4, -0.02, 0.44), p("7a7b59")),
		cub("Cojit", (0.2, 0.042, 0.135), (-0.5, 0.27, 0.62), p("7a7b59"), rot=(-0.2, 0, 0)),
		cub("Scrijelit", (0.35, 0.044, 0.02), (0.1, 0.268, 0.64), p("48313b"), rot=(-0.2, 0, 0)),
	]
	uneste(piese, "Banca")
	exporta(os.path.join(cale, "banca.glb"))


def stalp(cale):
	"""Stâlp de beton cu lampă de stradă pe braț (spre -Y). Sticla e separată, ca să pâlpâie."""
	curata()
	piese = [
		cilindru("Stalp", 0.14, 0.08, 6.4, (0, 0, 3.2), BETON_DESCHIS, laturi=6),
		cilindru("Baza", 0.2, 0.17, 0.4, (0, 0, 0.2), BETON, laturi=6),
		os_intre("Brat", (0, 0, 6.0), (0, -1.2, 6.35), 0.04, BETON_INCHIS, laturi=5),
		cub("Lampa", (0.3, 0.6, 0.14), (0, -1.35, 6.35), BETON_INCHIS),
		cub("Cutie", (0.18, 0.12, 0.3), (0, 0.12, 2.6), p("6f6d7f")),
		cub("Afis", (0.3, 0.01, 0.4), (0, -0.09, 1.7), ALB, rot=(0, 0, 0)),
		cub("Afis", (0.25, 0.01, 0.12), (0.05, -0.1, 1.45), p("a18463")),
	]
	uneste(piese, "Stalp")
	uneste([cub("Sticla", (0.24, 0.5, 0.04), (0, -1.35, 6.27), p("a18463"))], "Sticla")
	exporta(os.path.join(cale, "stalp.glb"))


def tomberon(cale):
	"""Tomberon verde de metal, pe roți, cu un sac lângă el (n-a încăput)."""
	curata()
	verde = p("32453b")
	piese = [
		cub("Cos", (1.2, 0.85, 1.05), (0, 0, 0.65), VERDE_VOPSIT),
		cub("Capac", (1.25, 0.9, 0.06), (0, 0.02, 1.2), verde, rot=(0.12, 0, 0)),
		cub("Maner", (0.9, 0.06, 0.05), (0, 0.47, 1.05), NEGRU),
		cub("Rugina", (0.4, 0.86, 0.25), (0.3, 0, 0.3), p("904a40")),
	]
	for x in (-0.45, 0.45):
		for y in (-0.3, 0.3):
			piese.append(cilindru("Roata", 0.09, 0.09, 0.05, (x, y, 0.09), NEGRU, laturi=6, rot=(0, 1.5708, 0)))
	piese += [
		sfera("Sac", 0.3, (0.9, -0.3, 0.25), NEGRU, segmente=6, inele=4, scara=(1, 0.9, 0.85)),
		cub("Nod sac", (0.08, 0.08, 0.12), (0.9, -0.3, 0.55), NEGRU),
	]
	uneste(piese, "Tomberon")
	exporta(os.path.join(cale, "tomberon.glb"))


def batator(cale):
	"""Bătătorul de covoare din fața blocului, cu un covor uitat pe el. Lung pe X."""
	curata()
	teava = p("7a7b59")
	piese = []
	for x in (-1.3, 1.3):
		piese += [
			cilindru("Stalp", 0.04, 0.04, 2.0, (x, 0, 1.0), teava, laturi=6),
			cilindru("Picior beton", 0.12, 0.12, 0.08, (x, 0, 0.04), BETON, laturi=6),
		]
	piese.append(cilindru("Bara", 0.035, 0.035, 2.66, (0, 0, 1.9), teava, laturi=6, rot=(0, 1.5708, 0)))
	piese.append(cilindru("Bara jos", 0.03, 0.03, 2.6, (0, 0, 0.9), teava, laturi=6, rot=(0, 1.5708, 0)))
	# covorul atârnat peste bară: două fețe, cu model
	for s in (-1, 1):
		piese.append(cub("Covor", (1.6, 0.02, 1.2), (0, s * 0.05, 1.32), p("7b383a"), rot=(s * 0.08, 0, 0)))
		piese.append(cub("Model", (1.2, 0.025, 0.85), (0, s * 0.055, 1.32), p("a18463"), rot=(s * 0.08, 0, 0)))
		piese.append(cub("Model", (0.8, 0.03, 0.5), (0, s * 0.06, 1.32), p("295555"), rot=(s * 0.08, 0, 0)))
	piese.append(cilindru("Fald", 0.06, 0.06, 1.6, (0, 0, 1.92), p("7b383a"), laturi=6, rot=(0, 1.5708, 0)))
	uneste(piese, "Batator")
	exporta(os.path.join(cale, "batator.glb"))


def gard(cale):
	"""O bucată de gărduleț din țeavă vopsită verde, lungă de 3 m pe X, de la x=0 la x=3."""
	curata()
	piese = []
	for x in (0.0, 1.5, 3.0):
		piese.append(cilindru("Stalp", 0.025, 0.025, 0.65, (x, 0, 0.325), VERDE_VOPSIT, laturi=5))
	for z in (0.3, 0.6):
		piese.append(cilindru("Teava", 0.02, 0.02, 3.0, (1.5, 0, z), VERDE_VOPSIT, laturi=5, rot=(0, 1.5708, 0)))
	piese.append(cub("Rugina", (0.25, 0.045, 0.045), (2.1, 0, 0.6), p("904a40")))
	uneste(piese, "Gard")
	exporta(os.path.join(cale, "gard.glb"))


def masina(cale):
	"""Mașină veche, parcată de ani de zile: caroserie ruginie, o roată dezumflată. Fața spre -Y."""
	curata()
	caroserie = p("904a40")
	crom = BETON_DESCHIS
	piese = [
		cub("Caroserie", (1.62, 4.25, 0.55), (0, 0, 0.6), caroserie),
		cub("Cabina", (1.45, 2.0, 0.5), (0, 0.25, 1.12), caroserie),
		cub("Parbriz", (1.3, 0.02, 0.45), (0, -0.765, 1.1), GEAM, rot=(-0.45, 0, 0)),
		cub("Luneta", (1.3, 0.02, 0.42), (0, 1.265, 1.1), GEAM, rot=(0.45, 0, 0)),
		cub("Bara fata", (1.66, 0.12, 0.14), (0, -2.15, 0.45), crom),
		cub("Bara spate", (1.66, 0.12, 0.14), (0, 2.15, 0.45), crom),
		cub("Grila", (0.9, 0.03, 0.22), (0, -2.13, 0.68), NEGRU),
		cub("Numar", (0.5, 0.02, 0.11), (0, -2.22, 0.45), ALB),
		cub("Numar", (0.5, 0.02, 0.11), (0, 2.22, 0.5), ALB),
		cub("Rugina", (0.6, 0.02, 0.25), (0.815, 0.9, 0.5), p("7b383a")),
		cub("Rugina", (0.4, 0.02, 0.2), (-0.815, -1.2, 0.48), p("7b383a")),
		cub("Frunze pe capota", (0.9, 0.7, 0.03), (0.1, -1.6, 0.89), p("a56850")),
	]
	# acoperișul cabinei și geamurile laterale
	for s in (-1, 1):
		piese.append(cub("Geam lateral", (0.02, 1.6, 0.36), (s * 0.73, 0.25, 1.15), GEAM))
		piese.append(cub("Far", (0.3, 0.03, 0.16), (s * 0.55, -2.13, 0.72), ALB))
		piese.append(cub("Stop", (0.28, 0.03, 0.12), (s * 0.6, 2.13, 0.72), p("7b383a")))
		piese.append(cub("Oglinda", (0.12, 0.05, 0.08), (s * 0.85, -0.6, 0.95), NEGRU))
	for x in (-0.7, 0.7):
		for y in (-1.35, 1.35):
			jos = 0.05 if (x, y) == (0.7, 1.35) else 0.0  # roata dezumflată
			piese.append(cilindru("Roata", 0.31, 0.31, 0.2, (x, y, 0.31 - jos), NEGRU, laturi=8, rot=(0, 1.5708, 0)))
			piese.append(cilindru("Janta", 0.15, 0.15, 0.21, (x, y, 0.31 - jos), crom, laturi=8, rot=(0, 1.5708, 0)))
	uneste(piese, "Masina")
	exporta(os.path.join(cale, "masina.glb"))


def baba(cale):
	"""Baba de pe bancă, făcută din forme „trase” prin inele (trunchi() din unelte.py), nu din cuburi:
	stă jos, cocoșată, cu capul împins în față și ambele mâini pe baston. Basma roșie cu flori legată
	sub bărbie, palton gros cu guler de blană, ciorapi groși, botoșei cu blană. În poală are un cornet
	de ziar cu semințe, la picioare cojile și un porumbel care le ciugulește; lângă ea, sacoșa de rafie.
	Originea = podeaua din fața băncii (la mijlocul șezutului, care e la z 0,46), fața spre -Y.
	Capul e separat (originea în gât), ca să te urmărească."""
	curata()
	r = random.Random(77)
	palton, palton_umbra = p("553e4d"), p("48313b")
	blana, ciorapi, botosi = p("70706e"), p("5e5356"), p("5e363e")
	piele, piele_umbra = p("a56850"), p("904a40")
	piese = []

	# --- trunchiul: șolduri late pe bancă, spatele cocoșat, umerii căzuți, gâtul spre față
	piese.append(trunchi("Trunchi", [
		((0, 0.13, 0.47), 0.2, 0.16),
		((0, 0.12, 0.58), 0.205, 0.165),
		((0, 0.1, 0.7), 0.185, 0.15),
		((0, 0.075, 0.81), 0.19, 0.155),
		((0, 0.05, 0.9), 0.205, 0.15),
		((0, 0.025, 0.965), 0.17, 0.12),
		((0, 0.0, 1.0), 0.09, 0.075),
	], palton, laturi=10))
	piese += [
		sfera("Cocoasa", 0.14, (0, 0.13, 0.9), palton, scara=(1.25, 0.75, 1.0), segmente=8, inele=6),
		# gulerul de blană (ros pe alocuri) și reverele
		inel("Guler", 0.098, 0.026, (0, 0.012, 0.975), blana, segmente=10),
		cub("Rever", (0.06, 0.012, 0.16), (-0.06, -0.085, 0.89), palton_umbra, rot=(0.25, 0.3, 0)),
		cub("Rever", (0.06, 0.012, 0.16), (0.06, -0.085, 0.89), palton_umbra, rot=(0.25, -0.3, 0)),
		# vesta tricotată care se vede în deschizătura paltonului
		cub("Vesta", (0.07, 0.01, 0.14), (0, -0.078, 0.89), p("445d46"), rot=(0.25, 0, 0)),
	]
	for z, y in ((0.85, -0.098), (0.75, -0.06), (0.65, -0.035)):  # nasturi mari, unul lipsă (al doilea are doar ața)
		if z == 0.75:
			piese.append(cub("Ata", (0.012, 0.006, 0.012), (0.0, y - 0.006, z), p("a18463")))
			continue
		piese.append(cilindru("Nasture", 0.02, 0.02, 0.012, (0.0, y - 0.006, z), p("2a3c3d"), laturi=6,
			rot=(1.35, 0, 0)))
	piese += [  # buzunarul cu batista
		cub("Buzunar", (0.1, 0.01, 0.012), (0.13, -0.05, 0.66), palton_umbra, rot=(0.15, 0, 0.3)),
		cub("Batista", (0.04, 0.006, 0.035), (0.135, -0.045, 0.675), ALB, rot=(0.15, 0.3, 0.6)),
	]

	# --- poala paltonului: peste coapse până la genunchi, apoi cade în față ca un clopot
	piese.append(trunchi("Poala", [
		((0, 0.12, 0.56), 0.21, 0.1),
		((0, -0.08, 0.565), 0.205, 0.09),
		((0, -0.26, 0.555), 0.2, 0.08),
		((0, -0.32, 0.52), 0.19, 0.055),
	], palton, laturi=8))
	for s in (-1, 1):
		piese.append(sfera("Genunchi", 0.075, (0.1 * s, -0.285, 0.545), palton, scara=(1, 1, 0.9),
			segmente=8, inele=5))
	piese.append(trunchi("Clopot", [
		((0, -0.32, 0.53), 0.2, 0.055),
		((0, -0.345, 0.42), 0.205, 0.045),
		((0, -0.37, 0.3), 0.215, 0.04),
		((0, -0.372, 0.285), 0.215, 0.04),
	], palton, laturi=8, ref=(1, 0, 0)))
	piese.append(trunchi("Tiv", [((0, -0.371, 0.305), 0.218, 0.043), ((0, -0.373, 0.282), 0.218, 0.043)],
		palton_umbra, laturi=8))

	# --- picioarele: gambe groase în ciorapi, glezne umflate, botoșei cu blană și pompon
	for s in (-1, 1):
		x = 0.1 * s
		piese.append(trunchi("Gamba", [
			((x, -0.33, 0.32), 0.05, 0.05),
			((x * 1.1, -0.35, 0.2), 0.052, 0.05),
			((x * 1.15, -0.36, 0.1), 0.05, 0.048),
			((x * 1.15, -0.36, 0.07), 0.048, 0.046),
		], ciorapi, laturi=8))
		xb = x * 1.15
		piese.append(trunchi("Botos", [
			((xb, -0.31, 0.045), 0.0, 0.0),
			((xb, -0.32, 0.045), 0.05, 0.042),
			((xb + 0.008 * s, -0.4, 0.045), 0.058, 0.045),
			((xb + 0.015 * s, -0.48, 0.035), 0.05, 0.033),
			((xb + 0.02 * s, -0.53, 0.025), 0.0, 0.0),
		], botosi, laturi=8, faza=0.39))
		piese += [
			inel("Blana", 0.055, 0.02, (xb, -0.355, 0.085), p("7e8d87"), segmente=8),
			cub("Talpa", (0.1, 0.2, 0.012), (xb + 0.008 * s, -0.42, 0.006), NEGRU),
			sfera("Pompon", 0.02, (xb + 0.012 * s, -0.47, 0.072), p("7b383a"), segmente=6, inele=4),
		]

	# --- brațele: din umeri, coatele ies în lături, mâinile una peste alta pe mânerul bastonului
	for s in (-1, 1):
		umar, cot, incheietura = (0.19 * s, 0.05, 0.925), (0.245 * s, -0.12, 0.74), (0.05 * s, -0.37, 0.8)
		mijl1 = tuple((a + b) / 2 + d for a, b, d in zip(umar, cot, (0.02 * s, 0, 0)))
		mijl2 = tuple((a + b) / 2 for a, b in zip(cot, incheietura))
		piese.append(trunchi("Brat", [
			(umar, 0.07, 0.07), (mijl1, 0.066, 0.062), (cot, 0.062, 0.058), (mijl2, 0.058, 0.054),
			(incheietura, 0.054, 0.05)], palton, laturi=8, ref=(0, 0, 1)))
		piese.append(sfera("Umar", 0.075, umar, palton, segmente=8, inele=5))
		directie = tuple(b - a for a, b in zip(cot, incheietura))
		lung = math.sqrt(sum(d * d for d in directie))
		mansa = tuple(i - d / lung * 0.03 for i, d in zip(incheietura, directie))
		piese.append(os_intre("Mansa", mansa, incheietura, 0.058, palton_umbra, laturi=8))
	# mâinile: dreapta strânge mânerul, stânga stă peste ea; degete noduroase, verigheta
	for nume, (x, y, z) in (("Mana dreapta", (0.015, -0.425, 0.835)), ("Mana stanga", (-0.01, -0.432, 0.872))):
		piese.append(sfera(nume, 0.048, (x, y, z), piele, scara=(1.15, 0.85, 0.62), segmente=8, inele=5))
		for k in range(4):
			piese.append(cub("Nod deget", (0.017, 0.022, 0.02), (x - 0.03 + k * 0.02, y - 0.038, z - 0.006 - 0.004 * k),
				piele_umbra, rot=(0.3, 0, 0)))
		piese.append(os_intre("Deget mare", (x + 0.04, y - 0.005, z), (x + 0.03, y - 0.04, z + 0.012), 0.013, piele,
			laturi=5))
	piese.append(cub("Verigheta", (0.006, 0.024, 0.022), (0.035, -0.452, 0.866), p("a18463")))

	# --- bastonul: lemn închis, cârja curbată în față, papuc de cauciuc jos
	piese.append(os_intre("Baston", (0, -0.5, 0.02), (0.0, -0.425, 0.82), 0.016, palton_umbra, laturi=6))
	piese.append(trunchi("Carja", [
		((0, -0.425, 0.8), 0.017, 0.017), ((0, -0.425, 0.85), 0.017, 0.017), ((0, -0.45, 0.885), 0.017, 0.017),
		((0, -0.49, 0.89), 0.017, 0.017), ((0, -0.525, 0.87), 0.017, 0.017), ((0, -0.535, 0.84), 0.015, 0.015),
	], palton_umbra, laturi=6))
	piese.append(cilindru("Talpa baston", 0.022, 0.02, 0.03, (0, -0.502, 0.015), NEGRU, laturi=6))

	# --- în poală: cornetul de ziar cu semințe, câteva semințe scăpate pe palton
	piese.append(trunchi("Cornet", [((-0.11, -0.2, 0.635), 0.0, 0.0), ((-0.06, -0.13, 0.64), 0.03, 0.03),
		((-0.03, -0.09, 0.645), 0.045, 0.045)], p("7e8d87"), laturi=6, capete=False))
	piese.append(cub("Scris ziar", (0.04, 0.002, 0.012), (-0.065, -0.145, 0.668), NEGRU, rot=(0.2, 0, 0.7)))
	for k in range(6):
		piese.append(cub("Saminta", (0.008, 0.014, 0.006), (-0.03 + r.uniform(-0.03, 0.03), -0.09 + r.uniform(-0.02, 0.02),
			0.66 + r.uniform(0, 0.02)), NEGRU, rot=(0, 0, r.uniform(0, 3))))
	for k in range(4):
		piese.append(cub("Coaja", (0.008, 0.014, 0.004), (r.uniform(-0.15, 0.15), r.uniform(-0.28, -0.05), 0.612),
			NEGRU, rot=(0, 0, r.uniform(0, 3))))
	for _ in range(28):  # coji scuipate pe jos, mai dese în fața ei
		piese.append(cub("Coaja", (0.012, 0.022, 0.004), (r.gauss(0, 0.2), r.uniform(-0.85, -0.45), 0.002),
			NEGRU, rot=(0, 0, r.uniform(0, math.tau))))

	# --- sacoșa de rafie în dungi, pe bancă lângă ea: praz și o pâine
	sx = 0.45
	for k, cul in enumerate((p("438b88"), ALB, p("438b88"), p("7b383a"), p("438b88"))):
		z0 = 0.465 + k * 0.055
		piese.append(trunchi("Sacosa", [((sx, -0.02, z0), 0.135 + k * 0.003, 0.07), ((sx, -0.02, z0 + 0.055), 0.138 + k * 0.003, 0.072)],
			cul, laturi=4, faza=0.785))
	for s in (-1, 1):
		piese.append(trunchi("Toarta", [((sx - 0.07 * s, -0.02, 0.73), 0.008, 0.008), ((sx - 0.06 * s, -0.02, 0.81), 0.008, 0.008),
			((sx, -0.02, 0.84), 0.008, 0.008)], p("438b88"), laturi=4))
	piese += [
		os_intre("Praz", (sx - 0.05, 0.0, 0.66), (sx - 0.11, 0.05, 0.98), 0.024, p("7e8d87"), laturi=6),
		os_intre("Frunze praz", (sx - 0.11, 0.05, 0.98), (sx - 0.16, 0.08, 1.1), 0.03, p("5b6d4e"), laturi=5),
		sfera("Paine", 0.07, (sx + 0.05, -0.02, 0.75), p("a18463"), scara=(1.3, 0.9, 0.7), segmente=8, inele=5),
	]

	# --- porumbelul care ciugulește cojile
	px, py = 0.32, -0.72
	piese += [
		sfera("Porumbel", 0.09, (px, py, 0.075), p("778c96"), scara=(1.25, 0.7, 0.7), segmente=8, inele=6),
		sfera("Gat porumbel", 0.04, (px - 0.08, py, 0.08), p("30716f"), segmente=6, inele=4),
		sfera("Cap porumbel", 0.032, (px - 0.115, py, 0.04), p("778c96"), segmente=6, inele=4),
		cub("Cioc", (0.025, 0.01, 0.01), (px - 0.145, py, 0.025), p("5e5356"), rot=(0, 0.6, 0)),
		cub("Ochi porumbel", (0.008, 0.066, 0.008), (px - 0.12, py, 0.05), p("904a40")),
		cub("Coada", (0.1, 0.07, 0.015), (px + 0.13, py, 0.1), p("6f6d7f"), rot=(0, -0.35, 0)),
		cub("Dunga aripa", (0.05, 0.13, 0.012), (px + 0.03, py, 0.1), p("6f6d7f")),
		cub("Dunga aripa", (0.04, 0.13, 0.012), (px + 0.08, py, 0.1), p("6f6d7f")),
		cub("Picior porumbel", (0.008, 0.008, 0.04), (px, py - 0.02, 0.02), p("904a40")),
		cub("Picior porumbel", (0.008, 0.008, 0.04), (px, py + 0.02, 0.02), p("904a40")),
	]
	uneste(piese, "Corp")

	# --- capul: fața trasă prin inele (bărbie ieșită, gură supta, pomeți, frunte), basma peste ea
	gat = (0, -0.03, 1.0)
	cap = [os_intre("Gat", (0, -0.02, 0.96), (0, -0.075, 1.07), 0.042, piele, laturi=6)]
	fata = [  # (z, centru y, rx, ry)
		(1.012, -0.125, 0.0, 0.0), (1.022, -0.12, 0.03, 0.03), (1.04, -0.112, 0.048, 0.05), (1.065, -0.098, 0.06, 0.068),
		(1.1, -0.09, 0.076, 0.085), (1.14, -0.086, 0.076, 0.084), (1.18, -0.08, 0.071, 0.08), (1.22, -0.075, 0.052, 0.062),
		(1.245, -0.07, 0.0, 0.0),
	]
	cap.append(trunchi("Fata", [((0, y, z), rx, ry) for z, y, rx, ry in fata], piele, laturi=10, faza=0.0))
	# basmaua: aceeași formă, mai mare și trasă spre spate, ca fața să iasă prin ea ca printr-un oval
	basma_inele = [
		(0.985, -0.045, 0.0, 0.0), (0.995, -0.04, 0.05, 0.055), (1.03, -0.03, 0.08, 0.085), (1.08, -0.032, 0.098, 0.105),
		(1.14, -0.036, 0.1, 0.112), (1.2, -0.046, 0.094, 0.1), (1.24, -0.06, 0.07, 0.077), (1.262, -0.062, 0.0, 0.0),
	]
	basma = p("2a3c3d")
	cap.append(trunchi("Basma", [((0, y, z), rx, ry) for z, y, rx, ry in basma_inele], basma, laturi=12))
	# florile de pe basma: doar pe laturi și pe spate (în față e fața)
	for z, y, rx, ry in basma_inele[2:6]:
		for k in range(12):
			a = (k + (0.5 if z > 1.1 else 0)) * math.tau / 12
			if -2.3 < (a if a <= math.pi else a - math.tau) < -0.85:
				continue
			fx, fy = rx * math.cos(a) * 1.01, y + ry * math.sin(a) * 1.01
			cul = p("a18463") if k % 2 else p("7b383a")
			cap.append(cub("Floare", (0.022, 0.006, 0.022), (fx, fy, z + 0.025), cul, rot=(0, 0.785, a + 1.5708)))
			cap.append(cub("Mijloc", (0.01, 0.008, 0.01), (fx * 1.005, fy + (fy - y) * 0.005, z + 0.025), p("2a3c3d"),
				rot=(0, 0, a + 1.5708)))
	cap += [
		# nodul de sub bărbie și cele două capete care atârnă
		sfera("Nod", 0.028, (0.03, -0.12, 0.995), basma, scara=(1.2, 1, 0.8), segmente=6, inele=4),
		cub("Capat basma", (0.04, 0.012, 0.08), (0.05, -0.125, 0.95), basma, rot=(0.2, -0.3, 0)),
		cub("Capat basma", (0.035, 0.012, 0.065), (0.015, -0.13, 0.955), basma, rot=(0.25, 0.4, 0)),
		# colțul basmalei, căzut pe ceafă și pe guler
		trunchi("Colt basma", [((0, 0.03, 1.1), 0.08, 0.02), ((0, 0.07, 1.0), 0.05, 0.016), ((0, 0.085, 0.94), 0.0, 0.0)],
			basma, laturi=4, faza=0.785),
		# o șuviță de păr cărunt scăpată sub basma
		cub("Suvita", (0.034, 0.012, 0.016), (-0.028, -0.152, 1.198), p("7e8d87"), rot=(0.3, 0, 0.35)),
		cub("Suvita", (0.022, 0.012, 0.014), (0.018, -0.153, 1.196), p("70706e"), rot=(0.3, 0, -0.2)),
	]
	# nasul coroiat, mare și roșiatic, cu negel (și un fir de păr în el)
	cap.append(trunchi("Nas", [((0, -0.16, 1.152), 0.014, 0.012), ((0, -0.192, 1.125), 0.021, 0.019),
		((0, -0.212, 1.096), 0.022, 0.02), ((0, -0.205, 1.074), 0.017, 0.014), ((0, -0.18, 1.068), 0.0, 0.0)],
		piele_umbra, laturi=6))
	cap += [
		sfera("Negel", 0.009, (0.016, -0.2, 1.112), p("48313b"), segmente=5, inele=3),
		cub("Fir", (0.002, 0.002, 0.016), (0.019, -0.207, 1.12), NEGRU, rot=(0.4, 0.5, 0)),
		cub("Nara", (0.008, 0.01, 0.005), (0.009, -0.192, 1.073), p("48313b")),
		cub("Nara", (0.008, 0.01, 0.005), (-0.009, -0.192, 1.073), p("48313b")),
	]
	# gura supta (fără dinți, doar unul de aur), colțurile lăsate în jos, ridurile, firele de pe bărbie
	cap += [
		cub("Gura", (0.044, 0.008, 0.008), (0, -0.163, 1.056), p("5e363e")),
		cub("Coltul gurii", (0.016, 0.008, 0.006), (0.026, -0.158, 1.051), p("5e363e"), rot=(0, 0.5, 0.3)),
		cub("Coltul gurii", (0.016, 0.008, 0.006), (-0.026, -0.158, 1.051), p("5e363e"), rot=(0, -0.5, -0.3)),
		cub("Dinte de aur", (0.008, 0.006, 0.007), (0.01, -0.167, 1.058), p("a18463")),
		cub("Rid", (0.004, 0.006, 0.045), (0.034, -0.156, 1.08), piele_umbra, rot=(0, -0.35, 0.3)),
		cub("Rid", (0.004, 0.006, 0.045), (-0.034, -0.156, 1.08), piele_umbra, rot=(0, 0.35, -0.3)),
		cub("Rid barbie", (0.03, 0.006, 0.004), (0, -0.152, 1.034), piele_umbra),
		cub("Fir barbie", (0.002, 0.004, 0.012), (0.012, -0.143, 1.022), NEGRU, rot=(0.3, 0, 0.3)),
		cub("Fir barbie", (0.002, 0.004, 0.012), (0.006, -0.145, 1.02), NEGRU, rot=(0.2, 0, -0.2)),
	]
	# ochelarii groși: ochii par uriași prin lentile; o sprânceană ridicată a suspiciune
	for s in (-1, 1):
		x = 0.036 * s
		cap += [
			cub("Orbita", (0.042, 0.01, 0.028), (x, -0.162, 1.138), piele_umbra),
			cilindru("Rama ochelari", 0.033, 0.033, 0.012, (x, -0.177, 1.138), NEGRU, laturi=8, rot=(1.5708, 0, 0)),
			cilindru("Lentila", 0.026, 0.026, 0.014, (x, -0.18, 1.138), p("61a19f"), laturi=8, rot=(1.5708, 0, 0)),
			cub("Ochi", (0.03, 0.004, 0.02), (x, -0.1878, 1.136), ALB),
			cub("Pupila", (0.014, 0.004, 0.016), (x - 0.004 * s, -0.189, 1.134), NEGRU),
			cub("Bratul ochelarilor", (0.006, 0.11, 0.006), (0.077 * s, -0.12, 1.142), NEGRU, rot=(0, 0, -0.08 * s)),
			cub("Spranceana", (0.04, 0.012, 0.012), (x, -0.172, 1.178 + (0.012 if s > 0 else 0)), p("7e8d87"),
				rot=(0, -0.35 * s if s > 0 else 0.2, 0)),
		]
	cap.append(cub("Punte ochelari", (0.016, 0.008, 0.008), (0, -0.181, 1.142), NEGRU))
	cap.append(sfera("Obraz", 0.02, (0.052, -0.155, 1.095), p("904a40"), scara=(1, 0.4, 0.8), segmente=6, inele=4))
	cap.append(sfera("Obraz", 0.02, (-0.052, -0.155, 1.095), p("904a40"), scara=(1, 0.4, 0.8), segmente=6, inele=4))
	uneste(cap, "Cap", gat)
	exporta(os.path.join(cale, "baba.glb"))


def toate(cale):
	bloc(cale)
	copac(cale, "copac_1", 21, 6.5, [p("904a40"), p("a56850"), p("7b383a")])
	copac(cale, "copac_2", 34, 5.5, [p("a18463"), p("a56850"), p("7a7b59")])
	copac(cale, "copac_3", 55, 7.0, [p("7b383a"), p("904a40"), p("a18463")], bucati=11)
	copac_gol(cale)
	frunze_jos(cale, "frunze_jos", 3, 2.6, 160)
	frunze_jos(cale, "frunze_jos_mic", 8, 1.4, 70)
	gramada_frunze(cale)
	banca(cale)
	stalp(cale)
	tomberon(cale)
	batator(cale)
	gard(cale)
	masina(cale)
	baba(cale)


if __name__ == "__main__":
	toate(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models"))
