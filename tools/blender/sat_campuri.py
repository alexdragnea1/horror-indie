# Lanurile și vacile din jurul primăriei (primarie.tscn, owner 17.11: „lanuri de porumb sau de floarea-soarelui să nu
# fie total gol, poate o vacă sau două în depărtare, în ceață”): o tulpină de porumb (`porumb`), o floarea-soarelui
# (`floarea_soarelui`) — puse în rânduri din cod (campuri_sat.gd, MultiMesh) — și vaca (`vaca`, cu `Cap` și `Coada`
# separate, ca să pască și să dea din coadă, vaca.gd). Culorile din paletă, de toamnă: porumbul pe jumătate uscat,
# floarea-soarelui cu capul greu, aplecat.
#   blender --background --factory-startup --python tools/blender/sat_campuri.py              (toate)
#   blender --background --factory-startup --python tools/blender/sat_campuri.py -- vaca      (doar unele)
# Axe Blender: Z în sus, fața spre -Y (în Godot +Z). Originea fiecărui model = la pământ, sub tulpină / între picioare.
import math
import os
import random
import sys

import bpy
from mathutils import Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, trunchi, uneste, exporta  # noqa: E402

NEGRU = p("262d2f")
ALB = p("83b3b0")
AUR = p("a18463")
BRONZ = p("a56850")
ROSCAT = p("904a40")
LEMN = p("5e363e")
LEMN_INCHIS = p("48313b")
VERDE = p("5b6d4e")
VERDE_INCHIS = p("445d46")
VERDE_NEGRU = p("32453b")
MASLINIU = p("7a7b59")
CROM = p("7e8d87")
ROZ = p("a56850")


def _bara(nume, a, b, lat, gros, culoare):
	"""O placă lungă de la `a` la `b` (frunză, petală), lată de `lat`, groasă de `gros` (cu două fețe: e o cutie)."""
	a, b = Vector(a), Vector(b)
	d = b - a
	rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_euler()
	return cub(nume, (lat, gros, d.length), tuple((a + b) / 2), culoare, rot=tuple(rot))


def _frunza(piese, baza, directie, lung, lat, culoare, cadere=0.5):
	"""Frunză arcuită din două plăci: urcă puțin din tulpină, apoi cade spre vârf."""
	dx, dy = directie
	m = (baza[0] + dx * lung * 0.5, baza[1] + dy * lung * 0.5, baza[2] + lung * 0.18)
	v = (baza[0] + dx * lung, baza[1] + dy * lung, baza[2] + lung * (0.18 - cadere * 0.5))
	piese.append(_bara("Frunza", baza, m, lat, 0.006, culoare))
	piese.append(_bara("Frunza", m, v, lat * 0.7, 0.006, culoare))


# ---------------------------------------------------------------------------------------------------------------

def porumb(cale):
	"""O tulpină de porumb de ~2,2 m, pe jumătate uscată (toamnă): tulpina, șase frunze arcuite în părți alternative,
	un știulete în pănuși la mijloc, spicul de sus."""
	curata()
	r = random.Random(5)
	piese = [cilindru("Tulpina", 0.022, 0.012, 2.05, (0, 0, 1.025), MASLINIU, laturi=5)]
	for k in range(6):
		z = 0.35 + k * 0.27
		u = k * 2.4 + r.uniform(-0.3, 0.3)
		cul = AUR if k < 2 else (MASLINIU if k % 2 else VERDE)
		_frunza(piese, (0, 0, z), (math.cos(u), math.sin(u)), r.uniform(0.55, 0.75), 0.07, cul, cadere=r.uniform(0.6, 1.0))
	# știuletele, culcat puțin spre afară, cu mătasea maronie în vârf
	piese.append(os_intre("Stiulete", (0.02, 0, 1.0), (0.12, -0.03, 1.25), 0.035, VERDE, laturi=6))
	piese.append(os_intre("Matase", (0.12, -0.03, 1.25), (0.15, -0.04, 1.31), 0.012, ROSCAT, laturi=4))
	# spicul: câteva fire subțiri, aurii
	for k in range(5):
		u = k * 1.25
		piese.append(os_intre("Spic", (0, 0, 2.03), (math.cos(u) * 0.12, math.sin(u) * 0.12, 2.25), 0.006, AUR, laturi=3))
	piese.append(os_intre("Spic", (0, 0, 2.03), (0, 0, 2.3), 0.007, AUR, laturi=3))
	uneste(piese, "Porumb")
	exporta(os.path.join(cale, "porumb.glb"))


def floarea_soarelui(cale):
	"""Floarea-soarelui de ~1,9 m, cu capul greu aplecat în față (spre -Y): tulpina, frunze late, discul cu petale
	aurii, mijlocul maro închis ieșit în față, spatele verde."""
	curata()
	r = random.Random(7)
	piese = [cilindru("Tulpina", 0.024, 0.016, 1.75, (0, 0, 0.875), VERDE_INCHIS, laturi=5)]
	for k in range(4):
		z = 0.45 + k * 0.3
		u = k * 2.1 + r.uniform(-0.3, 0.3)
		_frunza(piese, (0, 0, z), (math.cos(u), math.sin(u)), 0.32, 0.17, VERDE if k % 2 else VERDE_INCHIS, cadere=0.7)
	# gâtul care se apleacă și capul (axa capului = spre -Y și în jos)
	gat_sus = (0, -0.1, 1.86)
	piese.append(os_intre("Gat floare", (0, 0, 1.74), gat_sus, 0.018, VERDE_INCHIS, laturi=5))
	unghi = 0.5  # cât de aplecat (radiani, spre pământ)
	fata = Vector((0, -math.cos(unghi), -math.sin(unghi)))
	centru = Vector(gat_sus) + fata * 0.04
	rot = Vector((0, 0, 1)).rotation_difference(fata).to_euler()

	def disc(nume, raza, gros, dist, cul):
		c = centru + fata * dist
		return cilindru(nume, raza, raza, gros, tuple(c), cul, laturi=12, rot=tuple(rot))
	piese += [
		disc("Spate floare", 0.15, 0.03, -0.02, VERDE),
		disc("Petale", 0.19, 0.02, 0.005, AUR),
		disc("Seminte", 0.115, 0.03, 0.03, LEMN_INCHIS),
	]
	uneste(piese, "Floare")
	exporta(os.path.join(cale, "floarea_soarelui.glb"))


# ---------------------------------------------------------------------------------------------------------------

def vaca(cale):
	"""O vacă bălțată românească (roșcată cu alb), cu fața spre -Y: `Corp` (trunchiul, picioarele, ugerul), `Cap` (gâtul
	și capul, originea în ceafă: se apleacă să pască), `Coada` (originea la rădăcina ei: dă din coadă)."""
	curata()
	corp = [
		# trunchiul: un butoi din inele, de la crupă (+Y) la greabăn (-Y)
		trunchi("Trunchi", [((0, 0.85, 1.12), 0.0, 0.0), ((0, 0.82, 1.12), 0.2, 0.22), ((0, 0.6, 1.1), 0.3, 0.33),
			((0, 0.1, 1.08), 0.33, 0.37), ((0, -0.45, 1.1), 0.3, 0.34), ((0, -0.72, 1.18), 0.22, 0.27),
			((0, -0.75, 1.18), 0.0, 0.0)], ROSCAT, laturi=10, ref=(1, 0, 0)),
		# burta albă (dedesubt, ieșită puțin) și pata albă de pe spate
		trunchi("Burta", [((0, 0.45, 0.8), 0.0, 0.0), ((0, 0.42, 0.8), 0.18, 0.06), ((0, -0.3, 0.8), 0.2, 0.07),
			((0, -0.33, 0.8), 0.0, 0.0)], ALB, laturi=8, ref=(1, 0, 0)),
		sfera("Pata", 0.16, (0.0, 0.2, 1.43), ALB, scara=(1.3, 1.6, 0.35), segmente=8, inele=4),
		sfera("Uger", 0.13, (0, 0.5, 0.82), ROZ, scara=(1.0, 1.1, 0.7), segmente=8, inele=4),
	]
	for k in range(4):
		corp.append(cilindru("Ten", 0.018, 0.012, 0.07, (-0.06 + (k % 2) * 0.12, 0.45 + (k // 2) * 0.1, 0.71), ROZ, laturi=4))
	for sx in (-0.19, 0.19):
		for sy in (-0.5, 0.58):
			corp += [
				cilindru("Picior", 0.075, 0.06, 0.62, (sx, sy, 0.36 + 0.62 / 2 - 0.05), ROSCAT, laturi=6),
				cilindru("Picior alb", 0.058, 0.055, 0.22, (sx, sy, 0.05 + 0.11 + 0.01), ALB, laturi=6),
				cilindru("Copita", 0.058, 0.06, 0.06, (sx, sy, 0.03), NEGRU, laturi=6),
			]
	uneste(corp, "Corp")
	# capul: gâtul gros din ceafă în jos-înainte, capul alungit, botul alb-roz, nările, ochii, urechile, coarnele scurte
	ceafa = (0, -0.7, 1.28)
	cap = [
		trunchi("Gat", [(ceafa, 0.2, 0.24), ((0, -0.92, 1.2), 0.17, 0.2), ((0, -1.05, 1.12), 0.13, 0.15)], ROSCAT, laturi=8,
			ref=(1, 0, 0)),
		trunchi("Cap vaca", [((0, -1.0, 1.2), 0.0, 0.0), ((0, -1.02, 1.2), 0.13, 0.12), ((0, -1.15, 1.12), 0.12, 0.12),
			((0, -1.32, 1.0), 0.09, 0.1), ((0, -1.36, 0.97), 0.0, 0.0)], ALB, laturi=8, ref=(1, 0, 0)),
		sfera("Bot", 0.085, (0, -1.35, 0.95), ROZ, scara=(1.15, 0.7, 0.8), segmente=8, inele=4),
		sfera("Ceafa rosie", 0.12, (0, -1.06, 1.22), ROSCAT, scara=(1.1, 0.8, 0.6), segmente=8, inele=4),
	]
	for sx in (-1, 1):
		cap += [
			sfera("Ochi", 0.02, (sx * 0.11, -1.14, 1.15), NEGRU, segmente=6, inele=3),
			sfera("Nara", 0.014, (sx * 0.04, -1.42, 0.95), NEGRU, segmente=4, inele=3),
			_bara("Ureche", (sx * 0.1, -1.06, 1.2), (sx * 0.26, -1.08, 1.17), 0.08, 0.02, ROSCAT),
			os_intre("Corn", (sx * 0.08, -1.04, 1.27), (sx * 0.17, -1.07, 1.36), 0.018, AUR, laturi=4),
		]
	ob_cap = uneste(cap, "Cap", ceafa)
	coada = [
		os_intre("Coada", (0, 0.84, 1.3), (0, 0.9, 0.85), 0.018, ROSCAT, laturi=4),
		os_intre("Smoc", (0, 0.9, 0.85), (0, 0.92, 0.66), 0.035, ALB, laturi=5),
	]
	uneste(coada, "Coada", (0, 0.84, 1.3))
	exporta(os.path.join(cale, "vaca.glb"))


def toate(cale):
	porumb(cale)
	floarea_soarelui(cale)
	vaca(cale)


if __name__ == "__main__":
	cale_modele = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")
	if "--" in sys.argv:
		for nume in sys.argv[sys.argv.index("--") + 1:]:
			globals()[nume](cale_modele)
	else:
		toate(cale_modele)
