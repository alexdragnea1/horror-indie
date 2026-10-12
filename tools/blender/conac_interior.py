# Înăuntrul conacului coven-ului (conac_interior.tscn) și cine e acolo: living room-ul gotic cu scara dublă și
# galeria, cele două camere de la etaj (Helga în dreapta), vrăjitoarele care stau la povești, Helga, manechinul de
# antrenament, mâna ta (vraja Fireball, la persoana întâi) și pisica neagră din dormitor.
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
from unelte import p, curata, cub, cilindru, sfera, os_intre, inel, linie, uneste, exporta, trunchi, _coloreaza  # noqa: E402
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
OCHI_PISICA = p("a18463")


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
		if pahar == "clesti":
			# vrăjitoarele din camera de tortură (subsol): un clește lung de fierar, cu fălcile pătate de sânge
			for k in (-1, 1):
				a = (palma[0] + k * 0.012, palma[1] + 0.03, palma[2] - 0.13)
				b = (palma[0] + k * 0.008, palma[1] - 0.06, palma[2] + 0.06)
				c = (palma[0] - k * 0.004, palma[1] - 0.12, palma[2] + 0.16)
				brat.append(os_intre("Clesti", a, b, 0.009, NEGRU, laturi=4))
				brat.append(os_intre("Falca clesti", b, c, 0.011, GRI, laturi=4))
				brat.append(os_intre("Sange clesti", _lerp(b, c, 0.55), c, 0.013, ROSU, laturi=4))
			brat.append(sfera("Nit clesti", 0.016, (palma[0], palma[1] - 0.06, palma[2] + 0.06), GRI, segmente=6, inele=4))
		else:
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
	# brațul stâng ține cartea la piept: cotul jos pe lângă corp, antebrațul (cu mâneca largă, clopot) trece orizontal
	# prin fața corpului, cartea stă în picioare PE el, rezemată de piept, iar palma urcă pe coperta din față și o
	# ține. (Înainte antebrațul trecea prin copertă: mâneca are 10 cm rază la încheietură, nu încape între carte și piept.)
	umar, cot, inch = (0.21, 0.0, z_umar), (0.26, -0.06, z_umar - 0.31), (-0.07, -0.22, z_umar - 0.33)
	_maneca(piese, umar, cot, inch, s["roba"], s["roba_umbra"])
	_mana(piese, _lerp(cot, inch, 1.02), _norm((-0.05, 0.12, 1.0)), (1.0, 0.0, 0.0), s["piele"], NEGRU, r, deschisa=False)
	carte = [
		cub("Coperta", (0.17, 0.008, 0.24), (0, -0.017, 0), ROSU),
		cub("Coperta", (0.17, 0.008, 0.24), (0, 0.017, 0), ROSU),
		cub("Cotor", (0.012, 0.042, 0.24), (-0.085, 0, 0), ROSU_INCHIS),
		cub("Pagini", (0.158, 0.026, 0.226), (0.004, 0, 0), OS),
		cilindru("Pentagrama carte", 0.04, 0.04, 0.004, (0.0, -0.023, 0.02), AUR, laturi=5, rot=(math.pi / 2, 0, 0)),
	]
	# puțin înclinată cu vârful spre piept, cu jos-ul pe mânecă (10 cm deasupra antebrațului)
	_muta(carte, (-0.1, 0.0, -0.08), (0.01, -0.205, z_umar - 0.33 + 0.105 + 0.12))
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
		# mâneca e lungă (70 cm), ca să iasă din ecran oricum ai ține mâna (și când mângâi pisica)
		trunchi("Maneca", [((0.012, 0.12, -0.044), 0.05, 0.042), ((0.03, 0.22, -0.088), 0.056, 0.048), ((0.06, 0.38, -0.16), 0.062, 0.054),
			((0.09, 0.55, -0.235), 0.066, 0.058), ((0.115, 0.72, -0.31), 0.07, 0.062)],
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
GROS_TREAPTA = 0.3   # treptele sunt o placă groasă de 30 cm: sub cea din stânga e debaraua lui Parry, sub cea din dreapta
                     # coboară scara spre subsol
DEB_X0, DEB_X1, DEB_H = 7.48, 8.22, 1.95   # golul ușilor din capătul scărilor (peretele de sub galerie, y = GAL), la
                                           # x = ±(DEB_X0…DEB_X1): în stânga debaraua lui Parry, în dreapta scara spre subsol
SUB_Y0 = 4.35      # scara spre subsol coboară pe sub scara din dreapta, de la GAL până aici: podeaua sălii are gaură deasupra
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


def _scanduri(piese, x0, x1, y0, y1, z, r, gaura=None):
	"""Podea de scânduri late de 25 cm, pe lungul axei Y, cu îmbinări decalate și rosturi de 1 cm (fața de sus la `z`).
	`gaura` = (x0, x1, y0, y1): scândurile cu mijlocul între x0 și x1 sunt tăiate între y0 și y1."""
	n = int(round((x1 - x0) / 0.25))
	for i in range(n):
		x = x0 + (i + 0.5) * (x1 - x0) / n
		y = y0
		lung = r.uniform(0.6, 3.5)
		while y < y1 - 0.05:
			y2 = min(y + lung, y1)
			cul = r.choice((LEMN, LEMN, LEMN_DESCHIS))
			bucati = [(y, y2)]
			if gaura and gaura[0] <= x <= gaura[1]:
				bucati = [(a, b) for a, b in ((y, min(y2, gaura[2])), (max(y, gaura[3]), y2)) if b - a > 0.03]
			for a, b in bucati:
				piese.append(cub("Scandura", ((x1 - x0) / n - 0.01, b - a - 0.01, 0.02), (x, (a + b) / 2, z - 0.01), cul))
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
		# medalionul (raza rr + 0,15) stă la aceeași înălțime ca liniile de aur și chenarul: dacă le atinge, fețele se
		# bat (z-fighting, liniile ies rupte). Îl ținem cu 8 cm înăuntrul liniilor.
		incape = min(lx, ly) / 2 - d - 0.025 - 0.08 - 0.15
		if pentagrama > incape:
			print("COVOR: pentagrama %.2f nu încape în covorul %.1f x %.1f, o micșorez la %.2f" % (pentagrama, lx, ly, incape))
		rr = min(pentagrama, incape)
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


def _placa(nume, contur, z0, z1, culoare):
	"""Placă culcată, de la z0 la z1, cu marginea `contur` (punctele (x, y), în ordine; poate fi și concavă: carcasa
	pianului cu coadă)."""
	import bmesh
	bm = bmesh.new()
	jos = [bm.verts.new((x, y, z0)) for x, y in contur]
	sus = [bm.verts.new((x, y, z1)) for x, y in contur]
	bm.faces.new(jos)
	bm.faces.new(list(reversed(sus)))
	n = len(contur)
	for i in range(n):
		bm.faces.new((jos[i], jos[(i + 1) % n], sus[(i + 1) % n], sus[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bmesh.ops.triangulate(bm, faces=bm.faces[:])
	me = bpy.data.meshes.new(nume)
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new(nume, me)
	bpy.context.scene.collection.objects.link(ob)
	_coloreaza(ob, culoare)
	return ob


# Conturul pianului cu coadă, văzut de sus: clapele pe latura dreaptă de la y = 0 (spre -Y, unde stă pianistul), basul
# în stânga (latura dreaptă, lungă), iar în dreapta curba în S a carcasei până la coada rotunjită.
CONTUR_PIAN = [(-0.75, 0.0), (0.75, 0.0), (0.75, 0.38), (0.69, 0.62), (0.52, 0.84), (0.33, 1.06), (0.24, 1.32), (0.17, 1.58),
	(0.04, 1.8), (-0.18, 1.93), (-0.45, 1.96), (-0.64, 1.89), (-0.74, 1.74), (-0.75, 1.55)]


def _pian(piese, lumini, col, unghi, loc):
	"""Pianul cu coadă (în locul orgii, care stătea în drum): lac negru, capacul ridicat pe bețul lui (se vede placa de
	aur cu corzile), clapele de os cu clapele negre, pupitrul cu partitura, trei picioare strunjite cu rotile de alamă,
	lira cu pedalele, bancheta cu pernă roșie și un craniu pe carcasă."""
	c = []
	zj, zs = 0.66, 0.98  # carcasa: dedesubt și buza de sus
	zp = zs - 0.06  # fața de sus a corpului plin; deasupra ei, între pereții carcasei, stă placa cu corzile
	c += [
		_placa("Corp pian", CONTUR_PIAN, zj, zp, NEGRU),
		# placa de fontă aurie (se vede pe sub capacul ridicat)
		_placa("Placa corzi", [(x * 0.9, 0.08 + y * 0.9) for x, y in CONTUR_PIAN], zp, zp + 0.014, AUR),
	]
	# pereții carcasei: câte o scândură de 3 cm pe fiecare latură a conturului, de la corp până la buză
	n = len(CONTUR_PIAN)
	for i in range(n):
		(x0, y0), (x1, y1) = CONTUR_PIAN[i], CONTUR_PIAN[(i + 1) % n]
		lung = math.hypot(x1 - x0, y1 - y0)
		nx, ny = (y1 - y0) / lung, -(x1 - x0) / lung  # normala spre exterior (conturul merge invers acelor de ceasornic)
		c.append(cub("Perete pian", (lung + 0.03, 0.03, zs - zp + 0.01), ((x0 + x1) / 2 - nx * 0.015, (y0 + y1) / 2 - ny * 0.015,
			(zs + zp) / 2 + 0.005), NEGRU, rot=(0, 0, math.atan2(y1 - y0, x1 - x0))))
	for k, lung in enumerate((1.32, 1.38, 1.4, 1.38, 1.32, 1.25, 1.08, 0.66, 0.48)):  # corzile, cât încap pe placă
		x = -0.6 + k * 0.125
		c.append(cub("Coarda", (0.012, lung, 0.008), (x, 0.36 + lung / 2, zp + 0.018), OS))
	# în față, peste mecanism, capacul fix (pe el stau pupitrul și craniul); capacul mare are balamaua pe latura basului
	# (x = -0.75) și e ridicat ~33 de grade spre sală, pe bețul lui
	c.append(cub("Capac fata", (1.55, 0.35, 0.022), (0, 0.17, zs + 0.011), NEGRU))
	capac = [_placa("Capac pian", [(x + 0.765, max(y, 0.34)) for x, y in CONTUR_PIAN], 0.0, 0.022, NEGRU)]
	_muta(capac, (0, -0.58, 0), (-0.765, 0, zs + 0.004))
	c += capac
	xb = -0.765 + 1.15 * math.cos(0.58)
	c.append(os_intre("Bat capac", (xb, 0.95, zp + 0.014), (xb, 0.95, zs + 0.004 + 1.15 * math.sin(0.58) - 0.01), 0.012, NEGRU, laturi=4))
	# claviatura: patul clapelor iese în față, cu obrajii de la capete; clapele albe de os, cele negre câte două și trei
	c += [
		cub("Pat clape", (1.5, 0.3, 0.07), (0, -0.15, zj + 0.06), NEGRU),
		cub("Clape", (1.3, 0.16, 0.025), (0, -0.11, zj + 0.107), OS),
		cub("Spate clape", (1.3, 0.08, 0.14), (0, 0.02, zj + 0.16), NEGRU),
		cub("Obraz pian", (0.11, 0.33, 0.16), (-0.705, -0.145, zj + 0.13), NEGRU),
		cub("Obraz pian", (0.11, 0.33, 0.16), (0.705, -0.145, zj + 0.13), NEGRU),
	]
	for i in range(30):
		if i % 7 in (2, 6) or i > 28:
			continue
		c.append(cub("Clapa neagra", (0.022, 0.09, 0.022), (-0.6 + i * 0.0415 + 0.02, -0.075, zj + 0.13), NEGRU))
	# pupitrul cu partitura (aplecat spre spate) și un craniu pe buza din stânga
	c += [
		cub("Pupitru pian", (0.78, 0.025, 0.3), (0, 0.16, zs + 0.17), NEGRU, rot=(0.28, 0, 0)),
		cub("Partitura", (0.5, 0.012, 0.25), (0, 0.142, zs + 0.18), OS, rot=(0.28, 0, 0)),
	]
	_craniu(c, -0.6, 0.15, zs + 0.022, 0.9, 0.5)
	# picioarele strunjite (două la clape, unul la coadă), cu rotile de alamă
	for x, y in ((-0.64, 0.12), (0.64, 0.12), (-0.5, 1.72)):
		c += [
			cilindru("Picior pian", 0.07, 0.05, 0.12, (x, y, zj - 0.06), NEGRU, laturi=8),
			cilindru("Picior pian", 0.045, 0.06, zj - 0.17, (x, y, (zj - 0.17) / 2 + 0.05), NEGRU, laturi=8),
			sfera("Inel picior", 0.065, (x, y, zj - 0.28), NEGRU, scara=(1, 1, 0.45), segmente=8, inele=4),
			sfera("Rotila", 0.035, (x, y, 0.035), AUR, segmente=6, inele=4),
		]
	# lira cu pedalele, sub clape
	c += [
		cub("Lira", (0.26, 0.05, 0.035), (0, 0.32, zj - 0.02), NEGRU),
		cub("Lira", (0.035, 0.05, zj - 0.12), (-0.09, 0.32, (zj - 0.12) / 2 + 0.08), NEGRU),
		cub("Lira", (0.035, 0.05, zj - 0.12), (0.09, 0.32, (zj - 0.12) / 2 + 0.08), NEGRU),
		cub("Cutie pedale", (0.3, 0.12, 0.06), (0, 0.3, 0.06), NEGRU),
	]
	for k in (-1, 0, 1):
		c.append(cub("Pedala", (0.035, 0.13, 0.015), (k * 0.08, 0.2, 0.06), AUR))
	# bancheta
	c += [
		cub("Bancheta", (0.85, 0.38, 0.07), (0, -0.72, 0.47), NEGRU),
		cub("Perna bancheta", (0.8, 0.34, 0.05), (0, -0.72, 0.53), ROSU),
	]
	for sx in (-1, 1):
		for sy in (-1, 1):
			c.append(os_intre("Picior bancheta", (sx * 0.36, -0.72 + sy * 0.14, 0.44), (sx * 0.38, -0.72 + sy * 0.16, 0.0), 0.025, NEGRU,
				laturi=5))
	k = [cub("Coliziune", (1.5, 1.96, 1.0), (0, 0.98, 0.5), NEGRU), cub("Coliziune", (1.5, 0.32, 1.0), (0, -0.16, 0.5), NEGRU),
		cub("Coliziune", (0.85, 0.4, 0.56), (0, -0.72, 0.28), NEGRU)]
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
	# placa are o gaură sub scara din dreapta, deasupra scării care coboară în subsol (subsol.glb)
	for xa, xb, ya, yb in ((-W - G, SC_X, -G, D + G), (SC_X, W + G, -G, SUB_Y0), (SC_X, W + G, GAL, D + G)):
		dim, loc = (xb - xa, yb - ya, 0.3), ((xa + xb) / 2, (ya + yb) / 2)
		piese.append(cub("Placa podea", dim, (loc[0], loc[1], -0.17), NEGRU))
		col.append(cub("Coliziune", dim, (loc[0], loc[1], -0.15), NEGRU))
	_scanduri(piese, -W, W, 0.0, D, 0.0, r, gaura=(SC_X, W, SUB_Y0, GAL))
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
			# scările sunt goale pe dedesubt (stânga: debaraua lui Parry; dreapta: scara spre subsol): treptele sunt doar o
			# placă, în trepte și dedesubt
			jos = max(0.0, sus - GROS_TREAPTA)
			piese += [
				cub("Treapta", (lat, PAS, sus - jos), (xc, y0 + PAS / 2, (sus + jos) / 2), LEMN),
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
		# rampa e o placă (dedesubt e debaraua / scara spre subsol), plus peretele plin dinspre sală și cel din capăt, cu ușa
		yj = SC_Y0 + GROS_TREAPTA * 1.05 * (GAL - SC_Y0) / ET
		col.append(prisma("Coliziune", [(SC_Y0, 0.0), (GAL, ET), (GAL, ET - GROS_TREAPTA * 1.05), (yj, 0.0)], "yz", x0, x1, LEMN))
		xc0, xc1 = (SC_X - 0.05, SC_X + 0.02) if sx > 0 else (-SC_X - 0.02, -SC_X + 0.05)
		col.append(prisma("Coliziune", [(SC_Y0, 0.0), (GAL, ET), (GAL, 0.0)], "yz", xc0, xc1, LEMN))
		_capat_scara(piese, col, sx)
		if sx < 0:
			_debara(piese, lumini, col, r)
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
	# --- pianul cu coadă, sub galeria din dreapta, cu clapele spre sală (orga din colțul din față stătea în drumul spre
	# scară); ceasul cu pendul din colțul din stânga e în ceas_pendul.glb
	_pian(piese, lumini, col, -math.pi / 2, (4.9, 12.0, 0.0))
	_sfesnic(piese, lumini, 4.55, 12.95, 0.0, brate=3, inalt=1.3)
	col.append(cilindru("Coliziune", 0.2, 0.2, 1.6, (4.55, 12.95, 0.8), NEGRU, laturi=6))

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
	_covor(piese, 13.0, 11.7, 3.6, 3.6, p("2a3c3d"), VISINIU, r, pentagrama=1.05, z=z)
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
	"""Camera din stânga de sus: un dormitor gotic. Pat cu baldachin și draperii roșii, dulap sculptat, măsuță de toaletă cu oglindă ovală, biblioteci, un cufăr, dovleci aprinși, un candelabru mic."""
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
	# (pisica neagră nu mai doarme pe pat: stă pe covor și o poți mângâia, e separată: pisica.glb + scenes/pisica.tscn)
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


# ---------------------------------------------------------------------------------------------------------------
# Pisica neagră din dormitor
# ---------------------------------------------------------------------------------------------------------------

def pisica(cale):
	"""Pisica neagră a coven-ului, așezată pe jos cu coada strânsă în fața labelor: zgardă roșie cu clopoțel de aur,
	ochi galbeni cu pupile verticale, mustăți albe. Piese separate, ca să se miște în joc (pisica.gd): `Corp`, `Cap`
	(originea în gât: se uită după tine, își ridică fruntea în mâna ta) cu `Ochi` (strălucesc; originea la mijlocul
	ochilor, se strâng când clipește și când toarce) și `Coada` (originea la rădăcină)."""
	curata()
	blana, roz = NEGRU, p("5e363e")
	piese = [
		# pieptul drept, șoldurile late jos, gâtul
		trunchi("Corp", [((0, 0.05, 0.0), 0.0, 0.0), ((0, 0.05, 0.02), 0.1, 0.12), ((0, 0.04, 0.08), 0.115, 0.13),
			((0, 0.02, 0.15), 0.09, 0.1), ((0, -0.01, 0.22), 0.07, 0.075), ((0, -0.025, 0.27), 0.055, 0.058),
			((0, -0.03, 0.31), 0.042, 0.045)], blana, laturi=10),
		inel("Zgarda", 0.056, 0.009, (0, -0.028, 0.272), ROSU, segmente=12),
		sfera("Clopotel", 0.014, (0, -0.088, 0.258), AUR, segmente=8, inele=5),
		cub("Gura clopotel", (0.016, 0.004, 0.003), (0, -0.101, 0.254), NEGRU),
	]
	for s in (-1, 1):
		piese += [
			sfera("Sold", 0.07, (s * 0.075, 0.07, 0.07), blana, scara=(0.75, 1.15, 1.0), segmente=8, inele=6),
			os_intre("Picior fata", (s * 0.035, -0.06, 0.2), (s * 0.035, -0.088, 0.025), 0.02, blana, laturi=6),
			sfera("Laba fata", 0.026, (s * 0.035, -0.098, 0.016), blana, scara=(1.0, 1.3, 0.62), segmente=8, inele=5),
			sfera("Laba spate", 0.028, (s * 0.085, -0.03, 0.014), blana, scara=(0.9, 1.7, 0.5), segmente=8, inele=5),
		]
	uneste(piese, "Corp")

	cap, ochi = [], []
	cap += [
		sfera("Cap", 0.062, (0, -0.055, 0.345), blana, scara=(1.12, 1.0, 0.92), segmente=10, inele=7),
		sfera("Bot", 0.026, (0, -0.108, 0.325), blana, scara=(1.25, 0.8, 0.75), segmente=8, inele=5),
		sfera("Barbie", 0.015, (0, -0.095, 0.305), blana, segmente=6, inele=4),
		sfera("Nas", 0.008, (0, -0.127, 0.335), roz, scara=(1.3, 0.7, 0.8), segmente=6, inele=4),
	]
	for s in (-1, 1):
		cap += [
			sfera("Obraz", 0.028, (s * 0.034, -0.085, 0.325), blana, segmente=8, inele=5),
			prisma("Ureche", [(s * 0.02, 0.385), (s * 0.068, 0.37), (s * 0.055, 0.445)], "xz", -0.07, -0.045, blana),
			prisma("Ureche interior", [(s * 0.029, 0.388), (s * 0.06, 0.378), (s * 0.051, 0.428)], "xz", -0.077, -0.07, roz),
		]
		for k in range(3):  # mustățile
			cap.append(os_intre("Mustata", (s * 0.022, -0.121, 0.323), (s * 0.115, -0.128 + k * 0.014, 0.338 - k * 0.016), 0.0015, OS,
				laturi=3))
		ochi += [
			sfera("Ochi", 0.015, (s * 0.026, -0.108, 0.353), OCHI_PISICA, scara=(1.1, 0.45, 1.0), segmente=8, inele=6),
			cub("Pupila", (0.004, 0.004, 0.02), (s * 0.026, -0.117, 0.353), NEGRU),
		]
	ob_cap = uneste(cap, "Cap", (0, -0.04, 0.3))
	_parinte(uneste(ochi, "Ochi", (0, -0.108, 0.353)), ob_cap)

	# coada: din spate, pe lângă șold, apoi strânsă în fața labelor
	uneste([trunchi("Coada", [((0, 0.12, 0.03), 0.022, 0.022), ((0.08, 0.125, 0.02), 0.02, 0.02), ((0.135, 0.06, 0.018), 0.019, 0.019),
		((0.135, -0.03, 0.018), 0.017, 0.017), ((0.1, -0.115, 0.018), 0.016, 0.016), ((0.04, -0.158, 0.02), 0.014, 0.014),
		((-0.02, -0.162, 0.022), 0.011, 0.011), ((-0.055, -0.148, 0.026), 0.0, 0.0)], blana, laturi=6, ref=(0, 0, 1))],
		"Coada", (0, 0.11, 0.03))
	exporta(os.path.join(cale, "pisica.glb"))


def _plafon_debara(y):
	"""Cât de sus e dedesubtul treptelor din stânga (tavanul debaralei) la `y` (cel mai jos punct al treptei de acolo)."""
	k = min(max(int((y - SC_Y0) / PAS), 0), TREPTE - 1)
	return (k + 1) * 0.2 - GROS_TREAPTA


def _panza(piese, colt, spre_a, spre_b, raza=0.35, fire=5):
	"""Pânză de păianjen într-un colț: fire care pleacă din `colt` între direcțiile `spre_a` și `spre_b`, plus două arce."""
	cx, cy, cz = colt
	capete = []
	for k in range(fire):
		f = k / (fire - 1)
		d = [spre_a[i] * (1 - f) + spre_b[i] * f for i in range(3)]
		lung = math.sqrt(sum(v * v for v in d)) or 1.0
		d = [v / lung for v in d]
		capete.append(d)
		piese.append(os_intre("Panza paianjen", colt, (cx + d[0] * raza, cy + d[1] * raza, cz + d[2] * raza), 0.003, OS, laturi=3))
	for arc in (0.45, 0.8):
		for a, b in zip(capete, capete[1:]):
			pa = (cx + a[0] * raza * arc, cy + a[1] * raza * arc, cz + a[2] * raza * arc)
			pb = (cx + b[0] * raza * arc, cy + b[1] * raza * arc, cz + b[2] * raza * arc)
			piese.append(os_intre("Panza paianjen", pa, pb, 0.0025, OS, laturi=3))


def _matura_veche(piese, jos, sus):
	"""Mătură de nuiele rezemată: coada de la paie (`jos`) la vârf (`sus`)."""
	jos, sus = Vector(jos), Vector(sus)
	d = (sus - jos).normalized()
	piese.append(os_intre("Coada matura", tuple(jos + d * 0.3), tuple(sus), 0.015, LEMN_DESCHIS, laturi=5))
	piese.append(trunchi("Paie matura", [(tuple(jos), 0.09, 0.05), (tuple(jos + d * 0.32), 0.03, 0.025)], AUR, laturi=8))
	piese.append(trunchi("Legatura matura", [(tuple(jos + d * 0.25), 0.04, 0.03), (tuple(jos + d * 0.29), 0.035, 0.028)], NEGRU,
		laturi=8))


def _soldat(piese, x, y, z, culoare, cazut=False):
	"""Soldățel de jucărie (de plumb vopsit): corp, cap, chipiu înalt, pușca."""
	c = []
	c += [
		cilindru("Soldat", 0.012, 0.014, 0.05, (0, 0, 0.025), culoare, laturi=6),
		cilindru("Soldat", 0.008, 0.008, 0.03, (0, 0, -0.012), NEGRU, laturi=5),
		sfera("Cap soldat", 0.01, (0, 0, 0.06), p("a56850"), segmente=6, inele=4),
		cilindru("Chipiu", 0.01, 0.011, 0.024, (0, 0, 0.078), NEGRU, laturi=6),
		cub("Pusca", (0.004, 0.004, 0.06), (0.015, 0, 0.045), NEGRU),
	]
	_muta(c, (0, math.pi / 2, 0) if cazut else (0, 0, 0), (x, y, z + (0.012 if cazut else 0.027)))
	piese += c


def _capat_scara(piese, col, sx):
	"""Peretele din capătul de sus al scării (y = GAL), sub galerie, cu golul unei uși mici lângă vang (ușile sunt
	separate, usa_debara.glb): în stânga (sx = -1) debaraua lui Parry, în dreapta (sx = 1) scara spre subsol.
	Pe fața dinspre galerie: lambriul, pervazul ușii, pragul."""
	xa, xb = (-W, -SC_X + 0.05) if sx < 0 else (SC_X - 0.05, W)
	ua, ub = sorted((sx * DEB_X0, sx * DEB_X1))
	zp, y0, y1 = ET - 0.32, GAL, GAL + 0.1
	for a, b, z0, z1 in ((xa, ua, 0.0, zp), (ub, xb, 0.0, zp), (ua, ub, DEB_H, zp)):
		dim, loc = (b - a, y1 - y0, z1 - z0), ((a + b) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
		piese.append(cub("Perete capat scara", dim, loc, VISINIU))
		col.append(cub("Coliziune", dim, loc, VISINIU))
	for a, b in ((xa, ua - 0.07), (ub + 0.07, xb)):
		if b - a > 0.3:
			_lambriu(piese, a + (0.1 if a == -W else 0.0), b - (0.1 if b == W else 0.0), y1, 1)
	piese += [
		cub("Pervaz usa mica", (0.07, 0.04, DEB_H + 0.07), (ua - 0.035, y1 + 0.02, (DEB_H + 0.07) / 2), LEMN),
		cub("Pervaz usa mica", (0.07, 0.04, DEB_H + 0.07), (ub + 0.035, y1 + 0.02, (DEB_H + 0.07) / 2), LEMN),
		cub("Pervaz usa mica", (ub - ua + 0.14, 0.04, 0.07), ((ua + ub) / 2, y1 + 0.02, DEB_H + 0.035), LEMN),
		cub("Prag usa mica", (ub - ua, 0.12, 0.02), ((ua + ub) / 2, (y0 + y1) / 2, 0.01), LEMN_DESCHIS),
	]


def _debara(piese, lumini, col, r):
	"""Debaraua de sub scara din stânga (owner 12.10), camera lui Parry Hotter: x între -W și -SC_X, y între SC_Y0 și GAL,
	tavanul = dedesubtul treptelor (în trepte). Ușa (`usa_debara.glb`, separată) e în peretele din capătul scării, sub
	galerie (_capat_scara), deci intri cu spatele la galerie. Înăuntru: patul îngust lângă perete, lada cu lumânarea
	de lângă ușă, rafturile cu jucăriile lui, iar în partea joasă găleata cu mopul, mături vechi, cutii, cizme, pânze."""
	x0, x1 = -W, -SC_X

	# --- patul îngust, lipit de peretele sălii, și patura mototolită (pe lângă el, culoarul de la ușă)
	bx0, bx1, by0, by1 = x0 + 0.02, x0 + 0.82, 7.75, 9.5
	bxm, bym = (bx0 + bx1) / 2, (by0 + by1) / 2
	piese += [
		cub("Rama pat debara", (bx1 - bx0, by1 - by0, 0.08), (bxm, bym, 0.27), LEMN),
		cub("Saltea debara", (bx1 - bx0 - 0.04, by1 - by0 - 0.05, 0.09), (bxm, bym, 0.355), p("7e8d87")),
		cub("Pata saltea", (0.22, 0.3, 0.004), (bxm + 0.12, by0 + 0.3, 0.401), p("7a7b59"), rot=(0, 0, 0.4)),
		sfera("Perna debara", 0.2, (bxm, by1 - 0.22, 0.44), p("83b3b0"), scara=(1.5, 0.75, 0.32), segmente=8, inele=5),
		cub("Patura debara", (0.5, 1.15, 0.035), (bx0 + 0.3, bym + 0.2, 0.418), ROSU_INCHIS, rot=(0, -0.06, 0)),
		cub("Patura debara", (0.16, 1.1, 0.07), (bx0 + 0.1, bym + 0.2, 0.44), ROSU_INCHIS),
		cub("Dunga patura", (0.5, 0.05, 0.004), (bx0 + 0.3, bym - 0.3, 0.437), AUR_INCHIS, rot=(0, -0.06, 0)),
		cub("Dunga patura", (0.5, 0.05, 0.004), (bx0 + 0.3, bym + 0.7, 0.437), AUR_INCHIS, rot=(0, -0.06, 0)),
	]
	for x in (bx0 + 0.04, bx1 - 0.04):
		for y in (by0 + 0.04, by1 - 0.04):
			piese.append(cub("Picior pat debara", (0.05, 0.05, 0.23), (x, y, 0.115), LEMN))
	col.append(cub("Coliziune", (bx1 - bx0, by1 - by0, 0.42), (bxm, bym, 0.21), LEMN))
	# scrisoarea pe pat: plic de pergament cu sigiliu roșu
	piese += [
		cub("Plic", (0.16, 0.11, 0.004), (bx0 + 0.22, by1 - 0.55, 0.44), AUR, rot=(0, 0, 0.5)),
		cilindru("Sigiliu", 0.014, 0.014, 0.004, (bx0 + 0.22, by1 - 0.55, 0.444), ROSU, laturi=8),
	]

	# --- lada de la capul patului (lângă ușă), cu lumânarea (singura lumină) și un teanc de cărți
	lx, ly, lz = x0 + 0.24, GAL - 0.27, 0.36
	piese.append(cub("Lada debara", (0.4, 0.4, lz), (lx, ly, lz / 2), LEMN_DESCHIS))
	for z in (0.09, 0.27):
		piese.append(cub("Sipca lada", (0.41, 0.41, 0.03), (lx, ly, z), LEMN))
	col.append(cub("Coliziune", (0.4, 0.4, lz), (lx, ly, lz / 2), LEMN))
	piese.append(cilindru("Farfurioara", 0.06, 0.05, 0.012, (lx + 0.06, ly - 0.06, lz + 0.006), OS, laturi=10))
	_lumanare(piese, lumini, lx + 0.06, ly - 0.06, lz + 0.012, inalt=0.11, raza=0.022)
	for k, (cul, gros) in enumerate(((VERDE, 0.04), (ROSU_INCHIS, 0.03), (MOV, 0.035))):
		piese.append(cub("Carte debara", (0.16, 0.22, gros), (lx - 0.08, ly + 0.05, lz + 0.01 + sum(g for _, g in ((VERDE, 0.04),
			(ROSU_INCHIS, 0.03), (MOV, 0.035))[:k]) + gros / 2), cul, rot=(0, 0, 0.1 * (k - 1))))
	piese.append(sfera("Ceara scursa", 0.03, (lx + 0.06, ly - 0.06, lz + 0.013), OS, scara=(1.2, 1.0, 0.15), segmente=6, inele=3))

	# --- rafturile de pe peretele de deasupra patului: jucăriile lui (soldățeii, unul căzut), o cutie de tablă, un borcan
	for z in (1.35, 1.85):
		piese.append(cub("Raft debara", (0.22, 1.1, 0.025), (x0 + 0.11, 9.15, z), LEMN_DESCHIS))
		for y in (8.7, 9.6):
			piese.append(cub("Consola raft", (0.16, 0.025, 0.12), (x0 + 0.08, y, z - 0.07), LEMN))
	for k, y in enumerate((8.75, 8.82, 8.89, 8.96)):
		_soldat(piese, x0 + 0.1, y, 1.3625, (ROSU, VERDE, ROSU, TEAL)[k], cazut=(k == 2))
	piese += [
		cub("Cutie tabla", (0.12, 0.18, 0.07), (x0 + 0.1, 9.3, 1.3975), TEAL),
		cub("Capac tabla", (0.13, 0.19, 0.012), (x0 + 0.1, 9.3, 1.438), AUR_INCHIS),
		cilindru("Borcan", 0.045, 0.045, 0.12, (x0 + 0.1, 9.55, 1.4225), p("438b88"), laturi=8),
		cilindru("Capac borcan", 0.047, 0.047, 0.015, (x0 + 0.1, 9.55, 1.49), NEGRU, laturi=8),
		cilindru("Cutie vopsea", 0.07, 0.07, 0.13, (x0 + 0.1, 8.85, 1.9275), GRI, laturi=10),
		cub("Carpe", (0.15, 0.2, 0.06), (x0 + 0.1, 9.25, 1.8925), p("7a7b59"), rot=(0, 0, 0.2)),
		cub("Cutie pantofi", (0.18, 0.28, 0.12), (x0 + 0.1, 9.6, 1.9225), AUR),
	]
	# hanoracul uriaș (moștenit) atârnat într-un cui pe peretele dinspre sală (vangul), în fața patului
	hy = 8.45
	piese += [
		cilindru("Cui", 0.006, 0.006, 0.06, (x1 - 0.03, hy, 2.05), NEGRU, laturi=4, rot=(0, math.pi / 2, 0)),
		cub("Hanorac", (0.06, 0.55, 0.7), (x1 - 0.06, hy, 1.68), p("5e5356")),
		cub("Maneca hanorac", (0.05, 0.12, 0.6), (x1 - 0.07, hy - 0.32, 1.6), p("5e5356"), rot=(-0.12, 0, 0)),
		cub("Maneca hanorac", (0.05, 0.12, 0.6), (x1 - 0.07, hy + 0.32, 1.6), p("5e5356"), rot=(0.12, 0, 0)),
		cub("Buzunar hanorac", (0.01, 0.3, 0.14), (x1 - 0.095, hy, 1.5), p("48313b")),
		sfera("Gluga hanorac", 0.16, (x1 - 0.07, hy, 2.0), p("5e5356"), scara=(0.3, 1.0, 0.8), segmente=8, inele=5),
	]

	# --- partea joasă, spre fața scării: găleata cu mopul, mături vechi, cutii, cizme, o cutie de vopsea
	gx, gy = x1 - 0.32, 6.45
	piese += [
		cilindru("Galeata", 0.13, 0.15, 0.28, (gx, gy, 0.14), GRI, laturi=10),
		cilindru("Apa galeata", 0.135, 0.135, 0.01, (gx, gy, 0.24), p("5b6d4e"), laturi=10),
		inel("Toarta galeata", 0.14, 0.008, (gx, gy, 0.3), NEGRU, segmente=10),
	]
	piese.append(os_intre("Coada mop", (gx, gy, 0.2), (x0 + 0.05, gy - 0.5, _plafon_debara(gy - 0.5) - 0.08), 0.015, LEMN_DESCHIS,
		laturi=5))
	for k in range(7):
		u = k * math.tau / 7
		piese.append(os_intre("Mop", (gx, gy, 0.24), (gx + math.cos(u) * 0.1, gy + math.sin(u) * 0.1, 0.2), 0.018, p("7e8d87"), laturi=4))
	for y in (5.4, 5.75):
		_matura_veche(piese, (x0 + 0.42, y, 0.02), (x0 + 0.04, y + 0.12, _plafon_debara(y) - 0.08))
	cutii = [((0.5, 0.45, 0.38), (x0 + 0.3, 4.45, 0.19), 0.08), ((0.38, 0.36, 0.28), (x0 + 0.3, 4.4, 0.52), -0.25),
		((0.32, 0.3, 0.26), (x1 - 0.25, 3.75, 0.13), 0.35), ((0.42, 0.34, 0.3), (x0 + 0.28, 3.6, 0.15), 0.0)]
	for dim, loc, u in cutii:
		piese.append(cub("Cutie carton", dim, loc, AUR, rot=(0, 0, u)))
		piese.append(cub("Banda cutie", (dim[0] * 0.25, dim[1] + 0.004, 0.006), (loc[0], loc[1], loc[2] + dim[2] / 2 + 0.002), AUR_INCHIS,
			rot=(0, 0, u)))
		col.append(cub("Coliziune", dim, loc, AUR, rot=(0, 0, u)))
	piese += [
		cilindru("Cutie vopsea", 0.09, 0.09, 0.18, (x1 - 0.3, 5.0, 0.09), p("7e8d87"), laturi=10),
		cilindru("Prelingere vopsea", 0.092, 0.092, 0.05, (x1 - 0.3, 5.0, 0.155), VERDE, laturi=10),
	]
	for k, y in enumerate((6.85, 6.68)):  # cizmele de cauciuc, una culcată
		if k == 0:
			piese += [
				cilindru("Cizma", 0.05, 0.05, 0.28, (x1 - 0.12, y, 0.14), NEGRU, laturi=8),
				cub("Talpa cizma", (0.1, 0.26, 0.05), (x1 - 0.12, y - 0.06, 0.025), NEGRU),
			]
		else:
			piese += [
				cilindru("Cizma", 0.05, 0.05, 0.28, (x1 - 0.2, y, 0.05), NEGRU, laturi=8, rot=(0, math.pi / 2, 0.3)),
				cub("Talpa cizma", (0.1, 0.26, 0.05), (x1 - 0.06, y - 0.02, 0.05), NEGRU, rot=(0, 0, 0.3)),
			]
	# pânze de păianjen în colțurile de sus (sub trepte) și jos, lângă perete
	_panza(piese, (x0 + 0.01, GAL - 0.02, _plafon_debara(GAL - 0.1) - 0.02), (0, -1, 0), (0, 0, -1), raza=0.45)
	_panza(piese, (x1 - 0.01, GAL - 0.02, _plafon_debara(GAL - 0.1) - 0.02), (0, -1, 0), (0, 0, -1), raza=0.35)
	_panza(piese, (x0 + 0.01, 3.2, _plafon_debara(3.2) - 0.02), (1, 0, 0), (0, 1, 0), raza=0.3)
	_panza(piese, (x0 + 0.01, 7.6, _plafon_debara(7.6) - 0.02), (1, 0, 0), (0, 0, -1), raza=0.4)
	# un păianjen pe perete, deasupra cizmelor
	piese.append(sfera("Paianjen", 0.018, (x0 + 0.015, 7.3, 1.25), NEGRU, scara=(0.6, 1.0, 1.2), segmente=6, inele=4))
	for k in range(4):
		for s in (-1, 1):
			piese.append(os_intre("Picior paianjen", (x0 + 0.015, 7.3, 1.25 + (k - 1.5) * 0.008),
				(x0 + 0.012, 7.3 + s * 0.035, 1.25 + (k - 1.5) * 0.02), 0.0025, NEGRU, laturi=3))


def usa_debara(cale):
	"""Ușa debaralei (owner 12.10): scânduri verticale, Z-ul de întăritură pe spate, grilajul de aerisire sus, butonul.
	Originea = balamaua (jos); ușa merge spre +X, fața spre -Y (în Godot +Z). În conac_interior.tscn sunt două (debaraua
	și subsolul), rotite 180°: fața spre galerie."""
	curata()
	lat, inalt, gros = DEB_X1 - DEB_X0 - 0.02, DEB_H - 0.02, 0.035
	piese = []
	n = 5
	for i in range(n):
		piese.append(cub("Scandura usa", (lat / n - 0.006, gros, inalt), ((i + 0.5) * lat / n, 0, inalt / 2), LEMN_DESCHIS if i % 2 else LEMN))
	# Z-ul pe spate
	for z in (0.3, inalt - 0.3):
		piese.append(cub("Traversa usa", (lat - 0.06, 0.025, 0.1), (lat / 2, gros / 2 + 0.0125, z), LEMN))
	a, b = Vector((0.08, gros / 2 + 0.012, 0.35)), Vector((lat - 0.08, gros / 2 + 0.012, inalt - 0.35))
	piese.append(cub("Diagonala usa", (0.09, 0.022, (b - a).length), tuple((a + b) / 2), LEMN,
		rot=(0, math.atan2(b.x - a.x, b.z - a.z), 0)))
	# grilajul de aerisire: o fantă neagră cu lamele, pe fața din față
	gz = inalt - 0.28
	piese.append(cub("Fanta usa", (0.32, 0.006, 0.14), (lat / 2, -gros / 2 - 0.003, gz), NEGRU))
	for k in range(4):
		piese.append(cub("Lamela", (0.34, 0.012, 0.012), (lat / 2, -gros / 2 - 0.008, gz - 0.054 + k * 0.036), GRI, rot=(0.6, 0, 0)))
	piese.append(cub("Rama fanta", (0.36, 0.01, 0.018), (lat / 2, -gros / 2 - 0.005, gz + 0.08), GRI))
	piese.append(cub("Rama fanta", (0.36, 0.01, 0.018), (lat / 2, -gros / 2 - 0.005, gz - 0.08), GRI))
	# balamalele și butonul (pe ambele fețe)
	for z in (0.25, inalt - 0.25):
		piese.append(cub("Balama", (0.1, 0.006, 0.05), (0.05, -gros / 2 - 0.003, z), NEGRU))
	for s in (-1, 1):
		piese.append(sfera("Buton usa", 0.025, (lat - 0.08, s * (gros / 2 + 0.03), 0.95), AUR, segmente=8, inele=5))
		piese.append(cilindru("Gat buton", 0.008, 0.008, 0.03, (lat - 0.08, s * (gros / 2 + 0.015), 0.95), AUR, laturi=6,
			rot=(math.pi / 2, 0, 0)))
	uneste(piese, "Usa")
	exporta(os.path.join(cale, "usa_debara.glb"))


def parry(cale):
	"""Parry Hotter (owner 12.10), din debaraua de sub scara din stânga: păr negru ciufulit, ochelari rotunzi, cicatricea
	în fulger, puloverul gri prea mare, fularul roșu cu auriu; stă pe marginea patului și citește o carte ținută cu
	amândouă mâinile. Prin casino_oameni.om (OmLaMasa în joc); în conac_interior.tscn e micșorat la 0,82: e un copil."""
	import casino_oameni

	def carte_si_fular(corp):
		c = []
		for s in (-1, 1):
			u = -0.16 * s
			c.append(cub("Coperta", (0.12, 0.175, 0.008), (s * 0.06, 0, s * -u * 0.06 - 0.004), ROSU_INCHIS, rot=(0, u, 0)))
			c.append(cub("Pagini", (0.11, 0.163, 0.014), (s * 0.057, 0, s * -u * 0.057 + 0.007), OS, rot=(0, u, 0)))
			for k in range(3):  # rândurile de text
				c.append(cub("Rand", (0.07, 0.006, 0.002), (s * 0.057, -0.05 + k * 0.05, s * -u * 0.057 + 0.0148), GRI, rot=(0, u, 0)))
		c.append(cilindru("Cotor", 0.01, 0.01, 0.175, (0, 0, -0.004), ROSU_INCHIS, laturi=6, rot=(math.pi / 2, 0, 0)))
		ob = uneste(c, "Carte")
		ob.rotation_euler = (-0.55, 0, 0)
		ob.location = (0, -0.345, 0.885)
		_parinte(ob, corp)
		f = [inel("Fular", 0.072, 0.028, (0, 0.012, 1.11), ROSU, segmente=12)]
		for k in range(6):  # capătul care atârnă pe piept, în dungi
			f.append(cub("Capat fular", (0.07, 0.025, 0.055), (0.045, -0.085 - k * 0.004, 1.06 - k * 0.055), ROSU if k % 2 else AUR,
				rot=(0.08, 0, 0.05)))
		f.append(cub("Franjuri", (0.06, 0.02, 0.03), (0.047, -0.11, 0.725), AUR))
		ob_f = uneste(f, "Fular")
		_parinte(ob_f, corp)

	s = {
		"piele": p("a56850"), "piele_umbra": p("904a40"), "haina": p("7e8d87"), "haina_umbra": p("70706e"), "camasa": p("83b3b0"),
		"stil_haina": "pulover", "pantaloni": p("2a3c3d"), "pantofi": p("5e5356"), "par": NEGRU, "stil_par": "ciufulit",
		"ochelari": "rotunzi", "rama": NEGRU, "cicatrice": p("7b383a"), "slab": 0.6, "gros_brat": 0.8, "nas": 0.85,
		"spranceana": 0.006, "incruntat": -0.05,
		"poza_D": ((-0.2, -0.13, 0.8), (-0.1, -0.33, 0.865)), "poza_S": ((0.2, -0.13, 0.8), (0.1, -0.33, 0.865)),
		"extra": carte_si_fular,
	}
	casino_oameni.om(cale, "parry_hotter", s, 77)


# ---------------------------------------------------------------------------------------------------------------
# Subsolul (owner 12.10): ușa din capătul scării din dreapta (lângă pian) → scara coboară pe sub ea, se schimbă încet
# din conac în catacombe (tapet și lemn → tencuială crăpată și cărămidă → piatră, nișe cu oase și cranii) → coridorul
# catacombelor → camera de tortură, toate sub podeaua sălii. Separat de conac_interior.glb: subsol.glb.
# ---------------------------------------------------------------------------------------------------------------

SUB_X0, SUB_X1 = SC_X + 0.1, W            # puțul scării, sub z = 0 (deasupra e între vang și peretele sălii)
SUB_YT = GAL - 0.45                       # unde începe prima treaptă (până la ușă e un mic palier de lemn)
SUB_PAS, SUB_TREPTE = 0.4, 13             # 40 cm adâncime, 20 cm înălțime → jos la -2,6, la y = SUB_Y0
SUB_PODEST = -0.2 * SUB_TREPTE
COR_Y0, COR_Y1 = 0.8, 2.4                 # coridorul catacombelor, spre -X, de la podest până în camera de tortură
COR_XT = 6.2                              # de aici coboară 8 trepte de piatră, până la x = 3
TOR_X0, TOR_X1, TOR_Y0, TOR_Y1 = -4.6, 2.0, -1.6, 5.0   # camera de tortură
TOR_Z, TOR_TAVAN = -4.2, -1.0
GRINDA_Y, GRINDA_Z = 3.4, -1.25           # grinda de care atârnă cei trei (fața de jos); cârligele coboară până la -1,32
SPANZURATI_X = (-2.5, -1.1, 0.3)
FUNIE_SUS = 2.28                          # în modelul spânzuratului: capătul de sus al frânghiei (deasupra tălpilor)
PIETRE = (PIATRA, PIATRA_INCHISA, GRI, p("5e5356"))


def _z_coridor(x):
	"""Podeaua coridorului la `x` (fața de sus a treptei de acolo)."""
	if x >= COR_XT:
		return SUB_PODEST
	if x <= COR_XT - 3.2:
		return TOR_Z
	return SUB_PODEST - 0.2 * (min(int((COR_XT - x) / 0.4), 7) + 1)


def _tavan_coridor(x):
	return min(-0.4, _z_coridor(x) + 2.35)


def _bloc(lista, nume, x0, x1, y0, y1, z0, z1, cul):
	x0, x1 = sorted((x0, x1))
	y0, y1 = sorted((y0, y1))
	z0, z1 = sorted((z0, z1))
	lista.append(cub(nume, (x1 - x0, y1 - y0, z1 - z0), ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), cul))


def _pe_zid(axa, f, o, u, d, z):
	"""Punctul de pe un zid (vezi _zid) aflat la `u` de-a lungul lui, la `d` în fața lui (spre cameră), la înălțimea `z`."""
	return (u, f - o * d, z) if axa == "x" else (f - o * d, u, z)


def _spre_camera(axa, o):
	"""Unghiul (pentru _craniu, _muta) cu care un obiect făcut cu fața spre -Y privește dinspre zid spre cameră."""
	if axa == "x":
		return math.pi if o < 0 else 0.0
	return math.pi / 2 if o < 0 else -math.pi / 2


def _zid(piese, col, axa, f, o, u0, u1, z0, z1, goluri=(), cul=PIATRA_INCHISA, gros=0.4):
	"""Zid drept, gros de `gros`: `axa` "x" = de-a lungul lui X, cu fața (spre cameră) la y = `f`; "y" = de-a lungul lui Y,
	cu fața la x = `f`. `o` = încotro e zidul față de fața lui (camera e în partea cealaltă). `goluri` = [(u0, u1, z0, z1,
	fund)]: nișe (fund=True: adânci cât zidul minus 8 cm, coliziunea le acoperă) sau treceri (fund=False)."""
	def bloc(lista, nume, a, b, za, zb, d0, d1, c):
		fa, fb = f + o * d0, f + o * d1
		if axa == "x":
			_bloc(lista, nume, a, b, fa, fb, za, zb, c)
		else:
			_bloc(lista, nume, fa, fb, a, b, za, zb, c)
	taieturi = sorted({u0, u1} | {v for g in goluri for v in g[:2] if u0 < v < u1})
	for a, b in zip(taieturi, taieturi[1:]):
		aici = sorted((g for g in goluri if g[0] <= a + 1e-6 and g[1] >= b - 1e-6), key=lambda g: g[2])
		z = z0
		for g in aici + [(a, b, z1, z1, False)]:
			if g[2] - z > 0.005:
				bloc(piese, "Zid", a, b, z, g[2], 0.0, gros, cul)
				bloc(col, "Coliziune", a, b, z, g[2], 0.0, gros, cul)
			if g[4] and g[3] > g[2]:
				bloc(piese, "Fund nisa", a, b, g[2], g[3], gros - 0.08, gros, NEGRU)
				bloc(col, "Coliziune", a, b, g[2], g[3], 0.0, gros, cul)
			z = max(z, g[3])


def _pietre(piese, rs, axa, f, o, u0, u1, zjos, zsus, evita=(), culori=PIETRE):
	"""Pietre neregulate pe fața unui zid (vezi _zid): rânduri de blocuri de 18–30 cm, ieșite puțin spre cameră, doar
	între podea și tavan (`zjos`, `zsus` = funcții de poziția de-a lungul zidului), ocolind dreptunghiurile `evita`."""
	mostre = [u0 + (u1 - u0) * i / 8 for i in range(9)]
	z, zmax = min(zjos(u) for u in mostre) - 0.1, max(zsus(u) for u in mostre)
	while z < zmax:
		h = rs.uniform(0.18, 0.3)
		u = u0 - rs.uniform(0.0, 0.25)
		while u < u1:
			w = rs.uniform(0.25, 0.55)
			a, b, za, zb = max(u, u0) + 0.012, min(u + w, u1) - 0.012, z + 0.012, z + h - 0.012
			uc = (a + b) / 2
			if b - a > 0.08 and zb > zjos(uc) - 0.02 and za < zsus(uc) + 0.02 and \
					not any(a < e[1] and b > e[0] and za < e[3] and zb > e[2] for e in evita):
				t = rs.uniform(0.015, 0.05)
				p0, p1 = _pe_zid(axa, f, o, a, 0.0, za), _pe_zid(axa, f, o, b, t, zb)
				_bloc(piese, "Piatra", p0[0], p1[0], p0[1], p1[1], za, zb, rs.choice(culori))
			u += w
		z += h


def _os_lung(piese, a, b, raza=0.017):
	"""Un os lung (femur): tija și capetele noduroase."""
	piese.append(os_intre("Os", a, b, raza, OS, laturi=5))
	for c in (a, b):
		piese.append(sfera("Capat os", raza * 1.8, c, OS, segmente=6, inele=4))


def _nisa_cu_oase(piese, lumini, rs, axa, f, o, g, lumanare=False):
	"""Ce e într-o nișă `g` (u0, u1, z0, z1): jos, oase lungi stivuite de-a lungul ei și un craniu sau două deasupra;
	sus, cranii și uneori o lumânare. Întoarce flacăra lumânării (sau None)."""
	u0, u1, z0, z1 = g[:4]
	unghi = _spre_camera(axa, o)
	if z1 - z0 > 0.4 and rs.random() < 0.6:
		for strat in range(3):
			for d in (0.1, 0.2, 0.28):
				z = z0 + 0.02 + strat * 0.035
				_os_lung(piese, _pe_zid(axa, f, o, u0 + 0.05, -d, z), _pe_zid(axa, f, o, u1 - 0.05, -d - rs.uniform(-0.03, 0.03), z))
		zc = z0 + 0.13
	else:
		zc = z0
	n = 1 + int(rs.random() < 0.6)
	for i in range(n):
		u = u0 + (u1 - u0) * (i + 0.5) / n + rs.uniform(-0.04, 0.04)
		x, y, z = _pe_zid(axa, f, o, u, -0.16, zc)
		_craniu(piese, x, y, z, rs.uniform(0.9, 1.1), unghi + rs.uniform(-0.4, 0.4))
	if lumanare:
		x, y, z = _pe_zid(axa, f, o, u1 - 0.08, -0.08, zc)
		inalt = rs.uniform(0.06, 0.14)
		_lumanare(piese, lumini, x, y, z, inalt=inalt, raza=0.02)
		piese.append(sfera("Ceara scursa", 0.035, (x, y, z), OS, scara=(1.3, 1.3, 0.2), segmente=6, inele=3))
		return (x, y, z + inalt + 0.03)
	return None


def _zid_cranii(piese, rs, axa, f, o, u0, u1, z0, z1):
	"""Zid de osuar: rânduri de cranii zidite cu fața spre cameră, între ele rânduri de capete de femur."""
	unghi = _spre_camera(axa, o)
	z, rand = z0, 0
	while z < z1 - 0.12:
		if rand % 2 == 0:
			n = int((u1 - u0) / 0.17)
			for i in range(n):
				u = u0 + (u1 - u0) * (i + 0.5) / n
				x, y, zz = _pe_zid(axa, f, o, u, 0.03, z - 0.01)
				_craniu(piese, x, y, zz, rs.uniform(0.92, 1.05), unghi + rs.uniform(-0.15, 0.15))
			z += 0.16
		else:
			n = int((u1 - u0) / 0.075)
			for i in range(n):
				u = u0 + (u1 - u0) * (i + 0.5) / n
				for dz in (0.025, 0.07):
					piese.append(sfera("Capat os", 0.03, _pe_zid(axa, f, o, u, 0.01, z + dz), OS, segmente=6, inele=4))
			z += 0.1
		rand += 1


def _torta(piese, lumini, axa, f, o, u, z):
	"""Torță pe perete: placa și inelul de fier, coada de lemn înclinată spre cameră, smoala și flacăra (`z` = baza
	cozii). Întoarce unde e flacăra (pentru lumina din Godot)."""
	piese.append(cub("Placa torta", (0.12, 0.12, 0.2), _pe_zid(axa, f, o, u, 0.0, z + 0.05), NEGRU))
	piese.append(os_intre("Coada torta", _pe_zid(axa, f, o, u, 0.04, z - 0.2), _pe_zid(axa, f, o, u, 0.2, z + 0.25), 0.025, LEMN, laturi=6))
	piese.append(os_intre("Brat torta", _pe_zid(axa, f, o, u, 0.0, z + 0.06), _pe_zid(axa, f, o, u, 0.13, z + 0.08), 0.012, NEGRU, laturi=4))
	piese.append(os_intre("Smoala", _pe_zid(axa, f, o, u, 0.19, z + 0.22), _pe_zid(axa, f, o, u, 0.215, z + 0.32), 0.04, NEGRU, laturi=6))
	fl = _pe_zid(axa, f, o, u, 0.225, z + 0.42)
	lumini.append(sfera("Flacara torta", 0.07, fl, FLACARA_PORTOCALIE, scara=(1, 1, 1.7), segmente=6, inele=4))
	lumini.append(sfera("Flacara torta", 0.045, (fl[0], fl[1], fl[2] - 0.03), FLACARA, scara=(1, 1, 1.5), segmente=6, inele=4))
	return fl


def _balta(piese, rs, x, y, z, raza):
	"""Baltă de sânge pe jos: câteva pete rotunde suprapuse, închise la margine, cu stropi în jur."""
	for k in range(5):
		u, d = rs.uniform(0, math.tau), rs.uniform(0, raza * 0.5)
		rr = raza * rs.uniform(0.45, 0.8)
		piese.append(cilindru("Balta sange", rr, rr, 0.004 + 0.001 * k, (x + math.cos(u) * d, y + math.sin(u) * d, z + 0.002 + 0.0005 * k),
			ROSU_INCHIS if k < 3 else ROSU, laturi=10))
	for k in range(6):
		u, d = rs.uniform(0, math.tau), raza * rs.uniform(1.0, 1.6)
		piese.append(cilindru("Strop sange", 0.025, 0.025, 0.004, (x + math.cos(u) * d, y + math.sin(u) * d, z + 0.002), ROSU_INCHIS, laturi=6))


def _lant(piese, a, b):
	"""Lanț de fier de la `a` la `b`: zale de 6 cm, una în planul drumului, următoarea întoarsă."""
	a, b = Vector(a), Vector(b)
	n = max(int((b - a).length / 0.05), 1)
	d = (b - a).normalized()
	for i in range(n):
		c = a + (b - a) * (i + 0.5) / n
		za = _inel_vertical("Za", 0.03, 0.007, (0, 0, 0), NEGRU)
		rot = d.to_track_quat('Z', 'Y').to_matrix().to_4x4()
		if i % 2:
			rot = rot @ Matrix.Rotation(math.pi / 2, 4, 'Z')
		za.data.transform(Matrix.Translation(c) @ rot)
		piese.append(za)


def _scara_subsol(piese, lumini, col, rs):
	"""Puțul de sub scara din dreapta: palierul de lângă ușă, 13 trepte care coboară spre fața conacului (sus lemn cu
	covorul tocit, la mijloc lemn rupt peste piatră, jos piatră), pereții (tapet → tencuială crăpată și cărămidă →
	piatră), podestul de jos cu grinzile podelei sălii deasupra și prima nișă cu un craniu. Întoarce flăcările."""
	x0, x1 = SC_X, SUB_X1
	flacari = {}
	# palierul de la ușă și treptele (blocuri pline până jos, să nu se vadă pe sub ele)
	_bloc(piese, "Palier", x0, x1, SUB_YT, GAL + 0.05, -3.0, 0.0, LEMN)
	for k in range(SUB_TREPTE):
		ya, yb = SUB_YT - (k + 1) * SUB_PAS, SUB_YT - k * SUB_PAS
		sus = -0.2 * (k + 1)
		if k < 5:
			_bloc(piese, "Treapta", x0, x1, ya, yb, -3.0, sus, LEMN)
			_bloc(piese, "Bot treapta", x0, x1, ya - 0.02, ya + 0.03, sus - 0.03, sus + 0.005, LEMN_DESCHIS)
			if k < 4:  # covorul roșu de pe scara sălii, tocit, se termină în franjuri
				_bloc(piese, "Covor scara", (x0 + x1) / 2 - 0.45, (x0 + x1) / 2 + 0.45, ya, yb, sus, sus + 0.012, ROSU if k < 3 else ROSU_INCHIS)
				_bloc(piese, "Covor scara", (x0 + x1) / 2 - 0.45, (x0 + x1) / 2 + 0.45, yb - 0.012, yb, sus, sus + 0.2, ROSU)
			if k == 3:
				for i in range(9):
					xf = (x0 + x1) / 2 - 0.4 + i * 0.1
					_bloc(piese, "Franjuri", xf - 0.006, xf + 0.006, ya - 0.06, ya, sus, sus + 0.006, ROSU_INCHIS)
		else:
			_bloc(piese, "Treapta", x0, x1, ya, yb, -3.0, sus, PIATRA if k % 2 else PIATRA_INCHISA)
			if k < 8:  # scânduri rupte rămase peste piatră
				lung = rs.uniform(0.5, 1.0)
				xs = rs.uniform(x0, x1 - lung)
				_bloc(piese, "Scandura rupta", xs, xs + lung, ya + 0.02, yb - 0.02, sus, sus + 0.025, LEMN)
	col.append(prisma("Coliziune", [(GAL + 0.1, 0.0), (SUB_YT + 0.2, 0.0), (SUB_Y0 + 0.2, SUB_PODEST), (SUB_Y0 + 0.2, -3.0),
		(GAL + 0.1, -3.0)], "yz", x0, x1, LEMN))

	def podea(y):
		return 0.0 if y >= SUB_YT else -0.2 * (min(int((SUB_YT - y) / SUB_PAS), SUB_TREPTE - 1) + 1)

	# podestul de jos: lespezi, deasupra lui grinzile podelei sălii
	_bloc(piese, "Podest", x0, x1, 0.4, SUB_Y0, -3.0, SUB_PODEST - 0.01, PIATRA_INCHISA)
	_bloc(col, "Coliziune", x0, x1, 0.4, SUB_Y0 + 0.2, -3.0, SUB_PODEST, PIATRA)
	for i in range(4):
		for j in range(3):
			ya = 0.8 + i * 0.9 + (0.45 if j % 2 else 0.0)
			_bloc(piese, "Lespede", x0 + 0.1 + j * 0.5, x0 + 0.58 + j * 0.5, ya, min(ya + 0.86, SUB_Y0 - 0.02), SUB_PODEST - 0.01,
				SUB_PODEST + 0.004, rs.choice((PIATRA, GRI, PIATRA_INCHISA)))
	for y in (1.0, 1.9, 2.8, 3.7):
		_bloc(piese, "Grinda podea", x0, x1, y - 0.1, y + 0.1, -0.55, -0.32, LEMN)

	# pereții: estul (peretele sălii, x = 9) cu nișa de pe podest; vestul (x = SUB_X0) cu trecerea spre coridor
	nisa_podest = (2.7, 3.25, SUB_PODEST + 0.75, SUB_PODEST + 1.2, True)
	for y0, y1, cul in ((SUB_Y0 + 2.85, GAL + 0.1, VISINIU), (SUB_Y0 + 1.25, SUB_Y0 + 2.85, GRI), (0.4, SUB_Y0 + 1.25, PIATRA_INCHISA)):
		_zid(piese, col, "y", SUB_X1, 1, y0, y1, -3.0, 0.0, [nisa_podest] if y0 < 1 else [], cul=cul, gros=0.3)
		_zid(piese, col, "y", SUB_X0, -1, y0, y1, -3.0, 0.0, [(COR_Y0, COR_Y1, SUB_PODEST, -0.4, False)] if y0 < 1 else [], cul=cul,
			gros=0.3)
	_zid(piese, col, "x", 0.8, -1, SUB_X0, x1 + 0.3, -3.0, -0.32, cul=PIATRA_INCHISA, gros=0.4)
	# sus: tapetul conacului, cu brâul de lemn care coboară odată cu scara și un portret strâmb
	for xf, o in ((SUB_X1, 1), (SUB_X0, -1)):
		y_a, y_b = GAL, SUB_Y0 + 2.85
		piese.append(os_intre("Brau scara", (xf - o * 0.03, y_a, 0.9), (xf - o * 0.03, y_b, podea(y_b) + 0.9), 0.03, LEMN_DESCHIS, laturi=4))
		piese.append(os_intre("Plinta scara", (xf - o * 0.02, y_a, 0.06), (xf - o * 0.02, y_b, podea(y_b) + 0.06), 0.04, NEGRU, laturi=4))
	c, l = _tablou(rs, 0.5, 0.65, stil=1)
	_muta(c + l, (0, 0.14, -math.pi / 2), (SUB_X1 - 0.01, 7.95, 0.25))
	piese += c
	lumini += l
	# la mijloc: tencuiala crăpată, pe alocuri căzută, cu cărămida dedesubt
	for xf, o in ((SUB_X1, 1), (SUB_X0, -1)):
		for _ in range(5):
			yc = rs.uniform(SUB_Y0 + 1.35, SUB_Y0 + 2.75)
			zc = podea(yc) + rs.uniform(0.3, 1.6)
			for i in range(rs.randint(3, 6)):
				for j in range(rs.randint(2, 4)):
					yb_ = yc + (j - 1.5) * 0.23 + (0.11 if i % 2 else 0.0)
					p0 = (xf - o * 0.005, yb_ - 0.105, zc + i * 0.075)
					_bloc(piese, "Caramida", xf, xf - o * 0.025, p0[1], p0[1] + 0.21, p0[2], p0[2] + 0.065, rs.choice((ROSU_INCHIS, p("904a40"), VISINIU)))
		for _ in range(4):
			a = (xf - o * 0.004, rs.uniform(SUB_Y0 + 1.3, SUB_Y0 + 2.8), 0.0)
			a = (a[0], a[1], podea(a[1]) + rs.uniform(0.4, 1.8))
			for _ in range(3):
				b = (a[0], a[1] + rs.uniform(-0.25, 0.25), a[2] - rs.uniform(0.1, 0.3))
				piese.append(os_intre("Crapatura", a, b, 0.005, NEGRU, laturi=3))
				a = b
	# jos: piatra goală
	for xf, o in ((SUB_X1, 1), (SUB_X0, -1)):
		evita = [(COR_Y0, COR_Y1, SUB_PODEST - 0.1, -0.3)] if o < 0 else [(nisa_podest[0] - 0.03, nisa_podest[1] + 0.03, nisa_podest[2] - 0.03,
			nisa_podest[3] + 0.03)]
		_pietre(piese, rs, "y", xf, o, 0.8, SUB_Y0 + 1.25, podea, lambda y: -0.32 if y < SUB_Y0 else min(-0.02, podea(y) + 3.2), evita)
	_pietre(piese, rs, "x", 0.8, -1, SUB_X0, x1, lambda x: SUB_PODEST, lambda x: -0.32)
	flacari["SubsolPodest"] = _nisa_cu_oase(piese, lumini, rs, "y", SUB_X1, 1, nisa_podest, lumanare=True)
	# aplica cu lumânare pe peretele sălii, sus
	yl = 9.0
	zl = podea(yl) + 1.45
	piese += [
		cub("Placa aplica", (0.03, 0.1, 0.16), (SUB_X1 - 0.015, yl, zl - 0.05), NEGRU),
		os_intre("Brat aplica", (SUB_X1 - 0.02, yl, zl - 0.06), (SUB_X1 - 0.15, yl, zl - 0.02), 0.01, NEGRU, laturi=4),
		cilindru("Cupa aplica", 0.04, 0.03, 0.03, (SUB_X1 - 0.15, yl, zl), NEGRU, laturi=8),
	]
	_lumanare(piese, lumini, SUB_X1 - 0.15, yl, zl + 0.015, inalt=0.12)
	flacari["SubsolScara"] = (SUB_X1 - 0.15, yl, zl + 0.16)
	# pânzele de păianjen se înmulțesc spre jos
	_panza(piese, (SUB_X1 - 0.01, 0.81, -0.56), (0, 1, 0), (-1, 0, 0), raza=0.4)
	_panza(piese, (SUB_X0 + 0.01, SUB_Y0 - 0.1, -0.56), (0, -1, 0), (1, 0, 0), raza=0.3)
	_panza(piese, (SUB_X1 - 0.01, SUB_Y0 + 1.0, _plafon_dreapta(SUB_Y0 + 1.0) - 0.02), (0, -1, 0), (0, 0, -1), raza=0.35)
	return flacari


def _plafon_dreapta(y):
	"""Dedesubtul treptelor scării din dreapta la `y` (ca _plafon_debara)."""
	return _plafon_debara(y)


def _coridor(piese, lumini, col, rs):
	"""Coridorul catacombelor, de la podest spre -X până în camera de tortură: coboară 8 trepte de piatră, tavanul
	boltit în trepte, arcuri de piatră, nișe cu oase și cranii în ambii pereți (unele cu lumânări), iar la capăt pereții
	sunt zidiți din cranii. Întoarce flăcările."""
	flacari = {}
	xa, xb = TOR_X1, SUB_X0
	# podeaua: treptele și lespezile
	_bloc(piese, "Podea coridor", COR_XT, xb, COR_Y0, COR_Y1, -3.0, SUB_PODEST - 0.01, PIATRA_INCHISA)
	for k in range(8):
		xk0, xk1 = COR_XT - (k + 1) * 0.4, COR_XT - k * 0.4
		sus = SUB_PODEST - 0.2 * (k + 1)
		_bloc(piese, "Treapta piatra", xk0, xk1, COR_Y0, COR_Y1, -4.6, sus, PIATRA if k % 2 else PIATRA_INCHISA)
		_bloc(piese, "Bot treapta", xk0 - 0.015, xk0 + 0.04, COR_Y0 + 0.05, COR_Y1 - 0.05, sus - 0.03, sus + 0.004, GRI)
	_bloc(piese, "Podea coridor", xa, COR_XT - 3.2, COR_Y0, COR_Y1, -4.6, TOR_Z - 0.01, PIATRA_INCHISA)
	for x in (6.4, 6.9, 7.3):
		_bloc(piese, "Lespede", x - 0.24, x + 0.22, COR_Y0 + 0.05, COR_Y1 - 0.05, SUB_PODEST - 0.01, SUB_PODEST + 0.004, rs.choice((PIATRA, GRI)))
	col.append(prisma("Coliziune", [(xb, SUB_PODEST), (COR_XT + 0.2, SUB_PODEST), (COR_XT - 3.0, TOR_Z), (COR_XT - 3.0, -4.6), (xb, -4.6)],
		"xz", COR_Y0, COR_Y1, PIATRA))
	_bloc(col, "Coliziune", xa - 0.5, COR_XT - 3.0, COR_Y0, COR_Y1, -4.6, TOR_Z, PIATRA)
	# tavanul în trepte, boltit pe margini
	x = xb
	while x > xa + 0.01:
		x2 = max(x - 0.4, xa)
		zt = _tavan_coridor((x + x2) / 2)
		_bloc(piese, "Tavan coridor", x2, x, COR_Y0 - 0.1, COR_Y1 + 0.1, zt, zt + 0.25, PIATRA_INCHISA)
		for yb_, s in ((COR_Y0, 1), (COR_Y1, -1)):
			piese.append(cub("Bolta", (x - x2, 0.32, 0.32), ((x + x2) / 2, yb_, zt), PIATRA_INCHISA, rot=(math.pi / 4, 0, 0)))
		x = x2
	# arcurile de piatră (pilaștri și arc pe tavan)
	for xr in (7.35, 5.95, 4.55, 3.3, 2.15):
		zf, zt = _z_coridor(xr - 0.13), _tavan_coridor(xr)
		for yb_, s in ((COR_Y0, 1), (COR_Y1, -1)):
			_bloc(piese, "Pilastru", xr - 0.13, xr + 0.13, yb_, yb_ + s * 0.09, zf, zt, PIATRA)
		_bloc(piese, "Arc", xr - 0.13, xr + 0.13, COR_Y0, COR_Y1, zt - 0.14, zt, PIATRA)
	# pereții: nișe între arcuri (jos și sus); ultima porțiune, zid de cranii
	nise = []
	for u0, u1 in ((6.3, 7.0), (4.95, 5.6), (3.55, 4.2)):
		zf = _z_coridor((u0 + u1) / 2)
		nise.append((u0, u1, zf + 0.3, zf + 0.78, True))
		nise.append((u0, u1, zf + 1.02, zf + 1.45, True))
	for f, o in ((COR_Y0, -1), (COR_Y1, 1)):
		_zid(piese, col, "x", f, o, xa, xb, -4.6, -0.3, nise)
		evita = [(g[0] - 0.03, g[1] + 0.03, g[2] - 0.03, g[3] + 0.03) for g in nise] + [(xa, 3.15, -5, 0)]
		_pietre(piese, rs, "x", f, o, xa, xb, _z_coridor, _tavan_coridor, evita)
		_zid_cranii(piese, rs, "x", f, o, xa + 0.3, 3.15, TOR_Z + 0.15, _tavan_coridor(2.5) - 0.05)
		for i, g in enumerate(nise):
			fl = _nisa_cu_oase(piese, lumini, rs, "x", f, o, g, lumanare=(f, i) in ((COR_Y0, 1), (COR_Y1, 4)))
			if fl:
				flacari["CoridorLumanare%d" % (1 if f == COR_Y0 else 2)] = fl
	# torța, pe pilastrul din mijloc (peretele din nord)
	flacari["CoridorTorta"] = _torta(piese, lumini, "x", COR_Y1 - 0.09, 1, 4.55, _z_coridor(4.55) + 1.35)
	# oase și cranii căzute pe jos, pânze de păianjen
	for _ in range(6):
		x = rs.uniform(xa + 0.4, xb - 0.3)
		y = rs.choice((COR_Y0 + 0.15, COR_Y1 - 0.15))
		z = _z_coridor(x)
		u = rs.uniform(0, math.pi)
		_os_lung(piese, (x - math.cos(u) * 0.2, y - math.sin(u) * 0.06, z + 0.02), (x + math.cos(u) * 0.2, y + math.sin(u) * 0.06, z + 0.02), 0.015)
	_craniu(piese, 6.65, COR_Y1 - 0.2, SUB_PODEST, 1.0, 2.4)
	_craniu(piese, 2.7, COR_Y0 + 0.25, TOR_Z, 0.95, -0.7)
	for x in (6.0, 4.0):
		zt = _tavan_coridor(x)
		_panza(piese, (x, COR_Y0 + 0.01, zt - 0.05), (1, 0, 0), (0, 1, -0.6), raza=0.32)
		_panza(piese, (x - 0.6, COR_Y1 - 0.01, zt - 0.05), (-1, 0, 0), (0, -1, -0.6), raza=0.28)
	return flacari


def _masa_tortura(piese, lumini, rs, x0, x1, y0, y1):
	"""Masa de lucru de lângă peretele din vest: blatul gros pătat de sânge, raftul de jos cu o găleată, iar pe blat
	uneltele (fierăstrău, clește, ciocan, cuțite, satâr, menghina de degete, burghiul, dalta), o cârpă, un castron cu
	dinți, un craniu și o lumânare. Întoarce flacăra."""
	z = TOR_Z + 0.88
	_bloc(piese, "Blat", x0, x1, y0, y1, z - 0.08, z, LEMN)
	for x in (x0 + 0.06, x1 - 0.06):
		for y in (y0 + 0.06, y1 - 0.06):
			_bloc(piese, "Picior masa", x - 0.05, x + 0.05, y - 0.05, y + 0.05, TOR_Z, z - 0.08, LEMN)
	_bloc(piese, "Raft masa", x0 + 0.02, x1 - 0.02, y0 + 0.02, y1 - 0.02, TOR_Z + 0.2, TOR_Z + 0.24, LEMN_DESCHIS)
	xm = (x0 + x1) / 2
	piese += [
		cilindru("Galeata", 0.13, 0.15, 0.26, (xm, y0 + 0.35, TOR_Z + 0.37), GRI, laturi=10),
		cilindru("Sange galeata", 0.135, 0.135, 0.01, (xm, y0 + 0.35, TOR_Z + 0.46), ROSU_INCHIS, laturi=10),
	]
	for k in range(3):  # pete de sânge pe blat
		piese.append(cilindru("Pata blat", rs.uniform(0.06, 0.12), rs.uniform(0.06, 0.12), 0.003,
			(rs.uniform(x0 + 0.15, x1 - 0.15), rs.uniform(y0 + 0.2, y1 - 0.2), z + 0.0015), ROSU_INCHIS, laturi=8))
	# fierăstrăul
	ys = y0 + 0.28
	piese += [
		cub("Panza ferastrau", (0.05, 0.38, 0.004), (xm + 0.05, ys + 0.05, z + 0.004), GRI, rot=(0, 0, 0.15)),
		cub("Maner ferastrau", (0.06, 0.12, 0.025), (xm + 0.07, ys - 0.17, z + 0.013), LEMN_DESCHIS, rot=(0, 0, 0.15)),
	]
	# cleștele
	for s in (-1, 1):
		piese.append(os_intre("Clesti", (xm - 0.16, y0 + 0.55 + s * 0.03, z + 0.01), (xm - 0.02, y0 + 0.62, z + 0.012), 0.008, NEGRU, laturi=4))
		piese.append(os_intre("Clesti", (xm - 0.02, y0 + 0.62, z + 0.012), (xm + 0.05, y0 + 0.64 + s * 0.008, z + 0.012), 0.01, GRI, laturi=4))
	# ciocanul
	piese += [
		os_intre("Coada ciocan", (xm + 0.12, y0 + 0.7, z + 0.015), (xm - 0.1, y0 + 0.82, z + 0.015), 0.013, LEMN_DESCHIS, laturi=5),
		cub("Cap ciocan", (0.05, 0.12, 0.045), (xm + 0.13, y0 + 0.69, z + 0.023), NEGRU, rot=(0, 0, -0.5)),
	]
	# cuțitele și satârul
	for k, yy in enumerate((y0 + 0.95, y0 + 1.05)):
		piese += [
			cub("Lama cutit", (0.2, 0.025, 0.004), (xm + 0.04, yy, z + 0.004), GRI, rot=(0, 0, 0.1 * k)),
			cub("Maner cutit", (0.1, 0.022, 0.018), (xm - 0.11, yy - 0.01 * k, z + 0.01), NEGRU, rot=(0, 0, 0.1 * k)),
		]
	piese += [
		cub("Satar", (0.12, 0.2, 0.006), (xm - 0.02, y0 + 1.25, z + 0.004), GRI, rot=(0, 0, 0.3)),
		cub("Sange satar", (0.05, 0.12, 0.007), (xm + 0.02, y0 + 1.27, z + 0.004), ROSU, rot=(0, 0, 0.3)),
		cub("Maner satar", (0.03, 0.13, 0.025), (xm - 0.08, y0 + 1.09, z + 0.013), LEMN, rot=(0, 0, 0.3)),
	]
	# menghina de degete
	mx, my = xm + 0.15, y0 + 1.3
	piese += [
		cub("Menghina", (0.1, 0.03, 0.025), (mx, my, z + 0.0125), NEGRU),
		cub("Menghina", (0.1, 0.03, 0.025), (mx, my, z + 0.06), NEGRU),
		cilindru("Surub menghina", 0.008, 0.008, 0.09, (mx, my, z + 0.06), GRI, laturi=5),
		cub("Fluture menghina", (0.07, 0.012, 0.012), (mx, my, z + 0.105), GRI),
	]
	# castronul cu dinți, craniul, cârpa, lumânarea
	piese.append(cilindru("Castron", 0.08, 0.05, 0.05, (xm - 0.15, y1 - 0.25, z + 0.025), LEMN_DESCHIS, laturi=10))
	for k in range(7):
		u = k * 0.9
		piese.append(cub("Dinte", (0.012, 0.012, 0.018), (xm - 0.15 + math.cos(u) * 0.035, y1 - 0.25 + math.sin(u) * 0.035, z + 0.05), OS,
			rot=(0.4, 0.3 * k, 0)))
	_craniu(piese, xm - 0.12, y1 - 0.5, z, 1.0, -math.pi / 2 + 0.4)
	piese.append(cub("Carpa", (0.18, 0.22, 0.02), (xm + 0.12, y1 - 0.45, z + 0.01), ROSU_INCHIS, rot=(0, 0, 0.6)))
	piese.append(cilindru("Talpa lumanare", 0.045, 0.04, 0.02, (xm + 0.18, y1 - 0.15, z + 0.01), NEGRU, laturi=8))
	_lumanare(piese, lumini, xm + 0.18, y1 - 0.15, z + 0.02, inalt=0.09)
	piese.append(sfera("Ceara scursa", 0.04, (xm + 0.18, y1 - 0.15, z + 0.02), OS, scara=(1.3, 1.3, 0.2), segmente=6, inele=3))
	return (xm + 0.18, y1 - 0.15, z + 0.13)


def _panou_unelte(piese, rs, f, y0, y1):
	"""Panoul de lemn de pe peretele din vest (x = `f`), deasupra mesei: unelte atârnate în cuie (satâr, fierăstrău,
	topor, cârlige, fierul de înfierat, biciul, cătușe, un lanț)."""
	zb, zs = TOR_Z + 1.2, TOR_Z + 2.4
	_bloc(piese, "Panou unelte", f, f + 0.04, y0, y1, zb, zs, LEMN)
	_bloc(piese, "Sipca panou", f + 0.04, f + 0.065, y0, y1, zs - 0.08, zs - 0.03, LEMN_DESCHIS)
	x = f + 0.05
	n = 8
	for i in range(n):
		y = y0 + (y1 - y0) * (i + 0.5) / n
		zc = zs - 0.12
		piese.append(os_intre("Cui panou", (f + 0.04, y, zc), (f + 0.1, y, zc), 0.007, NEGRU, laturi=4))
		tip = i % 8
		if tip == 0:  # satâr
			piese += [cub("Maner satar", (0.025, 0.03, 0.14), (x + 0.02, y, zc - 0.08), LEMN),
				cub("Satar", (0.006, 0.13, 0.12), (x + 0.02, y + 0.04, zc - 0.21), GRI),
				cub("Sange satar", (0.007, 0.06, 0.05), (x + 0.02, y + 0.07, zc - 0.25), ROSU)]
		elif tip == 1:  # fierăstrău
			piese += [cub("Maner ferastrau", (0.025, 0.1, 0.06), (x + 0.02, y, zc - 0.04), LEMN_DESCHIS),
				cub("Panza ferastrau", (0.004, 0.08, 0.4), (x + 0.02, y, zc - 0.27), GRI)]
		elif tip == 2:  # topor
			piese += [os_intre("Coada topor", (x + 0.02, y, zc), (x + 0.02, y, zc - 0.55), 0.016, LEMN_DESCHIS, laturi=5),
				cub("Cap topor", (0.03, 0.16, 0.12), (x + 0.02, y + 0.06, zc - 0.5), NEGRU)]
		elif tip == 3:  # cârlige de carne
			for s in (-1, 1):
				piese.append(os_intre("Carlig", (x + 0.02, y, zc), (x + 0.02, y + s * 0.04, zc - 0.2), 0.008, NEGRU, laturi=4))
				piese.append(os_intre("Carlig", (x + 0.02, y + s * 0.04, zc - 0.2), (x + 0.02, y + s * 0.07, zc - 0.13), 0.008, NEGRU, laturi=4))
		elif tip == 4:  # fierul de înfierat
			piese += [os_intre("Fier infierat", (x + 0.02, y, zc), (x + 0.02, y, zc - 0.6), 0.01, NEGRU, laturi=4),
				cub("Semn fier", (0.01, 0.08, 0.08), (x + 0.02, y, zc - 0.64), NEGRU),
				cub("Maner fier", (0.03, 0.03, 0.12), (x + 0.02, y, zc - 0.04), LEMN)]
		elif tip == 5:  # biciul: coada și șfichiul atârnând
			a = (x + 0.02, y, zc)
			piese.append(os_intre("Coada bici", a, (x + 0.02, y, zc - 0.25), 0.015, p("48313b"), laturi=5))
			b = (x + 0.02, y, zc - 0.25)
			for k in range(5):
				c = (x + 0.02 + 0.01 * k, y + 0.03 * math.sin(k * 1.3), b[2] - 0.13)
				piese.append(os_intre("Bici", b, c, 0.006, p("48313b"), laturi=3))
				b = c
		elif tip == 6:  # cătușele
			for dz in (0.0, -0.13):
				piese.append(_inel_vertical("Catusa", 0.05, 0.01, (0, 0, 0), NEGRU))
				piese[-1].data.transform(Matrix.Translation((x + 0.02, y, zc - 0.08 + dz)) @ Matrix.Rotation(math.pi / 2, 4, 'Z'))
		else:  # un lanț
			_lant(piese, (x + 0.02, y, zc), (x + 0.03, y + 0.02, zc - 0.6))


def _mangal(piese, lumini, x, y):
	"""Mangalul cu jar: trei picioare de fier, vasul, cărbunii aprinși și flăcărui, fiarele de înfierat băgate în jar.
	Întoarce de unde vine lumina."""
	z = TOR_Z
	zv = z + 0.72
	for k in range(3):
		u = k * math.tau / 3
		piese.append(os_intre("Picior mangal", (x + math.cos(u) * 0.34, y + math.sin(u) * 0.34, z), (x + math.cos(u) * 0.2, y + math.sin(u) * 0.2, zv),
			0.018, NEGRU, laturi=4))
	piese.append(cilindru("Vas mangal", 0.18, 0.33, 0.2, (x, y, zv + 0.06), NEGRU, laturi=10))
	piese.append(inel("Buza mangal", 0.33, 0.02, (x, y, zv + 0.16), NEGRU, segmente=12))
	r = random.Random(13)
	for k in range(14):
		u, d = r.uniform(0, math.tau), r.uniform(0, 0.26)
		lumini.append(sfera("Jar", r.uniform(0.04, 0.07), (x + math.cos(u) * d, y + math.sin(u) * d, zv + 0.15), r.choice((p("904a40"), ROSU,
			FLACARA_PORTOCALIE)), scara=(1, 1, 0.6), segmente=6, inele=4))
	for k in range(5):
		u, d = r.uniform(0, math.tau), r.uniform(0, 0.18)
		h = r.uniform(0.12, 0.25)
		lumini.append(cilindru("Flacara mangal", 0.05, 0.0, h, (x + math.cos(u) * d, y + math.sin(u) * d, zv + 0.17 + h / 2),
			FLACARA_PORTOCALIE if k % 2 else FLACARA, laturi=5))
	for k, u in enumerate((0.4, 2.3, 4.4)):
		a = (x + math.cos(u) * 0.1, y + math.sin(u) * 0.1, zv + 0.14)
		b = (x + math.cos(u) * 0.75, y + math.sin(u) * 0.75, zv + 0.42)
		piese.append(os_intre("Fier infierat", a, b, 0.011, NEGRU, laturi=4))
		piese.append(os_intre("Maner fier", _lerp(a, b, 0.82), b, 0.02, LEMN, laturi=5))
		lumini.append(cub("Semn incins", (0.07, 0.07, 0.015), a, ROSU, rot=(0, 0, u)))
	return (x, y, zv + 0.45)


def _banc_de_intins(piese, rs, x0, x1, y0, y1):
	"""Bancul de întins („rack”-ul): cadrul de lemn pe patru picioare, șipcile, sulurile de la capete cu mânerele în
	cruce, frânghiile, inelele pentru încheieturi și glezne, sânge pe șipci."""
	z = TOR_Z + 0.72
	ym = (y0 + y1) / 2
	for y in (y0 + 0.05, y1 - 0.05):
		_bloc(piese, "Lonjeron", x0, x1, y - 0.05, y + 0.05, z - 0.14, z, LEMN)
	for x in (x0 + 0.08, x1 - 0.08):
		for y in (y0 + 0.05, y1 - 0.05):
			_bloc(piese, "Picior banc", x - 0.06, x + 0.06, y - 0.06, y + 0.06, TOR_Z, z - 0.14, LEMN)
	for i in range(9):
		x = x0 + 0.35 + i * (x1 - x0 - 0.7) / 8
		_bloc(piese, "Sipca banc", x - 0.05, x + 0.05, y0 + 0.1, y1 - 0.1, z - 0.04, z - 0.01, LEMN_DESCHIS)
	for x, s in ((x0 + 0.15, 1), (x1 - 0.15, -1)):
		piese.append(cilindru("Sul", 0.07, 0.07, y1 - y0 + 0.12, (x, ym, z + 0.04), LEMN_DESCHIS, laturi=8, rot=(math.pi / 2, 0, 0)))
		for k in range(4):
			u = k * math.pi / 2 + 0.3
			piese.append(os_intre("Maner sul", (x, y1 + 0.06, z + 0.04), (x + math.cos(u) * 0.28, y1 + 0.08, z + 0.04 + math.sin(u) * 0.28), 0.022,
				LEMN, laturi=5))
		for yy in (ym - 0.12, ym + 0.12):
			piese.append(os_intre("Franghie banc", (x, yy, z + 0.1), (x + s * 0.35, yy, z + 0.02), 0.012, PANZA, laturi=4))
			piese.append(inel("Inel banc", 0.04, 0.01, (x + s * 0.37, yy, z + 0.015), NEGRU, segmente=8))
	for k in range(4):
		piese.append(cilindru("Sange banc", rs.uniform(0.05, 0.12), rs.uniform(0.05, 0.12), 0.003,
			(rs.uniform(x0 + 0.4, x1 - 0.4), ym + rs.uniform(-0.15, 0.15), z - 0.008), ROSU_INCHIS, laturi=8))
	_balta(piese, rs, (x0 + x1) / 2 + 0.2, ym, TOR_Z, 0.25)


def _fecioara_de_fier(piese, x, y, unghi):
	"""Fecioara de fier: sarcofagul în picioare cu fața de femeie sus, ușa din față deschisă, cu țepi pe dinăuntru
	(și pe trupul din spatele ei). Făcută cu fața spre -Y, apoi rotită cu `unghi` și mutată."""
	c = []
	c.append(trunchi("Fecioara", [((0, 0, 0.0), 0.32, 0.25), ((0, 0, 0.12), 0.36, 0.28), ((0, 0, 1.25), 0.37, 0.28), ((0, 0, 1.45), 0.3, 0.23),
		((0, 0, 1.56), 0.18, 0.16), ((0, 0, 1.88), 0.17, 0.15), ((0, 0, 1.98), 0.1, 0.08)], NEGRU, laturi=10))
	c.append(cub("Interior fecioara", (0.5, 0.01, 1.2), (0, -0.276, 0.75), p("2a3c3d")))
	for i in range(4):
		for j in range(7):
			c.append(cilindru("Tep", 0.014, 0.0, 0.08, (-0.18 + i * 0.12, -0.32, 0.25 + j * 0.16), GRI, laturi=4, rot=(math.pi / 2, 0, 0)))
	# fața de sus
	c += [
		sfera("Fata fecioara", 0.12, (0, -0.135, 1.72), GRI, scara=(0.85, 0.35, 1.05), segmente=8, inele=6),
		cub("Ochi fecioara", (0.035, 0.012, 0.014), (-0.04, -0.178, 1.75), NEGRU),
		cub("Ochi fecioara", (0.035, 0.012, 0.014), (0.04, -0.178, 1.75), NEGRU),
		cub("Gura fecioara", (0.05, 0.012, 0.01), (0, -0.178, 1.66), NEGRU),
		cub("Lacrima rugina", (0.008, 0.01, 0.06), (0.04, -0.18, 1.71), p("904a40")),
	]
	for z in (0.3, 0.8, 1.3):
		c.append(cub("Banda fecioara", (0.68, 0.02, 0.04), (0, -0.285, z), GRI))
	# ușa: la închis ar sta pe față; deschisă larg în jurul balamalei din dreapta
	usa = [cub("Usa fecioara", (0.6, 0.05, 1.3), (-0.3, -0.03, 0.75), NEGRU)]
	for i in range(4):
		for j in range(7):
			usa.append(cilindru("Tep", 0.014, 0.0, 0.08, (-0.48 + i * 0.12, 0.03, 0.25 + j * 0.16), GRI, laturi=4, rot=(-math.pi / 2, 0, 0)))
	for z in (0.3, 0.8, 1.3):
		usa.append(cub("Balama fecioara", (0.08, 0.06, 0.05), (0.0, -0.03, z), GRI))
	_muta(usa, (0, 0, 1.9), (0.3, -0.3, 0.0))
	c += usa
	piese += _muta(c, (0, 0, unghi), (x, y, TOR_Z))


def _scaun_cu_tepi(piese, x, y, unghi):
	"""Scaunul cu țepi: șezut, spătar și brațe pline de țepi, curelele de piele pe brațe și la picioare.
	Făcut cu fața spre -Y, apoi rotit cu `unghi` și mutat."""
	c = []
	for sx in (-0.24, 0.24):
		for sy in (-0.22, 0.22):
			c.append(cub("Picior scaun", (0.06, 0.06, 0.48), (sx, sy, 0.24), LEMN))
		c.append(cub("Brat scaun", (0.07, 0.5, 0.05), (sx, 0.0, 0.75), LEMN))
		c.append(cub("Stalp brat", (0.05, 0.05, 0.27), (sx, -0.22, 0.61), LEMN))
		c.append(cub("Curea", (0.09, 0.06, 0.07), (sx, -0.05, 0.76), p("48313b")))
		c.append(cub("Curea picior", (0.08, 0.08, 0.05), (sx * 0.6, -0.26, 0.2), p("48313b")))
	c.append(cub("Sezut scaun", (0.54, 0.5, 0.05), (0, 0, 0.5), LEMN))
	c.append(cub("Spatar scaun", (0.54, 0.06, 0.8), (0, 0.24, 0.92), LEMN))
	c.append(cub("Spatar scaun", (0.6, 0.08, 0.06), (0, 0.24, 1.33), LEMN_DESCHIS))
	for i in range(5):
		for j in range(4):
			c.append(cilindru("Tep", 0.01, 0.0, 0.05, (-0.2 + i * 0.1, -0.17 + j * 0.11, 0.55), GRI, laturi=4))
		for j in range(6):
			c.append(cilindru("Tep", 0.01, 0.0, 0.05, (-0.2 + i * 0.1, 0.2, 0.62 + j * 0.11), GRI, laturi=4, rot=(math.pi / 2, 0, 0)))
	for sx in (-0.24, 0.24):
		for j in range(4):
			c.append(cilindru("Tep", 0.008, 0.0, 0.04, (sx, -0.19 + j * 0.12, 0.795), GRI, laturi=4))
	c.append(cub("Sange scaun", (0.3, 0.25, 0.004), (0.02, -0.04, 0.527), ROSU_INCHIS, rot=(0, 0, 0.3)))
	piese += _muta(c, (0, 0, unghi), (x, y, TOR_Z))


def _camera_tortura(piese, lumini, col, rs):
	"""Camera de tortură de la capătul catacombelor: pereți de piatră cu pilaștri, arcuri și lanțuri, tavanul cu grinda
	groasă de care atârnă cei trei (spânzurații sunt modele separate), bălți de sânge sub ei, rigola din mijloc, masa cu
	unelte și panoul de pe peretele din vest (lângă ele stau cele două vrăjitoare), mangalul, bancul de întins, fecioara
	de fier, scaunul cu țepi, un butoi, o grămadă de oase. Întoarce flăcările."""
	flacari = {}
	x0, x1, y0, y1 = TOR_X0, TOR_X1, TOR_Y0, TOR_Y1
	jos = lambda u: TOR_Z
	sus = lambda u: TOR_TAVAN
	# podeaua (lespezi), tavanul, pereții
	_bloc(piese, "Podea tortura", x0, x1, y0, y1, -4.6, TOR_Z - 0.01, PIATRA_INCHISA)
	_bloc(col, "Coliziune", x0, x1 + 0.05, y0, y1, -4.6, TOR_Z, PIATRA)
	y = y0
	while y < y1 - 0.05:
		h = rs.uniform(0.45, 0.7)
		x = x0 - rs.uniform(0, 0.3)
		while x < x1:
			w = rs.uniform(0.5, 0.9)
			a, b = max(x, x0) + 0.015, min(x + w, x1) - 0.015
			if b - a > 0.1:
				_bloc(piese, "Lespede", a, b, y + 0.015, min(y + h, y1) - 0.015, TOR_Z - 0.01, TOR_Z + rs.uniform(0.0, 0.008), rs.choice(PIETRE))
			x += w
		y += h
	_bloc(piese, "Tavan tortura", x0 - 0.1, x1 + 0.1, y0 - 0.1, y1 + 0.1, TOR_TAVAN, TOR_TAVAN + 0.3, PIATRA_INCHISA)
	trecere = (COR_Y0, COR_Y1, TOR_Z, _tavan_coridor(2.5), False)
	_zid(piese, col, "y", x0, -1, y0 - 0.4, y1 + 0.4, -4.6, -0.3)
	_zid(piese, col, "y", x1, 1, y0 - 0.4, y1 + 0.4, -4.6, -0.3, [trecere])
	_zid(piese, col, "x", y0, -1, x0, x1, -4.6, -0.3)
	_zid(piese, col, "x", y1, 1, x0, x1, -4.6, -0.3)
	_pietre(piese, rs, "y", x0, -1, y0, y1, jos, sus, [(0.75, 2.65, TOR_Z + 1.15, TOR_Z + 2.45)])
	_pietre(piese, rs, "y", x1, 1, y0, y1, jos, sus, [(COR_Y0 - 0.15, COR_Y1 + 0.15, TOR_Z - 0.2, _tavan_coridor(2.5) + 0.12)])
	_pietre(piese, rs, "x", y0, -1, x0, x1, jos, sus)
	_pietre(piese, rs, "x", y1, 1, x0, x1, jos, sus)
	# arcul trecerii dinspre coridor
	zt = _tavan_coridor(2.5)
	_bloc(piese, "Arc trecere", x1 - 0.06, x1 + 0.1, COR_Y0 - 0.2, COR_Y1 + 0.2, zt, zt + 0.2, PIATRA)
	for yb_ in (COR_Y0 - 0.1, COR_Y1 + 0.1):
		_bloc(piese, "Pilastru", x1 - 0.06, x1 + 0.1, yb_ - 0.1, yb_ + 0.1, TOR_Z, zt, PIATRA)
	# arcurile de pe tavan, cu pilaștrii lor pe pereții din nord și sud
	for x in (-3.3, -1.8, -0.4, 1.0):
		_bloc(piese, "Arc tavan", x - 0.15, x + 0.15, y0, y1, TOR_TAVAN - 0.2, TOR_TAVAN, PIATRA)
		for yb_, s in ((y0, 1), (y1, -1)):
			_bloc(piese, "Pilastru", x - 0.15, x + 0.15, yb_, yb_ + s * 0.1, TOR_Z, TOR_TAVAN - 0.2, PIATRA)
			piese.append(cub("Bolta", (0.3, 0.3, 0.3), (x, yb_, TOR_TAVAN - 0.2), PIATRA, rot=(math.pi / 4, 0, 0)))
	# grinda de care atârnă cei trei, cu cârligele, plus două lanțuri goale
	_bloc(piese, "Grinda spanzurati", x0, x1, GRINDA_Y - 0.13, GRINDA_Y + 0.13, GRINDA_Z, TOR_TAVAN - 0.2, LEMN)
	for x in (-3.4, 1.3):
		_bloc(piese, "Banda grinda", x - 0.04, x + 0.04, GRINDA_Y - 0.14, GRINDA_Y + 0.14, GRINDA_Z - 0.01, GRINDA_Z + 0.27, NEGRU)
	for x in SPANZURATI_X:
		piese.append(cub("Placa carlig", (0.1, 0.1, 0.02), (x, GRINDA_Y, GRINDA_Z - 0.01), NEGRU))
		piese.append(inel("Inel carlig", 0.035, 0.008, (x, GRINDA_Y, GRINDA_Z - 0.03), NEGRU, segmente=8))
		piese.append(os_intre("Carlig", (x, GRINDA_Y, GRINDA_Z - 0.02), (x, GRINDA_Y, GRINDA_Z - 0.07), 0.01, NEGRU, laturi=4))
		_balta(piese, rs, x + rs.uniform(-0.05, 0.05), GRINDA_Y - 0.05, TOR_Z, rs.uniform(0.3, 0.42))
		for k in range(4):  # stropi pe peretele din spate
			piese.append(sfera("Strop perete", rs.uniform(0.03, 0.07), (x + rs.uniform(-0.4, 0.4), y1 - 0.045, TOR_Z + rs.uniform(0.4, 1.8)), ROSU_INCHIS,
				scara=(1.0, 0.2, 1.3), segmente=6, inele=4))
	for x in (-3.6, 1.45):
		_lant(piese, (x, GRINDA_Y, GRINDA_Z), (x + 0.02, GRINDA_Y, GRINDA_Z - 1.1))
		piese.append(os_intre("Carlig", (x + 0.02, GRINDA_Y, GRINDA_Z - 1.1), (x + 0.02, GRINDA_Y - 0.06, GRINDA_Z - 1.25), 0.012, NEGRU, laturi=4))
	# rigola din mijloc, cu sângele care curge spre ea
	gx, gy = -1.1, 1.7
	_bloc(piese, "Rigola", gx - 0.2, gx + 0.2, gy - 0.2, gy + 0.2, TOR_Z - 0.005, TOR_Z + 0.006, NEGRU)
	for k in range(5):
		_bloc(piese, "Gratar", gx - 0.18 + k * 0.09, gx - 0.15 + k * 0.09, gy - 0.18, gy + 0.18, TOR_Z, TOR_Z + 0.012, GRI)
	for x in SPANZURATI_X:
		a = Vector((x, GRINDA_Y - 0.3, TOR_Z + 0.004))
		b = Vector((gx + (x - gx) * 0.15, gy + 0.2, TOR_Z + 0.004))
		piese.append(cub("Dara sange", ((b - a).length, 0.05, 0.003), tuple((a + b) / 2), ROSU_INCHIS, rot=(0, 0, math.atan2(b.y - a.y, b.x - a.x))))
	# lanțuri cu cătușe pe pereți
	for x in (-3.9, -0.4, 1.5):
		for s in (-1, 1):
			a = (x + s * 0.25, y1 - 0.05, TOR_Z + 2.0)
			piese.append(cub("Inel zid", (0.06, 0.04, 0.06), a, NEGRU))
			_lant(piese, a, (x + s * 0.18, y1 - 0.07, TOR_Z + 1.45))
			piese.append(inel("Catusa", 0.05, 0.012, (x + s * 0.18, y1 - 0.08, TOR_Z + 1.4), NEGRU, segmente=8))
	# mobilierul durerii
	flacari["TorturaMasa"] = _masa_tortura(piese, lumini, rs, x0 + 0.1, x0 + 0.8, 0.85, 2.55)
	_bloc(col, "Coliziune", x0, x0 + 0.8, 0.85, 2.55, TOR_Z, TOR_Z + 0.9, LEMN)
	_panou_unelte(piese, rs, x0, 0.8, 2.6)
	flacari["TorturaMangal"] = _mangal(piese, lumini, -2.7, -0.35)
	_banc_de_intins(piese, rs, -1.7, 0.5, y0 + 0.25, y0 + 0.95)
	_fecioara_de_fier(piese, x0 + 0.55, y0 + 0.6, math.pi - 0.75)
	_scaun_cu_tepi(piese, 1.3, -0.95, math.pi + 0.5)
	# un butoi, o găleată, un taburet, grămada de oase și cranii din colț
	piese += [
		cilindru("Butoi", 0.3, 0.3, 0.8, (1.55, 4.55, TOR_Z + 0.4), LEMN, laturi=10),
		inel("Cerc butoi", 0.3, 0.015, (1.55, 4.55, TOR_Z + 0.15), NEGRU, segmente=10),
		inel("Cerc butoi", 0.3, 0.015, (1.55, 4.55, TOR_Z + 0.65), NEGRU, segmente=10),
		cilindru("Taburet", 0.18, 0.18, 0.04, (-0.2, 0.3, TOR_Z + 0.45), LEMN_DESCHIS, laturi=8),
		cilindru("Galeata", 0.13, 0.15, 0.26, (0.9, 3.0, TOR_Z + 0.13), GRI, laturi=10),
		cilindru("Sange galeata", 0.135, 0.135, 0.01, (0.9, 3.0, TOR_Z + 0.23), ROSU_INCHIS, laturi=10),
	]
	for k in range(3):
		u = k * math.tau / 3
		piese.append(os_intre("Picior taburet", (-0.2 + math.cos(u) * 0.12, 0.3 + math.sin(u) * 0.12, TOR_Z + 0.44),
			(-0.2 + math.cos(u) * 0.17, 0.3 + math.sin(u) * 0.17, TOR_Z), 0.02, LEMN, laturi=4))
	_bloc(col, "Coliziune", 1.25, 1.85, 4.25, 4.85, TOR_Z, TOR_Z + 0.8, LEMN)
	for k in range(12):
		u, d = rs.uniform(0, math.tau), rs.uniform(0, 0.45)
		cx, cy = -3.9 + math.cos(u) * d, 4.4 + math.sin(u) * d * 0.7
		a = rs.uniform(0, math.pi)
		_os_lung(piese, (cx - math.cos(a) * 0.2, cy - math.sin(a) * 0.2, TOR_Z + 0.02 + (k % 3) * 0.03),
			(cx + math.cos(a) * 0.2, cy + math.sin(a) * 0.2, TOR_Z + 0.03 + (k % 3) * 0.03), 0.016)
	for k, (cx, cy, cz) in enumerate(((-3.95, 4.45, 0.08), (-3.7, 4.6, 0.02), (-4.15, 4.2, 0.02), (-3.85, 4.15, 0.05))):
		_craniu(piese, cx, cy, TOR_Z + cz, 1.0, -0.6 + k)
	# torțele
	flacari["TorturaTortaEst1"] = _torta(piese, lumini, "y", x1, 1, 0.25, TOR_Z + 1.75)
	flacari["TorturaTortaEst2"] = _torta(piese, lumini, "y", x1, 1, 2.95, TOR_Z + 1.75)
	flacari["TorturaTortaNord"] = _torta(piese, lumini, "x", y1, 1, -2.6 + 0.7, TOR_Z + 1.75)
	flacari["TorturaTortaSud"] = _torta(piese, lumini, "x", y0, -1, -2.35, TOR_Z + 1.75)
	# pânze în colțurile de sus
	for cx, cy, sa, sb in ((x0 + 0.01, y0 + 0.01, (1, 0, 0), (0, 1, 0)), (x1 - 0.01, y1 - 0.01, (-1, 0, 0), (0, -1, 0)),
			(x0 + 0.01, y1 - 0.01, (1, 0, 0), (0, -1, 0))):
		_panza(piese, (cx, cy, TOR_TAVAN - 0.02), sa, (sb[0], sb[1], -0.7), raza=0.5)
	return flacari


def subsol(cale):
	"""Subsolul conacului (owner 12.10), sub sală: puțul cu scara de sub scara din dreapta, coridorul catacombelor și
	camera de tortură. Piese: `Subsol`, `Lumini` (flăcările, jarul), `Coliziune`. Scrie la sfârșit unde sunt flăcările
	în coordonate Godot (pentru luminile din conac_interior.tscn)."""
	curata()
	rs = random.Random(1210)
	piese, lumini, col = [], [], []

	def strange():
		piese[:] = [uneste(piese, "Subsol")]

	flacari = _scara_subsol(piese, lumini, col, rs)
	strange()
	flacari.update(_coridor(piese, lumini, col, rs))
	strange()
	flacari.update(_camera_tortura(piese, lumini, col, rs))
	uneste(col, "Coliziune")
	uneste(lumini, "Lumini")
	uneste(piese, "Subsol")
	exporta(os.path.join(cale, "subsol.glb"))
	for nume, (x, y, z) in sorted(flacari.items()):
		print("FLACARA %s Godot (%.2f, %.2f, %.2f)" % (nume, x, z, -y))


def _sange_spanzurat(z0, saminta, burta=0.0):
	"""Pentru casino_oameni.om (`extra`): tăieturile de bici cu sângele prelins pe piept, pe burtă și pe spate, pete pe
	brațe și pe pantaloni, frânghia care îi leagă încheieturile și urcă până la cârlig (FUNIE_SUS)."""
	b = burta  # inelele trunchiului, ca în casino_oameni._tors (bărbat)
	inele = [(0.02, 0.03, 0.17, 0.13), (0.13, 0.02 - 0.05 * b, 0.175 + 0.05 * b, 0.135 + 0.07 * b),
		(0.25, 0.01 - 0.05 * b, 0.18 + 0.05 * b, 0.135 + 0.065 * b), (0.36, -0.02 * b, 0.195, 0.13 + 0.03 * b),
		(0.46, 0.01, 0.205, 0.12), (0.52, 0.02, 0.16, 0.095)]

	def pe_tors(z, x, spate=False):
		_, y, rx, ry = min(inele, key=lambda t: abs(t[0] - z))
		x = max(-rx * 0.85, min(rx * 0.85, x))
		dy = ry * math.sqrt(max(0.0, 1.0 - (x / rx) ** 2)) * 0.97
		return (x, y + dy if spate else y - dy, z0 + z * 1.18)

	def extra(corp):
		rs = random.Random(saminta)
		c = []
		for spate in (False, True):
			for _ in range(5 if not spate else 4):
				z, x = rs.uniform(0.12, 0.47), rs.uniform(-0.13, 0.08)
				a, b = pe_tors(z + 0.035, x - 0.07, spate), pe_tors(z - 0.035, x + 0.07, spate)
				c.append(os_intre("Taietura", a, b, 0.007, ROSU, laturi=4))
				for _ in range(rs.randint(1, 2)):
					xx = x + rs.uniform(-0.05, 0.05)
					zz = z + (xx - x) * -0.5
					top, jos = pe_tors(zz, xx, spate), pe_tors(zz - rs.uniform(0.08, 0.2), xx + rs.uniform(-0.01, 0.01), spate)
					c.append(os_intre("Prelingere", top, jos, 0.005, ROSU_INCHIS, laturi=4))
			for _ in range(4):
				pt = pe_tors(rs.uniform(0.05, 0.5), rs.uniform(-0.15, 0.15), spate)
				c.append(sfera("Pata sange", rs.uniform(0.02, 0.035), pt, ROSU_INCHIS, scara=(1, 0.4, 1.2), segmente=6, inele=4))
		for k in (-1, 1):  # pe brațe și pe coapse
			umar, cot = (0.19 * k, 0.01, z0 + 0.555), (0.2 * k, 0.05, 1.7)
			for t in (0.3, 0.7):
				pt = _lerp(umar, cot, t)
				c.append(sfera("Pata sange", 0.025, (pt[0], pt[1] - 0.048, pt[2]), ROSU_INCHIS, scara=(1, 0.4, 1.4), segmente=6, inele=4))
			for t in (0.35, 0.75):
				pt = _lerp((0.1 * k, 0.03, z0 + 0.047), (0.105 * k, 0.0, 0.5), t)
				c.append(sfera("Pata pantaloni", rs.uniform(0.03, 0.045), (pt[0], pt[1] - 0.07, pt[2]), ROSU_INCHIS, scara=(1, 0.4, 1.3),
					segmente=6, inele=4))
		ob = uneste(c, "Sange")
		_parinte(ob, corp)
		f = [
			os_intre("Funie", (0, 0.04, 1.97), (0, 0.04, FUNIE_SUS), 0.016, PANZA, laturi=5),
			os_intre("Legatura", (-0.1, 0.04, 1.93), (0.1, 0.04, 1.93), 0.03, PANZA, laturi=6),
			os_intre("Legatura", (-0.09, 0.04, 1.99), (0.09, 0.04, 1.99), 0.026, PANZA, laturi=6),
			os_intre("Nod funie", (0, 0.04, 1.96), (0, 0.04, 2.05), 0.035, PANZA, laturi=6),
		]
		ob_f = uneste(f, "Funie")
		_parinte(ob_f, corp)
	return extra


SPANZURATI = [
	# slăbănogul chel, nebărbierit, cu gura deschisă
	dict(par=p("48313b"), stil_par="chel", tepi=p("48313b"), slab=0.8, pantaloni=p("5e5356"), gura_deschisa=True, incruntat=0.25),
	# cel cu burtă, păr scurt și mustață
	dict(par=p("262d2f"), stil_par="scurt", mustata=p("262d2f"), burta=0.45, gras=0.3, pantaloni=p("48313b"), incruntat=0.3),
	# tânărul cu părul pe spate, nebărbierit
	dict(par=p("5e363e"), stil_par="spate", tepi=p("5e363e"), slab=0.5, pantaloni=p("2a3c3d"), gura_deschisa=True, spranceana=0.012),
]


def spanzurati(cale):
	"""Cei trei oameni spânzurați de mâini în camera de tortură (owner 12.10): fără tricou, plini de sânge, desculți,
	cu mâinile legate deasupra capului și frânghia până la cârlig. Prin casino_oameni.om (în picioare, `stil_haina`
	"gol", `descult`); originea = sub tălpi, frânghia se termină la FUNIE_SUS. În joc: spanzurat.gd (se leagănă)."""
	import casino_oameni
	for i, st in enumerate(SPANZURATI):
		s = dict(st, piele=p("a56850"), piele_umbra=p("904a40"), haina=p("a56850"), haina_umbra=p("904a40"), camasa=p("a56850"),
			stil_haina="gol", brate_goale=True, in_picioare=True, descult=True, sezut=0.86, gros_brat=0.9,
			poza_D=((-0.2, 0.05, 1.7), (-0.055, 0.04, 1.98)), poza_S=((0.2, 0.05, 1.7), (0.055, 0.04, 1.98)))
		s["extra"] = _sange_spanzurat(0.86, 500 + i, st.get("burta", 0.0))
		casino_oameni.om(cale, "spanzurat_%d" % (i + 1), s, 500 + i)


TORTURA = [
	(dict(CERC[0], roba=p("5e363e"), roba_umbra=p("48313b"), pelerina=p("262d2f"), banda=p("904a40"), cocoasa=0.08), False),
	(dict(CERC[2], roba=p("2a3c3d"), roba_umbra=p("262d2f"), pelerina=p("5e363e"), par=p("7e8d87"), par_suvita=p("83b3b0"), cocoasa=0.03), "clesti"),
]


def vrajitoare_tortura(cale):
	"""Cele două vrăjitoare din camera de tortură (owner 12.10), care stau la povești lângă masa cu unelte: ca cele din
	salon (vrajitoare_salon), una cu mâna în șold, alta cu un clește însângerat în loc de pocal."""
	for i, (s, unealta) in enumerate(TORTURA):
		vrajitoare_salon(cale, "vrajitoare_tortura_%d" % (i + 1), s, 300 + i, unealta)


def salon(cale):
	for i, (s, pahar) in enumerate(SALON):
		vrajitoare_salon(cale, "vrajitoare_salon_%d" % (i + 1), s, 200 + i, pahar)


def toate(cale):
	salon(cale)
	helga(cale)
	manechin(cale)
	mana_jucator(cale)
	pisica(cale)
	usa_debara(cale)
	parry(cale)
	spanzurati(cale)
	vrajitoare_tortura(cale)
	ceas_pendul(cale)
	subsol(cale)
	conac_interior(cale)


if __name__ == "__main__":
	cale_modele = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")
	if "--" in sys.argv:
		for nume in sys.argv[sys.argv.index("--") + 1:]:
			globals()[nume](cale_modele)
	else:
		toate(cale_modele)
