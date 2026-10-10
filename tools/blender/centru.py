# City Center (owner, 10.10): o piață rotundă între clădiri, la apus / „blue hour”, unde Head Witch omoară oameni și
# unde o înfrunți (lupta finală, scripts/lupta_head_witch.gd). Aici sunt:
#   centru_oras            piața (pavaj cu cercuri, fântâna cu statuia, felinare, bănci, jardiniere), cele 8 clădiri din
#                          jurul ei, pasajul spre bulevard, bulevardul cu stația și clădirile de vizavi
#   statie_centru          stația de autobuz „CITY CENTER” (autobuz.statie)
#   civil_1..6             oamenii din piață, în picioare, speriați (casino_oameni.om)
#   vrajitoare_sefa_lupta  Head Witch în faza întâi (coven.vrajitoare_sefa cu ambele brațe libere)
#   vrajitoare_sefa_demon  Head Witch în faza a doua: mare, plutește, fără picioare, aripi de os, coarne, gheare
#   palarie_sefa           pălăria ei, singură (cade din explozie la final; o pui pe cap)
#   blender --background --factory-startup --python tools/blender/centru.py                  (toate)
#   blender --background --factory-startup --python tools/blender/centru.py -- centru_oras   (doar unele)
# Axe Blender: Z în sus. Godot = (x, z, -y) din Blender. Bulevardul e pe X, la y < 0 (în Godot z > 0, ca la bar și la
# Gun Store: stația la z 2,4, autobuzul pe banda de la z 5,95); piața are centrul la y = 22 (Godot z = -22).
import math
import os
import random
import sys

import bmesh
import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, uneste, exporta, trunchi, _coloreaza  # noqa: E402
from casino import _text, _cutie_coliziune  # noqa: E402
from amanet import _obiect  # noqa: E402
from coven import _lerp, _parinte, _palarie, SEFA  # noqa: E402
import casino_oameni  # noqa: E402
import coven  # noqa: E402
import motel  # noqa: E402

NEGRU = p("262d2f")
ALB = p("83b3b0")
AUR = p("a18463")
BETON = p("70706e")
TENCUIALA = p("7e8d87")
METAL = p("6f6d7f")
METAL_INCHIS = p("5e5356")
GEAM = p("2a3c3d")
ROSU = p("7b383a")
ROSU_DESCHIS = p("904a40")
CARAMIDA = p("5e363e")
MORTAR = p("48313b")
MOV = p("655269")
MOV_INCHIS = p("553e4d")
TEAL = p("438b88")
TEAL_DESCHIS = p("61a19f")
PETROL = p("295555")
PETROL_DESCHIS = p("30716f")
VERDE = p("5b6d4e")
VERDE_INCHIS = p("445d46")
VERDE_NEGRU = p("32453b")
GRI_ALBASTRU = p("778c96")
MASLINIU = p("7a7b59")
BRONZ = p("a56850")
LEMN = p("5e363e")

FL = 0.15        # trotuarul și piața
CX, CY = 0.0, 22.0   # centrul pieței
R_PIATA = 16.5   # până la fațadele din jur
LAT_PASAJ = 6.0  # jumătate din lățimea pasajului dinspre bulevard


def _strange(piese, nume):
	if len(piese) > 1:
		piese[:] = [uneste(piese, nume)]


def _placa(nume, puncte, z0, z1, culoare):
	"""Un poligon (x, y) în ordine, oricât de strâmb (și concav), extrudat pe Z de la z0 la z1: podeaua pieței cu pasaj."""
	bm = bmesh.new()
	jos = [bm.verts.new((x, y, z0)) for x, y in puncte]
	sus = [bm.verts.new((x, y, z1)) for x, y in puncte]
	bm.faces.new(list(reversed(jos)))
	bm.faces.new(sus)
	n = len(puncte)
	for i in range(n):
		bm.faces.new((jos[i], jos[(i + 1) % n], sus[(i + 1) % n], sus[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	me = bpy.data.meshes.new(nume)
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new(nume, me)
	bpy.context.scene.collection.objects.link(ob)
	_coloreaza(ob, culoare)
	return ob


def _inel_plat(nume, centru, r0, r1, z, gros, culoare, n=56):
	"""Un inel plat (bandă de pavaj în cerc), de la raza r0 la r1, cu fața de sus la z."""
	bm = bmesh.new()
	cx, cy = centru
	rand = []
	for rr, zz in ((r0, z - gros), (r1, z - gros), (r1, z), (r0, z)):
		rand.append([bm.verts.new((cx + math.cos(k * math.tau / n) * rr, cy + math.sin(k * math.tau / n) * rr, zz)) for k in range(n)])
	for a, b in zip(rand, rand[1:] + rand[:1]):
		for k in range(n):
			bm.faces.new((a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	me = bpy.data.meshes.new(nume)
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new(nume, me)
	bpy.context.scene.collection.objects.link(ob)
	_coloreaza(ob, culoare)
	return ob


# ---------------------------------------------------------------------------------------------------------------
# Clădirile
# ---------------------------------------------------------------------------------------------------------------

# Firmele de la parter (neon), câte una pe clădire, în ordine.
FIRME = ["PHARMACY", "CAFE", "BANK", "CINEMA", "DINER", "HOTEL", "BOOKS", "PAWN", "LIQUOR", "BAKERY", "LAUNDRY", "SHOES",
	"BARBER", "PIZZA"]


def _cladire(piese, lumini, col, loc, unghi, w, d, h, stil, r, firma=None):
	"""O clădire de oraș: fațada (lată `w`) spre -Y-ul ei, adâncă `d`, înaltă `h`, mutată la `loc` și rotită cu `unghi`.
	Parterul cu vitrine (unele aprinse) și firma de neon (`firma`), etajele cu ferestre (din când în când aprinse),
	cornișa sus, soclul jos. `stil` = (perete, perete parter, ramă)."""
	perete, parter, rama = stil
	s, l = [], []
	s.append(cub("Cladire", (w, d, h), (0, d / 2, h / 2), perete))
	# parterul: o bandă mai închisă (iese 3 cm), soclul, vitrinele, ușa
	s.append(cub("Parter", (w + 0.06, 0.06, 4.0), (0, -0.03, 2.0), parter))
	s.append(cub("Soclu", (w + 0.1, 0.1, 0.45), (0, -0.07, 0.225), METAL_INCHIS))
	nv = max(1, int((w - 2.0) / 3.2))
	pas = (w - 1.6) / nv
	for k in range(nv):
		x = -w / 2 + 0.8 + pas * (k + 0.5)
		if k == nv // 2:
			s.append(cub("Usa", (1.4, 0.04, 2.5), (x, -0.08, 1.25 + 0.0), NEGRU))
			s.append(cub("Rama usa", (1.6, 0.03, 2.62), (x, -0.075, 1.31), rama))
			continue
		aprins = r.random() < 0.55
		(l if aprins else s).append(cub("Vitrina", (pas - 0.6, 0.02, 2.1), (x, -0.1, 1.7), AUR if aprins else GEAM))
		s.append(cub("Rama vitrina", (pas - 0.4, 0.03, 2.3), (x, -0.075, 1.7), rama))
	# firma: o tablă neagră și literele de neon deasupra vitrinelor
	if firma:
		lat = min(w - 1.0, 0.55 * len(firma) + 1.0)
		s.append(cub("Firma", (lat, 0.12, 0.8), (0, -0.12, 3.4), NEGRU))
		l.append(_text("Litere firma", firma, (0, -0.2, 3.4), 0.5, r.choice((ROSU_DESCHIS, TEAL_DESCHIS, AUR, ALB))))
	# etajele: rânduri de ferestre cu pervaz
	nf = max(1, int((w - 1.0) / 2.6))
	pasf = (w - 1.0) / nf
	z = 5.0
	while z + 1.6 < h - 0.6:
		for k in range(nf):
			x = -w / 2 + 0.5 + pasf * (k + 0.5)
			aprins = r.random() < 0.28
			(l if aprins else s).append(cub("Geam", (1.15, 0.02, 1.5), (x, -0.012, z + 0.75), AUR if aprins else GEAM))
			s.append(cub("Pervaz", (1.35, 0.14, 0.08), (x, -0.07, z - 0.04), rama))
			if not aprins and r.random() < 0.3:
				s.append(cub("Perdea", (0.5, 0.012, 1.4), (x - 0.3, -0.03, z + 0.75), r.choice((MOV_INCHIS, ROSU, MASLINIU))))
		z += 3.2
	# cornișa și aticul
	s.append(cub("Cornisa", (w + 0.3, 0.45, 0.3), (0, 0.0, h - 0.2), rama))
	s.append(cub("Atic", (w, 0.25, 0.7), (0, 0.12, h + 0.35), perete))
	piese.append(_obiect(s, (loc[0], loc[1], 0.0), (0, 0, unghi), nume="Cladire"))
	if l:
		lumini.append(_obiect(l, (loc[0], loc[1], 0.0), (0, 0, unghi), nume="Lumini"))
	col.append(_obiect([cub("Coliziune", (w, d, h), (0, d / 2, h / 2), NEGRU)], (loc[0], loc[1], 0.0), (0, 0, unghi), nume="Coliziune"))


STILURI = [
	(TENCUIALA, BETON, ALB), (CARAMIDA, MORTAR, BETON), (GRI_ALBASTRU, METAL, ALB), (MASLINIU, VERDE_INCHIS, TENCUIALA),
	(ROSU, CARAMIDA, TENCUIALA), (BETON, METAL_INCHIS, TENCUIALA), (PETROL, PETROL_DESCHIS, ALB), (MOV_INCHIS, MORTAR, BETON),
]


# ---------------------------------------------------------------------------------------------------------------
# Piața
# ---------------------------------------------------------------------------------------------------------------

def _felinar(piese, lumini, col, x, y):
	"""Felinar vechi de piață: stâlp de fontă cu soclu, brațul cu globul (aprins)."""
	piese += [
		cilindru("Soclu felinar", 0.2, 0.22, 0.5, (x, y, FL + 0.25), NEGRU, laturi=8),
		cilindru("Stalp felinar", 0.07, 0.09, 3.6, (x, y, FL + 2.3), NEGRU, laturi=8),
		cilindru("Inel felinar", 0.12, 0.12, 0.08, (x, y, FL + 4.1), AUR, laturi=8),
		cilindru("Capac felinar", 0.05, 0.24, 0.16, (x, y, FL + 4.68), NEGRU, laturi=8),
	]
	lumini.append(sfera("Glob felinar", 0.22, (x, y, FL + 4.42), AUR, segmente=8, inele=6))
	_cutie_coliziune(col, (0.35, 0.35, 4.6), (x, y, FL + 2.3))


def _banca(piese, col, x, y, unghi):
	"""Bancă de parc (picioare de fontă, scânduri), cu fața spre `unghi` (radiani, în planul XY)."""
	s = [
		cub("Sezut banca", (1.8, 0.45, 0.06), (0, 0, 0.45), LEMN),
		cub("Spatar banca", (1.8, 0.06, 0.38), (0, 0.24, 0.72), LEMN),
	]
	for k in (-0.8, 0.8):
		s.append(cub("Picior banca", (0.07, 0.42, 0.45), (k, 0.02, 0.225), NEGRU))
		s.append(cub("Brat banca", (0.06, 0.4, 0.06), (k, 0.0, 0.66), NEGRU))
	rot = unghi - math.pi / 2
	piese.append(_obiect(s, (x, y, FL), (0, 0, rot), nume="Banca"))
	col.append(_obiect([cub("Coliziune", (1.8, 0.55, 0.9), (0, 0.04, 0.45), NEGRU)], (x, y, FL), (0, 0, rot), nume="Coliziune"))


def _fantana(piese, lumini, col):
	"""Fântâna din mijloc: bazinul rotund de piatră (apă întunecată, frunze), soclul și statuia de bronz a unui om cu
	sabia ridicată (fondatorul orașului)."""
	piese.append(_inel_plat("Bazin", (CX, CY), 3.0, 3.35, FL + 0.6, 0.6, BETON, n=40))
	piese.append(_inel_plat("Buza bazin", (CX, CY), 2.95, 3.45, FL + 0.66, 0.06, TENCUIALA, n=40))
	piese.append(cilindru("Fund bazin", 3.0, 3.0, 0.1, (CX, CY, FL + 0.05), BETON, laturi=40))
	piese.append(cilindru("Apa", 3.0, 3.0, 0.03, (CX, CY, FL + 0.35), PETROL, laturi=40))
	r = random.Random(5)
	for k in range(9):
		u = r.uniform(0, math.tau)
		rr = r.uniform(0.9, 2.6)
		piese.append(cub("Frunza apa", (0.12, 0.08, 0.01), (CX + math.cos(u) * rr, CY + math.sin(u) * rr, FL + 0.37), BRONZ,
			rot=(0, 0, r.uniform(0, 3))))
	# soclul în trepte și statuia
	piese.append(cilindru("Soclu statuie", 0.75, 0.75, 0.5, (CX, CY, FL + 0.25 + 0.1), TENCUIALA, laturi=8))
	piese.append(cub("Piedestal", (0.9, 0.9, 1.6), (CX, CY, FL + 0.6 + 0.8), BETON))
	piese.append(cub("Placa piedestal", (0.5, 0.02, 0.3), (CX, CY - 0.46, FL + 1.3), BRONZ))
	piese.append(cub("Cornisa piedestal", (1.05, 1.05, 0.12), (CX, CY, FL + 2.26), TENCUIALA))
	z0 = FL + 2.32
	# omul: picioare, haina lungă, capul, brațul drept cu sabia spre cer, stângul pe piept
	statuie = [
		trunchi("Haina statuie", [((0, 0, 0.0), 0.0, 0.0), ((0, 0, 0.02), 0.3, 0.24), ((0, 0, 0.7), 0.24, 0.18), ((0, 0, 1.25), 0.28, 0.2),
			((0, 0, 1.45), 0.2, 0.15), ((0, 0, 1.5), 0.0, 0.0)], VERDE, laturi=8),
		sfera("Cap statuie", 0.13, (0, -0.02, 1.68), VERDE, segmente=8, inele=6),
		cilindru("Gat statuie", 0.06, 0.06, 0.12, (0, 0, 1.53), VERDE, laturi=6),
		os_intre("Brat statuie", (-0.25, 0, 1.38), (-0.38, -0.05, 1.85), 0.06, VERDE, laturi=6),
		os_intre("Sabie", (-0.4, -0.06, 1.9), (-0.52, -0.08, 2.75), 0.025, VERDE_INCHIS, laturi=4),
		cub("Garda sabie", (0.22, 0.04, 0.04), (-0.41, -0.06, 1.9), VERDE_INCHIS),
		os_intre("Brat stang statuie", (0.25, 0, 1.38), (0.12, -0.2, 1.15), 0.06, VERDE, laturi=6),
	]
	for k in range(6):  # petele de patină
		statuie.append(cub("Patina", (0.08, 0.012, 0.12), (r.uniform(-0.15, 0.15), -0.2, r.uniform(0.3, 1.2)), VERDE_INCHIS))
	piese.append(_obiect(statuie, (CX, CY, z0), (0, 0, 0.0), nume="Statuie"))
	col.append(_obiect([cilindru("Coliziune", 3.4, 3.4, 0.66, (0, 0, 0.33), NEGRU, laturi=16)], (CX, CY, FL), nume="Coliziune"))
	_cutie_coliziune(col, (1.0, 1.0, 4.6), (CX, CY, FL + 2.3))


def centru_oras(cale):
	"""Piața rotundă, clădirile din jur, pasajul spre bulevard, bulevardul (trotuar, bordură, asfalt cu marcaje), clădirile
	de vizavi, terenul. Piese: `Oras`, `Lumini` (geamuri și vitrine aprinse, neoanele, globurile felinarelor), `Coliziune`."""
	curata()
	r = random.Random(1010)
	piese, lumini, col = [], [], []

	# --- bulevardul (ca strada barului: trotuarul cu stația, bordura, asfaltul, trotuarul de vizavi)
	L = 220.0
	piese.append(cub("Teren", (L, 200.0, 0.1), (0, 20.0, -0.11), VERDE_NEGRU))
	piese.append(cub("Trotuar", (L, 3.4, FL), (0, -1.7, FL / 2), BETON))
	for xx in range(-60, 61, 2):
		piese.append(cub("Rost", (0.012, 3.4, 0.02), (xx * 1.0, -1.7, FL), METAL_INCHIS))
	piese.append(cub("Bordura", (L, 0.2, FL + 0.02), (0, -3.5, (FL + 0.02) / 2), TENCUIALA))
	piese.append(cub("Asfalt", (L, 7.4, 0.05), (0, -7.3, -0.025), NEGRU))
	for xx in range(-100, 102, 4):
		piese.append(cub("Marcaj", (2.0, 0.12, 0.02), (xx, -7.3, 0.0), AUR))
	piese.append(cub("Bordura", (L, 0.2, FL + 0.02), (0, -11.1, (FL + 0.02) / 2), TENCUIALA))
	piese.append(cub("Trotuar", (L, 3.0, FL), (0, -12.7, FL / 2), BETON))
	_cutie_coliziune(col, (L, 3.4, FL), (0, -1.7, FL / 2))
	_cutie_coliziune(col, (L, 0.2, FL + 0.02), (0, -3.5, (FL + 0.02) / 2))
	_cutie_coliziune(col, (L, 7.4, 0.05), (0, -7.3, -0.025))
	_cutie_coliziune(col, (L, 3.2, FL), (0, -12.6, FL / 2))
	for k in range(10):  # pete pe asfalt
		piese.append(cub("Pata asfalt", (r.uniform(0.5, 1.4), r.uniform(0.3, 0.9), 0.01), (-40 + k * 9 + r.uniform(-2, 2),
			r.uniform(-9.8, -4.5), 0.02), METAL_INCHIS, rot=(0, 0, r.uniform(0, 3))))
	# două mașini părăsite pe banda de vizavi (oamenii au fugit), una cu ușa deschisă, alta urcată pe bordură
	for (mx, my, mu, tip, cul) in ((-14.0, -9.0, 1.62, "sedan", ROSU), (17.0, -9.4, -1.45, "sedan", GRI_ALBASTRU)):
		s, c = motel._masina(tip, cul, r)
		piese.append(_obiect(s, (mx, my, 0.0), (0, 0, mu)))
		for (dx, dy, dz, ox, oy, oz) in c:
			col.append(_obiect([cub("Coliziune", (dx, dy, dz), (ox, oy, oz), NEGRU)], (mx, my, 0.0), (0, 0, mu), nume="Coliziune"))
	# felinarele bulevardului
	for x in (-18.0, 18.0):
		_felinar(piese, lumini, col, x, -3.0)
	_strange(piese, "Oras")

	# --- clădirile de pe bulevard: de o parte și de alta a pasajului, apoi de vizavi
	k = 0
	for semn in (-1, 1):
		x = LAT_PASAJ
		for lat, h in ((14.0, 9.5), (12.0, 13.0), (16.0, 10.5), (13.0, 15.0), (18.0, 8.5)):
			cx = semn * (x + lat / 2)
			_cladire(piese, lumini, col, (cx, 0.0), 0.0, lat, 6.5 if x == LAT_PASAJ else 12.0, h + r.uniform(-0.4, 0.4),
				STILURI[k % len(STILURI)], r, FIRME[k % len(FIRME)])
			x += lat
			k += 1
		_strange(piese, "Oras")
	x = -90.0
	while x < 90.0:
		lat = r.choice((12.0, 14.0, 16.0))
		_cladire(piese, lumini, col, (x + lat / 2, -14.3), math.pi, lat, 12.0, r.choice((9.0, 11.5, 14.0, 17.0)) + r.uniform(-0.3, 0.3),
			STILURI[k % len(STILURI)], r, FIRME[k % len(FIRME)])
		x += lat
		k += 1
	_strange(piese, "Oras")

	# --- podeaua: pasajul și piața, dintr-o bucată (fără fețe lipite)
	a0 = math.asin(LAT_PASAJ / R_PIATA)  # unde intră pasajul în cerc
	contur = [(LAT_PASAJ, 0.0)]
	n = 72
	start = -math.pi / 2 + a0
	for i in range(n + 1):
		u = start + (math.tau - 2 * a0) * i / n
		contur.append((CX + math.cos(u) * R_PIATA, CY + math.sin(u) * R_PIATA))
	contur.append((-LAT_PASAJ, 0.0))
	piese.append(_placa("Pavaj", contur, -0.05, FL, BETON))
	col.append(_placa("Coliziune", contur, -0.05, FL, NEGRU))
	# pe pavaj: cercurile de piatră deschisă și închisă, razele dintre ele, dalele din pasaj
	for r0, r1, cul in ((4.4, 5.0, TENCUIALA), (8.0, 8.4, METAL_INCHIS), (11.6, 12.4, TENCUIALA), (14.6, 14.9, METAL_INCHIS)):
		piese.append(_inel_plat("Cerc pavaj", (CX, CY), r0, r1, FL + 0.012, 0.03, cul))
	for i in range(16):
		u = i * math.tau / 16
		a = (CX + math.cos(u) * 5.0, CY + math.sin(u) * 5.0)
		b = (CX + math.cos(u) * 11.6, CY + math.sin(u) * 11.6)
		piese.append(cub("Raza pavaj", (math.hypot(b[0] - a[0], b[1] - a[1]), 0.18, 0.03), ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2,
			FL - 0.003), METAL_INCHIS, rot=(0, 0, u)))
	for yy in range(1, 6):
		piese.append(cub("Rost pasaj", (2 * LAT_PASAJ - 0.2, 0.06, 0.03), (0, yy * 1.0, FL - 0.003), METAL_INCHIS))
	_strange(piese, "Oras")

	# --- cele 8 clădiri din jurul pieței (cu fața spre centru); cele de la capete (lângă pasaj) sunt mai puțin adânci,
	# ca să nu iasă pe bulevard
	arc = math.tau - 2 * a0
	nr = 8
	inaltimi = [11.0, 16.5, 13.0, 19.0, 14.5, 17.5, 12.0, 10.5]
	for i in range(nr):
		u = -math.pi / 2 + a0 + arc * (i + 0.5) / nr
		lat = 2 * R_PIATA * math.tan(arc / nr / 2) + 0.5
		adanc = 7.0 if i in (0, nr - 1) else 14.0
		loc = (CX + math.cos(u) * R_PIATA, CY + math.sin(u) * R_PIATA)
		_cladire(piese, lumini, col, loc, u - math.pi / 2, lat, adanc, inaltimi[i], STILURI[(i + 3) % len(STILURI)], r,
			FIRME[(i + 5) % len(FIRME)])
		_strange(piese, "Oras")

	# --- în piață: fântâna, felinarele, băncile, jardinierele (copacii îi pune scena), coșuri de gunoi
	_fantana(piese, lumini, col)
	for i in range(8):
		u = -math.pi / 2 + 0.55 + i * (math.tau - 1.1) / 7
		_felinar(piese, lumini, col, CX + math.cos(u) * 14.0, CY + math.sin(u) * 14.0)
	for i in range(6):
		u = -math.pi / 2 + 0.9 + i * (math.tau - 1.8) / 5
		_banca(piese, col, CX + math.cos(u) * 10.3, CY + math.sin(u) * 10.3, u + math.pi)
	for u in (math.pi * 0.25, math.pi * 0.75, math.pi * 1.25, math.pi * 1.75):
		x, y = CX + math.cos(u) * 8.6, CY + math.sin(u) * 8.6
		piese.append(cub("Jardiniera", (1.8, 1.8, 0.55), (x, y, FL + 0.275), TENCUIALA))
		piese.append(cub("Pamant jardiniera", (1.6, 1.6, 0.04), (x, y, FL + 0.54), MORTAR))
		_cutie_coliziune(col, (1.8, 1.8, 0.55), (x, y, FL + 0.275))
	for u in (0.2, 2.1, 3.7, 5.2):
		x, y = CX + math.cos(u) * 12.9, CY + math.sin(u) * 12.9
		piese.append(cilindru("Cos gunoi", 0.24, 0.26, 0.85, (x, y, FL + 0.425), VERDE_NEGRU, laturi=10))
		piese.append(cilindru("Buza cos", 0.27, 0.27, 0.05, (x, y, FL + 0.87), METAL_INCHIS, laturi=10))
		_cutie_coliziune(col, (0.5, 0.5, 0.9), (x, y, FL + 0.45))
	# ce au scăpat oamenii când au fugit: o geantă, o umbrelă, cafele, ziare
	for k in range(10):
		u = r.uniform(0, math.tau)
		rr = r.uniform(4.0, 12.0)
		x, y = CX + math.cos(u) * rr, CY + math.sin(u) * rr
		fel = k % 4
		if fel == 0:
			piese.append(cub("Ziar", (0.4, 0.3, 0.012), (x, y, FL + 0.02), ALB, rot=(0, 0, r.uniform(0, 3))))
		elif fel == 1:
			piese.append(cilindru("Pahar cafea", 0.04, 0.05, 0.13, (x, y, FL + 0.05), ALB, laturi=6, rot=(1.57, 0, r.uniform(0, 3))))
		elif fel == 2:
			piese.append(cub("Geanta", (0.35, 0.15, 0.25), (x, y, FL + 0.08), r.choice((ROSU, MORTAR, NEGRU)), rot=(1.4, 0, r.uniform(0, 3))))
		else:
			piese.append(os_intre("Umbrela", (x, y, FL + 0.05), (x + 0.6, y + 0.3, FL + 0.08), 0.06, NEGRU, laturi=6))
	_strange(piese, "Oras")
	uneste(lumini, "Lumini")
	uneste(col, "Coliziune")
	exporta(os.path.join(cale, "centru_oras.glb"))


def statie(cale):
	import autobuz
	autobuz.statie(cale, "CITY CENTER", "statie_centru.glb")


# ---------------------------------------------------------------------------------------------------------------
# Oamenii din piață
# ---------------------------------------------------------------------------------------------------------------

PIELE = p("a56850")
PIELE_UMBRA = p("904a40")
# pozele de repaus ale brațelor (cot, încheietură), D = dreapta lor (-X): cu mâinile sus, cu mâinile la gură, atârnate
SUS = {"poza_D": ((-0.31, -0.02, 1.64), (-0.27, -0.08, 1.93)), "poza_S": ((0.31, -0.02, 1.64), (0.27, -0.08, 1.93))}
LA_GURA = {"poza_D": ((-0.2, -0.24, 1.3), (-0.05, -0.2, 1.62)), "poza_S": ((0.2, -0.24, 1.3), (0.05, -0.2, 1.62))}
UNA_SUS = {"poza_D": ((-0.31, -0.02, 1.64), (-0.27, -0.1, 1.93)), "poza_S": ((0.24, -0.02, 1.13), (0.24, -0.06, 0.87))}

CIVILI = {
	# omul de afaceri: costum, cravată, mâinile sus
	"civil_1": (dict({"piele": PIELE, "piele_umbra": PIELE_UMBRA, "haina": p("2a3c3d"), "haina_umbra": NEGRU, "camasa": ALB,
		"cravata": ROSU, "pantaloni": p("2a3c3d"), "pantofi": NEGRU, "par": p("48313b"), "stil_par": "spate", "in_picioare": True,
		"sezut": 0.86}, **SUS), 201),
	# femeia în rochie mov, cu mâinile la gură
	"civil_2": (dict({"piele": PIELE, "piele_umbra": PIELE_UMBRA, "haina": MOV, "haina_umbra": MOV_INCHIS, "camasa": MOV,
		"stil_haina": "rochie", "brate_goale": True, "femeie": True, "par": p("262d2f"), "par_suvita": MORTAR, "stil_par": "voluminos",
		"buze": ROSU, "gura": CARAMIDA, "pantaloni": PIELE, "pantofi": NEGRU, "in_picioare": True, "sezut": 0.86, "gros_brat": 0.8},
		**LA_GURA), 202),
	# alergătorul în trening
	"civil_3": (dict({"piele": PIELE, "piele_umbra": PIELE_UMBRA, "haina": PETROL_DESCHIS, "haina_umbra": PETROL, "camasa": ALB,
		"stil_haina": "trening", "dungi_maneca": ALB, "pantaloni": PETROL_DESCHIS, "pantofi": ALB, "par": MORTAR, "stil_par": "ras",
		"in_picioare": True, "sezut": 0.86}, **UNA_SUS), 203),
	# bătrânul cu șapcă și ochelari
	"civil_4": (dict({"piele": PIELE, "piele_umbra": PIELE_UMBRA, "haina": MASLINIU, "haina_umbra": VERDE, "camasa": TENCUIALA,
		"stil_haina": "pulover", "nasturi": MORTAR, "pantaloni": METAL_INCHIS, "pantofi": MORTAR, "par": ALB, "stil_par": "chel",
		"palarie": "sapca", "culoare_palarie": METAL_INCHIS, "culoare_palarie_umbra": MORTAR, "ochelari": "vedere", "rama": MORTAR,
		"riduri": True, "slab": 0.5, "in_picioare": True, "sezut": 0.86}, **LA_GURA), 204),
	# tânărul cu geacă de piele
	"civil_5": (dict({"piele": PIELE, "piele_umbra": PIELE_UMBRA, "haina": NEGRU, "haina_umbra": p("2a3c3d"), "camasa": ROSU,
		"stil_haina": "geaca", "pantaloni": GRI_ALBASTRU, "pantofi": NEGRU, "par": BRONZ, "stil_par": "scurt", "in_picioare": True,
		"sezut": 0.86}, **SUS), 205),
	# femeia blondă cu pulover
	"civil_6": (dict({"piele": PIELE, "piele_umbra": PIELE_UMBRA, "haina": ROSU_DESCHIS, "haina_umbra": ROSU, "camasa": ALB,
		"stil_haina": "pulover", "nasturi": AUR, "femeie": True, "par": AUR, "par_suvita": BRONZ, "stil_par": "voluminos",
		"buze": ROSU, "gura": CARAMIDA, "pantaloni": p("2a3c3d"), "pantofi": NEGRU, "in_picioare": True, "sezut": 0.86,
		"gros_brat": 0.85}, **UNA_SUS), 206),
}


def civili(cale):
	for nume, (s, saminta) in CIVILI.items():
		casino_oameni.om(cale, nume, s, saminta)


# ---------------------------------------------------------------------------------------------------------------
# Head Witch
# ---------------------------------------------------------------------------------------------------------------

def vrajitoare_sefa_lupta(cale):
	coven.vrajitoare_sefa(cale, lupta=True)


def palarie_sefa(cale):
	"""Pălăria lui Head Witch (aceeași ca pe capul ei, coven.SEFA), cu originea în mijlocul borului."""
	curata()
	piese = []
	_palarie(piese, (0, 0, 0), SEFA.get("bor", 0.27), SEFA.get("inaltime_palarie", 0.5), SEFA["palarie"], SEFA["banda"],
		random.Random(1313), aplecare=0.03, varf=SEFA.get("varf", (0.16, 0.05)))
	uneste(piese, "Palarie")
	exporta(os.path.join(cale, "palarie_sefa.glb"))


# culorile formei a doua: piele cenușie-verzuie, oase, robă neagră-mov, foc verde
D_PIELE = p("5b6d4e")
D_PIELE_UMBRA = p("445d46")
D_OS = p("83b3b0")
D_OS_UMBRA = p("7e8d87")
D_ROBA = p("262d2f")
D_ROBA_MOV = p("553e4d")
D_FOC = p("61a19f")
D_FOC_INCHIS = p("438b88")


def _gheara(piese, umar, cot, inch, r, latura):
	"""Brațul lung și osos al formei a doua: umărul cu spini, antebrațul, palma și cinci degete lungi cu gheare negre.
	Întoarce mijlocul palmei. `latura` = -1 (dreapta lor) / 1 (stânga)."""
	piese.append(trunchi("Brat demon", [(umar, 0.075, 0.07), (_lerp(umar, cot, 0.5), 0.06, 0.055), (cot, 0.065, 0.06),
		(_lerp(cot, inch, 0.5), 0.05, 0.045), (inch, 0.042, 0.04)], D_PIELE, laturi=6, ref=(0, 0, 1)))
	piese.append(sfera("Cot demon", 0.07, cot, D_OS, segmente=6, inele=4))
	# zdreanța mânecii rupte, de la umăr
	for k in range(4):
		a = _lerp(umar, cot, 0.1 + 0.18 * k)
		piese.append(cub("Maneca rupta", (0.16, 0.02, 0.22 - k * 0.03), (a[0], a[1] + 0.06, a[2] - 0.08), D_ROBA_MOV,
			rot=(0.2, 0.3 * latura, r.uniform(-0.3, 0.3))))
	# crăpăturile care ard (verde) pe antebraț
	for k in range(3):
		a = _lerp(cot, inch, 0.2 + 0.25 * k)
		piese.append(cub("Crapatura", (0.012, 0.012, 0.09), (a[0], a[1] - 0.045, a[2]), D_FOC, rot=(0, 0.4 * (k - 1), 0)))
	d = tuple((b - a) for a, b in zip(cot, inch))
	l = math.sqrt(sum(x * x for x in d))
	d = tuple(x / l for x in d)
	palma = tuple(a + b * 0.08 for a, b in zip(inch, d))
	piese.append(sfera("Palma demon", 0.075, palma, D_PIELE, scara=(1.0, 0.7, 1.2), segmente=6, inele=4))
	lat = (latura * 1.0, 0.0, 0.0)
	for k in range(5):
		o = (k - 2) * 0.03
		desf = (k - 2) * 0.22
		baza = (palma[0] + lat[0] * o, palma[1] - 0.02, palma[2] + d[2] * 0.06)
		dir_ = (d[0] + lat[0] * desf, d[1] - 0.25, d[2])
		lung = 0.22 if k != 0 else 0.15
		mij = tuple(b + x * lung * 0.5 for b, x in zip(baza, dir_))
		varf = (mij[0] + dir_[0] * lung * 0.5, mij[1] + dir_[1] * lung * 0.5 - 0.06, mij[2] + dir_[2] * lung * 0.5)
		piese.append(trunchi("Deget demon", [(baza, 0.018, 0.018), (mij, 0.015, 0.015), (varf, 0.012, 0.012)], D_PIELE, laturi=4))
		gheara = (varf[0] + dir_[0] * 0.09, varf[1] - 0.07, varf[2] + dir_[2] * 0.09)
		piese.append(trunchi("Gheara", [(varf, 0.013, 0.013), (gheara, 0.0, 0.0)], NEGRU, laturi=4))
	return palma


def vrajitoare_sefa_demon(cale):
	"""Head Witch după transformare (faza a doua): înaltă de ~3,4 m, plutește (sub brâu roba se rupe în fâșii ascuțite,
	fără picioare), trunchi slab cu coastele ieșite și un miez verde care arde în piept (amuleta topită în ea), brațe
	lungi cu gheare, gulerul de spini, aripi de os cu membrană ruptă, capul alungit cu fălcile deschise și colți, patru
	ochi, coarne mari întoarse, părul roșu care plutește în sus, pălăria mare și ruptă, iar în spatele capului o coroană
	de spini care ard. Piese: `Corp`, `Lumini` (miezul, crăpăturile, coroana), `Cap` (originea în gât) cu `Ochi`,
	`BratDrept` / `BratStang` (originea în umăr, cu punctul `Palma`), `AripaDreapta` / `AripaStanga` (originea în
	omoplat)."""
	curata()
	r = random.Random(666)
	corp, lumini = [], []
	# roba de sub brâu: un con negru și fâșii lungi, ascuțite, care se unduiesc spre pământ
	corp.append(trunchi("Roba demon", [((0, 0, 0.55), 0.0, 0.0), ((0, 0, 0.8), 0.2, 0.17), ((0, 0.02, 1.2), 0.32, 0.27),
		((0, 0.02, 1.6), 0.33, 0.26)], D_ROBA, laturi=10))
	for k in range(16):
		u = k * math.tau / 16 + r.uniform(-0.1, 0.1)
		sus = (math.cos(u) * 0.3, 0.02 + math.sin(u) * 0.24, 1.55)
		mij = (math.cos(u) * 0.52 + r.uniform(-0.06, 0.06), 0.02 + math.sin(u) * 0.44 + r.uniform(-0.06, 0.06), 0.95 + r.uniform(-0.1, 0.1))
		jos = (math.cos(u + r.uniform(-0.3, 0.3)) * 0.42, 0.02 + math.sin(u) * 0.36, r.uniform(0.15, 0.45))
		corp.append(trunchi("Fasie roba", [(sus, 0.12, 0.03), (mij, 0.11, 0.025), (jos, 0.0, 0.0)], D_ROBA if k % 3 else D_ROBA_MOV,
			laturi=4, ref=(-math.sin(u), math.cos(u), 0)))
	# trunchiul: talia îngustă, pieptul cu coastele, umerii lați
	tors = [(1.5, 0.27, 0.21), (1.75, 0.23, 0.17), (2.0, 0.29, 0.19), (2.25, 0.4, 0.21), (2.38, 0.24, 0.16), (2.44, 0.1, 0.09)]
	corp.append(trunchi("Tors demon", [((0, 0.02, z), rx, ry) for z, rx, ry in tors], D_PIELE, laturi=10))
	corp.append(trunchi("Brau demon", [((0, 0.02, 1.52), 0.3, 0.24), ((0, 0.02, 1.62), 0.29, 0.23)], D_ROBA_MOV, laturi=10))
	for i, z in enumerate((1.86, 1.96, 2.06, 2.15)):
		rx = 0.24 + i * 0.03
		ry = 0.175 + i * 0.006
		for latura in (-1, 1):
			pts = []
			for j in range(5):
				a = -math.pi / 2 + latura * (0.15 + j * 0.24)
				pts.append(((math.cos(a) * (rx + 0.015)), 0.02 + math.sin(a) * (ry + 0.015), z - j * 0.025))
			corp.append(trunchi("Coasta", [(pt, 0.014, 0.012) for pt in pts], D_OS, laturi=4))
	corp.append(cub("Stern", (0.04, 0.03, 0.34), (0, 0.02 - 0.2, 2.02), D_OS))
	# miezul verde din piept (amuleta topită) și crăpăturile care pleacă din el
	lumini.append(sfera("Miez", 0.085, (0, 0.02 - 0.215, 2.02), D_FOC, segmente=8, inele=6))
	for k in range(6):
		u = k * math.tau / 6 + 0.3
		a = (math.cos(u) * 0.09, 0.02 - 0.205, 2.02 + math.sin(u) * 0.09)
		b = (math.cos(u) * 0.2, 0.02 - 0.17, 2.02 + math.sin(u) * 0.22)
		lumini.append(os_intre("Crapatura piept", a, b, 0.012, D_FOC_INCHIS, laturi=4))
	# gulerul de spini, ca un evantai în spatele capului (gulerul ei înalt, crescut)
	for k in range(11):
		u = math.pi * (0.08 + 0.84 * k / 10)
		baza = (math.cos(u) * 0.2, 0.1 + math.sin(u) * 0.05, 2.36)
		varf = (math.cos(u) * 0.62, 0.22 + math.sin(u) * 0.12, 2.75 + math.sin(u) * 0.45)
		corp.append(trunchi("Spin guler", [(baza, 0.05, 0.02), (_lerp(baza, varf, 0.6), 0.035, 0.015), (varf, 0.0, 0.0)],
			D_ROBA_MOV if k % 2 else D_ROBA, laturi=4, ref=(0, 1, 0)))
	# spinii de os de pe umeri
	for latura in (-1, 1):
		for k in range(3):
			baza = (latura * (0.36 + k * 0.05), 0.04, 2.3 - k * 0.03)
			varf = (latura * (0.5 + k * 0.1), 0.1 + k * 0.03, 2.62 - k * 0.08)
			corp.append(trunchi("Spin umar", [(baza, 0.045, 0.045), (varf, 0.0, 0.0)], D_OS_UMBRA, laturi=5))
	# coroana de spini care ard, în spatele capului (pe corp: nu se mișcă odată cu capul)
	for k in range(9):
		u = math.pi * (0.1 + 0.8 * k / 8)
		baza = (math.cos(u) * 0.36, 0.3, 2.62 + math.sin(u) * 0.36)
		varf = (math.cos(u) * 0.6, 0.32, 2.62 + math.sin(u) * 0.6)
		lumini.append(trunchi("Spin coroana", [(baza, 0.03, 0.02), (varf, 0.0, 0.0)], D_FOC, laturi=4, ref=(0, 1, 0)))
	corp.append(cilindru("Cerc coroana", 0.36, 0.36, 0.03, (0, 0.31, 2.62), D_ROBA, laturi=16, rot=(1.5708, 0, 0)))
	uneste(corp, "Corp")
	uneste(lumini, "Lumini")


	# brațele lungi
	for latura, nume in ((-1, "BratDrept"), (1, "BratStang")):
		umar = (latura * 0.42, 0.02, 2.3)
		cot = (latura * 0.56, 0.06, 1.8)
		inch = (latura * 0.52, -0.06, 1.3)
		brat = []
		palma = _gheara(brat, umar, cot, inch, r, latura)
		ob = uneste(brat, nume, umar)
		casino_oameni._punct("Palma", palma, ob)


	# aripile: trei degete de os răsfirate în sus și în lături, cu membrană ruptă între ele
	for latura, nume in ((-1, "AripaDreapta"), (1, "AripaStanga")):
		omoplat = (latura * 0.16, 0.2, 2.2)
		aripa = []
		varfuri = []
		for k, (lung, sus, lat) in enumerate(((1.9, 1.3, 0.75), (1.6, 0.55, 1.0), (1.3, -0.2, 0.9))):
			cot_ = (omoplat[0] + latura * 0.5, omoplat[1] + 0.35, omoplat[2] + 0.45)
			varf = (cot_[0] + latura * lat * lung * 0.7, cot_[1] + 0.25, cot_[2] + sus * lung * 0.55)
			if k == 0:
				aripa.append(trunchi("Os aripa", [(omoplat, 0.06, 0.06), (cot_, 0.055, 0.055)], D_OS, laturi=5))
				aripa.append(sfera("Incheietura aripa", 0.07, cot_, D_OS_UMBRA, segmente=6, inele=4))
			aripa.append(trunchi("Deget aripa", [(cot_, 0.04, 0.04), (_lerp(cot_, varf, 0.6), 0.03, 0.03), (varf, 0.0, 0.0)], D_OS, laturi=5))
			varfuri.append(varf)
		# membrana: triunghiuri subțiri între degete, cu marginea ruptă (vârfurile tăiate la întâmplare)
		cot_ = (omoplat[0] + latura * 0.5, omoplat[1] + 0.35, omoplat[2] + 0.45)
		for a, b in zip(varfuri, varfuri[1:]):
			for j in range(3):
				t0, t1 = j / 3, (j + 1) / 3
				pa = _lerp(cot_, a, 0.95 - 0.1 * r.random())
				pb = _lerp(cot_, b, 0.95 - 0.1 * r.random())
				p0 = _lerp(pa, pb, t0)
				p1 = _lerp(pa, pb, t1)
				mij = _lerp(p0, p1, 0.5)
				adanc = r.uniform(0.0, 0.25)
				aripa.append(trunchi("Membrana", [(cot_, 0.0, 0.0), (_lerp(cot_, mij, 0.5), math.dist(p0, p1) * 0.27, 0.008),
					(_lerp(cot_, mij, 0.95 - adanc), math.dist(p0, p1) * 0.48, 0.008)], D_ROBA_MOV, laturi=4,
					ref=tuple(x - y for x, y in zip(p1, p0))))
		ob = uneste(aripa, nume, omoplat)


	# capul: un craniu alungit, fălcile deschise cu colți, patru ochi, coarnele, părul care plutește, pălăria
	g = (0, 0.0, 2.42)
	gx, gy, gz = g
	cap, ochi = [], []
	cap.append(os_intre("Gat demon", (gx, gy + 0.03, gz - 0.06), (gx, gy, gz + 0.1), 0.07, D_PIELE, laturi=6))
	# (z, y-ul centrului, rx, ry): fața din față e la y - ry
	fata = [(0.0, 0.0, 0.0, 0.0), (0.05, -0.01, 0.09, 0.08), (0.14, -0.02, 0.13, 0.12), (0.25, -0.015, 0.15, 0.14),
		(0.36, 0.0, 0.15, 0.14), (0.45, 0.015, 0.12, 0.115), (0.52, 0.02, 0.06, 0.06), (0.55, 0.02, 0.0, 0.0)]
	cap.append(trunchi("Fata demon", [((gx, gy + y, gz + z), rx, ry) for z, y, rx, ry in fata], D_OS_UMBRA, laturi=10))
	# falca de jos, căzută (gura deschisă larg), gaura neagră a gurii și colții de sus și de jos
	cap.append(trunchi("Falca", [((gx, gy - 0.04, gz + 0.07), 0.1, 0.06), ((gx, gy - 0.12, gz - 0.06), 0.085, 0.045),
		((gx, gy - 0.16, gz - 0.15), 0.045, 0.03), ((gx, gy - 0.17, gz - 0.18), 0.0, 0.0)], D_OS_UMBRA, laturi=8))
	cap.append(cub("Gura demon", (0.15, 0.05, 0.13), (gx, gy - 0.13, gz + 0.06), NEGRU))
	for k in range(6):
		x = gx - 0.06 + k * 0.024
		cap.append(trunchi("Colt", [((x, gy - 0.16, gz + 0.12), 0.009, 0.008), ((x, gy - 0.163, gz + 0.05 - 0.02 * (k in (0, 5))), 0.0, 0.0)],
			D_OS, laturi=4))
		if k in (1, 2, 3, 4):
			cap.append(trunchi("Colt", [((x, gy - 0.17, gz - 0.07), 0.008, 0.007), ((x, gy - 0.172, gz - 0.01), 0.0, 0.0)], D_OS, laturi=4))
	for latura in (-1, 1):
		cap.append(cub("Orbita demon", (0.07, 0.02, 0.05), (gx + 0.06 * latura, gy - 0.155, gz + 0.27), NEGRU))
		cap.append(cub("Orbita mica", (0.04, 0.02, 0.03), (gx + 0.075 * latura, gy - 0.14, gz + 0.37), NEGRU))
		cap.append(cub("Nara", (0.015, 0.02, 0.045), (gx + 0.018 * latura, gy - 0.155, gz + 0.19), NEGRU))
		cap.append(sfera("Pomet demon", 0.05, (gx + 0.12 * latura, gy - 0.1, gz + 0.2), D_PIELE_UMBRA, scara=(0.6, 0.6, 1.0), segmente=6,
			inele=4))
		ochi.append(cub("Ochi", (0.045, 0.012, 0.022), (gx + 0.06 * latura, gy - 0.172, gz + 0.27), D_FOC))
		ochi.append(cub("Ochi", (0.025, 0.012, 0.014), (gx + 0.075 * latura, gy - 0.157, gz + 0.37), D_FOC))
		# coarnele: ies din tâmple, se duc în lături (pe sub bor), apoi urcă și se întorc în față
		drum = [(gx + 0.12 * latura, gy + 0.0, gz + 0.42), (gx + 0.3 * latura, gy + 0.02, gz + 0.5), (gx + 0.48 * latura, gy + 0.05, gz + 0.62),
			(gx + 0.56 * latura, gy + 0.08, gz + 0.82), (gx + 0.52 * latura, gy + 0.04, gz + 1.0), (gx + 0.44 * latura, gy - 0.02, gz + 1.08)]
		raze = [0.07, 0.065, 0.055, 0.045, 0.03, 0.0]
		cap.append(trunchi("Corn", [(c, rr, rr) for c, rr in zip(drum, raze)], MORTAR, laturi=6))
		for j in range(1, 4):  # inelele de pe corn
			c = drum[j]
			cap.append(trunchi("Inel corn", [(c, raze[j] + 0.01, raze[j] + 0.01), (_lerp(c, drum[j + 1], 0.12), raze[j] + 0.01,
				raze[j] + 0.01)], NEGRU, laturi=6))
	# părul roșu: șuvițe groase care plutesc în sus și în lături, ca în apă
	for k in range(18):
		u = math.pi * (-0.2 + 1.4 * k / 17)
		start = (gx + math.cos(u) * 0.13, gy + math.sin(u) * 0.13 + 0.03, gz + 0.46)
		lung = r.uniform(0.5, 0.85)
		mij = (start[0] + math.cos(u) * lung * 0.45 + r.uniform(-0.05, 0.05), start[1] + math.sin(u) * lung * 0.3 + 0.1,
			start[2] + lung * 0.2)
		capat = (start[0] + math.cos(u) * lung * 0.8 + r.uniform(-0.1, 0.1), start[1] + math.sin(u) * lung * 0.5 + 0.2,
			start[2] + lung * 0.55 + r.uniform(-0.1, 0.1))
		cap.append(trunchi("Par demon", [(start, 0.035, 0.016), (mij, 0.036, 0.015), (capat, 0.0, 0.0)], ROSU if k % 3 else ROSU_DESCHIS,
			laturi=4, ref=(math.cos(u), math.sin(u), 0)))
	# pălăria: mai mare și strâmbă, pusă pe ceafă (coarnele trec pe sub bor)
	_palarie(cap, (gx, gy + 0.05, gz + 0.5), 0.38, 0.95, SEFA["palarie"], D_ROBA_MOV, r, aplecare=0.1, varf=(-0.35, 0.22))
	ob_cap = uneste(cap, "Cap", (gx, gy, gz + 0.02))
	_parinte(uneste(ochi, "Ochi", (gx, gy - 0.12, gz + 0.3)), ob_cap)

	exporta(os.path.join(cale, "vrajitoare_sefa_demon.glb"))


def toate(cale):
	centru_oras(cale)
	statie(cale)
	civili(cale)
	vrajitoare_sefa_lupta(cale)
	palarie_sefa(cale)
	vrajitoare_sefa_demon(cale)


if __name__ == "__main__":
	modele = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")
	argumente = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	if argumente:
		for nume in argumente:
			globals()[nume](modele)
	else:
		toate(modele)
