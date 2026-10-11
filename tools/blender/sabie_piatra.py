# Curtea din spatele barului „URBAN” și sabia din piatră (owner, 11.10): ieși pe ușa „EMPLOYEES ONLY” și ajungi într-o
# curte îngrădită (betonul crăpat de lângă ușă, pământ bătătorit, gardul de scânduri, butoaie de bere, lăzi, saci de
# gunoi, aparatul de aer condiționat, un copac uscat); în mijloc, o piatră veche cu o sabie înfiptă în ea.
#   curte  -> bar_curte.glb      (`Curte`, `Lumini`, `Coliziune`)
#   piatra -> piatra_sabie.glb   (`Piatra`, `Crapaturi` (se aprind verde cât tragi), `Muschi`)
#   sabie  -> sabie_blestemata.glb (`Sabie` + `Rune` (ochii craniului, runele, gema; strălucesc verde în joc))
#   pumn   -> pumn_jucator.glb   (mâna ta dreaptă strânsă pe un mâner vertical; stânga = aceeași, oglindită în joc)
#   blender --background --factory-startup --python tools/blender/sabie_piatra.py               (toate)
#   blender --background --factory-startup --python tools/blender/sabie_piatra.py -- sabie pumn (doar unele)
# Axe Blender: Z în sus; Godot = (x, z, -y) din Blender. Curtea e în spatele barului: y de la 13,25 (zidul din spate,
# fața de afară) la 23 (gardul), x ±7,25 (cât clădirea).
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, uneste, exporta, trunchi, _coloreaza  # noqa: E402
from casino import _text_o_fata, _cutie_coliziune  # noqa: E402

NEGRU = p("262d2f")
ALB = p("83b3b0")
AUR = p("a18463")
CROM = p("7e8d87")
METAL = p("6f6d7f")
METAL_INCHIS = p("5e5356")
LEMN = p("5e363e")
LEMN_INCHIS = p("48313b")
LEMN_DESCHIS = p("904a40")
ROSU = p("7b383a")
BETON = p("70706e")
TENCUIALA = p("7e8d87")
BRONZ = p("a56850")
VERDE = p("5b6d4e")
POSTAV = p("445d46")
VERDE_NEGRU = p("32453b")
MASLINIU = p("7a7b59")
GRI_ALBASTRU = p("778c96")
PETROL = p("295555")
OS = p("a18463")

FL = 0.15            # podeaua barului = curtea
Y0 = 13.25           # fața de afară a zidului din spate
Y1 = 23.0            # gardul din spate
XC = 7.25            # gardurile laterale (cât clădirea)
USA_X = -5.8         # ușa din spate (aceeași cu „EMPLOYEES ONLY” dinăuntru)
PIATRA = (0.0, 19.0)  # unde stă piatra (în Godot: (0, 0,15, -19))
H_GARD = 2.4


def _strange(piese, nume):
	if len(piese) > 1:
		ob = uneste(piese, nume)
		piese[:] = [ob]


def _parinte(copil, parinte):
	copil.parent = parinte
	copil.matrix_parent_inverse = parinte.matrix_world.inverted()


def _aseaza(ob, rot, loc):
	"""O piesă făcută în origine: o rotește (euler), apoi o mută la `loc` și aplică (rotirea unei piese gata aplicate s-ar
	face în jurul originii lumii)."""
	ob.rotation_euler = rot
	ob.location = loc
	bpy.ops.object.select_all(action="DESELECT")
	bpy.context.view_layer.objects.active = ob
	ob.select_set(True)
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	ob.select_set(False)


def curte(cale):
	"""Curtea din spate: betonul crăpat de lângă ușă, pământul, gardul de scânduri pe trei laturi (cu stâlpi și
	traverse), ușa de metal din spate cu lampa cu grilaj, aparatul de aer condiționat și țevile, butoaiele de bere,
	lăzile de sticle, sacii de gunoi, un scaun de bar rupt, copacul uscat din colț, plăcuța „Ancient Curse - DO NOT TOUCH OR REMOVE” de lângă
	piatră (piatra e separată)."""
	curata()
	r = random.Random(41)
	piese, lumini, col = [], [], []

	def strange():
		_strange(piese, "Curte")

	# --- jos: pământul (toată curtea) și betonul crăpat din dreptul ușii; coliziunea = o cutie cât curtea
	piese.append(cub("Pamant", (2 * XC, Y1 - Y0 + 0.3, FL), (0, (Y0 + Y1) / 2, FL / 2 - 0.004), LEMN_INCHIS))
	piese.append(cub("Beton curte", (2 * XC - 0.1, 3.0, 0.02), (0, Y0 + 1.5, FL + 0.006), BETON))
	_cutie_coliziune(col, (2 * XC + 0.5, Y1 - Y0 + 0.5, FL), (0, (Y0 + Y1) / 2, FL / 2))
	# crăpăturile din beton și petele de ulei (toate pe același strat, la 15 mm)
	for k in range(9):
		x = r.uniform(-6.5, 6.5)
		y = r.uniform(Y0 + 0.4, Y0 + 2.7)
		piese.append(cub("Crapatura beton", (r.uniform(0.4, 1.1), 0.02, 0.01), (x, y, FL + 0.02), NEGRU, rot=(0, 0, r.uniform(0, 3.1))))
	for k in range(4):
		piese.append(cub("Pata ulei", (r.uniform(0.3, 0.7), r.uniform(0.3, 0.6), 0.01), (r.uniform(-5, 5), r.uniform(Y0 + 0.5, Y0 + 2.6), FL + 0.02),
			METAL_INCHIS, rot=(0, 0, r.uniform(0, 3))))
	# smocuri de iarbă uscată pe pământ (mai rare spre piatră: în jurul ei nu crește nimic)
	for k in range(70):
		x = r.uniform(-6.9, 6.9)
		y = r.uniform(Y0 + 3.1, Y1 - 0.3)
		if math.hypot(x - PIATRA[0], y - PIATRA[1]) < 2.6:
			continue
		h = r.uniform(0.08, 0.22)
		for s in range(3):
			a = r.uniform(0, math.pi)
			piese.append(cub("Iarba", (0.012, 0.09, h), (x + 0.03 * math.cos(a * 3), y + 0.03 * math.sin(a * 3), FL + h / 2),
				r.choice((MASLINIU, VERDE, AUR)), rot=(r.uniform(-0.3, 0.3), 0, a)))
	# cercul de pământ ars din jurul pietrei (pete negre, pe un singur strat)
	for k in range(16):
		a = k / 16.0 * math.tau + r.uniform(-0.1, 0.1)
		rr = r.uniform(1.0, 2.1)
		piese.append(cub("Pamant ars", (r.uniform(0.25, 0.5), r.uniform(0.15, 0.3), 0.01),
			(PIATRA[0] + rr * math.cos(a), PIATRA[1] + rr * math.sin(a), FL + 0.008), NEGRU, rot=(0, 0, a)))
	strange()

	# --- gardul de scânduri: stâlpi, două traverse, scânduri verticale (unele lipsă, unele strâmbe)
	def gard(a, b):
		a, b = Vector((a[0], a[1], 0.0)), Vector((b[0], b[1], 0.0))
		d = b - a
		lung = d.length
		u = d.normalized()
		unghi = math.atan2(u.y, u.x)
		n = Vector((-u.y, u.x, 0))  # normala spre curte (gardurile se dau în sens trigonometric)
		pasi = int(lung / 2.0)
		for k in range(pasi + 1):
			c = a + u * (lung * k / pasi) - n * 0.06
			piese.append(cub("Stalp gard", (0.1, 0.1, H_GARD + 0.1), (c.x, c.y, FL + (H_GARD + 0.1) / 2 - 0.05), LEMN_INCHIS, rot=(0, 0, unghi)))
		for zz in (0.45, H_GARD - 0.35):
			c = a + d / 2 - n * 0.12
			piese.append(cub("Traversa", (lung, 0.05, 0.1), (c.x, c.y, FL + zz), LEMN_INCHIS, rot=(0, 0, unghi)))
		s = 0.0
		while s < lung - 0.05:
			lat = r.uniform(0.13, 0.17)
			if r.random() > 0.04:
				c = a + u * (s + lat / 2) - n * 0.17
				h = H_GARD - r.uniform(0.0, 0.12)
				piese.append(cub("Scandura", (lat - 0.012, 0.025, h), (c.x, c.y, FL + h / 2), r.choice((LEMN, LEMN, LEMN_DESCHIS, LEMN_INCHIS)),
					rot=(0, r.uniform(-0.015, 0.015), unghi)))
			s += lat
		c = a + d / 2 - n * 0.06
		col.append(cub("Coliziune", (lung + 0.2, 0.3, 3.0), (c.x, c.y, FL + 1.5), NEGRU, rot=(0, 0, unghi)))

	gard((-XC + 0.05, Y1), (-XC + 0.05, Y0))         # stânga
	strange()
	gard((XC - 0.05, Y0), (XC - 0.05, Y1))           # dreapta
	strange()
	gard((XC - 0.05, Y1), (-XC + 0.05, Y1))          # spate
	strange()

	# --- ușa de metal din spate, cu tocul, pragul, plăcuța și lampa cu grilaj de deasupra
	ux = USA_X
	piese.append(cub("Usa spate", (0.92, 0.05, 2.15), (ux, Y0 + 0.03, FL + 1.075), PETROL))
	for zz in (FL + 0.55, FL + 1.55):
		piese.append(cub("Nervura usa", (0.8, 0.015, 0.06), (ux, Y0 + 0.062, zz), METAL_INCHIS))
	for sx in (-1, 1):
		piese.append(cub("Toc usa spate", (0.07, 0.08, 2.25), (ux + sx * 0.5, Y0 + 0.04, FL + 1.125), METAL_INCHIS))
	piese.append(cub("Toc usa spate", (0.93, 0.08, 0.07), (ux, Y0 + 0.04, FL + 2.19), METAL_INCHIS))
	piese.append(cub("Prag", (1.1, 0.3, 0.03), (ux, Y0 + 0.24, FL + 0.015), BETON))
	piese.append(os_intre("Maner usa spate", (ux - 0.33, Y0 + 0.06, FL + 1.0), (ux - 0.33, Y0 + 0.13, FL + 1.0), 0.012, CROM))
	piese.append(cub("Maner usa spate", (0.13, 0.025, 0.025), (ux - 0.28, Y0 + 0.13, FL + 1.0), CROM))
	piese.append(cub("Placuta usa spate", (0.56, 0.012, 0.24), (ux, Y0 + 0.062, FL + 1.75), ALB))
	piese.append(_text_o_fata("Scris usa spate", "DELIVERIES\nRING BELL", (ux, Y0 + 0.078, FL + 1.75), 0.05, NEGRU, rot=(1.5708, 0, math.pi)))
	piese.append(cub("Sonerie", (0.06, 0.03, 0.09), (ux + 0.62, Y0 + 0.015, FL + 1.3), METAL_INCHIS))
	piese.append(cilindru("Buton sonerie", 0.012, 0.012, 0.01, (ux + 0.62, Y0 + 0.035, FL + 1.3), ROSU, laturi=8, rot=(1.5708, 0, 0)))
	lz = FL + 2.6
	piese.append(cub("Suport lampa", (0.12, 0.2, 0.06), (ux, Y0 + 0.1, lz + 0.12), METAL_INCHIS))
	piese.append(cilindru("Abajur lampa", 0.12, 0.05, 0.08, (ux, Y0 + 0.2, lz + 0.06), METAL_INCHIS, laturi=10))
	for k in range(4):
		a = k * math.pi / 4
		piese.append(cub("Grilaj lampa", (0.2, 0.008, 0.008), (ux, Y0 + 0.2, lz - 0.04), METAL_INCHIS, rot=(0, a, 0)))
	lumini.append(sfera("Bec curte", 0.05, (ux, Y0 + 0.2, lz - 0.02), AUR, segmente=8, inele=5))
	strange()

	# --- aparatul de aer condiționat pe zid, cu țeava care coboară, și un burlan la colț
	ax = 2.2
	piese.append(cub("Aer conditionat", (0.9, 0.35, 0.6), (ax, Y0 + 0.175, FL + 2.2), TENCUIALA))
	piese.append(cilindru("Grila ventilator", 0.22, 0.22, 0.012, (ax - 0.12, Y0 + 0.356, FL + 2.2), METAL_INCHIS, laturi=12, rot=(1.5708, 0, 0)))
	for k in range(5):
		piese.append(cub("Lamela", (0.012, 0.012, 0.42), (ax + 0.22 + k * 0.035, Y0 + 0.36, FL + 2.2), METAL))
	piese.append(cub("Suport aer", (0.05, 0.4, 0.05), (ax - 0.35, Y0 + 0.2, FL + 1.88), METAL_INCHIS))
	piese.append(cub("Suport aer", (0.05, 0.4, 0.05), (ax + 0.35, Y0 + 0.2, FL + 1.88), METAL_INCHIS))
	piese.append(os_intre("Teava aer", (ax + 0.4, Y0 + 0.06, FL + 2.0), (ax + 0.4, Y0 + 0.06, FL + 0.05), 0.02, METAL))
	piese.append(cub("Pata apa", (0.4, 0.3, 0.01), (ax + 0.4, Y0 + 0.3, FL + 0.02), METAL_INCHIS))
	piese.append(os_intre("Burlan", (6.95, Y0 + 0.08, FL + 3.6), (6.95, Y0 + 0.08, FL + 0.1), 0.05, METAL_INCHIS))
	piese.append(os_intre("Cot burlan", (6.95, Y0 + 0.08, FL + 0.18), (6.95, Y0 + 0.35, FL + 0.06), 0.05, METAL_INCHIS))
	strange()

	# --- butoaiele de bere goale lângă ușă, lăzile de sticle, sacii de gunoi
	for (bx, by, culcat) in ((-4.4, Y0 + 0.5, False), (-3.75, Y0 + 0.45, False), (-4.1, Y0 + 1.1, True)):
		if culcat:
			piese.append(cilindru("Butoi", 0.21, 0.21, 0.58, (bx, by, FL + 0.21), CROM, laturi=12, rot=(0, 1.5708, 0.4)))
			for dx in (-0.2, 0.2):
				piese.append(cilindru("Cerc butoi", 0.218, 0.218, 0.04, (bx + dx * math.cos(0.4), by + dx * math.sin(0.4), FL + 0.21), METAL,
					laturi=12, rot=(0, 1.5708, 0.4)))
			_cutie_coliziune(col, (0.6, 0.45, 0.42), (bx, by, FL + 0.21))
		else:
			piese.append(cilindru("Butoi", 0.21, 0.21, 0.58, (bx, by, FL + 0.29), CROM, laturi=12))
			for dz in (0.08, 0.5):
				piese.append(cilindru("Cerc butoi", 0.218, 0.218, 0.04, (bx, by, FL + dz), METAL, laturi=12))
			piese.append(cilindru("Cap butoi", 0.06, 0.06, 0.04, (bx, by, FL + 0.6), METAL_INCHIS, laturi=8))
			_cutie_coliziune(col, (0.44, 0.44, 0.6), (bx, by, FL + 0.3))
	for k, (lx, ly) in enumerate(((5.6, Y0 + 0.45), (5.6, Y0 + 0.45), (6.2, Y0 + 0.5))):
		z0 = FL + (0.3 if k == 1 else 0.0)
		piese.append(cub("Lada sticle", (0.5, 0.36, 0.28), (lx, ly, z0 + 0.14), r.choice((ROSU, PETROL))))
		for i in range(4):
			for j in range(3):
				piese.append(cilindru("Gat sticla", 0.022, 0.012, 0.1, (lx - 0.18 + i * 0.12, ly - 0.11 + j * 0.11, z0 + 0.32), VERDE_NEGRU, laturi=6))
	_cutie_coliziune(col, (1.2, 0.45, 0.6), (5.9, Y0 + 0.47, FL + 0.3))
	for k in range(5):
		sx, sy = 6.3 + r.uniform(-0.3, 0.3), Y0 + 1.6 + k * 0.45 + r.uniform(-0.1, 0.1)
		piese.append(sfera("Sac gunoi", 0.3, (sx, sy, FL + 0.24), NEGRU, scara=(1.0, 0.9, 0.85), segmente=8, inele=5))
		piese.append(cilindru("Nod sac", 0.04, 0.02, 0.12, (sx, sy, FL + 0.52), NEGRU, laturi=6))
	_cutie_coliziune(col, (0.8, 2.5, 0.5), (6.3, Y0 + 2.5, FL + 0.25))
	# scaunul de bar rupt, culcat (picior lipsă), aruncat lângă saci
	sx, sy = 4.9, Y0 + 2.9
	piese.append(cilindru("Sezut rupt", 0.19, 0.19, 0.07, (sx, sy, FL + 0.19), ROSU, laturi=10, rot=(1.5708, 0, 0.6)))
	for k in range(3):
		a = 0.6 + k * 0.5
		piese.append(os_intre("Picior scaun", (sx + 0.05 * math.cos(a), sy + 0.05 * math.sin(a), FL + 0.19),
			(sx + 0.7 * math.cos(0.6 + math.pi / 2) + 0.1 * k, sy + 0.7 * math.sin(0.6 + math.pi / 2) - 0.05 * k, FL + 0.03 + 0.06 * k), 0.016, METAL))
	strange()

	# --- copacul uscat din colțul din stânga-spate: trunchiul strâmb, crengi goale, rădăcini
	tx, ty = -5.6, Y1 - 1.3
	piese.append(trunchi("Trunchi copac", [((tx, ty, FL - 0.05), 0.24, 0.22), ((tx + 0.05, ty, FL + 0.8), 0.17, 0.16),
		((tx + 0.25, ty - 0.1, FL + 1.8), 0.13, 0.12), ((tx + 0.1, ty - 0.2, FL + 2.8), 0.09, 0.08), ((tx + 0.3, ty - 0.3, FL + 3.6), 0.0, 0.0)],
		LEMN_INCHIS, laturi=7))
	_cutie_coliziune(col, (0.45, 0.45, 3.0), (tx, ty, FL + 1.5))

	def creanga(a, dir, lung, gros, nivel):
		b = Vector(a) + Vector(dir).normalized() * lung
		piese.append(os_intre("Creanga", a, tuple(b), gros, LEMN_INCHIS, laturi=5))
		if nivel > 0:
			for s in (-1, 1):
				d2 = Vector(dir).normalized()
				d2 = Vector((d2.x * math.cos(0.6 * s) - d2.y * math.sin(0.6 * s), d2.x * math.sin(0.6 * s) + d2.y * math.cos(0.6 * s), d2.z + 0.35))
				creanga(tuple(b), tuple(d2), lung * 0.6, gros * 0.6, nivel - 1)

	for (h, d) in ((1.6, (1.0, -0.6, 0.6)), (2.2, (-0.8, -0.4, 0.7)), (2.7, (0.5, 0.9, 0.5)), (3.1, (-0.4, -1.0, 0.8))):
		creanga((tx + 0.15, ty - 0.12, FL + h), d, 0.9, 0.05, 2)
	for k in range(5):
		a = k / 5.0 * math.tau + 0.3
		piese.append(os_intre("Radacina", (tx, ty, FL + 0.15), (tx + 0.6 * math.cos(a), ty + 0.6 * math.sin(a), FL - 0.02), 0.06, LEMN_INCHIS, laturi=5))
	strange()

	# --- plăcuța de carton prinsă pe un țăruș lângă piatră: „Ancient Curse - DO NOT TOUCH OR REMOVE” (owner, 11.10)
	px, py = PIATRA[0] + 1.35, PIATRA[1] - 1.1
	piese.append(os_intre("Tarus", (px, py, FL - 0.05), (px, py, FL + 1.0), 0.02, LEMN_DESCHIS, laturi=5))
	# cartonul e întors spre ușă (fața spre -Y, rotit 0,35 rad); scrisul stă la 1,4 cm în fața lui, pe normală
	nx, ny = math.sin(0.35), -math.cos(0.35)
	cx, cy = px + nx * 0.03, py + ny * 0.03
	piese.append(cub("Carton", (0.56, 0.012, 0.38), (cx, cy, FL + 0.88), AUR, rot=(0, 0, 0.35)))
	piese.append(_text_o_fata("Scris carton", "Ancient Curse\nDO NOT TOUCH\nOR REMOVE", (cx + nx * 0.014, cy + ny * 0.014, FL + 0.88), 0.05, NEGRU,
		rot=(1.5708, 0, 0.35)))
	_cutie_coliziune(col, (0.12, 0.12, 1.0), (px, py, FL + 0.5))
	strange()

	uneste(piese, "Curte")
	uneste(lumini, "Lumini")
	uneste(col, "Coliziune")
	exporta(os.path.join(cale, "bar_curte.glb"))


def piatra(cale):
	"""Piatra veche din mijlocul curții: un bolovan colțuros (icosferă cu zgomot), cu vârful teșit în care e fanta
	sabiei; crăpăturile pornesc din fantă pe vârf și pe coaste (`Crapaturi`, piesă separată: în joc se aprind verde cât
	tragi), mușchiul de pe coaste (`Muschi`), pietricelele din jur. Originea = mijlocul bazei, pe sol (z = 0); fanta
	sabiei e în (0, 0, VARF)."""
	curata()
	r = random.Random(7)
	VARF = 0.86
	bm = bmesh.new()
	bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
	for v in bm.verts:
		d = v.co.normalized()
		zg = 1.0 + 0.11 * math.sin(d.x * 5.1 + 1.3) * math.cos(d.y * 4.3) + 0.07 * math.sin(d.z * 7.7 + d.x * 3.0) + r.uniform(-0.035, 0.035)
		v.co = Vector((d.x * 0.82 * zg, d.y * 0.68 * zg, d.z * 0.62 * zg + 0.38))
		if v.co.z > VARF:
			v.co.z = VARF + (v.co.z - VARF) * 0.08  # vârful teșit, aproape plat
		if v.co.z < 0.0:
			v.co.z = -0.05
	me = bpy.data.meshes.new("Piatra")
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new("Piatra", me)
	bpy.context.scene.collection.objects.link(ob)
	_coloreaza(ob, BETON)
	piese = [ob]
	# fanta sabiei (neagră, puțin deasupra vârfului) și buza ciobită din jurul ei
	piese.append(cub("Fanta", (0.075, 0.016, 0.02), (0, 0, VARF + 0.012), NEGRU))
	for k in range(7):
		a = k / 7.0 * math.tau
		piese.append(cub("Ciob", (0.05, 0.03, 0.02), (0.07 * math.cos(a), 0.05 * math.sin(a), VARF + 0.006), METAL_INCHIS, rot=(0, 0, a)))
	# pietricelele din jur
	for k in range(14):
		a = r.uniform(0, math.tau)
		rr = r.uniform(0.95, 1.5)
		piese.append(sfera("Pietricica", r.uniform(0.05, 0.13), (rr * math.cos(a), rr * math.sin(a), 0.0), r.choice((BETON, METAL, GRI_ALBASTRU)),
			scara=(1.0, 0.8, 0.55), segmente=6, inele=4))
	baza = uneste(piese, "Piatra")

	# mușchiul: pete turtite, lipite de coaste (pe normala suprafeței, ies 1,5 cm)
	muschi = []
	for k in range(16):
		a = r.uniform(0, math.tau)
		z = r.uniform(0.15, 0.7)
		hit, loc, nor, _ = baza.ray_cast(Vector((math.cos(a) * 3, math.sin(a) * 3, z)), Vector((-math.cos(a), -math.sin(a), 0)))
		if not hit:
			continue
		s = sfera("Muschi", r.uniform(0.08, 0.15), (0, 0, 0), r.choice((VERDE, POSTAV, MASLINIU)), scara=(1.0, 1.0, 0.18), segmente=6, inele=4)
		_aseaza(s, Vector((0, 0, 1)).rotation_difference(nor).to_euler(), loc + nor * 0.012)
		muschi.append(s)
	ob_muschi = uneste(muschi, "Muschi")

	# crăpăturile: din fantă spre margini pe vârf, apoi în jos pe coaste (urmate cu raze, ca să stea lipite)
	crap = []
	for k in range(6):
		a = k / 6.0 * math.tau + r.uniform(-0.25, 0.25)
		puncte = []
		for i in range(r.randint(4, 7)):
			rr = 0.06 + i * 0.09
			aa = a + r.uniform(-0.18, 0.18)
			de_la = Vector((rr * math.cos(aa), rr * math.sin(aa), 2.0))
			hit, loc, nor, _ = baza.ray_cast(de_la, Vector((0, 0, -1)))
			if not hit:
				break
			puncte.append((loc + nor * 0.012, nor))
		for (p0, n0), (p1, _n1) in zip(puncte, puncte[1:]):
			d = p1 - p0
			c = cub("Crapatura", (0.011, d.length + 0.01, 0.008), (0, 0, 0), NEGRU)
			_aseaza(c, Vector((0, 1, 0)).rotation_difference(d.normalized()).to_euler(), (p0 + p1) / 2)
			crap.append(c)
	ob_crap = uneste(crap, "Crapaturi")
	_parinte(ob_muschi, baza)
	_parinte(ob_crap, baza)
	exporta(os.path.join(cale, "piatra_sabie.glb"))


# Sabia: lungimile (metri, de-a lungul lui Y; originea = mijlocul mânerului)
MANER = 0.11          # jumătate din mâner
GARDA = 0.13          # garda (de la MANER la GARDA)
VARF_LAMA = 1.0       # vârful lamei


def sabie(cale):
	"""Sabia blestemată: o spadă lungă de oțel înnegrit (lama în romb), gravată cu rune pe ambele fețe; garda de fier
	cu brațele îndoite spre lamă ca niște coarne și un craniu de os în mijloc (pe ambele fețe); mânerul înfășurat în
	piele neagră cu sârmă de alamă; pomelul cu gheare care țin o gemă. `Rune` (runele, ochii craniului, gema) e piesă
	separată: în joc strălucește verde (sabie_blestemata.gd). Originea = mijlocul mânerului; lama spre +Y (în Godot spre
	-Z, ca restul armelor), lățimea pe Z, grosimea pe X."""
	curata()
	# lama: romb (grosime pe X, lățime pe Z), lată la gardă, se îngustează, apoi vârful
	inele = []
	for k in range(8):
		y = GARDA + 0.005 + k * 0.1
		u = k / 7.0
		inele.append(((0, y, 0), 0.0075 - 0.002 * u, 0.034 - 0.009 * u))
	inele.append(((0, VARF_LAMA - 0.1, 0), 0.0052, 0.022))
	inele.append(((0, VARF_LAMA - 0.04, 0), 0.0035, 0.012))
	inele.append(((0, VARF_LAMA, 0), 0.0, 0.0))
	piese = [trunchi("Lama", inele, NEGRU, laturi=4, ref=(1, 0, 0))]
	# tăișurile (benzi de oțel deschis pe muchii)
	for s in (-1, 1):
		puncte = []
		for k in range(8):
			y = GARDA + 0.01 + k * 0.1
			u = k / 7.0
			puncte.append(((0, y, s * (0.034 - 0.009 * u - 0.002)), 0.0022, 0.004))
		puncte.append(((0, VARF_LAMA - 0.1, s * 0.02), 0.0018, 0.0035))
		puncte.append(((0, VARF_LAMA - 0.035, s * 0.008), 0.0, 0.0))
		piese.append(trunchi("Tais", puncte, CROM, laturi=4, ref=(1, 0, 0)))
	# ricasso: bucata groasă de lângă gardă, cu doi colți mici
	piese.append(cub("Ricasso", (0.02, 0.06, 0.07), (0, GARDA + 0.03, 0), METAL_INCHIS))
	for s in (-1, 1):
		piese.append(os_intre("Colt ricasso", (0, GARDA + 0.05, s * 0.034), (0, GARDA + 0.085, s * 0.05), 0.006, METAL_INCHIS, laturi=4))

	# garda: bara de fier, brațele îndoite spre lamă (coarnele), craniul din mijloc
	gy = (MANER + GARDA) / 2
	piese.append(cub("Garda", (0.036, 0.028, 0.15), (0, gy, 0), METAL_INCHIS))
	for s in (-1, 1):
		piese.append(trunchi("Corn garda", [((0, gy, s * 0.07), 0.016, 0.014), ((0, GARDA, s * 0.12), 0.013, 0.011),
			((0, GARDA + 0.05, s * 0.15), 0.009, 0.008), ((0, GARDA + 0.11, s * 0.145), 0.004, 0.004), ((0, GARDA + 0.15, s * 0.13), 0.0, 0.0)],
			METAL_INCHIS, laturi=6, ref=(1, 0, 0)))
	for sx in (-1, 1):  # craniul, câte unul pe fiecare față a gărzii
		cx = sx * 0.027
		piese.append(sfera("Craniu", 0.024, (cx, gy + 0.004, 0), OS, scara=(0.7, 1.05, 0.95), segmente=8, inele=6))
		piese.append(cub("Falca", (0.012, 0.016, 0.026), (cx, gy - 0.021, 0), OS))
		for dz in (-0.009, 0.0, 0.009):
			piese.append(cub("Dinte", (0.004, 0.006, 0.005), (cx + sx * 0.006, gy - 0.026, dz), NEGRU))
		for dz in (-0.009, 0.009):
			piese.append(sfera("Orbita", 0.0075, (cx + sx * 0.012, gy + 0.008, dz), NEGRU, segmente=6, inele=4))
		piese.append(cub("Nas craniu", (0.004, 0.006, 0.005), (cx + sx * 0.016, gy - 0.006, 0), NEGRU))

	# mânerul: pielea neagră, sârma de alamă în spirală, inelele de la capete
	piese.append(cilindru("Maner", 0.0155, 0.0155, 2 * MANER, (0, 0, 0), NEGRU, laturi=8, rot=(-1.5708, 0, 0)))
	for k in range(9):
		y = -MANER + 0.015 + k * 0.024
		piese.append(cub("Sarma", (0.034, 0.004, 0.006), (0, y, 0), BRONZ, rot=(0, 0.6, 0)))
		piese.append(cub("Sarma", (0.006, 0.004, 0.034), (0, y + 0.012, 0), BRONZ, rot=(0, 0.6, 0)))
	for y in (-MANER, MANER - 0.004):
		piese.append(cilindru("Inel maner", 0.019, 0.019, 0.012, (0, y, 0), METAL_INCHIS, laturi=8, rot=(-1.5708, 0, 0)))
	# pomelul: o cupă de fier cu patru gheare care strâng gema, și un țep la capăt
	py = -MANER - 0.03
	piese.append(trunchi("Pomel", [((0, -MANER - 0.005, 0), 0.016, 0.016), ((0, py, 0), 0.026, 0.026), ((0, py - 0.018, 0), 0.016, 0.016)],
		METAL_INCHIS, laturi=8, ref=(1, 0, 0)))
	for k in range(4):
		a = k * math.pi / 2 + math.pi / 4
		piese.append(trunchi("Gheara", [((0.022 * math.cos(a), py, 0.022 * math.sin(a)), 0.005, 0.005),
			((0.026 * math.cos(a), py - 0.025, 0.026 * math.sin(a)), 0.004, 0.004), ((0.012 * math.cos(a), py - 0.045, 0.012 * math.sin(a)), 0.0, 0.0)],
			METAL_INCHIS, laturi=4, ref=(0, 0, 1)))
	piese.append(cilindru("Tep pomel", 0.008, 0.0, 0.035, (0, py - 0.065, 0), METAL_INCHIS, laturi=6, rot=(1.5708, 0, 0)))
	ob = uneste(piese, "Sabie")

	# ce strălucește: gema din pomel, ochii craniului, runele de pe ambele fețe ale lamei
	rune = [sfera("Gema", 0.019, (0, py - 0.028, 0), VERDE, segmente=8, inele=6)]
	for sx in (-1, 1):
		cx = sx * 0.027
		for dz in (-0.009, 0.009):
			rune.append(sfera("Ochi craniu", 0.0042, (cx + sx * 0.0175, gy + 0.008, dz), VERDE, segmente=6, inele=4))
	r = random.Random(13)
	for sx in (-1, 1):
		y = GARDA + 0.11
		while y < VARF_LAMA - 0.17:
			u = (y - GARDA) / (VARF_LAMA - GARDA)
			x = sx * (0.0075 - 0.002 * u + 0.0012)
			# o rună = un băț pe lungimea lamei, cu 1-2 bețe oblice
			rune.append(cub("Runa", (0.0015, 0.028, 0.0035), (x, y, 0), VERDE))
			for _ in range(r.randint(1, 2)):
				dy = r.uniform(-0.009, 0.009)
				rune.append(cub("Runa", (0.0015, 0.014, 0.003), (x, y + dy, r.choice((-1, 1)) * 0.005), VERDE, rot=(r.choice((-0.8, 0.8)), 0, 0)))
			y += 0.05
	ob_rune = uneste(rune, "Rune")
	_parinte(ob_rune, ob)
	exporta(os.path.join(cale, "sabie_blestemata.glb"))


def pumn(cale):
	"""Mâna ta dreaptă strânsă pe un mâner vertical (cât tragi de sabia din piatră): mânerul e pe axa Z, prin origine
	(raza 1,6 cm); dosul palmei e spre tine (-Y), degetele se strâng pe după mâner (prin +Y) și vin înapoi pe stânga,
	degetul mare peste arătător. Încheietura, antebrațul și mâneca neagră vin spre tine (-Y), spre umăr (+X) și puțin
	în jos. Mâna stângă = aceeași, oglindită pe X (în joc, scara -1)."""
	curata()
	piele, umbra = p("a56850"), p("904a40")
	R = 0.016 + 0.0095   # raza pe care merg degetele (mâner + jumătate de deget)
	piese = []
	# degetele: arătătorul sus, degetul mic jos (mai subțire și mai scurt)
	for k, z in enumerate((0.027, 0.008, -0.011, -0.029)):
		gros = (0.0098, 0.0102, 0.0096, 0.0085)[k]
		capat = 245.0 - (15.0 if k == 3 else 0.0)
		puncte = []
		for i in range(8):
			a = math.radians(-55 + i * capat / 7.0)  # din dreapta-față, pe după mâner, până în stânga-față
			puncte.append(((R * math.cos(a), R * math.sin(a), z), gros, gros * 0.9))
		piese.append(trunchi("Deget", puncte, piele, laturi=6, ref=(0, 0, 1)))
		a0 = math.radians(-55)
		piese.append(sfera("Incheietura deget", gros * 1.15, (R * math.cos(a0), R * math.sin(a0), z), piele, segmente=6, inele=4))
		a = math.radians(-55 + capat)
		piese.append(cub("Unghie", (0.009, 0.004, 0.009), ((R + 0.006) * math.cos(a), (R + 0.006) * math.sin(a), z), umbra, rot=(0, 0, a)))
	# dosul palmei: de la încheieturile degetelor (dreapta-față a mânerului) spre încheietura mâinii
	piese.append(trunchi("Palma", [((0.02, -0.022, -0.001), 0.031, 0.012), ((0.035, -0.05, -0.006), 0.033, 0.015),
		((0.045, -0.085, -0.004), 0.027, 0.016)], piele, laturi=8, ref=(0, 0, 1)))
	# degetul mare: din podul palmei, peste arătător, până în stânga-față
	piese.append(trunchi("Deget mare", [((0.03, -0.045, 0.03), 0.012, 0.011), ((0.008, -0.03, 0.042), 0.011, 0.01),
		((-0.014, -0.024, 0.04), 0.0095, 0.009), ((-0.026, -0.01, 0.037), 0.008, 0.008)], piele, laturi=6, ref=(0, 0, 1)))
	# antebrațul și mâneca: spre tine (-Y), spre umăr (+X) și puțin în jos: umerii sunt sub ochi, deci brațele
	# intră în cadru din colțurile de jos (urcate spre cameră, mânecile acopereau tot ecranul)
	piese.append(trunchi("Antebrat", [((0.045, -0.08, -0.004), 0.026, 0.02), ((0.099, -0.215, -0.03), 0.032, 0.026),
		((0.142, -0.323, -0.05), 0.036, 0.03)], piele, laturi=8, ref=(0, 0, 1)))
	piese.append(trunchi("Manseta", [((0.0665, -0.134, -0.012), 0.036, 0.03), ((0.073, -0.15, -0.016), 0.036, 0.03)], LEMN, laturi=8, ref=(0, 0, 1)))
	piese.append(trunchi("Maneca", [((0.071, -0.145, -0.015), 0.04, 0.034), ((0.12, -0.269, -0.04), 0.048, 0.04), ((0.185, -0.431, -0.075), 0.056, 0.048),
		((0.26, -0.62, -0.115), 0.062, 0.054), ((0.325, -0.782, -0.15), 0.066, 0.058)], NEGRU, laturi=8, ref=(0, 0, 1)))
	uneste(piese, "Pumn")
	exporta(os.path.join(cale, "pumn_jucator.glb"))


def toate(cale):
	curte(cale)
	piatra(cale)
	sabie(cale)
	pumn(cale)


if __name__ == "__main__":
	cale_modele = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")
	if "--" in sys.argv:
		for nume in sys.argv[sys.argv.index("--") + 1:]:
			globals()[nume](cale_modele)
	else:
		toate(cale_modele)
