# Bucătăria de bloc (anii '80–'90) și obiectele de pe hol: rame de tablouri, cuierul.
# Chemat din modele.py; merge și singur (mai repede):
#   blender --background --factory-startup --python tools/blender/bucatarie.py
# Axe: Z în sus, fața spre -Y. Obiectele de perete au spatele la y = 0 (lipit de perete).
import math
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, sfera_deschisa, inel, text, uneste, exporta  # noqa: E402

NEGRU = p("262d2f")
ALB = p("83b3b0")
CREM = p("7e8d87")
INOX = p("778c96")
ROSU = p("7b383a")
AUR = p("a18463")
LEMN = p("a56850")
LEMN_INCHIS = p("48313b")
VERDE = p("5b6d4e")
VERDE_INCHIS = p("445d46")


def _maner(x, y, z, piese):
	piese.append(cub("Maner", (0.012, 0.025, 0.07), (x, y - 0.0125, z), INOX))


def mobila_bucatarie(cale):
	"""Corpurile de jos, chiuveta, faianța, dulapurile de sus și polița. Spatele pe y = 0,
	originea în colțul din stânga-spate, jos; se întinde pe +X până la 3,2 m.
	Primii 0,6 m (x 0..0,6) sunt lăsați liberi pentru aragaz (model separat)."""
	curata()
	usa, corp, blat = CREM, p("70706e"), p("5e5356")
	A, H = 0.6, 0.85  # adâncime, înălțimea blatului
	piese = []
	# corpurile de jos: (x0, x1, fel)
	for x0, x1, fel in ((0.6, 1.2, "usa"), (1.2, 2.0, "chiuveta"), (2.0, 2.6, "sertare"), (2.6, 3.2, "usa")):
		lat = x1 - x0
		cx = (x0 + x1) / 2
		piese.append(cub("Soclu", (lat, A - 0.06, 0.08), (cx, -A / 2 + 0.03, 0.04), NEGRU))
		piese.append(cub("Corp", (lat, A - 0.02, H - 0.11), (cx, -A / 2 + 0.01, 0.08 + (H - 0.11) / 2), corp))
		fata = -A - 0.002
		if fel == "usa":
			piese.append(cub("Usa", (lat - 0.02, 0.02, 0.66), (cx, fata, 0.44), usa))
			_maner(x1 - 0.06, fata - 0.01, 0.66, piese)
		elif fel == "sertare":
			for i, (z, h) in enumerate(((0.69, 0.18), (0.48, 0.22), (0.23, 0.26))):
				piese.append(cub("Sertar", (lat - 0.02, 0.02, h - 0.015), (cx, fata, z), usa))
				piese.append(cub("Maner", (0.12, 0.022, 0.014), (cx, fata - 0.012, z + h / 2 - 0.05), INOX))
		else:
			# chiuveta n-are uși: perdeluță pe o sârmă, cu falduri. Dedesubt se vede găleata.
			piese.append(cub("Intuneric", (lat - 0.04, 0.01, 0.66), (cx, -A + 0.08, 0.44), NEGRU))
			piese.append(cilindru("Sarma", 0.006, 0.006, lat, (cx, fata - 0.01, 0.775), INOX, laturi=4,
				rot=(0, 1.5708, 0)))
			n = 8
			for i in range(n):
				x = x0 + 0.02 + (i + 0.5) * (lat - 0.04) / n
				y = fata - 0.015 - (0.015 if i % 2 else 0.0)
				piese.append(cub("Perdea", ((lat - 0.04) / n + 0.012, 0.008, 0.64), (x, y, 0.45),
					p("904a40") if i % 2 else p("a56850")))
				for z in (0.25, 0.45, 0.65):  # floricele
					piese.append(cub("Floare", (0.025, 0.006, 0.025), (x, y - 0.006, z + 0.06 * (i % 2)), AUR))
			piese += [
				cilindru("Galeata", 0.11, 0.13, 0.25, (x0 + 0.25, -0.35, 0.205), p("30716f"), laturi=8),
				cilindru("Toarta", 0.005, 0.005, 0.22, (x0 + 0.25, -0.35, 0.34), INOX, laturi=4, rot=(0, 1.5708, 0)),
			]
	# blatul, cu gaură pentru chiuvetă (x 1,35..1,85, y -0,52..-0,12)
	zb = H - 0.015
	piese += [
		cub("Blat", (0.75, A + 0.02, 0.03), (0.6 + 0.375, -A / 2 - 0.01, zb), blat),
		cub("Blat", (1.35, A + 0.02, 0.03), (1.85 + 0.675, -A / 2 - 0.01, zb), blat),
		cub("Blat", (0.5, 0.1, 0.03), (1.6, -0.57, zb), blat),
		cub("Blat", (0.5, 0.12, 0.03), (1.6, -0.06, zb), blat),
		# chiuveta din inox: buza, pereții, fundul și sita
		cub("Buza", (0.54, 0.03, 0.012), (1.6, -0.525, H + 0.004), INOX),
		cub("Buza", (0.54, 0.03, 0.012), (1.6, -0.115, H + 0.004), INOX),
		cub("Buza", (0.03, 0.44, 0.012), (1.345, -0.32, H + 0.004), INOX),
		cub("Buza", (0.03, 0.44, 0.012), (1.855, -0.32, H + 0.004), INOX),
		cub("Fund", (0.48, 0.38, 0.01), (1.6, -0.32, H - 0.17), p("70706e")),
		cub("Perete", (0.48, 0.01, 0.17), (1.6, -0.51, H - 0.085), INOX),
		cub("Perete", (0.48, 0.01, 0.17), (1.6, -0.13, H - 0.085), INOX),
		cub("Perete", (0.01, 0.38, 0.17), (1.36, -0.32, H - 0.085), INOX),
		cub("Perete", (0.01, 0.38, 0.17), (1.84, -0.32, H - 0.085), INOX),
		cilindru("Sita", 0.035, 0.035, 0.006, (1.6, -0.32, H - 0.162), NEGRU, laturi=8),
	]
	# faianța: rosturi gri în spate, plăcuțe în carouri, un rând cu flori, una lipsă, una pătată
	z0, rand, col = H, 0.14, 0.16
	piese.append(cub("Rosturi", (3.2, 0.006, 5 * rand), (1.6, -0.003, z0 + 2.5 * rand), p("70706e")))
	for r in range(5):
		for c in range(20):
			if (r, c) == (3, 13):
				continue  # plăcuța căzută
			x, z = (c + 0.5) * col, z0 + (r + 0.5) * rand
			cul = p("61a19f") if (r + c) % 2 else ALB
			if r == 2:
				cul = p("30716f")
			if (r, c) in ((1, 1), (0, 2)):
				cul = p("7a7b59")  # grăsime de la aragaz
			piese.append(cub("Placa", (col - 0.008, 0.01, rand - 0.008), (x, -0.011, z), cul))
			if r == 2 and c % 3 == 1:
				piese.append(cub("Floare", (0.04, 0.004, 0.04), (x, -0.017, z), ROSU, rot=(0, 0.785, 0)))
				piese.append(cub("Mijloc", (0.014, 0.005, 0.014), (x, -0.019, z), AUR))
	# robinetul din perete (ca la bloc): două robinete, roșu și albastru, și ciocul
	for dx, cul in ((-0.08, ROSU), (0.08, p("30716f"))):
		piese += [
			cilindru("Teava", 0.012, 0.012, 0.06, (1.6 + dx, -0.04, 1.08), INOX, laturi=6, rot=(1.5708, 0, 0)),
			cub("Robinet", (0.05, 0.012, 0.012), (1.6 + dx, -0.075, 1.08), cul),
			cub("Robinet", (0.012, 0.012, 0.05), (1.6 + dx, -0.075, 1.08), cul),
		]
	piese += [
		cub("Bara", (0.16, 0.025, 0.025), (1.6, -0.06, 1.08), INOX),
		cilindru("Cioc", 0.012, 0.012, 0.2, (1.6, -0.17, 1.08), INOX, laturi=6, rot=(1.5708, 0, 0)),
		cilindru("Cioc", 0.012, 0.01, 0.07, (1.6, -0.27, 1.05), INOX, laturi=6),
		cilindru("Picatura", 0.006, 0.0, 0.015, (1.6, -0.27, 1.0), p("61a19f"), laturi=4),
	]
	# pe blat: scurgătorul cu farfurii, detergentul în sticlă de suc, buretele,
	# tocătorul cu pâine și un borcan de zacuscă
	piese += [
		cub("Scurgator", (0.4, 0.3, 0.02), (2.3, -0.3, H + 0.01), INOX),
		cub("Scurgator", (0.4, 0.02, 0.12), (2.3, -0.16, H + 0.07), INOX),
		cub("Scurgator", (0.4, 0.02, 0.06), (2.3, -0.44, H + 0.04), INOX),
	]
	for i in range(4):
		piese.append(cilindru("Farfurie", 0.11, 0.11, 0.012, (2.16 + i * 0.07, -0.3, H + 0.12), ALB, laturi=10,
			rot=(0, 1.5708 - 0.15, 0)))
	piese += [
		cilindru("Sticla", 0.035, 0.035, 0.2, (1.25, -0.12, H + 0.1), p("30716f"), laturi=8),
		cilindru("Gat", 0.035, 0.014, 0.06, (1.25, -0.12, H + 0.23), p("30716f"), laturi=8),
		cilindru("Dop", 0.015, 0.015, 0.02, (1.25, -0.12, H + 0.27), ROSU, laturi=6),
		cub("Eticheta", (0.072, 0.072, 0.06), (1.25, -0.12, H + 0.1), p("904a40")),
		cub("Burete", (0.09, 0.06, 0.03), (1.92, -0.55, H + 0.015), p("7a7b59")),
		cub("Burete", (0.09, 0.06, 0.012), (1.92, -0.55, H + 0.036), VERDE),
		cub("Tocator", (0.4, 0.26, 0.02), (2.85, -0.3, H + 0.01), LEMN),
		sfera("Paine", 0.12, (2.82, -0.3, H + 0.06), AUR, scara=(1.3, 0.8, 0.55)),
		cub("Felie", (0.015, 0.14, 0.1), (2.98, -0.3, H + 0.06), p("a56850")),
		cilindru("Zacusca", 0.045, 0.045, 0.1, (3.1, -0.12, H + 0.05), p("904a40"), laturi=8),
		cilindru("Capac", 0.047, 0.047, 0.015, (3.1, -0.12, H + 0.105), AUR, laturi=8),
	]
	# dulapurile de sus (x 1,2..3,2), cu o ușă rămasă întredeschisă
	for i, x0 in enumerate((1.2, 1.7, 2.2, 2.7)):
		cx = x0 + 0.25
		piese.append(cub("Dulap", (0.5, 0.32, 0.62), (cx, -0.16, 1.92), corp))
		if i == 2:
			piese.append(cub("Intuneric", (0.46, 0.01, 0.58), (cx, -0.322, 1.92), NEGRU))
			piese.append(cub("Usa", (0.48, 0.02, 0.6), (x0 + 0.01 + 0.24 * math.cos(0.5), -0.34 - 0.24 * math.sin(0.5),
				1.92), usa, rot=(0, 0, -0.5)))
		else:
			piese.append(cub("Usa", (0.48, 0.02, 0.6), (cx, -0.33, 1.92), usa))
			_maner(x0 + (0.44 if i % 2 else 0.06), -0.34, 1.7, piese)
	# polița de deasupra aragazului: sare, condimente, râșnița de cafea
	piese += [
		cub("Polita", (1.0, 0.18, 0.025), (0.55, -0.09, 1.7), LEMN),
		cub("Suport", (0.02, 0.12, 0.1), (0.15, -0.06, 1.64), LEMN_INCHIS),
		cub("Suport", (0.02, 0.12, 0.1), (0.95, -0.06, 1.64), LEMN_INCHIS),
	]
	for i, cul in enumerate((ALB, ROSU, p("a56850"), VERDE, AUR)):
		x = 0.15 + i * 0.09
		piese.append(cilindru("Borcanel", 0.03, 0.03, 0.09, (x, -0.09, 1.757), cul, laturi=6))
		piese.append(cilindru("Capac", 0.031, 0.031, 0.015, (x, -0.09, 1.81), INOX, laturi=6))
	piese += [
		cub("Rasnita", (0.09, 0.09, 0.11), (0.7, -0.09, 1.767), LEMN_INCHIS),
		cilindru("Manivela", 0.006, 0.006, 0.08, (0.7, -0.09, 1.86), INOX, laturi=4),
		cub("Manivela", (0.06, 0.008, 0.008), (0.73, -0.09, 1.9), INOX),
		cub("Cutie sare", (0.08, 0.06, 0.13), (0.85, -0.09, 1.777), ALB),
		cub("Eticheta", (0.06, 0.004, 0.04), (0.85, -0.122, 1.78), p("30716f")),
	]
	uneste(piese, "Mobila")
	# neonul de sub dulapuri: separat, ca să strălucească (ModelPS2.stralucitoare)
	neon = [
		cub("Suport neon", (1.3, 0.05, 0.03), (2.25, -0.27, 1.595), INOX),
		cilindru("Tub", 0.016, 0.016, 1.2, (2.25, -0.27, 1.565), ALB, laturi=6, rot=(0, 1.5708, 0)),
	]
	uneste(neon[1:], "Neon")
	uneste(neon[:1], "SuportNeon")
	exporta(cale)


def aragaz(cale):
	"""Aragaz cu 4 ochiuri, capacul ridicat la perete, prosop pe mânerul cuptorului.
	Oala cu sarmale stă pe ochiul din față-stânga; `Capac` e separat (originea în centrul lui),
	ca să tremure în joc, iar `Flacara` e separată, ca să strălucească.
	Originea: mijlocul spatelui, jos. Lățime 0,6 (x -0,3..0,3), adâncime 0,6."""
	curata()
	email = ALB
	piese = [
		cub("Corp", (0.6, 0.58, 0.83), (0, -0.3, 0.035 + 0.415), email),
		cub("Plita", (0.6, 0.58, 0.02), (0, -0.3, 0.86), email),
		cub("Capac ridicat", (0.6, 0.02, 0.5), (0, -0.012, 1.12), email),
		cub("Panou", (0.58, 0.02, 0.1), (0, -0.595, 0.77), CREM),
		cub("Usa cuptor", (0.54, 0.02, 0.52), (0, -0.595, 0.41), email),
		cub("Geam cuptor", (0.32, 0.022, 0.2), (0, -0.597, 0.45), p("2a3c3d")),
		cub("Sertar", (0.54, 0.02, 0.1), (0, -0.595, 0.08), CREM),
		cilindru("Maner", 0.01, 0.01, 0.46, (0, -0.64, 0.64), INOX, laturi=6, rot=(0, 1.5708, 0)),
		cub("Prindere", (0.02, 0.04, 0.02), (-0.22, -0.62, 0.64), INOX),
		cub("Prindere", (0.02, 0.04, 0.02), (0.22, -0.62, 0.64), INOX),
		# prosopul de bucătărie pe mâner: o bucată în față, una în spate, dungi roșii
		cub("Prosop", (0.2, 0.008, 0.3), (-0.08, -0.652, 0.5), ALB),
		cub("Prosop", (0.2, 0.008, 0.2), (-0.08, -0.628, 0.55), ALB),
		cub("Dunga", (0.2, 0.01, 0.025), (-0.08, -0.653, 0.4), ROSU),
		cub("Dunga", (0.2, 0.01, 0.012), (-0.08, -0.653, 0.375), ROSU),
	]
	for x in (-0.25, 0.25):
		for y in (-0.05, -0.55):
			piese.append(cub("Picior", (0.04, 0.04, 0.035), (x, y, 0.0175), NEGRU))
	for i, x in enumerate((-0.2, -0.07, 0.07, 0.2)):
		piese.append(cilindru("Buton", 0.022, 0.022, 0.025, (x, -0.615, 0.77), NEGRU, laturi=8, rot=(1.5708, 0, 0)))
		piese.append(cub("Semn", (0.006, 0.01, 0.02), (x, -0.63, 0.78 if i else 0.765), ALB))
	# ochiurile: arzător negru + grătar în cruce
	for x, y in ((-0.14, -0.42), (0.14, -0.42), (-0.14, -0.17), (0.14, -0.17)):
		piese += [
			cilindru("Arzator", 0.05, 0.045, 0.02, (x, y, 0.88), NEGRU, laturi=8),
			cub("Gratar", (0.22, 0.012, 0.012), (x, y, 0.895), NEGRU),
			cub("Gratar", (0.012, 0.22, 0.012), (x, y, 0.895), NEGRU),
		]
	# oala emailată, roșie cu buline albe, și ibricul de cafea
	ox, oy, oz = -0.14, -0.42, 0.9
	piese.append(cilindru("Oala", 0.14, 0.14, 0.2, (ox, oy, oz + 0.1), ROSU, laturi=12))
	piese.append(inel("Buza oala", 0.14, 0.008, (ox, oy, oz + 0.2), ROSU, segmente=12))
	for i in range(8):
		a = i * math.pi / 4 + 0.3
		z = oz + (0.07 if i % 2 else 0.13)
		piese.append(cub("Bulina", (0.025, 0.006, 0.025), (ox + 0.141 * math.cos(a), oy + 0.141 * math.sin(a), z), ALB,
			rot=(0, 0, a + 1.5708)))
	for s in (-1, 1):
		piese.append(cub("Toarta", (0.05, 0.03, 0.015), (ox + 0.16 * s, oy, oz + 0.17), NEGRU))
	ix, iy = 0.14, -0.17
	piese += [
		cilindru("Ibric", 0.06, 0.05, 0.1, (ix, iy, 0.95), INOX, laturi=8),
		cilindru("Coada", 0.008, 0.008, 0.18, (ix + 0.14, iy, 0.99), LEMN_INCHIS, laturi=4, rot=(0, 1.3, 0)),
		cilindru("Cioc", 0.012, 0.0, 0.04, (ix - 0.065, iy, 0.99), INOX, laturi=4, rot=(0, -1.0, 0)),
	]
	uneste(piese, "Aragaz")
	capac = [
		cilindru("Capac", 0.145, 0.12, 0.03, (ox, oy, oz + 0.215), ROSU, laturi=12),
		cilindru("Buton capac", 0.02, 0.025, 0.025, (ox, oy, oz + 0.24), NEGRU, laturi=6),
	]
	uneste(capac, "Capac", (ox, oy, oz + 0.2))
	flacara = []
	for i in range(8):
		a = i * math.pi / 4
		flacara.append(cilindru("Limba", 0.012, 0.0, 0.03, (ox + 0.055 * math.cos(a), oy + 0.055 * math.sin(a), 0.895),
			p("61a19f"), laturi=4))
	uneste(flacara, "Flacara", (ox, oy, 0.89))
	exporta(cale)


def masa(cale):
	"""Masa de bucătărie cu mușama în carouri. Originea: centrul, jos. 1,2 × 0,75, blatul la 0,78."""
	curata()
	L, A, H = 1.2, 0.75, 0.78
	piese = [cub("Blat", (L, A, 0.03), (0, 0, H - 0.015), LEMN)]
	for x in (-L / 2 + 0.05, L / 2 - 0.05):
		for y in (-A / 2 + 0.05, A / 2 - 0.05):
			piese.append(cub("Picior", (0.05, 0.05, H - 0.03), (x, y, (H - 0.03) / 2), LEMN_INCHIS))
	piese.append(cub("Rama", (L - 0.1, A - 0.1, 0.08), (0, 0, H - 0.07), LEMN_INCHIS))
	# mușamaua: carouri de 10 cm, atârnă 10 cm pe margini
	c = 0.1
	nx, ny = 14, 9
	for i in range(nx):
		for j in range(ny):
			cul = ROSU if (i + j) % 2 else ALB
			piese.append(cub("Carou", (c, c, 0.004), (-nx * c / 2 + (i + 0.5) * c, -ny * c / 2 + (j + 0.5) * c, H + 0.002),
				cul))
	for i in range(nx):
		x = -nx * c / 2 + (i + 0.5) * c
		for s in (-1, 1):
			piese.append(cub("Margine", (c, 0.004, 0.1), (x, s * ny * c / 2, H - 0.048), ROSU if i % 2 else ALB))
	for j in range(ny):
		y = -ny * c / 2 + (j + 0.5) * c
		for s in (-1, 1):
			piese.append(cub("Margine", (0.004, c, 0.1), (s * nx * c / 2, y, H - 0.048), ALB if j % 2 else ROSU))
	# pe masă: ziarul, cana de ceai, solnița, un castron cu ciorbă cu lingura în el
	piese += [
		cub("Ziar", (0.3, 0.22, 0.01), (0.3, 0.12, H + 0.009), p("70706e"), rot=(0, 0, 0.25)),
		cub("Titlu", (0.2, 0.03, 0.002), (0.3, 0.06, H + 0.015), NEGRU, rot=(0, 0, 0.25)),
		cub("Rand", (0.22, 0.012, 0.002), (0.31, 0.12, H + 0.015), p("5e5356"), rot=(0, 0, 0.25)),
		cub("Rand", (0.22, 0.012, 0.002), (0.32, 0.16, H + 0.015), p("5e5356"), rot=(0, 0, 0.25)),
		cilindru("Cana", 0.04, 0.04, 0.09, (-0.05, 0.2, H + 0.047), ALB, laturi=8),
		cilindru("Ceai", 0.035, 0.035, 0.005, (-0.05, 0.2, H + 0.088), p("904a40"), laturi=8),
		cub("Toarta", (0.03, 0.012, 0.055), (0.05, 0.2, H + 0.05), ALB),
		cilindru("Solnita", 0.02, 0.025, 0.07, (-0.35, 0.05, H + 0.037), ALB, laturi=6),
		cilindru("Capac", 0.02, 0.012, 0.02, (-0.35, 0.05, H + 0.08), INOX, laturi=6),
		sfera_deschisa("Castron", 0.09, (-0.3, -0.18, H + 0.08), ALB, H + 0.08, grosime=0.008,
			scara=(1, 1, 0.7)),
		cilindru("Ciorba", 0.085, 0.085, 0.004, (-0.3, -0.18, H + 0.075), p("904a40"), laturi=10),
		cub("Lingura", (0.012, 0.15, 0.006), (-0.27, -0.12, H + 0.1), INOX, rot=(0.5, 0, 0.3)),
	]
	uneste(piese, "Masa")
	exporta(cale)


def taburet(cale):
	"""Taburet cu picioare de metal și șezut de vinilin roșu. Originea: centrul, jos."""
	curata()
	piese = [
		cilindru("Sezut", 0.17, 0.17, 0.05, (0, 0, 0.455), ROSU, laturi=10),
		inel("Margine", 0.17, 0.01, (0, 0, 0.432), INOX, segmente=10),
		inel("Inel", 0.15, 0.008, (0, 0, 0.16), INOX, segmente=8),
	]
	for i in range(4):
		a = i * math.pi / 2 + math.pi / 4
		piese.append(cilindru("Picior", 0.012, 0.012, 0.44, (0.14 * math.cos(a), 0.14 * math.sin(a), 0.22), INOX,
			laturi=4, rot=(0.1 * math.sin(a), -0.1 * math.cos(a), 0)))
	uneste(piese, "Taburet")
	exporta(cale)


def cutie_biscuiti(cale):
	"""Cutia albastră de biscuiți daneji (înăuntru: ațe și nasturi, evident). Originea: centrul, jos."""
	curata()
	piese = [
		cilindru("Cutie", 0.1, 0.1, 0.07, (0, 0, 0.035), p("295555"), laturi=12),
		cilindru("Capac", 0.103, 0.103, 0.02, (0, 0, 0.075), p("30716f"), laturi=12),
		inel("Chenar", 0.09, 0.005, (0, 0, 0.086), AUR, segmente=12),
		cub("Poza", (0.08, 0.06, 0.004), (0, 0, 0.086), ALB),
		cub("Casa", (0.03, 0.03, 0.005), (0, -0.005, 0.087), p("904a40")),
		cub("Acoperis", (0.02, 0.02, 0.005), (0, 0.015, 0.087), ROSU, rot=(0, 0, 0.785)),
	]
	for i in range(10):
		a = i * math.pi / 5
		piese.append(cub("Fulg", (0.012, 0.004, 0.012), (0.101 * math.cos(a), 0.101 * math.sin(a), 0.035), ALB,
			rot=(0, 0, a + 1.5708)))
	uneste(piese, "CutieBiscuiti")
	exporta(cale)


def icoana(cale):
	"""Icoana din colț, cu ștergar cusut și candelă. Originea: centrul icoanei, pe perete.
	`Flacara` din candelă e separată, ca să strălucească."""
	curata()
	fond, rama = p("7a7b59"), LEMN_INCHIS
	piese = [
		cub("Rama", (0.34, 0.03, 0.44), (0, -0.015, 0), rama),
		cub("Fond", (0.28, 0.01, 0.38), (0, -0.033, 0), fond),
		cilindru("Aureola", 0.075, 0.075, 0.006, (0, -0.04, 0.08), AUR, laturi=12, rot=(1.5708, 0, 0)),
		sfera("Fata", 0.045, (0, -0.045, 0.07), p("a56850"), scara=(0.9, 0.3, 1.15)),
		cub("Par", (0.1, 0.008, 0.03), (0, -0.048, 0.12), p("5e363e")),
		cub("Barba", (0.06, 0.008, 0.05), (0, -0.05, 0.03), p("5e363e")),
		cub("Mantie", (0.2, 0.01, 0.2), (0, -0.04, -0.09), ROSU),
		cub("Haina", (0.08, 0.012, 0.2), (0, -0.044, -0.09), p("295555")),
		cub("Mana", (0.03, 0.012, 0.03), (-0.04, -0.05, -0.04), p("a56850")),
		cub("Carte", (0.06, 0.014, 0.07), (0.045, -0.05, -0.06), AUR),
	]
	for s in (-1, 1):  # ochii mari, care se uită fix la tine
		piese.append(cub("Ochi", (0.018, 0.006, 0.01), (0.018 * s, -0.061, 0.08), ALB))
		piese.append(cub("Pupila", (0.008, 0.006, 0.008), (0.018 * s, -0.064, 0.08), NEGRU))
	# ștergarul: drapat peste colțurile de sus, atârnă pe laterale, cu cusături roșii la capete
	piese.append(cub("Stergar", (0.44, 0.012, 0.08), (0, -0.04, 0.24), ALB))
	for s in (-1, 1):
		piese.append(cub("Stergar", (0.08, 0.012, 0.55), (0.21 * s, -0.04, -0.06), ALB))
		for k, z in enumerate((-0.22, -0.26, -0.3)):
			piese.append(cub("Cusatura", (0.085, 0.014, 0.018 if k != 1 else 0.008), (0.21 * s, -0.04, z),
				ROSU if k != 1 else p("295555")))
		for k in range(4):
			piese.append(cub("Romb", (0.02, 0.014, 0.02), (0.21 * s, -0.041, 0.1 - k * 0.07), ROSU, rot=(0, 0.785, 0)))
		for k in range(4):  # ciucurii
			piese.append(cub("Ciucure", (0.008, 0.01, 0.04), (0.21 * s - 0.03 + k * 0.02, -0.04, -0.355), ALB))
	for k in range(5):
		piese.append(cub("Romb", (0.02, 0.014, 0.02), (-0.16 + k * 0.08, -0.047, 0.24), ROSU, rot=(0, 0.785, 0)))
	# candela: braț din perete, lanț, pahar roșu
	cz = -0.36
	piese += [
		cub("Brat", (0.02, 0.16, 0.02), (0, -0.08, -0.25), INOX),
		cilindru("Lant", 0.003, 0.003, 0.08, (0, -0.15, -0.3), INOX, laturi=4),
		cilindru("Pahar", 0.025, 0.04, 0.06, (0, -0.15, cz), ROSU, laturi=8),
		cilindru("Fund", 0.012, 0.025, 0.02, (0, -0.15, cz - 0.04), AUR, laturi=8),
	]
	uneste(piese, "Icoana")
	uneste([cilindru("Flacara", 0.008, 0.0, 0.025, (0, -0.15, cz + 0.035), AUR, laturi=4)], "Flacara",
		(0, -0.15, cz + 0.03))
	exporta(cale)


def punga_pungi(cale):
	"""Punga cu pungi, atârnată în cui. Originea: cuiul, pe perete."""
	curata()
	piese = [
		cilindru("Cui", 0.008, 0.008, 0.05, (0, -0.025, 0), NEGRU, laturi=4, rot=(1.5708, 0, 0)),
		sfera("Punga", 0.15, (0, -0.1, -0.3), CREM, scara=(1.05, 0.65, 1.25), segmente=8, inele=6),
		cub("Toarta", (0.03, 0.01, 0.16), (-0.06, -0.06, -0.08), CREM, rot=(0, 0.5, 0)),
		cub("Toarta", (0.03, 0.01, 0.16), (0.06, -0.06, -0.08), CREM, rot=(0, -0.5, 0)),
		cub("Scris", (0.12, 0.004, 0.05), (0, -0.2, -0.32), ROSU),
		cub("Scris", (0.08, 0.004, 0.02), (0, -0.2, -0.38), p("30716f")),
	]
	# pungi colorate care ies pe sus
	for x, y, z, cul in ((-0.07, -0.1, -0.15, ROSU), (0.05, -0.08, -0.14, p("30716f")),
			(0.0, -0.13, -0.13, VERDE), (0.09, -0.12, -0.17, AUR), (-0.02, -0.06, -0.12, p("904a40"))):
		piese.append(sfera("Pungulita", 0.05, (x, y, z), cul, scara=(1, 0.7, 0.8), segmente=6, inele=4))
	uneste(piese, "PungaPungi")
	exporta(cale)


def raft_borcane(cale):
	"""Raftul cu borcane: murături, zacuscă, compot, gem, plus o mușcată.
	Originea: mijlocul raftului, pe perete. Lățime 1,6."""
	curata()
	piese = [
		cub("Raft", (1.6, 0.24, 0.03), (0, -0.12, 0), LEMN),
		cub("Suport", (0.03, 0.18, 0.14), (-0.65, -0.09, -0.085), LEMN_INCHIS),
		cub("Suport", (0.03, 0.18, 0.14), (0.65, -0.09, -0.085), LEMN_INCHIS),
		cub("Mileu", (1.5, 0.24, 0.004), (0, -0.125, 0.017), ALB),
	]
	for i in range(15):  # dantela mileului, peste marginea raftului
		piese.append(cub("Dantela", (0.06, 0.004, 0.035), (-0.7 + i * 0.1, -0.245, -0.002), ALB, rot=(0, 0.785, 0)))
	borcane = [
		(0.07, 0.24, VERDE_INCHIS, "murat"), (0.07, 0.24, VERDE_INCHIS, "murat"), (0.05, 0.13, p("904a40"), "panza"),
		(0.06, 0.2, ROSU, ""), (0.06, 0.2, ROSU, "panza"), (0.05, 0.13, p("5e363e"), "panza"),
		(0.05, 0.13, p("904a40"), ""), (0.07, 0.24, p("7a7b59"), "murat"),
	]
	x = -0.68
	for r, h, cul, fel in borcane:
		x += r + 0.015
		z = 0.017
		piese.append(cilindru("Borcan", r, r, h, (x, -0.12, z + h / 2), cul, laturi=8))
		piese.append(cilindru("Gat", r * 0.8, r * 0.8, 0.02, (x, -0.12, z + h + 0.01), cul, laturi=8))
		if fel == "panza":  # capac de pânză legat cu sfoară
			piese.append(cub("Panza", (r * 2.2, r * 2.2, 0.01), (x, -0.12, z + h + 0.025), ALB, rot=(0, 0, 0.4)))
			piese.append(cilindru("Sfoara", r * 0.85, r * 0.85, 0.01, (x, -0.12, z + h + 0.01), ROSU, laturi=8))
		else:
			piese.append(cilindru("Capac", r * 0.85, r * 0.85, 0.02, (x, -0.12, z + h + 0.03), AUR, laturi=8))
		if fel == "murat":  # castraveții și ardeii dinăuntru, lipiți de sticlă
			piese.append(cub("Castravete", (0.02, 0.004, h * 0.7), (x - r * 0.4, -0.12 - r - 0.001, z + h / 2), VERDE))
			piese.append(cub("Ardei", (0.02, 0.004, h * 0.4), (x + r * 0.35, -0.12 - r - 0.001, z + h * 0.4), ROSU))
		x += r
	# mușcata în ghiveci, la capăt
	gx = 0.62
	piese += [
		cilindru("Ghiveci", 0.06, 0.075, 0.12, (gx, -0.12, 0.077), LEMN, laturi=8),
		cilindru("Farfurioara", 0.07, 0.07, 0.012, (gx, -0.12, 0.022), LEMN, laturi=8),
	]
	for dx, dy, dz in ((-0.05, 0, 0.17), (0.05, -0.03, 0.16), (0, 0.04, 0.2), (0.0, -0.05, 0.22), (-0.07, -0.04, 0.22)):
		piese.append(sfera("Frunza", 0.05, (gx + dx, -0.12 + dy, dz), VERDE, scara=(1, 1, 0.5), segmente=6, inele=4))
	for dx, dy, dz in ((-0.02, -0.03, 0.29), (0.05, -0.06, 0.27), (-0.07, -0.08, 0.26)):
		piese.append(sfera("Floare", 0.03, (gx + dx, -0.12 + dy, dz), ROSU, segmente=6, inele=4))
	uneste(piese, "RaftBorcane")
	exporta(cale)


def colt_camara(cale):
	"""Colțul cu damigeana de vin, lădița cu cartofi și sacul cu ceapă. Originea: colțul, jos
	(pereții pe +Y și pe -X; obiectele stau spre +X și -Y)."""
	curata()
	sticla = p("445d46")
	piese = [
		sfera("Damigeana", 0.2, (0.25, -0.25, 0.22), sticla, scara=(1, 1, 1.05), segmente=10, inele=8),
		cilindru("Gat", 0.04, 0.03, 0.14, (0.25, -0.25, 0.48), sticla, laturi=8),
		cilindru("Dop", 0.032, 0.032, 0.03, (0.25, -0.25, 0.56), LEMN, laturi=6),
		cilindru("Rachita", 0.205, 0.205, 0.16, (0.25, -0.25, 0.09), AUR, laturi=10),
	]
	for i in range(10):  # împletitura
		a = i * math.pi / 5
		piese.append(cub("Nuiele", (0.012, 0.01, 0.17), (0.25 + 0.207 * math.cos(a), -0.25 + 0.207 * math.sin(a), 0.09),
			LEMN, rot=(0, 0, a + 1.5708)))
	lx, ly = 0.75, -0.25
	for s in (-1, 1):
		piese.append(cub("Lada", (0.5, 0.02, 0.22), (lx, ly + 0.17 * s, 0.11), p("7a7b59")))
		piese.append(cub("Lada", (0.02, 0.34, 0.22), (lx + 0.24 * s, ly, 0.11), p("7a7b59")))
	piese.append(cub("Fund", (0.5, 0.34, 0.02), (lx, ly, 0.01), p("7a7b59")))
	for i in range(14):
		x = lx - 0.19 + (i % 5) * 0.095 + (0.04 if i // 5 == 1 else 0)
		y = ly - 0.1 + (i // 5) * 0.1
		piese.append(sfera("Cartof", 0.045, (x, y, 0.19 + (i % 2) * 0.02), AUR, scara=(1.3, 1, 0.9),
			segmente=6, inele=4))
	piese += [
		sfera("Sac", 0.14, (0.3, -0.62, 0.15), p("70706e"), scara=(1, 1, 1.1), segmente=8, inele=6),
		cilindru("Legatura", 0.04, 0.06, 0.08, (0.3, -0.62, 0.32), p("70706e"), laturi=6),
	]
	for dx, dy in ((-0.06, -0.12), (0.07, -0.1), (0.0, -0.14)):
		piese.append(sfera("Ceapa", 0.035, (0.3 + dx, -0.62 + dy, 0.2), p("904a40"), segmente=6, inele=4))
	uneste(piese, "ColtCamara")
	exporta(cale)


def calendar(cale):
	"""Calendar creștin-ortodox din 2009, încă pe perete. Originea: cuiul."""
	curata()
	piese = [
		cilindru("Cui", 0.006, 0.006, 0.03, (0, -0.015, 0), NEGRU, laturi=4, rot=(1.5708, 0, 0)),
		cub("Hartie", (0.3, 0.006, 0.46), (0, -0.006, -0.25), ALB),
		cub("Poza", (0.26, 0.004, 0.17), (0, -0.011, -0.12), p("2a3c3d")),
		cub("Biserica", (0.1, 0.004, 0.07), (0, -0.014, -0.17), CREM),
		sfera("Turla", 0.03, (0, -0.014, -0.11), AUR, scara=(1, 0.15, 1.3), segmente=6, inele=4),
		cub("Cruce", (0.006, 0.004, 0.04), (0, -0.015, -0.065), AUR),
		cub("Cruce", (0.02, 0.004, 0.006), (0, -0.015, -0.07), AUR),
		cub("Luna", (0.26, 0.004, 0.035), (0, -0.011, -0.235), ROSU),
		text("An", "2009", (0, -0.015, -0.235), 0.03, ALB),
	]
	for r in range(5):
		for c in range(7):
			cul = ROSU if c == 6 or (r, c) == (2, 2) else p("70706e")
			piese.append(cub("Zi", (0.022, 0.004, 0.018), (-0.105 + c * 0.035, -0.011, -0.285 - r * 0.035), cul))
	uneste(piese, "Calendar")
	exporta(cale)


def deasupra_frigiderului(cale):
	"""Ce stă pe frigider: mileu, vază cu flori de plastic și radioul. Originea: centrul capacului
	frigiderului (fața frigiderului spre -Y, ca în frigider.glb)."""
	curata()
	piese = [cilindru("Mileu", 0.24, 0.24, 0.004, (0, 0, 0.002), ALB, laturi=12)]
	for i in range(12):
		a = i * math.pi / 6 + math.pi / 12
		piese.append(cub("Dantela", (0.05, 0.05, 0.004), (0.25 * math.cos(a), 0.25 * math.sin(a), 0.002), ALB,
			rot=(0, 0, a + 0.785)))
	vx, vy = -0.12, 0.02
	piese += [
		cilindru("Vaza", 0.05, 0.035, 0.2, (vx, vy, 0.104), p("438b88"), laturi=8),
		cilindru("Buza", 0.045, 0.05, 0.02, (vx, vy, 0.21), p("438b88"), laturi=8),
	]
	for dx, dy, h, cul in ((-0.04, 0, 0.18, ROSU), (0.03, 0.02, 0.22, AUR), (0.0, -0.03, 0.15, p("904a40")),
			(0.04, -0.02, 0.2, p("655269"))):
		piese.append(cilindru("Tulpina", 0.004, 0.004, h, (vx + dx * 0.5, vy + dy * 0.5, 0.22 + h / 2), VERDE,
			laturi=4, rot=(dy * 4, -dx * 4, 0)))
		piese.append(sfera("Floare", 0.035, (vx + dx * 1.3, vy + dy * 1.3, 0.22 + h), cul, segmente=6, inele=4))
		piese.append(cub("Frunza", (0.05, 0.004, 0.02), (vx + dx, vy + dy, 0.24 + h * 0.4), VERDE,
			rot=(0, 0.4, dx * 20)))
	piese += [
		cub("Radio", (0.26, 0.12, 0.14), (0.1, 0.0, 0.074), LEMN_INCHIS),
		cub("Difuzor", (0.12, 0.004, 0.1), (0.05, -0.062, 0.074), p("5e5356")),
		cub("Scala", (0.08, 0.004, 0.04), (0.17, -0.062, 0.1), AUR),
		cub("Ac", (0.004, 0.005, 0.035), (0.16, -0.065, 0.1), ROSU),
		cilindru("Buton", 0.015, 0.015, 0.015, (0.15, -0.065, 0.04), CREM, laturi=6, rot=(1.5708, 0, 0)),
		cilindru("Buton", 0.015, 0.015, 0.015, (0.2, -0.065, 0.04), CREM, laturi=6, rot=(1.5708, 0, 0)),
		cilindru("Antena", 0.003, 0.003, 0.4, (0.2, 0.04, 0.3), INOX, laturi=4, rot=(0, 0.5, 0)),
	]
	for k in range(5):
		piese.append(cub("Grila", (0.12, 0.006, 0.006), (0.05, -0.065, 0.034 + k * 0.02), NEGRU))
	uneste(piese, "DeasupraFrigiderului")
	exporta(cale)


def pres(cale):
	"""Preș din cârpe, cu dungi și franjuri. Originea: centrul, jos. 1,3 × 0,65."""
	curata()
	culori = (ROSU, p("30716f"), AUR, p("655269"), VERDE, p("904a40"), p("295555"), ROSU, CREM)
	n = 13
	piese = []
	for i in range(n):
		piese.append(cub("Dunga", (1.3 / n, 0.65, 0.012), (-0.65 + (i + 0.5) * 1.3 / n, 0, 0.006),
			culori[i % len(culori)]))
	for s in (-1, 1):
		for k in range(12):
			piese.append(cub("Franj", (0.05, 0.012, 0.004), (s * 0.67, -0.3 + k * 0.055, 0.003), ALB))
	uneste(piese, "Pres")
	exporta(cale)


def rama(cale, nume, w, h, lat, cul, cul_interior, ornamente=False):
	"""Ramă de tablou pentru o pânză de w × h. Originea: centrul pânzei, pe perete.
	Pânza (cu poza) o pune Godot, la 0,013 în fața peretelui (tablou.gd); rama iese mai în față.
	Deasupra: cuiul și sfoara."""
	curata()
	ad = 0.04  # cât iese rama din perete
	W, H = w + 2 * lat, h + 2 * lat
	piese = [cub("Spate", (W - 0.01, 0.012, H - 0.01), (0, -0.006, 0), LEMN_INCHIS)]
	for s in (-1, 1):
		piese.append(cub("Bara", (W, ad, lat), (0, -ad / 2, s * (h + lat) / 2), cul))
		piese.append(cub("Bara", (lat, ad, h), (s * (w + lat) / 2, -ad / 2, 0), cul))
		# buza dinăuntru, mai închisă, coboară spre pânză
		piese.append(cub("Buza", (w + 0.02, 0.025, 0.012), (0, -0.0255, s * (h / 2 + 0.006)), cul_interior))
		piese.append(cub("Buza", (0.012, 0.025, h), (s * (w / 2 + 0.006), -0.0255, 0), cul_interior))
		# muchia din față, în relief
		piese.append(cub("Muchie", (W - lat, 0.01, 0.012), (0, -ad - 0.004, s * (h / 2 + lat * 0.55)), cul_interior))
		piese.append(cub("Muchie", (0.012, 0.01, H - lat), (s * (w / 2 + lat * 0.55), -ad - 0.004, 0), cul_interior))
	if ornamente:  # rozete în colțuri și o creastă sus, ca la ramele de la bunica
		for sx in (-1, 1):
			for sz in (-1, 1):
				piese.append(sfera("Rozeta", lat * 0.45, (sx * (w + lat) / 2, -ad - 0.005, sz * (h + lat) / 2), cul,
					scara=(1, 0.4, 1), segmente=6, inele=4))
		piese.append(sfera("Creasta", lat * 0.7, (0, -ad + 0.005, H / 2 + lat * 0.15), cul, scara=(2.2, 0.4, 0.9),
			segmente=8, inele=4))
		for sx in (-1, 1):
			piese.append(sfera("Voluta", lat * 0.4, (sx * 0.13, -ad + 0.005, H / 2), cul, scara=(1.5, 0.4, 0.8),
				segmente=6, inele=4))
	# cuiul și sfoara (două bucăți în V întors)
	cui_z = H / 2 + 0.12
	piese.append(cilindru("Cui", 0.007, 0.007, 0.03, (0, -0.015, cui_z), NEGRU, laturi=4, rot=(1.5708, 0, 0)))
	for s in (-1, 1):
		ax, az = s * W * 0.3, H / 2 - 0.02
		dx, dz = -ax, cui_z - az
		lung = math.hypot(dx, dz)
		piese.append(cub("Sfoara", (lung, 0.004, 0.004), (ax / 2, -0.008, (az + cui_z) / 2), p("7a7b59"),
			rot=(0, -math.atan2(dz, dx), 0)))
	uneste(piese, nume)
	exporta(cale)


def rame(modele):
	rama(os.path.join(modele, "rama_aurie.glb"), "RamaAurie", 0.55, 0.55, 0.08, AUR, p("904a40"), ornamente=True)
	rama(os.path.join(modele, "rama_lemn.glb"), "RamaLemn", 0.74, 0.48, 0.055, p("5e363e"), LEMN)
	rama(os.path.join(modele, "rama_alba.glb"), "RamaAlba", 0.74, 0.475, 0.05, CREM, p("70706e"))


def cuier(cale):
	"""Cuierul de pe hol: haina lui Mom, fularul, o căciulă, umbrela și papucii de dedesubt.
	Originea: perete, jos, la mijlocul cuierului (lat 0,9)."""
	curata()
	piese = [cub("Scandura", (0.9, 0.025, 0.14), (0, -0.0125, 1.72), LEMN_INCHIS)]
	for i, x in enumerate((-0.33, -0.11, 0.11, 0.33)):
		piese.append(cub("Carlig", (0.02, 0.08, 0.02), (x, -0.06, 1.7), INOX, rot=(-0.4, 0, 0)))
		piese.append(sfera("Bila", 0.014, (x, -0.1, 1.72), INOX, segmente=6, inele=4))
	# haina lungă pe primul cârlig
	hx = -0.33
	piese += [
		cub("Haina", (0.42, 0.14, 0.95), (hx, -0.1, 1.15), p("5e363e"), rot=(0, 0.03, 0)),
		cub("Guler", (0.24, 0.16, 0.12), (hx, -0.1, 1.62), p("553e4d")),
		cub("Maneca", (0.09, 0.12, 0.7), (hx - 0.2, -0.1, 1.25), p("5e363e"), rot=(0, -0.08, 0)),
		cub("Maneca", (0.09, 0.12, 0.7), (hx + 0.2, -0.1, 1.25), p("5e363e"), rot=(0, 0.08, 0)),
		cub("Cordon", (0.44, 0.15, 0.04), (hx, -0.1, 1.05), p("48313b")),
	]
	for z in (1.45, 1.3, 1.15, 0.95):
		piese.append(cilindru("Nasture", 0.015, 0.015, 0.01, (hx + 0.06, -0.176, z), NEGRU, laturi=6,
			rot=(1.5708, 0, 0)))
	# fularul roșu pe al treilea cârlig, căciula pe al patrulea
	piese += [
		cub("Fular", (0.1, 0.03, 0.6), (0.08, -0.1, 1.4), ROSU),
		cub("Fular", (0.1, 0.03, 0.5), (0.14, -0.08, 1.45), ROSU),
		cub("Dunga", (0.105, 0.035, 0.03), (0.08, -0.1, 1.15), ALB),
		cub("Dunga", (0.105, 0.035, 0.03), (0.14, -0.08, 1.24), ALB),
		sfera("Caciula", 0.1, (0.33, -0.1, 1.66), p("70706e"), scara=(1, 1, 0.8), segmente=8, inele=6),
		sfera("Mot", 0.035, (0.33, -0.1, 1.75), CREM, segmente=6, inele=4),
		# umbrela rezemată de perete
		cilindru("Umbrela", 0.05, 0.012, 0.75, (0.42, -0.08, 0.42), p("2a3c3d"), laturi=6, rot=(0, 0.15, 0)),
		cilindru("Varf", 0.005, 0.005, 0.06, (0.36, -0.08, 0.02), INOX, laturi=4),
		cub("Maner", (0.08, 0.02, 0.02), (0.48, -0.08, 0.81), LEMN, rot=(0, 0.6, 0)),
	]
	# papucii: ai lui Mom, pantofii de oraș și perechea „pentru musafiri”
	for k, (x, cul, inalt) in enumerate(((-0.35, p("655269"), 0.03), (-0.08, NEGRU, 0.07), (0.18, p("904a40"), 0.03))):
		for s in (-1, 1):
			px = x + s * 0.055
			piese.append(cub("Talpa", (0.085, 0.26, 0.02), (px, -0.2, 0.01), p("48313b") if k != 1 else NEGRU))
			piese.append(cub("Fata", (0.085, 0.13, inalt), (px, -0.25, 0.02 + inalt / 2), cul))
			if k == 1:
				piese.append(cub("Toc", (0.085, 0.08, 0.06), (px, -0.11, 0.05), cul))
	uneste(piese, "Cuier")
	exporta(cale)


def toate(modele):
	j = lambda n: os.path.join(modele, n)  # noqa: E731
	mobila_bucatarie(j("mobila_bucatarie.glb"))
	aragaz(j("aragaz.glb"))
	masa(j("masa_bucatarie.glb"))
	taburet(j("taburet.glb"))
	cutie_biscuiti(j("cutie_biscuiti.glb"))
	icoana(j("icoana.glb"))
	punga_pungi(j("punga_pungi.glb"))
	raft_borcane(j("raft_borcane.glb"))
	colt_camara(j("colt_camara.glb"))
	calendar(j("calendar.glb"))
	deasupra_frigiderului(j("deasupra_frigiderului.glb"))
	pres(j("pres.glb"))
	rame(modele)
	cuier(j("cuier.glb"))


if __name__ == "__main__":
	toate(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models"))
