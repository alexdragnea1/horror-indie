# Warlock-ul și armata lui de vrăjitori, care atacă sediul coven-ului (conac.tscn, atac_conac.gd).
# Le apelează modele.py, dar merge și singur (mai repede, doar astea):
#   blender --background --factory-startup --python tools/blender/warlock.py
#   blender --background --factory-startup --python tools/blender/warlock.py -- warlock vrajitor_1
# Axe Blender: Z în sus, fața modelului spre -Y (în Godot devine +Z). Originea = la sol. Dreapta lor = -X.
import math
import os
import random
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, uneste, exporta, trunchi  # noqa: E402
from coven import _maneca, _mana, _lerp, _parinte, _inel_vertical  # noqa: E402

NEGRU = p("262d2f")
NEGRU_VERDE = p("2a3c3d")
ROSU_INCHIS = p("5e363e")
ROSU = p("7b383a")
ROSU_APRINS = p("904a40")
PORTOCALIU = p("a56850")
AUR = p("a18463")
OS = p("83b3b0")
OS_UMBRA = p("7e8d87")
GRI = p("70706e")
GRI_INCHIS = p("5e5356")
LEMN = p("48313b")
VERDE = p("438b88")


def _norm(v):
	l = math.sqrt(sum(x * x for x in v))
	return tuple(x / l for x in v)


def _raza_la(inele, z):
	"""Raza (rx, ry) a unei forme făcute din inele [(z, rx, ry)], la înălțimea z (interpolare liniară)."""
	for (z0, a0, b0), (z1, a1, b1) in zip(inele, inele[1:]):
		if z0 <= z <= z1:
			t = (z - z0) / (z1 - z0)
			return a0 + (a1 - a0) * t, b0 + (b1 - b0) * t
	return inele[-1][1], inele[-1][2]


def _roba(piese, inele, culoare, umbra, r, zdrente=20):
	"""Roba lungă până în pământ (inele = [(z, rx, ry)]), cu tivul zdrențuit: fâșii care atârnă până jos."""
	piese.append(trunchi("Roba", [((0, 0, z), rx, ry) for z, rx, ry in inele], culoare, laturi=14))
	rx, ry = inele[0][1], inele[0][2]
	for k in range(zdrente):
		u = k * math.tau / zdrente + r.uniform(-0.08, 0.08)
		lung = r.uniform(0.05, 0.11)
		piese.append(cub("Zdreanta", (0.1, 0.018, lung), (math.cos(u) * (rx + 0.004), math.sin(u) * (ry + 0.004), lung / 2),
			umbra if k % 3 == 0 else culoare, rot=(0, 0, u + math.pi / 2)))


def _banda_fata(piese, lumini, inele, z0, z1, latime, culoare, runa=None, pas=0.2):
	"""O bandă care coboară pe fața robei (deschizătura hainei), din bucăți care urmează panta robei, cu 1,2 cm în fața
	ei; pe ea, din `pas` în `pas`, câte o rună care strălucește (în `lumini`), încă 1 cm mai în față."""
	n = max(int((z1 - z0) / 0.1), 1)
	for k in range(n):
		za, zb = z0 + (z1 - z0) * k / n, z0 + (z1 - z0) * (k + 1) / n
		ya = -_raza_la(inele, za)[1] - 0.012
		yb = -_raza_la(inele, zb)[1] - 0.012
		lung = math.hypot(zb - za, yb - ya)
		piese.append(cub("Banda", (latime, 0.014, lung + 0.005), (0, (ya + yb) / 2, (za + zb) / 2), culoare,
			rot=(math.atan2(ya - yb, zb - za), 0, 0)))
	if runa is None:
		return
	z = z0 + pas * 0.6
	k = 0
	while z < z1 - 0.06:
		y = -_raza_la(inele, z)[1] - 0.032
		if k % 2:
			lumini.append(cub("Runa", (latime * 0.12, 0.01, latime * 0.55), (0, y, z), runa))
			lumini.append(cub("Runa", (latime * 0.4, 0.01, latime * 0.1), (0, y - 0.001, z + latime * 0.12), runa, rot=(0, 0.5, 0)))
		else:
			lumini.append(cub("Runa", (latime * 0.4, 0.01, latime * 0.1), (0, y, z), runa, rot=(0, 0.785, 0)))
			lumini.append(cub("Runa", (latime * 0.4, 0.01, latime * 0.1), (0, y - 0.001, z), runa, rot=(0, -0.785, 0)))
		z += pas
		k += 1


def _mantie(piese, nume, z_sus, z_jos, raza_sus, raza_jos, u0, u1, culoare, r, falduri=7, grosime=0.025):
	"""Mantie (o pânză curbată pe un arc în jurul corpului, de la `u0` la `u1` radiani, 0 = +X, pi/2 = spate), de la umeri
	(`z_sus`, raza (rx, ry) `raza_sus`) până jos (`z_jos`, `raza_jos`), cu falduri (raza unduită) și marginea de jos
	zdrențuită (fiecare coloană se termină la altă înălțime). Are grosime, ca să se vadă din ambele părți."""
	import bmesh
	import bpy
	from unelte import _coloreaza
	nu, nv = 28, 10
	bm = bmesh.new()
	capete = [r.uniform(0.0, 0.16) for _ in range(nu + 1)]
	randuri = []
	for j in range(nv + 1):
		t = j / nv
		rand = []
		for i in range(nu + 1):
			u = u0 + (u1 - u0) * i / nu
			jos = z_jos + capete[i] if j == nv else None
			z = z_sus + (z_jos - z_sus) * t if jos is None else jos
			rx = raza_sus[0] + (raza_jos[0] - raza_sus[0]) * t ** 0.8
			ry = raza_sus[1] + (raza_jos[1] - raza_sus[1]) * t ** 0.8
			fald = 1.0 + 0.07 * t * math.sin(i / nu * falduri * math.tau)
			rand.append(bm.verts.new((math.cos(u) * rx * fald, math.sin(u) * ry * fald + 0.04 * t, z)))
		randuri.append(rand)
	for j in range(nv):
		for i in range(nu):
			bm.faces.new((randuri[j][i], randuri[j][i + 1], randuri[j + 1][i + 1], randuri[j + 1][i]))
	me = bpy.data.meshes.new(nume)
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new(nume, me)
	bpy.context.scene.collection.objects.link(ob)
	bpy.context.view_layer.objects.active = ob
	ob.select_set(True)
	mod = ob.modifiers.new("grosime", 'SOLIDIFY')
	mod.thickness = grosime
	bpy.ops.object.modifier_apply(modifier=mod.name)
	_coloreaza(ob, culoare)
	piese.append(ob)
	return ob


def _gluga(piese, ochi, gat, culoare, rama, gol=NEGRU, ochi_culoare=ROSU_APRINS, masca=None, marime=1.0):
	"""Glugă ascuțită trasă peste cap, cu vârful căzut pe spate. În față, golul negru (nu i se vede fața), iar în el doi
	ochi care strălucesc (`ochi`). Cu `masca` (culoare), în gol stă o mască de os cu orbite goale și dinți, iar ochii
	ard în orbite. `gat` = baza capului."""
	gx, gy, gz = gat
	m = marime
	piese.append(trunchi("Gluga", [
		((gx, gy + 0.03 * m, gz - 0.02 * m), 0.15 * m, 0.15 * m), ((gx, gy + 0.02 * m, gz + 0.1 * m), 0.165 * m, 0.17 * m),
		((gx, gy + 0.03 * m, gz + 0.22 * m), 0.15 * m, 0.16 * m), ((gx, gy + 0.08 * m, gz + 0.33 * m), 0.095 * m, 0.1 * m),
		((gx, gy + 0.16 * m, gz + 0.41 * m), 0.04 * m, 0.045 * m), ((gx, gy + 0.24 * m, gz + 0.42 * m), 0.0, 0.0),
	], culoare, laturi=12))
	# marginea glugii în jurul feței (un inel gros, în picioare) și golul negru din ea
	piese.append(_inel_vertical("Margine gluga", 0.118 * m, 0.022 * m, (gx, gy - 0.142 * m, gz + 0.13 * m), rama))
	piese.append(sfera("Gol", 0.115 * m, (gx, gy - 0.1 * m, gz + 0.13 * m), gol, scara=(0.95, 0.55, 1.05), segmente=10, inele=7))
	if masca:
		# masca de os, ca un craniu: fruntea lată, pomeții ieșiți, bărbia îngustă, orbite mari și adânci, nasul tăiat, dinții
		mz = gz + 0.12 * m
		my = gy - 0.155 * m
		piese.append(sfera("Masca", 0.085 * m, (gx, my, mz + 0.012 * m), masca, scara=(0.95, 0.42, 1.0), segmente=10, inele=7))
		piese.append(sfera("Barbie masca", 0.06 * m, (gx, my + 0.004, mz - 0.045 * m), masca, scara=(0.85, 0.5, 0.9), segmente=8, inele=5))
		for k in (-1, 1):
			piese.append(sfera("Pomet", 0.026 * m, (gx + 0.055 * m * k, my - 0.012 * m, mz - 0.005 * m), masca, scara=(0.8, 0.6, 0.7),
				segmente=6, inele=4))
			piese.append(cub("Orbita", (0.042 * m, 0.012, 0.036 * m), (gx + 0.033 * m * k, my - 0.034 * m, mz + 0.022 * m), NEGRU,
				rot=(0, 0.2 * k, 0)))
			ochi.append(cub("Ochi", (0.018 * m, 0.008, 0.014 * m), (gx + 0.033 * m * k, my - 0.047 * m, mz + 0.02 * m), ochi_culoare))
		piese.append(trunchi("Nas masca", [((gx, my - 0.03 * m, mz + 0.0), 0.0, 0.0), ((gx, my - 0.034 * m, mz - 0.02 * m), 0.013 * m, 0.006),
			((gx, my - 0.03 * m, mz - 0.03 * m), 0.0, 0.0)], NEGRU, laturi=4, ref=(1, 0, 0)))
		piese.append(cub("Gura masca", (0.06 * m, 0.012, 0.016 * m), (gx, my - 0.028 * m, mz - 0.06 * m), NEGRU))
		for k in range(5):
			# în fața gurii (cu 1,2 cm), altfel fețele lor se bat cu ale ei
			piese.append(cub("Dinte", (0.008 * m, 0.008, 0.02 * m), (gx + (k - 2) * 0.012 * m, my - 0.028 * m - 0.018, mz - 0.06 * m), masca))
	else:
		for k in (-1, 1):
			ochi.append(cub("Ochi", (0.028 * m, 0.008, 0.012 * m), (gx + 0.036 * m * k, gy - 0.162 * m, gz + 0.14 * m), ochi_culoare,
				rot=(0, 0.25 * k, 0)))


def _brat(piese, umar, cot, incheietura, culoare, umbra, piele, r, deschisa=True, lateral=None):
	"""Mâneca largă și mâna osoasă cu gheare (din coven.py)."""
	_maneca(piese, umar, cot, incheietura, culoare, umbra)
	d = _norm([b - a for a, b in zip(cot, incheietura)])
	if lateral is None:
		lateral = (1.0 if umar[0] < 0 else -1.0, 0.0, 0.0)
	_mana(piese, _lerp(cot, incheietura, 1.02), d, lateral, piele, NEGRU, r, deschisa=deschisa)


# ---------------------------------------------------------------------------------------------------------------
# Warlock-ul
# ---------------------------------------------------------------------------------------------------------------

def warlock(cale):
	"""Warlock-ul: 2,3 m, robă neagră lungă cu deschizătura roșie plină de rune care ard, mantie zdrențuită pe spate,
	guler înalt de țepi, epoleți de fier cu coarne de os, lanțuri pe piept și un amuletă roșie. Gluga trasă peste o mască
	de os, cu ochii roșii aprinși; coarne mari de berbec ies prin glugă. În mâna dreaptă un toiag strâmb cu o gheară
	care ține un cristal roșu.
	Piese: `Corp` (originea la sol), `Lumini` (runele și amuleta: strălucesc), `Cap` (originea în gât) cu `Ochi`,
	`BratDrept` (originea în umăr) cu `Toiag` (originea în mână) și `Cristal` (copil al toiagului), `BratStang` (originea
	în umăr: își ridică mâna și aruncă vraja)."""
	curata()
	r = random.Random(666)
	piese, lumini = [], []
	Z_UMAR = 1.84
	inele = [(0.02, 0.48, 0.43), (0.12, 0.47, 0.42), (0.55, 0.38, 0.32), (1.0, 0.29, 0.23), (1.18, 0.275, 0.215),
		(1.45, 0.31, 0.225), (1.68, 0.36, 0.235), (1.8, 0.35, 0.225), (1.87, 0.22, 0.16), (1.93, 0.09, 0.085)]
	_roba(piese, inele, NEGRU, NEGRU_VERDE, r, zdrente=24)
	_banda_fata(piese, lumini, inele, 0.05, 1.82, 0.16, ROSU_INCHIS, runa=ROSU_APRINS, pas=0.17)
	# brâul lat, cu catarama-craniu
	rx, ry = _raza_la(inele, 1.12)
	piese.append(trunchi("Brau", [((0, 0, 1.06), rx + 0.012, ry + 0.012), ((0, 0, 1.18), rx + 0.012, ry + 0.012)], LEMN, laturi=14))
	cy = -ry - 0.03
	piese += [
		sfera("Craniu brau", 0.055, (0, cy - 0.01, 1.12), OS, scara=(0.9, 0.7, 1.0), segmente=8, inele=5),
		cub("Orbita craniu", (0.018, 0.01, 0.018), (-0.018, cy - 0.05, 1.13), NEGRU),
		cub("Orbita craniu", (0.018, 0.01, 0.018), (0.018, cy - 0.05, 1.13), NEGRU),
		cub("Falca craniu", (0.04, 0.03, 0.02), (0, cy - 0.02, 1.07), OS),
	]
	# mantia de pe spate: din umeri până jos, pe la spate, cu falduri și marginea zdrențuită
	_mantie(piese, "Mantie", 1.83, 0.03, (0.4, 0.27), (0.55, 0.52), math.pi * 0.08, math.pi * 0.92, NEGRU_VERDE, r)
	# gulerul înalt de țepi, în evantai, în spatele capului
	for k in range(7):
		u = math.pi * (0.2 + 0.6 * k / 6)
		baza = (math.cos(u) * 0.2, math.sin(u) * 0.12 + 0.06, 1.86)
		varf = (math.cos(u) * 0.36, math.sin(u) * 0.2 + 0.14, 2.32 - abs(k - 3) * 0.06)
		piese.append(trunchi("Guler", [(baza, 0.045, 0.012), (_lerp(baza, varf, 0.6), 0.03, 0.01), (varf, 0.0, 0.0)], NEGRU,
			laturi=4, ref=(math.cos(u), math.sin(u), 0)))
	# epoleții de fier, cu câte trei coarne de os
	for s in (-1, 1):
		x = s * 0.33
		piese.append(sfera("Epolet", 0.16, (x, 0.0, Z_UMAR + 0.02), NEGRU_VERDE, scara=(1.05, 1.0, 0.62), segmente=10, inele=6))
		piese.append(trunchi("Margine epolet", [((x, 0.0, Z_UMAR - 0.06), 0.17, 0.16), ((x, 0.0, Z_UMAR - 0.03), 0.165, 0.155)],
			GRI_INCHIS, laturi=10))
		for k, (dx, dy, h) in enumerate(((0.06, -0.05, 0.2), (0.12, 0.03, 0.15), (0.0, 0.06, 0.13))):
			baza = (x + s * dx, dy, Z_UMAR + 0.08)
			varf = (x + s * (dx + 0.08), dy, Z_UMAR + 0.08 + h)
			piese.append(trunchi("Corn epolet", [(baza, 0.03, 0.03), (_lerp(baza, varf, 0.5), 0.022, 0.022), (varf, 0.0, 0.0)], OS_UMBRA,
				laturi=6))
	# lanțurile de pe piept (de pe umărul stâng spre șoldul drept) și amuleta
	a, b = (0.27, -0.2, 1.74), (-0.24, -0.27, 1.25)
	for k in range(14):
		t = (k + 0.5) / 14
		c = _lerp(a, b, t)
		rx, ry = _raza_la(inele, c[2])
		y = -ry * math.sqrt(max(1 - (c[0] / (rx * 1.02)) ** 2, 0.05)) - 0.025
		piese.append(cub("Za", (0.04, 0.012, 0.026), (c[0], y, c[2]), GRI, rot=(0, math.atan2(b[2] - a[2], b[0] - a[0]) + (0.9 if k % 2 else 0), 0)))
	ry = _raza_la(inele, 1.62)[1]
	piese.append(cilindru("Rama amuleta", 0.075, 0.075, 0.02, (0, -ry - 0.03, 1.62), AUR, laturi=8, rot=(math.pi / 2, 0, 0)))
	lumini.append(trunchi("Amuleta", [((0, -ry - 0.035, 1.68), 0.0, 0.0), ((0, -ry - 0.045, 1.62), 0.045, 0.035),
		((0, -ry - 0.035, 1.56), 0.0, 0.0)], ROSU_APRINS, laturi=4, ref=(1, 0, 0)))
	uneste(piese, "Corp")
	uneste(lumini, "Lumini")

	# brațul drept: antebrațul înainte, mâna strânsă pe toiag
	umar, cot, inch = (-0.33, 0.0, Z_UMAR - 0.05), (-0.42, -0.06, Z_UMAR - 0.4), (-0.38, -0.3, Z_UMAR - 0.58)
	brat = []
	_brat(brat, umar, cot, inch, NEGRU, NEGRU_VERDE, OS_UMBRA, r, deschisa=False, lateral=(0.0, 0.0, 1.0))
	ob_brat = uneste(brat, "BratDrept", umar)
	mana = _lerp(cot, inch, 1.12)
	# toiagul: lemn strâmb, de la pământ până peste cap, cu o gheară de os sus care ține cristalul
	toiag = []
	mx, my, mz = mana
	drum = [(mx, my, 0.04), (mx + 0.03, my - 0.02, 0.6), (mx - 0.02, my + 0.01, 1.2), (mx, my, mz), (mx + 0.04, my - 0.02, 2.0),
		(mx + 0.02, my, 2.35)]
	toiag.append(trunchi("Toiag", [(c, 0.026 - k * 0.001, 0.026 - k * 0.001) for k, c in enumerate(drum)], LEMN, laturi=6))
	for k in range(3):  # noduri
		c = drum[k + 1]
		toiag.append(sfera("Nod toiag", 0.035, c, LEMN, segmente=6, inele=4))
	sus = drum[-1]
	for k in range(4):  # gheara: patru degete de os care se strâng în jurul cristalului
		u = k * math.tau / 4 + 0.4
		baza = (sus[0] + math.cos(u) * 0.03, sus[1] + math.sin(u) * 0.03, sus[2])
		mij = (sus[0] + math.cos(u) * 0.11, sus[1] + math.sin(u) * 0.11, sus[2] + 0.12)
		varf = (sus[0] + math.cos(u) * 0.05, sus[1] + math.sin(u) * 0.05, sus[2] + 0.27)
		toiag.append(trunchi("Gheara", [(baza, 0.022, 0.022), (mij, 0.017, 0.017), (varf, 0.0, 0.0)], OS_UMBRA, laturi=5))
	ob_toiag = uneste(toiag, "Toiag", mana)
	_parinte(ob_toiag, ob_brat)
	centru_cristal = (sus[0], sus[1], sus[2] + 0.15)
	cristal = [trunchi("Cristal", [((centru_cristal[0], centru_cristal[1], centru_cristal[2] - 0.12), 0.0, 0.0),
		(centru_cristal, 0.07, 0.07), ((centru_cristal[0], centru_cristal[1], centru_cristal[2] + 0.14), 0.0, 0.0)], ROSU_APRINS,
		laturi=5, ref=(1, 0, 0))]
	_parinte(uneste(cristal, "Cristal", centru_cristal), ob_toiag)

	# brațul stâng: atârnă, cu ghearele răsfirate (îl ridică la vrăji)
	umar, cot, inch = (0.33, 0.0, Z_UMAR - 0.05), (0.39, 0.02, Z_UMAR - 0.4), (0.37, -0.06, Z_UMAR - 0.7)
	brat = []
	_brat(brat, umar, cot, inch, NEGRU, NEGRU_VERDE, OS_UMBRA, r)
	uneste(brat, "BratStang", umar)

	# capul: gluga cu masca de os, coarnele de berbec prin glugă
	cap, ochi = [], []
	gat = (0, -0.01, 1.93)
	_gluga(cap, ochi, gat, NEGRU, ROSU_INCHIS, masca=OS, marime=1.15)
	for s in (-1, 1):
		drum = [(s * 0.15, 0.04, 2.08), (s * 0.26, 0.08, 2.15), (s * 0.35, 0.14, 2.27), (s * 0.38, 0.13, 2.42), (s * 0.33, 0.04, 2.5),
			(s * 0.27, -0.04, 2.46), (s * 0.25, -0.08, 2.38)]
		raze = [0.06, 0.055, 0.048, 0.04, 0.03, 0.018, 0.0]
		cap.append(trunchi("Corn", [(c, rr, rr) for c, rr in zip(drum, raze)], GRI_INCHIS, laturi=7))
		for k in range(1, 5):  # inelele cornului
			c = drum[k]
			cap.append(trunchi("Inel corn", [(_lerp(drum[k - 1], c, 0.9), raze[k] + 0.008, raze[k] + 0.008),
				(_lerp(c, drum[k + 1], 0.1), raze[k] + 0.008, raze[k] + 0.008)], GRI, laturi=7))
	ob_cap = uneste(cap, "Cap", gat)
	_parinte(uneste(ochi, "Ochi", (0, -0.2, 2.07)), ob_cap)
	exporta(os.path.join(cale, "warlock.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Vrăjitorii din armată
# ---------------------------------------------------------------------------------------------------------------

ARMATA = [
	dict(roba=p("48313b"), umbra=p("262d2f"), banda=p("7b383a"), runa=p("904a40"), gluga=p("48313b"), rama=p("262d2f"),
		piele=p("7e8d87"), ochi=p("904a40"), masca=None, inaltime=1.0, coarne=False),
	dict(roba=p("2a3c3d"), umbra=p("262d2f"), banda=p("32453b"), runa=p("438b88"), gluga=p("2a3c3d"), rama=p("32453b"),
		piele=p("70706e"), ochi=p("438b88"), masca=p("83b3b0"), inaltime=1.04, coarne=False),
	dict(roba=p("553e4d"), umbra=p("48313b"), banda=p("5e363e"), runa=p("a56850"), gluga=p("553e4d"), rama=p("5e363e"),
		piele=p("7e8d87"), ochi=p("a56850"), masca=None, inaltime=0.97, coarne=True),
]


def vrajitor(cale, nume, s, saminta):
	"""Un vrăjitor din armata Warlock-ului: robă lungă cu glugă ascuțită trasă peste față (în gol ard doi ochi, sau o
	mască de os), o bandă cu rune care strălucesc, brâu de frânghie, mâini osoase. Unii au coarne mici prin glugă.
	Piese: `Corp`, `Lumini` (runele), `Cap` (originea în gât) cu `Ochi`, `BratDrept`/`BratStang` (originea în umăr,
	atârnă pe lângă corp: le ridică să arunce vrăji)."""
	curata()
	r = random.Random(saminta)
	h = s["inaltime"]
	piese, lumini = [], []
	z_umar = 1.47 * h
	inele = [(0.02, 0.37, 0.33), (0.1, 0.36, 0.32), (0.5, 0.3, 0.25), (0.95 * h, 0.22, 0.18), (1.12 * h, 0.21, 0.17),
		(1.36 * h, 0.25, 0.18), (1.47 * h, 0.255, 0.18), (1.53 * h, 0.15, 0.12), (1.58 * h, 0.07, 0.065)]
	_roba(piese, inele, s["roba"], s["umbra"], r)
	_banda_fata(piese, lumini, inele, 0.05, 1.5 * h, 0.11, s["banda"], runa=s["runa"], pas=0.22)
	rx, ry = _raza_la(inele, 1.0 * h)
	piese.append(trunchi("Brau", [((0, 0, 0.96 * h), rx + 0.012, ry + 0.012), ((0, 0, 1.03 * h), rx + 0.01, ry + 0.01)], LEMN, laturi=12))
	piese.append(os_intre("Capat brau", (0.08, -ry - 0.01, 0.99 * h), (0.11, -ry - 0.03, 0.7 * h), 0.014, LEMN, laturi=4))
	# pelerina scurtă peste umeri
	piese.append(trunchi("Pelerina", [((0, 0.0, 1.57 * h), 0.08, 0.075), ((0, 0.01, 1.5 * h), 0.27, 0.19), ((0, 0.02, 1.36 * h), 0.29, 0.21),
		((0, 0.03, 1.22 * h), 0.27, 0.2)], s["gluga"], laturi=12, capete=False))
	for k in range(10):
		u = math.pi * (0.05 + 0.9 * k / 9)
		piese.append(cub("Colt pelerina", (0.08, 0.016, 0.1), (math.cos(u) * 0.275, 0.03 + math.sin(u) * 0.205, 1.18 * h), s["gluga"],
			rot=(0, 0, u + math.pi / 2)))
	uneste(piese, "Corp")
	uneste(lumini, "Lumini")

	for semn, nume_brat in ((-1, "BratDrept"), (1, "BratStang")):
		umar = (semn * 0.25, 0.0, z_umar - 0.03)
		cot = (semn * 0.3, 0.02, z_umar - 0.31)
		inch = (semn * 0.28, -0.05, z_umar - 0.56)
		brat = []
		_brat(brat, umar, cot, inch, s["roba"], s["umbra"], s["piele"], r)
		uneste(brat, nume_brat, umar)

	cap, ochi = [], []
	gat = (0, -0.01, 1.57 * h)
	_gluga(cap, ochi, gat, s["gluga"], s["rama"], ochi_culoare=s["ochi"], masca=s["masca"])
	if s["coarne"]:
		for k in (-1, 1):
			cap.append(trunchi("Corn", [((k * 0.12, 0.02, gat[2] + 0.2), 0.03, 0.03), ((k * 0.19, 0.03, gat[2] + 0.3), 0.022, 0.022),
				((k * 0.2, 0.0, gat[2] + 0.4), 0.0, 0.0)], GRI_INCHIS, laturi=6))
	ob_cap = uneste(cap, "Cap", gat)
	_parinte(uneste(ochi, "Ochi", (0, -0.17, gat[2] + 0.13)), ob_cap)
	exporta(os.path.join(cale, nume + ".glb"))


def vrajitor_1(cale):
	vrajitor(cale, "vrajitor_1", ARMATA[0], 31)


def vrajitor_2(cale):
	vrajitor(cale, "vrajitor_2", ARMATA[1], 32)


def vrajitor_3(cale):
	vrajitor(cale, "vrajitor_3", ARMATA[2], 33)


def toate(cale):
	warlock(cale)
	vrajitor_1(cale)
	vrajitor_2(cale)
	vrajitor_3(cale)


if __name__ == "__main__":
	cale_modele = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")
	if "--" in sys.argv:
		for nume in sys.argv[sys.argv.index("--") + 1:]:
			globals()[nume](cale_modele)
	else:
		toate(cale_modele)
