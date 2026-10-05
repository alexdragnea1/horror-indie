# Casa lui Lexy (vizavi de stația de autobuz, cu cimitirul peste drum), ce e în ea și Lexy.
# Le apelează modele.py, dar merge și singur (mai repede, doar astea):
#   blender --background --factory-startup --python tools/blender/lexy.py
# Axe Blender: Z în sus, fața modelului spre -Y (în Godot devine +Z). Originea = la sol.
# Casa, bucătăria și decorul din living sunt în coordonatele casei (originea = mijlocul fațadei, la sol):
# în Godot le pui pe toate în același punct. Mobila care se mișcă sau cu care faci ceva are originea ei.
import math
import os
import random
import sys

import bmesh
import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, inel, text, uneste, exporta, trunchi, _coloreaza  # noqa: E402

NEGRU = p("262d2f")
ALB = p("83b3b0")
SIDING = p("5e5356")
TRIM = NEGRU
ACOPERIS = p("2a3c3d")
FUNDATIE = p("70706e")
LEMN = p("5e363e")
LEMN_INCHIS = p("48313b")
GEAM = p("2a3c3d")
PIATRA = p("6f6d7f")
PIATRA_DESCHISA = p("7e8d87")
MUSCHI = p("5b6d4e")
PAMANT = p("48313b")
PERETE_LIVING = p("553e4d")
PERETE_BUCATARIE = p("83b3b0")
PERETE_HOL = p("445d46")
TAVAN = p("70706e")

FL = 0.45   # podeaua casei (deasupra solului: verandă cu trepte)
H = 2.7     # înălțimea camerelor
D = 7.6     # adâncimea casei (spre +Y)
L = 7.0     # jumătate din lățimea casei
T = 0.1     # grosimea unui strat de perete (siding afară + vopsea înăuntru = 0,2)
W = FL + H + 0.1  # vârful pereților exteriori
LAT_USA = 1.0
# ferestrele: (de la, până la) pe peretele lor, și înălțimea (de la podea)
FER_Z = (FL + 0.8, FL + 2.2)
FER_FATA = [(2.4, 3.4), (4.8, 5.8), (-3.4, -2.4), (-5.8, -4.8)]
FER_LATERAL = (3.0, 4.2)  # pe Y, pe ambii pereți laterali
FER_SPATE = (3.5, 4.7)    # pe X, doar în living
FER_Z_BUC = (FL + 1.08, FL + 2.2)  # fereastra laterală din bucătărie e mai sus (sub ea e blatul)
GOL_CAMERE = (1.2, 3.8)   # golurile dintre hol și camere (pe Y)
HOL_X = 1.4               # holul e între -1,4 și 1,4
PERETE_HOL_Y = 5.4        # peretele din fundul holului (cu ușa spre dormitoare)


# ---------------------------------------------------------------------------------------------------------------
# Unelte pentru casă
# ---------------------------------------------------------------------------------------------------------------

def perete(piese, nume, axa, a0, a1, g0, g1, z0, z1, culoare, goluri=()):
	"""Perete drept din cutii, cu goluri dreptunghiulare (uși, ferestre).
	axa "x": se întinde pe X de la a0 la a1, grosimea pe Y între g0 și g1; axa "y": invers.
	goluri = [(a, b, za, zb)], pe aceeași axă ca a0..a1."""
	taieturi = sorted({a0, a1, *[v for g in goluri for v in g[:2] if a0 < v < a1]})
	for u, v in zip(taieturi, taieturi[1:]):
		m = (u + v) / 2
		acoperite = sorted((g[2], g[3]) for g in goluri if g[0] <= m <= g[1])
		z = z0
		bucati = []
		for za, zb in acoperite:
			if za > z:
				bucati.append((z, za))
			z = max(z, zb)
		if z < z1:
			bucati.append((z, z1))
		for za, zb in bucati:
			if zb - za < 0.005:
				continue
			if axa == "x":
				piese.append(cub(nume, (v - u, g1 - g0, zb - za), ((u + v) / 2, (g0 + g1) / 2, (za + zb) / 2), culoare))
			else:
				piese.append(cub(nume, (g1 - g0, v - u, zb - za), ((g0 + g1) / 2, (u + v) / 2, (za + zb) / 2), culoare))


def prisma(nume, puncte, plan, a0, a1, culoare):
	"""Poligon (convex, în ordine) extrudat: plan "yz" = punctele sunt (y, z), extrudat pe X de la a0 la a1;
	plan "xz" = (x, z), extrudat pe Y. Frontoane, acoperișuri în pantă, arcade."""
	bm = bmesh.new()
	def v3(pt, a):
		return (a, pt[0], pt[1]) if plan == "yz" else (pt[0], a, pt[1])
	jos = [bm.verts.new(v3(pt, a0)) for pt in puncte]
	sus = [bm.verts.new(v3(pt, a1)) for pt in puncte]
	bm.faces.new(jos)
	bm.faces.new(list(reversed(sus)))
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


def _copii(piese, nume):
	"""Copii ale pieselor ale căror nume (fără .001) e în `nume`: din ele se face obiectul `Coliziune`
	(forma simplă pe care o folosește Godot pentru coliziune, vezi ColiziuneModel.plasa; nu se vede)."""
	copii = []
	for ob in piese:
		if ob.name.split(".")[0] in nume:
			c = ob.copy()
			c.data = ob.data.copy()
			bpy.context.scene.collection.objects.link(c)
			copii.append(c)
	return copii


def _fereastra_fata(piese, geamuri, x0, x1, z0, z1, y_fata, spre, obloane=True):
	"""Fereastra dintr-un perete pe X (golul e deja făcut): rama și pervazul pe fața de afară (`y_fata`,
	afară e spre `spre` = -1 sau +1), geamul la mijlocul peretelui, crucea ramei, obloanele negre."""
	yr = y_fata + spre * 0.02
	cx = (x0 + x1) / 2
	piese += [
		cub("Rama", (x1 - x0 + 0.2, 0.04, 0.1), (cx, yr, z1 + 0.05), TRIM),
		cub("Rama", (0.1, 0.04, z1 - z0), (x0 - 0.05, yr, (z0 + z1) / 2), TRIM),
		cub("Rama", (0.1, 0.04, z1 - z0), (x1 + 0.05, yr, (z0 + z1) / 2), TRIM),
		cub("Pervaz", (x1 - x0 + 0.26, 0.12, 0.05), (cx, y_fata + spre * 0.06, z0 - 0.025), TRIM),
		# cornișa gotică de deasupra: un mic fronton
		prisma("Fronton fereastra", [(x0 - 0.12, z1 + 0.1), (x1 + 0.12, z1 + 0.1), (cx, z1 + 0.32)], "xz",
			y_fata + spre * 0.005, y_fata + spre * 0.045, TRIM),
	]
	ym = y_fata - spre * T  # mijlocul peretelui (siding + vopsea)
	geamuri.append(cub("Geam", (x1 - x0, 0.012, z1 - z0), (cx, ym, (z0 + z1) / 2), GEAM))
	piese += [
		cub("Cruce", (0.04, 0.05, z1 - z0), (cx, ym, (z0 + z1) / 2), TRIM),
		cub("Cruce", (x1 - x0, 0.034, 0.04), (cx, ym, z0 + (z1 - z0) * 0.62), TRIM),
	]
	if obloane:
		for s, x in ((-1, x0 - 0.1), (1, x1 + 0.1)):
			xo = x + s * 0.2
			piese.append(cub("Oblon", (0.36, 0.035, z1 - z0 + 0.05), (xo, y_fata + spre * 0.03, (z0 + z1) / 2), NEGRU))
			for k in range(6):
				z = z0 + 0.15 + k * (z1 - z0 - 0.3) / 5
				piese.append(cub("Lamela", (0.3, 0.012, 0.03), (xo, y_fata + spre * 0.054, z), p("2a3c3d")))


def _fereastra_lateral(piese, geamuri, y0, y1, z0, z1, x_fata, spre):
	"""Ca _fereastra_fata, pentru un perete pe Y (afară e spre `spre` pe X)."""
	xr = x_fata + spre * 0.02
	cy = (y0 + y1) / 2
	piese += [
		cub("Rama", (0.04, y1 - y0 + 0.2, 0.1), (xr, cy, z1 + 0.05), TRIM),
		cub("Rama", (0.04, 0.1, z1 - z0), (xr, y0 - 0.05, (z0 + z1) / 2), TRIM),
		cub("Rama", (0.04, 0.1, z1 - z0), (xr, y1 + 0.05, (z0 + z1) / 2), TRIM),
		cub("Pervaz", (0.12, y1 - y0 + 0.26, 0.05), (x_fata + spre * 0.06, cy, z0 - 0.025), TRIM),
		prisma("Fronton fereastra", [(y0 - 0.12, z1 + 0.1), (y1 + 0.12, z1 + 0.1), (cy, z1 + 0.32)], "yz",
			x_fata + spre * 0.005, x_fata + spre * 0.045, TRIM),
	]
	xm = x_fata - spre * T
	geamuri.append(cub("Geam", (0.012, y1 - y0, z1 - z0), (xm, cy, (z0 + z1) / 2), GEAM))
	piese += [
		cub("Cruce", (0.05, 0.04, z1 - z0), (xm, cy, (z0 + z1) / 2), TRIM),
		cub("Cruce", (0.034, y1 - y0, 0.04), (xm, cy, z0 + (z1 - z0) * 0.62), TRIM),
	]


def _dovleac(piese, x, y, z, raza, r, scobit=False):
	"""Dovleac de toamnă (cu coaste), cu codiță; `scobit` = cu fața tăiată (Halloween)."""
	portocaliu = p("904a40")
	for k in range(6):
		u = k * math.tau / 6
		piese.append(sfera("Dovleac", raza * 0.62, (x + math.cos(u) * raza * 0.38, y + math.sin(u) * raza * 0.38, z + raza * 0.7),
			portocaliu if k % 2 else p("a56850"), scara=(1, 1, 1.15), segmente=8, inele=5))
	piese.append(os_intre("Codita", (x, y, z + raza * 1.3), (x + 0.02, y + 0.01, z + raza * 1.55), raza * 0.12, p("5b6d4e"), laturi=5))
	if scobit:
		ff = y - raza * 0.98
		piese += [
			prisma("Ochi dovleac", [(x - 0.07 * raza * 5, z + raza * 0.85), (x - 0.02 * raza * 5, z + raza * 0.85),
				(x - 0.045 * raza * 5, z + raza * 1.05)], "xz", ff - 0.01, ff + 0.02, NEGRU),
			prisma("Ochi dovleac", [(x + 0.02 * raza * 5, z + raza * 0.85), (x + 0.07 * raza * 5, z + raza * 0.85),
				(x + 0.045 * raza * 5, z + raza * 1.05)], "xz", ff - 0.01, ff + 0.02, NEGRU),
			cub("Gura dovleac", (raza * 0.9, 0.03, raza * 0.18), (x, ff + 0.005, z + raza * 0.55), NEGRU),
		]


# ---------------------------------------------------------------------------------------------------------------
# Casa
# ---------------------------------------------------------------------------------------------------------------

def casa_lexy(cale):
	"""Casă americană cu un etaj, puțin gotică: siding gri-mov, ornamente negre, acoperiș abrupt de ardezie, un fronton
	ascuțit deasupra intrării (cu fereastră gotică și vârf de fier), verandă cu stâlpi strunjiți, balustradă,
	felinar, dovleci pe trepte, coș de fum din cărămidă. Înăuntru: holul la mijloc, livingul în dreapta (când intri,
	+X), bucătăria în stânga (-X); în fundul holului o ușă închisă spre dormitoare.
	Piese: `Casa`, `Geamuri` (sticla, `sticla = "Geam"` în Godot), `Lumini` (felinarul, strălucește).
	Ușa de la intrare e în usa_lexy.glb (golul ei: x -0,5..0,5)."""
	curata()
	r = random.Random(1313)
	piese, geamuri, lumini = [], [], []
	usa = (-LAT_USA / 2, LAT_USA / 2, FL, FL + 2.2)
	fer_fata = [(a, b, FER_Z[0], FER_Z[1]) for a, b in FER_FATA]

	# --- fundația și podelele (pe camere)
	piese.append(cub("Fundatie", (2 * L - 2 * T, D - 2 * T, FL - 0.05), (0, D / 2, (FL - 0.05) / 2), FUNDATIE))
	for (x0, x1), cul in (((-HOL_X, HOL_X), LEMN), ((HOL_X, L - T), LEMN_INCHIS), ((-L + T, -HOL_X), p("70706e"))):
		piese.append(cub("Podea", (x1 - x0, D - 2 * T, 0.05), ((x0 + x1) / 2, D / 2, FL - 0.025), cul))

	# --- pereții de afară (siding): fața, spatele, lateralele
	perete(piese, "Siding", "x", -L, L, 0, T, 0, W, SIDING, [usa] + fer_fata)
	perete(piese, "Siding", "x", -L, L, D - T, D, 0, W, SIDING, [(FER_SPATE[0], FER_SPATE[1], *FER_Z)])
	for x0, fz_ in ((-L, FER_Z_BUC), (L - T, FER_Z)):
		perete(piese, "Siding", "y", T, D - T, x0, x0 + T, 0, W, SIDING, [(*FER_LATERAL, *fz_)])
	# scândurile sidingului: dungi orizontale (ies 1 cm) pe fațadă, ocolind ușa, ferestrele cu obloane și veranda
	blocate = [(-0.65, 0.65, 0.0, FL + 2.8)] + [(a - 0.55, b + 0.55, FER_Z[0] - 0.1, FER_Z[1] + 0.4) for a, b in FER_FATA]
	for k in range(14):
		z = 0.62 + k * 0.19
		if z > W - 0.08:
			break
		if 2.9 < z < 3.2:
			continue  # acoperișul verandei
		x = -L
		for a, b, za, zb in sorted(g for g in blocate if g[2] < z < g[3]) + [(L, L, 0, 0)]:
			if a - x > 0.1:
				piese.append(cub("Scandura", (a - x, 0.012, 0.025), ((a + x) / 2, -0.006, z), p("553e4d")))
			x = max(x, b)
	# soclul de piatră (în față doar pe lângă verandă)
	for a, b in ((-L - 0.03, -3.5), (3.5, L + 0.03)):
		piese.append(cub("Soclu", (b - a, 0.03, FL - 0.03), ((a + b) / 2, -0.015, (FL - 0.03) / 2), FUNDATIE))
	piese.append(cub("Soclu", (2 * L + 0.06, 0.03, FL - 0.03), (0, D + 0.015, (FL - 0.03) / 2), FUNDATIE))
	for s in (-1, 1):
		piese.append(cub("Soclu", (0.03, D, FL - 0.03), (s * (L + 0.015), D / 2, (FL - 0.03) / 2), FUNDATIE))
	# colțarele negre
	for x in (-L, L):
		for y in (0, D):
			piese.append(cub("Coltar", (0.08, 0.08, W - FL), (x + (0.025 if x < 0 else -0.025), y + (0.025 if y > 0 else -0.025),
				FL + (W - FL) / 2), TRIM))

	# --- pereții dinăuntru (vopsea), pe camere
	camere = [((-HOL_X, HOL_X), PERETE_HOL), ((HOL_X, L - T), PERETE_LIVING), ((-L + T, -HOL_X), PERETE_BUCATARIE)]
	for (x0, x1), cul in camere:
		perete(piese, "Perete", "x", x0, x1, T, 2 * T, FL, FL + H, cul, [usa] + fer_fata)
		perete(piese, "Perete", "x", x0, x1, D - 2 * T, D - T, FL, FL + H, cul, [(FER_SPATE[0], FER_SPATE[1], *FER_Z)])
	perete(piese, "Perete", "y", 2 * T, D - 2 * T, L - 2 * T, L - T, FL, FL + H, PERETE_LIVING, [(*FER_LATERAL, *FER_Z)])
	perete(piese, "Perete", "y", 2 * T, D - 2 * T, -L + T, -L + 2 * T, FL, FL + H, PERETE_BUCATARIE, [(*FER_LATERAL, *FER_Z_BUC)])
	# pereții dintre hol și camere (câte un strat din fiecare culoare), cu golurile largi
	gol = [(*GOL_CAMERE, FL, FL + 2.3)]
	perete(piese, "Perete", "y", 2 * T, D - 2 * T, HOL_X - T, HOL_X, FL, FL + H, PERETE_HOL, gol)
	perete(piese, "Perete", "y", 2 * T, D - 2 * T, HOL_X, HOL_X + T, FL, FL + H, PERETE_LIVING, gol)
	perete(piese, "Perete", "y", 2 * T, D - 2 * T, -HOL_X - T, -HOL_X, FL, FL + H, PERETE_BUCATARIE, gol)
	perete(piese, "Perete", "y", 2 * T, D - 2 * T, -HOL_X, -HOL_X + T, FL, FL + H, PERETE_HOL, gol)
	# ancadramentele golurilor (lemn închis, ies 2 cm pe ambele fețe), cu un arc ascuțit deasupra
	for xp in (HOL_X, -HOL_X):
		for s in (-1, 1):
			xf = xp + s * (T + 0.012)
			piese += [
				cub("Ancadrament", (0.024, 0.08, 2.3), (xf, GOL_CAMERE[0] - 0.04, FL + 1.15), LEMN_INCHIS),
				cub("Ancadrament", (0.024, 0.08, 2.3), (xf, GOL_CAMERE[1] + 0.04, FL + 1.15), LEMN_INCHIS),
				prisma("Arc", [(GOL_CAMERE[0] - 0.08, FL + 2.3), (GOL_CAMERE[1] + 0.08, FL + 2.3), (sum(GOL_CAMERE) / 2, FL + 2.62)],
					"yz", xf - 0.012, xf + 0.012, LEMN_INCHIS),
			]
	# peretele din fundul holului, cu ușa (închisă) spre dormitoare
	perete(piese, "Perete", "x", -HOL_X + T, HOL_X - T, PERETE_HOL_Y, PERETE_HOL_Y + 0.2, FL, FL + H, PERETE_HOL)
	yu = PERETE_HOL_Y - 0.02
	piese += [
		cub("Usa dormitor", (0.9, 0.03, 2.1), (0, yu, FL + 1.05), LEMN_INCHIS),
		cub("Panou usa", (0.6, 0.012, 0.7), (0, yu - 0.02, FL + 1.55), LEMN),
		cub("Panou usa", (0.6, 0.012, 0.7), (0, yu - 0.02, FL + 0.6), LEMN),
		sfera("Clanta", 0.03, (0.33, yu - 0.04, FL + 1.0), p("a18463"), segmente=6, inele=4),
		cub("Toc", (1.04, 0.04, 0.07), (0, yu - 0.005, FL + 2.135), NEGRU),
		cub("Toc", (0.07, 0.04, 2.17), (-0.485, yu - 0.005, FL + 1.085), NEGRU),
		cub("Toc", (0.07, 0.04, 2.17), (0.485, yu - 0.005, FL + 1.085), NEGRU),
	]
	# tavanul
	piese.append(cub("Tavan", (2 * L - 2 * T, D - 2 * T, 0.1), (0, D / 2, FL + H + 0.05), TAVAN))

	# --- ferestrele
	for a, b in FER_FATA:
		_fereastra_fata(piese, geamuri, a, b, FER_Z[0], FER_Z[1], 0.0, -1)
	_fereastra_fata(piese, geamuri, FER_SPATE[0], FER_SPATE[1], FER_Z[0], FER_Z[1], D, 1, obloane=False)
	_fereastra_lateral(piese, geamuri, FER_LATERAL[0], FER_LATERAL[1], FER_Z[0], FER_Z[1], L, 1)
	_fereastra_lateral(piese, geamuri, FER_LATERAL[0], FER_LATERAL[1], FER_Z_BUC[0], FER_Z_BUC[1], -L, -1)

	# --- intrarea: ancadrament, arc ascuțit cu vitraliu deasupra, număr, felinar
	piese += [
		cub("Ancadrament", (0.12, 0.05, 2.3), (-0.56, -0.025, FL + 1.15), TRIM),
		cub("Ancadrament", (0.12, 0.05, 2.3), (0.56, -0.025, FL + 1.15), TRIM),
		cub("Ancadrament", (1.24, 0.07, 0.1), (0, -0.035, FL + 2.25), TRIM),
		prisma("Arc intrare", [(-0.62, FL + 2.3), (0.62, FL + 2.3), (0, FL + 2.75)], "xz", -0.05, -0.0, TRIM),
		prisma("Vitraliu", [(-0.45, FL + 2.33), (0.45, FL + 2.33), (0, FL + 2.66)], "xz", -0.058, -0.048, p("7b383a")),
		cub("Placuta", (0.22, 0.02, 0.12), (0.85, -0.01, FL + 1.75), p("a18463")),
		text("Numar", "13", (0.85, -0.022, FL + 1.75), 0.09, NEGRU),
		cub("Pres", (0.9, 0.55, 0.012), (0, -0.4, FL + 0.009), p("7b383a")),
		text("Scris pres", "GO AWAY", (0, -0.4, FL + 0.018), 0.09, NEGRU, rot=(0, 0, 0)),
	]
	piese += [  # felinarul de lângă ușă (sticla strălucește: e aprins și ziua)
		cub("Brat felinar", (0.04, 0.12, 0.04), (-0.85, -0.06, FL + 2.0), NEGRU),
		cub("Felinar", (0.14, 0.14, 0.03), (-0.85, -0.16, FL + 2.08), NEGRU),
		cub("Felinar", (0.14, 0.14, 0.03), (-0.85, -0.16, FL + 1.82), NEGRU),
		cilindru("Capac felinar", 0.11, 0.0, 0.12, (-0.85, -0.16, FL + 2.155), NEGRU, laturi=4, rot=(0, 0, 0.785)),
	]
	lumini.append(cub("Sticla felinar", (0.1, 0.1, 0.22), (-0.85, -0.16, FL + 1.95), p("a18463")))

	# --- veranda: podea, trepte, stâlpi strunjiți, balustradă, acoperiș, dovleci
	piese.append(cub("Veranda", (7.0, 2.2, FL), (0, -1.1, FL / 2), p("6f6d7f")))  # la nivelul podelei: fără prag
	for k in range(14):  # scândurile verandei (rosturi)
		piese.append(cub("Rost", (0.012, 2.18, 0.012), (-3.25 + k * 0.5, -1.1, FL + 0.003), p("5e5356")))
	piese.append(cub("Treapta", (2.0, 0.3, 0.3), (0, -2.35, 0.15), p("6f6d7f")))
	piese.append(cub("Treapta", (2.0, 0.3, 0.15), (0, -2.65, 0.075), p("6f6d7f")))
	stalpi = (-3.3, -1.2, 1.2, 3.3)
	for x in stalpi:
		piese += [
			cub("Baza stalp", (0.2, 0.2, 0.12), (x, -2.0, FL + 0.06), TRIM),
			cilindru("Stalp", 0.065, 0.065, 2.4, (x, -2.0, FL + 1.32), TRIM, laturi=8),
			inel("Inel stalp", 0.07, 0.015, (x, -2.0, FL + 0.5), TRIM, segmente=8),
			inel("Inel stalp", 0.07, 0.015, (x, -2.0, FL + 2.2), TRIM, segmente=8),
			cub("Capitel", (0.2, 0.2, 0.1), (x, -2.0, FL + 2.55), TRIM),
			# consolele dantelate dintre stâlp și acoperiș
			prisma("Consola", [(x - 0.35, 3.0), (x + 0.35, 3.0), (x, 2.75)], "xz", -2.02, -1.98, TRIM),
		]
	# balustrada: între stâlpii de pe margini și spre casă (nu în dreptul treptelor)
	for a, b in ((-3.3, -1.2), (1.2, 3.3)):
		piese.append(cub("Mana curenta", (b - a, 0.07, 0.05), ((a + b) / 2, -2.0, FL + 0.85), TRIM))
		piese.append(cub("Bara jos", (b - a, 0.05, 0.04), ((a + b) / 2, -2.0, FL + 0.1), TRIM))
		n = int((b - a) / 0.15)
		for k in range(1, n):
			piese.append(cub("Baluster", (0.025, 0.025, 0.73), (a + k * (b - a) / n, -2.0, FL + 0.48), TRIM))
	for x in (-3.3, 3.3):
		piese.append(cub("Mana curenta", (0.07, 1.95, 0.05), (x, -1.02, FL + 0.85), TRIM))
		piese.append(cub("Bara jos", (0.05, 1.95, 0.04), (x, -1.02, FL + 0.1), TRIM))
		for k in range(1, 13):
			piese.append(cub("Baluster", (0.025, 0.025, 0.73), (x, -2.0 + k * 0.15, FL + 0.48), TRIM))
	piese.append(cub("Acoperis veranda", (7.4, 2.5, 0.1), (0, -1.2, 3.07), ACOPERIS, rot=(-0.06, 0, 0)))
	piese.append(cub("Grinda veranda", (7.0, 0.14, 0.18), (0, -2.0, 2.92), TRIM))
	piese.append(cub("Tavan veranda", (6.9, 2.0, 0.02), (0, -1.0, 2.99), p("5e363e")))
	# dovlecii stau pe verandă, pe lângă balustradă (nu pe trepte, pe unde urci)
	_dovleac(piese, -2.75, -1.65, FL, 0.15, r, scobit=True)
	_dovleac(piese, -2.35, -1.75, FL, 0.1, r)
	_dovleac(piese, 2.6, -0.7, FL, 0.17, r)
	# scaunul-balansoar de pe verandă (gol, se mișcă singur? nu: e doar vechi)
	bx, by = 2.5, -1.2
	piese += [
		cub("Balansoar", (0.5, 0.45, 0.04), (bx, by, FL + 0.42), LEMN_INCHIS),
		cub("Balansoar", (0.5, 0.04, 0.6), (bx, by + 0.22, FL + 0.75), LEMN_INCHIS, rot=(-0.2, 0, 0)),
		cub("Balansoar", (0.04, 0.5, 0.04), (bx - 0.24, by, FL + 0.62), LEMN_INCHIS),
		cub("Balansoar", (0.04, 0.5, 0.04), (bx + 0.24, by, FL + 0.62), LEMN_INCHIS),
	]
	for s in (-1, 1):
		piese.append(os_intre("Picior balansoar", (bx + s * 0.22, by - 0.2, FL + 0.4), (bx + s * 0.22, by - 0.15, FL + 0.03), 0.015, LEMN_INCHIS, laturi=4))
		piese.append(os_intre("Picior balansoar", (bx + s * 0.22, by + 0.2, FL + 0.4), (bx + s * 0.22, by + 0.15, FL + 0.03), 0.015, LEMN_INCHIS, laturi=4))
		piese.append(trunchi("Sanie", [((bx + s * 0.22, by - 0.32, FL + 0.08), 0.015, 0.015), ((bx + s * 0.22, by, FL + 0.02), 0.015, 0.015),
			((bx + s * 0.22, by + 0.32, FL + 0.08), 0.015, 0.015)], LEMN_INCHIS, laturi=4))

	# --- acoperișul principal: două pante de 45°, frontoanele laterale, coama
	streasina = 0.45
	pas = D / 2 + streasina
	lung = pas * math.sqrt(2)
	for s in (-1, 1):  # s = -1 panta din față
		cy = D / 2 + s * pas / 2
		cz = W + D / 2 - pas / 2
		nrm = (0, s * 0.7071, 0.7071)
		piese.append(cub("Acoperis", (2 * L + 0.6, lung, 0.12), (0, cy + nrm[1] * 0.06, cz + nrm[2] * 0.06), ACOPERIS,
			rot=(-s * 0.7854, 0, 0)))
		# rândurile de șindrilă (dungi)
		for k in range(1, 12):
			t = k / 12
			yy = D / 2 + s * pas * (1 - t)
			zz = W - streasina + pas * t
			piese.append(cub("Sindrila", (2 * L + 0.6, 0.02, 0.025), (0, yy + nrm[1] * 0.13, zz + nrm[2] * 0.13), p("262d2f"),
				rot=(-s * 0.7854, 0, 0)))
	piese.append(cub("Coama", (2 * L + 0.7, 0.14, 0.14), (0, D / 2, W + D / 2 + 0.12), NEGRU, rot=(0.7854, 0, 0)))
	for x0 in (-L, L - 0.2):
		piese.append(prisma("Fronton", [(0, W), (D, W), (D / 2, W + D / 2)], "yz", x0, x0 + 0.2, SIDING))
	for s in (-1, 1):  # scândurile de streașină de pe frontoanele laterale, cu un vârf de fier sus
		x = s * (L + 0.3)
		for sy in (-1, 1):
			y0 = D / 2 + sy * (D / 2 + streasina)
			piese.append(os_intre("Streasina", (x, y0, W - streasina), (x, D / 2, W + D / 2 + 0.05), 0.05, TRIM, laturi=4))
		piese.append(os_intre("Varf", (x, D / 2, W + D / 2 + 0.2), (x, D / 2, W + D / 2 + 0.75), 0.025, TRIM, laturi=4))
		piese.append(sfera("Bila", 0.045, (x, D / 2, W + D / 2 + 0.5), TRIM, segmente=6, inele=4))

	# --- frontonul ascuțit de deasupra intrării (iese din acoperiș), cu fereastra gotică și vârful de fier
	fl = 1.9
	fz = fl * math.tan(math.radians(60))
	piese.append(prisma("Fronton intrare", [(-fl, W), (fl, W), (0, W + fz)], "xz", -0.1, 3.4, SIDING))
	lp = math.hypot(fl + 0.25, fz + 0.25 * math.tan(math.radians(60)))
	for s in (-1, 1):
		a = math.radians(60)
		cx = s * (fl + 0.25) / 2 + s * 0.06 * math.sin(a)
		cz = W - 0.25 * math.tan(a) / 2 + fz / 2 + 0.06 * math.cos(a)
		piese.append(cub("Acoperis fronton", (lp, 3.75, 0.12), (cx, 1.53, cz), ACOPERIS, rot=(0, s * a, 0)))
		piese.append(cub("Streasina fronton", (lp, 0.08, 0.16), (cx + s * 0.02, -0.38, cz - 0.02), TRIM, rot=(0, s * a, 0)))
		# dantela de sub streașină: dinți ascuțiți
		for k in range(1, 7):
			t = k / 7
			px = s * fl * (1 - t)
			pz = W + fz * t - 0.05
			piese.append(prisma("Dantela", [(px - 0.06, pz), (px + 0.06, pz), (px, pz - 0.16)], "xz", -0.35, -0.31, TRIM))
	piese.append(os_intre("Varf fronton", (0, -0.36, W + fz + 0.1), (0, -0.36, W + fz + 1.0), 0.03, TRIM, laturi=4))
	piese.append(sfera("Bila", 0.055, (0, -0.36, W + fz + 0.7), TRIM, segmente=6, inele=4))
	piese.append(cub("Cruce varf", (0.2, 0.02, 0.02), (0, -0.36, W + fz + 0.88), TRIM))  # cruciulița de fier din vârf
	# fereastra gotică (oarbă: în spatele ei e podul): ramă, arc ascuțit, vitraliu închis
	gz0, gz1 = W + 0.5, W + 1.7
	piese += [
		cub("Rama gotica", (0.9, 0.04, gz1 - gz0), (0, -0.12, (gz0 + gz1) / 2), TRIM),
		prisma("Arc gotic", [(-0.45, gz1), (0.45, gz1), (0, gz1 + 0.55)], "xz", -0.14, -0.1, TRIM),
		cub("Vitraliu", (0.7, 0.02, gz1 - gz0 - 0.1), (0, -0.15, (gz0 + gz1) / 2 + 0.03), p("295555")),
		prisma("Vitraliu", [(-0.35, gz1 - 0.02), (0.35, gz1 - 0.02), (0, gz1 + 0.4)], "xz", -0.16, -0.14, p("295555")),
		cub("Plumb", (0.03, 0.03, gz1 - gz0 + 0.3), (0, -0.165, (gz0 + gz1) / 2 + 0.1), TRIM),
		cub("Plumb", (0.7, 0.03, 0.03), (0, -0.165, gz0 + 0.65), TRIM),
		cub("Pervaz", (1.0, 0.12, 0.05), (0, -0.16, gz0 - 0.03), TRIM),
	]
	# --- coșul de fum (bucătăria), din cărămidă, cu capac
	piese.append(cub("Cos", (0.7, 0.7, 4.6), (-5.6, 4.9, W + 2.3), p("7b383a")))
	piese.append(cub("Capac cos", (0.84, 0.84, 0.12), (-5.6, 4.9, W + 4.66), NEGRU))
	for k in range(9):  # rosturile cărămizilor
		piese.append(cub("Rost cos", (0.72, 0.72, 0.015), (-5.6, 4.9, W + 2.9 + k * 0.18), p("5e363e")))

	# coliziunea: doar ce ține (pereți, podele, acoperișuri, stâlpi), o cutie pe balustradă și o rampă peste trepte,
	# ca să urci lin; detaliile (rosturi, preș, ornamente, dovleci) n-au coliziune, să nu te agăți de ele
	col = _copii(piese, ("Fundatie", "Podea", "Siding", "Perete", "Tavan", "Usa dormitor", "Acoperis", "Fronton", "Fronton intrare",
		"Acoperis fronton", "Cos", "Veranda", "Stalp", "Balansoar"))
	for a, b in ((-3.3, -1.2), (1.2, 3.3)):
		col.append(cub("Coliziune balustrada", (b - a, 0.1, 1.0), ((a + b) / 2, -2.0, FL + 0.5), NEGRU))
	for x in (-3.3, 3.3):
		col.append(cub("Coliziune balustrada", (0.1, 2.0, 1.0), (x, -1.0, FL + 0.5), NEGRU))
	col.append(prisma("Rampa", [(-2.9, 0.0), (-2.2, 0.0), (-2.2, FL - 0.01)], "yz", -1.0, 1.0, NEGRU))
	uneste(col, "Coliziune")
	uneste(piese, "Casa")
	uneste(geamuri, "Geamuri")
	uneste(lumini, "Lumini")
	exporta(os.path.join(cale, "casa_lexy.glb"))


def usa_lexy(cale):
	"""Ușa de la intrare: roșu-sânge, cu două panouri, un geam mic în arc ascuțit sus și ciocănelul de alamă.
	Balamaua în origine, ușa se întinde pe +X (1 m), grosimea pe Y. `GeamUsa` e separat (sticlă)."""
	curata()
	rosu = p("7b383a")
	piese = [cub("Usa", (1.0, 0.05, 2.18), (0.5, 0, 1.09), rosu)]
	for s in (-1, 1):
		piese += [
			cub("Panou", (0.7, 0.012, 0.75), (0.5, s * 0.031, 0.55), p("5e363e")),
			cub("Rama geam", (0.5, 0.012, 0.06), (0.5, s * 0.031, 1.33), NEGRU),
		]
	piese += [
		prisma("Rama arc", [(0.22, 1.36), (0.78, 1.36), (0.5, 1.98)], "xz", -0.03, 0.03, NEGRU),
		sfera("Clanta", 0.032, (0.88, -0.05, 1.0), p("a18463"), segmente=6, inele=4),
		sfera("Clanta", 0.032, (0.88, 0.05, 1.0), p("a18463"), segmente=6, inele=4),
		cub("Rozeta", (0.05, 0.02, 0.12), (0.88, -0.035, 1.0), p("a18463")),
		cub("Rozeta", (0.05, 0.02, 0.12), (0.88, 0.035, 1.0), p("a18463")),
		inel("Ciocanel", 0.05, 0.01, (0.5, -0.04, 1.2), p("a18463"), segmente=8),
		cub("Vizor", (0.03, 0.02, 0.03), (0.5, -0.035, 1.5), p("a18463")),
	]
	uneste(piese, "Usa")
	uneste([prisma("GeamUsa", [(0.27, 1.4), (0.73, 1.4), (0.5, 1.9)], "xz", -0.008, 0.008, GEAM)], "GeamUsa")
	exporta(os.path.join(cale, "usa_lexy.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Livingul
# ---------------------------------------------------------------------------------------------------------------

def canapea(cale):
	"""Canapea cu trei locuri, catifea verde-închis, brațe rulate, perne pe spătar, o pătură roșie aruncată pe brațul
	din stânga și două perne mici. Originea = podeaua, la mijloc; fața spre -Y. Șezutul e la 0,46 m.
	Locurile: x = -0,6 / 0 / 0,6."""
	curata()
	verde, umbra = p("32453b"), p("2a3c3d")
	piese = [cub("Baza", (2.2, 0.9, 0.25), (0, 0, 0.205), umbra)]
	for x in (-1.0, 1.0):
		for y in (-0.38, 0.38):
			piese.append(cilindru("Picior", 0.03, 0.022, 0.08, (x, y, 0.04), LEMN_INCHIS, laturi=6))
	for x in (-0.6, 0.0, 0.6):
		piese.append(cub("Perna sezut", (0.58, 0.64, 0.13), (x, -0.13, 0.395), verde))
		piese.append(cub("Perna spatar", (0.58, 0.18, 0.44), (x, 0.17, 0.66), verde, rot=(-0.18, 0, 0)))
		for k in (-1, 1):  # nasturii capitonajului
			piese.append(sfera("Nasture", 0.012, (x + k * 0.14, 0.07, 0.7), umbra, segmente=5, inele=3))
	piese.append(cub("Spatar", (1.8, 0.2, 0.62), (0, 0.35, 0.64), verde))
	for s in (-1, 1):
		piese.append(cub("Brat", (0.2, 0.9, 0.3), (s * 1.0, 0, 0.48), verde))
		piese.append(cilindru("Sul", 0.12, 0.12, 0.9, (s * 1.0, 0, 0.63), verde, laturi=8, rot=(1.5708, 0, 0)))
		piese.append(cilindru("Capat sul", 0.085, 0.085, 0.02, (s * 1.0, -0.455, 0.63), umbra, laturi=8, rot=(1.5708, 0, 0)))
	# pătura roșie peste brațul stâng (+X), care cade pe șezut
	piese.append(trunchi("Patura", [((0.95, -0.4, 0.78), 0.14, 0.03), ((0.95, -0.1, 0.8), 0.15, 0.035), ((0.88, 0.2, 0.75), 0.15, 0.03),
		((0.75, 0.25, 0.5), 0.14, 0.025)], p("7b383a"), laturi=6, ref=(1, 0, 0)))
	for k in range(4):
		piese.append(cub("Franjuri", (0.012, 0.02, 0.06), (0.86 + k * 0.05, -0.47, 0.74), p("904a40")))
	# perne mici: una neagră cu o lună, una mov
	piese.append(cub("Perna", (0.36, 0.12, 0.34), (0.68, 0.06, 0.63), NEGRU, rot=(-0.3, 0.2, 0.15)))
	piese.append(sfera("Luna", 0.06, (0.66, -0.005, 0.64), p("a18463"), scara=(1, 0.2, 1), segmente=8, inele=5))
	piese.append(cub("Perna", (0.32, 0.12, 0.3), (-0.75, 0.04, 0.62), p("553e4d"), rot=(-0.25, -0.25, -0.1)))
	uneste(piese, "Canapea")
	exporta(os.path.join(cale, "canapea.glb"))


def masuta(cale):
	"""Măsuța din fața canapelei (lemn închis), cu un raft jos plin de reviste. Pe ea: brichetă, foițe, grinder,
	o doză, telecomanda. Scrumiera e separată (în ea se stinge jointul). Originea = podeaua, la mijloc."""
	curata()
	piese = [cub("Blat", (1.1, 0.55, 0.04), (0, 0, 0.4), LEMN_INCHIS), cub("Raft", (1.0, 0.47, 0.025), (0, 0, 0.12), LEMN_INCHIS)]
	for x in (-0.5, 0.5):
		for y in (-0.22, 0.22):
			piese.append(cub("Picior", (0.05, 0.05, 0.38), (x, y, 0.19), NEGRU))
	for k, cul in enumerate((p("7b383a"), ALB, p("438b88"))):
		piese.append(cub("Revista", (0.28, 0.21, 0.012), (-0.2 + k * 0.03, -0.02 + k * 0.02, 0.139 + k * 0.013), cul, rot=(0, 0, k * 0.2)))
	piese += [
		cub("Bricheta", (0.025, 0.012, 0.075), (0.18, -0.12, 0.427), p("7b383a"), rot=(1.5708, 0, 0.4)),
		cub("Foite", (0.07, 0.04, 0.008), (0.3, -0.05, 0.424), ALB, rot=(0, 0, -0.3)),
		cub("Eticheta foite", (0.05, 0.03, 0.002), (0.3, -0.05, 0.429), p("a18463"), rot=(0, 0, -0.3)),
		cilindru("Grinder", 0.03, 0.03, 0.04, (0.42, 0.1, 0.44), p("70706e"), laturi=8),
		cilindru("Capac grinder", 0.031, 0.031, 0.008, (0.42, 0.1, 0.464), p("438b88"), laturi=8),
		cilindru("Doza", 0.033, 0.033, 0.12, (-0.4, 0.12, 0.48), p("438b88"), laturi=8),
		cilindru("Capac doza", 0.03, 0.03, 0.006, (-0.4, 0.12, 0.543), p("70706e"), laturi=8),
		cub("Telecomanda", (0.05, 0.18, 0.02), (-0.15, 0.15, 0.43), NEGRU, rot=(0, 0, 0.5)),
		cub("Buton", (0.012, 0.012, 0.006), (-0.17, 0.11, 0.443), p("7b383a"), rot=(0, 0, 0.5)),
	]
	uneste(piese, "Masuta")
	exporta(os.path.join(cale, "masuta.glb"))


def scrumiera(cale):
	"""Scrumiera de sticlă fumurie, cu scrum și câteva mucuri (ultimul joint se stinge în ea). Originea = jos, la mijloc."""
	curata()
	piese = [
		cilindru("Scrumiera", 0.075, 0.07, 0.03, (0, 0, 0.015), p("6f6d7f"), laturi=10),
		cilindru("Scrum", 0.06, 0.06, 0.012, (0, 0, 0.026), p("5e5356"), laturi=10),
	]
	for k in range(4):  # crestăturile de pe margine
		u = k * math.tau / 4
		piese.append(cub("Crestatura", (0.022, 0.03, 0.012), (math.cos(u) * 0.07, math.sin(u) * 0.07, 0.032), NEGRU, rot=(0, 0, u)))
	for (x, y, u) in ((0.02, 0.01, 0.4), (-0.025, -0.01, 2.0), (0.0, 0.03, 3.4)):
		piese.append(os_intre("Muc", (x, y, 0.036), (x + math.cos(u) * 0.035, y + math.sin(u) * 0.035, 0.038), 0.005, ALB, laturi=5))
		piese.append(os_intre("Filtru", (x, y, 0.036), (x - math.cos(u) * 0.012, y - math.sin(u) * 0.012, 0.035), 0.0055,
			p("a18463"), laturi=5))
	uneste(piese, "Scrumiera")
	exporta(os.path.join(cale, "scrumiera.glb"))


def televizor(cale):
	"""Televizor de mărime medie (cam 43") pe o comodă joasă: rama neagră subțire, picioare, sub el o consolă și
	câteva jocuri; pe comodă două lumânări groase (flăcările în `Lumini`) și un craniu mic de decor.
	`Ecran` e separat (pe el pune Godot imaginea cu știrile). Originea = podeaua, la mijloc; fața spre -Y."""
	curata()
	piese = [cub("Comoda", (1.5, 0.42, 0.5), (0, 0, 0.27), LEMN_INCHIS)]
	for x in (-0.68, 0.68):
		for y in (-0.17, 0.17):
			piese.append(cilindru("Picior", 0.025, 0.02, 0.02, (x, y, 0.01), NEGRU, laturi=6))
	for k in range(3):  # trei uși cu mânere
		x = -0.49 + k * 0.49
		piese.append(cub("Usita", (0.46, 0.012, 0.42), (x, -0.215, 0.27), p("5e363e")))
		piese.append(cub("Maner", (0.1, 0.02, 0.015), (x, -0.226, 0.42), p("a18463")))
	ez = 0.52 + 0.06 + 0.31
	piese += [
		cub("Rama tv", (0.98, 0.05, 0.6), (0, 0.02, ez), NEGRU),
		cub("Spate tv", (0.7, 0.06, 0.4), (0, 0.075, ez), NEGRU),
		cub("Logo", (0.05, 0.004, 0.012), (0, -0.007, ez - 0.285), p("70706e")),
		cub("Led", (0.008, 0.004, 0.006), (0.44, -0.007, ez - 0.285), p("7b383a")),
	]
	for x in (-0.38, 0.38):
		piese.append(cub("Picior tv", (0.04, 0.2, 0.012), (x, 0.0, 0.526), NEGRU))
		piese.append(os_intre("Picior tv", (x, 0.0, 0.53), (x, 0.03, 0.6), 0.008, NEGRU, laturi=4))
	piese += [  # consola și jocurile
		cub("Consola", (0.3, 0.2, 0.06), (-0.45, -0.02, 0.55), NEGRU),
		cub("Led consola", (0.12, 0.004, 0.006), (-0.45, -0.121, 0.55), p("438b88")),
		cub("Joc", (0.13, 0.17, 0.014), (0.3, -0.05, 0.527), p("7b383a"), rot=(0, 0, 0.2)),
		cub("Joc", (0.13, 0.17, 0.014), (0.31, -0.05, 0.541), p("2a3c3d"), rot=(0, 0, -0.1)),
		cub("Controller", (0.15, 0.09, 0.04), (0.5, -0.1, 0.54), NEGRU, rot=(0, 0, 0.3)),
	]
	for x, hh in ((-0.66, 0.16), (-0.58, 0.11)):  # lumânările groase, cu ceară scursă
		piese.append(cilindru("Lumanare", 0.035, 0.035, hh, (x, -0.08, 0.52 + hh / 2), ALB, laturi=8))
		piese.append(os_intre("Ceara", (x + 0.033, -0.08, 0.52 + hh), (x + 0.035, -0.09, 0.52 + hh * 0.5), 0.008, ALB, laturi=4))
		piese.append(cub("Fitil", (0.004, 0.004, 0.015), (x, -0.08, 0.52 + hh + 0.007), NEGRU))
	# craniul mic de decor
	cx, cy, cz = 0.62, -0.02, 0.6
	piese += [
		sfera("Craniu", 0.05, (cx, cy, cz), ALB, scara=(0.9, 1.0, 1.0), segmente=8, inele=6),
		cub("Falca", (0.05, 0.04, 0.028), (cx, cy - 0.025, cz - 0.05), ALB),
		cub("Orbita", (0.02, 0.008, 0.02), (cx - 0.02, cy - 0.048, cz + 0.005), NEGRU),
		cub("Orbita", (0.02, 0.008, 0.02), (cx + 0.02, cy - 0.048, cz + 0.005), NEGRU),
		cub("Nas craniu", (0.01, 0.008, 0.014), (cx, cy - 0.05, cz - 0.02), NEGRU),
	]
	uneste(piese, "Televizor")
	uneste([cub("Ecran", (0.92, 0.008, 0.53), (0, -0.007, ez), NEGRU)], "Ecran")
	lum = []
	for x, hh in ((-0.66, 0.16), (-0.58, 0.11)):
		lum.append(sfera("Flacara", 0.012, (x, -0.08, 0.52 + hh + 0.03), p("a18463"), scara=(0.8, 0.8, 1.8), segmente=5, inele=4))
	uneste(lum, "Lumini")
	exporta(os.path.join(cale, "televizor.glb"))


def lampadar(cale):
	"""Lampadar înalt de alamă cu abajur plisat (`Abajur`, strălucește puțin: e aprins). Originea = podeaua."""
	curata()
	uneste([
		cilindru("Baza", 0.16, 0.18, 0.03, (0, 0, 0.015), NEGRU, laturi=10),
		cilindru("Tija", 0.012, 0.012, 1.5, (0, 0, 0.78), p("a18463"), laturi=6),
		cilindru("Fasung", 0.025, 0.02, 0.06, (0, 0, 1.55), p("a18463"), laturi=6),
	], "Lampadar")
	uneste([cilindru("Abajur", 0.24, 0.14, 0.3, (0, 0, 1.6), p("a56850"), laturi=12)], "Abajur")
	exporta(os.path.join(cale, "lampadar.glb"))


def decor_living(cale):
	"""Ce mai e în living și în hol, în coordonatele casei: covorul persan de sub măsuță, draperiile grele
	(roșu închis) la ferestre, biblioteca de pe peretele din spate, raftul cu cristale și lumânări, un poster de
	trupă, planta; în hol un preș lung, o măsuță cu bol de chei și oglindă, lustrele. Plafonierele din `Lumini`."""
	curata()
	r = random.Random(7)
	piese, lumini = [], []
	# covorul persan (sub măsuță), cu chenar
	cx, cy = 4.1, 2.9
	piese += [
		cub("Covor", (2.6, 1.8, 0.01), (cx, cy, FL + 0.005), p("7b383a")),
		cub("Chenar", (2.4, 1.6, 0.01), (cx, cy, FL + 0.014), p("48313b")),
		cub("Mijloc covor", (2.1, 1.3, 0.01), (cx, cy, FL + 0.023), p("7b383a")),
		cub("Romb", (0.6, 0.6, 0.01), (cx, cy, FL + 0.032), p("a18463"), rot=(0, 0, 0.785)),
		cub("Romb", (0.35, 0.35, 0.01), (cx, cy, FL + 0.041), p("295555"), rot=(0, 0, 0.785)),
	]
	for s in (-1, 1):
		piese.append(cub("Romb", (0.25, 0.25, 0.01), (cx + s * 0.75, cy, FL + 0.032), p("a18463"), rot=(0, 0, 0.785)))
	# draperiile: la cele două ferestre din față ale livingului și la cea laterală, cu bara de fier
	for a, b in FER_FATA[:2]:
		piese.append(cilindru("Bara draperie", 0.012, 0.012, b - a + 0.6, ((a + b) / 2, 2 * T + 0.08, FER_Z[1] + 0.2), NEGRU,
			laturi=6, rot=(0, 1.5708, 0)))
		for x in (a - 0.2, b + 0.2):
			for k in range(3):
				piese.append(cilindru("Draperie", 0.05, 0.06, FER_Z[1] + 0.2 - FL - 0.02, (x + (k - 1) * 0.08, 2 * T + 0.08,
					FL + (FER_Z[1] + 0.2 - FL) / 2 + 0.01), p("7b383a") if k != 1 else p("5e363e"), laturi=6))
	piese.append(cilindru("Bara draperie", 0.012, 0.012, 1.8, (L - 2 * T - 0.08, sum(FER_LATERAL) / 2, FER_Z[1] + 0.2), NEGRU,
		laturi=6, rot=(1.5708, 0, 0)))
	for y in (FER_LATERAL[0] - 0.2, FER_LATERAL[1] + 0.2):
		for k in range(3):
			piese.append(cilindru("Draperie", 0.05, 0.06, FER_Z[1] + 0.2 - FL - 0.02, (L - 2 * T - 0.08, y + (k - 1) * 0.08,
				FL + (FER_Z[1] + 0.2 - FL) / 2 + 0.01), p("7b383a") if k != 1 else p("5e363e"), laturi=6))
	# biblioteca de pe peretele din spate (stânga ferestrei din spate)
	bx0, bx1 = 1.8, 3.2
	by = D - 2 * T - 0.17
	piese.append(cub("Biblioteca", (bx1 - bx0, 0.34, 0.03), ((bx0 + bx1) / 2, by, FL + 1.9), LEMN_INCHIS))
	for x in (bx0, bx1):
		piese.append(cub("Biblioteca", (0.03, 0.34, 1.9), (x, by, FL + 0.95), LEMN_INCHIS))
	for k in range(5):
		z = FL + 0.04 + k * 0.45
		piese.append(cub("Polita", (bx1 - bx0 - 0.03, 0.32, 0.025), ((bx0 + bx1) / 2, by, z), LEMN_INCHIS))
		if k == 4:
			break
		x = bx0 + 0.05
		while x < bx1 - 0.08:
			lat = r.uniform(0.03, 0.06)
			inalt = r.uniform(0.22, 0.34)
			if r.random() < 0.12:  # un gol, uneori o carte căzută într-o parte
				x += 0.1
				continue
			cul = r.choice([p("7b383a"), p("2a3c3d"), p("553e4d"), p("445d46"), p("a18463"), NEGRU, p("5e363e")])
			piese.append(cub("Carte", (lat, 0.22, inalt), (x + lat / 2, by - 0.03, z + 0.0125 + inalt / 2), cul))
			x += lat + 0.004
	# raftul cu cristale, lumânări și un borcan cu ierburi (Lexy crede că vrăjitoria e „fun”)
	ry = D - 2 * T - 0.1
	piese.append(cub("Raft", (1.0, 0.2, 0.03), (5.6, ry, FL + 1.45), LEMN_INCHIS))
	for k, (cul, h) in enumerate(((p("553e4d"), 0.09), (p("438b88"), 0.06), (p("61a19f"), 0.11))):
		piese.append(cilindru("Cristal", 0.022, 0.0, h, (5.25 + k * 0.1, ry, FL + 1.465 + h / 2), cul, laturi=5))
	piese.append(cilindru("Borcan", 0.04, 0.04, 0.12, (5.7, ry, FL + 1.525), p("6f6d7f"), laturi=8))
	piese.append(cilindru("Ierburi", 0.035, 0.035, 0.05, (5.7, ry, FL + 1.5), p("5b6d4e"), laturi=8))
	for k in range(2):
		piese.append(cilindru("Lumanare", 0.025, 0.025, 0.14 - k * 0.04, (5.9 + k * 0.1, ry, FL + 1.535 - k * 0.02), NEGRU, laturi=6))
	# posterul de trupă de pe peretele lateral (living), cu pioneze
	px = L - 2 * T - 0.01
	piese += [
		cub("Poster", (0.01, 0.6, 0.85), (px, 5.6, FL + 1.55), NEGRU),
		cub("Poster", (0.012, 0.5, 0.3), (px - 0.012, 5.6, FL + 1.75), p("7b383a")),
		text("Trupa", "NO SLEEP", (px - 0.012, 5.6, FL + 1.4), 0.07, ALB, rot=(1.5708, 0, -1.5708)),
	]
	# planta din colț (frunze late, puțin ofilite)
	pcx, pcy = 6.4, 0.65
	piese.append(cilindru("Ghiveci", 0.15, 0.12, 0.3, (pcx, pcy, FL + 0.15), p("5e5356"), laturi=8))
	piese.append(cilindru("Pamant", 0.14, 0.14, 0.02, (pcx, pcy, FL + 0.29), PAMANT, laturi=8))
	for k in range(9):
		u = k * math.tau / 9 + r.uniform(-0.2, 0.2)
		h = r.uniform(0.45, 0.85)
		varf = (pcx + math.cos(u) * 0.3, pcy + math.sin(u) * 0.3, FL + 0.3 + h)
		piese.append(os_intre("Tulpina", (pcx, pcy, FL + 0.3), varf, 0.008, p("445d46"), laturi=4))
		piese.append(sfera("Frunza", 0.09, varf, p("5b6d4e") if k % 3 else p("7a7b59"), scara=(1.0, 0.45, 0.2), segmente=6, inele=4))
	# holul: preșul lung, măsuța cu bolul de chei, oglinda cu ramă neagră
	piese += [
		cub("Pres hol", (1.0, 3.6, 0.01), (0, 2.9, FL + 0.005), p("5e363e")),
		cub("Chenar pres", (0.85, 3.45, 0.01), (0, 2.9, FL + 0.014), p("7b383a")),
		cub("Masuta hol", (0.8, 0.3, 0.03), (-HOL_X + T + 0.15 + 0.01, 4.6, FL + 0.8), LEMN_INCHIS, rot=(0, 0, 1.5708)),
	]
	mx = -HOL_X + T + 0.16
	for y in (4.25, 4.95):
		piese.append(cub("Picior masuta", (0.03, 0.03, 0.79), (mx, y, FL + 0.395), NEGRU))
	piese += [
		cilindru("Bol", 0.08, 0.05, 0.05, (mx, 4.6, FL + 0.84), p("438b88"), laturi=8),
		cub("Chei", (0.04, 0.02, 0.01), (mx, 4.62, FL + 0.87), p("a18463"), rot=(0, 0, 0.6)),
		cub("Oglinda", (0.02, 0.6, 0.9), (-HOL_X + T + 0.012, 4.6, FL + 1.55), p("778c96")),
		cub("Rama oglinda", (0.015, 0.7, 0.05), (-HOL_X + T + 0.01, 4.6, FL + 2.02), NEGRU),
		cub("Rama oglinda", (0.015, 0.7, 0.05), (-HOL_X + T + 0.01, 4.6, FL + 1.08), NEGRU),
		cub("Rama oglinda", (0.015, 0.05, 0.9), (-HOL_X + T + 0.01, 4.28, FL + 1.55), NEGRU),
		cub("Rama oglinda", (0.015, 0.05, 0.9), (-HOL_X + T + 0.01, 4.92, FL + 1.55), NEGRU),
	]
	# cuierul de lângă ușă, cu o geacă și o geantă
	piese.append(cub("Cuier", (0.03, 0.6, 0.08), (HOL_X - T - 0.015, 0.8, FL + 1.7), LEMN_INCHIS))
	piese.append(trunchi("Geaca", [((HOL_X - T - 0.08, 0.7, FL + 1.68), 0.04, 0.12), ((HOL_X - T - 0.1, 0.7, FL + 1.2), 0.06, 0.18),
		((HOL_X - T - 0.1, 0.72, FL + 0.95), 0.05, 0.17)], NEGRU, laturi=6, ref=(1, 0, 0)))
	piese.append(sfera("Geanta", 0.12, (HOL_X - T - 0.1, 1.0, FL + 1.35), p("553e4d"), scara=(0.5, 1, 0.8), segmente=6, inele=4))
	# plafonierele (hol, living): un con negru și globul aprins
	for x, y in ((0, 2.4), (4.1, 3.6)):
		piese.append(cilindru("Plafoniera", 0.05, 0.16, 0.08, (x, y, FL + H - 0.04), NEGRU, laturi=8))
		lumini.append(sfera("Glob", 0.13, (x, y, FL + H - 0.1), p("a18463"), scara=(1, 1, 0.5), segmente=8, inele=4))
	# coliziunea: biblioteca, planta, măsuța din hol (covoarele și draperiile n-au)
	uneste([
		cub("Coliziune", (bx1 - bx0 + 0.03, 0.34, 1.92), ((bx0 + bx1) / 2, by, FL + 0.96), NEGRU),
		cub("Coliziune", (0.5, 0.5, 1.0), (pcx, pcy, FL + 0.5), NEGRU),
		cub("Coliziune", (0.32, 0.82, 0.85), (mx, 4.6, FL + 0.425), NEGRU),
	], "Coliziune")
	uneste(piese, "Decor")
	uneste(lumini, "Lumini")
	exporta(os.path.join(cale, "decor_living.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Bucătăria (modernă, dar nu fițoasă): dulapuri teal închis cu mânere negre, blat deschis, faianță albă
# ---------------------------------------------------------------------------------------------------------------

BUC_X0 = -L + 2 * T   # peretele lateral, pe dinăuntru
BUC_X1 = -HOL_X - T   # peretele dinspre hol
BUC_Y1 = D - 2 * T    # peretele din spate
MASA = (-4.2, 2.3)    # mijlocul mesei
LOC_LEXY_BUC = (-5.05, 2.3)  # scaunul lui Lexy (cu fața spre +X, spre hol)


def _scaun_modern(piese, x, y, unghi):
	"""Scaun modern: șezut și spătar dintr-o bucată (alb), picioare negre subțiri. `unghi` = încotro privește (rad, 0 = -Y)."""
	c, s = math.cos(unghi), math.sin(unghi)
	def rot(dx, dy):
		return (x + dx * c - dy * s, y + dx * s + dy * c)
	piese.append(cub("Sezut", (0.44, 0.42, 0.04), (x, y, FL + 0.45), ALB, rot=(0, 0, unghi)))
	sx, sy = rot(0, 0.2)
	piese.append(cub("Spatar", (0.42, 0.035, 0.4), (sx, sy, FL + 0.7), ALB, rot=(-0.12, 0, unghi)))
	for dx in (-0.18, 0.18):
		for dy in (-0.17, 0.17):
			px, py = rot(dx, dy)
			piese.append(os_intre("Picior scaun", (px, py, FL + 0.43), (px + dx * 0.1, py + dy * 0.1, FL), 0.012, NEGRU, laturi=4))


def bucatarie_lexy(cale):
	"""Bucătăria, în coordonatele casei: rândul de dulapuri de pe peretele lateral (cu chiuveta sub fereastră și
	mașina de spălat vase), cel de pe peretele din spate (aragazul cu hota), frigiderul mare inox, dulapurile de
	sus, faianța, masa cu patru scaune și două lămpi suspendate deasupra (globurile în `Lumini`).
	Lexy stă pe scaunul din capătul dinspre perete (`LOC_LEXY_BUC`), cu fața spre hol."""
	curata()
	r = random.Random(21)
	dulap, blat, faianta = p("2a3c3d"), p("7e8d87"), ALB
	piese, lumini = [], []
	ad = 0.6  # adâncimea dulapurilor
	# --- rândul lateral (pe X = BUC_X0), de la y 1,7 până în colțul din spate
	y0, y1 = 1.7, BUC_Y1
	piese.append(cub("Dulapuri", (ad, y1 - y0, 0.82), (BUC_X0 + ad / 2, (y0 + y1) / 2, FL + 0.08 + 0.41), dulap))
	piese.append(cub("Plinta", (ad - 0.06, y1 - y0, 0.08), (BUC_X0 + (ad - 0.06) / 2, (y0 + y1) / 2, FL + 0.04), NEGRU))
	piese.append(cub("Blat", (ad + 0.03, y1 - y0 + 0.03, 0.04), (BUC_X0 + (ad + 0.03) / 2, (y0 + y1) / 2, FL + 0.92), blat))
	k = 0
	y = y0 + 0.02
	while y < y1 - ad - 0.55:  # ușile, cu mânere negre lungi (colțul e ascuns de rândul din spate)
		lat = 0.6
		piese.append(cub("Usa dulap", (0.012, lat - 0.02, 0.76), (BUC_X0 + ad + 0.006, y + lat / 2, FL + 0.5), p("32453b")))
		piese.append(cub("Maner", (0.02, 0.012, 0.22), (BUC_X0 + ad + 0.02, y + lat - 0.07, FL + 0.72), NEGRU))
		y += lat
		k += 1
	# chiuveta sub fereastră, cu bateria neagră
	cy = sum(FER_LATERAL) / 2
	piese += [
		cub("Chiuveta", (0.4, 0.55, 0.012), (BUC_X0 + 0.3, cy, FL + 0.946), NEGRU),
		cub("Chiuveta", (0.36, 0.5, 0.012), (BUC_X0 + 0.3, cy, FL + 0.958), p("5e5356")),
		os_intre("Baterie", (BUC_X0 + 0.08, cy, FL + 0.94), (BUC_X0 + 0.08, cy, FL + 1.28), 0.015, NEGRU, laturi=6),
		os_intre("Baterie", (BUC_X0 + 0.08, cy, FL + 1.28), (BUC_X0 + 0.26, cy, FL + 1.22), 0.012, NEGRU, laturi=6),
		cilindru("Detergent", 0.03, 0.03, 0.18, (BUC_X0 + 0.1, cy + 0.32, FL + 1.03), p("61a19f"), laturi=6),
		cub("Burete", (0.08, 0.05, 0.03), (BUC_X0 + 0.1, cy - 0.33, FL + 0.955), p("a18463")),
	]
	# --- rândul din spate (pe Y = BUC_Y1), de la perete până la frigider; aragazul la mijloc
	x0, x1 = BUC_X0 + ad, -3.4
	piese.append(cub("Dulapuri", (x1 - x0, ad, 0.82), ((x0 + x1) / 2, BUC_Y1 - ad / 2, FL + 0.49), dulap))
	piese.append(cub("Plinta", (x1 - x0, ad - 0.06, 0.08), ((x0 + x1) / 2, BUC_Y1 - (ad - 0.06) / 2, FL + 0.04), NEGRU))
	piese.append(cub("Blat", (x1 - x0 + 0.03 - 0.03, ad + 0.03, 0.04), ((x0 + 0.03 + x1 + 0.03) / 2, BUC_Y1 - (ad + 0.03) / 2, FL + 0.92), blat))
	ax = -4.7  # aragazul (în dreptul unei uși de dulap, ca să nu se suprapună)
	piese += [
		cub("Aragaz", (0.6, 0.012, 0.76), (ax, BUC_Y1 - ad - 0.006, FL + 0.48), NEGRU),
		cub("Geam cuptor", (0.45, 0.014, 0.3), (ax, BUC_Y1 - ad - 0.02, FL + 0.45), p("2a3c3d")),
		cub("Maner cuptor", (0.5, 0.03, 0.025), (ax, BUC_Y1 - ad - 0.03, FL + 0.74), p("70706e")),
		cub("Plita", (0.58, 0.55, 0.012), (ax, BUC_Y1 - ad / 2, FL + 0.946), NEGRU),
	]
	for dx in (-0.14, 0.14):
		for dy in (-0.12, 0.12):
			piese.append(inel("Ochi plita", 0.07, 0.005, (ax + dx, BUC_Y1 - ad / 2 + dy, FL + 0.953), p("5e5356"), segmente=10))
	piese.append(cilindru("Oala", 0.1, 0.1, 0.13, (ax - 0.14, BUC_Y1 - ad / 2 - 0.12, FL + 1.02), p("70706e"), laturi=10))
	for kx in range(int((x1 - x0) / 0.6)):  # ușile din spate (fără locul aragazului)
		xx = x0 + 0.3 + kx * 0.6
		if abs(xx - ax) < 0.35:
			continue
		piese.append(cub("Usa dulap", (0.58, 0.012, 0.76), (xx, BUC_Y1 - ad - 0.006, FL + 0.5), p("32453b")))
		piese.append(cub("Maner", (0.22, 0.02, 0.012), (xx, BUC_Y1 - ad - 0.02, FL + 0.84), NEGRU))
	# hota: o cutie care se îngustează spre tavan
	piese.append(cub("Hota", (0.7, 0.5, 0.12), (ax, BUC_Y1 - 0.25, FL + 1.7), p("70706e")))
	piese.append(cub("Hota", (0.3, 0.25, H - 1.76), (ax, BUC_Y1 - 0.125, FL + 1.76 + (H - 1.76) / 2), p("70706e")))
	# faianța albă (metro) dintre blat și dulapurile de sus, cu rosturi
	piese.append(cub("Faianta", (x1 - BUC_X0, 0.012, 0.55), ((BUC_X0 + x1) / 2, BUC_Y1 - 0.006, FL + 1.22), faianta))
	# pe lateral, în jurul ferestrei (sub ea doar o fâșie)
	segmente = ((y0, FER_LATERAL[0] - 0.05), (FER_LATERAL[1] + 0.05, BUC_Y1 - 0.012))
	for a, b in segmente:
		piese.append(cub("Faianta", (0.012, b - a, 0.55), (BUC_X0 + 0.006, (a + b) / 2, FL + 1.22), faianta))
	piese.append(cub("Faianta", (0.012, FER_LATERAL[1] - FER_LATERAL[0] + 0.1, 0.12),
		(BUC_X0 + 0.006, sum(FER_LATERAL) / 2, FL + 1.005), faianta))
	for kz in range(1, 6):
		z = FL + 0.94 + kz * 0.092
		piese.append(cub("Rost", (x1 - BUC_X0, 0.006, 0.006), ((BUC_X0 + x1) / 2, BUC_Y1 - 0.02, z), PIATRA_DESCHISA))
		for a, b in segmente:
			piese.append(cub("Rost", (0.006, b - a, 0.006), (BUC_X0 + 0.02, (a + b) / 2, z), PIATRA_DESCHISA))
	# dulapurile de sus (pe spate, mai puțin în dreptul hotei; pe lateral, după fereastră)
	for a, b in ((BUC_X0 + 0.35, ax - 0.4), (ax + 0.4, x1)):
		piese.append(cub("Dulap sus", (b - a, 0.35, 0.75), ((a + b) / 2, BUC_Y1 - 0.175, FL + 1.88), dulap))
		n = max(1, round((b - a) / 0.5))
		for kk in range(n):
			xx = a + (kk + 0.5) * (b - a) / n
			piese.append(cub("Usa dulap", ((b - a) / n - 0.02, 0.012, 0.7), (xx, BUC_Y1 - 0.356, FL + 1.88), p("32453b")))
			piese.append(cub("Maner", (0.012, 0.02, 0.15), (xx + ((b - a) / n / 2 - 0.06) * (1 if kk % 2 else -1), BUC_Y1 - 0.37, FL + 1.6), NEGRU))
	piese.append(cub("Dulap sus", (0.35, BUC_Y1 - 0.35 - 4.5, 0.75), (BUC_X0 + 0.175, (4.5 + BUC_Y1 - 0.35) / 2, FL + 1.88), dulap))
	# --- frigiderul mare, inox, cu magneți și o poză
	fx0, fx1 = -3.38, -2.45
	piese += [
		cub("Frigider", (fx1 - fx0, 0.7, 1.9), ((fx0 + fx1) / 2, BUC_Y1 - 0.35, FL + 0.95), p("70706e")),
		cub("Rost frigider", (0.012, 0.012, 1.8), ((fx0 + fx1) / 2, BUC_Y1 - 0.706, FL + 1.0), NEGRU),
		cub("Maner frigider", (0.025, 0.04, 0.7), ((fx0 + fx1) / 2 - 0.05, BUC_Y1 - 0.73, FL + 1.15), NEGRU),
		cub("Maner frigider", (0.025, 0.04, 0.7), ((fx0 + fx1) / 2 + 0.05, BUC_Y1 - 0.73, FL + 1.15), NEGRU),
		cub("Poza", (0.12, 0.008, 0.16), (fx0 + 0.14, BUC_Y1 - 0.709, FL + 1.45), ALB, rot=(0, 0.1, 0)),
		cub("Poza", (0.1, 0.008, 0.11), (fx0 + 0.14, BUC_Y1 - 0.712, FL + 1.46), p("438b88"), rot=(0, 0.1, 0)),
	]
	for k, cul in enumerate((p("7b383a"), p("a18463"), p("61a19f"), p("553e4d"))):
		piese.append(cub("Magnet", (0.035, 0.012, 0.035), (fx0 + 0.6 + (k % 2) * 0.12, BUC_Y1 - 0.71, FL + 1.3 + k * 0.1), cul))
	# pe blat: cuptor cu microunde, fierbător, cuțite, prosoape de hârtie, un fruct
	piese += [
		cub("Microunde", (0.5, 0.36, 0.28), (-3.85, BUC_Y1 - 0.25, FL + 1.08), NEGRU),
		cub("Usa microunde", (0.34, 0.012, 0.22), (-3.9, BUC_Y1 - 0.436, FL + 1.08), p("2a3c3d")),
		cub("Panou microunde", (0.1, 0.012, 0.22), (-3.66, BUC_Y1 - 0.436, FL + 1.08), p("5e5356")),
		cilindru("Fierbator", 0.08, 0.07, 0.2, (-5.4, BUC_Y1 - 0.3, FL + 1.04), ALB, laturi=8),
		cub("Maner fierbator", (0.03, 0.03, 0.15), (-5.4, BUC_Y1 - 0.2, FL + 1.06), NEGRU),
		cub("Suport cutite", (0.1, 0.14, 0.2), (BUC_X0 + 0.15, 5.6, FL + 1.04), LEMN_INCHIS, rot=(0, -0.3, 0)),
		cilindru("Prosoape", 0.06, 0.06, 0.26, (BUC_X0 + 0.15, 2.0, FL + 1.07), ALB, laturi=8),
		cilindru("Suport prosoape", 0.01, 0.01, 0.3, (BUC_X0 + 0.15, 2.0, FL + 1.09), NEGRU, laturi=4),
		cilindru("Fructiera", 0.14, 0.08, 0.06, (BUC_X0 + 0.3, 5.0, FL + 0.97), NEGRU, laturi=10),
	]
	for k in range(4):
		u = k * 1.5
		piese.append(sfera("Fruct", 0.04, (BUC_X0 + 0.3 + math.cos(u) * 0.06, 5.0 + math.sin(u) * 0.06, FL + 1.02 + (k == 3) * 0.04),
			p("7b383a") if k % 2 else p("a18463"), segmente=6, inele=4))
	for kk in range(3):
		piese.append(cub("Cutit", (0.012, 0.03, 0.09), (BUC_X0 + 0.13 + kk * 0.02, 5.58, FL + 1.18), NEGRU, rot=(0, -0.3, 0)))
	# --- masa cu cele patru scaune și lămpile suspendate
	mx, my = MASA
	piese.append(cub("Masa", (1.3, 0.85, 0.04), (mx, my, FL + 0.74), LEMN))
	for dx in (-0.58, 0.58):
		for dy in (-0.36, 0.36):
			piese.append(cub("Picior masa", (0.04, 0.04, 0.72), (mx + dx, my + dy, FL + 0.36), NEGRU))
	_scaun_modern(piese, LOC_LEXY_BUC[0], LOC_LEXY_BUC[1], 1.5708)
	# (capătul dinspre hol rămâne liber: de acolo o vezi pe Lexy)
	_scaun_modern(piese, mx - 0.25, my - 0.62, math.pi)
	_scaun_modern(piese, mx + 0.25, my + 0.62, 0.0)
	for dx in (-0.3, 0.3):
		piese.append(cilindru("Cablu", 0.004, 0.004, H - 1.55, (mx + dx, my, FL + 1.55 + (H - 1.55) / 2), NEGRU, laturi=4))
		piese.append(cilindru("Lampa", 0.16, 0.05, 0.16, (mx + dx, my, FL + 1.5), NEGRU, laturi=10))
		lumini.append(sfera("Bec", 0.05, (mx + dx, my, FL + 1.42), p("a18463"), segmente=6, inele=4))
	# pe masă: șervețele, o doză și o sticlă de suc
	piese += [
		cub("Servetele", (0.12, 0.08, 0.06), (mx + 0.45, my + 0.28, FL + 0.79), ALB),
		cilindru("Doza", 0.033, 0.033, 0.12, (mx - 0.2, my - 0.3, FL + 0.82), p("7b383a"), laturi=8),
		cilindru("Sticla", 0.04, 0.04, 0.22, (mx + 0.4, my - 0.2, FL + 0.87), p("2a3c3d"), laturi=8),
		cilindru("Dop", 0.015, 0.015, 0.04, (mx + 0.4, my - 0.2, FL + 1.0), p("7b383a"), laturi=6),
	]
	# ceasul de perete (modern, negru) deasupra golului spre hol
	piese.append(cilindru("Ceas", 0.15, 0.15, 0.03, (BUC_X1 - 0.02, 5.0, FL + 2.0), NEGRU, laturi=12, rot=(0, 1.5708, 0)))
	piese.append(cilindru("Cadran", 0.13, 0.13, 0.01, (BUC_X1 - 0.04, 5.0, FL + 2.0), ALB, laturi=12, rot=(0, 1.5708, 0)))
	piese.append(cub("Ac", (0.008, 0.008, 0.09), (BUC_X1 - 0.05, 5.0, FL + 2.03), NEGRU))
	piese.append(cub("Ac", (0.008, 0.07, 0.008), (BUC_X1 - 0.05, 4.97, FL + 2.0), NEGRU))
	# coliziunea: rândurile de dulapuri, frigiderul, masa, scaunele
	col = [
		cub("Coliziune", (ad + 0.03, BUC_Y1 - y0, 0.95), (BUC_X0 + (ad + 0.03) / 2, (y0 + BUC_Y1) / 2, FL + 0.475), NEGRU),
		cub("Coliziune", (x1 - x0 + 0.03, ad + 0.03, 0.95), ((x0 + x1 + 0.03) / 2, BUC_Y1 - (ad + 0.03) / 2, FL + 0.475), NEGRU),
		cub("Coliziune", (fx1 - fx0, 0.72, 1.9), ((fx0 + fx1) / 2, BUC_Y1 - 0.36, FL + 0.95), NEGRU),
		cub("Coliziune", (1.3, 0.85, 0.76), (mx, my, FL + 0.38), NEGRU),
	]
	for sx, sy in (LOC_LEXY_BUC, (mx - 0.25, my - 0.62), (mx + 0.25, my + 0.62)):
		col.append(cub("Coliziune", (0.46, 0.46, 0.9), (sx, sy, FL + 0.45), NEGRU))
	uneste(col, "Coliziune")
	uneste(piese, "Bucatarie")
	uneste(lumini, "Lumini")
	exporta(os.path.join(cale, "bucatarie_lexy.glb"))


def _felie(nume, u0, u1, raza, z, culoare, grosime=0.02):
	"""O felie de pizza (pană), din centrul (0, 0) între unghiurile u0 și u1."""
	pct = [(0.0, 0.0)] + [(math.cos(u0 + (u1 - u0) * k / 3) * raza, math.sin(u0 + (u1 - u0) * k / 3) * raza) for k in range(4)]
	bm = bmesh.new()
	jos = [bm.verts.new((x, y, z)) for x, y in pct]
	sus = [bm.verts.new((x, y, z + grosime)) for x, y in pct]
	bm.faces.new(jos)
	bm.faces.new(list(reversed(sus)))
	for i in range(len(pct)):
		bm.faces.new((jos[i], jos[(i + 1) % len(pct)], sus[(i + 1) % len(pct)], sus[i]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	me = bpy.data.meshes.new(nume)
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new(nume, me)
	bpy.context.scene.collection.objects.link(ob)
	_coloreaza(ob, culoare)
	return ob


def pizza(cale):
	"""Cutia de pizza deschisă (capacul ridicat, în spate) cu pizza cu salam: lipsesc trei felii (una e în mâna lui
	Lexy, vezi felie_pizza). Originea = fundul cutiei, la mijloc."""
	curata()
	piese = [
		cub("Cutie", (0.42, 0.42, 0.012), (0, 0, 0.006), ALB),
		cub("Margine", (0.42, 0.012, 0.04), (0, -0.204, 0.02), ALB),
		cub("Margine", (0.012, 0.396, 0.04), (-0.204, 0.0, 0.02), ALB),
		cub("Margine", (0.012, 0.396, 0.04), (0.204, 0.0, 0.02), ALB),
		cub("Capac", (0.42, 0.012, 0.42), (0, 0.22, 0.22), ALB, rot=(-0.15, 0, 0)),
		cub("Desen capac", (0.2, 0.004, 0.2), (0, 0.211, 0.25), p("7b383a"), rot=(-0.15, 0, 0)),
	]
	felii = 8
	for k in range(felii):
		if k in (2, 3, 4):
			continue
		u0 = k * math.tau / felii + 0.02
		u1 = (k + 1) * math.tau / felii - 0.02
		piese.append(_felie("Felie", u0, u1, 0.18, 0.012, p("a18463")))
		um = (u0 + u1) / 2
		for d, du in ((0.07, 0.0), (0.13, 0.12), (0.12, -0.15)):
			piese.append(cilindru("Salam", 0.018, 0.018, 0.006, (math.cos(um + du) * d, math.sin(um + du) * d, 0.035), p("7b383a"), laturi=8))
		# marginea (coaja), puțin mai înaltă
		piese.append(_felie("Coaja", u0, u1, 0.185, 0.012, p("a56850"), grosime=0.016))
	uneste(piese, "Pizza")
	exporta(os.path.join(cale, "pizza.glb"))


def felie_pizza(cale):
	"""Felia din mâna lui Lexy: originea la coajă (o ține de acolo), vârful spre +X. Se tot micșorează cât mănâncă."""
	curata()
	piese = [
		trunchi("Felie", [((0.0, 0, 0), 0.008, 0.06), ((0.09, 0, -0.008), 0.006, 0.035), ((0.17, 0, -0.02), 0.003, 0.004)],
			p("a18463"), laturi=8, ref=(0, 0, 1)),
		trunchi("Coaja", [((-0.015, 0, 0), 0.016, 0.062), ((0.01, 0, 0), 0.016, 0.064)], p("a56850"), laturi=6, ref=(0, 0, 1)),
	]
	for x, y in ((0.05, 0.02), (0.1, -0.012), (0.06, -0.03)):
		piese.append(cilindru("Salam", 0.012, 0.012, 0.004, (x, y, 0.006 - x * 0.08), p("7b383a"), laturi=6))
	uneste(piese, "FeliePizza")
	exporta(os.path.join(cale, "felie_pizza.glb"))


def joint(cale):
	"""Jointul: hârtie albă răsucită, cu filtrul de carton (originea, unde îl ții) și vârful aprins (`Jar`, separat:
	strălucește când tragi din el). Lung pe +X (10 cm)."""
	curata()
	uneste([
		trunchi("Joint", [((0.0, 0, 0), 0.0045, 0.0045), ((0.03, 0, 0), 0.0055, 0.0055), ((0.095, 0, 0), 0.0075, 0.0075)], ALB, laturi=6),
		cilindru("Filtru", 0.0047, 0.0047, 0.022, (0.011, 0, 0), p("a18463"), laturi=6, rot=(0, 1.5708, 0)),
		trunchi("Scrum", [((0.093, 0, 0), 0.0074, 0.0074), ((0.099, 0, 0), 0.0072, 0.0072)], p("70706e"), laturi=6),
	], "Joint")
	uneste([trunchi("Jar", [((0.098, 0, 0), 0.0068, 0.0068), ((0.104, 0, 0), 0.0045, 0.0045), ((0.106, 0, 0), 0.0, 0.0)],
		p("904a40"), laturi=6)], "Jar")
	exporta(os.path.join(cale, "joint.glb"))


# Bancnota de 5 dolari, „pixel art” din cutii lipite una de alta (fără plăci suprapuse: n-are z-fighting):
# B = rama, . = hârtia, - = linia din ramă, O = ovalul, P = fundalul portretului, F = fața, N = cifra 5, s = sigiliul
_HARTA_BANCNOTA = [
	"BBBBBBBBBBBBBBBBBB",
	"BNN..-.OOOO.-..NNB",
	"BN....OPPPPO.....B",
	"B.ss..OPFFPO..ss.B",
	"B.ss..OPFFPO..ss.B",
	"B.....OPPPPO....NB",
	"BNN..-.OOOO.-..NNB",
	"BBBBBBBBBBBBBBBBBB",
]


def bancnota(cale):
	"""Bancnota de 5 dolari pe care ți-o dă Lexy (15,6 × 6,6 cm), culcată în planul XY, cu originea în mijloc.
	Desenul (rama, ovalul cu portretul, cifrele din colțuri, sigiliile) e făcut din cutii una lângă alta,
	toate la fel de groase, ca să se vadă și de aproape, la rezoluția mică a jocului."""
	curata()
	culori = {"B": p("445d46"), ".": p("7e8d87"), "-": p("5b6d4e"), "O": p("32453b"), "P": p("5b6d4e"),
		"F": p("7a7b59"), "N": p("32453b"), "s": p("438b88")}
	randuri = len(_HARTA_BANCNOTA)
	coloane = len(_HARTA_BANCNOTA[0])
	lat, inalt, gros = 0.156, 0.066, 0.0012
	cx, cy = lat / coloane, inalt / randuri
	piese = []
	for r, rand in enumerate(_HARTA_BANCNOTA):
		# celulele de aceeași culoare de pe un rând se lipesc într-o singură cutie
		c = 0
		while c < coloane:
			k = c
			while k + 1 < coloane and rand[k + 1] == rand[c]:
				k += 1
			x = -lat / 2 + (c + k + 1) * cx / 2
			y = inalt / 2 - (r + 0.5) * cy
			piese.append(cub("Bancnota", ((k - c + 1) * cx, cy, gros), (x, y, 0), culori[rand[c]]))
			c = k + 1
	uneste(piese, "Bancnota")
	exporta(os.path.join(cale, "bancnota.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Strada și cimitirul de vizavi
# ---------------------------------------------------------------------------------------------------------------

def gard_fier(cale):
	"""O bucată de gard de fier forjat (2,4 m, pe X, de la 0 la 2,4): stâlp pătrat cu bilă, bare cu vârfuri de suliță.
	Se pun cap la cap (stâlpul de la capătul 2,4 e al bucății următoare)."""
	curata()
	piese = [
		cub("Stalp", (0.09, 0.09, 1.55), (0, 0, 0.775), NEGRU),
		sfera("Bila", 0.065, (0, 0, 1.6), NEGRU, segmente=6, inele=4),
		cub("Bara", (2.4, 0.03, 0.03), (1.2, 0, 0.25), NEGRU),
		cub("Bara", (2.4, 0.03, 0.03), (1.2, 0, 1.25), NEGRU),
	]
	for k in range(1, 20):
		x = k * 0.12
		piese.append(cub("Zabrea", (0.018, 0.018, 1.33), (x, 0, 0.74), NEGRU))
		piese.append(cilindru("Sulita", 0.022, 0.0, 0.08, (x, 0, 1.44), NEGRU, laturi=4))
		if k % 2:
			piese.append(cub("Romb", (0.05, 0.012, 0.05), (x + 0.06, 0, 1.12), NEGRU, rot=(0, 0.785, 0)))
	uneste(piese, "Gard")
	exporta(os.path.join(cale, "gard_fier.glb"))


def poarta_cimitir(cale):
	"""Poarta cimitirului: doi stâlpi de piatră cu capac, arcul de fier cu o cruce în vârf și două porți închise
	(lanț cu lacăt). Golul are 2 m, centrat în origine, pe X."""
	curata()
	piese = []
	for s in (-1, 1):
		x = s * 1.25
		piese += [
			cub("Stalp poarta", (0.5, 0.5, 2.3), (x, 0, 1.15), PIATRA),
			cub("Capac stalp", (0.6, 0.6, 0.1), (x, 0, 2.35), PIATRA_DESCHISA),
			cilindru("Bila stalp", 0.15, 0.1, 0.25, (x, 0, 2.52), PIATRA_DESCHISA, laturi=8),
			cub("Muschi", (0.5, 0.02, 0.4), (x, -0.255, 0.35), MUSCHI),
		]
		# poarta: două foi, închise
		for k in range(8):
			xx = s * (0.07 + k * 0.125)
			piese.append(cub("Zabrea", (0.02, 0.02, 1.9), (xx, 0, 1.0), NEGRU))
			piese.append(cilindru("Sulita", 0.025, 0.0, 0.09, (xx, 0, 2.0), NEGRU, laturi=4))
		piese.append(cub("Bara poarta", (0.98, 0.03, 0.04), (s * 0.5, 0, 0.3), NEGRU))
		piese.append(cub("Bara poarta", (0.98, 0.03, 0.04), (s * 0.5, 0, 1.75), NEGRU))
	# arcul de fier și crucea
	for k in range(13):
		u = math.pi * k / 12
		piese.append(cub("Arc fier", (0.14, 0.03, 0.03), (math.cos(u) * 1.0, 0, 2.3 + math.sin(u) * 0.6), NEGRU, rot=(0, -u + 1.5708, 0)))
	piese += [
		cub("Cruce", (0.03, 0.03, 0.5), (0, 0, 3.1), NEGRU),
		cub("Cruce", (0.3, 0.03, 0.03), (0, 0, 3.2), NEGRU),
		cub("Lant", (0.05, 0.04, 0.2), (0, -0.03, 1.1), p("70706e")),
		cub("Lacat", (0.07, 0.04, 0.08), (0, -0.05, 0.98), p("a18463")),
	]
	uneste(piese, "Poarta")
	exporta(os.path.join(cale, "poarta_cimitir.glb"))


def morminte(cale):
	"""Trei pietre de mormânt (fiecare în fișierul ei), cu movila de pământ în față (iarbă rară, mușchi pe piatră):
	mormant_1 = piatră rotunjită cu R.I.P.; mormant_2 = cruce celtică; mormant_3 = obelisc pe soclu.
	Originea = solul, la piatră; movila spre -Y."""
	for nume in ("mormant_1", "mormant_2", "mormant_3"):
		curata()
		piese = [
			sfera("Movila", 0.5, (0, -0.85, -0.05), PAMANT, scara=(0.75, 1.5, 0.3), segmente=8, inele=5),
			sfera("Iarba", 0.4, (0.05, -0.9, -0.02), MUSCHI, scara=(0.7, 1.3, 0.25), segmente=7, inele=4),
		]
		if nume == "mormant_1":
			piese += [
				cub("Piatra", (0.6, 0.15, 0.55), (0, 0, 0.275), PIATRA),
				cilindru("Piatra", 0.3, 0.3, 0.12, (0, 0, 0.55), PIATRA, laturi=12, rot=(1.5708, 0, 0)),
				cub("Soclu", (0.75, 0.25, 0.1), (0, 0, 0.05), PIATRA_DESCHISA),
				text("Scris", "R.I.P.", (0, -0.064, 0.66), 0.1, NEGRU),
				cub("Linie", (0.4, 0.01, 0.015), (0, -0.078, 0.45), NEGRU),
				cub("Linie", (0.3, 0.01, 0.015), (0, -0.078, 0.38), NEGRU),
				cub("Muschi", (0.25, 0.02, 0.18), (0.15, -0.08, 0.15), MUSCHI),
				cub("Crapatura", (0.012, 0.01, 0.3), (-0.17, -0.078, 0.5), NEGRU, rot=(0, 0.4, 0)),
			]
		elif nume == "mormant_2":
			piese += [
				cub("Cruce", (0.18, 0.14, 1.3), (0, 0, 0.75), PIATRA_DESCHISA),
				cub("Cruce", (0.75, 0.12, 0.18), (0, 0, 1.05), PIATRA_DESCHISA),
				cub("Soclu", (0.5, 0.35, 0.15), (0, 0, 0.075), PIATRA),
				cub("Muschi", (0.19, 0.02, 0.35), (0, -0.075, 0.35), MUSCHI),
			]
			# inelul crucii celtice, din cutii pe cerc (inel() e culcat)
			for k in range(16):
				u = k * math.tau / 16
				piese.append(cub("Inel cruce", (0.06, 0.12, 0.1), (math.cos(u) * 0.24, 0, 1.05 + math.sin(u) * 0.24), PIATRA_DESCHISA,
					rot=(0, -u, 0)))
		else:
			piese += [
				cub("Soclu", (0.6, 0.6, 0.35), (0, 0, 0.175), PIATRA),
				cub("Soclu", (0.5, 0.5, 0.1), (0, 0, 0.4), PIATRA_DESCHISA),
				cilindru("Obelisc", 0.2, 0.12, 1.4, (0, 0, 1.15), PIATRA, laturi=4, rot=(0, 0, 0.785)),
				cilindru("Varf obelisc", 0.12, 0.0, 0.2, (0, 0, 1.95), PIATRA, laturi=4, rot=(0, 0, 0.785)),
				cub("Placa", (0.3, 0.01, 0.2), (0, -0.305, 0.2), NEGRU),
				cub("Muschi", (0.6, 0.02, 0.12), (0, -0.305, 0.06), MUSCHI),
			]
		uneste(piese, "Mormant")
		exporta(os.path.join(cale, nume + ".glb"))


def cripta(cale):
	"""Cripta din fundul cimitirului: piatră înnegrită, două coloane, ușa de fier în arc ascuțit, fronton cu o cruce,
	trepte tocite, mușchi și o coroană de flori uscate. Originea = solul, la mijloc; fața spre -Y."""
	curata()
	pd, pi_ = p("5e5356"), p("6f6d7f")
	piese = [
		cub("Corp", (2.6, 3.0, 2.6), (0, 0.3, 1.3), pd),
		cub("Treapta", (2.0, 0.4, 0.12), (0, -1.4, 0.06), pi_),
		cub("Treapta", (1.7, 0.3, 0.24), (0, -1.25, 0.12), pi_),
		cub("Prag", (1.4, 0.2, 0.3), (0, -1.15, 0.15), pi_),
		prisma("Acoperis", [(-1.5, 2.6), (1.5, 2.6), (0, 3.6)], "xz", -1.35, 1.95, p("48313b")),
		prisma("Fronton", [(-1.35, 2.6), (1.35, 2.6), (0, 3.5)], "xz", -1.32, -1.2, pi_),
		cub("Cruce", (0.08, 0.08, 0.6), (0, -1.25, 3.85), pi_),
		cub("Cruce", (0.36, 0.08, 0.08), (0, -1.25, 3.95), pi_),
		cub("Brau", (2.7, 3.1, 0.12), (0, 0.3, 2.56), pi_),
	]
	for x in (-0.95, 0.95):
		piese += [
			cilindru("Coloana", 0.12, 0.12, 2.3, (x, -1.25, 1.27), pi_, laturi=8),
			cub("Capitel", (0.32, 0.32, 0.12), (x, -1.25, 2.46), pi_),
			cub("Baza", (0.32, 0.32, 0.12), (x, -1.25, 0.2), pi_),
		]
	# ușa de fier în arc ascuțit, cu gratii
	piese.append(cub("Usa cripta", (1.0, 0.04, 1.7), (0, -1.21, 1.15), NEGRU))
	piese.append(prisma("Usa arc", [(-0.5, 2.0), (0.5, 2.0), (0, 2.45)], "xz", -1.23, -1.19, NEGRU))
	for k in range(5):
		piese.append(cub("Gratie", (0.025, 0.03, 1.4), (-0.32 + k * 0.16, -1.245, 1.25), p("5e5356")))
	piese += [
		text("Nume", "1888", (0, -1.335, 2.85), 0.15, NEGRU, rot=(1.5708, 0, 0)),
		cub("Muschi", (0.45, 0.02, 0.5), (0.85, -1.205, 0.6), MUSCHI),
		cub("Muschi", (0.02, 1.2, 0.8), (1.305, 0.0, 0.5), MUSCHI),
	]
	for k in range(10):  # coroana de flori uscate rezemată de ușă
		u = k * math.tau / 10
		piese.append(sfera("Coroana", 0.06, (0.35 + math.cos(u) * 0.2, -1.32, 0.55 + math.sin(u) * 0.2),
			p("5e363e") if k % 2 else p("7a7b59"), segmente=5, inele=3))
	uneste(piese, "Cripta")
	exporta(os.path.join(cale, "cripta.glb"))


def cutie_posta(cale):
	"""Cutia poștală americană de lângă poartă: neagră, pe un stâlp de lemn, cu stegulețul roșu ridicat."""
	curata()
	uneste([
		cub("Stalp cutie", (0.08, 0.08, 1.05), (0, 0, 0.525), LEMN_INCHIS),
		cub("Cutie", (0.2, 0.48, 0.18), (0, -0.05, 1.14), NEGRU),
		cilindru("Cutie", 0.1, 0.1, 0.48, (0, -0.05, 1.23), NEGRU, laturi=10, rot=(1.5708, 0, 0)),
		cub("Steag", (0.012, 0.03, 0.2), (0.11, 0.05, 1.32), p("7b383a")),
		cub("Steag", (0.012, 0.08, 0.05), (0.11, 0.02, 1.4), p("7b383a")),
		text("Nume", "13", (-0.106, -0.05, 1.15), 0.06, ALB, rot=(1.5708, 0, -1.5708)),
	], "CutiePosta")
	exporta(os.path.join(cale, "cutie_posta.glb"))


def strada_lexy(cale):
	"""Strada din fața casei (pe X, 160 m): asfalt crăpat cu linia galbenă întreruptă la mijloc, borduri, trotuare,
	trecerea de pietoni dintre stație și casă. Originea = mijlocul străzii (y = 0 în Godot e la z 13,5)."""
	curata()
	r = random.Random(4)
	piese = [
		cub("Asfalt", (160, 7.0, 0.04), (0, 0, 0.02), p("5e5356")),
		cub("Trotuar", (160, 1.85, 0.14), (0, -4.575, 0.07), FUNDATIE),
		cub("Trotuar", (160, 2.35, 0.14), (0, 4.825, 0.07), FUNDATIE),
		cub("Bordura", (160, 0.15, 0.16), (0, -3.575, 0.08), PIATRA_DESCHISA),
		cub("Bordura", (160, 0.15, 0.16), (0, 3.575, 0.08), PIATRA_DESCHISA),
	]
	for k in range(40):
		x = -78 + k * 4
		if abs(x) < 3.5:
			continue  # trecerea de pietoni
		piese.append(cub("Linie", (2.0, 0.1, 0.012), (x, 0, 0.046), p("a18463")))
	for k in range(8):  # trecerea de pietoni: dungi lungi în lungul străzii, una sub alta de la un trotuar la celălalt
		piese.append(cub("Zebra", (2.6, 0.45, 0.012), (0, -3.15 + k * 0.9, 0.046), ALB))
	for k in range(25):  # crăpături și petice în asfalt
		x, y = r.uniform(-60, 60), r.uniform(-3, 3)
		if -3 < x < 3:
			continue
		piese.append(cub("Crapatura", (r.uniform(0.6, 2.0), 0.03, 0.01), (x, y, 0.045), NEGRU, rot=(0, 0, r.uniform(-0.6, 0.6))))
	for k in range(6):
		x = r.uniform(-40, 40)
		if -4 < x < 4:
			continue
		piese.append(cub("Petic", (r.uniform(0.8, 1.6), r.uniform(0.5, 1.2), 0.008), (x, r.choice((-1, 1)) * r.uniform(0.9, 2.5), 0.044), p("48313b")))
	for k in range(80):  # rosturile trotuarelor
		x = -79 + k * 2
		piese.append(cub("Rost", (0.02, 1.85, 0.01), (x, -4.575, 0.145), PIATRA))
		piese.append(cub("Rost", (0.02, 2.35, 0.01), (x, 4.825, 0.145), PIATRA))
	# coliziunea: asfaltul și trotuarele (cu bordurile), netede: crăpăturile, peticele și rosturile n-au
	uneste([
		cub("Coliziune", (160, 7.0, 0.04), (0, 0, 0.02), NEGRU),
		cub("Coliziune", (160, 2.0, 0.14), (0, -4.5, 0.07), NEGRU),
		cub("Coliziune", (160, 2.5, 0.14), (0, 4.75, 0.07), NEGRU),
	], "Coliziune")
	uneste(piese, "Strada")
	exporta(os.path.join(cale, "strada_lexy.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Lexy
# ---------------------------------------------------------------------------------------------------------------

PIELE = p("a56850")
PIELE_UMBRA = p("904a40")
PAR = p("a18463")
PAR_UMBRA = p("a56850")
SPRANCENE = p("5e363e")
HANORAC = p("438b88")
HANORAC_UMBRA = p("30716f")
PANTALONI = p("70706e")
SOSETE = ALB

# încheieturile (în picioare, fața spre -Y); dreapta ei e -X
SOLD = 0.86
GENUNCHI = 0.47
UMAR_Z = 1.37
GAT_Z = 1.43


def _mana_lexy(piese, inch, s, deget_jos=True):
	"""Mâna: palma, degetele strânse (ține ceva între arătător și degetul mare), unghii roșu închis.
	`s` = -1 dreapta, 1 stânga."""
	x, y, z = inch
	piese += [
		sfera("Palma", 0.036, (x, y - 0.012, z - 0.045), PIELE, scara=(0.55, 0.95, 1.15), segmente=6, inele=4),
		trunchi("Degete", [((x, y - 0.03, z - 0.07), 0.016, 0.03), ((x, y - 0.045, z - 0.1), 0.014, 0.026),
			((x, y - 0.05, z - 0.115), 0.0, 0.0)], PIELE, laturi=5, ref=(1, 0, 0)),
		os_intre("Deget mare", (x - s * 0.018, y - 0.02, z - 0.04), (x - s * 0.012, y - 0.055, z - 0.075), 0.009, PIELE, laturi=4),
		cub("Unghii", (0.022, 0.008, 0.01), (x, y - 0.062, z - 0.106), p("7b383a"), rot=(0.6, 0, 0)),
	]


def lexy(cale):
	"""Lexy: blondă (coc ciufulit, două șuvițe pe față, rădăcini mai închise), hanorac teal larg cu gluga pe spate și
	un craniu mic pe piept, pantaloni de trening gri, șosete albe pufoase. Ochi grei (e mereu un pic high), tuș cu
	„aripioare”, buze roșu închis, cercel în nas și cercei-inel. Modelată în picioare, fața spre -Y.
	Piese (pentru animații din Godot, vezi lexy.gd):
	  `Corp` (originea în bazin, la 0,9 m) cu copiii: `Cap` (originea în gât), `BratD`/`BratS` (umăr) cu
	  `AntebratD`/`AntebratS` (cot; mâna e pe antebraț); `CoapsaD`/`CoapsaS` (șold, frați cu `Corp`) cu
	  `GambaD`/`GambaS` (genunchi). Dreapta ei = -X (D), stânga = +X (S)."""
	curata()
	piese = []
	# --- bazinul (pantalonii) și hanoracul larg
	piese.append(trunchi("Sold", [((0, 0.01, 0.78), 0.14, 0.11), ((0, 0.012, 0.84), 0.165, 0.125), ((0, 0.005, 0.92), 0.158, 0.115),
		((0, 0, 0.98), 0.14, 0.1)], PANTALONI, laturi=10))
	piese.append(trunchi("Hanorac", [
		((0, 0.0, 0.875), 0.19, 0.142), ((0, 0.0, 0.93), 0.192, 0.143), ((0, -0.002, 1.02), 0.183, 0.135),
		((0, -0.008, 1.13), 0.19, 0.138), ((0, -0.002, 1.25), 0.198, 0.132), ((0, 0.008, 1.34), 0.19, 0.12),
		((0, 0.01, 1.4), 0.12, 0.085), ((0, 0.008, 1.44), 0.068, 0.06),
	], HANORAC, laturi=12))
	piese.append(trunchi("Tiv", [((0, 0.0, 0.865), 0.196, 0.147), ((0, 0.0, 0.915), 0.197, 0.148)], HANORAC_UMBRA, laturi=12))
	piese += [
		cub("Buzunar", (0.22, 0.012, 0.11), (0, -0.142, 1.0), HANORAC_UMBRA, rot=(0.08, 0, 0)),
		sfera("Gluga", 0.13, (0, 0.13, 1.35), HANORAC, scara=(1.1, 0.55, 0.75), segmente=8, inele=5),
		sfera("Gluga", 0.1, (0, 0.11, 1.4), HANORAC_UMBRA, scara=(1.0, 0.5, 0.5), segmente=6, inele=4),
		os_intre("Snur", (-0.045, -0.12, 1.36), (-0.05, -0.145, 1.2), 0.005, ALB, laturi=4),
		os_intre("Snur", (0.045, -0.12, 1.36), (0.052, -0.143, 1.22), 0.005, ALB, laturi=4),
		cub("Capat snur", (0.012, 0.012, 0.02), (-0.05, -0.147, 1.19), NEGRU),
		cub("Capat snur", (0.012, 0.012, 0.02), (0.052, -0.145, 1.21), NEGRU),
		# craniul mic de pe piept (imprimeu)
		sfera("Imprimeu", 0.032, (0.07, -0.135, 1.24), ALB, scara=(1, 0.25, 1), segmente=6, inele=4),
		cub("Imprimeu", (0.026, 0.008, 0.016), (0.07, -0.141, 1.212), ALB),
		cub("Imprimeu", (0.01, 0.006, 0.01), (0.058, -0.143, 1.245), NEGRU),
		cub("Imprimeu", (0.01, 0.006, 0.01), (0.082, -0.143, 1.245), NEGRU),
	]
	ob_corp = uneste(piese, "Corp", (0, 0, 0.9))

	# --- brațele: mâneci largi, manșete mai închise, mâinile
	for s, nume in ((-1, "D"), (1, "S")):
		umar, cot, inch = (0.165 * s, 0.0, UMAR_Z), (0.205 * s, 0.025, 1.115), (0.215 * s, -0.01, 0.875)
		brat = [
			sfera("Umar", 0.056, umar, HANORAC, segmente=8, inele=5),
			trunchi("Maneca", [(umar, 0.055, 0.055), ((0.19 * s, 0.012, 1.25), 0.06, 0.058), (cot, 0.055, 0.054)], HANORAC,
				laturi=8, ref=(0, 1, 0)),
		]
		ob_brat = uneste(brat, "Brat" + nume, umar)
		antebrat = [
			sfera("Cot", 0.054, cot, HANORAC, segmente=8, inele=5),
			trunchi("Maneca", [(cot, 0.054, 0.053), ((0.212 * s, 0.008, 1.0), 0.053, 0.05), (inch, 0.05, 0.048)], HANORAC,
				laturi=8, ref=(0, 1, 0)),
			trunchi("Manseta", [((0.215 * s, -0.008, 0.9), 0.045, 0.043), ((0.216 * s, -0.011, 0.865), 0.044, 0.042)],
				HANORAC_UMBRA, laturi=8, ref=(0, 1, 0)),
		]
		_mana_lexy(antebrat, (0.216 * s, -0.012, 0.865), s)
		ob_antebrat = uneste(antebrat, "Antebrat" + nume, cot)
		_parinte_obiect(ob_antebrat, ob_brat)
		_parinte_obiect(ob_brat, ob_corp)

	# --- picioarele: coapsă (șold), gambă (genunchi) cu șoseta și laba piciorului
	for s, nume in ((-1, "D"), (1, "S")):
		x = 0.088 * s
		coapsa = [trunchi("Coapsa", [((x, 0.005, 0.9), 0.082, 0.085), ((x, 0.0, SOLD), 0.08, 0.082), ((x, -0.008, 0.66), 0.068, 0.07),
			((x, -0.01, GENUNCHI + 0.01), 0.058, 0.06)], PANTALONI, laturi=8)]
		ob_coapsa = uneste(coapsa, "Coapsa" + nume, (x, 0.0, SOLD))
		gamba = [
			sfera("Genunchi", 0.06, (x, -0.012, GENUNCHI), PANTALONI, segmente=8, inele=5),
			trunchi("Gamba", [((x, -0.012, GENUNCHI), 0.057, 0.058), ((x, -0.004, 0.28), 0.052, 0.052), ((x, 0.0, 0.14), 0.046, 0.046)],
				PANTALONI, laturi=8),
			trunchi("Manseta", [((x, 0.0, 0.15), 0.044, 0.044), ((x, 0.0, 0.1), 0.04, 0.04)], p("5e5356"), laturi=8),
			trunchi("Soseta", [((x, 0.0, 0.11), 0.037, 0.037), ((x, 0.0, 0.05), 0.04, 0.042)], SOSETE, laturi=8),
			trunchi("Laba", [((x, 0.035, 0.035), 0.038, 0.03), ((x, -0.04, 0.03), 0.044, 0.032), ((x, -0.13, 0.025), 0.04, 0.026),
				((x, -0.165, 0.022), 0.0, 0.0)], SOSETE, laturi=8, ref=(1, 0, 0)),
		]
		ob_gamba = uneste(gamba, "Gamba" + nume, (x, -0.012, GENUNCHI))
		_parinte_obiect(ob_gamba, ob_coapsa)

	# --- capul
	cap = [os_intre("Gat", (0, 0.005, 1.4), (0, -0.008, 1.5), 0.037, PIELE, laturi=6)]
	fata = [  # (z, y-ul centrului, rx, ry): față tânără, rotunjită, bărbie mică
		(1.476, -0.052, 0.0, 0.0), (1.482, -0.055, 0.022, 0.02), (1.5, -0.048, 0.044, 0.044), (1.53, -0.034, 0.06, 0.066),
		(1.565, -0.024, 0.07, 0.08), (1.6, -0.019, 0.074, 0.086), (1.635, -0.017, 0.073, 0.085), (1.665, -0.012, 0.063, 0.076),
		(1.69, -0.005, 0.04, 0.052), (1.705, 0.0, 0.0, 0.0),
	]
	cap.append(trunchi("Fata", [((0, y, z), rx, ry) for z, y, rx, ry in fata], PIELE, laturi=12))
	cap += [
		trunchi("Nas", [((0, -0.098, 1.605), 0.009, 0.008), ((0, -0.114, 1.578), 0.012, 0.011), ((0, -0.117, 1.565), 0.011, 0.009),
			((0, -0.106, 1.557), 0.0, 0.0)], PIELE, laturi=6),
		cub("Cercel nas", (0.005, 0.006, 0.005), (0.012, -0.112, 1.562), p("a18463")),
		cub("Buza sus", (0.032, 0.012, 0.008), (0, -0.101, 1.537), p("7b383a")),
		cub("Buza jos", (0.034, 0.012, 0.01), (0, -0.098, 1.527), p("7b383a")),
		cub("Gura", (0.026, 0.008, 0.003), (0, -0.106, 1.5325), p("48313b")),
	]
	for s in (-1, 1):
		x = 0.031 * s
		cap += [
			cub("Ochi", (0.024, 0.006, 0.012), (x, -0.1, 1.598), ALB),
			cub("Iris", (0.011, 0.006, 0.011), (x - 0.002 * s, -0.103, 1.597), p("295555")),
			# pleoapa grea (e high): acoperă jumătatea de sus a ochiului
			cub("Pleoapa", (0.028, 0.009, 0.008), (x, -0.104, 1.6035), PIELE),
			cub("Tus", (0.03, 0.006, 0.003), (x, -0.108, 1.599), NEGRU),
			cub("Aripioara", (0.012, 0.006, 0.003), (x + 0.018 * s, -0.104, 1.6015), NEGRU, rot=(0, 0.45 * s, 0)),
			cub("Spranceana", (0.032, 0.008, 0.006), (x + 0.002 * s, -0.103, 1.624), SPRANCENE, rot=(0, -0.12 * s, 0)),
			sfera("Obraz", 0.012, (0.045 * s, -0.083, 1.567), PIELE_UMBRA, scara=(1, 0.3, 0.6), segmente=6, inele=4),
			trunchi("Ureche", [((0.071 * s, -0.005, 1.6), 0.008, 0.016), ((0.08 * s, 0.0, 1.585), 0.006, 0.014),
				((0.078 * s, 0.003, 1.56), 0.0, 0.0)], PIELE, laturi=4),
		]
		for k in range(8):  # cerceii-inel
			u = k * math.tau / 8
			cap.append(cub("Cercel", (0.006, 0.006, 0.006), (0.081 * s, -0.004 + math.cos(u) * 0.012, 1.548 + math.sin(u) * 0.012),
				p("a18463")))
	# părul: strâns la spate, cărare pe mijloc, coc ciufulit sus, două șuvițe care cad pe lângă față
	cap += [
		sfera("Par", 0.088, (0, 0.006, 1.636), PAR, scara=(1.0, 1.08, 1.0), segmente=12, inele=8),
		cub("Carare", (0.006, 0.09, 0.006), (0, -0.03, 1.722), PAR_UMBRA, rot=(0.35, 0, 0)),
		sfera("Coc", 0.055, (0, 0.045, 1.738), PAR, segmente=8, inele=6),
		sfera("Coc", 0.03, (0.04, 0.03, 1.765), PAR_UMBRA, segmente=6, inele=4),
		sfera("Coc", 0.032, (-0.035, 0.07, 1.77), PAR, segmente=6, inele=4),
		sfera("Coc", 0.025, (0.0, 0.09, 1.72), PAR_UMBRA, segmente=6, inele=4),
		inel("Elastic", 0.04, 0.009, (0, 0.04, 1.705), p("7b383a"), segmente=8),
	]
	for s in (-1, 1):
		cap.append(trunchi("Suvita", [((0.06 * s, -0.07, 1.67), 0.012, 0.008), ((0.075 * s, -0.085, 1.61), 0.011, 0.007),
			((0.078 * s, -0.08, 1.54), 0.008, 0.005), ((0.074 * s, -0.07, 1.5), 0.0, 0.0)], PAR, laturi=4, ref=(1, 0, 0)))
		cap.append(trunchi("Suvita", [((0.05 * s, 0.07, 1.7), 0.01, 0.006), ((0.07 * s, 0.09, 1.66), 0.009, 0.005),
			((0.065 * s, 0.1, 1.62), 0.0, 0.0)], PAR_UMBRA, laturi=4, ref=(1, 0, 0)))
	ob_cap = uneste(cap, "Cap", (0, 0, GAT_Z))
	_parinte_obiect(ob_cap, ob_corp)
	exporta(os.path.join(cale, "lexy.glb"))


def _parinte_obiect(copil, parinte):
	copil.parent = parinte
	copil.matrix_parent_inverse = parinte.matrix_world.inverted()


def toate(cale):
	casa_lexy(cale)
	usa_lexy(cale)
	canapea(cale)
	masuta(cale)
	scrumiera(cale)
	televizor(cale)
	lampadar(cale)
	decor_living(cale)
	bucatarie_lexy(cale)
	pizza(cale)
	felie_pizza(cale)
	joint(cale)
	bancnota(cale)
	gard_fier(cale)
	poarta_cimitir(cale)
	morminte(cale)
	cripta(cale)
	cutie_posta(cale)
	strada_lexy(cale)
	lexy(cale)


if __name__ == "__main__":
	cale_modele = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")
	if "--" in sys.argv:  # doar unele: blender ... --python lexy.py -- lexy canapea
		for nume in sys.argv[sys.argv.index("--") + 1:]:
			globals()[nume](cale_modele)
	else:
		toate(cale_modele)
