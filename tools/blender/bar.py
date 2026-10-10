# Barul „URBAN” (Găvana): un bar american mic, puțin întunecat — fațada de cărămidă închisă cu firma de neon, ferestrele
# cu reclame luminoase, înăuntru tejgheaua lungă de lemn cu scaune înalte, raftul cu sticle și oglinda, luminițele
# agățate pe sub tavan, masa de biliard cu lampa ei, colțul de darts, boxele (separeurile), tonomatul.
# Plus recuzita jocurilor (ținta de darts, săgețile, tacul, bilele, paharele, sticlele) și oamenii (barmanul,
# jucătorul de darts, cel de la biliard).
#   blender --background --factory-startup --python tools/blender/bar.py                (toate)
#   blender --background --factory-startup --python tools/blender/bar.py -- decor bile  (doar unele)
# Axe Blender: Z în sus, fața clădirii spre -Y (în Godot devine +Z, spre stradă); înăuntru e spre +Y (Godot -Z).
# Godot = (x, z, -y) din Blender.
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, uneste, exporta, trunchi, _coloreaza, desparte_fete  # noqa: E402
from lexy import perete  # noqa: E402
from casino import _text, _text_o_fata, _tor, _cutie_coliziune  # noqa: E402
import casino_oameni  # noqa: E402
import motel  # noqa: E402

NEGRU = p("262d2f")
ALB = p("83b3b0")
AUR = p("a18463")
CROM = p("7e8d87")
METAL = p("6f6d7f")
METAL_INCHIS = p("5e5356")
GEAM = p("2a3c3d")
LEMN = p("5e363e")
LEMN_INCHIS = p("48313b")
LEMN_DESCHIS = p("904a40")
ROSU = p("7b383a")
CARAMIDA = p("5e363e")
MORTAR = p("48313b")
BETON = p("70706e")
TENCUIALA = p("7e8d87")
BRONZ = p("a56850")
VERDE = p("5b6d4e")
POSTAV = p("445d46")
VERDE_NEGRU = p("32453b")
TEAL = p("438b88")
TEAL_DESCHIS = p("61a19f")
PETROL = p("295555")
PETROL_DESCHIS = p("30716f")
MOV = p("655269")
MOV_INCHIS = p("553e4d")
MASLINIU = p("7a7b59")
GRI_ALBASTRU = p("778c96")

# --- clădirea
W = 7.0       # jumătate din lățimea dinăuntru
G = 0.25      # grosimea pereților
FL = 0.15     # podeaua (= trotuarul)
HC = 3.4      # tavanul
TOP = 3.75    # acoperișul
D = 13.0      # fața dinăuntru a peretelui din spate
USA = (3.5, 4.6, FL, FL + 2.3)
FERESTRE = [(-6.3, -4.0), (-2.9, -0.6), (0.6, 2.5), (5.4, 6.5)]
FZ = (FL + 0.95, FL + 2.3)
# tejgheaua: fața spre sală la x BX1, spatele la BX0, de la y BY0 la BY1, blatul la BZ
BX0, BX1, BY0, BY1, BZ = -4.45, -3.9, 2.6, 10.6, FL + 1.1
# scaunele de la bar (x, y-uri); cel din fața barmanului (Y_BARMAN) e separat (scaun_bar_urban.glb, cu E în joc)
X_SCAUNE = -3.42
Y_SCAUNE = [3.4, 4.4, 5.4, 7.4, 8.4, 9.4]
Y_BARMAN = 6.4
X_BARMAN = -4.75
# masa de biliard: centrul, suprafața de joc (pe Y lungimea, pe X lățimea), înălțimea postavului
PCX, PCY = 2.2, 7.0
PL, PW = 2.24, 1.12
PZ = FL + 0.8
RAZA_BILA = 0.0286
# darts: ținta pe peretele din dreapta (fața spre -X), linia de aruncare la 2,37 m
DY, DZ = 10.9, FL + 1.73
DX = W - 0.045           # fața țintei
LINIE_DARTS = DX - 2.37


def _strange(piese, nume):
	if len(piese) > 1:
		piese[:] = [uneste(piese, nume)]


def _fata(nume, puncte, culoare, normala):
	"""Un poligon plat (puncte în ordine) cu fața spre `normala` (shader-ul are cull_back: doar fața asta se vede)."""
	bm = bmesh.new()
	vs = [bm.verts.new(v) for v in puncte]
	a, b, c = (Vector(puncte[0]), Vector(puncte[1]), Vector(puncte[2]))
	if (b - a).cross(c - a).dot(Vector(normala)) < 0:
		vs.reverse()
	bm.faces.new(vs)
	me = bpy.data.meshes.new(nume)
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new(nume, me)
	bpy.context.scene.collection.objects.link(ob)
	_coloreaza(ob, culoare)
	return ob


def _roteste_muta(obiecte, rot, loc):
	from mathutils import Matrix
	m = Matrix.Translation(Vector((loc[0], loc[1], loc[2] if len(loc) > 2 else 0))) @ Matrix.Rotation(rot, 4, 'Z')
	for ob in obiecte:
		ob.data.transform(m)
		ob.data.update()
	return obiecte


def _caramizi(piese, axa, a0, a1, fata, spre, z0, z1, goluri=(), pas_z=0.075, lung=0.25):
	"""Rosturile cărămizilor pe un perete: linii orizontale la `pas_z` și verticale decalate, cu golurile ocolite.
	axa "x": peretele merge pe X, fața la y = `fata`, ieșind spre `spre` (±1); axa "y": invers."""
	def bucati(z):
		taieturi = sorted((a, b) for a, b, za, zb in goluri if za - 0.03 < z < zb + 0.03)
		rez, u = [], a0
		for a, b in taieturi:
			if a - 0.04 > u:
				rez.append((u, a - 0.04))
			u = max(u, b + 0.04)
		if u < a1:
			rez.append((u, a1))
		return rez
	z, rand = z0 + pas_z, 0
	while z < z1 - 0.03:
		for a, b in bucati(z):
			if axa == "x":
				piese.append(cub("Rost", (b - a, 0.012, 0.012), ((a + b) / 2, fata + spre * 0.006, z), MORTAR))
			else:
				piese.append(cub("Rost", (0.012, b - a, 0.012), (fata + spre * 0.006, (a + b) / 2, z), MORTAR))
		u = a0 + (lung / 2 if rand % 2 else lung)
		for a, b in bucati(z + pas_z / 2):
			while u < b - 0.03:
				if u > a + 0.03:
					if axa == "x":
						piese.append(cub("Rost", (0.012, 0.012, pas_z - 0.012), (u, fata + spre * 0.006, z + pas_z / 2), MORTAR))
					else:
						piese.append(cub("Rost", (0.012, 0.012, pas_z - 0.012), (fata + spre * 0.006, u, z + pas_z / 2), MORTAR))
				u += lung
		z += pas_z
		rand += 1


# ---------------------------------------------------------------------------------------------------------------
# Clădirea
# ---------------------------------------------------------------------------------------------------------------

def cladire(cale):
	"""Barul: fațada de cărămidă închisă cu ferestrele (reclamele de neon din spatele lor: „BEER”, „OPEN”, „COCKTAILS”,
	„POOL & DARTS”), ușa de lemn cu copertina, firma mare „URBAN” cu becuri pe margine; înăuntru podeaua de scânduri
	închise, lambriul, cărămida aparentă deasupra, tavanul negru cu grinzi și tubulatură. Piese: `Cladire`, `Lumini`,
	`Geamuri`, `Coliziune`."""
	curata()
	piese, lumini, geamuri, col = [], [], [], []

	def strange():
		_strange(piese, "Cladire")

	# --- podeaua: scânduri pe Y, trei nuanțe închise, peste o șapă
	# șapa și acoperișul stau cu 2 cm înăuntrul pereților: cu fețele laterale în planul pereților de afară se băteau cu ei
	# pe ecran (marginea de sus a pereților laterali și a spatelui, din parcare)
	piese.append(cub("Sapa", (2 * W + 2 * G - 0.04, D + G - 0.04, 0.2), (0, (D + G) / 2, FL - 0.12), METAL_INCHIS))
	_cutie_coliziune(col, (2 * W + 2 * G, D + G, 0.3), (0, (D + G) / 2, FL - 0.15))
	x, k = -W, 0
	r = random.Random(5)
	while x < W - 0.001:
		lat = min(0.18, W - x)
		y = G
		while y < D - 0.01:  # scândurile au lungimi diferite (îmbinări decalate)
			lung = min(r.uniform(1.6, 3.2), D - y)
			piese.append(cub("Scandura", (lat - 0.006, lung - 0.006, 0.02), (x + lat / 2, y + lung / 2, FL - 0.01),
				(LEMN_INCHIS, LEMN, MOV_INCHIS)[(k + int(y)) % 3]))
			y += lung
		x += lat
		k += 1
	piese.append(cub("Prag", (USA[1] - USA[0], G, 0.02), ((USA[0] + USA[1]) / 2, G / 2, FL - 0.01), METAL))
	strange()

	# --- pereții: fațada (cărămidă afară, lambriu + cărămidă înăuntru), lateralele, spatele
	g2 = G / 2
	goluri = [(USA[0], USA[1], USA[2] - 0.2, USA[3])] + [(a, b, FZ[0], FZ[1]) for a, b in FERESTRE]
	perete(piese, "Fatada", "x", -W - G, W + G, 0.0, g2, 0.0, TOP, CARAMIDA, goluri)
	perete(piese, "Fatada int", "x", -W, W, g2, G, FL, HC, CARAMIDA, goluri)
	for a, b in [(-W - G, USA[0]), (USA[1], W + G)]:
		_cutie_coliziune(col, (b - a, G, TOP), ((a + b) / 2, G / 2, TOP / 2))
	_cutie_coliziune(col, (USA[1] - USA[0], G, TOP - USA[3]), ((USA[0] + USA[1]) / 2, G / 2, (TOP + USA[3]) / 2))
	_caramizi(piese, "x", -W - G, W + G, 0.0, -1, 0.55, TOP - 0.1, goluri)
	strange()
	for s in (-1, 1):
		piese.append(cub("Perete lateral", (g2, D + G - g2, TOP), (s * (W + G - g2 / 2), (D + G + g2) / 2, TOP / 2), BETON))
		piese.append(cub("Perete lateral int", (g2, D - G, HC - FL), (s * (W + g2 / 2), (G + D) / 2, (FL + HC) / 2), CARAMIDA))
		_cutie_coliziune(col, (G, D + G, TOP), (s * (W + G / 2), (D + G) / 2, TOP / 2))
	piese.append(cub("Spate", (2 * W + 2 * G, g2, TOP), (0, D + G - g2 / 2, TOP / 2), BETON))
	piese.append(cub("Spate int", (2 * W, g2, HC - FL), (0, D + g2 / 2, (FL + HC) / 2), CARAMIDA))
	_cutie_coliziune(col, (2 * W + 2 * G, G, TOP), (0, D + G / 2, TOP / 2))
	# cărămida aparentă dinăuntru (deasupra lambriului), pe dreapta, pe spate și pe fațadă
	ZL = FL + 1.15  # până unde urcă lambriul
	_caramizi(piese, "y", G, D, W, -1, ZL, HC - 0.05)
	strange()
	_caramizi(piese, "x", -W, W, D, -1, ZL, HC - 0.05)
	strange()
	_caramizi(piese, "x", -W, W, G, 1, ZL, HC - 0.05, goluri)
	strange()

	# lambriul: panouri de lemn închis cu șipci, brâul de sus, plinta (pe dreapta, pe spate și pe fațadă; în stânga e
	# barul, cu peretele lui)
	def lambriu(axa, a0, a1, fata, spre, sari=()):
		lung = a1 - a0
		mij = (a0 + a1) / 2
		zm = (FL + ZL) / 2
		if axa == "x":
			piese.append(cub("Lambriu", (lung, 0.02, ZL - FL), (mij, fata + spre * 0.01, zm), LEMN))
			piese.append(cub("Brau", (lung, 0.05, 0.06), (mij, fata + spre * 0.025, ZL + 0.01), LEMN_INCHIS))
			piese.append(cub("Plinta", (lung, 0.035, 0.12), (mij, fata + spre * 0.0175, FL + 0.06), LEMN_INCHIS))
		else:
			piese.append(cub("Lambriu", (0.02, lung, ZL - FL), (fata + spre * 0.01, mij, zm), LEMN))
			piese.append(cub("Brau", (0.05, lung, 0.06), (fata + spre * 0.025, mij, ZL + 0.01), LEMN_INCHIS))
			piese.append(cub("Plinta", (0.035, lung, 0.12), (fata + spre * 0.0175, mij, FL + 0.06), LEMN_INCHIS))
		u = a0 + 0.35
		while u < a1 - 0.1:
			if not any(a - 0.05 < u < b + 0.05 for a, b in sari):
				if axa == "x":
					piese.append(cub("Sipca", (0.03, 0.012, ZL - FL - 0.2), (u, fata + spre * 0.026, zm), LEMN_INCHIS))
				else:
					piese.append(cub("Sipca", (0.012, 0.03, ZL - FL - 0.2), (fata + spre * 0.026, u, zm), LEMN_INCHIS))
			u += 0.45
	lambriu("y", G, D, W, -1)
	lambriu("x", -W, W, D, -1)
	for a, b in ((-W, USA[0]), (USA[1], W)):
		lambriu("x", a, b, G, 1)
	strange()

	# --- tavanul: negru, cu grinzi de lemn pe X și o tubulatură de tablă pe lungime
	piese.append(cub("Tavan", (2 * W, D - G, 0.1), (0, (G + D) / 2, HC + 0.05), NEGRU))
	for y in [G + 1.6 * j for j in range(1, 8)]:
		piese.append(cub("Grinda", (2 * W, 0.16, 0.2), (0, y, HC - 0.1), LEMN_INCHIS))
	for x in (0.8, 5.0):
		piese.append(cilindru("Tubulatura", 0.17, 0.17, D - G - 0.2, (x, (G + D) / 2, HC - 0.42), METAL, laturi=10, rot=(1.5708, 0, 0)))
		for y in [1.0 + 1.9 * j for j in range(7)]:
			piese.append(cilindru("Colier", 0.18, 0.18, 0.03, (x, y, HC - 0.42), METAL_INCHIS, laturi=10, rot=(1.5708, 0, 0)))
			piese.append(cub("Tija", (0.02, 0.02, 0.24), (x, y, HC - 0.13), METAL_INCHIS))
		piese.append(cub("Gura aer", (0.3, 0.012, 0.18), (x, D - 0.11, HC - 0.42), NEGRU))
	strange()

	# --- tocul ușii, ferestrele (geam, ramă, pervaz) și reclamele de neon din spatele lor
	a, b, za, zb = USA
	for xx in (a + 0.03, b - 0.03):
		piese.append(cub("Toc", (0.06, G + 0.02, zb - za), (xx, g2, (za + zb) / 2), LEMN_INCHIS))
	piese.append(cub("Toc", (b - a, G + 0.02, 0.06), ((a + b) / 2, g2, zb - 0.03), LEMN_INCHIS))
	for (fa, fb), (scris, cul, marime) in zip(FERESTRE, (("COCKTAILS", TEAL_DESCHIS, 0.2), ("BEER", AUR, 0.36),
			("POOL & DARTS", TEAL_DESCHIS, 0.15), ("OPEN", ROSU, 0.24))):
		z0, z1 = FZ
		geamuri.append(cub("Geam", (fb - fa, 0.012, z1 - z0), ((fa + fb) / 2, g2, (z0 + z1) / 2), GEAM))
		for xx in (fa, fb):
			piese.append(cub("Rama fereastra", (0.06, G + 0.04, z1 - z0 + 0.06), (xx, g2, (z0 + z1) / 2), NEGRU))
		for zz in (z0, z1):
			piese.append(cub("Rama fereastra", (fb - fa, G + 0.04, 0.06), ((fa + fb) / 2, g2, zz), NEGRU))
		piese.append(cub("Pervaz", (fb - fa + 0.1, 0.12, 0.04), ((fa + fb) / 2, -0.06, z0 - 0.04), BETON))
		piese.append(cub("Pervaz int", (fb - fa, 0.22, 0.03), ((fa + fb) / 2, G + 0.11, z0 - 0.015), LEMN_INCHIS))
		# reclama de neon atârnată în spatele geamului, cu fața spre stradă: literele strălucesc, conturul tot
		xm, zm = (fa + fb) / 2, (z0 + z1) / 2 + 0.08
		lumini.append(_text_o_fata("Neon " + scris, scris, (xm, G + 0.06, zm), marime, cul, rot=(1.5708, 0, 0)))
		lat = min(fb - fa - 0.25, len(scris) * marime * 0.62 + 0.12)
		for zz in (zm - marime * 0.75, zm + marime * 0.75):
			lumini.append(cub("Neon contur", (lat, 0.012, 0.012), (xm, G + 0.07, zz), cul))
		for xx in (xm - lat / 2, xm + lat / 2):
			lumini.append(cub("Neon contur", (0.012, 0.012, marime * 1.5), (xx, G + 0.07, zm), cul))
		piese.append(cub("Placa neon", (lat + 0.1, 0.012, marime * 1.7), (xm, G + 0.085, zm), NEGRU))
		for xx in (xm - lat / 2 + 0.05, xm + lat / 2 - 0.05):  # lănțișoarele de care atârnă
			piese.append(cub("Lantisor", (0.006, 0.006, z1 - zm - marime * 0.85), (xx, G + 0.08, (z1 + zm + marime * 0.85) / 2), CROM))
	# soclul de beton de jos (nu și prin dreptul ușii), aplica de deasupra ușii
	for sa, sb in ((-W - G, USA[0]), (USA[1], W + G)):
		piese.append(cub("Soclu", (sb - sa, 0.03, 0.5), ((sa + sb) / 2, -0.015, 0.25), BETON))
	strange()

	# --- copertina de pânză neagră peste ușă (pe un cadru de țevi), cu „URBAN” mic pe volan
	cx0, cx1 = a - 0.35, b + 0.35
	cz, cadanc = zb + 0.42, 1.0
	piese.append(_fata("Copertina", [(cx0, 0.02, cz), (cx1, 0.02, cz), (cx1, -cadanc, cz - 0.4), (cx0, -cadanc, cz - 0.4)], NEGRU, (0, -0.4, 1)))
	piese.append(_fata("Copertina dedesubt", [(cx0, 0.02, cz - 0.01), (cx1, 0.02, cz - 0.01), (cx1, -cadanc, cz - 0.41), (cx0, -cadanc, cz - 0.41)],
		LEMN_INCHIS, (0, 0.4, -1)))
	piese.append(cub("Volan copertina", (cx1 - cx0, 0.012, 0.22), ((cx0 + cx1) / 2, -cadanc - 0.006, cz - 0.51), NEGRU))
	piese.append(_text_o_fata("Scris copertina", "URBAN", ((cx0 + cx1) / 2, -cadanc - 0.014, cz - 0.51), 0.12, AUR))
	for xx in (cx0, cx1):
		piese.append(_fata("Lateral copertina", [(xx, 0.02, cz), (xx, -cadanc, cz - 0.4), (xx, -cadanc, cz - 0.62), (xx, 0.02, cz - 0.3)],
			NEGRU, (1 if xx > a else -1, 0, 0)))
	lumini.append(cub("Bec usa", (0.25, 0.08, 0.02), ((a + b) / 2, -0.3, cz - 0.17), AUR))
	strange()

	# --- parapetul și firma mare „URBAN”: placa neagră, literele de neon, sublinierea, becurile de pe margine
	PZ0, PZ1 = TOP, TOP + 1.1
	piese.append(cub("Parapet", (2 * W + 2 * G, G, PZ1 - PZ0), (0, G / 2, (PZ0 + PZ1) / 2), CARAMIDA))
	piese.append(cub("Copertina parapet", (2 * W + 2 * G + 0.1, G + 0.1, 0.06), (0, G / 2, PZ1 + 0.03), METAL_INCHIS))
	piese.append(cub("Acoperis", (2 * W + 2 * G - 0.04, D + G - 0.04, 0.25), (0, (D + G) / 2, TOP - 0.135), METAL_INCHIS))
	_cutie_coliziune(col, (2 * W + 2 * G, D + G, 0.3), (0, (D + G) / 2, TOP - 0.15))
	fx0, fx1, fz0, fz1 = -3.6, 3.6, TOP - 0.45, TOP + 0.95
	piese.append(cub("Firma", (fx1 - fx0, 0.12, fz1 - fz0), (0, -0.06, (fz0 + fz1) / 2), NEGRU))
	for zz in (fz0 + 0.03, fz1 - 0.03):
		piese.append(cub("Tiv firma", (fx1 - fx0 + 0.04, 0.14, 0.06), (0, -0.07, zz), METAL_INCHIS))
	for xx in (fx0 + 0.03, fx1 - 0.03):
		piese.append(cub("Tiv firma", (0.06, 0.14, fz1 - fz0), (xx, -0.07, (fz0 + fz1) / 2), METAL_INCHIS))
	zm = (fz0 + fz1) / 2 + 0.08
	piese.append(_text("Umbra urban", "URBAN", (0.04, -0.125, zm - 0.04), 0.86, ROSU))
	lumini.append(_text("Litere urban", "URBAN", (0, -0.14, zm), 0.86, AUR))
	lumini.append(cub("Subliniere", (4.4, 0.012, 0.035), (0, -0.13, fz0 + 0.24), ROSU))
	piese.append(_text("Scris firma", "BAR  *  GRILL  *  POOL", (0, -0.125, fz0 + 0.13), 0.1, ALB))
	xx = fx0 + 0.12
	while xx < fx1 - 0.08:
		for zz in (fz0 + 0.09, fz1 - 0.09):
			lumini.append(sfera("Bec firma", 0.025, (xx, -0.135, zz), AUR, segmente=6, inele=4))
		xx += 0.24
	zz = fz0 + 0.33
	while zz < fz1 - 0.2:
		for xx in (fx0 + 0.09, fx1 - 0.09):
			lumini.append(sfera("Bec firma", 0.025, (xx, -0.135, zz), AUR, segmente=6, inele=4))
		zz += 0.24
	# suporturile firmei, prinse în parapet
	for xx in (fx0 + 0.6, fx1 - 0.6):
		piese.append(cub("Suport firma", (0.05, 0.06, 0.3), (xx, -0.03, fz1 + 0.1), METAL_INCHIS))
	strange()

	desparte_fete(fixe=("Fatada", "Fatada int", "Perete lateral", "Perete lateral int", "Spate", "Spate int", "Sapa",
		"Tavan", "Parapet", "Acoperis", "Firma", "Lambriu", "Scandura"))
	uneste(piese, "Cladire")
	uneste(lumini, "Lumini")
	uneste(geamuri, "Geamuri")
	uneste(col, "Coliziune")
	exporta(os.path.join(cale, "bar_cladire.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Strada
# ---------------------------------------------------------------------------------------------------------------

def strada(cale):
	"""Strada din fața barului: trotuarul, bordura, asfaltul cu marcaje, trotuarul și blocurile de vizavi, terenul (iarbă)
	de sub tot. În stânga un salon de tatuaje („TATTOO”, neon roșu), în dreapta o parcare mică cu un pickup și un
	tomberon, apoi un „CHECK CASHING” închis. Piese: `Strada`, `Lumini`, `Coliziune`."""
	from amanet import _obiect
	curata()
	r = random.Random(29)
	piese, lumini, col = [], [], []

	def strange():
		_strange(piese, "Strada")

	L = 140.0
	piese.append(cub("Teren", (L, 120.0, 0.1), (0, -10.0, -0.11), VERDE))
	piese.append(cub("Trotuar", (L, 3.4, FL), (0, -1.7, FL / 2), BETON))
	for xx in range(-70, 71, 1):
		piese.append(cub("Rost", (0.012, 3.4, 0.02), (xx * 1.0, -1.7, FL), METAL_INCHIS))
	piese.append(cub("Bordura", (L, 0.2, FL + 0.02), (0, -3.5, (FL + 0.02) / 2), TENCUIALA))
	piese.append(cub("Asfalt", (L, 7.4, 0.05), (0, -7.3, -0.025), NEGRU))
	for xx in range(-68, 70, 4):
		piese.append(cub("Marcaj", (2.0, 0.12, 0.02), (xx, -7.3, 0.0), AUR))
	piese.append(cub("Bordura", (L, 0.2, FL + 0.02), (0, -11.1, (FL + 0.02) / 2), TENCUIALA))
	piese.append(cub("Trotuar", (L, 3.0, FL), (0, -12.7, FL / 2), BETON))
	_cutie_coliziune(col, (L, 3.4, FL), (0, -1.7, FL / 2))
	_cutie_coliziune(col, (L, 0.2, FL + 0.02), (0, -3.5, (FL + 0.02) / 2))
	_cutie_coliziune(col, (L, 7.4, 0.05), (0, -7.3, -0.025))
	_cutie_coliziune(col, (L, 3.2, FL), (0, -12.6, FL / 2))
	# pete de ulei și petice pe asfalt (pe un singur strat, la 15 mm), un capac de canal
	for k in range(14):
		x = -40 + k * 6 + r.uniform(-1.5, 1.5)
		piese.append(cub("Pata asfalt", (r.uniform(0.4, 1.2), r.uniform(0.3, 0.8), 0.01), (x, r.uniform(-9.5, -5.0), 0.005 + 0.015),
			METAL_INCHIS, rot=(0, 0, r.uniform(0, 3))))
	piese.append(cilindru("Canal", 0.35, 0.35, 0.02, (2.0, -5.2, 0.01 + 0.015), METAL, laturi=12))
	# hidrantul, stâlpul de iluminat, un coș de gunoi, un automat de ziare lângă ușă
	piese += [
		cilindru("Hidrant", 0.11, 0.11, 0.55, (-2.0, -2.9, FL + 0.275), AUR, laturi=8),
		sfera("Hidrant cap", 0.11, (-2.0, -2.9, FL + 0.55), AUR, scara=(1, 1, 0.7), segmente=8, inele=4),
		cilindru("Stalp", 0.07, 0.09, 6.5, (-7.5, -3.1, FL + 3.25), METAL, laturi=8),
		os_intre("Brat stalp", (-7.5, -3.1, FL + 6.3), (-7.5, -4.6, FL + 6.5), 0.04, METAL, laturi=6),
		cub("Lampa stalp", (0.25, 0.5, 0.1), (-7.5, -4.7, FL + 6.45), METAL_INCHIS),
		cilindru("Cos gunoi", 0.22, 0.24, 0.8, (2.9, -2.8, FL + 0.4), VERDE_NEGRU, laturi=10),
		cilindru("Buza cos", 0.25, 0.25, 0.05, (2.9, -2.8, FL + 0.82), METAL_INCHIS, laturi=10),
		cub("Automat ziare", (0.45, 0.4, 0.9), (5.4, -0.8, FL + 0.45), PETROL),
		cub("Geam automat", (0.35, 0.012, 0.3), (5.4, -1.006, FL + 0.7), GEAM),
	]
	_cutie_coliziune(col, (0.2, 0.2, 6.5), (-7.5, -3.1, FL + 3.25))
	_cutie_coliziune(col, (0.45, 0.45, 0.85), (2.9, -2.8, FL + 0.42))
	_cutie_coliziune(col, (0.45, 0.4, 0.9), (5.4, -0.8, FL + 0.45))
	strange()

	# --- stânga: salonul de tatuaje (cărămidă roșie, vitrina cu desene, neonul „TATTOO”), apoi un bloc vechi
	vx0, vx1 = -19.0, -W - G - 0.01
	piese.append(cub("Vecin stanga", (vx1 - vx0, 12.0, 4.4), ((vx0 + vx1) / 2, 6.0, 2.2), ROSU))
	_cutie_coliziune(col, (vx1 - vx0, 12.0, 4.4), ((vx0 + vx1) / 2, 6.0, 2.2))
	piese.append(cub("Soclu vecin", (vx1 - vx0, 0.03, 0.5), ((vx0 + vx1) / 2, -0.015, 0.25), BETON))
	piese.append(cub("Vitrina tattoo", (4.0, 0.02, 1.7), (-12.6, -0.012, 1.55), GEAM))
	for k in range(5):  # desenele lipite pe geam: o inimă, un craniu, un trandafir, o ancoră, un șarpe (pete simple)
		cul = (ROSU, ALB, ROSU, PETROL, VERDE)[k]
		piese.append(cub("Desen", (0.42, 0.012, 0.55), (-14.2 + k * 0.8, -0.03, 1.5 + 0.2 * (k % 2)), cul))
	piese.append(cub("Usa tattoo", (1.0, 0.04, 2.2), (-9.4, -0.02, 1.1), NEGRU))
	piese.append(cub("Firma tattoo", (4.2, 0.14, 0.7), (-12.6, -0.07, 3.5), NEGRU))
	lumini.append(_text("Litere tattoo", "TATTOO", (-12.6, -0.15, 3.5), 0.5, ROSU))
	lumini.append(_text("Scris tattoo", "WALK-INS WELCOME", (-12.6, -0.03, 2.62), 0.12, TEAL_DESCHIS))
	piese.append(cub("Bloc vechi", (14.0, 12.0, 11.0), (-26.0, 6.0, 5.5), TENCUIALA))
	for fx in range(4):
		for fz in range(3):
			aprins = r.random() < 0.2
			(lumini if aprins else piese).append(cub("Geam bloc", (1.2, 0.02, 1.3), (-31.0 + fx * 3.2, -0.01, 4.5 + fz * 2.8),
				AUR if aprins else GEAM))
	_cutie_coliziune(col, (14.0, 12.0, 11.0), (-26.0, 6.0, 5.5))
	strange()

	# --- dreapta: parcarea (asfalt crăpat, liniile, opritoarele), pickup-ul, tomberonul, gardul din spate
	mx0, mx1 = W + G + 0.01, 17.0
	piese.append(cub("Parcare", (mx1 - mx0, 12.0, 0.04), ((mx0 + mx1) / 2, 6.0, FL - 0.02), METAL_INCHIS))
	_cutie_coliziune(col, (mx1 - mx0, 12.0, 0.2), ((mx0 + mx1) / 2, 6.0, FL - 0.1))
	for xx in (9.6, 12.4, 15.2):
		piese.append(cub("Linie parcare", (0.1, 4.6, 0.01), (xx, 4.2, FL + 0.005 + 0.01), ALB))
	for xx in (11.0, 13.8):
		piese.append(cub("Opritor", (1.6, 0.2, 0.12), (xx, 6.3, FL + 0.06), BETON))
	s, c = motel._masina("pickup", TEAL, r)
	piese.append(_obiect(s, (11.0, 3.6, FL - 0.02), (0, 0, math.pi + 0.06)))
	for (dx, dy, dz, ox, oy, oz) in c:
		col.append(_obiect([cub("Coliziune", (dx, dy, dz), (ox, oy, oz), NEGRU)], (11.0, 3.6, FL - 0.02), (0, 0, math.pi + 0.06),
			nume="Coliziune"))
	piese.append(cub("Tomberon", (1.8, 1.1, 1.2), (15.6, 9.6, FL + 0.6), VERDE_NEGRU))
	piese.append(cub("Capac tomberon", (1.85, 1.15, 0.06), (15.6, 9.6, FL + 1.23), NEGRU, rot=(0.12, 0, 0)))
	_cutie_coliziune(col, (1.8, 1.1, 1.2), (15.6, 9.6, FL + 0.6))
	piese.append(cub("Zid parcare", (mx1 - mx0, 0.3, 2.2), ((mx0 + mx1) / 2, 12.0, FL + 1.1), BETON))
	_cutie_coliziune(col, (mx1 - mx0, 0.3, 2.2), ((mx0 + mx1) / 2, 12.0, FL + 1.1))
	piese.append(cub("Indicator parcare", (0.6, 0.03, 0.6), (8.3, 0.8, FL + 2.0), PETROL))
	piese.append(_text_o_fata("Scris parcare", "P\nCUSTOMERS\nONLY", (8.3, 0.78, FL + 2.0), 0.08, ALB))
	piese.append(cilindru("Stalp indicator", 0.03, 0.03, 1.7, (8.3, 0.83, FL + 0.85), METAL, laturi=6))
	_cutie_coliziune(col, (0.1, 0.1, 1.7), (8.3, 0.83, FL + 0.85))
	# „CHECK CASHING”, închis cu oblon
	piese.append(cub("Vecin dreapta", (12.0, 12.0, 4.0), (mx1 + 6.0, 6.0, 2.0), METAL))
	_cutie_coliziune(col, (12.0, 12.0, 4.0), (mx1 + 6.0, 6.0, 2.0))
	piese.append(cub("Oblon", (6.0, 0.04, 2.4), (mx1 + 4.0, -0.02, 1.3), METAL_INCHIS))
	for k in range(12):
		piese.append(cub("Dunga oblon", (6.0, 0.012, 0.012), (mx1 + 4.0, -0.046, 0.3 + k * 0.2), METAL))
	piese.append(cub("Firma check", (5.0, 0.12, 0.7), (mx1 + 4.0, -0.06, 3.2), AUR))
	piese.append(_text("Scris check", "CHECK CASHING", (mx1 + 4.0, -0.13, 3.2), 0.36, NEGRU))
	strange()

	# --- vizavi: blocuri în ceață, cu alei; între ele parcări
	for k in range(6):
		bx = -50 + k * 20 + r.uniform(-2, 2)
		h = r.choice((9.0, 12.0, 14.5))
		piese.append(cub("Bloc vizavi", (16.0, 10.0, h), (bx, -20.0, h / 2), r.choice((BETON, METAL, TENCUIALA))))
		for fx in range(5):
			for fz in range(int(h / 3) - 1):
				aprins = r.random() < 0.15
				(lumini if aprins else piese).append(cub("Geam bloc", (1.2, 0.02, 1.2), (bx - 6 + fx * 3, -14.99, 2.5 + fz * 3),
					AUR if aprins else GEAM))
		piese.append(cub("Alee bloc", (2.0, 0.8, 0.04), (bx, -14.6, 0.0), BETON))
		piese.append(cub("Usa bloc", (1.4, 0.02, 1.8), (bx, -14.97, 0.9), METAL_INCHIS))
	_cutie_coliziune(col, (L, 1.0, 4.0), (0, -15.5, 2.0))
	strange()
	uneste(piese, "Strada")
	uneste(lumini, "Lumini")
	uneste(col, "Coliziune")
	exporta(os.path.join(cale, "bar_strada.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Decorul de dinăuntru
# ---------------------------------------------------------------------------------------------------------------

def _scaun_bar(piese, x, y, z0=FL, sezut=0.78, cul=ROSU):
	"""Scaunul înalt de la bar: talpa rotundă cromată, piciorul, inelul pentru picioare, șezutul de vinil cu tiv."""
	piese += [
		cilindru("Talpa scaun", 0.21, 0.23, 0.035, (x, y, z0 + 0.0175), CROM, laturi=12),
		cilindru("Picior scaun", 0.03, 0.03, sezut - 0.09, (x, y, z0 + (sezut - 0.09) / 2 + 0.03), CROM, laturi=8),
		_tor("Inel picioare", 0.17, 0.014, (x, y, z0 + 0.32), CROM, segmente=12),
		cilindru("Sub sezut", 0.12, 0.16, 0.04, (x, y, z0 + sezut - 0.08), METAL_INCHIS, laturi=12),
		cilindru("Sezut", 0.2, 0.19, 0.07, (x, y, z0 + sezut - 0.035), cul, laturi=14),
		_tor("Tiv sezut", 0.195, 0.016, (x, y, z0 + sezut - 0.055), LEMN_INCHIS, segmente=14),
	]
	for k in range(4):  # spițele inelului
		u = k * math.pi / 2 + 0.4
		piese.append(os_intre("Spita", (x, y, z0 + 0.32), (x + math.cos(u) * 0.16, y + math.sin(u) * 0.16, z0 + 0.32), 0.008, CROM, laturi=4))


def _sticla(piese, x, y, z, fel, cul, r, eticheta=None):
	"""O sticlă de băutură pe raft: `fel` = „rotunda” (vin, rom), „patrata” (whiskey), „inalta” (vodcă, gin)."""
	if fel == "patrata":
		h = 0.2 + r.uniform(-0.02, 0.02)
		piese.append(cub("Sticla", (0.075, 0.075, h), (x, y, z + h / 2), cul))
		gat = z + h
	else:
		h = (0.22 if fel == "rotunda" else 0.27) + r.uniform(-0.02, 0.02)
		raza = 0.04 if fel == "rotunda" else 0.033
		piese.append(cilindru("Sticla", raza, raza, h, (x, y, z + h / 2), cul, laturi=8))
		gat = z + h
	piese.append(trunchi("Gat sticla", [((x, y, gat), 0.03, 0.03), ((x, y, gat + 0.03), 0.014, 0.014), ((x, y, gat + 0.09), 0.013, 0.013)],
		cul, laturi=6))
	piese.append(cilindru("Dop", 0.015, 0.015, 0.025, (x, y, gat + 0.1), r.choice((AUR, NEGRU, CROM, ROSU)), laturi=6))
	if eticheta:
		if fel == "patrata":
			piese.append(cub("Eticheta", (0.095, 0.095, 0.06), (x, y, z + 0.08), eticheta))
		else:
			raza = 0.04 if fel == "rotunda" else 0.033
			piese.append(cilindru("Eticheta", raza + 0.009, raza + 0.009, 0.06, (x, y, z + 0.08), eticheta, laturi=8))


def _boxa(piese, col, yc):
	"""Un separeu lângă peretele din dreapta: masa lipită de perete, două banchete tapițate față în față."""
	x0, x1 = 5.42, W - 0.02
	piese.append(cub("Blat separeu", (x1 - x0 + 0.02, 0.78, 0.05), ((x0 + x1) / 2 + 0.05, yc, FL + 0.76), LEMN_DESCHIS))
	piese.append(cub("Tiv separeu", (x1 - x0 + 0.04, 0.8, 0.02), ((x0 + x1) / 2 + 0.05, yc, FL + 0.725), NEGRU))
	piese.append(cilindru("Picior separeu", 0.05, 0.05, 0.7, (x0 + 0.5, yc, FL + 0.38), METAL_INCHIS, laturi=8))
	piese.append(cub("Talpa separeu", (0.5, 0.5, 0.03), (x0 + 0.5, yc, FL + 0.015), METAL_INCHIS))
	for s in (-1, 1):
		yb = yc + s * 0.89
		piese.append(cub("Banca separeu", (x1 - x0, 0.5, 0.42), ((x0 + x1) / 2, yb, FL + 0.21), LEMN_INCHIS))
		piese.append(cub("Perna separeu", (x1 - x0 - 0.04, 0.48, 0.08), ((x0 + x1) / 2, yb - s * 0.0, FL + 0.46), ROSU))
		piese.append(cub("Spatar separeu", (x1 - x0, 0.1, 1.3), ((x0 + x1) / 2, yb + s * 0.3, FL + 0.65), LEMN_INCHIS))
		piese.append(cub("Perna spatar", (x1 - x0 - 0.04, 0.06, 0.62), ((x0 + x1) / 2, yb + s * 0.22, FL + 0.84), ROSU))
		for k in range(4):  # capitonajul: dungi verticale
			xx = x0 + 0.2 + k * (x1 - x0 - 0.4) / 3
			piese.append(cub("Capitonaj", (0.012, 0.012, 0.56), (xx, yb + s * 0.188, FL + 0.84), MOV_INCHIS))
		piese.append(cub("Capat banca", (0.06, 0.62, 1.32), (x0 - 0.01, yb + s * 0.06, FL + 0.66), LEMN))
		_cutie_coliziune(col, (x1 - x0 + 0.06, 0.62, 1.3), ((x0 + x1) / 2, yb + s * 0.05, FL + 0.65))
	_cutie_coliziune(col, (x1 - x0, 0.78, 0.8), ((x0 + x1) / 2, yc, FL + 0.4))
	# aplica de pe perete, deasupra mesei, și sticla de ketchup / sarea
	piese.append(cub("Aplica separeu", (0.06, 0.16, 0.22), (W - 0.03, yc, FL + 1.75), BRONZ))
	piese.append(cilindru("Sare", 0.018, 0.018, 0.07, (W - 0.25, yc - 0.05, FL + 0.82), ALB, laturi=6))
	piese.append(cilindru("Ketchup", 0.025, 0.025, 0.14, (W - 0.25, yc + 0.06, FL + 0.855), ROSU, laturi=6))


def _masa_inalta(piese, col, x, y):
	"""Masă înaltă rotundă (de stat în picioare sau pe scaun înalt), cu două scaune."""
	piese += [
		cilindru("Blat masa inalta", 0.36, 0.36, 0.04, (x, y, FL + 1.03), LEMN_DESCHIS, laturi=14),
		_tor("Tiv masa inalta", 0.36, 0.015, (x, y, FL + 1.03), LEMN_INCHIS, segmente=14),
		cilindru("Picior masa inalta", 0.04, 0.04, 1.0, (x, y, FL + 0.52), METAL_INCHIS, laturi=8),
		cilindru("Talpa masa inalta", 0.26, 0.28, 0.035, (x, y, FL + 0.0175), METAL_INCHIS, laturi=12),
		cilindru("Suport servetele", 0.04, 0.04, 0.07, (x + 0.1, y, FL + 1.085), CROM, laturi=6),
	]
	_cutie_coliziune(col, (0.72, 0.72, 1.05), (x, y, FL + 0.525))
	for u in (0.5, 0.5 + math.pi):
		sx, sy = x + math.cos(u) * 0.55, y + math.sin(u) * 0.55
		_scaun_bar(piese, sx, sy, sezut=0.74, cul=LEMN)
		_cutie_coliziune(col, (0.42, 0.42, 0.74), (sx, sy, FL + 0.37))


def _sir_lumini(piese, lumini, a, b, z, sag, pas=0.5):
	"""Un șir de becuri agățat între două puncte (x, y): firul în lănțișor, becurile la `pas` metri."""
	ax, ay = a
	bx, by = b
	lung = math.hypot(bx - ax, by - ay)
	n = max(2, int(lung / pas))
	puncte = []
	for i in range(n + 1):
		t = i / n
		puncte.append((ax + (bx - ax) * t, ay + (by - ay) * t, z - sag * 4 * t * (1 - t)))
	for i in range(n):
		piese.append(os_intre("Fir lumini", puncte[i], puncte[i + 1], 0.004, NEGRU, laturi=3))
	for i in range(1, n):
		x, y, zz = puncte[i]
		piese.append(cilindru("Dulie", 0.012, 0.012, 0.03, (x, y, zz - 0.015), NEGRU, laturi=6))
		lumini.append(sfera("Bec sir", 0.026, (x, y, zz - 0.055), AUR if i % 3 else LEMN_DESCHIS, scara=(1, 1, 1.25), segmente=6, inele=4))
	for x, y, zz in (puncte[0], puncte[-1]):
		piese.append(cub("Carlig", (0.03, 0.03, HC - zz), (x, y, (HC + zz) / 2), METAL_INCHIS))


def masa_biliard(piese, col):
	"""Masa de biliard (7 picioare): postavul verde, mantinelele, cadrul de lemn cu „diamante”, cele 6 buzunare de
	piele, picioarele groase. Suprafața de joc: x PCX ± PW/2, y PCY ± PL/2, la PZ. Lampa de deasupra, cu trei abajururi."""
	x0, x1, y0, y1 = PCX - PW / 2, PCX + PW / 2, PCY - PL / 2, PCY + PL / 2
	piese.append(cub("Postav", (PW + 0.1, PL + 0.1, 0.03), (PCX, PCY, PZ - 0.015), POSTAV))
	# mantinelele (cauciucul îmbrăcat în postav): pe lungime, întrerupte la buzunarele din colțuri și de la mijloc
	gura_colt, gura_mijloc = 0.075, 0.065
	m = 0.05
	for xx, s in ((x0 - m / 2, -1), (x1 + m / 2, 1)):
		for a, b in ((y0 + gura_colt, PCY - gura_mijloc), (PCY + gura_mijloc, y1 - gura_colt)):
			piese.append(cub("Mantinela", (m, b - a, 0.04), (xx, (a + b) / 2, PZ + 0.02), POSTAV))
	for yy in (y0 - m / 2, y1 + m / 2):
		piese.append(cub("Mantinela", (PW - 2 * gura_colt, m, 0.04), (PCX, yy, PZ + 0.02), POSTAV))
	# cadrul de lemn (șina) cu diamantele de sidef
	sina = 0.13
	X0, X1, Y0, Y1 = x0 - m - sina, x1 + m + sina, y0 - m - sina, y1 + m + sina
	for xx in (X0 + sina / 2, X1 - sina / 2):
		for a, b in ((Y0 + 0.13, PCY - 0.075), (PCY + 0.075, Y1 - 0.13)):
			piese.append(cub("Sina biliard", (sina, b - a, 0.06), (xx, (a + b) / 2, PZ + 0.03), LEMN_INCHIS))
	for yy in (Y0 + sina / 2, Y1 - sina / 2):
		piese.append(cub("Sina biliard", (X1 - X0 - 0.26, sina, 0.06), (PCX, yy, PZ + 0.03), LEMN_INCHIS))
	for k in (1, 2, 3, 5, 6, 7):
		yy = y0 + PL * k / 8
		for xx in (X0 + sina / 2, X1 - sina / 2):
			piese.append(cub("Diamant", (0.018, 0.018, 0.006), (xx, yy, PZ + 0.063), ALB, rot=(0, 0, 0.785)))
	for k in (1, 2, 3):
		xx = x0 + PW * k / 4
		for yy in (Y0 + sina / 2, Y1 - sina / 2):
			piese.append(cub("Diamant", (0.018, 0.018, 0.006), (xx, yy, PZ + 0.063), ALB, rot=(0, 0, 0.785)))
	# buzunarele: gaura neagră pe postav, cupa de piele dedesubt, colțurile de metal
	for bx, by, rb in ((x0 - 0.01, y0 - 0.01, 0.062), (x1 + 0.01, y0 - 0.01, 0.062), (x0 - 0.01, y1 + 0.01, 0.062),
			(x1 + 0.01, y1 + 0.01, 0.062), (x0 - 0.03, PCY, 0.058), (x1 + 0.03, PCY, 0.058)):
		piese.append(cilindru("Gaura buzunar", rb, rb, 0.006, (bx, by, PZ + 0.003), NEGRU, laturi=12))
		piese.append(cilindru("Cupa buzunar", rb + 0.02, rb, 0.14, (bx, by, PZ - 0.1), NEGRU, laturi=10))
		piese.append(cilindru("Colt buzunar", rb + 0.035, rb + 0.035, 0.062, (bx + (0.06 if bx > PCX else -0.06), by + (0.0 if by == PCY else (0.06 if by > PCY else -0.06)),
			PZ + 0.03), LEMN_INCHIS, laturi=10))
	# corpul (șorțul) cu panouri, picioarele
	piese.append(cub("Corp biliard", (X1 - X0 - 0.06, Y1 - Y0 - 0.06, 0.24), (PCX, PCY, PZ - 0.14), LEMN))
	for yy in (PCY - 0.7, PCY, PCY + 0.7):
		for xx, s in ((X0 + 0.03, -1), (X1 - 0.03, 1)):
			piese.append(cub("Panou corp", (0.012, 0.5, 0.14), (xx + s * 0.006, yy, PZ - 0.14), LEMN_INCHIS))
	for xx in (X0 + 0.14, X1 - 0.14):
		for yy in (Y0 + 0.16, Y1 - 0.16):
			piese.append(cub("Picior biliard", (0.16, 0.16, PZ - 0.26 - FL), (xx, yy, (FL + PZ - 0.26) / 2), LEMN_INCHIS))
			piese.append(cub("Talpa picior", (0.2, 0.2, 0.06), (xx, yy, FL + 0.03), NEGRU))
	_cutie_coliziune(col, (X1 - X0, Y1 - Y0, PZ + 0.06 - FL), (PCX, PCY, (FL + PZ + 0.06) / 2))
	return X0, X1, Y0, Y1


def decor(cale):
	"""Dinăuntru: tejgheaua lungă cu blatul gros, bara de alamă pentru picioare, robinetele de bere, casa de marcat;
	în spatele ei dulapul, oglinda și rafturile cu sticle (luminate pe dedesubt), neonul „URBAN”; scaunele înalte;
	lămpile de deasupra barului; televizorul din colț; masa de biliard cu lampa și suportul de tacuri; colțul de darts
	(dulăpiorul cu tabla de scor, linia de aruncare, covorul); două separeuri; mesele înalte; tonomatul; ușile de la
	toalete și „EMPLOYEES ONLY”; plăcuțele de înmatriculare, tablourile, chitara; șirurile de becuri de sub tavan.
	Piese: `Decor`, `Lumini`, `Geamuri`, `Coliziune`."""
	curata()
	r = random.Random(41)
	piese, lumini, geamuri, col = [], [], [], []

	def strange():
		_strange(piese, "Decor")

	# --- tejgheaua
	ym = (BY0 + BY1) / 2
	piese.append(cub("Corp tejghea", (BX1 - BX0, BY1 - BY0, BZ - 0.06 - FL), ((BX0 + BX1) / 2, ym, (FL + BZ - 0.06) / 2), LEMN_INCHIS))
	piese.append(cub("Plinta tejghea", (0.02, BY1 - BY0, 0.14), (BX1 + 0.01, ym, FL + 0.07), NEGRU))
	y = BY0 + 0.12
	while y < BY1 - 0.05:
		piese.append(cub("Sipca tejghea", (0.02, 0.05, BZ - FL - 0.3), (BX1 + 0.01, y, (FL + BZ) / 2 - 0.03), LEMN))
		y += 0.16
	for yy in (BY0, BY1):  # capetele
		piese.append(cub("Capat tejghea", (BX1 - BX0 + 0.04, 0.04, BZ - 0.06 - FL), ((BX0 + BX1) / 2, yy + (-0.02 if yy == BY0 else 0.02),
			(FL + BZ - 0.06) / 2), LEMN_INCHIS))
	piese.append(cub("Blat", (BX1 - BX0 + 0.15, BY1 - BY0 + 0.1, 0.06), ((BX0 + BX1) / 2 + 0.05, ym, BZ - 0.03), LEMN))
	piese.append(cilindru("Bordura blat", 0.035, 0.035, BY1 - BY0 + 0.1, (BX1 + 0.12, ym, BZ - 0.035), LEMN_INCHIS, laturi=8,
		rot=(1.5708, 0, 0)))
	_cutie_coliziune(col, (BX1 - BX0 + 0.2, BY1 - BY0 + 0.1, BZ - FL), ((BX0 + BX1) / 2 + 0.07, ym, (FL + BZ) / 2))
	# panourile dintre capetele tejghelei și peretele din stânga: în spatele barului intră doar barmanul
	for yy in (BY0 - 0.04, BY1 + 0.04):
		piese.append(cub("Panou capat", (BX0 + W, 0.06, BZ - FL - 0.06), ((-W + BX0) / 2, yy, (FL + BZ - 0.06) / 2), LEMN_INCHIS))
		piese.append(cub("Blat panou", (BX0 + W, 0.14, 0.05), ((-W + BX0) / 2, yy, BZ - 0.025), LEMN))
		for k in range(1, 5):
			piese.append(cub("Sipca panou", (0.05, 0.02, BZ - FL - 0.3), (-W + k * (BX0 + W) / 5, yy + (-0.04 if yy < ym else 0.04), (FL + BZ) / 2 - 0.03),
				LEMN))
		_cutie_coliziune(col, (BX0 + W, 0.14, 1.6), ((-W + BX0) / 2, yy, FL + 0.8))
	piese.append(cilindru("Bara picioare", 0.024, 0.024, BY1 - BY0 - 0.2, (BX1 + 0.17, ym, FL + 0.22), BRONZ, laturi=8, rot=(1.5708, 0, 0)))
	y = BY0 + 0.4
	while y < BY1 - 0.2:
		piese.append(os_intre("Suport bara", (BX1 + 0.02, y, FL + 0.32), (BX1 + 0.17, y, FL + 0.22), 0.012, BRONZ, laturi=4))
		y += 1.3
	# pe blat: suporturi de pahar (unul în fața barmanului, unde îți pune băutura), robinetele de bere, casa de marcat,
	# servețelele, castronul cu alune, scrumiera
	for yy in (3.4, 5.4, Y_BARMAN, 8.4):
		piese.append(cilindru("Suport pahar", 0.05, 0.05, 0.006, (-4.12, yy, BZ + 0.003), (ALB if yy == Y_BARMAN else AUR), laturi=10))
	tx, ty = -4.3, 8.3
	piese += [
		cub("Tava robinete", (0.18, 0.6, 0.02), (tx, ty, BZ + 0.01), CROM),
		cilindru("Coloana robinete", 0.03, 0.03, 0.42, (tx - 0.02, ty - 0.22, BZ + 0.21), CROM, laturi=8),
		cilindru("Coloana robinete", 0.03, 0.03, 0.42, (tx - 0.02, ty + 0.22, BZ + 0.21), CROM, laturi=8),
		cilindru("Bara robinete", 0.035, 0.035, 0.52, (tx - 0.02, ty, BZ + 0.43), CROM, laturi=8, rot=(1.5708, 0, 0)),
	]
	for k, cul in enumerate((AUR, ROSU, PETROL_DESCHIS, NEGRU)):
		yy = ty - 0.18 + k * 0.12
		piese.append(cub("Cioc robinet", (0.05, 0.02, 0.06), (tx + 0.03, yy, BZ + 0.37), CROM))
		piese.append(cub("Maner robinet", (0.035, 0.035, 0.16), (tx - 0.02, yy, BZ + 0.53), cul))
		piese.append(cub("Eticheta robinet", (0.038, 0.038, 0.04), (tx - 0.02, yy, BZ + 0.56), ALB))
	piese += [
		cub("Casa marcat", (0.34, 0.36, 0.16), (-4.25, 10.1, BZ + 0.08), NEGRU),
		cub("Ecran casa", (0.04, 0.24, 0.14), (-4.36, 10.1, BZ + 0.24), METAL_INCHIS, rot=(0, -0.4, 0)),
		cub("Sertar casa", (0.03, 0.3, 0.06), (-4.43, 10.1, BZ + 0.05), METAL_INCHIS),
		cub("Servetele", (0.1, 0.14, 0.05), (-4.0, 4.9, BZ + 0.025), ALB),
		cilindru("Castron alune", 0.07, 0.05, 0.05, (-4.0, 7.4, BZ + 0.025), LEMN_INCHIS, laturi=10),
		cilindru("Alune", 0.06, 0.06, 0.012, (-4.0, 7.4, BZ + 0.05), BRONZ, laturi=10),
		cilindru("Scrumiera", 0.055, 0.055, 0.025, (-4.0, 9.2, BZ + 0.0125), METAL_INCHIS, laturi=10),
	]
	lumini.append(cub("Ecran casa lumina", (0.012, 0.2, 0.1), (-4.385, 10.1, BZ + 0.245), TEAL_DESCHIS, rot=(0, -0.4, 0)))
	strange()

	# --- scaunele de la bar (cel din fața barmanului e separat, cu E)
	for yy in Y_SCAUNE:
		_scaun_bar(piese, X_SCAUNE, yy)
		_cutie_coliziune(col, (0.4, 0.4, 0.78), (X_SCAUNE, yy, FL + 0.39))
	strange()

	# --- în spatele barului: dulapul, panoul, oglinda, rafturile cu sticle luminate, neonul, ușa de la depozit
	dx0, dx1, dy0, dy1 = -W, -W + 0.55, 2.8, 10.4
	piese.append(cub("Dulap bar", (dx1 - dx0, dy1 - dy0, 0.9), ((dx0 + dx1) / 2, (dy0 + dy1) / 2, FL + 0.45), LEMN))
	piese.append(cub("Blat dulap", (dx1 - dx0 + 0.04, dy1 - dy0, 0.04), ((dx0 + dx1) / 2 + 0.02, (dy0 + dy1) / 2, FL + 0.92), LEMN_DESCHIS))
	y = dy0 + 0.05
	while y < dy1 - 0.3:
		piese.append(cub("Usa dulap", (0.012, 0.56, 0.7), (dx1 + 0.006, y + 0.3, FL + 0.47), LEMN_INCHIS))
		piese.append(cub("Maner dulap", (0.02, 0.012, 0.1), (dx1 + 0.02, y + 0.53, FL + 0.6), CROM))
		y += 0.62
	_cutie_coliziune(col, (dx1 - dx0, dy1 - dy0, 0.95), ((dx0 + dx1) / 2, (dy0 + dy1) / 2, FL + 0.475))
	piese.append(cub("Panou bar", (0.02, dy1 - dy0, HC - 0.35 - FL - 0.94), (-W + 0.01, (dy0 + dy1) / 2, (FL + 0.94 + HC - 0.35) / 2), LEMN_INCHIS))
	geamuri.append(cub("Geam oglinda", (0.01, 5.2, 1.25), (-W + 0.03, (dy0 + dy1) / 2, FL + 1.68), GEAM))
	for yy in ((dy0 + dy1) / 2 - 2.62, (dy0 + dy1) / 2 + 2.62):
		piese.append(cub("Rama oglinda", (0.04, 0.05, 1.33), (-W + 0.04, yy, FL + 1.68), AUR))
	for zz in (FL + 1.04, FL + 2.32):
		piese.append(cub("Rama oglinda", (0.04, 5.29, 0.05), (-W + 0.04, (dy0 + dy1) / 2, zz), AUR))
	for zz in (FL + 1.3, FL + 1.72, FL + 2.14):
		piese.append(cub("Raft sticle", (0.24, dy1 - dy0 - 0.2, 0.03), (-W + 0.16, (dy0 + dy1) / 2, zz), LEMN_DESCHIS))
		lumini.append(cub("Led raft", (0.02, dy1 - dy0 - 0.3, 0.008), (-W + 0.25, (dy0 + dy1) / 2, zz - 0.019), (MOV, TEAL_DESCHIS, MOV)[int(zz * 10) % 3]))
		yy = dy0 + 0.22
		while yy < dy1 - 0.2:
			fel = r.choice(("rotunda", "patrata", "inalta", "rotunda"))
			cul = r.choice((AUR, LEMN_DESCHIS, PETROL_DESCHIS, ALB, LEMN, BRONZ, VERDE, ROSU))
			_sticla(piese, -W + 0.16, yy, zz + 0.015, fel, cul, r, eticheta=r.choice((ALB, NEGRU, AUR, None)))
			yy += r.uniform(0.13, 0.2)
		strange()
	# pe blatul dulapului: sticle, pahare răsturnate pe un prosop, shaker-ul
	yy = dy0 + 0.3
	while yy < dy1 - 0.3:
		if not (5.6 < yy < 7.4 or 7.55 < yy < 8.45):  # locul sticlelor de turnat (sunt separate, în joc)
			_sticla(piese, -W + 0.3, yy, FL + 0.94, r.choice(("rotunda", "patrata", "inalta")), r.choice((AUR, LEMN_DESCHIS, ALB, PETROL_DESCHIS)), r)
		yy += r.uniform(0.35, 0.6)
	piese.append(cub("Prosop", (0.3, 0.5, 0.01), (-W + 0.32, 8.0, FL + 0.945), ALB))
	for k in range(6):
		piese.append(cilindru("Pahar intors", 0.035, 0.03, 0.09, (-W + 0.24 + (k % 2) * 0.1, 7.85 + (k // 2) * 0.11, FL + 0.995), GRI_ALBASTRU, laturi=8))
	piese.append(cilindru("Shaker", 0.04, 0.035, 0.2, (-W + 0.3, 9.9, FL + 1.04), CROM, laturi=8))
	# neonul „URBAN” de deasupra rafturilor și „EST. 1979”
	lumini.append(_text("Neon bar", "URBAN", (-W + 0.05, (dy0 + dy1) / 2, HC - 0.62), 0.42, TEAL_DESCHIS, rot=(1.5708, 0, 1.5708)))
	piese.append(cub("Placa neon bar", (0.02, 2.3, 0.6), (-W + 0.025, (dy0 + dy1) / 2, HC - 0.62), NEGRU))
	piese.append(_text("Scris est", "EST. 1979", (-W + 0.05, (dy0 + dy1) / 2, HC - 1.0), 0.1, AUR, rot=(1.5708, 0, 1.5708)))
	strange()
	# lămpile de deasupra barului (abajur de tablă, becul)
	for yy in (4.0, 6.6, 9.2):
		piese.append(cub("Cablu lampa", (0.008, 0.008, HC - 2.45), (-4.2, yy, (HC + 2.45) / 2), NEGRU))
		piese.append(trunchi("Abajur bar", [((-4.2, yy, 2.48), 0.03, 0.03), ((-4.2, yy, 2.45), 0.05, 0.05), ((-4.2, yy, 2.32), 0.17, 0.17),
			((-4.2, yy, 2.3), 0.175, 0.175)], METAL_INCHIS, laturi=12, capete=False))
		piese.append(trunchi("Abajur bar int", [((-4.2, yy, 2.305), 0.168, 0.168), ((-4.2, yy, 2.32), 0.163, 0.163), ((-4.2, yy, 2.45), 0.043, 0.043)],
			AUR, laturi=12, capete=False))
		lumini.append(sfera("Bec bar", 0.045, (-4.2, yy, 2.36), AUR, scara=(1, 1, 1.3), segmente=8, inele=5))
	# televizorul din colț (meci pe ecran: verdele terenului și o bandă cu scorul)
	tv = [
		cub("Televizor", (0.08, 0.95, 0.56), (0, 0, 0), NEGRU),
		cub("Suport tv", (0.3, 0.06, 0.06), (0.15, 0, 0.0), METAL_INCHIS),
	]
	ecran = [cub("Ecran tv", (0.01, 0.86, 0.48), (-0.045, 0, 0), POSTAV), cub("Scor tv", (0.012, 0.3, 0.06), (-0.048, -0.2, 0.18), ALB)]
	for o in tv + ecran:
		o.rotation_euler = (0, 0.12, -0.5)
		o.location = (o.location[0] - 6.55, o.location[1] + 11.55, o.location[2] + 2.75)
	bpy.ops.object.select_all(action='DESELECT')
	for o in tv + ecran:
		o.select_set(True)
	bpy.context.view_layer.objects.active = tv[0]
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	piese += tv
	lumini += ecran
	strange()

	# --- ușile închise de pe peretele din spate: „EMPLOYEES ONLY” în spatele barului, toaletele
	for ux, scris in ((-5.8, "EMPLOYEES\nONLY"), (1.7, "RESTROOMS")):
		piese.append(cub("Usa inchisa", (0.92, 0.05, 2.15), (ux, D - 0.03, FL + 1.075), LEMN_INCHIS))
		for zz in (FL + 0.5, FL + 1.5):
			piese.append(cub("Panou usa", (0.7, 0.012, 0.7), (ux, D - 0.061, zz), LEMN))
		piese.append(cub("Toc usa inchisa", (1.04, 0.07, 0.06), (ux, D - 0.035, FL + 2.18), NEGRU))
		piese.append(cub("Maner usa inchisa", (0.12, 0.03, 0.03), (ux + 0.33, D - 0.09, FL + 1.0), CROM))
		piese.append(cub("Placuta usa", (0.5, 0.012, 0.2), (ux, D - 0.072, FL + 1.75), NEGRU))
		piese.append(_text_o_fata("Scris usa", scris, (ux, D - 0.08, FL + 1.75), 0.06, ALB))
	strange()

	# --- masa de biliard, lampa ei, suportul de tacuri de pe perete, triunghiul agățat
	masa_biliard(piese, col)
	lz = PZ + 1.0
	piese.append(cub("Lampa biliard", (0.26, 1.55, 0.1), (PCX, PCY, lz + 0.12), VERDE_NEGRU))
	piese.append(cub("Tiv lampa", (0.28, 1.57, 0.03), (PCX, PCY, lz + 0.065), BRONZ))
	piese.append(_text_o_fata("Scris lampa", "URBAN", (PCX - 0.131, PCY, lz + 0.12), 0.07, AUR, rot=(1.5708, 0, -1.5708)))
	piese.append(_text_o_fata("Scris lampa", "URBAN", (PCX + 0.131, PCY, lz + 0.12), 0.07, AUR, rot=(1.5708, 0, 1.5708)))
	for yy in (PCY - 0.52, PCY, PCY + 0.52):
		piese.append(trunchi("Abajur biliard", [((PCX, yy, lz + 0.06), 0.06, 0.06), ((PCX, yy, lz), 0.11, 0.11), ((PCX, yy, lz - 0.12), 0.2, 0.2),
			((PCX, yy, lz - 0.13), 0.205, 0.205)], VERDE, laturi=12, capete=False))
		piese.append(trunchi("Abajur biliard int", [((PCX, yy, lz - 0.125), 0.197, 0.197), ((PCX, yy, lz - 0.115), 0.19, 0.19),
			((PCX, yy, lz), 0.1, 0.1)], ALB, laturi=12, capete=False))
		lumini.append(sfera("Bec biliard", 0.05, (PCX, yy, lz - 0.06), AUR, segmente=8, inele=5))
	for yy in (PCY - 0.6, PCY + 0.6):
		piese.append(cub("Lant lampa", (0.01, 0.01, HC - lz - 0.17), (PCX, yy, (HC + lz + 0.17) / 2), CROM))
	rx = W - 0.03
	piese.append(cub("Suport tacuri", (0.05, 1.1, 0.08), (rx, PCY, FL + 1.55), LEMN_INCHIS))
	piese.append(cub("Suport tacuri jos", (0.12, 1.1, 0.05), (W - 0.06, PCY, FL + 0.12), LEMN_INCHIS))
	for k in range(7):
		yy = PCY - 0.45 + k * 0.15
		piese.append(os_intre("Tac perete", (W - 0.07, yy, FL + 0.15), (W - 0.04, yy, FL + 1.6), 0.013 - 0.004 * (k % 2),
			(LEMN_DESCHIS if k % 2 else BRONZ), laturi=6))
	for k in range(3):
		piese.append(cub("Creta", (0.025, 0.025, 0.02), (W - 0.06, PCY - 0.2 + k * 0.2, FL + 1.6), TEAL))
	tri = [os_intre("Triunghi", (W - 0.03, 8.2, 1.9), (W - 0.03, 8.5, 1.9), 0.012, LEMN_INCHIS, laturi=4),
		os_intre("Triunghi", (W - 0.03, 8.2, 1.9), (W - 0.03, 8.35, 2.16), 0.012, LEMN_INCHIS, laturi=4),
		os_intre("Triunghi", (W - 0.03, 8.5, 1.9), (W - 0.03, 8.35, 2.16), 0.012, LEMN_INCHIS, laturi=4)]
	piese += tri
	strange()

	# --- colțul de darts: dulăpiorul (ușile deschise cu tabla de scor), covorul de cauciuc, linia, spotul
	piese.append(cub("Dulap darts", (0.06, 0.72, 0.8), (W - 0.03, DY, DZ), LEMN_INCHIS))
	for s in (-1, 1):
		# ușa deschisă (în balamale pe marginea dulapului), cu tabla de scor pe interior
		ux, uy = W - 0.03, DY + s * 0.36
		ob = cub("Usa darts", (0.03, 0.36, 0.8), (0, s * 0.18, 0), LEMN_INCHIS)
		tabla = cub("Tabla scor", (0.012, 0.3, 0.7), (-0.021, s * 0.18, 0), NEGRU)
		linii = [cub("Linie scor", (0.008, 0.28, 0.008), (-0.03, s * 0.18, -0.25 + j * 0.1), ALB) for j in range(6)]
		linii.append(cub("Linie scor", (0.008, 0.008, 0.6), (-0.03, s * 0.18, 0.0), ALB))
		bucati = [ob, tabla] + linii
		_roteste_muta(bucati, s * 1.15, (ux, uy, DZ))
		piese += bucati
	piese.append(cub("Covor darts", (W - 4.35, 1.2, 0.01), ((W + 4.35) / 2, DY, FL + 0.005), NEGRU))
	piese.append(cub("Linie darts", (0.04, 0.9, 0.01), (LINIE_DARTS, DY, FL + 0.016), BRONZ))
	piese.append(_text_o_fata("Scris linie", "OCHE", (LINIE_DARTS - 0.15, DY, FL + 0.0115), 0.07, ALB, rot=(0, 0, -1.5708)))
	piese.append(cub("Spot darts", (0.12, 0.12, 0.16), (LINIE_DARTS + 0.5, DY, HC - 0.08), NEGRU))
	lumini.append(cub("Bec spot darts", (0.08, 0.08, 0.01), (LINIE_DARTS + 0.5, DY, HC - 0.165), AUR))
	piese.append(cub("Placa darts", (0.02, 0.9, 0.22), (W - 0.01, DY, DZ + 0.6), NEGRU))
	piese.append(_text_o_fata("Scris darts", "DARTS", (W - 0.025, DY, DZ + 0.6), 0.14, ROSU, rot=(1.5708, 0, -1.5708)))
	# masa înaltă de lângă darts (berea omului de la darts e în joc, nu aici)
	_masa_inalta(piese, col, 3.2, 12.15)
	strange()

	# --- separeurile, mesele înalte, tonomatul
	for yc in (2.15, 4.55):
		_boxa(piese, col, yc)
	strange()
	for x, y in ((-1.0, 2.7), (-1.1, 5.0), (-0.2, 11.3)):
		_masa_inalta(piese, col, x, y)
	strange()
	jx, jy = -2.6, D - 0.3
	piese += [
		cub("Tonomat", (0.9, 0.55, 1.15), (jx, jy, FL + 0.575), LEMN_INCHIS),
		cilindru("Arc tonomat", 0.45, 0.45, 0.55, (jx, jy, FL + 1.15), LEMN_INCHIS, laturi=16, rot=(1.5708, 0, 0)),
		cub("Grila tonomat", (0.6, 0.012, 0.4), (jx, jy - 0.281, FL + 0.38), METAL_INCHIS),
	]
	for k in range(5):
		piese.append(cub("Bara grila", (0.6, 0.014, 0.014), (jx, jy - 0.29, FL + 0.22 + k * 0.08), CROM))
	lumini += [
		cub("Panou tonomat", (0.56, 0.012, 0.26), (jx, jy - 0.281, FL + 0.82), ALB),
		_tor("Tub tonomat", 0.42, 0.02, (jx, jy - 0.29, FL + 1.15), AUR, rot=(1.5708, 0, 0), segmente=20),
		_tor("Tub tonomat", 0.34, 0.02, (jx, jy - 0.29, FL + 1.15), ROSU, rot=(1.5708, 0, 0), segmente=20),
	]
	for k in range(4):
		piese.append(cub("Disc tonomat", (0.1, 0.012, 0.1), (jx - 0.18 + k * 0.12, jy - 0.293, FL + 0.82), NEGRU))
	_cutie_coliziune(col, (0.9, 0.55, 1.6), (jx, jy, FL + 0.8))
	strange()

	# --- pe pereți: plăcuțele de înmatriculare (dreapta), tablourile și chitara (spate), „ROUTE 66”, neonul „COLD BEER”
	for k in range(10):
		yy = 5.7 + (k % 5) * 0.72
		zz = FL + 2.25 + (k // 5) * 0.3
		cul = (AUR, ALB, PETROL, ROSU, TEAL, ALB, AUR, MASLINIU, ALB, PETROL_DESCHIS)[k]
		piese.append(cub("Placuta", (0.012, 0.42, 0.2), (W - 0.007, yy, zz), cul, rot=(r.uniform(-0.08, 0.08), 0, 0)))
		piese.append(cub("Numar placuta", (0.012, 0.3, 0.06), (W - 0.016, yy, zz - 0.01), NEGRU if cul != NEGRU else ALB))
	piese.append(cub("Route 66", (0.012, 0.5, 0.55), (W - 0.007, 3.35, FL + 2.45), ALB))
	piese.append(_text_o_fata("Scris route", "ROUTE\n66", (W - 0.016, 3.35, FL + 2.45), 0.12, NEGRU, rot=(1.5708, 0, -1.5708)))
	for k, (xx, lat, inalt, cul) in enumerate(((-5.0, 0.6, 0.45, ROSU), (-0.2, 0.5, 0.7, PETROL), (0.7, 0.45, 0.6, AUR),
			(4.2, 0.7, 0.5, MOV))):
		piese.append(cub("Rama tablou", (lat + 0.08, 0.03, inalt + 0.08), (xx, D - 0.015, FL + 2.2), LEMN_INCHIS))
		piese.append(cub("Tablou", (lat, 0.012, inalt), (xx, D - 0.036, FL + 2.2), cul))
	# chitara electrică (corpul, gâtul, capul) pe peretele din spate, lângă tonomat
	cx, cz = -3.7, FL + 1.75
	piese += [
		cub("Chitara corp", (0.32, 0.04, 0.42), (cx, D - 0.04, cz), ROSU, rot=(0, 0.25, 0)),
		cub("Chitara gat", (0.05, 0.03, 0.6), (cx + 0.1, D - 0.035, cz + 0.48), LEMN_DESCHIS, rot=(0, 0.25, 0)),
		cub("Chitara cap", (0.08, 0.03, 0.14), (cx + 0.19, D - 0.035, cz + 0.83), NEGRU, rot=(0, 0.25, 0)),
		cub("Chitara doza", (0.14, 0.012, 0.04), (cx, D - 0.066, cz + 0.05), CROM, rot=(0, 0.25, 0)),
	]
	piese.append(cub("Placa cold beer", (2.0, 0.02, 0.4), (-2.6, D - 0.01, FL + 2.75), NEGRU))
	lumini.append(_text_o_fata("Neon cold beer", "COLD BEER", (-2.6, D - 0.025, FL + 2.75), 0.24, AUR))
	strange()

	# --- șirurile de becuri, în zigzag de la stânga la dreapta, sub tavan
	capete = [(-3.5, 1.0), (6.8, 3.2), (-3.5, 5.5), (6.8, 7.9), (-3.5, 10.2), (6.8, 12.6)]
	for a, b in zip(capete, capete[1:]):
		_sir_lumini(piese, lumini, a, b, HC - 0.22, 0.42)
	strange()

	desparte_fete(distanta=0.01, fixe=("Corp tejghea", "Blat", "Dulap bar", "Panou bar", "Postav", "Corp biliard",
		"Covor darts", "Tonomat", "Spatar separeu", "Banca separeu", "Blat separeu"))
	uneste(piese, "Decor")
	uneste(lumini, "Lumini")
	uneste(geamuri, "Geamuri")
	uneste(col, "Coliziune")
	exporta(os.path.join(cale, "decor_bar.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Obiectele cu care joci (separate, se mișcă în joc)
# ---------------------------------------------------------------------------------------------------------------

def scaun_bar_urban(cale):
	"""Scaunul din fața barmanului (cel cu „[E] Sit at the bar”). Originea = podeaua de sub el."""
	curata()
	piese = []
	_scaun_bar(piese, 0, 0, z0=0.0)
	uneste(piese, "Scaun")
	exporta(os.path.join(cale, "scaun_bar_urban.glb"))


def usa_bar(cale):
	"""Ușa barului: lemn închis cu un geam mic rotund, mânerul de alamă, „PULL” pe dinăuntru. Originea = balamaua
	(jos, în stânga privită de pe stradă); ușa merge spre +X."""
	curata()
	L, H = USA[1] - USA[0] - 0.06, USA[3] - USA[2] - 0.04
	piese = [cub("Usa", (L, 0.05, H), (L / 2, 0, H / 2), LEMN_INCHIS)]
	for zz in (0.45, 1.25):
		for s in (-1, 1):
			piese.append(cub("Panou usa", (L - 0.2, 0.012, 0.55), (L / 2, s * 0.031, zz), LEMN))
	piese.append(cilindru("Rama hublou", 0.17, 0.17, 0.07, (L / 2, 0, 1.85), BRONZ, laturi=14, rot=(1.5708, 0, 0)))
	geam = cilindru("Geam hublou", 0.14, 0.14, 0.074, (L / 2, 0, 1.85), GEAM, laturi=14, rot=(1.5708, 0, 0))
	for s in (-1, 1):
		piese.append(os_intre("Maner usa", (L - 0.12, s * 0.025, 0.95), (L - 0.12, s * 0.09, 0.95), 0.012, BRONZ, laturi=6))
		piese.append(os_intre("Maner usa", (L - 0.12, s * 0.09, 0.85), (L - 0.12, s * 0.09, 1.15), 0.016, BRONZ, laturi=6))
	piese.append(cub("Placuta pull", (0.22, 0.012, 0.08), (L - 0.12, 0.046, 1.32), BRONZ))
	piese.append(_text_o_fata("Scris pull", "PULL", (L - 0.12, 0.054, 1.32), 0.045, NEGRU, rot=(1.5708, 0, 3.14159)))
	uneste(piese, "Usa")
	uneste([geam], "Geam")
	exporta(os.path.join(cale, "usa_bar.glb"))


# Ordinea sectoarelor pe tabla de darts, în sensul acelor de ceas, de la 20 (sus).
SECTOARE = (20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5)
# Razele (metri): bull, outer bull, triplu, dublu, marginea tablei cu numere.
R_BULL, R_25, R_T0, R_T1, R_D0, R_D1, R_TABLA = 0.00635, 0.0159, 0.099, 0.107, 0.162, 0.17, 0.2255


def tabla_darts(cale):
	"""Ținta de darts, standard: 20 de sectoare alternând negru / crem, triplul și dublul roșu / verde, bull-ul, inelul
	negru cu numere. Originea = centrul tablei, fața spre -Y (în Godot +Z). În joc, scorul se calculează cu aceleași
	raze (darts_bar.gd), deci ce vezi e ce primești."""
	curata()
	piese = []
	n = (0, -1, 0)

	def petic(nume, r0, r1, u0, u1, cul, y=0.0, pasi=3):
		pts_ext = [(r1 * math.sin(u0 + (u1 - u0) * k / pasi), y, r1 * math.cos(u0 + (u1 - u0) * k / pasi)) for k in range(pasi + 1)]
		if r0 <= 0.0:
			return _fata(nume, [(0, y, 0)] + pts_ext, cul, n)
		pts_int = [(r0 * math.sin(u0 + (u1 - u0) * k / pasi), y, r0 * math.cos(u0 + (u1 - u0) * k / pasi)) for k in range(pasi + 1)]
		return _fata(nume, pts_ext + list(reversed(pts_int)), cul, n)

	CREM, NEGRU_T = AUR, NEGRU
	felie = 2 * math.pi / 20
	for i in range(20):
		u0, u1 = (i - 0.5) * felie, (i + 0.5) * felie
		par = i % 2 == 0
		simplu = NEGRU_T if par else CREM
		inel = ROSU if par else POSTAV
		piese += [
			petic("Simplu", R_25, R_T0, u0, u1, simplu),
			petic("Triplu", R_T0, R_T1, u0, u1, inel),
			petic("Simplu", R_T1, R_D0, u0, u1, simplu, pasi=4),
			petic("Dublu", R_D0, R_D1, u0, u1, inel, pasi=4),
			petic("Margine", R_D1, R_TABLA, u0, u1, NEGRU_T, pasi=4),
		]
		# numărul sectorului pe inelul negru (drept, ca pe o tablă adevărată)
		u = i * felie
		piese.append(_text_o_fata("Numar", str(SECTOARE[i]), (0.198 * math.sin(u), -0.003, 0.198 * math.cos(u)), 0.026, ALB))
	for k in range(24):
		u0, u1 = k * 2 * math.pi / 24, (k + 1) * 2 * math.pi / 24
		piese.append(petic("Bull 25", R_BULL, R_25, u0, u1, POSTAV, pasi=1))
		piese.append(petic("Bull", 0.0, R_BULL, u0, u1, ROSU, pasi=1))
	# sârmele dintre sectoare (pe față, subțiri) și inelele de sârmă
	for i in range(20):
		u = (i - 0.5) * felie
		piese.append(os_intre("Sarma", (R_25 * math.sin(u), -0.002, R_25 * math.cos(u)), (R_D1 * math.sin(u), -0.002, R_D1 * math.cos(u)),
			0.0009, CROM, laturi=3))
	for rr in (R_25, R_T0, R_T1, R_D0, R_D1):
		piese.append(_tor("Sarma inel", rr, 0.0009, (0, -0.002, 0), CROM, rot=(1.5708, 0, 0), segmente=40))
	piese.append(cilindru("Spate tabla", R_TABLA + 0.005, R_TABLA + 0.005, 0.035, (0, 0.0185, 0), NEGRU, laturi=40, rot=(1.5708, 0, 0)))
	uneste(piese, "Tabla")
	exporta(os.path.join(cale, "tabla_darts.glb"))


def _sageata(cale, nume, cul):
	"""O săgeată de darts: vârful de oțel, corpul de tungsten zimțat, tija, cele patru aripioare. Originea = vârful,
	săgeata merge spre -Y (în Godot spre +Z: vârful înainte când o rotești spre țintă cu looking_at din spate)."""
	curata()
	piese = [
		cilindru("Varf", 0.0008, 0.0016, 0.03, (0, -0.015, 0), CROM, laturi=6, rot=(1.5708, 0, 0)),
		cilindru("Corp sageata", 0.0034, 0.0034, 0.045, (0, -0.0525, 0), METAL, laturi=8, rot=(1.5708, 0, 0)),
	]
	for k in range(4):
		piese.append(cilindru("Zimt", 0.0037, 0.0037, 0.003, (0, -0.036 - k * 0.009, 0), METAL_INCHIS, laturi=8, rot=(1.5708, 0, 0)))
	piese.append(cilindru("Tija", 0.0022, 0.0022, 0.04, (0, -0.095, 0), NEGRU, laturi=6, rot=(1.5708, 0, 0)))
	for k in range(4):
		u = k * math.pi / 2
		dx, dz = math.cos(u), math.sin(u)
		piese.append(_fata("Aripioara", [(0, -0.1, 0), (dx * 0.016, -0.108, dz * 0.016), (dx * 0.016, -0.135, dz * 0.016), (0, -0.135, 0)],
			cul, (-dz, 0, dx)))
		piese.append(_fata("Aripioara", [(0, -0.1, 0), (dx * 0.016, -0.108, dz * 0.016), (dx * 0.016, -0.135, dz * 0.016), (0, -0.135, 0)],
			cul, (dz, 0, -dx)))
	uneste(piese, "Sageata")
	exporta(os.path.join(cale, nume + ".glb"))


def sageti(cale):
	_sageata(cale, "sageata_rosie", ROSU)
	_sageata(cale, "sageata_albastra", TEAL)


def tac(cale):
	"""Tacul de biliard (1,45 m): vârful albastru de cretă, inelul alb, tija de arțar, îmbinarea cromată, capătul de
	lemn închis cu mânerul înfășurat. Originea = vârful, tacul merge spre -Y (în Godot +Z: din spate în față)."""
	curata()
	piese = [
		cilindru("Varf tac", 0.0062, 0.0062, 0.008, (0, -0.004, 0), TEAL, laturi=8, rot=(1.5708, 0, 0)),
		cilindru("Inel tac", 0.0064, 0.0064, 0.022, (0, -0.019, 0), ALB, laturi=8, rot=(1.5708, 0, 0)),
		trunchi("Tija tac", [((0, -0.03, 0), 0.0065, 0.0065), ((0, -0.7, 0), 0.0098, 0.0098)], LEMN_DESCHIS, laturi=8),
		cilindru("Imbinare", 0.0105, 0.0105, 0.03, (0, -0.715, 0), CROM, laturi=8, rot=(1.5708, 0, 0)),
		trunchi("Capat tac", [((0, -0.73, 0), 0.011, 0.011), ((0, -1.43, 0), 0.0145, 0.0145)], LEMN_INCHIS, laturi=8),
		trunchi("Manson tac", [((0, -0.98, 0), 0.0128, 0.0128), ((0, -1.25, 0), 0.0139, 0.0139)], NEGRU, laturi=8, capete=False),
		cilindru("Talpa tac", 0.0148, 0.0148, 0.02, (0, -1.44, 0), NEGRU, laturi=8, rot=(1.5708, 0, 0)),
	]
	for t in (0.75, 0.8, 0.85, 0.9):
		piese.append(cub("Romb tac", (0.006, 0.02, 0.006), (0, -t, 0.0115), AUR, rot=(0, 0.785, 0)))
	uneste(piese, "Tac")
	exporta(os.path.join(cale, "tac_biliard.glb"))


# Culorile bilelor (1–7 pline, 9–15 cu dungă, 8 neagră, 0 albă), din paletă.
CULORI_BILE = {1: AUR, 2: PETROL, 3: ROSU, 4: MOV, 5: LEMN_DESCHIS, 6: POSTAV, 7: LEMN}


def bile(cale):
	"""Cele 16 bile (`Bila0` albă … `Bila15`), fiecare cu originea în centru, toate în origine (jocul le mută). Plinele
	au un cerc alb mic (cu numărul, la rezoluția asta doar o pată), cele cu dungă au calotele albe: așa se vede cum se
	rostogolesc."""
	curata()
	R = RAZA_BILA

	def inel_sfera(z):
		return math.sqrt(max(0.0, R * R - z * z))

	for n in range(16):
		if n == 0:
			ob = sfera("Bila0", R, (0, 0, 0), ALB, segmente=12, inele=8)
			uneste([ob], "Bila0")
			continue
		if n == 8 or n <= 7:
			cul = NEGRU if n == 8 else CULORI_BILE[n]
			piese = [sfera("Bila", R, (0, 0, 0), cul, segmente=12, inele=8),
				cilindru("Cerc bila", R * 0.42, R * 0.42, 0.004, (0, 0, R - 0.0005), ALB, laturi=10)]
		else:
			cul = CULORI_BILE[n - 8]
			zb = R * 0.5
			zs = [-R, -R * 0.92, -R * 0.75, -zb, zb, R * 0.75, R * 0.92, R]
			piese = [
				trunchi("Dunga", [((0, 0, z), inel_sfera(z), inel_sfera(z)) for z in (-zb, -zb * 0.5, 0.0, zb * 0.5, zb)], cul, laturi=12, capete=False),
				trunchi("Calota", [((0, 0, z), inel_sfera(z), inel_sfera(z)) for z in zs[:4]], ALB, laturi=12),
				trunchi("Calota", [((0, 0, z), inel_sfera(z), inel_sfera(z)) for z in zs[4:]], ALB, laturi=12),
			]
		uneste(piese, "Bila%d" % n)
	exporta(os.path.join(cale, "bile_biliard.glb"))


def _pahar(raza_jos, raza_sus, h, gros=0.004, fund=0.012):
	"""Un pahar de sticlă (pereții cu grosime, fundul gros), ca piese `Geam`."""
	pereti = trunchi("Geam pahar", [((0, 0, fund), raza_jos, raza_jos), ((0, 0, h), raza_sus, raza_sus)], GRI_ALBASTRU, laturi=12, capete=False)
	interior = trunchi("Geam pahar int", [((0, 0, h - 0.001), raza_sus - gros, raza_sus - gros), ((0, 0, fund), raza_jos - gros, raza_jos - gros)],
		GRI_ALBASTRU, laturi=12, capete=False)
	fundul = cilindru("Geam fund", raza_jos, raza_jos, fund, (0, 0, fund / 2), GRI_ALBASTRU, laturi=12)
	buza = _tor("Geam buza", raza_sus - gros / 2, gros / 2, (0, 0, h), GRI_ALBASTRU, segmente=12)
	return [pereti, interior, fundul, buza]


def _lichid(raza_jos, raza_sus, h_pahar, nivel, cul, fund=0.012, gros=0.004):
	"""Băutura din pahar: originea pe fundul paharului, ca jocul s-o umple / golească scalând pe înălțime."""
	r_niv = raza_jos + (raza_sus - raza_jos) * (nivel / h_pahar)
	return trunchi("Lichid", [((0, 0, fund), raza_jos - gros - 0.0005, raza_jos - gros - 0.0005), ((0, 0, nivel), r_niv - gros - 0.0005,
		r_niv - gros - 0.0005)], cul, laturi=12)


def pahare(cale):
	"""Băuturile de la bar: sticla de bere (cu `Capac` separat, îl scoate barmanul), paharul de whiskey cu gheață, shot-ul
	de vodcă, paharul de rom. În fiecare: `Lichid` (originea pe fundul paharului, se scalează pe Z când bei) și sticla
	(`Geam*`, transparentă). Originea = baza."""
	# --- berea: sticla maro cu eticheta, gâtul, capacul
	curata()
	piese = [
		trunchi("Sticla bere", [((0, 0, 0.0), 0.0, 0.0), ((0, 0, 0.002), 0.03, 0.03), ((0, 0, 0.135), 0.031, 0.031), ((0, 0, 0.165), 0.022, 0.022),
			((0, 0, 0.21), 0.0125, 0.0125), ((0, 0, 0.228), 0.0135, 0.0135), ((0, 0, 0.23), 0.0, 0.0)], LEMN, laturi=12),
		trunchi("Eticheta bere", [((0, 0, 0.05), 0.0318, 0.0318), ((0, 0, 0.11), 0.0318, 0.0318)], AUR, laturi=12, capete=False),
		trunchi("Eticheta gat", [((0, 0, 0.18), 0.0185, 0.0185), ((0, 0, 0.198), 0.0158, 0.0158)], ROSU, laturi=12, capete=False),
		cub("Sigla bere", (0.03, 0.006, 0.025), (0, -0.032, 0.08), ROSU),
	]
	uneste(piese, "Bere")
	uneste([cilindru("Capac", 0.0145, 0.0145, 0.008, (0, 0, 0.233), AUR, laturi=10)], "Capac", (0, 0, 0.229))
	exporta(os.path.join(cale, "bere_sticla.glb"))
	# --- whiskey: pahar jos și lat, gheață, lichidul chihlimbar
	for nume, rj, rs, h, niv, cul, gheata in (("pahar_whiskey", 0.038, 0.042, 0.09, 0.045, LEMN_DESCHIS, 2),
			("pahar_vodka", 0.02, 0.025, 0.065, 0.045, GRI_ALBASTRU, 0), ("pahar_rom", 0.036, 0.04, 0.1, 0.05, LEMN, 1)):
		curata()
		uneste(_pahar(rj, rs, h), "Geam")
		uneste([_lichid(rj, rs, h, niv, cul)], "Lichid", (0, 0, 0.012))
		if gheata:
			cuburi = [cub("Gheata", (0.024, 0.024, 0.022), (0.009 * (k * 2 - 1), 0.006 * (1 - 2 * k), niv - 0.004 + k * 0.006), ALB,
				rot=(0.3 * k, 0.5, 0.4 * k)) for k in range(gheata)]
			uneste(cuburi, "Gheata")
		exporta(os.path.join(cale, nume + ".glb"))


def sticle_turnat(cale):
	"""Sticlele din care toarnă barmanul (stau pe dulapul din spatele barului): whiskey (pătrată, chihlimbar), vodcă
	(înaltă, limpede, eticheta roșie), rom (rotundă, închisă). Originea = baza."""
	for nume, fel, cul, eticheta in (("sticla_whiskey", "patrata", LEMN_DESCHIS, NEGRU), ("sticla_vodka", "inalta", GRI_ALBASTRU, ROSU),
			("sticla_rom", "rotunda", LEMN_INCHIS, AUR)):
		curata()
		piese = []
		_sticla(piese, 0, 0, 0, fel, cul, random.Random(3), eticheta=eticheta)
		uneste(piese, "Sticla")
		exporta(os.path.join(cale, nume + ".glb"))


# ---------------------------------------------------------------------------------------------------------------
# Oamenii (prin casino_oameni.om, în picioare)
# ---------------------------------------------------------------------------------------------------------------

BARMAN = {
	# barmanul: masiv, ras în cap, barbă deasă, tricou negru cu mânecă scurtă, șorț; palmele pe blat (tatuajele scoase:
	# la 480x270 erau pete verzi pe brațe, owner 10.10)
	"piele": p("a56850"), "piele_umbra": p("904a40"), "haina": p("262d2f"), "haina_umbra": p("2a3c3d"), "camasa": p("262d2f"),
	"maneca": p("262d2f"), "stil_haina": "tricou", "scris_tricou": p("a18463"), "maneca_scurta": True,
	"sort": p("48313b"), "pantaloni": p("2a3c3d"), "pantofi": p("262d2f"),
	"in_picioare": True, "sezut": 0.86, "masa": BZ - FL,
	"par": p("48313b"), "stil_par": "ras", "barba": p("48313b"), "mustata": p("48313b"), "incruntat": 0.35,
	"gros_brat": 1.25, "burta": 0.55, "nas": 1.15, "riduri": True, "cercei": p("7e8d87"),
	"poza_D": ((-0.27, -0.1, 1.2), (-0.15, -0.34, BZ - FL + 0.025)),
	"poza_S": ((0.27, -0.1, 1.2), (0.15, -0.34, BZ - FL + 0.025)),
}

JUCATOR_DARTS = {
	# „Big Mike”: camionagiu cu șapcă de baseball, cămașă în carouri peste un tricou, burtă de bere, barbă
	"piele": p("a56850"), "piele_umbra": p("904a40"), "haina": p("7b383a"), "haina_umbra": p("5e363e"), "camasa": p("7b383a"),
	"carouri": p("262d2f"), "stil_haina": "vesta", "pantaloni": p("295555"), "pantofi": p("48313b"), "curea": p("48313b"),
	"in_picioare": True, "sezut": 0.86,
	"par": p("48313b"), "stil_par": "scurt", "palarie": "baseball", "culoare_palarie": p("30716f"), "culoare_palarie_umbra": p("295555"),
	"panou_sapca": p("83b3b0"), "sigla_sapca": p("7b383a"), "barba": p("5e363e"), "gros_brat": 1.15, "burta": 1.0, "gras": 0.4,
	"nas": 1.1, "nas_rosu": True,
	# mâna dreaptă ține berea la piept, stânga atârnă
	"poza_D": ((-0.24, -0.05, 1.12), (-0.12, -0.3, 1.2)),
	"poza_S": ((0.25, 0.0, 1.1), (0.24, -0.14, 0.88)),
}

JUCATOR_BILIARD = {
	# „Fast Eddie”: slab, vestă neagră peste cămașă albă, pălărie fedora, mustață subțire, ochelari de soare în buzunar
	"piele": p("a56850"), "piele_umbra": p("904a40"), "haina": p("262d2f"), "haina_umbra": p("2a3c3d"), "camasa": p("83b3b0"),
	"carouri": p("83b3b0"), "stil_haina": "vesta", "maneca": p("83b3b0"), "pantaloni": p("262d2f"), "pantofi": p("262d2f"),
	"in_picioare": True, "sezut": 0.86, "lant": p("a18463"),
	"par": p("262d2f"), "stil_par": "spate", "palarie": "fedora", "culoare_palarie": p("262d2f"), "culoare_palarie_umbra": p("2a3c3d"),
	"banda": p("7b383a"), "mustata": p("262d2f"), "slab": 0.7, "gros_brat": 0.9, "incruntat": 0.2, "scobitoare": True,
	"poza_D": ((-0.24, -0.05, 1.12), (-0.2, -0.28, 0.98)),
	"poza_S": ((0.25, 0.0, 1.1), (0.24, -0.14, 0.88)),
}


def katana(cale):
	"""Katana din parcare (owner, 10.10): lama ușor curbată (crește spre muchie: tăișul în jos, -Z), vârful „kissaki”
	ridicat spre muchie, inelul de alamă (habaki), garda ovală (tsuba) neagră cu margine de aur, mânerul (tsuka) cu
	împletitura neagră în romburi peste pielea albă de rechin, ornamentele de aur (menuki) și capacul (kashira).
	Originea = mijlocul mânerului; lama spre +Y (în Godot spre -Z, ca restul armelor). `Lama` e piesă separată
	(strălucește puțin în joc), `Katana` restul."""
	curata()
	from coven import _parinte

	def curba(y):  # cât urcă muchia lamei (sori), de la gardă la vârf
		u = max(0.0, (y - 0.17) / 0.72)
		return 0.028 * u * u

	# lama: inele turtite (grosime pe X, lățime pe Z) de-a lungul curbei; lățimea scade spre vârf, apoi kissaki
	inele = []
	for k in range(9):
		y = 0.17 + k * 0.08
		u = k / 8.0
		inele.append(((0, y, curba(y) + 0.0005 * k), 0.0036 - 0.0012 * u, 0.0158 - 0.0028 * u))
	inele.append(((0, 0.86, curba(0.86) + 0.004), 0.0022, 0.0105))
	inele.append(((0, 0.885, curba(0.885) + 0.008), 0.0016, 0.0055))
	inele.append(((0, 0.9, curba(0.9) + 0.011), 0.0, 0.0))
	lama = trunchi("Lama", inele, CROM, laturi=6, ref=(1, 0, 0))
	# linia de călire (hamon), deschisă, pe ambele fețe, aproape de tăiș
	hamon = []
	for s in (-1, 1):
		puncte = []
		for k in range(8):
			y = 0.2 + k * 0.08
			puncte.append(((s * (0.0036 - 0.0012 * k / 8.0) * 0.72, y, curba(y) - 0.0085 + 0.0005 * k), 0.0006, 0.0028))
		hamon.append(trunchi("Hamon", puncte, ALB, laturi=4, ref=(1, 0, 0)))
	ob_lama = uneste([lama] + hamon, "Lama")

	piese = [
		# habaki (inelul de alamă de la baza lamei) și seppa (șaibele)
		cub("Habaki", (0.011, 0.032, 0.036), (0, 0.152, 0.0), AUR),
		cilindru("Seppa", 0.026, 0.026, 0.004, (0, 0.134, 0.0), AUR, laturi=10, rot=(-1.5708, 0, 0), scara=(0.8, 1.0, 1.0)),
		# tsuba: garda ovală, neagră, cu marginea de aur
		cilindru("Tsuba", 0.038, 0.038, 0.007, (0, 0.128, 0.0), NEGRU, laturi=14, rot=(-1.5708, 0, 0), scara=(0.75, 1.0, 1.0)),
		cilindru("Margine tsuba", 0.04, 0.04, 0.0035, (0, 0.128, 0.0), AUR, laturi=14, rot=(-1.5708, 0, 0), scara=(0.75, 1.0, 1.0)),
		cilindru("Seppa", 0.026, 0.026, 0.004, (0, 0.122, 0.0), AUR, laturi=10, rot=(-1.5708, 0, 0), scara=(0.8, 1.0, 1.0)),
		# fuchi (gulerul mânerului) și kashira (capacul)
		trunchi("Fuchi", [((0, 0.098, 0), 0.0135, 0.0175), ((0, 0.118, 0), 0.0145, 0.0185)], METAL_INCHIS, laturi=8, ref=(1, 0, 0)),
		trunchi("Kashira", [((0, -0.152, 0), 0.0135, 0.0175), ((0, -0.135, 0), 0.0135, 0.0175)], METAL_INCHIS, laturi=8,
			ref=(1, 0, 0)),
		# tsuka: pielea albă de rechin (samegawa) dedesubt
		trunchi("Tsuka", [((0, -0.136, 0), 0.0125, 0.0165), ((0, -0.02, 0), 0.0135, 0.0175), ((0, 0.098, 0), 0.0125, 0.0165)],
			ALB, laturi=8, ref=(1, 0, 0)),
	]
	# împletitura (ito): romburi negre pe fiecare parte, care lasă să se vadă pielea albă printre ele
	for s in (-1, 1):
		for i in range(7):
			y = -0.112 + i * 0.032
			piese.append(cub("Ito", (0.003, 0.022, 0.022), (s * 0.0128, y, 0.0), NEGRU, rot=(0.785, 0, 0)))
	for z in (-1, 1):
		for i in range(7):
			y = -0.112 + i * 0.032
			piese.append(cub("Ito", (0.016, 0.012, 0.0028), (0, y, z * 0.0168), NEGRU))
	# menuki (ornamentele de aur sub împletitură)
	for s in (-1, 1):
		piese.append(sfera("Menuki", 0.007, (s * 0.0145, -0.01 * s, 0.0), AUR, scara=(0.5, 1.8, 0.9), segmente=6, inele=4))
	ob = uneste(piese, "Katana")
	_parinte(ob_lama, ob)
	exporta(os.path.join(cale, "katana.glb"))


def oameni(cale):
	casino_oameni.om(cale, "barman_urban", BARMAN, 91)
	casino_oameni.om(cale, "jucator_darts", JUCATOR_DARTS, 92)
	casino_oameni.om(cale, "jucator_biliard", JUCATOR_BILIARD, 93)


def statie(cale):
	import autobuz
	autobuz.statie(cale, "VOMIT STREET", "statie_gavana.glb")


def toate(cale):
	cladire(cale)
	strada(cale)
	decor(cale)
	scaun_bar_urban(cale)
	usa_bar(cale)
	tabla_darts(cale)
	sageti(cale)
	tac(cale)
	bile(cale)
	pahare(cale)
	sticle_turnat(cale)
	katana(cale)
	oameni(cale)
	statie(cale)


if __name__ == "__main__":
	cale_modele = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")
	if "--" in sys.argv:
		for nume in sys.argv[sys.argv.index("--") + 1:]:
			globals()[nume](cale_modele)
	else:
		toate(cale_modele)
