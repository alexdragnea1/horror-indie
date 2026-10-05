# Demonul chemat pe pentagrama din camera ta, când arunci pisica moartă în ceaunul de acasă (ceaun_acasa.gd).
# Rulare (din folderul proiectului):
#   blender --background --factory-startup --python tools/blender/demon.py
# Axe Blender: Z în sus, fața modelului spre -Y (în Godot devine +Z). Originea = podeaua, între copite.
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, uneste, exporta, trunchi, _coloreaza  # noqa: E402
from coven import _parinte  # noqa: E402
from conac_interior import _muta  # noqa: E402

PIELE = p("7b383a")          # roșu închis
PIELE_UMBRA = p("5e363e")    # spatele, coapsele
BURTA = p("904a40")          # pieptul și burta, mai deschise
BLANA = p("48313b")          # blana de țap de pe picioare
MEMBRANA = p("553e4d")       # pielea aripilor
CORN = p("5e5356")
NEGRU = p("262d2f")          # copite, gheare, vârful cozii, gura
DINTI = p("a56850")          # dinți îngălbeniți, putrezi
JAR = p("a18463")            # ochii și pecetea de pe piept (strălucesc în joc)


def _membrana(nume, puncte, culoare, grosime=0.012):
	"""Poligon plat (convex, în ordine) în spațiu, cu grosime: pielea aripilor. Grosimea face și fața din spate,
	altfel shader-ul (cull_back) n-o desenează când aripa e văzută din cealaltă parte."""
	bm = bmesh.new()
	bm.faces.new([bm.verts.new(pt) for pt in puncte])
	me = bpy.data.meshes.new(nume)
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new(nume, me)
	bpy.context.scene.collection.objects.link(ob)
	bpy.context.view_layer.objects.active = ob
	mod = ob.modifiers.new("grosime", 'SOLIDIFY')
	mod.thickness = grosime
	mod.offset = 0.0
	bpy.ops.object.select_all(action='DESELECT')
	ob.select_set(True)
	bpy.ops.object.modifier_apply(modifier=mod.name)
	_coloreaza(ob, culoare)
	return ob


def _con(nume, baza, varf, raza, culoare, laturi=5):
	"""Con de la `baza` la `varf` (gheare, dinți, colți, smocuri de blană)."""
	return trunchi(nume, [(baza, raza, raza), (varf, 0.0, 0.0)], culoare, laturi=laturi)


def _mana(piese, incheietura, s):
	"""Mână cu patru degete lungi și un deget mare, cu gheare negre, atârnată în jos și puțin în față."""
	x, y, z = incheietura
	piese.append(sfera("Palma", 0.065, (x, y - 0.03, z - 0.06), PIELE, scara=(0.75, 0.6, 1.0), segmente=8, inele=5))
	for k in range(4):
		dx = s * (-0.03 + k * 0.022)
		baza = (x + dx, y - 0.06, z - 0.1)
		mijloc = (x + dx * 1.4, y - 0.12, z - 0.2)
		capat = (x + dx * 1.6, y - 0.13, z - 0.29 + abs(k - 1.5) * 0.02)
		piese.append(os_intre("Deget", baza, mijloc, 0.016, PIELE, laturi=5))
		piese.append(os_intre("Deget", mijloc, capat, 0.013, PIELE, laturi=5))
		varf = (capat[0], capat[1] + 0.03, capat[2] - 0.07)
		piese.append(_con("Gheara", capat, varf, 0.012, NEGRU, laturi=4))
	# degetul mare, spre interior
	baza = (x - s * 0.035, y - 0.07, z - 0.06)
	capat = (x - s * 0.07, y - 0.15, z - 0.14)
	piese.append(os_intre("Deget mare", baza, capat, 0.017, PIELE, laturi=5))
	piese.append(_con("Gheara", capat, (capat[0] - s * 0.01, capat[1] - 0.04, capat[2] - 0.05), 0.012, NEGRU, laturi=4))


def _picior(piese, s):
	"""Picior de țap (digitigrad): coapsa în față, gamba spre spate, glezna lungă, copita despicată. Blană zbârlită
	pe coapsă și smocuri deasupra copitei."""
	sold, genunchi, calcai, glezna = (s * 0.15, 0.03, 1.02), (s * 0.21, -0.2, 0.64), (s * 0.21, 0.13, 0.3), (s * 0.21, 0.02, 0.1)
	piese.append(trunchi("Coapsa", [(sold, 0.13, 0.14), (((sold[0] + genunchi[0]) / 2, -0.1, 0.84), 0.12, 0.12),
		(genunchi, 0.085, 0.085)], BLANA, laturi=8))
	# blana de pe coapsă: mai lată, cu marginea de jos zimțată (inelul de jos rotit, `faza`)
	piese.append(trunchi("Blana", [((s * 0.15, 0.03, 1.06), 0.165, 0.175), ((s * 0.17, -0.06, 0.9), 0.155, 0.155),
		((s * 0.2, -0.16, 0.72), 0.12, 0.11), ((s * 0.21, -0.19, 0.66), 0.0, 0.0)], BLANA, laturi=7, faza=0.3))
	for k in range(7):  # smocurile din marginea blănii, spre spate și în jos
		u = k * math.tau / 7
		baza = (s * 0.2 + math.cos(u) * 0.11, -0.15 + math.sin(u) * 0.1, 0.74)
		piese.append(_con("Smoc", baza, (baza[0] * 1.05, baza[1] + 0.05, 0.62), 0.04, BLANA, laturi=4))
	piese.append(trunchi("Gamba", [(genunchi, 0.08, 0.08), (((genunchi[0] + calcai[0]) / 2, -0.03, 0.47), 0.065, 0.07),
		(calcai, 0.05, 0.05)], BLANA, laturi=7))
	piese.append(trunchi("Glezna", [(calcai, 0.05, 0.05), (glezna, 0.04, 0.04)], BLANA, laturi=7))
	piese.append(sfera("Smocuri glezna", 0.07, (s * 0.21, 0.03, 0.13), BLANA, scara=(1.0, 1.0, 0.7), segmente=7, inele=4))
	for d in (-1, 1):  # copita despicată în două
		piese.append(cilindru("Copita", 0.045, 0.034, 0.08, (s * 0.21 + d * 0.028, -0.01, 0.04), NEGRU, laturi=6,
			scara=(0.85, 1.25, 1.0)))


def _brat(s):
	"""Brațul (originea în umăr) cu antebrațul separat (originea în cot), ca să le miște demon.gd."""
	umar, cot, inch = (s * 0.52, -0.05, 1.76), (s * 0.64, -0.03, 1.37), (s * 0.62, -0.25, 1.1)
	brat = [
		sfera("Umar", 0.17, umar, PIELE, scara=(1.0, 1.0, 0.9), segmente=8, inele=6),
		trunchi("Brat", [(umar, 0.125, 0.125), (((umar[0] + cot[0]) / 2, -0.04, 1.57), 0.12, 0.105), (cot, 0.085, 0.085)],
			PIELE, laturi=8),
	]
	ob_brat = uneste(brat, "Brat" + ("S" if s > 0 else "D"), umar)
	antebrat = [
		sfera("Cot", 0.085, cot, PIELE, segmente=8, inele=5),
		trunchi("Antebrat", [(cot, 0.088, 0.088), (((cot[0] + inch[0]) / 2, -0.13, 1.24), 0.1, 0.085), (inch, 0.058, 0.058)],
			PIELE, laturi=8),
	]
	# țepi de os pe muchia antebrațului
	for k in range(3):
		t = 0.25 + k * 0.22
		pt = (cot[0] + (inch[0] - cot[0]) * t + s * 0.06, cot[1] + (inch[1] - cot[1]) * t + 0.04, cot[2] + (inch[2] - cot[2]) * t)
		antebrat.append(_con("Tep", pt, (pt[0] + s * 0.07, pt[1] + 0.05, pt[2] + 0.02), 0.018, CORN, laturi=4))
	_mana(antebrat, inch, s)
	_parinte(uneste(antebrat, "Antebrat" + ("S" if s > 0 else "D"), cot), ob_brat)


def _aripa(s):
	"""Aripă de liliac (originea în rădăcina de pe spate): oasele (brațul aripii și trei degete) și pielea dintre ele,
	cu marginea din spate scobită între vârfuri."""
	R, E, W = Vector((s * 0.17, 0.2, 1.74)), Vector((s * 0.58, 0.44, 2.12)), Vector((s * 0.96, 0.5, 2.34))
	varfuri = [Vector((s * 1.36, 0.56, 2.08)), Vector((s * 1.33, 0.6, 1.66)), Vector((s * 1.05, 0.56, 1.3))]
	B = Vector((s * 0.16, 0.17, 1.24))
	piese = [
		os_intre("Os aripa", R, E, 0.035, BLANA, laturi=5),
		os_intre("Os aripa", E, W, 0.028, BLANA, laturi=5),
		sfera("Incheietura aripa", 0.04, W, BLANA, segmente=6, inele=4),
		_con("Gheara aripa", W, W + Vector((s * 0.02, -0.03, 0.12)), 0.022, NEGRU, laturi=4),
	]
	for v in varfuri:
		piese.append(os_intre("Deget aripa", W, v, 0.016, BLANA, laturi=4))
	# pielea: între vârfuri marginea intră spre încheietură (scobitura)
	contur = [W, varfuri[0]]
	for a, b in zip(varfuri, varfuri[1:]):
		mijloc = (a + b) / 2
		contur += [mijloc + (W - mijloc) * 0.22, b]
	scobit_corp = (varfuri[2] + B) / 2
	contur += [scobit_corp + (E - scobit_corp) * 0.25, B, R, E]
	# fâșii convexe în evantai din încheietură și din cot (poligonul întreg e concav); puțin în spatele oaselor
	inapoi = Vector((0, 0.012, 0))
	for i in range(1, 6):
		piese.append(_membrana("Membrana", [W + inapoi, contur[i] + inapoi, contur[i + 1] + inapoi], MEMBRANA))
	for i in range(6, 8):
		piese.append(_membrana("Membrana", [E + inapoi, contur[i] + inapoi, contur[i + 1] + inapoi], MEMBRANA))
	piese.append(_membrana("Membrana", [E + inapoi, W + inapoi, contur[6] + inapoi], MEMBRANA))
	uneste(piese, "Aripa" + ("S" if s > 0 else "D"), tuple(R))


def _cap():
	"""Capul (originea în gât): craniu lunguieț, arcade groase, bot de țap, urechi ascuțite, coarne de berbec
	răsucite pe lângă urechi și trei țepi în frunte. `Falca` (originea în balama) se mișcă când vorbește, `Ochi`
	strălucesc. Gura e neagră pe dinăuntru, cu dinți și colți."""
	cap, ochi, falca = [], [], []
	cap += [
		sfera("Craniu", 0.15, (0, -0.24, 2.12), PIELE, scara=(0.92, 1.12, 0.95), segmente=10, inele=7),
		trunchi("Bot", [((0, -0.3, 2.07), 0.1, 0.085), ((0, -0.42, 2.04), 0.075, 0.065), ((0, -0.48, 2.03), 0.05, 0.045)],
			PIELE, laturi=8),
		cub("Arcada", (0.25, 0.07, 0.05), (0, -0.37, 2.175), PIELE_UMBRA, rot=(-0.35, 0, 0)),
		sfera("Gura", 0.075, (0, -0.37, 1.995), NEGRU, scara=(0.9, 1.4, 0.45), segmente=8, inele=4),
	]
	for s in (-1, 1):
		cap += [
			sfera("Pomete", 0.05, (s * 0.085, -0.34, 2.07), PIELE, segmente=7, inele=5),
			cub("Nara", (0.016, 0.012, 0.012), (s * 0.018, -0.522, 2.045), NEGRU),
			# urechile: lungi, ascuțite, spre spate și în afară
			trunchi("Ureche", [((s * 0.12, -0.21, 2.15), 0.03, 0.045), ((s * 0.22, -0.13, 2.2), 0.02, 0.03),
				((s * 0.31, -0.06, 2.27), 0.0, 0.0)], PIELE, laturi=4, ref=(0, 0, 1)),
			_con("Colt", (s * 0.045, -0.465, 2.0), (s * 0.05, -0.47, 1.925), 0.014, DINTI, laturi=4),
		]
		for k in range(3):  # dinții de sus, mici
			y = -0.44 + k * 0.045
			cap.append(_con("Dinte", (s * (0.028 + k * 0.012), y, 2.0), (s * (0.028 + k * 0.012), y, 1.965), 0.008, DINTI, laturi=3))
		# cornul de berbec: urcă din frunte, se duce pe spate și se răsucește în jos, pe lângă ureche, cu vârful în față
		drum = [((0.08, -0.31, 2.22), 0.052), ((0.11, -0.27, 2.33), 0.05), ((0.17, -0.17, 2.4), 0.046),
			((0.26, -0.07, 2.39), 0.042), ((0.33, -0.02, 2.3), 0.038), ((0.36, -0.06, 2.18), 0.032)]
		varf = [((0.36, -0.06, 2.18), 0.032), ((0.34, -0.16, 2.1), 0.026), ((0.31, -0.26, 2.1), 0.019),
			((0.3, -0.32, 2.16), 0.011), ((0.31, -0.33, 2.21), 0.0)]
		cap.append(trunchi("Corn", [((s * c[0], c[1], c[2]), r, r) for c, r in drum], CORN, laturi=7, ref=(0, 0, 1)))
		cap.append(trunchi("Varf corn", [((s * c[0], c[1], c[2]), r, r) for c, r in varf], NEGRU, laturi=7, ref=(0, 0, 1)))
		# ochii: înguști și pieziși, sub arcadă
		ochi.append(sfera("Ochi", 0.026, (s * 0.062, -0.385, 2.125), JAR, scara=(1.25, 0.5, 0.6), segmente=8, inele=5))
	for k in range(3):  # țepii din frunte
		x = (k - 1) * 0.045
		cap.append(_con("Tep frunte", (x, -0.33, 2.21 - abs(x) * 0.5), (x * 1.3, -0.3, 2.29 - abs(x) * 0.5), 0.016, CORN, laturi=4))
	ob_cap = uneste(cap, "Cap", (0, -0.17, 1.98))
	_parinte(uneste(ochi, "Ochi", (0, -0.385, 2.125)), ob_cap)
	falca += [
		trunchi("Falca", [((0, -0.25, 1.975), 0.085, 0.04), ((0, -0.4, 1.955), 0.065, 0.032), ((0, -0.47, 1.955), 0.04, 0.025)],
			PIELE_UMBRA, laturi=7),
	]
	for s in (-1, 1):
		for k in range(3):
			y = -0.43 + k * 0.045
			falca.append(_con("Dinte", (s * (0.025 + k * 0.012), y, 1.975), (s * (0.025 + k * 0.012), y, 2.0), 0.007, DINTI, laturi=3))
	for k in range(4):  # barbișonul de țap
		x = (k - 1.5) * 0.015
		falca.append(_con("Barbison", (x, -0.45, 1.94), (x * 1.6, -0.43, 1.84 - abs(k - 1.5) * 0.02), 0.014, BLANA, laturi=4))
	_parinte(uneste(falca, "Falca", (0, -0.24, 1.99)), ob_cap)


def _pecete():
	"""Pecetea de pe piept: o pentagramă întoarsă, arsă în piele, care mocnește (strălucește în joc)."""
	raza = 0.1
	varfuri = [(raza * math.cos(math.radians(-90 + 72 * i)), raza * math.sin(math.radians(-90 + 72 * i))) for i in range(5)]
	piese = []
	for i in range(5):
		a, b = varfuri[i], varfuri[(i + 2) % 5]
		dx, dy = b[0] - a[0], b[1] - a[1]
		piese.append(cub("Pecete", (math.hypot(dx, dy), 0.014, 0.01), ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, 0), JAR,
			rot=(0, 0, math.atan2(dy, dx))))
	# din planul XY în planul XZ (pe piept), aplecată ca pieptul
	_muta(piese, (math.pi / 2 + 0.25, 0, 0), (0, -0.305, 1.5))
	return uneste(piese, "Pecete", (0, -0.3, 1.5))


def demon(cale):
	"""Demonul: înalt de ~2,45 m (încape în cameră cu coarne cu tot), gârbovit, umeri lați, brațe lungi cu gheare,
	picioare de țap cu copite, aripi de liliac pe jumătate deschise, coadă cu vârf de suliță, coarne de berbec, ochi de
	jar și o pentagramă întoarsă arsă în piept. Piese separate (demon.gd): `Corp` cu `Pecete`, `Cap` (`Falca`, `Ochi`),
	`BratS/D` (`AntebratS/D`), `AripaS/D`, `Coada`. S = stânga demonului (+X în Blender)."""
	curata()
	piese = [
		# trunchiul, aplecat în față, cu pieptul lat și talia îngustă
		trunchi("Corp", [((0, 0.05, 0.97), 0.0, 0.0), ((0, 0.05, 0.98), 0.19, 0.15), ((0, 0.04, 1.08), 0.24, 0.18),
			((0, 0.0, 1.25), 0.2, 0.16), ((0, -0.05, 1.45), 0.33, 0.22), ((0, -0.08, 1.62), 0.44, 0.25),
			((0, -0.07, 1.77), 0.48, 0.22), ((0, -0.09, 1.87), 0.25, 0.17), ((0, -0.15, 1.97), 0.1, 0.1)], PIELE, laturi=10),
		sfera("Cocoasa", 0.22, (0, 0.1, 1.72), PIELE_UMBRA, scara=(1.25, 0.7, 0.8), segmente=10, inele=6),
		sfera("Burta", 0.14, (0, -0.15, 1.33), PIELE_UMBRA, scara=(1.15, 0.75, 1.35), segmente=8, inele=6),
		cub("Brau", (0.42, 0.3, 0.07), (0, 0.04, 1.03), BLANA),
	]
	for s in (-1, 1):
		piese += [
			sfera("Piept", 0.17, (s * 0.16, -0.2, 1.64), PIELE, scara=(1.25, 0.55, 0.72), segmente=8, inele=6),
			sfera("Trapez", 0.14, (s * 0.22, -0.04, 1.86), PIELE_UMBRA, scara=(1.3, 0.9, 0.6), segmente=8, inele=5),
		]
		for k in range(3):  # pătrățelele de pe burtă
			piese.append(sfera("Abdomen", 0.052, (s * 0.055, -0.235, 1.22 + k * 0.1), BURTA, scara=(1.0, 0.45, 0.8),
				segmente=6, inele=4))
		for k in range(3):  # țepii de pe șira spinării
			z = 1.5 + k * 0.13
			piese.append(_con("Tep spate", (s * 0.06, 0.2 + k * 0.01, z), (s * 0.09, 0.3 + k * 0.01, z + 0.05), 0.025, CORN, laturi=4))
		_picior(piese, s)
	ob_corp = uneste(piese, "Corp")
	_parinte(_pecete(), ob_corp)
	_cap()
	for s in (-1, 1):
		_brat(s)
		_aripa(s)
	# coada: din spate, în jos pe podea și cu vârful ridicat, într-o parte
	coada = [trunchi("Coada", [((0, 0.17, 1.0), 0.06, 0.06), ((0, 0.42, 0.78), 0.05, 0.05), ((0.08, 0.66, 0.4), 0.04, 0.04),
		((0.22, 0.82, 0.12), 0.032, 0.032), ((0.46, 0.84, 0.07), 0.025, 0.025), ((0.66, 0.7, 0.16), 0.018, 0.018),
		((0.74, 0.58, 0.26), 0.012, 0.012)], PIELE_UMBRA, laturi=6, ref=(0, 0, 1))]
	# vârful de suliță, turtit
	varf = trunchi("Varf coada", [((0.74, 0.58, 0.26), 0.012, 0.012), ((0.77, 0.53, 0.3), 0.06, 0.012),
		((0.82, 0.45, 0.37), 0.0, 0.0)], NEGRU, laturi=4, ref=(0.6, 0.8, 0))
	coada.append(varf)
	uneste(coada, "Coada", (0, 0.17, 1.0))
	exporta(os.path.join(cale, "demon.glb"))


if __name__ == "__main__":
	cale_modele = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")
	demon(cale_modele)
