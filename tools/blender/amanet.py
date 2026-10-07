# Amanetul lui Johnny („JOHNNY'S PAWN”), clădirea de lângă spălătorie (casino.tscn): parterul vecinului din stânga,
# un magazin mic, înghesuit, în care intri pe ușa de lângă spălătorie. Fațada (cărămidă, vitrina cu gratii și obiecte
# la vânzare, firma luminată, neonul „OPEN”), înăuntru tejgheaua de sticlă cu bijuterii, casa de marcat, lampa de bancher,
# peretele din spate cu chitare, saxofon, trompetă, săbii, seiful, monitorul camerelor; în stânga raftul cu electronice,
# în dreapta bicicleta, chitarele și amplificatorul; neoanele din tavan. Plus ușa (`usa_amanet`) și Johnny (`johnny`).
#   blender --background --factory-startup --python tools/blender/amanet.py               (toate)
#   blender --background --factory-startup --python tools/blender/amanet.py -- johnny     (doar unele)
# Axe Blender: Z în sus, fațada spre -Y (în Godot +Z, spre stradă); înăuntru e spre +Y (Godot -Z).
# Coordonatele sunt ale casino-ului (originea = mijlocul fațadei spălătoriei, la nivelul străzii), deci în Godot
# modelul stă în origine, ca strada. Etajele de deasupra și restul clădirii sunt în casino.py (strada()).
import math
import os
import random
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, uneste, exporta, trunchi  # noqa: E402
from lexy import perete  # noqa: E402
from casino import _text, _text_o_fata, _tor, _cutie_coliziune  # noqa: E402
from coven import _parinte  # noqa: E402
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
CARAMIDA = p("7b383a")
MORTAR = p("5e363e")
VERDE = p("445d46")
VERDE_DESCHIS = p("5b6d4e")
TEAL = p("295555")
TURCOAZ = p("438b88")
ECRAN = p("61a19f")
PERETE = p("778c96")
TAVAN = p("7e8d87")
MOV = p("655269")

# --- magazinul (parterul): x de la X0 la X1 înăuntru, pereții până la XE0 / XE1; fațada de la y 0 la Y0
XE0, XE1 = -15.0, -7.4
X0, X1 = -14.75, -7.7
Y0 = 0.25    # fața dinăuntru a fațadei
Y1 = 6.6     # fața dinăuntru a peretelui din spate (peretele merge până la 7,2, ca restul clădirii)
YE = 7.2
FL = 0.15    # podeaua (= trotuarul)
HC = 3.3     # tavanul
TOP = 3.6    # de aici în sus e etajul (casino.py)
VITRINA = (-14.2, -9.8, 0.6, 2.5)
USA = (-9.1, -8.1, FL, FL + 2.25)
# tejgheaua: de la peretele din stânga până în dreapta, fața spre client la TY0, spatele la TY1, blatul la TZ
TY0, TY1, TZ = 3.7, 4.3, FL + 0.98
SX0, SX1 = -14.2, -9.4   # partea de sticlă (vitrina cu bijuterii)
CLAPA = -8.75            # de aici până la perete: clapeta (blatul care se ridică) cu ușița de dedesubt
# Johnny stă în spatele tejghelei, în dreptul casei
JX, JY = -11.8, 4.62


def _obiect(piese_locale, loc, rot=(0, 0, 0), nume="Obiect"):
	"""Lipește piesele făcute în jurul originii și le mută/rotește la `loc` (obiectele care se repetă)."""
	ob = uneste(piese_locale, nume)
	ob.location = loc
	ob.rotation_euler = rot
	bpy.ops.object.select_all(action='DESELECT')
	ob.select_set(True)
	bpy.context.view_layer.objects.active = ob
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	return ob


# ---------------------------------------------------------------------------------------------------------------
# Obiectele de vânzare (făcute în origine: fața spre -Y, sus = Z)
# ---------------------------------------------------------------------------------------------------------------

def _chitara_electrica(cul, cul_pick=NEGRU):
	"""Chitară electrică, în picioare (gâtul în sus), cu corpul în dublu cutaway: originea = mijlocul corpului."""
	s = [
		sfera("Corp chitara", 0.17, (0, 0, -0.04), cul, scara=(1.0, 0.13, 0.85), segmente=12, inele=6),
		sfera("Corp chitara", 0.13, (0, 0, 0.13), cul, scara=(1.0, 0.13, 0.85), segmente=12, inele=6),
		sfera("Corn chitara", 0.05, (-0.1, 0, 0.24), cul, scara=(0.7, 0.4, 1.3), segmente=8, inele=4),
		sfera("Corn chitara", 0.045, (0.09, 0, 0.21), cul, scara=(0.7, 0.4, 1.2), segmente=8, inele=4),
		cub("Pickguard", (0.16, 0.008, 0.2), (0.03, -0.022, 0.0), cul_pick, rot=(0, 0.3, 0)),
		cub("Doza", (0.08, 0.012, 0.022), (0, -0.026, 0.07), CROM),
		cub("Doza", (0.08, 0.012, 0.022), (0, -0.026, -0.02), CROM),
		cub("Calus", (0.07, 0.014, 0.02), (0, -0.026, -0.12), CROM),
		cub("Gat chitara", (0.05, 0.022, 0.46), (0, -0.004, 0.45), LEMN_DESCHIS),
		cub("Taste", (0.044, 0.006, 0.42), (0, -0.017, 0.45), LEMN_INCHIS),
		cub("Cap chitara", (0.075, 0.02, 0.16), (0.008, 0.0, 0.75), cul, rot=(0, 0.15, 0)),
	]
	for k in range(3):
		s.append(cilindru("Cheie", 0.008, 0.008, 0.03, (0.05, 0.0, 0.7 + k * 0.045), CROM, laturi=4, rot=(0, 1.5708, 0)))
		s.append(cilindru("Buton", 0.012, 0.012, 0.012, (0.07 + k * 0.025, -0.022, -0.1 + k * 0.012), ALB, laturi=6, rot=(1.5708, 0, 0)))
	return s


def _chitara_acustica():
	"""Chitară acustică (corpul ca un 8, rozeta neagră), originea = mijlocul corpului."""
	s = [
		sfera("Corp chitara", 0.2, (0, 0, -0.07), LEMN_DESCHIS, scara=(1.0, 0.24, 1.0), segmente=12, inele=6),
		sfera("Corp chitara", 0.155, (0, 0, 0.17), LEMN_DESCHIS, scara=(1.0, 0.3, 1.0), segmente=12, inele=6),
		cilindru("Rozeta", 0.055, 0.055, 0.01, (0, -0.045, 0.1), NEGRU, laturi=12, rot=(1.5708, 0, 0)),
		cub("Calus", (0.12, 0.014, 0.025), (0, -0.05, -0.12), LEMN_INCHIS),
		cub("Gat chitara", (0.052, 0.024, 0.46), (0, -0.01, 0.53), LEMN),
		cub("Taste", (0.046, 0.006, 0.42), (0, -0.024, 0.53), LEMN_INCHIS),
		cub("Cap chitara", (0.08, 0.02, 0.17), (0, -0.006, 0.84), LEMN_INCHIS),
	]
	return s


def _saxofon():
	"""Saxofon de alamă, în picioare (pavilionul jos, spre dreapta-față), originea = mijlocul tubului."""
	s = [
		trunchi("Tub sax", [((0, 0, 0.32), 0.012, 0.012), ((0, 0, 0.15), 0.025, 0.025), ((0, 0, -0.12), 0.035, 0.035),
			((0.02, 0, -0.24), 0.04, 0.04), ((0.09, 0, -0.28), 0.045, 0.045), ((0.14, 0, -0.2), 0.05, 0.05),
			((0.15, 0, -0.05), 0.07, 0.07), ((0.16, 0, 0.0), 0.085, 0.085)], AUR, laturi=8, ref=(0, 1, 0)),
		os_intre("Gat sax", (0, 0, 0.32), (-0.05, 0, 0.38), 0.011, AUR, laturi=6),
		cilindru("Mustiuc", 0.012, 0.008, 0.06, (-0.08, 0, 0.39), NEGRU, laturi=6, rot=(0, -1.2, 0)),
	]
	for k in range(6):
		s.append(cilindru("Clapa sax", 0.014, 0.014, 0.008, (0.0, -0.032, 0.1 - k * 0.05), BRONZ, laturi=6, rot=(1.5708, 0, 0)))
	return s


def _trompeta():
	"""Trompetă culcată (pavilionul spre +X), originea = mijlocul ei."""
	s = [
		os_intre("Tub trompeta", (-0.22, 0, 0.0), (0.12, 0, 0.0), 0.009, AUR, laturi=6),
		os_intre("Tub trompeta", (-0.12, 0, -0.06), (0.08, 0, -0.06), 0.009, AUR, laturi=6),
		cilindru("Pavilion", 0.012, 0.06, 0.12, (0.18, 0, 0.0), AUR, laturi=10, rot=(0, 1.5708, 0)),
		cilindru("Mustiuc", 0.006, 0.012, 0.035, (-0.24, 0, 0.0), CROM, laturi=6, rot=(0, 1.5708, 0)),
	]
	for k in range(3):
		s.append(cilindru("Piston", 0.014, 0.014, 0.1, (-0.03 + k * 0.03, 0, -0.02), AUR, laturi=6))
		s.append(cilindru("Buton piston", 0.012, 0.012, 0.012, (-0.03 + k * 0.03, 0, 0.04), ALB, laturi=6))
	s.append(_tor("Curba", 0.03, 0.009, (-0.16, 0, -0.03), AUR, rot=(1.5708, 0, 0), segmente=10))
	return s


def _televizor(lat=0.5, ecran_aprins=False, lumini=None):
	"""Televizor vechi (CRT) cu fundul adânc: originea = jos la mijloc."""
	h, a = lat * 0.78, lat * 0.85
	s = [
		cub("Carcasa tv", (lat, a * 0.55, h), (0, 0.0, h / 2), METAL_INCHIS),
		cub("Spate tv", (lat * 0.7, a * 0.45, h * 0.75), (0, a * 0.45, h * 0.45), METAL_INCHIS),
		cub("Rama ecran", (lat * 0.78, 0.01, h * 0.72), (-lat * 0.07, -a * 0.275 - 0.005, h * 0.55), NEGRU),
		cub("Panou tv", (lat * 0.14, 0.01, h * 0.7), (lat * 0.39, -a * 0.275 - 0.005, h * 0.5), METAL),
	]
	for k in range(2):
		s.append(cilindru("Buton tv", 0.014, 0.014, 0.012, (lat * 0.39, -a * 0.275 - 0.012, h * (0.7 - k * 0.15)), NEGRU, laturi=6,
			rot=(1.5708, 0, 0)))
	ecran = cub("Ecran tv", (lat * 0.68, 0.01, h * 0.6), (-lat * 0.07, -a * 0.275 - 0.01, h * 0.55), ECRAN if ecran_aprins else GEAM)
	(lumini if ecran_aprins and lumini is not None else s).append(ecran)
	return s


def _video(lat=0.42):
	"""Video (VCR) / amplificator plat: originea = jos la mijloc."""
	return [
		cub("Video", (lat, 0.3, 0.09), (0, 0, 0.045), NEGRU),
		cub("Fanta video", (lat * 0.45, 0.01, 0.015), (-lat * 0.15, -0.152, 0.055), METAL_INCHIS),
		cub("Afisaj video", (0.08, 0.01, 0.02), (lat * 0.3, -0.152, 0.055), ECRAN),
	]


def _boombox():
	s = [
		cub("Boombox", (0.5, 0.15, 0.24), (0, 0, 0.12), METAL),
		cub("Maner boombox", (0.36, 0.03, 0.03), (0, 0, 0.27), METAL_INCHIS),
		cub("Caseta", (0.12, 0.01, 0.08), (0, -0.078, 0.13), NEGRU),
	]
	for k in (-1, 1):
		s.append(cilindru("Difuzor", 0.075, 0.075, 0.012, (0.16 * k, -0.078, 0.11), NEGRU, laturi=10, rot=(1.5708, 0, 0)))
		s.append(cilindru("Con difuzor", 0.03, 0.03, 0.012, (0.16 * k, -0.084, 0.11), METAL_INCHIS, laturi=8, rot=(1.5708, 0, 0)))
	return s


def _aparat_foto():
	return [
		cub("Aparat foto", (0.14, 0.07, 0.09), (0, 0, 0.045), NEGRU),
		cilindru("Obiectiv", 0.032, 0.032, 0.07, (0, -0.07, 0.045), METAL_INCHIS, laturi=10, rot=(1.5708, 0, 0)),
		cilindru("Lentila", 0.024, 0.024, 0.005, (0, -0.106, 0.045), GEAM, laturi=10, rot=(1.5708, 0, 0)),
		cub("Blitz", (0.04, 0.03, 0.02), (0.04, 0, 0.1), CROM),
	]


def _consola():
	"""Consolă de jocuri cu două manete în fața ei."""
	s = [
		cub("Consola", (0.3, 0.24, 0.07), (0, 0, 0.035), NEGRU),
		cub("Fanta consola", (0.12, 0.01, 0.015), (0, -0.122, 0.045), METAL_INCHIS),
	]
	for k in (-1, 1):
		s.append(cub("Maneta", (0.12, 0.06, 0.03), (0.09 * k, -0.2, 0.015), METAL_INCHIS, rot=(0, 0, 0.2 * k)))
		s.append(os_intre("Fir maneta", (0.09 * k, -0.17, 0.01), (0.05 * k, -0.12, 0.02), 0.004, NEGRU, laturi=4))
	return s


def _bicicleta():
	"""Bicicletă BMX agățată pe perete, de profil: în planul XZ, originea = mijlocul cadrului."""
	s = []
	for x in (-0.38, 0.38):
		s.append(_tor("Roata", 0.27, 0.02, (x, 0, 0), NEGRU, rot=(1.5708, 0, 0), segmente=20))
		s.append(_tor("Janta", 0.22, 0.008, (x, 0, 0), CROM, rot=(1.5708, 0, 0), segmente=16))
		s.append(cilindru("Butuc", 0.025, 0.025, 0.06, (x, 0, 0), CROM, laturi=6, rot=(1.5708, 0, 0)))
		for k in range(4):
			u = k * math.pi / 4
			s.append(os_intre("Spita", (x - math.cos(u) * 0.21, 0, -math.sin(u) * 0.21), (x + math.cos(u) * 0.21, 0, math.sin(u) * 0.21),
				0.003, CROM, laturi=4))
	pedalier, sa, ghidon = (0.0, 0, -0.02), (-0.12, 0, 0.3), (0.28, 0, 0.36)
	for a, b in ((pedalier, sa), (pedalier, (0.28, 0, 0.24)), (sa, (0.28, 0, 0.24)), (pedalier, (-0.38, 0, 0.0)), (sa, (-0.38, 0, 0.0)),
			((0.28, 0, 0.24), (0.38, 0, 0.0)), ((0.28, 0, 0.24), ghidon)):
		s.append(os_intre("Cadru", a, b, 0.016, ROSU, laturi=6))
	s.append(cub("Sa", (0.16, 0.06, 0.03), (-0.12, 0, 0.33), NEGRU))
	s.append(os_intre("Ghidon", (0.28, -0.18, 0.37), (0.28, 0.18, 0.37), 0.012, CROM, laturi=6))
	s.append(cilindru("Foaie", 0.07, 0.07, 0.012, pedalier, CROM, laturi=10, rot=(1.5708, 0, 0)))
	return s


def _bormasina():
	return [
		cub("Bormasina", (0.2, 0.07, 0.08), (0, 0, 0.18), p("a18463")),
		cub("Maner bormasina", (0.06, 0.06, 0.15), (-0.04, 0, 0.07), NEGRU, rot=(0, 0.25, 0)),
		cub("Acumulator", (0.09, 0.08, 0.05), (-0.06, 0, 0.0), NEGRU),
		cilindru("Mandrina", 0.022, 0.016, 0.06, (0.13, 0, 0.18), METAL_INCHIS, laturi=6, rot=(0, 1.5708, 0)),
		cilindru("Burghiu", 0.005, 0.005, 0.08, (0.2, 0, 0.18), CROM, laturi=4, rot=(0, 1.5708, 0)),
	]


def _drujba():
	return [
		cub("Drujba", (0.28, 0.16, 0.2), (0, 0, 0.1), p("a56850")),
		cub("Lama drujba", (0.45, 0.02, 0.07), (0.34, 0, 0.08), CROM),
		cub("Lant drujba", (0.47, 0.025, 0.012), (0.34, 0, 0.12), METAL_INCHIS),
		os_intre("Maner drujba", (-0.05, -0.09, 0.14), (-0.05, 0.09, 0.14), 0.014, NEGRU, laturi=6),
		os_intre("Maner drujba", (0.1, -0.09, 0.25), (0.1, 0.09, 0.25), 0.014, NEGRU, laturi=6),
		os_intre("Maner drujba", (0.1, -0.09, 0.25), (0.1, -0.09, 0.12), 0.014, NEGRU, laturi=6),
	]


def _sac_golf():
	s = [
		cilindru("Sac golf", 0.12, 0.13, 0.85, (0, 0, 0.425), VERDE, laturi=10),
		cilindru("Buza sac", 0.13, 0.13, 0.05, (0, 0, 0.86), NEGRU, laturi=10),
		cub("Buzunar sac", (0.12, 0.04, 0.4), (0, -0.13, 0.35), VERDE_DESCHIS),
		os_intre("Curea sac", (0.0, -0.13, 0.75), (0.0, 0.13, 0.2), 0.012, NEGRU, laturi=4),
	]
	for k in range(5):
		u = k * 1.3
		varf = (math.cos(u) * 0.06, math.sin(u) * 0.06, 1.08 + 0.04 * (k % 2))
		s.append(os_intre("Crosa", (math.cos(u) * 0.05, math.sin(u) * 0.05, 0.85), varf, 0.008, CROM, laturi=4))
		s.append(cub("Cap crosa", (0.07, 0.03, 0.04), (varf[0] + 0.02, varf[1], varf[2]), CROM if k % 2 else NEGRU))
	return s


def _amplificator():
	s = [
		cub("Amplificator", (0.55, 0.3, 0.5), (0, 0, 0.25), NEGRU),
		cub("Panza amplificator", (0.48, 0.01, 0.32), (0, -0.152, 0.2), p("553e4d")),
		cub("Panou amplificator", (0.5, 0.01, 0.08), (0, -0.152, 0.43), AUR),
	]
	for k in range(6):
		s.append(cilindru("Buton amplificator", 0.01, 0.01, 0.012, (-0.18 + k * 0.07, -0.16, 0.43), NEGRU, laturi=6, rot=(1.5708, 0, 0)))
	return s


def _sabie(lung=0.95):
	"""Katana culcată pe orizontală (mânerul spre -X), originea = garda."""
	return [
		cub("Teaca", (lung * 0.72, 0.03, 0.035), (lung * 0.36, 0, 0), NEGRU),
		cub("Varf teaca", (0.04, 0.03, 0.03), (lung * 0.72 + 0.02, 0, 0.002), AUR),
		cilindru("Garda", 0.04, 0.04, 0.012, (0, 0, 0), AUR, laturi=8, rot=(0, 1.5708, 0)),
		cub("Maner sabie", (lung * 0.26, 0.03, 0.032), (-lung * 0.13, 0, 0), ALB),
	] + [cub("Snur maner", (0.012, 0.034, 0.036), (-0.03 - k * 0.04, 0, 0), NEGRU, rot=(0.4, 0, 0)) for k in range(5)]


def _ceas_mana(cul_bratara):
	"""Ceas de mână culcat pe pernuță, originea = cadranul."""
	return [
		cilindru("Ceas", 0.024, 0.024, 0.012, (0, 0, 0.006), AUR, laturi=10),
		cilindru("Cadran", 0.019, 0.019, 0.004, (0, 0, 0.013), ALB, laturi=10),
		cub("Bratara", (0.028, 0.15, 0.005), (0, 0, 0.003), cul_bratara),
	]


def _inel(cul_piatra):
	return [
		_tor("Inel", 0.013, 0.0035, (0, 0, 0.013), AUR, rot=(1.5708, 0, 0), segmente=10),
		cub("Piatra", (0.009, 0.009, 0.009), (0, 0, 0.03), cul_piatra, rot=(0.785, 0.785, 0)),
	]


def _lant(lung=0.22, cul=AUR, raza=0.006):
	"""Un lanț de aur întins pe postav într-un U (zale = sfere mici), cu medalion."""
	s = []
	n = 13
	for k in range(n):
		u = math.pi * k / (n - 1)
		s.append(sfera("Za", raza, (math.cos(u) * lung / 2, -math.sin(u) * lung * 0.45, raza), cul, segmente=6, inele=3))
	s.append(cub("Medalion", (0.03, 0.03, 0.006), (0, -lung * 0.5, 0.004), cul))
	return s


def _revolver():
	return [
		cub("Teava revolver", (0.16, 0.022, 0.022), (0.08, 0, 0.011), CROM),
		cilindru("Tambur", 0.022, 0.022, 0.045, (-0.01, 0, 0.022), CROM, laturi=6, rot=(0, 1.5708, 0)),
		cub("Maner revolver", (0.04, 0.09, 0.024), (-0.06, -0.04, 0.012), LEMN_DESCHIS, rot=(0, 0, 0.35)),
	]


# ---------------------------------------------------------------------------------------------------------------
# Magazinul
# ---------------------------------------------------------------------------------------------------------------

def amanet(cale):
	"""Parterul vecinului din stânga: pereții (cărămidă afară, lambriu și vopsea înăuntru), podeaua de scânduri, tavanul
	cu plăci și neoane, fațada cu vitrina și firma, tot decorul. Piese: `Amanet`, `Lumini` (firma, neonul „OPEN”, tuburile
	din tavan, ecranele, lampa de pe tejghea), `Geamuri` (vitrina și sticla tejghelei), `Coliziune`."""
	curata()
	r = random.Random(41)
	piese, lumini, geamuri, col = [], [], [], []

	def strange():
		piese[:] = [uneste(piese, "Amanet")]

	# --- podeaua: scânduri late, pe lungime (spre fundul magazinului), în două nuanțe, rosturile între ele
	x = X0
	k = 0
	while x < X1 - 0.001:
		lat = min(0.16, X1 - x)
		piese.append(cub("Scandura", (lat - 0.006, Y1 - Y0, 0.02), (x + lat / 2, (Y0 + Y1) / 2, FL - 0.01),
			LEMN if k % 3 else p("553e4d")))
		x += lat
		k += 1
	piese.append(cub("Rosturi podea", (X1 - X0, Y1 - Y0, 0.02), ((X0 + X1) / 2, (Y0 + Y1) / 2, FL - 0.016), NEGRU))
	piese.append(cub("Sapa", (XE1 - XE0, YE, FL - 0.02), ((XE0 + XE1) / 2, YE / 2, (FL - 0.02) / 2), METAL_INCHIS))
	_cutie_coliziune(col, (XE1 - XE0, YE, FL), ((XE0 + XE1) / 2, YE / 2, FL / 2))
	# pragul ușii
	piese.append(cub("Prag", (USA[1] - USA[0], Y0, 0.02), ((USA[0] + USA[1]) / 2, Y0 / 2, FL + 0.005), METAL))
	strange()

	# --- pereții: fațada (cu golurile vitrinei și ușii), stânga, dreapta, spate; afară cărămidă, înăuntru vopsea + lambriu
	gol_v = (VITRINA[0], VITRINA[1], VITRINA[2], VITRINA[3])
	gol_u = (USA[0], USA[1], 0.0, USA[3])
	perete(piese, "Fatada", "x", XE0, XE1, 0.0, Y0, 0.0, TOP, CARAMIDA, goluri=[gol_v, gol_u])
	perete(col, "Coliziune", "x", XE0, XE1, 0.0, Y0, 0.0, TOP, NEGRU, goluri=[gol_v, (USA[0], USA[1], 0.0, USA[3])])
	for xx0, xx1 in ((XE0, X0), (X1, XE1)):
		piese.append(cub("Perete lateral", (xx1 - xx0, YE - Y0, TOP), ((xx0 + xx1) / 2, (Y0 + YE) / 2, TOP / 2), PERETE))
		_cutie_coliziune(col, (xx1 - xx0, YE - Y0, TOP), ((xx0 + xx1) / 2, (Y0 + YE) / 2, TOP / 2))
	piese.append(cub("Perete spate", (X1 - X0, YE - Y1, TOP), ((X0 + X1) / 2, (Y1 + YE) / 2, TOP / 2), PERETE))
	_cutie_coliziune(col, (X1 - X0, YE - Y1, TOP), ((X0 + X1) / 2, (Y1 + YE) / 2, TOP / 2))
	# tavanul (placa de beton) și plăcile casetate de dedesubt
	piese.append(cub("Tavan", (X1 - X0, Y1 - Y0, TOP - HC), ((X0 + X1) / 2, (Y0 + Y1) / 2, (HC + TOP) / 2), TAVAN))
	_cutie_coliziune(col, (X1 - X0, Y1 - Y0, TOP - HC), ((X0 + X1) / 2, (Y0 + Y1) / 2, (HC + TOP) / 2))
	xx = X0 + 0.6
	while xx < X1:
		piese.append(cub("Profil tavan", (0.025, Y1 - Y0, 0.015), (xx, (Y0 + Y1) / 2, HC - 0.0075), CROM))
		xx += 0.6
	yy = Y0 + 0.6
	while yy < Y1:
		piese.append(cub("Profil tavan", (X1 - X0, 0.025, 0.015), ((X0 + X1) / 2, yy, HC - 0.0076), CROM))
		yy += 0.6
	# două plăci pătate de apă (o țeavă curge de la etaj)
	for px, py in ((X0 + 1.5, Y0 + 2.1), (X0 + 4.5, Y0 + 0.9)):
		piese.append(cub("Pata tavan", (0.5, 0.5, 0.004), (px, py, HC - 0.002), p("a18463") if px < -12 else p("70706e")))
	strange()
	# lambriul (până la 1,1 m), cu șipca de sus și plinta, pe stânga, dreapta și spate
	LH = FL + 1.0
	for nume, dim, loc in (
			("Lambriu", (0.02, Y1 - Y0, LH - FL), (X0 + 0.01, (Y0 + Y1) / 2, (FL + LH) / 2)),
			("Lambriu", (0.02, Y1 - Y0, LH - FL), (X1 - 0.01, (Y0 + Y1) / 2, (FL + LH) / 2)),
			("Lambriu", (X1 - X0 - 0.04, 0.02, LH - FL), ((X0 + X1) / 2, Y1 - 0.01, (FL + LH) / 2))):
		piese.append(cub(nume, dim, loc, LEMN_INCHIS))
	for nume, dim, loc in (
			("Sipca lambriu", (0.04, Y1 - Y0, 0.04), (X0 + 0.02, (Y0 + Y1) / 2, LH)),
			("Sipca lambriu", (0.04, Y1 - Y0, 0.04), (X1 - 0.02, (Y0 + Y1) / 2, LH)),
			("Sipca lambriu", (X1 - X0 - 0.08, 0.04, 0.04), ((X0 + X1) / 2, Y1 - 0.02, LH)),
			("Plinta", (0.035, Y1 - Y0, 0.1), (X0 + 0.0175, (Y0 + Y1) / 2, FL + 0.05)),
			("Plinta", (0.035, Y1 - Y0, 0.1), (X1 - 0.0175, (Y0 + Y1) / 2, FL + 0.05)),
			("Plinta", (X1 - X0 - 0.07, 0.035, 0.1), ((X0 + X1) / 2, Y1 - 0.0175, FL + 0.05))):
		piese.append(cub(nume, dim, loc, LEMN))
	# fațada pe dinăuntru: tencuită (cărămida e doar afară)
	perete(piese, "Fatada interior", "x", X0, X1, Y0, Y0 + 0.012, FL, HC, PERETE, goluri=[gol_v, gol_u])
	strange()

	# --- fațada pe dinafară: rosturile cărămizii, soclul, pervazul, gratiile, firma, copertina mică de deasupra ușii
	for i in range(int(TOP / 0.25)):
		zz = 0.25 * (i + 1)
		# rosturile orizontale, întrerupte la goluri
		for a, b in ((XE0, VITRINA[0]), (VITRINA[1], USA[0]), (USA[1], XE1)):
			piese.append(cub("Rost caramida", (b - a, 0.012, 0.012), ((a + b) / 2, -0.004, zz), MORTAR))
		if zz < VITRINA[2] or zz > VITRINA[3]:
			piese.append(cub("Rost caramida", (VITRINA[1] - VITRINA[0], 0.012, 0.012), ((VITRINA[0] + VITRINA[1]) / 2, -0.004, zz), MORTAR))
		if zz > USA[3]:
			piese.append(cub("Rost caramida", (USA[1] - USA[0], 0.012, 0.012), ((USA[0] + USA[1]) / 2, -0.004, zz), MORTAR))
	piese.append(cub("Soclu", (XE1 - XE0 + 0.02, 0.04, 0.4), ((XE0 + XE1) / 2, -0.015, 0.2), METAL_INCHIS))
	piese.append(cub("Pervaz vitrina", (VITRINA[1] - VITRINA[0] + 0.2, 0.16, 0.06), ((VITRINA[0] + VITRINA[1]) / 2, -0.06, VITRINA[2] - 0.03),
		CROM))
	a, b = VITRINA[0], VITRINA[1]
	piese.append(cub("Rama vitrina", (b - a, 0.06, 0.06), ((a + b) / 2, 0.1, VITRINA[3] - 0.03), METAL_INCHIS))
	for xx in (a + 0.03, (a + b) / 2, b - 0.03):
		piese.append(cub("Rama vitrina", (0.06, 0.06, VITRINA[3] - VITRINA[2]), (xx, 0.1, (VITRINA[2] + VITRINA[3]) / 2), METAL_INCHIS))
	# glafurile golului vitrinei pe dinăuntru (altfel se vede cărămida în grosimea peretelui)
	for dim, loc in (((b - a, Y0 - 0.13, 0.012), ((a + b) / 2, (0.13 + Y0) / 2, VITRINA[2] + 0.006)),
			((b - a, Y0 - 0.13, 0.012), ((a + b) / 2, (0.13 + Y0) / 2, VITRINA[3] - 0.006)),
			((0.012, Y0 - 0.13, VITRINA[3] - VITRINA[2]), (a + 0.006, (0.13 + Y0) / 2, (VITRINA[2] + VITRINA[3]) / 2)),
			((0.012, Y0 - 0.13, VITRINA[3] - VITRINA[2]), (b - 0.006, (0.13 + Y0) / 2, (VITRINA[2] + VITRINA[3]) / 2))):
		piese.append(cub("Glaf", dim, loc, PERETE))
	geamuri.append(cub("Geam vitrina", (VITRINA[1] - VITRINA[0], 0.012, VITRINA[3] - VITRINA[2]),
		((VITRINA[0] + VITRINA[1]) / 2, 0.06, (VITRINA[2] + VITRINA[3]) / 2), GEAM))
	# gratiile de fier din fața vitrinei (cu traversele lor)
	nb = 15
	for i in range(nb):
		xx = VITRINA[0] + 0.1 + i * (VITRINA[1] - VITRINA[0] - 0.2) / (nb - 1)
		piese.append(cilindru("Gratie", 0.012, 0.012, VITRINA[3] - VITRINA[2] + 0.1, (xx, -0.07, (VITRINA[2] + VITRINA[3]) / 2), NEGRU, laturi=6))
	for zz in (VITRINA[2] + 0.15, VITRINA[3] - 0.1):
		piese.append(cub("Traversa gratie", (VITRINA[1] - VITRINA[0], 0.02, 0.04), ((VITRINA[0] + VITRINA[1]) / 2, -0.07, zz), NEGRU))
	# rama ușii
	for xx in (USA[0] - 0.04, USA[1] + 0.04):
		piese.append(cub("Toc usa", (0.08, Y0 + 0.04, USA[3] - FL + 0.04), (xx, Y0 / 2, (FL + USA[3] + 0.04) / 2), METAL_INCHIS))
	piese.append(cub("Toc usa", (USA[1] - USA[0] + 0.16, Y0 + 0.04, 0.08), ((USA[0] + USA[1]) / 2, Y0 / 2, USA[3] + 0.04), METAL_INCHIS))
	# copertina mică de deasupra ușii, verde închis, cu dungi
	ux = (USA[0] + USA[1]) / 2
	piese.append(cub("Copertina", (1.5, 0.75, 0.04), (ux, -0.36, USA[3] + 0.35), VERDE, rot=(-0.35, 0, 0)))
	for k in range(5):
		piese.append(cub("Dunga copertina", (0.1, 0.76, 0.042), (ux - 0.6 + k * 0.3, -0.36, USA[3] + 0.35), ALB, rot=(-0.35, 0, 0)))
	piese.append(cub("Volan copertina", (1.5, 0.02, 0.16), (ux, -0.72, USA[3] + 0.15), VERDE))
	for xx in (ux - 0.7, ux + 0.7):
		piese.append(os_intre("Brat copertina", (xx, -0.01, USA[3] + 0.05), (xx, -0.7, USA[3] + 0.22), 0.01, NEGRU, laturi=4))
	# firma: „JOHNNY'S PAWN” cu litere aurii luminate pe panou negru, „$” verde, „WE BUY GOLD” dedesubt
	fx = (VITRINA[0] + VITRINA[1]) / 2
	piese.append(cub("Firma", (5.0, 0.14, 0.78), (fx, -0.07, 3.02), NEGRU))
	piese.append(cub("Chenar firma", (5.08, 0.12, 0.05), (fx, -0.07, 3.42), AUR))
	piese.append(cub("Chenar firma", (5.08, 0.12, 0.05), (fx, -0.07, 2.62), AUR))
	lumini.append(_text("Litere firma", "JOHNNY'S PAWN", (fx - 0.25, -0.145, 3.08), 0.42, AUR))
	lumini.append(_text("Litere firma", "$", (fx + 2.15, -0.145, 3.02), 0.6, VERDE_DESCHIS))
	piese.append(_text("Scris firma", "LOANS  *  GOLD  *  GUNS  *  GUITARS", (fx - 0.25, -0.145, 2.75), 0.11, ALB))
	for k in range(6):  # becurile mici de pe chenar
		lumini.append(sfera("Bec firma", 0.025, (fx - 2.4 + k * 0.96, -0.14, 3.42), p("a18463"), segmente=6, inele=3))
	# autocolantele de pe geamul vitrinei (pe ambele fețe, doar cea din față se vede)
	for t, xx, m, c in (("WE BUY GOLD", -13.2, 0.13, AUR), ("CASH LOANS", -10.8, 0.12, ALB)):
		piese.append(_text_o_fata("Autocolant", t, (xx, 0.052, 2.2), m, c))
		piese.append(_text_o_fata("Autocolant", t, (xx, 0.068, 2.2), m, c, rot=(1.5708, 0, 3.14159)))
	# neonul „OPEN” din vitrină (rama neagră, literele roșii aprinse), întors spre stradă
	piese.append(cub("Rama neon", (0.62, 0.03, 0.26), (-10.6, 0.2, 1.55), NEGRU))
	lumini.append(_text("Neon open", "OPEN", (-10.6, 0.18, 1.55), 0.16, ROSU))
	# preșul de la intrare
	piese.append(cub("Pres", (1.1, 0.7, 0.012), (ux, Y0 + 0.45, FL + 0.006), NEGRU))
	piese.append(_text("Scris pres", "NO\nLOITERING", (ux, Y0 + 0.45, FL + 0.014), 0.08, ALB, rot=(0, 0, 3.14159)))
	strange()

	# --- vitrina dinăuntru: podiumul cu mochetă roșie, pe el: chitara pe stativ, televizorul, trompeta, „SALE”
	py0, py1, pz = Y0 + 0.02, Y0 + 0.85, FL + 0.45
	piese.append(cub("Podium", (VITRINA[1] - VITRINA[0] - 0.1, py1 - py0, pz - FL), ((VITRINA[0] + VITRINA[1]) / 2, (py0 + py1) / 2, (FL + pz) / 2),
		LEMN_INCHIS))
	piese.append(cub("Mocheta podium", (VITRINA[1] - VITRINA[0] - 0.1, py1 - py0, 0.012), ((VITRINA[0] + VITRINA[1]) / 2, (py0 + py1) / 2, pz + 0.006),
		ROSU))
	_cutie_coliziune(col, (VITRINA[1] - VITRINA[0] - 0.1, py1 - py0, pz - FL), ((VITRINA[0] + VITRINA[1]) / 2, (py0 + py1) / 2, (FL + pz) / 2))
	# chitara roșie pe stativ, întoarsă spre stradă
	piese.append(_obiect(_chitara_electrica(ROSU, ALB), (-13.5, 0.55, pz + 0.3), (0, 0.15, 3.14159)))
	for k in (-1, 1):
		piese.append(os_intre("Stativ", (-13.5, 0.55, pz + 0.12), (-13.5 + 0.12 * k, 0.5, pz), 0.008, NEGRU, laturi=4))
	piese.append(os_intre("Stativ", (-13.5, 0.55, pz + 0.12), (-13.5, 0.7, pz), 0.008, NEGRU, laturi=4))
	piese.append(_obiect(_televizor(0.48), (-12.4, 0.62, pz + 0.012), (0, 0, 3.14159)))
	piese.append(_obiect(_trompeta(), (-11.5, 0.5, pz + 0.06), (0, 0, 2.9)))
	piese.append(_obiect(_boombox(), (-10.6, 0.65, pz + 0.012), (0, 0, 3.14159)))
	for xx, t in ((-12.95, "$40"), (-11.9, "$25"), (-11.1, "$15")):
		piese.append(cub("Eticheta", (0.12, 0.012, 0.07), (xx, 0.42, pz + 0.05), ALB, rot=(0.5, 0, 0)))
		piese.append(_text("Pret", t, (xx, 0.412, pz + 0.05), 0.04, ROSU, rot=(1.5708 + 0.5, 0, 3.14159)))
	piese.append(cub("Carton sale", (0.5, 0.012, 0.3), (-12.0, 0.95, pz + 0.35), AUR, rot=(0, 0, 3.14159)))
	piese.append(_text("Scris sale", "SALE!", (-12.0, 0.94, pz + 0.36), 0.12, ROSU, rot=(1.5708, 0, 0)))
	piese.append(os_intre("Picior carton", (-12.0, 0.96, pz + 0.2), (-12.0, 1.05, pz), 0.008, LEMN, laturi=4))
	strange()

	# --- tejgheaua: dulapul de lemn, vitrina de sticlă cu bijuterii pe postav, blatul de sticlă, clapeta din dreapta
	zc = FL + 0.42
	tm = (TY0 + TY1) / 2
	piese.append(cub("Dulap tejghea", (X1 - X0, TY1 - TY0, zc - FL - 0.08), ((X0 + X1) / 2, tm, (FL + 0.08 + zc) / 2), LEMN))
	piese.append(cub("Plinta tejghea", (X1 - X0, TY1 - TY0 + 0.02, 0.08), ((X0 + X1) / 2, tm, FL + 0.04), LEMN_INCHIS))
	xx = X0 + 0.3
	while xx < X1 - 0.2:
		piese.append(cub("Panou tejghea", (0.44, 0.012, 0.2), (xx, TY0 - 0.006, FL + 0.25), LEMN_INCHIS))
		xx += 0.52
	# părțile de lemn plin: stânga (lângă perete) și dreapta (sub casă), cu blat de lemn
	for a, b in ((X0, SX0), (SX1, CLAPA)):
		piese.append(cub("Tejghea lemn", (b - a, TY1 - TY0, TZ - zc), ((a + b) / 2, tm, (zc + TZ) / 2), LEMN))
		piese.append(cub("Blat lemn", (b - a, TY1 - TY0 + 0.04, 0.04), ((a + b) / 2, tm, TZ + 0.02), LEMN_INCHIS))
	# vitrina de sticlă
	piese.append(cub("Postav vitrina", (SX1 - SX0 - 0.06, TY1 - TY0 - 0.06, 0.02), ((SX0 + SX1) / 2, tm, zc + 0.01), ROSU))
	piese.append(cub("Polita vitrina", (SX1 - SX0 - 0.06, (TY1 - TY0) * 0.45, 0.012), ((SX0 + SX1) / 2, tm + 0.12, zc + 0.27), GEAM))
	geamuri.append(cub("Geam tejghea", (SX1 - SX0 - 0.06, 0.012, TZ - zc - 0.04), ((SX0 + SX1) / 2, TY0 + 0.03, (zc + TZ) / 2 - 0.01), GEAM))
	geamuri.append(cub("Geam tejghea", (SX1 - SX0 - 0.06, TY1 - TY0 - 0.06, 0.012), ((SX0 + SX1) / 2, tm, TZ - 0.006), GEAM))
	for xx in (SX0 + 0.015, (SX0 + SX1) / 2, SX1 - 0.015):
		for yy in (TY0 + 0.015, TY1 - 0.015):
			piese.append(cub("Rama vitrina", (0.03, 0.03, TZ - zc), (xx, yy, (zc + TZ) / 2), CROM))
	for yy in (TY0 + 0.015, TY1 - 0.015):
		piese.append(cub("Rama vitrina", (SX1 - SX0, 0.03, 0.025), ((SX0 + SX1) / 2, yy, TZ + 0.0125), CROM))
	lumini.append(cub("Neon vitrina", (SX1 - SX0 - 0.1, 0.02, 0.012), ((SX0 + SX1) / 2, TY1 - 0.04, TZ - 0.03), ALB))
	# spatele vitrinei (spre Johnny): uși glisante de lemn, cu încuietori
	nu = 4
	lu = (SX1 - SX0 - 0.06) / nu
	for i in range(nu):
		ux = SX0 + 0.03 + lu * (i + 0.5)
		piese.append(cub("Usa glisanta", (lu - 0.01, 0.015, TZ - zc - 0.06), (ux, TY1 - 0.025 - 0.016 * (i % 2), (zc + TZ) / 2 - 0.02), LEMN_INCHIS))
		piese.append(cilindru("Incuietoare", 0.01, 0.01, 0.01, (ux + lu * 0.4 * (1 if i % 2 else -1), TY1 - 0.01 - 0.016 * (i % 2), TZ - 0.1),
			AUR, laturi=6, rot=(1.5708, 0, 0)))
	_cutie_coliziune(col, (X1 - X0, TY1 - TY0, TZ + 0.02 - FL), ((X0 + X1) / 2, tm, (FL + TZ + 0.02) / 2))
	# în vitrină, pe postav: ceasuri pe pernuțe, inele pe un suport, lanțuri, un revolver, un ceas de buzunar, un grillz
	zp = zc + 0.02
	for i, xx in enumerate((-13.95, -13.55, -13.15)):
		piese.append(cub("Pernuta", (0.09, 0.12, 0.05), (xx, tm - 0.05, zp + 0.025), NEGRU))
		piese.append(_obiect(_ceas_mana((AUR, METAL, LEMN_INCHIS)[i]), (xx, tm - 0.05, zp + 0.05), (0.3, 0, 0)))
	piese.append(cub("Suport inele", (0.42, 0.06, 0.05), (-12.55, tm - 0.07, zp + 0.025), NEGRU))
	for k in range(6):
		piese.append(_obiect(_inel((ALB, ROSU, TURCOAZ, ALB, VERDE_DESCHIS, ALB)[k]), (-12.72 + k * 0.07, tm - 0.07, zp + 0.035)))
	for k, xx in enumerate((-11.95, -11.55)):
		piese.append(_obiect(_lant(0.22 - 0.04 * k), (xx, tm + 0.04, zp)))
	piese.append(_obiect(_revolver(), (-10.95, tm - 0.02, zp), (0, 0, 0.3)))
	piese.append(cilindru("Ceas buzunar", 0.03, 0.03, 0.012, (-10.4, tm - 0.04, zp + 0.006), AUR, laturi=10))
	piese.append(cilindru("Cadran", 0.024, 0.024, 0.004, (-10.4, tm - 0.04, zp + 0.013), ALB, laturi=10))
	for k in range(8):
		piese.append(sfera("Za", 0.005, (-10.4 + 0.035 + k * 0.012, tm - 0.04 + math.sin(k * 0.8) * 0.02, zp + 0.005), AUR, segmente=6, inele=3))
	for k in range(6):  # grillz: o dantură de aur
		piese.append(cub("Grillz", (0.014, 0.012, 0.016), (-9.9 + k * 0.016, tm - 0.05 + abs(k - 2.5) * 0.006, zp + 0.008), AUR))
	for xx in (-13.55, -12.55, -11.75, -10.95, -10.4, -9.86):
		piese.append(cub("Pret vitrina", (0.05, 0.03, 0.004), (xx, tm - 0.17, zp + 0.002), ALB))
	# pe polița de sticlă de sus: ceasuri, o brățară, două ceasuri mari de aur
	for k in range(5):
		piese.append(_obiect(_ceas_mana((AUR, METAL, AUR, NEGRU, AUR)[k]), (-14.0 + k * 0.85, tm + 0.12, zc + 0.276), (0, 0, 1.5708)))
	strange()
	# clapeta din dreapta (blatul care se ridică, ușița de dedesubt) și ce e pe tejghea
	piese.append(cub("Clapeta", (X1 - CLAPA, TY1 - TY0 + 0.04, 0.04), ((CLAPA + X1) / 2, tm, TZ + 0.02), LEMN_INCHIS))
	piese.append(cub("Balama clapeta", (0.04, TY1 - TY0, 0.03), (CLAPA + 0.02, tm, TZ + 0.05), CROM))
	piese.append(cub("Usita", (X1 - CLAPA - 0.04, 0.04, TZ - FL - 0.12), ((CLAPA + X1) / 2, tm, (FL + TZ) / 2 - 0.02), LEMN))
	# casa de marcat veche (pe partea de lemn, în dreapta lui Johnny)
	kx, ky = -10.0, tm + 0.04
	piese += [
		cub("Casa marcat", (0.38, 0.36, 0.14), (kx, ky, TZ + 0.11), METAL_INCHIS),
		cub("Casa marcat", (0.36, 0.17, 0.13), (kx, ky + 0.07, TZ + 0.23), METAL_INCHIS, rot=(-0.4, 0, 0)),
		cub("Afisaj casa", (0.2, 0.06, 0.06), (kx, ky + 0.13, TZ + 0.34), NEGRU),
		cub("Sertar casa", (0.36, 0.012, 0.07), (kx, ky - 0.186, TZ + 0.08), METAL),
		cub("Manivela casa", (0.03, 0.03, 0.12), (kx + 0.21, ky + 0.02, TZ + 0.14), CROM, rot=(0, 0.4, 0)),
	]
	lumini.append(cub("Cifre casa", (0.15, 0.008, 0.028), (kx, ky + 0.098, TZ + 0.34), ECRAN))
	for i in range(3):
		for j in range(4):
			piese.append(cub("Tasta", (0.04, 0.035, 0.012), (kx - 0.1 + j * 0.065, ky - 0.13 + i * 0.045, TZ + 0.186), ALB if i else ROSU))
	# lampa de bancher (abajurul verde, becul aprins), cântarul de bijuterii, lupa, clopoțelul, chitanțierul, cana
	lx, ly = -13.4, tm + 0.08
	piese += [
		cilindru("Baza lampa", 0.07, 0.08, 0.025, (lx, ly, TZ + 0.0325), AUR, laturi=10),
		os_intre("Tija lampa", (lx, ly, TZ + 0.04), (lx, ly - 0.02, TZ + 0.32), 0.01, AUR, laturi=6),
		cilindru("Abajur", 0.13, 0.13, 0.08, (lx, ly - 0.04, TZ + 0.34), VERDE, laturi=12, rot=(0, 1.5708, 0), scara=(1, 1, 0.5)),
	]
	lumini.append(cilindru("Bec lampa", 0.02, 0.02, 0.2, (lx, ly - 0.04, TZ + 0.315), AUR, laturi=6, rot=(0, 1.5708, 0)))
	piese += [
		cub("Cantar", (0.16, 0.12, 0.03), (-12.9, tm + 0.05, TZ + 0.015), NEGRU),
		cilindru("Taler cantar", 0.05, 0.05, 0.008, (-12.9, tm + 0.07, TZ + 0.034), CROM, laturi=10),
		cub("Afisaj cantar", (0.06, 0.008, 0.02), (-12.9, tm - 0.012, TZ + 0.02), ECRAN),
		cilindru("Lupa", 0.016, 0.02, 0.03, (-12.55, tm + 0.0, TZ + 0.015), NEGRU, laturi=8),
		cilindru("Clopotel", 0.045, 0.05, 0.03, (-11.0, TY0 + 0.13, TZ + 0.04), AUR, laturi=10),
		sfera("Clopotel", 0.04, (-11.0, TY0 + 0.13, TZ + 0.06), AUR, scara=(1, 1, 0.6), segmente=8, inele=4),
		cub("Chitantier", (0.22, 0.3, 0.02), (-12.2, tm + 0.08, TZ + 0.01), ALB, rot=(0, 0, 0.15)),
		cub("Pix", (0.14, 0.012, 0.012), (-12.15, tm + 0.0, TZ + 0.027), NEGRU, rot=(0, 0, 0.6)),
		cilindru("Cana", 0.04, 0.04, 0.1, (-9.65, TY1 - 0.12, TZ + 0.09), ROSU, laturi=10),
		cilindru("Cafea", 0.035, 0.035, 0.005, (-9.65, TY1 - 0.12, TZ + 0.138), LEMN_INCHIS, laturi=10),
	]
	piese.append(cub("Carton", (0.32, 0.012, 0.17), (-10.6, TY0 + 0.1, TZ + 0.1), ALB, rot=(-0.2, 0, 0)))
	piese.append(_text("Scris carton", "NO REFUNDS\nCASH ONLY", (-10.6, TY0 + 0.09, TZ + 0.103), 0.04, ROSU, rot=(1.5708 - 0.2, 0, 0)))
	piese.append(cub("Picior carton", (0.2, 0.08, 0.012), (-10.6, TY0 + 0.13, TZ + 0.006), ALB))
	strange()

	# --- în spatele tejghelei: scaunul înalt al lui Johnny, dulăpiorul cu monitorul camerelor, seiful, ușa „PRIVATE”
	piese.append(cilindru("Scaun inalt", 0.18, 0.18, 0.06, (-12.75, 5.35, FL + 0.75), ROSU, laturi=10))
	for k in range(4):
		u = k * math.pi / 2 + 0.4
		piese.append(os_intre("Picior scaun", (-12.75 + math.cos(u) * 0.06, 5.35 + math.sin(u) * 0.06, FL + 0.72),
			(-12.75 + math.cos(u) * 0.2, 5.35 + math.sin(u) * 0.2, FL), 0.015, METAL, laturi=4))
	# dulăpiorul de lângă peretele din spate, în dreapta: monitorul alb-negru împărțit în 4, video-ul de înregistrat
	dx0, dx1 = -10.9, -9.2
	piese.append(cub("Dulapior", (dx1 - dx0, 0.5, 0.85), ((dx0 + dx1) / 2, Y1 - 0.25, FL + 0.425), LEMN_INCHIS))
	for k in range(3):
		piese.append(cub("Usa dulapior", (0.5, 0.012, 0.7), (dx0 + 0.3 + k * 0.56, Y1 - 0.506, FL + 0.42), LEMN))
		piese.append(cub("Maner dulapior", (0.012, 0.02, 0.08), (dx0 + 0.5 + k * 0.56, Y1 - 0.52, FL + 0.6), CROM))
	_cutie_coliziune(col, (dx1 - dx0, 0.5, 0.85), ((dx0 + dx1) / 2, Y1 - 0.25, FL + 0.425))
	ecran = []
	piese.append(_obiect(_televizor(0.42, True, ecran), (-10.4, Y1 - 0.3, FL + 0.85)))
	lumini.append(_obiect(ecran, (-10.4, Y1 - 0.3, FL + 0.85)))  # ecranul aprins merge la Lumini
	for k in (0, 1):  # crucea care îl împarte în 4 camere
		piese.append(cub("Grila monitor", (0.012 if k else 0.3, 0.004, 0.2 if k else 0.012), (-10.4 - 0.03, Y1 - 0.3 - 0.2, FL + 0.85 + 0.18), NEGRU))
	piese.append(_obiect(_video(0.42), (-9.7, Y1 - 0.28, FL + 0.85)))
	piese.append(cilindru("Ventilator birou", 0.12, 0.12, 0.03, (-9.6, Y1 - 0.3, FL + 1.12), CROM, laturi=10, rot=(1.5708, 0, 0)))
	piese.append(os_intre("Picior ventilator", (-9.6, Y1 - 0.28, FL + 0.94), (-9.6, Y1 - 0.29, FL + 1.06), 0.012, CROM, laturi=4))
	# seiful mare din colțul din stânga-spate (oțel verde închis, roata, cadranul, „J&M SAFE CO.” auriu)
	sx, sy, sl = -14.15, Y1 - 0.42, 0.95
	piese.append(cub("Seif", (sl, 0.8, 1.35), (sx, sy, FL + 0.675), p("32453b")))
	piese.append(cub("Usa seif", (sl - 0.12, 0.04, 1.2), (sx, sy - 0.42, FL + 0.68), p("2a3c3d")))
	piese.append(cilindru("Cadran seif", 0.08, 0.08, 0.04, (sx - 0.15, sy - 0.46, FL + 0.95), CROM, laturi=12, rot=(1.5708, 0, 0)))
	piese.append(cilindru("Butuc roata", 0.04, 0.04, 0.05, (sx + 0.15, sy - 0.47, FL + 0.7), AUR, laturi=8, rot=(1.5708, 0, 0)))
	for k in range(3):
		u = k * math.tau / 3
		piese.append(os_intre("Spita roata", (sx + 0.15, sy - 0.49, FL + 0.7), (sx + 0.15 + math.cos(u) * 0.14, sy - 0.49, FL + 0.7 + math.sin(u) * 0.14),
			0.012, AUR, laturi=6))
		piese.append(sfera("Bila roata", 0.022, (sx + 0.15 + math.cos(u) * 0.14, sy - 0.49, FL + 0.7 + math.sin(u) * 0.14), AUR, segmente=6, inele=4))
	for zz in (FL + 0.35, FL + 1.05):
		piese.append(cub("Balama seif", (0.05, 0.06, 0.12), (sx + sl / 2 - 0.08, sy - 0.43, zz), CROM))
	piese.append(_text("Scris seif", "J&M SAFE CO.", (sx, sy - 0.445, FL + 1.2), 0.05, AUR))
	_cutie_coliziune(col, (sl, 0.8, 1.35), (sx, sy, FL + 0.675))
	# ușa „PRIVATE” din spate (spre depozit), închisă
	ux0, ux1 = -12.7, -11.75
	piese.append(cub("Usa private", (ux1 - ux0, 0.05, 2.1), ((ux0 + ux1) / 2, Y1 - 0.025, FL + 1.05), LEMN))
	for z0, z1 in ((0.15, 0.95), (1.1, 1.95)):
		piese.append(cub("Panou usa", (ux1 - ux0 - 0.24, 0.012, z1 - z0), ((ux0 + ux1) / 2, Y1 - 0.056, FL + (z0 + z1) / 2), LEMN_INCHIS))
	piese.append(sfera("Clanta", 0.03, (ux1 - 0.1, Y1 - 0.09, FL + 1.0), AUR, segmente=8, inele=5))
	piese.append(cub("Placuta usa", (0.36, 0.012, 0.09), ((ux0 + ux1) / 2, Y1 - 0.06, FL + 1.6), AUR))
	piese.append(_text("Scris usa", "PRIVATE", ((ux0 + ux1) / 2, Y1 - 0.068, FL + 1.6), 0.055, NEGRU))
	for xx in (ux0 - 0.04, ux1 + 0.04):
		piese.append(cub("Toc usa", (0.06, 0.06, 2.16), (xx, Y1 - 0.03, FL + 1.08), LEMN_INCHIS))
	piese.append(cub("Toc usa", (ux1 - ux0 + 0.14, 0.06, 0.06), ((ux0 + ux1) / 2, Y1 - 0.03, FL + 2.13), LEMN_INCHIS))
	strange()

	# --- peretele din spate, deasupra lambriului: panoul perforat cu ce e de vânzare
	bx0, bx1, bz0, bz1 = -11.55, -7.8, FL + 1.12, HC - 0.4
	piese.append(cub("Panou perforat", (bx1 - bx0, 0.02, bz1 - bz0), ((bx0 + bx1) / 2, Y1 - 0.01, (bz0 + bz1) / 2), p("7a7b59")))
	for i in range(int((bx1 - bx0) / 0.15)):
		for j in range(int((bz1 - bz0) / 0.15)):
			if (i * 7 + j * 3) % 4 == 0:
				piese.append(cub("Gaura panou", (0.012, 0.004, 0.012), (bx0 + 0.075 + i * 0.15, Y1 - 0.021, bz0 + 0.075 + j * 0.15), LEMN_INCHIS))
	piese.append(_obiect(_chitara_electrica(TEAL, ALB), (-11.05, Y1 - 0.06, FL + 1.5)))
	piese.append(_obiect(_chitara_electrica(NEGRU, ROSU), (-10.45, Y1 - 0.06, FL + 1.52)))
	piese.append(_obiect(_chitara_acustica(), (-9.8, Y1 - 0.08, FL + 1.55)))
	piese.append(_obiect(_saxofon(), (-9.05, Y1 - 0.08, FL + 1.75)))
	piese.append(_obiect(_trompeta(), (-8.35, Y1 - 0.05, FL + 2.2)))
	piese.append(_obiect(_bormasina(), (-8.4, Y1 - 0.07, FL + 1.55)))
	for xx in (-11.05, -10.45, -9.8, -9.05, -8.35):
		piese.append(cub("Carlig", (0.012, 0.06, 0.012), (xx, Y1 - 0.04, FL + 2.2 if xx > -9 else FL + 2.42), CROM))
	for xx, t in ((-11.05, "$350"), (-10.45, "$280"), (-9.8, "$120"), (-9.05, "$600"), (-8.4, "$45")):
		piese.append(cub("Eticheta", (0.14, 0.012, 0.07), (xx, Y1 - 0.03, FL + 1.18), ALB))
		piese.append(_text("Pret", t, (xx, Y1 - 0.038, FL + 1.18), 0.045, ROSU))
	# deasupra seifului și a ușii: săbiile pe suport, discul de aur înrămat, ceasul de perete
	for k in range(2):
		piese.append(_obiect(_sabie(), (-14.35, Y1 - 0.06, 2.35 + k * 0.16)))
	for xx in (-14.0, -13.4):
		piese.append(cub("Suport sabii", (0.04, 0.05, 0.38), (xx, Y1 - 0.03, 2.43), LEMN_INCHIS))
	piese.append(cub("Rama disc", (0.5, 0.03, 0.6), (-12.95, Y1 - 0.015, 2.62), NEGRU))
	piese.append(cub("Fundal disc", (0.44, 0.01, 0.54), (-12.95, Y1 - 0.034, 2.62), METAL_INCHIS))
	piese.append(cilindru("Disc aur", 0.16, 0.16, 0.008, (-12.95, Y1 - 0.042, 2.67), AUR, laturi=16, rot=(1.5708, 0, 0)))
	piese.append(cilindru("Eticheta disc", 0.05, 0.05, 0.008, (-12.95, Y1 - 0.046, 2.67), ROSU, laturi=10, rot=(1.5708, 0, 0)))
	piese.append(cub("Placuta disc", (0.2, 0.008, 0.04), (-12.95, Y1 - 0.042, 2.42), AUR))
	piese.append(cilindru("Ceas perete", 0.17, 0.17, 0.04, (-12.22, Y1 - 0.02, 2.75), ALB, laturi=14, rot=(1.5708, 0, 0)))
	piese.append(_tor("Rama ceas", 0.17, 0.015, (-12.22, Y1 - 0.04, 2.75), NEGRU, rot=(1.5708, 0, 0), segmente=14))
	piese.append(cub("Limba ceas", (0.012, 0.006, 0.12), (-12.22 + 0.025, Y1 - 0.045, 2.79), NEGRU, rot=(0, 0.5, 0)))
	piese.append(cub("Limba ceas", (0.012, 0.006, 0.08), (-12.22 - 0.03, Y1 - 0.045, 2.73), NEGRU, rot=(0, 2.2, 0)))
	# firma de neon „JOHNNY'S” de deasupra tejghelei, pe peretele din spate (în cursivă de neon: tub roșu pe ramă neagră)
	piese.append(cub("Rama neon", (1.5, 0.03, 0.34), (-10.0, Y1 - 0.016, 2.82), NEGRU))
	lumini.append(_text("Neon johnny", "Johnny's", (-10.0, Y1 - 0.04, 2.84), 0.22, ROSU))
	lumini.append(cub("Neon sublinieri", (1.2, 0.012, 0.015), (-10.0, Y1 - 0.04, 2.7), AUR))
	strange()

	# --- stânga: raftul metalic cu electronice (televizoare, video, console, aparate foto, boxe), cu fața spre +X
	rx = X0 + 0.27
	ry0, ry1 = Y0 + 1.05, TY0 - 0.25
	nivele = (FL + 0.05, FL + 0.55, FL + 1.05, FL + 1.55, FL + 2.05)
	for zz in nivele:
		piese.append(cub("Polita raft", (0.48, ry1 - ry0, 0.025), (rx, (ry0 + ry1) / 2, zz), METAL))
	for yy in (ry0, ry1):
		for xx in (rx - 0.22, rx + 0.22):
			piese.append(cub("Montant raft", (0.035, 0.035, 2.1), (xx, yy, FL + 1.05), METAL_INCHIS))
	_cutie_coliziune(col, (0.5, ry1 - ry0, 2.1), (rx, (ry0 + ry1) / 2, FL + 1.05))
	spre_x = (0, 0, -1.5708)  # obiectele făcute cu fața spre -Y, întoarse cu fața spre +X (spre magazin)
	# jos: două televizoare mari; apoi video-uri și o consolă; apoi aparate foto și un boombox; sus: un televizor mic, cutii
	piese.append(_obiect(_televizor(0.55), (rx, ry0 + 0.35, nivele[0] + 0.0125), spre_x))
	piese.append(_obiect(_televizor(0.5), (rx, ry1 - 0.35, nivele[0] + 0.0125), spre_x))
	for k in range(3):
		piese.append(_obiect(_video(0.38), (rx, ry0 + 0.3 + k * 0.48, nivele[1] + 0.0125), spre_x))
		piese.append(_obiect(_video(0.38), (rx, ry0 + 0.3 + k * 0.48, nivele[1] + 0.1025), spre_x))
	piese.append(_obiect(_consola(), (rx + 0.04, ry0 + 0.4, nivele[2] + 0.0125), spre_x))
	piese.append(_obiect(_consola(), (rx + 0.04, ry0 + 1.0, nivele[2] + 0.0125), (0, 0, -1.4)))
	piese.append(_obiect(_boombox(), (rx, ry1 - 0.4, nivele[2] + 0.0125), spre_x))
	for k in range(4):
		piese.append(_obiect(_aparat_foto(), (rx + 0.05, ry0 + 0.25 + k * 0.38, nivele[3] + 0.0125), (0, 0, -1.5708 + r.uniform(-0.3, 0.3))))
	piese.append(_obiect(_televizor(0.36), (rx, ry0 + 0.4, nivele[4] + 0.0125), spre_x))
	yy = ry0 + 0.8
	while yy < ry1 - 0.2:
		h = r.uniform(0.18, 0.32)
		piese.append(cub("Cutie raft", (0.36, 0.2, h), (rx, yy, nivele[4] + 0.0125 + h / 2), r.choice((ALB, AUR, LEMN_DESCHIS, METAL))))
		yy += 0.25
	for k, zz in enumerate(nivele[:4]):
		piese.append(cub("Eticheta raft", (0.012, 0.08, 0.035), (rx + 0.25, ry0 + 0.3 + k * 0.4, zz - 0.02), ALB))
	# deasupra raftului: afișul „WE BUY GOLD” și „PAWN • BUY • SELL”
	piese.append(cub("Afis", (0.02, 1.4, 0.45), (X0 + 0.01, (ry0 + ry1) / 2, 2.75), AUR))
	piese.append(_text("Scris afis", "WE BUY GOLD", (X0 + 0.025, (ry0 + ry1) / 2, 2.8), 0.14, NEGRU, rot=(1.5708, 0, 1.5708)))
	piese.append(_text("Scris afis", "TOP $$$ PAID", (X0 + 0.025, (ry0 + ry1) / 2, 2.64), 0.07, ROSU, rot=(1.5708, 0, 1.5708)))
	strange()
	# între raft și vitrină: masa cu scule (bormașina, drujba), sacul de golf rezemat
	mx, my = X0 + 0.55, Y0 + 0.62
	piese.append(cub("Masa scule", (0.6, 0.55, 0.04), (mx + 0.1, my, FL + 0.76), LEMN))
	for dx in (-0.17, 0.37):
		for dy in (-0.23, 0.23):
			piese.append(cub("Picior masa", (0.04, 0.04, 0.74), (mx + dx, my + dy, FL + 0.37), LEMN_INCHIS))
	_cutie_coliziune(col, (0.6, 0.55, 0.78), (mx + 0.1, my, FL + 0.39))
	piese.append(_obiect(_drujba(), (mx, my + 0.05, FL + 0.78), (0, 0, 0.6)))
	piese.append(_obiect(_bormasina(), (mx + 0.25, my - 0.12, FL + 0.78), (0, 0, -1.0)))
	piese.append(_obiect(_sac_golf(), (X0 + 0.95, Y0 + 0.25 + 0.8, FL), (0.12, -0.08, 0)))
	_cutie_coliziune(col, (0.3, 0.3, 1.0), (X0 + 0.95, Y0 + 1.05, FL + 0.5))

	# --- în mijloc: turnul de sticlă (vitrină înaltă, pătrată) cu ceasuri, aparate foto și o coroană de jucărie,
	# luminat pe dinăuntru, cu soclu de lemn
	tx, ty, tl = -12.85, 2.05, 0.5
	piese.append(cub("Soclu turn", (tl + 0.04, tl + 0.04, 0.3), (tx, ty, FL + 0.15), LEMN_INCHIS))
	piese.append(cub("Capac turn", (tl + 0.04, tl + 0.04, 0.08), (tx, ty, FL + 1.94), LEMN_INCHIS))
	for dx in (-1, 1):
		for dy in (-1, 1):
			piese.append(cub("Stalp turn", (0.025, 0.025, 1.6), (tx + dx * tl / 2, ty + dy * tl / 2, FL + 1.1), CROM))
	for dim, loc in (((tl, 0.008, 1.6), (tx, ty - tl / 2, FL + 1.1)), ((tl, 0.008, 1.6), (tx, ty + tl / 2, FL + 1.1)),
			((0.008, tl, 1.6), (tx - tl / 2, ty, FL + 1.1)), ((0.008, tl, 1.6), (tx + tl / 2, ty, FL + 1.1))):
		geamuri.append(cub("Geam turn", dim, loc, GEAM))
	for k, zz in enumerate((FL + 0.31, FL + 0.75, FL + 1.2, FL + 1.6)):
		piese.append(cub("Polita turn", (tl - 0.03, tl - 0.03, 0.012), (tx, ty, zz), GEAM if k else LEMN))
	lumini.append(cub("Bec turn", (0.2, 0.2, 0.01), (tx, ty, FL + 1.895), ALB))
	piese.append(_obiect(_aparat_foto(), (tx - 0.1, ty, FL + 0.756), (0, 0, 0.3)))
	piese.append(_obiect(_aparat_foto(), (tx + 0.12, ty + 0.05, FL + 0.756), (0, 0, -0.4)))
	for k in range(3):
		piese.append(_obiect(_ceas_mana((AUR, METAL, NEGRU)[k]), (tx - 0.15 + k * 0.15, ty, FL + 1.21), (0.3, 0, 0)))
	for k in range(5):  # coroana de jucărie (aur, cu „pietre” roșii) sus
		u = k * math.tau / 5
		piese.append(cub("Zimt coroana", (0.04, 0.012, 0.07), (tx + math.cos(u) * 0.07, ty + math.sin(u) * 0.07, FL + 1.68), AUR,
			rot=(0, 0, u + 1.5708)))
	piese.append(_tor("Coroana", 0.075, 0.015, (tx, ty, FL + 1.63), AUR, segmente=10))
	piese.append(sfera("Piatra coroana", 0.015, (tx, ty - 0.085, FL + 1.64), ROSU, segmente=6, inele=3))
	piese.append(cub("Eticheta", (0.12, 0.012, 0.06), (tx, ty - tl / 2 - 0.006, FL + 0.22), ALB))
	piese.append(_text("Pret", "ASK", (tx, ty - tl / 2 - 0.014, FL + 0.22), 0.04, ROSU))
	_cutie_coliziune(col, (tl + 0.04, tl + 0.04, 1.98), (tx, ty, FL + 0.99))
	strange()

	# --- dreapta (între ușă și tejghea): bicicleta agățată sus, două chitare pe perete, amplificatorul cu o tobă
	wx = X1 - 0.02
	piese.append(_obiect(_bicicleta(), (wx - 0.12, 2.2, 2.55), (0, 0, 1.5708)))
	for yy in (1.85, 2.55):
		piese.append(cub("Carlig bicicleta", (0.14, 0.02, 0.02), (wx - 0.07, yy, 2.85), CROM))
	piese.append(_obiect(_chitara_electrica(p("a18463"), NEGRU), (wx - 0.05, 1.75, FL + 1.35), (0, 0, 1.5708)))
	piese.append(_obiect(_chitara_electrica(MOV, ALB), (wx - 0.05, 2.35, FL + 1.37), (0, 0, 1.5708)))
	piese.append(_obiect(_chitara_acustica(), (wx - 0.06, 2.95, FL + 1.35), (0, 0, 1.5708)))
	for yy in (1.75, 2.35, 2.95):
		piese.append(cub("Suport chitara", (0.08, 0.06, 0.03), (wx - 0.04, yy, FL + 2.17 if yy != 2.95 else FL + 2.25), NEGRU))
	piese.append(_obiect(_amplificator(), (wx - 0.2, 2.25, FL), (0, 0, 1.5708)))
	_cutie_coliziune(col, (0.34, 0.6, 0.55), (wx - 0.18, 2.25, FL + 0.27))
	piese.append(cilindru("Toba", 0.17, 0.17, 0.14, (wx - 0.2, 2.25, FL + 0.57), ALB, laturi=12))
	piese.append(cilindru("Cerc toba", 0.175, 0.175, 0.02, (wx - 0.2, 2.25, FL + 0.64), CROM, laturi=12))
	piese.append(cilindru("Cerc toba", 0.175, 0.175, 0.02, (wx - 0.2, 2.25, FL + 0.5), CROM, laturi=12))
	for k in (-1, 1):
		piese.append(os_intre("Bat toba", (wx - 0.2 + 0.05 * k, 2.15, FL + 0.66), (wx - 0.2 + 0.12 * k, 2.4, FL + 0.66), 0.006, LEMN_DESCHIS, laturi=4))
	# afișele de pe peretele din dreapta și de pe fațadă (citite dinăuntru)
	piese.append(cub("Afis", (0.02, 0.7, 0.45), (X1 - 0.01, 3.25, 1.95), ALB))
	piese.append(_text("Scris afis", "ALL SALES\nFINAL", (X1 - 0.025, 3.25, 1.95), 0.08, ROSU, rot=(1.5708, 0, -1.5708)))
	piese.append(cub("Afis", (0.6, 0.02, 0.35), (-8.2, Y0 + 0.02, 2.75), AUR))
	piese.append(_text("Scris afis", "SMILE!\nYOU'RE ON CAMERA", (-8.2, Y0 + 0.035, 2.75), 0.05, NEGRU, rot=(1.5708, 0, 3.14159)))
	strange()

	# --- tavanul: două corpuri de neon (carcasa, două tuburi), camera de supraveghere din colț
	for nx, ny in ((-12.6, 2.1), (-10.0, 2.1), (-11.3, 5.2)):
		piese.append(cub("Carcasa neon", (1.3, 0.3, 0.06), (nx, ny, HC - 0.03), CROM))
		for k in (-1, 1):
			lumini.append(cilindru("Tub neon", 0.018, 0.018, 1.2, (nx, ny + 0.07 * k, HC - 0.075), ALB, laturi=6, rot=(0, 1.5708, 0)))
	cx, cy, cz = X1 - 0.15, Y0 + 0.15, HC - 0.05
	piese += [
		cub("Suport camera", (0.06, 0.06, 0.1), (cx, cy, cz), METAL_INCHIS),
		cub("Camera", (0.1, 0.22, 0.09), (cx - 0.05, cy + 0.08, cz - 0.1), ALB, rot=(-0.5, 0, 0.6)),
		cilindru("Obiectiv camera", 0.025, 0.025, 0.02, (cx - 0.11, cy + 0.17, cz - 0.15), NEGRU, laturi=8, rot=(1.0, 0, 0.6)),
	]
	lumini.append(sfera("Led camera", 0.008, (cx - 0.02, cy + 0.04, cz - 0.08), ROSU, segmente=4, inele=3))
	# coșul de gunoi lângă tejghea, cu hârtii
	piese.append(cilindru("Cos gunoi", 0.14, 0.12, 0.38, (X1 - 0.3, TY0 - 0.3, FL + 0.19), METAL_INCHIS, laturi=8))
	piese.append(sfera("Hartie", 0.05, (X1 - 0.3, TY0 - 0.28, FL + 0.38), ALB, segmente=5, inele=3))

	uneste(piese, "Amanet")
	uneste(lumini, "Lumini")
	uneste(geamuri, "Geamuri")
	uneste(col, "Coliziune")
	exporta(os.path.join(cale, "amanet.glb"))


def usa(cale):
	"""Ușa amanetului (`usa_amanet`, 1,0 × 2,25 m): cadru de oțel, geam cu plasă de fier peste el, bara de împins,
	„PULL” / „PUSH”, clopoțelul de deasupra (pe toc, nu pe ușă). Originea = balamaua (jos); se întinde spre +X; afară e -Y."""
	curata()
	lw, lh = USA[1] - USA[0], USA[3] - USA[2]
	piese = [
		cub("Rama", (0.08, 0.05, lh), (0.04, 0, lh / 2), METAL_INCHIS),
		cub("Rama", (0.08, 0.05, lh), (lw - 0.04, 0, lh / 2), METAL_INCHIS),
		cub("Rama", (lw, 0.05, 0.1), (lw / 2, 0, lh - 0.05), METAL_INCHIS),
		cub("Rama", (lw, 0.05, 0.5), (lw / 2, 0, 0.25), METAL_INCHIS),
		cub("Placa lovituri", (lw - 0.16, 0.012, 0.3), (lw / 2, -0.03, 0.2), CROM),
	]
	# grilajul de fier de pe fața de afară a geamului: bare verticale și trei traverse
	for k in range(6):
		piese.append(cub("Grilaj", (0.014, 0.014, lh - 0.6), (0.18 + k * (lw - 0.36) / 5, -0.034, 0.5 + (lh - 0.6) / 2), NEGRU))
	for zz in (0.75, 1.35, lh - 0.3):
		piese.append(cub("Grilaj", (lw - 0.16, 0.014, 0.025), (lw / 2, -0.034, zz), NEGRU))
	for s in (-1, 1):
		piese.append(cilindru("Bara", 0.018, 0.018, lw - 0.24, (lw / 2, s * 0.075, 1.05), CROM, laturi=6, rot=(0, 1.5708, 0)))
		for xx in (0.17, lw - 0.17):
			piese.append(cub("Suport bara", (0.03, 0.06, 0.03), (xx, s * 0.05, 1.05), CROM))
	piese.append(cub("Autocolant usa", (0.24, 0.006, 0.07), (lw / 2, -0.028, 1.25), ALB))
	piese.append(_text_o_fata("Scris usa", "PUSH", (lw / 2, -0.032, 1.25), 0.05, ROSU))
	piese.append(cub("Autocolant usa", (0.24, 0.006, 0.07), (lw / 2, 0.028, 1.25), ALB))
	piese.append(_text_o_fata("Scris usa", "PULL", (lw / 2, 0.032, 1.25), 0.05, ROSU, rot=(1.5708, 0, 3.14159)))
	piese.append(cub("Program", (0.22, 0.006, 0.14), (lw - 0.25, -0.03, 1.55), ALB))
	piese.append(_text_o_fata("Scris program", "MON-SAT\n10-8", (lw - 0.25, -0.034, 1.55), 0.03, NEGRU))
	ob = uneste(piese, "Usa")
	g = uneste([cub("Geam", (lw - 0.16, 0.012, lh - 0.6), (lw / 2, 0, 0.5 + (lh - 0.6) / 2), GEAM)], "GeamUsa")
	_parinte(g, ob)
	exporta(os.path.join(cale, "usa_amanet.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Johnny: proprietarul, în picioare după tejghea, cu palmele pe blat
# ---------------------------------------------------------------------------------------------------------------

JOHNNY = {
	"piele": p("a56850"), "piele_umbra": p("904a40"),
	# cămașă hawaiiană cu mânecă scurtă (teal cu flori), descheiată la gât, lanț gros de aur pe piept
	"haina": TEAL, "haina_umbra": p("30716f"), "camasa": TEAL, "stil_haina": "hawaiana", "maneca_scurta": True,
	"flori": (p("a18463"), p("7b383a"), p("83b3b0"), p("904a40")), "frunze": p("5b6d4e"),
	"pantaloni": p("5e5356"), "pantofi": p("262d2f"), "curea": p("262d2f"),
	"in_picioare": True, "sezut": 0.86, "masa": TZ - FL, "burta": 0.7, "gras": 0.45, "gros_brat": 1.12,
	# chel, cu părul tuns scurt pe laterale, cioc și mustață, lupa de bijutier ridicată pe frunte
	"par": p("262d2f"), "stil_par": "chel", "mustata": p("262d2f"), "barbison": p("262d2f"), "tepi": p("48313b"),
	"lupa": True, "incruntat": 0.18, "riduri": True, "nas": 1.2, "spranceana": 0.006,
	"lant": AUR, "medalion": True, "inele": AUR, "ceas": AUR, "par_piept": p("48313b"),
	# palmele pe marginea din spate a tejghelei (el stă la 0,32 m în spatele ei)
	"poza_D": ((-0.28, -0.08, 1.15), (-0.17, -0.34, TZ - FL + 0.025)),
	"poza_S": ((0.28, -0.08, 1.15), (0.17, -0.34, TZ - FL + 0.025)),
}


def johnny(cale):
	casino_oameni.om(cale, "johnny", JOHNNY, 88)


def toate(cale):
	amanet(cale)
	usa(cale)
	johnny(cale)


if __name__ == "__main__":
	cale_modele = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")
	if "--" in sys.argv:
		for nume in sys.argv[sys.argv.index("--") + 1:]:
			globals()[nume](cale_modele)
	else:
		toate(cale_modele)
