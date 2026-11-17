# „GENERAL STORE”, magazinul satului de lângă primărie (primarie.tscn, owner 17.11): clădirea (pereții cu ușa și vitrina,
# soclul, tavanul; acoperișul, firma și lăzile de bere din față rămân în primarie.py), înăuntru o încăpere mică: gresie în
# carouri, raftul de pe peretele din stânga, gondola din mijloc, raftul din spate, frigiderul de bere cu ușă de sticlă,
# lada frigorifică de înghețată, tejgheaua cu casa de marcat și, în spatele casierei, raftul cu pachete de țigări.
# Produsele de pe rafturi sunt GENERICE, fără scris, și cât mai simple (owner: „ca să nu fie bugate”): cutii, conserve,
# sticle și borcane din câte două-trei bucăți puse una PESTE alta (nu una în alta), cu loc între ele.
# Plus ușa (`usa_magazin_sat`), casiera (`casiera`), țigara din mână (`tigara`) și pachetul de țigări (`pachet_tigari`).
#   blender --background --factory-startup --python tools/blender/magazin_sat.py               (toate)
#   blender --background --factory-startup --python tools/blender/magazin_sat.py -- casiera    (doar unele)
# Axe Blender: Z în sus, fațada spre -Y (în Godot +Z, spre drum); înăuntru e spre +Y (Godot -Z). Coordonatele sunt ale
# primăriei (primarie.py, curte()), deci în Godot modelul stă în origine, ca și curtea: Godot = (x, z, -y).
import math
import os
import random
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, uneste, exporta, desparte_fete  # noqa: E402
from lexy import perete, prisma  # noqa: E402
from casino import _cutie_coliziune  # noqa: E402
from coven import _parinte  # noqa: E402
import casino_oameni  # noqa: E402

NEGRU = p("262d2f")
ALB = p("83b3b0")          # tencuiala de afară (aceeași ca înainte, în primarie.py)
AUR = p("a18463")
CROM = p("7e8d87")
METAL = p("6f6d7f")
METAL_INCHIS = p("5e5356")
GEAM = p("2a3c3d")
LEMN = p("5e363e")
LEMN_INCHIS = p("48313b")
LEMN_DESCHIS = p("904a40")
ROSU = p("7b383a")
BETON = p("70706e")
BRONZ = p("a56850")
VERDE = p("5b6d4e")
VERDE_INCHIS = p("445d46")
MASLINIU = p("7a7b59")
TEAL = p("438b88")
TEAL_DESCHIS = p("61a19f")
PETROL = p("295555")
PETROL_DESCHIS = p("30716f")
GRI_ALBASTRU = p("778c96")
MOV = p("655269")
MOV_INCHIS = p("553e4d")
VERDE_NEGRU = p("32453b")
PIATRA = p("5e5356")
GRI = p("70706e")
PERETE_INT = p("7e8d87")   # vopseaua de înăuntru
GRESIE_1 = p("778c96")
GRESIE_2 = p("6f6d7f")
TAVAN = p("83b3b0")

# --- clădirea (pe dinafară, ca înainte): x XE0…XE1, y YE0 (fațada) … YE1, pereți de G, înălțimea H
XE0, XE1 = -24.0, -14.0
YE0, YE1 = -5.0, 3.0
G = 0.2
H = 3.2
FL = 0.03      # podeaua (gresia)
HC = 2.85      # tavanul de înăuntru
# --- încăperea în care intri (mică): x RX0…RX1, y RY0 (fațada pe dinăuntru) … RY1 (peretele din spate); restul
# clădirii (stânga și spate) e depozitul, închis
RX0, RX1 = -22.6, XE1 - G
RY0, RY1 = YE0 + G, -0.6
USA = (-17.7, -16.7, 0.0, 2.1)             # golul ușii (x0, x1, z0, z1), ca vechea ușă din primarie.py
VITRINA = (-22.1, -19.5, 0.75, 2.15)       # golul vitrinei
# --- tejgheaua: de-a lungul peretelui din dreapta; casiera stă între ea și perete
CX0, CX1 = -15.6, -15.0
CY0, CY1 = -3.4, -0.9
TZ = FL + 0.95
CASIERA_X, CASIERA_Y = -14.66, -2.3
# --- frigiderul de bere (pe peretele din spate) și lada de înghețată (închide trecerea pe după tejghea)
FX0, FX1, FY0 = -21.45, -20.25, -1.25
LX0, LX1, LY0, LY1 = -15.6, -14.25, -4.35, -3.45

PRODUSE_CULORI = (ROSU, AUR, TEAL, VERDE, MOV, BRONZ, PETROL_DESCHIS, LEMN_DESCHIS, MASLINIU, ALB, TEAL_DESCHIS, VERDE_INCHIS)


def _strange(piese, nume):
	if len(piese) > 1:
		piese[:] = [uneste(piese, nume)]


# ---------------------------------------------------------------------------------------------------------------
# Produsele (generice, fără scris): fiecare = 2-3 bucăți puse una peste alta, originea la bază
# ---------------------------------------------------------------------------------------------------------------

def _produs(tip, x, y, z, lat, adanc, r, axa):
	"""Un produs cu baza în (x, y, z): `lat` pe lungimea raftului (axa `axa`), `adanc` spre perete.
	Întoarce piesele și cât ocupă pe lungime."""
	cul = r.choice(PRODUSE_CULORI)
	cul2 = r.choice([c for c in PRODUSE_CULORI if c != cul])
	sx, sy = (lat, adanc) if axa == "x" else (adanc, lat)
	z += 0.002  # deasupra raftului, nu în el
	if tip == "cutie":
		h = r.uniform(0.16, 0.27)
		return [cub("Produs", (sx, sy, h * 0.82), (x, y, z + h * 0.41), cul),
			cub("Produs", (sx, sy, h * 0.18), (x, y, z + h * 0.82 + h * 0.09), cul2)]
	if tip == "conserva":
		rr = min(lat, adanc) / 2
		h = r.uniform(0.09, 0.13)
		return [cilindru("Produs", rr, rr, h, (x, y, z + h / 2), cul, laturi=8),
			cilindru("Produs", rr * 0.92, rr * 0.92, 0.008, (x, y, z + h + 0.004), CROM, laturi=8)]
	if tip == "sticla":
		rr = min(lat, adanc) / 2
		h = r.uniform(0.18, 0.26)
		return [cilindru("Produs", rr, rr, h * 0.7, (x, y, z + h * 0.35), cul, laturi=8),
			cilindru("Produs", rr, rr * 0.4, h * 0.18, (x, y, z + h * 0.7 + h * 0.09), cul, laturi=8),
			cilindru("Produs", rr * 0.42, rr * 0.42, h * 0.12, (x, y, z + h * 0.88 + h * 0.06), cul2, laturi=8)]
	# borcan: corp + capac
	rr = min(lat, adanc) / 2
	h = r.uniform(0.11, 0.15)
	return [cilindru("Produs", rr, rr, h, (x, y, z + h / 2), cul, laturi=8),
		cilindru("Produs", rr * 1.02, rr * 1.02, 0.025, (x, y, z + h + 0.0125), cul2, laturi=8)]


def _umple_polita(piese, a0, a1, fix, z, adanc, spre, r, axa, h_max=0.3):
	"""Pune produse pe o poliță de la a0 la a1 (pe axa `axa`), cu fața spre `spre` (+1/-1 pe cealaltă axă), lipite de
	fundul poliței la `fix` (marginea dinspre perete). Între produse rămâne loc (1,5 cm)."""
	a = a0 + 0.02
	tip = r.choice(("cutie", "conserva", "sticla", "borcan"))
	n_la_fel = 0
	while True:
		if n_la_fel <= 0:
			tip = r.choice(("cutie", "cutie", "conserva", "sticla", "borcan"))
			n_la_fel = r.randint(2, 5)
		if tip == "cutie":
			lat = r.uniform(0.07, 0.16)
			ad = min(adanc - 0.04, r.uniform(0.06, 0.12))
		else:
			lat = r.uniform(0.06, 0.09)
			ad = lat
		if a + lat > a1 - 0.02:
			break
		centru = a + lat / 2
		c = fix + spre * (0.02 + ad / 2)
		x, y = (centru, c) if axa == "x" else (c, centru)
		if r.random() < 0.9:  # din loc în loc lipsește câte unul (s-a vândut)
			piese += _produs(tip, x, y, z, lat, ad, r, axa)
		a += lat + 0.015
		n_la_fel -= 1


def _raft_perete(piese, col, a0, a1, fix, adanc, spre, axa, niveluri, h, r, cul=METAL):
	"""Raft lipit de perete: de la a0 la a1 pe axa `axa`, adânc de `adanc`, cu spatele la `fix` și fața spre `spre`.
	Polițele la `niveluri` (z), montanții la capete, spatele de tablă, plinta jos. Coliziune = toată cutia."""
	def bucata(nume, lung_a, gros, inalt, centru_a, centru_b, centru_z, culoare):
		dim = (lung_a, gros, inalt) if axa == "x" else (gros, lung_a, inalt)
		loc = (centru_a, centru_b, centru_z) if axa == "x" else (centru_b, centru_a, centru_z)
		piese.append(cub(nume, dim, loc, culoare))
	mij = fix + spre * adanc / 2
	# spatele (tabla), lipit de perete
	bucata("Spate raft", a1 - a0, 0.02, h - FL, (a0 + a1) / 2, fix + spre * 0.01, (FL + h) / 2, METAL_INCHIS)
	for aa in (a0 + 0.02, a1 - 0.02):
		bucata("Montant raft", 0.04, adanc - 0.02, h - FL, aa, mij + spre * 0.01, (FL + h) / 2, cul)
	# plinta (jos, în față) și polițele (între montanți, ca să nu intre în ei)
	bucata("Plinta raft", a1 - a0 - 0.08, adanc - 0.02, 0.1, (a0 + a1) / 2, mij + spre * 0.01, FL + 0.05, METAL_INCHIS)
	for z in niveluri:
		bucata("Polita", a1 - a0 - 0.08, adanc - 0.02, 0.025, (a0 + a1) / 2, mij + spre * 0.01, z - 0.0125, cul)
		_umple_polita(piese, a0 + 0.04, a1 - 0.04, fix + spre * 0.02, z, adanc - 0.04, spre, r, axa)
	dim = (a1 - a0, adanc, h - FL) if axa == "x" else (adanc, a1 - a0, h - FL)
	loc = ((a0 + a1) / 2, mij, (FL + h) / 2) if axa == "x" else (mij, (a0 + a1) / 2, (FL + h) / 2)
	_cutie_coliziune(col, dim, loc)


# ---------------------------------------------------------------------------------------------------------------
# Magazinul
# ---------------------------------------------------------------------------------------------------------------

def magazin(cale):
	"""Clădirea „GENERAL STORE” și încăperea de înăuntru. Piese `Magazin`, `Lumini` (tuburile de neon, lumina din
	frigider), `Geamuri` (vitrina, ușa frigiderului, capacul lăzii), `Coliziune`."""
	curata()
	r = random.Random(1717)
	piese, lumini, geamuri, col = [], [], [], []

	def strange():
		_strange(piese, "Magazin")

	gol_u = USA
	gol_v = VITRINA
	# --- pereții de afară (tencuiala albăstruie de dinainte), cu golurile ușii și vitrinei în fațadă
	perete(piese, "Fatada", "x", XE0, XE1, YE0, YE0 + G, 0.0, H, ALB, goluri=[gol_v, gol_u])
	perete(col, "Coliziune", "x", XE0, XE1, YE0, YE0 + G, 0.0, H, NEGRU, goluri=[gol_v, gol_u])
	for x0, x1 in ((XE0, XE0 + G), (XE1 - G, XE1)):
		piese.append(cub("Perete lateral", (G, YE1 - YE0 - G, H), ((x0 + x1) / 2, (YE0 + G + YE1) / 2, H / 2), ALB))
		_cutie_coliziune(col, (G, YE1 - YE0 - G, H), ((x0 + x1) / 2, (YE0 + G + YE1) / 2, H / 2))
	piese.append(cub("Perete spate", (XE1 - XE0 - 2 * G, G, H), ((XE0 + XE1) / 2, YE1 - G / 2, H / 2), ALB))
	_cutie_coliziune(col, (XE1 - XE0 - 2 * G, G, H), ((XE0 + XE1) / 2, YE1 - G / 2, H / 2))
	# soclul de beton (o bandă de 2 cm în afara peretelui, jos), cu golul ușii
	perete(piese, "Soclu", "x", XE0 - 0.02, XE1 + 0.02, YE0 - 0.02, YE0, 0.0, 0.45, BETON, goluri=[(USA[0], USA[1], 0.0, 0.5)])
	for x0, x1 in ((XE0 - 0.02, XE0), (XE1, XE1 + 0.02)):
		piese.append(cub("Soclu", (0.02, YE1 - YE0, 0.45), ((x0 + x1) / 2, (YE0 + YE1) / 2, 0.225), BETON))
	# ramele vitrinei și ale ușii (pe dinafară, ieșite 3 cm), pervazul vitrinei
	for (a0, a1, z0, z1) in (VITRINA, USA):
		piese.append(cub("Rama", (0.08, 0.03, z1 - z0 + 0.08), (a0 - 0.04, YE0 - 0.015, (z0 + z1) / 2 + 0.04 * (z0 > 0)), PETROL))
		piese.append(cub("Rama", (0.08, 0.03, z1 - z0 + 0.08), (a1 + 0.04, YE0 - 0.015, (z0 + z1) / 2 + 0.04 * (z0 > 0)), PETROL))
		piese.append(cub("Rama", (a1 - a0 + 0.16, 0.03, 0.08), ((a0 + a1) / 2, YE0 - 0.015, z1 + 0.04), PETROL))
	piese.append(cub("Pervaz", (VITRINA[1] - VITRINA[0] + 0.2, 0.12, 0.05), ((VITRINA[0] + VITRINA[1]) / 2, YE0 - 0.06, VITRINA[2] - 0.025), BETON))
	geamuri.append(cub("Geam vitrina", (VITRINA[1] - VITRINA[0], 0.02, VITRINA[3] - VITRINA[2]),
		((VITRINA[0] + VITRINA[1]) / 2, YE0 + G / 2, (VITRINA[2] + VITRINA[3]) / 2), GEAM))
	# trei afișe colorate lipite pe dinăuntrul vitrinei (fără scris), ca înainte
	for k, cul in enumerate((ROSU, AUR, ALB)):
		piese.append(cub("Afis vitrina", (0.4, 0.008, 0.5), (-21.6 + k * 0.7, YE0 + G / 2 + 0.02, 1.5), cul))
	# pragul și lampa de deasupra ușii
	piese.append(cub("Prag", (USA[1] - USA[0], G + 0.02, 0.03), ((USA[0] + USA[1]) / 2, YE0 + G / 2 - 0.01, 0.015), BETON))
	piese.append(cub("Suport lampa", (0.08, 0.12, 0.08), ((USA[0] + USA[1]) / 2, YE0 - 0.06, 2.32), METAL_INCHIS))
	lumini.append(cilindru("Lampa usa", 0.09, 0.06, 0.08, ((USA[0] + USA[1]) / 2, YE0 - 0.12, 2.25), AUR, laturi=8))
	strange()

	# --- podeaua: șapa sub toată clădirea, gresia în carouri în încăpere
	piese.append(cub("Sapa", (XE1 - XE0 - 2 * G, YE1 - YE0 - 2 * G, FL - 0.006), ((XE0 + XE1) / 2, (YE0 + YE1) / 2, (FL - 0.006) / 2), BETON))
	_cutie_coliziune(col, (XE1 - XE0, YE1 - YE0, FL), ((XE0 + XE1) / 2, (YE0 + YE1) / 2, FL / 2))
	pas = 0.5
	nx = int(round((RX1 - RX0) / pas + 0.49))
	ny = int(round((RY1 - RY0) / pas + 0.49))
	for i in range(nx):
		for j in range(ny):
			x0, x1 = RX0 + i * pas, min(RX0 + (i + 1) * pas, RX1)
			y0, y1 = RY0 + j * pas, min(RY0 + (j + 1) * pas, RY1)
			piese.append(cub("Gresie", (x1 - x0 - 0.006, y1 - y0 - 0.006, 0.006), ((x0 + x1) / 2, (y0 + y1) / 2, FL - 0.003),
				GRESIE_1 if (i + j) % 2 else GRESIE_2))
	strange()

	# --- înăuntru: peretele din stânga (spre depozit), cel din spate, vopseaua pe fațadă și pe peretele din dreapta,
	# tavanul, plintele
	piese.append(cub("Perete depozit", (G, RY1 - RY0, H), (RX0 - G / 2, (RY0 + RY1) / 2, H / 2), PERETE_INT))
	_cutie_coliziune(col, (G, RY1 - RY0, H), (RX0 - G / 2, (RY0 + RY1) / 2, H / 2))
	piese.append(cub("Perete depozit", (RX1 - RX0 + G, G, H), ((RX0 - G + RX1) / 2, RY1 + G / 2, H / 2), PERETE_INT))
	_cutie_coliziune(col, (RX1 - RX0 + G, G, H), ((RX0 - G + RX1) / 2, RY1 + G / 2, H / 2))
	perete(piese, "Vopsea", "x", RX0, RX1, RY0, RY0 + 0.012, FL, HC, PERETE_INT, goluri=[gol_v, gol_u])
	piese.append(cub("Vopsea", (0.012, RY1 - RY0, HC - FL), (RX1 - 0.006, (RY0 + RY1) / 2, (FL + HC) / 2), PERETE_INT))
	piese.append(cub("Tavan", (XE1 - XE0 - 2 * G, YE1 - YE0 - 2 * G, H - HC), ((XE0 + XE1) / 2, (YE0 + YE1) / 2, (HC + H) / 2), TAVAN))
	_cutie_coliziune(col, (XE1 - XE0, YE1 - YE0, H - HC), ((XE0 + XE1) / 2, (YE0 + YE1) / 2, (HC + H) / 2))
	# brâul de faianță (o dungă închisă la 1,2 m) pe pereții încăperii, întrerupt la goluri
	for nume, dim, loc in (
			("Brau", (0.008, RY1 - RY0 - 0.03, 0.08), (RX0 + 0.004, (RY0 + RY1) / 2, 1.2)),
			("Brau", (0.008, RY1 - RY0 - 0.03, 0.08), (RX1 - 0.016, (RY0 + RY1) / 2, 1.2)),
			("Brau", (RX1 - RX0 - 0.03, 0.008, 0.08), ((RX0 + RX1) / 2, RY1 - 0.004, 1.2))):
		piese.append(cub(nume, dim, loc, PETROL))
	for nume, dim, loc in (
			("Plinta", (0.02, RY1 - RY0 - 0.04, 0.08), (RX0 + 0.01, (RY0 + RY1) / 2, FL + 0.04)),
			("Plinta", (0.02, RY1 - RY0 - 0.04, 0.08), (RX1 - 0.022, (RY0 + RY1) / 2, FL + 0.04)),
			("Plinta", (RX1 - RX0 - 0.04, 0.02, 0.08), ((RX0 + RX1) / 2, RY1 - 0.01, FL + 0.04))):
		piese.append(cub(nume, dim, loc, LEMN_INCHIS))
	# neoanele din tavan (carcasa + două tuburi care luminează)
	for nx_, ny_ in ((-20.4, -2.7), (-16.6, -2.7)):
		piese.append(cub("Carcasa neon", (1.3, 0.3, 0.05), (nx_, ny_, HC - 0.025), CROM))
		for k in (-1, 1):
			lumini.append(cilindru("Tub neon", 0.02, 0.02, 1.2, (nx_, ny_ + 0.07 * k, HC - 0.07), ALB, laturi=6, rot=(0, 1.5708, 0)))
	# ceasul de pe peretele din spate și coșul de gunoi de lângă ușă
	piese.append(cilindru("Ceas", 0.16, 0.16, 0.03, (-17.6, RY1 - 0.015, 2.35), ALB, laturi=12, rot=(1.5708, 0, 0)))
	piese.append(cilindru("Rama ceas", 0.18, 0.18, 0.02, (-17.6, RY1 - 0.01, 2.35), NEGRU, laturi=12, rot=(1.5708, 0, 0)))
	for unghi, lung in ((0.4, 0.1), (2.1, 0.13)):
		piese.append(cub("Ac ceas", (0.012, 0.004, lung), (-17.6 + math.sin(unghi) * lung / 2, RY1 - 0.033, 2.35 + math.cos(unghi) * lung / 2),
			NEGRU, rot=(0, unghi, 0)))
	piese.append(cilindru("Cos gunoi", 0.15, 0.13, 0.4, (-18.3, RY0 + 0.3, FL + 0.2), METAL_INCHIS, laturi=8))
	_cutie_coliziune(col, (0.3, 0.3, 0.4), (-18.3, RY0 + 0.3, FL + 0.2))
	strange()

	# --- raftul de pe peretele din stânga (5 polițe), gondola din mijloc (cu două fețe), raftul din spate
	_raft_perete(piese, col, -4.3, -1.6, RX0, 0.4, 1, "y", (FL + 0.15, 0.55, 0.93, 1.31, 1.69), 1.95, r)
	strange()
	GX0, GX1, GY0, GY1 = -20.05, -19.45, -3.75, -1.95
	gm = (GX0 + GX1) / 2
	piese.append(cub("Perete gondola", (0.03, GY1 - GY0, 1.5 - FL), (gm, (GY0 + GY1) / 2, (FL + 1.5) / 2), METAL_INCHIS))
	for yy in (GY0 + 0.02, GY1 - 0.02):
		piese.append(cub("Capat gondola", (GX1 - GX0, 0.04, 1.5 - FL), (gm, yy, (FL + 1.5) / 2), METAL))
	for s in (-1, 1):
		x_fata = gm + s * (GX1 - GX0) / 2
		piese.append(cub("Plinta raft", (0.27, GY1 - GY0 - 0.08, 0.1), (gm + s * 0.15, (GY0 + GY1) / 2, FL + 0.05), METAL_INCHIS))
		for z in (FL + 0.15, 0.55, 0.93, 1.31):
			piese.append(cub("Polita", (0.27, GY1 - GY0 - 0.08, 0.025), (gm + s * 0.15, (GY0 + GY1) / 2, z - 0.0125), METAL))
			# fundul poliței = peretele din mijloc (la gm ± 1,5 cm), fața spre x_fata
			_umple_polita(piese, GY0 + 0.04, GY1 - 0.04, gm + s * 0.02, z, 0.25, s, r, "y")
	piese.append(cub("Polita sus", (GX1 - GX0, GY1 - GY0, 0.03), (gm, (GY0 + GY1) / 2, 1.5 + 0.015), METAL))
	_umple_polita(piese, GY0 + 0.05, GY1 - 0.05, gm - 0.13, 1.53, 0.26, 1, r, "y")
	_cutie_coliziune(col, (GX1 - GX0, GY1 - GY0, 1.55), (gm, (GY0 + GY1) / 2, (FL + 1.55) / 2))
	strange()
	_raft_perete(piese, col, -19.7, -16.1, RY1, 0.4, -1, "x", (FL + 0.15, 0.55, 0.93, 1.31, 1.69), 1.95, r)
	strange()

	# --- frigiderul de bere: carcasa (cinci pereți), ușa de sticlă cu rama, polițele cu sticle și doze, lumina de sus,
	# panoul colorat de deasupra (fără scris)
	fz1 = FL + 2.0
	fy1 = RY1
	piese += [
		cub("Frigider", (0.05, fy1 - FY0, fz1 - FL), (FX0 + 0.025, (FY0 + fy1) / 2, (FL + fz1) / 2), ALB),
		cub("Frigider", (0.05, fy1 - FY0, fz1 - FL), (FX1 - 0.025, (FY0 + fy1) / 2, (FL + fz1) / 2), ALB),
		cub("Frigider", (FX1 - FX0 - 0.1, fy1 - FY0, 0.12), ((FX0 + FX1) / 2, (FY0 + fy1) / 2, FL + 0.06), METAL_INCHIS),
		cub("Frigider", (FX1 - FX0 - 0.1, fy1 - FY0, 0.06), ((FX0 + FX1) / 2, (FY0 + fy1) / 2, fz1 - 0.03), ALB),
		cub("Fund frigider", (FX1 - FX0 - 0.1, 0.03, fz1 - FL - 0.18), ((FX0 + FX1) / 2, fy1 - 0.015, (FL + 0.12 + fz1 - 0.06) / 2), CROM),
		cub("Panou frigider", (FX1 - FX0, 0.04, 0.28), ((FX0 + FX1) / 2, FY0 + 0.02, fz1 + 0.14), ROSU),
	]
	lumini.append(cub("Lumina frigider", (FX1 - FX0 - 0.2, 0.04, 0.02), ((FX0 + FX1) / 2, FY0 + 0.12, fz1 - 0.07), ALB))
	for z in (FL + 0.12, 0.62, 1.07, 1.52):
		piese.append(cub("Polita frigider", (FX1 - FX0 - 0.1, fy1 - FY0 - 0.08, 0.02), ((FX0 + FX1) / 2, (FY0 + fy1) / 2 + 0.01, z + 0.01), CROM))
		x = FX0 + 0.1
		k = 0
		while x < FX1 - 0.1:
			for rand_y in (FY0 + 0.12, FY0 + 0.24):
				zb = z + 0.022
				if k % 7 == 3 and z > 1.0:
					# doză
					piese.append(cilindru("Doza", 0.032, 0.032, 0.12, (x, rand_y, zb + 0.06), r.choice((ROSU, TEAL, AUR)), laturi=8))
				else:
					cul = LEMN if z < 1.0 else VERDE_INCHIS
					piese += [cilindru("Sticla bere", 0.03, 0.03, 0.15, (x, rand_y, zb + 0.075), cul, laturi=8),
						cilindru("Sticla bere", 0.03, 0.013, 0.06, (x, rand_y, zb + 0.18), cul, laturi=8),
						cilindru("Capac sticla", 0.014, 0.014, 0.012, (x, rand_y, zb + 0.216), AUR, laturi=6)]
			x += 0.085
			k += 1
	# ușa: rama și geamul, mânerul vertical
	piese += [
		cub("Rama frigider", (0.05, 0.04, fz1 - FL - 0.12), (FX0 + 0.025, FY0 - 0.02, (FL + 0.12 + fz1) / 2), METAL_INCHIS),
		cub("Rama frigider", (0.05, 0.04, fz1 - FL - 0.12), (FX1 - 0.025, FY0 - 0.02, (FL + 0.12 + fz1) / 2), METAL_INCHIS),
		cub("Rama frigider", (FX1 - FX0 - 0.1, 0.04, 0.05), ((FX0 + FX1) / 2, FY0 - 0.02, fz1 - 0.025), METAL_INCHIS),
		cub("Rama frigider", (FX1 - FX0 - 0.1, 0.04, 0.05), ((FX0 + FX1) / 2, FY0 - 0.02, FL + 0.145), METAL_INCHIS),
		cub("Maner frigider", (0.03, 0.04, 0.6), (FX1 - 0.1, FY0 - 0.06, 1.1), CROM),
	]
	geamuri.append(cub("Geam frigider", (FX1 - FX0 - 0.1, 0.012, fz1 - FL - 0.22), ((FX0 + FX1) / 2, FY0 - 0.02, (FL + 0.17 + fz1 - 0.05) / 2), GEAM))
	_cutie_coliziune(col, (FX1 - FX0, fy1 - FY0 + 0.06, fz1 + 0.28 - FL), ((FX0 + FX1) / 2, (FY0 - 0.06 + fy1) / 2, (FL + fz1 + 0.28) / 2))
	strange()

	# --- lada frigorifică de înghețată (în fața tejghelei, închide trecerea pe după ea): albă, capacul de sticlă,
	# înăuntru cutii colorate
	lz = FL + 0.82
	piese += [
		cub("Lada", (LX1 - LX0, LY1 - LY0, 0.1), ((LX0 + LX1) / 2, (LY0 + LY1) / 2, FL + 0.05), METAL_INCHIS),
		cub("Lada", (0.05, LY1 - LY0, lz - FL - 0.1), (LX0 + 0.025, (LY0 + LY1) / 2, (FL + 0.1 + lz) / 2), ALB),
		cub("Lada", (0.05, LY1 - LY0, lz - FL - 0.1), (LX1 - 0.025, (LY0 + LY1) / 2, (FL + 0.1 + lz) / 2), ALB),
		cub("Lada", (LX1 - LX0 - 0.1, 0.05, lz - FL - 0.1), ((LX0 + LX1) / 2, LY0 + 0.025, (FL + 0.1 + lz) / 2), ALB),
		cub("Lada", (LX1 - LX0 - 0.1, 0.05, lz - FL - 0.1), ((LX0 + LX1) / 2, LY1 - 0.025, (FL + 0.1 + lz) / 2), ALB),
		cub("Fund lada", (LX1 - LX0 - 0.1, LY1 - LY0 - 0.1, 0.02), ((LX0 + LX1) / 2, (LY0 + LY1) / 2, lz - 0.32), CROM),
		cub("Dunga lada", (0.008, LY1 - LY0 - 0.1, 0.12), (LX0 - 0.004, (LY0 + LY1) / 2, FL + 0.45), TEAL),
	]
	for i in range(5):
		for j in range(3):
			cx = LX0 + 0.13 + i * 0.23
			cy = LY0 + 0.17 + j * 0.28
			if cx < LX1 - 0.12:
				piese.append(cub("Inghetata", (0.18, 0.2, 0.08), (cx, cy, lz - 0.31 + 0.04), r.choice((ALB, ROSU, AUR, TEAL_DESCHIS, MOV))))
	geamuri.append(cub("Capac lada", (LX1 - LX0 - 0.1, LY1 - LY0 - 0.1, 0.012), ((LX0 + LX1) / 2, (LY0 + LY1) / 2, lz - 0.006), GEAM))
	_cutie_coliziune(col, (LX1 - LX0, LY1 - LY0, lz - FL), ((LX0 + LX1) / 2, (LY0 + LY1) / 2, (FL + lz) / 2))
	strange()

	# --- tejgheaua: corpul de lemn, panoul din față (petrol), blatul, casa de marcat, tava cu gume, cana cu brichete
	piese += [
		cub("Corp tejghea", (CX1 - CX0 - 0.02, CY1 - CY0, TZ - 0.04 - FL), ((CX0 + 0.02 + CX1) / 2, (CY0 + CY1) / 2, (FL + TZ - 0.04) / 2), LEMN),
		cub("Fata tejghea", (0.02, CY1 - CY0, TZ - 0.04 - FL - 0.1), (CX0 + 0.01, (CY0 + CY1) / 2, (FL + 0.1 + TZ - 0.04) / 2), PETROL),
		cub("Plinta tejghea", (0.02, CY1 - CY0, 0.1), (CX0 + 0.01, (CY0 + CY1) / 2, FL + 0.05), NEGRU),
		cub("Blat tejghea", (CX1 - CX0 + 0.08, CY1 - CY0 + 0.06, 0.04), ((CX0 - 0.06 + CX1 + 0.02) / 2, (CY0 + CY1) / 2, TZ - 0.02), LEMN_DESCHIS),
	]
	_cutie_coliziune(col, (CX1 - CX0 + 0.08, CY1 - CY0 + 0.06, TZ - FL), ((CX0 - 0.06 + CX1 + 0.02) / 2, (CY0 + CY1) / 2, (FL + TZ) / 2))
	# casa de marcat (spre capătul din față al tejghelei), cu ecranul spre client
	kx, ky = -15.32, -3.0
	piese += [
		cub("Casa marcat", (0.32, 0.36, 0.09), (kx, ky, TZ + 0.045), METAL_INCHIS),
		cub("Sertar casa", (0.02, 0.3, 0.06), (kx - 0.17, ky, TZ + 0.035), METAL),
		cub("Tastatura casa", (0.16, 0.24, 0.02), (kx - 0.06, ky, TZ + 0.1), NEGRU),
		cub("Stalp ecran", (0.03, 0.03, 0.12), (kx + 0.1, ky, TZ + 0.15), METAL_INCHIS),
		cub("Ecran casa", (0.03, 0.18, 0.12), (kx + 0.08, ky, TZ + 0.25), NEGRU, rot=(0, 0.25, 0)),
	]
	lumini.append(cub("Ecran casa lumina", (0.004, 0.15, 0.09), (kx + 0.062, ky, TZ + 0.252), TEAL_DESCHIS, rot=(0, 0.25, 0)))
	# tava cu gume (lângă casă) și cana cu brichete
	piese.append(cub("Tava gume", (0.2, 0.26, 0.03), (-15.3, -2.62, TZ + 0.015), METAL))
	for i in range(3):
		for j in range(4):
			piese.append(cub("Guma", (0.045, 0.05, 0.03), (-15.37 + i * 0.065, -2.71 + j * 0.06, TZ + 0.045), r.choice((ROSU, TEAL, AUR, ALB, VERDE))))
	piese.append(cilindru("Cana brichete", 0.05, 0.05, 0.08, (-15.3, -1.55, TZ + 0.04), NEGRU, laturi=8))
	for i in range(5):
		a = i * 1.25
		piese.append(cub("Bricheta", (0.022, 0.012, 0.075), (-15.3 + math.cos(a) * 0.025, -1.55 + math.sin(a) * 0.025, TZ + 0.1),
			r.choice((ROSU, TEAL, AUR, MOV, VERDE))))
	strange()

	# --- în spatele casierei, pe peretele din dreapta: raftul cu pachete de țigări (4 rânduri), fața spre tejghea
	wx = RX1 - 0.012       # fața vopselei
	ry0, ry1 = -3.2, -1.45
	piese.append(cub("Raft tigari", (0.025, ry1 - ry0, 0.95), (wx - 0.0125, (ry0 + ry1) / 2, 1.78), METAL_INCHIS))
	for nivel, z in enumerate((1.38, 1.6, 1.82, 2.04)):
		piese.append(cub("Polita tigari", (0.11, ry1 - ry0, 0.012), (wx - 0.025 - 0.055, (ry0 + ry1) / 2, z - 0.006), CROM))
		y = ry0 + 0.04
		cul = (ROSU, ROSU, TEAL, AUR, VERDE, MOV)[(nivel * 2) % 6]
		k = 0
		while y + 0.058 < ry1 - 0.03:
			if k % 6 == 0:
				cul = r.choice((ROSU, ROSU, TEAL, AUR, VERDE_INCHIS, MOV))
			px = wx - 0.025 - 0.03
			piese += [cub("Pachet raft", (0.022, 0.056, 0.05), (px, y + 0.028, z + 0.002 + 0.025), ALB),
				cub("Pachet raft", (0.022, 0.056, 0.036), (px, y + 0.028, z + 0.052 + 0.018), cul)]
			y += 0.066
			k += 1
	strange()

	uneste(piese, "Magazin")
	uneste(lumini, "Lumini")
	uneste(geamuri, "Geamuri")
	uneste(col, "Coliziune")
	# înăuntru te uiți de aproape: ajung 10 mm (ca la recepția motelului); pereții, gresia și mobila mare nu se mută
	desparte_fete(distanta=0.01, fixe=("Fatada", "Perete lateral", "Perete spate", "Perete depozit", "Vopsea", "Tavan", "Sapa",
		"Gresie", "Corp tejghea", "Blat tejghea", "Frigider", "Lada", "Spate raft", "Polita", "Montant raft", "Perete gondola",
		"Capat gondola", "Polita sus", "Raft tigari", "Polita tigari", "Polita frigider"))
	exporta(os.path.join(cale, "magazin_sat.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Ușa (de sticlă, cu rama petrol) — originea = balamaua (jos, stânga), se întinde spre +X; afară e -Y
# ---------------------------------------------------------------------------------------------------------------

def usa_magazin_sat(cale):
	curata()
	lw, lh = USA[1] - USA[0], USA[3] - USA[2]
	piese = [
		cub("Rama", (0.07, 0.05, lh), (0.035, 0, lh / 2), PETROL_DESCHIS),
		cub("Rama", (0.07, 0.05, lh), (lw - 0.035, 0, lh / 2), PETROL_DESCHIS),
		cub("Rama", (lw - 0.14, 0.05, 0.09), (lw / 2, 0, lh - 0.045), PETROL_DESCHIS),
		cub("Rama", (lw - 0.14, 0.05, 0.4), (lw / 2, 0, 0.2), PETROL_DESCHIS),
		cub("Traversa", (lw - 0.14, 0.05, 0.05), (lw / 2, 0, 1.05), PETROL_DESCHIS),
	]
	for s in (-1, 1):
		piese.append(cub("Maner", (0.03, 0.03, 0.32), (lw - 0.13, s * 0.05, 1.05), CROM))
		for zz in (0.92, 1.18):
			piese.append(cub("Suport maner", (0.025, 0.03, 0.025), (lw - 0.13, s * 0.03, zz), CROM))
	# un afiș mic pe dinăuntru, colorat (fără scris)
	piese.append(cub("Afis usa", (0.22, 0.006, 0.16), (lw / 2, 0.031, 1.4), AUR))
	ob = uneste(piese, "Usa")
	g = uneste([cub("Geam", (lw - 0.14, 0.012, 0.6), (lw / 2, 0, 0.4 + 0.3 + 0.025), GEAM),
		cub("Geam", (lw - 0.14, 0.012, lh - 0.09 - 1.075), (lw / 2, 0, 1.075 + (lh - 0.09 - 1.075) / 2), GEAM)], "GeamUsa")
	_parinte(g, ob)
	exporta(os.path.join(cale, "usa_magazin_sat.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Casiera: o femeie de vreo 50 de ani, în picioare după tejghea, cu palmele pe blat; pulover mov, șorț petrol,
# părul strâns în bucle, ochelari pe nas, cercei
# ---------------------------------------------------------------------------------------------------------------

CASIERA = {
	"piele": p("a56850"), "piele_umbra": p("904a40"), "haina": p("655269"), "haina_umbra": p("553e4d"), "camasa": p("83b3b0"),
	"stil_haina": "pulover", "nasturi": p("83b3b0"), "pantaloni": p("2a3c3d"), "pantofi": p("262d2f"), "femeie": True,
	"par": p("5e363e"), "par_suvita": p("7b383a"), "stil_par": "permanent", "ochelari": "vedere", "rama": p("48313b"),
	"cercei": p("a18463"), "buze": p("7b383a"), "gura": p("5e363e"), "riduri": True, "sort": p("295555"),
	"in_picioare": True, "sezut": 0.86, "masa": TZ - FL, "gros_brat": 0.88, "spranceana": 0.012, "incruntat": 0.05,
	# palmele pe marginea din spate a tejghelei (ea stă la 0,34 m în spatele ei)
	"poza_D": ((-0.26, -0.08, 1.15), (-0.17, -0.33, TZ - FL + 0.025)),
	"poza_S": ((0.26, -0.08, 1.15), (0.17, -0.33, TZ - FL + 0.025)),
}


def casiera(cale):
	casino_oameni.om(cale, "casiera", CASIERA, 1717)


# ---------------------------------------------------------------------------------------------------------------
# Țigara din mână și pachetul (ca un Marlboro roșu: alb jos, roșu sus, cu „acoperișul” alb în față; fără scris)
# ---------------------------------------------------------------------------------------------------------------

def tigara(cale):
	"""O țigară culcată pe +X: filtrul (portocaliu) la 0, vârful la +0,085. `Capat` = hârtia albă a vârfului (cât e
	stinsă), `Jar` = vârful aprins (strălucește în joc), `Scrum` = cenușa de pe el."""
	curata()
	uneste([cilindru("Hartie", 0.0045, 0.0045, 0.06, (0.022 + 0.03, 0, 0), ALB, laturi=8, rot=(0, 1.5708, 0)),
		cilindru("Filtru", 0.0047, 0.0047, 0.022, (0.011, 0, 0), BRONZ, laturi=8, rot=(0, 1.5708, 0))], "Tigara")
	uneste([cilindru("Capat", 0.0045, 0.0045, 0.004, (0.084, 0, 0), ALB, laturi=8, rot=(0, 1.5708, 0))], "Capat", (0.082, 0, 0))
	uneste([cilindru("Jar", 0.0046, 0.0046, 0.004, (0.084, 0, 0), LEMN_DESCHIS, laturi=8, rot=(0, 1.5708, 0))], "Jar", (0.082, 0, 0))
	uneste([cilindru("Scrum", 0.0044, 0.004, 0.006, (0.089, 0, 0), BETON, laturi=8, rot=(0, 1.5708, 0))], "Scrum", (0.086, 0, 0))
	exporta(os.path.join(cale, "tigara.glb"))


def pachet_tigari(cale):
	"""Pachetul: 5,5 × 2,2 × 8,5 cm, originea pe fund. Jos alb, sus roșu, în față și în spate „acoperișul” alb (un
	triunghi lipit pe roșu, ieșit 1,5 mm), capacul cu dunga lui. Fără niciun scris."""
	curata()
	w, d, h = 0.055, 0.022, 0.085
	z_rosu = h * 0.55
	piese = [
		cub("Pachet", (w, d, z_rosu), (0, 0, z_rosu / 2), ALB),
		cub("Pachet rosu", (w, d, h - z_rosu), (0, 0, z_rosu + (h - z_rosu) / 2), ROSU),
		cub("Dunga capac", (w + 0.001, d + 0.001, 0.003), (0, 0, h - 0.016), p("5e363e")),
	]
	for s in (-1, 1):
		# triunghiul alb („acoperișul”) cu vârful în sus, pe fața din față și pe cea din spate
		piese.append(prisma("Acoperis pachet", [(-w / 2, z_rosu), (w / 2, z_rosu), (0, z_rosu + 0.024)], "xz",
			s * d / 2, s * (d / 2 + 0.0015), ALB))
	uneste(piese, "Pachet")
	exporta(os.path.join(cale, "pachet_tigari.glb"))


def toate(cale):
	magazin(cale)
	usa_magazin_sat(cale)
	casiera(cale)
	tigara(cale)
	pachet_tigari(cale)


if __name__ == "__main__":
	cale_modele = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")
	if "--" in sys.argv:
		for nume in sys.argv[sys.argv.index("--") + 1:]:
			globals()[nume](cale_modele)
	else:
		toate(cale_modele)
