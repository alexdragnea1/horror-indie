# Înăuntrul conacului coven-ului (conac_interior.tscn) și cine e acolo: living room-ul gotic cu scara dublă și
# galeria, cele două camere de la etaj (Helga în dreapta), vrăjitoarele care stau la povești, Helga, manechinul de
# antrenament și mâna ta (vraja Fireball, la persoana întâi).
# Le apelează modele.py, dar merge și singur (mai repede, doar astea):
#   blender --background --factory-startup --python tools/blender/conac_interior.py
#   blender --background --factory-startup --python tools/blender/conac_interior.py -- helga manechin
# Axe Blender: Z în sus, fața modelului spre -Y (în Godot devine +Z). Originea = la sol.
# Interiorul: ușa de la intrare e la y = 0 (peretele din față), sala se întinde spre +Y (în Godot spre -Z).
import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, inel, linie, uneste, exporta, trunchi  # noqa: E402
from lexy import prisma, _copii, _dovleac  # noqa: E402
from conac import _pentagon, _roteste  # noqa: E402
from coven import CERC, _cap, _corp, _maneca, _mana, _lerp, _parinte, _inel_vertical  # noqa: E402

NEGRU = p("262d2f")
OS = p("83b3b0")
AUR = p("a18463")
AUR_INCHIS = p("a56850")
ROSU = p("7b383a")
ROSU_INCHIS = p("5e363e")
VISINIU = p("553e4d")
MOV = p("655269")
LEMN = p("48313b")
LEMN_DESCHIS = p("5e363e")
PIATRA = p("6f6d7f")
PIATRA_INCHISA = p("5e5356")
GRI = p("70706e")
VERDE = p("32453b")
VERDE_DESCHIS = p("445d46")
TEAL = p("295555")
TEAL_DESCHIS = p("438b88")
GEAM_NOAPTE = p("2a3c3d")
FLACARA = p("a18463")
FLACARA_PORTOCALIE = p("a56850")
PANZA = p("7a7b59")


# ---------------------------------------------------------------------------------------------------------------
# Unelte
# ---------------------------------------------------------------------------------------------------------------

def _muta(obiecte, rot=(0, 0, 0), loc=(0, 0, 0)):
	"""Rotește (Euler XYZ, în jurul originii) și mută piesele deja făcute (vârfurile lor sunt în coordonatele lumii)."""
	m = Matrix.Translation(Vector(loc)) @ Matrix.Rotation(rot[2], 4, 'Z') @ Matrix.Rotation(rot[1], 4, 'Y') @ \
		Matrix.Rotation(rot[0], 4, 'X')
	for ob in obiecte:
		ob.data.transform(m)
		ob.data.update()
	return obiecte


def _punct(nume, loc, parinte):
	"""Un punct gol (Empty) legat de `parinte`: în Godot devine un Node3D cu numele ăsta (ex. `Palma`)."""
	ob = bpy.data.objects.new(nume, None)
	bpy.context.scene.collection.objects.link(ob)
	ob.location = loc
	bpy.context.view_layer.update()
	_parinte(ob, parinte)
	return ob


def _norm(v):
	l = math.sqrt(sum(x * x for x in v))
	return tuple(x / l for x in v)


def _pahar(piese, baza, culoare=AUR, vin=ROSU):
	"""Pocal: talpă, picior, cupa (cu vin roșu, la 1 cm sub buză)."""
	x, y, z = baza
	piese += [
		cilindru("Talpa pahar", 0.03, 0.026, 0.008, (x, y, z + 0.004), culoare, laturi=8),
		cilindru("Picior pahar", 0.007, 0.007, 0.07, (x, y, z + 0.043), culoare, laturi=5),
		cilindru("Cupa", 0.014, 0.04, 0.06, (x, y, z + 0.108), culoare, laturi=8),
		cilindru("Vin", 0.034, 0.034, 0.004, (x, y, z + 0.124), vin, laturi=8),
	]


# ---------------------------------------------------------------------------------------------------------------
# Vrăjitoarele din living room
# ---------------------------------------------------------------------------------------------------------------

# Hainele de „seară”: aceleași fețe ca vrăjitoarele din cerc, dar drepte (nu se apleacă peste cazan).
SALON = [
	(dict(CERC[0], cocoasa=0.03), True),
	(dict(CERC[1], cocoasa=0.06, roba=p("655269"), pelerina=p("553e4d")), False),
	(dict(CERC[2], roba=p("7b383a"), roba_umbra=p("5e363e"), pelerina=p("48313b"), banda=p("a18463")), True),
	(dict(CERC[3], roba=p("2a3c3d"), pelerina=p("295555"), par=p("904a40"), par_suvita=p("a56850")), True),
]


def vrajitoare_salon(cale, nume, s, saminta, pahar):
	"""O vrăjitoare care stă la povești în living room: dreaptă, cu brațul drept pe lângă corp (`BratDrept`, originea
	în umăr: gesticulează când vorbește), iar cu stângul ține un pocal cu vin (`BratStang`, originea în umăr) sau
	își ține mâna în șold (atunci brațul e în `Corp`). `Cap` (originea în gât) cu `Ochi`."""
	curata()
	r = random.Random(saminta)
	s = dict(s, aplecare=0.0)
	h = s["inaltime"]
	piese = []
	z_umar, _ = _corp(piese, s, r, h)
	if not pahar:
		umar, cot, inch = (0.21, 0.0, z_umar), (0.36, 0.05, z_umar - 0.25), (0.21, -0.03, z_umar - 0.42)
		_maneca(piese, umar, cot, inch, s["roba"], s["roba_umbra"])
		_mana(piese, _lerp(cot, inch, 1.02), (-0.6, -0.1, -0.79), (0.0, -1.0, 0.0), s["piele"], NEGRU, r, deschisa=False)
	uneste(piese, "Corp")

	umar, cot, inch = (-0.21, 0.0, z_umar), (-0.25, 0.02, z_umar - 0.28), (-0.235, -0.04, z_umar - 0.53)
	brat = []
	_maneca(brat, umar, cot, inch, s["roba"], s["roba_umbra"])
	_mana(brat, _lerp(cot, inch, 1.02), (0.06, -0.15, -0.99), (0.9, -0.3, 0.0), s["piele"], NEGRU, r)
	uneste(brat, "BratDrept", umar)

	if pahar:
		umar, cot, inch = (0.21, 0.0, z_umar), (0.27, 0.04, z_umar - 0.27), (0.17, -0.2, z_umar - 0.36)
		brat = []
		_maneca(brat, umar, cot, inch, s["roba"], s["roba_umbra"])
		d = _norm([b - a for a, b in zip(cot, inch)])
		incheietura = _lerp(cot, inch, 1.02)
		_mana(brat, incheietura, d, (-1.0, 0.0, 0.0), s["piele"], NEGRU, r, deschisa=False)
		palma = tuple(incheietura[i] + d[i] * 0.045 for i in range(3))
		_pahar(brat, (palma[0], palma[1] - 0.01, palma[2] - 0.05), AUR if saminta % 2 else PIATRA)
		uneste(brat, "BratStang", umar)

	cap, ochi = [], []
	_cap(cap, ochi, (0, -0.02, (1.445 + 0.03) * h), s, r)
	ob_cap = uneste(cap, "Cap", (0, -0.02, 1.445 * h))
	_parinte(uneste(ochi, "Ochi", (0, -0.1, 1.6 * h)), ob_cap)
	exporta(os.path.join(cale, nume + ".glb"))


# ---------------------------------------------------------------------------------------------------------------
# Helga
# ---------------------------------------------------------------------------------------------------------------

HELGA = dict(piele=p("70706e"), piele_umbra=p("5e5356"), roba=p("262d2f"), roba_umbra=p("2a3c3d"), pelerina=p("2a3c3d"),
	par=p("7e8d87"), par_suvita=p("83b3b0"), palarie=None, banda=p("7b383a"), ochi=p("438b88"), brau=p("48313b"),
	cocoasa=0.0, nas=0.85, inaltime=1.1, coc=True, ochelari=p("a18463"))


def helga(cale):
	"""Helga, profesoara de vrăji: înaltă și foarte dreaptă, rochie neagră până în pământ cu guler înalt de dantelă și
	o broșă roșie, păr cărunt strâns în coc, ochelari rotunzi cu ramă de aur, fără pălărie (e în casă). Cu mâna stângă
	ține o carte de vrăji la piept. Piese separate: `Cap` (originea în gât) cu `Ochi`, `BratDrept` (originea în umăr,
	atârnă pe lângă corp; cu el aruncă mingea de foc) și în el punctul `Palma` (de acolo pornește focul)."""
	curata()
	r = random.Random(1888)
	s = HELGA
	h = s["inaltime"]
	piese = []
	z_umar, _ = _corp(piese, s, r, h)
	# gulerul înalt de dantelă, evazat, și broșa
	piese.append(trunchi("Guler", [((0, 0.0, 1.405 * h), 0.07, 0.062), ((0, 0.0, 1.46 * h), 0.068, 0.062),
		((0, 0.008, 1.52 * h), 0.09, 0.082)], OS, laturi=10, capete=False))
	for k in range(10):
		u = k * math.tau / 10
		piese.append(cub("Dantela", (0.03, 0.006, 0.022), (math.cos(u) * 0.094, 0.008 + math.sin(u) * 0.086, 1.515 * h), OS,
			rot=(0, 0, u + math.pi / 2)))
	piese += [
		cilindru("Rama brosa", 0.03, 0.03, 0.01, (0, -0.088, 1.385 * h), AUR, laturi=8, rot=(math.pi / 2, 0, 0)),
		cilindru("Brosa", 0.022, 0.018, 0.012, (0, -0.098, 1.385 * h), ROSU, laturi=8, rot=(math.pi / 2, 0, 0)),
	]
	# brațul stâng ține cartea la piept
	umar, cot, inch = (0.21, 0.0, z_umar), (0.25, -0.05, z_umar - 0.27), (0.04, -0.21, z_umar - 0.22)
	_maneca(piese, umar, cot, inch, s["roba"], s["roba_umbra"])
	d = _norm([b - a for a, b in zip(cot, inch)])
	_mana(piese, _lerp(cot, inch, 1.02), d, (0.0, 0.0, 1.0), s["piele"], NEGRU, r, deschisa=False)
	carte = [
		cub("Coperta", (0.17, 0.008, 0.24), (0, -0.017, 0), ROSU),
		cub("Coperta", (0.17, 0.008, 0.24), (0, 0.017, 0), ROSU),
		cub("Cotor", (0.012, 0.042, 0.24), (-0.085, 0, 0), ROSU_INCHIS),
		cub("Pagini", (0.158, 0.026, 0.226), (0.004, 0, 0), OS),
		cilindru("Pentagrama carte", 0.04, 0.04, 0.004, (0.0, -0.023, 0.02), AUR, laturi=5, rot=(math.pi / 2, 0, 0)),
	]
	_muta(carte, (0.12, 0.0, -0.35), (0.09, -0.24, z_umar - 0.22))
	piese += carte
	uneste(piese, "Corp")

	umar, cot, inch = (-0.21, 0.0, z_umar), (-0.25, 0.02, z_umar - 0.28), (-0.235, -0.04, z_umar - 0.53)
	brat = []
	_maneca(brat, umar, cot, inch, s["roba"], s["roba_umbra"])
	directie = _norm((0.06, -0.15, -0.99))
	incheietura = _lerp(cot, inch, 1.02)
	_mana(brat, incheietura, directie, (0.9, -0.3, 0.0), s["piele"], NEGRU, r)
	ob_brat = uneste(brat, "BratDrept", umar)
	_punct("Palma", tuple(incheietura[i] + directie[i] * 0.06 for i in range(3)), ob_brat)

	cap, ochi = [], []
	_cap(cap, ochi, (0, -0.02, 1.475 * h), s, r)
	ob_cap = uneste(cap, "Cap", (0, -0.02, 1.445 * h))
	_parinte(uneste(ochi, "Ochi", (0, -0.1, 1.6 * h)), ob_cap)
	exporta(os.path.join(cale, "helga.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Manechinul de antrenament și mâna ta
# ---------------------------------------------------------------------------------------------------------------

def _fata_dovleac(lumini, x, y, z, raza):
	"""Fața tăiată a unui dovleac de Halloween care luminează pe dinăuntru (în `lumini`): doi ochi triunghiulari, nasul și
	gura cu dinți, la 1 cm în fața dovleacului (fața spre -Y)."""
	ff = y - raza * 1.0 - 0.012
	k = raza / 0.2
	for sx in (-1, 1):
		lumini.append(prisma("Ochi dovleac", [(x + sx * 0.035 * k, z + 0.17 * k), (x + sx * 0.1 * k, z + 0.17 * k),
			(x + sx * 0.07 * k, z + 0.23 * k)], "xz", ff, ff + 0.01, FLACARA))
	lumini.append(prisma("Nas dovleac", [(x - 0.018 * k, z + 0.12 * k), (x + 0.018 * k, z + 0.12 * k), (x, z + 0.155 * k)],
		"xz", ff, ff + 0.01, FLACARA))
	lumini.append(prisma("Gura dovleac", [(x - 0.11 * k, z + 0.08 * k), (x - 0.05 * k, z + 0.04 * k), (x + 0.05 * k, z + 0.04 * k),
		(x + 0.11 * k, z + 0.08 * k), (x + 0.03 * k, z + 0.065 * k), (x, z + 0.085 * k), (x - 0.03 * k, z + 0.065 * k)],
		"xz", ff, ff + 0.01, FLACARA_PORTOCALIE))


def manechin(cale):
	"""Manechinul de antrenament din camera lui Helga: picioare de lemn în cruce, un stâlp, trunchiul din sac de pânză
	legat cu sfoară (cârpit, cu paie care ies pe la cusături), brațele dintr-o bară cu smocuri de paie, ținta pictată
	pe piept și un dovleac de Halloween în loc de cap (fața luminează: `Lumini`). Piese: `Baza` (picioarele) și
	`Corp` (restul, originea jos pe stâlp: se clatină când îl lovești), cu `Lumini` legat de el."""
	curata()
	r = random.Random(31)
	baza = [
		cub("Picior", (0.9, 0.1, 0.08), (0, 0, 0.04), LEMN_DESCHIS),
		cub("Picior", (0.1, 0.9, 0.08), (0, 0, 0.04), LEMN_DESCHIS),
		cub("Bloc", (0.2, 0.2, 0.12), (0, 0, 0.14), LEMN),
	]
	for sx, sy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
		baza.append(os_intre("Proptea", (sx * 0.32, sy * 0.32, 0.08), (sx * 0.06, sy * 0.06, 0.32), 0.022, LEMN, laturi=4))
	uneste(baza, "Baza")
	corp, lumini = [], []
	corp.append(cilindru("Stalp", 0.045, 0.04, 1.6, (0, 0, 0.9), LEMN_DESCHIS, laturi=6))
	# trunchiul: sac umplut cu paie, mai lat la umeri
	corp.append(trunchi("Sac", [((0, 0, 0.82), 0.12, 0.1), ((0, 0, 0.9), 0.19, 0.14), ((0, 0, 1.15), 0.2, 0.15),
		((0, 0, 1.38), 0.23, 0.15), ((0, 0, 1.47), 0.14, 0.11), ((0, 0, 1.5), 0.05, 0.05)], PANZA, laturi=10))
	for z, rx, ry in ((0.93, 0.192, 0.142), (1.4, 0.226, 0.152)):
		corp.append(trunchi("Sfoara", [((0, 0, z - 0.012), rx + 0.012, ry + 0.012), ((0, 0, z + 0.012), rx + 0.012, ry + 0.012)],
			LEMN, laturi=10))
	corp += [
		cub("Petec", (0.1, 0.012, 0.09), (0.1, 0.148, 1.05), p("5b6d4e"), rot=(0, 0.2, 0)),
		cub("Petec", (0.012, 0.08, 0.1), (0.2, 0.0, 1.22), p("655269"), rot=(0, 0.15, 0)),
	]
	# brațele: o bară prin sac, cu smocuri de paie la capete
	corp.append(cilindru("Bara", 0.03, 0.03, 0.95, (0, 0, 1.33), LEMN_DESCHIS, laturi=6, rot=(0, math.pi / 2, 0)))
	for sx in (-1, 1):
		for k in range(5):
			u = k * math.tau / 5
			corp.append(cilindru("Paie", 0.03, 0.0, 0.16, (sx * (0.5 + 0.06), math.cos(u) * 0.025, 1.33 + math.sin(u) * 0.025), AUR,
				laturi=4, rot=(u * 0.3, sx * (math.pi / 2 + 0.3 * math.sin(u)), 0)))
	for k in range(9):  # paie care ies pe la cusături
		u = r.uniform(0, math.tau)
		z = r.uniform(0.95, 1.4)
		corp.append(cilindru("Paie", 0.006, 0.0, 0.08, (math.cos(u) * 0.2, math.sin(u) * 0.15, z), AUR, laturi=3,
			rot=(r.uniform(-1, 1), r.uniform(-1, 1), u)))
	# ținta pictată pe piept: cercuri de pânză cusute, fiecare cu 1 cm peste cel de dedesubt
	y = -0.152
	for k, (raza, culoare) in enumerate(((0.13, OS), (0.1, ROSU), (0.07, OS), (0.04, ROSU))):
		corp.append(cilindru("Tinta", raza, raza, 0.01, (0, y - 0.005 - k * 0.01, 1.18), culoare, laturi=14, rot=(math.pi / 2, 0, 0)))
	# capul: dovleac de Halloween pe un gât de sfoară
	corp.append(cilindru("Gat", 0.035, 0.045, 0.12, (0, 0, 1.55), LEMN, laturi=6))
	_dovleac(corp, 0, 0, 1.56, 0.17, r)
	_fata_dovleac(lumini, 0, 0, 1.56, 0.17)
	ob_corp = uneste(corp, "Corp", (0, 0, 0.12))
	_parinte(uneste(lumini, "Lumini", (0, 0, 0.12)), ob_corp)
	exporta(os.path.join(cale, "manechin.glb"))


def mana_jucator(cale):
	"""Mâna ta dreaptă la persoana întâi (vraja Fireball): palma în sus, degetele spre înainte (-Y) puțin îndoite,
	degetul mare în dreapta, antebrațul vine din dreapta-jos, cu mâneca neagră a hanoracului și manșeta. Originea =
	mijlocul palmei (acolo stă focul)."""
	curata()
	piele, umbra = p("a56850"), p("904a40")
	piese = [
		sfera("Palma", 0.048, (0, 0.005, -0.004), piele, scara=(1.0, 1.1, 0.38), segmente=10, inele=6),
		sfera("Podul palmei", 0.03, (0.018, 0.035, -0.006), piele, scara=(1.0, 1.0, 0.6), segmente=8, inele=5),
		trunchi("Antebrat", [((0.0, 0.05, -0.012), 0.032, 0.022), ((0.02, 0.16, -0.06), 0.038, 0.028), ((0.05, 0.32, -0.13), 0.042, 0.032)],
			piele, laturi=8),
		trunchi("Maneca", [((0.012, 0.12, -0.044), 0.05, 0.042), ((0.03, 0.22, -0.088), 0.056, 0.048), ((0.06, 0.38, -0.16), 0.062, 0.054)],
			NEGRU, laturi=8),
		trunchi("Manseta", [((0.011, 0.108, -0.04), 0.053, 0.045), ((0.014, 0.13, -0.05), 0.053, 0.045)], LEMN, laturi=8),
	]
	for k, x in enumerate((0.022, 0.006, -0.01, -0.025)):
		lung = (0.075, 0.085, 0.08, 0.062)[k]
		baza = (x, -0.035, 0.0)
		mij = (x * 1.05, -0.035 - lung * 0.55, 0.012)
		varf = (x * 1.1, -0.035 - lung, 0.03)
		piese.append(trunchi("Deget", [(baza, 0.0105, 0.009), (mij, 0.0095, 0.008), (varf, 0.008, 0.007)], piele, laturi=5))
		piese.append(sfera("Varf deget", 0.008, varf, piele, segmente=5, inele=3))
		piese.append(cub("Unghie", (0.012, 0.008, 0.003), (varf[0], varf[1] + 0.002, varf[2] + 0.007), umbra, rot=(-0.6, 0, 0)))
	piese.append(trunchi("Deget mare", [((0.04, 0.02, -0.004), 0.013, 0.011), ((0.062, -0.012, 0.006), 0.011, 0.009),
		((0.074, -0.042, 0.018), 0.009, 0.008)], piele, laturi=5))
	ob = uneste(piese, "Mana")
	# făcută cu degetele spre -Y (în Godot ar fi spre cameră): oglindită pe Y, degetele merg înainte (Godot -Z), iar
	# degetul mare rămâne în dreapta; oglindirea întoarce fețele pe dos, așa că le întoarcem la loc
	ob.data.transform(Matrix.Scale(-1.0, 4, Vector((0.0, 1.0, 0.0))))
	ob.data.flip_normals()
	ob.data.update()
	exporta(os.path.join(cale, "mana_jucator.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Interiorul: dimensiuni
# ---------------------------------------------------------------------------------------------------------------

W = 9.0            # jumătate din lățimea sălii: pereții la x = ±9
D = 14.0           # adâncimea: peretele din față (cu ușa) la y = 0, cel din spate la y = 14
H = 8.0            # tavanul sălii (înaltă cât două etaje)
G = 0.4            # grosimea pereților
ET = 3.6           # podeaua galeriei și a camerelor de sus
GAL = 10.0         # galeria: y între 10 și 14, de la un perete la altul
SC_X = 7.4         # scările urcă pe lângă pereții laterali: x între ±7,4 și ±9
SC_Y0 = 2.2        # prima treaptă (urcă spre galerie, spre +Y)
TREPTE = 18
PAS = (GAL - SC_Y0) / TREPTE
CAM_X1 = 17.0      # camerele de sus: x între ±9,4 și ±17
CAM_Y0, CAM_Y1 = 8.0, 16.0
CAM_H = 7.2        # tavanul camerelor
USA_Y0, USA_Y1, USA_Z1 = 11.2, 12.8, 6.3   # golul ușilor spre camere, în pereții x = ±9
STOFE = [ROSU, ROSU_INCHIS, VISINIU, MOV, VERDE, TEAL, LEMN, AUR_INCHIS, p("2a3c3d"), p("904a40")]


# ---------------------------------------------------------------------------------------------------------------
# Mobila și decorul (fiecare făcut în origine, cu fața spre -Y, apoi rotit și mutat cu _muta)
# ---------------------------------------------------------------------------------------------------------------

def _flacara(lumini, x, y, z, marime=1.0):
	"""Flacăra unei lumânări (strălucește în joc)."""
	lumini.append(sfera("Flacara", 0.014 * marime, (x, y, z + 0.018 * marime), FLACARA, scara=(1, 1, 2.0), segmente=6, inele=4))


def _lumanare(piese, lumini, x, y, z, inalt=0.16, raza=0.025):
	"""Lumânare de ceară (cu prelingeri) cu fitil și flacără; `z` = unde stă."""
	piese.append(cilindru("Lumanare", raza, raza, inalt, (x, y, z + inalt / 2), OS, laturi=6))
	piese.append(cilindru("Prelingere", raza * 0.5, raza * 0.25, inalt * 0.4, (x + raza * 0.85, y, z + inalt * 0.75), OS, laturi=4))
	piese.append(cilindru("Fitil", 0.003, 0.003, 0.016, (x, y, z + inalt + 0.008), NEGRU, laturi=3))
	_flacara(lumini, x, y, z + inalt + 0.01)


def _sfesnic(piese, lumini, x, y, z, brate=3, inalt=0.5):
	"""Sfeșnic de fier cu mai multe brațe (pe noptiere, pe mese, pe stâlpii scării)."""
	piese += [
		cilindru("Talpa sfesnic", 0.09, 0.06, 0.03, (x, y, z + 0.015), NEGRU, laturi=8),
		cilindru("Tija sfesnic", 0.015, 0.015, inalt, (x, y, z + inalt / 2), NEGRU, laturi=5),
	]
	zb = z + inalt
	if brate == 1:
		piese.append(cilindru("Cupa sfesnic", 0.04, 0.03, 0.03, (x, y, zb), NEGRU, laturi=8))
		_lumanare(piese, lumini, x, y, zb + 0.015)
		return
	piese.append(cilindru("Cupa sfesnic", 0.04, 0.03, 0.03, (x, y, zb + 0.08), NEGRU, laturi=8))
	_lumanare(piese, lumini, x, y, zb + 0.095, inalt=0.18)
	for k in range(brate - 1):
		u = k * math.tau / (brate - 1)
		cx, cy = x + math.cos(u) * 0.2, y + math.sin(u) * 0.2
		piese.append(os_intre("Brat sfesnic", (x, y, zb - 0.06), (cx, cy, zb), 0.012, NEGRU, laturi=4))
		piese.append(cilindru("Cupa sfesnic", 0.035, 0.025, 0.03, (cx, cy, zb), NEGRU, laturi=8))
		_lumanare(piese, lumini, cx, cy, zb + 0.015, inalt=0.13)


def _dovleac_aprins(piese, lumini, x, y, z, raza, unghi, r):
	"""Dovleac de Halloween cu fața tăiată care luminează, întors spre `unghi` (radiani; 0 = fața spre -Y)."""
	p_, l_ = [], []
	_dovleac(p_, 0, 0, 0, raza, r)
	_fata_dovleac(l_, 0, 0, 0, raza)
	_muta(p_ + l_, (0, 0, unghi), (x, y, z))
	piese += p_
	lumini += l_


def _craniu(piese, x, y, z, marime=1.0, unghi=0.0):
	c = []
	m = marime
	c += [
		sfera("Craniu", 0.07 * m, (0, 0, 0.075 * m), OS, scara=(0.85, 1.0, 0.95), segmente=8, inele=6),
		cub("Falca", (0.07 * m, 0.05 * m, 0.035 * m), (0, -0.035 * m, 0.02 * m), OS),
		cub("Orbita", (0.026 * m, 0.012 * m, 0.024 * m), (-0.024 * m, -0.066 * m, 0.08 * m), NEGRU),
		cub("Orbita", (0.026 * m, 0.012 * m, 0.024 * m), (0.024 * m, -0.066 * m, 0.08 * m), NEGRU),
		cub("Nas craniu", (0.012 * m, 0.012 * m, 0.02 * m), (0, -0.069 * m, 0.05 * m), NEGRU),
	]
	piese += _muta(c, (0, 0, unghi), (x, y, z))


def _canapea(piese, col, x, y, unghi, lung=2.1, culoare=ROSU, umbra=ROSU_INCHIS):
	"""Canapea chesterfield de catifea: brațe rulate, spătar capitonat (nasturi), trei perne, picioare negre."""
	c, k = [], []
	c += [
		cub("Baza canapea", (lung, 0.85, 0.36), (0, 0, 0.28), culoare),
		cub("Spatar", (lung, 0.22, 0.48), (0, 0.315, 0.7), culoare),
		cilindru("Spatar rulat", 0.12, 0.12, lung, (0, 0.33, 0.95), culoare, laturi=8, rot=(0, math.pi / 2, 0)),
	]
	for i in range(3):
		w = (lung - 0.46) / 3
		c.append(cub("Perna", (w - 0.02, 0.6, 0.12), (-lung / 2 + 0.23 + w * (i + 0.5), -0.09, 0.52), culoare))
	for s in (-1, 1):
		c += [
			cub("Brat canapea", (0.22, 0.8, 0.3), (s * (lung / 2 - 0.11), -0.01, 0.61), culoare),
			cilindru("Brat rulat", 0.13, 0.13, 0.8, (s * (lung / 2 - 0.11), -0.01, 0.78), culoare, laturi=8, rot=(math.pi / 2, 0, 0)),
		]
		for sy in (-1, 1):
			c.append(cilindru("Picior", 0.04, 0.03, 0.1, (s * (lung / 2 - 0.08), sy * 0.34, 0.05), NEGRU, laturi=6))
	for i in range(int(lung / 0.25)):
		for z in (0.62, 0.8):
			c.append(sfera("Nasture", 0.016, (-lung / 2 + 0.3 + i * 0.25 + (0.125 if z > 0.7 else 0), 0.2, z), umbra, segmente=5, inele=3))
	k.append(cub("Coliziune", (lung, 0.85, 1.0), (0, 0, 0.5), culoare))
	piese += _muta(c, (0, 0, unghi), (x, y, 0))
	col += _muta(k, (0, 0, unghi), (x, y, 0))


def _fotoliu(piese, col, x, y, unghi, culoare=MOV, umbra=VISINIU, z=0.0):
	"""Fotoliu cu urechi (wingback), de catifea, cu picioare de lemn întoarse."""
	c, k = [], []
	c += [
		cub("Sezut", (0.8, 0.75, 0.3), (0, 0, 0.33), culoare),
		cub("Perna", (0.6, 0.6, 0.1), (0, -0.04, 0.53), culoare),
		cub("Spatar", (0.78, 0.18, 0.85), (0, 0.29, 0.85), culoare),
		prisma("Varf spatar", [(-0.4, 1.27), (0.4, 1.27), (0.25, 1.38), (-0.25, 1.38)], "xz", 0.2, 0.38, culoare),
	]
	for s in (-1, 1):
		c += [
			cub("Ureche", (0.11, 0.35, 0.55), (s * 0.335, 0.11, 1.0), culoare),
			cub("Brat fotoliu", (0.11, 0.7, 0.22), (s * 0.335, -0.02, 0.59), culoare),
			cilindru("Brat rulat", 0.07, 0.07, 0.7, (s * 0.34, -0.02, 0.7), umbra, laturi=6, rot=(math.pi / 2, 0, 0)),
		]
		for sy in (-1, 1):
			c.append(cilindru("Picior", 0.035, 0.025, 0.18, (s * 0.33, sy * 0.3, 0.09), LEMN, laturi=6))
	k.append(cub("Coliziune", (0.8, 0.75, 1.2), (0, 0, 0.6), culoare))
	piese += _muta(c, (0, 0, unghi), (x, y, z))
	col += _muta(k, (0, 0, unghi), (x, y, z))


def _masa_rotunda(piese, col, x, y, raza=0.55, inalt=0.75, z=0.0, culoare=LEMN):
	piese += [
		cilindru("Blat", raza, raza, 0.05, (x, y, z + inalt - 0.025), culoare, laturi=12),
		cilindru("Picior masa", 0.06, 0.09, inalt - 0.15, (x, y, z + (inalt - 0.05) / 2 + 0.05), culoare, laturi=8),
		sfera("Nod masa", 0.1, (x, y, z + inalt * 0.45), culoare, segmente=8, inele=5),
	]
	for k in range(3):
		u = k * math.tau / 3
		piese.append(os_intre("Gheara", (x, y, z + 0.18), (x + math.cos(u) * 0.32, y + math.sin(u) * 0.32, z + 0.03), 0.03, culoare, laturi=4))
	col.append(cilindru("Coliziune", raza, raza, inalt, (x, y, z + inalt / 2), culoare, laturi=8))


def _tablou(r, lat=0.9, inalt=1.2, stil=0):
	"""Un portret vechi, în origine, cu fața spre -Y: rama de aur sculptată, fundalul întunecat și o vrăjitoare din
	familie (sau o pisică neagră), cu ochii care sclipesc puțin. Întoarce piesele (le muți cu _muta)."""
	c, l = [], []
	for dx, dz, w, hh in ((0, inalt / 2 + 0.06, lat + 0.24, 0.12), (0, -inalt / 2 - 0.06, lat + 0.24, 0.12),
			(-lat / 2 - 0.06, 0, 0.12, inalt), (lat / 2 + 0.06, 0, 0.12, inalt)):
		c.append(cub("Rama", (w, 0.08, hh), (dx, -0.04, dz), AUR))
	c.append(cub("Panza", (lat, 0.02, inalt), (0, -0.01, 0), r.choice((VERDE, p("2a3c3d"), VISINIU, LEMN))))
	f = -0.032
	if stil == 2:  # pisica neagră pe o pernă
		c += [
			sfera("Perna tablou", 0.24 * lat, (0, f, -inalt * 0.32), ROSU, scara=(1.3, 0.05, 0.4), segmente=8, inele=4),
			sfera("Pisica", 0.2 * lat, (0, f - 0.012, -inalt * 0.12), NEGRU, scara=(1.0, 0.05, 1.1), segmente=8, inele=5),
			sfera("Cap pisica", 0.12 * lat, (0, f - 0.014, inalt * 0.12), NEGRU, scara=(1.0, 0.05, 0.9), segmente=8, inele=5),
		]
		for s in (-1, 1):
			c.append(prisma("Ureche pisica", [(s * 0.04 * lat, inalt * 0.18), (s * 0.11 * lat, inalt * 0.18), (s * 0.09 * lat, inalt * 0.27)],
				"xz", f - 0.022, f - 0.012, NEGRU))
			l.append(cub("Ochi tablou", (0.03 * lat, 0.006, 0.02 * lat), (s * 0.045 * lat, f - 0.026, inalt * 0.13), TEAL_DESCHIS))
	else:
		roba = r.choice((MOV, ROSU_INCHIS, NEGRU, p("2a3c3d")))
		piele = r.choice((p("7e8d87"), p("70706e"), p("7a7b59")))
		c += [
			prisma("Roba tablou", [(-0.36 * lat, -inalt / 2), (0.36 * lat, -inalt / 2), (0.16 * lat, inalt * 0.08),
				(-0.16 * lat, inalt * 0.08)], "xz", f - 0.012, f, roba),
			sfera("Fata tablou", 0.1 * lat, (0, f - 0.014, inalt * 0.17), piele, scara=(0.85, 0.05, 1.15), segmente=8, inele=5),
			prisma("Par tablou", [(-0.13 * lat, inalt * 0.03), (0.13 * lat, inalt * 0.03), (0.1 * lat, inalt * 0.26),
				(-0.1 * lat, inalt * 0.26)], "xz", f - 0.008, f - 0.002, r.choice((NEGRU, p("904a40"), p("7e8d87")))),
		]
		if stil == 0:  # cu pălărie
			c.append(prisma("Palarie tablou", [(-0.26 * lat, inalt * 0.24), (0.26 * lat, inalt * 0.24), (0.05 * lat, inalt * 0.46)],
				"xz", f - 0.03, f - 0.02, NEGRU))
		for s in (-1, 1):
			l.append(cub("Ochi tablou", (0.03 * lat, 0.006, 0.014 * lat), (s * 0.035 * lat, f - 0.03, inalt * 0.19), AUR))
	return c, l


def _fereastra(piese, geamuri, lat, inalt, z0, unghi, loc, perdele=None, vitraliu=False, r=None):
	"""Fereastră gotică lungă pe un perete (făcută în origine pe planul y = 0, cu fața spre -Y, apoi rotită spre
	`unghi` și mutată la `loc`): rama de piatră, geamul de noapte (`geamuri`, abia luminat de lună) sau vitraliu colorat,
	baghetele de plumb, pervazul și, opțional, draperii grele de catifea cu ciucuri de aur."""
	c, g = [], []
	arc = lat * 0.8
	x0, x1 = -lat / 2, lat / 2
	z1 = z0 + inalt
	c.append(prisma("Rama fereastra", _pentagon(x0 - 0.16, x1 + 0.16, z0 - 0.12, z1 + 0.18, arc + 0.14), "xz", -0.06, 0.0, PIATRA))
	g.append(prisma("Geam", _pentagon(x0, x1, z0, z1, arc), "xz", -0.075, -0.065, GEAM_NOAPTE))
	if vitraliu:
		randuri = int(inalt / 0.45)
		for i in range(randuri):
			for j in range(2):
				g.append(cub("Vitraliu", (lat / 2 - 0.05, 0.008, 0.4), (x0 + lat / 4 + j * lat / 2, -0.083, z0 + 0.23 + i * 0.45),
					r.choice((ROSU, AUR, TEAL_DESCHIS, MOV, VERDE_DESCHIS, AUR_INCHIS))))
	# baghetele de plumb
	c.append(cub("Bagheta", (0.03, 0.015, inalt - arc * 0.3), (0, -0.095, z0 + (inalt - arc * 0.3) / 2), NEGRU))
	for i in range(1, int(inalt / 0.45) + 1):
		zz = z0 + i * 0.45
		if zz < z1 - arc * 0.6:
			c.append(cub("Bagheta", (lat, 0.015, 0.025), (0, -0.095, zz), NEGRU))
	c.append(cub("Pervaz", (lat + 0.36, 0.25, 0.1), (0, -0.12, z0 - 0.17), PIATRA))
	if perdele:
		for s in (-1, 1):
			xp = s * (lat / 2 + 0.3)
			for k in range(3):
				c.append(cub("Draperie", (0.16, 0.08, inalt + 0.9), (xp + (k - 1) * 0.13, -0.2 - (k % 2) * 0.05, z0 + inalt / 2 + 0.15),
					perdele, rot=(0, 0, (k - 1) * 0.12)))
			c.append(inel("Ciucure", 0.2, 0.025, (xp, -0.22, z0 + 0.9), AUR, segmente=8))
		c.append(cub("Garnisa", (lat + 1.2, 0.3, 0.22), (0, -0.2, z1 + 0.45), LEMN))
		c.append(cub("Franjuri", (lat + 1.2, 0.012, 0.1), (0, -0.356, z1 + 0.29), AUR))
	piese += _muta(c, (0, 0, unghi), loc)
	geamuri += _muta(g, (0, 0, unghi), loc)


def _lambriu(piese, x0, x1, y, spre, z0=0.0, inalt=1.2):
	"""Lambriu de lemn închis pe un perete paralel cu axa X (fața peretelui la `y`, `spre` = +1 dacă privește spre +Y):
	panourile, montanții și brâul de sus."""
	l = x1 - x0
	piese.append(cub("Lambriu", (l, 0.04, inalt), ((x0 + x1) / 2, y + spre * 0.02, z0 + inalt / 2), LEMN))
	piese.append(cub("Brau lambriu", (l, 0.09, 0.08), ((x0 + x1) / 2, y + spre * 0.045, z0 + inalt + 0.04), LEMN_DESCHIS))
	piese.append(cub("Plinta", (l, 0.07, 0.14), ((x0 + x1) / 2, y + spre * 0.035, z0 + 0.07), NEGRU))
	n = max(int(l / 1.1), 1)
	for i in range(n + 1):
		x = x0 + i * l / n
		x = min(max(x, x0 + 0.04), x1 - 0.04)
		piese.append(cub("Montant lambriu", (0.08, 0.03, inalt - 0.14), (x, y + spre * 0.055, z0 + 0.14 + (inalt - 0.14) / 2), LEMN_DESCHIS))


def _lambriu_y(piese, y0, y1, x, spre, z0=0.0, inalt=1.2):
	"""Ca `_lambriu`, pe un perete paralel cu axa Y (fața la `x`, `spre` = +1 dacă privește spre +X). Îl face pe
	planul y = 0 (cu fața spre -Y) și îl rotește: cu +90° fața ajunge spre +X, cu -90° spre -X (atunci lungimea se
	inversează, așa că îl face de la -y1 la -y0)."""
	c = []
	if spre > 0:
		_lambriu(c, y0, y1, 0.0, -1, z0, inalt)
		_muta(c, (0, 0, math.pi / 2), (x, 0, 0))
	else:
		_lambriu(c, -y1, -y0, 0.0, -1, z0, inalt)
		_muta(c, (0, 0, -math.pi / 2), (x, 0, 0))
	piese += c


def _raft_carti(piese, col, lat, inalt, r, unghi, loc, adanc=0.4):
	"""Bibliotecă înaltă, plină: cărți de toate culorile (unele aplecate), cranii, borcane, o lumânare stinsă."""
	c = []
	c += [
		cub("Spate raft", (lat, 0.03, inalt), (0, adanc / 2 - 0.015, inalt / 2), LEMN),
		cub("Laterala raft", (0.05, adanc, inalt), (-lat / 2 + 0.025, 0, inalt / 2), LEMN_DESCHIS),
		cub("Laterala raft", (0.05, adanc, inalt), (lat / 2 - 0.025, 0, inalt / 2), LEMN_DESCHIS),
		cub("Cornisa raft", (lat + 0.12, adanc + 0.06, 0.1), (0, -0.03, inalt + 0.05), LEMN_DESCHIS),
	]
	polite = int(inalt / 0.55)
	for i in range(polite):
		z = 0.08 + i * (inalt - 0.1) / polite
		c.append(cub("Polita", (lat - 0.1, adanc - 0.03, 0.04), (0, -0.015, z), LEMN_DESCHIS))
		x = -lat / 2 + 0.07
		while x < lat / 2 - 0.1:
			alege = r.random()
			if alege < 0.07 and x < lat / 2 - 0.3:
				_craniu(c, x + 0.08, -0.03, z + 0.02, 0.9, r.uniform(-0.4, 0.4))
				x += 0.2
			elif alege < 0.12 and x < lat / 2 - 0.25:
				c.append(cilindru("Borcan", 0.06, 0.06, 0.18, (x + 0.07, -0.03, z + 0.11), r.choice((TEAL, VERDE_DESCHIS, p("30716f"))), laturi=8))
				c.append(cilindru("Capac borcan", 0.065, 0.065, 0.025, (x + 0.07, -0.03, z + 0.212), LEMN, laturi=8))
				x += 0.16
			else:
				w = r.uniform(0.03, 0.065)
				h = r.uniform(0.2, min(0.34, (inalt - 0.1) / polite - 0.08))
				apl = r.uniform(-0.25, 0.0) if r.random() < 0.12 else 0.0
				c.append(cub("Carte", (w, r.uniform(0.2, 0.28), h), (x + w / 2, -0.03, z + 0.02 + h / 2), r.choice(STOFE), rot=(0, apl, 0)))
				x += w + 0.004 + (0.04 if apl else 0.0)
	piese += _muta(c, (0, 0, unghi), loc)
	col += _muta([cub("Coliziune", (lat, adanc, inalt), (0, 0, inalt / 2), LEMN)], (0, 0, unghi), loc)


def ceas_pendul(cale):
	"""Ceasul înalt cu pendul (bunicul) din living room: cutia de lemn închis cu fronton gotic și turnulețe, cadranul de
	aur cu limbile la 7:12, fereastra pendulului. `Pendul` e separat, cu originea în prindere (se leagănă în joc)."""
	curata()
	piese = [
		cub("Soclu ceas", (0.66, 0.42, 0.36), (0, 0, 0.18), LEMN),
		cub("Corp ceas", (0.5, 0.34, 1.3), (0, 0, 1.01), LEMN),
		cub("Cap ceas", (0.64, 0.44, 0.62), (0, 0, 1.97), LEMN),
		cub("Cornisa ceas", (0.72, 0.5, 0.06), (0, 0, 2.31), LEMN_DESCHIS),
		prisma("Fronton ceas", [(-0.36, 2.34), (0.36, 2.34), (0, 2.62)], "xz", -0.22, 0.22, LEMN),
		cub("Fereastra pendul", (0.3, 0.012, 0.9), (0, -0.176, 1.05), p("2a3c3d")),
		cub("Rama pendul", (0.38, 0.03, 0.04), (0, -0.18, 1.52), LEMN_DESCHIS),
		cub("Rama pendul", (0.38, 0.03, 0.04), (0, -0.18, 0.58), LEMN_DESCHIS),
		cilindru("Rama cadran", 0.25, 0.25, 0.03, (0, -0.225, 1.97), AUR, laturi=16, rot=(math.pi / 2, 0, 0)),
		cilindru("Cadran", 0.21, 0.21, 0.012, (0, -0.245, 1.97), OS, laturi=16, rot=(math.pi / 2, 0, 0)),
	]
	for k in range(12):
		u = k * math.pi / 6
		piese.append(cub("Cifra", (0.012, 0.006, 0.035), (math.sin(u) * 0.17, -0.254, 1.97 + math.cos(u) * 0.17), NEGRU, rot=(0, u, 0)))
	for unghi, lung, gros in ((7.2 / 12 * math.tau, 0.11, 0.016), (12 / 60 * math.tau, 0.16, 0.01)):
		piese.append(cub("Limba", (gros, 0.006, lung), (math.sin(unghi) * lung / 2, -0.26, 1.97 + math.cos(unghi) * lung / 2), NEGRU,
			rot=(0, unghi, 0)))
	for s in (-1, 1):
		piese.append(cilindru("Turnulet ceas", 0.04, 0.0, 0.28, (s * 0.3, -0.18, 2.48), LEMN_DESCHIS, laturi=4))
		piese.append(cub("Coloana ceas", (0.05, 0.05, 0.56), (s * 0.29, -0.2, 1.97), AUR_INCHIS))
	uneste(piese, "Ceas")
	pendul = [
		cub("Tija pendul", (0.012, 0.008, 0.62), (0, -0.19, 1.2), AUR),
		cilindru("Disc pendul", 0.07, 0.07, 0.01, (0, -0.194, 0.86), AUR, laturi=12, rot=(math.pi / 2, 0, 0)),
	]
	uneste(pendul, "Pendul", (0, -0.19, 1.5))
	exporta(os.path.join(cale, "ceas_pendul.glb"))


def _scanduri(piese, x0, x1, y0, y1, z, r):
	"""Podea de scânduri late de 25 cm, pe lungul axei Y, cu îmbinări decalate și rosturi de 1 cm (fața de sus la `z`)."""
	n = int(round((x1 - x0) / 0.25))
	for i in range(n):
		x = x0 + (i + 0.5) * (x1 - x0) / n
		y = y0
		lung = r.uniform(0.6, 3.5)
		while y < y1 - 0.05:
			y2 = min(y + lung, y1)
			piese.append(cub("Scandura", ((x1 - x0) / n - 0.01, y2 - y - 0.01, 0.02), (x, (y + y2) / 2, z - 0.01),
				r.choice((LEMN, LEMN, LEMN_DESCHIS))))
			y = y2
			lung = r.uniform(2.0, 4.0)


def _covor(piese, cx, cy, lx, ly, baza, margine, r, pentagrama=None, z=0.0):
	"""Covor gros (1,5 cm) cu chenar lat și o linie subțire de aur în interior; opțional o pentagramă în cerc la mijloc
	(raza dată). Fiecare strat stă cu 1,2 cm peste cel de dedesubt; franjuri pe laturile scurte."""
	piese.append(cub("Covor", (lx, ly, 0.015), (cx, cy, z + 0.0075), baza))
	b = 0.3
	piese += [
		cub("Chenar", (lx, b, 0.012), (cx, cy - ly / 2 + b / 2, z + 0.021), margine),
		cub("Chenar", (lx, b, 0.012), (cx, cy + ly / 2 - b / 2, z + 0.021), margine),
		cub("Chenar", (b, ly - 2 * b, 0.012), (cx - lx / 2 + b / 2, cy, z + 0.021), margine),
		cub("Chenar", (b, ly - 2 * b, 0.012), (cx + lx / 2 - b / 2, cy, z + 0.021), margine),
	]
	d = b + 0.15
	piese += [
		cub("Linie covor", (lx - 2 * d, 0.05, 0.012), (cx, cy - ly / 2 + d, z + 0.021), AUR),
		cub("Linie covor", (lx - 2 * d, 0.05, 0.012), (cx, cy + ly / 2 - d, z + 0.021), AUR),
		cub("Linie covor", (0.05, ly - 2 * d - 0.05, 0.012), (cx - lx / 2 + d, cy, z + 0.021), AUR),
		cub("Linie covor", (0.05, ly - 2 * d - 0.05, 0.012), (cx + lx / 2 - d, cy, z + 0.021), AUR),
	]
	if pentagrama:
		rr = pentagrama
		piese.append(cilindru("Medalion", rr + 0.15, rr + 0.15, 0.012, (cx, cy, z + 0.021), margine, laturi=20))
		piese.append(inel("Cerc covor", rr, 0.025, (cx, cy, z + 0.033), AUR, segmente=20))
		varfuri = [(cx + math.cos(math.pi / 2 + k * math.tau / 5) * rr, cy + math.sin(math.pi / 2 + k * math.tau / 5) * rr) for k in range(5)]
		for k in range(5):
			piese.append(linie("Pentagrama", varfuri[k], varfuri[(k + 2) % 5], 0.05, 0.012, z + 0.033, AUR))
	for s in (-1, 1):
		for i in range(int(lx / 0.08)):
			piese.append(cub("Franjuri", (0.02, 0.1, 0.01), (cx - lx / 2 + 0.04 + i * 0.08, cy + s * (ly / 2 + 0.05), z + 0.005), OS))


def _candelabru(piese, lumini, cx, cy, cz, tavan, raza=1.15, mic=False):
	"""Candelabru de fier forjat atârnat în lanț: două cercuri cu lumânări, brațe, picături de aur dedesubt."""
	piese += [
		os_intre("Lant", (cx, cy, tavan), (cx, cy, cz + 0.75), 0.022, NEGRU, laturi=4),
		cilindru("Tija candelabru", 0.08, 0.05, 0.6, (cx, cy, cz + 0.45), NEGRU, laturi=8),
		sfera("Glob candelabru", 0.14, (cx, cy, cz + 0.1), NEGRU, segmente=8, inele=5),
		cilindru("Varf candelabru", 0.06, 0.0, 0.2, (cx, cy, cz - 0.1), AUR, laturi=6, rot=(math.pi, 0, 0)),
	]
	for raza_c, zc, n in ((raza, cz, 12), (raza * 0.52, cz + 0.42, 6)) if not mic else ((raza, cz, 6),):
		piese.append(inel("Cerc candelabru", raza_c, 0.03, (cx, cy, zc), NEGRU, segmente=16))
		for k in range(n):
			u = k * math.tau / n
			x, y = cx + math.cos(u) * raza_c, cy + math.sin(u) * raza_c
			piese.append(cilindru("Cupa", 0.04, 0.03, 0.04, (x, y, zc + 0.02), NEGRU, laturi=6))
			_lumanare(piese, lumini, x, y, zc + 0.04, inalt=0.13, raza=0.022)
			if k % 2 == 0:
				piese.append(os_intre("Brat candelabru", (cx, cy, zc + 0.25), (x, y, zc), 0.016, NEGRU, laturi=4))
			piese.append(cilindru("Picatura", 0.018, 0.0, 0.07, (x, y, zc - 0.07), AUR, laturi=4, rot=(math.pi, 0, 0)))


def _orga(piese, col, unghi, loc):
	"""Orga de lemn negru din colțul din dreapta: consola cu două claviaturi, registrele, pupitrul cu partitura,
	tuburile de cositor care urcă pe perete și dulapul cu fronton gotic din spatele lor, bancheta."""
	c, k = [], []
	c += [
		cub("Consola", (2.0, 0.8, 0.82), (0, 0, 0.41), LEMN),
		cub("Claviatura", (1.7, 0.28, 0.05), (0, -0.5, 0.8), OS),
		cub("Sub claviatura", (1.8, 0.4, 0.06), (0, -0.45, 0.74), LEMN_DESCHIS),
		cub("Claviatura", (1.7, 0.22, 0.05), (0, -0.33, 0.93), OS),
		cub("Dulap orga", (2.0, 0.5, 1.5), (0, 0.15, 1.57), LEMN),
		cub("Pupitru", (0.9, 0.04, 0.42), (0, -0.14, 1.2), LEMN_DESCHIS, rot=(-0.2, 0, 0)),
		cub("Partitura", (0.62, 0.012, 0.32), (0, -0.165, 1.21), OS, rot=(-0.2, 0, 0)),
		cub("Spate orga", (2.2, 0.12, 2.3), (0, 0.34, 3.45), LEMN),
		prisma("Fronton orga", [(-1.1, 4.6), (1.1, 4.6), (0, 5.3)], "xz", 0.28, 0.4, LEMN),
		cub("Cornisa orga", (2.3, 0.6, 0.1), (0, 0.15, 2.37), LEMN_DESCHIS),
	]
	for i in range(19):  # clapele negre (câte două și trei, ca la pian)
		if i % 7 in (2, 6):
			continue
		for z, y in ((0.835, -0.46), (0.965, -0.3)):
			c.append(cub("Clapa neagra", (0.03, 0.14, 0.022), (-0.81 + i * 0.09, y, z), NEGRU))
	for s in (-1, 1):  # registrele
		for j in range(4):
			c.append(cilindru("Registru", 0.022, 0.022, 0.05, (s * (0.6 + j * 0.09), -0.11, 1.05 + (j % 2) * 0.1), OS if j % 2 else ROSU,
				laturi=6, rot=(math.pi / 2, 0, 0)))
	for i in range(11):  # tuburile
		h = 1.0 + (5 - abs(i - 5)) * 0.32
		x = -0.95 + i * 0.19
		c.append(cilindru("Tub orga", 0.07, 0.07, h, (x, 0.1, 2.42 + h / 2), PIATRA, laturi=8))
		c.append(cilindru("Picior tub", 0.07, 0.02, 0.2, (x, 0.1, 2.52), PIATRA, laturi=8, rot=(math.pi, 0, 0)))
		c.append(prisma("Gura tub", [(x - 0.035, 2.75), (x + 0.035, 2.75), (x, 2.85)], "xz", 0.02, 0.031, NEGRU))
	c += [
		cub("Bancheta", (1.4, 0.38, 0.08), (0, -1.0, 0.5), LEMN),
		cub("Picior bancheta", (0.08, 0.3, 0.46), (-0.6, -1.0, 0.23), LEMN),
		cub("Picior bancheta", (0.08, 0.3, 0.46), (0.6, -1.0, 0.23), LEMN),
	]
	k += [cub("Coliziune", (2.2, 0.85, 3.0), (0, 0.05, 1.5), LEMN), cub("Coliziune", (1.4, 0.4, 0.55), (0, -1.0, 0.27), LEMN)]
	piese += _muta(c, (0, 0, unghi), loc)
	col += _muta(k, (0, 0, unghi), loc)


def _spre(x, y, tx, ty):
	"""Unghiul (pentru _muta) cu care un obiect făcut cu fața spre -Y ajunge să privească spre (tx, ty)."""
	return math.atan2(tx - x, -(ty - y))


def _portal(piese, xf, spre):
	"""Rama gotică a unei uși spre o cameră de sus (în peretele x = `xf`, cu fața spre `spre` pe X): montanți, buiandrug
	și un fronton ascuțit deasupra."""
	x0, x1 = sorted((xf, xf + spre * 0.06))
	xc = (x0 + x1) / 2
	yc = (USA_Y0 + USA_Y1) / 2
	piese += [
		cub("Montant usa", (0.06, 0.16, USA_Z1 - ET), (xc, USA_Y0 - 0.08, (ET + USA_Z1) / 2), LEMN_DESCHIS),
		cub("Montant usa", (0.06, 0.16, USA_Z1 - ET), (xc, USA_Y1 + 0.08, (ET + USA_Z1) / 2), LEMN_DESCHIS),
		cub("Buiandrug", (0.06, USA_Y1 - USA_Y0 + 0.32, 0.18), (xc, yc, USA_Z1 + 0.09), LEMN_DESCHIS),
		prisma("Fronton usa", [(USA_Y0 - 0.16, USA_Z1 + 0.18), (USA_Y1 + 0.16, USA_Z1 + 0.18), (yc, USA_Z1 + 0.62)], "yz", x0, x1, LEMN),
	]


def conac_interior(cale):
	"""Interiorul conacului (o scenă separată): living room-ul gotic, înalt cât două etaje, cu scara dublă care urcă pe
	lângă pereții laterali la o galerie de-a lungul peretelui din spate; de pe galerie, câte o ușă în stânga și în dreapta
	spre cele două camere de sus (dreapta = camera lui Helga, cu manechinul; stânga = un dormitor). Lemn negru, catifea
	roșie și mov, lambriuri, candelabru cu lumânări, șemineu cu portretul fondatoarei, orgă, ceas cu pendul (separat:
	ceas_pendul.glb), biblioteci, vitralii, dovleci de Halloween aprinși pe trepte.
	Piese: `Interior`, `Lumini` (flăcările, fețele dovlecilor, ochii din portrete), `Geamuri` (ferestrele de noapte),
	`Vitralii`, `Coliziune` (pereți, podele, rampa scărilor, balustrade, mobila)."""
	curata()
	r = random.Random(1312)
	piese, lumini, geamuri, vitralii, col = [], [], [], [], []

	def strange():
		# lipește din când în când piesele făcute până acum: cu mii de obiecte separate în scenă Blender merge foarte încet
		piese[:] = [uneste(piese, "Interior")]

	def zid(dim, loc, culoare=VISINIU):
		piese.append(cub("Perete", dim, loc, culoare))
		col.append(cub("Coliziune", dim, loc, culoare))

	# --- podeaua, pereții, tavanul cu grinzi
	piese.append(cub("Placa podea", (2 * W + 2 * G, D + 2 * G, 0.3), (0, D / 2, -0.17), NEGRU))
	col.append(cub("Coliziune", (2 * W + 2 * G, D + 2 * G, 0.3), (0, D / 2, -0.15), NEGRU))
	_scanduri(piese, -W, W, 0.0, D, 0.0, r)
	zh, zc = H + 0.3, (H - 0.3) / 2
	zid((2 * W + 2 * G, G, zh), (0, -G / 2, zc))
	zid((2 * W + 2 * G, G, zh), (0, D + G / 2, zc))
	for sx in (-1, 1):
		xc = sx * (W + G / 2)
		zid((G, USA_Y0 + G, zh), (xc, (USA_Y0 - G) / 2, zc))
		zid((G, CAM_Y1 + G - USA_Y1, zh), (xc, (USA_Y1 + CAM_Y1 + G) / 2, zc))
		zid((G, USA_Y1 - USA_Y0, ET + 0.3), (xc, (USA_Y0 + USA_Y1) / 2, (ET - 0.3) / 2))
		zid((G, USA_Y1 - USA_Y0, H - USA_Z1), (xc, (USA_Y0 + USA_Y1) / 2, (H + USA_Z1) / 2))
	piese.append(cub("Tavan", (2 * W + 2 * G, D + 2 * G, 0.3), (0, D / 2, H + 0.15), LEMN))
	for i in range(7):
		y = 1.0 + i * 2.0
		piese.append(cub("Grinda", (2 * W, 0.3, 0.4), (0, y, H - 0.2), LEMN_DESCHIS))
		for sx in (-1, 1):
			piese.append(cub("Consola grinda", (0.25, 0.34, 0.45), (sx * (W - 0.125), y, H - 0.62), LEMN_DESCHIS))
	piese += [
		cub("Cornisa", (2 * W, 0.18, 0.18), (0, 0.09, H - 0.09), LEMN),
		cub("Cornisa", (2 * W, 0.18, 0.18), (0, D - 0.09, H - 0.09), LEMN),
		cub("Cornisa", (0.18, D - 0.36, 0.18), (-W + 0.09, D / 2, H - 0.09), LEMN),
		cub("Cornisa", (0.18, D - 0.36, 0.18), (W - 0.09, D / 2, H - 0.09), LEMN),
	]
	# lambriurile și pilaștrii
	_lambriu(piese, -W, -1.75, 0.0, 1)
	_lambriu(piese, 1.75, W, 0.0, 1)
	_lambriu(piese, -W, W, D, -1)
	for x0, x1 in ((-W, -2.3), (2.3, W)):
		_lambriu(piese, x0, x1, D, -1, z0=ET)
	for sx in (-1, 1):
		_lambriu_y(piese, 0.0, SC_Y0 - 0.1, sx * W, -sx)
		_lambriu_y(piese, GAL + 0.1, D, sx * W, -sx)
		_lambriu_y(piese, GAL, USA_Y0 - 0.25, sx * W, -sx, z0=ET)
		_lambriu_y(piese, USA_Y1 + 0.25, D, sx * W, -sx, z0=ET)
	for x in (-7.6, -2.2, 2.2, 7.6):
		piese.append(cub("Pilastru", (0.34, 0.1, H - 1.46), (x, 0.05, (H - 0.18 + 1.28) / 2), LEMN))
		piese.append(cub("Capitel", (0.46, 0.16, 0.22), (x, 0.08, H - 0.29), LEMN_DESCHIS))
	for x in (-6.9, -3.0, 3.0, 6.9):
		piese.append(cub("Pilastru", (0.34, 0.1, H - ET - 1.46), (x, D - 0.05, (H - 0.18 + ET + 1.28) / 2), LEMN))
		piese.append(cub("Capitel", (0.46, 0.16, 0.22), (x, D - 0.08, H - 0.29), LEMN_DESCHIS))

	strange()
	# --- ușa de la intrare, văzută dinăuntru (dublă, sub arc ascuțit, cu benzi de fier și inele)
	piese.append(prisma("Portal usa", _pentagon(-1.55, 1.55, 0.0, 4.2, 1.55), "xz", 0.0, 0.1, LEMN_DESCHIS))
	piese.append(prisma("Usa", _pentagon(-1.15, 1.15, 0.0, 3.75, 1.15), "xz", 0.1, 0.13, LEMN))
	for x in (-0.84, -0.56, -0.28, 0.28, 0.56, 0.84):
		piese.append(cub("Rost", (0.02, 0.012, 2.5), (x, 0.136, 1.3), NEGRU))
	piese.append(cub("Rost", (0.03, 0.012, 3.6), (0, 0.136, 1.8), NEGRU))
	for z in (0.5, 1.5, 2.4):
		piese.append(cub("Banda usa", (2.2, 0.012, 0.08), (0, 0.148, z), NEGRU))
		for i in range(8):
			piese.append(sfera("Tinta", 0.018, (-1.0 + i * 0.285, 0.156, z), NEGRU, segmente=5, inele=3))
	for s in (-1, 1):
		piese.append(_inel_vertical("Inel usa", 0.09, 0.014, (s * 0.24, 0.175, 1.35), NEGRU))
		piese.append(cilindru("Prindere inel", 0.035, 0.035, 0.03, (s * 0.24, 0.16, 1.44), NEGRU, laturi=6, rot=(math.pi / 2, 0, 0)))

	strange()
	# --- ferestrele din față și rozeta de deasupra ușii
	for x in (-3.6, 3.6):
		_fereastra(piese, geamuri, 1.5, 4.4, 1.6, math.pi, (x, 0.0, 0.0), perdele=ROSU)
	rc, rv = [], []
	zr, R = 5.85, 1.15
	rc.append(cilindru("Rama rozeta", R + 0.16, R + 0.16, 0.1, (0, -0.05, zr), PIATRA, laturi=24, rot=(math.pi / 2, 0, 0)))
	for k in range(12):
		u0, u1 = k * math.tau / 12, (k + 1) * math.tau / 12
		rv.append(prisma("Vitraliu", [(0, zr), (math.cos(u0) * R, zr + math.sin(u0) * R), (math.cos(u1) * R, zr + math.sin(u1) * R)],
			"xz", -0.118, -0.11, (ROSU, AUR_INCHIS, ROSU, MOV)[k % 4]))
		rc.append(cub("Spita rozeta", (R, 0.015, 0.035), (math.cos(u0) * R / 2, -0.13, zr + math.sin(u0) * R / 2), NEGRU, rot=(0, -u0, 0)))
	rv.append(cilindru("Vitraliu", 0.3, 0.3, 0.008, (0, -0.135, zr), AUR, laturi=12, rot=(math.pi / 2, 0, 0)))
	rc.append(inel("Inel rozeta", 0.62, 0.025, (0, 0, 0), NEGRU, segmente=16))
	_muta(rc[-1:], (math.pi / 2, 0, 0), (0, -0.125, zr))
	piese += _muta(rc, (0, 0, math.pi), (0, 0, 0))
	vitralii += _muta(rv, (0, 0, math.pi), (0, 0, 0))
	# aplicele de pe pilaștrii din față (lumânări)
	for x in (-2.2, 2.2):
		piese.append(cub("Brat aplica", (0.06, 0.3, 0.06), (x, 0.25, 2.45), NEGRU))
		piese.append(cilindru("Cupa aplica", 0.06, 0.04, 0.05, (x, 0.38, 2.5), NEGRU, laturi=8))
		_lumanare(piese, lumini, x, 0.38, 2.525, inalt=0.2)

	strange()
	# --- vitraliul mare din spate, deasupra galeriei (trei lancete)
	for x, inalt in ((-1.4, 2.2), (0.0, 2.6), (1.4, 2.2)):
		_fereastra(piese, vitralii, 1.0, inalt, 5.0, 0.0, (x, D, 0.0), vitraliu=True, r=r)
	for x in (-3.0, 3.0):
		piese.append(cub("Brat aplica", (0.06, 0.3, 0.06), (x, D - 0.25, ET + 2.0), NEGRU))
		piese.append(cilindru("Cupa aplica", 0.06, 0.04, 0.05, (x, D - 0.38, ET + 2.05), NEGRU, laturi=8))
		_lumanare(piese, lumini, x, D - 0.38, ET + 2.075, inalt=0.2)

	strange()
	# --- galeria de sus: podeaua, marginea cu dinți, grinzile de dedesubt, coloanele, balustrada
	piese.append(cub("Placa galerie", (2 * W, D - GAL, 0.3), (0, (GAL + D) / 2, ET - 0.17), LEMN))
	col.append(cub("Coliziune", (2 * W, D - GAL, 0.3), (0, (GAL + D) / 2, ET - 0.15), LEMN))
	_scanduri(piese, -W, W, GAL, D, ET, r)
	piese.append(cub("Margine galerie", (2 * SC_X, 0.14, 0.5), (0, GAL - 0.07, ET - 0.25), LEMN_DESCHIS))
	for i in range(int(2 * SC_X / 0.3)):
		piese.append(cub("Dinte", (0.12, 0.08, 0.12), (-SC_X + 0.15 + i * 0.3, GAL - 0.18, ET - 0.44), LEMN))
	for x in (-6.0, -3.0, 0.0, 3.0, 6.0):
		piese.append(cub("Grinda galerie", (0.2, D - GAL - 0.14, 0.22), (x, (GAL + D) / 2 + 0.07, ET - 0.43), LEMN_DESCHIS))
	for x in (-3.6, 3.6):
		y = GAL + 0.25
		piese += [
			cub("Baza coloana", (0.5, 0.5, 0.25), (x, y, 0.125), PIATRA_INCHISA),
			cilindru("Coloana", 0.17, 0.17, ET - 0.9, (x, y, 0.25 + (ET - 0.9) / 2), PIATRA, laturi=8),
			cub("Capitel coloana", (0.56, 0.56, 0.25), (x, y, ET - 0.525), PIATRA_INCHISA),
		]
		for k in range(4):
			u = k * math.tau / 4 + math.pi / 4
			piese.append(cilindru("Colonet", 0.05, 0.05, ET - 0.9, (x + math.cos(u) * 0.19, y + math.sin(u) * 0.19, 0.25 + (ET - 0.9) / 2),
				PIATRA_INCHISA, laturi=5))
		col.append(cub("Coliziune", (0.5, 0.5, ET), (x, y, ET / 2), PIATRA))
	yb = GAL + 0.1
	piese += [
		cub("Mana curenta", (2 * SC_X, 0.12, 0.07), (0, yb, ET + 1.0), LEMN_DESCHIS),
		cub("Bara balustrada", (2 * SC_X, 0.1, 0.07), (0, yb, ET + 0.1), LEMN),
	]
	stalpi = (-SC_X, -3.6, 0.0, 3.6, SC_X)
	for i in range(int(2 * SC_X / 0.22)):
		x = -SC_X + 0.11 + i * 0.22
		if min(abs(x - s) for s in stalpi) < 0.12:
			continue
		piese.append(cilindru("Baluster", 0.02, 0.02, 0.83, (x, yb, ET + 0.55), LEMN, laturi=5))
		piese.append(sfera("Baluster", 0.038, (x, yb, ET + 0.42), LEMN, scara=(1, 1, 1.7), segmente=6, inele=4))
	for x in stalpi:
		piese += [
			cub("Stalp balustrada", (0.16, 0.16, 1.2), (x, yb, ET + 0.6), LEMN),
			cub("Capac stalp", (0.22, 0.22, 0.06), (x, yb, ET + 1.23), LEMN_DESCHIS),
			sfera("Bila stalp", 0.07, (x, yb, ET + 1.33), AUR, segmente=8, inele=5),
		]
	col.append(cub("Coliziune", (2 * SC_X, 0.2, 1.2), (0, yb, ET + 0.6), LEMN))

	strange()
	# --- scara dublă: urcă pe lângă pereții laterali, cu un covor roșu cu bare de alamă, balustrada pe partea dinspre sală
	def mana_curenta(y):
		return 1.15 + (y - SC_Y0) / (GAL + 0.1 - SC_Y0) * (ET + 1.0 - 1.15)

	for sx in (-1, 1):
		x0, x1 = (SC_X, W) if sx > 0 else (-W, -SC_X)
		xc, lat = (x0 + x1) / 2, x1 - x0
		xb = sx * (SC_X + 0.07)
		for k in range(TREPTE):
			y0 = SC_Y0 + k * PAS
			sus = (k + 1) * 0.2
			piese += [
				cub("Treapta", (lat, PAS, sus), (xc, y0 + PAS / 2, sus / 2), LEMN),
				cub("Traversa", (1.0, PAS, 0.012), (xc, y0 + PAS / 2, sus + 0.006), ROSU),
				cub("Traversa", (1.0, 0.012, 0.2), (xc, y0 - 0.006, sus - 0.1), ROSU),
				cub("Dunga", (0.04, PAS, 0.012), (xc - 0.52, y0 + PAS / 2, sus + 0.006), AUR),
				cub("Dunga", (0.04, PAS, 0.012), (xc + 0.52, y0 + PAS / 2, sus + 0.006), AUR),
				cilindru("Bara covor", 0.009, 0.009, 1.12, (xc, y0 + 0.02, sus + 0.02), AUR, laturi=5, rot=(0, math.pi / 2, 0)),
			]
			zm = mana_curenta(y0 + PAS / 2)
			piese.append(cilindru("Baluster", 0.02, 0.02, zm - sus - 0.03, (xb, y0 + PAS / 2, (sus + zm) / 2), LEMN, laturi=5))
			if k % 5 == 2:
				_dovleac_aprins(piese, lumini, sx * (W - 0.3), y0 + PAS / 2, sus + 0.012, 0.15, -sx * 0.9, r)
		piese.append(os_intre("Mana curenta", (xb, SC_Y0, 1.15), (xb, GAL + 0.1, ET + 1.0), 0.045, LEMN_DESCHIS, laturi=6))
		xs0, xs1 = (SC_X - 0.05, SC_X) if sx > 0 else (-SC_X, -SC_X + 0.05)
		piese.append(prisma("Vang", [(SC_Y0 - 0.03, 0.0), (SC_Y0 - 0.03, 0.32), (GAL, ET + 0.12), (GAL, 0.0)], "yz", xs0, xs1, LEMN_DESCHIS))
		# stâlpul de la baza scării, cu un sfeșnic
		xn, yn = sx * (SC_X + 0.12), SC_Y0 + 0.05
		piese += [
			cub("Stalp scara", (0.26, 0.26, 1.25), (xn, yn, 0.625), LEMN),
			cub("Capac stalp", (0.34, 0.34, 0.08), (xn, yn, 1.29), LEMN_DESCHIS),
		]
		_sfesnic(piese, lumini, xn, yn, 1.33, brate=3, inalt=0.3)
		col.append(prisma("Coliziune", [(SC_Y0, 0.0), (GAL, ET), (GAL, 0.0)], "yz", x0, x1, LEMN))
		bx0, bx1 = (SC_X - 0.05, SC_X + 0.14) if sx > 0 else (-SC_X - 0.14, -SC_X + 0.05)
		col.append(prisma("Coliziune", [(SC_Y0 - 0.05, 0.0), (GAL, ET), (GAL, ET + 1.15), (SC_Y0 - 0.05, 1.3)], "yz", bx0, bx1, LEMN))
		col.append(cub("Coliziune", (0.3, 0.3, 1.5), (xn, yn, 0.75), LEMN))
		# portretele familiei, tot mai sus pe peretele scării
		for i, y in enumerate((3.6, 6.2, 8.8)):
			c, l = _tablou(r, 0.85, 1.15, stil=2 if (i == 1 and sx > 0) else i % 2)
			_muta(c + l, (0, 0, -sx * math.pi / 2), (sx * W, y, (y - SC_Y0) / PAS * 0.2 + 2.0))
			piese += c
			lumini += l

	strange()
	# --- șemineul (sub galerie, în mijloc), cu focul, poliță și portretul fondatoarei
	yf = D - 0.75
	piese += [
		cub("Semineu", (1.05, 0.75, 1.45), (-1.375, D - 0.375, 0.725), PIATRA),
		cub("Semineu", (1.05, 0.75, 1.45), (1.375, D - 0.375, 0.725), PIATRA),
		cub("Semineu", (3.8, 0.75, ET - 0.3 - 1.45), (0, D - 0.375, 1.45 + (ET - 0.3 - 1.45) / 2), PIATRA_INCHISA),
		cub("Vatra", (1.7, 0.1, 1.45), (0, D - 0.05, 0.725), NEGRU),
		cub("Vatra", (1.7, 0.65, 0.06), (0, D - 0.425, 0.03), NEGRU),
		cub("Prag semineu", (4.0, 0.9, 0.1), (0, yf - 0.45, 0.05), PIATRA),
		cub("Polita", (4.3, 0.5, 0.12), (0, yf - 0.1, 1.52), PIATRA),
		prisma("Arc semineu", [(-0.85, 1.45), (0.85, 1.45), (0.85, 1.2), (0.0, 1.4), (-0.85, 1.2)], "xz", yf - 0.04, yf, PIATRA),
	]
	for s in (-1, 1):
		piese += [
			cilindru("Coloana semineu", 0.11, 0.11, 1.35, (s * 1.35, yf - 0.1, 0.72), PIATRA_INCHISA, laturi=8),
			cub("Consola polita", (0.18, 0.3, 0.25), (s * 1.75, yf - 0.1, 1.33), PIATRA),
			cub("Capra foc", (0.04, 0.4, 0.3), (s * 0.45, D - 0.4, 0.21), NEGRU),
		]
	for k, (dx, u) in enumerate(((-0.25, 0.25), (0.2, -0.3), (0.0, 0.05))):
		piese.append(cilindru("Butuc", 0.07, 0.07, 0.75, (dx, D - 0.42, 0.12 + (k == 2) * 0.12), LEMN_DESCHIS, laturi=6,
			rot=(0, math.pi / 2, u)))
	for dx, h, rr, cul in ((-0.3, 0.42, 0.13, FLACARA_PORTOCALIE), (0.0, 0.62, 0.17, FLACARA), (0.28, 0.48, 0.13, FLACARA_PORTOCALIE),
			(-0.1, 0.35, 0.1, FLACARA), (0.15, 0.3, 0.09, FLACARA)):
		lumini.append(cilindru("Foc", rr, 0.0, h, (dx, D - 0.42, 0.2 + h / 2), cul, laturi=6))
	_sfesnic(piese, lumini, -1.65, yf - 0.1, 1.57, brate=1, inalt=0.12)
	_sfesnic(piese, lumini, 1.65, yf - 0.1, 1.57, brate=1, inalt=0.12)
	_craniu(piese, 0.9, yf - 0.12, 1.57, 1.0, 0.3)
	piese += [  # clepsidra și corbul împăiat de pe poliță
		cilindru("Clepsidra", 0.06, 0.06, 0.02, (-0.85, yf - 0.1, 1.58), LEMN, laturi=6),
		cilindru("Clepsidra", 0.05, 0.01, 0.1, (-0.85, yf - 0.1, 1.64), TEAL, laturi=6),
		cilindru("Clepsidra", 0.01, 0.05, 0.1, (-0.85, yf - 0.1, 1.74), TEAL, laturi=6),
		cilindru("Clepsidra", 0.06, 0.06, 0.02, (-0.85, yf - 0.1, 1.8), LEMN, laturi=6),
		sfera("Corb", 0.09, (0.3, yf - 0.1, 1.68), NEGRU, scara=(0.8, 1.3, 1.0), segmente=8, inele=5),
		sfera("Cap corb", 0.055, (0.3, yf - 0.2, 1.78), NEGRU, segmente=6, inele=4),
		cilindru("Cioc corb", 0.022, 0.0, 0.08, (0.3, yf - 0.27, 1.77), PIATRA_INCHISA, laturi=4, rot=(math.pi / 2, 0, 0)),
		cub("Coada corb", (0.06, 0.14, 0.02), (0.3, yf + 0.05, 1.62), NEGRU, rot=(0.5, 0, 0)),
	]
	c, l = _tablou(r, 1.3, 1.3, stil=0)
	_muta(c + l, (0, 0, 0), (0, yf, 2.45))
	piese += c
	lumini += l
	col.append(cub("Coliziune", (4.3, 1.6, 1.7), (0, D - 0.8, 0.85), PIATRA))

	strange()
	# --- bibliotecile de sub galerie, de o parte și de alta a șemineului
	for sx in (-1, 1):
		_raft_carti(piese, col, 4.4, 2.9, r, 0.0, (sx * 4.75, D - 0.2, 0.0))

	strange()
	# --- colțul cu canapelele din fața șemineului
	_covor(piese, 0.0, 11.65, 5.2, 2.7, ROSU_INCHIS, AUR_INCHIS, r)
	_canapea(piese, col, -2.05, 11.65, math.pi / 2, lung=2.0)
	_canapea(piese, col, 2.05, 11.65, -math.pi / 2, lung=2.0)
	piese.append(cub("Masuta", (0.7, 1.3, 0.06), (0, 11.65, 0.45), LEMN))
	for sx in (-1, 1):
		for sy in (-1, 1):
			piese.append(os_intre("Picior masuta", (sx * 0.3, 11.65 + sy * 0.58, 0.43), (sx * 0.34, 11.65 + sy * 0.62, 0.02), 0.03, LEMN,
				laturi=4))
	piese += [
		sfera("Ceainic", 0.1, (0.1, 11.4, 0.56), NEGRU, scara=(1, 1, 0.85), segmente=8, inele=5),
		cilindru("Cioc ceainic", 0.025, 0.012, 0.12, (0.1, 11.27, 0.6), NEGRU, laturi=5, rot=(0.9, 0, 0)),
		cilindru("Capac ceainic", 0.04, 0.01, 0.05, (0.1, 11.4, 0.66), AUR, laturi=6),
		cilindru("Ceasca", 0.035, 0.03, 0.05, (-0.15, 11.85, 0.505), OS, laturi=8),
		cilindru("Ceasca", 0.035, 0.03, 0.05, (0.18, 12.05, 0.505), OS, laturi=8),
	]
	for k in range(4):  # cărțile de tarot întinse pe masă
		piese.append(cub("Tarot", (0.07, 0.11, 0.004), (-0.18 + k * 0.09, 11.25 + (k % 2) * 0.03, 0.482), MOV if k % 2 else ROSU_INCHIS,
			rot=(0, 0, (k - 1.5) * 0.15)))
	col.append(cub("Coliziune", (0.7, 1.3, 0.5), (0, 11.65, 0.25), LEMN))

	strange()
	# --- covorul mare din mijloc și candelabrul de deasupra
	_covor(piese, 0.0, 5.6, 7.2, 6.0, ROSU, AUR_INCHIS, r, pentagrama=1.5)
	_candelabru(piese, lumini, 0.0, 5.6, 6.2, H)

	strange()
	# --- colțurile din față: orga (dreapta); ceasul cu pendul (stânga) e în ceas_pendul.glb
	_orga(piese, col, math.pi, (6.0, 0.45, 0.0))

	strange()
	# --- în stânga: o măsuță rotundă cu un glob de cristal, între două fotolii; un sfeșnic înalt
	_masa_rotunda(piese, col, -5.6, 4.9, raza=0.5, inalt=0.72)
	piese += [
		cilindru("Suport glob", 0.08, 0.1, 0.06, (-5.6, 4.9, 0.75), AUR, laturi=8),
		cilindru("Suport glob", 0.03, 0.06, 0.05, (-5.6, 4.9, 0.8), AUR, laturi=8),
	]
	lumini.append(sfera("Glob cristal", 0.13, (-5.6, 4.9, 0.94), TEAL_DESCHIS, segmente=10, inele=7))
	_fotoliu(piese, col, -6.65, 4.9, math.pi / 2)
	_fotoliu(piese, col, -5.6, 3.75, math.pi, culoare=ROSU, umbra=ROSU_INCHIS)
	_sfesnic(piese, lumini, -6.4, 8.4, 0.0, brate=5, inalt=1.5)
	col.append(cilindru("Coliziune", 0.2, 0.2, 1.8, (-6.4, 8.4, 0.9), NEGRU, laturi=6))

	strange()
	# --- în dreapta: un șezlong de catifea mov și o măsuță cu un sfeșnic; un sfeșnic înalt
	_canapea(piese, col, 6.45, 6.4, -math.pi / 2, lung=1.8, culoare=MOV, umbra=VISINIU)
	_masa_rotunda(piese, col, 6.5, 4.75, raza=0.35, inalt=0.6)
	_sfesnic(piese, lumini, 6.5, 4.75, 0.6, brate=3, inalt=0.3)
	_sfesnic(piese, lumini, 6.4, 8.4, 0.0, brate=5, inalt=1.5)
	col.append(cilindru("Coliziune", 0.2, 0.2, 1.8, (6.4, 8.4, 0.9), NEGRU, laturi=6))
	# dovleci lângă ușă
	_dovleac_aprins(piese, lumini, -2.0, 0.6, 0.0, 0.2, _spre(-2.0, 0.6, 0.0, 4.0), r)
	_dovleac_aprins(piese, lumini, -2.35, 0.95, 0.0, 0.14, _spre(-2.35, 0.95, 0.0, 4.0), r)
	_dovleac_aprins(piese, lumini, 2.0, 0.6, 0.0, 0.18, _spre(2.0, 0.6, 0.0, 4.0), r)

	strange()
	# --- pe galerie: o bancă, o măsuță cu sfeșnic, dovleci
	piese += [
		cub("Banca", (1.8, 0.45, 0.08), (-5.4, D - 0.4, ET + 0.47), LEMN),
		cub("Spatar banca", (1.8, 0.08, 0.6), (-5.4, D - 0.2, ET + 0.8), LEMN),
		cub("Picior banca", (0.08, 0.4, 0.45), (-6.2, D - 0.4, ET + 0.225), LEMN),
		cub("Picior banca", (0.08, 0.4, 0.45), (-4.6, D - 0.4, ET + 0.225), LEMN),
	]
	col.append(cub("Coliziune", (1.8, 0.5, 1.1), (-5.4, D - 0.35, ET + 0.55), LEMN))
	_masa_rotunda(piese, col, 5.4, D - 0.6, raza=0.4, inalt=0.75, z=ET)
	_sfesnic(piese, lumini, 5.4, D - 0.6, ET + 0.75, brate=3, inalt=0.3)
	_dovleac_aprins(piese, lumini, 8.3, D - 0.5, ET, 0.2, _spre(8.3, D - 0.5, 0.0, 6.0), r)
	_dovleac_aprins(piese, lumini, -8.3, D - 0.5, ET, 0.17, _spre(-8.3, D - 0.5, 0.0, 6.0), r)

	strange()
	# --- camerele de sus
	for sx in (-1, 1):
		xa, xb = (W + G, CAM_X1) if sx > 0 else (-CAM_X1, -W - G)
		xm, lx = (xa + xb) / 2, xb - xa
		ym = (CAM_Y0 + CAM_Y1) / 2
		piese.append(cub("Placa podea", (lx, CAM_Y1 - CAM_Y0, 0.3), (xm, ym, ET - 0.17), NEGRU))
		col.append(cub("Coliziune", (lx, CAM_Y1 - CAM_Y0, 0.3), (xm, ym, ET - 0.15), NEGRU))
		_scanduri(piese, xa, xb, CAM_Y0, CAM_Y1, ET, r)
		zhc, zcc = CAM_H - ET + 0.6, (ET + CAM_H) / 2
		xl0, xl1 = (W, CAM_X1 + G) if sx > 0 else (-CAM_X1 - G, -W)
		zid((xl1 - xl0, G, zhc), ((xl0 + xl1) / 2, CAM_Y0 - G / 2, zcc))
		zid((xl1 - xl0, G, zhc), ((xl0 + xl1) / 2, CAM_Y1 + G / 2, zcc))
		zid((G, CAM_Y1 - CAM_Y0 + 2 * G, zhc), (sx * (CAM_X1 + G / 2), ym, zcc))
		piese.append(cub("Tavan", (lx, CAM_Y1 - CAM_Y0, 0.3), (xm, ym, CAM_H + 0.15), LEMN))
		for i in range(5):
			piese.append(cub("Grinda", (lx, 0.22, 0.28), (xm, CAM_Y0 + 1.0 + i * 1.5, CAM_H - 0.14), LEMN_DESCHIS))
		piese += [
			cub("Cornisa", (lx, 0.16, 0.16), (xm, CAM_Y0 + 0.08, CAM_H - 0.08), LEMN),
			cub("Cornisa", (lx, 0.16, 0.16), (xm, CAM_Y1 - 0.08, CAM_H - 0.08), LEMN),
			cub("Cornisa", (0.16, CAM_Y1 - CAM_Y0 - 0.32, 0.16), (sx * (CAM_X1 - 0.08), ym, CAM_H - 0.08), LEMN),
			cub("Cornisa", (0.16, CAM_Y1 - CAM_Y0 - 0.32, 0.16), (sx * (W + G + 0.08), ym, CAM_H - 0.08), LEMN),
		]
		_lambriu(piese, xa, xb, CAM_Y0, 1, z0=ET)
		_lambriu(piese, xa, xb, CAM_Y1, -1, z0=ET)
		_lambriu_y(piese, CAM_Y0, CAM_Y1, sx * CAM_X1, -sx, z0=ET)
		_lambriu_y(piese, CAM_Y0, USA_Y0 - 0.2, sx * (W + G), sx, z0=ET)
		_lambriu_y(piese, USA_Y1 + 0.2, CAM_Y1, sx * (W + G), sx, z0=ET)
		_portal(piese, sx * W, -sx)
		_portal(piese, sx * (W + G), sx)
		# ușa, deschisă spre cameră (lipită de perete, lângă balama)
		xu = sx * (W + G + 0.13)
		piese.append(cub("Usa camera", (0.06, 1.55, USA_Z1 - ET - 0.05), (xu, USA_Y0 - 0.85, ET + (USA_Z1 - ET) / 2), LEMN))
		for z in (ET + 0.6, ET + 2.0):
			piese.append(cub("Banda usa", (0.08, 1.5, 0.06), (xu, USA_Y0 - 0.85, z), NEGRU))
		strange()
		if sx > 0:
			_camera_helga(piese, lumini, geamuri, col, r)
		else:
			_camera_stanga(piese, lumini, geamuri, col, r)

	uneste(col, "Coliziune")
	uneste(geamuri, "Geamuri")
	uneste(vitralii, "Vitralii")
	uneste(lumini, "Lumini")
	uneste(piese, "Interior")
	exporta(os.path.join(cale, "conac_interior.glb"))


def _sticla(piese, lumini, x, y, z, r):
	"""O poțiune: sticlă rotundă, înaltă sau borcănaș, cu lichid colorat (unele strălucesc) și dop."""
	lichid = r.choice((TEAL_DESCHIS, VERDE_DESCHIS, ROSU, MOV, AUR, p("30716f"), p("904a40")))
	forma = r.random()
	unde = lumini if r.random() < 0.3 else piese
	if forma < 0.4:
		rr = r.uniform(0.045, 0.07)
		unde.append(sfera("Potiune", rr, (x, y, z + rr), lichid, segmente=8, inele=5))
		piese.append(cilindru("Gat sticla", 0.016, 0.014, 0.07, (x, y, z + rr * 2 + 0.025), GEAM_NOAPTE, laturi=6))
		piese.append(cilindru("Dop", 0.018, 0.016, 0.025, (x, y, z + rr * 2 + 0.07), LEMN_DESCHIS, laturi=6))
	elif forma < 0.75:
		h = r.uniform(0.14, 0.24)
		unde.append(cilindru("Potiune", 0.035, 0.035, h, (x, y, z + h / 2), lichid, laturi=6))
		piese.append(cilindru("Gat sticla", 0.035, 0.014, 0.05, (x, y, z + h + 0.025), GEAM_NOAPTE, laturi=6))
		piese.append(cilindru("Dop", 0.016, 0.014, 0.025, (x, y, z + h + 0.06), LEMN_DESCHIS, laturi=6))
	else:
		piese.append(cilindru("Borcanas", 0.05, 0.05, 0.1, (x, y, z + 0.05), lichid, laturi=8))
		piese.append(cilindru("Capac borcan", 0.054, 0.054, 0.02, (x, y, z + 0.11), LEMN, laturi=8))


def _raft_potiuni(piese, lumini, col, lat, inalt, r, unghi, loc):
	"""Etajera vrăjitoarei: poțiuni de toate culorile, un borcan cu ochi, cărți, un craniu cu o lumânare, cristale."""
	c, l = [], []
	adanc = 0.36
	c += [
		cub("Spate raft", (lat, 0.03, inalt), (0, adanc / 2 - 0.015, inalt / 2), LEMN),
		cub("Laterala raft", (0.05, adanc, inalt), (-lat / 2 + 0.025, 0, inalt / 2), LEMN_DESCHIS),
		cub("Laterala raft", (0.05, adanc, inalt), (lat / 2 - 0.025, 0, inalt / 2), LEMN_DESCHIS),
		cub("Cornisa raft", (lat + 0.12, adanc + 0.06, 0.1), (0, -0.03, inalt + 0.05), LEMN_DESCHIS),
		prisma("Fronton raft", [(-lat / 2, inalt + 0.1), (lat / 2, inalt + 0.1), (0, inalt + 0.45)], "xz", -0.02, 0.02, LEMN),
	]
	polite = 4
	for i in range(polite):
		z = 0.06 + i * (inalt - 0.1) / polite
		c.append(cub("Polita", (lat - 0.1, adanc - 0.03, 0.04), (0, -0.015, z), LEMN_DESCHIS))
		x = -lat / 2 + 0.12
		while x < lat / 2 - 0.15:
			alege = r.random()
			if alege < 0.08:
				_craniu(c, x + 0.06, -0.03, z + 0.02, 0.85, r.uniform(-0.5, 0.5))
				_lumanare(c, l, x + 0.06, -0.04, z + 0.165, inalt=0.08, raza=0.018)
				x += 0.2
			elif alege < 0.14:  # borcanul cu ochi
				c.append(cilindru("Borcan", 0.075, 0.075, 0.2, (x + 0.08, -0.03, z + 0.12), p("30716f"), laturi=8))
				for k in range(3):
					c.append(sfera("Ochi borcan", 0.025, (x + 0.06 + k * 0.025, -0.1, z + 0.08 + k * 0.045), OS, segmente=6, inele=4))
					c.append(cub("Pupila", (0.014, 0.006, 0.014), (x + 0.06 + k * 0.025, -0.126, z + 0.08 + k * 0.045), NEGRU))
				x += 0.2
			elif alege < 0.24:  # teanc de cărți culcate
				for k in range(r.randint(2, 4)):
					c.append(cub("Carte", (0.2, 0.24, 0.04), (x + 0.11, -0.02, z + 0.04 + k * 0.042), r.choice(STOFE), rot=(0, 0, r.uniform(-0.15, 0.15))))
				x += 0.26
			else:
				_sticla(c, l, x + 0.05, -0.03 + r.uniform(-0.04, 0.04), z + 0.02, r)
				x += r.uniform(0.11, 0.16)
	piese += _muta(c, (0, 0, unghi), loc)
	lumini += _muta(l, (0, 0, unghi), loc)
	col += _muta([cub("Coliziune", (lat, adanc, inalt), (0, 0, inalt / 2), LEMN)], (0, 0, unghi), loc)


def _liliac(piese, x, y, z, unghi):
	"""Un liliac de hârtie atârnat de un fir (decor de Halloween)."""
	c = [
		sfera("Liliac", 0.035, (0, 0, 0), NEGRU, scara=(0.8, 0.7, 1.2), segmente=6, inele=4),
		prisma("Aripa", [(0.02, 0.02), (0.18, 0.06), (0.14, -0.02), (0.1, 0.01), (0.06, -0.03)], "xz", -0.003, 0.003, NEGRU),
		prisma("Aripa", [(-0.02, 0.02), (-0.06, -0.03), (-0.1, 0.01), (-0.14, -0.02), (-0.18, 0.06)], "xz", -0.003, 0.003, NEGRU),
	]
	for s in (-1, 1):
		c.append(prisma("Ureche liliac", [(s * 0.01, 0.035), (s * 0.03, 0.035), (s * 0.022, 0.065)], "xz", -0.004, 0.004, NEGRU))
	piese += _muta(c, (0, 0, unghi), (x, y, z))


def _camera_helga(piese, lumini, geamuri, col, r):
	"""Camera din dreapta de sus (a lui Helga): sala de vrăji de Halloween. Ferestrele pe peretele din fund cu
	manechinul între ele (pe perete, urme de arsură de la mingile de foc), etajera cu poțiuni, biroul cu cartea de vrăji
	deschisă, un ceaun care bolborosește verde, dovleci aprinși, covorul cu pentagramă, ierburi și lilieci atârnați."""
	z = ET
	xm, ym = (W + G + CAM_X1) / 2, (CAM_Y0 + CAM_Y1) / 2
	for y in (9.85, 14.15):
		_fereastra(piese, geamuri, 1.0, 2.2, z + 0.95, -math.pi / 2, (CAM_X1, y, 0.0), perdele=MOV)
	for k, (dy, dz, rr) in enumerate(((0.0, 1.62, 0.26), (0.3, 1.82, 0.16), (-0.28, 1.5, 0.14), (0.12, 2.05, 0.1))):
		piese.append(cilindru("Arsura", rr, rr * 0.85, 0.008, (CAM_X1 - 0.014 - k * 0.011, 12.0 + dy, z + dz),
			NEGRU if k % 2 == 0 else PIATRA_INCHISA, laturi=10, rot=(0, math.pi / 2, 0)))
	_raft_potiuni(piese, lumini, col, 4.4, 2.5, r, math.pi, (13.4, CAM_Y0 + 0.2, z))
	# biroul cu cartea de vrăji, la peretele din spate
	bx, by = 12.4, CAM_Y1 - 0.45
	piese += [
		cub("Birou", (1.9, 0.85, 0.06), (bx, by, z + 0.76), LEMN),
		cub("Sertare", (0.5, 0.75, 0.6), (bx - 0.65, by, z + 0.43), LEMN_DESCHIS),
		cub("Sertare", (0.5, 0.75, 0.6), (bx + 0.65, by, z + 0.43), LEMN_DESCHIS),
		cub("Plinta birou", (1.9, 0.75, 0.12), (bx, by, z + 0.06), LEMN),
	]
	for s in (-1, 1):
		for k in range(3):
			piese.append(sfera("Maner sertar", 0.018, (bx + s * 0.65, by - 0.385, z + 0.25 + k * 0.18), AUR, segmente=5, inele=3))
	carte = [
		cub("Pagina", (0.24, 0.32, 0.02), (-0.125, 0, 0.0), OS, rot=(0, 0.08, 0)),
		cub("Pagina", (0.24, 0.32, 0.02), (0.125, 0, 0.0), OS, rot=(0, -0.08, 0)),
		cub("Coperta", (0.52, 0.34, 0.012), (0, 0, -0.02), ROSU),
	]
	for s in (-1, 1):
		for k in range(7):
			carte.append(cub("Rand", (0.15 - (k % 3) * 0.03, 0.012, 0.004), (s * 0.125, 0.12 - k * 0.04, 0.013 - abs(s) * 0.0), NEGRU,
				rot=(math.pi / 2, s * 0.08, 0)))
	carte.append(cilindru("Desen carte", 0.05, 0.05, 0.004, (0.125, -0.05, 0.016), ROSU_INCHIS, laturi=5))
	piese += _muta(carte, (0, 0, 0.15), (bx - 0.15, by - 0.05, z + 0.81))
	piese += [
		cilindru("Calimara", 0.035, 0.03, 0.05, (bx + 0.35, by + 0.1, z + 0.815), NEGRU, laturi=6),
		cilindru("Pana", 0.004, 0.018, 0.3, (bx + 0.38, by + 0.12, z + 0.95), OS, laturi=4, rot=(0.3, 0.25, 0)),
	]
	_craniu(piese, bx + 0.7, by + 0.15, z + 0.79, 1.0, 0.4)
	for k, (dx, h) in enumerate(((-0.75, 0.22), (-0.62, 0.15), (-0.68, 0.3))):
		_lumanare(piese, lumini, bx + dx, by + 0.15 + k * 0.04, z + 0.79, inalt=h, raza=0.024)
	_dovleac_aprins(piese, lumini, bx + 0.25, by + 0.22, z + 0.79, 0.12, 0.0, r)
	col.append(cub("Coliziune", (1.9, 0.85, 0.85), (bx, by, z + 0.42), LEMN))
	# scaunul gotic cu spătar înalt
	sc = [
		cub("Sezut scaun", (0.5, 0.5, 0.06), (0, 0, 0.48), LEMN),
		prisma("Spatar scaun", [(-0.25, 0.5), (0.25, 0.5), (0.25, 1.35), (0, 1.6), (-0.25, 1.35)], "xz", 0.2, 0.25, LEMN),
		cub("Perna scaun", (0.42, 0.42, 0.05), (0, -0.02, 0.535), ROSU),
	]
	for sx_ in (-1, 1):
		for sy_ in (-1, 1):
			sc.append(cub("Picior scaun", (0.05, 0.05, 0.46), (sx_ * 0.21, sy_ * 0.21, 0.23), LEMN))
	piese += _muta(sc, (0, 0, math.pi + 0.3), (bx - 0.1, by - 0.85, z))
	col += _muta([cub("Coliziune", (0.5, 0.5, 1.2), (0, 0, 0.6), LEMN)], (0, 0, math.pi + 0.3), (bx - 0.1, by - 0.85, z))
	# ceaunul care bolborosește, în colț
	cx, cy = 10.45, 15.0
	piese += [
		sfera("Ceaun", 0.42, (cx, cy, z + 0.42), NEGRU, scara=(1, 1, 0.85), segmente=12, inele=7),
		inel("Buza ceaun", 0.36, 0.04, (cx, cy, z + 0.72), NEGRU, segmente=12),
	]
	for k in range(3):
		u = k * math.tau / 3
		piese.append(os_intre("Picior ceaun", (cx + math.cos(u) * 0.25, cy + math.sin(u) * 0.25, z + 0.15),
			(cx + math.cos(u) * 0.36, cy + math.sin(u) * 0.36, z), 0.035, NEGRU, laturi=4))
	lumini.append(cilindru("Fiertura", 0.34, 0.34, 0.01, (cx, cy, z + 0.66), VERDE_DESCHIS, laturi=12))
	for k in range(5):
		u = r.uniform(0, math.tau)
		d = r.uniform(0.05, 0.25)
		lumini.append(sfera("Bula", r.uniform(0.025, 0.05), (cx + math.cos(u) * d, cy + math.sin(u) * d, z + 0.67), VERDE_DESCHIS,
			scara=(1, 1, 0.6), segmente=6, inele=4))
	col.append(cilindru("Coliziune", 0.45, 0.45, 0.8, (cx, cy, z + 0.4), NEGRU, laturi=8))
	# dovleci, covorul cu pentagramă, mături, ierburi, lilieci, un candelabru mic, pânze de păianjen
	for x, y, rr in ((16.45, 8.6, 0.22), (16.45, 15.4, 0.2), (16.0, 8.55, 0.13)):
		_dovleac_aprins(piese, lumini, x, y, z, rr, _spre(x, y, xm, ym), r)
	_covor(piese, 13.0, 11.7, 3.4, 3.0, p("2a3c3d"), VISINIU, r, pentagrama=1.05, z=z)
	for k, (x, y) in enumerate(((9.75, 8.55), (10.1, 8.5))):
		baza = Vector((x + 0.05 * k, y + 0.5, z + 0.3))
		varf = Vector((x, y + 0.04, z + 1.7))
		d = (baza - varf).normalized()
		piese.append(os_intre("Coada matura", tuple(varf), tuple(baza), 0.018, LEMN_DESCHIS, laturi=5))
		piese.append(trunchi("Paie matura", [(tuple(baza - d * 0.02), 0.04, 0.035), (tuple(baza + d * 0.38), 0.13, 0.08)], AUR, laturi=8))
	for k in range(5):
		x, y = 9.9 + (k % 2) * 0.25, 9.0 + k * 1.4
		piese.append(os_intre("Sfoara", (x, y, CAM_H - 0.1), (x, y, CAM_H - 0.55), 0.004, NEGRU, laturi=3))
		piese.append(cilindru("Ierburi", 0.02, 0.08, 0.3, (x, y, CAM_H - 0.7), r.choice((VERDE, VERDE_DESCHIS, AUR_INCHIS)), laturi=6))
	for k in range(6):
		x, y = 11.2 + (k % 3) * 1.9, 9.6 + (k // 3) * 4.6
		lung = r.uniform(0.4, 0.9)
		piese.append(os_intre("Fir", (x, y, CAM_H - 0.28), (x, y, CAM_H - 0.28 - lung), 0.003, NEGRU, laturi=3))
		_liliac(piese, x, y, CAM_H - 0.32 - lung, r.uniform(0, math.tau))
	_candelabru(piese, lumini, xm, ym, CAM_H - 0.9, CAM_H, raza=0.5, mic=True)
	for xc, yc, sx_, sy_ in ((CAM_X1, CAM_Y0, -1, 1), (CAM_X1, CAM_Y1, -1, -1)):
		for k in range(4):
			u = k * math.pi / 6
			piese.append(os_intre("Panza paianjen", (xc - 0.02 * -sx_, yc + 0.02 * -sy_, CAM_H - 0.3),
				(xc + sx_ * math.cos(u) * 0.6, yc + sy_ * math.sin(u) * 0.6, CAM_H - 0.3 - math.sin(u + 0.4) * 0.3), 0.003, OS, laturi=3))


def _camera_stanga(piese, lumini, geamuri, col, r):
	"""Camera din stânga de sus: un dormitor gotic. Pat cu baldachin și draperii roșii (o pisică neagră doarme pe el),
	dulap sculptat, măsuță de toaletă cu oglindă ovală, biblioteci, un cufăr, dovleci aprinși, un candelabru mic."""
	z = ET
	xm, ym = (-W - G - CAM_X1) / 2, (CAM_Y0 + CAM_Y1) / 2
	for y in (9.5, 14.5):
		_fereastra(piese, geamuri, 1.0, 2.2, z + 0.95, math.pi / 2, (-CAM_X1, y, 0.0), perdele=ROSU)
	# patul cu baldachin, cu capul la peretele din fund
	px0, px1 = -CAM_X1 + 0.12, -CAM_X1 + 2.35
	py0, py1 = 11.05, 12.95
	pmx = (px0 + px1) / 2
	piese += [
		cub("Pat", (px1 - px0, py1 - py0, 0.35), (pmx, 12.0, z + 0.3), LEMN),
		cub("Saltea", (px1 - px0 - 0.1, py1 - py0 - 0.12, 0.2), (pmx, 12.0, z + 0.575), OS),
		cub("Plapuma", (1.5, py1 - py0 - 0.06, 0.1), (px1 - 0.8, 12.0, z + 0.72), ROSU_INCHIS),
		cub("Plapuma intoarsa", (0.25, py1 - py0 - 0.04, 0.12), (px1 - 1.6, 12.0, z + 0.74), ROSU),
		sfera("Perna", 0.3, (px0 + 0.35, 11.55, z + 0.76), OS, scara=(0.5, 1.0, 0.35), segmente=8, inele=5),
		sfera("Perna", 0.3, (px0 + 0.35, 12.45, z + 0.76), OS, scara=(0.5, 1.0, 0.35), segmente=8, inele=5),
		prisma("Tablie", [(py0, z + 0.4), (py1, z + 0.4), (py1, z + 1.9), (12.0, z + 2.35), (py0, z + 1.9)], "yz", px0 - 0.1, px0, LEMN),
		cub("Baldachin", (px1 - px0 + 0.1, py1 - py0 + 0.1, 0.04), (pmx, 12.0, z + 2.66), ROSU),
	]
	for x in (px0, px1):
		for y in (py0, py1):
			piese.append(cilindru("Stalp pat", 0.07, 0.06, 2.6, (x, y, z + 1.3), LEMN, laturi=6))
			piese.append(sfera("Bila pat", 0.08, (x, y, z + 2.72), AUR, segmente=6, inele=4))
			sy_ = 1 if y < 12 else -1
			sx_ = 1 if x < pmx else -1
			for k in range(3):  # draperiile strânse la stâlp, legate cu un ciucure de aur
				piese.append(cub("Draperie", (0.14, 0.06, 2.4), (x + sx_ * (0.12 + k * 0.1), y - sy_ * 0.05, z + 1.42), ROSU,
					rot=(0, 0, (k - 1) * 0.15)))
			piese.append(inel("Ciucure", 0.17, 0.022, (x + sx_ * 0.22, y - sy_ * 0.05, z + 1.25), AUR, segmente=8))
	for y in (py0, py1):
		piese.append(cub("Bara baldachin", (px1 - px0, 0.08, 0.12), (pmx, y, z + 2.58), LEMN))
	for x in (px0, px1):
		piese.append(cub("Bara baldachin", (0.08, py1 - py0, 0.12), (x, 12.0, z + 2.58), LEMN))
	# pisica neagră, ghemuită pe plapumă
	kx, ky, kz = px1 - 0.55, 12.35, z + 0.77
	piese += [
		sfera("Pisica", 0.2, (kx, ky, kz + 0.07), NEGRU, scara=(1.0, 0.75, 0.5), segmente=8, inele=5),
		sfera("Cap pisica", 0.075, (kx + 0.17, ky - 0.1, kz + 0.1), NEGRU, segmente=8, inele=5),
		trunchi("Coada pisica", [((kx - 0.16, ky + 0.05, kz + 0.05), 0.025, 0.025), ((kx - 0.1, ky - 0.15, kz + 0.04), 0.022, 0.022),
			((kx + 0.08, ky - 0.2, kz + 0.04), 0.018, 0.018)], NEGRU, laturi=5),
	]
	for s in (-1, 1):
		piese.append(prisma("Ureche pisica", [(ky - 0.1 + s * 0.02, kz + 0.15), (ky - 0.1 + s * 0.065, kz + 0.15), (ky - 0.1 + s * 0.045, kz + 0.21)],
			"yz", kx + 0.16, kx + 0.18, NEGRU))
	col.append(cub("Coliziune", (px1 - px0 + 0.2, py1 - py0 + 0.2, 2.8), (pmx, 12.0, z + 1.4), LEMN))
	piese.append(cub("Cufar", (0.5, 1.2, 0.5), (px1 + 0.4, 12.0, z + 0.25), LEMN_DESCHIS))
	piese.append(cilindru("Capac cufar", 0.25, 0.25, 1.2, (px1 + 0.4, 12.0, z + 0.5), LEMN_DESCHIS, laturi=8, rot=(math.pi / 2, 0, 0),
		scara=(1, 1, 0.5)))
	for y in (11.6, 12.4):
		piese.append(cub("Banda cufar", (0.52, 0.04, 0.52), (px1 + 0.4, y, z + 0.27), AUR))
	col.append(cub("Coliziune", (0.55, 1.25, 0.7), (px1 + 0.4, 12.0, z + 0.35), LEMN))
	# dulapul sculptat (peretele din față al camerei)
	dx, dy = -12.6, CAM_Y0 + 0.32
	piese += [
		cub("Dulap", (1.8, 0.6, 2.45), (dx, dy, z + 1.225), LEMN),
		cub("Coroana dulap", (1.95, 0.7, 0.12), (dx, dy, z + 2.51), LEMN_DESCHIS),
		prisma("Fronton dulap", [(dx - 0.9, z + 2.57), (dx + 0.9, z + 2.57), (dx, z + 2.95)], "xz", dy - 0.02, dy + 0.02, LEMN),
	]
	for s in (-1, 1):
		piese.append(prisma("Usa dulap", _pentagon(dx + s * 0.43 - 0.38, dx + s * 0.43 + 0.38, z + 0.15, z + 2.3, 0.4), "xz",
			dy + 0.3, dy + 0.32, LEMN_DESCHIS))
		piese.append(sfera("Maner dulap", 0.025, (dx + s * 0.08, dy + 0.34, z + 1.2), AUR, segmente=5, inele=3))
	col.append(cub("Coliziune", (1.8, 0.65, 2.6), (dx, dy, z + 1.3), LEMN))
	_dovleac_aprins(piese, lumini, dx + 0.5, dy, z + 2.57, 0.16, math.pi, r)
	# măsuța de toaletă cu oglinda ovală (peretele din spate al camerei)
	vx, vy = -12.8, CAM_Y1 - 0.3
	piese += [
		cub("Masuta toaleta", (1.3, 0.5, 0.06), (vx, vy, z + 0.75), LEMN),
		cub("Sertar", (1.2, 0.45, 0.2), (vx, vy, z + 0.62), LEMN_DESCHIS),
		cilindru("Rama oglinda", 0.42, 0.42, 0.04, (vx, CAM_Y1 - 0.12, z + 1.55), AUR, laturi=16, rot=(math.pi / 2, 0, 0), scara=(1, 1, 1.4)),
		cilindru("Oglinda", 0.36, 0.36, 0.01, (vx, CAM_Y1 - 0.15, z + 1.55), GRI, laturi=16, rot=(math.pi / 2, 0, 0), scara=(1, 1, 1.4)),
	]
	for s in (-1, 1):
		for sy_ in (-1, 1):
			piese.append(cub("Picior masuta", (0.05, 0.05, 0.72), (vx + s * 0.6, vy + sy_ * 0.2, z + 0.36), LEMN))
		_sfesnic(piese, lumini, vx + s * 0.5, vy - 0.05, z + 0.78, brate=1, inalt=0.15)
	for k in range(3):
		_sticla(piese, lumini, vx - 0.2 + k * 0.1, vy - 0.08, z + 0.78, r)
	col.append(cub("Coliziune", (1.3, 0.5, 0.8), (vx, vy, z + 0.4), LEMN))
	# biblioteci pe peretele cu ușa
	for y0, y1 in ((CAM_Y0 + 0.3, USA_Y0 - 0.3), (USA_Y1 + 0.3, CAM_Y1 - 0.3)):
		_raft_carti(piese, col, y1 - y0, 2.4, r, -math.pi / 2, (-W - G - 0.2, (y0 + y1) / 2, z), adanc=0.36)
	_covor(piese, -13.4, 12.0, 3.2, 3.6, ROSU_INCHIS, AUR_INCHIS, r, z=z)
	for x, y, rr in ((-16.5, 8.65, 0.2), (-16.4, 15.35, 0.17), (-11.3, 15.6, 0.15)):
		_dovleac_aprins(piese, lumini, x, y, z, rr, _spre(x, y, xm, ym), r)
	_candelabru(piese, lumini, xm, ym, CAM_H - 0.9, CAM_H, raza=0.5, mic=True)


def salon(cale):
	for i, (s, pahar) in enumerate(SALON):
		vrajitoare_salon(cale, "vrajitoare_salon_%d" % (i + 1), s, 200 + i, pahar)


def toate(cale):
	salon(cale)
	helga(cale)
	manechin(cale)
	mana_jucator(cale)
	ceas_pendul(cale)
	conac_interior(cale)


if __name__ == "__main__":
	cale_modele = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")
	if "--" in sys.argv:
		for nume in sys.argv[sys.argv.index("--") + 1:]:
			globals()[nume](cale_modele)
	else:
		toate(cale_modele)
