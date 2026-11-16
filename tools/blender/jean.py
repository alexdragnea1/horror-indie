# Casa lui Jean (owner 16.11): vecinul din stânga lui Lexy. O singură cameră mare, gotică, victoriană, ca la familia
# Addams: pereți negri, lambriu de lemn închis, tavan cu grinzi, șemineu de marmură neagră, biblioteci, draperii grele
# trase, covor persan, lumânări peste tot (singura lumină). În mijloc masa de șah, cu Jean în tronul lui.
#   blender --background --factory-startup --python tools/blender/jean.py               (toate)
#   blender --background --factory-startup --python tools/blender/jean.py -- piese_sah   (doar unele)
# Modele: camera_jean, masa_sah, piese_sah (12 obiecte: Pion_A ... Rege_N), tron_jean, scaun_sah, sfesnic_inalt,
# sfesnic_masa, candelabru_jean, jean, draperie (pentru geamurile caselor vecine de afară).
# Axe Blender: Z în sus, -Y = spre ușă (în Godot +Z). Originea camerei = mijlocul podelei.
# Culori: doar din paletă. Pereții sunt piesa `PereteNegru` (în Godot primesc material_negru.tres, mai negru decât
# paleta: owner-ul a cerut „pereții negri neapărat”); cravata lui Jean e piesa `CravataRoz` (material_roz.tres).
import math
import os
import random
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, inel, uneste, exporta, trunchi  # noqa: E402
from lexy import perete  # noqa: E402
import casino_oameni  # noqa: E402

NEGRU = p("262d2f")
NEGRU2 = p("2a3c3d")
ALB = p("83b3b0")
AUR = p("a18463")
BRONZ = p("a56850")
LEMN = p("48313b")
LEMN2 = p("553e4d")
VISINIU = p("5e363e")
ROSU = p("7b383a")
CEARA = p("7e8d87")
FLACARA = p("a18463")

# camera
LX = 5.0  # x ±LX
LY = 6.0  # y ±LY (ușa la y = -LY)
H = 4.2
GROS = 0.2
USA = (-0.5, 0.5, 0.0, 2.2)  # golul ușii (pe x, pe z): ușa lui Lexy are 1 × 2,18
FEREASTRA_Y = (-2.6, -1.2)  # golul ferestrelor din pereții laterali (pe y)
FEREASTRA_Z = (0.9, 3.3)
# masa de șah
TZ = 0.76  # blatul
PATRAT = 0.055
TABLA_Z = TZ + 0.02 + 0.006  # fața pătratelor (blat 0,04 → TZ+0,02; pătratele 0,006)


def _strung(nume, profil, culoare, laturi=14, centru=(0, 0)):
	"""Piesă rotundă (strunjită) din profil [(z, raza)], de jos în sus. O rază 0 = vârf."""
	return trunchi(nume, [((centru[0], centru[1], z), r, r) for z, r in profil], culoare, laturi=laturi)


# ---------------------------------------------------------------------------------------------------------------
# Camera
# ---------------------------------------------------------------------------------------------------------------

def camera_jean(cale):
	curata()
	r = random.Random(7)
	negre, lemn, decor, carti, draperii = [], [], [], [], []
	# pereții (negri), cu golul ușii în față și ferestrele în lateral
	perete(negre, "PereteNegru", "x", -LX - GROS, LX + GROS, -LY - GROS, -LY, 0, H, NEGRU, goluri=[USA])
	perete(negre, "PereteNegru", "x", -LX - GROS, LX + GROS, LY, LY + GROS, 0, H, NEGRU)
	for k in (-1, 1):
		x0, x1 = (-LX - GROS, -LX) if k < 0 else (LX, LX + GROS)
		perete(negre, "PereteNegru", "y", -LY, LY, x0, x1, 0, H, NEGRU, goluri=[(*FEREASTRA_Y, *FEREASTRA_Z)])
	# tapetul cu model damasc: romburi abia mai deschise pe negru (se văd doar lângă lumânări)
	for y in [v * 0.6 for v in range(-9, 10)]:
		for z in (1.6, 2.2, 2.8, 3.4):
			for k in (-1, 1):
				if FEREASTRA_Y[0] - 0.3 < y < FEREASTRA_Y[1] + 0.3 and z < FEREASTRA_Z[1] + 0.3:
					continue
				negre.append(cub("PereteNegru", (0.004, 0.09, 0.09), (k * (LX - 0.003), y, z + (0.3 if int(y / 0.6) % 2 else 0)),
					NEGRU2, rot=(math.pi / 4, 0, 0)))
	for x in [v * 0.6 for v in range(-8, 9)]:
		for z in (1.6, 2.2, 2.8, 3.4):
			if abs(x) > 1.4 or z > 3.0:  # nu în spatele portretului de deasupra șemineului
				negre.append(cub("PereteNegru", (0.09, 0.004, 0.09), (x, LY - 0.003, z + (0.3 if int(x / 0.6) % 2 else 0)),
					NEGRU2, rot=(0, math.pi / 4, 0)))
	# podeaua: scânduri vechi, închise, cu câte una mai deschisă sau mai roasă
	x = -LX
	while x < LX - 0.01:
		w = min(0.22, LX - x)
		c = r.choice((LEMN, LEMN, LEMN2, VISINIU))
		lemn.append(cub("Podea", (w - 0.006, 2 * LY, 0.04), (x + w / 2, 0, -0.02), c))
		x += w
	lemn.append(cub("PodeaRost", (2 * LX, 2 * LY, 0.02), (0, 0, -0.035), NEGRU))
	# lambriul: panouri de lemn până la 1,1 m, cu ramă, plintă și brâu
	for k in (-1, 1):
		for latura in ("x", "y"):
			lung = 2 * LX if latura == "x" else 2 * LY
			pas = 0.9
			n = int(lung / pas)
			for i in range(n):
				u = -lung / 2 + (i + 0.5) * lung / n
				if latura == "x":
					if k < 0 and abs(u) < 0.75:
						continue  # ușa
					if k > 0 and abs(u) < 1.3:
						continue  # șemineul
					loc = (u, k * (LY - 0.015), 0.62)
					dim = (lung / n - 0.12, 0.02, 0.62)
				else:
					if FEREASTRA_Y[0] - 0.1 < u < FEREASTRA_Y[1] + 0.1:
						loc = (k * (LX - 0.015), u, 0.5)
						dim = (0.02, lung / n - 0.12, 0.4)
					else:
						loc = (k * (LX - 0.015), u, 0.62)
						dim = (0.02, lung / n - 0.12, 0.62)
				lemn.append(cub("Panou", dim, loc, LEMN2))
		for latura in ("x", "y"):
			for z, gros, inalt, c in ((0.07, 0.05, 0.14, NEGRU), (1.08, 0.045, 0.06, LEMN), (H - 0.12, 0.08, 0.24, LEMN)):
				if latura == "x":
					segmente = [(-LX, -0.6), (0.6, LX)] if (k < 0 and z < 2.3) else [(-LX, LX)]
					for a, b in segmente:
						lemn.append(cub("Bru", (b - a, gros, inalt), ((a + b) / 2, k * (LY - gros / 2), z), c))
				else:
					segmente = [(-LY, LY)]
					if z < FEREASTRA_Z[1] + 0.1 and z > FEREASTRA_Z[0] - 0.1:
						segmente = [(-LY, FEREASTRA_Y[0] - 0.12), (FEREASTRA_Y[1] + 0.12, LY)]
					for a, b in segmente:
						lemn.append(cub("Bru", (gros, b - a, inalt), (k * (LX - gros / 2), (a + b) / 2, z), c))
	# ancadramentul ușii (lemn, cu fronton)
	for k in (-1, 1):
		lemn.append(cub("TocUsa", (0.12, 0.08, 2.35), (k * 0.58, -LY + 0.04, 1.175), LEMN))
	lemn.append(cub("TocUsa", (1.4, 0.1, 0.16), (0, -LY + 0.05, 2.35), LEMN))
	lemn.append(cub("TocUsa", (1.2, 0.06, 0.1), (0, -LY + 0.03, 2.48), BRONZ))
	# tavanul cu grinzi (casete)
	negre.append(cub("PereteNegru", (2 * LX, 2 * LY, 0.1), (0, 0, H + 0.05), NEGRU))
	for x in (-3.0, -1.0, 1.0, 3.0):
		lemn.append(cub("Grinda", (0.22, 2 * LY, 0.24), (x, 0, H - 0.12), LEMN))
	for y in (-4.0, -2.0, 0.0, 2.0, 4.0):
		lemn.append(cub("Grinda", (2 * LX, 0.16, 0.18), (0, y, H - 0.09), LEMN2))
	# rozeta candelabrului
	decor.append(cilindru("Rozeta", 0.28, 0.2, 0.06, (0, 0, H - 0.27), BRONZ, laturi=12))

	# ferestrele: ramă, întuneric în spate, draperii grele trase până jos, pelerina de sus cu ciucuri
	for k in (-1, 1):
		xf = k * (LX + GROS)
		y0, y1 = FEREASTRA_Y
		decor.append(cub("Intuneric", (0.02, y1 - y0, FEREASTRA_Z[1] - FEREASTRA_Z[0]), (xf - k * 0.01, (y0 + y1) / 2,
			(FEREASTRA_Z[0] + FEREASTRA_Z[1]) / 2), NEGRU))
		_draperie_camera(draperii, k * (LX - 0.06), y0 - 0.35, y1 + 0.35, H - 0.3, r, k)

	# șemineul de marmură neagră (pe peretele din spate, în spatele lui Jean)
	ys = LY - 0.25
	decor.append(cub("Semineu", (2.3, 0.5, 1.3), (0, ys, 0.65), NEGRU2))
	decor.append(cub("SemineuGura", (1.0, 0.02, 0.85), (0, ys - 0.26, 0.47), NEGRU))
	decor.append(cub("SemineuInterior", (0.96, 0.4, 0.82), (0, ys - 0.05, 0.46), NEGRU))
	for k in (-1, 1):
		decor.append(cub("Coloana", (0.18, 0.08, 1.2), (k * 0.85, ys - 0.28, 0.62), NEGRU))
		decor.append(cub("Capitel", (0.24, 0.12, 0.08), (k * 0.85, ys - 0.28, 1.25), BRONZ))
	decor.append(cub("Polita", (2.6, 0.62, 0.08), (0, ys - 0.04, 1.34), NEGRU))
	decor.append(cub("PolitaMuchie", (2.62, 0.04, 0.03), (0, ys - 0.355, 1.31), BRONZ))
	# grătarul cu cenușă veche (focul e stins: doar lumânările luminează)
	for i in range(5):
		decor.append(cub("Gratar", (0.012, 0.3, 0.012), (-0.24 + i * 0.12, ys - 0.05, 0.12), NEGRU2))
	for i in range(3):
		decor.append(os_intre("Taciune", (-0.25 + i * 0.2, ys - 0.15, 0.14), (-0.1 + i * 0.2, ys + 0.05, 0.16), 0.025, LEMN, laturi=5))
	decor.append(cub("Cenusa", (0.8, 0.3, 0.02), (0, ys - 0.05, 0.08), CEARA))

	# bibliotecile (peretele din dreapta, +X) și cărțile vechi
	for yb in (-4.2, 1.2, 3.6):
		_biblioteca(lemn, carti, LX - 0.22, yb, r)
	# colțul cu sofaua (stânga, -X) și măsuța cu craniul
	_sofa(decor, -LX + 0.45, 2.6)
	decor.append(_strung("Masuta", [(0, 0.16), (0.02, 0.16), (0.04, 0.05), (0.4, 0.035), (0.52, 0.06), (0.55, 0.22),
		(0.58, 0.22), (0.585, 0)], LEMN, laturi=12, centru=(-LX + 0.5, 0.9)))
	_craniu(decor, (-LX + 0.5, 0.9, 0.585))

	# covorul persan de sub masă: bordura, câmpul, medalionul
	decor.append(cub("Covor", (3.6, 4.6, 0.012), (0, 0.3, 0.006), ROSU))
	decor.append(cub("CovorBordura", (3.3, 4.3, 0.004), (0, 0.3, 0.014), VISINIU))
	decor.append(cub("CovorCamp", (3.0, 4.0, 0.004), (0, 0.3, 0.018), ROSU))
	for k in (-1, 1):
		for kk in (-1, 1):
			decor.append(cub("CovorColt", (0.32, 0.32, 0.004), (k * 1.2, 0.3 + kk * 1.7, 0.022), AUR, rot=(0, 0, math.pi / 4)))
	decor.append(cub("CovorMedalion", (1.0, 1.0, 0.004), (0, 0.3, 0.022), LEMN2, rot=(0, 0, math.pi / 4)))
	decor.append(cub("CovorMedalion2", (0.5, 0.5, 0.004), (0, 0.3, 0.026), AUR, rot=(0, 0, math.pi / 4)))
	for i in range(14):  # franjurile
		for kk in (-1, 1):
			decor.append(cub("Franj", (0.12, 0.08, 0.006), (-1.6 + i * 3.2 / 13, 0.3 + kk * 2.34, 0.004), CEARA))

	# pânze de păianjen în colțurile de sus
	for kx in (-1, 1):
		for ky in (-1, 1):
			for i in range(4):
				a = (kx * (LX - 0.02), ky * (LY - 0.02 - 0.5 - i * 0.12), H - 0.25)
				b = (kx * (LX - 0.5 - i * 0.12), ky * (LY - 0.02), H - 0.25)
				decor.append(os_intre("Panza", a, b, 0.003, CEARA, laturi=3))
			decor.append(os_intre("Panza", (kx * (LX - 0.02), ky * (LY - 0.02), H - 0.25),
				(kx * (LX - 0.4), ky * (LY - 0.4), H - 0.25), 0.003, CEARA, laturi=3))

	# lumânări topite pe jos, lângă perete și pe polița șemineului (flăcările: `Flacara`, strălucesc în joc)
	flacari = []
	for loc in ((-LX + 0.3, -LY + 0.4), (LX - 0.35, -LY + 0.5), (-1.4, LY - 0.35), (1.5, LY - 0.4), (-LX + 0.35, -0.2),
			(LX - 0.3, -1.9), (-LX + 0.4, 4.6), (LX - 0.4, 5.4)):
		_lumanari_topite(decor, flacari, (loc[0], loc[1], 0), r, mult=4)
	for x in (-1.05, -0.75, 0.8, 1.1):
		_lumanari_topite(decor, flacari, (x, ys - 0.1, 1.38), r, mult=2)

	uneste(negre, "PereteNegru")
	uneste(lemn, "Lemn")
	uneste(decor, "Decor")
	uneste(carti, "Carti")
	uneste(draperii, "Draperii")
	if flacari:
		uneste(flacari, "Flacara")
	exporta(os.path.join(cale, "camera_jean.glb"))


def _draperie_camera(piese, x, y0, y1, sus, r, k):
	"""Draperia trasă peste o fereastră a camerei: falduri (cilindri turtiți, două culori), pelerina, ciucurii aurii."""
	n = 16
	for i in range(n):
		y = y0 + (i + 0.5) * (y1 - y0) / n
		c = VISINIU if i % 2 else ROSU
		piese.append(cilindru("Fald", 0.055, 0.06, sus, (x - k * 0.02 * (i % 2), y, sus / 2), c, laturi=6,
			scara=(0.7, 1.0, 1.0)))
	piese.append(cub("Pelerina", (0.12, y1 - y0 + 0.2, 0.42), (x - k * 0.08, (y0 + y1) / 2, sus - 0.05), ROSU))
	piese.append(cub("Galon", (0.13, y1 - y0 + 0.22, 0.04), (x - k * 0.085, (y0 + y1) / 2, sus - 0.25), AUR))
	for i in range(12):
		y = y0 - 0.05 + i * (y1 - y0 + 0.1) / 11
		piese.append(cilindru("Ciucure", 0.012, 0.004, 0.07, (x - k * 0.15, y, sus - 0.3), AUR, laturi=4))
	piese.append(cilindru("Bara", 0.025, 0.025, y1 - y0 + 0.5, (x - k * 0.04, (y0 + y1) / 2, sus + 0.2), BRONZ, laturi=6,
		rot=(math.pi / 2, 0, 0)))


def _biblioteca(lemn, carti, x, y, r):
	"""Bibliotecă înaltă cu fronton, lipită de peretele din dreapta (+X), cu fața spre -X."""
	lat, inalt, ad = 1.6, 2.9, 0.42
	lemn.append(cub("Biblioteca", (0.04, lat, inalt), (x + ad / 2 - 0.02, y, inalt / 2), LEMN))
	for k in (-1, 1):
		lemn.append(cub("Biblioteca", (ad, 0.05, inalt), (x, y + k * (lat / 2 - 0.025), inalt / 2), LEMN))
	lemn.append(cub("Biblioteca", (ad + 0.06, lat + 0.1, 0.12), (x - 0.02, y, inalt + 0.06), LEMN2))
	lemn.append(cub("Biblioteca", (ad + 0.02, lat, 0.12), (x, y, 0.06), LEMN2))
	lemn.append(cub("Fronton", (0.06, lat * 0.6, 0.2), (x - 0.2, y, inalt + 0.2), LEMN, rot=(0, 0, 0)))
	polite = [0.12 + i * 0.55 for i in range(6)]
	for z in polite[1:]:
		lemn.append(cub("Polita", (ad, lat - 0.1, 0.03), (x, y, z), LEMN))
	culori = (ROSU, VISINIU, LEMN2, NEGRU2, p("5b6d4e"), p("445d46"), BRONZ, p("295555"))
	for z in polite[:-1]:
		yy = y - lat / 2 + 0.06
		while yy < y + lat / 2 - 0.08:
			gros = r.uniform(0.025, 0.06)
			h = r.uniform(0.3, 0.46)
			if r.random() < 0.08:  # un gol, sau o carte culcată
				yy += 0.08
				continue
			incl = r.uniform(-0.06, 0.06) if r.random() < 0.2 else 0.0
			carti.append(cub("Carte", (r.uniform(0.22, 0.3), gros, h), (x - 0.02, yy + gros / 2, z + 0.015 + h / 2),
				r.choice(culori), rot=(incl, 0, 0)))
			if r.random() < 0.3:
				carti.append(cub("Cotor", (0.005, gros * 0.8, 0.02), (x - 0.17, yy + gros / 2, z + 0.015 + h * 0.75), AUR))
			yy += gros + 0.004


def _sofa(piese, x, y):
	"""Sofa victoriană (canapea cu spătar capitonat, picioare strunjite), lipită de peretele din stânga, cu fața spre +X."""
	piese.append(cub("Sofa", (0.6, 1.8, 0.18), (x, y, 0.42), ROSU))
	piese.append(cub("Sofa", (0.16, 1.9, 0.6), (x - 0.27, y, 0.75), ROSU))
	piese.append(cub("SofaRama", (0.06, 1.95, 0.08), (x - 0.3, y, 1.08), LEMN))
	for k in (-1, 1):
		piese.append(cub("SofaBrat", (0.6, 0.12, 0.28), (x, y + k * 0.93, 0.56), ROSU))
		piese.append(cilindru("SofaBratRulou", 0.08, 0.08, 0.6, (x, y + k * 0.93, 0.7), VISINIU, laturi=8,
			rot=(0, math.pi / 2, 0)))
		for kk in (-1, 1):
			piese.append(cilindru("SofaPicior", 0.025, 0.035, 0.33, (x + kk * 0.25, y + k * 0.85, 0.165), LEMN, laturi=6))
	for i in range(5):  # nasturii capitonajului
		for j in range(2):
			piese.append(sfera("Capiton", 0.015, (x - 0.185, y - 0.7 + i * 0.35, 0.62 + j * 0.2), VISINIU, segmente=6, inele=4))


def _craniu(piese, baza):
	x, y, z = baza
	piese.append(sfera("Craniu", 0.075, (x, y, z + 0.085), ALB, scara=(0.85, 1.0, 0.95), segmente=10, inele=7))
	piese.append(cub("Falca", (0.08, 0.06, 0.04), (x + 0.02, y, z + 0.025), ALB))
	for k in (-1, 1):
		piese.append(sfera("Orbita", 0.018, (x + 0.06, y + k * 0.028, z + 0.09), NEGRU, segmente=6, inele=4))
	piese.append(cub("Nas", (0.01, 0.016, 0.02), (x + 0.068, y, z + 0.06), NEGRU))


def _lumanari_topite(piese, flacari, baza, r, mult=3):
	"""Un grup de lumânări vechi, topite, de înălțimi diferite, cu ceară scursă pe jos."""
	x, y, z = baza
	piese.append(cilindru("CearaScursa", 0.09 * (1 + mult * 0.12), 0.09 * (1 + mult * 0.12), 0.012, (x, y, z + 0.006), CEARA,
		laturi=10))
	for i in range(mult):
		a = r.uniform(0, math.tau)
		d = 0.0 if i == 0 else r.uniform(0.04, 0.08)
		cx, cy = x + math.cos(a) * d, y + math.sin(a) * d
		h = r.uniform(0.08, 0.32) * (1.0 if i == 0 else 0.7)
		rr = r.uniform(0.016, 0.026)
		piese.append(cilindru("Lumanare", rr, rr * 0.92, h, (cx, cy, z + h / 2), ALB if r.random() < 0.6 else CEARA, laturi=8))
		piese.append(sfera("Scurgere", rr * 0.6, (cx + rr * 0.8, cy, z + h * r.uniform(0.4, 0.9)), ALB, scara=(0.6, 0.6, 1.8),
			segmente=5, inele=4))
		piese.append(cilindru("Fitil", 0.002, 0.002, 0.012, (cx, cy, z + h + 0.006), NEGRU, laturi=3))
		flacari.append(sfera("Flacara", 0.009, (cx, cy, z + h + 0.022), FLACARA, scara=(1.0, 1.0, 2.2), segmente=6, inele=4))


# ---------------------------------------------------------------------------------------------------------------
# Sfeșnicele și candelabrul
# ---------------------------------------------------------------------------------------------------------------

def _lumanare_pe(piese, flacari, x, y, z, h=0.2, rr=0.018):
	piese.append(cilindru("Talger", 0.04, 0.035, 0.015, (x, y, z), BRONZ, laturi=8))
	piese.append(cilindru("Lumanare", rr, rr, h, (x, y, z + 0.0075 + h / 2), ALB, laturi=8))
	piese.append(sfera("Scurgere", rr * 0.55, (x + rr * 0.8, y, z + h * 0.7), ALB, scara=(0.6, 0.6, 2.0), segmente=5, inele=4))
	piese.append(cilindru("Fitil", 0.002, 0.002, 0.012, (x, y, z + h + 0.012), NEGRU, laturi=3))
	flacari.append(sfera("Flacara", 0.011, (x, y, z + h + 0.03), FLACARA, scara=(1.0, 1.0, 2.2), segmente=6, inele=4))


def sfesnic_inalt(cale):
	"""Sfeșnicul de podea (1,6 m), cu trei brațe; originea = podeaua de sub el."""
	curata()
	piese, flacari = [], []
	piese.append(_strung("Picior", [(0, 0.2), (0.03, 0.2), (0.06, 0.14), (0.1, 0.05), (0.3, 0.03), (0.34, 0.06), (0.38, 0.03),
		(1.2, 0.02), (1.25, 0.05), (1.3, 0.025), (1.38, 0.02), (1.4, 0)], BRONZ, laturi=10))
	for k in (-1, 0, 1):
		x = 0.28 * k
		if k:
			piese.append(os_intre("Brat", (0, 0, 1.32), (x, 0, 1.32), 0.012, BRONZ))
			piese.append(os_intre("Brat", (x, 0, 1.32), (x, 0, 1.4), 0.012, BRONZ))
		_lumanare_pe(piese, flacari, x, 0, 1.42 + (0.1 if k == 0 else 0), h=0.24 if k == 0 else 0.18)
	uneste(piese, "Sfesnic")
	uneste(flacari, "Flacara")
	exporta(os.path.join(cale, "sfesnic_inalt.glb"))


def sfesnic_masa(cale):
	"""Sfeșnicul de pe masa de șah (trei lumânări, ~0,45 m); originea = blatul de sub el."""
	curata()
	piese, flacari = [], []
	piese.append(_strung("Picior", [(0, 0.06), (0.012, 0.06), (0.025, 0.035), (0.05, 0.015), (0.18, 0.012), (0.2, 0.025),
		(0.22, 0.012), (0.24, 0)], BRONZ, laturi=10))
	for k in (-1, 1):
		piese.append(os_intre("Brat", (0, 0, 0.2), (0.11 * k, 0, 0.24), 0.007, BRONZ))
		_lumanare_pe(piese, flacari, 0.11 * k, 0, 0.25, h=0.12, rr=0.011)
	_lumanare_pe(piese, flacari, 0, 0, 0.24, h=0.16, rr=0.012)
	uneste(piese, "Sfesnic")
	uneste(flacari, "Flacara")
	exporta(os.path.join(cale, "sfesnic_masa.glb"))


def candelabru_jean(cale):
	"""Candelabrul de deasupra mesei: lanț, coroană de fier cu 8 lumânări; originea = punctul de prindere din tavan."""
	curata()
	piese, flacari = [], []
	for i in range(10):
		z = -0.08 - i * 0.11
		piese.append(inel("Lant", 0.025, 0.006, (0, 0, z), NEGRU2, segmente=6))
	z0 = -1.25
	piese.append(_strung("Ax", [(z0 - 0.25, 0), (z0 - 0.22, 0.04), (z0 - 0.1, 0.07), (z0, 0.05), (z0 + 0.15, 0.02), (z0 + 0.2, 0)],
		NEGRU2, laturi=8))
	piese.append(inel("Coroana", 0.55, 0.018, (0, 0, z0), NEGRU2, segmente=16))
	piese.append(inel("Coroana", 0.3, 0.012, (0, 0, z0 - 0.1), NEGRU2, segmente=12))
	for i in range(8):
		a = i * math.tau / 8
		x, y = math.cos(a) * 0.55, math.sin(a) * 0.55
		piese.append(os_intre("Spita", (0, 0, z0 - 0.1), (x, y, z0), 0.008, NEGRU2, laturi=4))
		piese.append(os_intre("Lant", (0, 0, -1.0), (x, y, z0), 0.004, NEGRU2, laturi=3))
		_lumanare_pe(piese, flacari, x, y, z0 + 0.02, h=0.16 + 0.05 * (i % 3), rr=0.016)
		piese.append(sfera("Picatura", 0.012, (x, y, z0 - 0.03), ALB, scara=(1, 1, 2), segmente=5, inele=4))
	uneste(piese, "Candelabru")
	uneste(flacari, "Flacara")
	exporta(os.path.join(cale, "candelabru_jean.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Masa de șah și piesele
# ---------------------------------------------------------------------------------------------------------------

def masa_sah(cale):
	"""Masa victoriană cu tabla încrustată în blat; originea = podeaua de sub mijlocul mesei. Albul (jucătorul) stă la -Y.
	Pătratul (coloana c, rândul r) are mijlocul la x = (c - 3,5) * PATRAT, y = (r - 3,5) * PATRAT, fața la TABLA_Z."""
	curata()
	piese = []
	piese.append(cub("Blat", (0.92, 0.92, 0.04), (0, 0, TZ), LEMN))
	piese.append(cub("BlatMuchie", (0.96, 0.96, 0.025), (0, 0, TZ - 0.03), LEMN2))
	piese.append(cub("Sort", (0.82, 0.82, 0.09), (0, 0, TZ - 0.09), LEMN))
	for k in (-1, 1):
		for kk in (-1, 1):
			x, y = k * 0.38, kk * 0.38
			piese.append(_strung("Picior", [(0, 0.04), (0.03, 0.05), (0.06, 0.03), (0.2, 0.025), (0.26, 0.045), (0.32, 0.028),
				(0.55, 0.035), (0.6, 0.05), (0.64, 0.03), (TZ - 0.04, 0.035), (TZ - 0.02, 0)], LEMN, laturi=8, centru=(x, y)))
			piese.append(sfera("Gheara", 0.045, (x, y, 0.035), BRONZ, scara=(1.1, 1.1, 0.7), segmente=8, inele=5))
	# tabla: rama de bronz și lemn deschis, apoi pătratele (deschis = auriu-fildeș, închis = vișiniu)
	lat = PATRAT * 8
	# rama: patru margini în jurul pătratelor (nu o placă: ar acoperi pătratele)
	for k in (-1, 1):
		piese.append(cub("RamaTabla", (lat + 0.06, 0.03, 0.01), (0, k * (lat / 2 + 0.015), TZ + 0.025), BRONZ))
		piese.append(cub("RamaTabla", (0.03, lat, 0.01), (k * (lat / 2 + 0.015), 0, TZ + 0.025), BRONZ))
		piese.append(cub("RamaTablaLemn", (lat + 0.002, 0.008, 0.012), (0, k * (lat / 2 + 0.004), TZ + 0.026), LEMN2))
		piese.append(cub("RamaTablaLemn", (0.008, lat - 0.004, 0.012), (k * (lat / 2 + 0.004), 0, TZ + 0.026), LEMN2))
	for c in range(8):
		for rr in range(8):
			culoare = AUR if (c + rr) % 2 else VISINIU
			piese.append(cub("Patrat", (PATRAT, PATRAT, 0.006), ((c - 3.5) * PATRAT, (rr - 3.5) * PATRAT, TABLA_Z - 0.003),
				culoare))
	uneste(piese, "Masa")
	exporta(os.path.join(cale, "masa_sah.glb"))


def _piesa(tip, culoare, sufix):
	"""O piesă de șah în origine (baza la z = 0), cu fața (calul) spre +Y = spre negru."""
	p_ = []
	baza = [(0, 0.019), (0.005, 0.019), (0.007, 0.016), (0.01, 0.017), (0.013, 0.013)]
	if tip == "Pion":
		p_.append(_strung("Corp", baza + [(0.02, 0.008), (0.026, 0.006), (0.028, 0.01), (0.03, 0.006)], culoare))
		p_.append(sfera("Cap", 0.009, (0, 0, 0.037), culoare, segmente=10, inele=7))
	elif tip == "Tura":
		p_.append(_strung("Corp", baza + [(0.02, 0.011), (0.034, 0.012), (0.037, 0.016), (0.046, 0.016), (0.046, 0)], culoare))
		for i in range(4):
			a = i * math.pi / 2 + math.pi / 4
			p_.append(cub("Creneel", (0.009, 0.009, 0.008), (math.cos(a) * 0.012, math.sin(a) * 0.012, 0.05), culoare,
				rot=(0, 0, a)))
	elif tip == "Cal":
		p_.append(_strung("Corp", baza + [(0.016, 0.012), (0.018, 0)], culoare))
		p_.append(trunchi("Gat", [((0, -0.004, 0.016), 0.012, 0.01), ((0, -0.002, 0.03), 0.009, 0.011),
			((0, 0.004, 0.044), 0.008, 0.011), ((0, 0.014, 0.05), 0.007, 0.008), ((0, 0.024, 0.046), 0.005, 0.006),
			((0, 0.028, 0.042), 0.0, 0.0)], culoare, laturi=8))
		p_.append(cub("Coama", (0.004, 0.012, 0.03), (0, -0.01, 0.035), culoare, rot=(-0.3, 0, 0)))
		for k in (-1, 1):
			p_.append(cilindru("Ureche", 0.003, 0.0, 0.009, (k * 0.004, 0.0, 0.058), culoare, laturi=4))
	elif tip == "Nebun":
		p_.append(_strung("Corp", baza + [(0.02, 0.008), (0.034, 0.006), (0.036, 0.01), (0.038, 0.006)], culoare))
		p_.append(sfera("Mitra", 0.009, (0, 0, 0.047), culoare, scara=(1, 1, 1.45), segmente=10, inele=7))
		p_.append(sfera("Bila", 0.003, (0, 0, 0.062), culoare, segmente=6, inele=4))
	elif tip == "Regina":
		p_.append(_strung("Corp", baza + [(0.02, 0.009), (0.04, 0.0065), (0.043, 0.011), (0.046, 0.007), (0.055, 0.011),
			(0.058, 0.007), (0.06, 0)], culoare))
		for i in range(8):
			a = i * math.tau / 8
			p_.append(sfera("Zimt", 0.0025, (math.cos(a) * 0.01, math.sin(a) * 0.01, 0.058), culoare, segmente=5, inele=3))
		p_.append(sfera("Bila", 0.0035, (0, 0, 0.063), culoare, segmente=6, inele=4))
	elif tip == "Rege":
		p_.append(_strung("Corp", baza + [(0.02, 0.0095), (0.044, 0.007), (0.047, 0.012), (0.05, 0.008), (0.06, 0.011),
			(0.062, 0)], culoare))
		p_.append(cub("Cruce", (0.003, 0.003, 0.014), (0, 0, 0.069), culoare))
		p_.append(cub("CruceBrat", (0.01, 0.003, 0.003), (0, 0, 0.071), culoare))
	return uneste(p_, tip + "_" + sufix)


def piese_sah(cale):
	"""Toate piesele, în același fișier: Pion_A ... Rege_A (albe, ale tale) și Pion_N ... Rege_N (negre, ale lui Jean).
	În joc se iau mesh-urile după nume (MasaSah); aici stau puse una lângă alta."""
	curata()
	for i, tip in enumerate(("Pion", "Cal", "Nebun", "Tura", "Regina", "Rege")):
		for sufix, culoare, y in (("A", ALB, 0.0), ("N", NEGRU, 0.1)):
			ob = _piesa(tip, culoare, sufix)
			ob.location = (i * 0.06, y, 0)
	exporta(os.path.join(cale, "piese_sah.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Scaunele
# ---------------------------------------------------------------------------------------------------------------

def _scaun(piese, inalt_spate, lat, coroana):
	"""Scaun gotic, cu fața spre -Y (în Godot +Z); originea = podeaua sub mijlocul șezutului."""
	z = 0.46
	piese.append(cub("Sezut", (lat, 0.5, 0.06), (0, 0, z - 0.03), LEMN))
	piese.append(cub("Perna", (lat - 0.06, 0.46, 0.06), (0, -0.01, z + 0.025), ROSU))
	for k in (-1, 1):
		for kk in (-1, 1):
			piese.append(_strung("Picior", [(0, 0.03), (0.04, 0.025), (0.1, 0.035), (0.2, 0.02), (0.38, 0.025), (z - 0.07, 0.022),
				(z - 0.06, 0)], LEMN, laturi=6, centru=(k * (lat / 2 - 0.04), kk * 0.21)))
	piese.append(cub("Spatar", (lat, 0.06, inalt_spate), (0, 0.24, z + inalt_spate / 2), LEMN))
	piese.append(cub("SpatarPerna", (lat - 0.12, 0.02, inalt_spate - 0.2), (0, 0.2, z + inalt_spate / 2), ROSU))
	for i in range(3):
		for j in range(int(inalt_spate / 0.3)):
			piese.append(sfera("Capiton", 0.012, (-lat / 2 + 0.15 + i * (lat - 0.3) / 2, 0.19, z + 0.15 + j * 0.3), VISINIU,
				segmente=6, inele=4))
	for k in (-1, 1):
		piese.append(cub("Stalp", (0.07, 0.08, inalt_spate + 0.1), (k * (lat / 2 + 0.035), 0.24, z + inalt_spate / 2 + 0.05), LEMN2))
		piese.append(cilindru("Fleuron", 0.035, 0.0, 0.14, (k * (lat / 2 + 0.035), 0.24, z + inalt_spate + 0.17), LEMN2, laturi=6))
	if coroana:  # tronul lui Jean: arcul ascuțit de sus și brațele
		piese.append(cilindru("Arc", lat / 2, 0.0, 0.32, (0, 0.24, z + inalt_spate + 0.16), LEMN, laturi=4, scara=(1, 0.12, 1)))
		piese.append(sfera("Bila", 0.035, (0, 0.24, z + inalt_spate + 0.35), BRONZ, segmente=8, inele=5))
		for k in (-1, 1):
			piese.append(cub("Brat", (0.08, 0.46, 0.05), (k * (lat / 2 - 0.02), 0.0, z + 0.25), LEMN2))
			piese.append(cilindru("BratPicior", 0.025, 0.025, 0.25, (k * (lat / 2 - 0.02), -0.2, z + 0.12), LEMN, laturi=6))
			piese.append(sfera("BratCap", 0.04, (k * (lat / 2 - 0.02), -0.22, z + 0.29), BRONZ, segmente=8, inele=5))


def tron_jean(cale):
	curata()
	piese = []
	_scaun(piese, 1.1, 0.66, True)
	uneste(piese, "Tron")
	exporta(os.path.join(cale, "tron_jean.glb"))


def scaun_sah(cale):
	curata()
	piese = []
	_scaun(piese, 0.6, 0.5, False)
	uneste(piese, "Scaun")
	exporta(os.path.join(cale, "scaun_sah.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Jean
# ---------------------------------------------------------------------------------------------------------------

def _cravata_roz(ob_corp):
	"""Cravata și batista roz, ca piesă separată (`CravataRoz`): roz nu e în paletă, îl dă material_roz.tres în joc.
	Locurile sunt cele din casino_oameni._tors (sacou, burta 0): pieptul e la y = -0,11…-0,13."""
	z0, h = 0.48, 1.18
	piese = [
		cub("Nod", (0.03, 0.016, 0.026), (0, -0.101, z0 + 0.5 * h), ALB),
		cub("Cravata", (0.038, 0.012, 0.2), (0, -0.157, z0 + 0.39 * h), ALB, rot=(0.12, 0, 0)),
		cub("BatistaRoz", (0.044, 0.012, 0.03), (0.12, -0.126, z0 + 0.445 * h), ALB),
	]
	ob = uneste(piese, "CravataRoz", (0, -0.12, z0 + 0.5 * h))
	from coven import _parinte
	_parinte(ob, ob_corp)


JEAN = {
	# bătrân, palid, în costum negru cu cămașă albă și cravată roz; chel, cu smocuri albe pe laterale,
	# mustață albă, sprâncene groase, încruntat, inele de aur
	"piele": p("a18463"), "piele_umbra": p("a56850"), "haina": NEGRU, "haina_umbra": NEGRU2, "camasa": ALB,
	"batista": NEGRU, "pantaloni": NEGRU, "pantofi": NEGRU, "par": ALB, "stil_par": "chel", "tepi": CEARA,
	"mustata": ALB, "riduri": True, "nas": 1.35, "incruntat": 0.35, "spranceana": 0.016, "inele": AUR,
	"manseta": ALB, "masa": TZ + 0.02, "gros_brat": 0.85, "extra": _cravata_roz,
}


def jean(cale):
	casino_oameni.om(cale, "jean", JEAN, 1906)


# ---------------------------------------------------------------------------------------------------------------
# Draperia trasă din spatele geamurilor caselor vecine (afara_lexy.gd o întinde cât geamul)
# ---------------------------------------------------------------------------------------------------------------

def draperie(cale):
	"""1 × 1 m în planul XZ (fața spre -Y), cu falduri; în joc se scalează cât geamul. Originea = mijlocul."""
	curata()
	piese = []
	n = 10
	for i in range(n):
		x = -0.5 + (i + 0.5) / n
		piese.append(cilindru("Fald", 0.055, 0.055, 1.0, (x, 0.02 * (i % 2), 0), VISINIU if i % 2 else ROSU, laturi=6,
			scara=(1.0, 0.45, 1.0)))
	uneste(piese, "Draperie")
	exporta(os.path.join(cale, "draperie.glb"))


def toate(cale):
	camera_jean(cale)
	masa_sah(cale)
	piese_sah(cale)
	tron_jean(cale)
	scaun_sah(cale)
	sfesnic_inalt(cale)
	sfesnic_masa(cale)
	candelabru_jean(cale)
	jean(cale)
	draperie(cale)


if __name__ == "__main__":
	cale_modele = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")
	if "--" in sys.argv:
		for nume in sys.argv[sys.argv.index("--") + 1:]:
			globals()[nume](cale_modele)
	else:
		toate(cale_modele)
