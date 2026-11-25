# Sala de forță „IRON PUMP GYM” (owner 25.11): clădirea mică (ca Gun Store-ul: un parter cu banner pe parapet), strada
# din fața ei, decorul de dinăuntru (recepția cu turnichetul, oglinzile, rastelul cu gantere, cele 3 bănci, cușca de
# genuflexiuni), barele și ganterele care se mișcă, pumnii tăi la persoana întâi (pumn_sala.glb) și cei trei oameni: fata de la recepție,
# slăbănogul cu ganterele de 1 kg și Gym Bro (Mr. Olympia, culcat pe bancă, cu 500 kg pe bară).
#   blender --background --factory-startup --python tools/blender/sala.py            (toate)
#   blender --background --factory-startup --python tools/blender/sala.py -- decor   (doar unele)
# Axe Blender: Z în sus, fața clădirii spre -Y (în Godot +Z, spre stradă); înăuntru e spre +Y (Godot -Z).
# Clădirea, strada și decorul au originea în mijlocul fațadei, la nivelul străzii (în Godot toate în același punct).
import math
import os
import random
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, uneste, exporta, trunchi, desparte_fete  # noqa: E402
from lexy import perete  # noqa: E402
from casino import _text, _text_o_fata, _tor, _cutie_coliziune  # noqa: E402
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
BETON = p("70706e")
TENCUIALA = p("7e8d87")
ALBASTRU = p("2a3c3d")
TEAL = p("30716f")
VERDE = p("5b6d4e")
VERDE_INCHIS = p("445d46")
ROZ = p("a56850")       # „roz”-ul ganterelor de 1 kg (cel mai apropiat din paletă)
GALBEN = p("a18463")
CAUCIUC = p("2a3c3d")   # podeaua de cauciuc
CAUCIUC_2 = p("262d2f")
OGLINDA = p("83b3b0")
OGLINDA_DUNGA = p("61a19f")
VIOLET = p("778c96")

# --- clădirea
W = 5.0      # jumătate din lățimea dinăuntru
G = 0.25     # grosimea pereților
FL = 0.15    # podeaua (= trotuarul)
HC = 3.2     # tavanul
TOP = 3.5    # acoperișul
D = 10.0     # fața dinăuntru a peretelui din spate
USA = (1.6, 2.7, FL, FL + 2.3)          # ca la Gun Store (același model de ușă, în același loc)
VITRINE = [(-4.3, -2.5, 0.85, 2.5), (-1.9, -0.1, 0.85, 2.5), (3.3, 4.5, 0.85, 2.5)]
# recepția: peretele scund dintre hol și sală la y = PY, cu golul turnichetului între TX0 și TX1 (în dreptul ușii)
PY = 3.2
TX0, TX1 = 1.5, 2.8
PH = 1.15            # cât de înalt e peretele scund
# biroul recepției: de la peretele din stânga până la BX1, fața spre hol la BY0, spatele la BY1, blatul la BZ
BX1, BY0, BY1, BZ = 1.0, 1.7, 2.3, FL + 1.0
# băncile: (x, y-ul capului) — capul spre peretele din spate, picioarele spre hol; pernele lungi de 1,2 m pe Y
BANCI = [(1.3, 9.35), (3.75, 9.35)]
BANCA_BRO = (3.3, 5.6)
BANCA_Z = FL + 0.45  # fața pernei
CUSCA = (-2.2, 9.1)   # cușca de genuflexiuni (mijlocul ei)


# ---------------------------------------------------------------------------------------------------------------
# Clădirea (cu bannerul)
# ---------------------------------------------------------------------------------------------------------------

def cladire(cale):
	"""Sala: fațada de tencuială gri cu soclu de cărămidă, trei vitrine („OPEN 24/7”, „NO EXCUSES”), ușa (ca la Gun
	Store), bannerul „IRON PUMP GYM” cu o halteră; înăuntru: holul cu linoleum, sala cu podea de cauciuc, pereții
	vopsiți (dungă teal), tavanul cu neoane. Piese: `Cladire`, `Lumini`, `Geamuri`, `Coliziune`."""
	curata()
	piese, lumini, geamuri, col = [], [], [], []

	def strange():
		piese[:] = [uneste(piese, "Cladire")]

	# --- podeaua: holul cu linoleum în carouri, sala cu plăci de cauciuc
	piese.append(cub("Sapa", (2 * W + 2 * G - 0.04, D + G - 0.04, 0.2), (0, (D + G) / 2, FL - 0.12), METAL_INCHIS))
	_cutie_coliziune(col, (2 * W + 2 * G, D + G, 0.3), (0, (D + G) / 2, FL - 0.15))
	pas = 0.5
	for i in range(int(2 * W / pas)):
		for j in range(int((PY - G) / pas) + 1):
			y0 = G + j * pas
			y1 = min(y0 + pas, PY)
			if y1 <= y0:
				continue
			piese.append(cub("Linoleum", (pas, y1 - y0, 0.02), (-W + (i + 0.5) * pas, (y0 + y1) / 2, FL - 0.01),
				ALB if (i + j) % 2 else CROM))
	pas = 1.0
	for i in range(int(2 * W / pas)):
		for j in range(int((D - PY) / pas) + 1):
			y0 = PY + j * pas
			y1 = min(y0 + pas, D)
			if y1 <= y0:
				continue
			piese.append(cub("Cauciuc", (pas, y1 - y0, 0.02), (-W + (i + 0.5) * pas, (y0 + y1) / 2, FL - 0.01),
				CAUCIUC if (i + j) % 2 else CAUCIUC_2))
	piese.append(cub("Prag", (USA[1] - USA[0], G, 0.02), ((USA[0] + USA[1]) / 2, G / 2, FL - 0.01), METAL))
	strange()

	# --- pereții: fațada (tencuială peste un soclu de cărămidă), înăuntru vopsit cu o dungă teal la mijloc
	g2 = G / 2
	goluri = [(USA[0], USA[1], USA[2] - 0.2, USA[3])] + [tuple(v) for v in VITRINE]
	perete(piese, "Fatada", "x", -W - G, W + G, 0.0, g2, 0.0, TOP, TENCUIALA, goluri)
	perete(piese, "Fatada int", "x", -W, W, g2, G, FL, HC, ALB, goluri)
	for a, b in [(-W - G, USA[0]), (USA[1], W + G)]:
		_cutie_coliziune(col, (b - a, G, TOP), ((a + b) / 2, G / 2, TOP / 2))
	_cutie_coliziune(col, (USA[1] - USA[0], G, TOP - USA[3]), ((USA[0] + USA[1]) / 2, G / 2, (TOP + USA[3]) / 2))
	# soclul de cărămidă de sub vitrine (nu și prin dreptul ușii), cu rosturi
	for sa, sb in ((-W - G, USA[0]), (USA[1], W + G)):
		piese.append(cub("Soclu", (sb - sa, 0.03, 0.8), ((sa + sb) / 2, -0.015, 0.4), ROSU))
		z = 0.1
		while z < 0.8:
			piese.append(cub("Rost", (sb - sa, 0.012, 0.012), ((sa + sb) / 2, -0.034, z), LEMN))
			z += 0.1
	for s in (-1, 1):
		piese.append(cub("Perete lateral", (g2, D + G - g2, TOP), (s * (W + G - g2 / 2), (D + G + g2) / 2, TOP / 2), TENCUIALA))
		piese.append(cub("Perete int", (g2, D - G, HC - FL), (s * (W + g2 / 2), (G + D) / 2, (FL + HC) / 2), ALB))
		_cutie_coliziune(col, (G, D + G, TOP), (s * (W + G / 2), (D + G) / 2, TOP / 2))
		# dunga teal și plinta neagră
		piese.append(cub("Dunga", (0.02, D - G, 0.25), (s * (W - 0.01), (G + D) / 2, FL + 1.25), TEAL))
		piese.append(cub("Plinta", (0.03, D - G, 0.12), (s * (W - 0.015), (G + D) / 2, FL + 0.06), NEGRU))
	piese.append(cub("Spate", (2 * W + 2 * G, g2, TOP), (0, D + G - g2 / 2, TOP / 2), TENCUIALA))
	piese.append(cub("Spate int", (2 * W, g2, HC - FL), (0, D + g2 / 2, (FL + HC) / 2), ALB))
	piese.append(cub("Dunga", (2 * W, 0.02, 0.25), (0, D - 0.01, FL + 1.25), TEAL))
	piese.append(cub("Plinta", (2 * W, 0.03, 0.12), (0, D - 0.015, FL + 0.06), NEGRU))
	_cutie_coliziune(col, (2 * W + 2 * G, G, TOP), (0, D + G / 2, TOP / 2))
	for a, b in ((-W, VITRINE[0][0]), (VITRINE[0][1], VITRINE[1][0]), (VITRINE[1][1], USA[0]), (USA[1], VITRINE[2][0]), (VITRINE[2][1], W)):
		piese.append(cub("Plinta", (b - a, 0.03, 0.12), ((a + b) / 2, G + 0.015, FL + 0.06), NEGRU))
	strange()

	# --- tavanul: plăci, neoane în trei rânduri (holul are două)
	piese.append(cub("Tavan", (2 * W, D - G, 0.1), (0, (G + D) / 2, HC + 0.05), ALB))
	for x in [-W + 1.0 * i for i in range(1, 10)]:
		piese.append(cub("Profil", (0.025, D - G, 0.012), (x, (G + D) / 2, HC - 0.006), METAL))
	for y in [G + 1.0 * j for j in range(1, 10)]:
		piese.append(cub("Profil", (2 * W, 0.025, 0.01), (0, y, HC - 0.016), METAL))
	for x, y in NEOANE:
		piese.append(cub("Corp neon", (0.3, 1.25, 0.06), (x, y, HC - 0.05), METAL))
		for dx in (-0.07, 0.07):
			lumini.append(cub("Neon", (0.045, 1.18, 0.03), (x + dx, y, HC - 0.095), ALB))
	strange()

	# --- tocul ușii, vitrinele (geamul, rama, autocolantele)
	a, b, za, zb = USA
	for xx in (a + 0.03, b - 0.03):
		piese.append(cub("Toc", (0.06, G + 0.02, zb - za), (xx, G / 2, (za + zb) / 2), METAL_INCHIS))
	piese.append(cub("Toc", (b - a, G + 0.02, 0.06), ((a + b) / 2, G / 2, zb - 0.03), METAL_INCHIS))
	for va, vb, vz0, vz1 in VITRINE:
		geamuri.append(cub("Geam", (vb - va, 0.012, vz1 - vz0), ((va + vb) / 2, g2, (vz0 + vz1) / 2), GEAM))
		for xx in (va, vb):
			piese.append(cub("Rama vitrina", (0.06, G + 0.04, vz1 - vz0), (xx, G / 2, (vz0 + vz1) / 2), NEGRU))
		for zz in (vz0, vz1):
			piese.append(cub("Rama vitrina", (vb - va, G + 0.04, 0.06), ((va + vb) / 2, G / 2, zz), NEGRU))
		piese.append(cub("Pervaz", (vb - va, 0.3, 0.04), ((va + vb) / 2, G + 0.15, vz0 - 0.02), ALB))
	for continut, xx, zz, marime, cul in (("OPEN 24/7", -3.4, 2.15, 0.16, AUR), ("NO EXCUSES", -1.0, 2.15, 0.15, ALB),
			("FIRST DAY\n$5", 3.9, 1.9, 0.12, AUR)):
		piese.append(_text_o_fata("Autocolant", continut, (xx, g2 - 0.009, zz), marime, cul))
		piese.append(_text_o_fata("Autocolant", continut, (xx, g2 + 0.009, zz), marime, cul, rot=(1.5708, 0, 3.14159)))
	piese.append(cub("Aplica usa", (0.3, 0.16, 0.08), ((a + b) / 2, -0.08, zb + 0.25), NEGRU))
	lumini.append(cub("Bec usa", (0.2, 0.1, 0.03), ((a + b) / 2, -0.08, zb + 0.2), AUR))
	strange()

	# --- parapetul cu bannerul
	PZ0, PZ1 = TOP, TOP + 1.3
	piese.append(cub("Parapet", (2 * W + 2 * G, G, PZ1 - PZ0), (0, G / 2, (PZ0 + PZ1) / 2), TENCUIALA))
	piese.append(cub("Copertina parapet", (2 * W + 2 * G + 0.1, G + 0.1, 0.06), (0, G / 2, PZ1 + 0.03), METAL))
	piese.append(cub("Acoperis", (2 * W + 2 * G - 0.04, D + G - 0.04, 0.25), (0, (D + G) / 2, TOP - 0.135), METAL_INCHIS))
	_cutie_coliziune(col, (2 * W + 2 * G, D + G, 0.3), (0, (D + G) / 2, TOP - 0.15))
	banner(piese, lumini, PZ0 + 0.1, PZ1 - 0.12)
	strange()

	desparte_fete(fixe=("Fatada", "Fatada int", "Perete lateral", "Perete int", "Spate", "Spate int", "Sapa", "Tavan",
		"Parapet", "Acoperis", "Banner", "Linoleum", "Cauciuc", "Soclu"))
	uneste(piese, "Cladire")
	uneste(lumini, "Lumini")
	uneste(geamuri, "Geamuri")
	uneste(col, "Coliziune")
	exporta(os.path.join(cale, "sala_cladire.glb"))


# neoanele (x, y): aceleași locuri au și luminile din sala.tscn
NEOANE = [(-2.5, 1.6), (2.5, 1.6), (-3.0, 4.8), (0.0, 4.8), (3.0, 4.8), (-3.0, 7.8), (0.0, 7.8), (3.0, 7.8)]


def _haltera(piese, x, z, lung, raza, cul, y):
	"""Desenul unei haltere din profil (față spre -Y): bara și câte două discuri la capete."""
	piese.append(cub("Bara desen", (lung, 0.01, raza * 0.25), (x, y, z), CROM))
	for s in (-1, 1):
		piese.append(cub("Disc desen", (raza * 0.35, 0.012, raza * 2.0), (x + s * (lung / 2 - raza * 0.5), y - 0.004, z), cul))
		piese.append(cub("Disc desen", (raza * 0.3, 0.012, raza * 1.5), (x + s * (lung / 2 - raza * 0.95), y - 0.004, z), cul))
		piese.append(cub("Manson desen", (raza * 0.25, 0.012, raza * 0.5), (x + s * (lung / 2 + raza * 0.05), y - 0.006, z), CROM))


def banner(piese, lumini, z0, z1):
	"""Bannerul de pe parapet (fața spre -Y): placa neagră cu tiv galben, „IRON PUMP” mare (cu umbră teal), „GYM” sub el,
	câte o halteră desenată în stânga și în dreapta, „EST. 1998  *  NO PAIN NO GAIN” dedesubt."""
	bw = 2 * W + 0.1
	zm = (z0 + z1) / 2
	piese.append(cub("Banner", (bw, 0.03, z1 - z0), (0, -0.03, zm), NEGRU))
	for zz in (z0 + 0.02, z1 - 0.02):
		piese.append(cub("Tiv banner", (bw + 0.01, 0.04, 0.05), (0, -0.04, zz), GALBEN))
	for xx in (-bw / 2 + 0.02, bw / 2 - 0.02):
		piese.append(cub("Tiv banner", (0.05, 0.04, z1 - z0 + 0.01), (xx, -0.04, zm), GALBEN))
	for sx in (-1, 1):
		for zz in (z0 + 0.12, z1 - 0.12):
			piese.append(cilindru("Surub", 0.02, 0.02, 0.012, (sx * (bw / 2 - 0.12), -0.064, zz), CROM, laturi=6, rot=(1.5708, 0, 0)))
	y = -0.07
	piese.append(_text("Umbra iron", "IRON PUMP", (0.035, y + 0.004, zm + 0.16 - 0.035), 0.56, TEAL))
	lumini.append(_text("Litere iron", "IRON PUMP", (0.0, y - 0.01, zm + 0.16), 0.56, ALB))
	piese.append(_text("Scris gym", "G Y M", (0.0, y - 0.01, zm - 0.24), 0.2, GALBEN))
	piese.append(_text("Scris banner", "EST. 1998  *  NO PAIN NO GAIN", (0.0, y - 0.01, zm - 0.45), 0.09, CROM))
	for sx in (-1, 1):
		_haltera(piese, sx * 3.9, zm + 0.05, 1.5, 0.22, ROSU, y)


# ---------------------------------------------------------------------------------------------------------------
# Strada
# ---------------------------------------------------------------------------------------------------------------

def strada(cale):
	"""Strada din fața sălii (ca la Gun Store: trotuar, bordură, asfalt, blocuri vizavi, iarbă sub tot); în stânga un
	salon de unghii („NAILS”, închis cu oblon pe jumătate), în dreapta o parcare mică cu două mașini vechi și un stâlp
	de iluminat, apoi o casă de schimb valutar („CHECKS CASHED”). Piese: `Strada`, `Lumini`, `Coliziune`."""
	curata()
	r = random.Random(29)
	piese, lumini, col = [], [], []
	L = 120.0
	piese.append(cub("Teren", (L, 110.0, 0.1), (0, -15.0, -0.11), p("5b6d4e")))
	piese.append(cub("Trotuar", (L, 3.4, FL), (0, -1.7, FL / 2), BETON))
	for xx in range(-60, 61, 1):
		piese.append(cub("Rost", (0.012, 3.4, 0.02), (xx * 1.0, -1.7, FL), METAL_INCHIS))
	piese.append(cub("Bordura", (L, 0.2, FL + 0.02), (0, -3.5, (FL + 0.02) / 2), TENCUIALA))
	piese.append(cub("Asfalt", (L, 7.4, 0.05), (0, -7.3, -0.025), NEGRU))
	for xx in range(-58, 60, 4):
		piese.append(cub("Marcaj", (2.0, 0.12, 0.02), (xx, -7.3, 0.0), AUR))
	piese.append(cub("Bordura", (L, 0.2, FL + 0.02), (0, -11.1, (FL + 0.02) / 2), TENCUIALA))
	piese.append(cub("Trotuar", (L, 3.0, FL), (0, -12.7, FL / 2), BETON))
	_cutie_coliziune(col, (L, 3.4, FL), (0, -1.7, FL / 2))
	_cutie_coliziune(col, (L, 0.2, FL + 0.02), (0, -3.5, (FL + 0.02) / 2))
	_cutie_coliziune(col, (L, 7.4, 0.05), (0, -7.3, -0.025))
	_cutie_coliziune(col, (L, 3.2, FL), (0, -12.6, FL / 2))
	piese += [
		cilindru("Hidrant", 0.11, 0.11, 0.55, (-6.4, -2.9, FL + 0.275), ROSU, laturi=8),
		sfera("Hidrant cap", 0.11, (-6.4, -2.9, FL + 0.55), ROSU, scara=(1, 1, 0.7), segmente=8, inele=4),
	]
	# --- stânga: salonul de unghii, cu oblonul tras pe jumătate și firma
	vx0, vx1 = -18.0, -W - G - 0.01
	piese.append(cub("Vecin stanga", (vx1 - vx0, 12.0, 4.2), ((vx0 + vx1) / 2, 6.0, 2.1), VIOLET))
	_cutie_coliziune(col, (vx1 - vx0, 12.0, 4.2), ((vx0 + vx1) / 2, 6.0, 2.1))
	piese.append(cub("Soclu vecin", (vx1 - vx0, 0.03, 0.5), ((vx0 + vx1) / 2, -0.015, 0.25), BETON))
	for xx in (-15.5, -11.5):
		piese.append(cub("Vitrina nails", (3.0, 0.02, 1.8), (xx, -0.012, 1.5), GEAM))
		piese.append(cub("Oblon nails", (3.2, 0.04, 0.9), (xx, -0.03, 2.0), METAL))
		for k in range(8):
			piese.append(cub("Lamela", (3.2, 0.012, 0.01), (xx, -0.052, 1.6 + k * 0.11), METAL_INCHIS))
	piese.append(cub("Usa nails", (1.0, 0.04, 2.2), (-8.3, -0.02, 1.1), METAL_INCHIS))
	piese.append(cub("Firma nails", (5.0, 0.14, 0.7), (-13.5, -0.07, 3.45), ALB))
	lumini.append(_text("Litere nails", "NAILS & SPA", (-13.5, -0.15, 3.45), 0.45, ROSU))
	# --- dreapta: parcarea (asfalt crăpat, liniile albe), două mașini vechi, stâlpul de iluminat; apoi „CHECKS CASHED”
	mx0, mx1 = W + G + 0.01, 14.0
	piese.append(cub("Parcare", (mx1 - mx0, 12.0, 0.04), ((mx0 + mx1) / 2, 6.0, FL - 0.02), METAL_INCHIS))
	_cutie_coliziune(col, (mx1 - mx0, 12.0, 0.2), ((mx0 + mx1) / 2, 6.0, FL - 0.1))
	for xx in (6.5, 9.0, 11.5, 13.9):
		piese.append(cub("Linie parcare", (0.08, 4.5, 0.01), (xx, 3.5, FL + 0.005), ALB))
	for k in range(9):  # crăpăturile
		x0, y0 = r.uniform(mx0 + 0.5, mx1 - 0.5), r.uniform(1.0, 11.0)
		u = r.uniform(0, math.pi)
		piese.append(cub("Crapatura", (r.uniform(0.6, 1.6), 0.03, 0.01), (x0, y0, FL + 0.003), NEGRU, rot=(0, 0, u)))
	for mx, my, cul in ((7.75, 3.8, ROSU), (12.7, 4.1, p("295555"))):
		piese.append(cub("Masina", (1.8, 4.2, 0.65), (mx, my, FL + 0.55), cul))
		piese.append(cub("Cabina", (1.6, 2.1, 0.55), (mx, my + 0.3, FL + 1.12), cul))
		piese.append(cub("Parbriz", (1.5, 0.02, 0.45), (mx, my - 0.76, FL + 1.12), GEAM, rot=(0.45, 0, 0)))
		piese.append(cub("Luneta", (1.5, 0.02, 0.4), (mx, my + 1.36, FL + 1.12), GEAM, rot=(-0.45, 0, 0)))
		for s in (-1, 1):
			piese.append(cub("Geam lateral", (0.02, 1.6, 0.36), (mx + s * 0.81, my + 0.3, FL + 1.14), GEAM))
		piese.append(cub("Bara masina", (1.85, 0.1, 0.16), (mx, my - 2.12, FL + 0.38), CROM))
		for dx, dy in ((-0.9, -1.3), (0.9, -1.3), (-0.9, 1.3), (0.9, 1.3)):
			piese.append(cilindru("Roata", 0.32, 0.32, 0.22, (mx + dx, my + dy, FL + 0.32), NEGRU, laturi=10, rot=(0, 1.5708, 0)))
		for s in (-1, 1):
			lumini.append(cub("Far", (0.3, 0.02, 0.12), (mx + s * 0.6, my - 2.11, FL + 0.66), AUR))
		_cutie_coliziune(col, (1.8, 4.2, 1.4), (mx, my, FL + 0.7))
	piese += [
		cilindru("Stalp", 0.07, 0.09, 6.5, (10.3, 0.4, FL + 3.25), METAL, laturi=8),
		os_intre("Brat stalp", (10.3, 0.4, FL + 6.3), (10.3, -1.1, FL + 6.5), 0.04, METAL, laturi=6),
		cub("Lampa stalp", (0.25, 0.5, 0.1), (10.3, -1.2, FL + 6.45), METAL_INCHIS),
	]
	_cutie_coliziune(col, (0.2, 0.2, 6.5), (10.3, 0.4, FL + 3.25))
	piese.append(cub("Bordura parcare", (mx1 - mx0, 0.2, 0.12), ((mx0 + mx1) / 2, 0.1, FL + 0.06), TENCUIALA))
	# casa de schimb: fațadă galbenă, vitrina cu gratii, firma cu litere roșii
	piese.append(cub("Check cashing", (12.0, 12.0, 4.4), (20.0, 6.0, 2.2), GALBEN))
	_cutie_coliziune(col, (12.0, 12.0, 4.4), (20.0, 6.0, 2.2))
	piese.append(cub("Vitrina checks", (4.0, 0.02, 1.6), (18.0, -0.012, 1.5), GEAM))
	xx = 16.1
	while xx < 20.0:
		piese.append(cub("Gratie", (0.03, 0.03, 1.7), (xx, -0.04, 1.5), NEGRU))
		xx += 0.2
	piese.append(cub("Firma checks", (5.0, 0.12, 0.75), (19.0, -0.06, 3.6), NEGRU))
	lumini.append(_text("Scris checks", "CHECKS CASHED", (19.0, -0.13, 3.6), 0.36, ROSU))
	lumini.append(_text("Scris checks", "PAYDAY LOANS", (18.0, -0.03, 2.55), 0.16, AUR))
	# --- vizavi: blocuri în ceață, cu alei, între ele parcări
	for k in range(5):
		bx = -42 + k * 20 + r.uniform(-2, 2)
		h = r.choice((9.0, 12.0, 14.5))
		piese.append(cub("Bloc vizavi", (16.0, 10.0, h), (bx, -20.0, h / 2), r.choice((BETON, METAL, TENCUIALA))))
		for fx in range(5):
			for fz in range(int(h / 3) - 1):
				aprins = r.random() < 0.15
				(lumini if aprins else piese).append(cub("Geam bloc", (1.2, 0.02, 1.2), (bx - 6 + fx * 3, -14.99, 2.5 + fz * 3),
					AUR if aprins else GEAM))
		piese.append(cub("Alee bloc", (2.0, 0.8, 0.04), (bx, -14.6, 0.0), BETON))
		piese.append(cub("Usa bloc", (1.4, 0.02, 1.8), (bx, -14.97, 0.9), METAL_INCHIS))
	for k in range(4):
		px = -32 + k * 20
		piese.append(cub("Parcare vizavi", (3.6, 10.8, 0.04), (px, -20.0, -0.04), NEGRU))
	uneste(piese, "Strada")
	uneste(lumini, "Lumini")
	uneste(col, "Coliziune")
	exporta(os.path.join(cale, "sala_strada.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Decorul de dinăuntru
# ---------------------------------------------------------------------------------------------------------------

def _gantera_statica(piese, x, y, z, raza, lat, cul):
	"""O ganteră hexagonală pe rastel (mânerul pe X)."""
	maner = lat * 1.3
	piese.append(cilindru("Maner gantera", 0.014, 0.014, maner, (x, y, z), CROM, laturi=6, rot=(0, 1.5708, 0)))
	for s in (-1, 1):
		piese.append(cilindru("Cap gantera", raza, raza, lat, (x + s * (maner / 2 + lat / 2), y, z), cul, laturi=6, rot=(0, 1.5708, 0)))


def _banca(piese, col, x, yc, cu_stalpi=True):
	"""O bancă plată de împins (perna pe Y, de la yc - 1,2 la yc), cu suporturile pentru bară la cap (y = yc + 0,15)."""
	y0, y1 = yc - 1.2, yc
	piese.append(cub("Perna banca", (0.3, y1 - y0, 0.09), (x, (y0 + y1) / 2, BANCA_Z - 0.045), ROSU))
	piese.append(cub("Cusatura", (0.31, y1 - y0 + 0.01, 0.01), (x, (y0 + y1) / 2, BANCA_Z - 0.03), LEMN))
	piese.append(cub("Cadru banca", (0.1, y1 - y0 - 0.1, 0.06), (x, (y0 + y1) / 2, BANCA_Z - 0.12), NEGRU))
	for yy in (y0 + 0.1, y1 - 0.1):
		piese.append(cub("Picior banca", (0.08, 0.06, BANCA_Z - FL - 0.12), (x, yy, (FL + BANCA_Z - 0.12) / 2), NEGRU))
		piese.append(cub("Talpa banca", (0.45, 0.08, 0.04), (x, yy, FL + 0.02), NEGRU))
	_cutie_coliziune(col, (0.32, y1 - y0, BANCA_Z - FL), (x, (y0 + y1) / 2, (FL + BANCA_Z) / 2))
	if not cu_stalpi:
		return
	ys = y1 + 0.15
	for s in (-1, 1):
		xs = x + s * 0.55
		piese.append(cub("Stalp suport", (0.07, 0.07, 1.05), (xs, ys, FL + 0.525), NEGRU))
		piese.append(cub("Carlig", (0.07, 0.12, 0.05), (xs, ys - 0.05, FL + 1.0), METAL))
		piese.append(cub("Carlig", (0.07, 0.03, 0.1), (xs, ys - 0.105, FL + 1.04), METAL))
		piese.append(cub("Talpa suport", (0.12, 0.5, 0.04), (xs, ys, FL + 0.02), NEGRU))
		_cutie_coliziune(col, (0.1, 0.1, 1.05), (xs, ys, FL + 0.525))
	piese.append(cub("Traversa suport", (1.1, 0.06, 0.06), (x, ys + 0.2, FL + 0.08), NEGRU))


def decor(cale):
	"""Dinăuntru: recepția (biroul, calculatorul, borcanul cu batoane proteice, „DAY PASS $5”), peretele scund cu turnichetul,
	scaunele din hol, automatul de băuturi, oglinzile de pe peretele din stânga, rastelul cu gantere, cele 3 bănci
	(una a lui Gym Bro, cu suporturi mai groase), cușca de genuflexiuni, pomul cu discuri, afișele, ceasul, sticla de
	apă, prosoapele. Piese: `Decor`, `Lumini`, `Geamuri`, `Coliziune`."""
	curata()
	r = random.Random(31)
	piese, lumini, geamuri, col = [], [], [], []

	def strange():
		piese[:] = [uneste(piese, "Decor")]

	# --- peretele scund dintre hol și sală, cu golul turnichetului (în joc: peretele invizibil până plătești)
	for a, b in ((-W, TX0), (TX1, W)):
		piese.append(cub("Perete scund", (b - a, 0.12, PH - FL), ((a + b) / 2, PY, (FL + PH) / 2), ALB))
		piese.append(cub("Blat perete", (b - a, 0.18, 0.04), ((a + b) / 2, PY, PH + 0.02), TEAL))
		# (mai înalt decât se vede: nu treci peste el)
		_cutie_coliziune(col, (b - a, 0.14, HC - FL), ((a + b) / 2, PY, (FL + HC) / 2))
	# turnichetul: stâlpul cu cele trei brațe, la mijlocul golului, și balustrada scurtă
	tx = (TX0 + TX1) / 2
	piese.append(cub("Stalp turnichet", (0.22, 0.3, 0.95), (TX0 + 0.11, PY, FL + 0.475), CROM))
	piese.append(cub("Cap turnichet", (0.24, 0.32, 0.05), (TX0 + 0.11, PY, FL + 0.97), NEGRU))
	lumini.append(cub("Led turnichet", (0.06, 0.012, 0.03), (TX0 + 0.11, PY - 0.157, FL + 0.9), p("61a19f")))
	for k in range(3):
		u = k * 2 * math.pi / 3 + 0.3
		a = (TX0 + 0.22, PY, FL + 0.85)
		b = (TX0 + 0.22 + 0.55 * abs(math.cos(u)) + 0.05, PY + 0.25 * math.sin(u), FL + 0.85 - 0.25 * math.cos(u) * 0.6)
		piese.append(os_intre("Brat turnichet", a, b, 0.018, CROM, laturi=6))
	piese.append(cub("Stalp turnichet", (0.06, 0.06, 0.95), (TX1 - 0.04, PY, FL + 0.475), CROM))
	strange()

	# --- biroul recepției: dulapul, blatul, calculatorul vechi, telefonul, borcanul cu batoane, afișul cu prețul
	piese.append(cub("Birou", (BX1 + W, BY1 - BY0, BZ - FL - 0.05), ((BX1 - W) / 2, (BY0 + BY1) / 2, (FL + BZ - 0.05) / 2), ALB))
	piese.append(cub("Blat birou", (BX1 + W + 0.04, BY1 - BY0 + 0.08, 0.05), ((BX1 - W) / 2, (BY0 + BY1) / 2, BZ - 0.025), TEAL))
	piese.append(cub("Dunga birou", (BX1 + W + 0.01, 0.012, 0.12), ((BX1 - W) / 2, BY0 - 0.006, FL + 0.6), TEAL))
	_cutie_coliziune(col, (BX1 + W, BY1 - BY0, BZ - FL), ((BX1 - W) / 2, (BY0 + BY1) / 2, (FL + BZ) / 2))
	# capătul biroului spre turnichet: până la peretele scund (nu treci pe lângă el)
	piese.append(cub("Capat birou", (0.06, PY - BY1, BZ - FL), (BX1 - 0.03, (BY1 + PY) / 2, (FL + BZ) / 2), ALB))
	_cutie_coliziune(col, (0.08, PY - BY1, HC - FL), (BX1 - 0.03, (BY1 + PY) / 2, (FL + HC) / 2))
	kx, ky = -0.9, (BY0 + BY1) / 2 + 0.1
	piese.append(cub("Monitor", (0.36, 0.3, 0.3), (kx, ky, BZ + 0.2), p("7e8d87")))
	lumini.append(cub("Ecran", (0.28, 0.012, 0.22), (kx, ky - 0.152, BZ + 0.21), p("438b88")))
	piese.append(cub("Picior monitor", (0.12, 0.12, 0.05), (kx, ky, BZ + 0.025), p("7e8d87")))
	piese.append(cub("Tastatura", (0.4, 0.14, 0.02), (kx + 0.1, ky - 0.25, BZ + 0.01), METAL_INCHIS))
	piese.append(cub("Telefon fix", (0.18, 0.2, 0.06), (-2.0, ky, BZ + 0.03), NEGRU))
	piese.append(cub("Receptor", (0.2, 0.05, 0.04), (-2.0, ky - 0.04, BZ + 0.08), NEGRU))
	piese.append(cilindru("Borcan", 0.08, 0.08, 0.2, (0.45, BY0 + 0.18, BZ + 0.1), GEAM, laturi=10))
	for i in range(5):
		piese.append(cub("Baton", (0.03, 0.1, 0.02), (0.42 + (i % 3) * 0.03, BY0 + 0.18, BZ + 0.03 + i * 0.03), (AUR, ROSU, VERDE)[i % 3],
			rot=(0, 0.3 * i, 0)))
	piese.append(cub("Afis pret", (0.4, 0.012, 0.3), (0.2, BY0 - 0.01, BZ - 0.25), AUR))
	piese.append(_text("Scris pret", "DAY PASS\n$5", (0.2, BY0 - 0.02, BZ - 0.25), 0.07, NEGRU))
	piese.append(cub("Clopotel recepție", (0.08, 0.08, 0.04), (-0.35, BY0 + 0.12, BZ + 0.02), AUR))
	# pe peretele din spatele recepției (fața peretelui scund spre hol... nu: peretele din stânga): sigla sălii
	piese.append(cub("Placa sigla", (0.02, 1.6, 0.6), (-W + 0.01, 1.4, 2.2), NEGRU))
	piese.append(_text("Sigla", "IRON\nPUMP", (-W + 0.025, 1.4, 2.2), 0.18, AUR, rot=(1.5708, 0, -1.5708)))
	strange()
	# holul: două scaune de plastic, automatul cu băuturi, un ficus, preșul
	for sy in (0.9, 1.5):
		sx = W - 0.35
		piese.append(cub("Scaun hol", (0.42, 0.42, 0.05), (sx, sy, FL + 0.45), p("295555")))
		piese.append(cub("Spatar hol", (0.05, 0.42, 0.4), (sx + 0.2, sy, FL + 0.68), p("295555")))
		for dx, dy in ((-0.18, -0.18), (0.18, -0.18), (-0.18, 0.18), (0.18, 0.18)):
			piese.append(cub("Picior scaun", (0.03, 0.03, 0.43), (sx + dx, sy + dy, FL + 0.215), CROM))
	_cutie_coliziune(col, (0.45, 1.05, 0.9), (W - 0.35, 1.2, FL + 0.45))
	piese.append(cub("Automat", (0.8, 0.7, 1.85), (W - 0.42, 2.65, FL + 0.925), ROSU))
	geamuri.append(cub("Geam automat", (0.012, 0.5, 1.2), (W - 0.83, 2.6, FL + 1.1), GEAM))
	for i in range(4):
		for j in range(3):
			piese.append(cub("Doza", (0.06, 0.08, 0.12), (W - 0.75, 2.45 + j * 0.15, FL + 0.6 + i * 0.3), (ALB, AUR, VERDE, p("438b88"))[(i + j) % 4]))
	lumini.append(cub("Firma automat", (0.012, 0.6, 0.22), (W - 0.826, 2.65, FL + 1.72), ALB))
	_cutie_coliziune(col, (0.82, 0.72, 1.85), (W - 0.42, 2.65, FL + 0.925))
	piese.append(cilindru("Ghiveci", 0.18, 0.14, 0.35, (-W + 0.35, 0.6, FL + 0.175), LEMN, laturi=8))
	for k in range(7):
		u = k * 0.9
		piese.append(sfera("Frunza", 0.16, (-W + 0.35 + math.cos(u) * 0.12, 0.6 + math.sin(u) * 0.12, FL + 0.6 + k * 0.08), VERDE_INCHIS,
			scara=(1, 1, 0.55), segmente=6, inele=4))
	piese.append(cub("Pres", (1.3, 0.8, 0.012), ((USA[0] + USA[1]) / 2, G + 0.5, FL + 0.006), NEGRU))
	piese.append(_text("Scris pres", "NO PAIN\nNO GAIN", ((USA[0] + USA[1]) / 2, G + 0.5, FL + 0.014), 0.08, AUR, rot=(0, 0, 0)))
	strange()

	# --- oglinzile de pe peretele din stânga (în sală), cu rama și dungi de lumină
	oy0, oy1 = PY + 0.5, D - 0.4
	piese.append(cub("Oglinda", (0.02, oy1 - oy0, 1.9), (-W + 0.012, (oy0 + oy1) / 2, FL + 1.45), OGLINDA))
	for k in range(6):
		yy = oy0 + 0.6 + k * 1.0
		piese.append(cub("Reflex", (0.008, 0.08, 1.6), (-W + 0.026, yy, FL + 1.45), OGLINDA_DUNGA, rot=(0.5, 0, 0)))
	for zz in (FL + 0.5, FL + 2.4):
		piese.append(cub("Rama oglinda", (0.04, oy1 - oy0 + 0.04, 0.04), (-W + 0.02, (oy0 + oy1) / 2, zz), CROM))
	strange()

	# --- rastelul cu gantere (în fața oglinzii, două rânduri înclinate), de la 1 kg la 50 kg
	ry0, ry1 = 4.0, 6.6
	rx = -W + 0.55
	for zz, dx in ((FL + 0.45, 0.0), (FL + 0.8, -0.15)):
		piese.append(cub("Polita rastel", (0.35, ry1 - ry0, 0.03), (rx + dx, (ry0 + ry1) / 2, zz), NEGRU, rot=(0, -0.2, 0)))
	for yy in (ry0, (ry0 + ry1) / 2, ry1):
		piese.append(cub("Picior rastel", (0.5, 0.06, 0.85), (rx, yy, FL + 0.425), NEGRU))
	_cutie_coliziune(col, (0.55, ry1 - ry0, 0.9), (rx, (ry0 + ry1) / 2, FL + 0.45))
	# perechile (de jos mari, sus mici); locul perechii tale (`LOC_GANTERE` din sala.tscn) e liber, la y 5,3
	n = 0
	for zz, dx, razaj in ((FL + 0.45, 0.0, 0.085), (FL + 0.8, -0.15, 0.06)):
		yy = ry0 + 0.15
		while yy < ry1 - 0.1:
			if abs(yy - 5.3) < 0.2 and dx == 0.0:
				yy += 0.32
				continue
			raza = razaj * (0.75 + 0.5 * (yy - ry0) / (ry1 - ry0))
			_gantera_statica(piese, rx + dx, yy, zz + raza + 0.015, raza, 0.06 + raza * 0.4, NEGRU)
			n += 1
			yy += 0.32
	piese.append(cub("Eticheta rastel", (0.012, 0.3, 0.06), (rx + 0.19, 5.3, FL + 0.38), ALB))
	strange()

	# --- băncile: două libere (în spate, dreapta) și a lui Gym Bro (cu stâlpi mai groși), sprijinite pe suporturi
	for x, yc in BANCI:
		_banca(piese, col, x, yc)
	_banca(piese, col, BANCA_BRO[0], BANCA_BRO[1])
	strange()

	# --- cușca de genuflexiuni: 4 montanți, traversele de sus, cârligele (J-hooks) și barele de siguranță
	cx, cy = CUSCA
	for sx in (-1, 1):
		for sy in (-1, 1):
			piese.append(cub("Montant cusca", (0.08, 0.08, 2.3), (cx + sx * 0.6, cy + sy * 0.3, FL + 1.15), NEGRU))
			_cutie_coliziune(col, (0.09, 0.09, 2.3), (cx + sx * 0.6, cy + sy * 0.3, FL + 1.15))
			for k in range(20):  # găurile montanților
				piese.append(cub("Gaura montant", (0.084, 0.02, 0.02), (cx + sx * 0.6, cy + sy * 0.3, FL + 0.3 + k * 0.1), METAL_INCHIS))
		piese.append(cub("Traversa sus", (0.08, 0.68, 0.08), (cx + sx * 0.6, cy, FL + 2.3), NEGRU))
		piese.append(cub("Traversa jos", (0.08, 0.68, 0.06), (cx + sx * 0.6, cy, FL + 0.05), NEGRU))
		piese.append(cub("Bara siguranta", (0.05, 0.75, 0.05), (cx + sx * 0.6, cy, FL + 0.85), CROM))
		piese.append(cub("Carlig J", (0.08, 0.12, 0.05), (cx + sx * 0.6, cy - 0.35, FL + 1.38), METAL))
		piese.append(cub("Carlig J", (0.08, 0.03, 0.09), (cx + sx * 0.6, cy - 0.405, FL + 1.41), METAL))
	piese.append(cub("Traversa spate", (1.28, 0.08, 0.08), (cx, cy + 0.3, FL + 2.3), NEGRU))
	piese.append(cub("Traversa fata", (1.28, 0.08, 0.08), (cx, cy - 0.3, FL + 2.3), NEGRU))
	piese.append(cub("Platforma", (1.6, 1.5, 0.03), (cx, cy - 0.3, FL + 0.015), LEMN))
	strange()
	# pomul cu discuri, lângă cușcă
	px, py = -0.4, 9.5
	piese.append(cilindru("Pom discuri", 0.03, 0.03, 1.2, (px, py, FL + 0.6), NEGRU, laturi=6))
	piese.append(cub("Baza pom", (0.6, 0.6, 0.04), (px, py, FL + 0.02), NEGRU))
	for k, (zz, raza, cul) in enumerate(((0.35, 0.225, ALBASTRU), (0.7, 0.2, ROSU), (1.0, 0.16, AUR))):
		u = k * 2.1
		dx, dy = math.cos(u) * 0.12, math.sin(u) * 0.12
		piese.append(os_intre("Brat pom", (px, py, FL + zz), (px + dx, py + dy, FL + zz + 0.06), 0.015, CROM, laturi=6))
		for j in range(2):
			piese.append(cilindru("Disc pom", raza, raza, 0.05, (px + dx * (1.05 + j * 0.45), py + dy * (1.05 + j * 0.45), FL + zz + 0.06),
				cul, laturi=12, rot=(0, 1.5708, u)))
	_cutie_coliziune(col, (0.5, 0.5, 1.2), (px, py, FL + 0.6))
	strange()

	# --- afișele, ceasul, fântâna de apă, coșul de prosoape
	for continut, xx, zz, marime, cul, fond in (("NO PAIN\nNO GAIN", -3.5, 2.3, 0.14, AUR, NEGRU),
			("DON'T SKIP\nLEG DAY", -0.9, 2.1, 0.12, ROSU, ALB), ("TRAIN INSANE\nOR REMAIN\nTHE SAME", 2.6, 2.2, 0.09, ALB, TEAL)):
		piese.append(cub("Afis", (1.2, 0.012, 0.75), (xx, D - 0.008, zz), fond))
		piese.append(_text("Scris afis", continut, (xx, D - 0.018, zz), marime, cul))
	piese.append(cilindru("Ceas", 0.18, 0.18, 0.04, (0.9, D - 0.02, 2.75), ALB, laturi=12, rot=(1.5708, 0, 0)))
	piese.append(cub("Ac ceas", (0.01, 0.01, 0.13), (0.9, D - 0.045, 2.79), NEGRU, rot=(0, 0.6, 0)))
	piese.append(cub("Ac ceas", (0.01, 0.01, 0.09), (0.9, D - 0.045, 2.76), NEGRU, rot=(0, -1.2, 0)))
	piese.append(cub("Fantana apa", (0.4, 0.3, 0.9), (W - 0.2, 7.0, FL + 0.45), CROM))
	piese.append(cub("Cuva", (0.42, 0.32, 0.08), (W - 0.2, 7.0, FL + 0.94), METAL))
	_cutie_coliziune(col, (0.4, 0.3, 0.98), (W - 0.2, 7.0, FL + 0.49))
	piese.append(cilindru("Cos prosoape", 0.25, 0.22, 0.5, (W - 0.3, 3.7, FL + 0.25), METAL_INCHIS, laturi=8))
	for k in range(3):
		piese.append(sfera("Prosop", 0.14, (W - 0.3 + (k - 1) * 0.08, 3.7, FL + 0.52), (ALB, TEAL, ALB)[k], scara=(1, 1, 0.4),
			segmente=6, inele=4))
	_cutie_coliziune(col, (0.5, 0.5, 0.6), (W - 0.3, 3.7, FL + 0.3))
	# pe peretele din dreapta: „RE-RACK YOUR WEIGHTS” și „NO CHALK”
	piese.append(cub("Placa", (0.02, 1.4, 0.3), (W - 0.01, 6.4, 2.4), NEGRU))
	piese.append(_text("Scris placa", "RE-RACK YOUR WEIGHTS", (W - 0.025, 6.4, 2.4), 0.07, AUR, rot=(1.5708, 0, 1.5708)))
	piese.append(cub("Placa", (0.02, 0.8, 0.3), (W - 0.01, 8.6, 2.4), ALB))
	piese.append(_text("Scris placa", "NO CHALK", (W - 0.025, 8.6, 2.4), 0.08, ROSU, rot=(1.5708, 0, 1.5708)))
	strange()

	uneste(piese, "Decor")
	uneste(lumini, "Lumini")
	uneste(geamuri, "Geamuri")
	uneste(col, "Coliziune")
	exporta(os.path.join(cale, "decor_sala.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Ce se mișcă: barele, ganterele, pumnii tăi (originea la mijloc / în mâner)
# ---------------------------------------------------------------------------------------------------------------

def _bara(piese, lung, manson0, raza_bara=0.014):
	"""Bara olimpică pe X: bara subțire, zimții, manșoanele groase de la capete (de la `manson0` până la capăt), gulerele."""
	piese.append(cilindru("Bara", raza_bara, raza_bara, 2 * manson0, (0, 0, 0), CROM, laturi=8, rot=(0, 1.5708, 0)))
	for s in (-1, 1):
		piese.append(cilindru("Manson", 0.025, 0.025, lung / 2 - manson0, (s * (manson0 + lung / 2) / 2, 0, 0), CROM, laturi=8,
			rot=(0, 1.5708, 0)))
		piese.append(cilindru("Guler bara", 0.04, 0.04, 0.03, (s * (manson0 - 0.015), 0, 0), METAL, laturi=8, rot=(0, 1.5708, 0)))
		for k in range(4):  # zimții (unde ții bara)
			piese.append(cilindru("Zimti", raza_bara + 0.001, raza_bara + 0.001, 0.05, (s * (0.25 + k * 0.08), 0, 0), METAL, laturi=8,
				rot=(0, 1.5708, 0)))


def _disc(piese, x, raza, gros, cul):
	piese.append(cilindru("Disc", raza, raza, gros, (x, 0, 0), cul, laturi=14, rot=(0, 1.5708, 0)))
	piese.append(cilindru("Butuc disc", 0.05, 0.05, gros + 0.006, (x, 0, 0), CROM, laturi=8, rot=(0, 1.5708, 0)))


def bare(cale):
	"""`bara_sala.glb`: bara ta, 60 kg (câte un disc albastru de 20 kg). `bara_500.glb`: a lui Gym Bro, mai lungă, cu
	câte 9 discuri roșii de 25 kg și câte unul de 15 (galben) pe fiecare parte = 500 kg; manșoanele abia le mai țin."""
	curata()
	piese = []
	_bara(piese, 2.2, 0.72)
	for s in (-1, 1):
		_disc(piese, s * 0.79, 0.225, 0.07, ALBASTRU)
		piese.append(cilindru("Clema", 0.035, 0.035, 0.04, (s * 0.85, 0, 0), ROSU, laturi=8, rot=(0, 1.5708, 0)))
	uneste(piese, "Bara")
	exporta(os.path.join(cale, "bara_sala.glb"))

	curata()
	piese = []
	_bara(piese, 2.9, 0.72, raza_bara=0.016)
	for s in (-1, 1):
		for k in range(9):
			_disc(piese, s * (0.77 + k * 0.058), 0.225, 0.054, ROSU)
		_disc(piese, s * (0.77 + 9 * 0.058 + 0.005), 0.2, 0.05, GALBEN)
		piese.append(cilindru("Clema", 0.04, 0.04, 0.05, (s * (0.77 + 10 * 0.058 + 0.01), 0, 0), NEGRU, laturi=8, rot=(0, 1.5708, 0)))
	uneste(piese, "Bara")
	exporta(os.path.join(cale, "bara_500.glb"))


def gantere(cale):
	"""`gantera.glb` (hexagonală, 12,5 kg) și `gantera_roz.glb` (de vinil, 1 kg, a slăbănogului). Mânerul pe X, originea
	în mijlocul lui."""
	for nume, raza, lat, maner, cul, laturi in (("gantera", 0.07, 0.1, 0.13, NEGRU, 6), ("gantera_roz", 0.042, 0.05, 0.1, ROZ, 10)):
		curata()
		piese = [cilindru("Maner", 0.015, 0.015, maner, (0, 0, 0), CROM, laturi=8, rot=(0, 1.5708, 0))]
		for s in (-1, 1):
			piese.append(cilindru("Cap", raza, raza, lat, (s * (maner / 2 + lat / 2), 0, 0), cul, laturi=laturi, rot=(0, 1.5708, 0)))
			if nume == "gantera":
				piese.append(cilindru("Inel cap", raza * 0.55, raza * 0.55, lat + 0.006, (s * (maner / 2 + lat / 2), 0, 0), CROM, laturi=8,
					rot=(0, 1.5708, 0)))
		uneste(piese, "Gantera")
		exporta(os.path.join(cale, nume + ".glb"))


def pumn(cale):
	"""Pumnul tău la persoana întâi (bench, genuflexiuni, biceps): strânge o bară pe X care trece prin origine; antebrațul
	pleacă spre +Z (în Godot +Y), cu mâneca neagră a hanoracului și manșeta (ca mana_jucator.glb); dosul palmei și
	încheieturile degetelor spre -Y (în Godot +Z). E simetric pe X: același model pentru ambele mâini."""
	curata()
	piele, umbra = p("a56850"), p("904a40")
	piese = [
		cub("Dos palma", (0.084, 0.03, 0.085), (0, -0.018, 0.035), piele),
		cub("Degete", (0.084, 0.034, 0.042), (0, 0.016, -0.006), umbra),
		cub("Palma", (0.08, 0.02, 0.06), (0, 0.022, 0.045), piele),
		trunchi("Antebrat", [((0, -0.004, 0.07), 0.034, 0.024), ((0, -0.004, 0.16), 0.038, 0.028), ((0, -0.004, 0.3), 0.042, 0.032)],
			piele, laturi=8),
		trunchi("Maneca", [((0, -0.004, 0.12), 0.05, 0.042), ((0, -0.004, 0.3), 0.058, 0.05), ((0, -0.004, 0.55), 0.064, 0.056),
			((0, -0.004, 0.8), 0.068, 0.06)], NEGRU, laturi=8),
		trunchi("Manseta", [((0, -0.004, 0.11), 0.053, 0.045), ((0, -0.004, 0.135), 0.053, 0.045)], LEMN, laturi=8),
		os_intre("Deget mare", (-0.03, 0.03, 0.035), (0.012, 0.036, -0.004), 0.011, piele, laturi=5),
	]
	for k in range(4):  # încheieturile degetelor (dosul pumnului) și șanțurile dintre degete
		x = -0.03 + k * 0.02
		piese.append(sfera("Incheietura", 0.012, (x, -0.024, -0.01), piele, segmente=6, inele=4))
		if k:
			piese.append(cub("Sant deget", (0.003, 0.004, 0.04), (x - 0.01, 0.034, -0.006), LEMN_INCHIS))
	uneste(piese, "Pumn")
	exporta(os.path.join(cale, "pumn_sala.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Oamenii (casino_oameni.om; modelul privește spre -Y, în Godot +Z)
# ---------------------------------------------------------------------------------------------------------------

RECEPTIONISTA = {
	"piele": p("a56850"), "piele_umbra": p("904a40"), "haina": TEAL, "haina_umbra": p("295555"), "camasa": TEAL,
	"stil_haina": "tricou", "scris_tricou": AUR, "maneca_scurta": True, "femeie": True, "par": p("a18463"),
	"par_suvita": p("a56850"), "stil_par": "voluminos", "cercei": AUR, "buze": p("7b383a"), "gura": p("5e363e"),
	"unghii": p("7b383a"), "pantaloni": NEGRU, "pantofi": ALB, "gros_brat": 0.8, "spranceana": 0.012, "incruntat": -0.12,
	"in_picioare": True, "sezut": 0.84, "masa": BZ - FL,
	# palmele pe birou (ea stă la 0,3 m în spatele lui)
	"poza_D": ((-0.25, -0.06, 1.1), (-0.15, -0.3, BZ - FL + 0.025)),
	"poza_S": ((0.25, -0.06, 1.1), (0.15, -0.3, BZ - FL + 0.025)),
}

SLABANOG = {
	"piele": p("a56850"), "piele_umbra": p("904a40"), "haina": p("7e8d87"), "haina_umbra": p("70706e"), "camasa": p("7e8d87"),
	"stil_haina": "tricou", "maneca_scurta": True, "slab": 1.0, "gros_brat": 0.6, "par": p("48313b"), "stil_par": "scurt",
	"ochelari": "vedere", "rama": NEGRU, "pantaloni": p("5e5356"), "pantofi": ALB, "nas": 1.25, "spranceana": 0.015,
	"incruntat": -0.2, "in_picioare": True, "sezut": 0.86,
	# brațele pe lângă corp, cotul puțin în spate (la ridicare se îndoaie înainte)
	"poza_D": ((-0.2, 0.06, 1.12), (-0.2, -0.03, 0.85)),
	"poza_S": ((0.2, 0.06, 1.12), (0.2, -0.03, 0.85)),
}

# Gym Bro: făcut în picioare, dar în joc e culcat pe spate (Godot: rotit -90° pe X). Brațele în repaus țin bara sus
# (înainte, în modelul în picioare = în sus, culcat), cu coatele în afară; picioarele (`_picioare_bro`) sunt îndoite
# pentru culcat: coapsele de-a lungul băncii, gambele în jos spre podea.
GYM_BRO = {
	"piele": p("a56850"), "piele_umbra": p("904a40"), "haina": p("a56850"), "haina_umbra": p("904a40"), "camasa": p("a56850"),
	"stil_haina": "gol", "brate_goale": True, "gros_brat": 1.9, "lat": 1.5, "umeri": 1.45, "par": NEGRU, "stil_par": "ras",
	"tepi": p("48313b"), "lant": AUR, "incruntat": 0.35, "nas": 1.05, "pantaloni": NEGRU, "sezut": 0.86, "fara_picioare": True,
	"poza_D": ((-0.43, -0.25, 1.39), (-0.42, -0.53, 1.43)),
	"poza_S": ((0.43, -0.25, 1.39), (0.42, -0.53, 1.43)),
}


def _picioare_bro(corp):
	"""Picioarele lui Gym Bro (separate, `Picioare`): cvadricepși uriași în șort negru, gambele, adidașii albi. În
	modelul în picioare: „jos” = de-a lungul băncii spre tălpi (-Z), „în spate” (+Y) = spre podea când e culcat."""
	piele, umbra = GYM_BRO["piele"], GYM_BRO["piele_umbra"]
	z0 = GYM_BRO["sezut"]
	pp = []
	for k in (-1, 1):
		sold = (0.14 * k, 0.03, z0 + 0.04)
		genunchi = (0.27 * k, -0.06, z0 - 0.42)
		glezna = (0.32 * k, 0.5, z0 - 0.5)
		mij = tuple((a + b) / 2 for a, b in zip(sold, genunchi))
		pp.append(trunchi("Sort", [(sold, 0.15, 0.15), (mij, 0.135, 0.135)], NEGRU, laturi=10, ref=(1, 0, 0)))
		pp.append(trunchi("Coapsa", [(sold, 0.14, 0.14), (mij, 0.13, 0.135), (genunchi, 0.085, 0.085)], piele, laturi=10, ref=(1, 0, 0)))
		pp.append(sfera("Genunchi", 0.085, genunchi, piele, segmente=8, inele=5))
		pp.append(trunchi("Gamba", [(genunchi, 0.08, 0.08), (tuple(genunchi[i] + (glezna[i] - genunchi[i]) * 0.35 for i in range(3)), 0.095, 0.09),
			(glezna, 0.055, 0.055)], piele, laturi=8, ref=(1, 0, 0)))
		pp.append(trunchi("Ciorap", [((glezna[0], glezna[1] - 0.12, glezna[2]), 0.06, 0.06), (glezna, 0.058, 0.058)], ALB, laturi=8,
			ref=(1, 0, 0)))
		# adidasul: talpa pe podea (perpendicular pe +Y), vârful spre tălpi (-Z)
		pp.append(cub("Adidas", (0.11, 0.1, 0.28), (glezna[0], glezna[1] + 0.03, glezna[2] - 0.08), ALB))
		pp.append(cub("Talpa adidas", (0.115, 0.02, 0.29), (glezna[0], glezna[1] + 0.08, glezna[2] - 0.08), NEGRU))
		pp.append(cub("Siret", (0.08, 0.012, 0.1), (glezna[0], glezna[1] - 0.025, glezna[2] - 0.12), umbra))
	uneste(pp, "Picioare")


def oameni(cale):
	casino_oameni.om(cale, "receptionista_sala", RECEPTIONISTA, 81)
	casino_oameni.om(cale, "slabanog_sala", SLABANOG, 82)
	bro = dict(GYM_BRO)
	bro["extra"] = _picioare_bro
	casino_oameni.om(cale, "gym_bro", bro, 83)


def toate(cale):
	cladire(cale)
	strada(cale)
	decor(cale)
	bare(cale)
	gantere(cale)
	pumn(cale)
	oameni(cale)


if __name__ == "__main__":
	cale_modele = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")
	if "--" in sys.argv:
		for nume in sys.argv[sys.argv.index("--") + 1:]:
			globals()[nume](cale_modele)
	else:
		toate(cale_modele)
