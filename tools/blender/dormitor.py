# Modelele din camera jucătorului (tema: vrăjitoare). Le apelează modele.py.
# Axe Blender: Z în sus, fața modelului spre -Y (în Godot devine +Z). Originea = podeaua.
import math
import os
import random

from mathutils import Vector

from unelte import p, curata, cub, cilindru, sfera, sfera_deschisa, inel, linie, text, os_intre, uneste, exporta

LEMN = p("5e363e")
LEMN_INCHIS = p("48313b")
NEGRU = p("262d2f")
AUR = p("a18463")
OS = p("83b3b0")  # cea mai deschisă culoare: os, sclipiri


def palarie(hx, hy, hz):
	"""Pălăria de vrăjitoare, așezată pe o suprafață la înălțimea hz: bor cu marginea răsucită,
	con din trei bucăți cu vârful îndoit (spre +X), bandă și cataramă."""
	negru, banda = NEGRU, p("655269")
	piese = [
		cilindru("Bor", 0.24, 0.24, 0.012, (hx, hy, hz + 0.006), negru, laturi=12),
		inel("Margine bor", 0.235, 0.012, (hx, hy, hz + 0.012), negru, segmente=12),
	]
	# conul: puncte pe axă și razele în ele; fiecare bucată e un trunchi de con între două puncte
	puncte = [(hx, hy, hz + 0.01), (hx + 0.005, hy, hz + 0.15), (hx + 0.05, hy, hz + 0.25), (hx + 0.13, hy, hz + 0.29)]
	raze = [0.105, 0.07, 0.035, 0.0]
	for i in range(3):
		a, b = Vector(puncte[i]), Vector(puncte[i + 1])
		d = b - a
		rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_euler()
		piese.append(cilindru("Con", raze[i], raze[i + 1], d.length, (a + b) / 2, negru, laturi=8, rot=rot))
		if 0 < i:  # încheietura dintre bucăți, ca să nu se vadă găuri la îndoitură
			piese.append(sfera("Incheietura", raze[i], puncte[i], negru, segmente=8, inele=4))
	piese += [
		cilindru("Banda", 0.11, 0.1, 0.035, (hx, hy, hz + 0.03), banda, laturi=8),
		cub("Catarama", (0.04, 0.008, 0.032), (hx, hy - 0.104, hz + 0.03), AUR),
		cub("Gaura catarama", (0.02, 0.01, 0.014), (hx, hy - 0.106, hz + 0.03), negru),
	]
	return piese


def pat(cale):
	"""Pat gotic cu țepi la tăblie, pătură cu stele și pălăria de vrăjitoare aruncată pe el.
	Lung pe X (tăblia spre +X), lat pe Y."""
	curata()
	r = random.Random(7)
	piese = []
	for x in (-0.95, 0.95):
		for y in (-0.5, 0.5):
			piese.append(cub("Picior", (0.08, 0.08, 0.3), (x, y, 0.15), LEMN))
	piese += [
		cub("Rama", (2.0, 1.1, 0.12), (0, 0, 0.3), LEMN),
		cub("Patura", (1.9, 1.04, 0.18), (0, 0, 0.45), p("553e4d")),
		cub("Perna", (0.35, 0.7, 0.12), (0.72, 0, 0.6), p("7e8d87"), rot=(0, -0.15, 0)),
		cub("Tablie", (0.08, 1.1, 1.0), (0.98, 0, 0.6), LEMN),
		cub("Tablie jos", (0.08, 1.1, 0.55), (-0.98, 0, 0.38), LEMN),
	]
	for y, h in ((-0.5, 0.22), (0.0, 0.34), (0.5, 0.22)):
		piese.append(cilindru("Tep", 0.05, 0.0, h, (0.98, y, 1.1 + h / 2), LEMN_INCHIS, laturi=4))
	for _ in range(9):  # stele pe pătură
		x, y = r.uniform(-0.85, 0.45), r.uniform(-0.45, 0.45)
		piese.append(cub("Stea", (0.04, 0.04, 0.006), (x, y, 0.542), AUR, rot=(0, 0, 0.785)))
	piese += palarie(-0.45, 0.12, 0.54)
	uneste(piese, "Pat")
	exporta(os.path.join(cale, "pat.glb"))


def noptiera(cale):
	"""Noptieră cu glob de cristal. Globul e separat, ca să strălucească în joc."""
	curata()
	uneste([
		cub("Corp", (0.45, 0.4, 0.5), (0, 0, 0.25), LEMN),
		cub("Sertar", (0.38, 0.01, 0.16), (0, -0.2, 0.36), LEMN_INCHIS),
		sfera("Buton", 0.018, (0, -0.21, 0.36), AUR, segmente=6, inele=4),
		cilindru("Suport", 0.07, 0.045, 0.05, (0, 0, 0.525), NEGRU, laturi=6),
	], "Noptiera")
	uneste([sfera("Glob", 0.08, (0, 0, 0.62), p("438b88"), segmente=10, inele=8)], "Glob", (0, 0, 0.62))
	exporta(os.path.join(cale, "noptiera.glb"))


def raft(cale):
	"""Raft cu cărți de vrăji, poțiuni și un craniu deasupra. Lat pe X, fața spre -Y."""
	curata()
	r = random.Random(3)
	L, A, H = 1.2, 0.3, 1.8
	piese = [
		cub("Spate", (L, 0.02, H), (0, A / 2 - 0.01, H / 2), NEGRU),
		cub("Stanga", (0.04, A, H), (-L / 2 + 0.02, 0, H / 2), LEMN_INCHIS),
		cub("Dreapta", (0.04, A, H), (L / 2 - 0.02, 0, H / 2), LEMN_INCHIS),
	]
	polite = (0.05, 0.5, 0.95, 1.4, 1.78)
	for z in polite:
		piese.append(cub("Polita", (L, A, 0.04), (0, 0, z), LEMN_INCHIS))
	culori_carti = [p(c) for c in ("7b383a", "655269", "445d46", "295555", "904a40", "553e4d", "2a3c3d", "a18463")]
	for z in polite[:3]:  # cărți pe primele trei polițe
		x = -L / 2 + 0.06
		while x < L / 2 - 0.12:
			lat, h = r.uniform(0.04, 0.08), r.uniform(0.22, 0.36)
			culca = r.random() < 0.12
			rot = (0, r.choice((-0.35, 0.35)), 0) if culca else (0, 0, 0)
			piese.append(cub("Carte", (lat, 0.22, h), (x + lat / 2, 0, z + 0.02 + h / 2), r.choice(culori_carti), rot=rot))
			piese.append(cub("Cotor", (lat * 0.8, 0.005, 0.02), (x + lat / 2, -0.112, z + 0.02 + h * 0.75), AUR, rot=rot))
			x += lat + (0.06 if culca else 0.005)
	# poțiuni pe a patra poliță
	for i, (c, h) in enumerate((("30716f", 0.14), ("7b383a", 0.1), ("5b6d4e", 0.18), ("655269", 0.12))):
		x = -0.4 + i * 0.26
		piese += [
			cilindru("Sticla", 0.045, 0.045, h, (x, 0, 1.42 + h / 2), p(c), laturi=6),
			cilindru("Gat", 0.02, 0.02, 0.05, (x, 0, 1.42 + h + 0.025), p(c), laturi=6),
			cilindru("Dop", 0.024, 0.02, 0.025, (x, 0, 1.42 + h + 0.06), AUR, laturi=6),
		]
	# craniu pe capac
	piese += [
		sfera("Craniu", 0.09, (0.3, 0, 1.89), OS, scara=(0.9, 1.05, 0.95), segmente=8, inele=6),
		cub("Falca", (0.1, 0.08, 0.05), (0.3, -0.04, 1.82), OS),
		cub("Ochi", (0.03, 0.01, 0.03), (0.27, -0.094, 1.9), NEGRU),
		cub("Ochi", (0.03, 0.01, 0.03), (0.33, -0.094, 1.9), NEGRU),
		cub("Nas", (0.016, 0.01, 0.02), (0.3, -0.096, 1.86), NEGRU),
		cilindru("Lumanare", 0.025, 0.025, 0.12, (-0.35, 0, 1.86), p("7b383a"), laturi=6),
	]
	uneste(piese, "Raft")
	exporta(os.path.join(cale, "raft.glb"))


def ceaun(cale):
	"""Ceaun de fontă cu poțiune. Lichidul e separat (strălucește și pâlpâie în joc)."""
	curata()
	piese = [
		sfera_deschisa("Corp", 0.35, (0, 0, 0.4), NEGRU, z_taiere=0.58, scara=(1, 1, 0.85)),
		inel("Buza", 0.27, 0.03, (0, 0, 0.58), NEGRU),
	]
	for i in range(3):
		a = i * 2 * math.pi / 3
		piese.append(os_intre("Picior", (0.2 * math.cos(a), 0.2 * math.sin(a), 0.16),
			(0.25 * math.cos(a), 0.25 * math.sin(a), 0.0), 0.03, NEGRU, laturi=4))
	for s in (1, -1):  # urechile
		piese.append(inel("Ureche", 0.05, 0.012, (0.3 * s, 0, 0.52), NEGRU, segmente=6))
	uneste(piese, "Ceaun")
	lichid = [cilindru("Lichid", 0.27, 0.27, 0.01, (0, 0, 0.52), p("61a19f"), laturi=12)]
	for x, y, rz in ((0.08, 0.05, 0.03), (-0.1, -0.04, 0.022), (0.02, -0.12, 0.018), (-0.04, 0.12, 0.025)):
		lichid.append(sfera("Bula", rz, (x, y, 0.53), OS, segmente=6, inele=4))
	uneste(lichid, "Lichid", (0, 0, 0.52))
	exporta(os.path.join(cale, "ceaun.glb"))


def lumanare(cale):
	"""Lumânare roșie cu scurgeri de ceară. Flacăra e separată (pâlpâie în joc)."""
	curata()
	uneste([
		cilindru("Ceara", 0.035, 0.032, 0.16, (0, 0, 0.08), p("7b383a"), laturi=6),
		cub("Scurgere", (0.012, 0.012, 0.06), (0.03, 0, 0.13), p("7b383a")),
		cub("Scurgere", (0.012, 0.012, 0.04), (-0.02, 0.025, 0.14), p("7b383a")),
		cilindru("Balta", 0.05, 0.045, 0.008, (0, 0, 0.004), p("7b383a"), laturi=6),
		cilindru("Fitil", 0.004, 0.004, 0.02, (0, 0, 0.17), NEGRU, laturi=4),
	], "Lumanare")
	uneste([cilindru("Flacara", 0.014, 0.0, 0.045, (0, 0, 0.198), AUR, laturi=4)], "Flacara", (0, 0, 0.18))
	exporta(os.path.join(cale, "lumanare.glb"))


def covor(cale):
	"""Covor rotund cu pentagramă. Vârfurile stelei sunt la raza 0,92 (acolo stau lumânările)."""
	curata()
	piese = [
		cilindru("Margine", 1.0, 1.0, 0.01, (0, 0, 0.005), AUR, laturi=20),
		cilindru("Covor", 0.96, 0.96, 0.012, (0, 0, 0.006), LEMN_INCHIS, laturi=20),
	]
	varfuri = [(0.92 * math.cos(math.radians(90 + 72 * i)), 0.92 * math.sin(math.radians(90 + 72 * i)))
		for i in range(5)]
	for i in range(5):
		piese.append(linie("Linie", varfuri[i], varfuri[(i + 2) % 5], 0.03, 0.014, 0.007, AUR))
	uneste(piese, "Covor")
	exporta(os.path.join(cale, "covor.glb"))


def matura(cale):
	"""Mătura de vrăjitoare, dreaptă (în joc o sprijinim de perete)."""
	curata()
	uneste([
		cilindru("Paie", 0.13, 0.04, 0.4, (0, 0, 0.2), AUR, laturi=8),
		cilindru("Sfoara", 0.045, 0.045, 0.04, (0, 0, 0.38), p("7b383a"), laturi=8),
		cilindru("Coada", 0.018, 0.016, 1.2, (0, 0, 0.95), p("904a40"), laturi=5),
	], "Matura")
	exporta(os.path.join(cale, "matura.glb"))


def usa(cale):
	"""Ușa camerei: balamaua în origine, ușa se întinde pe +X. Pe fața dinspre hol scrie KEEP OUT.
	Tocul e în alt fișier, fiindcă el nu se mișcă."""
	curata()
	piese = [cub("Usa", (0.9, 0.045, 2.05), (0.45, 0, 1.025), LEMN)]
	for s in (-1, 1):  # panouri în relief, pe ambele fețe
		for z in (0.55, 1.45):
			piese.append(cub("Panou", (0.6, 0.012, 0.7), (0.45, 0.026 * s, z), LEMN_INCHIS))
		piese.append(sfera("Clanta", 0.03, (0.8, 0.045 * s, 1.0), AUR, segmente=6, inele=4))
	piese += [
		cub("Placuta", (0.46, 0.012, 0.15), (0.45, -0.04, 1.62), AUR, rot=(0, 0.05, 0)),
		text("Scris", "KEEP OUT", (0.45, -0.047, 1.62), 0.075, NEGRU, rot=(1.5708, 0.05, 0)),
		cub("Cui", (0.012, 0.01, 0.012), (0.45, -0.047, 1.72), NEGRU),
	]
	uneste(piese, "Usa")
	exporta(os.path.join(cale, "usa_dormitor.glb"))

	curata()
	uneste([
		cub("Toc", (0.05, 0.22, 2.1), (-0.025, 0, 1.05), LEMN_INCHIS),
		cub("Toc", (0.05, 0.22, 2.1), (0.925, 0, 1.05), LEMN_INCHIS),
		cub("Toc", (1.0, 0.22, 0.05), (0.45, 0, 2.085), LEMN_INCHIS),
	], "Toc")
	exporta(os.path.join(cale, "toc_usa.glb"))


def raft_depozit(cale):
	"""Etajera joasă cu 5 compartimente, unde îți lași lucrurile (RaftDepozit în joc pune obiectele în ele).
	Lată pe X (1,55 m), fața spre -Y. Compartimentele au mijloacele la x = -0,62 / -0,31 / 0 / 0,31 / 0,62,
	fundul la z = 0,08. Sus: o lumânare și două cărți. Pe fiecare compartiment, o plăcuță cu numărul lui."""
	curata()
	L, A, H = 1.55, 0.36, 0.62
	piese = [
		cub("Spate", (L - 0.04, 0.02, H - 0.09), (0, A / 2 - 0.01, 0.08 + (H - 0.09) / 2), NEGRU),
		cub("Jos", (L, A, 0.06), (0, 0, 0.05), LEMN_INCHIS),
		cub("Sus", (L + 0.04, A + 0.02, 0.03), (0, -0.01, H + 0.005), LEMN_INCHIS),
	]
	for x in (-L / 2 + 0.01, L / 2 - 0.01):
		piese.append(cub("Lateral", (0.02, A, H - 0.1), (x, 0, 0.08 + (H - 0.1) / 2), LEMN_INCHIS))
	for k in range(4):
		x = -0.465 + k * 0.31
		piese.append(cub("Perete", (0.02, A - 0.03, H - 0.1), (x, 0.005, 0.08 + (H - 0.1) / 2), LEMN))
	for k in range(5):
		x = -0.62 + k * 0.31
		piese.append(cub("Placuta", (0.07, 0.01, 0.025), (x, -A / 2 - 0.004, 0.05), AUR))
		piese.append(text("Cifra", str(k + 1), (x, -A / 2 - 0.011, 0.05), 0.022, NEGRU))
	for x in (-0.72, 0.72):
		piese.append(cilindru("Picior", 0.02, 0.02, 0.02, (x, 0, 0.01), NEGRU, laturi=6))
	piese += [
		cilindru("Lumanare", 0.03, 0.03, 0.11, (0.6, 0.02, H + 0.075), p("7b383a"), laturi=6),
		cub("Fitil", (0.004, 0.004, 0.012), (0.6, 0.02, H + 0.136), NEGRU),
		cub("Carte", (0.2, 0.14, 0.04), (-0.55, 0.0, H + 0.04), p("553e4d"), rot=(0, 0, 0.2)),
		cub("Carte", (0.18, 0.13, 0.035), (-0.54, 0.01, H + 0.0775), p("295555"), rot=(0, 0, -0.1)),
	]
	uneste(piese, "RaftDepozit")
	exporta(os.path.join(cale, "raft_depozit.glb"))


def toate(cale):
	for f in (pat, noptiera, raft, ceaun, lumanare, covor, matura, usa, raft_depozit):
		f(cale)
