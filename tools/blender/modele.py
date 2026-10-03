# Construiește modelele low-poly ale casei și le exportă ca .glb în models/.
# Rulare (din folderul proiectului):
#   blender --background --python tools/blender/modele.py
# Schimbi o dimensiune sau o culoare aici, rulezi din nou, iar Godot reimportă modelul.
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, uneste, exporta  # noqa: E402

MODELE = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")

PIELE = p("a56850")
NEGRU = p("262d2f")
ALB = p("83b3b0")  # cea mai deschisă culoare din paletă
AUR = p("a18463")


def frigider():
	"""Frigider retro, gol pe dinăuntru, cu ușile separate (se deschid în joc)."""
	curata()
	crem = p("7e8d87")
	crem_usa = p("83b3b0")
	crom = p("778c96")
	raft = p("778c96")
	L, A, H, g = 0.76, 0.68, 1.78, 0.05  # lățime, adâncime, înălțime, grosimea peretelui
	jos = 0.08
	corp = [
		cub("Spate", (L, g, H - jos), (0, A / 2 - g / 2, jos + (H - jos) / 2), crem),
		cub("Stanga", (g, A, H - jos), (-L / 2 + g / 2, 0, jos + (H - jos) / 2), crem),
		cub("Dreapta", (g, A, H - jos), (L / 2 - g / 2, 0, jos + (H - jos) / 2), crem),
		cub("Fund", (L, A, g), (0, 0, jos + g / 2), crem),
		cub("Capac", (L, A, g), (0, 0, H - g / 2), crem),
		cub("Despartitor", (L, A, g), (0, 0, 1.24), crem),
		cub("Soclu", (L - 0.06, A - 0.08, jos), (0, 0.04, jos / 2), NEGRU),
		cub("Raft1", (L - 2 * g, A - 0.1, 0.015), (0, 0.03, 0.5), raft),
		cub("Raft2", (L - 2 * g, A - 0.1, 0.015), (0, 0.03, 0.85), raft),
		# ce e înăuntru: varză, tort de ziua ta, lapte, murături
		sfera("Varza", 0.1, (-0.12, 0.05, 0.23), p("5b6d4e"), scara=(1, 1, 0.9)),
		cilindru("Tort", 0.14, 0.14, 0.1, (0.05, 0.05, 0.56), p("a18463"), laturi=10),
		cilindru("Glazura", 0.145, 0.14, 0.02, (0.05, 0.05, 0.62), p("7b383a"), laturi=10),
		cub("Lapte", (0.08, 0.08, 0.2), (-0.18, 0.08, 0.96), p("778c96")),
		cilindru("Muraturi", 0.06, 0.06, 0.14, (0.12, 0.05, 0.93), p("445d46"), laturi=8),
		cilindru("Capac borcan", 0.062, 0.062, 0.025, (0.12, 0.05, 1.01), p("a18463"), laturi=8),
	]
	for i in range(6):
		x = 0.05 + (i - 2.5) * 0.04
		corp.append(cub("Lumanare", (0.01, 0.01, 0.05), (x, 0.0, 0.655), ALB))
	uneste(corp, "Corp")

	# Ușile au originea în balama (marginea din stânga, partea din spate a ușii).
	balama_x, fata = -L / 2, -A / 2
	y = fata - 0.025
	usa = [
		cub("Usa", (L - 0.01, 0.05, 1.12), (0, y, 0.66), crem_usa),
		cub("Maner", (0.03, 0.03, 0.4), (L / 2 - 0.07, y - 0.065, 0.95), crom),
		cub("Prindere", (0.02, 0.04, 0.02), (L / 2 - 0.07, y - 0.04, 1.13), crom),
		cub("Prindere", (0.02, 0.04, 0.02), (L / 2 - 0.07, y - 0.04, 0.77), crom),
		# desenul de pe frigider: un omuleț cu pălărie de vrăjitoare
		cub("Hartie", (0.2, 0.004, 0.26), (-0.1, y - 0.027, 0.95), p("a18463")),
		cub("Magnet", (0.035, 0.012, 0.035), (-0.1, y - 0.031, 1.07), p("7b383a")),
		cub("Cap omulet", (0.035, 0.004, 0.035), (-0.1, y - 0.03, 0.97), NEGRU),
		cub("Corp omulet", (0.01, 0.004, 0.09), (-0.1, y - 0.03, 0.9), NEGRU),
		cub("Maini omulet", (0.08, 0.004, 0.01), (-0.1, y - 0.03, 0.92), NEGRU),
		cub("Picior", (0.01, 0.004, 0.05), (-0.115, y - 0.03, 0.84), NEGRU, rot=(0, 0.4, 0)),
		cub("Picior", (0.01, 0.004, 0.05), (-0.085, y - 0.03, 0.84), NEGRU, rot=(0, -0.4, 0)),
		cub("Bor palarie", (0.07, 0.004, 0.01), (-0.1, y - 0.03, 0.99), p("655269")),
		cilindru("Palarie", 0.03, 0.0, 0.06, (-0.1, y - 0.03, 1.02), p("655269"), laturi=4,
			scara=(1, 0.1, 1)),
		cilindru("Magnet galben", 0.022, 0.022, 0.012, (0.16, y - 0.031, 1.1), p("904a40"),
			laturi=8, rot=(1.5708, 0, 0)),
		cub("Magnet verde", (0.04, 0.012, 0.03), (0.13, y - 0.031, 0.7), p("5b6d4e")),
	]
	uneste(usa, "UsaFrigider", (balama_x, fata, 0))
	congelator = [
		cub("Usa", (L - 0.01, 0.05, 0.5), (0, y, 1.51), crem_usa),
		cub("Maner", (0.03, 0.03, 0.18), (L / 2 - 0.07, y - 0.065, 1.38), crom),
		cub("Prindere", (0.02, 0.04, 0.02), (L / 2 - 0.07, y - 0.04, 1.3), crom),
		cub("Prindere", (0.02, 0.04, 0.02), (L / 2 - 0.07, y - 0.04, 1.46), crom),
	]
	uneste(congelator, "UsaCongelator", (balama_x, fata, 0))
	exporta(os.path.join(MODELE, "frigider.glb"))


def bec():
	"""Bec atârnat de fir. Originea = tavanul. Sticla e separată, ca să lumineze în joc."""
	curata()
	fir = [
		cilindru("Rozeta", 0.06, 0.045, 0.03, (0, 0, -0.015), p("7e8d87"), laturi=8),
		cilindru("Fir", 0.006, 0.006, 0.36, (0, 0, -0.2), NEGRU, laturi=4),
		cilindru("Dulie", 0.022, 0.022, 0.06, (0, 0, -0.41), p("7a7b59"), laturi=8),
	]
	uneste(fir, "Fir")
	sticla = [
		cilindru("Gat", 0.016, 0.03, 0.03, (0, 0, -0.455), p("a18463"), laturi=8),
		sfera("Glob", 0.045, (0, 0, -0.5), p("a18463"), scara=(1, 1, 1.15)),
	]
	uneste(sticla, "Sticla", (0, 0, -0.5))
	exporta(os.path.join(MODELE, "bec.glb"))


def mama():
	"""Mom: rochie mov, mâinile în șolduri, bigudiuri. Capul e separat (originea în gât), ca să te urmărească."""
	curata()
	rochie = p("655269")
	par = p("5e363e")
	piese = [
		cub("Pantof", (0.1, 0.22, 0.08), (0.1, -0.03, 0.04), p("48313b")),
		cub("Pantof", (0.1, 0.22, 0.08), (-0.1, -0.03, 0.04), p("48313b")),
		cilindru("Picior", 0.05, 0.06, 0.46, (0.1, 0, 0.31), PIELE, laturi=6),
		cilindru("Picior", 0.05, 0.06, 0.46, (-0.1, 0, 0.31), PIELE, laturi=6),
		cilindru("Fusta", 0.32, 0.2, 0.55, (0, 0, 0.775), rochie, scara=(1, 0.82, 1)),
		cilindru("Tiv", 0.325, 0.32, 0.04, (0, 0, 0.52), p("553e4d"), scara=(1, 0.82, 1)),
		cilindru("Curea", 0.21, 0.205, 0.05, (0, 0, 1.06), NEGRU, scara=(1, 0.78, 1)),
		cilindru("Bust", 0.2, 0.23, 0.37, (0, 0, 1.235), rochie, scara=(1, 0.74, 1)),
		cilindru("Guler", 0.13, 0.09, 0.05, (0, 0, 1.43), p("778c96"), scara=(1, 0.85, 1)),
		cilindru("Gat", 0.05, 0.05, 0.1, (0, 0, 1.47), PIELE, laturi=6),
		sfera("Pandantiv", 0.022, (0, -0.17, 1.33), p("438b88"), segmente=6, inele=4),
	]
	for s in (1, -1):  # brațele, în oglindă: mâinile în șolduri
		umar, cot, mana = (0.25 * s, 0, 1.37), (0.43 * s, 0.03, 1.15), (0.23 * s, 0.0, 1.04)
		piese += [
			sfera("Umar", 0.075, umar, rochie, segmente=6, inele=4),
			os_intre("Brat", umar, cot, 0.06, rochie),
			sfera("Cot", 0.05, cot, PIELE, segmente=6, inele=4),
			os_intre("Antebrat", cot, mana, 0.045, PIELE),
			sfera("Mana", 0.05, mana, PIELE, segmente=6, inele=4, scara=(0.8, 1, 1.2)),
		]
	uneste(piese, "Corp")

	cap = [
		sfera("Fata", 0.115, (0, 0, 1.6), PIELE, scara=(1, 1.05, 1.2)),
		sfera("Calota", 0.13, (0, 0.01, 1.67), par, scara=(1.02, 1.05, 0.6)),
		sfera("Ceafa", 0.115, (0, 0.06, 1.6), par, scara=(1.06, 0.8, 1.1)),
		sfera("Coc", 0.07, (0, 0.04, 1.76), par),
		cub("Nas", (0.022, 0.03, 0.04), (0, -0.123, 1.585), p("904a40")),
		cub("Gura", (0.055, 0.01, 0.012), (0, -0.117, 1.535), p("7b383a")),
	]
	for s in (1, -1):
		cap += [
			cub("Ochi", (0.042, 0.01, 0.026), (0.042 * s, -0.117, 1.61), ALB),
			cub("Pupila", (0.017, 0.01, 0.02), (0.042 * s, -0.121, 1.608), NEGRU),
			# sprâncene încruntate: coborâte spre nas
			cub("Spranceana", (0.05, 0.012, 0.012), (0.045 * s, -0.12, 1.64), par, rot=(0, 0.35 * s, 0)),
			cub("Cercel", (0.015, 0.015, 0.03), (0.118 * s, -0.01, 1.56), p("a18463")),
		]
	for x in (-0.065, 0.0, 0.065):  # bigudiuri roșii
		cap.append(cilindru("Bigudiu", 0.026, 0.026, 0.07, (x, -0.08, 1.7), p("7b383a"),
			laturi=6, rot=(0, 1.5708, 0)))
	uneste(cap, "Cap", (0, 0, 1.47))
	exporta(os.path.join(MODELE, "mama.glb"))


def ceas():
	"""Ceas de perete. Limbile sunt separate, cu originea în centru, ca să se învârtă în joc
	(toate arată în sus, spre ora 12; ora o pune scriptul ceas.gd)."""
	import math
	curata()
	fata, rama = p("a18463"), p("48313b")
	piese = [
		cilindru("Rama", 0.17, 0.17, 0.05, (0, 0.0, 0), rama, laturi=16, rot=(1.5708, 0, 0)),
		cilindru("Cadran", 0.15, 0.15, 0.01, (0, -0.026, 0), fata, laturi=16, rot=(1.5708, 0, 0)),
		cilindru("Ax", 0.012, 0.012, 0.03, (0, -0.04, 0), NEGRU, laturi=6, rot=(1.5708, 0, 0)),
	]
	for i in range(12):
		a = i * math.pi / 6
		lung = 0.03 if i % 3 == 0 else 0.015
		r = 0.135 - lung / 2
		piese.append(cub("Gradatie", (0.008, 0.004, lung), (r * math.sin(a), -0.032, r * math.cos(a)), NEGRU,
			rot=(0, a, 0)))
	uneste(piese, "Ceas")
	for nume, lung, lat, culoare, y in (("Orar", 0.075, 0.014, NEGRU, -0.034), ("Minutar", 0.115, 0.009, NEGRU, -0.038),
			("Secundar", 0.125, 0.004, p("7b383a"), -0.042)):
		uneste([cub(nume, (lat, 0.003, lung + 0.02), (0, y, lung / 2 - 0.01), culoare)], nume)
	exporta(os.path.join(MODELE, "ceas.glb"))


def usa_intrare():
	"""Ușa de la intrarea casei: roșie, cu geam mic sus, yală și vizor. Balamaua în origine,
	ușa se întinde pe +X. Fața (-Y) e spre hol; mânerul e pe ambele părți. Se folosește cu toc_usa.glb."""
	curata()
	rosu, rosu_inchis, geam = p("7b383a"), p("5e363e"), p("2a3c3d")
	piese = [cub("Usa", (0.9, 0.05, 2.05), (0.45, 0, 1.025), rosu)]
	for s in (-1, 1):  # aceleași detalii pe ambele fețe
		y = 0.028 * s
		piese += [
			cub("Panou", (0.3, 0.012, 0.75), (0.25, y, 0.55), rosu_inchis),
			cub("Panou", (0.3, 0.012, 0.75), (0.65, y, 0.55), rosu_inchis),
			cub("Rama geam", (0.62, 0.014, 0.36), (0.45, y, 1.6), rosu_inchis),
			sfera("Clanta", 0.032, (0.8, 0.05 * s, 1.0), AUR, segmente=6, inele=4),
			cilindru("Yala", 0.022, 0.022, 0.02, (0.8, 0.03 * s, 1.18), AUR, laturi=6, rot=(1.5708, 0, 0)),
		]
		for x in (0.27, 0.45, 0.63):  # trei ochiuri de geam închis la culoare
			piese.append(cub("Geam", (0.15, 0.016, 0.28), (x, y, 1.6), geam))
	piese += [
		cub("Fanta posta", (0.26, 0.016, 0.05), (0.45, -0.03, 1.08), AUR),
		cub("Fanta", (0.22, 0.02, 0.016), (0.45, -0.031, 1.08), NEGRU),
		cilindru("Vizor", 0.012, 0.012, 0.06, (0.45, 0, 1.38), AUR, laturi=6, rot=(1.5708, 0, 0)),
	]
	uneste(piese, "UsaIntrare")
	exporta(os.path.join(MODELE, "usa_intrare.glb"))


frigider()
bec()
mama()
ceas()
usa_intrare()

import dormitor  # noqa: E402
dormitor.toate(MODELE)

import afara  # noqa: E402
afara.toate(MODELE)

import bucatarie  # noqa: E402
bucatarie.toate(MODELE)
