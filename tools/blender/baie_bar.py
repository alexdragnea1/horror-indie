# Baia barului „URBAN” (owner, 11.10): ușa „RESTROOMS” din spatele barului te duce (UsaTeleport, ca „EMPLOYEES ONLY”)
# într-o toaletă de bar, jegoasă: gresie în carouri, faianță verzuie până la umăr, două cabine (una „OUT OF ORDER”),
# două pisoare, blatul negru cu două chiuvete și oglinda crăpată, uscătorul de mâini, coșul plin, neonul care pâlpâie,
# graffiti pe pereți. La blat, „8 Ball Enjoyer” trage linii de pe telefon.
#   baie      -> bar_baie.glb        (`Baie`, `Lumini`, `Coliziune`)
#   recuzita  -> recuzita_8ball.glb  (`Telefon`, `Ecran`, `Linie1..3`, `Card`, `Bancnota`, `Punga`)
#   prizator  -> prizator_baie.glb   (8 Ball Enjoyer, în picioare, prin casino_oameni.om)
#   blender --background --factory-startup --python tools/blender/baie_bar.py               (toate)
#   blender --background --factory-startup --python tools/blender/baie_bar.py -- recuzita   (doar unele)
# Axe Blender: Z în sus; Godot = (x, z, -y) din Blender. Originea = mijlocul podelei băii; în bar.tscn baia stă sub
# pământ (nodul `Baie` la (0, -8, -6)): e închisă de jur împrejur, deci nu se vede nimic din afară.
import math
import os
import random
import sys

import bpy
from mathutils import Matrix

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, uneste, exporta, trunchi, desparte_fete  # noqa: E402
from casino import _text_o_fata, _cutie_coliziune, _tor  # noqa: E402
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
ROSU = p("7b383a")
TENCUIALA = p("7e8d87")
BRONZ = p("a56850")
VERDE = p("5b6d4e")
TEAL = p("438b88")
PETROL = p("295555")
PETROL_DESCHIS = p("30716f")
MOV = p("655269")
MASLINIU = p("7a7b59")
GRI_ALBASTRU = p("778c96")

XI = 2.0     # jumătate din lățimea dinăuntru (x de la -2 la 2)
YI = 1.6     # jumătate din adâncime (y de la -1,6 = peretele cu ușa, la 1,6 = cabinele)
H = 2.6      # tavanul
G = 0.2      # grosimea pereților
FAIANTA = 1.45
USA_X = 1.3  # ușa (pe peretele -Y)
# blatul cu chiuvetele, pe peretele din stânga (-X): fața spre cameră la BX, de la BY0 la BY1, deasupra la BZ
BX, BY0, BY1, BZ = -1.42, -1.55, 0.1, 0.905
CHIUVETE = (-1.25, -0.15)
# telefonul: pe blat, între chiuvete, cu lungimea pe X (liniile merg dinspre om spre perete)
TEL = (-1.69, -0.7)
# cabinele: de la x -2 la -0.1, fața la y 0,2
CAB_Y = 0.2
CABINE = ((-2.0, -1.05), (-1.05, -0.1))
PISOARE = (0.4, 1.1)


def _strange(piese, nume):
	if len(piese) > 1:
		piese[:] = [uneste(piese, nume)]


def baie(cale):
	curata()
	r = random.Random(808)
	piese, lumini, col = [], [], []

	def strange():
		_strange(piese, "Baie")

	# --- podeaua: gresie în carouri (plăci de 0,4 m, alternant), cu pete și hârtie igienică pe jos
	n = 0
	x = -XI
	while x < XI - 0.001:
		y = -YI
		while y < YI - 0.001:
			piese.append(cub("Gresie", (0.4, 0.4, 0.1), (x + 0.2, y + 0.2, -0.05), ALB if (n + int((y + YI) / 0.4)) % 2 == 0 else METAL_INCHIS))
			y += 0.4
		x += 0.4
		n += 1
	_cutie_coliziune(col, (2 * XI + 2 * G, 2 * YI + 2 * G, 0.2), (0, 0, -0.1))
	for k in range(5):
		piese.append(cub("Balta", (r.uniform(0.25, 0.5), r.uniform(0.2, 0.4), 0.01), (r.uniform(0.6, 1.8), r.uniform(-0.2, 1.4), 0.004),
			GRI_ALBASTRU, rot=(0, 0, r.uniform(0, 3))))
	strange()

	# --- pereții (cutii pe dinafară), faianța până la umăr cu brâul închis, tencuiala murdară deasupra, tavanul
	for (dx, dy, cx, cy) in ((G, 2 * YI + 2 * G, -XI - G / 2, 0), (G, 2 * YI + 2 * G, XI + G / 2, 0),
			(2 * XI, G, 0, -YI - G / 2), (2 * XI, G, 0, YI + G / 2)):
		piese.append(cub("Perete", (dx, dy, H + 0.2), (cx, cy, H / 2), TENCUIALA))
		_cutie_coliziune(col, (dx, dy, H + 0.4), (cx, cy, H / 2))
	piese.append(cub("Tavan", (2 * XI + 2 * G, 2 * YI + 2 * G, 0.15), (0, 0, H + 0.075), METAL_INCHIS))
	_cutie_coliziune(col, (2 * XI + 2 * G, 2 * YI + 2 * G, 0.2), (0, 0, H + 0.1))
	f = 0.012
	for (dx, dy, cx, cy) in ((f, 2 * YI, -XI + f / 2, 0), (f, 2 * YI, XI - f / 2, 0), (2 * XI, f, 0, -YI + f / 2), (2 * XI, f, 0, YI - f / 2)):
		piese.append(cub("Faianta", (dx, dy, FAIANTA), (cx, cy, FAIANTA / 2), PETROL_DESCHIS))
		bx, by = (dx + 0.012 if dx < 0.1 else dx), (dy + 0.012 if dy < 0.1 else dy)
		piese.append(cub("Brau", (bx, by, 0.06), (cx, cy, FAIANTA + 0.03), PETROL))
		piese.append(cub("Plinta", (bx, by, 0.1), (cx, cy, 0.05), PETROL))
	# rosturile faianței: linii orizontale închise, din 15 în 15 cm (doar pe pereții care se văd mult)
	for z in [0.25 + 0.15 * k for k in range(8)]:
		piese.append(cub("Rost", (0.006, 2 * YI - 0.02, 0.006), (XI - 0.014, 0, z), TEAL))
		piese.append(cub("Rost", (2 * XI - 0.02, 0.006, 0.006), (0, YI - 0.014, z), TEAL))
	# plăci de faianță sparte / lipsă (se vede tencuiala)
	for k in range(7):
		zz = r.uniform(0.3, 1.3)
		if k % 2:
			piese.append(cub("Placa lipsa", (0.004, 0.15, 0.15), (XI - 0.016, r.uniform(-1.4, -0.3), zz), TENCUIALA))
		else:
			piese.append(cub("Placa lipsa", (0.15, 0.004, 0.15), (r.uniform(-1.8, 1.8), -YI + 0.016, zz), TENCUIALA))
	strange()

	# --- neonul din tavan (pâlpâie în joc) și lampa de deasupra oglinzii
	piese.append(cub("Corp neon", (1.3, 0.22, 0.06), (0.2, 0.2, H - 0.03), METAL))
	lumini.append(cub("Tub neon", (1.2, 0.05, 0.04), (0.2, 0.14, H - 0.07), ALB))
	lumini.append(cub("Tub neon", (1.2, 0.05, 0.04), (0.2, 0.26, H - 0.07), ALB))
	piese.append(cub("Corp lampa oglinda", (0.1, 0.8, 0.07), (-XI + 0.05, -0.7, 2.08), METAL))
	lumini.append(cub("Bec lampa oglinda", (0.03, 0.72, 0.03), (-XI + 0.1, -0.7, 2.05), AUR))
	strange()

	# --- ușa (pe dinăuntru; e UsaTeleport în joc), cu tocul, placa de împins și afișul de lângă
	piese.append(cub("Usa baie", (0.92, 0.05, 2.15), (USA_X, -YI + 0.025, 1.075), LEMN_INCHIS))
	piese.append(cub("Toc usa", (1.04, 0.04, 0.06), (USA_X, -YI + 0.02, 2.18), NEGRU))
	for sx in (-1, 1):
		piese.append(cub("Toc usa", (0.06, 0.04, 2.15), (USA_X + sx * 0.49, -YI + 0.02, 1.075), NEGRU))
	piese.append(cub("Placa impins", (0.1, 0.01, 0.3), (USA_X - 0.33, -YI + 0.055, 1.15), CROM))
	piese.append(cub("Afis spalat", (0.36, 0.008, 0.26), (0.15, -YI + 0.016, 1.65), ALB))
	piese.append(_text_o_fata("Scris afis", "EMPLOYEES\nMUST WASH\nHANDS", (0.15, -YI + 0.021, 1.65), 0.045, NEGRU, rot=(1.5708, 0, math.pi)))
	strange()

	# --- blatul cu chiuvetele (stânga), dulapul de dedesubt, oglinda crăpată, dozatorul de săpun
	ad = BY1 - BY0
	cy = (BY0 + BY1) / 2
	piese.append(cub("Blat", (-XI - BX + 0.03, ad, 0.05), ((-XI + BX) / 2 - 0.015, cy, BZ - 0.025), NEGRU))
	piese.append(cub("Dulap blat", (-XI - BX - 0.04, ad - 0.04, BZ - 0.15), ((-XI + BX) / 2 - 0.04, cy, (BZ - 0.15) / 2 + 0.1), LEMN_INCHIS))
	piese.append(cub("Soclu blat", (-XI - BX - 0.1, ad - 0.06, 0.1), ((-XI + BX) / 2 - 0.07, cy, 0.05), NEGRU))
	for yy in (BY0 + 0.45, cy + 0.2):
		piese.append(cub("Usa dulap", (0.012, 0.6, BZ - 0.3), (BX - 0.034, yy, (BZ - 0.15) / 2 + 0.1), LEMN))
	_cutie_coliziune(col, (-XI - BX + 0.03, ad, BZ), ((-XI + BX) / 2 - 0.015, cy, BZ / 2))
	for yc in CHIUVETE:
		xc = -1.72
		piese.append(cilindru("Chiuveta", 0.17, 0.17, 0.006, (xc, yc, BZ + 0.003), ALB, laturi=14, scara=(0.8, 1.15, 1.0)))
		piese.append(cilindru("Fund chiuveta", 0.12, 0.12, 0.004, (xc, yc, BZ + 0.007), TENCUIALA, laturi=14, scara=(0.8, 1.15, 1.0)))
		piese.append(cilindru("Scurgere", 0.02, 0.02, 0.004, (xc + 0.02, yc, BZ + 0.0095), NEGRU, laturi=8))
		piese.append(os_intre("Robinet", (-XI + 0.08, yc, BZ), (-XI + 0.08, yc, BZ + 0.22), 0.014, CROM, laturi=6))
		piese.append(os_intre("Robinet", (-XI + 0.08, yc, BZ + 0.21), (-XI + 0.22, yc, BZ + 0.17), 0.011, CROM, laturi=6))
		piese.append(cub("Maner robinet", (0.03, 0.08, 0.014), (-XI + 0.08, yc, BZ + 0.24), CROM))
	piese.append(cub("Rama oglinda", (0.02, 1.52, 0.8), (-XI + 0.022, -0.7, 1.5), METAL))
	# oglinda: închisă (reflectă baia, nu lumina), cu două dâre deschise în diagonală
	piese.append(cub("Oglinda", (0.01, 1.44, 0.72), (-XI + 0.037, -0.7, 1.5), GEAM))
	for dy, l in ((-1.1, 0.5), (-0.95, 0.3), (-0.2, 0.45)):
		piese.append(cub("Luciu oglinda", (0.004, 0.03, l), (-XI + 0.044, dy, 1.5), GRI_ALBASTRU, rot=(0.6, 0, 0)))
	# crăpătura din colț (o stea de linii) și un abțibild
	for a in (0.3, 1.1, 1.9, 2.6, 3.9, 5.0):
		l = r.uniform(0.12, 0.3)
		piese.append(cub("Crapatura", (0.004, l, 0.006), (-XI + 0.044, -0.25 + math.cos(a) * l / 2, 1.7 + math.sin(a) * l / 2), TENCUIALA,
			rot=(a, 0, 0)))
	piese.append(cub("Abtibild", (0.004, 0.14, 0.09), (-XI + 0.044, -1.25, 1.25), ROSU))
	piese.append(_text_o_fata("Scris abtibild", "8 BALL\nCORNER\nPOCKET", (-XI + 0.047, -1.25, 1.25), 0.024, ALB, rot=(1.5708, 0, 1.5708)))
	piese.append(cub("Dozator sapun", (0.08, 0.1, 0.16), (-XI + 0.05, -0.7, 1.02), ALB))
	piese.append(cub("Buton dozator", (0.02, 0.05, 0.03), (-XI + 0.1, -0.7, 0.97), METAL))
	strange()

	# --- cabinele (spate): pereții despărțitori, stâlpii din față, ușile (prima deschisă spre înăuntru, a doua
	# închisă, cu „OUT OF ORDER”), bara de sus, vasele de toaletă cu rezervoarele
	pz0, pz1 = 0.15, 1.95
	for xp in (-1.05, -0.1):
		piese.append(cub("Perete cabina", (0.03, YI - CAB_Y, pz1 - pz0), (xp, (YI + CAB_Y) / 2, (pz0 + pz1) / 2), PETROL))
		_cutie_coliziune(col, (0.05, YI - CAB_Y, 2.0), (xp, (YI + CAB_Y) / 2, 1.0))
	for k, (a, b) in enumerate(CABINE):
		a2 = a + 0.012 if k == 0 else a + 0.015
		b2 = b - 0.015
		# stâlpii din stânga și din dreapta ușii, de la podea
		piese.append(cub("Stalp cabina", (0.15, 0.03, pz1), (a2 + 0.075, CAB_Y, pz1 / 2), PETROL))
		piese.append(cub("Stalp cabina", (0.16, 0.03, pz1), (b2 - 0.08, CAB_Y, pz1 / 2), PETROL))
		_cutie_coliziune(col, (0.15, 0.06, 2.0), (a2 + 0.075, CAB_Y, 1.0))
		_cutie_coliziune(col, (0.16, 0.06, 2.0), (b2 - 0.08, CAB_Y, 1.0))
		ux0, ux1 = a2 + 0.16, b2 - 0.17
		lat = ux1 - ux0
		if k == 0:
			# deschisă: balamaua la ux0, rotită 95° spre înăuntru (spre +Y)
			piese.append(cub("Usa cabina", (lat, 0.025, pz1 - pz0), (ux0 + lat / 2, CAB_Y, (pz0 + pz1) / 2), PETROL_DESCHIS))
			u = piese[-1]
			u.data.transform(Matrix.Translation((-ux0, -CAB_Y, 0)))
			u.data.transform(Matrix.Rotation(math.radians(95), 4, 'Z'))
			u.data.transform(Matrix.Translation((ux0 + 0.02, CAB_Y + 0.02, 0)))
			_cutie_coliziune(col, (0.06, lat, 2.0), (ux0 + 0.02, CAB_Y + 0.02 + lat / 2, 1.0))
		else:
			piese.append(cub("Usa cabina", (lat, 0.025, pz1 - pz0), (ux0 + lat / 2, CAB_Y, (pz0 + pz1) / 2), PETROL_DESCHIS))
			_cutie_coliziune(col, (lat, 0.06, 2.0), (ux0 + lat / 2, CAB_Y, 1.0))
			piese.append(cub("Hartie usa", (0.24, 0.006, 0.18), (ux0 + lat / 2, CAB_Y - 0.016, 1.45), ALB, rot=(0, 0.06, 0)))
			piese.append(_text_o_fata("Scris hartie", "OUT OF\nORDER", (ux0 + lat / 2, CAB_Y - 0.02, 1.45), 0.05, ROSU, rot=(1.5708, 0.06, 0)))
			piese.append(cub("Zavor", (0.05, 0.012, 0.03), (ux1 - 0.05, CAB_Y - 0.02, 1.05), ROSU))
		# vasul de toaletă, capacul ridicat, rezervorul, hârtia igienică
		tx = (a + b) / 2
		piese.append(cub("Rezervor", (0.42, 0.18, 0.36), (tx, YI - 0.1, 0.62), ALB))
		piese.append(cub("Capac rezervor", (0.45, 0.2, 0.03), (tx, YI - 0.1, 0.815), ALB))
		piese.append(trunchi("Picior wc", [((tx, YI - 0.33, 0.0), 0.12, 0.15), ((tx, YI - 0.36, 0.3), 0.16, 0.2)], ALB, laturi=10))
		piese.append(trunchi("Vas wc", [((tx, YI - 0.4, 0.3), 0.16, 0.2), ((tx, YI - 0.4, 0.4), 0.19, 0.24)], ALB, laturi=12, capete=False))
		piese.append(cilindru("Apa wc", 0.15, 0.15, 0.004, (tx, YI - 0.42, 0.34), GRI_ALBASTRU, laturi=12, scara=(1.0, 1.25, 1.0)))
		piese.append(_tor("Colac wc", 0.18, 0.025, (tx, YI - 0.4, 0.42), NEGRU, scara=(1.0, 1.25, 1.0)))
		piese.append(cub("Capac wc", (0.36, 0.03, 0.44), (tx, YI - 0.2, 0.62), NEGRU, rot=(-0.12, 0, 0)))
		_cutie_coliziune(col, (0.45, 0.65, 0.85), (tx, YI - 0.33, 0.42))
		piese.append(cilindru("Hartie wc", 0.055, 0.055, 0.1, (b - 0.1 if k == 0 else a + 0.1, YI - 0.6, 0.7), ALB, laturi=8, rot=(0, 1.5708, 0)))
	piese.append(os_intre("Bara cabine", (-XI, CAB_Y, pz1 + 0.04), (-0.1, CAB_Y, pz1 + 0.04), 0.02, CROM, laturi=6))
	# hârtia igienică trasă pe jos din prima cabină
	for k in range(6):
		piese.append(cub("Hartie jos", (0.11, 0.2, 0.004), (-1.45 + k * 0.05 + r.uniform(-0.03, 0.03), 0.05 - k * 0.19, 0.004 + 0.002 * (k % 2)), ALB,
			rot=(0, 0, r.uniform(-0.4, 0.4))))
	strange()

	# --- pisoarele (dreapta), cu despărțitorul și țevile de apă; uscătorul de mâini, coșul plin
	for yp in PISOARE:
		piese.append(cub("Pisoar", (0.3, 0.38, 0.62), (XI - 0.15, yp, 0.78), ALB))
		piese.append(cub("Interior pisoar", (0.006, 0.28, 0.42), (XI - 0.303, yp, 0.74), TENCUIALA))
		piese.append(cub("Buza pisoar", (0.06, 0.38, 0.04), (XI - 0.28, yp, 0.48), ALB))
		piese.append(cub("Pastila pisoar", (0.08, 0.1, 0.02), (XI - 0.22, yp, 0.51), AUR))
		piese.append(os_intre("Teava pisoar", (XI - 0.04, yp, 1.09), (XI - 0.04, yp, 1.45), 0.015, CROM, laturi=6))
		piese.append(cub("Robinet pisoar", (0.06, 0.08, 0.08), (XI - 0.05, yp, 1.45), CROM))
		_cutie_coliziune(col, (0.34, 0.4, 1.1), (XI - 0.17, yp, 0.55))
	piese.append(cub("Despartitor", (0.45, 0.03, 0.85), (XI - 0.23, sum(PISOARE) / 2, 1.05), PETROL))
	_cutie_coliziune(col, (0.45, 0.05, 2.0), (XI - 0.23, sum(PISOARE) / 2, 1.0))
	piese.append(cub("Uscator", (0.12, 0.26, 0.24), (XI - 0.06, -0.55, 1.2), METAL))
	piese.append(cub("Gura uscator", (0.06, 0.06, 0.05), (XI - 0.12, -0.55, 1.06), METAL_INCHIS, rot=(0, 0.4, 0)))
	piese.append(cub("Placuta uscator", (0.004, 0.12, 0.05), (XI - 0.122, -0.55, 1.23), NEGRU))
	piese.append(_text_o_fata("Scris uscator", "PUSH", (XI - 0.125, -0.55, 1.23), 0.03, ALB, rot=(1.5708, 0, -1.5708)))
	cx_c, cy_c = 0.15, -1.32
	piese.append(trunchi("Cos", [((cx_c, cy_c, 0.0), 0.15, 0.15), ((cx_c, cy_c, 0.5), 0.18, 0.18)], METAL_INCHIS, laturi=10, capete=False))
	piese.append(cilindru("Fund cos", 0.15, 0.15, 0.01, (cx_c, cy_c, 0.005), METAL_INCHIS, laturi=10))
	for k in range(9):
		a = k * 2.4
		piese.append(sfera("Prosop mototolit", r.uniform(0.05, 0.07), (cx_c + 0.09 * math.cos(a), cy_c + 0.09 * math.sin(a), 0.47 + 0.04 * (k % 3)),
			ALB, scara=(1.0, 0.8, 0.7), segmente=6, inele=4))
	for k in range(3):
		piese.append(sfera("Prosop jos", 0.05, (cx_c + r.uniform(-0.4, 0.3), cy_c + r.uniform(0.2, 0.45), 0.03), ALB, scara=(1.0, 0.8, 0.6),
			segmente=6, inele=4))
	_cutie_coliziune(col, (0.4, 0.4, 0.6), (cx_c, cy_c, 0.3))
	strange()

	# --- graffiti (cu markerul) pe faianță și pe ușile cabinelor
	gr = [
		# (text, loc, mărime, culoare, rotație)
		("BIG MIKE\nCHEATS", (XI - 0.016, -0.05, 1.75), 0.06, NEGRU, (1.5708, 0, -1.5708)),
		("EDDIE IS A\nHUSTLER", (XI - 0.016, 0.75, 1.68), 0.05, ROSU, (1.5708, 0, -1.5708)),
		("FOR A GOOD TIME\nCALL 555-0142", (-0.55, CAB_Y - 0.028, 1.0), 0.035, NEGRU, (1.5708, 0, 0)),
		("I WAS HERE", (1.0, YI - 0.016, 1.15), 0.06, NEGRU, (1.5708, 0, 0)),
		("NO PISS\nON SEAT", (-1.55, YI - 0.016, 1.3), 0.045, ROSU, (1.5708, 0, 0)),
	]
	for text, loc, m, c, rot in gr:
		piese.append(_text_o_fata("Graffiti", text, loc, m, c, rot=rot))
	strange()

	fixe = ["Gresie", "Perete", "Faianta", "Tavan", "Blat", "Oglinda", "Usa baie", "Pisoar", "Usa cabina", "Stalp cabina", "Perete cabina"]
	desparte_fete(fixe=fixe)
	uneste(piese, "Baie")
	uneste(lumini, "Lumini")
	uneste(col, "Coliziune")
	exporta(os.path.join(cale, "bar_baie.glb"))


def recuzita(cale):
	"""Telefonul de pe blat (culcat, lungimea pe X: liniile merg dinspre 8 Ball Enjoyer spre perete), cele trei linii
	(originea = capătul dinspre perete: în joc se micșorează spre el cât sunt trase), cardul cu care le „taie”,
	bancnota rulată (originea = mijlocul, axa pe X) și punguța. Totul în coordonatele băii (nodul se pune ca baia)."""
	curata()
	tx, ty = TEL
	z = BZ
	uneste([cub("Telefon", (0.155, 0.075, 0.009), (tx, ty, z + 0.0045), NEGRU),
		cub("Rama telefon", (0.157, 0.077, 0.004), (tx, ty, z + 0.002), METAL)], "Telefon", (tx, ty, z))
	uneste([cub("Ecran", (0.145, 0.067, 0.002), (tx, ty, z + 0.009), GEAM)], "Ecran", (tx, ty, z + 0.009))
	for k, dy in enumerate((-0.02, 0.0, 0.02)):
		capat = (tx - 0.06, ty + dy, z + 0.011)
		uneste([cub("Linie", (0.1, 0.006, 0.003), (tx - 0.01, ty + dy, z + 0.0115), ALB)], "Linie%d" % (k + 1), capat)
	# cardul: argintiu („platinum”), lângă telefon, cu banda neagră
	cx, cy = tx + 0.05, ty - 0.085
	uneste([cub("Card", (0.0856, 0.054, 0.002), (cx, cy, z + 0.001), GRI_ALBASTRU),
		cub("Banda card", (0.0856, 0.008, 0.0005), (cx, cy + 0.015, z + 0.00225), NEGRU)], "Card", (cx, cy, z))
	# bancnota rulată: verde, cu marginea mai închisă (unde se termină sulul)
	bx, by = tx + 0.04, ty + 0.075
	uneste([os_intre("Bancnota", (bx - 0.04, by, z + 0.006), (bx + 0.04, by, z + 0.006), 0.006, VERDE, laturi=8),
		os_intre("Margine bancnota", (bx - 0.04, by + 0.004, z + 0.009), (bx + 0.04, by + 0.004, z + 0.009), 0.0012, MASLINIU, laturi=4)],
		"Bancnota", (bx, by, z + 0.006))
	# punguța (aproape goală) lângă telefon
	px, py = tx - 0.03, ty + 0.15
	uneste([cub("Punga", (0.05, 0.04, 0.006), (px, py, z + 0.003), TENCUIALA, rot=(0, 0, 0.4)),
		cub("Fermoar punga", (0.05, 0.004, 0.004), (px - 0.006, py + 0.016, z + 0.006), ROSU, rot=(0, 0, 0.4)),
		sfera("Praf punga", 0.012, (px + 0.008, py - 0.004, z + 0.005), ALB, scara=(1.0, 0.8, 0.3), segmente=6, inele=4)], "Punga", (px, py, z))
	exporta(os.path.join(cale, "recuzita_8ball.glb"))


PRIZATOR = {
	# „8 Ball Enjoyer”: slab, transpirat, sacou mov lucios pe o cămașă neagră descheiată, lanț de aur, ochelari de soare
	# (în baie), părul dat cu gel pe spate, mustăcioară, nasul roșu; adidași albi
	"piele": p("a56850"), "piele_umbra": p("904a40"), "haina": MOV, "haina_umbra": p("553e4d"), "camasa": NEGRU,
	"pantaloni": p("2a3c3d"), "pantofi": ALB, "in_picioare": True, "sezut": 0.86, "lant": AUR,
	"par": p("262d2f"), "stil_par": "spate", "ochelari": "soare", "mustata": p("262d2f"), "tepi": p("48313b"),
	"slab": 0.75, "gros_brat": 0.85, "nas": 1.15, "nas_rosu": True, "inele": AUR, "ceas": AUR,
	# palmele pe marginea blatului, cotul ieșit în afară
	"poza_D": ((-0.28, -0.1, 1.12), (-0.15, -0.3, BZ + 0.015)),
	"poza_S": ((0.28, -0.1, 1.12), (0.15, -0.3, BZ + 0.015)),
}


def prizator(cale):
	casino_oameni.om(cale, "prizator_baie", PRIZATOR, 88)


def toate(cale):
	baie(cale)
	recuzita(cale)
	prizator(cale)


if __name__ == "__main__":
	cale_modele = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")
	if "--" in sys.argv:
		for nume in sys.argv[sys.argv.index("--") + 1:]:
			globals()[nume](cale_modele)
	else:
		toate(cale_modele)
