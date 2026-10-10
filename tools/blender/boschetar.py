# Tom Berone, boschetarul din fața magazinului de băuturi („LIQUOR”, lângă Gun Store, magazin_arme.tscn): stă jos pe un
# carton, cu spatele la zid și genunchii la gură, și ține în mâini un carton pe care scrie „SAVING MONEY FOR DRUGS”.
# În față: paharul de carton cu mărunțiș; lângă el sticla în pungă de hârtie și o sacoșă. Rulare:
#   blender --background --factory-startup --python tools/blender/boschetar.py
# Axe Blender: Z în sus, fața modelului spre -Y (în Godot devine +Z). Originea = la sol, sub bazin; zidul e la y = +0,2.
# Piese separate: `Corp` (tot ce stă pe loc), `Cap` (originea în gât: te urmărește cu privirea), `BratDrept` (originea în
# umăr: îl ridică la vrajă) cu punctul `Palma` în el (de acolo ies scânteile vrăjii, boschetar.gd).
import math
import os
import sys
import bpy
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, inel, uneste, exporta, trunchi, text, desparte_fete  # noqa: E402

NEGRU = p("262d2f")
ALB = p("83b3b0")
PIELE = p("a56850")
PIELE_UMBRA = p("904a40")
NAS = p("7b383a")
PAR = p("7e8d87")         # cărunt, nespălat
PAR_UMBRA = p("70706e")
GEACA = p("5b6d4e")       # geacă de armată, decolorată
GEACA_UMBRA = p("445d46")
FULAR = p("7b383a")
BLUGI = p("295555")
BLUGI_UMBRA = p("2a3c3d")
PETEC = p("7a7b59")
GHETE = p("48313b")
MANUSI = p("262d2f")
CACIULA = p("32453b")
CARTON = p("a18463")
CARTON_UMBRA = p("a56850")
SACOSA = p("6f6d7f")
STICLA = p("445d46")

## Înălțimea șezutului (cartonul de pe trotuar).
Z0 = 0.02


def _brat(piese, umar, cot, incheietura, nume):
	"""Mâneca de geacă, largă, cu manșeta ponosită, și mâna cu mănușă fără degete care ține colțul cartonului."""
	m1 = tuple((a + b) / 2 for a, b in zip(umar, cot))
	m2 = tuple((a + b) / 2 for a, b in zip(cot, incheietura))
	piese.append(trunchi(nume, [(umar, 0.08, 0.08), (m1, 0.077, 0.072), (cot, 0.07, 0.066), (m2, 0.064, 0.06),
		(incheietura, 0.055, 0.052)], GEACA, laturi=8, ref=(0, 0, 1)))
	piese.append(sfera("Umar", 0.085, umar, GEACA, segmente=8, inele=5))
	d = tuple(b - a for a, b in zip(cot, incheietura))
	l = math.sqrt(sum(v * v for v in d))
	manseta = tuple(i - v / l * 0.03 for i, v in zip(incheietura, d))
	piese.append(os_intre("Manseta", manseta, incheietura, 0.056, GEACA_UMBRA, laturi=8))
	mana = tuple(i + v / l * 0.05 for i, v in zip(incheietura, d))
	piese.append(sfera("Manusa", 0.045, mana, MANUSI, scara=(0.9, 0.8, 1.0), segmente=8, inele=5))
	for k in range(4):  # degetele goale ies din mănușă și se strâng pe muchia cartonului
		piese.append(cub("Deget", (0.016, 0.022, 0.016), (mana[0] - 0.024 + k * 0.016, mana[1] - 0.04, mana[2] + 0.02), PIELE))
	return mana


def boschetar(cale):
	curata()
	piese = []
	z0 = Z0
	# --- cartonul de sub el, turtit, cu o margine îndoită
	piese += [
		cub("Carton jos", (0.9, 1.05, 0.012), (0, -0.25, 0.006), CARTON),
		cub("Carton banda", (0.9, 0.06, 0.013), (0, -0.05, 0.007), CARTON_UMBRA),
		cub("Carton indoit", (0.9, 0.012, 0.12), (0, 0.19, 0.06), CARTON_UMBRA),
	]
	# --- bazinul și trunchiul: rezemat de zid, puțin cocoșat, geaca largă
	piese.append(sfera("Bazin", 0.18, (0, 0.03, z0 + 0.1), BLUGI, scara=(1.15, 1.0, 0.6), segmente=10, inele=6))
	tors = trunchi("Trunchi", [
		((0, 0.04, z0 + 0.08), 0.2, 0.16),
		((0, 0.05, z0 + 0.22), 0.215, 0.17),
		((0, 0.07, z0 + 0.36), 0.225, 0.165),
		((0, 0.09, z0 + 0.5), 0.235, 0.155),
		((0, 0.1, z0 + 0.58), 0.2, 0.13),
		((0, 0.1, z0 + 0.62), 0.09, 0.08),
	], GEACA, laturi=10)
	piese.append(tors)
	piese += [
		# fermoarul, buzunarele de piept cu clape, petecul de pe umăr
		os_intre("Fermoar", (0, -0.075, z0 + 0.12), (0, -0.065, z0 + 0.56), 0.008, GEACA_UMBRA, laturi=4),
		cub("Buzunar", (0.1, 0.012, 0.09), (-0.1, -0.072, z0 + 0.44), GEACA_UMBRA),
		cub("Buzunar", (0.1, 0.012, 0.09), (0.1, -0.072, z0 + 0.44), GEACA_UMBRA),
		cub("Clapa", (0.11, 0.016, 0.025), (-0.1, -0.076, z0 + 0.49), GEACA_UMBRA),
		cub("Clapa", (0.11, 0.016, 0.025), (0.1, -0.076, z0 + 0.49), GEACA_UMBRA),
		cub("Petec umar", (0.08, 0.06, 0.012), (0.19, 0.04, z0 + 0.58), PETEC, rot=(0, -0.5, 0)),
		# fularul roșu, înfășurat de două ori pe gât, cu un capăt atârnând
		trunchi("Fular", [((0, 0.09, z0 + 0.58), 0.12, 0.11), ((0, 0.09, z0 + 0.64), 0.11, 0.1)], FULAR, laturi=10),
		os_intre("Capat fular", (0.06, -0.03, z0 + 0.6), (0.09, -0.07, z0 + 0.42), 0.025, FULAR, laturi=5),
		# gluga lăsată pe spate, între el și zid
		sfera("Gluga", 0.13, (0, 0.2, z0 + 0.58), GEACA_UMBRA, scara=(1.3, 0.6, 0.7), segmente=8, inele=5),
	]
	# --- picioarele: genunchii la gură, tălpile pe carton; blugi cu un petec pe genunchi, ghete scâlciate
	for s in (-1, 1):
		sold, genunchi, glezna = (0.1 * s, -0.03, z0 + 0.1), (0.14 * s, -0.36, z0 + 0.42), (0.13 * s, -0.56, z0 + 0.1)
		piese += [
			trunchi("Coapsa", [(sold, 0.095, 0.095), (genunchi, 0.078, 0.075)], BLUGI, laturi=8, ref=(0, 0, 1)),
			sfera("Genunchi", 0.08, genunchi, BLUGI, segmente=8, inele=5),
			trunchi("Gamba", [(genunchi, 0.074, 0.074), (glezna, 0.062, 0.06)], BLUGI, laturi=8, ref=(0, 0, 1)),
			trunchi("Tiv", [((glezna[0], glezna[1], glezna[2] + 0.03), 0.068, 0.066), ((glezna[0], glezna[1], glezna[2] + 0.06), 0.068, 0.066)],
				BLUGI_UMBRA, laturi=8),
		]
		if s == 1:
			piese.append(cub("Petec genunchi", (0.09, 0.012, 0.08), (genunchi[0], genunchi[1] - 0.075, genunchi[2] + 0.01), PETEC,
				rot=(0.6, 0, 0)))
		xb = glezna[0]
		piese += [
			trunchi("Gheata", [((xb, -0.52, z0 + 0.04), 0.0, 0.0), ((xb, -0.53, z0 + 0.04), 0.06, 0.06),
				((xb, -0.6, z0 + 0.04), 0.062, 0.05), ((xb, -0.68, z0 + 0.035), 0.055, 0.04), ((xb, -0.73, z0 + 0.03), 0.0, 0.0)],
				GHETE, laturi=8, faza=0.39),
			cub("Talpa", (0.12, 0.25, 0.025), (xb, -0.62, z0 + 0.012), NEGRU),
			cilindru("Caramb", 0.065, 0.065, 0.1, (xb, -0.56, z0 + 0.1), GHETE, laturi=8),
		]
	# --- cartonul cu scris, lăsat pe spate (spre el)
	# sprijinit de gambe, cât sunt ele de înclinate (~32°), la 5-6 cm în fața lor (înainte trecea prin genunchi și gambe)
	inclinare = -0.56
	centru_semn = (0, -0.535, z0 + 0.36)
	normala = (0, -math.cos(inclinare), -math.sin(inclinare))  # spre stradă
	sus = (0, -math.sin(inclinare), math.cos(inclinare))
	piese.append(cub("Semn", (0.56, 0.012, 0.34), centru_semn, CARTON, rot=(inclinare, 0, 0)))
	# colțul rupt din dreapta jos și o pată
	colt = tuple(c + u * -0.14 + n * 0.002 for c, u, n in zip(centru_semn, sus, normala))
	piese.append(cub("Semn rupt", (0.07, 0.014, 0.05), (0.25, colt[1], colt[2]), CARTON_UMBRA, rot=(inclinare, 0, 0.5)))
	scris = []
	for rand, (cuvinte, marime) in enumerate((("SAVING", 0.07), ("MONEY", 0.07), ("FOR DRUGS", 0.06))):
		h = 0.085 - rand * 0.085
		loc = tuple(c + n * 0.009 + u * h for c, n, u in zip(centru_semn, normala, sus))
		scris.append(text("Scris semn", cuvinte, loc, marime, NEGRU, rot=(1.5708 + inclinare, 0, 0)))
	piese += scris
	# --- brațul stâng (în corp): ține colțul din stânga sus al cartonului
	# coatele pe lângă genunchi, mâinile peste muchia de sus (antebrațele rămân în spatele cartonului)
	_brat(piese, (0.22, 0.07, z0 + 0.56), (0.33, -0.2, z0 + 0.36), (0.27, -0.43, z0 + 0.53), "Brat")
	# --- paharul de carton cu mărunțiș, sticla în pungă, sacoșa
	px, py = -0.36, -0.82
	piese += [
		cilindru("Pahar", 0.04, 0.05, 0.12, (px, py, 0.06), ALB, laturi=10),
		cilindru("Banda pahar", 0.046, 0.048, 0.03, (px, py, 0.06), FULAR, laturi=10),
		inel("Gura pahar", 0.05, 0.006, (px, py, 0.12), ALB, segmente=10),
	]
	for k, (dx, dy) in enumerate(((-0.015, 0.01), (0.012, -0.008), (0.0, 0.018))):
		piese.append(cilindru("Moneda", 0.012, 0.012, 0.004, (px + dx, py + dy, 0.105 + k * 0.003), CARTON, laturi=8))
	piese.append(cilindru("Moneda", 0.012, 0.012, 0.004, (px + 0.09, py + 0.03, 0.002), CARTON, laturi=8))
	sx, sy = 0.42, -0.25
	piese += [
		trunchi("Punga", [((sx, sy, 0.0), 0.06, 0.05), ((sx, sy, 0.18), 0.062, 0.052), ((sx, sy, 0.24), 0.04, 0.035)], CARTON,
			laturi=8),
		cilindru("Gat sticla", 0.015, 0.012, 0.09, (sx, sy, 0.28), STICLA, laturi=6),
		cilindru("Dop sticla", 0.013, 0.013, 0.015, (sx, sy, 0.33), NEGRU, laturi=6),
		trunchi("Sacosa", [((-0.45, 0.02, 0.0), 0.14, 0.09), ((-0.45, 0.02, 0.22), 0.15, 0.1), ((-0.45, 0.02, 0.3), 0.1, 0.06)],
			SACOSA, laturi=8),
		os_intre("Toarta", (-0.53, 0.02, 0.3), (-0.45, 0.0, 0.38), 0.008, SACOSA, laturi=4),
		os_intre("Toarta", (-0.37, 0.02, 0.3), (-0.45, 0.0, 0.38), 0.008, SACOSA, laturi=4),
	]
	uneste(piese, "Corp")

	# --- brațul drept (separat, originea în umăr): ține colțul din dreapta sus; la vrajă îl ridică
	umar = (-0.22, 0.07, z0 + 0.56)
	brat = []
	mana = _brat(brat, umar, (-0.33, -0.2, z0 + 0.36), (-0.27, -0.43, z0 + 0.53), "BratDrept")
	ob_brat = uneste(brat, "BratDrept", umar)
	palma = bpy.data.objects.new("Palma", None)
	bpy.context.scene.collection.objects.link(palma)
	palma.location = (mana[0], mana[1] - 0.05, mana[2] + 0.03)
	bpy.context.view_layer.update()
	palma.parent = ob_brat
	palma.matrix_parent_inverse = ob_brat.matrix_world.inverted()

	# --- capul (separat, originea în gât): bătrân, pletos, cu barbă căruntă și căciulă; obrajii roșii, nasul de bețiv
	gat = (0, 0.1, z0 + 0.62)
	cap = [os_intre("Gat", (0, 0.1, z0 + 0.6), (0, 0.08, z0 + 0.69), 0.05, PIELE, laturi=8)]
	fata = [  # (z, centru y, rx, ry)
		(0.665, 0.04, 0.0, 0.0), (0.675, 0.04, 0.045, 0.045), (0.7, 0.05, 0.066, 0.074), (0.74, 0.065, 0.08, 0.092),
		(0.79, 0.075, 0.085, 0.098), (0.84, 0.08, 0.083, 0.096), (0.88, 0.085, 0.072, 0.085), (0.905, 0.09, 0.045, 0.055),
		(0.92, 0.095, 0.0, 0.0),
	]
	cap.append(trunchi("Fata", [((0, y, z0 + z), rx, ry) for z, y, rx, ry in fata], PIELE, laturi=12))
	# căciula de lână trasă pe urechi, cu marginea răsfrântă
	caciula = [(0.82, 0.08, 0.09, 0.103), (0.87, 0.085, 0.084, 0.097), (0.915, 0.09, 0.064, 0.075), (0.945, 0.095, 0.03, 0.035),
		(0.952, 0.096, 0.0, 0.0)]
	cap.append(trunchi("Caciula", [((0, y, z0 + z), rx, ry) for z, y, rx, ry in caciula], CACIULA, laturi=12))
	cap.append(trunchi("Margine caciula", [((0, 0.079, z0 + 0.81), 0.096, 0.108), ((0, 0.08, z0 + 0.845), 0.096, 0.108)],
		GEACA_UMBRA, laturi=12))
	# pletele: ies de sub căciulă pe laterale și pe ceafă, până pe umeri
	for s in (-1, 1):
		cap.append(trunchi("Plete", [((0.075 * s, 0.1, z0 + 0.82), 0.03, 0.05), ((0.088 * s, 0.11, z0 + 0.74), 0.032, 0.055),
			((0.09 * s, 0.13, z0 + 0.66), 0.028, 0.045), ((0.085 * s, 0.14, z0 + 0.6), 0.0, 0.0)], PAR, laturi=6))
	cap.append(trunchi("Plete ceafa", [((0, 0.16, z0 + 0.82), 0.08, 0.035), ((0, 0.18, z0 + 0.72), 0.085, 0.035),
		((0, 0.17, z0 + 0.64), 0.0, 0.0)], PAR_UMBRA, laturi=8))
	# barba: lungă și zbârlită, de sub gură până pe piept (gura și mustața se văd), cu favoriți până la plete
	cap.append(trunchi("Barba", [((0, -0.012, z0 + 0.722), 0.068, 0.042), ((0, -0.03, z0 + 0.69), 0.072, 0.045),
		((0, -0.038, z0 + 0.64), 0.052, 0.035), ((0, -0.038, z0 + 0.6), 0.026, 0.022), ((0, -0.034, z0 + 0.575), 0.0, 0.0)], PAR, laturi=8))
	for s in (-1, 1):
		cap.append(os_intre("Favorit", (0.078 * s, 0.03, z0 + 0.79), (0.058 * s, -0.015, z0 + 0.715), 0.018, PAR, laturi=5))
	cap += [
		cub("Mustata", (0.07, 0.016, 0.014), (0, -0.04, z0 + 0.745), PAR_UMBRA),
		cub("Gura", (0.03, 0.01, 0.006), (0, -0.046, z0 + 0.733), NEGRU),
		# nasul mare, roșu, și obrajii roșii
		trunchi("Nas", [((0, -0.01, z0 + 0.815), 0.013, 0.01), ((0, -0.036, z0 + 0.78), 0.022, 0.018),
			((0, -0.042, z0 + 0.762), 0.026, 0.02), ((0, -0.028, z0 + 0.752), 0.0, 0.0)], NAS, laturi=6),
		cub("Obraz", (0.03, 0.006, 0.02), (0.05, -0.012, z0 + 0.775), NAS),
		cub("Obraz", (0.03, 0.006, 0.02), (-0.05, -0.012, z0 + 0.775), NAS),
	]
	for s in (-1, 1):
		x = 0.035 * s
		cap += [
			# ochii mici, înfundați, cu cearcăne și sprâncenele stufoase, cărunte
			cub("Ochi", (0.024, 0.006, 0.01), (x, -0.022, z0 + 0.8), ALB),
			cub("Pupila", (0.01, 0.006, 0.008), (x - 0.003 * s, -0.026, z0 + 0.8), NEGRU),
			cub("Cearcan", (0.028, 0.008, 0.008), (x, -0.018, z0 + 0.788), PIELE_UMBRA),
			cub("Spranceana", (0.04, 0.016, 0.014), (x, -0.024, z0 + 0.817), PAR, rot=(0, 0.15 * s, -0.1 * s)),
		]
	uneste(cap, "Cap", gat)
	# cartonul cu banda, buzunarele cu clapele, ochii cu pupilele: se băteau pe ecran (z-fighting)
	desparte_fete(fixe=("Carton jos", "Trunchi", "Fata"))
	exporta(os.path.join(cale, "boschetar.glb"))


def toate(cale):
	boschetar(cale)


if __name__ == "__main__":
	toate(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models"))
