# Autobuzul de noapte (linia 13), stația lui, șoferul, creatura din pădure și pădurea de pe drum.
# Le apelează modele.py, dar merg și singure (mai repede, doar astea):
#   blender --background --factory-startup --python tools/blender/autobuz.py
# Axe Blender: Z în sus, fața modelului spre -Y (în Godot devine +Z). Originea = la sol.
import math
import os
import random
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, text, uneste, exporta, trunchi  # noqa: E402

NEGRU = p("262d2f")
ALB = p("83b3b0")
GEAM = p("2a3c3d")
METAL = p("778c96")
METAL_INCHIS = p("6f6d7f")
OCRU = p("a18463")       # galbenul decolorat al Ikarus-urilor RATB
ROSU = p("7b383a")
RUGINA = p("904a40")
GRI = p("7e8d87")
GRI_INCHIS = p("70706e")
CAUCIUC = p("48313b")

# --- autobuzul: un Ikarus 260 obosit. Lung pe Y (fața la y = -5,5), ușile pe partea -X (dreapta mersului).
LUNG = 11.0
LAT = 2.5
X = LAT / 2
JOS = 0.35        # unde începe caroseria
PODEA = 0.9       # fața de sus a podelei din salon
BRAU = 1.55       # sub geamuri
SUS_GEAM = 2.45   # deasupra geamurilor
ACOPERIS = 2.85
AXE = (-2.9, 2.5)  # roțile din față și din spate
ROATA = 0.5
# ușile (de la, până la) pe Y; toate pe partea -X
USI = [(-5.15, -3.95), (-0.6, 0.6), (3.6, 4.8)]


def _intervale(a, b, gauri):
	"""[a, b] fără găurile date: bucățile pline, în ordine."""
	bucati = [(a, b)]
	for g0, g1 in gauri:
		noi = []
		for c0, c1 in bucati:
			if g1 <= c0 or g0 >= c1:
				noi.append((c0, c1))
				continue
			if g0 > c0:
				noi.append((c0, g0))
			if g1 < c1:
				noi.append((g1, c1))
		bucati = noi
	return [(c0, c1) for c0, c1 in bucati if c1 - c0 > 0.01]


def _panou(piese, nume, s, y0, y1, z0, z1, culoare, grosime=0.05, adanc=0.0):
	"""O bucată din peretele lateral (s = -1 partea ușilor, +1 partea șoferului)."""
	piese.append(cub(nume, (grosime, y1 - y0, z1 - z0), (s * (X - grosime / 2 - adanc), (y0 + y1) / 2, (z0 + z1) / 2), culoare))


def _scaun(piese, x, y, z=PODEA, culoare=RUGINA):
	"""Scaun de plastic de autobuz, cu fața spre -Y și mânerul de țeavă în spate."""
	piese += [
		cub("Picior scaun", (0.05, 0.05, z + 0.42 - PODEA), (x, y, PODEA + (z + 0.42 - PODEA) / 2), METAL_INCHIS),
		cub("Sezut", (0.42, 0.42, 0.07), (x, y, z + 0.45), culoare),
		cub("Spatar", (0.42, 0.06, 0.52), (x, y + 0.22, z + 0.74), culoare, rot=(-0.12, 0, 0)),
		cub("Maner scaun", (0.3, 0.035, 0.035), (x, y + 0.27, z + 1.02), METAL),
	]


def _bara(piese, a, b, raza=0.02):
	piese.append(os_intre("Bara", a, b, raza, METAL, laturi=6))


def _compostor(piese, x, y, z):
	"""Compostorul portocaliu de pe bară, cu fanta neagră și ledul."""
	piese += [
		cub("Compostor", (0.12, 0.1, 0.2), (x, y, z), p("a56850")),
		cub("Fanta", (0.07, 0.012, 0.012), (x, y - 0.052, z + 0.05), NEGRU),
		cub("Led", (0.012, 0.012, 0.012), (x + 0.03, y - 0.052, z - 0.04), ROSU),
	]


def autobuz(cale):
	"""Ikarus 260 de noapte: caroserie ocru cu bandă roșie, stâlpi negri între geamuri, rugină.
	Salonul e mobilat (scaune, bare, compostoare, cabina șoferului), fiindcă în el se joacă o scenă.
	Obiecte separate: foile ușilor (Usa<n>A/B, originea în balama), roțile (Roata<..>, originea în butuc),
	geamurile (Geam*, devin transparente în joc), Lumini (neoanele din tavan), Faruri, Stopuri, Panou."""
	curata()
	r = random.Random(13)
	piese = []
	geamuri = []
	lumini = []
	# Regula carcasei (altfel fețele se bat pe ecran, vezi verifica_fete din unelte.py):
	# fața și spatele au grosimea G_CAP și acoperă toată lățimea; pereții laterali stau ÎNTRE ele;
	# acoperișul stă PE pereți; orice detaliu lipit pe tablă (bandă, rugină, noroi, grilă) e o placă
	# subțire pusă în fața suprafeței, care iese cel puțin 1 cm.
	FY = -LUNG / 2
	SY = LUNG / 2
	G_CAP = 0.08
	SUS_PERETE = ACOPERIS - 0.06  # unde se termină pereții și începe acoperișul
	Y0, Y1 = FY + G_CAP, SY - G_CAP  # pereții laterali
	# --- podeaua, cu treptele de la uși
	piese.append(cub("Podea", (1.9, Y1 - Y0, 0.1), (0.25, 0, PODEA - 0.05), CAUCIUC))  # între pereți, nu prin ei
	for y0, y1 in _intervale(Y0, Y1, USI):
		piese.append(cub("Podea usi", (0.5, y1 - y0, 0.1), (-0.95, (y0 + y1) / 2, PODEA - 0.05), CAUCIUC))
	for y0, y1 in USI:
		piese += [
			cub("Treapta", (0.25, y1 - y0, 0.1), (-X + 0.15, (y0 + y1) / 2, 0.45), CAUCIUC),
			cub("Treapta", (0.3, y1 - y0, 0.1), (-X + 0.4, (y0 + y1) / 2, 0.68), CAUCIUC),
			cub("Muchie treapta", (0.03, y1 - y0, 0.012), (-X + 0.265, (y0 + y1) / 2, 0.736), OCRU),
		]
	# nervurile de cauciuc pe culoar
	for i in range(30):
		piese.append(cub("Nervura", (0.5, 0.025, 0.012), (-0.05, -4.0 + i * 0.32, PODEA + 0.006), NEGRU))
	piese.append(cub("Sasiu", (LAT - 0.3, LUNG - 0.4, 0.4), (0, 0, 0.55), NEGRU))

	# --- pereții laterali
	roti = [(a - 0.62, a + 0.62) for a in AXE]
	for s in (-1, 1):
		usi = USI if s < 0 else []
		bucati = _intervale(Y0, Y1, usi)
		fuste = []
		for y0, y1 in bucati:
			for a0, a1 in _intervale(y0, y1, roti):
				_panou(piese, "Fusta", s, a0, a1, JOS, 0.8, ROSU)
				_panou(piese, "Lateral", s, a0, a1, 0.8, 1.08, OCRU)
				fuste.append((a0, a1))
			_panou(piese, "Lateral", s, y0, y1, 1.08, BRAU - 0.07, OCRU)
			_panou(piese, "Banda", s, y0, y1, BRAU - 0.07, BRAU, ROSU)
			# geamurile: stâlpi negri la capete și la cel mult 1,6 m unul de altul (pe partea șoferului
			# iese un geam întreg fix în dreptul scaunului din mijloc, unde stai în scena din autobuz)
			n = max(1, math.ceil((y1 - y0) / 1.6))
			pas = (y1 - y0) / n
			for k in range(n + 1):
				ys = min(max(y0 + k * pas, y0 + 0.05), y1 - 0.05)
				_panou(piese, "Stalp geam", s, ys - 0.05, ys + 0.05, BRAU, SUS_GEAM, NEGRU, grosime=0.07)
			for k in range(n):
				# geamul începe unde se termină stâlpul (cei de la capete sunt împinși înăuntru)
				g0, g1 = max(y0 + k * pas + 0.05, y0 + 0.1), min(y0 + (k + 1) * pas - 0.05, y1 - 0.1)
				geamuri.append(cub("Geam lateral", (0.012, g1 - g0, SUS_GEAM - BRAU), (s * (X - 0.03), (g0 + g1) / 2, (BRAU + SUS_GEAM) / 2), GEAM))
				# geamul de sus, rabatabil, cu rama lui
				piese.append(cub("Rama rabatabil", (0.03, g1 - g0, 0.03), (s * (X - 0.02), (g0 + g1) / 2, SUS_GEAM - 0.12), NEGRU))
		# noroiul de jos și rugina: plăci în fața tablei, doar pe tablă (nu peste arcele roților sau uși)
		for a0, a1 in fuste:
			_panou(piese, "Noroi", s, a0, a1, JOS, JOS + 0.12, p("5e5356"), grosime=0.012, adanc=-0.012)
		# petele de rugină nu se calcă una pe alta (în același plan s-ar bate pe ecran)
		pete = []
		for _ in range(40):
			if len(pete) == 6:
				break
			a0, a1 = r.choice([f for f in fuste if f[1] - f[0] > 0.6])
			lung = min(r.uniform(0.15, 0.5), a1 - a0 - 0.1)
			y = r.uniform(a0 + 0.05, a1 - 0.05 - lung)
			if any(y < b + 0.05 and y + lung > a - 0.05 for a, b in pete):
				continue
			pete.append((y, y + lung))
			z = r.uniform(0.4, 0.62)
			_panou(piese, "Rugina", s, y, y + lung, z, z + r.uniform(0.08, 0.17), r.choice([RUGINA, p("5e363e")]),
				grosime=0.024, adanc=-0.024)
		for a in AXE:
			# fundul întunecat al arcului (altfel prin gaură se vede salonul)
			piese.append(cub("Fund arc", (0.05, 1.24, 0.75), (s * (X - 0.57), a, JOS + 0.375), NEGRU))
			piese.append(cub("Aparatoare", (0.25, 0.03, 0.35), (s * (X - 0.15), a + 0.66, JOS + 0.05), NEGRU))
		# între geamuri și acoperiș, cu jgheabul de ploaie ieșit în afară
		_panou(piese, "Deasupra geamurilor", s, Y0, Y1, SUS_GEAM, SUS_PERETE, OCRU)
		_panou(piese, "Jgheab", s, FY, SY, SUS_PERETE - 0.03, SUS_PERETE, NEGRU, grosime=0.03, adanc=-0.03)
		# căptușeala din salon, sub geamuri
		for y0, y1 in bucati:
			_panou(piese, "Captuseala", s, y0, y1, PODEA, BRAU, GRI_INCHIS, grosime=0.02, adanc=0.06)
	# arcele mascate pe dinăuntru (roțile intră în salon)
	for a in AXE:
		for s in (-1, 1):
			piese.append(cub("Carcasa roata", (0.45, 1.2, 0.3), (s * (X - 0.3), a, PODEA + 0.15), GRI_INCHIS))
	# rame deasupra ușilor (ies 1 cm în afara stâlpilor) și garniturile de jos
	for y0, y1 in USI:
		piese.append(cub("Rama usa", (0.06, y1 - y0 + 0.1, 0.06), (-X + 0.018, (y0 + y1) / 2, SUS_GEAM - 0.03), NEGRU))
		piese.append(cub("Garnitura", (0.06, y1 - y0, 0.04), (-X + 0.03, (y0 + y1) / 2, JOS + 0.02), NEGRU))

	# --- acoperișul (stă pe pereți) și tavanul
	piese += [
		cub("Acoperis", (LAT, LUNG, 0.06), (0, 0, SUS_PERETE + 0.03), GRI),
		cub("Acoperis bombat", (LAT - 0.5, LUNG - 0.3, 0.07), (0, 0, ACOPERIS + 0.035), GRI),
		cub("Tavan", (LAT - 0.14, Y1 - Y0 - 0.02, 0.03), (0, 0, ACOPERIS - 0.1), GRI),
		cub("Trapa", (0.7, 0.7, 0.08), (0, -2.0, ACOPERIS + 0.08), GRI_INCHIS),
		cub("Trapa", (0.7, 0.7, 0.08), (0, 2.2, ACOPERIS + 0.08), GRI_INCHIS),
		cub("Rugina acoperis", (0.4, 1.1, 0.03), (0.6, 3.6, ACOPERIS + 0.082), RUGINA),
	]
	for s in (-1, 1):
		piese.append(cub("Muchie acoperis", (0.25, LUNG - 0.02, 0.06), (s * (X - 0.17), 0, ACOPERIS + 0.01), GRI, rot=(0, s * 0.35, 0)))  # nu iese prin pereți
	# neoanele din tavan: două șiruri, unul stins (lipsește tubul)
	for s in (-1, 1):
		for i in range(6):
			y = -3.6 + i * 1.6
			piese.append(cub("Carcasa neon", (0.16, 0.9, 0.04), (s * 0.5, y, ACOPERIS - 0.13), GRI_INCHIS))
			if (s, i) != (-1, 3):
				lumini.append(cub("Neon", (0.1, 0.82, 0.02), (s * 0.5, y, ACOPERIS - 0.155), ALB))
			else:
				piese.append(cub("Neon lipsa", (0.1, 0.82, 0.02), (s * 0.5, y, ACOPERIS - 0.155), NEGRU))

	# --- fața: parbrizul în două, panoul cu linia, farurile rotunde, bara
	FC = FY + G_CAP / 2  # mijlocul peretelui din față
	piese += [
		cub("Fata jos", (LAT, G_CAP, 1.13 - JOS), (0, FC, (JOS + 1.13) / 2), OCRU),
		cub("Banda fata", (LAT, 0.012, 0.35), (0, FY - 0.006, JOS + 0.175), ROSU),
		cub("Grila", (1.0, 0.03, 0.25), (0, FY - 0.015, 0.9), NEGRU),
		cub("Sigla", (0.22, 0.02, 0.07), (0, FY - 0.04, 0.9), METAL),
		cub("Bara fata", (LAT + 0.04, 0.16, 0.2), (0, FY - 0.05, 0.42), METAL_INCHIS),
		cub("Numar", (0.52, 0.02, 0.12), (0, FY - 0.14, 0.42), ALB),
		cub("Rama parbriz", (LAT, G_CAP, 0.08), (0, FC, 1.17), NEGRU),
		cub("Rama parbriz", (LAT, G_CAP, 0.08), (0, FC, 2.5), NEGRU),
		cub("Stalp parbriz", (0.1, G_CAP, 2.46 - 1.21), (0, FC, (1.21 + 2.46) / 2), NEGRU),
		cub("Panou linie", (LAT, G_CAP, SUS_PERETE - 2.54), (0, FC, (2.54 + SUS_PERETE) / 2), OCRU),
		cub("Fundal panou", (1.7, 0.02, 0.24), (0, FY - 0.01, 2.68), NEGRU),
		cub("Bord", (LAT - 0.1, 0.45, 0.25), (0, FY + 0.31, 1.2), NEGRU),
	]
	for s in (-1, 1):
		piese.append(cub("Stalp parbriz", (0.1, G_CAP, 2.46 - 1.21), (s * (X - 0.05), FC, (1.21 + 2.46) / 2), NEGRU))
		geamuri.append(cub("Geam parbriz", (X - 0.1, 0.012, 1.25), (s * X / 2, FY + 0.03, 1.83), GEAM))
		piese.append(os_intre("Stergator", (s * 0.3 - 0.35, FY - 0.02, 1.25), (s * 0.3 + 0.1, FY - 0.02, 1.85), 0.012, NEGRU, laturi=4))
		# oglinzile „antenă” ale Ikarus-ului, pe brațe lungi
		piese.append(os_intre("Brat oglinda", (s * X, FY + 0.15, 2.3), (s * (X + 0.25), FY - 0.35, 2.15), 0.02, NEGRU, laturi=5))
		piese.append(cub("Oglinda", (0.18, 0.04, 0.3), (s * (X + 0.27), FY - 0.37, 1.98), NEGRU))
		piese.append(cub("Semnalizare", (0.12, 0.03, 0.07), (s * 1.05, FY - 0.005, 1.0), p("a56850")))
		for dx in (0.72, 0.95):
			piese.append(cilindru("Rama far", 0.1, 0.1, 0.04, (s * dx, FY - 0.005, 0.72), METAL, laturi=10, rot=(1.5708, 0, 0)))
			lumini.append(cilindru("Far", 0.08, 0.08, 0.03, (s * dx, FY - 0.02, 0.72), ALB, laturi=10, rot=(1.5708, 0, 0)))
	# panoul cu linia: cifrele și destinația „aprinse”, la 1,5 cm în fața fundalului
	panou = [text("Linia", "13 Trivale", (0, FY - 0.035, 2.68), 0.17, p("a56850"))]

	# --- spatele: geam mic, grilele motorului, stopurile
	SC = SY - G_CAP / 2
	piese += [
		cub("Spate jos", (LAT, G_CAP, 1.7 - JOS), (0, SC, (JOS + 1.7) / 2), OCRU),
		cub("Banda spate", (LAT, 0.012, 0.35), (0, SY + 0.006, JOS + 0.175), ROSU),
		cub("Spate sus", (LAT, G_CAP, SUS_PERETE - 2.4), (0, SC, (2.4 + SUS_PERETE) / 2), OCRU),
		cub("Bara spate", (LAT + 0.04, 0.14, 0.18), (0, SY + 0.05, 0.42), METAL_INCHIS),
		cub("Numar", (0.52, 0.02, 0.12), (0, SY + 0.13, 0.65), ALB),
		cub("Funingine", (0.5, 0.025, 0.4), (-0.7, SY + 0.0125, 0.7), NEGRU),
		cub("Stalp spate mijloc", (0.06, G_CAP, 0.7), (0, SC, 2.05), NEGRU),
	]
	for s in (-1, 1):
		piese.append(cub("Stalp spate", (0.25, G_CAP, 0.7), (s * (X - 0.125), SC, 2.05), OCRU))
		geamuri.append(cub("Geam spate", (X - 0.28, 0.012, 0.7), (s * (X - 0.25 + 0.03) / 2, SY - 0.03, 2.05), GEAM))
		lumini.append(cub("Stop", (0.14, 0.03, 0.22), (s * 1.0, SY + 0.005, 1.0), ROSU))
		for i in range(5):
			piese.append(cub("Grila motor", (0.6, 0.03, 0.025), (s * 0.55, SY + 0.015, 1.2 + i * 0.07), NEGRU))

	# --- salonul: scaunele
	for i in range(10):
		y = -3.2 + i * 0.8
		z = PODEA + (0.18 if any(abs(y - a) < 0.5 for a in AXE) else 0.0)
		for x in (0.48, 0.92):
			_scaun(piese, x, y, z)
	for y in (-3.0, -2.2, -1.4, 1.4, 2.2):
		z = PODEA + (0.18 if any(abs(y - a) < 0.5 for a in AXE) else 0.0)
		_scaun(piese, -0.92, y, z)
	for x in (-0.92, -0.48, 0.0, 0.48, 0.92):
		_scaun(piese, x, 4.95, PODEA + 0.2)
	piese.append(cub("Podium spate", (LAT - 0.2, 0.6, 0.2), (0, 4.95, PODEA + 0.1), GRI_INCHIS))
	# --- barele: verticale lângă uși și pe culoar, două lungi sub tavan
	for s in (-0.6, 0.62):
		_bara(piese, (s, -4.2, ACOPERIS - 0.25), (s, 4.6, ACOPERIS - 0.25), 0.018)
	for x, y in ((-0.66, -3.85), (-0.66, -0.75), (-0.66, 0.75), (-0.66, 3.5), (0.22, -1.8), (0.22, 1.1), (0.22, 3.0)):
		_bara(piese, (x, y, PODEA), (x, y, ACOPERIS - 0.1))
	for y0, y1 in USI:
		_bara(piese, (-X + 0.12, y0 + 0.08, 0.7), (-X + 0.12, y0 + 0.08, 2.1))
		_bara(piese, (-X + 0.12, y1 - 0.08, 0.7), (-X + 0.12, y1 - 0.08, 2.1))
	# mânere de piele atârnate de bara din dreapta, câteva lipsesc
	for i in range(14):
		if i in (4, 9):
			continue
		y = -3.8 + i * 0.62
		piese.append(cub("Curea", (0.025, 0.04, 0.22), (-0.6, y, ACOPERIS - 0.37), p("553e4d")))
		piese.append(cub("Maner curea", (0.045, 0.12, 0.03), (-0.6, y, ACOPERIS - 0.49), NEGRU))
	_compostor(piese, -0.66, -0.68, 1.45)
	_compostor(piese, -0.66, 3.43, 1.45)
	_compostor(piese, 0.22, -1.73, 1.45)
	# ziarul uitat pe un scaun și o sticlă pe jos
	piese.append(cub("Ziar", (0.28, 0.36, 0.02), (0.48, 1.6, PODEA + 0.49), ALB, rot=(0, 0, 0.3)))
	piese.append(cub("Ziar titlu", (0.2, 0.05, 0.022), (0.47, 1.52, PODEA + 0.49), NEGRU, rot=(0, 0, 0.3)))
	piese.append(cilindru("Sticla", 0.035, 0.035, 0.25, (0.1, 2.6, PODEA + 0.035), p("445d46"), laturi=6, rot=(1.5708, 0, 0.8)))
	# --- cabina șoferului (pe partea +X, în față)
	piese += [
		cub("Podium sofer", (0.9, 1.1, 0.2), (0.75, -4.85, PODEA + 0.1), GRI_INCHIS),
		cub("Scaun sofer", (0.5, 0.5, 0.1), (0.62, -4.4, PODEA + 0.62), p("553e4d")),
		cub("Spatar sofer", (0.5, 0.1, 0.65), (0.62, -4.1, PODEA + 0.98), p("553e4d"), rot=(-0.15, 0, 0)),
		cub("Picior scaun sofer", (0.15, 0.15, 0.3), (0.62, -4.4, PODEA + 0.38), NEGRU),
		cub("Perete cabina", (1.0, 0.05, 1.0), (0.72, -3.75, PODEA + 0.5), GRI),
		cub("Rama cabina", (1.02, 0.08, 0.05), (0.72, -3.75, PODEA + 1.0), NEGRU),
		cub("Coloana volan", (0.08, 0.08, 0.45), (0.62, -5.1, 1.45), NEGRU, rot=(-0.5, 0, 0)),
		cub("Cutie bilete", (0.25, 0.2, 0.15), (0.15, -4.7, PODEA + 0.75), METAL_INCHIS),
		cub("Iconita", (0.07, 0.01, 0.09), (0.25, FY + 0.33, 1.42), p("a18463")),
		cub("Brad parfumat", (0.05, 0.01, 0.08), (0.9, FY + 0.33, 1.5), p("5b6d4e")),
		cub("Tablou bord", (0.5, 0.05, 0.18), (0.62, FY + 0.48, 1.38), p("2a3c3d"), rot=(-0.6, 0, 0)),
	]
	geamuri.append(cub("Geam cabina", (0.97, 0.012, 0.75), (0.705, -3.75, PODEA + 1.4), GEAM))
	piese.append(cub("Rama cabina", (0.05, 0.08, 0.75), (0.195, -3.75, PODEA + 1.4), NEGRU))
	piese.append(cilindru("Volan", 0.22, 0.22, 0.04, (0.62, -4.95, 1.62), NEGRU, laturi=12, rot=(1.0, 0, 0)))
	piese.append(cilindru("Butuc volan", 0.05, 0.05, 0.05, (0.62, -4.95, 1.62), METAL_INCHIS, laturi=6, rot=(1.0, 0, 0)))
	# oglinda retrovizoare din interior, prin care șoferul se uită la tine
	piese.append(cub("Retrovizoare", (0.3, 0.03, 0.09), (0.35, FY + 0.25, 2.35), NEGRU))
	piese.append(cub("Retrovizoare sticla", (0.27, 0.01, 0.07), (0.35, FY + 0.27, 2.35), METAL))
	uneste(piese, "Autobuz")
	uneste(lumini, "Lumini")
	uneste(panou, "Panou")
	uneste(geamuri, "Geamuri")

	# --- foile ușilor: fiecare se rotește în jurul balamalei ei (marginea dinspre capătul golului)
	for n, (y0, y1) in enumerate(USI, 1):
		lat = (y1 - y0) / 2
		for litera, balama, semn in (("A", y0, 1), ("B", y1, -1)):
			cy = balama + semn * lat / 2
			# foaia: doi montanți negri pe margini și o traversă sus; între ei, fără să se suprapună:
			# tabla ocru jos, banda roșie și geamul (obiect separat, transparent)
			xu, g, m = -X + 0.04, 0.05, 0.05  # planul ușii, grosimea, lățimea montanților
			ya, yb = sorted((balama + semn * 0.01, balama + semn * (lat - 0.01)))
			jos_u, sus_u = JOS + 0.06, SUS_GEAM - 0.06
			interior = (yb - ya) - 2 * m
			foaie = [
				cub("Montant usa", (g, m, sus_u - jos_u), (xu, ya + m / 2, (jos_u + sus_u) / 2), NEGRU),
				cub("Montant usa", (g, m, sus_u - jos_u), (xu, yb - m / 2, (jos_u + sus_u) / 2), NEGRU),
				cub("Traversa usa", (g, interior, m), (xu, cy, sus_u - m / 2), NEGRU),
				cub("Tabla usa", (g, interior, BRAU - 0.07 - jos_u), (xu, cy, (jos_u + BRAU - 0.07) / 2), OCRU),
				cub("Banda usa", (g, interior, 0.07), (xu, cy, BRAU - 0.035), ROSU),
				cub("Maner usa", (0.03, 0.03, 0.5), (xu + 0.06, cy, 1.4), METAL),
			]
			ob = uneste(foaie, "Usa%d%s" % (n, litera), (xu, balama, 0))
			sticla = uneste([cub("Geam usa", (0.012, interior, sus_u - m - BRAU), (xu, cy, (BRAU + sus_u - m) / 2), GEAM)],
				"GeamUsa%d%s" % (n, litera), (xu, balama, 0))
			sticla.parent = ob
			sticla.matrix_parent_inverse = ob.matrix_world.inverted()

	# --- roțile (cu jante și piulițe), originea în butuc, ca să se poată învârti
	for nume_ax, a in (("F", AXE[0]), ("S", AXE[1])):
		for nume_s, s in (("S", -1), ("D", 1)):
			latime = 0.3 if nume_ax == "F" else 0.5  # spate: roți duble
			roata = [
				cilindru("Anvelopa", ROATA, ROATA, latime, (s * (X - latime / 2 - 0.02), a, ROATA), NEGRU, laturi=12,
					rot=(0, 1.5708, 0)),
				cilindru("Janta", 0.27, 0.27, latime + 0.02, (s * (X - latime / 2 - 0.02), a, ROATA), METAL_INCHIS,
					laturi=10, rot=(0, 1.5708, 0)),
				cilindru("Butuc", 0.1, 0.1, latime + 0.06, (s * (X - latime / 2 - 0.02), a, ROATA), METAL, laturi=6,
					rot=(0, 1.5708, 0)),
			]
			for k in range(6):
				u = k * math.tau / 6
				roata.append(cub("Piulita", (latime + 0.04, 0.035, 0.035),
					(s * (X - latime / 2 - 0.02), a + math.cos(u) * 0.17, ROATA + math.sin(u) * 0.17), METAL))
			uneste(roata, "Roata%s%s" % (nume_ax, nume_s), (s * (X - latime / 2 - 0.02), a, ROATA))
	exporta(os.path.join(cale, "autobuz.glb"))


def statie(cale, nume="STATIE", fisier="statie.glb"):
	"""Stația de autobuz: copertină de tablă pe stâlpi, perete de plexiglas în spate (un panou lateral spart),
	bancă de lemn, afiș cu reclamă, orarul, tomberonaș și stâlpul cu plăcuța liniei 13.
	Lată pe X (3 m), deschisă spre -Y (spre stradă). Geamurile sunt separate (Geam*), cum sunt la autobuz.
	`nume` = ce scrie pe frontonul din față (stația lui Lexy: „BASCOV”, statie_bascov.glb)."""
	curata()
	r = random.Random(7)
	piese = []
	geamuri = []
	cadru = METAL_INCHIS
	for x in (-1.5, 1.5):
		for y in (-0.55, 0.6):
			piese.append(cub("Stalp", (0.07, 0.07, 2.35), (x, y, 1.175), cadru))
			piese.append(cub("Talpa", (0.16, 0.16, 0.03), (x, y, 0.015), cadru))
	piese += [
		cub("Acoperis", (3.4, 1.6, 0.06), (0, 0.0, 2.38), METAL, rot=(-0.06, 0, 0)),
		cub("Frontoane", (3.4, 0.05, 0.22), (0, -0.8, 2.32), p("295555")),
		cub("Frontoane spate", (3.4, 0.05, 0.12), (0, 0.8, 2.42), p("295555")),
		cub("Grinda", (2.93, 0.07, 0.07), (0, 0.6, 2.3), cadru),
		cub("Grinda", (2.93, 0.07, 0.07), (0, 0.6, 0.12), cadru),
		cub("Grinda", (2.93, 0.07, 0.07), (0, 0.6, 1.2), cadru),
		cub("Rugina", (0.6, 0.07, 0.1), (0.9, -0.8, 2.3), RUGINA),
		cub("Frunze pe acoperis", (0.9, 0.5, 0.03), (-0.6, 0.2, 2.43), p("a56850"), rot=(-0.06, 0, 0.2)),
	]
	# peretele din spate: două geamuri; în stânga lipit un afiș, pe lateral orarul
	geamuri.append(cub("Geam spate", (1.45, 0.012, 1.0), (-0.75, 0.6, 0.68), GEAM))
	geamuri.append(cub("Geam spate", (1.45, 0.012, 1.0), (0.75, 0.6, 0.68), GEAM))
	geamuri.append(cub("Geam spate sus", (2.95, 0.012, 1.0), (0, 0.6, 1.75), GEAM))
	piese.append(cub("Stalp mijloc", (0.05, 0.04, 2.2), (0, 0.6, 1.2), cadru))
	geamuri.append(cub("Geam lateral", (0.012, 1.05, 1.9), (1.5, 0.03, 1.2), GEAM))
	# panoul din stânga e spart: rama goală, cioburi pe jos și o bucată rămasă în colț
	piese.append(cub("Rama lateral", (0.05, 1.1, 0.05), (-1.5, 0.03, 0.25), cadru))
	piese.append(cub("Rama lateral", (0.05, 1.1, 0.05), (-1.5, 0.03, 2.15), cadru))
	geamuri.append(cub("Geam ciob", (0.012, 0.3, 0.45), (-1.5, 0.43, 1.9), GEAM, rot=(0.4, 0, 0)))
	for _ in range(9):
		piese.append(cub("Ciob", (r.uniform(0.04, 0.1), r.uniform(0.04, 0.1), 0.01),
			(-1.5 + r.uniform(-0.4, 0.3), r.uniform(-0.3, 0.5), 0.008), p("61a19f"), rot=(0, 0, r.uniform(0, 3))))
	# afiș de concert de manele, decolorat, pe dinăuntru
	piese += [
		cub("Afis", (0.75, 0.01, 1.0), (-0.85, 0.585, 1.5), p("a18463")),
		cub("Afis poza", (0.5, 0.012, 0.45), (-0.85, 0.572, 1.62), p("7b383a")),
		cub("Afis titlu", (0.6, 0.012, 0.1), (-0.85, 0.572, 1.32), NEGRU),
		cub("Afis rupt", (0.25, 0.014, 0.3), (-0.6, 0.579, 1.15), p("7e8d87"), rot=(0, 0.3, 0)),
		# orarul, într-o ramă, pe stâlpul din dreapta
		cub("Orar rama", (0.04, 0.38, 0.5), (1.45, -0.45, 1.5), cadru),
		cub("Orar", (0.02, 0.32, 0.42), (1.42, -0.45, 1.5), ALB),
		cub("Orar titlu", (0.01, 0.25, 0.05), (1.4, -0.45, 1.65), p("295555")),
	]
	for i in range(6):
		piese.append(cub("Orar rand", (0.01, 0.22, 0.012), (1.4, -0.45, 1.55 - i * 0.045), NEGRU))
	# graffiti pe geam și pe bancă
	piese.append(cub("Graffiti", (0.5, 0.014, 0.12), (0.7, 0.592, 0.9), p("30716f"), rot=(0, 0.25, 0)))
	piese.append(cub("Graffiti", (0.3, 0.014, 0.08), (0.9, 0.592, 0.8), p("30716f"), rot=(0, -0.4, 0)))
	piese.append(cub("Graffiti", (0.4, 0.014, 0.06), (0.4, 0.592, 0.62), p("7b383a"), rot=(0, 0.1, 0)))
	# banca: trei scânduri pe două console
	for x in (-0.9, 0.9):
		piese.append(cub("Consola banca", (0.05, 0.35, 0.05), (x, 0.405, 0.45), cadru))
		piese.append(cub("Picior banca", (0.05, 0.05, 0.45), (x, 0.2, 0.225), cadru))
	for i in range(3):
		piese.append(cub("Scandura", (2.3, 0.1, 0.035), (0, 0.24 + i * 0.12, 0.49), RUGINA))
	piese.append(cub("Scandura rupta", (0.6, 0.1, 0.02), (0.75, 0.48, 0.5175), p("5e363e")))
	# tomberonaș de tablă prins de stâlp, cu un pahar aruncat lângă
	piese += [
		cilindru("Cos", 0.17, 0.15, 0.45, (1.25, -0.25, 0.65), p("445d46"), laturi=8),
		cilindru("Gura cos", 0.175, 0.175, 0.03, (1.25, -0.25, 0.88), NEGRU, laturi=8),
		cub("Prindere cos", (0.25, 0.04, 0.05), (1.38, -0.25, 0.8), cadru),
		cilindru("Pahar", 0.035, 0.03, 0.09, (0.95, -0.5, 0.035), ALB, laturi=6, rot=(1.5708, 0, 0.5)),
	]
	# stâlpul cu plăcuța stației și numărul liniei (lângă bordură, în dreapta)
	piese += [
		cilindru("Stalp placuta", 0.035, 0.035, 2.7, (2.1, -0.65, 1.35), METAL, laturi=6),
		# plăcuțele stau ÎN FAȚA stâlpului (spre stradă), nu prin el: stâlpul iese până la y = -0,685
		cub("Placuta chenar", (0.6, 0.03, 0.45), (2.1, -0.68, 2.55), p("295555")),
		cub("Placuta", (0.55, 0.03, 0.4), (2.1, -0.71, 2.55), ALB),
		cub("Autobuz desenat", (0.32, 0.012, 0.14), (2.1, -0.733, 2.6), p("295555")),
		cub("Roti desenate", (0.25, 0.012, 0.04), (2.1, -0.733, 2.5), p("295555")),
		cub("Placuta linie", (0.3, 0.03, 0.22), (2.1, -0.71, 2.12), p("a18463")),
		text("Numar linie", "13", (2.1, -0.735, 2.12), 0.16, NEGRU),
		text("Statie", nume, (0, -0.83, 2.32), 0.12, ALB),
	]
	uneste(piese, "Statie")
	uneste(geamuri, "Geamuri")
	exporta(os.path.join(cale, fisier))


def sofer(cale):
	"""Șoferul de noapte, așezat, cu mâinile pe volan: geacă de piele, burtă, șapcă, mustață.
	Originea = pe scaun, sub fund. `Cap` e separat (originea în gât): în joc se întoarce spre tine."""
	curata()
	piele = p("a56850")
	umbra = p("904a40")
	geaca = p("553e4d")
	pantaloni = p("32453b")
	corp = [
		trunchi("Trunchi", [((0, 0.06, 0.0), 0.19, 0.15), ((0, 0.0, 0.18), 0.22, 0.2), ((0, 0.02, 0.32), 0.22, 0.17),
			((0, 0.06, 0.48), 0.21, 0.13), ((0, 0.07, 0.56), 0.15, 0.1), ((0, 0.06, 0.6), 0.0, 0.0)], geaca, laturi=10),
		trunchi("Guler", [((0, 0.06, 0.53), 0.12, 0.1), ((0, 0.06, 0.62), 0.11, 0.09)], p("6f6d7f"), laturi=8),
		cub("Fermoar", (0.02, 0.01, 0.4), (0, -0.2, 0.25), METAL, rot=(0.2, 0, 0)),
	]
	for s in (-1, 1):
		x = 0.1 * s
		corp += [
			trunchi("Coapsa", [((x, 0.04, 0.05), 0.09, 0.09), ((x * 1.15, -0.2, 0.07), 0.085, 0.08),
				((x * 1.2, -0.42, 0.08), 0.07, 0.07)], pantaloni, laturi=7),
			trunchi("Gamba", [((x * 1.2, -0.42, 0.08), 0.065, 0.065), ((x * 1.25, -0.48, -0.15), 0.055, 0.055),
				((x * 1.25, -0.5, -0.4), 0.045, 0.045)], pantaloni, laturi=7),
			cub("Pantof", (0.1, 0.24, 0.08), (x * 1.25, -0.57, -0.43), NEGRU),
			trunchi("Brat", [((0.2 * s, 0.07, 0.5), 0.065, 0.065), ((0.25 * s, -0.08, 0.3), 0.06, 0.06),
				((0.22 * s, -0.3, 0.18), 0.05, 0.05), ((0.17 * s, -0.47, 0.13), 0.042, 0.042)], geaca, laturi=7),
			sfera("Mana", 0.045, (0.16 * s, -0.5, 0.13), piele, scara=(1, 1.2, 0.8), segmente=6, inele=4),
		]
	uneste(corp, "Sofer")
	gat = (0, 0.06, 0.6)
	cap = [
		trunchi("Gat", [((0, 0.06, 0.57), 0.055, 0.055), ((0, 0.05, 0.67), 0.05, 0.05)], piele, laturi=7),
		trunchi("Fata", [((0, 0.0, 0.64), 0.0, 0.0), ((0, -0.005, 0.66), 0.07, 0.065), ((0, 0.01, 0.72), 0.095, 0.1),
			((0, 0.02, 0.8), 0.1, 0.11), ((0, 0.03, 0.86), 0.085, 0.09), ((0, 0.035, 0.9), 0.0, 0.0)], piele, laturi=10,
			ref=(1, 0, 0)),
		trunchi("Nas", [((0, -0.08, 0.79), 0.022, 0.018), ((0, -0.11, 0.765), 0.03, 0.022), ((0, -0.108, 0.75), 0.0, 0.0)],
			umbra, laturi=6, ref=(1, 0, 0)),
		cub("Mustata", (0.12, 0.03, 0.03), (0, -0.095, 0.735), NEGRU),
		cub("Mustata", (0.04, 0.025, 0.04), (0.06, -0.085, 0.71), NEGRU, rot=(0, 0.3, 0)),
		cub("Mustata", (0.04, 0.025, 0.04), (-0.06, -0.085, 0.71), NEGRU, rot=(0, -0.3, 0)),
		cub("Gura", (0.05, 0.01, 0.008), (0, -0.094, 0.705), umbra),
		cub("Barba nerasa", (0.14, 0.05, 0.05), (0, -0.06, 0.68), p("5e363e")),
		# șapca de piele, cu cozoroc
		cilindru("Sapca", 0.11, 0.115, 0.07, (0, 0.03, 0.885), CAUCIUC, laturi=10, scara=(1, 1.12, 1)),
		cub("Cozoroc", (0.18, 0.1, 0.015), (0, -0.1, 0.86), NEGRU, rot=(0.25, 0, 0)),
	]
	for s in (-1, 1):
		cap += [
			cub("Ochi", (0.03, 0.01, 0.012), (0.04 * s, -0.085, 0.8), NEGRU),
			cub("Cearcan", (0.035, 0.008, 0.012), (0.04 * s, -0.082, 0.787), umbra),
			cub("Spranceana", (0.045, 0.012, 0.014), (0.042 * s, -0.088, 0.822), NEGRU, rot=(0, 0.15 * s, 0)),
			sfera("Ureche", 0.025, (0.1 * s, 0.03, 0.78), piele, scara=(0.4, 1, 1.3), segmente=6, inele=4),
		]
	uneste(cap, "Cap", gat)
	exporta(os.path.join(cale, "sofer.glb"))


def creatura(cale):
	"""Ce aleargă pe lângă autobuz: înalt de 2,3 m, slab ca o cracă, cu brațe până la genunchi,
	picioare îndoite ca la câine, cap lunguieț cu fălci deschise și ochi care sclipesc.
	Stă drept, cu fața spre -Y; originea la sol. Piese separate, ca să alerge în joc:
	`Corp` (originea în bazin), `BratS`/`BratD` (în umăr), `PiciorS`/`PiciorD` (în șold), `Ochi` (copil al lui Corp)."""
	curata()
	piele = p("7e8d87")  # palidă, cenușie: în întuneric se vede ca o arătare
	umbra = p("48313b")
	os_culoare = p("70706e")
	dinti = p("83b3b0")
	bazin = (0, 0, 1.15)
	corp = [
		trunchi("Trunchi", [((0, 0.02, 1.08), 0.12, 0.09), ((0, 0.0, 1.2), 0.14, 0.08), ((0, -0.01, 1.35), 0.11, 0.07),
			((0, 0.0, 1.5), 0.15, 0.1), ((0, 0.02, 1.65), 0.2, 0.11), ((0, 0.04, 1.76), 0.18, 0.09),
			((0, 0.03, 1.82), 0.06, 0.05)], piele, laturi=8),
		# gâtul lung, aplecat în față
		trunchi("Gat", [((0, 0.03, 1.8), 0.05, 0.05), ((0, -0.05, 1.95), 0.045, 0.045), ((0, -0.1, 2.05), 0.05, 0.05)],
			piele, laturi=6),
		# craniul lunguieț și falca de jos, căscată
		trunchi("Craniu", [((0, 0.02, 2.06), 0.0, 0.0), ((0, -0.02, 2.1), 0.08, 0.08), ((0, -0.1, 2.14), 0.09, 0.085),
			((0, -0.2, 2.13), 0.07, 0.06), ((0, -0.3, 2.1), 0.045, 0.035), ((0, -0.34, 2.08), 0.0, 0.0)], piele,
			laturi=8, ref=(1, 0, 0)),
		trunchi("Falca", [((0, -0.08, 2.04), 0.06, 0.03), ((0, -0.2, 1.98), 0.05, 0.025), ((0, -0.29, 1.95), 0.03, 0.015),
			((0, -0.31, 1.945), 0.0, 0.0)], os_culoare, laturi=6, ref=(1, 0, 0)),
		cub("Gura", (0.06, 0.18, 0.05), (0, -0.2, 2.03), umbra, rot=(0.25, 0, 0)),
	]
	for i in range(5):
		y = -0.12 - i * 0.04
		corp.append(cub("Dinte sus", (0.075, 0.008, 0.035), (0, y - 0.05, 2.06 - i * 0.004), dinti))
		corp.append(cub("Dinte jos", (0.06, 0.008, 0.03), (0, y - 0.05, 1.99 - i * 0.008), dinti))
	# coastele care ies prin piele și șira spinării
	for i in range(5):
		z = 1.45 + i * 0.06
		for s in (-1, 1):
			corp.append(cub("Coasta", (0.11, 0.02, 0.015), (0.08 * s, -0.08 - (0.01 if i in (2, 3) else 0), z), umbra,
				rot=(0, 0.3 * s, 0)))
	for i in range(8):
		corp.append(sfera("Vertebra", 0.025, (0, 0.1 + (0.02 if 3 < i < 7 else 0), 1.15 + i * 0.08), os_culoare,
			segmente=5, inele=3))
	trup = uneste(corp, "Corp", bazin)
	ochi = []
	for s in (-1, 1):
		ochi.append(sfera("Ochi", 0.018, (0.045 * s, -0.19, 2.155), ALB, scara=(1.3, 0.6, 0.8), segmente=6, inele=4))
	ob_ochi = uneste(ochi, "Ochi", bazin)
	ob_ochi.parent = trup
	ob_ochi.matrix_parent_inverse = trup.matrix_world.inverted()

	for nume, s in (("BratS", -1), ("BratD", 1)):
		umar = (0.2 * s, 0.04, 1.74)
		brat = [
			trunchi("Brat", [(umar, 0.045, 0.045), ((0.26 * s, 0.0, 1.45), 0.035, 0.035), ((0.29 * s, -0.03, 1.2), 0.04, 0.035),
				((0.3 * s, -0.06, 0.95), 0.03, 0.028), ((0.31 * s, -0.08, 0.72), 0.025, 0.025)], piele, laturi=6),
			sfera("Cot", 0.04, (0.29 * s, -0.03, 1.2), os_culoare, segmente=6, inele=4),
			trunchi("Palma", [((0.31 * s, -0.08, 0.74), 0.04, 0.015), ((0.31 * s, -0.09, 0.66), 0.05, 0.015)], piele,
				laturi=6, ref=(0, 1, 0)),
		]
		for k in range(4):
			dx = (-0.03 + k * 0.02) * s
			brat.append(trunchi("Gheara", [((0.31 * s + dx, -0.09, 0.66), 0.008, 0.008),
				((0.31 * s + dx * 1.4, -0.12, 0.5), 0.006, 0.006), ((0.31 * s + dx * 1.5, -0.16, 0.42), 0.0, 0.0)],
				os_culoare, laturi=4))
		uneste(brat, nume, umar)

	for nume, s in (("PiciorS", -1), ("PiciorD", 1)):
		sold = (0.12 * s, 0.0, 1.12)
		picior = [
			trunchi("Coapsa", [(sold, 0.065, 0.065), ((0.14 * s, -0.1, 0.88), 0.05, 0.05), ((0.15 * s, -0.18, 0.65), 0.04, 0.04)],
				piele, laturi=6),
			sfera("Genunchi", 0.045, (0.15 * s, -0.18, 0.65), os_culoare, segmente=6, inele=4),
			trunchi("Gamba", [((0.15 * s, -0.18, 0.65), 0.035, 0.035), ((0.15 * s, -0.02, 0.42), 0.03, 0.03),
				((0.15 * s, 0.1, 0.22), 0.028, 0.028)], piele, laturi=6),
			trunchi("Laba", [((0.15 * s, 0.1, 0.22), 0.03, 0.03), ((0.15 * s, -0.02, 0.06), 0.035, 0.02),
				((0.15 * s, -0.16, 0.01), 0.04, 0.012)], piele, laturi=6),
		]
		for k in range(3):
			dx = (-0.025 + k * 0.025)
			picior.append(trunchi("Gheara", [((0.15 * s + dx, -0.15, 0.015), 0.007, 0.007),
				((0.15 * s + dx * 1.3, -0.24, 0.005), 0.0, 0.0)], os_culoare, laturi=4))
		uneste(picior, nume, sold)
	exporta(os.path.join(cale, "creatura.glb"))


def brad(cale, nume, saminta, inaltime, straturi):
	"""Brad întunecat pentru pădurea de pe drum: trunchi și conuri suprapuse, ușor strâmbe."""
	curata()
	r = random.Random(saminta)
	culori = [p("32453b"), p("2a3c3d"), p("445d46"), p("295555")]
	piese = [cilindru("Trunchi", 0.18, 0.06, inaltime, (0, 0, inaltime / 2), CAUCIUC, laturi=6)]
	for i in range(straturi):
		t = i / straturi
		z = inaltime * (0.18 + 0.78 * t)
		raza = (1.0 - t) * inaltime * 0.24 + 0.25
		piese.append(cilindru("Cetina", raza, 0.05, inaltime * 0.3, (r.uniform(-0.1, 0.1), r.uniform(-0.1, 0.1), z),
			r.choice(culori), laturi=7, rot=(r.uniform(-0.06, 0.06), r.uniform(-0.06, 0.06), r.uniform(0, 1))))
	# câteva crengi uscate jos, fără ace
	for _ in range(4):
		u = r.uniform(0, math.tau)
		z = r.uniform(0.8, inaltime * 0.2)
		piese.append(os_intre("Creanga", (0, 0, z), (math.cos(u) * 0.9, math.sin(u) * 0.9, z - 0.2), 0.025, CAUCIUC, laturi=4))
	uneste(piese, "Brad")
	exporta(os.path.join(cale, nume + ".glb"))


def stalpisor(cale):
	"""Stâlpișorul alb de pe marginea drumului, cu bandă neagră și ochi de pisică (Reflector, strălucește)."""
	curata()
	uneste([
		cub("Stalpisor", (0.1, 0.1, 1.0), (0, 0, 0.5), ALB),
		cub("Banda", (0.12, 0.12, 0.22), (0, 0, 0.82), NEGRU),
		cub("Noroi", (0.12, 0.12, 0.12), (0, 0, 0.06), p("5e5356")),
	], "Stalpisor")
	uneste([cub("Reflector", (0.06, 0.012, 0.12), (0, -0.056, 0.82), p("a56850"))], "Reflector")
	exporta(os.path.join(cale, "stalpisor.glb"))


def stalp_lemn(cale):
	"""Stâlp de lemn de pe marginea drumului, cu traversă și izolatori (firele le pune jocul)."""
	curata()
	uneste([
		cilindru("Stalp", 0.13, 0.1, 8.0, (0, 0, 4.0), p("553e4d"), laturi=6, rot=(0.03, 0, 0)),
		cub("Traversa", (1.6, 0.1, 0.1), (0, 0.12, 7.4), p("553e4d")),
		cilindru("Izolator", 0.04, 0.03, 0.12, (-0.7, 0.12, 7.51), ALB, laturi=5),
		cilindru("Izolator", 0.04, 0.03, 0.12, (0.0, 0.12, 7.51), ALB, laturi=5),
		cilindru("Izolator", 0.04, 0.03, 0.12, (0.7, 0.12, 7.51), ALB, laturi=5),
		cub("Placuta", (0.15, 0.02, 0.2), (0, -0.12, 2.5), p("a18463")),
	], "StalpLemn")
	exporta(os.path.join(cale, "stalp_lemn.glb"))


def toate(cale):
	autobuz(cale)
	statie(cale)
	statie(cale, "BASCOV", "statie_bascov.glb")
	sofer(cale)
	creatura(cale)
	brad(cale, "brad_1", 4, 9.0, 6)
	brad(cale, "brad_2", 9, 12.0, 7)
	stalpisor(cale)
	stalp_lemn(cale)


if __name__ == "__main__":
	toate(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models"))
