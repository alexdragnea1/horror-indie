# Sediul coven-ului: conacul gotic din vârful dealului (conac.tscn) și ce e în curtea lui.
# Le apelează modele.py, dar merge și singur (mai repede, doar astea):
#   blender --background --factory-startup --python tools/blender/conac.py
#   blender --background --factory-startup --python tools/blender/conac.py -- conac felinar_conac
# Axe Blender: Z în sus, fața modelului spre -Y (în Godot devine +Z). Originea = la sol.
# Conacul: originea e mijlocul fațadei corpului central (y = 0), la sol; corpul se întinde spre +Y.
import math
import os
import random
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, inel, uneste, exporta, trunchi, text  # noqa: E402
from lexy import prisma, _copii  # noqa: E402

ZID = p("5e5356")             # piatra pereților
PIATRA = p("6f6d7f")          # ramele, brâiele, colțurile (piatră mai deschisă)
PIATRA_INCHISA = p("553e4d")  # soclul, coșurile
ARDEZIE = p("2a3c3d")         # acoperișurile
FIER = p("262d2f")            # creasta, felinarele, porțile
LEMN = p("48313b")            # ușa
GEAM_STINS = p("262d2f")
GEAM_APRINS = p("a18463")
GEAM_PORTOCALIU = p("a56850")
ROSU = p("7b383a")
IEDERA = p("32453b")
IEDERA_DESCHISA = p("445d46")
MUSCHI = p("5b6d4e")
PIETRIS = p("6f6d7f")
BORDURA = p("70706e")
APA = p("295555")
ALB = p("83b3b0")

PL = 0.9                 # podeaua parterului (soclul)
ETAJ = 3.5               # înălțimea unui etaj
NIVELURI = [PL + k * ETAJ for k in range(3)]  # 0,9 / 4,4 / 7,9
E_C = PL + 3 * ETAJ      # streașina corpului central (11,4)
E_A = PL + 2 * ETAJ + 0.6  # streașina aripilor (8,5)
CX = 7.0                 # corpul central: x între -7 și 7
C_SPATE = 11.0           # adâncimea corpului central
A_X = 15.6               # aripile: x între 7 și 15,6 (și oglindit)
A_FATA, A_SPATE = 0.8, 12.6
GOLF = 2.7               # golul din față (intrarea), x între -2,7 și 2,7
GOLF_Y = -1.8            # cât iese în față
TURN = (-15.8, 0.4)      # turnul pătrat (stânga, colțul din față al aripii), latura 4 m
TURN_L = 2.0
TURN_H = 18.6
TURELA = (15.9, 0.7)     # turela rotundă (dreapta)
TURELA_R = 2.1
TURELA_H = 15.2


# ---------------------------------------------------------------------------------------------------------------
# Unelte
# ---------------------------------------------------------------------------------------------------------------

def _roteste(obiecte, centru, unghi):
	"""Rotește piesele deja făcute (vârfurile lor sunt în coordonatele lumii) în jurul axei Z care trece prin `centru`.
	Așa o fereastră făcută pe un perete cu fața spre -Y ajunge pe un perete lateral sau pe turela rotundă."""
	c = Vector((centru[0], centru[1], 0.0))
	m = Matrix.Translation(c) @ Matrix.Rotation(unghi, 4, 'Z') @ Matrix.Translation(-c)
	for ob in obiecte:
		ob.data.transform(m)
		ob.data.update()


def _pentagon(x0, x1, z0, z1, arc):
	"""Conturul unei ferestre gotice (dreptunghi cu arc ascuțit deasupra), în planul XZ, în ordine."""
	return [(x0, z0), (x1, z0), (x1, z1 - arc), ((x0 + x1) / 2, z1), (x0, z1 - arc)]


def _lancet(piese, lumini, cx, yf, z0, lat, inalt, aprinsa, culoare=GEAM_APRINS, traversa=True):
	"""Fereastră gotică (lancetă) pe un perete cu fața spre -Y (`yf` = fața peretelui): rama de piatră (iese 6 cm),
	geamul cu 1,5 cm în fața ramei (aprins = în `lumini`, strălucește în joc), montantul și traversa de piatră,
	pervazul. Întoarce piesele făcute (ca să le poți roti cu _roteste)."""
	fac = []
	x0, x1 = cx - lat / 2, cx + lat / 2
	arc = lat * 0.8
	z1 = z0 + inalt
	fac.append(prisma("Rama fereastra", _pentagon(x0 - 0.14, x1 + 0.14, z0 - 0.1, z1 + 0.16, arc + 0.12), "xz",
		yf - 0.06, yf + 0.05, PIATRA))
	geam = prisma("Geam", _pentagon(x0, x1, z0, z1, arc), "xz", yf - 0.075, yf - 0.065,
		culoare if aprinsa else GEAM_STINS)
	(lumini if aprinsa else piese).append(geam)
	fac.append(geam)
	fac.append(cub("Montant", (0.06, 0.02, inalt - arc * 0.35), (cx, yf - 0.08, z0 + (inalt - arc * 0.35) / 2), PIATRA))
	if traversa:
		fac.append(cub("Traversa", (lat, 0.02, 0.06), (cx, yf - 0.08, z0 + (inalt - arc) * 0.62), PIATRA))
	fac.append(cub("Pervaz", (lat + 0.42, 0.2, 0.09), (cx, yf - 0.1, z0 - 0.145), PIATRA))
	piese += [o for o in fac if o is not geam]
	return fac


def _colturi(piese, xc, yc, sx, sy, z0, z1):
	"""Pietrele de colț (alternativ lungi pe o parte și pe cealaltă), care ies 3 cm din ambii pereți."""
	k = 0
	z = z0
	while z + 0.46 <= z1:
		lx, ly = (0.7, 0.4) if k % 2 else (0.4, 0.7)
		piese.append(cub("Colt", (lx, ly, 0.44), (xc + sx * (0.03 - lx / 2), yc + sy * (0.03 - ly / 2), z + 0.22), PIATRA))
		z += 0.5
		k += 1


def _acoperis(piese, axa, a0, a1, b0, b1, e, panta, peste=0.4, creasta=True):
	"""Acoperiș în două ape. axa "x": coama pe X (de la a0 la a1), apele spre y = b0 și b1; axa "y": invers.
	Dedesubt podul de piatră (frontoanele, puțin sub plăci), deasupra plăcile de ardezie (22 cm), coama de fier și
	creasta cu vârfuri. Întoarce înălțimea coamei."""
	bm = (b0 + b1) / 2
	r = e + (bm - b0) * panta
	g = 0.22
	ba, bb = b0 - peste, b1 + peste
	za = e - peste * panta
	plan = "yz" if axa == "x" else "xz"
	piese.append(prisma("Pod", [(b0, e - 0.05), (b1, e - 0.05), (bm, r - 0.15)], plan, a0, a1, ZID))
	piese.append(prisma("Acoperis", [(ba, za), (bm, r), (bm, r + g), (ba, za + g)], plan, a0 - 0.25, a1 + 0.25, ARDEZIE))
	piese.append(prisma("Acoperis", [(bm, r), (bb, za), (bb, za + g), (bm, r + g)], plan, a0 - 0.25, a1 + 0.25, ARDEZIE))
	lung = a1 - a0 + 0.5
	if axa == "x":
		piese.append(cub("Coama", (lung, 0.16, 0.14), ((a0 + a1) / 2, bm, r + g + 0.04), FIER))
	else:
		piese.append(cub("Coama", (0.16, lung, 0.14), (bm, (a0 + a1) / 2, r + g + 0.04), FIER))
	if creasta:
		n = int(lung / 0.55)
		for k in range(n + 1):
			a = a0 - 0.25 + k * lung / n
			loc = (a, bm, r + g + 0.25) if axa == "x" else (bm, a, r + g + 0.25)
			inalt = 0.42 if k % 3 == 0 else 0.26
			piese.append(cilindru("Creasta", 0.025, 0.0, inalt, (loc[0], loc[1], r + g + 0.1 + inalt / 2), FIER, laturi=4))
	return r


def _cos(piese, x, y, z0, z1):
	"""Coș de fum înalt, din piatră închisă, cu brâu, capac și trei olane."""
	piese += [
		cub("Cos", (0.9, 1.3, z1 - z0), (x, y, (z0 + z1) / 2), PIATRA_INCHISA),
		cub("Brau cos", (1.04, 1.44, 0.16), (x, y, z1 - 0.5), PIATRA),
		cub("Capac cos", (1.12, 1.52, 0.14), (x, y, z1 + 0.07), PIATRA),
	]
	for k in (-1, 0, 1):
		piese.append(cilindru("Olan", 0.12, 0.09, 0.5, (x, y + k * 0.4, z1 + 0.39), ROSU, laturi=6))


def _iedera(piese, r, x0, x1, y, z0, z1, spre=-1):
	"""Iederă cățărată pe un perete cu fața spre -Y: frunzișul din plăci mici (2–4 cm în fața peretelui),
	mai deasă jos, rărită în sus, cu tulpini."""
	for k in range(int((x1 - x0) * (z1 - z0) * 3.2)):
		x = r.uniform(x0, x1)
		t = r.random() ** 1.6  # mai multă jos
		z = z0 + t * (z1 - z0)
		latime = r.uniform(0.25, 0.6) * (1.0 - t * 0.5)
		piese.append(cub("Iedera", (latime, 0.012, r.uniform(0.18, 0.4)), (x, y + spre * r.choice((0.02, 0.032, 0.044)), z),
			r.choice((IEDERA, IEDERA, IEDERA_DESCHISA)), rot=(0, r.uniform(-0.5, 0.5), 0)))


# ---------------------------------------------------------------------------------------------------------------
# Conacul
# ---------------------------------------------------------------------------------------------------------------

def conac(cale, distrus=False):
	"""Conacul gotic al coven-ului, pe trei etaje: corpul central (cu golul intrării în față: ușa dublă sub arc
	ascuțit, scara de piatră cu parapete și urne, felinarele de perete, rozeta din fronton), două aripi mai joase cu
	frontoane ascuțite spre față, turnul pătrat din stânga (ceasul care arată 7:12, turla de ardezie cu fleșă și
	turnulețe la colțuri) și turela rotundă din dreapta (con de ardezie). Acoperișuri abrupte cu creste de fier,
	lucarne, coșuri înalte, pietre de colț, brâie între etaje, iederă. Ferestrele sunt lancete gotice; cam jumătate
	sunt aprinse (`Lumini`, strălucesc în joc). Curtea (pietrișul, aleile cu borduri) e tot aici.
	Piese: `Conac`, `Lumini`, `Coliziune` (pereții, acoperișurile, rampa peste trepte, parapetele).
	`distrus` = același conac după atacul Warlock-ului (`conac_distrus.glb`, vezi _distruge): ferestrele rămase sunt stinse
	sau roșii de focul dinăuntru, iar `Lumini` sunt jarul și ferestrele în flăcări."""
	curata()
	r = random.Random(712)
	r_foc = random.Random(1913)  # separat: așa conacul distrus are aceleași ferestre și aceeași iederă ca cel întreg
	piese, lumini = [], []

	def aprinsa():
		a = r.random() < 0.55
		return r_foc.random() < 0.2 if distrus else a

	def culoare_aprinsa():
		c = GEAM_PORTOCALIU if r.random() < 0.25 else GEAM_APRINS
		return GEAM_PORTOCALIU if distrus else c

	def fereastra(cx, yf, z0, lat=1.0, inalt=2.3, centru=None, unghi=0.0, mereu=None):
		a = aprinsa() if mereu is None else (r_foc.random() < 0.2 if distrus else mereu)
		fac = _lancet(piese, lumini, cx, yf, z0, lat, inalt, a, culoare_aprinsa())
		if centru is not None:
			_roteste(fac, centru, unghi)

	# --- corpul central
	piese += [
		cub("Zid", (2 * CX, C_SPATE, E_C), (0, C_SPATE / 2, E_C / 2), ZID),
		cub("Soclu", (2 * CX + 0.2, C_SPATE + 0.2, PL + 0.1), (0, C_SPATE / 2, (PL + 0.1) / 2), PIATRA_INCHISA),
		cub("Cornisa", (2 * CX + 0.3, C_SPATE + 0.3, 0.3), (0, C_SPATE / 2, E_C - 0.15), PIATRA),
	]
	for z in NIVELURI[1:]:
		piese.append(cub("Brau", (2 * CX + 0.12, C_SPATE + 0.12, 0.14), (0, C_SPATE / 2, z - 0.1), PIATRA))
	for z0 in NIVELURI:
		for x in (-5.3, -3.9, 3.9, 5.3):
			fereastra(x, 0.0, z0 + 0.75, lat=0.9)
	# spatele corpului central (se vede doar dacă ocolești conacul)
	for z0 in NIVELURI:
		for x in (-4.5, -1.5, 1.5, 4.5):
			fereastra(-x, 0.0, z0 + 0.75, lat=0.9, centru=(0, C_SPATE / 2), unghi=math.pi)
	_colturi(piese, -CX, 0, -1, -1, PL + 0.1, E_C - 0.3)
	_colturi(piese, CX, 0, 1, -1, PL + 0.1, E_C - 0.3)
	r_c = _acoperis(piese, "x", -CX, CX, 0, C_SPATE, E_C, 1.45)
	# lucarnele de pe apa din față (câte o fereastră aprinsă sub un fronton mic)
	for x in (-4.8, 4.8):
		y0 = 1.1
		z_jos = E_C + (y0 + 0.4) * 1.45 - 0.6
		piese.append(cub("Lucarna", (1.6, 2.6, 2.4), (x, y0 + 1.3, z_jos + 1.2), ZID))
		_acoperis(piese, "y", y0 - 0.1, y0 + 2.6, x - 0.8, x + 0.8, z_jos + 2.4, 1.3, peste=0.2, creasta=False)
		fereastra(x, y0, z_jos + 0.75, lat=0.7, inalt=1.3, mereu=True)
	_cos(piese, -5.6, 6.2, r_c - 4.0, r_c + 2.2)
	_cos(piese, 5.6, 6.2, r_c - 4.0, r_c + 2.2)

	# --- golul intrării (iese în față), cu frontonul lui și rozeta
	piese += [
		cub("Zid", (2 * GOLF, -GOLF_Y + 0.3, E_C), (0, (GOLF_Y + 0.3) / 2, E_C / 2), ZID),
		cub("Soclu", (2 * GOLF + 0.2, -GOLF_Y + 0.4, PL + 0.1), (0, (GOLF_Y - 0.1 + 0.3) / 2, (PL + 0.1) / 2), PIATRA_INCHISA),
		cub("Cornisa", (2 * GOLF + 0.3, -GOLF_Y + 0.15, 0.3), (0, GOLF_Y / 2 - 0.075, E_C - 0.15), PIATRA),
	]
	for z in NIVELURI[1:]:
		piese.append(cub("Brau", (2 * GOLF + 0.12, -GOLF_Y + 0.06, 0.14), (0, GOLF_Y / 2 - 0.03, z - 0.1), PIATRA))
	_colturi(piese, -GOLF, GOLF_Y, -1, -1, PL + 0.1, E_C - 0.3)
	_colturi(piese, GOLF, GOLF_Y, 1, -1, PL + 0.1, E_C - 0.3)
	for z0 in NIVELURI[1:]:
		fereastra(0, GOLF_Y, z0 + 0.55, lat=1.4, inalt=2.35, mereu=True)
	r_golf = _acoperis(piese, "y", GOLF_Y, 4.5, -GOLF, GOLF, E_C, 1.65)
	# rozeta: ramă rotundă de piatră, vitraliu roșu cu mijlocul auriu, spițe
	rz = E_C + 1.75
	yr = GOLF_Y
	piese.append(cilindru("Rama rozeta", 1.2, 1.2, 0.12, (0, yr - 0.01, rz), PIATRA, laturi=16, rot=(math.pi / 2, 0, 0)))
	lumini.append(cilindru("Rozeta", 1.0, 1.0, 0.01, (0, yr - 0.08, rz), ROSU, laturi=16, rot=(math.pi / 2, 0, 0)))
	lumini.append(cilindru("Rozeta mijloc", 0.34, 0.34, 0.01, (0, yr - 0.095, rz), GEAM_APRINS, laturi=10, rot=(math.pi / 2, 0, 0)))
	for k in range(8):
		u = k * math.pi / 4
		piese.append(cub("Spita", (0.66, 0.03, 0.07), (math.cos(u) * 0.67, yr - 0.115, rz + math.sin(u) * 0.67), PIATRA, rot=(0, -u, 0)))
	piese.append(cilindru("Inel rozeta", 0.4, 0.4, 0.03, (0, yr - 0.115, rz), PIATRA, laturi=10, rot=(math.pi / 2, 0, 0)))
	piese.append(cilindru("Fleșa golf", 0.05, 0.0, 1.2, (0, yr + 1.0, r_golf + 0.8), FIER, laturi=4))

	# --- ușa dublă sub arc ascuțit, portalul, felinarele
	uy = GOLF_Y
	piese.append(prisma("Portal", _pentagon(-1.45, 1.45, PL, PL + 3.7, 1.45), "xz", uy - 0.16, uy + 0.05, PIATRA))
	piese.append(prisma("Usa", _pentagon(-1.05, 1.05, PL, PL + 3.3, 1.05), "xz", uy - 0.18, uy - 0.17, LEMN))
	for x in (-0.84, -0.63, -0.42, -0.21, 0.21, 0.42, 0.63, 0.84):
		piese.append(cub("Scandura", (0.02, 0.012, 2.4), (x, uy - 0.188, PL + 1.2), FIER))
	piese.append(cub("Rost usa", (0.04, 0.012, 3.1), (0, uy - 0.188, PL + 1.55), FIER))
	for z in (PL + 0.5, PL + 1.7, PL + 2.6):
		for s in (-1, 1):
			piese.append(cub("Balama", (0.75, 0.016, 0.08), (s * 0.62, uy - 0.192, z), FIER))
	for s in (-1, 1):
		piese.append(cilindru("Ciocan usa", 0.11, 0.11, 0.03, (s * 0.3, uy - 0.2, PL + 1.55), FIER, laturi=8, rot=(math.pi / 2, 0, 0)))
		# felinarele de perete, de o parte și de alta a ușii
		x = s * 2.0
		piese += [
			cub("Brat felinar", (0.06, 0.3, 0.06), (x, uy - 0.15, PL + 2.75), FIER),
			cub("Felinar", (0.32, 0.32, 0.04), (x, uy - 0.42, PL + 2.4), FIER),
			cilindru("Capac felinar", 0.27, 0.0, 0.3, (x, uy - 0.42, PL + 2.95), FIER, laturi=4, rot=(0, 0, math.pi / 4)),
		]
		for dx, dy in ((-0.14, -0.14), (0.14, -0.14), (-0.14, 0.14), (0.14, 0.14)):
			piese.append(cub("Montant felinar", (0.03, 0.03, 0.42), (x + dx, uy - 0.42 + dy, PL + 2.62), FIER))
		lumini.append(cub("Flacara felinar", (0.24, 0.24, 0.36), (x, uy - 0.42, PL + 2.62), GEAM_APRINS))

	# --- scara: podest, trepte, parapete cu urne
	piese.append(cub("Podest", (6.0, 1.4, PL), (0, GOLF_Y - 0.7, PL / 2), PIATRA))
	trepte = 6
	adanc = 0.42
	for k in range(trepte):
		h = PL * (trepte - k) / (trepte + 1)
		y = GOLF_Y - 1.4 - adanc * (k + 0.5)
		piese.append(cub("Treapta", (5.2, adanc, h), (0, y, h / 2), PIATRA))
	capat = GOLF_Y - 1.4 - adanc * trepte
	for s in (-1, 1):
		x = s * 3.0
		piese += [
			cub("Parapet", (0.45, GOLF_Y - capat, PL + 0.75), (x, (GOLF_Y + capat) / 2, (PL + 0.75) / 2), ZID),
			cub("Capac parapet", (0.6, GOLF_Y - capat + 0.15, 0.12), (x, (GOLF_Y + capat) / 2 - 0.075, PL + 0.81), PIATRA),
			cub("Soclu urna", (0.55, 0.55, 0.2), (x, capat + 0.35, PL + 0.97), PIATRA),
			cilindru("Urna", 0.12, 0.3, 0.45, (x, capat + 0.35, PL + 1.3), PIATRA, laturi=8),
			cilindru("Buza urna", 0.33, 0.33, 0.08, (x, capat + 0.35, PL + 1.56), PIATRA, laturi=8),
			cub("Muschi", (0.46, 0.02, 0.35), (x, capat - 0.26, 0.4), MUSCHI),
		]

	# --- aripile
	for s in (-1, 1):
		x0, x1 = (CX, A_X) if s > 0 else (-A_X, -CX)
		mx = (x0 + x1) / 2
		lat = x1 - x0
		piese += [
			cub("Zid", (lat, A_SPATE - A_FATA, E_A), (mx, (A_FATA + A_SPATE) / 2, E_A / 2), ZID),
			cub("Soclu", (lat + 0.2, A_SPATE - A_FATA + 0.2, PL + 0.1), (mx, (A_FATA + A_SPATE) / 2, (PL + 0.1) / 2), PIATRA_INCHISA),
			cub("Cornisa", (lat + 0.3, A_SPATE - A_FATA + 0.3, 0.3), (mx, (A_FATA + A_SPATE) / 2, E_A - 0.15), PIATRA),
			cub("Brau", (lat + 0.12, A_SPATE - A_FATA + 0.12, 0.14), (mx, (A_FATA + A_SPATE) / 2, NIVELURI[1] - 0.1), PIATRA),
		]
		_acoperis(piese, "y", A_FATA, A_SPATE, x0, x1, E_A, 1.55)
		# fereastra din fronton (mereu aprinsă: cineva stă în pod)
		fereastra(mx, A_FATA, E_A + 0.5, lat=0.8, inalt=1.9, mereu=s < 0)
		for z0 in NIVELURI[:2]:
			for dx in (s * 1.6, -s * 2.2):
				fereastra(mx + dx, A_FATA, z0 + 0.75)
		# laturile de afară și spatele
		latura = (A_X if s > 0 else -A_X)
		for z0 in NIVELURI[:2]:
			for y in (5.0, 8.6):
				fac = _lancet(piese, lumini, s * y, 0.0, z0 + 0.75, 0.9, 2.3, aprinsa(), culoare_aprinsa())
				# fereastra e făcută pe planul y = 0 la x = y (pe lungul peretelui); o mutăm pe latură
				_roteste(fac, (0, 0), s * math.pi / 2)
				for ob in fac:
					ob.data.transform(Matrix.Translation(Vector((latura, 0, 0))))
			for x in (mx - 2.0, mx + 2.0):
				fac = _lancet(piese, lumini, -x, -A_SPATE, z0 + 0.75, 0.9, 2.3, aprinsa(), culoare_aprinsa())
				_roteste(fac, (0, 0), math.pi)
		for xc in (x0, x1):
			if (s < 0 and xc == x0) or (s > 0 and xc == x1):
				continue  # colțul din față de afară e acoperit de turn / turelă
			_colturi(piese, xc, A_FATA, -1 if xc < 0 else 1, -1, PL + 0.1, E_A - 0.3)
		_cos(piese, mx + s * 2.0, A_SPATE - 2.0, E_A + 2.0, E_A + 6.0 + 1.8)
	_iedera(piese, r, -12.9, -8.0, A_FATA, PL + 0.1, 6.5)
	_iedera(piese, r, 3.0, 6.6, 0.0, PL + 0.1, 3.6)

	# --- turnul pătrat (stânga): ferestre pe toate etajele, ceasul, turla cu turnulețe
	tx, ty = TURN
	l = TURN_L
	piese += [
		cub("Turn", (2 * l, 2 * l, TURN_H), (tx, ty, TURN_H / 2), ZID),
		cub("Soclu", (2 * l + 0.2, 2 * l + 0.2, PL + 0.1), (tx, ty, (PL + 0.1) / 2), PIATRA_INCHISA),
		cub("Cornisa turn", (2 * l + 0.4, 2 * l + 0.4, 0.35), (tx, ty, TURN_H - 0.175), PIATRA),
	]
	for z in NIVELURI[1:] + [PL + 3 * ETAJ]:
		piese.append(cub("Brau", (2 * l + 0.12, 2 * l + 0.12, 0.14), (tx, ty, z - 0.1), PIATRA))
	for k in range(int(2 * l / 0.5)):  # consolele de sub cornișă, pe toate laturile
		u = -l + 0.25 + k * 0.5
		for cx_, cy_, dx, dy in ((tx + u, ty - l, 0.18, 0.16), (tx + u, ty + l, 0.18, 0.16), (tx - l, ty + u, 0.16, 0.18), (tx + l, ty + u, 0.16, 0.18)):
			px = cx_ - 0.05 if cx_ == tx - l else cx_ + 0.05 if cx_ == tx + l else cx_
			py = cy_ - 0.05 if cy_ == ty - l else cy_ + 0.05 if cy_ == ty + l else cy_
			piese.append(cub("Consola", (dx, dy, 0.3), (px, py, TURN_H - 0.5), PIATRA))
	for sx in (-1, 1):
		for sy in (-1, 1):
			_colturi(piese, tx + sx * l, ty + sy * l, sx, sy, PL + 0.1, TURN_H - 0.7)
	for k, z0 in enumerate(NIVELURI + [PL + 3 * ETAJ]):
		# față (spre -Y) și latura din stânga (spre -X); pe ultimul etaj, în față, e ceasul
		if k < 4:
			fereastra(tx, ty - l, z0 + 0.7, lat=0.8, inalt=2.0)
		fac = _lancet(piese, lumini, -ty, 0.0, z0 + 0.7, 0.8, 2.0, aprinsa(), culoare_aprinsa())
		_roteste(fac, (0, 0), -math.pi / 2)
		for ob in fac:
			ob.data.transform(Matrix.Translation(Vector((tx - l, 0, 0))))
	# ceasul: cadran deschis, cifre-liniuțe, limbile la 7:12
	zc = PL + 3 * ETAJ + 4.9
	yc = ty - l
	piese.append(cilindru("Rama ceas", 1.05, 1.05, 0.16, (tx, yc - 0.02, zc), PIATRA, laturi=16, rot=(math.pi / 2, 0, 0)))
	piese.append(cilindru("Cadran", 0.88, 0.88, 0.02, (tx, yc - 0.115, zc), ALB, laturi=16, rot=(math.pi / 2, 0, 0)))
	for k in range(12):
		u = k * math.pi / 6
		lung = 0.18 if k % 3 == 0 else 0.1
		rr = 0.88 - 0.06 - lung / 2
		piese.append(cub("Cifra", (lung, 0.012, 0.04), (tx + math.sin(u) * rr, yc - 0.132, zc + math.cos(u) * rr), FIER, rot=(0, u - math.pi / 2, 0)))
	for unghi, lung, gros in ((7.2 / 12 * math.tau, 0.48, 0.07), (12 / 60 * math.tau, 0.72, 0.045)):
		piese.append(cub("Limba ceas", (lung, 0.014, gros), (tx + math.sin(unghi) * lung * 0.4, yc - 0.15, zc + math.cos(unghi) * lung * 0.4),
			FIER, rot=(0, unghi - math.pi / 2, 0)))
	piese.append(cilindru("Ax ceas", 0.06, 0.06, 0.03, (tx, yc - 0.165, zc), FIER, laturi=6, rot=(math.pi / 2, 0, 0)))
	# turla: piramidă de ardezie, turnulețe în colțuri, fleșa cu giruetă
	piese.append(cilindru("Turla", (l + 0.25) * math.sqrt(2), 0.0, 10.5, (tx, ty, TURN_H + 5.25), ARDEZIE, laturi=4, rot=(0, 0, math.pi / 4)))
	for sx in (-1, 1):
		for sy in (-1, 1):
			x, y = tx + sx * (l - 0.1), ty + sy * (l - 0.1)
			piese += [
				cub("Turnulet", (0.5, 0.5, 1.0), (x, y, TURN_H + 0.5), PIATRA),
				cilindru("Varf turnulet", 0.38, 0.0, 1.6, (x, y, TURN_H + 1.8), ARDEZIE, laturi=4, rot=(0, 0, math.pi / 4)),
				sfera("Bila turnulet", 0.07, (x, y, TURN_H + 2.65), FIER, segmente=6, inele=4),
			]
	vf = TURN_H + 10.5
	piese += [
		cilindru("Flesa", 0.05, 0.03, 2.4, (tx, ty, vf + 0.9), FIER, laturi=4),
		sfera("Bila flesa", 0.12, (tx, ty, vf + 0.5), FIER, segmente=6, inele=4),
		cub("Girueta", (0.7, 0.02, 0.25), (tx + 0.25, ty, vf + 1.7), FIER),
		cilindru("Semiluna", 0.22, 0.22, 0.02, (tx, ty, vf + 2.3), FIER, laturi=10, rot=(math.pi / 2, 0, 0)),
	]
	_iedera(piese, r, tx - l + 0.1, tx + l - 0.1, ty - l, PL + 0.1, 7.0)

	# --- turela rotundă (dreapta): 12 laturi, una cu fața spre -Y
	ux, uy_ = TURELA
	ur = TURELA_R
	ap = ur * math.cos(math.pi / 12)  # apotema (distanța până la o latură)
	piese += [
		cilindru("Turela", ur, ur, TURELA_H, (ux, uy_, TURELA_H / 2), ZID, laturi=12, rot=(0, 0, math.pi / 12)),
		cilindru("Soclu turela", ur + 0.1, ur + 0.1, PL + 0.1, (ux, uy_, (PL + 0.1) / 2), PIATRA_INCHISA, laturi=12, rot=(0, 0, math.pi / 12)),
		cilindru("Cornisa turela", ur + 0.25, ur + 0.25, 0.35, (ux, uy_, TURELA_H - 0.175), PIATRA, laturi=12, rot=(0, 0, math.pi / 12)),
		cilindru("Con turela", ur + 0.35, 0.0, 9.0, (ux, uy_, TURELA_H + 4.5), ARDEZIE, laturi=12, rot=(0, 0, math.pi / 12)),
		cilindru("Flesa", 0.05, 0.03, 2.0, (ux, uy_, TURELA_H + 9.7), FIER, laturi=4),
		sfera("Bila flesa", 0.11, (ux, uy_, TURELA_H + 9.2), FIER, segmente=6, inele=4),
	]
	for z in NIVELURI[1:] + [PL + 3 * ETAJ]:
		piese.append(cilindru("Brau", ur + 0.06, ur + 0.06, 0.14, (ux, uy_, z - 0.1), PIATRA, laturi=12, rot=(0, 0, math.pi / 12)))
	for z0 in NIVELURI + [PL + 3 * ETAJ]:
		for unghi in (0.0, math.pi / 3):  # spre -Y și spre +X-față
			fac = _lancet(piese, lumini, ux, uy_ - ap, z0 + 0.7, 0.62, 1.9, aprinsa(), culoare_aprinsa(), traversa=False)
			_roteste(fac, (ux, uy_), unghi)

	# --- curtea: pietrișul din fața scării, cercul cu fântâna, aleea spre poartă, borduri
	fy = -16.0  # fântâna (Godot: z = 6, cu conacul la z = -10)
	alee = [(capat - 0.02, fy + 6.95, 3.4), (fy - 6.95, -41.0, 3.2)]
	for y0, y1, lat in alee:
		piese.append(cub("Pietris", (lat, y0 - y1, 0.04), (0, (y0 + y1) / 2, 0.02), PIETRIS))
		for s in (-1, 1):
			piese.append(cub("Bordura", (0.16, y0 - y1, 0.09), (s * (lat / 2 + 0.08), (y0 + y1) / 2, 0.045), BORDURA))
	piese.append(cilindru("Pietris", 7.0, 7.0, 0.055, (0, fy, 0.0275), PIETRIS, laturi=28))
	piese.append(inel("Bordura", 7.08, 0.09, (0, fy, 0.03), BORDURA, segmente=28))
	piese.append(cub("Pietris", (8.0, 1.6, 0.05), (0, capat - 0.8, 0.025), PIETRIS))  # la picioarele scării
	for k in range(60):  # pietre mai mari în pietriș
		u = r.uniform(0, math.tau)
		d = r.uniform(1.0, 6.6)
		piese.append(cub("Piatra", (r.uniform(0.08, 0.2), r.uniform(0.08, 0.2), 0.03), (math.cos(u) * d, fy + math.sin(u) * d, 0.065), BORDURA,
			rot=(0, 0, r.uniform(0, 3))))

	col_moloz = _distruge(piese, lumini, r_foc) if distrus else []

	# coliziunea: pereții, acoperișurile (să nu sari pe ele, oricum nu poți), parapetele, o rampă peste trepte
	col = _copii(piese, ("Zid", "Soclu", "Turn", "Turela", "Soclu turela", "Parapet", "Podest", "Pod", "Acoperis", "Lucarna"))
	col.append(prisma("Rampa", [(capat, 0.0), (GOLF_Y - 1.4, PL - 0.01), (GOLF_Y - 1.4, 0.0)], "yz", -2.6, 2.6, FIER))
	if not distrus:
		col.append(cub("Usa coliziune", (2.2, 0.3, 3.6), (0, GOLF_Y - 0.2, PL + 1.8), FIER))
	uneste(col + col_moloz, "Coliziune")
	uneste(piese, "Conac")
	uneste(lumini, "Lumini")
	exporta(os.path.join(cale, "conac_distrus.glb" if distrus else "conac.glb"))


def conac_distrus(cale):
	conac(cale, distrus=True)


# ---------------------------------------------------------------------------------------------------------------
# Conacul după atacul Warlock-ului
# ---------------------------------------------------------------------------------------------------------------

NEGRU_ARS = p("262d2f")    # piatra arsă, golurile
FUNINGINE = p("553e4d")    # pereții afumați din jurul găurilor
JAR = p("a56850")          # jarul din moloz (strălucește)
JAR_ROSU = p("904a40")
LEMN_ARS = p("48313b")

# Unde a lovit (centrul în coordonatele conacului, raza): vraja mare a Warlock-ului a intrat pe ușă și a scos mijlocul
# corpului central până la acoperiș; vrăjile mici au spart aripile, vârful turelei și turla turnului (căzută în curte).
CRATERE = [
	((0.0, 1.8, 8.6), 7.4),
	((-4.2, 6.5, 12.6), 4.0),
	((9.6, 0.8, 7.6), 3.3),
	((-11.2, 2.6, 8.0), 2.8),
	((15.9, 0.7, 16.8), 3.4),
	((-15.8, 0.4, 21.2), 3.6),
]
GROSIME_ZID = 0.45
# Ce stă sus, pe acoperișuri și turnuri: lângă o gaură cade de tot (vezi _distruge).
DE_PE_ACOPERIS = ("Cos", "Brau cos", "Capac cos", "Olan", "Con turela", "Flesa", "Bila flesa", "Turla", "Girueta", "Semiluna",
	"Fleșa golf", "Cornisa turn", "Consola")


def _raza_crater(i, d):
	"""Raza zdrențuită a craterului `i` pe direcția `d` (vector unitar): marginea găurii nu e o sferă, ci o margine
	ruptă (zgomot pe sferă)."""
	from mathutils import noise
	c, raza = CRATERE[i]
	o = Vector((i * 13.7, i * 7.1, i * 3.3))
	return raza * (1.0 + 0.2 * noise.noise(d * 1.7 + o) + 0.1 * noise.noise(d * 4.3 + o))


def _taietor(i):
	"""Sfera zdrențuită a craterului `i`, colorată în negru ars: fețele tăiate în piatră primesc culoarea ei."""
	from unelte import _coloreaza
	c, _ = CRATERE[i]
	bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1.0, location=(0, 0, 0))
	ob = bpy.context.active_object
	for v in ob.data.vertices:
		d = v.co.normalized()
		v.co = Vector(c) + d * _raza_crater(i, d)
	ob.data.update()
	ob.name = "Taietor"
	_coloreaza(ob, NEGRU_ARS)
	return ob


def _cutie_piesa(ob):
	vs = [v.co for v in ob.data.vertices]
	return (Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs))),
		Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs))))


def _scade(ob, taietor):
	"""ob - taietor (boolean exact); fețele noi iau culoarea tăietorului."""
	mod = ob.modifiers.new("taie", 'BOOLEAN')
	mod.operation = 'DIFFERENCE'
	mod.object = taietor
	mod.solver = 'EXACT'
	bpy.context.view_layer.objects.active = ob
	bpy.ops.object.modifier_apply(modifier=mod.name)


def _sterge(ob, liste):
	for lista in liste:
		if ob in lista:
			lista.remove(ob)
	bpy.data.objects.remove(ob, do_unlink=True)


def _distruge(piese, lumini, r):
	"""Face din conacul întreg ruina de după atac:
	 - zidurile pline (`Zid`, `Turn`, `Turela`) devin pereți goi pe dinăuntru (cu podelele etajelor), ca prin găuri să se
	   vadă camerele arse, nu piatră plină;
	 - craterele (`CRATERE`) taie tot ce ating: piesele mari cu boolean (marginea ruptă, neagră), cele mici dispar;
	 - pereții din jurul găurilor se înnegresc de fum;
	 - moloz în grămezi (piatră, ardezie, grinzi arse, jar care strălucește), turla turnului prăbușită în curte,
	   arsuri pe pietriș.
	Întoarce piesele de coliziune ale molozului."""
	# 1. ziduri goale pe dinăuntru, cu podelele etajelor
	for ob in [o for o in piese if o.name.split(".")[0] in ("Zid", "Turn")]:
		mn, mx = _cutie_piesa(ob)
		g = GROSIME_ZID
		gol = cub("Gol", (mx.x - mn.x - 2 * g, mx.y - mn.y - 2 * g, mx.z - PL - 0.4), ((mn.x + mx.x) / 2, (mn.y + mx.y) / 2,
			(PL + mx.z - 0.4) / 2), NEGRU_ARS)
		_scade(ob, gol)
		bpy.data.objects.remove(gol, do_unlink=True)
		for z in NIVELURI[1:]:
			if z < mx.z - 1.0:
				piese.append(cub("Podea", (mx.x - mn.x - 2 * g - 0.02, mx.y - mn.y - 2 * g - 0.02, 0.24),
					((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, z - 0.13), LEMN_ARS))
	for ob in [o for o in piese if o.name.split(".")[0] == "Turela"]:
		gol = cilindru("Gol", TURELA_R - 0.4, TURELA_R - 0.4, TURELA_H - PL - 0.4, (TURELA[0], TURELA[1], (PL + TURELA_H - 0.4) / 2),
			NEGRU_ARS, laturi=12, rot=(0, 0, math.pi / 12))
		_scade(ob, gol)
		bpy.data.objects.remove(gol, do_unlink=True)

	# 2. craterele
	taietori = [_taietor(i) for i in range(len(CRATERE))]
	for lista in (piese, lumini):
		for ob in list(lista):
			mn, mx = _cutie_piesa(ob)
			marime = max(mx - mn)
			for i, (c, raza) in enumerate(CRATERE):
				c = Vector(c)
				# turnurile subțiri de deasupra găurii (coșuri cu capace și olane, conul turelei, turla, fleșele) cad întregi:
				# tăiate, bucata de sus ar rămâne în aer (oricât de sus ar fi, deci înaintea testului de distanță)
				xy = (Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, 0)) - Vector((c.x, c.y, 0))).length
				if ob.name.split(".")[0] in DE_PE_ACOPERIS and xy < raza * 1.3 and mn.z > c.z - raza:
					_sterge(ob, (piese, lumini))
					break
				aproape = Vector((min(max(c.x, mn.x), mx.x), min(max(c.y, mn.y), mx.y), min(max(c.z, mn.z), mx.z)))
				if (aproape - c).length > raza * 1.35:
					continue
				if marime > 1.2 and lista is piese:
					_scade(ob, taietori[i])
					if len(ob.data.polygons) == 0:
						_sterge(ob, (piese, lumini))
						break
				else:
					d = (mn + mx) / 2 - c
					if d.length < _raza_crater(i, d.normalized() if d.length > 0.001 else Vector((0, 0, 1))) * 0.97:
						_sterge(ob, (piese, lumini))
						break
	for t in taietori:
		bpy.data.objects.remove(t, do_unlink=True)

	# 3. funinginea din jurul găurilor: fețele de piatră de lângă un crater se înnegresc (pe sărite, ca petele de fum)
	for ob in piese:
		col = ob.data.color_attributes.get("Col")
		if col is None:
			continue
		for poly in ob.data.polygons:
			c = poly.center
			for i, (cc, raza) in enumerate(CRATERE):
				d = c - Vector(cc)
				if d.length < 0.001:
					continue
				margine = d.length - _raza_crater(i, d.normalized())
				if margine < 1.6 + r.uniform(-0.5, 0.6):
					k = FUNINGINE if margine > 0.6 or hash((round(c.x, 1), round(c.z, 1))) % 3 else NEGRU_ARS
					for li in poly.loop_indices:
						col.data[li].color_srgb = (k[0], k[1], k[2], 1.0)
					break

	# 4. molozul: grămezi de pietre la picioarele găurilor, cu ardezie din acoperiș, grinzi arse și jar
	col_moloz = []
	gramezi = [  # (x, y, raza pe x, raza pe y, înălțimea în mijloc, câte bucăți)
		(0.0, -1.6, 6.2, 4.0, 2.6, 420),
		(0.5, 5.0, 5.5, 4.0, 1.8, 160),
		(9.8, -0.6, 2.6, 1.6, 1.1, 70),
		(-11.0, -0.6, 2.3, 1.5, 0.9, 60),
		(14.6, -2.6, 2.2, 2.0, 0.9, 60),
	]
	culori_piatra = (ZID, ZID, PIATRA, PIATRA_INCHISA, NEGRU_ARS, FUNINGINE)
	for gx, gy, rx, ry, h, n in gramezi:
		for _ in range(n):
			u = r.uniform(0, math.tau)
			t = math.sqrt(r.random())
			x = gx + math.cos(u) * rx * t
			y = gy + math.sin(u) * ry * t
			sus = h * (1.0 - t * t) ** 1.3
			z = r.uniform(0.0, 1.0) ** 0.5 * sus
			if r.random() < 0.2:
				piese.append(cub("Ardezie", (r.uniform(0.4, 0.9), r.uniform(0.3, 0.6), 0.05), (x, y, z + 0.03), ARDEZIE,
					rot=(r.uniform(-0.9, 0.9), r.uniform(-0.9, 0.9), r.uniform(0, math.pi))))
			else:
				m = r.uniform(0.18, 0.75)
				piese.append(cub("Moloz", (m * r.uniform(0.8, 1.6), m * r.uniform(0.7, 1.3), m * r.uniform(0.5, 1.0)), (x, y, z + m * 0.25),
					r.choice(culori_piatra), rot=(r.uniform(-0.6, 0.6), r.uniform(-0.6, 0.6), r.uniform(0, math.pi))))
			if r.random() < 0.09:
				m = r.uniform(0.06, 0.16)
				lumini.append(cub("Jar", (m, m * 0.8, m * 0.6), (x + r.uniform(-0.2, 0.2), y + r.uniform(-0.2, 0.2), z + 0.12),
					r.choice((JAR, JAR, JAR_ROSU)), rot=(r.uniform(-1, 1), r.uniform(-1, 1), r.uniform(0, 3))))
		# grinzile arse care ies din grămadă
		for _ in range(int(n / 30)):
			u = r.uniform(0, math.tau)
			x = gx + math.cos(u) * rx * 0.5
			y = gy + math.sin(u) * ry * 0.5
			lung = r.uniform(2.0, 4.2)
			piese.append(cub("Grinda", (0.22, 0.22, lung), (x, y, lung * 0.32), r.choice((LEMN_ARS, NEGRU_ARS)),
				rot=(r.uniform(0.5, 1.2) * r.choice((-1, 1)), r.uniform(-0.4, 0.4), r.uniform(0, math.pi))))
		# coliziunea grămezii: o treaptă prea înaltă ca s-o urci (nu intri în ruină)
		col_moloz.append(cub("Moloz coliziune", (rx * 2.0, ry * 2.0, max(h, 0.8)), (gx, gy, max(h, 0.8) / 2), NEGRU_ARS))

	# 5. turla turnului, ruptă și căzută în curte (culcată, cu vârful spre față)
	tx, ty = TURN
	baza = Vector((tx + 2.2, ty - 4.0, 1.5))
	spre = Vector((0.55, -0.83, -0.09)).normalized()
	rot = Vector((0, 0, 1)).rotation_difference(spre).to_euler()
	raza_turla = (TURN_L + 0.25) * math.sqrt(2)
	piese.append(cilindru("Turla cazuta", raza_turla, 0.0, 10.5, tuple(baza + spre * 5.25), ARDEZIE, laturi=4, rot=rot))
	piese.append(cilindru("Ciot turla", raza_turla + 0.05, raza_turla * 0.8, 2.4, tuple(baza - spre * 0.6), NEGRU_ARS, laturi=4, rot=rot))
	piese.append(cilindru("Flesa", 0.05, 0.03, 2.4, tuple(baza + spre * 11.6), FIER, laturi=4, rot=rot))
	col_moloz.append(cilindru("Turla coliziune", raza_turla, 0.2, 10.5, tuple(baza + spre * 5.25), NEGRU_ARS, laturi=4, rot=rot))
	for _ in range(40):  # ardezia ruptă din turlă, împrăștiată
		x = baza.x + spre.x * r.uniform(0, 10) + r.uniform(-2.5, 2.5)
		y = baza.y + spre.y * r.uniform(0, 10) + r.uniform(-2.5, 2.5)
		piese.append(cub("Ardezie", (r.uniform(0.3, 0.7), r.uniform(0.2, 0.5), 0.04), (x, y, 0.1 + r.uniform(0, 0.15)), ARDEZIE,
			rot=(r.uniform(-0.5, 0.5), r.uniform(-0.5, 0.5), r.uniform(0, 3))))

	# 6. arsurile de pe pietriș (pietrișul e la 4–5,5 cm): discuri negre neregulate, fiecare la altă înălțime
	for k, (x, y, raza) in enumerate(((0.0, -8.5, 3.2), (4.5, -12.0, 2.0), (-4.5, -10.5, 2.2), (0.0, -16.0, 1.6), (6.5, -6.0, 1.8))):
		piese.append(cilindru("Arsura", raza, raza * 0.9, 0.02, (x, y, 0.075 + k * 0.012), NEGRU_ARS, laturi=9,
			rot=(0, 0, r.uniform(0, 3))))
	return col_moloz


# ---------------------------------------------------------------------------------------------------------------
# Curtea
# ---------------------------------------------------------------------------------------------------------------

def poarta_conac(cale):
	"""Poarta curții: doi stâlpi groși de piatră (capace, bile), porțile de fier închise cu arc ascuțit deasupra și o
	pentagramă într-un cerc (e coven-ul). Golul are 3 m, centrat în origine, pe X; gardul de fier (gard_fier.glb)
	se prinde de stâlpi la x = ±1,9."""
	curata()
	piese = []
	for s in (-1, 1):
		x = s * 1.85
		piese += [
			cub("Stalp poarta", (0.7, 0.7, 2.9), (x, 0, 1.45), ZID),
			cub("Soclu stalp", (0.84, 0.84, 0.35), (x, 0, 0.175), PIATRA_INCHISA),
			cub("Capac stalp", (0.86, 0.86, 0.14), (x, 0, 2.97), PIATRA),
			cilindru("Postament", 0.22, 0.28, 0.3, (x, 0, 3.19), PIATRA, laturi=8),
			sfera("Bila stalp", 0.3, (x, 0, 3.6), PIATRA, segmente=10, inele=6),
			cub("Muschi", (0.5, 0.02, 0.5), (x, -0.36, 0.55), MUSCHI),
		]
		for k in range(11):  # foile porții
			xx = s * (0.07 + k * 0.135)
			inalt = 2.1 + (1.0 - (k / 10.0)) * 0.6  # urcă spre mijloc: arcul
			piese.append(cub("Zabrea", (0.025, 0.025, inalt), (xx, 0, inalt / 2 + 0.05), FIER))
			piese.append(cilindru("Sulita", 0.03, 0.0, 0.12, (xx, 0, inalt + 0.11), FIER, laturi=4))
		piese.append(cub("Bara poarta", (1.48, 0.055, 0.05), (s * 0.75, 0, 0.35), FIER))
		piese.append(cub("Bara poarta", (1.48, 0.055, 0.05), (s * 0.75, 0, 1.9), FIER))
	# cercul cu pentagrama, între foi, sus
	zc = 2.35
	for k in range(16):
		u = k * math.tau / 16
		piese.append(cub("Cerc", (0.13, 0.03, 0.03), (math.cos(u) * 0.42, -0.03, zc + math.sin(u) * 0.42), FIER, rot=(0, -u + math.pi / 2, 0)))
	varfuri = [(math.cos(math.pi / 2 + k * math.tau / 5) * 0.4, zc + math.sin(math.pi / 2 + k * math.tau / 5) * 0.4) for k in range(5)]
	for k in range(5):
		a = varfuri[k]
		b = varfuri[(k + 2) % 5]
		lung = math.hypot(b[0] - a[0], b[1] - a[1])
		u = math.atan2(b[1] - a[1], b[0] - a[0])
		piese.append(cub("Pentagrama", (lung, 0.025, 0.025), ((a[0] + b[0]) / 2, -0.05, (a[1] + b[1]) / 2), FIER, rot=(0, -u, 0)))
	piese += [
		cub("Lant", (0.06, 0.05, 0.25), (0, -0.04, 1.2), BORDURA),
		cub("Lacat", (0.09, 0.05, 0.1), (0, -0.07, 1.05), GEAM_APRINS),
	]
	uneste(piese, "Poarta")
	exporta(os.path.join(cale, "poarta_conac.glb"))


def felinar_conac(cale):
	"""Felinar de fier pe stâlp (3,2 m): soclu, stâlp cu inele, felinarul cu patru montanți, flacăra (`Lumini`) și
	capacul piramidal cu bilă. Lumina adevărată o pune Godot (OmniLight) la y = 2,85."""
	curata()
	piese, lumini = [], []
	piese += [
		cub("Soclu", (0.36, 0.36, 0.3), (0, 0, 0.15), PIATRA),
		cilindru("Stalp", 0.06, 0.045, 2.5, (0, 0, 1.55), FIER, laturi=6),
		cilindru("Inel", 0.09, 0.09, 0.08, (0, 0, 0.55), FIER, laturi=6),
		cilindru("Inel", 0.08, 0.08, 0.06, (0, 0, 2.2), FIER, laturi=6),
		cub("Fund felinar", (0.36, 0.36, 0.05), (0, 0, 2.6), FIER),
		cilindru("Capac felinar", 0.32, 0.0, 0.32, (0, 0, 3.24), FIER, laturi=4, rot=(0, 0, math.pi / 4)),
		cub("Brau capac", (0.38, 0.38, 0.05), (0, 0, 3.06), FIER),
		sfera("Bila", 0.05, (0, 0, 3.44), FIER, segmente=6, inele=4),
	]
	for dx, dy in ((-0.16, -0.16), (0.16, -0.16), (-0.16, 0.16), (0.16, 0.16)):
		piese.append(cub("Montant", (0.03, 0.03, 0.42), (dx, dy, 2.84), FIER))
	lumini.append(cub("Flacara", (0.26, 0.26, 0.38), (0, 0, 2.84), GEAM_APRINS))
	uneste(piese, "Felinar")
	uneste(lumini, "Lumini")
	exporta(os.path.join(cale, "felinar_conac.glb"))


def fantana(cale):
	"""Fântâna din mijlocul curții (secată, cu apă stătută verde-închis): bazin octogonal cu buză, stâlp, cupa de sus,
	iar în vârf o statuie: o vrăjitoare cu glugă, cu brațele ridicate. Mușchi pe bazin."""
	curata()
	piese = [
		cilindru("Bazin", 2.3, 2.3, 0.62, (0, 0, 0.31), PIATRA, laturi=8, rot=(0, 0, math.pi / 8)),
		cilindru("Buza bazin", 2.45, 2.45, 0.12, (0, 0, 0.68), PIATRA, laturi=8, rot=(0, 0, math.pi / 8)),
		cilindru("Apa", 2.1, 2.1, 0.02, (0, 0, 0.75), APA, laturi=8, rot=(0, 0, math.pi / 8)),
		cilindru("Stalp fantana", 0.32, 0.25, 1.4, (0, 0, 1.45), PIATRA, laturi=8),
		cilindru("Cupa", 0.3, 0.95, 0.35, (0, 0, 2.3), PIATRA, laturi=10),
		cilindru("Buza cupa", 1.0, 1.0, 0.08, (0, 0, 2.51), PIATRA, laturi=10),
		cilindru("Postament statuie", 0.32, 0.36, 0.5, (0, 0, 2.8), ZID, laturi=8),
	]
	# statuia: roba (trunchi), glugă, brațele ridicate spre cer
	piese.append(trunchi("Roba", [((0, 0, 3.05), 0.36, 0.34), ((0, 0, 3.6), 0.27, 0.24), ((0, 0, 4.2), 0.2, 0.18),
		((0, 0, 4.45), 0.16, 0.15)], ZID, laturi=8))
	piese.append(trunchi("Gluga", [((0, 0.02, 4.4), 0.17, 0.17), ((0, 0.03, 4.7), 0.17, 0.16), ((0, 0.07, 4.95), 0.0, 0.0)], ZID, laturi=8))
	piese.append(sfera("Fata statuie", 0.11, (0, -0.07, 4.62), PIATRA_INCHISA, segmente=6, inele=4))
	for s in (-1, 1):
		piese.append(os_intre("Brat statuie", (s * 0.17, 0, 4.3), (s * 0.42, -0.08, 4.95), 0.06, ZID))
		piese.append(sfera("Mana statuie", 0.06, (s * 0.44, -0.08, 5.0), ZID, segmente=6, inele=4))
	r = random.Random(3)
	for k in range(8):
		u = (k + 0.5) * math.tau / 8
		if r.random() < 0.6:
			piese.append(cub("Muschi", (r.uniform(0.4, 0.9), 0.02, r.uniform(0.15, 0.35)), (math.cos(u) * 2.15, math.sin(u) * 2.15, 0.25), MUSCHI,
				rot=(0, 0, u + math.pi / 2)))
	uneste(piese, "Fantana")
	exporta(os.path.join(cale, "fantana.glb"))


# ---------------------------------------------------------------------------------------------------------------
# Easter egg-ul din spatele conacului
# ---------------------------------------------------------------------------------------------------------------

AUR = p("a18463")
AUR_INCHIS = p("a56850")
NEGRU = p("262d2f")


def pistol_aur(cale):
	"""Pistolul placat cu aur (un Desert Eagle): țeava lungă cu șină pe ea, închizătorul cu zimți, cocoșul, plăsele
	negre cu un medalion de aur, gravuri pe laterale. Aurul e din paletă (a18463, umbrele a56850); `Luciu` (muchiile
	de sus, medalioanele) e separat și strălucește puțin în joc, ca să sclipească. Ca la pistolul roz: țeava spre +Y
	(în Godot: -Z, înainte), originea = locul unde îl ții (sus pe mâner), gura țevii la (0, 0,19, 0,046)."""
	curata()
	piese, luciu = [], []
	piese += [
		# cadrul de jos
		cub("Cadru", (0.026, 0.2, 0.024), (0, 0.05, 0.012), AUR),
		# blocul țevii (în față) și închizătorul (în spate), puțin mai lat
		cub("Teava", (0.03, 0.15, 0.036), (0, 0.105, 0.042), AUR),
		cub("Inchizator", (0.032, 0.09, 0.04), (0, -0.015, 0.044), AUR),
		cub("Gura tevii", (0.012, 0.012, 0.012), (0, 0.184, 0.046), NEGRU),
		cub("Catare", (0.008, 0.008, 0.008), (0, 0.172, 0.0665), AUR_INCHIS),
		cub("Inaltator", (0.02, 0.01, 0.01), (0, -0.05, 0.069), AUR_INCHIS),
		cub("Fereastra", (0.004, 0.04, 0.016), (0.017, 0.0, 0.05), NEGRU),
		cub("Cocos", (0.01, 0.014, 0.018), (0, -0.064, 0.054), AUR_INCHIS, rot=(-0.4, 0, 0)),
		# mânerul, înclinat spre spate, cu talpa magaziei
		cub("Maner", (0.03, 0.055, 0.115), (0, -0.03, -0.045), AUR, rot=(-0.28, 0, 0)),
		cub("Talpa magazie", (0.034, 0.06, 0.014), (0, -0.046, -0.103), AUR_INCHIS, rot=(-0.28, 0, 0)),
		# trăgaciul și apărătoarea
		cub("Tragaci", (0.008, 0.008, 0.024), (0, 0.032, -0.012), NEGRU, rot=(0.3, 0, 0)),
		cub("Aparatoare", (0.012, 0.064, 0.008), (0, 0.042, -0.032), AUR),
		cub("Aparatoare", (0.01, 0.008, 0.032), (0, 0.072, -0.016), AUR),
	]
	for sx in (-1, 1):
		# plăsele negre pe mâner, cu medalionul de aur
		x = sx * 0.0165
		piese.append(cub("Plasea", (0.004, 0.045, 0.09), (x, -0.028, -0.043), NEGRU, rot=(-0.28, 0, 0)))
		luciu.append(cilindru("Medalion", 0.008, 0.008, 0.003, (sx * 0.0195, -0.022, -0.035), AUR, laturi=8, rot=(0, math.pi / 2, 0)))
		# zimții închizătorului
		for k in range(5):
			piese.append(cub("Zimt", (0.004, 0.004, 0.03), (sx * 0.0175, -0.056 + k * 0.007, 0.044), AUR_INCHIS))
		# gravurile de pe țeavă: o liniuță lungă și volute mici
		piese.append(cub("Gravura", (0.004, 0.11, 0.003), (sx * 0.0165, 0.11, 0.032), AUR_INCHIS))
		for k in range(4):
			piese.append(cub("Voluta", (0.004, 0.008, 0.008), (sx * 0.0165, 0.07 + k * 0.025, 0.05), AUR_INCHIS, rot=(0.785, 0, 0)))
	# muchiile de sus: șina de pe țeavă și marginile închizătorului (sclipesc)
	luciu.append(cub("Sina", (0.012, 0.15, 0.006), (0, 0.105, 0.063), AUR))
	luciu.append(cub("Muchie", (0.034, 0.088, 0.004), (0, -0.015, 0.066), AUR))
	uneste(piese, "Pistol")
	uneste(luciu, "Luciu")
	exporta(os.path.join(cale, "pistol_aur.glb"))


def masa_pistol(cale):
	"""Masa din spatele conacului, cu easter egg-ul: o măsuță de grădină din scânduri strâmbe, pe ea un carton îndoit
	(„Free shit”, scris cu markerul), o pernuță de catifea verde-închis pe care stă pistolul de aur (îl pune jocul, la
	(0,18, -0,12, 0,77) în Blender), câteva gloanțe și o lumânare într-un borcan (`Lumini` = flacăra).
	Originea la sol, în mijlocul mesei; fața spre -Y. `Coliziune` = o cutie cât masa."""
	curata()
	r = random.Random(5)
	piese, lumini = [], []
	h = 0.74  # fața mesei
	for k in range(5):  # scândurile blatului, cu rosturi
		y = -0.32 + k * 0.16
		piese.append(cub("Scandura", (1.2 + r.uniform(-0.03, 0.03), 0.15, 0.035), (r.uniform(-0.02, 0.02), y, h - 0.0175),
			LEMN if k % 2 else p("5e363e"), rot=(0, 0, r.uniform(-0.01, 0.01))))
	for sx in (-1, 1):
		piese.append(cub("Traversa", (0.05, 0.74, 0.05), (sx * 0.5, 0, h - 0.06), LEMN))
		for sy in (-1, 1):
			piese.append(cub("Picior", (0.06, 0.06, h - 0.085), (sx * 0.52, sy * 0.3, (h - 0.085) / 2), LEMN,
				rot=(sy * 0.04, sx * 0.04, 0)))
	for sy in (-1, 1):
		piese.append(cub("Bara", (0.98, 0.04, 0.04), (0, sy * 0.3, 0.18), LEMN))
	# cartonul îndoit (ca un cort), cu scrisul pe fața din față
	t = 0.35
	lat, inalt = 0.46, 0.27
	for s in (-1, 1):
		piese.append(cub("Carton", (lat, 0.006, inalt), (-0.24, s * inalt / 2 * math.sin(t), h + inalt / 2 * math.cos(t)),
			AUR_INCHIS if s < 0 else p("904a40"), rot=(s * t, 0, 0)))
	normala = Vector((0, -math.cos(t), math.sin(t)))
	centru = Vector((-0.24, -inalt / 2 * math.sin(t), h + inalt / 2 * math.cos(t))) + normala * 0.012
	piese.append(text("Scris", "Free shit", tuple(centru), 0.085, NEGRU, rot=(math.pi / 2 - t, 0, 0)))
	# pernuța de catifea și gloanțele
	piese.append(cub("Perna", (0.3, 0.2, 0.03), (0.18, -0.12, h + 0.015), APA, rot=(0, 0, 0.08)))
	for k, (x, y, u) in enumerate(((0.38, -0.25, 0.3), (0.42, -0.16, 1.2), (0.37, 0.02, 2.4))):
		piese.append(cilindru("Glont", 0.006, 0.006, 0.022, (x, y, h + 0.006), AUR, laturi=6, rot=(math.pi / 2, 0, u)))
		piese.append(cilindru("Varf glont", 0.006, 0.0, 0.01, (x + math.sin(u) * 0.016, y - math.cos(u) * 0.016, h + 0.006), AUR_INCHIS,
			laturi=6, rot=(math.pi / 2, 0, u)))
	# lumânarea în borcan
	piese += [
		cilindru("Lumanare", 0.03, 0.03, 0.09, (0.45, 0.2, h + 0.045), ALB, laturi=8),
		cilindru("Fitil", 0.003, 0.003, 0.015, (0.45, 0.2, h + 0.097), NEGRU, laturi=4),
	]
	for k in range(6):  # pereții borcanului: șase plăci subțiri (sticla nu acoperă lumânarea)
		u = k * math.tau / 6
		piese.append(cub("Borcan", (0.045, 0.004, 0.12), (0.45 + math.cos(u) * 0.045, 0.2 + math.sin(u) * 0.045, h + 0.06),
			p("30716f"), rot=(0, 0, u + math.pi / 2)))
	lumini.append(sfera("Flacara", 0.012, (0.45, 0.2, h + 0.118), GEAM_APRINS, scara=(1, 1, 1.8), segmente=6, inele=4))
	col = [cub("Coliziune", (1.2, 0.76, h), (0, 0, h / 2), LEMN)]
	uneste(col, "Coliziune")
	uneste(piese, "Masa")
	uneste(lumini, "Lumini")
	exporta(os.path.join(cale, "masa_pistol.glb"))


def toate(cale):
	conac(cale)
	conac_distrus(cale)
	poarta_conac(cale)
	felinar_conac(cale)
	fantana(cale)
	pistol_aur(cale)
	masa_pistol(cale)


if __name__ == "__main__":
	cale_modele = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")
	if "--" in sys.argv:
		for nume in sys.argv[sys.argv.index("--") + 1:]:
			globals()[nume](cale_modele)
	else:
		toate(cale_modele)
