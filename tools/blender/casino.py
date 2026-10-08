# „Casino”-ul: spălătoria „Wash Your Clothes” (clădire cu un etaj, firma și bannerul cu mașina de spălat), înăuntru
# două rânduri de mașini de spălat, iar în spate, după ușa „EMPLOYEES ONLY”, camera de joc în stil mafiot: masa de poker,
# păcănelele, tejgheaua bătrânei. Oamenii sunt în casino_oameni.py.
# Le apelează modele.py, dar merge și singur (mai repede, doar astea):
#   blender --background --factory-startup --python tools/blender/casino.py
#   blender ... --python tools/blender/casino.py -- cladire masina_spalat     (doar unele)
# Axe Blender: Z în sus, fața modelului spre -Y (în Godot devine +Z). Originea = la sol.
# Clădirea, strada și decorul sunt în coordonatele clădirii: originea = mijlocul fațadei (fața de afară), la nivelul
# străzii; în Godot le pui pe toate în același punct. Ce se mișcă sau se pune de mai multe ori (mașinile de spălat,
# păcănelele, scaunele, ușile) are originea lui.
import math
import os
import random
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, inel, text, uneste, exporta, trunchi, _termina  # noqa: E402
from lexy import perete, prisma, _copii  # noqa: E402
from coven import _lerp, _parinte  # noqa: E402
import casino_oameni  # noqa: E402

NEGRU = p("262d2f")
ALB = p("83b3b0")
AUR = p("a18463")
CROM = p("7e8d87")
METAL = p("6f6d7f")
METAL_INCHIS = p("5e5356")
GEAM = p("2a3c3d")
LEMN = p("5e363e")
LEMN_INCHIS = p("48313b")
ROSU = p("7b383a")
TENCUIALA = p("7e8d87")
SOCLU = p("5e5356")
FAIANTA = p("438b88")
FAIANTA_INCHISA = p("30716f")
TAPET = p("32453b")
TAPET_DUNGA = p("2a3c3d")
POSTAV = p("445d46")

# --- clădirea
W = 7.0      # jumătate din lățimea dinăuntru (x de la -W la W)
G = 0.25     # grosimea pereților
FL = 0.15    # podeaua (= trotuarul)
HC = 3.35    # tavanul (fața de jos)
Y1 = 12.0    # peretele dintre spălătorie și camera de joc (de la Y1 la Y1 + G)
Y2 = 22.0    # peretele din spate
TOP = 3.7    # acoperișul (fața de sus)
USA_FATA = (-0.55, 0.55, FL, FL + 2.3)
FER_FATA = [(-6.3, -1.0), (1.0, 6.3)]
FER_Z = (0.75, 2.75)
USA_SPATE = (2.9, 3.95, FL, FL + 2.15)


def _cutie_coliziune(col, dim, loc):
	col.append(cub("Coliziune", dim, loc, NEGRU))


def _tor(nume, raza, grosime, loc, culoare, scara=(1, 1, 1), rot=(0, 0, 0), segmente=16):
	"""Inel (tor), cu scară (oval) și rotație."""
	bpy.ops.mesh.primitive_torus_add(major_segments=segmente, minor_segments=4, major_radius=raza, minor_radius=grosime,
		location=loc, rotation=rot)
	return _termina(bpy.context.active_object, nume, culoare, scara)


def _text(nume, continut, loc, marime, culoare, rot=(1.5708, 0, 0), lat=None):
	"""Ca text() din unelte, dar cu grosime mai mare (literele de pe firmă se văd și din lateral)."""
	ob = text(nume, continut, loc, marime, culoare, rot)
	return ob


def _text_o_fata(nume, continut, loc, marime, culoare, rot=(1.5708, 0, 0)):
	"""Text plat, cu o singură față (cea din față): din spate nu se vede deloc (shader-ul are cull_back), deci nu apare
	scris invers. Pentru autocolantele de pe geamuri, puse câte unul pe fiecare parte a sticlei."""
	bpy.ops.object.text_add(location=loc, rotation=rot)
	ob = bpy.context.active_object
	ob.data.body = continut
	ob.data.size = marime
	ob.data.extrude = 0.0
	ob.data.fill_mode = 'FRONT'
	ob.data.resolution_u = 1
	ob.data.align_x = 'CENTER'
	ob.data.align_y = 'CENTER'
	bpy.ops.object.convert(target='MESH')
	ob = bpy.context.active_object
	# toate fețele spre +Z local (adică spre partea dorită, după rotație)
	for f in ob.data.polygons:
		if f.normal.z < 0:
			f.flip()
	ob.data.update()
	return _termina(ob, nume, culoare)


# ---------------------------------------------------------------------------------------------------------------
# Clădirea și strada
# ---------------------------------------------------------------------------------------------------------------

def cladire(cale):
	"""Clădirea cu un etaj: fațada cu vitrine și firma „WASH YOUR CLOTHES”, bannerul cu mașina de spălat, copertina în
	dungi, pereții de afară; înăuntru podeaua în carouri, faianța, tavanul cu neoane, peretele despărțitor cu golul ușii
	din spate, camera de joc (parchet, lambriu, tapet în dungi, tavan închis). Piese: `Cladire`, `Lumini` (literele firmei,
	neoanele, aplicele, neonul „POKER”), `Geamuri` (vitrinele), `Coliziune`."""
	curata()
	r = random.Random(5)
	piese, lumini, geamuri, col = [], [], [], []

	def strange():
		piese[:] = [uneste(piese, "Cladire")]

	# --- podelele
	# spălătoria: plăci 0,5 m în carouri (fiecare placă e o cutie; nu stau una peste alta)
	pas = 0.5
	nx, ny = int(2 * W / pas), int((Y1 - G) / pas)
	for i in range(nx):
		for j in range(ny):
			cul = ALB if (i + j) % 2 == 0 else METAL
			x = -W + (i + 0.5) * pas
			y = G + (j + 0.5) * pas
			hy = pas if j < ny - 1 else (Y1 - G) - (ny - 1) * pas
			piese.append(cub("Placa", (pas, hy, 0.02), (x, G + j * pas + hy / 2, FL - 0.01), cul))
		if i % 6 == 5:
			strange()
	piese.append(cub("Sapa", (2 * W + 2 * G, Y2 + G, 0.2), (0, (Y2 + G) / 2, FL - 0.12), SOCLU))
	_cutie_coliziune(col, (2 * W + 2 * G, Y2 + G, 0.3), (0, (Y2 + G) / 2, FL - 0.15))
	# camera de joc: parchet în scânduri pe Y, două nuanțe
	k = 0
	x = -W
	while x < W - 0.001:
		lat = min(0.18, W - x)
		piese.append(cub("Scandura", (lat, Y2 - Y1 - G, 0.02), (x + lat / 2, (Y1 + G + Y2) / 2, FL - 0.01),
			LEMN if k % 3 else LEMN_INCHIS))
		x += lat
		k += 1
	strange()
	# pragul ușii din spate
	piese.append(cub("Prag", (USA_SPATE[1] - USA_SPATE[0], G, 0.02), ((USA_SPATE[0] + USA_SPATE[1]) / 2, Y1 + G / 2, FL - 0.01), METAL))

	# --- pereții (afară tencuială, înăuntru faianță / tapet: două straturi, fiecare de G/2)
	g2 = G / 2
	# fațada: afară (y 0..g2) și înăuntru (g2..G), cu vitrinele și ușa
	goluri = [(USA_FATA[0], USA_FATA[1], USA_FATA[2] - 0.2, USA_FATA[3])] + [(a, b, FER_Z[0], FER_Z[1]) for a, b in FER_FATA]
	perete(piese, "Fatada", "x", -W - G, W + G, 0.0, g2, 0.0, TOP, TENCUIALA, goluri)
	perete(piese, "Fatada int", "x", -W, W, g2, G, FL, HC, ALB, goluri)
	for a, b in [(-W - G, USA_FATA[0])] + [(USA_FATA[1], W + G)]:
		_cutie_coliziune(col, (b - a, G, TOP), ((a + b) / 2, G / 2, TOP / 2))
	_cutie_coliziune(col, (USA_FATA[1] - USA_FATA[0], G, TOP - USA_FATA[3]), (0, G / 2, (TOP + USA_FATA[3]) / 2))
	# soclul de afară (sub vitrine), puțin în față
	for a, b in [(-W - G, USA_FATA[0]), (USA_FATA[1], W + G)]:
		piese.append(cub("Soclu", (b - a, 0.03, 0.72), ((a + b) / 2, -0.015, 0.36), SOCLU))
	# laterale și spate: afară tencuială (cu soclu), înăuntru faianță în spălătorie și tapet în camera de joc
	for s in (-1, 1):
		piese.append(cub("Perete lateral", (g2, Y2 + G - g2 * 0, TOP), (s * (W + G - g2 / 2), (Y2 + G) / 2, TOP / 2), TENCUIALA))
		piese.append(cub("Soclu lateral", (0.03, Y2 + G, 0.6), (s * (W + G + 0.015), (Y2 + G) / 2, 0.3), SOCLU))
		piese.append(cub("Faianta", (g2, Y1 - G, HC - FL), (s * (W + g2 / 2), (G + Y1) / 2, (FL + HC) / 2), ALB))
		piese.append(cub("Perete camera", (g2, Y2 - Y1 - G, HC - FL), (s * (W + g2 / 2), (Y1 + G + Y2) / 2, (FL + HC) / 2), TAPET))
		_cutie_coliziune(col, (G, Y2 + G, TOP), (s * (W + G / 2), (Y2 + G) / 2, TOP / 2))
	piese.append(cub("Spate", (2 * W + 2 * G, g2, TOP), (0, Y2 + G - g2 / 2, TOP / 2), TENCUIALA))
	piese.append(cub("Spate int", (2 * W, g2, HC - FL), (0, Y2 + g2 / 2, (FL + HC) / 2), TAPET))
	_cutie_coliziune(col, (2 * W + 2 * G, G, TOP), (0, Y2 + G / 2, TOP / 2))
	# peretele despărțitor cu golul ușii din spate
	gol = [(USA_SPATE[0], USA_SPATE[1], FL - 0.1, USA_SPATE[3])]
	perete(piese, "Despartitor", "x", -W, W, Y1, Y1 + g2, FL, HC, ALB, gol)
	perete(piese, "Despartitor camera", "x", -W, W, Y1 + g2, Y1 + G, FL, HC, TAPET, gol)
	_cutie_coliziune(col, (USA_SPATE[0] + W, G, HC), ((-W + USA_SPATE[0]) / 2, Y1 + G / 2, HC / 2))
	_cutie_coliziune(col, (W - USA_SPATE[1], G, HC), ((W + USA_SPATE[1]) / 2, Y1 + G / 2, HC / 2))
	_cutie_coliziune(col, (USA_SPATE[1] - USA_SPATE[0], G, HC - USA_SPATE[3]),
		((USA_SPATE[0] + USA_SPATE[1]) / 2, Y1 + G / 2, (HC + USA_SPATE[3]) / 2))
	strange()

	# --- spălătoria pe dinăuntru: faianță turcoaz până la 1,25 m, brâu, plinta
	def brau(x0, x1, y0, y1, axa):
		# faianța de jos: plăci 15 cm (benzi) cu 1 cm în fața peretelui alb
		if axa == "x":
			piese.append(cub("Faianta jos", (x1 - x0, 0.012, 1.1), ((x0 + x1) / 2, y0, FL + 0.55), FAIANTA))
			piese.append(cub("Brau", (x1 - x0, 0.024, 0.06), ((x0 + x1) / 2, y0, FL + 1.12), FAIANTA_INCHISA))
		else:
			piese.append(cub("Faianta jos", (0.012, y1 - y0, 1.1), (x0, (y0 + y1) / 2, FL + 0.55), FAIANTA))
			piese.append(cub("Brau", (0.024, y1 - y0, 0.06), (x0, (y0 + y1) / 2, FL + 1.12), FAIANTA_INCHISA))
	for s in (-1, 1):
		brau(s * (W - 0.006), 0, G, Y1, "y")
	# peretele din spate al spălătoriei (fără golul ușii)
	for a, b in ((-W, USA_SPATE[0]), (USA_SPATE[1], W)):
		piese.append(cub("Faianta jos", (b - a, 0.012, 1.1), ((a + b) / 2, Y1 - 0.006, FL + 0.55), FAIANTA))
		piese.append(cub("Brau", (b - a, 0.024, 0.06), ((a + b) / 2, Y1 - 0.012, FL + 1.12), FAIANTA_INCHISA))
	# rosturile faianței: linii închise la fiecare 15 cm (doar pe laterale, unde se văd între mașini)
	for s in (-1, 1):
		for z in (0.3, 0.45, 0.6, 0.75, 0.9, 1.05):
			piese.append(cub("Rost", (0.004, Y1 - G, 0.006), (s * (W - 0.014), (G + Y1) / 2, FL + z), FAIANTA_INCHISA))

	# tavanul: casete albe cu profile metalice, neoane în două rânduri
	piese.append(cub("Tavan", (2 * W, Y1 - G, 0.1), (0, (G + Y1) / 2, HC + 0.05), ALB))
	for x in [-W + 1.2 * i for i in range(1, 12)]:
		piese.append(cub("Profil", (0.03, Y1 - G, 0.012), (x, (G + Y1) / 2, HC - 0.006), METAL))
	for y in [G + 1.2 * j for j in range(1, 10)]:
		piese.append(cub("Profil", (2 * W, 0.03, 0.01), (0, y, HC - 0.016), METAL))
	for x in (-2.4, 2.4):
		for y in (2.0, 5.2, 8.4, 11.0):
			piese.append(cub("Corp neon", (0.32, 1.3, 0.06), (x, y, HC - 0.05), METAL))
			for dx in (-0.08, 0.08):
				lumini.append(cub("Neon", (0.05, 1.22, 0.03), (x + dx, y, HC - 0.095), ALB))
	strange()

	# --- camera de joc: lambriu, brâu, tapet cu dungi, cornișă, tavan închis cu grinzi
	def lambriu(x0, x1, y0, y1, axa, spre):
		lung = (x1 - x0) if axa == "x" else (y1 - y0)
		n = max(1, int(lung / 0.9))
		for i in range(n + 1):
			u = (x0 if axa == "x" else y0) + i * lung / n
			if axa == "x":
				piese.append(cub("Montant", (0.06, 0.03, 1.0), (u, y0 + spre * 0.015, FL + 0.5), LEMN_INCHIS))
			else:
				piese.append(cub("Montant", (0.03, 0.06, 1.0), (x0 + spre * 0.015, u, FL + 0.5), LEMN_INCHIS))
		if axa == "x":
			piese.append(cub("Lambriu", (lung, 0.012, 1.0), ((x0 + x1) / 2, y0 + spre * 0.006, FL + 0.5), LEMN))
			piese.append(cub("Brau lemn", (lung, 0.05, 0.06), ((x0 + x1) / 2, y0 + spre * 0.025, FL + 1.03), LEMN_INCHIS))
			piese.append(cub("Plinta", (lung, 0.04, 0.1), ((x0 + x1) / 2, y0 + spre * 0.02, FL + 0.05), NEGRU))
			piese.append(cub("Cornisa", (lung, 0.08, 0.12), ((x0 + x1) / 2, y0 + spre * 0.04, HC - 0.06), LEMN_INCHIS))
			for d in range(int(lung / 0.32)):
				piese.append(cub("Dunga tapet", (0.05, 0.008, HC - FL - 1.18), (x0 + 0.16 + d * 0.32, y0 + spre * 0.004,
					(FL + 1.06 + HC - 0.12) / 2), TAPET_DUNGA))
		else:
			piese.append(cub("Lambriu", (0.012, lung, 1.0), (x0 + spre * 0.006, (y0 + y1) / 2, FL + 0.5), LEMN))
			piese.append(cub("Brau lemn", (0.05, lung, 0.06), (x0 + spre * 0.025, (y0 + y1) / 2, FL + 1.03), LEMN_INCHIS))
			piese.append(cub("Plinta", (0.04, lung, 0.1), (x0 + spre * 0.02, (y0 + y1) / 2, FL + 0.05), NEGRU))
			piese.append(cub("Cornisa", (0.08, lung, 0.12), (x0 + spre * 0.04, (y0 + y1) / 2, HC - 0.06), LEMN_INCHIS))
			for d in range(int(lung / 0.32)):
				piese.append(cub("Dunga tapet", (0.008, 0.05, HC - FL - 1.18), (x0 + spre * 0.004, y0 + 0.16 + d * 0.32,
					(FL + 1.06 + HC - 0.12) / 2), TAPET_DUNGA))
	ya, yb = Y1 + G, Y2
	lambriu(-W, W, yb, yb, "x", -1)
	lambriu(-W, USA_SPATE[0] - 0.08, ya, ya, "x", 1)
	lambriu(USA_SPATE[1] + 0.08, W, ya, ya, "x", 1)
	lambriu(-W, -W, ya, yb, "y", 1)
	lambriu(W, W, ya, yb, "y", -1)
	strange()
	piese.append(cub("Tavan camera", (2 * W, Y2 - Y1 - G, 0.1), (0, (Y1 + G + Y2) / 2, HC + 0.05), NEGRU))
	for y in (14.5, 17.1, 19.7):
		piese.append(cub("Grinda", (2 * W, 0.22, 0.18), (0, y, HC - 0.09), LEMN_INCHIS))
	# aplicele de pe pereții laterali (un abajur roșu, becul strălucește); în stânga, prima e lângă ușă, înaintea păcănelelor
	for s in (-1, 1):
		for y in ((12.95, 20.5) if s < 0 else (16.0, 20.5)):
			xa = s * (W - 0.12)
			piese.append(cub("Aplica", (0.04, 0.12, 0.2), (s * (W - 0.02), y, 2.05), AUR))
			piese.append(trunchi("Abajur", [((xa, y, 2.12), 0.06, 0.06), ((xa, y, 2.3), 0.1, 0.1)], ROSU, laturi=8, capete=False))
			lumini.append(sfera("Bec aplica", 0.035, (xa, y, 2.16), AUR, segmente=6, inele=4))
	# neonul „POKER” pe peretele din spate, pe o placă neagră
	piese.append(cub("Placa neon", (2.2, 0.04, 0.6), (0, Y2 - 0.04, 2.55), NEGRU))
	lumini.append(_text("Neon poker", "POKER", (0, Y2 - 0.075, 2.55), 0.42, ROSU, rot=(1.5708, 0, 0)))
	for s in (-1, 1):
		lumini.append(_text("Neon pica", "*", (s * 0.85, Y2 - 0.075, 2.5), 0.38, AUR, rot=(1.5708, 0, 0)))
	strange()

	# --- tocurile ușilor
	for (a, b, za, zb), y0, y1 in ((USA_FATA, 0.0, G), (USA_SPATE, Y1, Y1 + G)):
		cul = CROM if y0 == 0 else LEMN_INCHIS
		piese.append(cub("Toc", (0.06, y1 - y0 + 0.02, zb - za), (a + 0.03, (y0 + y1) / 2, (za + zb) / 2), cul))
		piese.append(cub("Toc", (0.06, y1 - y0 + 0.02, zb - za), (b - 0.03, (y0 + y1) / 2, (za + zb) / 2), cul))
		piese.append(cub("Toc", (b - a, y1 - y0 + 0.02, 0.06), ((a + b) / 2, (y0 + y1) / 2, zb - 0.03), cul))
	# deasupra ușii din spate, pe partea spălătoriei: „EMPLOYEES ONLY”
	piese.append(cub("Placuta", (0.9, 0.02, 0.16), ((USA_SPATE[0] + USA_SPATE[1]) / 2, Y1 - 0.012, USA_SPATE[3] + 0.17), ROSU))
	piese.append(_text("Scris placuta", "EMPLOYEES ONLY", ((USA_SPATE[0] + USA_SPATE[1]) / 2, Y1 - 0.024, USA_SPATE[3] + 0.17), 0.085, ALB))

	# --- vitrinele: geamul, ramele de aluminiu, montanții, autocolantele
	for a, b in FER_FATA:
		geamuri.append(cub("Geam", (b - a, 0.012, FER_Z[1] - FER_Z[0]), ((a + b) / 2, g2, (FER_Z[0] + FER_Z[1]) / 2), GEAM))
		for x in (a, b):
			piese.append(cub("Rama vitrina", (0.07, G + 0.04, FER_Z[1] - FER_Z[0]), (x, G / 2, (FER_Z[0] + FER_Z[1]) / 2), CROM))
		for z in FER_Z:
			piese.append(cub("Rama vitrina", (b - a, G + 0.04, 0.07), ((a + b) / 2, G / 2, z), CROM))
		for x in (a + (b - a) / 3, a + 2 * (b - a) / 3):
			piese.append(cub("Montant vitrina", (0.05, 0.08, FER_Z[1] - FER_Z[0]), (x, g2, (FER_Z[0] + FER_Z[1]) / 2), CROM))
		# pervazul de dinăuntru, cu un ghiveci și reviste
		piese.append(cub("Pervaz", (b - a, 0.3, 0.04), ((a + b) / 2, G + 0.15, FER_Z[0] - 0.02), ALB))
	# autocolantele lipite pe geamuri, câte unul pe fiecare parte a sticlei, cu o singură față: se citesc drept și de afară,
	# și dinăuntru („SELF SERVICE”, „COIN LAUNDRY”, „OPEN 24 HOURS”, „WASH DRY FOLD”)
	for continut, x, z, marime, cul in (("SELF SERVICE", -3.65, 2.45, 0.2, ALB), ("COIN LAUNDRY", 3.65, 2.45, 0.2, ALB),
			("OPEN 24 HOURS", 3.65, 1.0, 0.13, ROSU), ("WASH  DRY  FOLD", -3.65, 1.0, 0.13, ALB)):
		piese.append(_text_o_fata("Autocolant", continut, (x, g2 - 0.009, z), marime, cul))
		piese.append(_text_o_fata("Autocolant", continut, (x, g2 + 0.009, z), marime, cul, rot=(1.5708, 0, 3.14159)))

	# --- firma de pe parapet: placa, rama, literele (strălucesc); bannerul cu mașina de spălat în dreapta
	piese.append(cub("Parapet", (2 * W + 2 * G, G, 1.0), (0, G / 2, TOP + 0.5), TENCUIALA))
	piese.append(cub("Copertina parapet", (2 * W + 2 * G + 0.1, G + 0.1, 0.06), (0, G / 2, TOP + 1.03), METAL))
	_cutie_coliziune(col, (2 * W + 2 * G, Y2 + G, 0.3), (0, (Y2 + G) / 2, TOP - 0.15))
	piese.append(cub("Acoperis", (2 * W + 2 * G, Y2 + G, 0.25), (0, (Y2 + G) / 2, TOP - 0.125), METAL_INCHIS))
	fx0, fx1, fz0, fz1 = -6.6, 3.5, 3.82, 4.62
	piese.append(cub("Firma", (fx1 - fx0, 0.14, fz1 - fz0), ((fx0 + fx1) / 2, -0.07, (fz0 + fz1) / 2), GEAM))
	for z in (fz0, fz1):
		piese.append(cub("Rama firma", (fx1 - fx0 + 0.06, 0.18, 0.05), ((fx0 + fx1) / 2, -0.07, z), FAIANTA))
	for x in (fx0, fx1):
		piese.append(cub("Rama firma", (0.05, 0.18, fz1 - fz0), (x, -0.07, (fz0 + fz1) / 2), FAIANTA))
	lumini.append(_text("Litere firma", "WASH YOUR CLOTHES", ((fx0 + fx1) / 2, -0.152, (fz0 + fz1) / 2 - 0.02), 0.56, ALB))
	# bannerul de pânză, prins în inele de parapet: mașina de spălat desenată (cutia, hublou cu apă și spumă, butoanele)
	bx, bz = 5.35, 4.22
	bw, bh = 2.8, 0.88
	piese.append(cub("Banner", (bw, 0.02, bh), (bx, -0.03, bz), ALB))
	piese.append(cub("Tiv banner", (bw, 0.04, 0.05), (bx, -0.03, bz + bh / 2 - 0.025), FAIANTA))
	piese.append(cub("Tiv banner", (bw, 0.04, 0.05), (bx, -0.03, bz - bh / 2 + 0.025), FAIANTA))
	for sx in (-1, 1):
		for sz in (-1, 1):
			piese.append(_tor("Ochet", 0.025, 0.008, (bx + sx * (bw / 2 - 0.06), -0.045, bz + sz * (bh / 2 - 0.06)), AUR,
				rot=(1.5708, 0, 0), segmente=8))
	mx = bx - 0.75  # desenul: mașina de spălat, în stânga bannerului
	piese.append(cub("Desen masina", (0.62, 0.012, 0.72), (mx, -0.046, bz - 0.02), CROM))
	piese.append(cub("Desen masina", (0.56, 0.012, 0.62), (mx, -0.058, bz - 0.05), ALB))
	piese.append(cub("Desen panou", (0.56, 0.012, 0.1), (mx, -0.058, bz + 0.27), METAL))
	for k in range(3):
		piese.append(cilindru("Desen buton", 0.025, 0.025, 0.012, (mx - 0.18 + k * 0.08, -0.068, bz + 0.27), ROSU if k == 0 else NEGRU,
			laturi=8, rot=(1.5708, 0, 0)))
	piese.append(cub("Desen afisaj", (0.14, 0.012, 0.05), (mx + 0.15, -0.068, bz + 0.27), FAIANTA))
	piese.append(_tor("Desen hublou", 0.2, 0.03, (mx, -0.07, bz - 0.08), METAL, rot=(1.5708, 0, 0)))
	piese.append(cilindru("Desen geam", 0.18, 0.18, 0.012, (mx, -0.066, bz - 0.08), FAIANTA, laturi=16, rot=(1.5708, 0, 0)))
	piese.append(cilindru("Desen apa", 0.15, 0.15, 0.012, (mx, -0.074, bz - 0.13), FAIANTA_INCHISA, laturi=16, rot=(1.5708, 0, 0),
		scara=(1, 1, 0.55)))
	for k in range(6):  # spuma: bule albe
		piese.append(cilindru("Desen spuma", 0.025 + 0.01 * (k % 2), 0.025 + 0.01 * (k % 2), 0.012,
			(mx - 0.12 + k * 0.05, -0.082, bz - 0.06 + 0.02 * math.sin(k * 2.1)), ALB, laturi=8, rot=(1.5708, 0, 0)))
	piese.append(_text("Scris banner", "SELF\nSERVICE", (bx + 0.55, -0.046, bz + 0.12), 0.2, ROSU))
	piese.append(_text("Scris banner", "OPEN 24/7", (bx + 0.55, -0.046, bz - 0.27), 0.13, NEGRU))
	# copertina în dungi de deasupra vitrinelor
	for k in range(14):
		x0 = -6.6 + k * 0.95
		cul = FAIANTA if k % 2 == 0 else ALB
		piese.append(cub("Copertina", (0.95, 1.0, 0.03), (x0 + 0.475, -0.48, 3.12), cul, rot=(-0.3, 0, 0)))
		piese.append(cub("Volan", (0.95, 0.02, 0.22), (x0 + 0.475, -0.955, 2.86), cul))
	piese.append(cub("Bara copertina", (13.4, 0.05, 0.05), (0.15, -0.01, 3.27), METAL))
	# pe lateral: țeava de scurgere, aparatul de aer condiționat, un graffiti
	for s in (-1, 1):
		piese.append(cilindru("Burlan", 0.05, 0.05, TOP, (s * (W + G + 0.06), 0.4, TOP / 2), METAL, laturi=6))
	piese.append(cub("Aer conditionat", (0.35, 0.8, 0.6), (W + G + 0.18, 4.5, 2.6), ALB))
	for k in range(5):
		piese.append(cub("Grila", (0.01, 0.6, 0.02), (W + G + 0.36, 4.5, 2.4 + k * 0.08), METAL))
	for k, cul in enumerate((ROSU, p("5b6d4e"), FAIANTA, ROSU)):
		piese.append(cub("Graffiti", (0.01, 0.5 + 0.2 * (k % 2), 0.12), (-(W + G + 0.006), 2.2 + k * 0.42, 1.2 + 0.18 * math.sin(k)), cul,
			rot=(0.3 * math.sin(k * 3), 0, 0)))
	strange()

	_copii_col = col
	uneste(piese, "Cladire")
	uneste(lumini, "Lumini")
	uneste(geamuri, "Geamuri")
	uneste(_copii_col, "Coliziune")
	exporta(os.path.join(cale, "casino_cladire.glb"))


def strada(cale):
	"""Strada din fața spălătoriei: trotuarul (la nivelul podelei), bordura, asfaltul cu marcaje, trotuarul de vizavi,
	un hidrant, capace de canal; clădirile vecine (amanetul din stânga, magazinul închis din dreapta,
	blocurile de vizavi, în ceață). Piese: `Strada`, `Lumini` (geamurile aprinse, firma amanetului), `Coliziune`."""
	curata()
	r = random.Random(9)
	piese, lumini, col = [], [], []
	L = 120.0
	# trotuarul (y de la -3,4 la 0, sus la FL), plăci de beton cu rosturi
	piese.append(cub("Trotuar", (L, 3.4, FL), (0, -1.7, FL / 2), p("70706e")))
	for x in range(-60, 61, 1):
		piese.append(cub("Rost", (0.012, 3.4, 0.02), (x * 1.0, -1.7, FL), METAL_INCHIS))
	piese.append(cub("Bordura", (L, 0.2, FL + 0.02), (0, -3.5, (FL + 0.02) / 2), p("7e8d87")))
	piese.append(cub("Asfalt", (L, 7.4, 0.05), (0, -7.3, -0.025), NEGRU))
	for x in range(-58, 60, 4):
		piese.append(cub("Marcaj", (2.0, 0.12, 0.02), (x, -7.3, 0.0), p("a18463")))
	piese.append(cub("Bordura", (L, 0.2, FL + 0.02), (0, -11.1, (FL + 0.02) / 2), p("7e8d87")))
	piese.append(cub("Trotuar", (L, 3.0, FL), (0, -12.7, FL / 2), p("70706e")))
	_cutie_coliziune(col, (L, 3.4, FL), (0, -1.7, FL / 2))
	_cutie_coliziune(col, (L, 0.2, FL + 0.02), (0, -3.5, (FL + 0.02) / 2))
	_cutie_coliziune(col, (L, 7.4, 0.05), (0, -7.3, -0.025))
	_cutie_coliziune(col, (L, 3.2, FL), (0, -12.6, FL / 2))
	for x in (-9.0, 12.0):
		piese.append(cilindru("Canal", 0.35, 0.35, 0.012, (x, -6.0, 0.006), METAL_INCHIS, laturi=12))
	# hidrantul (parcometrul de lângă stație l-am scos: stătea în fața stației Prundu și treceai prin el)
	piese += [
		cilindru("Hidrant", 0.11, 0.11, 0.55, (-7.9, -2.9, FL + 0.275), ROSU, laturi=8),
		sfera("Hidrant cap", 0.11, (-7.9, -2.9, FL + 0.55), ROSU, scara=(1, 1, 0.7), segmente=8, inele=4),
		cilindru("Hidrant gura", 0.05, 0.05, 0.3, (-7.9, -2.9, FL + 0.38), ROSU, laturi=6, rot=(0, 1.5708, 0)),
	]
	# vecinul din stânga: clădirea de cărămidă cu două etaje; parterul din dreapta (x de la -15 la -7,4, până la 3,6 m)
	# e amanetul lui Johnny, cu fațada și interiorul lui (amanet.py), deci aici e doar restul clădirii
	vx0, vx1, ax0, az1 = -22.0, -7.4, -15.0, 3.6
	piese.append(cub("Vecin stanga", (ax0 - vx0, 14.0, 7.2), ((vx0 + ax0) / 2, 7.0, 3.6), ROSU))
	_cutie_coliziune(col, (ax0 - vx0, 14.0, 7.2), ((vx0 + ax0) / 2, 7.0, 3.6))
	piese.append(cub("Vecin stanga", (vx1 - ax0, 14.0, 7.2 - az1), ((ax0 + vx1) / 2, 7.0, (az1 + 7.2) / 2), ROSU))
	_cutie_coliziune(col, (vx1 - ax0, 14.0, 7.2 - az1), ((ax0 + vx1) / 2, 7.0, (az1 + 7.2) / 2))
	piese.append(cub("Cornisa", (vx1 - ax0 + 0.1, 0.2, 0.12), ((ax0 + vx1) / 2, -0.1, az1 + 0.06), p("7e8d87")))
	for k in range(int((vx1 - vx0) / 0.6)):
		z = 0.25 * (k % 28)
		x = vx0 + 0.3 + k * 0.6
		if x > ax0 and z < az1 + 0.1:
			continue
		piese.append(cub("Rost caramida", (0.6, 0.01, 0.012), (x, -0.006, z), p("5e363e")))
	for x in (-19.5, -16.0, -12.5, -9.2):
		lumini.append(cub("Geam etaj", (1.2, 0.02, 1.4), (x, -0.012, 5.0), p("a18463") if x in (-16.0,) else GEAM))
		piese.append(cub("Pervaz", (1.35, 0.12, 0.06), (x, -0.06, 4.27), p("7e8d87")))
	# parterul din stânga amanetului: o vitrină goală, cu hârtie lipită pe geam
	piese.append(cub("Vitrina goala", (3.4, 0.02, 1.8), (-18.5, -0.012, 1.5), GEAM))
	for k in range(4):
		piese.append(cub("Hartie geam", (0.7, 0.012, 1.6), (-19.6 + k * 0.75, -0.02, 1.5), p("a18463") if k % 2 else p("7e8d87")))
	# vecinul din dreapta: magazinul închis, cu oblon tras și un „FOR RENT”
	dx0, dx1 = 7.4, 21.0
	piese.append(cub("Vecin dreapta", (dx1 - dx0, 14.0, 5.0), ((dx0 + dx1) / 2, 7.0, 2.5), p("70706e")))
	_cutie_coliziune(col, (dx1 - dx0, 14.0, 5.0), ((dx0 + dx1) / 2, 7.0, 2.5))
	piese.append(cub("Oblon", (5.0, 0.04, 2.6), (13.0, -0.02, 1.4), METAL))
	for k in range(26):
		piese.append(cub("Lamela oblon", (5.0, 0.02, 0.012), (13.0, -0.045, 0.15 + k * 0.1), METAL_INCHIS))
	piese.append(cub("Cutie oblon", (5.2, 0.3, 0.3), (13.0, -0.15, 2.85), METAL_INCHIS))
	piese.append(cub("Afis", (0.8, 0.012, 0.5), (16.6, -0.008, 1.6), ALB))
	piese.append(_text("Scris afis", "FOR\nRENT", (16.6, -0.016, 1.6), 0.14, ROSU))
	for k, cul in enumerate((p("5b6d4e"), ROSU, FAIANTA)):
		piese.append(cub("Graffiti oblon", (0.9 + 0.3 * k, 0.01, 0.25), (11.5 + k * 1.2, -0.07, 1.0 + 0.3 * k), cul, rot=(0, 0.2 * (k - 1), 0)))
	# vizavi: blocuri de 4 etaje, în ceață (fără coliziune; sunt dincolo de limite)
	for k in range(5):
		bx = -40 + k * 20 + r.uniform(-2, 2)
		h = r.choice((9.0, 12.0, 14.5))
		piese.append(cub("Bloc vizavi", (16.0, 10.0, h), (bx, -20.0, h / 2), r.choice((p("70706e"), p("6f6d7f"), p("7e8d87")))))
		for fx in range(5):
			for fz in range(int(h / 3) - 1):
				aprins = r.random() < 0.15
				(lumini if aprins else piese).append(cub("Geam bloc", (1.2, 0.02, 1.2), (bx - 6 + fx * 3, -14.99, 2.5 + fz * 3),
					p("a18463") if aprins else GEAM))
		# aleea de beton de la trotuar până la ușa scării (sub geamurile de la parter)
		piese.append(cub("Alee bloc", (2.0, 0.8, 0.04), (bx, -14.6, 0.0), p("70706e")))
		piese.append(cub("Usa bloc", (1.4, 0.02, 1.8), (bx, -14.97, 0.9), METAL_INCHIS))
	# terenul de sub tot (iarbă), ca nimic să nu stea în aer: vizavi, între blocuri, în spatele vecinilor
	piese.append(cub("Teren", (L, 110.0, 0.1), (0, -15.0, -0.11), p("5b6d4e")))
	# între blocuri: aleile de asfalt spre parcările din spate, cu dungi
	for k in range(4):
		px = -30 + k * 20
		piese.append(cub("Parcare", (3.6, 10.8, 0.04), (px, -20.0, -0.04), NEGRU))
		piese.append(cub("Dunga parcare", (0.1, 10.8, 0.01), (px, -20.0, -0.015), p("a18463")))
	# copacii de toamnă din trotuarul de vizavi (groapa cu pământ, trunchiul, ramuri, coroana rară)
	for k in range(9):
		tx = -44 + k * 11 + r.uniform(-1.5, 1.5)
		piese.append(cub("Groapa copac", (1.0, 1.0, 0.02), (tx, -13.4, FL), LEMN_INCHIS))
		piese.append(cilindru("Trunchi copac", 0.13, 0.09, 3.2, (tx, -13.4, FL + 1.6), LEMN_INCHIS, laturi=6))
		for j in range(3):
			a = j * 2.1 + r.uniform(0, 1)
			piese.append(os_intre("Ramura", (tx, -13.4, FL + 2.3 + j * 0.3),
				(tx + 0.8 * math.cos(a), -13.4 + 0.6 * math.sin(a), FL + 3.1 + j * 0.25), 0.04, LEMN_INCHIS, laturi=4))
		# coroana: smocuri mici de frunze în culori de toamnă, în jurul capetelor ramurilor (nu o singură bilă)
		for j in range(7):
			a = j * 0.9 + r.uniform(0, 0.5)
			dist = r.uniform(0.25, 0.75)
			cul = r.choice((p("a18463"), p("a18463"), p("7b383a"), p("904a40"), p("5b6d4e")))
			piese.append(sfera("Coroana", r.uniform(0.38, 0.6), (tx + dist * math.cos(a), -13.4 + dist * 0.7 * math.sin(a),
				FL + 3.2 + r.uniform(0.0, 0.9)), cul, scara=(1, 1, 0.75), segmente=6, inele=4))
	uneste(piese, "Strada")
	uneste(lumini, "Lumini")
	uneste(col, "Coliziune")
	exporta(os.path.join(cale, "casino_strada.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Decorul: spălătoria și camera de joc
# ---------------------------------------------------------------------------------------------------------------

def _scaun_plastic(piese, x, y, unghi, cul):
	"""Scaun de plastic (cochilie) pe picioare metalice; `unghi` = încotro privește (0 = -Y)."""
	c, s = math.cos(unghi), math.sin(unghi)
	def R(dx, dy, z):
		return (x + dx * c - dy * s, y + dx * s + dy * c, z)
	piese.append(cub("Sezut plastic", (0.44, 0.42, 0.04), R(0, 0, FL + 0.44), cul, rot=(0, 0, unghi)))
	piese.append(cub("Spatar plastic", (0.44, 0.04, 0.4), R(0, 0.22, FL + 0.68), cul, rot=(0.12, 0, unghi)))
	for dx in (-0.19, 0.19):
		for dy in (-0.17, 0.17):
			piese.append(cilindru("Picior scaun", 0.012, 0.012, 0.42, R(dx, dy, FL + 0.21), CROM, laturi=4))


def _cos_rufe(piese, x, y, z, cul, r):
	"""Coș de rufe de plastic, cu haine mototolite în el."""
	piese.append(cub("Cos", (0.5, 0.36, 0.26), (x, y, z + 0.13), cul))
	for k in range(5):
		piese.append(cub("Gaura cos", (0.06, 0.012, 0.03), (x - 0.16 + k * 0.08, y - 0.186, z + 0.15), p("2a3c3d")))
	for k in range(5):
		piese.append(sfera("Haine", 0.1, (x + r.uniform(-0.12, 0.12), y + r.uniform(-0.08, 0.08), z + 0.26 + r.uniform(0, 0.04)),
			r.choice((ALB, ROSU, FAIANTA, p("a18463"), p("5b6d4e"))), scara=(1.2, 0.9, 0.5), segmente=6, inele=4))


def _sticla_detergent(piese, x, y, z, cul):
	piese.append(cub("Detergent", (0.12, 0.08, 0.24), (x, y, z + 0.12), cul))
	piese.append(cilindru("Dop detergent", 0.025, 0.025, 0.04, (x - 0.03, y, z + 0.26), ROSU, laturi=6))
	piese.append(cub("Eticheta detergent", (0.09, 0.006, 0.08), (x, y - 0.048, z + 0.12), ALB))


def _sticla_bar(piese, x, y, z, cul, inalta=True):
	h = 0.3 if inalta else 0.22
	piese.append(trunchi("Sticla bar", [((x, y, z), 0.0, 0.0), ((x, y, z + 0.002), 0.04, 0.04), ((x, y, z + h * 0.65), 0.042, 0.042),
		((x, y, z + h * 0.8), 0.016, 0.016), ((x, y, z + h), 0.014, 0.014), ((x, y, z + h + 0.002), 0.0, 0.0)], cul, laturi=8))
	piese.append(trunchi("Eticheta", [((x, y, z + h * 0.25), 0.0435, 0.0435), ((x, y, z + h * 0.45), 0.0435, 0.0435)], ALB, laturi=8))


def decor_spalatorie(cale):
	"""Ce e în spălătorie, în afară de mașini (care sunt modele separate): uscătoarele de pe peretele din spate, mesele de
	împăturit cu coșuri și detergenți, cărucioarele de rufe, scaunele de lângă vitrine, aparatul de mărunțit bani,
	automatul cu detergent, avizierul, ceasul, prețurile, televizorul din colț, coșul de gunoi, găleata cu mop și semnul
	„WET FLOOR”, ghiveciul. Piese: `Decor`, `Lumini` (ecranele aparatelor, televizorul), `Geamuri`, `Coliziune`."""
	curata()
	r = random.Random(17)
	piese, lumini, geamuri, col = [], [], [], []

	# uscătoarele: 6 coloane câte două, cu hublourile mari (în spate, la stânga ușii)
	for i in range(6):
		x = -6.5 + i * 0.92
		for etaj in range(2):
			z0 = FL + etaj * 0.98
			piese.append(cub("Uscator", (0.9, 0.8, 0.96), (x, Y1 - 0.4, z0 + 0.48), ALB))
			piese.append(cub("Panou uscator", (0.86, 0.012, 0.14), (x, Y1 - 0.806, z0 + 0.86), METAL))
			piese.append(cub("Monede uscator", (0.08, 0.012, 0.08), (x + 0.3, Y1 - 0.816, z0 + 0.86), AUR))
			lumini.append(cub("Afisaj uscator", (0.16, 0.012, 0.05), (x - 0.22, Y1 - 0.816, z0 + 0.86), FAIANTA))
			piese.append(_tor("Hublou uscator", 0.27, 0.035, (x, Y1 - 0.83, z0 + 0.42), METAL, rot=(1.5708, 0, 0)))
			geamuri.append(cilindru("Geam uscator", 0.24, 0.24, 0.012, (x, Y1 - 0.815, z0 + 0.42), GEAM, laturi=16, rot=(1.5708, 0, 0)))
			if r.random() < 0.4:  # rufe înăuntru (se văd prin geam)
				piese.append(sfera("Rufe uscator", 0.18, (x, Y1 - 0.6, z0 + 0.32), r.choice((ROSU, FAIANTA, ALB, p("a18463"))),
					scara=(1.1, 0.8, 0.6), segmente=6, inele=4))
			piese.append(cub("Maner uscator", (0.04, 0.03, 0.12), (x + 0.22, Y1 - 0.85, z0 + 0.42), METAL_INCHIS))
	_cutie_coliziune(col, (6 * 0.92, 0.82, 2.0), (-6.5 + 2.5 * 0.92, Y1 - 0.41, FL + 1.0))
	piese.append(cub("Cornisa uscatoare", (6 * 0.92, 0.82, 0.12), (-6.5 + 2.5 * 0.92, Y1 - 0.41, FL + 2.02), METAL))
	piese.append(cub("Scris uscatoare", (2.0, 0.012, 0.18), (-4.2, Y1 - 0.83, FL + 2.3), ROSU))
	piese.append(_text("Scris", "DRYERS  $1.00 / 10 MIN", (-4.2, Y1 - 0.84, FL + 2.3), 0.09, ALB))

	# avizierul cu fluturași, ceasul
	piese.append(cub("Avizier", (1.4, 0.03, 0.9), (1.1, Y1 - 0.02, 1.7), p("a56850")))
	piese.append(cub("Rama avizier", (1.46, 0.035, 0.03), (1.1, Y1 - 0.02, 2.16), LEMN))
	piese.append(cub("Rama avizier", (1.46, 0.035, 0.03), (1.1, Y1 - 0.02, 1.24), LEMN))
	for k in range(9):
		cul = r.choice((ALB, p("a18463"), FAIANTA, ROSU, p("7a7b59")))
		piese.append(cub("Fluturas", (r.uniform(0.18, 0.28), 0.006, r.uniform(0.2, 0.3)),
			(0.55 + (k % 4) * 0.33 + r.uniform(-0.04, 0.04), Y1 - 0.04, 1.42 + (k // 4) * 0.27 + r.uniform(-0.03, 0.03)), cul,
			rot=(0, r.uniform(-0.12, 0.12), 0)))
		piese.append(cub("Pioneza", (0.02, 0.01, 0.02), (0.55 + (k % 4) * 0.33, Y1 - 0.046, 1.52 + (k // 4) * 0.27), ROSU))
	piese.append(cilindru("Ceas", 0.18, 0.18, 0.04, (1.1, Y1 - 0.03, 2.6), ALB, laturi=12, rot=(1.5708, 0, 0)))
	piese.append(_tor("Rama ceas", 0.18, 0.02, (1.1, Y1 - 0.045, 2.6), NEGRU, rot=(1.5708, 0, 0), segmente=12))
	piese.append(cub("Ac ceas", (0.012, 0.01, 0.12), (1.1, Y1 - 0.06, 2.65), NEGRU))
	piese.append(cub("Ac ceas", (0.1, 0.01, 0.012), (1.14, Y1 - 0.062, 2.6), NEGRU))

	# aparatul de schimbat bani și automatul cu detergent (în spate, la dreapta ușii)
	ax = 4.7
	piese.append(cub("Aparat schimb", (0.7, 0.5, 1.7), (ax, Y1 - 0.25, FL + 0.85), METAL))
	piese.append(cub("Fata aparat", (0.6, 0.012, 0.5), (ax, Y1 - 0.506, FL + 1.3), METAL_INCHIS))
	piese.append(cub("Firma aparat", (0.66, 0.02, 0.18), (ax, Y1 - 0.51, FL + 1.75), ROSU))
	piese.append(_text("Scris aparat", "CHANGE", (ax, Y1 - 0.524, FL + 1.75), 0.11, ALB))
	piese.append(cub("Fanta bancnote", (0.2, 0.02, 0.05), (ax, Y1 - 0.52, FL + 1.2), NEGRU))
	lumini.append(cub("Bec fanta", (0.22, 0.012, 0.012), (ax, Y1 - 0.522, FL + 1.24), p("5b6d4e")))
	piese.append(cub("Tava monede", (0.3, 0.1, 0.1), (ax, Y1 - 0.55, FL + 0.7), METAL_INCHIS))
	_cutie_coliziune(col, (0.7, 0.5, 1.7), (ax, Y1 - 0.25, FL + 0.85))
	vx = 5.9
	piese.append(cub("Automat", (0.9, 0.6, 1.85), (vx, Y1 - 0.3, FL + 0.925), ROSU))
	geamuri.append(cub("Geam automat", (0.6, 0.012, 1.1), (vx - 0.1, Y1 - 0.606, FL + 1.1), GEAM))
	for rand in range(4):
		for c_ in range(4):
			piese.append(cub("Produs", (0.1, 0.1, 0.16), (vx - 0.32 + c_ * 0.145, Y1 - 0.5, FL + 0.66 + rand * 0.26),
				r.choice((ALB, FAIANTA, p("a18463"), p("5b6d4e")))))
		piese.append(cub("Raft automat", (0.6, 0.2, 0.012), (vx - 0.1, Y1 - 0.5, FL + 0.57 + rand * 0.26), METAL))
	piese.append(cub("Tastatura", (0.16, 0.012, 0.3), (vx + 0.3, Y1 - 0.606, FL + 1.25), METAL_INCHIS))
	lumini.append(cub("Afisaj automat", (0.14, 0.012, 0.05), (vx + 0.3, Y1 - 0.612, FL + 1.45), p("5b6d4e")))
	piese.append(cub("Gura automat", (0.5, 0.012, 0.15), (vx - 0.1, Y1 - 0.606, FL + 0.32), NEGRU))
	_cutie_coliziune(col, (0.9, 0.6, 1.85), (vx, Y1 - 0.3, FL + 0.925))

	# mesele de împăturit din mijloc, cu coșuri, detergenți, prosoape împăturite
	for y in (4.4, 7.8):
		piese.append(cub("Blat masa", (2.4, 0.9, 0.05), (0, y, FL + 0.9), ALB))
		piese.append(cub("Cant masa", (2.42, 0.92, 0.03), (0, y, FL + 0.865), METAL))
		for sx in (-1, 1):
			for sy in (-1, 1):
				piese.append(cilindru("Picior masa", 0.025, 0.025, 0.85, (sx * 1.1, y + sy * 0.38, FL + 0.425), CROM, laturi=6))
		piese.append(cub("Bara masa", (2.2, 0.03, 0.03), (0, y, FL + 0.15), CROM))
		_cutie_coliziune(col, (2.4, 0.9, 0.95), (0, y, FL + 0.475))
		_cos_rufe(piese, -0.6, y + 0.05, FL + 0.925, r.choice((FAIANTA, ROSU)), r)
		_sticla_detergent(piese, 0.5, y - 0.2, FL + 0.925, p("a18463"))
		for k in range(3):  # prosoape împăturite, în teanc
			piese.append(cub("Prosop", (0.36, 0.28, 0.05), (0.75, y + 0.15, FL + 0.95 + k * 0.05), r.choice((ALB, ROSU, FAIANTA, p("a18463")))))
	# cărucioarele de rufe (coș de sârmă pe roți, cu bara pentru umerașe)
	for x, y in ((1.8, 2.6), (-1.9, 9.6)):
		piese.append(cub("Carucior", (0.7, 0.5, 0.45), (x, y, FL + 0.55), METAL))
		piese.append(cub("Interior carucior", (0.64, 0.44, 0.02), (x, y, FL + 0.34), METAL_INCHIS))
		for sx in (-1, 1):
			for sy in (-1, 1):
				piese.append(cilindru("Bara carucior", 0.012, 0.012, 0.6, (x + sx * 0.33, y + sy * 0.23, FL + 0.3), CROM, laturi=4))
				piese.append(sfera("Roata", 0.04, (x + sx * 0.33, y + sy * 0.23, FL + 0.04), NEGRU, segmente=6, inele=4))
			piese.append(cilindru("Stalp umerase", 0.012, 0.012, 1.0, (x + sx * 0.33, y, FL + 1.1), CROM, laturi=4))
		piese.append(cilindru("Bara umerase", 0.012, 0.012, 0.66, (x, y, FL + 1.6), CROM, laturi=4, rot=(0, 1.5708, 0)))
		for k in range(3):
			piese.append(cub("Umeras", (0.02, 0.36, 0.2), (x - 0.2 + k * 0.2, y, FL + 1.48), METAL_INCHIS, rot=(0, 0, 0.0)))
			piese.append(cub("Camasa agatata", (0.04, 0.42, 0.6), (x - 0.2 + k * 0.2, y, FL + 1.15), r.choice((ALB, FAIANTA, ROSU))))
		_cutie_coliziune(col, (0.72, 0.52, 1.6), (x, y, FL + 0.8))

	# scaunele de lângă vitrine (cu fața spre stradă) și un ghiveci
	for x in (-5.4, -4.8, -4.2, 4.2, 4.8, 5.4):
		_scaun_plastic(piese, x, 0.85, math.pi, FAIANTA if x < 0 else ROSU)
	_cutie_coliziune(col, (1.8, 0.5, 0.9), (-4.8, 0.85, FL + 0.45))
	_cutie_coliziune(col, (1.8, 0.5, 0.9), (4.8, 0.85, FL + 0.45))
	piese.append(cilindru("Ghiveci", 0.2, 0.16, 0.35, (-6.5, 0.7, FL + 0.175), p("904a40"), laturi=8))
	for k in range(7):
		u = k * math.tau / 7
		piese.append(os_intre("Frunza", (-6.5, 0.7, FL + 0.35), (-6.5 + math.cos(u) * 0.35, 0.7 + math.sin(u) * 0.35, FL + 0.9 + 0.2 * (k % 2)),
			0.035, p("5b6d4e"), laturi=4))
	_cutie_coliziune(col, (0.4, 0.4, 1.0), (-6.5, 0.7, FL + 0.5))

	# prețurile pe peretele din dreapta, sus; „NO DYEING”, „DO NOT LEAVE LAUNDRY UNATTENDED” pe cel din stânga
	piese.append(cub("Panou preturi", (0.02, 1.6, 0.6), (W - 0.012, 6.0, 2.6), ALB))
	piese.append(cub("Rama preturi", (0.025, 1.64, 0.04), (W - 0.014, 6.0, 2.9), ROSU))
	piese.append(_text("Preturi", "WASH ...... $2.50\nEXTRA ..... $0.75\nDRY ....... $1.00", (W - 0.026, 6.0, 2.55), 0.1, NEGRU,
		rot=(1.5708, 0, -1.5708)))
	piese.append(cub("Panou", (0.02, 1.4, 0.4), (-W + 0.012, 6.0, 2.65), ROSU))
	piese.append(_text("Avertisment", "NO DYEING\nNO PETS", (-W + 0.026, 6.0, 2.65), 0.1, ALB, rot=(1.5708, 0, 1.5708)))
	piese.append(cub("Panou", (0.02, 1.8, 0.3), (-W + 0.012, 9.6, 2.65), ALB))
	piese.append(_text("Avertisment", "DO NOT LEAVE LAUNDRY\nUNATTENDED", (-W + 0.026, 9.6, 2.65), 0.07, NEGRU, rot=(1.5708, 0, 1.5708)))

	# televizorul vechi din colțul din față-dreapta, pe un suport
	tx, ty, tz = 6.55, 0.7, 2.75
	piese.append(cub("Suport tv", (0.4, 0.4, 0.04), (tx, ty, tz - 0.27), METAL))
	piese.append(cub("Bara suport", (0.04, 0.04, 0.6), (tx + 0.25, ty, tz), METAL))
	piese.append(cub("Televizor", (0.55, 0.5, 0.45), (tx, ty, tz), METAL_INCHIS, rot=(0, 0, -0.5)))
	lumini.append(cub("Ecran tv", (0.4, 0.012, 0.32), (tx - 0.13, ty - 0.22, tz), p("61a19f"), rot=(0, 0, -0.5)))

	# coșul de gunoi, găleata cu mopul și semnul galben
	piese.append(cilindru("Cos gunoi", 0.22, 0.2, 0.7, (-0.6, Y1 - 0.35, FL + 0.35), METAL_INCHIS, laturi=10))
	piese.append(cilindru("Capac cos", 0.23, 0.23, 0.05, (-0.6, Y1 - 0.35, FL + 0.72), METAL, laturi=10))
	piese.append(cub("Galeata", (0.4, 0.3, 0.32), (2.4, Y1 - 0.4, FL + 0.16), p("a18463")))
	piese.append(os_intre("Mop", (2.4, Y1 - 0.4, FL + 0.2), (2.45, Y1 - 0.15, FL + 1.4), 0.015, LEMN, laturi=4))
	piese.append(prisma("Semn ud", [(-0.15, 0.0), (0.15, 0.0), (0.0, 0.6)], "xz", -0.2, 0.2, p("a18463")))
	semn = piese[-1]
	semn.location = (6.2, 9.0, FL)
	semn.rotation_euler = (0, 0, 0.4)
	bpy.context.view_layer.objects.active = semn
	semn.select_set(True)
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	piese.append(_text("Scris semn", "WET\nFLOOR", (6.12, 8.81, FL + 0.25), 0.05, NEGRU, rot=(1.5708 - 0.24, 0, 0.4)))

	uneste(piese, "Decor")
	uneste(lumini, "Lumini")
	uneste(geamuri, "Geamuri")
	uneste(col, "Coliziune")
	exporta(os.path.join(cale, "decor_spalatorie.glb"))


def decor_casino(cale):
	"""Camera de joc: covorul de sub masă, tejgheaua bătrânei (cu gratii, tava de jetoane, soneria, scrumiera, rafturile din
	spate cu cutii de jetoane, seiful, televizorul mic), barul de pe peretele din spate (dulap, rafturi cu sticle, oglinda,
	portretul „Don”-ului), canapeaua chesterfield cu măsuța, cuierul cu pălăria, palmierul, lampa mare de deasupra mesei
	(cu `Lumini`). Piese: `Decor`, `Lumini`, `Geamuri`, `Coliziune`."""
	curata()
	r = random.Random(23)
	piese, lumini, geamuri, col = [], [], [], []
	ym = 17.6  # mijlocul mesei de poker

	# covorul persan: bordură aurie, câmp roșu, medalion
	piese.append(cub("Covor", (5.6, 4.2, 0.012), (0, ym, FL + 0.006), ROSU))
	piese.append(cub("Bordura covor", (5.2, 0.12, 0.012), (0, ym - 1.85, FL + 0.016), AUR))
	piese.append(cub("Bordura covor", (5.2, 0.12, 0.012), (0, ym + 1.85, FL + 0.016), AUR))
	piese.append(cub("Bordura covor", (0.12, 3.58, 0.012), (-2.54, ym, FL + 0.016), AUR))
	piese.append(cub("Bordura covor", (0.12, 3.58, 0.012), (2.54, ym, FL + 0.016), AUR))
	for k in range(16):
		u = k * math.tau / 16
		piese.append(cub("Model covor", (0.16, 0.16, 0.012), (math.cos(u) * 2.2, ym + math.sin(u) * 1.5, FL + 0.016), p("5e363e"), rot=(0, 0, u + 0.785)))

	# --- tejgheaua casei (colțul din dreapta, imediat după ușă): bătrâna stă în spatele ei, cu fața spre -X
	tx0, tx1 = 4.35, W          # cabina pe X
	ty0, ty1 = Y1 + G, 15.05    # pe Y
	tz = 1.06                   # blatul
	piese.append(cub("Tejghea", (0.45, ty1 - ty0 - 0.1, tz - FL - 0.05), (tx0 + 0.225, (ty0 + ty1) / 2, (FL + tz - 0.05) / 2), LEMN_INCHIS))
	for k in range(4):  # panourile de lemn ale tejghelei
		piese.append(cub("Panou tejghea", (0.012, 0.55, 0.6), (tx0 - 0.006, ty0 + 0.4 + k * 0.62, FL + 0.45), LEMN))
	piese.append(cub("Blat tejghea", (0.6, ty1 - ty0, 0.05), (tx0 + 0.23, (ty0 + ty1) / 2, tz - 0.025), LEMN))
	piese.append(cub("Cant tejghea", (0.04, ty1 - ty0, 0.07), (tx0 - 0.08, (ty0 + ty1) / 2, tz - 0.03), AUR))
	_cutie_coliziune(col, (0.62, ty1 - ty0, tz), (tx0 + 0.23, (ty0 + ty1) / 2, tz / 2))
	# peretele lateral al cabinei (pe Y), gratiile de deasupra tejghelei, cu ghișeul liber în mijloc
	piese.append(cub("Perete cabina", (tx1 - tx0, 0.1, HC - FL), ((tx0 + tx1) / 2, ty1 + 0.05, (FL + HC) / 2), LEMN_INCHIS))
	_cutie_coliziune(col, (tx1 - tx0, 0.1, HC), ((tx0 + tx1) / 2, ty1 + 0.05, HC / 2))
	piese.append(cub("Grinda gratii", (0.1, ty1 - ty0, 0.12), (tx0 + 0.1, (ty0 + ty1) / 2, 2.3), LEMN_INCHIS))
	ghiseu = (13.35, 14.0)  # ghișeul (gol în gratii, în dreptul ei)
	yg = ty0 + 0.08
	while yg < ty1 - 0.04:
		if not (ghiseu[0] < yg < ghiseu[1]):
			piese.append(cilindru("Gratie", 0.012, 0.012, 2.3 - tz, (tx0 + 0.1, yg, (tz + 2.3) / 2), AUR, laturi=6))
		yg += 0.11
	for z in (1.6, 2.0):
		for a, b in ((ty0, ghiseu[0]), (ghiseu[1], ty1)):
			piese.append(cilindru("Bara gratii", 0.01, 0.01, b - a, (tx0 + 0.1, (a + b) / 2, z), AUR, laturi=6, rot=(1.5708, 0, 0)))
	piese.append(cub("Arc ghiseu", (0.06, ghiseu[1] - ghiseu[0] + 0.1, 0.06), (tx0 + 0.1, sum(ghiseu) / 2, 1.5), AUR))
	piese.append(cub("Placuta casa", (0.02, 0.7, 0.16), (tx0 + 0.04, sum(ghiseu) / 2, 2.15), NEGRU))
	piese.append(_text("Scris casa", "CASHIER", (tx0 + 0.028, sum(ghiseu) / 2, 2.15), 0.09, AUR, rot=(1.5708, 0, -1.5708)))
	# pe blat: soneria, tava cu jetoane, scrumiera cu o țigară, cutia de bani
	piese.append(cilindru("Sonerie", 0.04, 0.045, 0.03, (tx0 + 0.15, ghiseu[0] - 0.25, tz + 0.015), AUR, laturi=8))
	piese.append(sfera("Sonerie", 0.035, (tx0 + 0.15, ghiseu[0] - 0.25, tz + 0.035), AUR, scara=(1, 1, 0.6), segmente=8, inele=4))
	piese.append(cub("Tava jetoane", (0.24, 0.42, 0.05), (tx0 + 0.42, ghiseu[1] + 0.35, tz + 0.025), LEMN_INCHIS))
	for k in range(6):
		cul = (ROSU, p("2a3c3d"), p("5b6d4e"), ALB, ROSU, p("2a3c3d"))[k]
		piese.append(cilindru("Fisic jetoane", 0.019, 0.019, 0.18, (tx0 + 0.35 + (k % 2) * 0.07, ghiseu[1] + 0.2 + (k // 2) * 0.13,
			tz + 0.06), cul, laturi=8, rot=(1.5708, 0, 0)))
	piese.append(cilindru("Scrumiera casa", 0.07, 0.06, 0.03, (tx0 + 0.25, ty0 + 0.25, tz + 0.015), GEAM, laturi=10))
	piese.append(os_intre("Muc", (tx0 + 0.24, ty0 + 0.25, tz + 0.032), (tx0 + 0.31, ty0 + 0.27, tz + 0.04), 0.005, ALB, laturi=4))
	piese.append(cub("Cutie bani", (0.3, 0.25, 0.12), (tx0 + 0.48, ty0 + 0.3, tz + 0.06), p("445d46")))
	# în spatele ei: rafturi cu cutii de jetoane, seiful, televizorul mic, calendarul, lampa de birou
	for z in (1.3, 1.75, 2.2):
		piese.append(cub("Raft casa", (0.35, 2.3, 0.03), (W - 0.18, (ty0 + ty1) / 2, z), LEMN))
		for k in range(5):
			piese.append(cub("Cutie jetoane", (0.25, 0.3, 0.14), (W - 0.18, ty0 + 0.35 + k * 0.45, z + 0.085),
				r.choice((ROSU, LEMN_INCHIS, p("2a3c3d")))))
	piese.append(cub("Seif", (0.6, 0.6, 0.8), (W - 0.35, ty1 - 0.4, FL + 0.4), METAL_INCHIS))
	piese.append(cilindru("Roata seif", 0.08, 0.08, 0.03, (W - 0.66, ty1 - 0.4, FL + 0.48), AUR, laturi=8, rot=(0, 1.5708, 0)))
	piese.append(cub("Maner seif", (0.03, 0.04, 0.16), (W - 0.67, ty1 - 0.25, FL + 0.4), AUR))
	_cutie_coliziune(col, (0.6, 0.6, 0.8), (W - 0.35, ty1 - 0.4, FL + 0.4))
	piese.append(cub("Televizor mic", (0.32, 0.3, 0.26), (W - 0.2, ty0 + 0.6, tz + 0.5), METAL_INCHIS))
	lumini.append(cub("Ecran tv mic", (0.012, 0.22, 0.17), (W - 0.366, ty0 + 0.6, tz + 0.5), p("61a19f")))
	piese.append(cub("Raft tv", (0.36, 0.4, 0.03), (W - 0.2, ty0 + 0.6, tz + 0.355), LEMN))
	piese.append(cub("Calendar", (0.012, 0.3, 0.42), (W - 0.012, ty0 + 1.4, 2.65), ALB))
	piese.append(cub("Poza calendar", (0.012, 0.24, 0.2), (W - 0.02, ty0 + 1.4, 2.73), p("a56850")))

	# --- barul de pe peretele din spate: dulap jos, oglindă, rafturi cu sticle, portretul
	bx0, bx1 = -2.6, 2.6
	piese.append(cub("Dulap bar", (bx1 - bx0, 0.5, 1.0), (0, Y2 - 0.25, FL + 0.5), LEMN_INCHIS))
	for k in range(5):
		piese.append(cub("Usa dulap", (0.95, 0.012, 0.75), (bx0 + 0.55 + k * 1.03, Y2 - 0.506, FL + 0.48), LEMN))
		piese.append(sfera("Buton dulap", 0.018, (bx0 + 0.95 + k * 1.03, Y2 - 0.52, FL + 0.7), AUR, segmente=6, inele=4))
	piese.append(cub("Blat bar", (bx1 - bx0 + 0.1, 0.56, 0.05), (0, Y2 - 0.27, FL + 1.025), p("2a3c3d")))
	_cutie_coliziune(col, (bx1 - bx0, 0.56, 1.05), (0, Y2 - 0.27, FL + 0.525))
	for z in (1.55, 1.95):
		for sx in (-1, 1):
			piese.append(cub("Raft bar", (1.4, 0.22, 0.03), (sx * 1.75, Y2 - 0.12, z), LEMN_INCHIS))
			for k in range(7):
				_sticla_bar(piese, sx * 1.75 - 0.6 + k * 0.2, Y2 - 0.12, z + 0.015,
					r.choice((p("5b6d4e"), p("904a40"), p("a18463"), GEAM, p("7b383a"))), inalta=k % 3 != 1)
	# pe blat: pahare de whisky, o sticlă, frapiera
	for k in range(4):
		piese.append(cilindru("Pahar", 0.035, 0.035, 0.08, (-1.6 + k * 0.12, Y2 - 0.3, FL + 1.09), p("61a19f"), laturi=8))
	_sticla_bar(piese, -0.9, Y2 - 0.28, FL + 1.05, p("a18463"))
	piese.append(cilindru("Frapiera", 0.1, 0.09, 0.2, (1.4, Y2 - 0.3, FL + 1.15), CROM, laturi=10))
	# portretul în ramă aurie, în stânga neonului
	px = -4.3
	piese.append(cub("Rama portret", (0.9, 0.05, 1.1), (px, Y2 - 0.03, 2.2), AUR))
	piese.append(cub("Portret", (0.76, 0.012, 0.96), (px, Y2 - 0.06, 2.2), p("2a3c3d")))
	piese.append(sfera("Portret cap", 0.14, (px, Y2 - 0.08, 2.35), p("a56850"), scara=(1, 0.2, 1.2), segmente=8, inele=5))
	piese.append(cub("Portret palarie", (0.36, 0.012, 0.08), (px, Y2 - 0.08, 2.52), NEGRU))
	piese.append(cub("Portret palarie", (0.22, 0.012, 0.12), (px, Y2 - 0.08, 2.6), NEGRU))
	piese.append(cub("Portret umeri", (0.6, 0.012, 0.3), (px, Y2 - 0.08, 1.88), NEGRU))
	piese.append(cub("Portret cravata", (0.05, 0.012, 0.2), (px, Y2 - 0.09, 1.95), ROSU))
	piese.append(cub("Lampa portret", (0.4, 0.08, 0.04), (px, Y2 - 0.1, 2.82), AUR))

	# --- canapeaua chesterfield pe peretele din dreapta, cu măsuța, și un fotoliu
	sx_ = W - 0.45
	sy0, sy1 = 17.6, 20.6
	piese.append(cub("Canapea", (0.8, sy1 - sy0, 0.42), (sx_, (sy0 + sy1) / 2, FL + 0.21), LEMN))
	piese.append(cub("Spatar canapea", (0.2, sy1 - sy0, 0.45), (W - 0.1, (sy0 + sy1) / 2, FL + 0.62), LEMN))
	for s in (sy0, sy1):
		piese.append(cub("Brat canapea", (0.8, 0.2, 0.62), (sx_, s, FL + 0.31), LEMN))
	for k in range(3):
		piese.append(cub("Perna", (0.62, 0.96, 0.12), (sx_ - 0.04, sy0 + 0.5 + k * 1.0, FL + 0.48), LEMN_INCHIS))
	for k in range(10):  # capitonajul: nasturi pe spătar
		piese.append(sfera("Capitonaj", 0.014, (W - 0.205, sy0 + 0.2 + k * 0.29, FL + 0.7 + (k % 2) * 0.12), NEGRU, segmente=4, inele=3))
	_cutie_coliziune(col, (0.9, sy1 - sy0 + 0.2, 0.9), (W - 0.45, (sy0 + sy1) / 2, FL + 0.45))
	piese.append(cub("Masuta", (0.6, 1.2, 0.05), (W - 1.4, 19.1, FL + 0.45), LEMN_INCHIS))
	for dx in (-0.25, 0.25):
		for dy in (-0.55, 0.55):
			piese.append(cub("Picior masuta", (0.05, 0.05, 0.43), (W - 1.4 + dx, 19.1 + dy, FL + 0.215), LEMN_INCHIS))
	_cutie_coliziune(col, (0.6, 1.2, 0.5), (W - 1.4, 19.1, FL + 0.25))
	piese.append(cilindru("Scrumiera masuta", 0.08, 0.07, 0.03, (W - 1.4, 18.8, FL + 0.49), GEAM, laturi=10))
	for k in range(3):
		piese.append(os_intre("Muc", (W - 1.42 + k * 0.02, 18.8, FL + 0.505), (W - 1.36 + k * 0.03, 18.84 - k * 0.03, FL + 0.51), 0.005, ALB, laturi=4))
	piese.append(cub("Ziar", (0.3, 0.4, 0.01), (W - 1.45, 19.4, FL + 0.48), ALB, rot=(0, 0, 0.3)))
	piese.append(cilindru("Pahar masuta", 0.035, 0.035, 0.08, (W - 1.3, 19.6, FL + 0.515), p("61a19f"), laturi=8))
	# palmierul din colț și cuierul cu pălărie și palton (lângă ușă)
	piese.append(cilindru("Ghiveci palmier", 0.25, 0.2, 0.45, (W - 0.45, Y2 - 0.45, FL + 0.225), LEMN_INCHIS, laturi=8))
	piese.append(os_intre("Trunchi palmier", (W - 0.45, Y2 - 0.45, FL + 0.4), (W - 0.5, Y2 - 0.5, FL + 1.5), 0.05, LEMN, laturi=6))
	for k in range(8):
		u = k * math.tau / 8
		a = (W - 0.5, Y2 - 0.5, FL + 1.5)
		b = (a[0] + math.cos(u) * 0.6, a[1] + math.sin(u) * 0.6, a[2] + 0.1 - 0.3 * (k % 2))
		piese.append(trunchi("Frunza palmier", [(a, 0.02, 0.06), (_lerp(a, b, 0.5), 0.015, 0.1), (b, 0.0, 0.0)], p("5b6d4e"), laturi=4,
			ref=(0, 0, 1)))
	_cutie_coliziune(col, (0.5, 0.5, 1.2), (W - 0.45, Y2 - 0.45, FL + 0.6))
	cx, cy = 2.3, Y1 + G + 0.35
	piese.append(cilindru("Cuier", 0.025, 0.025, 1.8, (cx, cy, FL + 0.9), LEMN_INCHIS, laturi=6))
	piese.append(cilindru("Baza cuier", 0.22, 0.22, 0.04, (cx, cy, FL + 0.02), LEMN_INCHIS, laturi=8))
	piese.append(trunchi("Palton", [((cx, cy - 0.06, FL + 1.75), 0.06, 0.05), ((cx, cy - 0.08, FL + 1.4), 0.2, 0.12),
		((cx, cy - 0.08, FL + 0.6), 0.22, 0.13)], p("6f6d7f"), laturi=8))
	piese.append(cilindru("Bor palarie", 0.15, 0.15, 0.012, (cx, cy, FL + 1.82), NEGRU, laturi=12))
	piese.append(trunchi("Calota palarie", [((cx, cy, FL + 1.82), 0.09, 0.1), ((cx, cy, FL + 1.93), 0.08, 0.09), ((cx, cy, FL + 1.94), 0.0, 0.0)],
		NEGRU, laturi=10))
	_cutie_coliziune(col, (0.4, 0.4, 1.9), (cx, cy, FL + 0.95))

	# --- lampa mare de deasupra mesei: abajur verde, lung, pe lanțuri; becurile dedesubt strălucesc
	lz = 2.05
	piese.append(prisma("Abajur", [(-0.95, 0.0), (0.95, 0.0), (0.75, 0.22), (-0.75, 0.22)], "xz", ym - 0.28, ym + 0.28, POSTAV))
	piese[-1].location = (0, 0, lz)
	bpy.context.view_layer.objects.active = piese[-1]
	piese[-1].select_set(True)
	bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
	piese.append(cub("Capac abajur", (1.5, 0.5, 0.03), (0, ym, lz + 0.235), AUR))
	for x in (-0.55, 0.0, 0.55):
		lumini.append(sfera("Bec lampa", 0.06, (x, ym, lz + 0.04), AUR, scara=(1, 1, 0.6), segmente=8, inele=4))
	for x in (-0.6, 0.6):
		piese.append(os_intre("Lant lampa", (x, ym, lz + 0.24), (x * 0.5, ym, HC), 0.008, AUR, laturi=4))
	# ventilatorul din tavan e model separat (se învârte), ca și ușile

	uneste(piese, "Decor")
	uneste(lumini, "Lumini")
	if geamuri:
		uneste(geamuri, "Geamuri")
	uneste(col, "Coliziune")
	exporta(os.path.join(cale, "decor_casino.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Obiectele puse de mai multe ori
# ---------------------------------------------------------------------------------------------------------------

def masina_spalat(cale):
	"""Mașina de spălat profesională (cu fise), încărcare frontală. Originea = podeaua de sub mijlocul ei, fața spre -Y.
	Piese: `Masina` (carcasa din panouri, cu gaura hubloului; înăuntru se vede tamburul), `Tambur` (originea în centrul lui,
	axa pe Y: se învârte, cu rufele înăuntru), `Usa` (originea în balamaua din stânga; `GeamUsa` copil al ei), `Afisaj`
	(strălucește când merge)."""
	curata()
	r = random.Random(3)
	piese = []
	w, d, h = 0.7, 0.72, 1.0
	zh = 0.55  # centrul hubloului
	gaura = 0.175
	# soclul, panourile (fără fața din față întreagă: are o gaură pătrată în dreptul hubloului)
	piese.append(cub("Soclu", (w, d - 0.04, 0.1), (0, 0.02, 0.05), METAL_INCHIS))
	piese.append(cub("Lateral", (0.02, d, h - 0.1), (-w / 2 + 0.01, 0, 0.1 + (h - 0.1) / 2), ALB))
	piese.append(cub("Lateral", (0.02, d, h - 0.1), (w / 2 - 0.01, 0, 0.1 + (h - 0.1) / 2), ALB))
	piese.append(cub("Spate", (w - 0.04, 0.02, h - 0.1), (0, d / 2 - 0.01, 0.1 + (h - 0.1) / 2), ALB))
	piese.append(cub("Capac", (w, d, 0.02), (0, 0, h - 0.01), ALB))
	piese.append(cub("Fund", (w - 0.04, d - 0.04, 0.02), (0, 0, 0.11), METAL))
	perete(piese, "Fata", "x", -w / 2 + 0.02, w / 2 - 0.02, -d / 2, -d / 2 + 0.02, 0.1, h - 0.02, ALB,
		[(-gaura, gaura, zh - gaura, zh + gaura)])
	# garnitura hubloului (acoperă colțurile găurii pătrate) și interiorul închis la culoare
	piese.append(_tor("Garnitura", 0.215, 0.04, (0, -d / 2 - 0.01, zh), METAL, rot=(1.5708, 0, 0), segmente=16))
	# panoul de comandă de sus (înclinat), fanta de fise, butoanele, sertarul de detergent
	piese.append(prisma("Panou", [(-d / 2, h), (-d / 2 + 0.02, h + 0.16), (-d / 2 + 0.2, h + 0.16), (-d / 2 + 0.2, h)], "yz",
		-w / 2, w / 2, METAL))
	piese.append(cub("Fanta fise", (0.12, 0.02, 0.06), (0.2, -d / 2 + 0.01, h + 0.08), AUR, rot=(-0.12, 0, 0)))
	piese.append(cub("Gura fise", (0.05, 0.022, 0.012), (0.2, -d / 2 + 0.005, h + 0.095), NEGRU, rot=(-0.12, 0, 0)))
	for k in range(3):
		piese.append(cilindru("Buton", 0.018, 0.018, 0.02, (-0.22 + k * 0.07, -d / 2 + 0.01, h + 0.06), (ROSU, p("5b6d4e"), ALB)[k],
			laturi=8, rot=(1.45, 0, 0)))
	piese.append(cub("Sertar", (0.2, 0.02, 0.07), (-0.2, -d / 2 - 0.006, h - 0.07), METAL))
	piese.append(cub("Eticheta", (0.18, 0.012, 0.05), (0.15, -d / 2 - 0.006, 0.2), METAL_INCHIS))
	piese.append(cub("Numar", (0.06, 0.012, 0.06), (0.24, -d / 2 - 0.006, h - 0.07), FAIANTA))
	uneste(piese, "Masina")
	afisaj = uneste([cub("Afisaj", (0.11, 0.012, 0.04), (-0.02, -d / 2 + 0.0, h + 0.08), FAIANTA, rot=(-0.12, 0, 0))], "Afisaj")
	# tamburul: cilindru deschis în față (inox, cu găuri și palete), rufele colorate înăuntru
	tc = (0, -d / 2 + 0.23, zh)
	tambur = [cilindru("Fund tambur", 0.19, 0.19, 0.02, (0, -d / 2 + 0.45, zh), CROM, laturi=14, rot=(1.5708, 0, 0))]
	for k in range(14):
		u = k * math.tau / 14
		tambur.append(cub("Perete tambur", (0.088, 0.42, 0.01), (math.cos(u) * 0.186, -d / 2 + 0.24, zh + math.sin(u) * 0.186), CROM,
			rot=(0, -u + 1.5708, 0)))
	for k in range(3):
		u = k * math.tau / 3
		tambur.append(cub("Paleta", (0.05, 0.38, 0.04), (math.cos(u) * 0.16, -d / 2 + 0.24, zh + math.sin(u) * 0.16), METAL,
			rot=(0, -u + 1.5708, 0)))
	for k in range(6):
		u = r.uniform(0, math.tau)
		rr = r.uniform(0.04, 0.12)
		tambur.append(sfera("Rufe", r.uniform(0.06, 0.09), (math.cos(u) * rr, -d / 2 + 0.22 + r.uniform(-0.08, 0.1), zh + math.sin(u) * rr),
			r.choice((ROSU, FAIANTA, ALB, p("a18463"), p("5b6d4e"), p("2a3c3d"))), scara=(1.2, 1.0, 0.8), segmente=6, inele=4))
	uneste(tambur, "Tambur", tc)
	# ușa: inel cromat cu geamul (copil), mânerul în dreapta; balamaua în stânga
	ux = -0.24
	usa = [
		_tor("Rama usa", 0.2, 0.035, (0, -d / 2 - 0.05, zh), CROM, rot=(1.5708, 0, 0), segmente=16),
		cub("Maner usa", (0.05, 0.04, 0.12), (0.2, -d / 2 - 0.06, zh), METAL_INCHIS),
		cub("Balama", (0.06, 0.03, 0.08), (ux + 0.02, -d / 2 - 0.035, zh), METAL_INCHIS),
	]
	ob_usa = uneste(usa, "Usa", (ux, -d / 2 - 0.035, zh))
	geam = uneste([cilindru("GeamUsa", 0.175, 0.175, 0.012, (0, -d / 2 - 0.05, zh), GEAM, laturi=16, rot=(1.5708, 0, 0))], "GeamUsa")
	_parinte(geam, ob_usa)
	exporta(os.path.join(cale, "masina_spalat.glb"))


def pacanea(cale):
	"""Păcănea în stil EGT: soclu, dulapul cu ecranul mare înclinat (`Ecran` = punct gol în centrul lui; ecranul îl pune
	jocul: 0,5 × 0,38 m, privește spre -Y înclinat cu 0,15 rad), ecranul de sus cu jackpot-urile (`EcranSus`, 0,5 × 0,22 m),
	pupitrul cu butoane, tava de monede, maneta (`Maner`, originea în pivot), luminile de pe margini (`Lumini`).
	Originea = podeaua, fața spre -Y."""
	curata()
	piese, lumini = [], []
	w, d = 0.64, 0.6
	piese.append(cub("Soclu", (w, d, 0.72), (0, 0, 0.36), NEGRU))
	piese.append(cub("Banda soclu", (w + 0.03, d + 0.03, 0.05), (0, 0, 0.7), AUR))
	for k in range(3):
		piese.append(cub("Grila soclu", (0.4, 0.012, 0.02), (0, -d / 2 - 0.006, 0.25 + k * 0.08), METAL_INCHIS))
	# pupitrul (înclinat spre jucător), cu butoane mari colorate
	piese.append(prisma("Pupitru", [(-d / 2 - 0.12, 0.72), (-d / 2 - 0.12, 0.84), (-d / 2 + 0.08, 0.92), (-d / 2 + 0.08, 0.72)], "yz",
		-w / 2, w / 2, NEGRU))
	for k, cul in enumerate((ROSU, AUR, p("5b6d4e"), FAIANTA, ALB)):
		lumini.append(cub("Buton pacanea", (0.075, 0.06, 0.02), (-0.24 + k * 0.12, -d / 2 - 0.05, 0.88), cul, rot=(0.38, 0, 0)))
	lumini.append(cub("Buton start", (0.12, 0.07, 0.025), (0.0, -d / 2 + 0.03, 0.93), p("5b6d4e"), rot=(0.38, 0, 0)))
	# dulapul ecranului, ecranul mare (gol: îl pune jocul), rama luminoasă
	piese.append(cub("Dulap", (w, d - 0.08, 0.98), (0, 0.04, 0.92 + 0.49), METAL_INCHIS))
	piese.append(cub("Rama ecran", (w - 0.04, 0.03, 0.46), (0, -d / 2 + 0.07, 1.25), NEGRU, rot=(-0.15, 0, 0)))
	for x in (-w / 2 + 0.015, w / 2 - 0.015):
		lumini.append(cub("Dunga luminoasa", (0.02, 0.02, 0.96), (x, -d / 2 + 0.065, 1.41), AUR))
	# ecranul de sus și coronamentul rotunjit cu numele jocului
	piese.append(cub("Rama sus", (w - 0.04, 0.03, 0.26), (0, -d / 2 + 0.08, 1.67), NEGRU))
	piese.append(cilindru("Coronament", w / 2, w / 2, d - 0.1, (0, 0.05, 1.9), ROSU, laturi=16, rot=(1.5708, 0, 0), scara=(1, 1, 0.38)))
	lumini.append(_text("Nume joc", "40 BURNING 7s", (0, -d / 2 + 0.135, 1.93), 0.075, AUR))
	lumini.append(cub("Bec varf", (0.08, 0.08, 0.06), (0, 0.0, 2.03), ROSU))
	# tava de monede, fanta de bancnote, maneta
	piese.append(cub("Tava monede", (0.4, 0.14, 0.08), (0, -d / 2 - 0.05, 0.6), CROM))
	piese.append(cub("Interior tava", (0.36, 0.1, 0.02), (0, -d / 2 - 0.05, 0.63), METAL_INCHIS))
	piese.append(cub("Fanta bancnote", (0.012, 0.16, 0.04), (w / 2 + 0.006, -0.1, 1.05), NEGRU))
	lumini.append(cub("Bec fanta", (0.014, 0.18, 0.01), (w / 2 + 0.007, -0.1, 1.08), p("5b6d4e")))
	piese.append(cilindru("Pivot maneta", 0.04, 0.04, 0.05, (w / 2 + 0.025, 0.0, 1.25), CROM, laturi=8, rot=(0, 1.5708, 0)))
	uneste(piese, "Pacanea")
	uneste(lumini, "Lumini")
	maner = [
		os_intre("Maneta", (w / 2 + 0.06, 0.0, 1.25), (w / 2 + 0.06, -0.02, 1.6), 0.014, CROM, laturi=6),
		sfera("Bila maneta", 0.04, (w / 2 + 0.06, -0.02, 1.62), ROSU, segmente=8, inele=5),
	]
	uneste(maner, "Maner", (w / 2 + 0.06, 0.0, 1.25))
	# punctele goale unde pune jocul cele două ecrane
	for nume, loc in (("Ecran", (0, -d / 2 + 0.05, 1.25)), ("EcranSus", (0, -d / 2 + 0.06, 1.67))):
		ob = bpy.data.objects.new(nume, None)
		bpy.context.scene.collection.objects.link(ob)
		ob.location = loc
	exporta(os.path.join(cale, "pacanea.glb"))


def scaun_bar(cale):
	"""Scaunul înalt de la păcănele: picior cromat, șezut rotund de piele roșie. Originea = podeaua."""
	curata()
	piese = [
		cilindru("Baza", 0.22, 0.24, 0.04, (0, 0, 0.02), CROM, laturi=10),
		cilindru("Picior", 0.035, 0.035, 0.66, (0, 0, 0.35), CROM, laturi=8),
		_tor("Inel picioare", 0.18, 0.015, (0, 0, 0.3), CROM, segmente=10),
		cilindru("Sezut", 0.2, 0.19, 0.08, (0, 0, 0.72), ROSU, laturi=12),
		_tor("Margine sezut", 0.19, 0.02, (0, 0, 0.7), LEMN_INCHIS, segmente=12),
	]
	uneste(piese, "Scaun")
	exporta(os.path.join(cale, "scaun_bar.glb"))


def masa_poker(cale):
	"""Masa de poker ovală (2,9 × 1,7 m): postav verde cu linia de pariuri, marginea capitonată de piele, suporturi de
	pahare, cantul de lemn, două picioare masive. Originea = podeaua sub mijlocul mesei; postavul e la 0,77 m."""
	curata()
	piese = []
	a, b = 1.45, 0.85
	zp = 0.77
	piese.append(cilindru("Postav", 1.0, 1.0, 0.04, (0, 0, zp - 0.02), POSTAV, laturi=28, scara=(a - 0.1, b - 0.1, 1)))
	piese.append(_tor("Linie pariuri", 1.0, 0.006, (0, 0, zp + 0.002), AUR, scara=(a - 0.42, b - 0.38, 1), segmente=28))
	piese.append(_tor("Bordura", 1.0, 0.075, (0, 0, zp + 0.025), LEMN_INCHIS, scara=(a - 0.06, b - 0.06, 1.0), segmente=28))
	piese.append(cilindru("Cant", 1.0, 1.0, 0.08, (0, 0, zp - 0.07), LEMN, laturi=28, scara=(a, b, 1)))
	piese.append(cilindru("Sub masa", 1.0, 1.0, 0.04, (0, 0, zp - 0.13), LEMN_INCHIS, laturi=28, scara=(a - 0.1, b - 0.1, 1)))
	for k in range(8):  # suporturile de pahare din margine
		u = k * math.tau / 8 + 0.2
		piese.append(cilindru("Suport pahar", 0.045, 0.045, 0.012, (math.cos(u) * (a - 0.06), math.sin(u) * (b - 0.06), zp + 0.098),
			METAL_INCHIS, laturi=8))
	for x in (-0.75, 0.75):
		piese.append(cilindru("Picior masa", 0.12, 0.16, zp - 0.15, (x, 0, (zp - 0.15) / 2), LEMN_INCHIS, laturi=8))
		piese.append(cub("Talpa masa", (0.25, 0.9, 0.06), (x, 0, 0.03), LEMN_INCHIS))
	uneste(piese, "Masa")
	exporta(os.path.join(cale, "masa_poker.glb"))


def scaun_poker(cale):
	"""Scaunul de la masa de poker: ramă de lemn, șezut și spătar de piele roșie capitonată, brațe. Originea = podeaua
	sub mijlocul șezutului (0,48 m), fața spre -Y (spre masă)."""
	curata()
	piese = [
		cub("Sezut", (0.5, 0.48, 0.1), (0, 0.02, 0.44), ROSU),
		cub("Rama sezut", (0.54, 0.52, 0.05), (0, 0.02, 0.365), LEMN_INCHIS),
		cub("Spatar", (0.5, 0.08, 0.5), (0, 0.27, 0.78), ROSU, rot=(-0.12, 0, 0)),
		cub("Rama spatar", (0.54, 0.06, 0.06), (0, 0.31, 1.04), LEMN_INCHIS, rot=(-0.12, 0, 0)),
	]
	for s in (-1, 1):
		piese.append(cub("Brat scaun", (0.06, 0.46, 0.05), (s * 0.27, 0.04, 0.66), LEMN_INCHIS))
		piese.append(cub("Suport brat", (0.05, 0.05, 0.22), (s * 0.27, -0.16, 0.53), LEMN_INCHIS))
		for dy in (-0.2, 0.24):
			piese.append(cub("Picior scaun", (0.05, 0.05, 0.36), (s * 0.23, dy, 0.18), LEMN_INCHIS))
	for k in range(4):
		piese.append(sfera("Capitonaj", 0.012, (-0.15 + k * 0.1, 0.225, 0.8), NEGRU, segmente=4, inele=3))
	uneste(piese, "Scaun")
	exporta(os.path.join(cale, "scaun_poker.glb"))


def usi(cale):
	"""Ușa de sticlă a spălătoriei (`usa_spalatorie`, 1,1 × 2,3 m, ramă de aluminiu, bara de împins, plăcuța „OPEN” pe
	sfoară, clopoțelul de deasupra) și ușa de lemn dintre spălătorie și camera de joc (`usa_casino`, 1,05 × 2,15 m,
	„EMPLOYEES ONLY” pe fața dinspre spălătorie). Originea = balamaua (jos); ușa se întinde spre +X; fața „de afară” e -Y."""
	curata()
	lw, lh = 1.1, 2.3
	piese = [
		cub("Rama", (0.06, 0.05, lh), (0.03, 0, lh / 2), CROM),
		cub("Rama", (0.06, 0.05, lh), (lw - 0.03, 0, lh / 2), CROM),
		cub("Rama", (lw, 0.05, 0.12), (lw / 2, 0, lh - 0.06), CROM),
		cub("Rama", (lw, 0.05, 0.2), (lw / 2, 0, 0.1), CROM),
		cilindru("Bara", 0.018, 0.018, lw - 0.2, (lw / 2, -0.07, 1.05), METAL, laturi=6, rot=(0, 1.5708, 0)),
		cilindru("Bara", 0.018, 0.018, lw - 0.2, (lw / 2, 0.07, 1.05), METAL, laturi=6, rot=(0, 1.5708, 0)),
	]
	for s in (-1, 1):
		for x in (0.15, lw - 0.15):
			piese.append(cub("Suport bara", (0.03, 0.06, 0.03), (x, s * 0.045, 1.05), METAL))
	# plăcuța „OPEN” atârnată pe sfoară, în față
	piese.append(cub("Placuta open", (0.34, 0.012, 0.14), (lw / 2, -0.04, 1.65), ROSU))
	piese.append(_text("Scris open", "OPEN", (lw / 2, -0.048, 1.65), 0.085, ALB))
	piese.append(os_intre("Sfoara", (lw / 2 - 0.15, -0.035, 1.72), (lw / 2, -0.032, 1.85), 0.003, NEGRU, laturi=4))
	piese.append(os_intre("Sfoara", (lw / 2 + 0.15, -0.035, 1.72), (lw / 2, -0.032, 1.85), 0.003, NEGRU, laturi=4))
	piese.append(cub("Program", (0.2, 0.006, 0.12), (lw - 0.2, -0.028, 1.35), ALB))
	ob = uneste(piese, "Usa")
	g = uneste([cub("Geam", (lw - 0.12, 0.012, lh - 0.32), (lw / 2, 0, 0.2 + (lh - 0.32) / 2), GEAM)], "GeamUsa")
	_parinte(g, ob)
	exporta(os.path.join(cale, "usa_spalatorie.glb"))

	curata()
	lw, lh = 1.05, 2.15
	piese = [cub("Usa", (lw, 0.05, lh), (lw / 2, 0, lh / 2), LEMN_INCHIS)]
	for z0, z1 in ((0.15, 0.95), (1.1, 2.0)):  # panourile ușii, pe ambele fețe
		for s in (-1, 1):
			piese.append(cub("Panou usa", (lw - 0.3, 0.012, z1 - z0), (lw / 2, s * 0.031, (z0 + z1) / 2), LEMN))
	for s in (-1, 1):
		piese.append(sfera("Clanta", 0.035, (lw - 0.1, s * 0.07, 1.0), AUR, segmente=8, inele=5))
		piese.append(cub("Rozeta", (0.06, 0.02, 0.12), (lw - 0.1, s * 0.035, 1.0), AUR))
	piese.append(cub("Placuta usa", (0.4, 0.012, 0.1), (lw / 2, -0.04, 1.55), AUR))
	piese.append(_text("Scris usa", "PRIVATE", (lw / 2, -0.048, 1.55), 0.06, NEGRU))
	piese.append(cilindru("Vizor", 0.015, 0.015, 0.07, (lw / 2, 0, 1.6), AUR, laturi=6, rot=(1.5708, 0, 0)))
	uneste(piese, "Usa")
	exporta(os.path.join(cale, "usa_casino.glb"))


def ventilator(cale):
	"""Ventilatorul din tavanul camerei de joc: tija, motorul de alamă, 5 pale de lemn (`Pale`, se învârt, originea în ax),
	globul de sticlă cu becul (`Lumini`). Originea = prinderea din tavan; atârnă în jos 0,6 m."""
	curata()
	piese = [
		cilindru("Prindere", 0.08, 0.08, 0.04, (0, 0, -0.02), AUR, laturi=10),
		cilindru("Tija", 0.015, 0.015, 0.4, (0, 0, -0.22), AUR, laturi=6),
		cilindru("Motor", 0.12, 0.12, 0.14, (0, 0, -0.48), AUR, laturi=12),
	]
	uneste(piese, "Ventilator")
	pale = []
	for k in range(5):
		u = k * math.tau / 5
		pale.append(cub("Pala", (0.55, 0.13, 0.012), (math.cos(u) * 0.38, math.sin(u) * 0.38, -0.5), LEMN, rot=(0.12, 0, u)))
		pale.append(cub("Brat pala", (0.16, 0.04, 0.012), (math.cos(u) * 0.14, math.sin(u) * 0.14, -0.49), AUR, rot=(0, 0, u)))
	uneste(pale, "Pale", (0, 0, -0.5))
	uneste([sfera("Glob", 0.09, (0, 0, -0.6), AUR, scara=(1, 1, 0.8), segmente=8, inele=5)], "Lumini")
	exporta(os.path.join(cale, "ventilator.glb"))


def oameni(cale):
	casino_oameni.toate(cale)


def toate(cale):
	cladire(cale)
	strada(cale)
	decor_spalatorie(cale)
	decor_casino(cale)
	masina_spalat(cale)
	pacanea(cale)
	scaun_bar(cale)
	masa_poker(cale)
	scaun_poker(cale)
	usi(cale)
	ventilator(cale)
	oameni(cale)


if __name__ == "__main__":
	cale_modele = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")
	if "--" in sys.argv:
		for nume in sys.argv[sys.argv.index("--") + 1:]:
			globals()[nume](cale_modele)
	else:
		toate(cale_modele)
