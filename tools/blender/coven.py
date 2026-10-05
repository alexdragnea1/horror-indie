# Coven-ul din fundul văii (stânga, jos): vrăjitoarele în cerc, șefa lor (Head Witch), cazanul mare,
# pistolul roz pe care ți-l dă și mătura cu care te duce acasă.
# Le apelează modele.py, dar merge și singur (mai repede, doar astea):
#   blender --background --factory-startup --python tools/blender/coven.py
# Axe Blender: Z în sus, fața modelului spre -Y (în Godot devine +Z). Originea = la sol.
import math
import os
import random
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, sfera_deschisa, os_intre, inel, uneste, exporta, trunchi  # noqa: E402

NEGRU = p("262d2f")
OS = p("83b3b0")  # cea mai deschisă culoare: os, dinți, sclipiri
AUR = p("a18463")
LEMN = p("5e363e")
LEMN_INCHIS = p("48313b")
PAIE = p("a18463")
PIATRA = p("6f6d7f")
PIATRA_INCHISA = p("5e5356")


def _lerp(a, b, t):
	return tuple(x + (y - x) * t for x, y in zip(a, b))


def _parinte(copil, parinte):
	"""Leagă un obiect de altul (ca SticlaMana de braț), fără să-l miște din loc."""
	copil.parent = parinte
	copil.matrix_parent_inverse = parinte.matrix_world.inverted()


# ---------------------------------------------------------------------------------------------------------------
# Vrăjitoarele
# ---------------------------------------------------------------------------------------------------------------

def _palarie(piese, baza, raza, inaltime, culoare, banda, r, aplecare=0.0, varf=(0.16, 0.05)):
	"""Pălărie de vrăjitoare: bor larg și puțin ondulat, con tras pe un drum strâmb (vârful căzut într-o parte),
	bandă cu cataramă și un petec cusut. `baza` = mijlocul borului; `aplecare` = cât e dată pe ceafă (m)."""
	bx, by, bz = baza
	# borul: disc subțire, cu marginea îngroșată și puțin ridicată
	piese.append(cilindru("Bor", raza, raza, 0.014, (bx, by + aplecare * 0.2, bz), culoare, laturi=14))
	piese.append(inel("Margine bor", raza * 0.97, 0.014, (bx, by + aplecare * 0.2, bz + 0.012), culoare, segmente=14))
	# conul: puncte pe un drum care se strâmbă spre vârf
	vx, vy = varf
	drum = [
		((bx, by, bz + 0.005), raza * 0.46),
		((bx, by + aplecare * 0.4, bz + inaltime * 0.35), raza * 0.36),
		((bx + vx * 0.15, by + aplecare * 0.8 + vy * 0.2, bz + inaltime * 0.62), raza * 0.24),
		((bx + vx * 0.5, by + aplecare + vy * 0.6, bz + inaltime * 0.85), raza * 0.13),
		((bx + vx, by + aplecare + vy, bz + inaltime * 0.93), raza * 0.05),
		((bx + vx * 1.3, by + aplecare + vy * 1.1, bz + inaltime * 0.9), 0.0),
	]
	piese.append(trunchi("Con", [(c, rr, rr) for c, rr in drum], culoare, laturi=10))
	# banda și catarama, puțin peste con (fără fețe lipite)
	piese.append(trunchi("Banda", [((bx, by, bz + 0.016), raza * 0.46 + 0.01, raza * 0.46 + 0.01),
		((bx, by + aplecare * 0.07, bz + 0.06), raza * 0.43 + 0.01, raza * 0.43 + 0.01)], banda, laturi=10))
	# catarama: o ramă pătrată de aur (prin mijloc se vede banda)
	cy = by - raza * 0.46 - 0.018
	for dx, dz, w, hh in ((-0.02, 0, 0.01, 0.04), (0.02, 0, 0.01, 0.04), (0, 0.015, 0.03, 0.01), (0, -0.015, 0.03, 0.01)):
		piese.append(cub("Catarama", (w, 0.012, hh), (bx + dx, cy, bz + 0.038 + dz), AUR))
	# un petec cusut pe con
	pz = bz + inaltime * 0.3
	piese.append(cub("Petec", (0.05, 0.012, 0.045), (bx + raza * 0.24, by - raza * 0.27, pz), p("5e5356"), rot=(0.2, 0.0, 0.75)))


def _mana(piese, incheietura, directie, lateral, piele, unghie, r, deschisa=True):
	"""Mână osoasă: palma turtită și patru degete lungi, noduroase, cu unghii negre ascuțite.
	`directie` = încotro arată degetele, `lateral` = spre degetul mare (vectori unitari)."""
	ix, iy, iz = incheietura
	dx, dy, dz = directie
	lx, ly, lz = lateral
	palma = (ix + dx * 0.045, iy + dy * 0.045, iz + dz * 0.045)
	piese.append(sfera("Palma", 0.042, palma, piele, scara=(1.0, 1.0, 1.0), segmente=6, inele=4))
	for k in range(4):
		o = (k - 1.5) * 0.017
		baza = (palma[0] + dx * 0.03 + lx * o, palma[1] + dy * 0.03 + ly * o, palma[2] + dz * 0.03 + lz * o)
		desfacere = (k - 1.5) * (0.35 if deschisa else 0.1)
		lung = 0.06 + (0.012 if k in (1, 2) else 0.0)
		# degetul: două falange, a doua îndoită puțin în jos (gheare)
		mij = (baza[0] + (dx + lx * desfacere) * lung * 0.55, baza[1] + (dy + ly * desfacere) * lung * 0.55,
			baza[2] + (dz + lz * desfacere) * lung * 0.55 - 0.004)
		varf = (mij[0] + (dx + lx * desfacere) * lung * 0.45, mij[1] + (dy + ly * desfacere) * lung * 0.45,
			mij[2] + (dz + lz * desfacere) * lung * 0.45 - 0.02)
		piese.append(trunchi("Deget", [(baza, 0.009, 0.009), (mij, 0.008, 0.008), (varf, 0.006, 0.006)], piele, laturi=4))
		gheara = (varf[0] + (dx + lx * desfacere) * 0.02, varf[1] + (dy + ly * desfacere) * 0.02, varf[2] + (dz + lz * desfacere) * 0.02 - 0.012)
		piese.append(trunchi("Unghie", [(varf, 0.006, 0.006), (gheara, 0.0, 0.0)], unghie, laturi=4))
	# degetul mare
	dm = (palma[0] + lx * 0.04 + dx * 0.01, palma[1] + ly * 0.04 + dy * 0.01, palma[2] + lz * 0.04 + dz * 0.01)
	varf = (dm[0] + dx * 0.035 + lx * 0.015, dm[1] + dy * 0.035 + ly * 0.015, dm[2] + dz * 0.035 + lz * 0.015 - 0.01)
	piese.append(trunchi("Deget mare", [(palma, 0.011, 0.011), (dm, 0.009, 0.009), (varf, 0.007, 0.007)], piele, laturi=4))


def _maneca(piese, umar, cot, incheietura, culoare, culoare_umbra):
	"""Mânecă largă, evazată spre încheietură (ca un clopot), cu tivul zdrențuit."""
	mij1 = _lerp(umar, cot, 0.5)
	mij2 = _lerp(cot, incheietura, 0.5)
	capat = _lerp(cot, incheietura, 1.08)
	piese.append(trunchi("Maneca", [(umar, 0.065, 0.065), (mij1, 0.062, 0.06), (cot, 0.064, 0.062), (mij2, 0.08, 0.078),
		(incheietura, 0.1, 0.098), (capat, 0.108, 0.105)], culoare, laturi=8, ref=(0, 0, 1)))
	piese.append(sfera("Umar", 0.07, umar, culoare, segmente=8, inele=5))
	# înăuntrul mânecii, întuneric (altfel s-ar vedea prin ea)
	piese.append(trunchi("Gura manecii", [(_lerp(cot, incheietura, 1.0), 0.088, 0.086), (_lerp(cot, incheietura, 1.06), 0.088, 0.086)],
		culoare_umbra, laturi=8, ref=(0, 0, 1)))


def _cap(piese, ochi, gat, s, r):
	"""Capul (fața lungă cu bărbie ascuțită, nas coroiat cu negel, gura strâmbă cu un dinte, pomeți supți, părul lung
	și pălăria). Ochii strălucitori merg în `ochi` (obiect separat, ca să strălucească în joc). `gat` = baza capului."""
	gx, gy, gz = gat
	piele, piele_umbra = s["piele"], s["piele_umbra"]
	piese.append(os_intre("Gat", (gx, gy + 0.02, gz - 0.08), (gx, gy - 0.005, gz + 0.04), 0.038, piele, laturi=6))
	nas = s.get("nas", 1.0)
	# fața: inele de jos în sus (z, y-ul centrului, rx, ry); bărbia iese mult în față
	fata = [
		(0.0, -0.085, 0.0, 0.0), (0.012, -0.083, 0.018, 0.016), (0.035, -0.066, 0.036, 0.04), (0.07, -0.04, 0.055, 0.066),
		(0.115, -0.022, 0.07, 0.082), (0.16, -0.014, 0.078, 0.088), (0.205, -0.01, 0.078, 0.088), (0.245, -0.006, 0.066, 0.078),
		(0.272, 0.0, 0.04, 0.05), (0.285, 0.004, 0.0, 0.0),
	]
	piese.append(trunchi("Fata", [((gx, gy + y, gz + z), rx, ry) for z, y, rx, ry in fata], piele, laturi=10))
	# nasul coroiat: urcă din frunte, iese mult și se îndoaie în jos la vârf
	piese.append(trunchi("Nas", [
		((gx, gy - 0.075, gz + 0.19), 0.013, 0.012),
		((gx, gy - 0.1 - 0.03 * nas, gz + 0.16), 0.017, 0.016),
		((gx, gy - 0.12 - 0.05 * nas, gz + 0.125), 0.016, 0.015),
		((gx, gy - 0.115 - 0.055 * nas, gz + 0.1), 0.011, 0.01),
		((gx, gy - 0.095 - 0.04 * nas, gz + 0.092), 0.0, 0.0),
	], piele, laturi=6))
	piese.append(sfera("Negel", 0.011, (gx + 0.014, gy - 0.115 - 0.04 * nas, gz + 0.145), piele_umbra, segmente=5, inele=3))
	piese.append(sfera("Negel barbie", 0.009, (gx - 0.02, gy - 0.07, gz + 0.03), piele_umbra, segmente=5, inele=3))
	# gura strâmbă, un dinte strâmb care iese în sus
	piese += [
		cub("Gura", (0.055, 0.01, 0.009), (gx, gy - 0.083, gz + 0.075), NEGRU, rot=(0, 0.12, 0)),
		cub("Buza", (0.06, 0.012, 0.006), (gx, gy - 0.086, gz + 0.067), piele_umbra, rot=(0, 0.12, 0)),
		cub("Dinte", (0.009, 0.008, 0.016), (gx + 0.013, gy - 0.092, gz + 0.082), OS, rot=(0, 0.2, 0)),
	]
	for k in (-1, 1):
		x = 0.034 * k
		piese += [
			# orbite adânci, întunecate
			cub("Orbita", (0.034, 0.012, 0.024), (gx + x, gy - 0.084, gz + 0.17), piele_umbra),
			# sprâncene groase, încruntate (coborâte spre nas)
			cub("Spranceana", (0.045, 0.014, 0.012), (gx + x * 1.05, gy - 0.088, gz + 0.192), s["par"], rot=(0, -0.4 * k, 0)),
			# pomeți supți
			sfera("Pomet", 0.02, (gx + 0.058 * k, gy - 0.06, gz + 0.135), piele_umbra, scara=(0.6, 0.6, 1.0), segmente=6, inele=4),
			# urechi ascuțite, ies prin păr
			trunchi("Ureche", [((gx + 0.076 * k, gy + 0.005, gz + 0.15), 0.012, 0.02), ((gx + 0.098 * k, gy + 0.02, gz + 0.19), 0.006, 0.01),
				((gx + 0.108 * k, gy + 0.035, gz + 0.215), 0.0, 0.0)], piele, laturi=4),
		]
		ochi += [
			cub("Ochi", (0.022, 0.008, 0.012), (gx + x, gy - 0.092, gz + 0.168), s["ochi"]),
		]
	if s.get("ochelari"):
		_ochelari(piese, gx, gy, gz, s["ochelari"])
	if s.get("coc"):
		# părul strâns (fără pălărie): o calotă peste creștet și ceafă, cocul în vârf, două șuvițe pe lângă urechi
		piese.append(sfera("Par", 0.094, (gx, gy + 0.03, gz + 0.205), s["par"], scara=(0.98, 1.0, 0.95), segmente=10, inele=7))
		piese.append(sfera("Coc", 0.052, (gx, gy + 0.085, gz + 0.3), s["par"], scara=(1.0, 0.9, 0.85), segmente=8, inele=5))
		piese.append(inel("Funda coc", 0.042, 0.008, (gx, gy + 0.085, gz + 0.262), s.get("par_suvita", s["par"]), segmente=10))
		for k in (-1, 1):
			piese.append(trunchi("Suvita", [((gx + 0.08 * k, gy - 0.02, gz + 0.2), 0.008, 0.005),
				((gx + 0.086 * k, gy - 0.035, gz + 0.12), 0.006, 0.004)], s.get("par_suvita", s["par"]), laturi=4))
		return
	# părul: șuvițe lungi, slinoase, de sub pălărie până pe umeri și spate
	for k in range(16):
		u = math.pi * (-0.15 + 1.3 * k / 15)  # de pe o parte, pe la spate, pe cealaltă parte
		raza = 0.083
		start = (gx + math.cos(u) * raza, gy + math.sin(u) * raza + 0.01, gz + 0.235)
		lung = s.get("par_lung", 0.38) * r.uniform(0.8, 1.15)
		iese = 0.07 + r.uniform(0, 0.04)
		mij = (start[0] + math.cos(u) * iese * 0.6 + r.uniform(-0.02, 0.02), start[1] + math.sin(u) * iese * 0.6 + 0.03,
			start[2] - lung * 0.45)
		cap_ = (start[0] + math.cos(u) * iese + r.uniform(-0.03, 0.03), start[1] + math.sin(u) * iese + 0.05 + r.uniform(0, 0.03),
			start[2] - lung)
		cul = s["par"] if k % 4 else s.get("par_suvita", s["par"])
		piese.append(trunchi("Suvita", [(start, 0.02, 0.012), (mij, 0.022, 0.011), (cap_, 0.01, 0.006)], cul, laturi=4,
			ref=(math.cos(u), math.sin(u), 0)))
	_palarie(piese, (gx, gy + 0.012, gz + 0.235), s.get("bor", 0.27) , s.get("inaltime_palarie", 0.5), s["palarie"],
		s["banda"], r, aplecare=0.03, varf=s.get("varf", (0.16, 0.05)))


def _ochelari(piese, gx, gy, gz, culoare):
	"""Ochelari rotunzi cu ramă subțire de metal: două cercuri în dreptul ochilor, puntea și brațele spre urechi."""
	y = gy - 0.106
	for k in (-1, 1):
		x = gx + 0.034 * k
		piese.append(_inel_vertical("Rama ochelari", 0.021, 0.003, (x, y, gz + 0.168), culoare))
		piese.append(cub("Brat ochelari", (0.004, 0.09, 0.004), (gx + 0.074 * k, y + 0.05, gz + 0.172), culoare))
	piese.append(cub("Punte ochelari", (0.026, 0.004, 0.004), (gx, y, gz + 0.174), culoare))


def _corp(piese, s, r, inaltime=1.0):
	"""Roba lungă până în pământ (cu tivul zdrențuit), brâul cu săculeț, craniu și fiolă, pelerina pe umeri,
	gluga lăsată pe spate și pantofii cu vârful întors. Întoarce înălțimea umerilor."""
	h = inaltime
	cocoasa = s.get("cocoasa", 0.0)
	aplecare = s.get("aplecare", 0.0)  # cât se apleacă în față (spre cazan)
	roba, umbra = s["roba"], s["roba_umbra"]
	inele = [  # (z, rx, ry, cât e împins centrul în față)
		(0.05, 0.34, 0.3, 0.0), (0.12, 0.325, 0.29, 0.0), (0.42, 0.265, 0.23, 0.0), (0.8, 0.2, 0.158, 0.0),
		(0.92, 0.186, 0.146, 0.0), (1.1, 0.2, 0.152, aplecare * 0.4), (1.26, 0.215, 0.152 + cocoasa * 0.3, aplecare * 0.8),
		(1.35, 0.2, 0.13 + cocoasa * 0.2, aplecare), (1.41, 0.12, 0.09, aplecare), (1.44, 0.06, 0.055, aplecare),
	]
	piese.append(trunchi("Roba", [((0, cocoasa * (0.5 if z > 1.15 else 0.0) - f, z * h), rx, ry) for z, rx, ry, f in inele],
		roba, laturi=12))
	# tivul zdrențuit: fâșii care atârnă până la pământ, de lungimi diferite
	for k in range(18):
		u = k * math.tau / 18 + r.uniform(-0.08, 0.08)
		lung = r.uniform(0.045, 0.075)
		piese.append(cub("Zdreanta", (0.085, 0.016, lung), (math.cos(u) * 0.343, math.sin(u) * 0.303, lung / 2),
			umbra if k % 3 == 0 else roba, rot=(0, 0, u + 1.5708)))
	# brâul (frânghie groasă) cu ce atârnă de el
	piese.append(trunchi("Brau", [((0, 0, 0.87 * h), 0.2, 0.158), ((0, 0, 0.95 * h), 0.198, 0.156)], s.get("brau", LEMN), laturi=12))
	piese.append(cub("Nod brau", (0.05, 0.03, 0.04), (0.05, -0.165, 0.91 * h), s.get("brau", LEMN)))
	piese.append(os_intre("Capat brau", (0.05, -0.17, 0.89 * h), (0.07, -0.19, 0.7 * h), 0.012, s.get("brau", LEMN), laturi=4))
	# săculețul cu ierburi
	piese.append(sfera("Saculet", 0.05, (-0.13, -0.145, 0.8 * h), p("7a7b59"), scara=(1, 0.8, 1.2), segmente=6, inele=5))
	piese.append(cilindru("Gura saculet", 0.02, 0.03, 0.03, (-0.13, -0.145, 0.865 * h), p("7a7b59"), laturi=6))
	# craniul mic (de pisică? de copil? nu întrebăm)
	cx, cy, cz = 0.13, -0.15, 0.79 * h
	piese += [
		sfera("Craniu", 0.042, (cx, cy, cz), OS, scara=(0.9, 1.0, 1.0), segmente=8, inele=5),
		cub("Falca", (0.04, 0.03, 0.022), (cx, cy - 0.02, cz - 0.04), OS),
		cub("Orbita craniu", (0.016, 0.008, 0.016), (cx - 0.016, cy - 0.04, cz + 0.004), NEGRU),
		cub("Orbita craniu", (0.016, 0.008, 0.016), (cx + 0.016, cy - 0.04, cz + 0.004), NEGRU),
		cub("Nas craniu", (0.008, 0.008, 0.012), (cx, cy - 0.043, cz - 0.016), NEGRU),
		os_intre("Sfoara craniu", (cx, cy, cz + 0.04), (cx - 0.04, cy - 0.01, 0.9 * h), 0.004, LEMN_INCHIS, laturi=4),
	]
	# fiola cu poțiune
	piese += [
		cilindru("Fiola", 0.022, 0.018, 0.08, (0.02, -0.18, 0.8 * h), p("438b88"), laturi=6),
		cilindru("Dop fiola", 0.012, 0.012, 0.02, (0.02, -0.18, 0.85 * h), LEMN, laturi=5),
	]
	# pelerina scurtă peste umeri (zdrențuită jos) și gluga lăsată pe spate
	pel = s.get("pelerina", umbra)
	piese.append(trunchi("Pelerina", [
		((0, 0.0 - aplecare, 1.445 * h), 0.085, 0.075),
		((0, 0.005 - aplecare, 1.395 * h), 0.235, 0.17 + cocoasa * 0.2),
		((0, 0.015 - aplecare * 0.9 + cocoasa * 0.3, 1.29 * h), 0.25, 0.18 + cocoasa * 0.3),
		((0, 0.03 - aplecare * 0.6 + cocoasa * 0.3, 1.12 * h), 0.235, 0.185 + cocoasa * 0.2),
	], pel, laturi=12, capete=False))
	for k in range(10):  # colțurile zdrențuite ale pelerinei, mai ales la spate
		u = math.pi * (0.1 + 0.8 * k / 9)
		piese.append(cub("Colt pelerina", (0.07, 0.014, 0.08), (math.cos(u) * 0.24, 0.03 - aplecare * 0.6 + cocoasa * 0.3 + math.sin(u) * 0.19,
			1.08 * h), pel, rot=(0, 0, u + 1.5708)))
	piese.append(sfera("Gluga", 0.12, (0, 0.17 - aplecare + cocoasa * 0.3, 1.39 * h), pel, scara=(1.2, 0.55, 0.8), segmente=8, inele=5))
	# pantofii cu vârful întors, ies de sub robă în față
	for k in (-1, 1):
		x = 0.09 * k
		piese.append(trunchi("Pantof", [
			((x, -0.2, 0.035), 0.0, 0.0), ((x, -0.22, 0.035), 0.042, 0.034), ((x + 0.01 * k, -0.3, 0.03), 0.04, 0.03),
			((x + 0.015 * k, -0.37, 0.035), 0.022, 0.018), ((x + 0.02 * k, -0.41, 0.065), 0.01, 0.01),
			((x + 0.022 * k, -0.4, 0.095), 0.0, 0.0),
		], NEGRU, laturi=6, faza=0.52))
		piese.append(cub("Catarama pantof", (0.03, 0.012, 0.022), (x + 0.008 * k, -0.29, 0.065), AUR, rot=(0.25, 0, 0)))
	return (1.37 * h, aplecare)


# Stilurile vrăjitoarelor din cerc: fiecare altfel la piele, haine, păr, nas și cocoașă.
CERC = [
	dict(piele=p("5b6d4e"), piele_umbra=p("445d46"), roba=p("2a3c3d"), roba_umbra=p("262d2f"), pelerina=p("32453b"),
		par=p("262d2f"), par_suvita=p("70706e"), palarie=p("262d2f"), banda=p("7b383a"), ochi=p("a18463"),
		cocoasa=0.06, nas=1.3, varf=(0.18, 0.06), inaltime=0.98),
	dict(piele=p("7e8d87"), piele_umbra=p("70706e"), roba=p("553e4d"), roba_umbra=p("48313b"), pelerina=p("48313b"),
		par=p("7e8d87"), par_suvita=p("83b3b0"), palarie=p("48313b"), banda=p("5b6d4e"), ochi=p("a18463"),
		cocoasa=0.1, nas=1.6, varf=(-0.15, 0.08), inaltime=0.93, par_lung=0.45),
	dict(piele=p("7a7b59"), piele_umbra=p("5b6d4e"), roba=p("32453b"), roba_umbra=p("2a3c3d"), pelerina=p("295555"),
		par=p("5e363e"), par_suvita=p("7b383a"), palarie=p("2a3c3d"), banda=p("904a40"), ochi=p("a18463"),
		cocoasa=0.0, nas=1.0, varf=(0.12, -0.1), inaltime=1.02, par_lung=0.5),
	dict(piele=p("70706e"), piele_umbra=p("5e5356"), roba=p("48313b"), roba_umbra=p("262d2f"), pelerina=p("2a3c3d"),
		par=p("262d2f"), par_suvita=p("48313b"), palarie=p("262d2f"), banda=p("438b88"), ochi=p("a18463"),
		cocoasa=0.04, nas=1.4, varf=(-0.08, 0.16), inaltime=0.96, par_lung=0.32),
]


def vrajitoare_cerc(cale, nume, s, saminta):
	"""O vrăjitoare din cercul din jurul cazanului: aplecată spre cazan, cu brațele întinse peste el, degetele
	răsfirate (descântă). Piese separate: `Cap` (originea în gât: se uită în cazan, apoi la cer), `Brate` (ambele
	brațe, originea între umeri: le ridică la cer când pornește vraja), `Ochi` (copil al capului, strălucesc)."""
	curata()
	r = random.Random(saminta)
	s = dict(s, aplecare=0.05)
	h = s["inaltime"]
	piese = []
	z_umar, aplecare = _corp(piese, s, r, h)
	uneste(piese, "Corp")

	# brațele: întinse înainte și puțin în jos, spre cazan, mâinile cu palma în jos
	brate = []
	for k in (-1, 1):
		umar = (0.2 * k, -aplecare, z_umar)
		cot = (0.27 * k, -0.2 - aplecare, z_umar - 0.13)
		inch = (0.17 * k, -0.45 - aplecare, z_umar - 0.2)
		_maneca(brate, umar, cot, inch, s["roba"], s["roba_umbra"])
		d = [b - a for a, b in zip(cot, inch)]
		l = math.sqrt(sum(v * v for v in d))
		d = [v / l for v in d]
		_mana(brate, _lerp(cot, inch, 1.02), d, (-k * 0.9, 0.0, -0.3), s["piele"], NEGRU, r)
	uneste(brate, "Brate", (0, -aplecare, z_umar))

	cap, ochi = [], []
	_cap(cap, ochi, (0, -aplecare - 0.02, (1.445 + 0.03) * h), s, r)
	ob_cap = uneste(cap, "Cap", (0, -aplecare - 0.02, 1.445 * h))
	_parinte(uneste(ochi, "Ochi", (0, -aplecare - 0.1, 1.6 * h)), ob_cap)
	exporta(os.path.join(cale, nume + ".glb"))


SEFA = dict(piele=p("7e8d87"), piele_umbra=p("70706e"), roba=p("655269"), roba_umbra=p("553e4d"), pelerina=p("48313b"),
	par=p("7b383a"), par_suvita=p("904a40"), palarie=p("262d2f"), banda=p("655269"), ochi=p("438b88"), brau=p("a18463"),
	cocoasa=0.0, nas=1.15, varf=(0.22, 0.1), inaltime=1.06, par_lung=0.6, bor=0.31, inaltime_palarie=0.62)


def vrajitoare_sefa(cale):
	"""Head Witch: mai înaltă, robă mov cu fir de aur, guler înalt ca evantaiul, păr roșu lung, amuletă verde la gât.
	Stă dreaptă, cu mâna stângă în șold. Piese separate: `Cap` (originea în gât) cu `Ochi`, `BratDrept` (originea în
	umăr, atârnă pe lângă corp: îți întinde pistolul, scoate mătura), `Amuleta` (strălucește)."""
	curata()
	r = random.Random(1313)
	s = SEFA
	h = s["inaltime"]
	piese = []
	z_umar, _ = _corp(piese, s, r, h)
	# firul de aur: dungi pe robă (pe tiv și pe mijloc, în față) și stele/luni cusute
	piese.append(trunchi("Tiv aur", [((0, 0, 0.13 * h), 0.33, 0.294), ((0, 0, 0.17 * h), 0.322, 0.287)], AUR, laturi=12))
	for z, x, dim in ((0.35, -0.1, 0.04), (0.55, 0.12, 0.035), (0.68, -0.05, 0.03), (0.25, 0.15, 0.03), (1.15, 0.12, 0.03)):
		# raza robei la înălțimea asta (aproximativ), ca steaua să stea la 1 cm peste ea
		ry = 0.3 - (z - 0.05) / 0.87 * 0.15
		y = -math.sqrt(max(ry * ry * (1 - (x / (ry * 1.15)) ** 2), 0.01)) - 0.012
		piese.append(cub("Stea", (dim, 0.01, dim), (x, y, z * h), AUR, rot=(0, 0.785, 0)))
		piese.append(cub("Stea", (dim * 0.7, 0.012, dim * 0.7), (x, y - 0.002, z * h), AUR))
	# lanțul amuletei
	for k in range(9):
		u = math.pi * (0.15 + 0.7 * k / 8)
		cade = math.sin(u)
		piese.append(cub("Za", (0.014, 0.01, 0.01), (math.cos(u) * 0.075, -0.07 - cade * 0.07, 1.42 * h - cade * 0.09), AUR,
			rot=(0.5, 0, u)))
	# brațul stâng: în șold, cotul în lături
	umar, cot, inch = (0.21, 0.0, z_umar), (0.36, 0.05, z_umar - 0.25), (0.21, -0.03, z_umar - 0.42)
	_maneca(piese, umar, cot, inch, s["roba"], s["roba_umbra"])
	_mana(piese, _lerp(cot, inch, 1.02), (-0.6, -0.1, -0.79), (0.0, -1.0, 0.0), s["piele"], NEGRU, r, deschisa=False)
	piese.append(trunchi("Manseta aur", [(_lerp(cot, inch, 0.96), 0.104, 0.102), (_lerp(cot, inch, 1.0), 0.106, 0.104)], AUR, laturi=8,
		ref=(0, 0, 1)))
	uneste(piese, "Corp")
	uneste([
		trunchi("Amuleta", [((0, -0.17, 1.33 * h), 0.0, 0.0), ((0, -0.17, 1.34 * h), 0.03, 0.03), ((0, -0.17, 1.36 * h), 0.03, 0.03),
			((0, -0.17, 1.37 * h), 0.0, 0.0)], p("438b88"), laturi=6, ref=(1, 0, 0)),
	], "Amuleta")
	# rama de aur a amuletei, în spatele pietrei
	piese_rama = [cilindru("Rama amuleta", 0.038, 0.038, 0.012, (0, -0.158, 1.35 * h), AUR, laturi=6, rot=(1.5708, 0, 0))]
	ob_corp = bpy_obiect("Corp")
	ob_rama = uneste(piese_rama, "RamaAmuleta")
	_lipeste(ob_corp, ob_rama)

	# brațul drept: atârnă pe lângă corp, mâna deschisă (ține pistolul, apoi mătura)
	umar, cot, inch = (-0.21, 0.0, z_umar), (-0.25, 0.02, z_umar - 0.28), (-0.235, -0.04, z_umar - 0.53)
	brat = []
	_maneca(brat, umar, cot, inch, s["roba"], s["roba_umbra"])
	_mana(brat, _lerp(cot, inch, 1.02), (0.06, -0.15, -0.99), (0.9, -0.3, 0.0), s["piele"], NEGRU, r)
	brat.append(trunchi("Manseta aur", [(_lerp(cot, inch, 0.96), 0.104, 0.102), (_lerp(cot, inch, 1.0), 0.106, 0.104)], AUR, laturi=8,
		ref=(0, 0, 1)))
	uneste(brat, "BratDrept", umar)

	cap, ochi = [], []
	_cap(cap, ochi, (0, -0.02, 1.475 * h), s, r)
	ob_cap = uneste(cap, "Cap", (0, -0.02, 1.445 * h))
	_parinte(uneste(ochi, "Ochi", (0, -0.1, 1.6 * h)), ob_cap)
	exporta(os.path.join(cale, "vrajitoare_sefa.glb"))


def bpy_obiect(nume):
	import bpy
	return bpy.data.objects[nume]


def _inel_vertical(nume, raza, grosime, loc, culoare):
	"""Inel (tor) în picioare, în planul XZ (toartele cazanului)."""
	import bpy
	from unelte import _termina
	bpy.ops.mesh.primitive_torus_add(major_segments=10, minor_segments=4, major_radius=raza, minor_radius=grosime,
		location=loc, rotation=(1.5708, 0, 0))
	return _termina(bpy.context.active_object, nume, culoare)


def _lipeste(ob, altul):
	"""Lipește `altul` în `ob` (același obiect, aceeași origine)."""
	import bpy
	bpy.ops.object.select_all(action='DESELECT')
	ob.select_set(True)
	altul.select_set(True)
	bpy.context.view_layer.objects.active = ob
	bpy.ops.object.join()


# ---------------------------------------------------------------------------------------------------------------
# Cazanul
# ---------------------------------------------------------------------------------------------------------------

def cazan(cale):
	"""Cazanul mare de fontă (încape un om în el): pântecos, pe trei picioare cu gheare, cu buza groasă, două toarte
	mari, o bandă bătută în nituri și rune pe ea, un polonic mare rezemat în el și un os care iese peste buză.
	Dedesubt, focul: bușteni încrucișați într-un cerc de pietre. Originea = solul, la mijloc.
	Piese separate: `Lichid` (oglinda poțiunii cu bule, originea în mijlocul ei: își schimbă culoarea în joc) și
	`Foc` (flăcările, strălucesc și pâlpâie)."""
	curata()
	r = random.Random(666)
	fonta, fonta_umbra = NEGRU, p("2a3c3d")
	R, CZ, SZ = 0.86, 0.82, 0.85  # raza, înălțimea centrului, turtirea pe verticală
	Z_BUZA = 1.3
	piese = [sfera_deschisa("Corp", R, (0, 0, CZ), fonta, z_taiere=Z_BUZA, grosime=0.05, scara=(1, 1, SZ), segmente=16, inele=12)]

	def raza_la(z):
		t = (z - CZ) / (R * SZ)
		return R * math.sqrt(max(1 - t * t, 0.0))

	rb = raza_la(Z_BUZA)
	piese += [
		inel("Buza", rb + 0.01, 0.055, (0, 0, Z_BUZA + 0.01), fonta, segmente=16),
		inel("Buza", rb + 0.06, 0.03, (0, 0, Z_BUZA - 0.03), fonta_umbra, segmente=16),
	]
	# banda bătută în nituri, cu rune
	zb = 0.95
	rbd = raza_la(zb) + 0.012
	piese.append(trunchi("Banda", [((0, 0, zb - 0.05), rbd, rbd), ((0, 0, zb + 0.05), rbd - 0.004, rbd - 0.004)], fonta_umbra, laturi=16))
	for k in range(16):
		u = k * math.tau / 16 + math.tau / 32
		piese.append(sfera("Nit", 0.016, (math.cos(u) * (rbd + 0.005), math.sin(u) * (rbd + 0.005), zb), PIATRA, segmente=5, inele=3))
	for k in range(6):  # rune scrijelite, roșii ca rugina
		u = k * math.tau / 6
		x, y = math.cos(u) * (rbd + 0.01), math.sin(u) * (rbd + 0.01)
		piese.append(cub("Runa", (0.012, 0.012, 0.06), (x, y, zb + 0.13), p("7b383a"), rot=(0, 0.3 * (k % 2 * 2 - 1), u + 1.5708)))
		piese.append(cub("Runa", (0.04, 0.012, 0.012), (x, y, zb + 0.15 - 0.02 * (k % 3)), p("7b383a"), rot=(0, 0, u + 1.5708)))
	# toartele: inele mari, prinse în urechi
	for k in (-1, 1):
		ru = raza_la(1.18)
		piese.append(cub("Ureche toarta", (0.06, 0.08, 0.08), (k * (ru + 0.02), 0, 1.18), fonta_umbra))
		piese.append(_inel_vertical("Toarta", 0.12, 0.022, (k * (ru + 0.12), 0, 1.13), fonta))
	# picioarele scurte, cu gheare
	for k in range(3):
		u = k * math.tau / 3 + 0.5
		sus = (math.cos(u) * 0.5, math.sin(u) * 0.5, 0.32)
		jos = (math.cos(u) * 0.62, math.sin(u) * 0.62, 0.04)
		piese.append(trunchi("Picior", [(sus, 0.07, 0.07), (_lerp(sus, jos, 0.5), 0.05, 0.05), (jos, 0.06, 0.06)], fonta, laturi=6))
		for g in (-1, 0, 1):  # ghearele
			gu = u + g * 0.35
			piese.append(trunchi("Gheara", [(jos, 0.03, 0.025), ((jos[0] + math.cos(gu) * 0.11, jos[1] + math.sin(gu) * 0.11, 0.015), 0.0, 0.0)],
				fonta, laturi=4))
	# focul de dedesubt: pietre în cerc, bușteni încrucișați, jar
	for k in range(11):
		u = k * math.tau / 11 + r.uniform(-0.1, 0.1)
		rr = 0.98 + r.uniform(-0.05, 0.05)
		piese.append(sfera("Piatra", 0.11 + r.uniform(-0.02, 0.03), (math.cos(u) * rr, math.sin(u) * rr, 0.05),
			PIATRA if k % 3 else PIATRA_INCHISA, scara=(1.2, 1.0, 0.7), segmente=6, inele=4))
	for k in range(5):
		u = k * math.tau / 5 + 0.3
		a = (math.cos(u) * 0.72, math.sin(u) * 0.72, 0.06)
		b = (math.cos(u + math.pi) * 0.12, math.sin(u + math.pi) * 0.12, 0.2)
		piese.append(os_intre("Bustean", a, b, 0.055, LEMN if k % 2 else LEMN_INCHIS, laturi=6))
		piese.append(cub("Carbune", (0.05, 0.05, 0.03), (a[0] * 0.5, a[1] * 0.5, 0.03), p("7b383a"), rot=(0, 0, u)))
	# polonicul mare de lemn, rezemat în cazan
	piese.append(os_intre("Polonic", (0.25, 0.1, 0.95), (0.62, 0.42, 1.95), 0.025, LEMN, laturi=5))
	piese.append(sfera("Cauc polonic", 0.08, (0.2, 0.06, 0.88), LEMN, scara=(1, 1, 0.5), segmente=6, inele=4))
	# un os mare (de picior) care iese peste buză
	piese.append(os_intre("Os", (-0.3, -0.2, 1.05), (-0.65, -0.38, 1.55), 0.025, OS, laturi=5))
	piese.append(sfera("Capat os", 0.045, (-0.65, -0.38, 1.56), OS, scara=(1.3, 1, 0.8), segmente=6, inele=4))
	uneste(piese, "Cazan")

	# poțiunea: oglinda puțin sub buză, cu bule. Culoarea o dă jocul (e albă aici).
	zl = Z_BUZA - 0.09
	rl = raza_la(zl) - 0.06
	lichid = [cilindru("Lichid", rl, rl, 0.012, (0, 0, zl), OS, laturi=16)]
	for k in range(9):
		u = r.uniform(0, math.tau)
		d = r.uniform(0.0, rl * 0.8)
		rz = r.uniform(0.025, 0.06)
		lichid.append(sfera("Bula", rz, (math.cos(u) * d, math.sin(u) * d, zl + 0.004), OS, scara=(1, 1, 0.6), segmente=6, inele=4))
	uneste(lichid, "Lichid", (0, 0, zl))

	# flăcările: limbi de foc printre bușteni
	foc = []
	for k in range(9):
		u = k * math.tau / 9 + r.uniform(-0.2, 0.2)
		d = r.uniform(0.15, 0.5)
		hf = r.uniform(0.2, 0.36)
		foc.append(cilindru("Flacara", 0.08, 0.0, hf, (math.cos(u) * d, math.sin(u) * d, 0.1 + hf / 2), AUR if k % 2 else p("904a40"),
			laturi=4, rot=(r.uniform(-0.2, 0.2), r.uniform(-0.2, 0.2), u)))
	uneste(foc, "Foc", (0, 0, 0.1))
	exporta(os.path.join(cale, "cazan.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Pistolul roz și mătura
# ---------------------------------------------------------------------------------------------------------------

def pistol_roz(cale):
	"""Pistol compact, cu inimioară pe mâner și strasuri pe închizător (de la Head Witch, cine altcineva).
	E făcut în culorile paletei, din cea mai deschisă (83b3b0); rozul îl dă jocul (shaders/material_roz.tres).
	Țeava spre +Y (în Godot: -Z, adică înainte, ca la cameră). Originea = locul unde îl ții (sus pe mâner).
	`Strasuri` e separat (strălucește)."""
	curata()
	corp, inchis, inima = OS, NEGRU, p("7b383a")
	piese = [
		# închizătorul (partea de sus), cu zimți la spate
		cub("Inchizator", (0.028, 0.18, 0.034), (0, 0.045, 0.04), corp),
		cub("Teava", (0.012, 0.012, 0.012), (0, 0.14, 0.037), inchis),
		cub("Gura tevii", (0.007, 0.004, 0.007), (0, 0.148, 0.037), NEGRU),
		cub("Inaltator", (0.006, 0.012, 0.008), (0, 0.125, 0.061), inchis),
		cub("Catare", (0.02, 0.01, 0.009), (0, -0.035, 0.0615), inchis),
		cub("Fereastra", (0.018, 0.04, 0.004), (0, 0.06, 0.059), inchis),
		# cadrul de dedesubt
		cub("Cadru", (0.026, 0.15, 0.022), (0, 0.035, 0.012), corp),
		# mânerul, înclinat spre spate
		cub("Maner", (0.03, 0.05, 0.11), (0, -0.025, -0.045), corp, rot=(-0.28, 0, 0)),
		cub("Talpa magazie", (0.034, 0.056, 0.014), (0, -0.04, -0.101), inchis, rot=(-0.28, 0, 0)),
		# trăgaciul și apărătoarea
		cub("Tragaci", (0.008, 0.008, 0.024), (0, 0.032, -0.012), inchis, rot=(0.3, 0, 0)),
		cub("Aparatoare", (0.012, 0.06, 0.008), (0, 0.04, -0.03), corp),
		cub("Aparatoare", (0.012, 0.008, 0.03), (0, 0.068, -0.016), corp),
	]
	for k in range(5):  # zimții închizătorului, pe ambele părți
		for sx in (-1, 1):
			piese.append(cub("Zimt", (0.004, 0.004, 0.026), (sx * 0.0155, -0.03 + k * 0.009, 0.04), corp))
	for sx in (-1, 1):  # inimioara pe mâner, pe ambele părți
		x = sx * 0.017
		piese += [
			sfera("Inima", 0.009, (x, -0.022, -0.035), inima, scara=(0.4, 1, 1), segmente=6, inele=4),
			sfera("Inima", 0.009, (x, -0.034, -0.032), inima, scara=(0.4, 1, 1), segmente=6, inele=4),
			cub("Inima", (0.006, 0.014, 0.014), (x, -0.03, -0.043), inima, rot=(0.785, 0, 0)),
		]
	uneste(piese, "Pistol")
	stras = []
	for k in range(6):
		stras.append(cub("Stras", (0.008, 0.008, 0.006), (0, -0.02 + k * 0.022, 0.06), p("7e8d87"), rot=(0, 0, 0.785)))
	uneste(stras, "Strasuri")
	exporta(os.path.join(cale, "pistol_roz.glb"))


def matura_zbor(cale):
	"""Mătura de zbor a lui Head Witch: coadă lungă, noduroasă și strâmbă, cu mâner de prins în față, paiele
	strânse în trei legături și răsfirate la capăt. Lungă pe Y: vârful cozii spre +Y (în Godot: -Z, înainte),
	paiele spre -Y. Originea = mijlocul cozii (acolo stă ea; tu stai mai în spate)."""
	curata()
	r = random.Random(9)
	lemn, lemn_inchis = p("5e363e"), p("48313b")
	# coada: trasă prin puncte, puțin strâmbă, mai groasă spre paie
	drum = [(0, 1.05, 0.06), (0.01, 0.8, 0.02), (-0.01, 0.4, 0.0), (0.012, 0.0, 0.0), (-0.008, -0.4, 0.0), (0, -0.7, 0.01)]
	raze = [0.02, 0.022, 0.024, 0.026, 0.027, 0.028]
	piese = [trunchi("Coada", [(c, rr, rr) for c, rr in zip(drum, raze)], lemn, laturi=6)]
	for k in range(6):  # nodurile din lemn
		t = r.uniform(0.05, 0.9)
		i = int(t * (len(drum) - 1))
		c = _lerp(drum[i], drum[i + 1], t * (len(drum) - 1) - i)
		piese.append(sfera("Nod", 0.03, c, lemn_inchis, scara=(1, 0.8, 1), segmente=5, inele=3))
	# vârful cozii, încârligat în sus
	piese.append(trunchi("Carlig", [((0, 1.05, 0.06), 0.02, 0.02), ((0, 1.12, 0.12), 0.017, 0.017), ((0, 1.1, 0.19), 0.014, 0.014),
		((0, 1.05, 0.2), 0.0, 0.0)], lemn, laturi=6))
	# paiele: un con lung, răsfirat, din fâșii
	piese.append(trunchi("Paie", [((0, -0.62, 0.01), 0.05, 0.05), ((0, -0.8, 0.0), 0.1, 0.09), ((0, -1.05, -0.01), 0.16, 0.14),
		((0, -1.2, -0.015), 0.19, 0.16)], PAIE, laturi=10))
	for k in range(24):  # fire care ies din mănunchi
		u = k * math.tau / 24
		a = (math.cos(u) * 0.12, -0.95, math.sin(u) * 0.11)
		b = (math.cos(u) * 0.25, -1.28 + r.uniform(-0.03, 0.03), math.sin(u) * 0.21)
		piese.append(os_intre("Fir", a, b, 0.012, PAIE if k % 3 else p("904a40"), laturi=4))
	for y, rr in ((-0.66, 0.06), (-0.76, 0.088), (-0.86, 0.112)):  # legăturile cu sfoară roșie
		piese.append(trunchi("Legatura", [((0, y + 0.015, 0.0), rr, rr), ((0, y - 0.015, 0.0), rr + 0.003, rr + 0.003)],
			p("7b383a"), laturi=10))
	uneste(piese, "Matura")
	exporta(os.path.join(cale, "matura_zbor.glb"))


def torta(cale):
	"""Torță înfiptă în pământ: par strâmb de lemn, cap înfășurat în cârpe unse, legat cu sârmă, și un craniu mic
	înfipt mai jos (de decor). Flacăra e separată (`Flacara`, pâlpâie și strălucește). Originea = solul."""
	curata()
	r = random.Random(31)
	piese = [
		trunchi("Par", [((0, 0, -0.05), 0.035, 0.035), ((0.02, 0.01, 0.7), 0.03, 0.03), ((-0.01, 0.0, 1.45), 0.028, 0.028)], LEMN, laturi=6),
		trunchi("Carpe", [((-0.01, 0.0, 1.38), 0.05, 0.05), ((-0.01, 0.0, 1.5), 0.065, 0.06), ((-0.01, 0.0, 1.6), 0.055, 0.05)],
			p("5e5356"), laturi=6),
		trunchi("Sarma", [((-0.01, 0.0, 1.43), 0.06, 0.056), ((-0.01, 0.0, 1.45), 0.06, 0.056)], PIATRA, laturi=6),
		trunchi("Funingine", [((-0.01, 0.0, 1.6), 0.055, 0.05), ((-0.01, 0.0, 1.63), 0.04, 0.035)], NEGRU, laturi=6),
	]
	uneste(piese, "Torta")
	foc = []
	for k in range(5):
		u = k * math.tau / 5
		hf = r.uniform(0.18, 0.3)
		foc.append(cilindru("Flacara", 0.045, 0.0, hf, (math.cos(u) * 0.025, math.sin(u) * 0.025, 1.63 + hf / 2), AUR if k % 2 else p("904a40"),
			laturi=4, rot=(r.uniform(-0.15, 0.15), r.uniform(-0.15, 0.15), u)))
	uneste(foc, "Flacara", (0, 0, 1.63))
	exporta(os.path.join(cale, "torta.glb"))


def toate(cale):
	for i, s in enumerate(CERC):
		vrajitoare_cerc(cale, "vrajitoare_%d" % (i + 1), s, 100 + i)
	vrajitoare_sefa(cale)
	cazan(cale)
	pistol_roz(cale)
	matura_zbor(cale)
	torta(cale)


if __name__ == "__main__":
	toate(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models"))
