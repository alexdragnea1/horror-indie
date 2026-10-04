# Dealul din dreapta (platoul): bețivul de pe buștean, boombox-ul lui și sticlele de bere.
# Le apelează modele.py, dar merge și singur (mai repede, doar astea):
#   blender --background --factory-startup --python tools/blender/deal.py
# Axe Blender: Z în sus, fața modelului spre -Y (în Godot devine +Z). Originea = la sol.
import math
import os
import random
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, inel, uneste, exporta, trunchi  # noqa: E402

NEGRU = p("262d2f")
ALB = p("83b3b0")
STICLA = p("904a40")
STICLA_UMBRA = p("7b383a")
ETICHETA = p("a18463")
DOP = p("778c96")

PIELE = p("5e363e")
PIELE_UMBRA = p("48313b")
PALMA = p("7b383a")
BUZE = p("553e4d")
HANORAC = p("30716f")
HANORAC_UMBRA = p("295555")
PANTALONI = p("2a3c3d")
CACIULA = p("904a40")
CACIULA_MANSETA = p("7b383a")
AUR = p("a18463")

## Înălțimea șezutului (fața de sus a bușteanului din scenă).
SEZUT = 0.5


def _sticla(x, y, z, nume="Sticla", plina=True):
	"""Sticlă de bere de 0,5 l (bruna, cu etichetă), în picioare, cu baza în (x, y, z)."""
	piese = [
		trunchi(nume, [((x, y, z), 0.0, 0.0), ((x, y, z + 0.002), 0.03, 0.03), ((x, y, z + 0.15), 0.032, 0.032),
			((x, y, z + 0.175), 0.027, 0.027), ((x, y, z + 0.2), 0.013, 0.013), ((x, y, z + 0.238), 0.012, 0.012),
			((x, y, z + 0.24), 0.0, 0.0)], STICLA, laturi=8),
		# eticheta: un inel puțin mai gros decât sticla, cu o dungă roșie
		trunchi("Eticheta", [((x, y, z + 0.055), 0.0335, 0.0335), ((x, y, z + 0.12), 0.0335, 0.0335)], ETICHETA, laturi=8),
		trunchi("Dunga", [((x, y, z + 0.08), 0.0345, 0.0345), ((x, y, z + 0.093), 0.0345, 0.0345)], STICLA_UMBRA, laturi=8),
		trunchi("Gat eticheta", [((x, y, z + 0.205), 0.0145, 0.0145), ((x, y, z + 0.222), 0.0145, 0.0145)], ETICHETA, laturi=8),
	]
	if plina:
		piese.append(cilindru("Dop", 0.014, 0.014, 0.012, (x, y, z + 0.245), DOP, laturi=8))
	return piese


def bere(cale):
	"""Sticla de bere, plină (cu dop) și goală (fără)."""
	for nume, plina in (("bere", True), ("bere_goala", False)):
		curata()
		uneste(_sticla(0, 0, 0, plina=plina), "Bere")
		exporta(os.path.join(cale, nume + ".glb"))


def _brat(piese, umar, cot, incheietura, culoare, nume):
	mijl1 = tuple((a + b) / 2 for a, b in zip(umar, cot))
	mijl2 = tuple((a + b) / 2 for a, b in zip(cot, incheietura))
	# mâneca de hanorac: largă, strânsă în manșetă la încheietură
	piese.append(trunchi(nume, [(umar, 0.075, 0.075), (mijl1, 0.072, 0.068), (cot, 0.068, 0.064), (mijl2, 0.064, 0.06),
		(incheietura, 0.05, 0.048)], culoare, laturi=8, ref=(0, 0, 1)))
	piese.append(sfera("Umar", 0.08, umar, culoare, segmente=8, inele=5))
	d = tuple(b - a for a, b in zip(cot, incheietura))
	l = math.sqrt(sum(v * v for v in d))
	manseta = tuple(i - v / l * 0.035 for i, v in zip(incheietura, d))
	piese.append(os_intre("Manseta", manseta, incheietura, 0.05, HANORAC_UMBRA, laturi=8))


def betiv(cale):
	"""Bețivul de pe dealul din dreapta: tânăr, negru la piele, mort de beat, tolănit pe buștean cu spatele lăsat,
	picioarele depărtate, o bere în mâna dreaptă sprijinită pe genunchi, stânga atârnând peste celălalt genunchi.
	Hanorac larg cu glugă, pantaloni de trening cu dungă, adidași albi, căciulă, lanț de aur.
	Originea = solul de sub el (șezutul e la SEZUT), fața spre -Y. Piese separate: `Cap` (originea în gât, ca
	să dea din cap pe muzică și să te urmărească), `BratBere` (originea în umăr: îți întinde berea), iar sticla
	din mână e `SticlaMana`, copil al brațului (dispare cât bei tu). Restul corpului e tot în bucăți, pentru
	ragdoll (când îl împuști): `Corp` (trunchiul), `BratStang`, `CoapsaS/D` cu `GambaS/D` în ele."""
	curata()
	r = random.Random(13)
	piese = []
	z0 = SEZUT

	# --- bazinul și trunchiul: lăsat pe spate, burta puțin înainte
	piese.append(sfera("Bazin", 0.17, (0, 0.03, z0 + 0.08), PANTALONI, scara=(1.2, 1.0, 0.6), segmente=10, inele=6))
	piese.append(trunchi("Trunchi", [
		((0, 0.03, z0 + 0.1), 0.19, 0.14),
		((0, 0.04, z0 + 0.22), 0.205, 0.155),
		((0, 0.07, z0 + 0.34), 0.215, 0.152),
		((0, 0.1, z0 + 0.45), 0.225, 0.142),
		((0, 0.125, z0 + 0.52), 0.185, 0.12),
		((0, 0.14, z0 + 0.56), 0.08, 0.07),
	], HANORAC, laturi=10))
	piese += [
		# tivul lat al hanoracului, peste șolduri
		trunchi("Tiv", [((0, 0.03, z0 + 0.06), 0.198, 0.148), ((0, 0.03, z0 + 0.11), 0.198, 0.148)], HANORAC_UMBRA, laturi=10),
		# buzunarul cangur, în față
		trunchi("Buzunar", [((-0.1, -0.095, z0 + 0.2), 0.03, 0.006), ((0.1, -0.095, z0 + 0.2), 0.03, 0.006)],
			HANORAC_UMBRA, laturi=4, ref=(0, 0, 1)),
		# gluga strânsă la ceafă și șnururile
		sfera("Gluga", 0.13, (0, 0.21, z0 + 0.54), HANORAC, scara=(1.3, 0.6, 0.65), segmente=8, inele=5),
		sfera("Gluga", 0.1, (0, 0.24, z0 + 0.5), HANORAC_UMBRA, scara=(1.1, 0.5, 0.6), segmente=8, inele=5),
		os_intre("Snur", (-0.035, 0.03, z0 + 0.535), (-0.045, -0.06, z0 + 0.4), 0.007, ALB, laturi=4),
		os_intre("Snur", (0.035, 0.03, z0 + 0.535), (0.05, -0.055, z0 + 0.38), 0.007, ALB, laturi=4),
	]
	# lanțul de aur: zale pe o curbă care atârnă pe piept, cu un medalion
	for k in range(13):
		u = math.pi * (0.1 + 0.8 * k / 12)
		x = math.cos(u) * 0.1
		cade = math.sin(u)
		piese.append(cub("Za", (0.016, 0.012, 0.012), (x, 0.06 - cade * 0.1, z0 + 0.55 - cade * 0.09), AUR,
			rot=(0.6, 0, u)))
	piese.append(cub("Medalion", (0.034, 0.012, 0.04), (0, -0.05, z0 + 0.44), AUR, rot=(0.35, 0, 0)))

	uneste(piese, "Corp")

	# --- picioarele: depărtate, coapsele pe buștean, gambele în jos; trening cu dungă albă pe lateral.
	# Fiecare picior = `Coapsa*` (originea în șold) + `Gamba*` (originea în genunchi, copil al coapsei, cu adidasul):
	# când moare, bucățile devin un ragdoll (Ragdoll în Godot), legate în punctele astea.
	for s, latura in ((-1, "D"), (1, "S")):
		sold, genunchi, glezna = (0.1 * s, 0.02, z0 + 0.06), (0.24 * s, -0.4, z0 + 0.06), (0.29 * s, -0.5, 0.11)
		coapsa = [
			trunchi("Coapsa", [(sold, 0.09, 0.09), (genunchi, 0.075, 0.072)], PANTALONI, laturi=8, ref=(0, 0, 1)),
			# dunga: pe partea din afară, la 1 cm peste material
			os_intre("Dunga", (sold[0] + 0.1 * s, sold[1] - 0.05, sold[2]), (genunchi[0] + 0.083 * s, genunchi[1], genunchi[2]),
				0.012, ALB, laturi=4),
		]
		gamba = [
			sfera("Genunchi", 0.078, genunchi, PANTALONI, segmente=8, inele=5),
			trunchi("Gamba", [(genunchi, 0.07, 0.07), (glezna, 0.058, 0.055)], PANTALONI, laturi=8, ref=(0, 0, 1)),
			os_intre("Dunga", (genunchi[0] + 0.078 * s, genunchi[1], genunchi[2]), (glezna[0] + 0.066 * s, glezna[1], glezna[2] + 0.04),
				0.012, ALB, laturi=4),
		]
		# adidașii: albi, groși, cu talpa închisă și șireturi
		xb = glezna[0]
		gamba.append(trunchi("Adidas", [
			((xb, -0.46, 0.06), 0.0, 0.0),
			((xb, -0.47, 0.06), 0.055, 0.05),
			((xb + 0.01 * s, -0.55, 0.055), 0.06, 0.048),
			((xb + 0.015 * s, -0.63, 0.045), 0.052, 0.035),
			((xb + 0.02 * s, -0.68, 0.035), 0.0, 0.0),
		], ALB, laturi=8, faza=0.39))
		gamba.append(cub("Talpa", (0.115, 0.24, 0.02), (xb + 0.012 * s, -0.57, 0.01), NEGRU))
		gamba.append(cub("Siret", (0.05, 0.012, 0.006), (xb + 0.008 * s, -0.56, 0.104), NEGRU, rot=(0.5, 0, 0)))
		gamba.append(cub("Siret", (0.045, 0.012, 0.006), (xb + 0.011 * s, -0.6, 0.09), NEGRU, rot=(0.5, 0, 0)))
		gamba.append(inel("Gura adidas", 0.048, 0.012, (xb, -0.48, 0.105), PANTALONI, segmente=8))
		ob_coapsa = uneste(coapsa, "Coapsa" + latura, sold)
		ob_gamba = uneste(gamba, "Gamba" + latura, genunchi)
		ob_gamba.parent = ob_coapsa
		ob_gamba.matrix_parent_inverse = ob_coapsa.matrix_world.inverted()

	# --- brațul stâng (separat, originea în umăr): atârnă moale peste genunchiul stâng, mâna căzută
	umar_s, cot_s, inch_s = (0.215, 0.13, z0 + 0.48), (0.31, 0.0, z0 + 0.25), (0.27, -0.3, z0 + 0.15)
	brat_s = []
	_brat(brat_s, umar_s, cot_s, inch_s, HANORAC, "Brat")
	brat_s.append(sfera("Mana", 0.045, (0.265, -0.355, z0 + 0.12), PIELE, scara=(0.8, 1.1, 0.55), segmente=8, inele=5))
	for k in range(4):  # degetele atârnă peste genunchi
		brat_s.append(os_intre("Deget", (0.245 + k * 0.014, -0.39, z0 + 0.11), (0.243 + k * 0.015, -0.41, z0 + 0.07), 0.009, PIELE, laturi=4))
	brat_s.append(sfera("Palma", 0.03, (0.265, -0.36, z0 + 0.1), PALMA, scara=(0.8, 1.0, 0.4), segmente=6, inele=4))
	uneste(brat_s, "BratStang", umar_s)

	# --- brațul cu berea (separat, originea în umăr): mâna pe genunchiul drept, ține sticla dreaptă
	umar_d, cot_d, inch_d = (-0.215, 0.13, z0 + 0.48), (-0.3, -0.02, z0 + 0.25), (-0.26, -0.3, z0 + 0.2)
	brat = []
	_brat(brat, umar_d, cot_d, inch_d, HANORAC, "BratBere")
	mana = (-0.255, -0.35, z0 + 0.21)
	brat.append(sfera("Pumn", 0.047, mana, PIELE, scara=(0.9, 0.85, 1.0), segmente=8, inele=5))
	for k in range(4):  # degetele strânse în jurul sticlei
		brat.append(cub("Deget", (0.018, 0.016, 0.018), (mana[0] + 0.03, mana[1] - 0.025, mana[2] - 0.03 + k * 0.02), PIELE_UMBRA))
	brat.append(os_intre("Deget mare", (mana[0] - 0.03, mana[1] - 0.01, mana[2] + 0.02), (mana[0] - 0.01, mana[1] - 0.045, mana[2] + 0.035),
		0.012, PIELE, laturi=5))
	ob_brat = uneste(brat, "BratBere", umar_d)
	sticla = uneste(_sticla(mana[0], mana[1] - 0.005, mana[2] - 0.1), "SticlaMana")
	sticla.parent = ob_brat
	sticla.matrix_parent_inverse = ob_brat.matrix_world.inverted()

	# --- capul (separat, originea în gât): rotund, lăsat pe spate, ochii pe jumătate închiși
	gat = (0, 0.14, z0 + 0.56)
	cap = [os_intre("Gat", (0, 0.14, z0 + 0.53), (0, 0.11, z0 + 0.63), 0.052, PIELE, laturi=8)]
	fata = [  # (z, centru y, rx, ry)
		(0.605, 0.04, 0.0, 0.0), (0.615, 0.04, 0.045, 0.045), (0.64, 0.05, 0.068, 0.075), (0.68, 0.068, 0.082, 0.094),
		(0.73, 0.078, 0.088, 0.1), (0.78, 0.083, 0.087, 0.098), (0.82, 0.088, 0.076, 0.088), (0.85, 0.093, 0.05, 0.06),
		(0.865, 0.098, 0.0, 0.0),
	]
	cap.append(trunchi("Fata", [((0, y, z0 + z), rx, ry) for z, y, rx, ry in fata], PIELE, laturi=12))
	# căciula trasă pe frunte, cu manșetă răsfrântă
	caciula = [(0.765, 0.084, 0.093, 0.104), (0.81, 0.088, 0.088, 0.1), (0.855, 0.094, 0.07, 0.08), (0.89, 0.098, 0.04, 0.048),
		(0.902, 0.1, 0.0, 0.0)]
	cap.append(trunchi("Caciula", [((0, y, z0 + z), rx, ry) for z, y, rx, ry in caciula], CACIULA, laturi=12))
	cap.append(trunchi("Manseta caciula", [((0, 0.083, z0 + 0.762), 0.1, 0.111), ((0, 0.085, z0 + 0.795), 0.1, 0.111)],
		CACIULA_MANSETA, laturi=12))
	cap.append(cub("Eticheta caciula", (0.03, 0.006, 0.016), (0.045, -0.02, z0 + 0.778), ALB, rot=(0, 0, 0.4)))
	for s in (-1, 1):  # urechile
		cap.append(sfera("Ureche", 0.026, (0.089 * s, 0.09, z0 + 0.73), PIELE, scara=(0.45, 0.8, 1.0), segmente=6, inele=4))
	# nasul lat și nările
	cap.append(trunchi("Nas", [((0, -0.012, z0 + 0.755), 0.012, 0.01), ((0, -0.034, z0 + 0.722), 0.022, 0.017),
		((0, -0.04, z0 + 0.702), 0.03, 0.02), ((0, -0.026, z0 + 0.69), 0.0, 0.0)], PIELE, laturi=6))
	cap += [
		cub("Nara", (0.012, 0.012, 0.006), (0.014, -0.04, z0 + 0.692), PIELE_UMBRA),
		cub("Nara", (0.012, 0.012, 0.006), (-0.014, -0.04, z0 + 0.692), PIELE_UMBRA),
		# gura întredeschisă, buzele groase
		cub("Buza sus", (0.05, 0.014, 0.012), (0, -0.031, z0 + 0.672), BUZE),
		cub("Gura", (0.038, 0.01, 0.008), (0, -0.03, z0 + 0.662), NEGRU),
		cub("Buza jos", (0.048, 0.016, 0.013), (0, -0.029, z0 + 0.651), BUZE),
		# barbă scurtă pe bărbie și mustață rară
		cub("Barbie", (0.032, 0.012, 0.022), (0, -0.026, z0 + 0.63), NEGRU),
		cub("Mustata", (0.05, 0.008, 0.006), (0, -0.036, z0 + 0.683), NEGRU),
	]
	for s in (-1, 1):
		x = 0.036 * s
		cap += [
			# ochii: albul înroșit, pupila căzută în jos, pleoapa grea până la jumătate
			cub("Ochi", (0.028, 0.006, 0.011), (x, -0.02, z0 + 0.745), ALB),
			cub("Pupila", (0.011, 0.006, 0.008), (x - 0.004 * s, -0.03, z0 + 0.742), NEGRU),
			cub("Vina", (0.008, 0.006, 0.003), (x + 0.009 * s, -0.03, z0 + 0.744), STICLA),
			cub("Pleoapa", (0.034, 0.016, 0.01), (x, -0.022, z0 + 0.753), PIELE_UMBRA, rot=(0.25, 0, 0)),
			cub("Cearcan", (0.03, 0.01, 0.006), (x, -0.017, z0 + 0.733), PIELE_UMBRA),
			cub("Spranceana", (0.038, 0.012, 0.009), (x, -0.024, z0 + 0.768), NEGRU, rot=(0, 0.15 * s, -0.12 * s)),
		]
	uneste(cap, "Cap", gat)
	exporta(os.path.join(cale, "betiv.glb"))


def boombox(cale):
	"""Boombox anii '90: carcasă gri, două difuzoare mari (`DifuzorS`, `DifuzorD`, separate, originea în centru:
	pulsează pe muzică), casetofon la mijloc, afișaj (`Afisaj`, strălucește), mâner, antenă scoasă.
	Originea = jos, la mijloc, fața spre -Y."""
	curata()
	carcasa, fata, inchis = p("6f6d7f"), p("778c96"), p("2a3c3d")
	piese = [
		cub("Carcasa", (0.52, 0.14, 0.26), (0, 0, 0.13), carcasa),
		cub("Panou", (0.5, 0.012, 0.24), (0, -0.076, 0.13), fata),
		# casetofonul și caseta din el
		cub("Caseta usa", (0.13, 0.01, 0.08), (0, -0.087, 0.11), inchis),
		cub("Caseta", (0.09, 0.006, 0.045), (0, -0.0985, 0.11), p("a18463")),
		cub("Bobina", (0.016, 0.006, 0.016), (-0.02, -0.108, 0.11), NEGRU),
		cub("Bobina", (0.016, 0.006, 0.016), (0.02, -0.108, 0.11), NEGRU),
		# butoanele de sus și cele de volum
	]
	for k in range(6):
		piese.append(cub("Buton", (0.028, 0.03, 0.016), (-0.085 + k * 0.034, -0.02, 0.268), NEGRU if k != 1 else p("7b383a")))
	for x in (-0.05, 0.05):
		piese.append(cilindru("Volum", 0.012, 0.012, 0.014, (x, -0.089, 0.205), NEGRU, laturi=6, rot=(1.5708, 0, 0)))
	# mânerul și antena
	piese += [
		os_intre("Maner", (-0.2, 0.0, 0.26), (-0.17, 0.0, 0.34), 0.012, NEGRU, laturi=5),
		os_intre("Maner", (0.2, 0.0, 0.26), (0.17, 0.0, 0.34), 0.012, NEGRU, laturi=5),
		os_intre("Maner", (-0.17, 0.0, 0.34), (0.17, 0.0, 0.34), 0.014, NEGRU, laturi=5),
		os_intre("Antena", (0.23, 0.04, 0.26), (0.05, 0.12, 0.72), 0.004, fata, laturi=4),
		sfera("Varf antena", 0.008, (0.05, 0.12, 0.72), fata, segmente=5, inele=3),
		# un abțibild jupuit pe carcasă
		cub("Abtibild", (0.06, 0.004, 0.035), (0.21, -0.0835, 0.225), p("438b88"), rot=(0, 0.1, 0)),
	]
	uneste(piese, "Boombox")
	uneste([cub("Afisaj", (0.11, 0.006, 0.03), (0, -0.0855, 0.2), p("a56850"))], "Afisaj")
	for nume, x in (("DifuzorS", -0.17), ("DifuzorD", 0.17)):
		uneste([
			cilindru("Grila", 0.095, 0.095, 0.014, (x, -0.089, 0.13), NEGRU, laturi=12, rot=(1.5708, 0, 0)),
			cilindru("Con", 0.075, 0.03, 0.02, (x, -0.1, 0.13), p("5e5356"), laturi=12, rot=(1.5708, 0, 0)),
			sfera("Capac", 0.025, (x, -0.105, 0.13), NEGRU, scara=(1, 0.5, 1), segmente=8, inele=4),
		], nume, (x, -0.089, 0.13))
	exporta(os.path.join(cale, "boombox.glb"))


def toate(cale):
	bere(cale)
	betiv(cale)
	boombox(cale)


if __name__ == "__main__":
	toate(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models"))
