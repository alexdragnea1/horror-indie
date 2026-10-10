# Primăria („TOWN HALL”, primarie.tscn): o primărie de la țară din România, în ziua de după Warlock. Clădirea veche cu
# tencuială galbenă scorojită (pe alocuri se vede cărămida), soclu gri, acoperiș de tablă ruginită, corpul din mijloc cu
# etaj și fronton (ceasul oprit, „TOWN HALL” sus), aripile joase cu frontoane spre stradă, copertina pe doi stâlpi peste
# intrare. În față grădina sărăcăcioasă: gard verde de fier pe soclu de beton, poarta deschisă, alee de dale crăpate,
# straturi de flori în cauciucuri vopsite alb, pomi cu tulpina văruită, bancă, avizier, iarbă uscată și pământ.
# Peste drum: case de țară cu gard de lemn, fântână cu cumpănă, stâlpi de beton cu fire, biserica în ceață.
# Înăuntru, la parter: holul cu linoleum în carouri, pereții vopsiți în ulei pe jumătate, ghișeul „INFORMATION” cu geam
# (și funcționara, `angajata`), ușile birourilor, scaune legate, avizierul, afișul „VOTE SMEGMA”, scara spre etaj.
# La etaj doar holul și biroul primarului, oval, ca Oval Office-ul (fără steag american): covorul cu pecetea, biroul
# masiv în fața celor trei ferestre cu draperii aurii, canapelele, șemineul cu portretul primarului, biblioteci, ceasul.
#   blender --background --factory-startup --python tools/blender/primarie.py              (toate)
#   blender --background --factory-startup --python tools/blender/primarie.py -- interior  (doar unele)
# Axe Blender: Z în sus, fațada spre -Y (în Godot +Z, spre stradă), clădirea spre +Y. Originea = mijlocul fațadei, la sol.
# Piese: `Cladire`/`Interior`/`Curte`, `Lumini` (ce strălucește), `Geamuri` (sticlă), `Coliziune` (nu se vede).
import math
import os
import random
import sys

import bpy
import bmesh

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, uneste, exporta, _coloreaza, desparte_fete  # noqa: E402
from lexy import perete, prisma  # noqa: E402
from casino import _text, _text_o_fata, _tor, _cutie_coliziune  # noqa: E402
from coven import _parinte  # noqa: E402
import casino_oameni  # noqa: E402

NEGRU = p("262d2f")
ALB = p("83b3b0")
AUR = p("a18463")
CROM = p("7e8d87")
METAL = p("6f6d7f")
METAL_INCHIS = p("5e5356")
GEAM = p("2a3c3d")
LEMN = p("5e363e")
LEMN_INCHIS = p("48313b")
LEMN_DESCHIS = p("904a40")
ROSU = p("7b383a")
BETON = p("70706e")
GALBEN = p("a18463")       # tencuiala galbenă a primăriei
BRONZ = p("a56850")
VERDE = p("5b6d4e")
VERDE_INCHIS = p("445d46")
MASLINIU = p("7a7b59")
TEAL = p("438b88")
TEAL_DESCHIS = p("61a19f")
PETROL = p("295555")
PETROL_DESCHIS = p("30716f")
GRI_ALBASTRU = p("778c96")
MOV = p("655269")
MOV_INCHIS = p("553e4d")
VERDE_NEGRU = p("32453b")
RUGINA = p("904a40")
TABLA = p("7b383a")         # tabla roșie a acoperișului

# --- clădirea (Blender: fațada la y = 0, clădirea spre +Y)
G = 0.3            # grosimea zidurilor de afară
FL = 0.45          # podeaua parterului (trei trepte de la sol)
HC1 = 3.75         # tavanul parterului
FL2 = 4.0          # podeaua etajului
HC2 = 7.4          # tavanul etajului
TOP = 7.7          # streașina corpului din mijloc
XC = 5.3           # jumătate din lățimea corpului din mijloc (pe afară); dinăuntru 5.0
XI = XC - G
XA = 10.0          # capătul aripilor
YB = 12.0          # spatele
YI0, YI1 = G, YB - G
USA = (-0.6, 0.6)
# ferestrele: parterul (fațada), etajul = biroul oval (trei ferestre înalte)
FER_JOS = [(-4.45, -3.35), (-2.55, -1.45), (1.45, 2.55), (3.35, 4.45)]
FZ_JOS = (FL + 0.9, FL + 2.6)
FER_SUS = [(-2.75, -1.65), (-0.55, 0.55), (1.65, 2.75)]
FZ_SUS = (FL2 + 0.5, FL2 + 2.9)
# scara: 20 de trepte de-a lungul peretelui din spate, de la x SX0 (jos) spre +X; sus palierul
NT = 20
TR = (FL2 - FL) / NT    # 0,1775
TL = 0.3
SX0 = -3.8
SX1 = SX0 + NT * TL     # 2.2
SY0, SY1 = 10.5, YI1
# ghișeul: tejgheaua de la x GX0 la XI, fața spre public la y GY0, spatele la GY1, blatul la TZ; geamul la y GG
GX0, GY0, GY1, TZ, GG = 1.2, 6.0, 6.7, FL + 1.0, 6.25
GHISEU = (2.6, 3.4)
# biroul oval: elipsa (dinăuntru) cu centrul în (0, OCY), semiaxele OA (pe X) și OB (pe Y); ușa în peretele drept de la
# y = YHOL (holul de sus e în spatele lui)
OCY, OA, OB = 4.05, 4.6, 3.55
YHOL = 7.6
USA_BIROU = (-0.55, 0.55)
# biroul primarului (masa) și scaunul
MX, MY, MZ = 0.0, 1.75, 0.78


def _ramas(piese, nume):
	"""Lipește ce s-a strâns până acum într-un singur obiect (Blender încetinește cu mii de obiecte)."""
	if len(piese) > 1:
		piese[:] = [uneste(piese, nume)]


def _plasa(nume, verts, fete, culoare):
	"""Un obiect din vârfuri și fețe date (acoperișuri în patru ape)."""
	bm = bmesh.new()
	vs = [bm.verts.new(v) for v in verts]
	for f in fete:
		bm.faces.new([vs[i] for i in f])
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	me = bpy.data.meshes.new(nume)
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new(nume, me)
	bpy.context.scene.collection.objects.link(ob)
	_coloreaza(ob, culoare)
	return ob


def _acoperis_doua_ape(piese, x0, x1, y0, y1, z0, h, culoare, gros=0.12):
	"""Acoperiș în două ape cu coama pe Y (la mijloc pe X), de tablă: două pante groase + coama + nervurile tablei."""
	xm = (x0 + x1) / 2
	for semn in (-1, 1):
		xe = x0 if semn < 0 else x1
		piese.append(prisma("Tabla", [(xe, z0), (xm, z0 + h), (xm, z0 + h + gros), (xe, z0 + gros)], "xz", y0, y1, culoare))
		# nervurile tablei, la 0,45 m, pe pantă (rotite în jurul lui Y: +X merge spre (cos φ, -sin φ))
		lung = math.hypot(xm - xe, h)
		phi = semn * math.atan2(h, abs(xm - xe))
		y = y0 + 0.2
		while y < y1 - 0.1:
			piese.append(cub("Nervura tabla", (lung, 0.035, 0.03), ((xm + xe) / 2, y, z0 + h / 2 + gros + 0.02), culoare,
				rot=(0, phi, 0)))
			y += 0.45
	piese.append(cub("Coama", (0.22, y1 - y0, 0.08), (xm, (y0 + y1) / 2, z0 + h + gros + 0.03), METAL_INCHIS))


def _fereastra(piese, geamuri, x0, x1, z0, z1, y_fata, spre, cul_rama=ALB, ancadrament=True, crucea=True):
	"""O fereastră veche de lemn într-un perete pe X (golul e deja făcut): tocul, pervazul de tablă afară, geamul la
	mijlocul zidului, crucea ramei, ancadramentul de tencuială albă pe fațadă. `spre` = -1 (afară e spre -Y) sau +1."""
	cx = (x0 + x1) / 2
	ym = y_fata + spre * -G / 2           # mijlocul zidului
	piese += [
		cub("Toc", (x1 - x0, G - 0.02, 0.06), (cx, ym, z0 + 0.03), cul_rama),
		cub("Toc", (x1 - x0, G - 0.02, 0.06), (cx, ym, z1 - 0.03), cul_rama),
		cub("Toc", (0.06, G - 0.02, z1 - z0), (x0 + 0.03, ym, (z0 + z1) / 2), cul_rama),
		cub("Toc", (0.06, G - 0.02, z1 - z0), (x1 - 0.03, ym, (z0 + z1) / 2), cul_rama),
		cub("Pervaz tabla", (x1 - x0 + 0.12, 0.14, 0.03), (cx, y_fata + spre * 0.06, z0 + 0.008), METAL),
	]
	if crucea:
		piese.append(cub("Cruce rama", (0.05, 0.05, z1 - z0 - 0.1), (cx, ym, (z0 + z1) / 2), cul_rama))
		piese.append(cub("Cruce rama", (x1 - x0 - 0.1, 0.05, 0.05), (cx, ym, z0 + (z1 - z0) * 0.68), cul_rama))
	geamuri.append(cub("Geam", (x1 - x0 - 0.1, 0.012, z1 - z0 - 0.1), (cx, ym + spre * 0.04, (z0 + z1) / 2), GEAM))
	if ancadrament:
		ya = y_fata + spre * 0.02
		piese += [
			cub("Ancadrament", (x1 - x0 + 0.36, 0.04, 0.16), (cx, ya, z1 + 0.08), ALB),
			cub("Ancadrament", (0.16, 0.04, z1 - z0), (x0 - 0.08, ya, (z0 + z1) / 2), ALB),
			cub("Ancadrament", (0.16, 0.04, z1 - z0), (x1 + 0.08, ya, (z0 + z1) / 2), ALB),
			cub("Cornisa fereastra", (x1 - x0 + 0.5, 0.1, 0.07), (cx, y_fata + spre * 0.05, z1 + 0.2), ALB),
		]


def _fereastra_oarba(piese, x0, x1, z0, z1, y_fata, spre, r, axa="x"):
	"""Fereastră pe un zid plin (aripile, unde nu intri): geam închis la culoare ieșit puțin, perdele de dantelă pe
	jumătate trase, tocul alb cu cruce, pervazul, ancadramentul. Pe axa "y" (pereții laterali), x0..x1 sunt pe Y."""
	cx = (x0 + x1) / 2
	w = x1 - x0
	def c(nume, dx, dy_iesire, dz, lat, gros, inalt, cul):
		# dx = de-a lungul zidului (față de mijloc), dy_iesire = cât iese din zid, dz = înălțimea mijlocului
		if axa == "x":
			piese.append(cub(nume, (lat, gros, inalt), (cx + dx, y_fata + spre * dy_iesire, dz), cul))
		else:
			piese.append(cub(nume, (gros, lat, inalt), (y_fata + spre * dy_iesire, cx + dx, dz), cul))
	zm = (z0 + z1) / 2
	c("Geam orb", 0, 0.01, zm, w, 0.02, z1 - z0, GEAM)
	trasa = r.uniform(0.25, 0.45)
	c("Perdea", -w / 2 + w * trasa / 2, 0.028, zm + 0.05, w * trasa, 0.012, z1 - z0 - 0.1, ALB)
	c("Perdea", w / 2 - w * trasa / 2 * 0.8, 0.028, zm + 0.05, w * trasa * 0.8, 0.012, z1 - z0 - 0.1, ALB)
	for (dx, lat) in ((-w / 2 + 0.03, 0.06), (w / 2 - 0.03, 0.06), (0, 0.05)):
		c("Toc", dx, 0.045, zm, lat, 0.03, z1 - z0, ALB)
	c("Toc", 0, 0.045, z1 - 0.03, w, 0.03, 0.06, ALB)
	c("Toc", 0, 0.045, z0 + 0.03, w, 0.03, 0.06, ALB)
	c("Toc", 0, 0.045, z0 + (z1 - z0) * 0.68, w, 0.03, 0.05, ALB)
	c("Pervaz tabla", 0, 0.07, z0 + 0.008, w + 0.12, 0.14, 0.03, METAL)
	c("Ancadrament", 0, 0.02, z1 + 0.08, w + 0.36, 0.04, 0.16, ALB)
	c("Ancadrament", -w / 2 - 0.08, 0.02, zm, 0.16, 0.04, z1 - z0, ALB)
	c("Ancadrament", w / 2 + 0.08, 0.02, zm, 0.16, 0.04, z1 - z0, ALB)


def _coscos(piese, x0, x1, y_fata, z0, z1, spre, r, n=4):
	"""Tencuiala căzută de pe un zid pe X: pete de cărămidă (cu rosturi) și de tencuială veche, gri."""
	for k in range(n):
		w, h = r.uniform(0.35, 0.9), r.uniform(0.25, 0.6)
		x = r.uniform(x0 + w / 2, x1 - w / 2)
		z = r.uniform(z0 + h / 2, z1 - h / 2)
		if r.random() < 0.6:
			piese.append(cub("Caramida vazuta", (w, 0.02, h), (x, y_fata + spre * 0.016, z), ROSU))
			zz = z - h / 2 + 0.08
			while zz < z + h / 2:
				piese.append(cub("Rost caramida", (w - 0.04, 0.012, 0.012), (x, y_fata + spre * 0.03, zz), LEMN))
				zz += 0.075
		else:
			piese.append(cub("Tencuiala veche", (w, 0.02, h), (x, y_fata + spre * 0.016, z), BETON))


# ---------------------------------------------------------------------------------------------------------------
# Clădirea (zidurile, podelele, scara, biroul oval)
# ---------------------------------------------------------------------------------------------------------------

def _elipsa(t):
	return (OA * math.cos(t), OCY + OB * math.sin(t))


def _y_elipsa_fata(x):
	"""Peretele oval din față (dinspre fațadă) la x."""
	return OCY - OB * math.sqrt(max(0.0, 1 - (x / OA) ** 2))


def cladire(cale):
	"""Zidurile (cu goluri pentru uși și ferestre), podelele, tavanele, scara, peretele oval al biroului, acoperișurile,
	copertina, treptele, tencuiala căzută, jgheaburile. Piese `Cladire`, `Geamuri`, `Lumini`, `Coliziune`."""
	curata()
	r = random.Random(1907)
	piese, geamuri, lumini, col = [], [], [], []

	def strange():
		_ramas(piese, "Cladire")

	# --- corpul din mijloc: zidurile de afară, cu goluri
	goluri_fata = [(USA[0], USA[1], FL, FL + 2.45)] + [(a, b, FZ_JOS[0], FZ_JOS[1]) for a, b in FER_JOS] + \
		[(a, b, FZ_SUS[0], FZ_SUS[1]) for a, b in FER_SUS]
	perete(piese, "Zid", "x", -XC, XC, 0, G, 0, TOP, GALBEN, goluri_fata)
	goluri_spate = [(3.0, 4.2, FL + 1.0, FL + 2.5), (3.0, 4.2, FL2 + 0.9, FL2 + 2.5), (-1.6, -0.4, FL2 + 0.9, FL2 + 2.5)]
	perete(piese, "Zid", "x", -XC, XC, YB - G, YB, 0, TOP, GALBEN, goluri_spate)
	for semn in (-1, 1):
		x0, x1 = (-XC, -XI) if semn < 0 else (XI, XC)
		perete(piese, "Zid", "y", G, YB - G, x0, x1, 0, TOP, GALBEN)
	# coliziunea zidurilor (ferestrele sunt pline, ușa e gol)
	for (x0, x1) in ((-XC, USA[0]), (USA[1], XC)):
		_cutie_coliziune(col, (x1 - x0, G, TOP), ((x0 + x1) / 2, G / 2, TOP / 2))
	_cutie_coliziune(col, (USA[1] - USA[0], G, TOP - FL - 2.45), (0, G / 2, (FL + 2.45 + TOP) / 2))
	_cutie_coliziune(col, (2 * XC, G, TOP), (0, YB - G / 2, TOP / 2))
	for semn in (-1, 1):
		_cutie_coliziune(col, (G, YB, TOP), (semn * (XC - G / 2), YB / 2, TOP / 2))
	for a, b in FER_JOS:
		_fereastra(piese, geamuri, a, b, FZ_JOS[0], FZ_JOS[1], 0.0, -1)
	for a, b in FER_SUS:
		_fereastra(piese, geamuri, a, b, FZ_SUS[0], FZ_SUS[1], 0.0, -1)
	for (a, b, z0, z1) in goluri_spate:
		_fereastra(piese, geamuri, a, b, z0, z1, YB, 1, ancadrament=False)
	# soclul gri, brâul dintre etaje, cornișa de sus
	piese.append(cub("Soclu", (2 * XA + 0.1, 0.06, 0.6), (0, -0.03, 0.3), BETON))
	piese.append(cub("Brau", (2 * XC + 0.1, 0.12, 0.18), (0, -0.06, HC1 + 0.12), ALB))
	piese.append(cub("Cornisa", (2 * XC + 0.3, 0.3, 0.22), (0, -0.1, TOP - 0.1), ALB))
	# frontonul din față (ceasul oprit la 7:12) și din spate
	for (y0, y1) in ((-0.02, G), (YB - G, YB + 0.02)):
		piese.append(prisma("Fronton", [(-XC, TOP), (XC, TOP), (0, TOP + 2.0)], "xz", y0, y1, GALBEN))
	# cornișa de pe marginile frontonului (două benzi pe pante)
	alfa = math.atan2(2.0, XC)
	for semn in (-1, 1):
		piese.append(cub("Cornisa fronton", (math.hypot(XC, 2.0) + 0.2, 0.12, 0.14), (semn * XC / 2, -0.07, TOP + 1.0 + 0.05),
			ALB, rot=(0, semn * alfa, 0)))
	# „TOWN HALL” pe placa din fronton, iar deasupra ceasul (oprit la 7:12)
	piese.append(cub("Placa nume", (4.3, 0.05, 0.62), (0, -0.045, TOP + 0.48), ALB))
	piese.append(_text("Litere primarie", "TOWN HALL", (0, -0.075, TOP + 0.47), 0.5, NEGRU))
	zc = TOP + 1.28
	piese.append(cilindru("Ceas", 0.34, 0.34, 0.06, (0, -0.05, zc), ALB, laturi=20, rot=(math.pi / 2, 0, 0)))
	piese.append(_tor("Rama ceas", 0.36, 0.035, (0, -0.07, zc), METAL_INCHIS, rot=(math.pi / 2, 0, 0), segmente=20))
	for k in range(12):
		a = k * math.pi / 6
		piese.append(cub("Ora", (0.025, 0.01, 0.06), (0.27 * math.sin(a), -0.085, zc + 0.27 * math.cos(a)), NEGRU,
			rot=(0, a, 0)))
	# limba orelor spre 7, a minutelor spre 12 (rotația pe Y: +Z al limbii merge spre (sin φ, cos φ) în planul fațadei)
	piese.append(cub("Limba ora", (0.025, 0.01, 0.17), (0.085 * math.sin(math.radians(210)), -0.095,
		zc + 0.085 * math.cos(math.radians(210))), NEGRU, rot=(0, math.radians(210), 0)))
	piese.append(cub("Limba minut", (0.02, 0.01, 0.26), (0.0, -0.1, zc + 0.12), NEGRU))
	_acoperis_doua_ape(piese, -XC - 0.35, XC + 0.35, -0.35, YB + 0.35, TOP, 2.0, TABLA)
	strange()

	# --- aripile: ziduri pline cu ferestre „oarbe” (nu intri în ele), frontoane spre stradă, acoperiș în două ape
	HA = HC1 + 0.25
	for semn in (-1, 1):
		x0, x1 = (-XA, -XC) if semn < 0 else (XC, XA)
		xm = (x0 + x1) / 2
		piese.append(cub("Aripa", (x1 - x0, YB, HA), (xm, YB / 2, HA / 2), GALBEN))
		piese.append(cub("Cornisa aripa", (x1 - x0 + 0.2, YB + 0.2, 0.18), (xm, YB / 2, HA - 0.05), ALB))
		for fx in (xm - 1.15, xm + 1.15):
			_fereastra_oarba(piese, fx - 0.55, fx + 0.55, FZ_JOS[0], FZ_JOS[1], 0.0, -1, r)
			_fereastra_oarba(piese, fx - 0.55, fx + 0.55, FZ_JOS[0], FZ_JOS[1], YB, 1, r)
		xs = XA if semn > 0 else -XA
		for fy in (2.2, 5.0, 7.8, 10.4):
			_fereastra_oarba(piese, fy - 0.55, fy + 0.55, FZ_JOS[0], FZ_JOS[1], xs, semn, r, axa="y")
		for (y0, y1) in ((-0.02, 0.2), (YB - 0.2, YB + 0.02)):
			piese.append(prisma("Fronton aripa", [(x0, HA), (x1, HA), (xm, HA + 1.6)], "xz", y0, y1, GALBEN))
		piese.append(cub("Rasuflatoare", (0.5, 0.04, 0.35), (xm, -0.04, HA + 0.55), LEMN_INCHIS))
		_acoperis_doua_ape(piese, x0 - 0.3, x1 + 0.3, -0.3, YB + 0.3, HA, 1.6, TABLA)
		# jgheabul și burlanul ruginit
		piese.append(cub("Jgheab", (x1 - x0 + 0.5, 0.14, 0.12), (xm, -0.38, HA - 0.02), METAL))
		bx = x0 + 0.25 if semn < 0 else x1 - 0.25
		piese.append(cilindru("Burlan", 0.05, 0.05, HA, (bx, -0.12, HA / 2), METAL, laturi=6))
		piese.append(cub("Rugina burlan", (0.12, 0.12, 0.5), (bx, -0.12, 0.6), RUGINA))
		_coscos(piese, x0 + 0.3, x1 - 0.3, 0.0, 0.62, FZ_JOS[0] - 0.06, -1, r, n=2)
		_cutie_coliziune(col, (x1 - x0, YB, HA), (xm, YB / 2, HA / 2))
	_coscos(piese, -XC + 0.3, -1.0, 0.0, 0.62, FZ_JOS[0] - 0.06, -1, r, n=2)
	_coscos(piese, 1.0, XC - 0.3, 0.0, 0.62, FZ_JOS[0] - 0.06, -1, r, n=2)
	# aerul condiționat de pe aripa din stânga (cu dâra de rugină sub el) și un cablu de curent pe fațadă
	piese.append(cub("Aer conditionat", (0.8, 0.28, 0.55), (-7.65, -0.16, 3.1), ALB))
	piese.append(cub("Grila aer", (0.5, 0.01, 0.4), (-7.45, -0.305, 3.1), METAL_INCHIS))
	piese.append(cub("Dara rugina", (0.08, 0.015, 1.2), (-7.4, -0.015, 2.2), RUGINA))
	piese.append(os_intre("Cablu", (-XA, -0.05, HC1 + 0.05), (XA, -0.05, HC1 + 0.02), 0.012, NEGRU, laturi=4))
	strange()

	# --- intrarea: trei trepte, platforma, copertina pe doi stâlpi
	for k, (yy, zz) in enumerate(((-2.25, 0.15), (-1.9, 0.30), (-1.55, FL))):
		piese.append(cub("Treapta", (4.0 - k * 0.3, -yy, zz), (0, yy / 2, zz / 2), BETON))
		_cutie_coliziune(col, (4.0 - k * 0.3, -yy, zz), (0, yy / 2, zz / 2))
		piese.append(cub("Muchie treapta", (4.0 - k * 0.3, 0.06, 0.02), (0, yy + 0.02, zz + 0.002), METAL_INCHIS))
	piese.append(cub("Stirbitura", (0.3, 0.25, 0.1), (1.5, -2.12, 0.1), ROSU))
	for sx in (-1.5, 1.5):
		piese.append(cub("Stalp copertina", (0.32, 0.32, 3.2 - FL), (sx, -1.3, FL + (3.2 - FL) / 2), ALB))
		piese.append(cub("Baza stalp", (0.42, 0.42, 0.2), (sx, -1.3, FL + 0.1), BETON))
		_cutie_coliziune(col, (0.32, 0.32, 3.2 - FL), (sx, -1.3, FL + (3.2 - FL) / 2))
	piese.append(cub("Copertina", (4.2, 1.9, 0.22), (0, -0.85, 3.31), ALB))
	piese.append(cub("Tabla copertina", (4.3, 2.0, 0.04), (0, -0.85, 3.44), TABLA))
	piese.append(cub("Pata copertina", (1.2, 0.02, 0.15), (-0.8, -1.81, 3.26), BETON))
	# lampa de deasupra ușii
	piese.append(cub("Lampa usa", (0.2, 0.12, 0.28), (0, -0.07, FL + 2.7), METAL_INCHIS))
	lumini.append(cub("Bec usa", (0.14, 0.03, 0.2), (0, -0.135, FL + 2.7), AUR))
	strange()

	# --- podelele și tavanele
	# parterul: placa (coliziunea) + linoleum în carouri (plăci alăturate, nimic una peste alta)
	piese.append(cub("Placa parter", (2 * XI, YI1 - YI0, FL - 0.02), (0, (YI0 + YI1) / 2, (FL - 0.02) / 2), BETON))
	_cutie_coliziune(col, (2 * XI, YI1 - YI0, FL), (0, (YI0 + YI1) / 2, FL / 2))
	_cutie_coliziune(col, (USA[1] - USA[0], G, FL), (0, G / 2, FL / 2))
	piese.append(cub("Prag", (USA[1] - USA[0], G, FL), (0, G / 2, FL / 2), BETON))
	pas = 0.5
	nx, ny = int(2 * XI / pas), int((YI1 - YI0) / pas + 0.999)
	for i in range(nx):
		for j in range(ny):
			y0 = YI0 + j * pas
			y1 = min(y0 + pas, YI1)
			cul = LEMN_DESCHIS if (i + j) % 2 == 0 else ROSU
			if r.random() < 0.025:
				cul = BRONZ  # o placă înlocuită, de altă culoare
			piese.append(cub("Linoleum", (pas, y1 - y0, 0.02), (-XI + (i + 0.5) * pas, (y0 + y1) / 2, FL - 0.01), cul))
	strange()
	# placa dintre etaje (cu golul scării), tavanul parterului, podeaua etajului (parchet la birou, mochetă pe hol)
	for (x0, x1, y0, y1) in ((-XI, XI, YI0, SY0), (-XI, SX0, SY0, SY1), (SX1, XI, SY0, SY1)):
		piese.append(cub("Placa etaj", (x1 - x0, y1 - y0, FL2 - HC1 - 0.02), ((x0 + x1) / 2, (y0 + y1) / 2,
			(HC1 + FL2 - 0.02) / 2), ALB))
		_cutie_coliziune(col, (x1 - x0, y1 - y0, FL2 - HC1), ((x0 + x1) / 2, (y0 + y1) / 2, (HC1 + FL2) / 2))
	# parchetul biroului (în pătrate de 0,6 m, două tonuri, ca un parchet „în coș” văzut de departe)
	for i in range(int(2 * XI / 0.6) + 1):
		for j in range(int((YHOL - YI0) / 0.6) + 1):
			x0, y0 = -XI + i * 0.6, YI0 + j * 0.6
			x1, y1 = min(x0 + 0.6, XI), min(y0 + 0.6, YHOL)
			if x1 - x0 < 0.01 or y1 - y0 < 0.01:
				continue
			piese.append(cub("Parchet", (x1 - x0, y1 - y0, 0.02), ((x0 + x1) / 2, (y0 + y1) / 2, FL2 - 0.01),
				LEMN if (i + j) % 2 == 0 else LEMN_INCHIS))
	for (x0, x1, y0, y1) in ((-XI, XI, YHOL, SY0), (-XI, SX0, SY0, SY1), (SX1, XI, SY0, SY1)):
		piese.append(cub("Mocheta hol", (x1 - x0, y1 - y0, 0.02), ((x0 + x1) / 2, (y0 + y1) / 2, FL2 - 0.01), MOV_INCHIS))
	piese.append(cub("Traversa", (1.2, SY0 - 0.1 - (YHOL + 0.25), 0.012), (0, (YHOL + 0.25 + SY0 - 0.1) / 2, FL2 + 0.006), ROSU))
	piese.append(cub("Tavan etaj", (2 * XI, YI1 - YI0, TOP - HC2), (0, (YI0 + YI1) / 2, (HC2 + TOP) / 2), ALB))
	strange()

	# --- parterul: pereții vopsiți în ulei pe jumătate (verde-albastru jos, alb sus, cu o dungă între ele)
	VU = FL + 1.5
	perete(piese, "Vopsea ulei", "x", -XI, XI, G, G + 0.015, FL, VU, TEAL,
		[(USA[0], USA[1], FL, FL + 2.45)] + [(a, b, FZ_JOS[0], FZ_JOS[1]) for a, b in FER_JOS])
	perete(piese, "Vopsea ulei", "x", -XI, XI, YI1 - 0.015, YI1, FL, VU, TEAL, [(3.0, 4.2, FL + 1.0, FL + 2.5)])
	for semn in (-1, 1):
		g0, g1 = (-XI, -XI + 0.015) if semn < 0 else (XI - 0.015, XI)
		perete(piese, "Vopsea ulei", "y", YI0, YI1, g0, g1, FL, VU, TEAL)
		piese.append(cub("Dunga", (0.02, YI1 - YI0, 0.04), (semn * (XI - 0.018), (YI0 + YI1) / 2, VU), PETROL))
	perete(piese, "Dunga", "x", -XI, XI, G + 0.008, G + 0.028, VU - 0.02, VU + 0.02, PETROL,
		[(USA[0], USA[1], FL, FL + 2.45)] + [(a, b, FZ_JOS[0], FZ_JOS[1]) for a, b in FER_JOS])
	perete(piese, "Dunga", "x", -XI, XI, YI1 - 0.028, YI1 - 0.008, VU - 0.02, VU + 0.02, PETROL, [(3.0, 4.2, FL + 1.0, FL + 2.5)])
	# ușile birourilor (închise, de lemn vopsit, cu plăcuțe)
	for (x, y, nume) in ((-XI, 2.6, "CIVIL\nREGISTRY"), (-XI, 5.7, "TAXES"), (XI, 3.2, "ARCHIVE")):
		s = 1 if x > 0 else -1
		piese.append(cub("Toc usa birou", (0.06, 1.15, 2.25), (x - s * 0.03, y, FL + 1.125), ALB))
		piese.append(cub("Usa birou", (0.05, 0.95, 2.1), (x - s * 0.06, y, FL + 1.05), LEMN))
		for dz in (0.55, 1.45):
			piese.append(cub("Panou usa", (0.02, 0.7, 0.6), (x - s * 0.095, y, FL + dz), LEMN_INCHIS))
		piese.append(cub("Clanta", (0.06, 0.12, 0.03), (x - s * 0.11, y + 0.36, FL + 1.0), CROM))
		piese.append(cub("Placuta", (0.015, 0.45, 0.2), (x - s * 0.095, y, FL + 1.95), ALB))
		piese.append(_text_o_fata("Scris placuta", nume, (x - s * 0.105, y, FL + 1.95), 0.06, NEGRU,
			rot=(math.pi / 2, 0, -s * math.pi / 2)))
	# tavanul parterului: neoanele
	for (x, y) in ((-2.5, 2.5), (2.5, 2.5), (-2.5, 6.5), (2.5, 6.5), (-1.0, 9.5)):
		piese.append(cub("Corp neon", (0.3, 1.3, 0.06), (x, y, HC1 - 0.03), METAL))
		lumini.append(cub("Tub neon", (0.18, 1.2, 0.02), (x, y, HC1 - 0.07), ALB))
	strange()

	# --- scara de lângă peretele din spate: trepte de beton cu muchie de metal, balustradă de fier, mâna curentă de lemn
	for i in range(NT):
		x0 = SX0 + i * TL
		z = FL + (i + 1) * TR
		piese.append(cub("Treapta scara", (TL, SY1 - SY0, z - FL), (x0 + TL / 2, (SY0 + SY1) / 2, (FL + z) / 2), BETON))
		piese.append(cub("Muchie scara", (0.03, SY1 - SY0, 0.02), (x0 - 0.005, (SY0 + SY1) / 2, z + 0.004), METAL_INCHIS))
	# coliziunea scării: o rampă (nu 20 de trepte, pe care corpul sărea treaptă cu treaptă), prin mijlocul fiecărei
	# trepte (la jumătatea ei e fix la înălțimea treptei); sus se termină pe palier
	col.append(prisma("Coliziune", [(SX0 - TL / 2, FL), (SX1 - TL / 2, FL2), (SX1, FL2), (SX1, FL)], "xz", SY0, SY1, NEGRU))
	# și un perete nevăzut sub balustradă, de jos până peste palier: nu cazi de pe scară în hol și nu te mai agăți cu
	# capul de marginea plăcii de sus când urci lipit de balustradă
	_cutie_coliziune(col, (SX1 - SX0, 0.1, FL2 + 1.0 - FL), ((SX0 + SX1) / 2, SY0 + 0.05, (FL + FL2 + 1.0) / 2))
	# balustrada de pe marginea scării (spre hol) și de sus, de pe marginea golului
	for i in range(0, NT, 2):
		x = SX0 + i * TL + TL / 2
		z = FL + (i + 1) * TR
		piese.append(cub("Bara balustrada", (0.03, 0.03, 0.9), (x, SY0 + 0.05, z + 0.45), METAL_INCHIS))
	piese.append(os_intre("Mana curenta", (SX0, SY0 + 0.05, FL + 0.95), (SX1, SY0 + 0.05, FL2 + 0.95), 0.03, LEMN, laturi=6))
	x = SX0 + 0.1
	while x < SX1:
		piese.append(cub("Bara balustrada", (0.03, 0.03, 0.9), (x, SY0 - 0.04, FL2 + 0.45), METAL_INCHIS))
		x += 0.25
	piese.append(cub("Mana curenta sus", (SX1 - SX0, 0.08, 0.05), ((SX0 + SX1) / 2, SY0 - 0.04, FL2 + 0.93), LEMN))
	_cutie_coliziune(col, (SX1 - SX0, 0.1, 1.0), ((SX0 + SX1) / 2, SY0 - 0.04, FL2 + 0.5))
	for yy in (SY0 + 0.3, SY0 + 0.6, SY0 + 0.9):
		piese.append(cub("Bara balustrada", (0.03, 0.03, 0.9), (SX0 - 0.04, yy, FL2 + 0.45), METAL_INCHIS))
	piese.append(cub("Mana curenta sus", (0.08, SY1 - SY0, 0.05), (SX0 - 0.04, (SY0 + SY1) / 2, FL2 + 0.93), LEMN))
	_cutie_coliziune(col, (0.1, SY1 - SY0, 1.0), (SX0 - 0.04, (SY0 + SY1) / 2, FL2 + 0.5))
	strange()

	# --- holul de sus: peretele drept cu ușa biroului, lambriu de lemn, aplice
	perete(piese, "Perete hol", "x", -XI, XI, YHOL, YHOL + 0.2, FL2, HC2, ALB, [(USA_BIROU[0], USA_BIROU[1], FL2, FL2 + 2.3)])
	perete(piese, "Lambriu hol", "x", -XI, XI, YHOL + 0.2, YHOL + 0.22, FL2, FL2 + 1.0, LEMN,
		[(USA_BIROU[0] - 0.12, USA_BIROU[1] + 0.12, FL2, FL2 + 2.3)])
	_cutie_coliziune(col, (USA_BIROU[0] + XI, 0.2, HC2 - FL2), ((-XI + USA_BIROU[0]) / 2, YHOL + 0.1, (FL2 + HC2) / 2))
	_cutie_coliziune(col, (XI - USA_BIROU[1], 0.2, HC2 - FL2), ((XI + USA_BIROU[1]) / 2, YHOL + 0.1, (FL2 + HC2) / 2))
	for semn in (-1, 1):
		g0, g1 = (-XI, -XI + 0.02) if semn < 0 else (XI - 0.02, XI)
		perete(piese, "Lambriu hol", "y", YHOL + 0.2, YI1, g0, g1, FL2, FL2 + 1.0, LEMN)
	perete(piese, "Lambriu hol", "x", -XI, XI, YI1 - 0.02, YI1, FL2, FL2 + 1.0, LEMN, [(3.0, 4.2, FL2 + 0.9, FL2 + 2.5)])
	# tocul ușii biroului (lat, alb, cu fronton mic) și plăcuța de alamă
	for semn in (-1, 1):
		piese.append(cub("Toc birou", (0.14, 0.32, 2.35), (semn * 0.62, YHOL + 0.1, FL2 + 1.175), ALB))
	piese.append(cub("Toc birou", (1.38, 0.32, 0.14), (0, YHOL + 0.1, FL2 + 2.37), ALB))
	piese.append(prisma("Fronton usa", [(-0.8, FL2 + 2.44), (0.8, FL2 + 2.44), (0, FL2 + 2.75)], "xz", YHOL + 0.22,
		YHOL + 0.3, ALB))
	piese.append(cub("Placuta birou", (0.5, 0.02, 0.16), (1.05, YHOL + 0.235, FL2 + 1.55), AUR))
	piese.append(_text_o_fata("Scris birou", "MAYOR", (1.05, YHOL + 0.25, FL2 + 1.55), 0.08, NEGRU,
		rot=(math.pi / 2, 0, math.pi)))
	for x in (-2.8, 2.8):
		piese.append(cub("Aplica", (0.14, 0.08, 0.2), (x, YHOL + 0.26, FL2 + 2.2), AUR))
		lumini.append(cub("Bec aplica", (0.1, 0.05, 0.1), (x, YHOL + 0.31, FL2 + 2.32), AUR))
	strange()

	# --- biroul oval: peretele din segmente pe elipsă, cu golul ușii (în spate) și al ferestrelor (în față)
	N = 120
	T = 0.15
	for k in range(N):
		t0, t1 = 2 * math.pi * k / N, 2 * math.pi * (k + 1) / N
		tm = (t0 + t1) / 2
		p0, p1 = _elipsa(t0), _elipsa(t1)
		mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
		dx, dy = p1[0] - p0[0], p1[1] - p0[1]
		lung = math.hypot(dx, dy) + 0.02
		ang = math.atan2(dy, dx)
		nx, ny = math.cos(tm) / OA, math.sin(tm) / OB
		nl = math.hypot(nx, ny)
		nx, ny = nx / nl, ny / nl
		goluri = []
		if my > OCY and abs(mx) < 0.62:
			goluri.append((FL2, FL2 + 2.3))
		if my < OCY and any(abs(mx - (a + b) / 2) < 0.58 for a, b in FER_SUS):
			goluri.append(FZ_SUS)
		z = FL2
		bucati = []
		for (za, zb) in goluri:
			bucati.append((z, za))
			z = zb
		bucati.append((z, HC2))
		for (za, zb) in bucati:
			if zb - za < 0.01:
				continue
			piese.append(cub("Perete oval", (lung, T, zb - za), (mx + nx * T / 2, my + ny * T / 2, (za + zb) / 2), ALB,
				rot=(0, 0, ang)))
		# coliziunea: perete întreg (podea → tavan), cu gol doar la ușă; la ferestre e plin, altfel pe sub geam
		# (parapetul de 0,5 m) treceai în golul dintre peretele oval și fațadă (owner, 09.10)
		col_z = [(FL2, HC2)] if not goluri or goluri[0][0] > FL2 + 0.2 else [(FL2 + 2.3, HC2)]
		for (za, zb) in col_z:
			col.append(cub("Coliziune", (lung, T, zb - za), (mx + nx * T / 2, my + ny * T / 2, (za + zb) / 2), NEGRU,
				rot=(0, 0, ang)))
		# plinta, brâul de la 0,9 m și cornișa de sus (fără golul ușii; brâul și plinta fără ferestre)
		if not goluri or goluri[0][0] > FL2 + 0.2:
			piese.append(cub("Plinta oval", (lung, 0.03, 0.16), (mx - nx * 0.015, my - ny * 0.015, FL2 + 0.08), LEMN_INCHIS,
				rot=(0, 0, ang)))
			piese.append(cub("Brau oval", (lung, 0.03, 0.05), (mx - nx * 0.015, my - ny * 0.015, FL2 + 0.9), CROM,
				rot=(0, 0, ang)))
		piese.append(cub("Cornisa oval", (lung, 0.12, 0.18), (mx - nx * 0.06, my - ny * 0.06, HC2 - 0.09), CROM,
			rot=(0, 0, ang)))
	strange()
	# nișele ferestrelor (de la peretele oval până la fațadă) și draperiile aurii
	for a, b in FER_SUS:
		xc = (a + b) / 2
		ye = _y_elipsa_fata(xc)
		for sx in (-1, 1):
			x_lat = xc + sx * 0.665
			yl = _y_elipsa_fata(xc + sx * 0.58)
			piese.append(cub("Nisa", (0.17, yl - G + 0.1, FZ_SUS[1] - FZ_SUS[0]), (x_lat, (G + yl + 0.1) / 2,
				(FZ_SUS[0] + FZ_SUS[1]) / 2), ALB))
		piese.append(cub("Nisa", (1.5, ye - G + 0.12, 0.08), (xc, (G + ye + 0.12) / 2, FZ_SUS[1] + 0.04), ALB))
		piese.append(cub("Nisa", (1.5, ye - G + 0.12, 0.08), (xc, (G + ye + 0.12) / 2, FZ_SUS[0] - 0.04), ALB))
		for sx in (-1, 1):
			xd = xc + sx * 0.78
			yd = _y_elipsa_fata(xd) + 0.14
			piese.append(cub("Draperie", (0.42, 0.14, HC2 - FL2 - 0.35), (xd, yd, (FL2 + HC2 - 0.35) / 2), AUR))
			for k in range(3):
				piese.append(cub("Falt draperie", (0.05, 0.03, HC2 - FL2 - 0.4), (xd - 0.14 + k * 0.14, yd - 0.085,
					(FL2 + HC2 - 0.4) / 2), BRONZ))
			piese.append(cub("Ciucure", (0.08, 0.08, 0.25), (xd - sx * 0.2, yd - 0.1, FL2 + 1.25), AUR))
		piese.append(cub("Galerie draperie", (2.1, 0.22, 0.32), (xc, ye + 0.08, HC2 - 0.45), BRONZ))
	# tavanul: medalionul oval și inelul de lumini
	piese.append(cilindru("Medalion tavan", 1.6, 1.6, 0.06, (0, OCY, HC2 - 0.03), CROM, laturi=32, scara=(1.0, 0.78, 1.0)))
	piese.append(cilindru("Medalion tavan", 1.0, 1.0, 0.04, (0, OCY, HC2 - 0.08), ALB, laturi=28, scara=(1.0, 0.78, 1.0)))
	for k in range(10):
		a = k * 2 * math.pi / 10
		x, y = 3.4 * math.cos(a), OCY + 2.55 * math.sin(a)
		piese.append(cilindru("Spot tavan", 0.1, 0.1, 0.03, (x, y, HC2 - 0.015), METAL_INCHIS, laturi=8))
		lumini.append(cilindru("Bec spot", 0.07, 0.07, 0.02, (x, y, HC2 - 0.035), ALB, laturi=8))
	strange()

	uneste(piese, "Cladire")
	uneste(geamuri, "Geamuri")
	uneste(lumini, "Lumini")
	uneste(col, "Coliziune")
	# tocurile ferestrelor, ramele, plintele, brâiele lipite de ziduri: se văd și de pe stradă, deci distanța implicită
	desparte_fete(fixe=("Zid", "Vopsea ulei", "Lambriu hol", "Perete hol", "Perete oval", "Aripa", "Placa parter",
		"Placa etaj", "Tavan etaj", "Linoleum", "Parchet", "Mocheta hol", "Treapta", "Treapta scara", "Tabla", "Fronton",
		"Fronton aripa", "Soclu"))
	exporta(os.path.join(cale, "primarie_cladire.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Interiorul: ghișeul și holul de jos, biroul oval de sus
# ---------------------------------------------------------------------------------------------------------------

def _scaun_simplu(piese, x, y, rot, cul=LEMN_DESCHIS):
	"""Scaun de lemn cu picioare de metal (lângă perete, la rând)."""
	c, s = math.cos(rot), math.sin(rot)
	def m(dx, dy):
		return (x + dx * c - dy * s, y + dx * s + dy * c)
	for (dx, dy) in ((-0.2, -0.2), (0.2, -0.2), (-0.2, 0.2), (0.2, 0.2)):
		px, py = m(dx, dy)
		piese.append(cub("Picior scaun", (0.03, 0.03, 0.45), (px, py, FL + 0.225), METAL_INCHIS))
	px, py = m(0, 0)
	piese.append(cub("Sezut scaun", (0.46, 0.44, 0.04), (px, py, FL + 0.46), cul, rot=(0, 0, rot)))
	px, py = m(0, 0.21)
	piese.append(cub("Spatar scaun", (0.46, 0.03, 0.42), (px, py, FL + 0.75), cul, rot=(0, 0, rot)))


def _canapea(piese, col, cx, cy, rot, lung=2.0, cul=ALB, dungi=GRI_ALBASTRU, z0=FL2):
	"""Canapea capitonată (ca în Oval Office): în coordonatele ei fața e spre -Y; o rotesc cu `rot` în jurul centrului."""
	s = []
	s.append(cub("Baza canapea", (lung, 0.85, 0.24), (0, 0, z0 + 0.22), cul))
	for k in range(3):
		s.append(cub("Perna canapea", (lung / 3 - 0.03, 0.62, 0.14), (-lung / 3 + k * lung / 3, -0.08, z0 + 0.41), cul))
	s.append(cub("Spatar canapea", (lung, 0.21, 0.5), (0, 0.31, z0 + 0.6), cul))
	for semn in (-1, 1):
		s.append(cub("Brat canapea", (0.2, 0.87, 0.36), (semn * (lung / 2 + 0.06), 0, z0 + 0.42), cul))
	for k in range(6):
		s.append(cub("Dunga canapea", (0.04, 0.012, 0.42), (-lung / 2 + 0.2 + k * (lung - 0.4) / 5, 0.195, z0 + 0.62), dungi))
	for (dx, dy) in ((-lung / 2, -0.35), (lung / 2, -0.35), (-lung / 2, 0.35), (lung / 2, 0.35)):
		s.append(cub("Picior canapea", (0.06, 0.06, 0.1), (dx, dy, z0 + 0.05), LEMN_INCHIS))
	_roteste_muta(s, rot, (cx, cy))
	piese += s
	col.append(cub("Coliziune", (lung + 0.4, 0.85, 0.7), (cx, cy, z0 + 0.35), NEGRU, rot=(0, 0, rot)))


def _roteste_muta(obiecte, rot, loc):
	from mathutils import Matrix, Vector
	m = Matrix.Translation(Vector((loc[0], loc[1], 0))) @ Matrix.Rotation(rot, 4, 'Z')
	for ob in obiecte:
		ob.data.transform(m)
		ob.data.update()


def _fotoliu(piese, col, cx, cy, rot, cul=AUR, z0=FL2):
	s = [
		cub("Baza fotoliu", (0.8, 0.8, 0.26), (0, 0, z0 + 0.23), cul),
		cub("Perna fotoliu", (0.56, 0.6, 0.12), (0, -0.06, z0 + 0.42), cul),
		# spătarul între brațe și brațele cu 1 cm peste bază, ca fețele să nu stea în același plan (pâlpâiau)
		cub("Spatar fotoliu", (0.78, 0.2, 0.62), (0, 0.29, z0 + 0.62), cul),
		cub("Brat fotoliu", (0.16, 0.82, 0.32), (-0.33, 0, z0 + 0.48), cul),
		cub("Brat fotoliu", (0.16, 0.82, 0.32), (0.33, 0, z0 + 0.48), cul),
	]
	for (dx, dy) in ((-0.34, -0.34), (0.34, -0.34), (-0.34, 0.34), (0.34, 0.34)):
		s.append(cub("Picior fotoliu", (0.06, 0.06, 0.1), (dx, dy, z0 + 0.05), LEMN_INCHIS))
	_roteste_muta(s, rot, (cx, cy))
	piese += s
	_cutie_coliziune(col, (0.8, 0.8, 0.8), (cx, cy, z0 + 0.4))


def _carti(piese, x0, x1, y, z, r, adanc=0.2, axa="x", spre=1):
	"""Un raft de cărți (cotoare colorate, de înălțimi diferite) de-a lungul lui x0..x1 (sau pe Y, cu axa "y")."""
	x = x0
	while x < x1 - 0.04:
		g = r.uniform(0.025, 0.06)
		h = r.uniform(0.2, 0.3)
		cul = r.choice((ROSU, PETROL, VERDE_INCHIS, LEMN, MOV_INCHIS, BRONZ, NEGRU, AUR))
		if axa == "x":
			piese.append(cub("Carte", (g - 0.004, adanc, h), (x + g / 2, y, z + h / 2), cul))
		else:
			piese.append(cub("Carte", (adanc, g - 0.004, h), (y, x + g / 2, z + h / 2), cul))
		x += g
		if r.random() < 0.06:
			x += 0.1


def interior(cale):
	"""Mobila de la parter (ghișeul, scaunele, avizierul, afișele, planta, caloriferele) și din biroul oval (biroul
	masiv, canapelele, măsuța, șemineul cu portretul, fotoliile, bibliotecile, ceasul, globul, bustul, covorul cu pecetea).
	Piese `Interior`, `Geamuri`, `Lumini`, `Coliziune`."""
	curata()
	r = random.Random(2024)
	piese, geamuri, lumini, col = [], [], [], []

	def strange():
		_ramas(piese, "Interior")

	# =========================== PARTERUL
	# --- ghișeul: tejgheaua de lemn, geamul cu ghișeul mic jos, plăcuța „INFORMATION”, peretele de lemn și sticlă din stânga
	# tejgheaua începe la XT (fața din stânga a peretelui ghișeului, ca să fie una cu el); corpul se oprește sub blat (fețele
	# de sus nu mai stau una peste alta) și capătul din stânga e închis (nu se mai vede gol pe sub blat)
	XT = GX0 - 0.03
	ZB = TZ - 0.05
	piese.append(cub("Tejghea", (XI - XT, 0.12, ZB - FL), ((XT + XI) / 2, GY0 + 0.06, (FL + ZB) / 2), LEMN))
	piese.append(cub("Capat tejghea", (0.06, GY1 + 0.02 - GY0 - 0.12, ZB - FL), (GX0, (GY0 + 0.14 + GY1) / 2, (FL + ZB) / 2), LEMN))
	for k in range(4):
		x = GX0 + 0.45 + k * (XI - GX0 - 0.9) / 3
		piese.append(cub("Panou tejghea", (0.7, 0.02, 0.6), (x, GY0 - 0.01, FL + 0.5), LEMN_INCHIS))
	piese.append(cub("Blat tejghea", (XI - XT + 0.04, GY1 - GY0 + 0.04, 0.05), ((XT + XI) / 2, (GY0 + GY1) / 2, TZ - 0.025),
		LEMN_DESCHIS))
	piese.append(cub("Plinta tejghea", (XI - XT, 0.03, 0.1), ((XT + XI) / 2, GY0 - 0.015, FL + 0.05), NEGRU))
	_cutie_coliziune(col, (XI - XT, GY1 - GY0, TZ - FL), ((XT + XI) / 2, (GY0 + GY1) / 2, (FL + TZ) / 2))
	# geamul: rama de aluminiu, sticla în bucăți, golul ghișeului jos; stâlpii sunt mai subțiri decât barele (3 vs 5 cm),
	# ca fețele lor să nu stea în același plan acolo unde se întâlnesc (pâlpâiau)
	ZG1 = TZ + 0.95
	for x in (GX0 + 0.02, GHISEU[0], GHISEU[1], XI - 0.02):
		piese.append(cub("Rama geam ghiseu", (0.04, 0.03, ZG1 - TZ), (x, GG, (TZ + ZG1) / 2), CROM))
	piese.append(cub("Rama geam ghiseu", (XI - GX0 + 0.02, 0.05, 0.04), ((GX0 + XI) / 2, GG, ZG1), CROM))
	piese.append(cub("Rama geam ghiseu", (GHISEU[1] - GHISEU[0], 0.05, 0.04), ((GHISEU[0] + GHISEU[1]) / 2, GG, TZ + 0.3), CROM))
	for (a, b, z0) in ((GX0 + 0.04, GHISEU[0] - 0.02, TZ), (GHISEU[1] + 0.02, XI - 0.04, TZ), (GHISEU[0] + 0.02,
			GHISEU[1] - 0.02, TZ + 0.32)):
		geamuri.append(cub("Geam ghiseu", (b - a, 0.012, ZG1 - z0 - 0.02), ((a + b) / 2, GG, (z0 + ZG1) / 2), GEAM))
	_cutie_coliziune(col, (XI - GX0, 0.06, ZG1 - TZ), ((GX0 + XI) / 2, GG, (TZ + ZG1) / 2))
	piese.append(cub("Placa info", (1.4, 0.03, 0.24), (3.0, GG - 0.04, ZG1 + 0.18), ALB))
	piese.append(_text("Scris info", "INFORMATION", (3.0, GG - 0.06, ZG1 + 0.18), 0.11, NEGRU))
	piese.append(cub("Hartie lipita", (0.21, 0.01, 0.29), (1.9, GG - 0.015, TZ + 0.55), ALB))
	piese.append(_text_o_fata("Scris hartie", "CLOSED\n12-1 PM", (1.9, GG - 0.022, TZ + 0.6), 0.035, ROSU))
	piese.append(cub("Hartie lipita", (0.21, 0.01, 0.15), (4.3, GG - 0.015, TZ + 0.75), AUR))
	piese.append(cub("Taviță ghiseu", (0.5, 0.25, 0.03), (3.0, GG - 0.05, TZ + 0.015), METAL))
	# peretele de lemn și sticlă din stânga (închide spatele ghișeului până la scară)
	piese.append(cub("Perete ghiseu", (0.06, SY0 - GY1 - 0.02, TZ - FL), (GX0, (GY1 + 0.02 + SY0) / 2, (FL + TZ) / 2), LEMN))
	# sticla și bara de sus pornesc din colțul geamului din față (GG): înainte sticla începea abia la GY1 (gaură între ele,
	# deasupra tejghelei) și bara ieșea în față, dincolo de geam
	piese.append(cub("Rama geam ghiseu", (0.04, SY0 - GG, 0.03), (GX0, (GG + SY0) / 2, ZG1 - 0.003), CROM))
	geamuri.append(cub("Geam ghiseu", (0.012, SY0 - GG - 0.035, ZG1 - TZ - 0.02), (GX0, (GG + 0.015 + SY0 - 0.02) / 2, (TZ + ZG1) / 2), GEAM))
	_cutie_coliziune(col, (0.08, SY0 - GY0, ZG1 - FL), (GX0, (GY0 + SY0) / 2, (FL + ZG1) / 2))
	# în spatele ghișeului: scaunul înalt al funcționarei, biroul cu monitorul vechi, dulapul cu dosare, ceainicul
	piese.append(cilindru("Picior scaun inalt", 0.03, 0.03, 0.62, (3.0, 7.0, FL + 0.31), METAL_INCHIS, laturi=6))
	piese.append(cilindru("Baza scaun inalt", 0.28, 0.28, 0.04, (3.0, 7.0, FL + 0.02), METAL_INCHIS, laturi=5))
	piese.append(cilindru("Sezut scaun inalt", 0.24, 0.24, 0.08, (3.0, 7.0, FL + 0.67), NEGRU, laturi=10))
	piese.append(cub("Birou functionara", (1.6, 0.7, 0.05), (3.5, 8.3, FL + 0.76), LEMN_DESCHIS))
	piese.append(cub("Picioare birou", (1.5, 0.6, 0.73), (3.5, 8.32, FL + 0.365), LEMN))
	piese.append(cub("Monitor vechi", (0.42, 0.4, 0.36), (3.2, 8.4, FL + 0.97), ALB))
	piese.append(cub("Ecran monitor", (0.32, 0.01, 0.25), (3.2, 8.195, FL + 0.99), GEAM))
	piese.append(cub("Tastatura", (0.45, 0.16, 0.03), (3.2, 8.0, FL + 0.8), ALB))
	piese.append(cub("Stampila", (0.06, 0.06, 0.1), (3.9, 8.1, FL + 0.84), LEMN_INCHIS))
	piese.append(cub("Teanc dosare", (0.3, 0.24, 0.18), (4.0, 8.4, FL + 0.87), BRONZ))
	piese.append(cub("Dulap dosare", (0.5, 0.6, 1.8), (XI - 0.3, 9.6, FL + 0.9), METAL))
	for k in range(4):
		piese.append(cub("Sertar dosare", (0.02, 0.4, 0.3), (XI - 0.56, 9.6, FL + 0.3 + k * 0.42), CROM))
	piese.append(cilindru("Ceainic", 0.08, 0.06, 0.18, (2.9, 8.5, FL + 0.87), ALB, laturi=8))
	piese.append(cub("Calendar", (0.3, 0.01, 0.42), (XI - 0.01, 7.6, FL + 1.75), ALB, rot=(0, 0, math.pi / 2)))
	_cutie_coliziune(col, (1.6, 0.7, 0.8), (3.5, 8.3, FL + 0.4))
	_cutie_coliziune(col, (0.5, 0.6, 1.8), (XI - 0.3, 9.6, FL + 0.9))
	strange()

	# --- holul: scaunele legate, avizierul, afișele, planta, caloriferele, cuierul, coșul de gunoi, ceasul de perete
	for k in range(4):
		_scaun_simplu(piese, -XI + 0.32, 3.55 + k * 0.5, math.pi / 2, cul=r.choice((LEMN_DESCHIS, LEMN_DESCHIS, BRONZ)))
	piese.append(cub("Bara scaune", (0.04, 1.9, 0.04), (-XI + 0.32, 4.3, FL + 0.4), METAL_INCHIS))
	_cutie_coliziune(col, (0.5, 2.0, 0.9), (-XI + 0.32, 4.3, FL + 0.45))
	# avizierul de pe peretele din stânga (lângă scară)
	piese.append(cub("Avizier", (0.04, 1.4, 0.9), (-XI + 0.03, 8.2, FL + 1.55), LEMN))
	piese.append(cub("Pluta avizier", (0.02, 1.3, 0.8), (-XI + 0.06, 8.2, FL + 1.55), BRONZ))
	for k in range(6):
		w, h = r.uniform(0.18, 0.3), r.uniform(0.22, 0.3)
		piese.append(cub("Foaie avizier", (0.012, w, h), (-XI + 0.075, 7.65 + k * 0.22 + r.uniform(-0.03, 0.03),
			FL + 1.55 + r.choice((-0.2, 0.18))), r.choice((ALB, ALB, AUR))))
	piese.append(_text_o_fata("Scris avizier", "NOTICES", (-XI + 0.08, 8.2, FL + 2.08), 0.08, NEGRU,
		rot=(math.pi / 2, 0, math.pi / 2)))
	# afișul de campanie „VOTE SMEGMA” (fața lui zâmbind, un deget mare în sus)
	ax, ay, az = -XI + 0.045, 1.4, FL + 1.65
	piese.append(cub("Afis", (0.012, 0.7, 0.95), (ax, ay, az), PETROL))
	piese.append(cub("Afis fata", (0.012, 0.34, 0.4), (ax + 0.01, ay, az + 0.1), BRONZ))
	piese.append(cub("Afis chelie", (0.012, 0.3, 0.06), (ax + 0.016, ay, az + 0.27), AUR))
	piese.append(cub("Afis mustata", (0.012, 0.18, 0.04), (ax + 0.02, ay, az + 0.02), LEMN_INCHIS))
	piese.append(cub("Afis zambet", (0.012, 0.12, 0.02), (ax + 0.022, ay, az - 0.04), ALB))
	for dy in (-0.07, 0.07):
		piese.append(cub("Afis ochi", (0.012, 0.04, 0.03), (ax + 0.02, ay + dy, az + 0.15), NEGRU))
	piese.append(cub("Afis costum", (0.012, 0.6, 0.18), (ax + 0.01, ay, az - 0.21), NEGRU))
	piese.append(_text_o_fata("Scris afis", "VOTE\nSMEGMA", (ax + 0.025, ay, az - 0.36), 0.075, AUR,
		rot=(math.pi / 2, 0, math.pi / 2)))
	piese.append(cub("Mustata desenata", (0.012, 0.12, 0.03), (ax + 0.026, ay + 0.02, az + 0.07), NEGRU, rot=(0.3, 0, 0)))
	# ceasul de perete
	piese.append(cilindru("Ceas perete", 0.17, 0.17, 0.04, (0.0, G + 0.03, FL + 2.85), ALB, laturi=14, rot=(math.pi / 2, 0, 0)))
	piese.append(cub("Limba ceas", (0.015, 0.01, 0.12), (0.03, G + 0.055, FL + 2.88), NEGRU, rot=(0, 0.5, 0)))
	# ficusul din colțul din dreapta, lângă tejghea (nu mai e înghesuit în capătul ei din stânga, unde frunzele intrau în
	# tejghea și te agățai între ghiveci și colțul ei), caloriferele de sub ferestre, cuierul, coșul de gunoi, preșul
	fx, fy = XI - 0.45, 5.45
	piese.append(cilindru("Ghiveci", 0.22, 0.17, 0.4, (fx, fy, FL + 0.2), ROSU, laturi=10))
	piese.append(cilindru("Tulpina ficus", 0.03, 0.02, 1.1, (fx, fy, FL + 0.9), LEMN, laturi=5))
	for k in range(8):
		piese.append(sfera("Frunze ficus", r.uniform(0.16, 0.24), (fx + r.uniform(-0.2, 0.2), fy + r.uniform(-0.2, 0.2),
			FL + 1.1 + r.uniform(0, 0.6)), r.choice((VERDE, VERDE_INCHIS, MASLINIU)), segmente=6, inele=4))
	_cutie_coliziune(col, (0.45, 0.45, 1.6), (fx, fy, FL + 0.8))
	for a, b in FER_JOS:
		piese.append(cub("Calorifer", (b - a - 0.1, 0.1, 0.55), ((a + b) / 2, G + 0.09, FL + 0.45), ALB))
		for k in range(int((b - a) / 0.07)):
			piese.append(cub("Element calorifer", (0.02, 0.12, 0.5), (a + 0.08 + k * 0.07, G + 0.09, FL + 0.45), CROM))
	piese.append(cilindru("Cuier", 0.025, 0.025, 1.75, (-1.2, G + 0.35, FL + 0.875), LEMN_INCHIS, laturi=6))
	piese.append(cilindru("Baza cuier", 0.22, 0.22, 0.03, (-1.2, G + 0.35, FL + 0.015), LEMN_INCHIS, laturi=6))
	piese.append(cub("Haina cuier", (0.4, 0.2, 0.75), (-1.2, G + 0.42, FL + 1.25), MASLINIU))
	piese.append(cilindru("Cos gunoi", 0.15, 0.13, 0.35, (1.05, G + 0.3, FL + 0.175), METAL, laturi=8))
	piese.append(cub("Pres intrare", (1.3, 0.8, 0.012), (0, G + 0.5, FL + 0.006), VERDE_NEGRU))
	_cutie_coliziune(col, (0.35, 0.35, 1.8), (-1.2, G + 0.35, FL + 0.9))
	strange()

	# --- holul de sus: banca, palmierul, tabloul cu primăria veche
	piese.append(cub("Banca hol", (1.4, 0.4, 0.06), (-3.2, YHOL + 0.5, FL2 + 0.45), LEMN_DESCHIS))
	piese.append(cub("Picioare banca", (1.3, 0.3, 0.42), (-3.2, YHOL + 0.5, FL2 + 0.21), METAL_INCHIS))
	_cutie_coliziune(col, (1.4, 0.4, 0.5), (-3.2, YHOL + 0.5, FL2 + 0.25))
	piese.append(cilindru("Ghiveci", 0.2, 0.16, 0.38, (XI - 0.4, YHOL + 0.55, FL2 + 0.19), ALB, laturi=10))
	for k in range(7):
		a = k * 2 * math.pi / 7
		piese.append(os_intre("Frunza palmier", (XI - 0.4, YHOL + 0.55, FL2 + 0.5), (XI - 0.4 + 0.45 * math.cos(a),
			YHOL + 0.55 + 0.45 * math.sin(a), FL2 + 1.2 + r.uniform(-0.1, 0.2)), 0.04, VERDE, laturi=3))
	piese.append(cub("Tablou hol", (0.9, 0.04, 0.6), (-2.0, YI1 - 0.04, FL2 + 1.75), AUR))
	piese.append(cub("Pictura hol", (0.78, 0.01, 0.48), (-2.0, YI1 - 0.065, FL2 + 1.75), GALBEN))
	piese.append(cub("Pictura cer", (0.78, 0.012, 0.18), (-2.0, YI1 - 0.068, FL2 + 1.9), GRI_ALBASTRU))
	strange()

	# =========================== BIROUL OVAL
	# --- covorul oval cu pecetea primarului (fără steag și fără vultur: o stea, „THE MAYOR” și cununa de spice)
	z = FL2
	piese.append(cilindru("Covor margine", 3.45, 3.45, 0.008, (0, OCY + 0.25, z + 0.004), AUR, laturi=40, scara=(1, 0.77, 1)))
	piese.append(cilindru("Covor", 3.25, 3.25, 0.008, (0, OCY + 0.25, z + 0.014), PETROL, laturi=40, scara=(1, 0.77, 1)))
	piese.append(cilindru("Pecete", 1.0, 1.0, 0.008, (0, OCY + 0.25, z + 0.024), AUR, laturi=28))
	# coliziunea covorului (cât e de gros cu pecetea): ce arunci pe el stă deasupra, nu dedesubt (owner, 08.10: banii
	# aruncați în birou nu se vedeau)
	col.append(cilindru("Coliziune", 3.45, 3.45, 0.04, (0, OCY + 0.25, z + 0.02), NEGRU, laturi=40, scara=(1, 0.77, 1)))
	piese.append(cilindru("Pecete mijloc", 0.82, 0.82, 0.008, (0, OCY + 0.25, z + 0.034), PETROL_DESCHIS, laturi=28))
	piese.append(cilindru("Stea mijloc", 0.21, 0.21, 0.008, (0, OCY + 0.25, z + 0.042), AUR, laturi=5))
	for k in range(0, 10, 2):
		a = k * math.pi / 5 + math.pi / 2
		piese.append(cub("Raza stea", (0.13, 0.36, 0.008), (0.24 * math.cos(a), OCY + 0.25 - 0.24 * math.sin(a), z + 0.042),
			AUR, rot=(0, 0, -a + math.pi / 2)))
	# (citit de la ușă: sus = spre birou)
	piese.append(_text_o_fata("Scris pecete", "THE MAYOR", (0, OCY + 0.25 - 0.66, z + 0.04), 0.1, AUR, rot=(0, 0, math.pi)))
	piese.append(_text_o_fata("Scris pecete", "OF OUR TOWN", (0, OCY + 0.25 + 0.66, z + 0.04), 0.08, AUR, rot=(0, 0, math.pi)))
	strange()

	# --- biroul masiv (ca Resolute desk): lemn închis, panouri sculptate, plăcuța cu numele în față
	mx, my = MX, MY
	piese.append(cub("Blat birou", (1.95, 1.0, 0.06), (mx, my, z + MZ - 0.03), LEMN_INCHIS))
	piese.append(cub("Piele blat", (1.2, 0.55, 0.008), (mx, my - 0.1, z + MZ + 0.004), VERDE_NEGRU))
	for semn in (-1, 1):
		piese.append(cub("Corp birou", (0.6, 0.92, MZ - 0.1), (mx + semn * 0.65, my, z + (MZ - 0.1) / 2 + 0.04), LEMN))
		piese.append(cub("Soclu birou", (0.66, 0.98, 0.06), (mx + semn * 0.65, my, z + 0.03), LEMN_INCHIS))
		for k in range(3):
			piese.append(cub("Sertar birou", (0.48, 0.02, 0.17), (mx + semn * 0.65, my - 0.47, z + 0.17 + k * 0.2), LEMN_INCHIS))
			piese.append(cub("Maner sertar", (0.1, 0.02, 0.02), (mx + semn * 0.65, my - 0.49, z + 0.2 + k * 0.2), AUR))
	# panoul din față (spre cameră = +Y): sculptat, cu plăcuța „MAYOR SMEGMA”
	piese.append(cub("Panou birou", (0.72, 0.04, MZ - 0.12), (mx, my + 0.46, z + (MZ - 0.12) / 2 + 0.04), LEMN))
	piese.append(cub("Sculptura birou", (0.5, 0.02, 0.42), (mx, my + 0.485, z + 0.36), LEMN_INCHIS))
	piese.append(cilindru("Ornament birou", 0.13, 0.13, 0.02, (mx, my + 0.5, z + 0.36), AUR, laturi=10, rot=(math.pi / 2, 0, 0)))
	for semn in (-1, 1):
		piese.append(cub("Panou lateral", (0.5, 0.02, 0.5), (mx + semn * 0.65, my + 0.47, z + 0.38), LEMN_INCHIS))
	piese.append(cub("Placuta nume", (0.55, 0.08, 0.1), (mx, my + 0.28, z + MZ + 0.05), AUR, rot=(0.5, 0, 0)))
	piese.append(_text_o_fata("Scris nume", "MAYOR SMEGMA", (mx, my + 0.33, z + MZ + 0.068), 0.045, NEGRU,
		rot=(math.pi / 2 - 0.5, 0, math.pi)))
	# pe birou: lampa verde de bancher, două telefoane, dosare, stiloul în suport, rama foto, sticla de whisky și paharul
	piese.append(cub("Baza lampa", (0.18, 0.12, 0.03), (mx - 0.7, my - 0.15, z + MZ + 0.015), AUR))
	piese.append(cilindru("Picior lampa", 0.015, 0.015, 0.3, (mx - 0.7, my - 0.15, z + MZ + 0.15), AUR, laturi=6))
	piese.append(cub("Abajur lampa", (0.34, 0.14, 0.08), (mx - 0.7, my - 0.08, z + MZ + 0.32), VERDE_INCHIS, rot=(-0.2, 0, 0)))
	lumini.append(cub("Bec lampa", (0.28, 0.08, 0.01), (mx - 0.7, my - 0.07, z + MZ + 0.27), AUR))
	for (tx, cul) in ((0.55, NEGRU), (0.78, ROSU)):
		piese.append(cub("Telefon", (0.18, 0.2, 0.07), (mx + tx, my - 0.2, z + MZ + 0.035), cul))
		piese.append(cub("Receptor", (0.2, 0.06, 0.04), (mx + tx, my - 0.25, z + MZ + 0.09), cul))
	piese.append(cub("Dosar birou", (0.24, 0.32, 0.03), (mx + 0.15, my + 0.1, z + MZ + 0.015), BRONZ, rot=(0, 0, 0.15)))
	piese.append(cub("Dosar birou", (0.24, 0.32, 0.02), (mx + 0.17, my + 0.08, z + MZ + 0.04), ALB, rot=(0, 0, 0.1)))
	piese.append(cub("Rama foto", (0.16, 0.03, 0.2), (mx - 0.35, my - 0.35, z + MZ + 0.1), AUR, rot=(0.15, 0, 0.3)))
	piese.append(cilindru("Sticla whisky", 0.05, 0.05, 0.22, (mx + 0.82, my + 0.2, z + MZ + 0.11), BRONZ, laturi=8))
	piese.append(cilindru("Gat sticla", 0.02, 0.02, 0.06, (mx + 0.82, my + 0.2, z + MZ + 0.25), BRONZ, laturi=6))
	piese.append(cilindru("Pahar whisky", 0.04, 0.04, 0.08, (mx + 0.65, my + 0.25, z + MZ + 0.04), ALB, laturi=8))
	piese.append(cub("Suport stilou", (0.18, 0.08, 0.04), (mx - 0.1, my + 0.25, z + MZ + 0.02), AUR))
	_cutie_coliziune(col, (1.95, 1.0, MZ), (mx, my, z + MZ / 2))
	strange()

	# --- canapelele față în față, măsuța dintre ele (cu un bol), măsuțele cu lămpi de la capete
	_canapea(piese, col, -1.55, OCY + 0.6, math.pi / 2, lung=1.9)
	_canapea(piese, col, 1.55, OCY + 0.6, -math.pi / 2, lung=1.9)
	piese.append(cub("Masuta", (0.6, 1.1, 0.04), (0, OCY + 0.6, z + 0.44), LEMN_INCHIS))
	for (dx, dy) in ((-0.25, -0.5), (0.25, -0.5), (-0.25, 0.5), (0.25, 0.5)):
		piese.append(cub("Picior masuta", (0.05, 0.05, 0.42), (dx, OCY + 0.6 + dy, z + 0.21), LEMN_INCHIS))
	piese.append(cilindru("Bol", 0.15, 0.1, 0.08, (0, OCY + 0.45, z + 0.5), ALB, laturi=10))
	for k in range(4):
		piese.append(sfera("Mar", 0.04, (r.uniform(-0.06, 0.06), OCY + 0.45 + r.uniform(-0.06, 0.06), z + 0.56), ROSU,
			segmente=6, inele=4))
	piese.append(cub("Revista", (0.22, 0.3, 0.012), (0.08, OCY + 0.9, z + 0.466), ROSU, rot=(0, 0, 0.3)))
	_cutie_coliziune(col, (0.6, 1.1, 0.46), (0, OCY + 0.6, z + 0.23))
	for (sx, sy) in ((-1.55, OCY - 0.77), (-1.55, OCY + 1.97), (1.55, OCY - 0.77), (1.55, OCY + 1.97)):
		piese.append(cub("Masuta lampa", (0.45, 0.45, 0.6), (sx, sy, z + 0.3), LEMN))
		piese.append(cilindru("Picior veioza", 0.06, 0.05, 0.35, (sx, sy, z + 0.78), AUR, laturi=8))
		piese.append(cilindru("Abajur veioza", 0.17, 0.12, 0.22, (sx, sy, z + 1.06), ALB, laturi=10))
		lumini.append(cilindru("Bec veioza", 0.1, 0.1, 0.02, (sx, sy, z + 0.95), AUR, laturi=8))
		_cutie_coliziune(col, (0.45, 0.45, 0.6), (sx, sy, z + 0.3))
	strange()

	# --- șemineul de pe peretele din stânga, cu portretul primarului deasupra, două fotolii aurii în fața lui
	fx = -OA + 0.02
	piese.append(cub("Semineu", (0.4, 1.7, 1.25), (fx + 0.2, OCY, z + 0.625), ALB))
	piese.append(cub("Gura semineu", (0.06, 0.85, 0.75), (fx + 0.41, OCY, z + 0.42), NEGRU))
	piese.append(cub("Polita semineu", (0.55, 1.95, 0.08), (fx + 0.25, OCY, z + 1.29), ALB))
	piese.append(cub("Vatra", (0.7, 1.5, 0.04), (fx + 0.7, OCY, z + 0.02), BETON))
	for k in range(3):
		piese.append(os_intre("Bustean", (fx + 0.32, OCY - 0.3 + k * 0.25, z + 0.12), (fx + 0.32, OCY - 0.1 + k * 0.25, z + 0.12),
			0.07, LEMN, laturi=6))
	_cutie_coliziune(col, (0.6, 1.95, 1.3), (fx + 0.3, OCY, z + 0.65))
	for dy in (-0.7, 0.7):
		piese.append(cilindru("Sfesnic", 0.04, 0.03, 0.3, (fx + 0.25, OCY + dy, z + 1.48), AUR, laturi=6))
	piese.append(cub("Ceas polita", (0.15, 0.32, 0.26), (fx + 0.25, OCY, z + 1.46), AUR))
	# portretul (fața primarului pe fundal închis, rama aurie groasă)
	piese.append(cub("Rama portret", (0.08, 1.05, 1.3), (fx + 0.06, OCY, z + 2.35), AUR))
	piese.append(cub("Portret", (0.02, 0.85, 1.1), (fx + 0.105, OCY, z + 2.35), LEMN_INCHIS))
	piese.append(cub("Portret costum", (0.02, 0.6, 0.4), (fx + 0.115, OCY, z + 2.0), NEGRU))
	piese.append(cub("Portret cravata", (0.02, 0.08, 0.3), (fx + 0.125, OCY, z + 2.05), ROSU))
	piese.append(sfera("Portret cap", 0.2, (fx + 0.12, OCY, z + 2.48), BRONZ, scara=(0.1, 1.0, 1.15), segmente=8, inele=6))
	piese.append(cub("Portret mustata", (0.02, 0.16, 0.035), (fx + 0.14, OCY, z + 2.42), LEMN_INCHIS))
	_fotoliu(piese, col, -2.95, OCY - 1.25, math.pi)
	_fotoliu(piese, col, -2.95, OCY + 1.25, 0.0)
	strange()

	# --- bibliotecile din dreapta (urmează peretele), globul, ceasul cu pendul, bustul, palmierii, coșul auriu
	for semn in (-1, 1):
		# lipită de peretele oval: spatele (+X în coordonatele ei) spre normala peretelui
		t = semn * 0.42
		wx, wy = _elipsa(t)
		nxv, nyv = math.cos(t) / OA, math.sin(t) / OB
		nl = math.hypot(nxv, nyv)
		nxv, nyv = nxv / nl, nyv / nl
		ung = math.atan2(nyv, nxv)
		b = [cub("Spate biblioteca", (0.04, 1.3, 2.4), (0.18, 0, z + 1.2), ALB)]
		for dy in (-0.63, 0.63):
			b.append(cub("Lateral biblioteca", (0.4, 0.04, 2.4), (0, dy, z + 1.2), ALB))
		b.append(cub("Soclu biblioteca", (0.4, 1.3, 0.2), (0, 0, z + 0.1), ALB))
		b.append(cub("Cornisa biblioteca", (0.46, 1.36, 0.08), (0, 0, z + 2.44), CROM))
		for k in range(5):
			b.append(cub("Raft", (0.36, 1.22, 0.03), (0, 0, z + 0.62 + k * 0.45), ALB))
		for k in range(4):
			_carti(b, -0.58, 0.58, 0.02, z + 0.635 + k * 0.45, r, axa="y")
		_roteste_muta(b, ung, (wx - nxv * 0.24, wy - nyv * 0.24))
		piese += b
		col.append(cub("Coliziune", (0.45, 1.3, 2.4), (wx - nxv * 0.24, wy - nyv * 0.24, z + 1.2), NEGRU, rot=(0, 0, ung)))
	piese.append(cilindru("Picior glob", 0.03, 0.03, 0.7, (3.2, OCY, z + 0.35), LEMN, laturi=6))
	piese.append(cilindru("Baza glob", 0.22, 0.22, 0.04, (3.2, OCY, z + 0.02), LEMN, laturi=8))
	piese.append(sfera("Glob", 0.28, (3.2, OCY, z + 0.95), PETROL, segmente=10, inele=7))
	piese.append(_tor("Meridian", 0.31, 0.012, (3.2, OCY, z + 0.95), AUR, rot=(math.pi / 2, 0, 0.4), segmente=16))
	for k in range(5):
		a = r.uniform(0, 2 * math.pi)
		h = r.uniform(-0.15, 0.15)
		piese.append(sfera("Continent", 0.09, (3.2 + 0.24 * math.cos(a), OCY + 0.24 * math.sin(a), z + 0.95 + h), MASLINIU,
			segmente=6, inele=4))
	_cutie_coliziune(col, (0.6, 0.6, 1.25), (3.2, OCY, z + 0.62))
	# ceasul cu pendul de lângă ușă
	piese.append(cub("Ceas pendul", (0.5, 0.35, 2.1), (2.2, 7.05, z + 1.05), LEMN_INCHIS, rot=(0, 0, 0.45)))
	piese.append(cilindru("Cadran ceas", 0.16, 0.16, 0.02, (2.12, 6.88, z + 1.75), ALB, laturi=14, rot=(math.pi / 2, 0, 0.45)))
	piese.append(cub("Usita pendul", (0.3, 0.02, 0.9), (2.12, 6.88, z + 0.85), AUR, rot=(0, 0, 0.45)))
	col.append(cub("Coliziune", (0.5, 0.35, 2.1), (2.2, 7.05, z + 1.05), NEGRU, rot=(0, 0, 0.45)))
	# bustul pe soclu (lângă fereastra din stânga) și palmierii din colțurile ferestrelor
	piese.append(cub("Soclu bust", (0.4, 0.4, 1.1), (-3.75, 1.85, z + 0.55), ALB))
	piese.append(sfera("Bust umeri", 0.22, (-3.75, 1.85, z + 1.28), CROM, scara=(1.3, 0.8, 0.6), segmente=8, inele=5))
	piese.append(sfera("Bust cap", 0.14, (-3.75, 1.85, z + 1.5), CROM, scara=(0.9, 1.0, 1.15), segmente=8, inele=6))
	_cutie_coliziune(col, (0.4, 0.4, 1.6), (-3.75, 1.85, z + 0.8))
	# palmierii: ghiveciul stătea pe peretele oval (frunzele intrau prin el și se vedeau doar câteva bețe drepte): acum stau
	# mai în cameră (la 82% din drumul de la centru spre perete), cu tulpina scurtă și frunze arcuite (urcă, apoi cad)
	rp = random.Random(17)  # separat de `r`, ca restul decorului să rămână la fel
	for t in (-0.667, 2.34):
		wx, wy = _elipsa(t)
		px, py = wx * 0.82, OCY + (wy - OCY) * 0.82
		piese.append(cilindru("Ghiveci palmier", 0.24, 0.2, 0.45, (px, py, z + 0.225), AUR, laturi=10))
		piese.append(cilindru("Pamant palmier", 0.215, 0.215, 0.02, (px, py, z + 0.44), LEMN_INCHIS, laturi=10))
		varf = (px, py, z + 1.15)
		piese.append(cilindru("Tulpina palmier", 0.05, 0.035, 0.72, (px, py, z + 0.8), LEMN, laturi=6))
		for k in range(9):
			a = k * 2 * math.pi / 9 + rp.uniform(-0.2, 0.2)
			ca, sa = math.cos(a), math.sin(a)
			lung = rp.uniform(0.45, 0.58)
			mij = (px + ca * lung * 0.5, py + sa * lung * 0.5, varf[2] + rp.uniform(0.22, 0.32))
			capat = (px + ca * lung, py + sa * lung, varf[2] + rp.uniform(-0.05, 0.1))
			piese.append(os_intre("Frunza palmier", varf, mij, 0.045, VERDE, laturi=3))
			piese.append(os_intre("Frunza palmier", mij, capat, 0.035, VERDE, laturi=3))
		_cutie_coliziune(col, (0.5, 0.5, 1.4), (px, py, z + 0.7))
	piese.append(cilindru("Cos auriu", 0.13, 0.11, 0.3, (0.95, 1.05, z + 0.15), AUR, laturi=8))
	# tablourile de pe pereți (peisaje) și aplicele dintre ferestre
	for (t, cul) in ((math.radians(150), MASLINIU), (math.radians(30), PETROL)):
		tx, ty = _elipsa(t)
		nxv, nyv = math.cos(t) / OA, math.sin(t) / OB
		nl = math.hypot(nxv, nyv)
		nxv, nyv = nxv / nl, nyv / nl
		ung = math.atan2(nyv, nxv) + math.pi / 2
		piese.append(cub("Rama tablou", (0.8, 0.05, 0.6), (tx - nxv * 0.03, ty - nyv * 0.03, z + 1.8), AUR, rot=(0, 0, ung)))
		piese.append(cub("Pictura", (0.66, 0.01, 0.46), (tx - nxv * 0.06, ty - nyv * 0.06, z + 1.8), cul, rot=(0, 0, ung)))
	for xa in (-1.1, 1.1, -3.4, 3.4):
		ya = _y_elipsa_fata(xa) + 0.06
		piese.append(cub("Aplica birou", (0.1, 0.08, 0.25), (xa, ya, z + 2.3), AUR))
		lumini.append(cub("Bec aplica", (0.06, 0.06, 0.08), (xa, ya + 0.03, z + 2.47), AUR))
	strange()

	uneste(piese, "Interior")
	uneste(geamuri, "Geamuri")
	uneste(lumini, "Lumini")
	uneste(col, "Coliziune")
	# înăuntru te uiți de aproape: ajung 10 mm (ca la recepția motelului)
	desparte_fete(distanta=0.01, fixe=("Tejghea", "Blat tejghea", "Perete ghiseu", "Covor margine", "Covor",
		"Baza canapea", "Spatar canapea", "Baza fotoliu", "Semineu", "Corp birou", "Piele blat", "Avizier", "Pluta avizier"))
	exporta(os.path.join(cale, "primarie_interior.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Afară: grădina, gardul, drumul, satul de vizavi
# ---------------------------------------------------------------------------------------------------------------

YG = -6.0           # gardul din față
YD0, YD1 = -14.0, -8.0   # drumul (asfalt)
XGARD = 12.0        # gardurile laterale


def _casa_sat(piese, col, x, y, lat, adanc, cul_zid, cul_acoperis, r, spre=1):
	"""Casă de țară: un nivel, tencuită, acoperiș în două ape cu coama pe X, două ferestre cu rame albastre spre drum,
	ușa, prispa cu stâlpi de lemn. `spre` = încotro e drumul (+1 = spre +Y)."""
	h = 2.7
	piese.append(cub("Casa", (lat, adanc, h), (x, y, h / 2), cul_zid))
	piese.append(cub("Soclu casa", (lat + 0.04, adanc + 0.04, 0.45), (x, y, 0.225), BETON))
	fata = y + spre * adanc / 2
	for prism_y in ((y - adanc / 2 - 0.25, y + adanc / 2 + 0.25),):
		piese.append(prisma("Acoperis casa", [(x - lat / 2 - 0.35, h - 0.05), (x + lat / 2 + 0.35, h - 0.05), (x, h + 1.6)],
			"xz", prism_y[0], prism_y[1], cul_acoperis))
	piese.append(cub("Coama casa", (0.15, adanc + 0.55, 0.1), (x, y, h + 1.6), METAL_INCHIS))
	for dx in (-lat / 4, lat / 4):
		piese.append(cub("Geam casa", (0.9, 0.04, 1.0), (x + dx, fata + spre * 0.02, 1.55), GEAM))
		piese.append(cub("Rama casa", (1.04, 0.05, 0.08), (x + dx, fata + spre * 0.03, 2.08), PETROL_DESCHIS))
		piese.append(cub("Rama casa", (1.04, 0.05, 0.08), (x + dx, fata + spre * 0.03, 1.02), PETROL_DESCHIS))
		piese.append(cub("Rama casa", (0.05, 0.05, 1.0), (x + dx, fata + spre * 0.035, 1.55), PETROL_DESCHIS))
		piese.append(cub("Perdea casa", (0.4, 0.01, 0.9), (x + dx - 0.2, fata + spre * 0.042, 1.55), ALB))
	piese.append(cub("Usa casa", (0.9, 0.05, 2.0), (x + lat / 2 - 0.8, fata + spre * 0.02, 1.0), LEMN))
	# prispa: stâlpi de lemn, streașina prelungită
	for k in range(4):
		px = x - lat / 2 + 0.2 + k * (lat - 0.4) / 3
		piese.append(cub("Stalp prispa", (0.12, 0.12, h - 0.45), (px, fata + spre * 1.1, 0.45 + (h - 0.45) / 2), LEMN_DESCHIS))
	piese.append(cub("Prispa", (lat + 0.2, 1.3, 0.45), (x, fata + spre * 0.65, 0.225), BETON))
	piese.append(cub("Streasina prispa", (lat + 0.3, 1.5, 0.08), (x, fata + spre * 0.75, h + 0.02), cul_acoperis))
	_cutie_coliziune(col, (lat, adanc + 2.6, h), (x, y + spre * 1.3, h / 2))


def _bicicleta(piese, col, cx, cy, rot):
	"""O bicicletă veche de oraș (ca o Pegas): cadru romb turcoaz, roți cu spițe, aripi cromate, portbagaj, ghidon
	întors, șa de piele, pedalier cu foaie, pe cric (înclinată puțin spre el). În coordonatele ei: lungimea pe X (fața
	spre +X), lățimea pe Y, roțile la z = 0,34; o rotesc cu `rot` și o mut în (cx, cy)."""
	from mathutils import Matrix, Vector
	R = 0.34
	spate, fata = Vector((-0.52, 0, R)), Vector((0.52, 0, R))
	pedalier = Vector((-0.08, 0, 0.29))
	sa = Vector((-0.24, 0, 0.82))          # capătul de sus al tubului de șa
	cap_sus, cap_jos = Vector((0.33, 0, 0.8)), Vector((0.37, 0, 0.66))
	s = []
	for (c, nume) in ((spate, "spate"), (fata, "fata")):
		s.append(_tor("Cauciuc bicicleta", R - 0.02, 0.022, tuple(c), NEGRU, rot=(math.pi / 2, 0, 0), segmente=20))
		s.append(_tor("Janta bicicleta", R - 0.05, 0.012, tuple(c), CROM, rot=(math.pi / 2, 0, 0), segmente=20))
		s.append(cilindru("Butuc bicicleta", 0.025, 0.025, 0.1, tuple(c), CROM, laturi=8, rot=(math.pi / 2, 0, 0)))
		for k in range(12):
			a = k * math.pi / 6 + (0.13 if nume == "fata" else 0.0)
			s.append(os_intre("Spita", tuple(c), (c.x + (R - 0.06) * math.cos(a), 0, c.z + (R - 0.06) * math.sin(a)), 0.003,
				CROM, laturi=3))
		# aripa (apărătoarea): un sfert de cerc de bucăți scurte deasupra roții
		for k in range(7):
			a0, a1 = math.radians(20 + k * 20), math.radians(40 + k * 20)
			if nume == "fata":
				a0, a1 = math.radians(160 - k * 20), math.radians(140 - k * 20)
			s.append(os_intre("Aripa bicicleta", (c.x + (R + 0.04) * math.cos(a0), 0, c.z + (R + 0.04) * math.sin(a0)),
				(c.x + (R + 0.04) * math.cos(a1), 0, c.z + (R + 0.04) * math.sin(a1)), 0.022, CROM, laturi=4))
	# cadrul (romb): tubul de sus, tubul diagonal, tubul de șa, furcile din spate (jos și sus, pe ambele părți), furca față
	tub = lambda a, b, g=0.019: s.append(os_intre("Cadru bicicleta", tuple(a), tuple(b), g, TEAL, laturi=6))
	tub(sa, cap_sus)
	tub(pedalier, cap_jos, 0.022)
	tub(pedalier, sa)
	tub(cap_jos, cap_sus, 0.024)
	for dy in (-0.05, 0.05):
		tub(spate + Vector((0, dy, 0)), pedalier, 0.012)
		tub(spate + Vector((0, dy, 0)), sa - Vector((0, 0, 0.03)), 0.012)
		tub(fata + Vector((0, dy, 0)), cap_jos + Vector((0, dy * 0.6, 0)), 0.013)
	# șaua: tija cromată și șaua de piele cu arcurile dedesubt
	tija = sa + Vector((-0.03, 0, 0.12))
	s.append(os_intre("Tija sa", tuple(sa), tuple(tija), 0.012, CROM, laturi=6))
	s.append(cub("Sa bicicleta", (0.26, 0.15, 0.05), tuple(tija + Vector((0.0, 0, 0.03))), NEGRU))
	s.append(cub("Varf sa", (0.1, 0.07, 0.04), tuple(tija + Vector((0.16, 0, 0.035))), NEGRU))
	for dy in (-0.05, 0.05):
		s.append(cilindru("Arc sa", 0.018, 0.018, 0.04, tuple(tija + Vector((-0.08, dy, 0))), CROM, laturi=6))
	# ghidonul: pipa, ghidonul întors spre șa, mânerele negre, clopoțelul
	pipa = cap_sus + Vector((-0.02, 0, 0.12))
	s.append(os_intre("Pipa ghidon", tuple(cap_sus), tuple(pipa), 0.014, CROM, laturi=6))
	for semn in (-1, 1):
		capat = pipa + Vector((-0.12, semn * 0.26, 0.02))
		s.append(os_intre("Ghidon", tuple(pipa), tuple(pipa + Vector((-0.02, semn * 0.14, 0))), 0.011, CROM, laturi=6))
		s.append(os_intre("Ghidon", tuple(pipa + Vector((-0.02, semn * 0.14, 0))), tuple(capat), 0.011, CROM, laturi=6))
		s.append(os_intre("Maner ghidon", tuple(capat), tuple(capat + Vector((-0.1, semn * 0.02, 0))), 0.017, NEGRU, laturi=6))
	s.append(cilindru("Clopotel", 0.03, 0.025, 0.02, tuple(pipa + Vector((-0.03, 0.1, 0.03))), CROM, laturi=8))
	s.append(cub("Far bicicleta", (0.05, 0.07, 0.07), tuple(cap_jos + Vector((0.06, 0, 0.05))), CROM))
	# pedalierul: foaia, angrenajul, pedalele (o pedală sus în față, cealaltă jos în spate), lanțul
	s.append(_tor("Foaie", 0.09, 0.008, tuple(pedalier + Vector((0, 0.06, 0))), CROM, rot=(math.pi / 2, 0, 0), segmente=14))
	s.append(cilindru("Ax pedalier", 0.03, 0.03, 0.14, tuple(pedalier), CROM, laturi=8, rot=(math.pi / 2, 0, 0)))
	for (semn, ung) in ((1, 0.6), (-1, 0.6 + math.pi)):
		capat = pedalier + Vector((0.17 * math.cos(ung), semn * 0.08, 0.17 * math.sin(ung)))
		s.append(os_intre("Pedala brat", tuple(pedalier + Vector((0, semn * 0.08, 0))), tuple(capat), 0.012, CROM, laturi=4))
		s.append(cub("Pedala", (0.09, 0.1, 0.025), tuple(capat + Vector((0, semn * 0.05, 0))), NEGRU))
	for dz in (-0.09, 0.09):
		s.append(os_intre("Lant", tuple(pedalier + Vector((0, 0.06, dz))), tuple(spate + Vector((0, 0.06, dz * 0.45))), 0.006,
			METAL_INCHIS, laturi=3))
	# portbagajul de deasupra roții din spate
	for dy in (-0.07, 0.07):
		s.append(os_intre("Portbagaj", tuple(spate + Vector((0, dy, 0))), tuple(spate + Vector((0.02, dy, 0.42))), 0.008,
			CROM, laturi=4))
		s.append(os_intre("Portbagaj", (spate.x - 0.12, dy, R + 0.42), (sa.x - 0.04, dy, R + 0.42), 0.008, CROM, laturi=4))
	s.append(os_intre("Portbagaj", (sa.x - 0.04, -0.07, R + 0.42), (sa.x - 0.02, 0, sa.z - 0.02), 0.008, CROM, laturi=4))
	s.append(cub("Catadioptru", (0.02, 0.06, 0.04), (spate.x - 0.12, 0, R + 0.38), ROSU))
	# cricul, din pedalier în jos și puțin spre stânga
	s.append(os_intre("Cric", tuple(pedalier + Vector((-0.04, -0.05, 0))), (pedalier.x - 0.1, -0.2, 0.01), 0.01, CROM, laturi=4))
	inclinare = Matrix.Rotation(math.radians(6), 4, 'X')     # pe cric se lasă puțin spre stânga (-Y)
	for ob in s:
		ob.data.transform(inclinare)
	_roteste_muta(s, rot, (cx, cy))
	piese += s
	_cutie_coliziune(col, (1.75, 0.6, 1.0), (cx, cy, 0.5))


def _scaun_plastic(piese, col, cx, cy, rot):
	"""Scaunul alb de plastic, ca la terasă: șezut, picioare răsfirate, spătar cu fante, brațe. Fața spre -Y."""
	s = [cub("Sezut plastic", (0.44, 0.42, 0.04), (0, 0, 0.43), ALB)]
	for (dx, dy) in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
		s.append(os_intre("Picior plastic", (dx * 0.19, dy * 0.18, 0.42), (dx * 0.24, dy * 0.23, 0.0), 0.022, ALB, laturi=5))
	s.append(cub("Spatar plastic", (0.44, 0.04, 0.42), (0, 0.24, 0.66), ALB, rot=(-0.18, 0, 0)))
	for dx in (-0.12, 0.0, 0.12):
		s.append(cub("Fanta spatar", (0.05, 0.05, 0.22), (dx, 0.245, 0.68), METAL_INCHIS, rot=(-0.18, 0, 0)))
	for semn in (-1, 1):
		s.append(cub("Brat plastic", (0.05, 0.38, 0.03), (semn * 0.22, 0.02, 0.62), ALB))
		s.append(cub("Suport brat", (0.04, 0.04, 0.18), (semn * 0.22, -0.15, 0.53), ALB))
	_roteste_muta(s, rot, (cx, cy))
	piese += s
	_cutie_coliziune(col, (0.5, 0.5, 0.9), (cx, cy, 0.45))


def _gard_lemn(piese, x0, x1, y, r, cul=LEMN, col=None):
	"""Gard de scânduri (uluci) cu două rigle, pe X. Cu `col`, primește și coliziune (un perete de 1,5 m)."""
	if col is not None:
		_cutie_coliziune(col, (x1 - x0, 0.2, 1.5), ((x0 + x1) / 2, y - 0.02, 0.75))
	piese.append(cub("Rigla gard", (x1 - x0, 0.04, 0.08), ((x0 + x1) / 2, y, 0.45), LEMN_INCHIS))
	piese.append(cub("Rigla gard", (x1 - x0, 0.04, 0.08), ((x0 + x1) / 2, y, 1.15), LEMN_INCHIS))
	x = x0 + 0.06
	while x < x1:
		if r.random() > 0.04:
			h = r.uniform(1.35, 1.5)
			piese.append(cub("Uluca", (0.1, 0.025, h), (x, y - 0.03, h / 2), cul, rot=(0, r.uniform(-0.04, 0.04), 0)))
		x += 0.14


def _pom(piese, x, y, r, inalt=4.5, varuit=True):
	"""Pom cu tulpina văruită (alb până la 1 m), crengi și coroană de toamnă din bulgări."""
	piese.append(cilindru("Tulpina", 0.13, 0.1, 1.0, (x, y, 0.5), ALB if varuit else LEMN, laturi=7))
	piese.append(cilindru("Tulpina", 0.1, 0.07, inalt - 1.6, (x, y, 1.0 + (inalt - 1.6) / 2), LEMN, laturi=7))
	for k in range(4):
		a = k * math.pi / 2 + r.uniform(-0.4, 0.4)
		piese.append(os_intre("Creanga", (x, y, inalt - 1.4), (x + 0.9 * math.cos(a), y + 0.9 * math.sin(a), inalt - 0.6),
			0.04, LEMN, laturi=5))
	for k in range(9):
		piese.append(sfera("Coroana", r.uniform(0.6, 0.95), (x + r.uniform(-0.9, 0.9), y + r.uniform(-0.9, 0.9),
			inalt - 0.6 + r.uniform(-0.3, 0.6)), r.choice((MASLINIU, BRONZ, AUR, VERDE)), segmente=7, inele=5))


def curte(cale):
	"""Terenul (900 m, cât să nu se vadă marginea), drumul cu acostamentul, stația, gardul primăriei cu poarta deschisă,
	grădina, magazinul satului din stânga, casa din dreapta, satul de peste drum (case, garduri, fântâna cu cumpănă,
	stâlpii cu fire), biserica în ceață. Piese `Curte`, `Lumini`, `Coliziune`."""
	curata()
	r = random.Random(1918)
	piese, lumini, col = [], [], []

	def strange():
		_ramas(piese, "Curte")

	# --- terenul, drumul, acostamentele
	piese.append(cub("Teren", (900.0, 900.0, 0.1), (0, 0, -0.05), VERDE))
	_cutie_coliziune(col, (200.0, 200.0, 0.2), (0, 0, -0.1))
	piese.append(cub("Asfalt", (900.0, YD1 - YD0, 0.02), (0, (YD0 + YD1) / 2, 0.0), NEGRU))
	for semn_y in (YD0, YD1):
		piese.append(cub("Acostament", (900.0, 1.2, 0.02), (0, semn_y + (0.6 if semn_y == YD1 else -0.6), 0.004), BETON))
	x = -200.0
	while x < 200.0:
		if r.random() < 0.8:
			piese.append(cub("Marcaj drum", (2.5, 0.12, 0.006), (x, (YD0 + YD1) / 2, 0.022), ALB))
		x += 6.0
	for k in range(14):
		piese.append(cub("Petic asfalt", (r.uniform(0.6, 2.0), r.uniform(0.5, 1.6), 0.006), (r.uniform(-30, 30),
			r.uniform(YD0 + 0.6, (YD0 + YD1) / 2 - 0.4), 0.015), GEAM, rot=(0, 0, r.uniform(-0.3, 0.3))))
	# între drum și gard: iarbă și o rigolă (șanț) betonată
	piese.append(cub("Rigola", (900.0, 0.5, 0.02), (0, YD1 + 1.5, 0.006), BETON))
	strange()

	# --- gardul primăriei: soclu de beton, stâlpi tencuiți, bare de fier vopsite verde (unele ruginite), poarta deschisă
	def gard_fier(x0, x1, y, axa="x"):
		if axa == "x":
			piese.append(cub("Soclu gard", (x1 - x0, 0.25, 0.35), ((x0 + x1) / 2, y, 0.175), BETON))
			_cutie_coliziune(col, (x1 - x0, 0.25, 1.5), ((x0 + x1) / 2, y, 0.75))
		else:
			piese.append(cub("Soclu gard", (0.25, x1 - x0, 0.35), (y, (x0 + x1) / 2, 0.175), BETON))
			_cutie_coliziune(col, (0.25, x1 - x0, 1.5), (y, (x0 + x1) / 2, 0.75))
		n = max(1, int((x1 - x0) / 2.4 + 0.5))
		for k in range(n + 1):
			s = x0 + k * (x1 - x0) / n
			loc = (s, y, 0.35 + 0.65) if axa == "x" else (y, s, 1.0)
			piese.append(cub("Stalp gard", (0.32, 0.32, 1.3), loc, GALBEN))
			loc_c = (loc[0], loc[1], 1.68)
			piese.append(cub("Capac stalp", (0.4, 0.4, 0.06), loc_c, BETON))
		s = x0 + 0.2
		while s < x1 - 0.1:
			cul = VERDE_INCHIS if r.random() > 0.15 else RUGINA
			loc = (s, y, 0.85) if axa == "x" else (y, s, 0.85)
			piese.append(cub("Bara gard", (0.025, 0.025, 1.0), loc, cul))
			s += 0.13
		for z in (0.45, 1.25):
			if axa == "x":
				piese.append(cub("Rigla fier", (x1 - x0, 0.04, 0.04), ((x0 + x1) / 2, y, z), VERDE_INCHIS))
			else:
				piese.append(cub("Rigla fier", (0.04, x1 - x0, 0.04), (y, (x0 + x1) / 2, z), VERDE_INCHIS))

	gard_fier(-XGARD, -1.0, YG)
	gard_fier(1.0, XGARD, YG)
	gard_fier(YG, 14.0, -XGARD, axa="y")
	gard_fier(YG, 14.0, XGARD, axa="y")
	gard_fier(-XGARD, XGARD, 14.0)
	# poarta: două foi de fier deschise spre curte, una căzută puțin din balama
	for semn, ung in ((-1, 1.25), (1, -1.35)):
		bx = semn * 1.0
		foaie = []
		foaie.append(cub("Rama poarta", (0.92, 0.04, 0.05), (-semn * 0.46, 0, 1.35), VERDE_INCHIS))
		foaie.append(cub("Rama poarta", (0.92, 0.04, 0.05), (-semn * 0.46, 0, 0.2), VERDE_INCHIS))
		for k in range(7):
			foaie.append(cub("Bara poarta", (0.025, 0.025, 1.2), (-semn * (0.06 + k * 0.13), 0, 0.78), VERDE_INCHIS))
		foaie.append(_tor("Ornament poarta", 0.14, 0.015, (-semn * 0.46, 0, 0.78), VERDE_INCHIS, rot=(math.pi / 2, 0, 0)))
		_roteste_muta(foaie, ung, (bx, YG))
		piese += foaie
	strange()

	# --- aleea de dale (crăpate, câteva lipsă), grădina: iarbă uscată, pământ, cauciucuri albe cu flori uscate, pomii
	y = YG + 0.3
	while y < -2.3:
		for dx in (-0.31, 0.31):
			if r.random() > 0.08:  # câteva dale lipsesc
				piese.append(cub("Dala", (0.58, 0.58, 0.04), (dx, y + 0.3, 0.02), BETON if r.random() > 0.2 else METAL,
					rot=(0, 0, r.uniform(-0.04, 0.04))))
		y += 0.62
	for k in range(10):
		w, h = r.uniform(0.5, 1.3), r.uniform(0.4, 1.0)
		xx = r.choice((r.uniform(-11, -1.6), r.uniform(1.6, 11)))
		piese.append(cub("Iarba uscata", (w, h, 0.01), (xx, r.uniform(YG + 0.8, -2.8), 0.004), r.choice((MASLINIU, LEMN_INCHIS, MASLINIU))))
	for k in range(40):
		xx = r.choice((r.uniform(-11, -1.0), r.uniform(1.0, 11)))
		yy = r.uniform(YG + 0.4, 13.0) if abs(xx) > 10.3 else r.uniform(YG + 0.4, -2.6)
		piese.append(cilindru("Smoc", 0.1, 0.02, r.uniform(0.15, 0.35), (xx, yy, 0.1), r.choice((MASLINIU, VERDE, AUR)), laturi=4))
	for (cx, cy) in ((-3.0, -3.6), (3.0, -3.6), (-5.0, -4.6), (5.2, -4.8)):
		piese.append(_tor("Cauciuc", 0.42, 0.12, (cx, cy, 0.06), ALB, segmente=12))
		piese.append(cilindru("Pamant strat", 0.36, 0.36, 0.06, (cx, cy, 0.04), LEMN_INCHIS, laturi=10))
		for k in range(5):
			a = r.uniform(0, 2 * math.pi)
			fx, fy = cx + 0.18 * math.cos(a), cy + 0.18 * math.sin(a)
			hz = r.uniform(0.3, 0.55)
			piese.append(os_intre("Tulpina floare", (fx, fy, 0.06), (fx + r.uniform(-0.05, 0.05), fy, hz), 0.008, MASLINIU,
				laturi=3))
			piese.append(sfera("Floare uscata", 0.04, (fx, fy, hz), r.choice((ROSU, BRONZ, AUR)), segmente=5, inele=3))
		_cutie_coliziune(col, (0.9, 0.9, 0.2), (cx, cy, 0.1))
	_pom(piese, -7.2, -3.4, r)
	_pom(piese, 7.0, -4.2, r, inalt=5.0)
	_cutie_coliziune(col, (0.3, 0.3, 3.0), (-7.2, -3.4, 1.5))
	_cutie_coliziune(col, (0.3, 0.3, 3.0), (7.0, -4.2, 1.5))
	# banca de lângă alee (picioare de beton, scânduri, una lipsă), coșul de gunoi ruginit, avizierul de la poartă
	for dx in (-0.65, 0.65):
		piese.append(cub("Picior banca", (0.12, 0.45, 0.42), (-2.6 + dx, -4.9, 0.21), BETON))
	for k, dy in enumerate((-0.15, 0.0, 0.15)):
		if k != 1:
			piese.append(cub("Scandura banca", (1.6, 0.12, 0.04), (-2.6, -4.9 + dy, 0.44), LEMN_DESCHIS))
	_cutie_coliziune(col, (1.6, 0.45, 0.45), (-2.6, -4.9, 0.22))
	piese.append(cilindru("Cos gunoi", 0.2, 0.18, 0.6, (-1.3, -5.3, 0.3), RUGINA, laturi=8))
	piese.append(cub("Avizier curte", (1.4, 0.12, 0.9), (2.6, YG + 0.35, 1.25), LEMN))
	geamuri_av = cub("Geam avizier", (1.24, 0.01, 0.74), (2.6, YG + 0.28, 1.25), GEAM)
	piese.append(geamuri_av)
	for k in range(4):
		piese.append(cub("Foaie avizier", (0.2, 0.012, 0.28), (2.1 + k * 0.32, YG + 0.3, 1.25 + r.uniform(-0.1, 0.1)),
			r.choice((ALB, AUR, ALB))))
	for dx in (-0.6, 0.6):
		piese.append(cub("Picior avizier", (0.08, 0.08, 1.3), (2.6 + dx, YG + 0.35, 0.65), LEMN_INCHIS))
	_cutie_coliziune(col, (1.4, 0.2, 1.7), (2.6, YG + 0.35, 0.85))
	# o bicicletă veche pe cric, lângă gard, pe dinafară (owner, 08.10: cea veche era „făcută prost”)
	_bicicleta(piese, col, -5.5, YG - 0.55, 0.0)
	strange()

	# --- vecinii: în stânga „GENERAL STORE” (magazinul mixt al satului), în dreapta o casă
	sx0, sx1 = -24.0, -14.0
	piese.append(cub("Magazin", (sx1 - sx0, 8.0, 3.2), ((sx0 + sx1) / 2, -1.0, 1.6), ALB))
	piese.append(cub("Soclu magazin", (sx1 - sx0 + 0.04, 8.04, 0.5), ((sx0 + sx1) / 2, -1.0, 0.25), BETON))
	piese.append(prisma("Acoperis magazin", [(sx0 - 0.3, 3.15), (sx1 + 0.3, 3.15), ((sx0 + sx1) / 2, 4.6)], "xz", -5.3, 3.3,
		METAL))
	piese.append(cub("Firma magazin", (5.0, 0.1, 0.7), ((sx0 + sx1) / 2, -5.06, 2.75), PETROL))
	piese.append(_text("Scris magazin", "GENERAL STORE", ((sx0 + sx1) / 2, -5.13, 2.75), 0.38, ALB))
	piese.append(cub("Vitrina magazin", (2.6, 0.04, 1.4), (-20.8, -5.02, 1.45), GEAM))
	piese.append(cub("Usa magazin", (1.0, 0.04, 2.1), (-17.2, -5.02, 1.05), PETROL_DESCHIS))
	for k in range(3):
		piese.append(cub("Afis vitrina", (0.4, 0.01, 0.5), (-21.6 + k * 0.7, -5.05, 1.5), r.choice((ROSU, AUR, ALB))))
	# lăzile de bere (trei pe jos, una pusă peste prima, cu sticlele în ele) și scaunele de plastic din fața magazinului;
	# owner, 08.10: scaunele „pluteau” (n-aveau picioare), a patra ladă stătea în aer și lăzile n-aveau coliziune
	for (lx, ly, lz, rl) in ((-15.4, -5.9, 0.0, 0.0), (-14.95, -5.9, 0.0, 0.05), (-15.4, -6.27, 0.0, -0.04),
			(-15.4, -5.9, 0.3, 0.12)):
		cul = r.choice((ROSU, AUR))
		s = [cub("Lada bere", (0.4, 0.3, 0.26), (0, 0, lz + 0.13), cul),
			cub("Buza lada", (0.42, 0.32, 0.04), (0, 0, lz + 0.28), cul)]
		for i in range(4):
			for j in range(3):
				s.append(cilindru("Sticla lada", 0.025, 0.025, 0.06, (-0.15 + i * 0.1, -0.09 + j * 0.09, lz + 0.31), BRONZ,
					laturi=6))
		_roteste_muta(s, rl, (lx, ly))
		piese += s
	_cutie_coliziune(col, (0.85, 0.7, 0.3), (-15.18, -6.08, 0.15))
	_cutie_coliziune(col, (0.45, 0.35, 0.65), (-15.4, -5.9, 0.33))
	for k in range(2):
		_scaun_plastic(piese, col, -18.6 + k * 0.9, -6.1, (k - 0.5) * 0.3)
	_cutie_coliziune(col, (sx1 - sx0, 8.0, 3.2), ((sx0 + sx1) / 2, -1.0, 1.6))
	_casa_sat(piese, col, 19.0, 2.0, 7.0, 6.0, TEAL_DESCHIS, METAL, r, spre=-1)
	_gard_lemn(piese, 13.5, 26.0, YG, r, col=col)
	strange()

	# --- peste drum: case de țară cu gard de uluci, fântâna cu cumpănă, nuci, stâlpii de beton cu fire
	for (cx, lat, cul, acop) in ((-26.0, 8.0, GALBEN, TABLA), (-12.0, 7.5, ALB, METAL), (2.0, 9.0, TEAL_DESCHIS, TABLA),
			(16.0, 7.0, GRI_ALBASTRU, METAL_INCHIS), (30.0, 8.0, ALB, TABLA)):
		_casa_sat(piese, col, cx, -26.0, lat, 6.0, cul, acop, r, spre=1)
		_gard_lemn(piese, cx - 7.0, cx + 6.0, YD0 - 1.8, r, cul=r.choice((LEMN, LEMN_DESCHIS, PETROL_DESCHIS)))
		strange()
	_cutie_coliziune(col, (90.0, 0.2, 1.6), (0, YD0 - 1.8, 0.8))
	# fântâna cu cumpănă
	fx, fy = -4.5, -18.5
	piese.append(cilindru("Ghizd", 0.6, 0.6, 0.8, (fx, fy, 0.4), BETON, laturi=10))
	piese.append(cilindru("Apa fantana", 0.5, 0.5, 0.02, (fx, fy, 0.78), GEAM, laturi=10))
	piese.append(cilindru("Furca cumpana", 0.12, 0.1, 3.2, (fx + 2.2, fy, 1.6), LEMN, laturi=6))
	piese.append(os_intre("Cumpana", (fx + 5.0, fy, 1.2), (fx - 0.2, fy, 4.8), 0.07, LEMN, laturi=6))
	piese.append(os_intre("Prajina", (fx - 0.1, fy, 4.75), (fx - 0.05, fy, 1.4), 0.025, LEMN_INCHIS, laturi=4))
	piese.append(cilindru("Galeata", 0.14, 0.12, 0.25, (fx - 0.05, fy, 1.3), METAL, laturi=8))
	piese.append(cub("Contragreutate", (0.35, 0.3, 0.3), (fx + 5.0, fy, 1.05), BETON))
	_cutie_coliziune(col, (1.3, 1.3, 0.8), (fx, fy, 0.4))
	_pom(piese, 10.0, -19.0, r, inalt=6.0, varuit=False)
	_pom(piese, -18.0, -20.0, r, inalt=5.5, varuit=True)
	# stâlpii de beton de pe marginea drumului (de partea primăriei) cu fire lăsate, și becul stradal
	stalpi = [(x, YD1 + 0.9) for x in (-37.0, -17.0, 3.6, 24.0, 44.0)]
	for (sx, sy) in stalpi:
		piese.append(cub("Stalp beton", (0.22, 0.3, 8.5), (sx, sy, 4.25), BETON))
		piese.append(cub("Consola", (1.4, 0.1, 0.1), (sx, sy, 8.2), METAL_INCHIS))
		_cutie_coliziune(col, (0.25, 0.32, 8.5), (sx, sy, 4.25))
	for (a, b) in zip(stalpi, stalpi[1:]):
		for dx in (-0.6, 0.6):
			m = ((a[0] + b[0]) / 2, a[1], 7.7)
			piese.append(os_intre("Fir", (a[0] + dx, a[1], 8.25), (m[0] + dx, m[1], m[2]), 0.012, NEGRU, laturi=3))
			piese.append(os_intre("Fir", (m[0] + dx, m[1], m[2]), (b[0] + dx, b[1], 8.25), 0.012, NEGRU, laturi=3))
	piese.append(os_intre("Brat lampa", (3.6, YD1 + 0.9, 7.2), (3.6, YD1 - 0.6, 7.4), 0.04, METAL, laturi=5))
	piese.append(cub("Lampa drum", (0.25, 0.5, 0.12), (3.6, YD1 - 0.75, 7.35), METAL_INCHIS))
	# biserica din sat, în ceață (corpul, turnul cu acoperiș ascuțit, crucea)
	bx, by = 34.0, -70.0
	piese.append(cub("Biserica", (10.0, 18.0, 7.0), (bx, by, 3.5), ALB))
	piese.append(prisma("Acoperis biserica", [(bx - 5.4, 6.9), (bx + 5.4, 6.9), (bx, 10.5)], "xz", by - 9.4, by + 9.4, METAL))
	piese.append(cub("Turn biserica", (4.0, 4.0, 14.0), (bx, by + 9.0, 7.0), ALB))
	piese.append(cilindru("Turla", 2.8, 0.05, 7.0, (bx, by + 9.0, 17.5), METAL_INCHIS, laturi=8))
	piese.append(cub("Cruce", (0.12, 0.12, 1.4), (bx, by + 9.0, 21.6), AUR))
	piese.append(cub("Cruce", (0.8, 0.12, 0.12), (bx, by + 9.0, 21.8), AUR))
	strange()

	uneste(piese, "Curte")
	if lumini:
		uneste(lumini, "Lumini")
	uneste(col, "Coliziune")
	exporta(os.path.join(cale, "primarie_curte.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Ușile, scaunul primarului, teancul de bani
# ---------------------------------------------------------------------------------------------------------------

def usa_primarie(cale):
	"""Ușa de la intrare: lemn vopsit maro, cu geam sus și gratii, clanța de alamă. Originea în balama (stânga, jos),
	foaia spre +X (1,2 m), grosimea pe Y."""
	curata()
	piese, geamuri = [], []
	L, H = 1.2, 2.45
	piese.append(cub("Foaie usa", (L, 0.06, 1.25), (L / 2, 0, 0.625), LEMN))
	piese.append(cub("Foaie usa", (L, 0.06, 0.25), (L / 2, 0, H - 0.125), LEMN))
	for x in (0.06, L - 0.06, L / 2):
		piese.append(cub("Foaie usa", (0.12 if x != L / 2 else 0.06, 0.06, H - 1.5), (x, 0, 1.25 + (H - 1.5) / 2), LEMN))
	geamuri.append(cub("Geam usa", (L - 0.24, 0.01, H - 1.5), (L / 2, 0, 1.25 + (H - 1.5) / 2), GEAM))
	for k in range(5):
		piese.append(cub("Gratie usa", (0.02, 0.1, H - 1.5), (0.2 + k * 0.2, -0.02, 1.25 + (H - 1.5) / 2), NEGRU))
	for dz in (0.35, 0.9):
		for semn in (-1, 1):
			piese.append(cub("Panou usa", (L - 0.3, 0.012, 0.38), (L / 2, semn * 0.033, dz), LEMN_INCHIS))
	for semn in (-1, 1):
		piese.append(cub("Clanta", (0.14, 0.05, 0.03), (L - 0.15, semn * 0.06, 1.0), AUR))
	piese.append(cub("Plinta usa", (L, 0.07, 0.12), (L / 2, 0, 0.06), METAL))
	uneste(piese, "Usa")
	uneste(geamuri, "GeamUsa")
	exporta(os.path.join(cale, "usa_primarie.glb"))


def usa_birou(cale):
	"""Ușa biroului primarului: albă, cu panouri și clanță aurie. Originea în balama, foaia spre +X (1,1 m)."""
	curata()
	piese = []
	L, H = 1.1, 2.3
	piese.append(cub("Foaie usa", (L, 0.05, H), (L / 2, 0, H / 2), ALB))
	for semn in (-1, 1):
		for (dz, h) in ((0.5, 0.7), (1.55, 1.0)):
			piese.append(cub("Panou usa", (L - 0.3, 0.012, h), (L / 2, semn * 0.029, dz), CROM))
		piese.append(cub("Clanta", (0.14, 0.05, 0.03), (L - 0.12, semn * 0.05, 1.0), AUR))
	exporta_ob = uneste(piese, "Usa")
	exporta(os.path.join(cale, "usa_birou_primar.glb"))


def scaun_primar(cale):
	"""Fotoliul de birou al primarului: piele închisă, spătar înalt capitonat, pe rotile. Originea jos, în mijlocul
	șezutului; fața spre -Y (în Godot +Z)."""
	curata()
	piese = []
	piese.append(cub("Sezut fotoliu", (0.62, 0.6, 0.12), (0, 0, 0.47), LEMN_INCHIS))
	piese.append(cub("Spatar fotoliu", (0.62, 0.14, 0.9), (0, 0.3, 0.98), LEMN_INCHIS))
	for k in range(3):
		for j in range(2):
			piese.append(sfera("Nasture capitonaj", 0.02, (-0.18 + k * 0.18, 0.225, 0.8 + j * 0.3), NEGRU, segmente=5, inele=3))
	for semn in (-1, 1):
		piese.append(cub("Brat fotoliu", (0.08, 0.5, 0.06), (semn * 0.33, 0.0, 0.68), LEMN_INCHIS))
		piese.append(cub("Suport brat", (0.04, 0.04, 0.18), (semn * 0.33, -0.1, 0.58), METAL_INCHIS))
	piese.append(cilindru("Picior fotoliu", 0.04, 0.04, 0.32, (0, 0, 0.25), METAL_INCHIS, laturi=6))
	for k in range(5):
		a = k * 2 * math.pi / 5
		piese.append(os_intre("Spita", (0, 0, 0.1), (0.3 * math.cos(a), 0.3 * math.sin(a), 0.06), 0.025, METAL_INCHIS, laturi=4))
		piese.append(sfera("Rotila", 0.035, (0.3 * math.cos(a), 0.3 * math.sin(a), 0.035), NEGRU, segmente=6, inele=4))
	uneste(piese, "Scaun")
	exporta(os.path.join(cale, "scaun_primar.glb"))


def teanc_bani(cale):
	"""Un teanc de bancnote (verzi), legat cu banderolă albă. Originea în mijlocul feței de jos; 2 cm grosime (în joc îl
	fac mai gros sau mai subțire după sumă)."""
	curata()
	piese = []
	piese.append(cub("Bancnote", (0.156, 0.067, 0.02), (0, 0, 0.01), VERDE))
	piese.append(cub("Bancnota sus", (0.15, 0.06, 0.002), (0, 0, 0.021), MASLINIU))
	piese.append(cub("Chip bancnota", (0.03, 0.035, 0.002), (0, 0, 0.0225), VERDE_INCHIS))
	piese.append(cub("Banderola", (0.03, 0.071, 0.024), (-0.035, 0, 0.012), ALB))
	uneste(piese, "Teanc")
	exporta(os.path.join(cale, "teanc_bani.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Oamenii: funcționara de la ghișeu și primarul
# ---------------------------------------------------------------------------------------------------------------

# funcționara: la vreo 55 de ani, părul vopsit vișiniu (închis, ca să nu se piardă pe piele), ochelari pe lănțișor,
# cardigan gri peste bluză, cercei de aur, ruj; stă pe scaunul înalt de la ghișeu, cu coatele pe blat
ANGAJATA = {
	"piele": p("a56850"), "piele_umbra": p("904a40"), "haina": p("5e5356"), "haina_umbra": p("48313b"), "camasa": p("61a19f"),
	"stil_haina": "pulover", "nasturi": AUR, "pantaloni": p("2a3c3d"), "femeie": True, "par": p("553e4d"),
	"par_suvita": p("7b383a"), "stil_par": "voluminos", "ochelari": "vedere", "rama": p("48313b"), "lantisor_ochelari": True,
	"cercei": AUR, "buze": p("7b383a"), "gura": p("5e363e"), "riduri": True, "unghii": p("7b383a"), "inele": AUR,
	"sezut": 0.72, "masa": TZ - FL, "pantofi": p("48313b"), "gros_brat": 0.9, "spranceana": 0.014, "incruntat": 0.35,
	"burta": 0.3,
}

# primarul Smegma: gras, chel, mustață, nas roșu de băutor, costum închis, cravată roșie, ceas de aur, inele
PRIMAR = {
	"piele": p("a56850"), "piele_umbra": p("904a40"), "haina": p("2a3c3d"), "haina_umbra": p("262d2f"), "camasa": ALB,
	"cravata": p("7b383a"), "pantaloni": p("2a3c3d"), "par": p("5e5356"), "stil_par": "chel", "mustata": p("48313b"),
	"gras": 1.0, "burta": 1.2, "gros_brat": 1.15, "inele": AUR, "nas": 1.3, "nas_rosu": True, "incruntat": 0.15,
	"batista": p("a18463"), "manseta": ALB, "riduri": True, "ceas": AUR, "sezut": 0.5, "masa": MZ,
}


def angajata(cale):
	casino_oameni.om(cale, "angajata_primarie", ANGAJATA, 1989)


def primar(cale):
	casino_oameni.om(cale, "primar_smegma", PRIMAR, 1990)


def toate(cale):
	cladire(cale)
	interior(cale)
	curte(cale)
	usa_primarie(cale)
	usa_birou(cale)
	scaun_primar(cale)
	teanc_bani(cale)
	angajata(cale)
	primar(cale)


if __name__ == "__main__":
	cale_modele = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")
	if "--" in sys.argv:
		for nume in sys.argv[sys.argv.index("--") + 1:]:
			globals()[nume](cale_modele)
	else:
		toate(cale_modele)
