# Pădurea Trivale: stația de la marginea pădurii, bariera forestieră, indicatorul de la bifurcație
# și ce e prin pădure (copaci morți, bușteni, pietre) și pe poteca din stânga (cruci, păpuși de paie, vatra), plus omul care se ușurează pe urcuș și ce lasă în urmă.
# Le apelează modele.py, dar merg și singure (mai repede, doar astea):
#   blender --background --factory-startup --python tools/blender/padure.py
# Axe Blender: Z în sus, fața modelului spre -Y (în Godot devine +Z). Originea = la sol.
# Regula fețelor: nimic lipit în același plan (vezi verifica_fete din unelte.py).
import math
import os
import random
import sys

import bmesh
import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, text, uneste, exporta, trunchi  # noqa: E402

NEGRU = p("262d2f")
ALB = p("83b3b0")
BETON = p("70706e")
BETON_DESCHIS = p("7e8d87")
BETON_INCHIS = p("5e5356")
METAL = p("778c96")
METAL_INCHIS = p("6f6d7f")
ROSU = p("7b383a")
RUGINA = p("904a40")
LEMN = p("553e4d")
LEMN_VECHI = p("5e363e")
LEMN_DESCHIS = p("a18463")
SCOARTA = p("48313b")
PAIE = p("a18463")
PAIE_INCHIS = p("7a7b59")
MUSCHI = p("445d46")
VERDE = p("32453b")


def _scaun_beton(piese, x, y):
	piese.append(cub("Picior banca", (0.12, 0.35, 0.4), (x, y, 0.3), BETON))


def statie_rurala(cale):
	"""Stație de autobuz de beton, la marginea pădurii, cum sunt pe drumurile județene: trei pereți
	de beton cu un mozaic decolorat înăuntru, acoperiș în consolă, bancă de lemn, rugină, graffiti.
	Lângă ea, stâlpul cu plăcuța liniei 13. Deschisă spre -Y (spre șosea)."""
	curata()
	r = random.Random(3)
	piese = []
	piese += [
		cub("Placa jos", (3.3, 1.75, 0.1), (0, -0.075, 0.05), BETON_INCHIS),
		cub("Perete spate", (3.0, 0.15, 2.3), (0, 0.725, 1.25), BETON),
		cub("Perete stanga", (0.15, 1.15, 2.3), (-1.425, 0.075, 1.25), BETON),
		cub("Perete dreapta", (0.15, 1.15, 2.3), (1.425, 0.075, 1.25), BETON),
		cub("Acoperis", (3.4, 1.9, 0.14), (0, -0.15, 2.47), BETON_DESCHIS),
		cub("Streasina", (3.4, 0.06, 0.18), (0, -1.13, 2.42), METAL_INCHIS),
		# numele stației pe streașină, ca frontonul stațiilor din oraș
		text("Statie", "TRIVALE", (0, -1.175, 2.42), 0.12, ALB),
	]
	# mozaicul de pe peretele din spate (un soare stilizat, cu plăcuțe lipsă); plăcuțele la 1,5 cm în față
	culori = [p("a56850"), p("a18463"), p("30716f"), p("438b88"), p("7b383a")]
	for i in range(-8, 9):
		for k in range(0, 9):
			x, z = i * 0.15, 0.95 + k * 0.15
			d = math.hypot(x, (z - 1.55) * 1.2)
			if r.random() < 0.18:
				continue  # plăcuță căzută
			c = culori[0] if d < 0.3 else culori[1] if d < 0.5 else culori[2 + (i + k) % 2] if d < 1.0 else culori[4]
			piese.append(cub("Placuta", (0.13, 0.012, 0.13), (x, 0.644, z), c))
	# banca de lemn pe picioare de beton
	for x in (-1.0, 1.0):
		_scaun_beton(piese, x, 0.45)
	for i in range(3):
		piese.append(cub("Scandura", (2.4, 0.11, 0.04), (0, 0.32 + i * 0.13, 0.52), LEMN_DESCHIS if i != 1 else LEMN))
	# pete de rugină scursă din acoperiș și graffiti pe pereții laterali (în afară)
	piese += [
		cub("Graffiti", (0.012, 0.6, 0.25), (1.507, 0.0, 1.2), p("30716f")),
		cub("Graffiti", (0.012, 0.3, 0.12), (1.507, 0.25, 0.95), ROSU),
		cub("Graffiti", (0.012, 0.5, 0.18), (-1.507, -0.1, 1.4), NEGRU),
		cub("Afis", (0.6, 0.012, 0.6), (0.9, 0.644, 0.55), p("7e8d87")),
	]
	# stâlpul cu plăcuța liniei, lângă șosea
	piese += [
		cilindru("Stalp placuta", 0.035, 0.035, 2.6, (2.2, -0.9, 1.3), METAL, laturi=6),
		# plăcuțele stau ÎN FAȚA stâlpului (spre șosea), nu prin el: stâlpul iese până la y = -0,935
		cub("Placuta chenar", (0.56, 0.03, 0.41), (2.2, -0.93, 2.45), p("295555")),
		cub("Placuta", (0.5, 0.03, 0.35), (2.2, -0.96, 2.45), ALB),
		text("Numar linie", "13", (2.2, -0.985, 2.5), 0.15, NEGRU),
		cub("Placuta traseu", (0.5, 0.03, 0.14), (2.2, -0.96, 2.15), p("a18463")),
		text("Traseu", "TRIVALE", (2.2, -0.985, 2.15), 0.08, NEGRU),
	]
	for s in (-1, 1):
		for y in (-0.44, 0.52):
			piese.append(cub("Scurgere", (0.012, 0.1, r.uniform(0.6, 1.1)), (s * 1.507, y, 1.8), RUGINA))
	uneste(piese, "StatieRurala")
	exporta(os.path.join(cale, "statie_rurala.glb"))


def bariera(cale):
	"""Bariera forestieră de la intrarea pe potecă: doi stâlpi de țeavă, bara vopsită roșu-alb (`Bara`,
	separată, originea în balama), contragreutatea de beton, lanțul cu lacăt de pe stâlpul din dreapta
	și plăcuța „NO ENTRY”. Bara e pe X, poteca trece pe Y. Pe lângă stâlpul din stânga rămâne loc
	de trecut pe jos."""
	curata()
	piese = [
		cilindru("Stalp balama", 0.07, 0.07, 1.1, (-1.8, 0, 0.55), METAL_INCHIS, laturi=8),
		cilindru("Stalp sprijin", 0.06, 0.06, 0.9, (1.95, 0, 0.45), METAL_INCHIS, laturi=8),
		cub("Furca", (0.14, 0.04, 0.12), (1.95, 0, 0.96), METAL_INCHIS),
		cub("Fundatie", (0.4, 0.4, 0.1), (-1.8, 0, 0.05), BETON),
		cub("Fundatie", (0.3, 0.3, 0.1), (1.95, 0, 0.05), BETON),
		# lanțul care atârnă și lacătul
		cub("Lant", (0.02, 0.02, 0.22), (1.95, -0.07, 0.83), METAL),
		cub("Lacat", (0.06, 0.03, 0.08), (1.95, -0.08, 0.68), p("a18463")),
	]
	uneste(piese, "Bariera")
	bara = []
	segmente = 8
	lung = 3.85
	for i in range(segmente):
		x0 = -1.8 + 0.08 + i * lung / segmente
		bara.append(cilindru("Bara", 0.045, 0.045, lung / segmente, (x0 + lung / segmente / 2, 0, 1.0),
			ROSU if i % 2 == 0 else ALB, laturi=8, rot=(0, 1.5708, 0)))
	bara += [
		cub("Contragreutate", (0.4, 0.22, 0.22), (-2.1, 0, 1.0), BETON),
		cub("Brat contragreutate", (0.3, 0.06, 0.06), (-1.9, 0, 1.0), METAL_INCHIS),
		cub("Placuta", (0.42, 0.02, 0.26), (0.15, -0.06, 0.82), ALB),
		cub("Placuta chenar", (0.46, 0.02, 0.3), (0.15, -0.04, 0.82), ROSU),
		text("Acces", "NO", (0.15, -0.085, 0.87), 0.08, ROSU),
		text("Interzis", "ENTRY", (0.15, -0.085, 0.78), 0.07, ROSU),
	]
	uneste(bara, "Bara", (-1.8, 0, 1.0))
	exporta(os.path.join(cale, "bariera.glb"))


def panou_ocol(cale):
	"""Panoul de lemn de lângă barieră: două picioare, acoperiș mic, tabla verde, mare (2,2 × 1,3 m),
	ca textul să se poată citi la rezoluția jocului. Textul l-a scris owner-ul (nu-l corecta)."""
	curata()
	piese = [
		cub("Picior", (0.12, 0.12, 2.5), (-1.15, 0, 1.25), LEMN),
		cub("Picior", (0.12, 0.12, 2.5), (1.15, 0, 1.25), LEMN),
		cub("Panou", (2.2, 0.05, 1.3), (0, 0, 1.65), VERDE),
		cub("Rama", (2.3, 0.04, 0.06), (0, -0.01, 2.33), LEMN_DESCHIS),
		cub("Rama", (2.3, 0.04, 0.06), (0, -0.01, 0.97), LEMN_DESCHIS),
		cub("Acoperis panou", (2.5, 0.45, 0.05), (0, 0.05, 2.5), LEMN_VECHI, rot=(0.25, 0, 0)),
		# rândurile sunt rupte ca să încapă pe tablă
		text("Text", "If I bite your neck and", (0, -0.04, 2.15), 0.13, ALB),
		text("Text", "stick my dick in your ass,", (0, -0.04, 1.95), 0.13, ALB),
		text("Text", "how do you get the", (0, -0.04, 1.75), 0.13, ALB),
		text("Text", "t-shirt out?", (0, -0.04, 1.55), 0.13, ALB),
		cub("Linie", (1.5, 0.012, 0.02), (0, -0.031, 1.4), ALB),
		text("Semnatura", "- Signed by the forest ranger", (0, -0.04, 1.24), 0.09, p("a18463")),
		cub("Rugina", (0.18, 0.012, 0.14), (0.9, -0.031, 1.1), RUGINA),
	]
	uneste(piese, "PanouOcol")
	exporta(os.path.join(cale, "panou_ocol.glb"))


def indicator(cale):
	"""Stâlpul indicator de la bifurcație: săgeata din dreapta scrie PLATEAU, cea din stânga e zgâriată
	până la lemn. Fața spre -Y (spre cine urcă poteca)."""
	curata()
	piese = [
		cub("Stalp", (0.12, 0.12, 2.2), (0, 0, 1.1), LEMN),
		cub("Capac", (0.18, 0.18, 0.05), (0, 0, 2.225), LEMN_VECHI),
		# săgeata spre dreapta (+X)
		cub("Sageata", (0.8, 0.04, 0.2), (0.46, -0.08, 1.85), LEMN_DESCHIS),
		cub("Varf", (0.14, 0.04, 0.14), (0.86, -0.08, 1.85), LEMN_DESCHIS, rot=(0, 0.785, 0)),
		text("Platou", "PLATEAU", (0.42, -0.115, 1.85), 0.09, NEGRU),
		# săgeata spre stânga (-X), puțin strâmbă, zgâriată
		cub("Sageata", (0.8, 0.04, 0.2), (-0.46, -0.08, 1.55), LEMN_DESCHIS, rot=(0, 0.06, 0)),
		cub("Varf", (0.14, 0.04, 0.14), (-0.86, -0.08, 1.5), LEMN_DESCHIS, rot=(0, 0.845, 0)),
	]
	r = random.Random(11)
	for _ in range(9):
		piese.append(cub("Zgarietura", (r.uniform(0.15, 0.4), 0.012, 0.012), (-0.45 + r.uniform(-0.15, 0.15), -0.106,
			1.55 + r.uniform(-0.06, 0.06)), LEMN_VECHI, rot=(0, r.uniform(-0.6, 0.6), 0)))
	uneste(piese, "Indicator")
	exporta(os.path.join(cale, "indicator.glb"))


def copac_mort(cale, nume, saminta, inaltime):
	"""Copac mort, strâmb, fără frunze, cu scoarța închisă și crengi ca niște degete."""
	curata()
	r = random.Random(saminta)
	piese = []
	# trunchiul se răsucește pe drum
	inele = []
	x = y = 0.0
	for i in range(8):
		t = i / 7
		x += r.uniform(-0.25, 0.25) * t
		y += r.uniform(-0.25, 0.25) * t
		raza = 0.32 * (1 - t) + 0.06
		inele.append(((x, y, t * inaltime), raza, raza * r.uniform(0.85, 1.0)))
	piese.append(trunchi("Trunchi", inele, SCOARTA, laturi=7))
	# rădăcini ieșite din pământ
	for k in range(4):
		u = k * math.tau / 4 + r.uniform(-0.3, 0.3)
		piese.append(os_intre("Radacina", (0, 0, 0.35), (math.cos(u) * 0.9, math.sin(u) * 0.9, -0.1), 0.09, SCOARTA, laturi=5))

	def creanga(a, directie, lungime, grosime, nivel):
		b = (a[0] + directie[0] * lungime, a[1] + directie[1] * lungime, a[2] + directie[2] * lungime)
		piese.append(os_intre("Creanga", a, b, grosime, NEGRU if nivel > 1 else SCOARTA, laturi=4))
		if nivel >= 3:
			return
		for _ in range(2):
			d = (directie[0] + r.uniform(-0.7, 0.7), directie[1] + r.uniform(-0.7, 0.7), directie[2] + r.uniform(-0.2, 0.5))
			n = math.sqrt(sum(c * c for c in d)) or 1
			creanga(b, tuple(c / n for c in d), lungime * 0.62, grosime * 0.6, nivel + 1)

	for k in range(5):
		i = r.randint(3, 6)
		c, raza, _ = inele[i]
		u = r.uniform(0, math.tau)
		creanga(c, (math.cos(u), math.sin(u), r.uniform(0.2, 0.7)), inaltime * 0.28, raza * 0.6, 1)
	uneste(piese, "CopacMort")
	exporta(os.path.join(cale, nume + ".glb"))


def trunchi_cazut(cale):
	"""Buștean căzut, culcat pe X, cu capetele tăiate (lemn deschis, cu inele) și mușchi pe el."""
	curata()
	lung, raza = 3.6, 0.3
	piese = [
		trunchi("Bustean", [((-lung / 2, 0, raza), raza, raza * 0.95), ((0, 0.03, raza * 0.98), raza * 0.97, raza * 0.92),
			((lung / 2, 0, raza * 0.92), raza * 0.88, raza * 0.85)], SCOARTA, laturi=9, ref=(0, 0, 1)),
		cilindru("Taietura", raza * 0.85, raza * 0.85, 0.02, (-lung / 2 - 0.012, 0, raza), LEMN_DESCHIS, laturi=9, rot=(0, 1.5708, 0)),
		cilindru("Inel", raza * 0.45, raza * 0.45, 0.02, (-lung / 2 - 0.032, 0, raza), p("904a40"), laturi=9, rot=(0, 1.5708, 0)),
		cilindru("Taietura", raza * 0.75, raza * 0.75, 0.02, (lung / 2 + 0.012, 0, raza * 0.92), LEMN_DESCHIS, laturi=9, rot=(0, 1.5708, 0)),
		os_intre("Ciot", (0.4, 0, raza * 1.6), (0.7, -0.2, raza * 2.6), 0.06, SCOARTA, laturi=5),
	]
	for x, l in ((-0.9, 0.8), (0.6, 0.6)):
		piese.append(cub("Muschi", (l, 0.3, 0.05), (x, 0, raza * 2 + 0.01), MUSCHI))
	uneste(piese, "Bustean")
	exporta(os.path.join(cale, "trunchi_cazut.glb"))


def piatra(cale, nume, saminta, marime):
	"""Piatră colțuroasă: o sferă cu puține fețe, deformată la întâmplare, cu mușchi pe o parte."""
	curata()
	r = random.Random(saminta)
	bpy.ops.mesh.primitive_uv_sphere_add(segments=7, ring_count=5, radius=marime, location=(0, 0, marime * 0.45))
	ob = bpy.context.active_object
	for v in ob.data.vertices:
		v.co.x *= r.uniform(0.8, 1.25)
		v.co.y *= r.uniform(0.8, 1.2)
		v.co.z *= r.uniform(0.55, 0.85)
	ob.name = "Piatra"
	from unelte import _coloreaza
	_coloreaza(ob, BETON)
	piese = [ob, sfera("Muschi", marime * 0.6, (marime * 0.2, marime * 0.1, marime * 0.75), MUSCHI,
		scara=(1.1, 1.0, 0.35), segmente=6, inele=4)]
	uneste(piese, "Piatra")
	exporta(os.path.join(cale, nume + ".glb"))


def cruce(cale):
	"""Cruce de lemn bătută în cuie, veche, cu o cârpă roșie legată (în pădure, unde n-are ce căuta)."""
	curata()
	piese = [
		cub("Lemn", (0.1, 0.07, 1.6), (0, 0, 0.8), LEMN_VECHI),
		cub("Brat", (0.75, 0.07, 0.1), (0, -0.07, 1.2), LEMN_VECHI),
		cub("Cui", (0.02, 0.02, 0.02), (0.0, -0.115, 1.2), METAL),
		cub("Carpa", (0.12, 0.03, 0.35), (0.3, -0.13, 1.05), ROSU, rot=(0, 0.15, 0)),
		cub("Nod", (0.08, 0.04, 0.06), (0.3, -0.12, 1.2), ROSU),
	]
	uneste(piese, "Cruce")
	exporta(os.path.join(cale, "cruce.glb"))


def papusa(cale):
	"""Păpușă de paie atârnată de o sfoară (momâie): originea e sus, la nodul sforii, ca să se legene.
	Cap de paie legat, ochi din nasturi, rochiță de cârpă, brațe dintr-un bețigaș, fir roșu la gât.
	Două bucăți, ca sfoara să se poată rupe (sperietura din vale): `Sfoara` (cât rămâne în cracă) și `Papusa`
	(păpușa, cu capătul rupt al sforii), amândouă cu originea la nod."""
	curata()
	sfoara = cub("Sfoara", (0.012, 0.012, 0.85), (0, 0, -0.425), PAIE_INCHIS)
	piese = [
		cub("Sfoara rupta", (0.012, 0.012, 0.35), (0, 0, -1.025), PAIE_INCHIS),
		trunchi("Cap", [((0, 0, -1.2), 0.0, 0.0), ((0, 0, -1.23), 0.07, 0.07), ((0, 0, -1.3), 0.09, 0.08),
			((0, 0, -1.37), 0.06, 0.055)], PAIE, laturi=7),
		trunchi("Rochie", [((0, 0, -1.37), 0.04, 0.04), ((0, 0, -1.45), 0.09, 0.07), ((0, 0, -1.65), 0.16, 0.12),
			((0, 0, -1.72), 0.17, 0.13)], LEMN_VECHI, laturi=7),
		os_intre("Brate", (-0.22, 0, -1.43), (0.22, 0, -1.41), 0.012, LEMN, laturi=4),
		trunchi("Fir rosu", [((0, 0, -1.36), 0.065, 0.06), ((0, 0, -1.38), 0.065, 0.06)], ROSU, laturi=7),
		cub("Nasture", (0.025, 0.012, 0.025), (-0.03, -0.088, -1.29), NEGRU),
		cub("Nasture", (0.025, 0.012, 0.025), (0.035, -0.088, -1.3), NEGRU),
	]
	# paiele care ies din mâini și de sub rochie
	for x in (-0.22, 0.22):
		for k in range(3):
			piese.append(os_intre("Pai", (x, 0, -1.42), (x * 1.25, (k - 1) * 0.03, -1.5), 0.006, PAIE, laturi=3))
	for k in range(6):
		u = k * math.tau / 6
		piese.append(os_intre("Pai", (math.cos(u) * 0.1, math.sin(u) * 0.08, -1.7), (math.cos(u) * 0.13, math.sin(u) * 0.1, -1.82),
			0.008, PAIE, laturi=3))
	uneste([sfoara], "Sfoara")
	uneste(piese, "Papusa")
	exporta(os.path.join(cale, "papusa.glb"))


def vatra(cale):
	"""Vatra stinsă: un cerc de pietre, tăciuni, cenușă și un os (mic, de animal... sperăm)."""
	curata()
	r = random.Random(5)
	piese = [cilindru("Cenusa", 0.55, 0.55, 0.03, (0, 0, 0.015), BETON_DESCHIS, laturi=10)]
	for k in range(10):
		u = k * math.tau / 10
		piese.append(sfera("Piatra", 0.13, (math.cos(u) * 0.68, math.sin(u) * 0.68, 0.07), BETON if k % 3 else BETON_INCHIS,
			scara=(1.1, 0.9, 0.7), segmente=6, inele=4))
	for k in range(5):
		u = r.uniform(0, math.tau)
		piese.append(os_intre("Taciune", (math.cos(u) * 0.05, math.sin(u) * 0.05, 0.05),
			(math.cos(u) * 0.45, math.sin(u) * 0.45, 0.1), 0.035, NEGRU, laturi=5))
	piese.append(os_intre("Os", (0.2, -0.25, 0.04), (0.42, -0.1, 0.05), 0.015, BETON_DESCHIS, laturi=4))
	uneste(piese, "Vatra")
	exporta(os.path.join(cale, "vatra.glb"))


def copac_craca(cale):
	"""Copac mort cu o cracă lungă, aproape orizontală, spre +X: de capătul ei (CARLIG) atârnă o păpușă.
	În Godot cârligul e la (1,6, 3,55, 0) față de originea copacului."""
	curata()
	r = random.Random(23)
	piese = [trunchi("Trunchi", [((0, 0, 0), 0.34, 0.32), ((0.05, 0.02, 1.5), 0.24, 0.23), ((-0.08, 0.05, 3.2), 0.17, 0.16),
		((0.02, 0.0, 5.0), 0.09, 0.08), ((0.25, -0.1, 6.2), 0.0, 0.0)], SCOARTA, laturi=7)]
	for k in range(4):
		u = k * math.tau / 4 + 0.4
		piese.append(os_intre("Radacina", (0, 0, 0.35), (math.cos(u) * 0.9, math.sin(u) * 0.9, -0.1), 0.09, SCOARTA, laturi=5))
	# craca: pleacă din trunchi la 3,6 m și se lasă puțin sub greutate
	piese.append(trunchi("Craca", [((0.0, 0, 3.75), 0.09, 0.08), ((0.8, 0, 3.72), 0.07, 0.06), ((1.7, 0, 3.6), 0.045, 0.04),
		((2.2, 0, 3.62), 0.0, 0.0)], SCOARTA, laturi=5))
	for a, b in (((0.0, 0, 4.6), (-1.2, 0.5, 5.6)), ((0.0, 0, 5.3), (0.7, -0.6, 6.4)), ((-0.05, 0, 2.6), (-1.0, -0.4, 3.2)),
			((1.0, 0, 3.7), (1.4, 0.5, 4.5))):
		piese.append(os_intre("Creanga", a, b, 0.04, NEGRU, laturi=4))
		piese.append(os_intre("Creanga", b, (b[0] + r.uniform(-0.5, 0.5), b[1] + r.uniform(-0.5, 0.5), b[2] + 0.6), 0.02, NEGRU, laturi=3))
	uneste(piese, "CopacCraca")
	exporta(os.path.join(cale, "copac_craca.glb"))


def om_padure(cale):
	"""Omul care se ușurează în pădure, pe urcușul spre platou: la vreo 50 de ani, burtă, chelie cu păr pe
	laturi, mustață, fâș mov, fundul gol, chiloții la genunchi și pantalonii de trening adunați la glezne, o rolă
	de hârtie igienică în dreapta. Modelat în picioare (fața spre -Y, originea la sol); ghemuitul și fuga le face
	`om_padure.gd` din piese: `Corp` (originea în bazin), cu `Cap` (în gât) și `BratS`/`BratD` (în umeri) copii ai
	lui, apoi `CoapsaS`/`CoapsaD` (în șolduri), fiecare cu `GambaS`/`GambaD` (în genunchi)."""
	curata()
	piele, piele_umbra = p("a56850"), p("904a40")
	fas, fas_umbra, fas_panou = p("655269"), p("553e4d"), p("30716f")
	trening, par = p("2a3c3d"), p("5e5356")
	bazin = (0, 0, 0.92)

	corp = [
		# fundul gol (se vede din spate, sub fâș), cu bazinul
		sfera("Bazin", 0.15, (0, 0.02, 0.9), piele, scara=(1.15, 0.85, 0.6), segmente=10, inele=6),
		sfera("Fund", 0.11, (-0.068, 0.07, 0.855), piele, scara=(1.0, 0.85, 1.05), segmente=8, inele=6),
		sfera("Fund", 0.11, (0.068, 0.07, 0.855), piele, scara=(1.0, 0.85, 1.05), segmente=8, inele=6),
		cub("Dunga fund", (0.01, 0.03, 0.13), (0, 0.15, 0.85), piele_umbra),
		# fâșul: lung în față (acoperă ce trebuie), cu burtă
		trunchi("Fas", [((0, 0.0, 0.89), 0.18, 0.14), ((0, -0.025, 1.0), 0.2, 0.17), ((0, -0.015, 1.13), 0.2, 0.16),
			((0, 0.01, 1.28), 0.2, 0.13), ((0, 0.02, 1.4), 0.17, 0.11), ((0, 0.02, 1.46), 0.07, 0.06)], fas, laturi=10),
		cub("Poala fas", (0.3, 0.05, 0.15), (0, -0.115, 0.83), fas_umbra, rot=(-0.12, 0, 0)),
		cub("Panou fas", (0.36, 0.08, 0.07), (0, -0.115, 1.25), fas_panou),
		trunchi("Guler", [((0, 0.02, 1.42), 0.1, 0.08), ((0, 0.02, 1.5), 0.09, 0.075)], fas_umbra, laturi=8),
	]
	trup = uneste(corp, "Corp", bazin)

	gat = (0, 0.02, 1.47)
	cap = [
		trunchi("Gat", [((0, 0.02, 1.44), 0.055, 0.055), ((0, 0.01, 1.54), 0.05, 0.05)], piele, laturi=7),
		trunchi("Fata", [((0, -0.02, 1.51), 0.0, 0.0), ((0, -0.025, 1.53), 0.07, 0.065), ((0, -0.01, 1.59), 0.095, 0.1),
			((0, 0.0, 1.67), 0.1, 0.11), ((0, 0.01, 1.73), 0.085, 0.09), ((0, 0.015, 1.77), 0.0, 0.0)], piele, laturi=10),
		trunchi("Nas", [((0, -0.1, 1.66), 0.022, 0.018), ((0, -0.132, 1.635), 0.032, 0.024), ((0, -0.128, 1.618), 0.0, 0.0)],
			piele_umbra, laturi=6),
		cub("Mustata", (0.12, 0.03, 0.03), (0, -0.112, 1.605), NEGRU),
		# gura căscată: l-ai prins
		cub("Gura", (0.045, 0.01, 0.04), (0, -0.112, 1.57), NEGRU),
		cub("Barba nerasa", (0.14, 0.05, 0.05), (0, -0.07, 1.55), piele_umbra),
		# chelie: păr doar pe laturi și la ceafă
		sfera("Par", 0.06, (-0.092, 0.03, 1.665), par, scara=(0.5, 1.2, 0.8), segmente=6, inele=4),
		sfera("Par", 0.06, (0.092, 0.03, 1.665), par, scara=(0.5, 1.2, 0.8), segmente=6, inele=4),
		sfera("Par", 0.08, (0, 0.085, 1.655), par, scara=(1.15, 0.5, 0.8), segmente=8, inele=4),
	]
	for s in (-1, 1):
		cap += [
			cub("Ochi", (0.032, 0.012, 0.024), (0.04 * s, -0.112, 1.68), ALB),
			cub("Pupila", (0.012, 0.012, 0.008), (0.04 * s, -0.122, 1.68), NEGRU),
			cub("Spranceana", (0.045, 0.012, 0.012), (0.042 * s, -0.105, 1.712), par, rot=(0, -0.2 * s, 0)),
			sfera("Ureche", 0.025, (0.1 * s, 0.01, 1.65), piele, scara=(0.4, 1, 1.3), segmente=6, inele=4),
		]
	ob_cap = uneste(cap, "Cap", gat)
	ob_cap.parent = trup
	ob_cap.matrix_parent_inverse = trup.matrix_world.inverted()

	for nume, s in (("BratS", -1), ("BratD", 1)):
		umar, cot, inch = (0.21 * s, 0.02, 1.4), (0.245 * s, 0.03, 1.12), (0.255 * s, 0.0, 0.86)
		brat = [
			sfera("Umar", 0.07, umar, fas, segmente=8, inele=5),
			trunchi("Maneca", [(umar, 0.065, 0.065), (cot, 0.06, 0.058), (inch, 0.048, 0.046)], fas, laturi=8),
			trunchi("Manseta", [((0.255 * s, 0.0, 0.88), 0.05, 0.05), ((0.256 * s, 0.0, 0.85), 0.05, 0.05)], fas_umbra, laturi=8),
			sfera("Mana", 0.045, (0.256 * s, -0.01, 0.8), piele, scara=(0.9, 1.1, 1.1), segmente=6, inele=4),
		]
		if s == 1:
			# rola de hârtie, ținută în față, și o fâșie care flutură
			brat += [
				cilindru("Hartie", 0.055, 0.055, 0.11, (0.256, -0.08, 0.79), ALB, laturi=8, rot=(1.5708, 0, 0)),
				cilindru("Gaura hartie", 0.02, 0.02, 0.13, (0.256, -0.08, 0.79), NEGRU, laturi=6, rot=(1.5708, 0, 0)),
				cub("Fasie hartie", (0.07, 0.006, 0.3), (0.256, -0.13, 0.64), ALB),
			]
		ob = uneste(brat, nume, umar)
		ob.parent = trup
		ob.matrix_parent_inverse = trup.matrix_world.inverted()

	for s, latura in ((-1, "S"), (1, "D")):
		sold, genunchi, glezna = (0.1 * s, 0.0, 0.9), (0.11 * s, -0.01, 0.49), (0.11 * s, 0.01, 0.1)
		coapsa = [trunchi("Coapsa", [(sold, 0.085, 0.085), (genunchi, 0.06, 0.06)], piele, laturi=8)]
		gamba = [
			sfera("Genunchi", 0.062, genunchi, piele, segmente=8, inele=5),
			trunchi("Gamba", [(genunchi, 0.058, 0.058), ((0.11 * s, -0.005, 0.32), 0.055, 0.055), (glezna, 0.04, 0.04)],
				piele, laturi=8),
			# chiloții, coborâți sub genunchi
			trunchi("Chiloti", [((0.11 * s, -0.008, 0.36), 0.075, 0.072), ((0.11 * s, -0.006, 0.43), 0.078, 0.075)], ALB, laturi=8),
			# trening-ul adunat la glezne, șifonat
			trunchi("Pantaloni", [((0.11 * s, 0.01, 0.07), 0.08, 0.08), ((0.11 * s, 0.01, 0.13), 0.1, 0.095),
				((0.11 * s, 0.005, 0.2), 0.085, 0.085), ((0.11 * s, 0.0, 0.27), 0.095, 0.09), ((0.11 * s, -0.003, 0.32), 0.07, 0.068)],
				trening, laturi=8),
			cub("Dunga trening", (0.012, 0.03, 0.2), (0.11 * s + 0.1 * s, 0.01, 0.19), ALB),
			cub("Pantof", (0.1, 0.25, 0.08), (0.11 * s, -0.06, 0.04), NEGRU),
		]
		ob_coapsa = uneste(coapsa, "Coapsa" + latura, sold)
		ob_gamba = uneste(gamba, "Gamba" + latura, genunchi)
		ob_gamba.parent = ob_coapsa
		ob_gamba.matrix_parent_inverse = ob_coapsa.matrix_world.inverted()
	exporta(os.path.join(cale, "om_padure.glb"))


def caca(cale):
	"""Ce lasă omul din pădure în urmă: o grămăjoară încolăcită și câteva ghemotoace de hârtie. Originea la sol."""
	curata()
	maro, maro_inchis = p("5e363e"), p("48313b")
	piese = [
		sfera("Caca", 0.09, (0, 0, 0.04), maro, scara=(1.0, 1.0, 0.5), segmente=8, inele=5),
		sfera("Caca", 0.065, (0.012, 0.004, 0.085), maro_inchis, scara=(1.0, 1.0, 0.65), segmente=8, inele=5),
		sfera("Caca", 0.042, (-0.004, 0.006, 0.122), maro, scara=(1.0, 1.0, 0.8), segmente=7, inele=4),
		trunchi("Varf", [((0.0, 0.005, 0.14), 0.02, 0.02), ((0.012, 0.0, 0.17), 0.0, 0.0)], maro_inchis, laturi=5),
	]
	for k, (x, y) in enumerate(((0.28, 0.1), (-0.22, 0.2), (0.12, 0.32))):
		piese.append(sfera("Hartie", 0.035 + k * 0.006, (x, y, 0.025), ALB, scara=(1.2, 1.0, 0.7), segmente=6, inele=4))
	uneste(piese, "Caca")
	exporta(os.path.join(cale, "caca.glb"))


def toate(cale):
	statie_rurala(cale)
	bariera(cale)
	panou_ocol(cale)
	indicator(cale)
	copac_mort(cale, "copac_mort_1", 7, 7.5)
	copac_mort(cale, "copac_mort_2", 19, 6.0)
	trunchi_cazut(cale)
	piatra(cale, "piatra_1", 2, 0.6)
	piatra(cale, "piatra_2", 8, 1.1)
	cruce(cale)
	papusa(cale)
	vatra(cale)
	copac_craca(cale)
	om_padure(cale)
	caca(cale)


if __name__ == "__main__":
	toate(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models"))
