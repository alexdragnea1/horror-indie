# Construiește modelele low-poly ale casei și le exportă ca .glb în models/.
# Rulare (din folderul proiectului):
#   blender --background --python tools/blender/modele.py
# Schimbi o dimensiune sau o culoare aici, rulezi din nou, iar Godot reimportă modelul.
import os
import sys

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import curata, cub, cilindru, sfera, os_intre, uneste, exporta  # noqa: E402

MODELE = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), "models")

PIELE = (0.86, 0.68, 0.56)
NEGRU = (0.05, 0.04, 0.04)
ALB = (0.95, 0.94, 0.9)


def frigider():
	"""Frigider retro, gol pe dinăuntru, cu ușile separate (se deschid în joc)."""
	curata()
	crem = (0.86, 0.83, 0.72)
	crem_usa = (0.9, 0.87, 0.77)
	crom = (0.62, 0.64, 0.66)
	raft = (0.78, 0.82, 0.85)
	L, A, H, g = 0.76, 0.68, 1.78, 0.05  # lățime, adâncime, înălțime, grosimea peretelui
	jos = 0.08
	corp = [
		cub("Spate", (L, g, H - jos), (0, A / 2 - g / 2, jos + (H - jos) / 2), crem),
		cub("Stanga", (g, A, H - jos), (-L / 2 + g / 2, 0, jos + (H - jos) / 2), crem),
		cub("Dreapta", (g, A, H - jos), (L / 2 - g / 2, 0, jos + (H - jos) / 2), crem),
		cub("Fund", (L, A, g), (0, 0, jos + g / 2), crem),
		cub("Capac", (L, A, g), (0, 0, H - g / 2), crem),
		cub("Despartitor", (L, A, g), (0, 0, 1.24), crem),
		cub("Soclu", (L - 0.06, A - 0.08, jos), (0, 0.04, jos / 2), (0.18, 0.18, 0.2)),
		cub("Raft1", (L - 2 * g, A - 0.1, 0.015), (0, 0.03, 0.5), raft),
		cub("Raft2", (L - 2 * g, A - 0.1, 0.015), (0, 0.03, 0.85), raft),
		# ce e înăuntru: varză, tort de ziua ta, lapte, murături
		sfera("Varza", 0.1, (-0.12, 0.05, 0.23), (0.5, 0.7, 0.32), scara=(1, 1, 0.9)),
		cilindru("Tort", 0.14, 0.14, 0.1, (0.05, 0.05, 0.56), (0.92, 0.55, 0.65), laturi=10),
		cilindru("Glazura", 0.145, 0.14, 0.02, (0.05, 0.05, 0.62), ALB, laturi=10),
		cub("Lapte", (0.08, 0.08, 0.2), (-0.18, 0.08, 0.96), (0.85, 0.9, 1.0)),
		cilindru("Muraturi", 0.06, 0.06, 0.14, (0.12, 0.05, 0.93), (0.35, 0.5, 0.15), laturi=8),
		cilindru("Capac borcan", 0.062, 0.062, 0.025, (0.12, 0.05, 1.01), (0.75, 0.6, 0.2), laturi=8),
	]
	for i in range(6):
		x = 0.05 + (i - 2.5) * 0.04
		corp.append(cub("Lumanare", (0.01, 0.01, 0.05), (x, 0.0, 0.655), (0.9, 0.85, 0.3)))
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
		cub("Hartie", (0.2, 0.004, 0.26), (-0.1, y - 0.027, 0.95), ALB),
		cub("Magnet", (0.035, 0.012, 0.035), (-0.1, y - 0.031, 1.07), (0.8, 0.1, 0.1)),
		cub("Cap omulet", (0.035, 0.004, 0.035), (-0.1, y - 0.03, 0.97), NEGRU),
		cub("Corp omulet", (0.01, 0.004, 0.09), (-0.1, y - 0.03, 0.9), NEGRU),
		cub("Maini omulet", (0.08, 0.004, 0.01), (-0.1, y - 0.03, 0.92), NEGRU),
		cub("Picior", (0.01, 0.004, 0.05), (-0.115, y - 0.03, 0.84), NEGRU, rot=(0, 0.4, 0)),
		cub("Picior", (0.01, 0.004, 0.05), (-0.085, y - 0.03, 0.84), NEGRU, rot=(0, -0.4, 0)),
		cub("Bor palarie", (0.07, 0.004, 0.01), (-0.1, y - 0.03, 0.99), (0.35, 0.1, 0.45)),
		cilindru("Palarie", 0.03, 0.0, 0.06, (-0.1, y - 0.03, 1.02), (0.35, 0.1, 0.45), laturi=4,
			scara=(1, 0.1, 1)),
		cilindru("Magnet galben", 0.022, 0.022, 0.012, (0.16, y - 0.031, 1.1), (0.95, 0.8, 0.1),
			laturi=8, rot=(1.5708, 0, 0)),
		cub("Magnet verde", (0.04, 0.012, 0.03), (0.13, y - 0.031, 0.7), (0.2, 0.6, 0.25)),
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
		cilindru("Rozeta", 0.06, 0.045, 0.03, (0, 0, -0.015), (0.85, 0.85, 0.8), laturi=8),
		cilindru("Fir", 0.006, 0.006, 0.36, (0, 0, -0.2), NEGRU, laturi=4),
		cilindru("Dulie", 0.022, 0.022, 0.06, (0, 0, -0.41), (0.32, 0.26, 0.14), laturi=8),
	]
	uneste(fir, "Fir")
	sticla = [
		cilindru("Gat", 0.016, 0.03, 0.03, (0, 0, -0.455), (1.0, 0.92, 0.7), laturi=8),
		sfera("Glob", 0.045, (0, 0, -0.5), (1.0, 0.92, 0.7), scara=(1, 1, 1.15)),
	]
	uneste(sticla, "Sticla", (0, 0, -0.5))
	exporta(os.path.join(MODELE, "bec.glb"))


def mama():
	"""Mom: rochie mov, mâinile în șolduri, bigudiuri. Capul e separat (originea în gât), ca să te urmărească."""
	curata()
	rochie = (0.42, 0.17, 0.36)
	par = (0.36, 0.12, 0.08)
	piese = [
		cub("Pantof", (0.1, 0.22, 0.08), (0.1, -0.03, 0.04), (0.22, 0.12, 0.08)),
		cub("Pantof", (0.1, 0.22, 0.08), (-0.1, -0.03, 0.04), (0.22, 0.12, 0.08)),
		cilindru("Picior", 0.05, 0.06, 0.46, (0.1, 0, 0.31), PIELE, laturi=6),
		cilindru("Picior", 0.05, 0.06, 0.46, (-0.1, 0, 0.31), PIELE, laturi=6),
		cilindru("Fusta", 0.32, 0.2, 0.55, (0, 0, 0.775), rochie, scara=(1, 0.82, 1)),
		cilindru("Tiv", 0.325, 0.32, 0.04, (0, 0, 0.52), (0.3, 0.1, 0.26), scara=(1, 0.82, 1)),
		cilindru("Curea", 0.21, 0.205, 0.05, (0, 0, 1.06), NEGRU, scara=(1, 0.78, 1)),
		cilindru("Bust", 0.2, 0.23, 0.37, (0, 0, 1.235), rochie, scara=(1, 0.74, 1)),
		cilindru("Guler", 0.13, 0.09, 0.05, (0, 0, 1.43), ALB, scara=(1, 0.85, 1)),
		cilindru("Gat", 0.05, 0.05, 0.1, (0, 0, 1.47), PIELE, laturi=6),
		sfera("Pandantiv", 0.022, (0, -0.17, 1.33), (0.3, 0.9, 0.4), segmente=6, inele=4),
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
		cub("Nas", (0.022, 0.03, 0.04), (0, -0.123, 1.585), (0.8, 0.6, 0.5)),
		cub("Gura", (0.055, 0.01, 0.012), (0, -0.117, 1.535), (0.65, 0.08, 0.12)),
	]
	for s in (1, -1):
		cap += [
			cub("Ochi", (0.042, 0.01, 0.026), (0.042 * s, -0.117, 1.61), ALB),
			cub("Pupila", (0.017, 0.01, 0.02), (0.042 * s, -0.121, 1.608), NEGRU),
			# sprâncene încruntate: coborâte spre nas
			cub("Spranceana", (0.05, 0.012, 0.012), (0.045 * s, -0.12, 1.64), par, rot=(0, 0.35 * s, 0)),
			cub("Cercel", (0.015, 0.015, 0.03), (0.118 * s, -0.01, 1.56), (0.9, 0.75, 0.2)),
		]
	for x in (-0.065, 0.0, 0.065):  # bigudiuri roz
		cap.append(cilindru("Bigudiu", 0.026, 0.026, 0.07, (x, -0.08, 1.7), (0.95, 0.5, 0.68),
			laturi=6, rot=(0, 1.5708, 0)))
	uneste(cap, "Cap", (0, 0, 1.47))
	exporta(os.path.join(MODELE, "mama.glb"))


frigider()
bec()
mama()
