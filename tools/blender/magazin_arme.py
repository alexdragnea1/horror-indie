# Magazinul de arme „Freedom” (Gun Store): clădirea mică de cărămidă cu bannerul (steagul american, „FREEDOM”, un Glock),
# strada din fața lui, decorul de dinăuntru (tejgheaua cu vitrină, peretele cu arme, rafturile cu muniție, trofeul cu
# coarne), armele pe care le vinde (cuțitul, shotgun-ul, AK-47, bazooka + racheta) și vânzătorul (Gun Clerk, cowboy).
#   blender --background --factory-startup --python tools/blender/magazin_arme.py            (toate)
#   blender --background --factory-startup --python tools/blender/magazin_arme.py -- ak47    (doar unele)
# Axe Blender: Z în sus, fața clădirii spre -Y (în Godot devine +Z, spre stradă); înăuntru e spre +Y (Godot -Z).
# Armele: originea în mâner (unde le ții), țeava spre +Y (în Godot -Z, adică înainte, ca pistolul).
import math
import os
import random
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, uneste, exporta, trunchi, desparte_fete  # noqa: E402
from lexy import perete  # noqa: E402
from coven import _parinte  # noqa: E402
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
LEMN_DESCHIS = p("904a40")
ROSU = p("7b383a")
CARAMIDA = p("7b383a")
MORTAR = p("5e363e")
BETON = p("70706e")
TENCUIALA = p("7e8d87")
ALBASTRU = p("2a3c3d")  # albastrul steagului (cel mai apropiat din paletă)
VERDE_ARMA = p("5b6d4e")
VERDE_INCHIS = p("445d46")
MASLINIU = p("7a7b59")
BRONZ = p("a56850")

# --- clădirea
W = 4.0      # jumătate din lățimea dinăuntru
G = 0.25     # grosimea pereților
FL = 0.15    # podeaua (= trotuarul)
HC = 3.0     # tavanul
TOP = 3.3    # acoperișul
D = 7.0      # fața dinăuntru a peretelui din spate
USA = (1.6, 2.7, FL, FL + 2.3)
VITRINA = (-3.4, 0.9, 0.85, 2.45)
# tejgheaua: de la x TX0 la TX1, fața spre client la y TY0, spatele la TY1, blatul la TZ
TX0, TX1, TY0, TY1, TZ = -3.0, 1.0, 4.4, 5.0, FL + 0.95


# ---------------------------------------------------------------------------------------------------------------
# Clădirea (cu bannerul)
# ---------------------------------------------------------------------------------------------------------------

def cladire(cale):
	"""Magazinul: fațada de cărămidă cu vitrina (cu gratii) și ușa, bannerul „FREEDOM” de pe parapet (steagul american
	în stânga, Glock-ul în dreapta), pereții, podeaua de scânduri, lambriul, tavanul cu neoane, peretele cu arme din spate
	(panou cu șanțuri). Piese: `Cladire`, `Lumini`, `Geamuri`, `Coliziune`."""
	curata()
	piese, lumini, geamuri, col = [], [], [], []

	def strange():
		piese[:] = [uneste(piese, "Cladire")]

	# --- podeaua: scânduri pe Y, trei nuanțe, peste o șapă
	# șapa și acoperișul stau cu 2 cm înăuntrul pereților: cu fețele laterale în planul pereților de afară se băteau cu ei
	# pe ecran (pereții laterali, spatele, fațada sub parapet)
	piese.append(cub("Sapa", (2 * W + 2 * G - 0.04, D + G - 0.04, 0.2), (0, (D + G) / 2, FL - 0.12), METAL_INCHIS))
	_cutie_coliziune(col, (2 * W + 2 * G, D + G, 0.3), (0, (D + G) / 2, FL - 0.15))
	x, k = -W, 0
	while x < W - 0.001:
		lat = min(0.16, W - x)
		piese.append(cub("Scandura", (lat, D - G, 0.02), (x + lat / 2, (G + D) / 2, FL - 0.01), (LEMN, LEMN_INCHIS, LEMN_DESCHIS)[k % 3]))
		x += lat
		k += 1
	piese.append(cub("Prag", (USA[1] - USA[0], G, 0.02), ((USA[0] + USA[1]) / 2, G / 2, FL - 0.01), METAL))
	strange()

	# --- pereții: fațada de cărămidă (afară) cu golurile, înăuntru lambriu de lemn
	g2 = G / 2
	goluri = [(USA[0], USA[1], USA[2] - 0.2, USA[3]), (VITRINA[0], VITRINA[1], VITRINA[2], VITRINA[3])]
	perete(piese, "Fatada", "x", -W - G, W + G, 0.0, g2, 0.0, TOP, CARAMIDA, goluri)
	perete(piese, "Fatada int", "x", -W, W, g2, G, FL, HC, LEMN, goluri)
	for a, b in [(-W - G, USA[0]), (USA[1], W + G)]:
		_cutie_coliziune(col, (b - a, G, TOP), ((a + b) / 2, G / 2, TOP / 2))
	_cutie_coliziune(col, (USA[1] - USA[0], G, TOP - USA[3]), ((USA[0] + USA[1]) / 2, G / 2, (TOP + USA[3]) / 2))
	# rosturile cărămizilor: linii orizontale la 7,5 cm și verticale decalate (doar pe fațadă, unde le vezi de aproape)
	def bucati(z, x0, x1):
		"""Bucățile de pe [x0, x1] care nu trec prin vitrină sau ușă, la înălțimea z."""
		taieturi = [(a, b) for a, b, za, zb in (USA, VITRINA) if za - 0.03 < z < zb + 0.03]
		rez, x = [], x0
		for a, b in sorted(taieturi):
			if a - 0.04 > x:
				rez.append((x, a - 0.04))
			x = max(x, b + 0.04)
		if x < x1:
			rez.append((x, x1))
		return rez
	z = 0.6
	rand = 0
	while z < TOP - 0.05:
		for a, b in bucati(z, -W - G, W + G):
			piese.append(cub("Rost", (b - a, 0.012, 0.012), ((a + b) / 2, -0.006, z), MORTAR))
		# rosturile verticale (cărămizile de 25 cm, decalate la fiecare rând)
		xx = -W - G + (0.125 if rand % 2 else 0.25)
		while xx < W + G - 0.05:
			if any(a < xx < b for a, b in bucati(z + 0.0375, -W - G, W + G)):
				piese.append(cub("Rost", (0.012, 0.012, 0.063), (xx, -0.006, z + 0.0375), MORTAR))
			xx += 0.25
		z += 0.075
		rand += 1
		if rand % 6 == 0:
			strange()
	strange()
	for s in (-1, 1):
		# (începe în spatele fațadei: fețele din față nu se mai bat una cu alta la colțuri)
		piese.append(cub("Perete lateral", (g2, D + G - g2, TOP), (s * (W + G - g2 / 2), (D + G + g2) / 2, TOP / 2), TENCUIALA))
		piese.append(cub("Lambriu", (g2, D - G, HC - FL), (s * (W + g2 / 2), (G + D) / 2, (FL + HC) / 2), LEMN))
		_cutie_coliziune(col, (G, D + G, TOP), (s * (W + G / 2), (D + G) / 2, TOP / 2))
	piese.append(cub("Spate", (2 * W + 2 * G, g2, TOP), (0, D + G - g2 / 2, TOP / 2), TENCUIALA))
	piese.append(cub("Spate int", (2 * W, g2, HC - FL), (0, D + g2 / 2, (FL + HC) / 2), LEMN))
	_cutie_coliziune(col, (2 * W + 2 * G, G, TOP), (0, D + G / 2, TOP / 2))
	# lambriul: șipci verticale închise la fiecare 30 cm, plinta, brâul, cornișa
	def sipci(x0, x1, y0, y1, axa, spre):
		lung = (x1 - x0) if axa == "x" else (y1 - y0)
		for i in range(1, int(lung / 0.3)):
			u = (x0 if axa == "x" else y0) + i * 0.3
			if axa == "x":
				if USA[0] - 0.05 < u < USA[1] + 0.05 or VITRINA[0] - 0.05 < u < VITRINA[1] + 0.05:
					continue
				piese.append(cub("Sipca", (0.02, 0.012, HC - FL - 0.2), (u, y0 + spre * 0.006, (FL + HC) / 2 + 0.05), LEMN_INCHIS))
			else:
				piese.append(cub("Sipca", (0.012, 0.02, HC - FL - 0.2), (x0 + spre * 0.006, u, (FL + HC) / 2 + 0.05), LEMN_INCHIS))
		if axa == "x":
			piese.append(cub("Plinta", (lung, 0.03, 0.12), ((x0 + x1) / 2, y0 + spre * 0.015, FL + 0.06), LEMN_INCHIS))
			piese.append(cub("Cornisa", (lung, 0.06, 0.1), ((x0 + x1) / 2, y0 + spre * 0.03, HC - 0.05), LEMN_INCHIS))
		else:
			piese.append(cub("Plinta", (0.03, lung, 0.12), (x0 + spre * 0.015, (y0 + y1) / 2, FL + 0.06), LEMN_INCHIS))
			piese.append(cub("Cornisa", (0.06, lung, 0.1), (x0 + spre * 0.03, (y0 + y1) / 2, HC - 0.05), LEMN_INCHIS))
	sipci(-W, -W, G, D, "y", 1)
	sipci(W, W, G, D, "y", -1)
	for a, b in ((-W, VITRINA[0]), (VITRINA[1], USA[0]), (USA[1], W)):
		piese.append(cub("Plinta", (b - a, 0.03, 0.12), ((a + b) / 2, G + 0.015, FL + 0.06), LEMN_INCHIS))
	piese.append(cub("Cornisa", (2 * W, 0.06, 0.1), (0, G + 0.03, HC - 0.05), LEMN_INCHIS))
	strange()

	# --- peretele cu arme din spate: panou cu șanțuri orizontale (slatwall), cu ramă
	px0, px1, pz0, pz1 = -3.7, 3.7, FL + 0.75, HC - 0.25
	piese.append(cub("Panou arme", (px1 - px0, 0.03, pz1 - pz0), ((px0 + px1) / 2, D - 0.015, (pz0 + pz1) / 2), LEMN_DESCHIS))
	z = pz0 + 0.1
	while z < pz1 - 0.05:
		piese.append(cub("Sant panou", (px1 - px0 - 0.04, 0.012, 0.018), ((px0 + px1) / 2, D - 0.036, z), LEMN_INCHIS))
		z += 0.15
	for x in (px0, px1):
		piese.append(cub("Rama panou", (0.06, 0.06, pz1 - pz0 + 0.06), (x, D - 0.03, (pz0 + pz1) / 2), LEMN_INCHIS))
	for zz in (pz0, pz1):
		piese.append(cub("Rama panou", (px1 - px0 + 0.06, 0.06, 0.06), ((px0 + px1) / 2, D - 0.03, zz), LEMN_INCHIS))
	strange()

	# --- tavanul: plăci albe, neoane în două rânduri, un detector de fum
	piese.append(cub("Tavan", (2 * W, D - G, 0.1), (0, (G + D) / 2, HC + 0.05), ALB))
	for x in [-W + 1.0 * i for i in range(1, 8)]:
		piese.append(cub("Profil", (0.025, D - G, 0.012), (x, (G + D) / 2, HC - 0.006), METAL))
	for y in [G + 1.0 * j for j in range(1, 7)]:
		piese.append(cub("Profil", (2 * W, 0.025, 0.01), (0, y, HC - 0.016), METAL))
	for x in (-2.0, 1.5):
		for y in (1.7, 4.0, 6.0):
			piese.append(cub("Corp neon", (0.3, 1.25, 0.06), (x, y, HC - 0.05), METAL))
			for dx in (-0.07, 0.07):
				lumini.append(cub("Neon", (0.045, 1.18, 0.03), (x + dx, y, HC - 0.095), ALB))
	piese.append(cilindru("Detector fum", 0.06, 0.06, 0.03, (-0.5, 2.6, HC - 0.035), ALB, laturi=10))
	strange()

	# --- tocul ușii, vitrina (geamul, rama, gratiile de afară, autocolantele)
	a, b, za, zb = USA
	for xx in (a + 0.03, b - 0.03):
		piese.append(cub("Toc", (0.06, G + 0.02, zb - za), (xx, G / 2, (za + zb) / 2), METAL_INCHIS))
	piese.append(cub("Toc", (b - a, G + 0.02, 0.06), ((a + b) / 2, G / 2, zb - 0.03), METAL_INCHIS))
	va, vb, vz0, vz1 = VITRINA
	geamuri.append(cub("Geam", (vb - va, 0.012, vz1 - vz0), ((va + vb) / 2, g2, (vz0 + vz1) / 2), GEAM))
	for xx in (va, vb):
		piese.append(cub("Rama vitrina", (0.06, G + 0.04, vz1 - vz0), (xx, G / 2, (vz0 + vz1) / 2), METAL_INCHIS))
	for zz in (vz0, vz1):
		piese.append(cub("Rama vitrina", (vb - va, G + 0.04, 0.06), ((va + vb) / 2, G / 2, zz), METAL_INCHIS))
	piese.append(cub("Pervaz", (vb - va, 0.3, 0.04), ((va + vb) / 2, G + 0.15, vz0 - 0.02), LEMN_INCHIS))
	# gratiile: bare verticale, două traverse, prinse în cărămidă
	xx = va + 0.12
	while xx < vb - 0.05:
		piese.append(cilindru("Gratie", 0.012, 0.012, vz1 - vz0 + 0.1, (xx, -0.05, (vz0 + vz1) / 2), NEGRU, laturi=6))
		xx += 0.14
	for zz in (vz0 + 0.25, vz1 - 0.25):
		piese.append(cub("Traversa", (vb - va + 0.1, 0.02, 0.03), ((va + vb) / 2, -0.07, zz), NEGRU))
	for continut, xx, zz, marime, cul in (("GUNS  AMMO  KNIVES", -1.25, 2.2, 0.13, ALB), ("WE BUY GUNS", -1.25, 1.1, 0.12, AUR)):
		piese.append(_text_o_fata("Autocolant", continut, (xx, g2 - 0.009, zz), marime, cul))
		piese.append(_text_o_fata("Autocolant", continut, (xx, g2 + 0.009, zz), marime, cul, rot=(1.5708, 0, 3.14159)))
	# soclul de beton de sub vitrină și un aplic de lumină deasupra ușii
	for sa, sb in ((-W - G, USA[0]), (USA[1], W + G)):  # (nu și prin dreptul ușii)
		piese.append(cub("Soclu", (sb - sa, 0.03, 0.45), ((sa + sb) / 2, -0.015, 0.225), BETON))
	piese.append(cub("Aplica usa", (0.3, 0.16, 0.08), ((a + b) / 2, -0.08, zb + 0.25), NEGRU))
	lumini.append(cub("Bec usa", (0.2, 0.1, 0.03), ((a + b) / 2, -0.08, zb + 0.2), AUR))
	# camera de supraveghere în colțul din dreapta-sus al fațadei
	piese.append(cub("Camera supraveghere", (0.1, 0.22, 0.09), (W - 0.2, -0.2, TOP - 0.35), ALB, rot=(0.3, 0, -0.4)))
	piese.append(cub("Suport camera", (0.04, 0.12, 0.04), (W - 0.15, -0.07, TOP - 0.3), METAL))
	strange()

	# --- parapetul cu bannerul
	PZ0, PZ1 = TOP, TOP + 1.35
	piese.append(cub("Parapet", (2 * W + 2 * G, G, PZ1 - PZ0), (0, G / 2, (PZ0 + PZ1) / 2), CARAMIDA))
	piese.append(cub("Copertina parapet", (2 * W + 2 * G + 0.1, G + 0.1, 0.06), (0, G / 2, PZ1 + 0.03), METAL))
	piese.append(cub("Acoperis", (2 * W + 2 * G - 0.04, D + G - 0.04, 0.25), (0, (D + G) / 2, TOP - 0.135), METAL_INCHIS))
	_cutie_coliziune(col, (2 * W + 2 * G, D + G, 0.3), (0, (D + G) / 2, TOP - 0.15))
	banner(piese, PZ0 + 0.1, PZ1 - 0.12)
	strange()

	# fețele lipite (desenele bannerului pe placa lui, rosturile, ramele): piesa mai mică iese puțin în față
	desparte_fete(fixe=("Fatada", "Fatada int", "Perete lateral", "Spate", "Spate int", "Sapa", "Tavan", "Parapet",
		"Acoperis", "Banner", "Lambriu", "Scandura"))
	uneste(piese, "Cladire")
	uneste(lumini, "Lumini")
	uneste(geamuri, "Geamuri")
	uneste(col, "Coliziune")
	exporta(os.path.join(cale, "magazin_arme_cladire.glb"))


def banner(piese, z0, z1):
	"""Bannerul de pe parapet (fața spre -Y): placa neagră cu tiv roșu, steagul american (13 dungi, 50 de stele) în stânga,
	„FREEDOM” mare în mijloc (cu umbră roșie), „GUNS & AMMO • EST. 1776” dedesubt, un Glock din profil în dreapta."""
	bw = 2 * W + 0.1
	zm = (z0 + z1) / 2
	piese.append(cub("Banner", (bw, 0.03, z1 - z0), (0, -0.03, zm), NEGRU))
	for zz in (z0 + 0.02, z1 - 0.02):
		# tivul iese puțin peste muchiile plăcii (jos, sus, în lateral): cu ele în același plan se băteau
		piese.append(cub("Tiv banner", (bw + 0.01, 0.04, 0.05), (0, -0.04, zz), ROSU))
	for xx in (-bw / 2 + 0.02, bw / 2 - 0.02):
		piese.append(cub("Tiv banner", (0.05, 0.04, z1 - z0 + 0.01), (xx, -0.04, zm), ROSU))
	for sx in (-1, 1):  # șuruburile cu care e prins
		for zz in (z0 + 0.12, z1 - 0.12):
			piese.append(cilindru("Surub", 0.02, 0.02, 0.012, (sx * (bw / 2 - 0.12), -0.064, zz), CROM, laturi=6, rot=(1.5708, 0, 0)))
	# fața desenelor: la 2,5 cm în fața plăcii (la 0,7 cm dungile steagului se băteau cu placa pe ecran, de jos din stradă)
	y = -0.07
	# --- steagul american: 13 dungi (roșu sus și jos), cantonul albastru cu 50 de stele (rânduri de 6 și de 5)
	fx0, fx1 = -bw / 2 + 0.2, -1.55
	fz0, fz1 = z0 + 0.14, z1 - 0.14
	h = (fz1 - fz0) / 13
	for i in range(13):
		zz = fz1 - h * (i + 0.5)
		piese.append(cub("Dunga steag", (fx1 - fx0, 0.01, h), ((fx0 + fx1) / 2, y, zz), ROSU if i % 2 == 0 else ALB))
	cx1, cz0 = fx0 + (fx1 - fx0) * 0.4, fz1 - h * 7
	piese.append(cub("Canton", (cx1 - fx0, 0.012, fz1 - cz0), ((fx0 + cx1) / 2, y - 0.006, (cz0 + fz1) / 2), ALBASTRU))
	for r in range(9):
		cate = 6 if r % 2 == 0 else 5
		for c in range(cate):
			sx = fx0 + (cx1 - fx0) * ((c + (0.5 if cate == 6 else 1.0)) / 6.0)
			sz = fz1 - (fz1 - cz0) * ((r + 1) / 10.0)
			piese.append(cub("Stea", (0.026, 0.008, 0.026), (sx, y - 0.016, sz), ALB, rot=(0, 0.785, 0)))
	# catargul mic de sub steag (doar un bețișor de aur, ca la steagurile de birou), ca să nu fie doar un dreptunghi
	piese.append(cilindru("Catarg", 0.015, 0.015, fz1 - fz0 + 0.12, (fx0 - 0.06, y, (fz0 + fz1) / 2), AUR, laturi=6))
	piese.append(sfera("Varf catarg", 0.03, (fx0 - 0.06, y, fz1 + 0.08), AUR, segmente=6, inele=4))
	# --- „FREEDOM”: literele albe, cu o umbră roșie puțin în dreapta-jos (relief)
	tx = 0.08
	piese.append(_text("Umbra freedom", "FREEDOM", (tx + 0.035, y + 0.004, zm + 0.1 - 0.035), 0.58, ROSU))
	piese.append(_text("Litere freedom", "FREEDOM", (tx, y - 0.01, zm + 0.1), 0.58, ALB))
	piese.append(cub("Linie", (2.3, 0.01, 0.025), (tx, y, zm - 0.24), AUR))
	piese.append(_text("Scris banner", "GUNS & AMMO  *  EST. 1776", (tx, y - 0.01, zm - 0.36), 0.12, AUR))
	# --- Glock-ul din profil (țeava spre dreapta): închizătorul cu zimți, cadrul, mânerul înclinat, trăgaciul, apărătoarea
	gx, gz = 2.75, zm + 0.02
	piese.append(cub("Inchizator", (1.55, 0.016, 0.26), (gx, y - 0.004, gz + 0.12), CROM))
	for i in range(7):  # zimții din spate
		piese.append(cub("Zimt", (0.025, 0.01, 0.2), (gx - 0.72 + i * 0.05, y - 0.016, gz + 0.12), METAL_INCHIS))
	piese.append(cub("Fereastra evacuare", (0.3, 0.01, 0.08), (gx + 0.05, y - 0.016, gz + 0.2), NEGRU))
	piese.append(cub("Inaltator", (0.05, 0.01, 0.05), (gx + 0.7, y - 0.012, gz + 0.27), METAL_INCHIS))
	piese.append(cub("Inaltator", (0.06, 0.01, 0.05), (gx - 0.68, y - 0.012, gz + 0.27), METAL_INCHIS))
	piese.append(cub("Cadru", (1.4, 0.016, 0.13), (gx + 0.05, y, gz - 0.06), METAL))
	piese.append(cub("Sina", (0.4, 0.01, 0.025), (gx + 0.45, y - 0.012, gz - 0.11), METAL_INCHIS))
	piese.append(cub("Maner", (0.36, 0.016, 0.72), (gx - 0.48, y, gz - 0.36), METAL, rot=(0, -0.3, 0)))
	for i in range(5):  # canelurile mânerului
		piese.append(cub("Canelura", (0.3, 0.01, 0.02), (gx - 0.42 - 0.04 * i, y - 0.012, gz - 0.2 - 0.11 * i), METAL_INCHIS, rot=(0, -0.3, 0)))
	piese.append(cub("Aparatoare", (0.42, 0.016, 0.045), (gx - 0.02, y, gz - 0.33), METAL))
	piese.append(cub("Aparatoare", (0.045, 0.016, 0.2), (gx + 0.18, y, gz - 0.23), METAL, rot=(0, 0.3, 0)))
	piese.append(cub("Tragaci", (0.035, 0.012, 0.14), (gx - 0.02, y - 0.006, gz - 0.2), METAL_INCHIS, rot=(0, 0.2, 0)))
	piese.append(cilindru("Gura teava", 0.06, 0.06, 0.01, (gx + 0.776, y - 0.004, gz + 0.12), NEGRU, laturi=10, rot=(0, 1.5708, 0)))


# ---------------------------------------------------------------------------------------------------------------
# Strada
# ---------------------------------------------------------------------------------------------------------------

def strada(cale):
	"""Strada din fața magazinului: trotuarul, bordura, asfaltul, trotuarul și blocurile de vizavi, terenul (iarbă) de sub
	tot; în stânga o băutură („LIQUOR”), în dreapta un maidan cu gard de plasă, un tomberon și o mașină arsă, apoi un
	diner închis. Piese: `Strada`, `Lumini`, `Coliziune`."""
	curata()
	r = random.Random(17)
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
	# hidrant, stâlp de iluminat
	piese += [
		cilindru("Hidrant", 0.11, 0.11, 0.55, (-5.6, -2.9, FL + 0.275), ROSU, laturi=8),
		sfera("Hidrant cap", 0.11, (-5.6, -2.9, FL + 0.55), ROSU, scara=(1, 1, 0.7), segmente=8, inele=4),
		cilindru("Stalp", 0.07, 0.09, 6.5, (-9.5, -3.1, FL + 3.25), METAL, laturi=8),
		os_intre("Brat stalp", (-9.5, -3.1, FL + 6.3), (-9.5, -4.6, FL + 6.5), 0.04, METAL, laturi=6),
		cub("Lampa stalp", (0.25, 0.5, 0.1), (-9.5, -4.7, FL + 6.45), METAL_INCHIS),
	]
	_cutie_coliziune(col, (0.2, 0.2, 6.5), (-9.5, -3.1, FL + 3.25))
	# --- stânga: magazinul de băuturi („LIQUOR”), cu vitrine pline de afișe
	vx0, vx1 = -17.0, -W - G - 0.01
	piese.append(cub("Vecin stanga", (vx1 - vx0, 12.0, 4.6), ((vx0 + vx1) / 2, 6.0, 2.3), p("a56850")))
	_cutie_coliziune(col, (vx1 - vx0, 12.0, 4.6), ((vx0 + vx1) / 2, 6.0, 2.3))
	piese.append(cub("Soclu vecin", (vx1 - vx0, 0.03, 0.5), ((vx0 + vx1) / 2, -0.015, 0.25), BETON))
	for xx in (-14.5, -11.0):
		piese.append(cub("Vitrina liquor", (2.8, 0.02, 1.7), (xx, -0.012, 1.55), GEAM))
		for k in range(4):
			cul = (ROSU, AUR, ALB, p("5b6d4e"))[k]
			piese.append(cub("Afis", (0.45, 0.012, 0.6), (xx - 1.0 + k * 0.66, -0.03, 1.4 + 0.25 * (k % 2)), cul))
	piese.append(cub("Usa liquor", (1.0, 0.04, 2.2), (-7.6, -0.02, 1.1), METAL_INCHIS))
	piese.append(cub("Firma liquor", (4.6, 0.14, 0.75), (-11.5, -0.07, 3.7), NEGRU))
	lumini.append(_text("Litere liquor", "LIQUOR", (-11.5, -0.15, 3.7), 0.55, ROSU))
	lumini.append(_text("Scris liquor", "COLD BEER", (-7.4, -0.03, 3.0), 0.16, AUR))
	# --- dreapta: maidanul cu gard de plasă, tomberonul, mașina arsă; apoi diner-ul închis
	mx0, mx1 = W + G + 0.01, 13.5  # până în diner (altfel rămânea o gaură între gard și diner)
	piese.append(cub("Pietris", (mx1 - mx0, 12.0, 0.04), ((mx0 + mx1) / 2, 6.0, FL - 0.02), p("70706e")))
	_cutie_coliziune(col, (mx1 - mx0, 12.0, 0.2), ((mx0 + mx1) / 2, 6.0, FL - 0.1))
	gy = 0.6  # gardul, puțin în spatele trotuarului
	xx = mx0 + 0.1
	while xx < mx1:
		piese.append(cilindru("Stalp gard", 0.03, 0.03, 2.0, (xx, gy, FL + 1.0), METAL, laturi=6))
		xx += 2.2
	piese.append(os_intre("Teava gard", (mx0 + 0.1, gy, FL + 2.0), (mx1, gy, FL + 2.0), 0.022, METAL, laturi=6))
	for k in range(int((mx1 - mx0) / 0.12)):  # ochiurile plasei: diagonale în ambele sensuri
		x0 = mx0 + 0.1 + k * 0.12
		for semn in (-1, 1):
			a = (x0, gy, FL + 0.05)
			b = (x0 + semn * 0.4, gy, FL + 1.95)
			if mx0 + 0.1 <= b[0] <= mx1:
				piese.append(os_intre("Plasa", a, b, 0.004, CROM, laturi=3))
	_cutie_coliziune(col, (mx1 - mx0, 0.1, 2.0), ((mx0 + mx1) / 2, gy, FL + 1.0))
	piese.append(cub("Afis gard", (0.7, 0.012, 0.45), (8.0, gy - 0.03, FL + 1.3), ALB))
	piese.append(_text("Scris afis", "NO\nTRESPASSING", (8.0, gy - 0.04, FL + 1.3), 0.08, ROSU))
	# tomberonul verde și mașina arsă din maidan
	piese.append(cub("Tomberon", (1.8, 1.1, 1.2), (10.5, 3.5, FL + 0.6), VERDE_INCHIS))
	piese.append(cub("Capac tomberon", (1.85, 1.15, 0.06), (10.5, 3.5, FL + 1.23), NEGRU, rot=(0.15, 0, 0)))
	piese.append(cub("Masina arsa", (1.8, 4.2, 0.7), (7.4, 6.2, FL + 0.55), p("48313b"), rot=(0, 0, 0.12)))
	piese.append(cub("Cabina arsa", (1.6, 2.0, 0.6), (7.35, 6.5, FL + 1.15), METAL_INCHIS, rot=(0, 0, 0.12)))
	for dx, dy in ((-0.9, 4.9), (0.9, 4.9), (-0.9, 7.5), (0.9, 7.5)):
		piese.append(cilindru("Janta", 0.3, 0.3, 0.2, (7.4 + dx, dy, FL + 0.3), METAL_INCHIS, laturi=8, rot=(0, 1.5708, 0)))
	_cutie_coliziune(col, (1.8, 1.1, 1.2), (10.5, 3.5, FL + 0.6))
	piese.append(cub("Diner", (12.0, 12.0, 4.0), (19.5, 6.0, 2.0), p("6f6d7f")))
	_cutie_coliziune(col, (12.0, 12.0, 4.0), (19.5, 6.0, 2.0))  # (fără ea treceai prin diner și ajungeai în maidan)
	piese.append(cub("Oblon diner", (6.0, 0.04, 2.4), (18.0, -0.02, 1.3), METAL))
	piese.append(cub("Firma diner", (3.6, 0.12, 0.7), (18.0, -0.06, 3.3), ALB))
	piese.append(_text("Scris diner", "DINER", (18.0, -0.13, 3.3), 0.42, ROSU))
	# --- vizavi: blocuri în ceață, cu alei, între ele parcări (ca la casino)
	for k in range(5):
		bx = -40 + k * 20 + r.uniform(-2, 2)
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
		px = -30 + k * 20
		piese.append(cub("Parcare", (3.6, 10.8, 0.04), (px, -20.0, -0.04), NEGRU))
	uneste(piese, "Strada")
	uneste(lumini, "Lumini")
	uneste(col, "Coliziune")
	exporta(os.path.join(cale, "magazin_arme_strada.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Decorul de dinăuntru
# ---------------------------------------------------------------------------------------------------------------

def _cutie_munitie(piese, x, y, z, cul, r, lat=0.16):
	"""O cutie de cartușe pe raft (cu fața spre +X): cutia, eticheta albă."""
	w, d, h = 0.1 + r.uniform(0, 0.03), lat, 0.08 + r.uniform(0, 0.04)
	piese.append(cub("Cutie munitie", (w, d, h), (x, y, z + h / 2), cul))
	piese.append(cub("Eticheta munitie", (0.008, d * 0.7, h * 0.45), (x + w / 2 + 0.004, y, z + h / 2), ALB))
	return h


def decor(cale):
	"""Dinăuntru: tejgheaua de lemn cu vitrina de sticlă (pistoale și cuțite pe postav), casa de marcat, clopoțelul,
	cana, ușița batantă de la capătul tejghelei, rafturile cu muniție (stânga), steagul mare, trofeul cu coarne,
	afișele („WE DON'T DIAL 911”, „2ND AMENDMENT”, „NO REFUNDS”, „CASH ONLY”), ținte de hârtie, preșul de la
	intrare, scaunul înalt al vânzătorului, coșul de gunoi, etichetele de preț. Piese: `Decor`, `Lumini`, `Geamuri`
	(sticla vitrinei), `Coliziune`."""
	curata()
	r = random.Random(23)
	piese, lumini, geamuri, col = [], [], [], []

	def strange():
		piese[:] = [uneste(piese, "Decor")]

	# --- tejgheaua: dulapul de lemn, vitrina de sticlă deasupra (rama de lemn, postavul), blatul de sticlă
	zc = FL + 0.4  # unde începe vitrina
	piese.append(cub("Dulap tejghea", (TX1 - TX0, TY1 - TY0, zc - FL - 0.08), ((TX0 + TX1) / 2, (TY0 + TY1) / 2, (FL + 0.08 + zc) / 2), LEMN))
	piese.append(cub("Plinta tejghea", (TX1 - TX0 + 0.02, TY1 - TY0 + 0.02, 0.08), ((TX0 + TX1) / 2, (TY0 + TY1) / 2, FL + 0.04),
		LEMN_INCHIS))
	for i in range(8):
		xx = TX0 + 0.25 + i * 0.5
		piese.append(cub("Panou tejghea", (0.42, 0.012, 0.18), (xx, TY0 - 0.006, FL + 0.24), LEMN_INCHIS))
	piese.append(cub("Postav vitrina", (TX1 - TX0 - 0.06, TY1 - TY0 - 0.06, 0.02), ((TX0 + TX1) / 2, (TY0 + TY1) / 2, zc + 0.01),
		p("445d46")))
	geamuri.append(cub("Geam", (TX1 - TX0 - 0.06, 0.012, TZ - zc - 0.05), ((TX0 + TX1) / 2, TY0 + 0.03, (zc + TZ) / 2 - 0.01), GEAM))
	geamuri.append(cub("Geam", (TX1 - TX0 - 0.06, TY1 - TY0 - 0.06, 0.012), ((TX0 + TX1) / 2, (TY0 + TY1) / 2, TZ - 0.006), GEAM))
	for xx in (TX0 + 0.03, TX1 - 0.03):
		geamuri.append(cub("Geam", (0.012, TY1 - TY0 - 0.09, TZ - zc - 0.05), (xx, (TY0 + TY1) / 2, (zc + TZ) / 2 - 0.01), GEAM))
	for xx in (TX0 + 0.015, TX1 - 0.015):  # stâlpii ramei
		for yy in (TY0 + 0.015, TY1 - 0.015):
			piese.append(cub("Rama vitrina", (0.03, 0.03, TZ - zc - 0.012), (xx, yy, (zc + TZ - 0.012) / 2), LEMN_INCHIS))
	for yy in (TY0 + 0.015, TY1 - 0.015):
		piese.append(cub("Rama vitrina", (TX1 - TX0, 0.03, 0.03), ((TX0 + TX1) / 2, yy, TZ + 0.003), LEMN_INCHIS))
	_cutie_coliziune(col, (TX1 - TX0, TY1 - TY0, TZ - FL), ((TX0 + TX1) / 2, (TY0 + TY1) / 2, (FL + TZ) / 2))
	# în vitrină: pistoale (culcate), cuțite, etichete de preț
	for i in range(7):
		xx = TX0 + 0.35 + i * 0.52
		yy = (TY0 + TY1) / 2
		zp = zc + 0.02
		cul = (NEGRU, METAL, NEGRU, p("5e5356"), NEGRU, CROM, NEGRU)[i]
		if i % 3 != 2:  # pistol culcat pe postav
			piese.append(cub("Pistol vitrina", (0.19, 0.03, 0.018), (xx, yy, zp + 0.009), cul))
			piese.append(cub("Maner vitrina", (0.05, 0.11, 0.016), (xx - 0.07, yy - 0.06, zp + 0.008), NEGRU, rot=(0, 0, 0.3)))
		else:  # cuțit
			piese.append(cub("Lama vitrina", (0.18, 0.025, 0.006), (xx + 0.03, yy, zp + 0.003), CROM))
			piese.append(cub("Maner cutit vitrina", (0.11, 0.03, 0.02), (xx - 0.11, yy, zp + 0.01), LEMN_INCHIS))
		piese.append(cub("Pret vitrina", (0.06, 0.035, 0.004), (xx, yy - 0.17, zp + 0.002), ALB))
	strange()
	# pe blat: casa de marcat veche, clopoțelul, cana de cafea, o cutie de cartușe, „CASH ONLY”
	kx, ky = -2.35, (TY0 + TY1) / 2 + 0.05
	piese.append(cub("Casa marcat", (0.36, 0.34, 0.14), (kx, ky, TZ + 0.07), METAL_INCHIS))
	piese.append(cub("Casa marcat", (0.34, 0.16, 0.12), (kx, ky + 0.07, TZ + 0.18), METAL_INCHIS, rot=(-0.4, 0, 0)))
	piese.append(cub("Afisaj casa", (0.18, 0.06, 0.05), (kx, ky + 0.12, TZ + 0.29), NEGRU))
	lumini.append(cub("Cifre casa", (0.13, 0.008, 0.025), (kx, ky + 0.088, TZ + 0.29), p("61a19f")))
	for i in range(2):
		for j in range(4):
			piese.append(cub("Tasta", (0.04, 0.035, 0.012), (kx - 0.09 + j * 0.06, ky - 0.13 + i * 0.05, TZ + 0.146), ALB))
	piese.append(cub("Sertar casa", (0.34, 0.012, 0.06), (kx, ky - 0.176, TZ + 0.05), METAL))
	piese.append(cilindru("Clopotel", 0.045, 0.05, 0.03, (-1.55, TY0 + 0.15, TZ + 0.015), AUR, laturi=10))
	piese.append(sfera("Clopotel", 0.04, (-1.55, TY0 + 0.15, TZ + 0.035), AUR, scara=(1, 1, 0.6), segmente=8, inele=4))
	piese.append(cilindru("Cana", 0.04, 0.04, 0.1, (0.55, TY1 - 0.15, TZ + 0.05), ALB, laturi=10))
	piese.append(_tor("Toarta cana", 0.03, 0.008, (0.6, TY1 - 0.15, TZ + 0.05), ALB, rot=(1.5708, 0, 0), segmente=8))
	piese.append(cilindru("Cafea", 0.035, 0.035, 0.005, (0.55, TY1 - 0.15, TZ + 0.098), LEMN_INCHIS, laturi=10))
	piese.append(cub("Cutie cartuse", (0.16, 0.1, 0.09), (0.15, TY1 - 0.2, TZ + 0.045), ROSU))
	piese.append(cub("Eticheta cartuse", (0.11, 0.008, 0.04), (0.15, TY1 - 0.254, TZ + 0.045), ALB))
	for i in range(6):  # cartușe lângă cutie
		piese.append(cilindru("Cartus", 0.006, 0.006, 0.04, (0.3 + i * 0.02, TY1 - 0.18, TZ + 0.02), AUR, laturi=6))
	piese.append(cub("Carton", (0.3, 0.012, 0.16), (-1.95, TY0 + 0.12, TZ + 0.085), ALB, rot=(-0.2, 0, 0)))
	piese.append(_text("Scris carton", "CASH ONLY", (-1.95, TY0 + 0.11, TZ + 0.088), 0.045, ROSU, rot=(1.5708 - 0.2, 0, 0)))
	# ușița batantă de la capătul din stânga al tejghelei (te oprește să treci în spate)
	ux0, ux1 = -W, TX0
	uy = (TY0 + TY1) / 2
	piese.append(cub("Usita", (ux1 - ux0 - 0.04, 0.05, 0.82), ((ux0 + ux1) / 2, uy, FL + 0.5), LEMN))
	piese.append(cub("Usita blat", (ux1 - ux0 - 0.02, 0.09, 0.04), ((ux0 + ux1) / 2, uy, FL + 0.93), LEMN_INCHIS))
	for zz in (0.3, 0.65):
		piese.append(cub("Usita panou", (ux1 - ux0 - 0.2, 0.012, 0.2), ((ux0 + ux1) / 2, uy - 0.031, FL + zz), LEMN_INCHIS))
	_cutie_coliziune(col, (ux1 - ux0, 0.1, 1.0), ((ux0 + ux1) / 2, uy, FL + 0.5))
	# în dreapta tejghelei, până la perete: un paravan scund
	_cutie_coliziune(col, (W - TX1, 0.1, 1.0), ((TX1 + W) / 2, uy, FL + 0.5))
	piese.append(cub("Paravan", (W - TX1, 0.1, 0.93), ((TX1 + W) / 2, uy, FL + 0.465), LEMN))
	piese.append(cub("Paravan blat", (W - TX1, 0.16, 0.04), ((TX1 + W) / 2, uy, FL + 0.95), LEMN_INCHIS))
	# scaunul înalt al vânzătorului și coșul de gunoi, în spatele tejghelei (scaunul în stânga, să nu fie în drumul lui spre
	# cuțitul de pe perete: owner, 08.10)
	sx = -2.0
	piese.append(cilindru("Scaun inalt", 0.18, 0.18, 0.06, (sx, 6.2, FL + 0.75), ROSU, laturi=10))
	for k in range(4):
		u = k * math.pi / 2 + 0.4
		piese.append(os_intre("Picior scaun", (sx + math.cos(u) * 0.06, 6.2 + math.sin(u) * 0.06, FL + 0.72),
			(sx + math.cos(u) * 0.2, 6.2 + math.sin(u) * 0.2, FL), 0.015, METAL, laturi=4))
	piese.append(cilindru("Cos gunoi", 0.15, 0.13, 0.4, (-2.6, 5.6, FL + 0.2), METAL_INCHIS, laturi=8))
	strange()

	# --- stânga: două corpuri de rafturi cu muniție (cutii colorate, eticheta spre camera)
	rx = -W + 0.22
	for ry0 in (1.0, 2.4):
		ry1 = ry0 + 1.2
		for zz in (FL + 0.02, FL + 0.55, FL + 1.05, FL + 1.55, FL + 2.0):
			piese.append(cub("Polita", (0.4, ry1 - ry0 - 0.03, 0.03), (rx, (ry0 + ry1) / 2, zz), LEMN_INCHIS))
			if zz < FL + 1.9:
				yy = ry0 + 0.12
				while yy < ry1 - 0.12:
					cul = r.choice((ROSU, AUR, p("5b6d4e"), NEGRU, p("295555"), BRONZ))
					_cutie_munitie(piese, rx, yy, zz + 0.015, cul, r, lat=0.14)
					yy += 0.17
		for yy in (ry0, ry1):
			piese.append(cub("Montant raft", (0.4, 0.03, 2.05), (rx, yy, FL + 1.025), LEMN_INCHIS))
		_cutie_coliziune(col, (0.44, ry1 - ry0, 2.05), (rx, (ry0 + ry1) / 2, FL + 1.02))
	strange()
	# ținte de hârtie pe peretele din stânga, deasupra rafturilor (silueta neagră pe alb, cercuri, găuri)
	for yy in (1.6, 3.0):
		piese.append(cub("Tinta", (0.012, 0.5, 0.62), (-W + 0.012, yy, 2.6), ALB))
		piese.append(cub("Silueta", (0.008, 0.26, 0.36), (-W + 0.022, yy, 2.52), NEGRU))
		piese.append(sfera("Cap silueta", 0.07, (-W + 0.022, yy, 2.78), NEGRU, scara=(0.1, 1, 1.15), segmente=8, inele=5))
		for raza in (0.06, 0.12):
			piese.append(_tor("Cerc tinta", raza, 0.006, (-W + 0.03, yy, 2.55), ALB, rot=(0, 1.5708, 0), segmente=16))
		for gx, gz in ((0.03, 2.6), (-0.05, 2.47), (0.07, 2.5)):  # găurile de glonț
			piese.append(cub("Gaura", (0.008, 0.015, 0.015), (-W + 0.036, yy + gx, gz), ALB))
	# pe fațada dinăuntru: „NO REFUNDS” lângă ușă și „SMILE, YOU'RE ON CAMERA” deasupra vitrinei (citite dinăuntru)
	piese.append(cub("Afis", (0.6, 0.012, 0.4), (3.35, G + 0.006, 2.2), ALB))
	piese.append(_text("Scris afis", "NO\nREFUNDS", (3.35, G + 0.015, 2.2), 0.1, ROSU, rot=(1.5708, 0, 3.14159)))
	piese.append(cub("Afis", (0.7, 0.012, 0.3), (-1.25, G + 0.006, 2.72), AUR))
	piese.append(_text("Scris afis", "SMILE, YOU'RE\nON CAMERA", (-1.25, G + 0.015, 2.72), 0.06, NEGRU, rot=(1.5708, 0, 3.14159)))

	# --- dreapta: steagul mare pe perete, „WE DON'T DIAL 911”, „2ND AMENDMENT”
	sx = W - 0.012
	sy0, sy1, sz0, sz1 = 1.0, 3.3, 1.5, 2.7
	h = (sz1 - sz0) / 13
	for i in range(13):
		piese.append(cub("Dunga steag", (0.01, sy1 - sy0, h), (sx, (sy0 + sy1) / 2, sz1 - h * (i + 0.5)), ROSU if i % 2 == 0 else ALB))
	cy1 = sy0 + (sy1 - sy0) * 0.4
	cz0 = sz1 - h * 7
	piese.append(cub("Canton", (0.012, cy1 - sy0, sz1 - cz0), (sx - 0.009, (sy0 + cy1) / 2, (cz0 + sz1) / 2), ALBASTRU))
	for rr in range(9):
		cate = 6 if rr % 2 == 0 else 5
		for c in range(cate):
			yy = sy0 + (cy1 - sy0) * ((c + (0.5 if cate == 6 else 1.0)) / 6.0)
			zz = sz1 - (sz1 - cz0) * ((rr + 1) / 10.0)
			piese.append(cub("Stea", (0.008, 0.018, 0.018), (sx - 0.019, yy, zz), ALB, rot=(0.785, 0, 0)))
	# „WE DON'T DIAL 911” (cu un revolver desenat), lângă tejghea
	piese.append(cub("Placa 911", (0.02, 0.8, 0.5), (W - 0.01, 3.95, 2.2), NEGRU))
	piese.append(_text("Scris 911", "WE DON'T\nDIAL 911", (W - 0.025, 3.95, 2.3), 0.085, AUR, rot=(1.5708, 0, -1.5708)))
	piese.append(cub("Revolver desen", (0.008, 0.3, 0.05), (W - 0.025, 3.9, 2.06), ALB))
	piese.append(cub("Revolver desen", (0.008, 0.07, 0.13), (W - 0.025, 4.06, 2.0), ALB, rot=(-0.4, 0, 0)))
	piese.append(cub("Placa", (0.02, 1.6, 0.25), (W - 0.01, 2.15, 2.86), LEMN_INCHIS))
	piese.append(_text("Scris placa", "2ND AMENDMENT", (W - 0.025, 2.15, 2.86), 0.11, AUR, rot=(1.5708, 0, -1.5708)))
	strange()
	# trofeul cu coarne de cerb pe peretele din spate, în dreapta, deasupra panoului
	tx, ty, tz = 2.6, D - 0.02, 2.55
	piese.append(cub("Placa trofeu", (0.36, 0.04, 0.44), (tx, ty - 0.02, tz), LEMN_INCHIS))
	piese.append(trunchi("Gat cerb", [((tx, ty - 0.04, tz - 0.05), 0.11, 0.1), ((tx, ty - 0.2, tz + 0.02), 0.09, 0.085)], BRONZ, laturi=8))
	piese.append(trunchi("Cap cerb", [((tx, ty - 0.2, tz + 0.03), 0.08, 0.08), ((tx, ty - 0.32, tz - 0.02), 0.06, 0.06),
		((tx, ty - 0.42, tz - 0.06), 0.035, 0.03), ((tx, ty - 0.44, tz - 0.07), 0.0, 0.0)], BRONZ, laturi=8))
	piese.append(sfera("Bot cerb", 0.03, (tx, ty - 0.43, tz - 0.07), NEGRU, segmente=6, inele=4))
	for k in (-1, 1):
		piese.append(sfera("Ochi cerb", 0.015, (tx + 0.055 * k, ty - 0.3, tz + 0.0), NEGRU, segmente=6, inele=4))
		piese.append(cub("Ureche cerb", (0.03, 0.03, 0.1), (tx + 0.1 * k, ty - 0.2, tz + 0.08), BRONZ, rot=(0, 0.8 * k, 0)))
		baza = (tx + 0.05 * k, ty - 0.2, tz + 0.1)
		varf = (tx + 0.22 * k, ty - 0.24, tz + 0.38)
		piese.append(os_intre("Corn", baza, varf, 0.013, ALB, laturi=4))
		for t, dz in ((0.35, 0.14), (0.6, 0.12), (0.85, 0.1)):
			a = tuple(baza[i] + (varf[i] - baza[i]) * t for i in range(3))
			piese.append(os_intre("Ramura corn", a, (a[0] - 0.02 * k, a[1] - 0.06, a[2] + dz), 0.009, ALB, laturi=4))
	# preșul de la intrare: „COME BACK WITH A WARRANT”
	piese.append(cub("Pres", (1.4, 0.9, 0.012), ((USA[0] + USA[1]) / 2, G + 0.55, FL + 0.006), NEGRU))
	piese.append(_text("Scris pres", "COME BACK\nWITH A WARRANT", ((USA[0] + USA[1]) / 2, G + 0.55, FL + 0.014), 0.07, ALB, rot=(0, 0, 0)))
	# etichetele de preț de sub armele de vânzare, pe panoul din spate, și suportul cuțitului
	for continut, xx, zz in (("$500", 0.15, 2.05), ("$250", 0.15, 1.62), ("$25", 0.15, 1.22), ("$5", 0.75, 1.36)):
		piese.append(cub("Eticheta pret", (0.2, 0.012, 0.1), (xx, D - 0.042, zz), ALB))
		piese.append(_text("Scris pret", continut, (xx, D - 0.051, zz), 0.06, ROSU))
	piese.append(cub("Suport cutit", (0.4, 0.04, 0.16), (0.75, D - 0.05, 1.52), LEMN_INCHIS))
	strange()

	uneste(piese, "Decor")
	uneste(lumini, "Lumini")
	uneste(geamuri, "Geamuri")
	uneste(col, "Coliziune")
	exporta(os.path.join(cale, "decor_magazin_arme.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Armele (originea în mâner, țeava spre +Y, sus = +Z)
# ---------------------------------------------------------------------------------------------------------------

def _pe_y(nume, raza, y0, y1, x, z, culoare, laturi=10, raza_sus=None):
	"""Cilindru culcat pe Y, de la y0 la y1 (țevi, tuburi)."""
	return cilindru(nume, raza, raza if raza_sus is None else raza_sus, y1 - y0, (x, (y0 + y1) / 2, z), culoare, laturi=laturi,
		rot=(-1.5708, 0, 0))


def cutit(cale):
	"""Cuțitul de luptă: mânerul negru cu caneluri, garda, lama cu vârf „clip point”, canalul, muchia ascuțită
	(deschisă), zimții de pe cotor. Originea = mijlocul mânerului; lama spre +Y, tăișul în jos."""
	curata()
	from lexy import prisma
	piese = [
		trunchi("Maner cutit", [((0, -0.07, 0), 0.013, 0.017), ((0, -0.03, 0.0), 0.015, 0.02), ((0, 0.015, 0), 0.014, 0.019),
			((0, 0.05, 0), 0.013, 0.017)], NEGRU, laturi=8, ref=(1, 0, 0)),
		cub("Pomel", (0.028, 0.018, 0.038), (0, -0.075, 0), METAL_INCHIS),
		cub("Garda", (0.018, 0.012, 0.072), (0, 0.055, -0.004), METAL_INCHIS),
		prisma("Lama", [(0.06, -0.019), (0.205, -0.019), (0.272, 0.003), (0.24, 0.016), (0.06, 0.016)], "yz", -0.0025, 0.0025, CROM),
		cub("Tais", (0.006, 0.15, 0.005), (0, 0.132, -0.0165), ALB),
		cub("Canal", (0.0056, 0.11, 0.004), (0, 0.12, 0.004), METAL),
	]
	for i in range(4):
		piese.append(cilindru("Canelura", 0.0155, 0.0155, 0.004, (0, -0.05 + i * 0.022, 0), METAL_INCHIS, laturi=8, rot=(-1.5708, 0, 0),
			scara=(1, 1.25, 1)))
	for i in range(6):
		piese.append(cub("Zimt", (0.0048, 0.008, 0.008), (0, 0.08 + i * 0.013, 0.017), CROM, rot=(0.785, 0, 0)))
	uneste(piese, "Cutit")
	exporta(os.path.join(cale, "cutit.glb"))


def shotgun(cale):
	"""Shotgun-ul cu pompă: patul de lemn, receptorul negru cu fereastra de evacuare (pe dreapta, +X), apărătoarea
	trăgaciului, țeava și tubul magaziei, înălțătorul (bila albă). `Pompa` (lemn cu caneluri) e piesă separată: se trage
	înapoi (spre patul armei) și revine după fiecare foc. Originea = mânerul (gâtul patului)."""
	curata()
	lemn = p("904a40")
	piese = [
		trunchi("Pat", [((0, -0.43, -0.06), 0.021, 0.075), ((0, -0.3, -0.045), 0.02, 0.06), ((0, -0.15, -0.012), 0.018, 0.034),
			((0, -0.06, -0.002), 0.019, 0.028)], lemn, laturi=8, ref=(1, 0, 0)),
		cub("Talpa pat", (0.044, 0.016, 0.152), (0, -0.437, -0.06), NEGRU),
		cub("Receptor", (0.046, 0.26, 0.072), (0, 0.06, 0.004), NEGRU),
		cub("Receptor sus", (0.04, 0.24, 0.012), (0, 0.06, 0.046), METAL_INCHIS),
		cub("Fereastra evacuare", (0.008, 0.08, 0.028), (0.027, 0.09, 0.014), METAL_INCHIS),
		cub("Aparatoare", (0.012, 0.09, 0.008), (0, 0.0, -0.064), NEGRU),
		cub("Aparatoare", (0.012, 0.008, 0.035), (0, 0.042, -0.048), NEGRU),
		cub("Tragaci", (0.008, 0.01, 0.026), (0, 0.012, -0.045), METAL, rot=(0.3, 0, 0)),
		_pe_y("Teava", 0.0135, 0.19, 0.67, 0, 0.022, METAL_INCHIS, laturi=10),
		_pe_y("Tub magazie", 0.0125, 0.19, 0.58, 0, -0.012, NEGRU, laturi=10),
		_pe_y("Capac magazie", 0.014, 0.58, 0.6, 0, -0.012, METAL, laturi=10),
		cub("Brida", (0.03, 0.02, 0.05), (0, 0.585, 0.005), METAL),
		sfera("Inaltator", 0.006, (0, 0.655, 0.039), ALB, segmente=6, inele=4),
		_pe_y("Gura teava", 0.0145, 0.66, 0.672, 0, 0.022, NEGRU, laturi=10),
		cub("Curea prindere", (0.008, 0.02, 0.012), (0, -0.38, -0.12), METAL),
	]
	uneste(piese, "Shotgun")
	pompa = [trunchi("Pompa", [((0, 0.24, -0.008), 0.023, 0.025), ((0, 0.26, -0.008), 0.026, 0.028), ((0, 0.41, -0.008), 0.026, 0.028),
		((0, 0.43, -0.008), 0.023, 0.025)], lemn, laturi=10, ref=(1, 0, 0))]
	for i in range(6):
		pompa.append(_pe_y("Canelura pompa", 0.0285, 0.275 + i * 0.022, 0.283 + i * 0.022, 0, -0.008, p("5e363e"), laturi=10))
	uneste(pompa, "Pompa", (0, 0.33, -0.008))
	exporta(os.path.join(cale, "shotgun.glb"))


def ak47(cale):
	"""AK-47: patul și garda de lemn portocaliu, receptorul cu capacul, mânerul de pistol, trăgaciul, tubul de gaze,
	țeava cu frâna de gură, cătarea și înălțătorul. Piese separate pentru animații: `Incarcator` (curbat, se scoate și
	se pune la reîncărcare; originea sus, unde intră în armă) și `Manivela` (maneta de armare din dreapta, +X: merge
	înapoi la fiecare foc). Originea = mânerul de pistol."""
	curata()
	lemn = p("904a40")
	piese = [
		trunchi("Pat", [((0, -0.46, -0.05), 0.02, 0.06), ((0, -0.32, -0.035), 0.019, 0.048), ((0, -0.15, 0.0), 0.018, 0.03),
			((0, -0.11, 0.004), 0.019, 0.03)], lemn, laturi=8, ref=(1, 0, 0)),
		cub("Talpa pat", (0.042, 0.012, 0.125), (0, -0.465, -0.05), METAL_INCHIS),
		cub("Receptor", (0.042, 0.33, 0.06), (0, 0.05, 0.004), METAL_INCHIS),
		cub("Capac receptor", (0.038, 0.3, 0.022), (0, 0.04, 0.044), METAL),
		cub("Selector", (0.006, 0.12, 0.012), (0.026, 0.04, 0.016), NEGRU),
		cub("Maner", (0.03, 0.04, 0.1), (0, -0.075, -0.07), lemn, rot=(-0.3, 0, 0)),
		cub("Aparatoare", (0.012, 0.085, 0.008), (0, -0.01, -0.058), METAL_INCHIS),
		cub("Tragaci", (0.008, 0.01, 0.024), (0, -0.02, -0.04), NEGRU, rot=(0.3, 0, 0)),
		cub("Garda jos", (0.048, 0.18, 0.046), (0, 0.3, -0.006), lemn),
		cub("Garda sus", (0.034, 0.15, 0.022), (0, 0.29, 0.042), lemn),
		_pe_y("Tub gaze", 0.01, 0.21, 0.45, 0, 0.047, METAL_INCHIS, laturi=8),
		cub("Bloc gaze", (0.026, 0.03, 0.04), (0, 0.455, 0.03), METAL_INCHIS),
		_pe_y("Teava", 0.0095, 0.385, 0.6, 0, 0.012, NEGRU, laturi=8),
		_pe_y("Frana gura", 0.013, 0.6, 0.64, 0, 0.012, METAL_INCHIS, laturi=8),
		cub("Catare", (0.006, 0.006, 0.04), (0, 0.545, 0.04), NEGRU),
		cub("Suport catare", (0.024, 0.02, 0.025), (0, 0.545, 0.025), NEGRU),
		cub("Inaltator", (0.026, 0.05, 0.016), (0, 0.205, 0.052), METAL_INCHIS),
	]
	for i in range(4):
		piese.append(cub("Canelura garda", (0.05, 0.008, 0.006), (0, 0.24 + i * 0.035, -0.02), p("5e363e")))
	uneste(piese, "AK47")
	inc = [trunchi("Incarcator", [((0, 0.035, -0.03), 0.013, 0.036), ((0, 0.045, -0.09), 0.013, 0.036), ((0, 0.07, -0.15), 0.013, 0.036),
		((0, 0.105, -0.2), 0.013, 0.035), ((0, 0.115, -0.212), 0.012, 0.033)], METAL_INCHIS, laturi=8, ref=(1, 0, 0))]
	for t in (-0.07, -0.12, -0.17):  # nervurile încărcătorului
		inc.append(cub("Nervura", (0.0275, 0.012, 0.01), (0, 0.035 + (-0.03 - t) * 0.6, t), METAL, rot=(-(-0.03 - t) * 3.0, 0, 0)))
	uneste(inc, "Incarcator", (0, 0.035, -0.03))
	uneste([cub("Manivela", (0.03, 0.016, 0.014), (0.034, 0.17, 0.026), METAL), cub("Tija manivela", (0.012, 0.012, 0.012),
		(0.02, 0.17, 0.026), METAL)], "Manivela", (0.034, 0.17, 0.026))
	exporta(os.path.join(cale, "ak47.glb"))


def bazooka(cale):
	"""Bazooka (tub de 1,5 m, verde-măsliniu): pâlnia din spate, inelele, sprijinul de umăr, două mânere, carcasa
	trăgaciului, cătarea rabatabilă în stânga, dungile galbene de avertizare. `Racheta` (vârful focosului, văzut în gura
	tubului) e piesă separată: dispare la tragere și intră la loc la reîncărcare. Originea = mânerul din spate."""
	curata()
	piese = [
		_pe_y("Tub", 0.045, -0.8, 0.66, 0, 0.0, MASLINIU, laturi=12),
		_pe_y("Palnie", 0.062, -0.92, -0.8, 0, 0.0, VERDE_INCHIS, laturi=12, raza_sus=0.046),
		_pe_y("Gura tub", 0.05, 0.62, 0.67, 0, 0.0, VERDE_INCHIS, laturi=12),
		cub("Sprijin umar", (0.05, 0.26, 0.05), (0, -0.33, -0.07), VERDE_INCHIS),
		cub("Perna umar", (0.06, 0.22, 0.02), (0, -0.33, -0.1), NEGRU),
		cub("Maner", (0.032, 0.045, 0.13), (0, 0.0, -0.1), NEGRU, rot=(-0.25, 0, 0)),
		cub("Carcasa tragaci", (0.04, 0.12, 0.04), (0, 0.04, -0.055), VERDE_INCHIS),
		cub("Tragaci", (0.008, 0.012, 0.026), (0, 0.06, -0.085), METAL, rot=(0.3, 0, 0)),
		cub("Maner fata", (0.03, 0.04, 0.1), (0, 0.3, -0.09), NEGRU),
		cub("Suport catare", (0.02, 0.1, 0.02), (-0.052, 0.12, 0.03), METAL_INCHIS),
		cub("Catare", (0.035, 0.08, 0.05), (-0.072, 0.12, 0.06), NEGRU),
		cilindru("Lentila", 0.016, 0.016, 0.01, (-0.072, 0.07, 0.06), GEAM, laturi=8, rot=(-1.5708, 0, 0)),
		cub("Cablu", (0.008, 0.6, 0.008), (0.047, -0.25, 0.0), NEGRU),
	]
	for y in (-0.55, -0.2, 0.2, 0.5):
		piese.append(_pe_y("Inel", 0.0485, y - 0.02, y + 0.02, 0, 0.0, METAL_INCHIS, laturi=12))
	for y in (-0.72, -0.66):
		piese.append(_pe_y("Dunga galbena", 0.0475, y - 0.015, y + 0.015, 0, 0.0, AUR, laturi=12))
	uneste(piese, "Bazooka")
	uneste([trunchi("Racheta", [((0, 0.5, 0.0), 0.04, 0.04), ((0, 0.6, 0.0), 0.04, 0.04), ((0, 0.66, 0.0), 0.03, 0.03),
		((0, 0.7, 0.0), 0.0, 0.0)], MASLINIU, laturi=10, ref=(1, 0, 0)),
		_pe_y("Banda racheta", 0.0405, 0.56, 0.575, 0, 0.0, AUR, laturi=10)], "Racheta", (0, 0.6, 0))
	exporta(os.path.join(cale, "bazooka.glb"))


def racheta(cale):
	"""Racheta care zboară (bazooka): corpul, focosul ascuțit, banda galbenă, aripioarele din spate, duza. Originea =
	mijlocul, vârful spre +Y."""
	curata()
	piese = [
		_pe_y("Corp racheta", 0.035, -0.17, 0.1, 0, 0, METAL_INCHIS, laturi=10),
		trunchi("Focos", [((0, 0.1, 0), 0.042, 0.042), ((0, 0.2, 0), 0.04, 0.04), ((0, 0.27, 0), 0.02, 0.02), ((0, 0.3, 0), 0.0, 0.0)],
			MASLINIU, laturi=10, ref=(1, 0, 0)),
		_pe_y("Banda racheta", 0.043, 0.13, 0.15, 0, 0, AUR, laturi=10),
		_pe_y("Duza", 0.032, -0.2, -0.17, 0, 0, NEGRU, laturi=10, raza_sus=0.025),
	]
	for k in range(4):
		u = k * math.pi / 2 + math.pi / 4
		piese.append(cub("Aripioara", (0.004, 0.08, 0.05), (math.cos(u) * 0.055, -0.13, math.sin(u) * 0.055), MASLINIU, rot=(0, u, 0)))
	uneste(piese, "Racheta")
	exporta(os.path.join(cale, "racheta.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Vânzătorul (Gun Clerk): cowboy modern, în picioare, cu palmele pe tejghea
# ---------------------------------------------------------------------------------------------------------------

VANZATOR = {
	"piele": p("a56850"), "piele_umbra": p("904a40"), "haina": p("5e363e"), "haina_umbra": p("48313b"),
	"camasa": p("7b383a"), "maneca": p("7b383a"), "carouri": p("48313b"), "stil_haina": "vesta", "bolo": p("438b88"),
	"curea": p("48313b"), "toc_pistol": p("5e363e"), "pantaloni": p("295555"), "pantofi": p("904a40"),
	"in_picioare": True, "sezut": 0.86, "masa": TZ - FL,
	"par": p("48313b"), "stil_par": "scurt", "palarie": "cowboy", "culoare_palarie": p("a18463"),
	"culoare_palarie_umbra": p("a56850"), "banda": p("48313b"),
	"mustata": p("48313b"), "mustata_potcoava": p("48313b"), "perciuni": p("48313b"), "tepi": p("5e363e"),
	"scobitoare": True, "incruntat": 0.25, "riduri": True, "gros_brat": 1.05, "burta": 0.35, "nas": 1.1,
	# palmele pe marginea din spate a tejghelei (el stă la 0,28 m în spatele ei)
	"poza_D": ((-0.27, -0.06, 1.15), (-0.16, -0.3, TZ - FL + 0.025)),
	"poza_S": ((0.27, -0.06, 1.15), (0.16, -0.3, TZ - FL + 0.025)),
}


def vanzator(cale):
	casino_oameni.om(cale, "gun_clerk", VANZATOR, 77)


def arme(cale):
	cutit(cale)
	shotgun(cale)
	ak47(cale)
	bazooka(cale)
	racheta(cale)


def toate(cale):
	cladire(cale)
	strada(cale)
	decor(cale)
	arme(cale)
	vanzator(cale)


if __name__ == "__main__":
	cale_modele = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")
	if "--" in sys.argv:
		for nume in sys.argv[sys.argv.index("--") + 1:]:
			globals()[nume](cale_modele)
	else:
		toate(cale_modele)
