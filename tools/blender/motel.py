# „Paradise Motel”: motelul american jegos din orașul vecin, unde se ascunde Warlock-ul (motel.tscn, noaptea, după zborul
# pe mătură de la bloc). O aripă lungă cu două etaje (camerele 117–124 jos, 217–224 sus, pasarela de beton cu balustradă
# ruginită, scara de la capăt, streașina de șindrilă), recepția („OFFICE”) la capătul din dreapta, ieșită spre parcare,
# parcarea crăpată cu gropi și pete de ulei, piscina golită cu gard de plasă, stâlpul cu firma „PARADISE MOTEL” (litere
# arse, săgeata cu becuri, „NO VACANCY” cu „NO” stins), mașinile (una pe butuci), tomberonul cu saltea, strada.
# Recepția pe dinăuntru: mocheta pătată, tavanul casetat cu plăci căzute și pete de apă, neoanele, tejgheaua cu geam
# antiglonț și fanta de bani, sonerie, monitorul vechi, panoul cu chei, televizorul cu purici, scaunele de vinil rupte,
# planta moartă, automatul de gustări, aparatul de cafea „OUT OF ORDER”, afișele („NO REFUNDS”, „CHECK OUT 11 AM”).
# Plus receptionera (`receptionera`, prin casino_oameni.om).
#   blender --background --factory-startup --python tools/blender/motel.py                  (toate)
#   blender --background --factory-startup --python tools/blender/motel.py -- receptionera  (doar unele)
# Axe Blender: Z în sus, fațadele spre -Y (în Godot +Z, spre parcare și stradă). Originea = mijlocul parcării, la sol.
# Piese: `Motel`/`Parcare`/`Receptie`, `Lumini` (ce strălucește: neoane, becuri, geamuri aprinse), `Geamuri` (sticlă),
# `Coliziune` (forma simplă pentru Godot, nu se vede).
import math
import os
import random
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, uneste, exporta, trunchi, desparte_fete  # noqa: E402
from lexy import perete, prisma  # noqa: E402
from casino import _text, _text_o_fata, _tor, _cutie_coliziune  # noqa: E402
from amanet import _obiect  # noqa: E402
import casino_oameni  # noqa: E402

NEGRU = p("262d2f")
ALB = p("83b3b0")
AUR = p("a18463")
BRONZ = p("a56850")
CROM = p("7e8d87")
METAL = p("6f6d7f")
METAL_INCHIS = p("5e5356")
GEAM = p("2a3c3d")
LEMN = p("5e363e")
LEMN_INCHIS = p("48313b")
LEMN_DESCHIS = p("904a40")
ROSU = p("7b383a")
RUGINA = p("904a40")
VERDE = p("445d46")
VERDE_DESCHIS = p("5b6d4e")
TEAL = p("295555")
TURCOAZ = p("438b88")
NEON = p("61a19f")
PERETE = p("778c96")
MOV = p("655269")
MASLINIU = p("7a7b59")
BETON = p("70706e")
ASFALT = p("5e5356")
TENCUIALA = AUR          # stucco bej, decolorat
TENCUIALA_PATA = MASLINIU
SINDRILA = LEMN_INCHIS
# lămpile de lângă uși care încă merg (în motel.tscn au câte o lumină adevărată; restul sunt arse)
LAMPI_APRINSE = (118, 121, 122, 123, 217, 220, 224)

# --- aripa cu camere (Blender: fațada la y = YF, corpul spre +Y)
YF = 10.0       # fațada
YS = 18.0       # spatele
YP = 8.0        # marginea pasarelei (sus) și a trotuarului (jos)
XV0 = -18.8     # capătul din stânga (nișa cu automate până la XA)
XA = -17.2      # prima cameră
RW = 3.4        # lățimea unei camere
NR = 8          # camere pe etaj
XB = XA + NR * RW   # = 10.0, aici începe recepția
FL = 0.15       # trotuarul / pragul camerelor
E2 = 3.15       # podeaua de sus
HT = 6.0        # acoperișul
# --- recepția (Blender: fațada la y = OY0)
OX0, OX1 = 10.0, 17.5
OY0, OY1 = 5.0, 16.0
OG = 0.25
OH = 3.0        # tavanul casetat
OT = 3.4        # acoperișul
OUSA = (12.0, 13.1, FL, FL + 2.3)
OVITRINA = (13.6, 16.9, 0.9, 2.45)
TY0, TY1, TZ = 10.0, 10.7, FL + 1.05   # tejgheaua: fața spre client, spatele, blatul
PERETE_SPATE = 12.5                   # peretele din spatele receptionerei (cu panoul de chei)
# receptionera stă pe scaun în spatele tejghelei
RX, RY = 13.75, 10.98
# --- piscina (golită)
PX0, PX1, PY0, PY1, PADANC = -15.5, -9.5, -6.0, -1.0, 1.6
GX0, GX1, GY0, GY1 = -17.0, -8.0, -7.5, 0.5   # gardul de plasă / dalele din jur
# --- strada
SY0, SY1 = -26.0, -18.0


def _ramas(piese, nume):
	"""Lipește ce s-a strâns până acum într-un singur obiect (Blender încetinește cu mii de obiecte)."""
	if len(piese) > 1:
		piese[:] = [uneste(piese, nume)]


# ---------------------------------------------------------------------------------------------------------------
# Bucăți care se repetă
# ---------------------------------------------------------------------------------------------------------------

def _usa_camera(piese, lumini, x0, z0, numar, cul, r, nu_deranjati=False, aprins=True):
	"""Ușa unei camere (metal vopsit, scorojit), cu numărul de alamă, vizorul, clanța, pragul și lampa de lângă ea."""
	x1 = x0 + 0.95
	y = YF - 0.01
	piese.append(cub("Toc usa", (1.09, 0.06, 2.17), ((x0 + x1) / 2, y - 0.02, z0 + 1.07), LEMN))
	piese.append(cub("Usa camera", (0.95, 0.05, 2.08), ((x0 + x1) / 2, y - 0.045, z0 + 1.04), cul))
	# vopsea sărită jos, la lovituri de picior
	piese.append(cub("Vopsea sarita", (0.3, 0.052, 0.18), (x0 + 0.3 + r.uniform(0, 0.3), y - 0.056, z0 + 0.2), METAL))
	piese.append(cub("Placa numar", (0.26, 0.01, 0.12), ((x0 + x1) / 2, y - 0.075, z0 + 1.72), LEMN_INCHIS))
	piese.append(_text("Numar", str(numar), ((x0 + x1) / 2, y - 0.082, z0 + 1.72), 0.09, AUR))
	piese.append(cilindru("Vizor", 0.012, 0.012, 0.02, ((x0 + x1) / 2, y - 0.075, z0 + 1.55), CROM, laturi=6, rot=(1.5708, 0, 0)))
	piese.append(cub("Clanta", (0.05, 0.05, 0.12), (x1 - 0.1, y - 0.08, z0 + 1.0), CROM))
	piese.append(cub("Clanta maner", (0.12, 0.03, 0.025), (x1 - 0.15, y - 0.11, z0 + 0.98), CROM))
	if nu_deranjati:
		piese.append(cub("Agatatoare", (0.09, 0.006, 0.22), (x1 - 0.15, y - 0.13, z0 + 0.85), ROSU))
		piese.append(_text_o_fata("Do not disturb", "DO NOT\nDISTURB", (x1 - 0.15, y - 0.134, z0 + 0.85), 0.028, ALB))
	# lampa de perete (globul din sticlă cu gratie) — unele sunt arse
	lx = x0 - 0.25
	piese.append(cub("Baza lampa", (0.14, 0.05, 0.2), (lx, y - 0.03, z0 + 2.35), METAL_INCHIS))
	(lumini if aprins else piese).append(sfera("Glob lampa", 0.07, (lx, y - 0.1, z0 + 2.35), AUR if aprins else METAL,
		scara=(1, 0.7, 1.25), segmente=8, inele=5))
	piese.append(cub("Gratie lampa", (0.012, 0.012, 0.2), (lx, y - 0.17, z0 + 2.35), METAL_INCHIS))


def _fereastra_camera(piese, lumini, geamuri, x0, z0, culoare_perdea, aprinsa, r, scanduri=False, culoare_lumina=AUR):
	"""Fereastra unei camere: rama de aluminiu, perdeaua trasă (la unele aprinsă din spate), aerul condiționat de sub ea,
	cu dâra de rugină și apă de pe perete."""
	x1 = x0 + 1.4
	y = YF - 0.01
	za, zb = z0 + 0.95, z0 + 2.15
	piese.append(cub("Rama fereastra", (1.5, 0.07, 1.3), ((x0 + x1) / 2, y - 0.02, (za + zb) / 2), CROM))
	if scanduri:
		# geam spart, bătut în scânduri
		piese.append(cub("Fereastra neagra", (1.4, 0.1, 1.2), ((x0 + x1) / 2, y - 0.02, (za + zb) / 2), NEGRU))
		for k in range(4):
			piese.append(cub("Scandura", (1.55, 0.03, 0.22), ((x0 + x1) / 2, y - 0.075, za + 0.15 + k * 0.3),
				(LEMN_DESCHIS, LEMN, BRONZ)[k % 3], rot=(0, r.uniform(-0.12, 0.12), 0)))
			for c in (x0 + 0.05, x1 - 0.05):
				piese.append(cub("Cui", (0.015, 0.02, 0.015), (c, y - 0.095, za + 0.15 + k * 0.3), CROM))
	else:
		(lumini if aprinsa else piese).append(cub("Perdea", (1.38, 0.03, 1.18), ((x0 + x1) / 2, y + 0.04, (za + zb) / 2),
			culoare_lumina if aprinsa else culoare_perdea))
		# perdeaua are falduri (dungi verticale mai închise)
		for k in range(6):
			piese.append(cub("Falduri", (0.04, 0.028, 1.18), (x0 + 0.12 + k * 0.23, y + 0.02, (za + zb) / 2), LEMN_INCHIS))
		geamuri.append(cub("Geam fereastra", (1.38, 0.01, 1.18), ((x0 + x1) / 2, y - 0.02, (za + zb) / 2), GEAM))
		piese.append(cub("Montant", (0.04, 0.08, 1.2), ((x0 + x1) / 2, y - 0.03, (za + zb) / 2), CROM))
	# aerul condiționat prin perete, sub fereastră, cu grila și o dâră de apă/rugină pe perete
	ax = x0 + 0.7
	piese.append(cub("Aer conditionat", (0.66, 0.3, 0.42), (ax, y - 0.14, z0 + 0.62), BETON))
	piese.append(cub("Grila aer", (0.58, 0.01, 0.3), (ax, y - 0.295, z0 + 0.62), METAL_INCHIS))
	for k in range(5):
		piese.append(cub("Lamela", (0.56, 0.012, 0.012), (ax, y - 0.316, z0 + 0.5 + k * 0.06), METAL))
	piese.append(cub("Rugina aer", (0.07, 0.006, 0.5), (ax + r.uniform(-0.2, 0.2), y - 0.016, z0 + 0.15), RUGINA))
	piese.append(cub("Pata apa", (0.42, 0.005, 0.38), (ax, y - 0.003, z0 + 0.25), TENCUIALA_PATA))


def _masina(tip, culoare, r):
	"""O mașină veche, în origine, cu botul spre -Y. tip: „sedan”, „pickup”, „epava” (pe butuci, fără roți, capota
	ridicată). Întoarce piesele și piesele de coliziune (în coordonatele ei)."""
	s, col = [], []
	L = 4.8 if tip != "pickup" else 5.2
	h0 = 0.3 if tip != "epava" else 0.42
	s.append(cub("Caroserie", (1.86, L, 0.62), (0, 0, h0 + 0.31), culoare))
	s.append(cub("Bara fata", (1.9, 0.14, 0.18), (0, -L / 2 - 0.05, h0 + 0.18), CROM))
	s.append(cub("Bara spate", (1.9, 0.14, 0.18), (0, L / 2 + 0.05, h0 + 0.18), CROM if tip != "epava" else RUGINA))
	s.append(cub("Grila", (1.2, 0.03, 0.22), (0, -L / 2 - 0.005, h0 + 0.42), METAL_INCHIS))
	for x in (-0.72, 0.72):
		s.append(cub("Far", (0.26, 0.03, 0.14), (x, -L / 2 - 0.01, h0 + 0.44), ALB if tip != "epava" else NEGRU))
		s.append(cub("Stop", (0.3, 0.03, 0.12), (x, L / 2 + 0.01, h0 + 0.46), ROSU))
	if tip == "pickup":
		s.append(cub("Cabina", (1.7, 1.7, 0.62), (0, -0.35, h0 + 0.93), culoare))
		s.append(cub("Parbriz", (1.56, 0.04, 0.5), (0, -1.22, h0 + 0.94), GEAM, rot=(-0.35, 0, 0)))
		s.append(cub("Luneta", (1.4, 0.03, 0.4), (0, 0.51, h0 + 0.96), GEAM))
		s.append(cub("Bena", (1.7, 2.1, 0.06), (0, 1.5, h0 + 0.64), METAL_INCHIS))
		for x in (-0.85, 0.85):
			s.append(cub("Perete bena", (0.06, 2.1, 0.4), (x, 1.5, h0 + 0.82), culoare))
		s.append(cub("Oblon bena", (1.7, 0.06, 0.4), (0, 2.55, h0 + 0.82), culoare))
		s.append(cub("Anvelopa bena", (0.7, 0.7, 0.22), (0.3, 1.6, h0 + 0.78), NEGRU, rot=(0, 0, 0.4)))
		s.append(cub("Rugina", (0.5, 0.01, 0.2), (0.94, -1.4, h0 + 0.3), RUGINA))
	else:
		s.append(cub("Cabina", (1.66, 2.3, 0.56), (0, 0.25, h0 + 0.9), culoare))
		s.append(cub("Parbriz", (1.56, 0.04, 0.6), (0, -0.98, h0 + 0.88), GEAM if tip != "epava" else METAL, rot=(-0.6, 0, 0)))
		s.append(cub("Luneta", (1.5, 0.04, 0.5), (0, 1.48, h0 + 0.88), GEAM, rot=(0.6, 0, 0)))
		for y in (-0.25, 0.75):
			for x in (-0.835, 0.835):
				s.append(cub("Geam lateral", (0.02, 0.85, 0.36), (x, y, h0 + 0.92), GEAM if tip != "epava" or r.random() < 0.5 else NEGRU))
	if tip == "epava":
		# capota ridicată, motorul la vedere, roțile scoase, pe butuci de beton
		s.append(cub("Capota", (1.7, 1.3, 0.04), (0, -1.95, h0 + 1.1), culoare, rot=(-1.1, 0, 0)))
		s.append(cub("Motor", (1.1, 1.0, 0.4), (0, -1.7, h0 + 0.62), METAL_INCHIS))
		for x in (-0.72, 0.72):
			for y in (-1.5, 1.5):
				s.append(cub("Butuc", (0.38, 0.38, 0.28), (x, y, 0.14), BETON))
				s.append(cub("Aripa goala", (0.3, 0.8, 0.3), (x * 1.21, y, h0 + 0.12), NEGRU))
		for k in range(4):
			s.append(cub("Rugina", (r.uniform(0.2, 0.5), 0.012, r.uniform(0.1, 0.25)),
				(r.uniform(-0.6, 0.6), -L / 2 - 0.08 - k * 0.01 if k % 2 else L / 2 + 0.08 + k * 0.01, h0 + r.uniform(0.15, 0.5)), RUGINA))
	else:
		for x in (-0.86, 0.86):
			for y in (-L / 2 + 0.95, L / 2 - 0.95):
				platou = tip == "pickup" and x > 0 and y > 0
				s.append(cilindru("Roata", 0.34, 0.34, 0.24, (x, y, 0.34 if not platou else 0.26), NEGRU, laturi=10,
					rot=(0, 1.5708, 0), scara=(1, 1, 0.78) if platou else None))
				s.append(cilindru("Janta", 0.17, 0.17, 0.27, (x, y, 0.34 if not platou else 0.26), CROM, laturi=8, rot=(0, 1.5708, 0)))
	s.append(cub("Numar", (0.5, 0.01, 0.14), (0, L / 2 + 0.125, h0 + 0.2), AUR))
	col.append((1.95, L + 0.3, 1.5, 0.0, 0.0, 0.75))
	return s, col


def _plasa_gard(piese, a, b, h, r, poarta=None):
	"""Gard de plasă între a=(x,y) și b=(x,y): stâlpi, bara de sus, plasa (romburi din sârme pe diagonală)."""
	dx, dy = b[0] - a[0], b[1] - a[1]
	L = math.hypot(dx, dy)
	ux, uy = dx / L, dy / L
	unghi = math.atan2(dy, dx)
	n = max(1, int(L / 2.4))
	for k in range(n + 1):
		t = k / n
		piese.append(cilindru("Stalp gard", 0.035, 0.035, h + 0.05, (a[0] + dx * t, a[1] + dy * t, (h + 0.05) / 2), METAL, laturi=6))
	piese.append(cilindru("Bara gard", 0.022, 0.022, L, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, h), METAL, laturi=5,
		rot=(0, 1.5708, unghi)))
	pas = 0.22
	m = int(L / pas)
	for k in range(-int(h / pas), m + 1):
		for semn in (1, -1):
			# o sârmă în diagonală (45°) de la sol la bara de sus, tăiată la capetele gardului
			s0 = k * pas
			s1 = s0 + semn * h
			lo, hi = sorted((s0, s1))
			c0, c1 = max(lo, 0.0), min(hi, L)
			if c1 - c0 < 0.02:
				continue
			# punctele de pe sârmă la c0 și c1 (z crește liniar de-a lungul ei)
			def z_la(s):
				return (s - s0) / (s1 - s0) * h
			z0, z1 = z_la(c0), z_la(c1)
			p0 = (a[0] + ux * c0, a[1] + uy * c0, max(0.04, z0))
			p1 = (a[0] + ux * c1, a[1] + uy * c1, min(h - 0.02, z1))
			if poarta and poarta[0] < (c0 + c1) / 2 < poarta[1]:
				continue
			piese.append(os_intre("Sarma", p0, p1, 0.006, CROM, laturi=3))
	if r.random() < 1.0:
		# o bucată de plasă îndoită jos (cineva a trecut pe sub ea)
		t = r.uniform(0.3, 0.7)
		piese.append(cub("Plasa indoita", (0.6, 0.02, 0.25), (a[0] + dx * t, a[1] + dy * t, 0.12), CROM, rot=(0.6, 0, unghi)))


def _gunoi(piese, x, y, r, n=4, z=0.0):
	"""Mărunțișuri pe jos: mucuri de țigară, doze turtite, un pahar de plastic, hârtii."""
	for k in range(n):
		cx, cy = x + r.uniform(-0.6, 0.6), y + r.uniform(-0.4, 0.4)
		alege = r.random()
		if alege < 0.4:
			piese.append(cilindru("Muc", 0.006, 0.006, 0.03, (cx, cy, z + 0.006), ALB, laturi=4, rot=(0, 1.5708, r.uniform(0, 3))))
		elif alege < 0.7:
			piese.append(cilindru("Doza", 0.033, 0.033, 0.06, (cx, cy, z + 0.03), r.choice((ROSU, CROM, TEAL)), laturi=6,
				rot=(1.5708, 0, r.uniform(0, 3)), scara=(1, 0.5, 1)))
		else:
			piese.append(cub("Hartie", (0.12, 0.09, 0.005), (cx, cy, z + 0.004), r.choice((ALB, CROM, AUR)), rot=(0, 0, r.uniform(0, 3))))


def _loc_liber(ocupate, r, x0, x1, y0, y1, raza, evita=None, incercari=60):
	"""Un loc pe jos (x, y) unde un detaliu de `raza` nu atinge nimic din `ocupate` ([(x, y, raza)]), ca petele, petecele
	și crăpăturile să nu stea una peste alta: așa stau toate pe același strat (altfel `desparte_fete` le clădește una peste
	alta). `evita(x, y)` = True dacă locul e interzis. None dacă nu găsește."""
	for _ in range(incercari):
		x, y = r.uniform(x0, x1), r.uniform(y0, y1)
		if evita and evita(x, y):
			continue
		if all(math.hypot(x - a, y - b) > raza + rb for a, b, rb in ocupate):
			ocupate.append((x, y, raza))
			return x, y
	return None


# ---------------------------------------------------------------------------------------------------------------
# Aripa cu camere
# ---------------------------------------------------------------------------------------------------------------

def motel(cale):
	"""Aripa cu două etaje: fațada de stucco bej pătată, ușile și ferestrele camerelor (117–124, 217–224), pasarela de
	sus cu balustrada ruginită (o bucată ruptă), scara de la capăt, streașina de șindrilă, nișa cu automatul de gheață și
	cel de suc, graffiti pe capăt. Piese: `Motel`, `Lumini`, `Geamuri`, `Coliziune`."""
	curata()
	r = random.Random(122)
	piese, lumini, geamuri, col = [], [], [], []

	def strange():
		_ramas(piese, "Motel")

	# --- corpul (plin; în spate nu ajungi) și fațada cu goluri pentru uși și ferestre
	goluri = []
	for f in (0, 1):
		z0 = FL if f == 0 else E2
		for k in range(NR):
			x0 = XA + k * RW
			goluri.append((x0 + 0.45, x0 + 1.4, z0, z0 + 2.12))
			goluri.append((x0 + 1.85, x0 + 3.25, z0 + 0.95, z0 + 2.15))
	perete(piese, "Fatada", "x", XV0, XB, YF, YF + 0.25, 0.0, HT, TENCUIALA, goluri)
	piese.append(cub("Corp motel", (XB - XV0, YS - YF - 0.25, HT), ((XV0 + XB) / 2, (YF + 0.25 + YS) / 2, HT / 2), TENCUIALA))
	# în spatele golurilor: camera întunecată (nu se vede nimic înăuntru, doar perdeaua)
	for (a, b, za, zb) in goluri:
		piese.append(cub("Fund gol", (b - a, 0.02, zb - za), ((a + b) / 2, YF + 0.24, (za + zb) / 2), NEGRU))
	_cutie_coliziune(col, (XB - XV0, YS - YF, HT), ((XV0 + XB) / 2, (YF + YS) / 2, HT / 2))
	# soclul (dunga închisă de jos) și brâul dintre etaje
	piese.append(cub("Soclu", (XB - XV0 + 0.04, 0.27, 0.35), ((XV0 + XB) / 2, YF + 0.12, FL + 0.175), LEMN))
	piese.append(cub("Brau", (XB - XV0 + 0.04, 0.28, 0.12), ((XV0 + XB) / 2, YF + 0.12, E2 + 0.06), LEMN))
	# pete de apă, tencuială căzută (se vede blocul de BCA de dedesubt), dâre de rugină
	for k in range(26):
		x = r.uniform(XV0 + 0.3, XB - 0.3)
		z = r.choice((r.uniform(0.3, 2.8), r.uniform(E2 + 0.3, HT - 0.4)))
		if any(a - 0.05 < x < b + 0.05 and za - 0.05 < z < zb + 0.05 for (a, b, za, zb) in goluri):
			continue
		w, h = r.uniform(0.2, 0.8), r.uniform(0.2, 0.9)
		piese.append(cub("Pata", (w, 0.006, h), (x, YF - 0.012 - (k % 3) * 0.009, z), r.choice((TENCUIALA_PATA, TENCUIALA_PATA, BRONZ))))
		if r.random() < 0.3:
			piese.append(cub("Tencuiala cazuta", (w * 0.5, 0.008, h * 0.4), (x, YF - 0.045, z), BETON))
	strange()

	# --- camerele: ușile, ferestrele, numerele, lămpile
	for f in (0, 1):
		z0 = FL if f == 0 else E2
		for k in range(NR):
			x0 = XA + k * RW
			numar = 117 + k + 100 * f
			cul_usa = TEAL if r.random() < 0.8 else (LEMN_DESCHIS if r.random() < 0.5 else MOV)
			_usa_camera(piese, lumini, x0 + 0.45, z0, numar, cul_usa, r, nu_deranjati=numar in (122, 219),
				aprins=numar in LAMPI_APRINSE)
			if numar == 122:
				# camera Warlock-ului: perdeaua roșie, aprinsă din spate
				_fereastra_camera(piese, lumini, geamuri, x0 + 1.85, z0, ROSU, True, r, culoare_lumina=ROSU)
			elif numar in (120, 219):
				_fereastra_camera(piese, lumini, geamuri, x0 + 1.85, z0, LEMN, False, r, scanduri=True)
			else:
				_fereastra_camera(piese, lumini, geamuri, x0 + 1.85, z0, r.choice((ROSU, VERDE, MOV, AUR, LEMN, TEAL)),
					r.random() < 0.35, r)
		strange()

	# --- trotuarul de jos (sub pasarelă), cu bordura și crăpături
	piese.append(cub("Trotuar motel", (XB - XV0 + 6.6, YF - YP, FL), ((XV0 - 6.6 + XB) / 2, (YP + YF) / 2, FL / 2), BETON))
	piese.append(cub("Bordura", (XB - XV0 + 6.64, 0.12, FL + 0.02), ((XV0 - 6.6 + XB) / 2, YP + 0.05, FL / 2), METAL))
	_cutie_coliziune(col, (XB - XV0 + 6.6, YF - YP, FL), ((XV0 - 6.6 + XB) / 2, (YP + YF) / 2, FL / 2))
	ocupate = [((XV0 + XA) / 2 - 0.3, YF - 0.9, 0.6)]  # balta de lângă automatul de gheață
	for k in range(14):
		loc = _loc_liber(ocupate, r, XV0 - 6, XB, YP + 0.3, YF - 0.3, 0.75)
		if loc:
			piese.append(cub("Crapatura", (r.uniform(0.4, 1.4), 0.025, 0.004), (loc[0], loc[1], FL + 0.013),
				LEMN_INCHIS, rot=(0, 0, r.uniform(-0.8, 0.8))))
		loc = _loc_liber(ocupate, r, XV0 - 6, XB, YP + 0.3, YF - 0.3, 0.5)
		if loc:
			piese.append(cub("Pata trotuar", (r.uniform(0.3, 0.9), r.uniform(0.2, 0.6), 0.003), (loc[0], loc[1], FL + 0.013),
				r.choice((METAL_INCHIS, MASLINIU, LEMN))))

	# --- pasarela de sus: placa, grinda de margine, stâlpii, balustrada (cu o bucată ruptă)
	XP0 = XV0 - 0.8
	piese.append(cub("Pasarela", (XB - XP0, YF - YP, 0.18), ((XP0 + XB) / 2, (YP + YF) / 2, E2 - 0.09), BETON))
	piese.append(cub("Grinda pasarela", (XB - XP0 + 0.02, 0.22, 0.43), ((XP0 + XB) / 2, YP + 0.1, E2 - 0.185), TENCUIALA))
	piese.append(cub("Dunga grinda", (XB - XP0 + 0.06, 0.25, 0.08), ((XP0 + XB) / 2, YP + 0.1, E2 - 0.36), LEMN))
	_cutie_coliziune(col, (XB - XP0, YF - YP, 0.4), ((XP0 + XB) / 2, (YP + YF) / 2, E2 - 0.2))
	for x in [XP0 + 0.15] + [XA + k * RW for k in range(NR + 1)]:
		piese.append(cub("Stalp pasarela", (0.18, 0.18, E2 - 0.4), (x, YP + 0.2, (E2 - 0.4) / 2), METAL_INCHIS))
		piese.append(cub("Rugina stalp", (0.21, 0.21, 0.25), (x, YP + 0.2, 0.125), RUGINA))
		_cutie_coliziune(col, (0.2, 0.2, E2), (x, YP + 0.2, E2 / 2))
	rupt = (XA + 5.2 * RW - 0.4, XA + 5.2 * RW + 0.9)  # deasupra camerei 122-ish: balustrada ruptă
	yb = YP + 0.06
	for (a, b) in ((XP0, rupt[0]), (rupt[1], XB)):
		piese.append(cub("Mana curenta", (b - a, 0.06, 0.05), ((a + b) / 2, yb, E2 + 1.0), METAL_INCHIS))
		piese.append(cub("Bara mijloc", (b - a, 0.03, 0.03), ((a + b) / 2, yb, E2 + 0.1), METAL_INCHIS))
	x = XP0 + 0.1
	while x < XB:
		if not (rupt[0] < x < rupt[1]):
			piese.append(cub("Baluster", (0.02, 0.02, 0.9), (x, yb, E2 + 0.55), METAL_INCHIS if r.random() < 0.85 else RUGINA))
		x += 0.14
	# bucata ruptă: mâna curentă atârnă în jos, doi baluștri îndoiți
	piese.append(cub("Mana curenta rupta", (1.3, 0.06, 0.05), (rupt[0] + 0.55, yb - 0.05, E2 + 0.7), RUGINA, rot=(0, 0.45, 0)))
	piese.append(cub("Baluster indoit", (0.02, 0.02, 0.8), (rupt[0] + 0.3, yb - 0.12, E2 + 0.4), RUGINA, rot=(0.5, 0, 0)))
	piese.append(cub("Banda avertizare", (rupt[1] - rupt[0], 0.01, 0.06), ((rupt[0] + rupt[1]) / 2, yb, E2 + 0.85), AUR, rot=(0, 0.04, 0)))
	_cutie_coliziune(col, (XB - XP0, 0.12, 1.2), ((XP0 + XB) / 2, yb, E2 + 0.6))
	# capătul pasarelei (spre scară): balustradă pe lateral, cu deschiderea scării
	piese.append(cub("Mana curenta", (0.06, 0.4, 0.05), (XP0 + 0.03, YP + 0.2, E2 + 1.0), METAL_INCHIS))
	piese.append(cub("Mana curenta", (0.06, 0.4, 0.05), (XP0 + 0.03, YF - 0.2, E2 + 1.0), METAL_INCHIS))
	_cutie_coliziune(col, (0.1, 0.4, 1.2), (XP0 + 0.03, YP + 0.2, E2 + 0.6))
	_cutie_coliziune(col, (0.1, 0.4, 1.2), (XP0 + 0.03, YF - 0.2, E2 + 0.6))
	strange()

	# --- scara: de la x XS0 (jos) la XP0 (sus), lată de 1,2 m între y 8,4 și 9,6; treptele, vangurile, balustrada
	trepte = 18
	XS0 = XP0 - trepte * 0.32
	ys0, ys1 = YP + 0.4, YP + 1.6
	for k in range(trepte):
		xa = XS0 + k * 0.32
		z = (k + 1) * E2 / trepte
		piese.append(cub("Treapta", (0.34, ys1 - ys0, 0.05), (xa + 0.16, (ys0 + ys1) / 2, z - 0.025), BETON if k % 5 else METAL))
		piese.append(cub("Contratreapta", (0.02, ys1 - ys0, E2 / trepte - 0.05), (xa + 0.01, (ys0 + ys1) / 2, z - 0.05 - (E2 / trepte - 0.05) / 2),
			METAL_INCHIS))
	for y in (ys0 - 0.04, ys1 + 0.04):
		lung = math.hypot(XP0 - XS0, E2)
		unghi = math.atan2(E2, XP0 - XS0)
		piese.append(cub("Vang", (lung, 0.06, 0.25), ((XS0 + XP0) / 2, y, E2 / 2 - 0.1), METAL_INCHIS, rot=(0, -unghi, 0)))
		piese.append(cub("Balustrada scara", (lung, 0.05, 0.05), ((XS0 + XP0) / 2, y, E2 / 2 + 0.95), RUGINA, rot=(0, -unghi, 0)))
		for k in range(0, trepte, 3):
			xa = XS0 + k * 0.32 + 0.16
			z = (k + 1) * E2 / trepte
			piese.append(cub("Stalp balustrada", (0.035, 0.035, 0.95), (xa, y, z + 0.47), METAL_INCHIS))
		_cutie_coliziune(col, (lung, 0.1, 1.3), ((XS0 + XP0) / 2, y, E2 / 2 + 0.55))
	piese.append(cub("Stalp scara", (0.16, 0.16, E2), (XS0 + 2.2, ys1 + 0.15, E2 / 2 - 0.4), METAL_INCHIS))
	# coliziunea scării: o rampă, ca la verandele din joc (treptele te-ar opri)
	col.append(prisma("Coliziune", [(XS0 - 0.25, 0.0), (XP0, E2), (XP0, 0.0)], "xz", ys0, ys1, NEGRU))
	# un panou sub scară: „NO LOITERING” (nimeni nu-l bagă în seamă)
	piese.append(cub("Panou", (0.6, 0.02, 0.4), (XS0 + 3.5, ys1 + 0.3, 1.2), ALB))
	piese.append(_text("Scris panou", "NO\nLOITERING", (XS0 + 3.5, ys1 + 0.29, 1.2), 0.1, ROSU))
	strange()

	# --- streașina de șindrilă deasupra pasarelei de sus și acoperișul
	piese.append(prisma("Streasina", [(YF + 0.3, HT + 0.55), (YP - 0.45, HT - 0.3), (YP - 0.45, HT - 0.45), (YF + 0.3, HT + 0.4)],
		"yz", XP0 - 0.3, XB, SINDRILA))
	panta = math.atan2(0.85, YF + 0.3 - (YP - 0.45))
	lung = math.hypot(0.85, YF + 0.3 - (YP - 0.45))
	for k in range(9):
		t = (k + 0.5) / 9
		y = (YP - 0.45) + t * (YF + 0.3 - (YP - 0.45))
		z = (HT - 0.3) + t * 0.85 + 0.008
		piese.append(cub("Rand sindrila", (XB - XP0 + 0.3, 0.025, 0.02), ((XP0 - 0.3 + XB) / 2, y, z), LEMN, rot=(panta, 0, 0)))
	for k in range(7):
		# șindrile lipsă / înlocuite cu altă culoare
		x = r.uniform(XP0, XB - 1)
		t = r.uniform(0.15, 0.85)
		piese.append(cub("Sindrila lipsa", (r.uniform(0.4, 1.0), lung * 0.12, 0.012),
			(x, (YP - 0.45) + t * (YF + 0.3 - (YP - 0.45)), (HT - 0.3) + t * 0.85 + 0.012), r.choice((BRONZ, NEGRU, LEMN_DESCHIS)),
			rot=(panta, 0, 0)))
	piese.append(cub("Jgheab", (XB - XP0 + 0.3, 0.14, 0.12), ((XP0 - 0.3 + XB) / 2, YP - 0.5, HT - 0.4), METAL))
	piese.append(cub("Burlan", (0.1, 0.1, HT - 0.4), (XP0 - 0.2, YP - 0.5, (HT - 0.4) / 2), METAL))
	piese.append(cub("Acoperis", (XB - XV0 + 0.2, YS - YF + 0.3, 0.3), ((XV0 + XB) / 2, (YF + YS) / 2 + 0.15, HT + 0.15), METAL_INCHIS))
	for x in (-12.0, 2.0):
		piese.append(cub("Unitate AC", (1.2, 1.0, 0.8), (x, 14.5, HT + 0.7), BETON))
		piese.append(cilindru("Ventilator AC", 0.35, 0.35, 0.05, (x, 14.5, HT + 1.12), METAL_INCHIS, laturi=10))
	strange()

	# --- nișa cu automatele (între capăt și prima cameră)
	nx = (XV0 + XA) / 2
	piese.append(cub("Automat gheata", (0.8, 0.7, 1.55), (nx - 0.38, YF - 0.37, FL + 0.775), CROM))
	piese.append(cub("Usa gheata", (0.6, 0.02, 0.5), (nx - 0.38, YF - 0.73, FL + 1.1), METAL))
	piese.append(_text("Scris gheata", "ICE", (nx - 0.38, YF - 0.74, FL + 1.42), 0.14, TEAL))
	piese.append(cub("Balta", (0.9, 0.7, 0.004), (nx - 0.3, YF - 0.9, FL + 0.002), GEAM))
	piese.append(cub("Automat suc", (0.85, 0.75, 1.85), (nx + 0.38, YF - 0.4, FL + 0.925), ROSU))
	lumini.append(cub("Panou suc", (0.55, 0.02, 1.2), (nx + 0.3, YF - 0.785, FL + 1.1), ALB))
	piese.append(_text("Scris suc", "COLA", (nx + 0.3, YF - 0.8, FL + 1.3), 0.13, ROSU))
	for k in range(6):
		piese.append(cub("Buton suc", (0.08, 0.02, 0.1), (nx + 0.67, YF - 0.79, FL + 1.5 - k * 0.13), NEGRU if k != 2 else AUR))
	piese.append(cub("Hartie lipita", (0.2, 0.005, 0.15), (nx + 0.3, YF - 0.79, FL + 0.7), ALB, rot=(0, 0.1, 0)))
	piese.append(_text_o_fata("Out of order", "BROKEN", (nx + 0.3, YF - 0.795, FL + 0.7), 0.04, ROSU))
	_cutie_coliziune(col, (1.65, 0.8, 1.9), (nx, YF - 0.4, FL + 0.95))

	# --- scaunul de plastic din fața camerei 120, cu scrumiera plină și doze de bere
	sx = XA + 3 * RW + 2.4
	scaun = [cub("Sezut", (0.46, 0.44, 0.04), (0, 0, 0.44), ALB), cub("Spatar", (0.46, 0.04, 0.45), (0, 0.22, 0.7), ALB, rot=(-0.15, 0, 0))]
	for dx in (-0.2, 0.2):
		for dy in (-0.19, 0.19):
			scaun.append(cub("Picior", (0.035, 0.035, 0.44), (dx, dy, 0.22), ALB))
	piese.append(_obiect(scaun, (sx, YF - 0.8, FL), (0, 0, 0.4)))
	piese.append(cilindru("Scrumiera", 0.07, 0.06, 0.04, (sx + 0.45, YF - 0.7, FL + 0.02), METAL, laturi=8))
	for k in range(6):
		piese.append(cilindru("Muc", 0.006, 0.006, 0.03, (sx + 0.45 + r.uniform(-0.04, 0.04), YF - 0.7 + r.uniform(-0.04, 0.04),
			FL + 0.045), ALB, laturi=4, rot=(0, 1.3, r.uniform(0, 3))))
	_cutie_coliziune(col, (0.5, 0.5, 0.9), (sx, YF - 0.8, FL + 0.45))
	for k in range(NR):
		_gunoi(piese, XA + k * RW + 1.6, YP + 0.9, r, n=r.randint(1, 4), z=FL)

	# --- graffiti pe capătul aripii (peretele dinspre scară)
	gx = XV0 - 0.01
	piese.append(_text_o_fata("Graffiti", "TONY + TINA", (gx, 14.5, 1.6), 0.45, MOV, rot=(1.5708, 0, -1.5708)))
	piese.append(_text_o_fata("Graffiti", "666", (gx, 12.2, 2.4), 0.6, ROSU, rot=(1.5708, 0, -1.5708)))
	piese.append(_text_o_fata("Graffiti", "NO SLEEP", (gx, 16.0, 4.4), 0.38, NEGRU, rot=(1.5708, 0, -1.5708)))
	strange()

	uneste(piese, "Motel")
	uneste(lumini, "Lumini")
	uneste(geamuri, "Geamuri")
	uneste(col, "Coliziune")
	# structura nu se mută; petele, plăcuțele, scândurile, literele se desprind de ea
	desparte_fete(fixe=("Fatada", "Corp motel", "Trotuar motel", "Pasarela", "Acoperis", "Streasina", "Soclu", "Fund gol"))
	exporta(os.path.join(cale, "motel_cladire.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Recepția („OFFICE”)
# ---------------------------------------------------------------------------------------------------------------

def _scaun_vinil(cul, r):
	"""Fotoliu de așteptare cu vinil rupt (se vede buretele galben), în origine, cu fața spre -Y."""
	s = [cub("Sezut vinil", (0.6, 0.55, 0.14), (0, 0, 0.42), cul), cub("Spatar vinil", (0.6, 0.14, 0.5), (0, 0.24, 0.72), cul),
		cub("Cotiera", (0.08, 0.55, 0.22), (-0.3, 0, 0.55), CROM), cub("Cotiera", (0.08, 0.55, 0.22), (0.3, 0, 0.55), CROM),
		cub("Burete", (0.18, 0.14, 0.01), (r.uniform(-0.12, 0.12), r.uniform(-0.1, 0.1), 0.495), AUR, rot=(0, 0, r.uniform(0, 3))),
		cub("Bandă scotch", (0.22, 0.05, 0.005), (r.uniform(-0.1, 0.1), -0.05, 0.494), CROM, rot=(0, 0, 0.5))]
	for dx in (-0.26, 0.26):
		for dy in (-0.22, 0.22):
			s.append(cub("Picior fotoliu", (0.04, 0.04, 0.35), (dx, dy, 0.175), CROM))
	return s


def receptie(cale):
	"""Recepția: clădirea mică de la capătul din dreapta (ușa de sticlă, vitrina cu neonul „OPEN 24 HRS”, firma „OFFICE”,
	copertina, lampa anti-țânțari), iar înăuntru holul jegos și tejgheaua cu geam antiglonț, în spatele căreia stă
	receptionera (panoul cu chei, cu cârligul camerei 122 gol). Piese: `Receptie`, `Lumini`, `Geamuri`, `Coliziune`."""
	curata()
	r = random.Random(77)
	piese, lumini, geamuri, col = [], [], [], []

	def strange():
		_ramas(piese, "Receptie")

	ix0, ix1, iy0 = OX0 + OG, OX1 - OG, OY0 + OG
	# --- podeaua: placa, mocheta pătată cu romburi (holul), linoleum în spatele tejghelei
	piese.append(cub("Placa receptie", (OX1 - OX0 - 0.04, OY1 - OY0 - 0.04, FL - 0.012), ((OX0 + OX1) / 2, (OY0 + OY1) / 2, (FL - 0.012) / 2), BETON))
	_cutie_coliziune(col, (OX1 - OX0, OY1 - OY0, FL), ((OX0 + OX1) / 2, (OY0 + OY1) / 2, FL / 2))
	piese.append(cub("Mocheta", (ix1 - ix0, TY0 - iy0, 0.012), ((ix0 + ix1) / 2, (iy0 + TY0) / 2, FL + 0.006), TEAL))
	# romburile și petele stau pe un singur strat, 10 mm peste mochetă: unde e o pată (sau preșul), lipsește rombul
	pe_mocheta = FL + 0.022
	ocupate = [((OUSA[0] + OUSA[1]) / 2, iy0 + 0.45, 0.7)]
	for k in range(9):
		raza = r.uniform(0.12, 0.4)
		loc = _loc_liber(ocupate, r, ix0 + 0.4, ix1 - 0.4, iy0 + 0.4, TY0 - 0.3, raza)
		if loc:
			piese.append(cilindru("Pata mocheta", raza, raza, 0.004, (loc[0], loc[1], pe_mocheta - 0.002),
				r.choice((LEMN_INCHIS, LEMN, MASLINIU)), laturi=8, scara=(1, r.uniform(0.5, 1.0), 1)))
	for i in range(int((ix1 - ix0) / 0.7)):
		for j in range(int((TY0 - iy0) / 0.7)):
			x, y = ix0 + 0.35 + i * 0.7, iy0 + 0.35 + j * 0.7
			if all(math.hypot(x - a, y - b) > 0.12 + rb for a, b, rb in ocupate):
				piese.append(cub("Romb mocheta", (0.16, 0.16, 0.004), (x, y, pe_mocheta - 0.002), MOV, rot=(0, 0, 0.785)))
	piese.append(cub("Pres", (1.2, 0.7, 0.015), ((OUSA[0] + OUSA[1]) / 2, iy0 + 0.45, FL + 0.0195), LEMN_INCHIS))
	piese.append(_text_o_fata("Welcome", "WELCOME", ((OUSA[0] + OUSA[1]) / 2, iy0 + 0.45, FL + 0.037), 0.12, BRONZ, rot=(0, 0, 0)))
	piese.append(cub("Linoleum", (ix1 - ix0, PERETE_SPATE - TY1, 0.01), ((ix0 + ix1) / 2, (TY1 + PERETE_SPATE) / 2, FL + 0.005), BETON))

	# --- pereții, cu ușa, vitrina și câte o fereastră pe laterale
	perete(piese, "Perete receptie", "x", OX0, OX1, OY0, OY0 + OG, 0.0, OT, TENCUIALA, [OUSA, OVITRINA])
	perete(col, "Coliziune", "x", OX0, OX1, OY0, OY0 + OG, 0.0, OT, NEGRU, [OUSA])
	geamuri.append(cub("Geam vitrina", (OVITRINA[1] - OVITRINA[0], 0.02, OVITRINA[3] - OVITRINA[2]),
		((OVITRINA[0] + OVITRINA[1]) / 2, OY0 + OG / 2, (OVITRINA[2] + OVITRINA[3]) / 2), GEAM))
	piese.append(cub("Rama vitrina", (OVITRINA[1] - OVITRINA[0] + 0.1, OG + 0.04, 0.08),
		((OVITRINA[0] + OVITRINA[1]) / 2, OY0 + OG / 2, OVITRINA[2] - 0.03), CROM))
	piese.append(cub("Montant vitrina", (0.06, OG + 0.04, OVITRINA[3] - OVITRINA[2]),
		((OVITRINA[0] + OVITRINA[1]) / 2, OY0 + OG / 2, (OVITRINA[2] + OVITRINA[3]) / 2), CROM))
	ferestre_v = [(6.4, 8.8, 1.0, 2.2)]
	perete(piese, "Perete receptie", "y", OY0 + OG, OY1 - OG, OX0, OX0 + OG, 0.0, OT, TENCUIALA, ferestre_v)
	perete(piese, "Perete receptie", "y", OY0 + OG, OY1 - OG, OX1 - OG, OX1, 0.0, OT, TENCUIALA, [(6.6, 8.6, 1.0, 2.2)])
	perete(piese, "Perete receptie", "x", OX0, OX1, OY1 - OG, OY1, 0.0, OT, TENCUIALA)
	for (a, b, za, zb) in ferestre_v:
		geamuri.append(cub("Geam lateral", (0.02, b - a, zb - za), (OX0 + OG / 2, (a + b) / 2, (za + zb) / 2), GEAM))
		piese.append(cub("Jaluzea", (0.03, b - a, (zb - za) * 0.6), (OX0 + OG + 0.02, (a + b) / 2, zb - (zb - za) * 0.3), CROM))
	geamuri.append(cub("Geam lateral", (0.02, 2.0, 1.2), (OX1 - OG / 2, 7.6, 1.6), GEAM))
	piese.append(cub("Jaluzea strambă", (0.03, 2.0, 0.9), (OX1 - OG - 0.02, 7.6, 1.75), CROM, rot=(0.12, 0, 0)))
	_cutie_coliziune(col, (OG, OY1 - OY0, OT), (OX0 + OG / 2, (OY0 + OY1) / 2, OT / 2))
	_cutie_coliziune(col, (OG, OY1 - OY0, OT), (OX1 - OG / 2, (OY0 + OY1) / 2, OT / 2))
	_cutie_coliziune(col, (OX1 - OX0, OG, OT), ((OX0 + OX1) / 2, OY1 - OG / 2, OT / 2))
	# lambriul de jos și pata de apă care curge din tavan pe perete
	# (pe peretele din față doar de o parte și de alta a ușii: dintr-o bucată trecea prin golul ușii)
	for (a, b) in ((ix0, OUSA[0] - 0.02), (OUSA[1] + 0.02, ix1)):
		piese.append(cub("Lambriu", (b - a, 0.02, 0.9), ((a + b) / 2, iy0 + 0.01, FL + 0.45), LEMN))
	piese.append(cub("Lambriu", (0.02, TY0 - iy0 - 0.04, 0.9), (ix0 + 0.01, (iy0 + TY0) / 2 + 0.02, FL + 0.45), LEMN))
	piese.append(cub("Lambriu", (0.02, TY0 - iy0 - 0.04, 0.9), (ix1 - 0.01, (iy0 + TY0) / 2 + 0.02, FL + 0.45), LEMN))
	piese.append(cub("Pata apa perete", (0.02, 1.1, 1.4), (ix1 - 0.012, 9.4, OH - 0.7), TENCUIALA_PATA))
	piese.append(cub("Pata apa perete", (0.6, 0.02, 0.9), (ix0 + 1.2, iy0 + 0.012, OH - 0.45), TENCUIALA_PATA))
	strange()

	# --- tavanul casetat: plăci pătate, una căzută (gaura neagră), una lăsată, neoanele
	piese.append(cub("Tavan", (ix1 - ix0, OY1 - OG - iy0, 0.02), ((ix0 + ix1) / 2, (iy0 + OY1 - OG) / 2, OH + 0.01), CROM))
	x = ix0
	while x < ix1 + 0.01:
		piese.append(cub("Profil tavan", (0.025, OY1 - OG - iy0, 0.02), (x, (iy0 + OY1 - OG) / 2, OH - 0.005), METAL))
		x += 0.6
	y = iy0
	while y < OY1:
		piese.append(cub("Profil tavan", (ix1 - ix0, 0.025, 0.02), ((ix0 + ix1) / 2, y, OH - 0.005), METAL))
		y += 0.6
	for k in range(7):
		i, j = r.randint(0, 10), r.randint(0, 7)
		piese.append(cub("Placa patata", (0.5, 0.5, 0.004), (ix0 + 0.3 + i * 0.6, iy0 + 0.3 + j * 0.6, OH - 0.012),
			r.choice((BRONZ, MASLINIU, AUR))))
	piese.append(cub("Placa lipsa", (0.56, 0.56, 0.006), (ix0 + 0.3 + 2 * 0.6, iy0 + 0.3 + 5 * 0.6, OH - 0.014), NEGRU))
	piese.append(cub("Placa lasata", (0.56, 0.56, 0.02), (ix0 + 0.3 + 6 * 0.6, iy0 + 0.3 + 2 * 0.6, OH - 0.12), CROM, rot=(0.25, 0, 0)))
	for (nx, ny) in ((12.4, 7.6), (15.2, 7.6), (13.8, 11.5)):
		piese.append(cub("Corp neon", (1.25, 0.32, 0.06), (nx, ny, OH - 0.03), METAL))
		lumini.append(cub("Neon", (1.15, 0.24, 0.02), (nx, ny, OH - 0.07), ALB))
	piese.append(cub("Mustele moarte", (0.3, 0.12, 0.005), (15.0, 7.62, OH - 0.081), NEGRU))
	piese.append(cub("Acoperis receptie", (OX1 - OX0 + 0.2, OY1 - OY0 + 0.2, 0.2), ((OX0 + OX1) / 2, (OY0 + OY1) / 2, OT + 0.1), METAL_INCHIS))
	piese.append(cub("Atic", (OX1 - OX0 + 0.24, 0.2, 0.45), ((OX0 + OX1) / 2, OY0 - 0.02, OT + 0.2), LEMN))
	strange()

	# --- tejgheaua: lambriu, blatul, geamul antiglonț până în tavan (cu fanta de bani și difuzorul), soneria
	piese.append(cub("Tejghea", (ix1 - ix0, TY1 - TY0, TZ - FL), ((ix0 + ix1) / 2, (TY0 + TY1) / 2, (FL + TZ) / 2), LEMN))
	for k in range(int((ix1 - ix0) / 0.3)):
		piese.append(cub("Sipca tejghea", (0.02, 0.01, TZ - FL - 0.2), (ix0 + 0.15 + k * 0.3, TY0 - 0.005, (FL + TZ) / 2 + 0.05), LEMN_INCHIS))
	piese.append(cub("Plinta tejghea", (ix1 - ix0, 0.03, 0.12), ((ix0 + ix1) / 2, TY0 - 0.01, FL + 0.06), NEGRU))
	piese.append(cub("Blat", (ix1 - ix0, TY1 - TY0 + 0.25, 0.04), ((ix0 + ix1) / 2, (TY0 + TY1) / 2 - 0.12, TZ + 0.02), BRONZ))
	piese.append(cub("Zgarieturi blat", (0.8, 0.12, 0.003), (12.2, TY0 - 0.12, TZ + 0.042), AUR, rot=(0, 0, 0.2)))
	_cutie_coliziune(col, (ix1 - ix0, TY1 - TY0 + 0.25, TZ), ((ix0 + ix1) / 2, (TY0 + TY1) / 2 - 0.12, TZ / 2))
	gy = TY0 + 0.04
	geamuri.append(cub("Geam antiglont", (ix1 - ix0, 0.03, OH - TZ - 0.12), ((ix0 + ix1) / 2, gy, (TZ + 0.12 + OH) / 2), GEAM))
	piese.append(cub("Rama geam", (ix1 - ix0, 0.06, 0.08), ((ix0 + ix1) / 2, gy, TZ + 0.08), CROM))
	piese.append(cub("Rama geam", (ix1 - ix0, 0.06, 0.08), ((ix0 + ix1) / 2, gy, OH - 0.04), CROM))
	for x in (ix0 + 0.03, 12.3, 15.2, ix1 - 0.03):
		piese.append(cub("Montant geam", (0.06, 0.09, OH - TZ - 0.02), (x, gy, (TZ + OH) / 2), CROM))
	# fanta de bani (tava coborâtă sub geam) și difuzorul rotund
	piese.append(cub("Tava bani", (0.36, 0.34, 0.02), (RX, gy, TZ + 0.05), METAL))
	piese.append(cub("Gaura tava", (0.3, 0.3, 0.004), (RX, gy, TZ + 0.07), NEGRU))
	piese.append(cilindru("Difuzor", 0.07, 0.07, 0.012, (RX + 0.45, gy - 0.02, TZ + 0.28), METAL, laturi=10, rot=(1.5708, 0, 0)))
	for k in range(3):
		piese.append(cub("Fanta difuzor", (0.09, 0.004, 0.008), (RX + 0.45, gy - 0.027, TZ + 0.26 + k * 0.022), NEGRU))
	piese.append(_text_o_fata("Bell", "PLEASE RING\nBELL", (RX + 0.95, gy - 0.02, 1.62), 0.055, ROSU, rot=(1.5708, 0, 0)))
	piese.append(_text_o_fata("Refunds", "NO REFUNDS", (RX - 1.0, gy - 0.02, 1.95), 0.07, ROSU, rot=(1.5708, 0, 0)))
	piese.append(cilindru("Sonerie", 0.045, 0.05, 0.02, (RX + 0.5, TY0 - 0.15, TZ + 0.05), METAL_INCHIS, laturi=10))
	piese.append(sfera("Clopot sonerie", 0.04, (RX + 0.5, TY0 - 0.15, TZ + 0.065), CROM, scara=(1, 1, 0.7), segmente=10, inele=4))
	piese.append(cub("Pix legat", (0.14, 0.012, 0.012), (RX - 0.55, TY0 - 0.18, TZ + 0.05), NEGRU, rot=(0, 0, 0.4)))
	piese.append(os_intre("Lantisor pix", (RX - 0.5, TY0 - 0.15, TZ + 0.05), (RX - 0.42, TY0 - 0.04, TZ + 0.06), 0.003, CROM, laturi=3))
	piese.append(cub("Suport brosuri", (0.3, 0.12, 0.25), (RX - 1.6, TY0 - 0.15, TZ + 0.165), CROM))
	for k in range(3):
		piese.append(cub("Brosura", (0.08, 0.02, 0.2), (RX - 1.7 + k * 0.1, TY0 - 0.15, TZ + 0.2), (AUR, TURCOAZ, ROSU)[k]))
	strange()

	# --- în spatele tejghelei: scaunul ei, biroul cu monitorul vechi, sertarul, cafeaua, revista, scrumiera cu ruj
	piese.append(cilindru("Scaun receptionera", 0.2, 0.2, 0.07, (RX, RY + 0.1, FL + 0.72), MOV, laturi=10))
	piese.append(cilindru("Picior scaun", 0.03, 0.03, 0.7, (RX, RY + 0.1, FL + 0.35), CROM, laturi=6))
	piese.append(cilindru("Baza scaun", 0.25, 0.25, 0.04, (RX, RY + 0.1, FL + 0.02), CROM, laturi=5))
	piese.append(cub("Birou spate", (2.2, 0.6, 0.05), (15.8, PERETE_SPATE - 0.32, FL + 0.9), LEMN))
	piese.append(cub("Picior birou", (0.05, 0.55, 0.88), (14.75, PERETE_SPATE - 0.32, FL + 0.45), LEMN_INCHIS))
	piese.append(cub("Picior birou", (0.05, 0.55, 0.88), (16.85, PERETE_SPATE - 0.32, FL + 0.45), LEMN_INCHIS))
	piese.append(cub("Monitor", (0.42, 0.4, 0.36), (15.3, PERETE_SPATE - 0.35, FL + 1.11), AUR))
	lumini.append(cub("Ecran monitor", (0.3, 0.01, 0.23), (15.3, PERETE_SPATE - 0.556, FL + 1.12), NEON))
	piese.append(cub("Tastatura", (0.42, 0.15, 0.025), (15.3, PERETE_SPATE - 0.75, FL + 0.94), AUR))
	piese.append(cilindru("Cana", 0.045, 0.04, 0.1, (16.1, PERETE_SPATE - 0.35, FL + 0.975), ALB, laturi=8))
	piese.append(_text_o_fata("Cana scris", "#1", (16.1, PERETE_SPATE - 0.396, FL + 0.98), 0.03, ROSU))
	piese.append(cub("Revista", (0.22, 0.3, 0.01), (RX + 0.35, TY1 - 0.12, TZ + 0.045), ROSU, rot=(0, 0, 0.3)))
	piese.append(cilindru("Scrumiera", 0.07, 0.06, 0.035, (RX - 0.45, TY1 - 0.1, TZ + 0.06), METAL, laturi=8))
	for k in range(5):
		piese.append(cilindru("Muc ruj", 0.006, 0.006, 0.035, (RX - 0.45 + r.uniform(-0.04, 0.04), TY1 - 0.1 + r.uniform(-0.04, 0.04),
			TZ + 0.085), ALB if k % 2 else ROSU, laturi=4, rot=(0, 1.3, r.uniform(0, 3))))
	# lampa de birou (îi luminează fața de jos, ca într-un film prost)
	piese.append(cilindru("Baza lampa birou", 0.07, 0.08, 0.02, (RX - 0.75, TY1 - 0.15, TZ + 0.05), METAL_INCHIS, laturi=8))
	piese.append(os_intre("Gat lampa birou", (RX - 0.75, TY1 - 0.15, TZ + 0.06), (RX - 0.62, TY1 - 0.25, TZ + 0.38), 0.012, METAL_INCHIS, laturi=4))
	piese.append(cilindru("Abajur", 0.05, 0.09, 0.1, (RX - 0.58, TY1 - 0.27, TZ + 0.36), TEAL, laturi=8, rot=(0.6, 0, 0.5)))
	lumini.append(sfera("Bec lampa birou", 0.03, (RX - 0.57, TY1 - 0.28, TZ + 0.32), AUR, segmente=6, inele=4))
	piese.append(cub("Ventilator birou", (0.25, 0.12, 0.3), (16.6, PERETE_SPATE - 0.35, FL + 1.08), CROM))
	# peretele din spate, cu ușa „PRIVATE” și panoul cu chei (cârligul camerei 122 gol)
	perete(piese, "Perete spate", "x", ix0, ix1, PERETE_SPATE, PERETE_SPATE + 0.12, FL, OH, PERETE, [(16.0, 16.95, FL, FL + 2.1)])
	piese.append(cub("Usa private", (0.95, 0.04, 2.1), (16.475, PERETE_SPATE - 0.01, FL + 1.05), LEMN))
	piese.append(_text("Private", "PRIVATE", (16.475, PERETE_SPATE - 0.04, FL + 1.6), 0.09, ALB))
	piese.append(cub("Clanta", (0.08, 0.04, 0.03), (16.85, PERETE_SPATE - 0.05, FL + 1.0), CROM))
	piese.append(cub("Panou chei", (1.6, 0.03, 0.9), (13.1, PERETE_SPATE - 0.02, FL + 1.75), LEMN_DESCHIS))
	for i in range(8):
		for j in range(2):
			numar = 117 + i + (1 - j) * 100
			cx, cz = 12.45 + i * 0.185, FL + 2.0 - j * 0.45
			piese.append(cub("Carlig", (0.012, 0.03, 0.012), (cx, PERETE_SPATE - 0.045, cz), CROM))
			piese.append(_text_o_fata("Numar cheie", str(numar), (cx, PERETE_SPATE - 0.036, cz + 0.06), 0.035, NEGRU))
			if numar in (122, 219, 121):
				continue  # cheia 122 e la Warlock (și alte două camere ocupate)
			piese.append(cub("Breloc", (0.06, 0.012, 0.09), (cx, PERETE_SPATE - 0.05, cz - 0.08), r.choice((ROSU, TEAL, AUR, VERDE)),
				rot=(0, 0.785, 0)))
			piese.append(cub("Cheie", (0.012, 0.006, 0.05), (cx, PERETE_SPATE - 0.05, cz - 0.15), CROM))
	piese.append(cilindru("Ceas perete", 0.16, 0.16, 0.04, (14.6, PERETE_SPATE - 0.03, FL + 2.45), ALB, laturi=12, rot=(1.5708, 0, 0)))
	piese.append(cub("Limba ceas", (0.01, 0.01, 0.11), (14.6, PERETE_SPATE - 0.055, FL + 2.48), NEGRU, rot=(0, 0.4, 0)))
	piese.append(cub("Limba ceas", (0.01, 0.01, 0.08), (14.6, PERETE_SPATE - 0.055, FL + 2.43), NEGRU, rot=(0, -2.0, 0)))
	piese.append(cub("Afis checkout", (0.5, 0.01, 0.3), (11.4, PERETE_SPATE - 0.02, FL + 1.9), ALB))
	piese.append(_text_o_fata("Checkout", "CHECK OUT\n11 AM", (11.4, PERETE_SPATE - 0.026, FL + 1.9), 0.06, NEGRU))
	# televizorul cu purici pe consolă, în colț, întors spre ea
	piese.append(cub("Consola tv", (0.4, 0.4, 0.05), (ix1 - 0.3, TY1 + 0.3, FL + 2.3), METAL_INCHIS))
	piese.append(cub("Televizor", (0.5, 0.42, 0.4), (ix1 - 0.32, TY1 + 0.3, FL + 2.53), LEMN_INCHIS, rot=(0, 0, 0.6)))
	lumini.append(cub("Purici", (0.36, 0.01, 0.28), (ix1 - 0.47, TY1 + 0.12, FL + 2.53), CROM, rot=(0, 0, 0.6)))
	strange()

	# --- holul: fotoliile de vinil, măsuța cu reviste, planta moartă, automatul de gustări, cafeaua stricată, coșul plin
	for (fx, fy, fr, cul) in ((10.75, 8.2, 1.5708, MOV), (10.75, 7.3, 1.5708, ROSU)):
		piese.append(_obiect(_scaun_vinil(cul, r), (fx, fy, FL), (0, 0, -fr)))
		_cutie_coliziune(col, (0.6, 0.6, 0.85), (fx, fy, FL + 0.42))
	piese.append(cub("Masuta", (0.5, 0.5, 0.04), (10.75, 6.45, FL + 0.48), LEMN))
	piese.append(cub("Picior masuta", (0.05, 0.05, 0.48), (10.75, 6.45, FL + 0.24), CROM))
	for k in range(3):
		piese.append(cub("Revista veche", (0.2, 0.27, 0.008), (10.75 + r.uniform(-0.08, 0.08), 6.45 + r.uniform(-0.06, 0.06),
			FL + 0.505 + k * 0.009), r.choice((AUR, TURCOAZ, ROSU, ALB)), rot=(0, 0, r.uniform(-0.5, 0.5))))
	_cutie_coliziune(col, (0.5, 0.5, 0.55), (10.75, 6.45, FL + 0.27))
	piese.append(cilindru("Ghiveci", 0.2, 0.15, 0.35, (ix0 + 0.35, TY0 - 0.4, FL + 0.175), LEMN_DESCHIS, laturi=8))
	piese.append(cilindru("Pamant", 0.18, 0.18, 0.02, (ix0 + 0.35, TY0 - 0.4, FL + 0.34), LEMN_INCHIS, laturi=8))
	for k in range(5):
		a = k * 1.25 + r.uniform(0, 0.4)
		baza = (ix0 + 0.35, TY0 - 0.4, FL + 0.34)
		varf = (baza[0] + math.cos(a) * 0.25, baza[1] + math.sin(a) * 0.25, FL + r.uniform(0.9, 1.3))
		piese.append(os_intre("Tulpina moarta", baza, varf, 0.012, LEMN, laturi=4))
		piese.append(cub("Frunza uscata", (0.08, 0.04, 0.005), (varf[0], varf[1], varf[2] - 0.05), BRONZ, rot=(0.5, 0, a)))
	for k in range(4):
		piese.append(cub("Frunza cazuta", (0.08, 0.04, 0.005), (ix0 + 0.4 + r.uniform(-0.4, 0.4), TY0 - 0.4 + r.uniform(-0.4, 0.3),
			FL + 0.02), BRONZ, rot=(0, 0, r.uniform(0, 3))))
	_cutie_coliziune(col, (0.45, 0.45, 1.0), (ix0 + 0.35, TY0 - 0.4, FL + 0.5))
	# automatul de gustări, lângă fereastra din dreapta
	ax = ix1 - 0.45
	piese.append(cub("Automat gustari", (0.85, 0.8, 1.85), (ax, 9.2, FL + 0.925), NEGRU))
	lumini.append(cub("Vitrina gustari", (0.03, 0.55, 1.15), (ax - 0.43, 9.1, FL + 1.15), ALB))
	for j in range(5):
		for i in range(4):
			piese.append(cub("Gustare", (0.03, 0.1, 0.12), (ax - 0.455, 8.9 + i * 0.12, FL + 0.7 + j * 0.22),
				r.choice((ROSU, AUR, TURCOAZ, BRONZ, VERDE_DESCHIS)) if r.random() < 0.6 else NEGRU))
	piese.append(cub("Tastatura automat", (0.03, 0.12, 0.3), (ax - 0.44, 9.5, FL + 1.2), CROM))
	_cutie_coliziune(col, (0.85, 0.8, 1.9), (ax, 9.2, FL + 0.95))
	# aparatul de cafea „OUT OF ORDER” și coșul de gunoi plin
	piese.append(cub("Masa cafea", (0.8, 0.45, 0.05), (ix1 - 0.3, 7.6, FL + 0.85), LEMN))
	piese.append(cub("Picior masa cafea", (0.7, 0.4, 0.82), (ix1 - 0.3, 7.6, FL + 0.42), LEMN_INCHIS))
	piese.append(cub("Aparat cafea", (0.3, 0.3, 0.42), (ix1 - 0.3, 7.6, FL + 1.085), NEGRU))
	piese.append(cilindru("Carafa", 0.08, 0.07, 0.16, (ix1 - 0.38, 7.6, FL + 0.96), GEAM, laturi=8))
	piese.append(cub("Bilet aparat", (0.01, 0.22, 0.15), (ix1 - 0.46, 7.6, FL + 1.15), ALB))
	piese.append(_text_o_fata("Out of order", "OUT OF\nORDER", (ix1 - 0.466, 7.6, FL + 1.15), 0.04, ROSU, rot=(1.5708, 0, -1.5708)))
	piese.append(cilindru("Teanc pahare", 0.04, 0.035, 0.18, (ix1 - 0.3, 7.88, FL + 0.97), ALB, laturi=6))
	_cutie_coliziune(col, (0.8, 0.5, 1.3), (ix1 - 0.3, 7.6, FL + 0.65))
	piese.append(cilindru("Cos gunoi", 0.17, 0.15, 0.42, (ix1 - 0.3, 6.6, FL + 0.21), METAL, laturi=8))
	for k in range(5):
		piese.append(sfera("Gunoi cos", r.uniform(0.05, 0.09), (ix1 - 0.3 + r.uniform(-0.1, 0.1), 6.6 + r.uniform(-0.1, 0.1),
			FL + 0.44 + k * 0.03), r.choice((ALB, AUR, ROSU)), segmente=5, inele=3))
	piese.append(cub("Pahar jos", (0.06, 0.06, 0.1), (ix1 - 0.6, 6.5, FL + 0.03), ALB, rot=(1.5708, 0, 0.5)))
	_cutie_coliziune(col, (0.35, 0.35, 0.5), (ix1 - 0.3, 6.6, FL + 0.25))
	# tabloul cu „PARADISE” (palmier, soare decolorat) și afișul cu regulile
	piese.append(cub("Rama tablou", (0.03, 1.0, 0.7), (ix0 + 0.02, 7.75, FL + 1.75), BRONZ))
	piese.append(cub("Cer tablou", (0.01, 0.9, 0.6), (ix0 + 0.04, 7.75, FL + 1.75), TURCOAZ))
	piese.append(cilindru("Soare tablou", 0.14, 0.14, 0.01, (ix0 + 0.05, 7.6, FL + 1.85), AUR, laturi=10, rot=(0, 1.5708, 0)))
	piese.append(cub("Mare tablou", (0.012, 0.9, 0.18), (ix0 + 0.05, 7.75, FL + 1.53), TEAL))
	piese.append(cub("Trunchi palmier", (0.012, 0.04, 0.4), (ix0 + 0.055, 8.0, FL + 1.68), LEMN, rot=(0.2, 0, 0)))
	for k in range(4):
		piese.append(cub("Frunza palmier", (0.012, 0.22, 0.04), (ix0 + 0.056, 8.0 + (k - 1.5) * 0.08, FL + 1.9), VERDE,
			rot=((k - 1.5) * 0.4, 0, 0)))
	piese.append(_text_o_fata("Tablou scris", "PARADISE", (ix0 + 0.056, 7.75, FL + 2.0), 0.08, ROSU, rot=(1.5708, 0, 1.5708)))
	piese.append(cub("Afis reguli", (0.01, 0.5, 0.65), (ix0 + 0.02, 9.3, FL + 1.65), ALB))
	piese.append(_text_o_fata("Reguli", "NO PETS\nNO PARTIES\nCASH ONLY\nWE RESERVE\nTHE RIGHT\nTO REFUSE\nSERVICE", (ix0 + 0.027, 9.3, FL + 1.65),
		0.04, NEGRU, rot=(1.5708, 0, 1.5708)))
	strange()

	# --- pe dinafară: firma „OFFICE”, copertina de deasupra ușii, neonul din vitrină, lampa anti-țânțari, pragul
	cx = (OUSA[0] + OUSA[1]) / 2
	piese.append(cub("Firma office", (2.2, 0.15, 0.55), (cx + 0.4, OY0 - 0.1, OT - 0.35), NEGRU))
	lumini.append(_text("Office", "OFFICE", (cx + 0.4, OY0 - 0.18, OT - 0.35), 0.36, NEON))
	piese.append(cub("Copertina", (2.0, 1.4, 0.08), (cx, OY0 - 0.7, FL + 2.75), TEAL, rot=(-0.12, 0, 0)))
	piese.append(cub("Volan copertina", (2.0, 0.02, 0.18), (cx, OY0 - 1.4, FL + 2.75), TEAL))
	for dx in (-0.95, 0.95):
		piese.append(cub("Stalp copertina", (0.06, 0.06, 2.75), (cx + dx, OY0 - 1.35, FL + 1.375 - 0.075), METAL))
		_cutie_coliziune(col, (0.1, 0.1, 2.7), (cx + dx, OY0 - 1.35, 1.35))
	piese.append(cub("Prag receptie", (2.4, 1.6, FL), (cx, OY0 - 0.8, FL / 2), BETON))
	_cutie_coliziune(col, (2.4, 1.6, FL), (cx, OY0 - 0.8, FL / 2))
	piese.append(cub("Placa neon", (1.4, 0.03, 0.45), (15.3, OY0 + OG + 0.05, 2.0), NEGRU))
	lumini.append(_text_o_fata("Open", "OPEN 24 HRS", (15.3, OY0 + OG + 0.07, 2.0), 0.13, LEMN_DESCHIS, rot=(1.5708, 0, 3.1416)))
	lumini.append(_text_o_fata("Open", "OPEN 24 HRS", (15.3, OY0 + OG + 0.03, 2.0), 0.13, LEMN_DESCHIS))
	piese.append(cub("Afis geam", (0.4, 0.01, 0.3), (14.2, OY0 + OG + 0.03, 1.2), ALB))
	piese.append(_text_o_fata("Afis geam", "NO\nREFUNDS", (14.2, OY0 + OG + 0.022, 1.2), 0.06, ROSU))
	piese.append(cub("Cutie zapper", (0.3, 0.3, 0.42), (OX0 + 0.3, OY0 - 0.3, 2.3), METAL_INCHIS))
	lumini.append(cilindru("Tub zapper", 0.08, 0.08, 0.34, (OX0 + 0.3, OY0 - 0.3, 2.3), MOV, laturi=8))
	for k in range(6):
		piese.append(cub("Musca moarta", (0.015, 0.015, 0.006), (OX0 + 0.3 + r.uniform(-0.4, 0.4), OY0 - 0.3 + r.uniform(-0.4, 0.4), 0.004),
			NEGRU))
	strange()

	uneste(piese, "Receptie")
	uneste(lumini, "Lumini")
	uneste(geamuri, "Geamuri")
	uneste(col, "Coliziune")
	# înăuntru te uiți de aproape: ajung 10 mm (altfel romburile și petele de pe mochetă ar sta prea sus)
	desparte_fete(distanta=0.01, fixe=("Placa receptie", "Perete receptie", "Mocheta", "Linoleum", "Tavan", "Lambriu", "Acoperis receptie",
		"Tejghea", "Perete spate", "Blat"))
	exporta(os.path.join(cale, "motel_receptie.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Parcarea, piscina, firma, strada
# ---------------------------------------------------------------------------------------------------------------

def _carucior(r):
	"""Cărucior de supermarket (din sârme), în origine, cu mânerul spre +Y."""
	s = []
	for x in (-0.25, 0.25):
		s.append(os_intre("Sarma carucior", (x, -0.45, 0.45), (x, 0.4, 0.5), 0.008, CROM, laturi=3))
		s.append(os_intre("Sarma carucior", (x, -0.42, 0.95), (x, 0.42, 1.0), 0.008, CROM, laturi=3))
		for y in (-0.45, 0.0, 0.4):
			s.append(os_intre("Sarma carucior", (x, y, 0.45), (x, y, 0.98), 0.006, CROM, laturi=3))
		s.append(os_intre("Picior carucior", (x, -0.4, 0.45), (x * 0.9, -0.4, 0.08), 0.01, CROM, laturi=3))
		s.append(os_intre("Picior carucior", (x, 0.38, 0.45), (x * 0.9, 0.38, 0.08), 0.01, CROM, laturi=3))
		for y in (-0.4, 0.38):
			s.append(cilindru("Rotita", 0.05, 0.05, 0.03, (x * 0.9, y, 0.05), NEGRU, laturi=6, rot=(0, 1.5708, 0)))
	for y in (-0.45, 0.4):
		s.append(os_intre("Sarma carucior", (-0.25, y, 0.98), (0.25, y, 0.98), 0.008, CROM, laturi=3))
	for k in range(5):
		s.append(os_intre("Sarma carucior", (-0.25 + k * 0.125, -0.45, 0.46), (-0.25 + k * 0.125, 0.4, 0.5), 0.005, CROM, laturi=3))
	s.append(cub("Maner carucior", (0.55, 0.04, 0.04), (0, 0.5, 1.02), ROSU))
	return s


def parcare(cale):
	"""Parcarea și tot ce e afară în afară de clădiri: asfaltul crăpat (gropi, pete de ulei, buruieni, liniile șterse,
	opritoarele de beton), piscina golită (dale, gard de plasă cu lacăt, gunoaie în ea, trambulina ruptă), mașinile (una
	pe butuci), tomberonul cu salteaua și căruciorul, stâlpul cu firma „PARADISE MOTEL”, strada, câmpul de vizavi cu
	stâlpi de curent și un panou publicitar, felinarele. Piese: `Parcare`, `Lumini`, `Geamuri`, `Coliziune`."""
	curata()
	r = random.Random(1976)
	piese, lumini, geamuri, col = [], [], [], []

	def strange():
		_ramas(piese, "Parcare")

	# --- câmpul (pământ și iarbă uscată) până departe, sub tot
	piese.append(cub("Camp", (220.0, 160.0, 0.06), (0.0, -20.0, -0.08), LEMN_INCHIS))
	# petice de iarbă uscată, câte unul pe un careu de 10 m (nu se suprapun, deci nu pâlpâie)
	for cx in range(-90, 90, 10):
		for cy in range(-90, -30, 10):
			if r.random() < 0.6:
				w, h = r.uniform(2, 8), r.uniform(1.5, 8)
				piese.append(cub("Iarba uscata", (w, h, 0.02), (cx + 5 + r.uniform(-(10 - w) / 2, (10 - w) / 2),
					cy + 5 + r.uniform(-(10 - h) / 2, (10 - h) / 2), -0.045), r.choice((MASLINIU, VERDE, BRONZ, LEMN))))
	# --- asfaltul parcării, în jurul curții piscinei
	# (până sub zidurile invizibile din motel.tscn, x = -33 și 25, z = -18,5: altfel rămâneau fâșii fără podea prin care cădeai)
	ax0, ax1, ay0, ay1, ay_spate = -34.0, 26.0, SY1, YP, 19.5
	for (a, b, c, d) in ((ax0, GX0, ay0, ay1), (GX1, ax1, ay0, ay1), (GX0, GX1, ay0, GY0), (GX0, GX1, GY1, ay1)):
		piese.append(cub("Asfalt", (b - a, d - c, 0.06), ((a + b) / 2, (c + d) / 2, -0.03), ASFALT))
	_cutie_coliziune(col, (ax1 - ax0, ay1 - ay0, 0.2), ((ax0 + ax1) / 2, (ay0 + ay1) / 2, -0.1))
	# asfaltul din spatele clădirilor: lângă scară, în spatele aripii, în spatele recepției (la tomberon) și în dreapta ei
	for (a, b, c, d) in ((ax0, XV0 - 6.6, YP, YF), (ax0, XV0, YF, ay_spate), (XV0, XB, YS, ay_spate), (XB, OX1, OY1, ay_spate),
			(OX1, ax1, YP, ay_spate)):
		piese.append(cub("Asfalt", (b - a, d - c, 0.06), ((a + b) / 2, (c + d) / 2, -0.03), ASFALT))
	_cutie_coliziune(col, (ax1 - ax0, ay_spate - YP, 0.2), ((ax0 + ax1) / 2, (YP + ay_spate) / 2, -0.1))
	# Tot ce e desenat pe asfalt (liniile, peticele, gropile, petele de ulei, crăpăturile) stă pe UN strat, cu fața de sus
	# la `PE_ASFALT`, și nimic nu se suprapune (`_loc_liber`): așa nu se bat pe ecran nici de sus, de pe mătură.
	PE_ASFALT = 0.015
	curte = lambda m: lambda x, y: GX0 - m < x < GX1 + m and GY0 - m < y < GY1 + m
	ocupate = []
	# liniile locurilor de parcare (șterse pe alocuri) și opritoarele de beton din fața camerelor
	for k in range(NR + 1):
		x = XA + k * RW
		y = 2.8
		while y < 7.6:
			if r.random() < 0.8:
				piese.append(cub("Linie parcare", (0.1, 0.5, 0.004), (x, y + 0.25, PE_ASFALT - 0.002), CROM))
				ocupate.append((x, y + 0.25, 0.3))
			y += 0.55
	# petice de asfalt mai nou, gropile (unele pline cu apă), petele de ulei, crăpăturile cu buruieni
	for k in range(10):
		loc = _loc_liber(ocupate, r, -26, 20, -16, 6, 1.95, curte(2.0))
		if loc:
			piese.append(cub("Petic asfalt", (r.uniform(1, 3), r.uniform(0.8, 2.5), 0.004), (loc[0], loc[1], PE_ASFALT - 0.002),
				r.choice((METAL_INCHIS, NEGRU, METAL)), rot=(0, 0, r.uniform(-0.3, 0.3))))
	for k in range(11):
		raza = r.uniform(0.3, 0.8)
		loc = _loc_liber(ocupate, r, -28, 21, -16, 6, raza, curte(1.0))
		if not loc:
			continue
		if r.random() < 0.5:
			geamuri.append(cilindru("Balta groapa", raza, raza, 0.004, (loc[0], loc[1], PE_ASFALT - 0.002), GEAM, laturi=9))
		else:
			piese.append(cilindru("Groapa", raza, raza, 0.012, (loc[0], loc[1], PE_ASFALT - 0.006), NEGRU, laturi=9,
				scara=(1, r.uniform(0.5, 1.0), 1)))
	for k in range(14):
		loc = _loc_liber(ocupate, r, -17, 9.5, 3.2, 7.0, 0.7)
		if loc:
			piese.append(cilindru("Pata ulei", r.uniform(0.3, 0.7), r.uniform(0.3, 0.7), 0.004, (loc[0], loc[1], PE_ASFALT - 0.002),
				r.choice((NEGRU, LEMN_INCHIS)), laturi=8, scara=(1, r.uniform(0.4, 0.9), 1)))
	for k in range(24):
		# o crăpătură = 3 bucăți frânte; se pune doar dacă tot lanțul încape într-un loc liber
		for _ in range(40):
			x, y, u = r.uniform(-30, 22), r.uniform(-17, 7), r.uniform(0, 3.14)
			lant = []
			for j in range(3):
				lung = r.uniform(0.6, 1.8)
				lant.append((x, y, lung, u))
				x += math.cos(u) * lung * 0.5
				y += math.sin(u) * lung * 0.5
				u += r.uniform(-0.9, 0.9)
			cx = sum(b[0] for b in lant) / 3
			cy = sum(b[1] for b in lant) / 3
			raza = max(math.hypot(b[0] - cx, b[1] - cy) + b[2] / 2 for b in lant)
			if not curte(0.5)(cx, cy) and all(math.hypot(cx - a, cy - b) > raza + rb for a, b, rb in ocupate):
				ocupate.append((cx, cy, raza))
				break
		else:
			continue
		for (x, y, lung, u) in lant:
			piese.append(cub("Crapatura", (lung, 0.03, 0.004), (x, y, PE_ASFALT - 0.002), LEMN_INCHIS, rot=(0, 0, u)))
			if r.random() < 0.4:
				piese.append(cilindru("Buruiana", 0.06, 0.0, r.uniform(0.1, 0.25), (x, y, 0.06), r.choice((VERDE, MASLINIU)), laturi=4))
	for k in range(NR):
		if k == 4:
			continue  # opritorul lipsă
		x = XA + k * RW + RW / 2
		piese.append(cub("Opritor", (1.7, 0.2, 0.12), (x + r.uniform(-0.1, 0.1), 7.25, 0.06), BETON, rot=(0, 0, r.uniform(-0.08, 0.08))))
		_cutie_coliziune(col, (1.7, 0.2, 0.12), (x, 7.25, 0.06))
	strange()

	# --- piscina golită: dalele, pereții de faianță pătată, fundul cu mâl verde, scara, trambulina ruptă, gunoaiele
	for (a, b, c, d) in ((GX0, PX0, GY0, GY1), (PX1, GX1, GY0, GY1), (PX0, PX1, GY0, PY0), (PX0, PX1, PY1, GY1)):
		piese.append(cub("Dale", (b - a, d - c, 0.08), ((a + b) / 2, (c + d) / 2, -0.02), BETON))
	x = GX0
	while x < GX1:
		piese.append(cub("Rost dale", (0.02, GY1 - GY0, 0.004), (x, (GY0 + GY1) / 2, 0.03), METAL))
		x += 0.6
	piese.append(cub("Bordura piscina", (PX1 - PX0 + 0.4, 0.2, 0.06), ((PX0 + PX1) / 2, PY0 - 0.1, 0.05), ALB))
	piese.append(cub("Bordura piscina", (PX1 - PX0 + 0.4, 0.2, 0.06), ((PX0 + PX1) / 2, PY1 + 0.1, 0.05), ALB))
	piese.append(cub("Bordura piscina", (0.2, PY1 - PY0, 0.06), (PX0 - 0.1, (PY0 + PY1) / 2, 0.05), ALB))
	piese.append(cub("Bordura piscina", (0.2, PY1 - PY0, 0.06), (PX1 + 0.1, (PY0 + PY1) / 2, 0.05), ALB))
	piese.append(cub("Fund piscina", (PX1 - PX0, PY1 - PY0, 0.1), ((PX0 + PX1) / 2, (PY0 + PY1) / 2, -PADANC - 0.05), TURCOAZ))
	for (dim, loc) in (((PX1 - PX0 - 0.03, 0.1, PADANC), ((PX0 + PX1) / 2, PY0 - 0.038, -PADANC / 2)),
			((PX1 - PX0 - 0.03, 0.1, PADANC), ((PX0 + PX1) / 2, PY1 + 0.038, -PADANC / 2)),
			((0.1, PY1 - PY0 - 0.03, PADANC), (PX0 - 0.038, (PY0 + PY1) / 2, -PADANC / 2)),
			((0.1, PY1 - PY0 - 0.03, PADANC), (PX1 + 0.038, (PY0 + PY1) / 2, -PADANC / 2))):
		piese.append(cub("Perete piscina", dim, loc, TURCOAZ))
	piese.append(cub("Dunga faianta", (PX1 - PX0 - 0.06, 0.13, 0.15), ((PX0 + PX1) / 2, PY1 + 0.03, -0.1), TEAL))
	piese.append(cub("Dunga faianta", (PX1 - PX0 - 0.06, 0.13, 0.15), ((PX0 + PX1) / 2, PY0 - 0.03, -0.1), TEAL))
	for k in range(10):
		piese.append(cub("Pata piscina", (r.uniform(0.3, 1.2), 0.11, r.uniform(0.3, 1.0)),
			(r.uniform(PX0 + 0.5, PX1 - 0.5), PY1 + 0.025 - (k // 2) * 0.01 if k % 2 else PY0 - 0.025 + (k // 2) * 0.01, -r.uniform(0.4, 1.2)), r.choice((MASLINIU, BRONZ, TEAL))))
	piese.append(cilindru("Mal", 1.6, 1.6, 0.03, ((PX0 + PX1) / 2 + 0.8, (PY0 + PY1) / 2, -PADANC + 0.015), VERDE_DESCHIS, laturi=10,
		scara=(1.3, 0.7, 1)))
	geamuri.append(cilindru("Balta piscina", 1.0, 1.0, 0.01, ((PX0 + PX1) / 2 + 1.0, (PY0 + PY1) / 2 - 0.3, -PADANC + 0.035), GEAM,
		laturi=10, scara=(1.4, 0.6, 1)))
	piese.append(_text("Adancime", "3 FT", (PX0 + 0.8, PY0 + 0.01, 0.02), 0.12, ALB, rot=(0, 0, 0)))
	piese.append(_text("Adancime", "5 FT", (PX1 - 0.8, PY0 + 0.01, 0.02), 0.12, ALB, rot=(0, 0, 0)))
	# gunoaiele din piscină: un cărucior culcat, o anvelopă, un scaun, frunze, o doză
	piese.append(_obiect(_carucior(r), (PX0 + 1.6, (PY0 + PY1) / 2 + 0.6, -PADANC + 0.02), (1.4, 0, 0.6)))
	piese.append(_tor("Anvelopa", 0.32, 0.12, (PX1 - 1.5, PY0 + 1.2, -PADANC + 0.12), NEGRU, segmente=12))
	piese.append(_obiect([cub("Sezut", (0.46, 0.44, 0.04), (0, 0, 0.44), ALB), cub("Spatar", (0.46, 0.04, 0.45), (0, 0.22, 0.7), ALB)],
		(PX1 - 2.6, PY1 - 1.0, -PADANC + 0.25), (2.6, 0.3, 0.9)))
	for k in range(30):
		piese.append(cub("Frunza", (0.08, 0.05, 0.005), (r.uniform(PX0 + 0.2, PX1 - 0.2), r.uniform(PY0 + 0.2, PY1 - 0.2),
			-PADANC + 0.01), r.choice((BRONZ, LEMN_DESCHIS, AUR)), rot=(0, 0, r.uniform(0, 3))))
	# scara piscinei și trambulina ruptă
	for dx in (-0.25, 0.25):
		piese.append(os_intre("Teava scara", (PX1 - 0.6 + dx, PY1 - 0.15, -1.2), (PX1 - 0.6 + dx, PY1 + 0.25, 0.9), 0.025, CROM, laturi=6))
	for k in range(3):
		piese.append(cub("Treapta scara", (0.5, 0.1, 0.03), (PX1 - 0.6, PY1 - 0.1, -0.3 - k * 0.3), CROM))
	piese.append(cub("Postament trambulina", (0.5, 0.6, 0.4), ((PX0 + PX1) / 2, PY1 + 0.6, 0.2), BETON))
	piese.append(cub("Trambulina", (0.45, 1.6, 0.06), ((PX0 + PX1) / 2, PY1 - 0.2, 0.44), ALB, rot=(0.1, 0, 0)))
	piese.append(cub("Trambulina rupta", (0.45, 0.6, 0.06), ((PX0 + PX1) / 2 + 0.1, PY1 - 1.5, -PADANC + 0.2), ALB, rot=(-0.7, 0.2, 0.3)))
	# gardul de plasă cu poarta încuiată (lanț și lacăt) și panourile
	_plasa_gard(piese, (GX0, GY0), (GX1, GY0), 1.5, r)
	_plasa_gard(piese, (GX0, GY1), (GX1, GY1), 1.5, r, poarta=(4.0, 5.2))
	_plasa_gard(piese, (GX0, GY0), (GX0, GY1), 1.5, r)
	_plasa_gard(piese, (GX1, GY0), (GX1, GY1), 1.5, r)
	strange()
	px = GX0 + 4.6
	piese.append(cub("Rama poarta", (1.2, 0.05, 1.45), (px, GY1, 0.76), METAL))
	for k in range(6):
		piese.append(cub("Bara poarta", (0.025, 0.03, 1.4), (px - 0.5 + k * 0.2, GY1, 0.75), METAL))
	piese.append(_tor("Lant", 0.06, 0.012, (px + 0.6, GY1 + 0.03, 0.9), CROM, rot=(1.5708, 0, 0), segmente=8))
	piese.append(_tor("Lant", 0.06, 0.012, (px + 0.6, GY1 + 0.03, 0.8), CROM, rot=(1.5708, 0, 0.6), segmente=8))
	piese.append(cub("Lacat", (0.07, 0.03, 0.09), (px + 0.6, GY1 + 0.06, 0.7), AUR))
	piese.append(cub("Panou piscina", (1.1, 0.02, 0.5), (GX0 + 2.0, GY1 + 0.03, 1.1), ALB))
	piese.append(_text("Scris piscina", "POOL CLOSED", (GX0 + 2.0, GY1 + 0.042, 1.18), 0.1, ROSU, rot=(1.5708, 0, 3.1416)))
	piese.append(_text("Scris piscina", "NO LIFEGUARD ON DUTY", (GX0 + 2.0, GY1 + 0.042, 1.0), 0.06, NEGRU, rot=(1.5708, 0, 3.1416)))
	piese.append(cub("Panou piscina", (1.1, 0.02, 0.5), (GX1 - 2.0, GY0 - 0.03, 1.1), ALB))
	piese.append(_text("Scris piscina", "SWIM AT YOUR\nOWN RISK", (GX1 - 2.0, GY0 - 0.042, 1.1), 0.08, NEGRU))
	for (a, b) in (((GX0, GY0), (GX1, GY0)), ((GX0, GY1), (GX1, GY1))):
		_cutie_coliziune(col, (GX1 - GX0, 0.12, 1.6), ((a[0] + b[0]) / 2, a[1], 0.8))
	for x in (GX0, GX1):
		_cutie_coliziune(col, (0.12, GY1 - GY0, 1.6), (x, (GY0 + GY1) / 2, 0.8))
	strange()

	# --- mașinile: maro în fața camerei 119, neagră în fața lui 122 (a lui?), pickup-ul cu pană în fața lui 124,
	# epava pe butuci lângă scară
	for (tip, cul, x, y, unghi) in (("sedan", LEMN_DESCHIS, XA + 2 * RW + RW / 2, 4.9, math.pi + 0.04),
			("sedan", NEGRU, XA + 5 * RW + RW / 2, 4.95, math.pi - 0.03), ("pickup", TEAL, XA + 7 * RW + RW / 2, 4.7, math.pi + 0.1),
			("epava", BRONZ, -26.5, 1.0, 0.7)):
		s, c = _masina(tip, cul, r)
		piese.append(_obiect(s, (x, y, 0.0), (0, 0, unghi)))
		for (dx, dy, dz, ox, oy, oz) in c:
			cutie = cub("Coliziune", (dx, dy, dz), (ox, oy, oz), NEGRU)
			col.append(_obiect([cutie], (x, y, 0.0), (0, 0, unghi), nume="Coliziune"))
	# un pentagramă mic, odorizant, atârnat în oglinda mașinii negre (doar cine se uită vede)
	piese.append(cub("Odorizant", (0.06, 0.005, 0.08), (XA + 5 * RW + RW / 2, 4.95 - 0.5, 1.2), ROSU))
	strange()

	# --- tomberonul de lângă recepție, cu sacii, salteaua pătată și televizorul aruncat; căruciorul abandonat
	tx, ty = 20.4, 12.8
	piese.append(cub("Tomberon", (2.0, 1.5, 1.3), (tx, ty, 0.7), VERDE))
	piese.append(cub("Buza tomberon", (2.06, 1.56, 0.08), (tx, ty, 1.36), p("445d46")))
	piese.append(cub("Capac tomberon", (1.0, 1.5, 0.04), (tx - 0.5, ty, 1.42), NEGRU))
	piese.append(cub("Capac deschis", (1.0, 0.04, 1.3), (tx + 0.5, ty + 0.8, 2.0), NEGRU, rot=(0.25, 0, 0)))
	piese.append(_text("Tomberon scris", "WASTE", (tx, ty - 0.76, 0.9), 0.22, ALB))
	for k in range(5):
		piese.append(sfera("Sac gunoi", r.uniform(0.25, 0.4), (tx + r.uniform(-0.6, 0.9), ty + r.uniform(-1.4, -0.9) if k < 3 else ty,
			0.25 if k < 3 else 1.45), NEGRU, scara=(1, 0.9, 0.8), segmente=7, inele=4))
	piese.append(cub("Saltea", (0.95, 0.2, 1.9), (tx - 1.3, ty - 0.2, 0.85), ALB, rot=(0, -0.3, 0)))
	for k in range(3):
		piese.append(cilindru("Pata saltea", r.uniform(0.1, 0.25), r.uniform(0.1, 0.25), 0.01,
			(tx - 1.3 - 0.15 + r.uniform(-0.1, 0.1), ty - 0.31, 0.6 + k * 0.45), r.choice((BRONZ, AUR, LEMN)), laturi=8, rot=(1.5708, 0, 0)))
	piese.append(cub("Televizor aruncat", (0.55, 0.5, 0.45), (tx + 1.4, ty - 1.0, 0.22), LEMN_INCHIS, rot=(0, 0, 0.4)))
	piese.append(cub("Ecran spart", (0.4, 0.01, 0.3), (tx + 1.3, ty - 1.24, 0.24), NEGRU, rot=(0, 0, 0.4)))
	_cutie_coliziune(col, (2.2, 1.6, 1.6), (tx, ty, 0.8))
	_cutie_coliziune(col, (1.0, 0.5, 1.9), (tx - 1.3, ty - 0.2, 0.95))
	piese.append(_obiect(_carucior(r), (4.5, -9.0, 0.0), (0, 0, 2.3)))
	_cutie_coliziune(col, (0.7, 1.0, 1.0), (4.5, -9.0, 0.5))
	strange()

	# --- stâlpul cu firma: „PARADISE” (litera D arsă), „MOTEL”, săgeata cu becuri, „NO VACANCY” cu „NO” stins, steaua
	fx, fy = 15.5, -15.0
	for dy in (-0.9, 0.9):
		piese.append(cub("Stalp firma", (0.3, 0.3, 10.0), (fx, fy + dy, 5.0), METAL))
		piese.append(cub("Rugina stalp", (0.33, 0.33, 1.2), (fx, fy + dy, 0.6), RUGINA))
	piese.append(cub("Jardiniera", (1.2, 2.8, 0.45), (fx, fy, 0.22), BETON))
	piese.append(cub("Pamant jardiniera", (1.0, 2.6, 0.02), (fx, fy, 0.45), LEMN_INCHIS))
	for k in range(4):
		piese.append(sfera("Tufa moarta", 0.25, (fx + r.uniform(-0.3, 0.3), fy + r.uniform(-1.0, 1.0), 0.55), LEMN, segmente=5, inele=3))
	_cutie_coliziune(col, (1.2, 2.8, 2.0), (fx, fy, 1.0))
	# panourile sunt cu două fețe: textul pe partea dinspre parcare (-X) și pe cea dinspre drum (+X)
	def doua_fete(nume, continut, z, marime, culoare, aprins, dy=0.0):
		for semn, unghi in ((-1, -1.5708), (1, 1.5708)):
			(lumini if aprins else piese).append(_text(nume, continut, (fx + semn * 0.27, fy + dy * semn, z), marime, culoare,
				rot=(1.5708, 0, unghi)))
	piese.append(cub("Panou paradise", (0.45, 5.4, 1.6), (fx, fy, 8.6), TEAL))
	piese.append(cub("Chenar paradise", (0.5, 5.6, 0.12), (fx, fy, 9.45), AUR))
	piese.append(cub("Chenar paradise", (0.5, 5.6, 0.12), (fx, fy, 7.75), AUR))
	litere = "PARADISE"
	for i, lit in enumerate(litere):
		dy = (i - (len(litere) - 1) / 2) * 0.62
		doua_fete("Litera", lit, 8.6, 0.85, LEMN_INCHIS if lit == "D" else NEON, lit != "D", dy)
	piese.append(cub("Panou motel", (0.4, 3.6, 0.9), (fx, fy, 7.0), NEGRU))
	for i, lit in enumerate("MOTEL"):
		dy = (i - 2) * 0.62
		doua_fete("Litera", lit, 7.0, 0.65, LEMN_DESCHIS if i != 3 else LEMN, i != 3, dy)
	# săgeata (în jos, spre intrare) cu becuri, unele arse
	piese.append(prisma("Sageata", [(fy - 1.5 + a, z) for (a, z) in [(0.0, 5.6), (2.6, 5.6), (2.6, 5.3), (3.3, 5.9), (2.6, 6.5),
		(2.6, 6.2), (0.0, 6.2)]], "yz", fx - 0.15, fx + 0.15, ROSU))
	for k in range(14):
		y = fy - 1.4 + k * 0.2
		for semn in (-1, 1):
			aprins = r.random() < 0.8
			(lumini if aprins else piese).append(sfera("Bec", 0.045, (fx + semn * 0.17, y, 5.9), AUR if aprins else METAL_INCHIS,
				segmente=6, inele=4))
	# „NO VACANCY” (NO stins) și panoul cu „COLOR TV • WEEKLY RATES”
	piese.append(cub("Panou vacancy", (0.35, 3.0, 0.55), (fx, fy, 4.5), NEGRU))
	doua_fete("No", "NO", 4.5, 0.32, METAL_INCHIS, False, -1.05)
	doua_fete("Vacancy", "VACANCY", 4.5, 0.32, LEMN_DESCHIS, True, 0.35)
	piese.append(cub("Panou tv", (0.34, 3.0, 0.7), (fx, fy, 3.5), ALB))
	doua_fete("Tv", "COLOR TV\nWEEKLY RATES", 3.5, 0.2, NEGRU, False)
	# steaua din vârf, cu becuri
	stea = []
	for k in range(10):
		a = k * math.pi / 5 + math.pi / 2
		raza = 0.75 if k % 2 == 0 else 0.32
		stea.append((fy + math.cos(a) * raza, 10.5 + math.sin(a) * raza))
	# prisma vrea poligon convex: steaua o fac din 5 triunghiuri + pentagonul din mijloc
	piese.append(prisma("Stea", [stea[k] for k in range(1, 10, 2)], "yz", fx - 0.1, fx + 0.1, AUR))
	for k in range(0, 10, 2):
		piese.append(prisma("Raza stea", [stea[(k - 1) % 10], stea[k], stea[(k + 1) % 10]], "yz", fx - 0.1, fx + 0.1, AUR))
		for semn in (-1, 1):
			lumini.append(sfera("Bec stea", 0.05, (fx + semn * 0.12, stea[k][0], stea[k][1]), AUR, segmente=6, inele=4))
	strange()

	# --- strada (asfalt închis, linia galbenă întreruptă), acostamentul, bordura cu intrarea în parcare
	piese.append(cub("Strada", (240.0, SY1 - SY0, 0.06), (0.0, (SY0 + SY1) / 2, -0.035), GEAM))
	_cutie_coliziune(col, (240.0, SY1 - SY0 + 30, 0.2), (0.0, (SY0 + SY1) / 2 - 15, -0.1))
	x = -118.0
	while x < 118.0:
		piese.append(cub("Linie galbena", (3.0, 0.14, 0.004), (x, (SY0 + SY1) / 2, 0.006), AUR))
		x += 7.0
	for y in (SY0 + 0.3, SY1 - 0.3):
		piese.append(cub("Linie margine", (240.0, 0.12, 0.004), (0.0, y, 0.006), CROM))
	for (a, b) in ((-60.0, 3.0), (13.0, 60.0)):
		piese.append(cub("Bordura strada", (b - a, 0.25, 0.15), ((a + b) / 2, SY1 + 0.12, 0.05), BETON))
		piese.append(cub("Iarba bordura", (b - a, 0.8, 0.02), ((a + b) / 2, SY1 + 0.7, 0.005), MASLINIU))
	# stâlpul de iluminat din mijlocul parcării (lumina portocalie, cu brațul spre clădire)
	piese.append(cilindru("Stalp parcare", 0.14, 0.1, 7.8, (10.0, -8.0, 3.9), METAL, laturi=6))
	piese.append(cub("Baza stalp", (0.5, 0.5, 0.5), (10.0, -8.0, 0.25), BETON))
	piese.append(cub("Brat felinar", (0.1, 1.4, 0.1), (10.0, -7.4, 7.75), METAL))
	piese.append(cub("Cap felinar", (0.4, 0.7, 0.18), (10.0, -6.8, 7.68), METAL_INCHIS))
	lumini.append(cub("Lumina felinar", (0.32, 0.55, 0.02), (10.0, -6.8, 7.58), AUR))
	_cutie_coliziune(col, (0.5, 0.5, 7.8), (10.0, -8.0, 3.9))
	# felinarele de pe stradă (cap de cobră, lumină portocalie) și stâlpii de curent de vizavi, cu firele lăsate
	for fxs in (-12.0, 26.0):
		piese.append(cilindru("Stalp felinar", 0.12, 0.09, 8.0, (fxs, SY1 + 0.6, 4.0), METAL, laturi=6))
		piese.append(cub("Brat felinar", (0.1, 2.2, 0.1), (fxs, SY1 - 0.4, 7.9), METAL))
		piese.append(cub("Cap felinar", (0.4, 0.7, 0.18), (fxs, SY1 - 1.4, 7.82), METAL_INCHIS))
		lumini.append(cub("Lumina felinar", (0.32, 0.55, 0.02), (fxs, SY1 - 1.4, 7.72), AUR))
		_cutie_coliziune(col, (0.3, 0.3, 8), (fxs, SY1 + 0.6, 4.0))
	stalpi = [(-60.0 + k * 24.0, -33.0) for k in range(6)]
	for (sx, sy) in stalpi:
		piese.append(cilindru("Stalp curent", 0.14, 0.12, 9.0, (sx, sy, 4.5), LEMN, laturi=6))
		piese.append(cub("Traversa", (0.12, 1.8, 0.12), (sx, sy, 8.6), LEMN))
		piese.append(cilindru("Transformator", 0.25, 0.25, 0.6, (sx + 0.25, sy, 7.6), METAL, laturi=8))
	for (a, b) in zip(stalpi, stalpi[1:]):
		for dy in (-0.8, 0.8):
			m = ((a[0] + b[0]) / 2, a[1] + dy, 8.0)
			piese.append(os_intre("Fir", (a[0], a[1] + dy, 8.62), m, 0.012, NEGRU, laturi=3))
			piese.append(os_intre("Fir", m, (b[0], b[1] + dy, 8.62), 0.012, NEGRU, laturi=3))
	# panoul publicitar de vizavi, luminat de jos de doi reflectoare (unul ars)
	bx, by = -18.0, -44.0
	for dx in (-2.0, 2.0):
		piese.append(cub("Stalp panou", (0.25, 0.25, 6.0), (bx + dx, by, 3.0), METAL))
	piese.append(cub("Panou publicitar", (7.0, 0.3, 3.0), (bx, by, 6.8), ALB))
	piese.append(cub("Fundal reclama", (6.6, 0.02, 2.6), (bx, by - 0.16, 6.8), ROSU))
	piese.append(_text("Reclama", "TRUCK STOP\nEXIT 9  -  OPEN 24/7", (bx, by - 0.18, 6.8), 0.5, ALB))
	piese.append(cub("Reflector", (0.3, 0.3, 0.2), (bx - 2.0, by - 1.0, 5.2), METAL_INCHIS))
	lumini.append(cub("Reflector aprins", (0.24, 0.02, 0.14), (bx - 2.0, by - 1.16, 5.2), AUR))
	piese.append(cub("Reflector", (0.3, 0.3, 0.2), (bx + 2.0, by - 1.0, 5.2), METAL_INCHIS))
	# câțiva copaci uscați pe câmp
	for k in range(9):
		cx, cy = r.uniform(-80, 80), r.uniform(-75, -36)
		h = r.uniform(4, 8)
		piese.append(cilindru("Trunchi uscat", 0.2, 0.08, h, (cx, cy, h / 2), LEMN_INCHIS, laturi=5))
		for j in range(4):
			a = r.uniform(0, 6.28)
			z = h * r.uniform(0.5, 0.9)
			piese.append(os_intre("Creanga uscata", (cx, cy, z), (cx + math.cos(a) * 1.5, cy + math.sin(a) * 1.5, z + r.uniform(0.5, 1.5)),
				0.05, LEMN_INCHIS, laturi=4))
	strange()

	uneste(piese, "Parcare")
	uneste(lumini, "Lumini")
	uneste(geamuri, "Geamuri")
	uneste(col, "Coliziune")
	desparte_fete(fixe=("Asfalt", "Strada", "Dale", "Perete piscina", "Fund piscina", "Camp", "Stalp firma", "Stalp parcare",
		"Stalp curent", "Bordura strada", "Bordura piscina"))
	exporta(os.path.join(cale, "motel_parcare.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Receptionera
# ---------------------------------------------------------------------------------------------------------------

# 40 și ceva de ani, plictisită: păr blond tapat cu rădăcinile închise, cercei mari de aur, ruj, unghii lungi roșii,
# cardigan mov peste un maieu roșu, lănțișor; stă pe scaunul înalt cu coatele pe tejghea (ca bătrâna de la casino).
RECEPTIONERA = {
	"piele": p("a56850"), "piele_umbra": p("904a40"), "haina": p("655269"), "haina_umbra": p("48313b"), "camasa": p("7b383a"),
	"stil_haina": "pulover", "nasturi": AUR, "pantaloni": p("2a3c3d"), "femeie": True, "par": p("a18463"),
	"par_suvita": p("48313b"), "stil_par": "voluminos", "cercei": AUR, "lant": AUR, "buze": p("7b383a"), "gura": p("5e363e"),
	"unghii": p("7b383a"), "inele": AUR, "sezut": 0.72, "masa": TZ - FL, "pantofi": p("262d2f"), "gros_brat": 0.85,
	"spranceana": 0.012, "incruntat": 0.12, "riduri": True,
}


def receptionera(cale):
	casino_oameni.om(cale, "receptionera", RECEPTIONERA, 122)


def toate(cale):
	motel(cale)
	receptie(cale)
	parcare(cale)
	receptionera(cale)


if __name__ == "__main__":
	cale_modele = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")
	if "--" in sys.argv:
		for nume in sys.argv[sys.argv.index("--") + 1:]:
			globals()[nume](cale_modele)
	else:
		toate(cale_modele)
