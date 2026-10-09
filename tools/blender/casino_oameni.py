# Oamenii din camera de joc din spatele spălătoriei („Casino”): cei 5 jucători de la masa de poker și bătrâna de la
# casă (îți schimbă banii pe jetoane). Îi cheamă casino.py (toate modelele casino-ului):
#   blender --background --factory-startup --python tools/blender/casino.py -- oameni
# Axe Blender: Z în sus, fața spre -Y (în Godot devine +Z). Toți stau jos; originea = podeaua de sub mijlocul șezutului.
# Piese (pentru animația din cod, vezi scripts/om_la_masa.gd):
#   `Corp` (originea în bazin) → `Cap` (originea în gât), `BratD`/`BratS` (originea în umăr) → `AntebratD`/`AntebratS`
#   (originea în cot) → punctul gol `Mana` (între degete); fumătorii au `Tigara` (sau trabucul) în mâna dreaptă, cu `Jar`.
# Modelați cu antebrațele pe masă (`masa` = înălțimea mesei), palmele pe postav: așa e și poza lor de repaus.
# D = dreapta lor = -X.
import math
import os
import random
import sys

import bpy

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from unelte import p, curata, cub, cilindru, sfera, os_intre, inel, uneste, exporta, trunchi  # noqa: E402
from coven import _lerp, _parinte  # noqa: E402

NEGRU = p("262d2f")
ALB = p("83b3b0")
AUR = p("a18463")
AUR_UMBRA = p("a56850")


def _punct(nume, loc, parinte):
	"""Un punct gol (Empty) legat de `parinte`: în Godot devine un Node3D cu numele ăsta (`Mana`)."""
	ob = bpy.data.objects.new(nume, None)
	bpy.context.scene.collection.objects.link(ob)
	ob.location = loc
	bpy.context.view_layer.update()
	_parinte(ob, parinte)
	return ob


def _add(a, b):
	return tuple(x + y for x, y in zip(a, b))


def _scade(a, b):
	return tuple(x - y for x, y in zip(a, b))


def _norm(v):
	l = math.sqrt(sum(x * x for x in v))
	return tuple(x / l for x in v)


# ---------------------------------------------------------------------------------------------------------------
# Capul
# ---------------------------------------------------------------------------------------------------------------

def _cap(piese, gat, s, r):
	"""Fața trasă prin inele (ca la baba / bețiv), apoi părul, pălăria, ochelarii după stil. `gat` = baza capului."""
	gx, gy, gz = gat
	piele, umbra = s["piele"], s["piele_umbra"]
	gras = s.get("gras", 0.0)    # fălci, gușă
	slab = s.get("slab", 0.0)    # obraji supți
	fem = s.get("femeie", False)

	def P(x, y, z):
		return (gx + x, gy + y, gz + z)

	piese.append(os_intre("Gat", P(0, 0.012, -0.03), P(0, -0.005, 0.07), 0.056 + 0.012 * gras - (0.008 if fem else 0), piele, laturi=8))
	l = 1.0 - 0.12 * slab
	g = 1.0 + 0.16 * gras
	fata = [  # (z, y centru, rx, ry)
		(0.035, -0.035, 0.0, 0.0), (0.045, -0.035, 0.04 * g, 0.04), (0.07, -0.025, 0.066 * g * l, 0.074 * g),
		(0.11, -0.012, 0.079 * g * l, 0.092), (0.155, -0.006, 0.083 * (1 + 0.06 * gras), 0.098), (0.2, 0.0, 0.083, 0.098),
		(0.24, 0.006, 0.074, 0.088), (0.27, 0.012, 0.05, 0.062), (0.285, 0.014, 0.0, 0.0),
	]
	if fem:
		fata = [(z, y, rx * 0.92, ry * 0.95) for z, y, rx, ry in fata]
	piese.append(trunchi("Fata", [(P(0, y, z), rx, ry) for z, y, rx, ry in fata], piele, laturi=12))
	fy = -0.1 * (0.95 if fem else 1.0)  # fața din față, la înălțimea ochilor
	# urechile
	for k in (-1, 1):
		piese.append(sfera("Ureche", 0.026, P(0.083 * k * (0.93 if fem else 1), 0.01, 0.17), piele, scara=(0.45, 0.8, 1.0), segmente=6, inele=4))
	# nasul
	n = s.get("nas", 1.0)
	piese.append(trunchi("Nas", [(P(0, fy + 0.008, 0.19), 0.011, 0.01), (P(0, fy - 0.012 * n, 0.158), 0.018 * n, 0.015),
		(P(0, fy - 0.022 * n, 0.137), 0.022 * n, 0.018), (P(0, fy - 0.012 * n, 0.126), 0.0, 0.0)], umbra if s.get("nas_rosu") else piele, laturi=6))
	piese += [
		cub("Nara", (0.01, 0.01, 0.005), P(0.011, fy - 0.012 * n, 0.128), umbra),
		cub("Nara", (0.01, 0.01, 0.005), P(-0.011, fy - 0.012 * n, 0.128), umbra),
	]
	# gura
	buze = s.get("buze", umbra)
	piese += [
		cub("Gura", (0.042, 0.008, 0.007), P(0, fy + 0.006, 0.106), NEGRU if s.get("gura_deschisa") else s.get("gura", umbra)),
		cub("Buza", (0.046, 0.012, 0.009 if fem else 0.006), P(0, fy + 0.007, 0.096), buze),
	]
	if fem:
		piese.append(cub("Buza", (0.04, 0.012, 0.007), P(0, fy + 0.007, 0.114), buze))
	# ochii, sprâncenele
	for k in (-1, 1):
		x = 0.033 * k
		piese += [
			cub("Orbita", (0.034, 0.008, 0.022), P(x, fy + 0.012, 0.17), umbra),
			cub("Ochi", (0.026, 0.006, 0.012), P(x, fy + 0.004, 0.168), ALB),
			cub("Pupila", (0.011, 0.006, 0.011), P(x - 0.003 * k, fy - 0.006, 0.167), NEGRU),
			cub("Spranceana", (0.036, 0.012, 0.009), P(x * 1.05, fy + 0.002, 0.19 + s.get("spranceana", 0.0) * (1 if k > 0 else 0.4)),
				s.get("par_sprancene", s["par"]), rot=(0, s.get("incruntat", 0.12) * k, 0)),
		]
		if gras > 0.3:
			piese.append(sfera("Falca", 0.035, P(0.06 * k, -0.04, 0.08), piele, scara=(0.7, 0.9, 1.0), segmente=6, inele=4))
		if slab > 0.3:
			piese.append(sfera("Pomet", 0.016, P(0.06 * k, -0.07, 0.135), umbra, scara=(0.6, 0.5, 1.0), segmente=6, inele=4))
		if fem:
			piese.append(sfera("Obraz", 0.016, P(0.05 * k, fy + 0.025, 0.14), p("904a40"), scara=(1, 0.4, 0.8), segmente=6, inele=4))
			piese.append(cub("Gene", (0.03, 0.006, 0.006), P(x, fy + 0.001, 0.177), NEGRU))
		if s.get("riduri"):
			piese.append(cub("Rid", (0.003, 0.006, 0.04), P(0.035 * k, fy + 0.012, 0.115), umbra, rot=(0, -0.35 * k, 0.3 * k)))
			piese.append(cub("Rid ochi", (0.014, 0.006, 0.003), P(0.056 * k, fy + 0.018, 0.165), umbra, rot=(0, 0, 0.4 * k)))
	if gras > 0.3:
		piese.append(sfera("Gusa", 0.06, P(0, -0.035, 0.045), piele, scara=(1.2, 0.8, 0.6), segmente=8, inele=5))
	# mustață, barbă, țepi
	if s.get("mustata"):
		piese.append(cub("Mustata", (0.056, 0.014, 0.012), P(0, fy - 0.004, 0.118), s["mustata"]))
		for k in (-1, 1):
			piese.append(cub("Mustata", (0.016, 0.012, 0.022), P(0.028 * k, fy + 0.0, 0.106), s["mustata"], rot=(0, 0.3 * k, 0)))
	if s.get("barba"):
		piese.append(trunchi("Barba", [(P(0, -0.04, 0.03), 0.0, 0.0), (P(0, -0.042, 0.045), 0.05, 0.048),
			(P(0, -0.03, 0.08), 0.07, 0.072), (P(0, -0.02, 0.11), 0.078, 0.086)], s["barba"], laturi=12, capete=False))
	if s.get("barbison"):  # cioc: barbă doar pe bărbie, legată de mustață pe lângă gură
		piese.append(cub("Barbison", (0.04, 0.022, 0.045), P(0, fy + 0.016, 0.07), s["barbison"]))
		for k in (-1, 1):
			piese.append(cub("Barbison", (0.01, 0.014, 0.03), P(0.026 * k, fy + 0.006, 0.098), s["barbison"]))
	if s.get("lupa"):  # lupa de bijutier ridicată pe frunte, pe o bandă elastică în jurul capului
		piese.append(trunchi("Banda lupa", [(P(0, 0.0, 0.222), 0.086, 0.1), (P(0, 0.0, 0.238), 0.086, 0.1)], NEGRU, laturi=12, capete=False))
		piese.append(cilindru("Lupa", 0.02, 0.016, 0.045, P(0.03, fy - 0.02, 0.24), NEGRU, laturi=8, rot=(1.25, 0, 0)))
		piese.append(cilindru("Lentila lupa", 0.016, 0.016, 0.004, P(0.03, fy - 0.042, 0.248), p("438b88"), laturi=8, rot=(1.25, 0, 0)))
	if s.get("mustata_potcoava"):  # mustață „potcoavă” (cowboy): coborâtă pe lângă gură până la bărbie
		for k in (-1, 1):
			piese.append(cub("Mustata", (0.014, 0.014, 0.06), P(0.03 * k, fy + 0.004, 0.085), s["mustata_potcoava"], rot=(0, 0.12 * k, 0)))
	if s.get("perciuni"):
		for k in (-1, 1):
			piese.append(cub("Perciune", (0.012, 0.03, 0.06), P(0.081 * k, -0.02, 0.165), s["perciuni"]))
	if s.get("scobitoare"):  # scobitoare în colțul gurii
		piese.append(os_intre("Scobitoare", P(-0.012, fy + 0.004, 0.103), P(-0.05, fy - 0.035, 0.094), 0.0025, p("a18463"), laturi=4))
	if s.get("tepi"):  # barbă nerasă: puncte pe bărbie și pe fălci
		for k in range(18):
			u = math.pi * (0.15 + 0.7 * k / 17)
			piese.append(cub("Tep", (0.006, 0.004, 0.006), P(math.cos(u) * 0.066 * g, -0.025 - math.sin(u) * 0.075, 0.065 + r.uniform(0, 0.03)),
				s["tepi"]))
	# părul
	par = s["par"]
	stil = s.get("stil_par", "scurt")
	if stil == "scurt":
		piese.append(sfera("Par", 0.09, P(0, 0.022, 0.205), par, scara=(0.98, 1.0, 0.82), segmente=10, inele=7))
		piese.append(sfera("Ceafa", 0.08, P(0, 0.05, 0.15), par, scara=(1.0, 0.75, 0.9), segmente=8, inele=5))
	elif stil == "spate":  # pieptănat pe spate, cu gel
		piese.append(trunchi("Par", [(P(0, -0.08, 0.24), 0.06, 0.02), (P(0, -0.04, 0.275), 0.08, 0.04), (P(0, 0.03, 0.27), 0.088, 0.06),
			(P(0, 0.08, 0.22), 0.082, 0.05), (P(0, 0.1, 0.16), 0.06, 0.03)], par, laturi=10, ref=(1, 0, 0)))
		for k in (-1, 1):
			piese.append(cub("Perciune", (0.012, 0.03, 0.05), P(0.082 * k, -0.025, 0.19), par))
	elif stil == "chel":  # chel în creștet, smocuri pe laterale și la ceafă
		for k in (-1, 1):
			piese.append(sfera("Par", 0.05, P(0.07 * k, 0.03, 0.17), par, scara=(0.5, 1.2, 0.8), segmente=6, inele=4))
		piese.append(sfera("Ceafa", 0.07, P(0, 0.07, 0.155), par, scara=(1.1, 0.6, 0.7), segmente=8, inele=5))
	elif stil == "ras":
		piese.append(sfera("Par", 0.092, P(0, 0.02, 0.205), par, scara=(1.0, 1.04, 0.9), segmente=10, inele=7))
	elif stil == "permanent":  # bucle mari, umflate (bătrâna de la casă)
		for k in range(22):
			u = r.uniform(0, math.tau)
			v = r.uniform(-0.15, 1.2)
			c = P(math.cos(u) * 0.09 * math.cos(v * 0.9), 0.03 + math.sin(u) * 0.085 * math.cos(v * 0.9) + 0.02,
				0.2 + math.sin(v * 0.9) * 0.08)
			if c[1] - gy < -0.06 and c[2] - gz < 0.24:
				continue  # fața rămâne liberă
			piese.append(sfera("Bucla", 0.038 + r.uniform(0, 0.012), c, par if k % 3 else s.get("par_suvita", par), segmente=6, inele=4))
		piese.append(sfera("Par", 0.094, P(0, 0.025, 0.22), par, scara=(1.05, 1.05, 0.8), segmente=10, inele=6))
	elif stil == "voluminos":  # buclat, lung, până pe umeri (femeia)
		piese.append(sfera("Par", 0.1, P(0, 0.03, 0.215), par, scara=(1.05, 1.0, 0.85), segmente=10, inele=7))
		for k in range(16):
			u = math.pi * (-0.2 + 1.4 * k / 15)
			start = P(math.cos(u) * 0.088, 0.02 + math.sin(u) * 0.08, 0.22)
			jos = _add(start, (math.cos(u) * 0.05, math.sin(u) * 0.045 + 0.02, -0.26 + r.uniform(-0.03, 0.03)))
			mij = _add(_lerp(start, jos, 0.5), (math.cos(u) * 0.035, math.sin(u) * 0.03, 0))
			piese.append(trunchi("Bucla", [(start, 0.024, 0.02), (mij, 0.032, 0.026), (jos, 0.018, 0.014)],
				par if k % 3 else s.get("par_suvita", par), laturi=6, ref=(math.cos(u), math.sin(u), 0)))
		piese.append(trunchi("Breton", [(P(-0.07, -0.06, 0.26), 0.02, 0.012), (P(0, -0.095, 0.25), 0.03, 0.015),
			(P(0.07, -0.06, 0.26), 0.02, 0.012)], par, laturi=5, ref=(0, 0, 1)))
	# pălăria
	palarie = s.get("palarie")
	if palarie == "fedora":
		cul, banda = s["culoare_palarie"], s.get("banda", NEGRU)
		piese.append(cilindru("Bor", 0.16, 0.16, 0.012, P(0, 0.015, 0.245), cul, laturi=14, rot=(-0.08, 0, 0)))
		piese.append(trunchi("Calota", [(P(0, 0.015, 0.25), 0.1, 0.11), (P(0, 0.018, 0.3), 0.095, 0.105), (P(0, 0.022, 0.34), 0.085, 0.095),
			(P(0, 0.028, 0.35), 0.0, 0.0)], cul, laturi=10))
		piese.append(cub("Indoitura", (0.07, 0.11, 0.012), P(0, 0.022, 0.346), s.get("culoare_palarie_umbra", cul)))
		piese.append(trunchi("Banda", [(P(0, 0.015, 0.256), 0.104, 0.114), (P(0, 0.016, 0.278), 0.102, 0.112)], banda, laturi=10))
		piese.append(cub("Pana", (0.012, 0.04, 0.06), P(0.1, 0.03, 0.29), p("7b383a"), rot=(0.3, 0, 0.2)))
	elif palarie == "cowboy":  # pălărie de cowboy: borul lat, ridicat pe laterale, calota înaltă cu „ciupitura” în față
		cul, umbra_p = s["culoare_palarie"], s.get("culoare_palarie_umbra", s["culoare_palarie"])
		piese.append(_bor_cowboy(P(0, 0.015, 0.232), 0.098, 0.112, 0.205, 0.19, 0.055, cul))
		piese.append(trunchi("Calota", [(P(0, 0.015, 0.236), 0.096, 0.108), (P(0, 0.016, 0.29), 0.094, 0.106),
			(P(0, 0.02, 0.34), 0.086, 0.1), (P(0, 0.024, 0.365), 0.07, 0.088), (P(0, 0.03, 0.372), 0.0, 0.0)], cul, laturi=12))
		piese.append(cub("Indoitura", (0.03, 0.15, 0.014), P(0, 0.03, 0.368), umbra_p))
		for k in (-1, 1):  # ciupitura din față
			piese.append(cub("Ciupitura", (0.012, 0.05, 0.05), P(0.045 * k, -0.06, 0.33), umbra_p, rot=(0.25, 0, 0.35 * k)))
		piese.append(trunchi("Banda", [(P(0, 0.015, 0.243), 0.099, 0.111), (P(0, 0.015, 0.262), 0.098, 0.11)], s.get("banda", NEGRU), laturi=12))
		piese.append(cub("Catarama banda", (0.02, 0.008, 0.016), P(0.04, -0.093, 0.252), AUR, rot=(0, 0, 0.35)))
	elif palarie == "sapca":  # șapcă de stofă (bunicul)
		cul = s["culoare_palarie"]
		piese.append(sfera("Sapca", 0.1, P(0, 0.01, 0.245), cul, scara=(1.0, 1.15, 0.45), segmente=10, inele=6))
		piese.append(cub("Cozoroc", (0.15, 0.07, 0.012), P(0, -0.1, 0.235), cul, rot=(0.18, 0, 0)))
		piese.append(cub("Nasture sapca", (0.016, 0.016, 0.01), P(0, -0.02, 0.29), s.get("culoare_palarie_umbra", cul)))
	elif palarie == "baseball":  # șapcă de camionagiu: calota rotundă, panoul din față cu sigla, cozorocul curbat
		cul, umbra_p = s["culoare_palarie"], s.get("culoare_palarie_umbra", s["culoare_palarie"])
		piese.append(trunchi("Calota", [(P(0, 0.008, 0.2), 0.092, 0.104), (P(0, 0.008, 0.25), 0.09, 0.102), (P(0, 0.01, 0.29), 0.072, 0.084),
			(P(0, 0.012, 0.31), 0.04, 0.05), (P(0, 0.014, 0.316), 0.0, 0.0)], cul, laturi=12))
		piese.append(cub("Panou sapca", (0.11, 0.012, 0.07), P(0, -0.092, 0.248), s.get("panou_sapca", ALB), rot=(-0.22, 0, 0)))
		if s.get("sigla_sapca"):
			piese.append(cub("Sigla sapca", (0.05, 0.008, 0.03), P(0, -0.1, 0.25), s["sigla_sapca"], rot=(-0.22, 0, 0)))
		for k in (-1, 0, 1):  # cozorocul în trei bucăți, puțin curbat
			piese.append(cub("Cozoroc", (0.06, 0.09, 0.01), P(0.055 * k, -0.135 + 0.006 * abs(k), 0.205 - 0.008 * abs(k)), umbra_p,
				rot=(0.12, 0, -0.18 * k)))
		piese.append(cilindru("Nasture sapca", 0.012, 0.012, 0.01, P(0, 0.014, 0.318), umbra_p, laturi=6))
	# ochelarii
	och = s.get("ochelari")
	if och == "soare":
		for k in (-1, 1):
			piese.append(cub("Lentila", (0.042, 0.008, 0.028), P(0.035 * k, fy - 0.006, 0.168), NEGRU))
			piese.append(cub("Brat ochelari", (0.005, 0.1, 0.005), P(0.08 * k, -0.04, 0.175), NEGRU))
		piese.append(cub("Punte", (0.03, 0.008, 0.008), P(0, fy - 0.006, 0.176), AUR))
		piese.append(cub("Rama sus", (0.12, 0.009, 0.008), P(0, fy - 0.007, 0.184), AUR))
	elif och in ("vedere", "pisica"):
		rama = s.get("rama", NEGRU)
		for k in (-1, 1):
			x = 0.035 * k
			piese.append(cub("Rama", (0.044, 0.006, 0.006), P(x, fy - 0.006, 0.185 + (0.006 if och == "pisica" else 0)), rama,
				rot=(0, (-0.25 if och == "pisica" else 0) * k, 0)))
			piese.append(cub("Rama", (0.044, 0.006, 0.005), P(x, fy - 0.006, 0.153), rama))
			piese.append(cub("Rama", (0.005, 0.006, 0.034), P(x + 0.022 * k, fy - 0.006, 0.169), rama))
			piese.append(cub("Rama", (0.005, 0.006, 0.034), P(x - 0.02 * k, fy - 0.006, 0.169), rama))
			piese.append(cub("Brat ochelari", (0.005, 0.1, 0.005), P(0.08 * k, -0.04, 0.178), rama))
			if och == "pisica":  # colțurile ridicate
				piese.append(cub("Colt rama", (0.016, 0.007, 0.01), P(0.058 * k, fy - 0.004, 0.193), rama, rot=(0, -0.6 * k, 0)))
		piese.append(cub("Punte", (0.026, 0.006, 0.005), P(0, fy - 0.006, 0.175), rama))
		if s.get("lantisor_ochelari"):
			for k in (-1, 1):
				piese.append(os_intre("Lantisor", P(0.08 * k, 0.0, 0.17), P(0.1 * k, 0.02, 0.02), 0.003, AUR, laturi=4))
	if s.get("cercei"):
		for k in (-1, 1):
			piese.append(sfera("Cercel", 0.012, P(0.085 * k, 0.0, 0.135), s["cercei"], segmente=6, inele=4))
	if s.get("aparat_auditiv"):
		piese.append(cub("Aparat", (0.012, 0.02, 0.025), P(0.09, 0.02, 0.17), p("a56850")))


def _bor_cowboy(centru, rx0, ry0, rx1, ry1, ridicare, culoare, segmente=24, inele_bor=4, gros=0.008):
	"""Borul pălăriei de cowboy: o coroană plină (de la elipsa calotei rx0/ry0 la marginea rx1/ry1), ridicată pe laterale
	(cu `ridicare` la margine, mai mult cu cât e mai departe de calotă) și puțin lăsată în față și în spate."""
	import bmesh
	bm = bmesh.new()
	cx, cy, cz = centru
	sus, jos = [], []
	for i in range(inele_bor + 1):
		t = i / inele_bor
		rs, rj = [], []
		for j in range(segmente):
			u = math.tau * j / segmente
			x = math.cos(u) * (rx0 + (rx1 - rx0) * t)
			y = math.sin(u) * (ry0 + (ry1 - ry0) * t)
			z = ridicare * (math.cos(u) ** 2) * t * t - 0.02 * (math.sin(u) ** 2) * t * t
			rs.append(bm.verts.new((cx + x, cy + y, cz + z + gros / 2)))
			rj.append(bm.verts.new((cx + x, cy + y, cz + z - gros / 2)))
		sus.append(rs)
		jos.append(rj)
	for i in range(inele_bor):
		for j in range(segmente):
			k = (j + 1) % segmente
			bm.faces.new((sus[i][j], sus[i + 1][j], sus[i + 1][k], sus[i][k]))
			bm.faces.new((jos[i][j], jos[i][k], jos[i + 1][k], jos[i + 1][j]))
	for j in range(segmente):  # marginile (interioară și exterioară)
		k = (j + 1) % segmente
		bm.faces.new((sus[0][j], sus[0][k], jos[0][k], jos[0][j]))
		bm.faces.new((sus[-1][j], jos[-1][j], jos[-1][k], sus[-1][k]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	me = bpy.data.meshes.new("Bor")
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new("Bor", me)
	bpy.context.scene.collection.objects.link(ob)
	from unelte import _coloreaza
	_coloreaza(ob, culoare)
	return ob


# ---------------------------------------------------------------------------------------------------------------
# Corpul
# ---------------------------------------------------------------------------------------------------------------

def _mana(piese, incheietura, directie, s, strans=False):
	"""Mâna pe masă, cu palma în jos: palma turtită, patru degete înainte, degetul mare spre mijloc.
	`directie` = încotro arată degetele (pe orizontală). Întoarce punctul dintre degete."""
	piele, umbra = s["piele"], s["piele_umbra"]
	d = _norm(directie)
	lat = (-d[1], d[0], 0.0)  # perpendicular, pe orizontală
	palma = _add(incheietura, tuple(v * 0.045 for v in d))
	piese.append(sfera("Palma", 0.042, palma, piele, scara=(1.0, 1.0, 0.4), segmente=8, inele=5))
	for k in range(4):
		o = (k - 1.5) * 0.017
		baza = _add(palma, (d[0] * 0.035 + lat[0] * o, d[1] * 0.035 + lat[1] * o, 0.0))
		lung = 0.052 if k in (1, 2) else 0.044
		if strans:
			varf = _add(baza, (d[0] * 0.02, d[1] * 0.02, -0.02))
		else:
			varf = _add(baza, (d[0] * lung, d[1] * lung, -0.008))
		piese.append(os_intre("Deget", baza, varf, 0.0085, piele, laturi=4))
	if s.get("inele"):
		piese.append(cub("Inel", (0.018, 0.012, 0.012), _add(palma, (d[0] * 0.045 - lat[0] * 0.01, d[1] * 0.045 - lat[1] * 0.01, 0.008)),
			s["inele"]))
	if s.get("unghii"):
		for k in range(4):
			o = (k - 1.5) * 0.017
			piese.append(cub("Unghie", (0.009, 0.01, 0.004), _add(palma, (d[0] * 0.08 + lat[0] * o, d[1] * 0.08 + lat[1] * o, 0.002)),
				s["unghii"]))
	# degetul mare: spre interior (spre mijlocul corpului)
	return _add(palma, (d[0] * 0.05, d[1] * 0.05, 0.015))


def _brat(piese_brat, piese_antebrat, umar, cot, incheietura, s, latura):
	"""Mâneca (sacou / pulover / rochie fără mâneci) de la umăr la cot și de la cot la încheietură, cu manșeta."""
	haina, umbra = s["haina"], s["haina_umbra"]
	maneca = s.get("maneca", haina)
	gros = s.get("gros_brat", 1.0)
	scurta = s.get("maneca_scurta")  # mânecă scurtă: de la jumătatea brațului în jos e pielea
	piese_brat.append(sfera("Umar", 0.062 * gros, _add(umar, (0, 0, -0.01)), maneca, segmente=8, inele=5))
	piese_brat.append(trunchi("Brat", [(umar, 0.068 * gros, 0.068 * gros), (_lerp(umar, cot, 0.5), 0.062 * gros, 0.058 * gros),
		(cot, 0.056 * gros, 0.054 * gros)], maneca if not (s.get("brate_goale") or scurta) else s["piele"], laturi=8, ref=(0, 0, 1)))
	if scurta:
		piese_brat.append(trunchi("Maneca scurta", [(umar, 0.078 * gros, 0.078 * gros), (_lerp(umar, cot, 0.55), 0.074 * gros, 0.07 * gros)],
			maneca, laturi=8, ref=(0, 0, 1)))
		for t, cul in (((0.2, s["flori"][0]), (0.4, s["flori"][1])) if s.get("flori") else ()):
			piese_brat.append(sfera("Floare", 0.018, _add(_lerp(umar, cot, t), (0, -0.07 * gros, 0)), cul, scara=(1, 0.4, 1), segmente=6, inele=3))
	goale = s.get("brate_goale") or scurta
	piese_antebrat.append(sfera("Cot", 0.056 * gros, cot, maneca if not goale else s["piele"], segmente=8, inele=5))
	capat = _lerp(cot, incheietura, 0.92)
	piese_antebrat.append(trunchi("Antebrat", [(cot, 0.054 * gros, 0.052 * gros), (_lerp(cot, incheietura, 0.5), 0.05 * gros, 0.046 * gros),
		(capat, 0.046 * gros, 0.042 * gros)], maneca if not goale else s["piele"], laturi=8, ref=(0, 0, 1)))
	if goale and s.get("tatuaj"):  # tatuaje pe antebraț: câteva pete închise, pe partea de sus
		for t, dz in ((0.3, 0.0), (0.5, 0.01), (0.68, -0.005)):
			piese_antebrat.append(sfera("Tatuaj", 0.024, _add(_lerp(cot, incheietura, t), (0, 0, 0.042 * gros + dz)), s["tatuaj"],
				scara=(1.3, 1.0, 0.35), segmente=6, inele=3))
	if not goale:
		if s.get("manseta"):
			piese_antebrat.append(os_intre("Manseta", _lerp(cot, incheietura, 0.9), _lerp(cot, incheietura, 1.0), 0.04, s["manseta"], laturi=8))
		else:
			piese_antebrat.append(os_intre("Tiv maneca", _lerp(cot, incheietura, 0.86), capat, 0.049 * gros, umbra, laturi=8))
		if s.get("dungi_maneca"):  # trening: două dungi pe lateral
			for k in (0.0, 0.025):
				iesire = (0.0, 0.0, 0.048 + k * 0.1)
				piese_brat.append(os_intre("Dunga", _add(umar, (0, 0, 0.06 - k)), _add(cot, (0, 0, 0.052 - k)), 0.008, s["dungi_maneca"], laturi=4))
	if s.get("carouri"):  # cămașă în carouri: inele închise pe mânecă (de departe se citesc drept carouri)
		for t in (0.22, 0.5, 0.78):
			piese_brat.append(os_intre("Carou", _lerp(umar, cot, t - 0.03), _lerp(umar, cot, t + 0.03), 0.073 * gros, s["carouri"], laturi=8))
		for t in (0.25, 0.55):
			piese_antebrat.append(os_intre("Carou", _lerp(cot, incheietura, t - 0.03), _lerp(cot, incheietura, t + 0.03), 0.06 * gros,
				s["carouri"], laturi=8))
	if s.get("ceas") and latura == "S":
		piese_antebrat.append(os_intre("Ceas", _lerp(cot, incheietura, 0.97), _lerp(cot, incheietura, 1.04), 0.043, s["ceas"], laturi=8))


def _tors(piese, z0, s, picioare=None):
	"""Trunchiul (sacou/pulover/trening/rochie), bazinul, picioarele cu pantofii. Întoarce inelele trunchiului."""
	h = 1.18  # cât de înalt e trunchiul (față de valorile de mai jos)
	burta = s.get("burta", 0.0)
	fem = s.get("femeie", False)
	haina, umbra = s["haina"], s["haina_umbra"]
	lat = 0.92 if fem else 1.0
	inele = [  # (z față de șezut, y, rx, ry)
		(0.02, 0.03, 0.17 * lat, 0.13), (0.13, 0.02 - 0.05 * burta, (0.175 + 0.05 * burta) * lat, 0.135 + 0.07 * burta),
		(0.25, 0.01 - 0.05 * burta, (0.18 + 0.05 * burta) * lat, 0.135 + 0.065 * burta), (0.36, 0.0 - 0.02 * burta, 0.195 * lat, 0.13 + 0.03 * burta),
		(0.46, 0.01, 0.205 * lat, 0.12), (0.52, 0.02, 0.16 * lat, 0.095), (0.56, 0.02, 0.075, 0.06),
	]
	if fem:  # talia și pieptul
		inele[1] = (0.13, 0.03, 0.15, 0.11)
		inele[2] = (0.25, 0.02, 0.145, 0.11)
		inele[3] = (0.36, 0.0, 0.17, 0.135)
	piese.append(trunchi("Trunchi", [((0, y, z0 + z * h), rx, ry) for z, y, rx, ry in inele], haina, laturi=12))
	piese.append(sfera("Bazin", 0.17, (0, 0.03, z0 + 0.06 * h), s.get("pantaloni", haina), scara=(1.15 * lat, 1.0, 0.55), segmente=10, inele=6))
	fata = lambda z, k=0.0: min(((zz, y - ry) for zz, y, rx, ry in inele), key=lambda t: abs(t[0] - z))[1] - 0.012 - k
	stil = s.get("stil_haina", "sacou")
	if stil == "sacou":
		# cămașa în deschizătura în V, cravata, reverele, nasturii, batista din buzunar
		for z, w in ((0.48, 0.07), (0.42, 0.06), (0.36, 0.045), (0.3, 0.025)):
			piese.append(cub("Camasa", (w, 0.012, 0.062), (0, fata(z), z0 + z * h), s["camasa"]))
		if s.get("cravata"):
			piese.append(cub("Nod cravata", (0.026, 0.014, 0.024), (0, fata(0.5, 0.013), z0 + 0.5 * h), s["cravata"]))
			piese.append(cub("Cravata", (0.034, 0.012, 0.2), (0, fata(0.4, 0.013), z0 + 0.39 * h), s["cravata"]))
		for k in (-1, 1):
			piese.append(cub("Rever", (0.05, 0.012, 0.2), (0.055 * k, fata(0.42, 0.004), z0 + 0.41 * h), umbra, rot=(0, -0.35 * k, 0)))
		for z in (0.24, 0.15):
			piese.append(cilindru("Nasture", 0.011, 0.011, 0.008, (0.02, fata(z), z0 + z * h), NEGRU, laturi=6, rot=(1.5708, 0, 0)))
		piese.append(cub("Batista", (0.04, 0.012, 0.022), (0.12, fata(0.42) + 0.01, z0 + 0.44 * h), s.get("batista", ALB)))
	elif stil == "geaca":  # geacă de piele, tricou negru dedesubt, fermoar
		piese.append(cub("Tricou", (0.12, 0.012, 0.25), (0, fata(0.38), z0 + 0.38 * h), s["camasa"]))
		for k in (-1, 1):
			piese.append(cub("Guler", (0.06, 0.03, 0.08), (0.075 * k, fata(0.52, -0.02), z0 + 0.53 * h), umbra, rot=(0.3, 0, 0.4 * k)))
			piese.append(cub("Fermoar", (0.008, 0.01, 0.4), (0.065 * k, fata(0.3, 0.004), z0 + 0.3 * h), AUR))
	elif stil == "pulover":  # pulover cu nasturi (cardigan) peste cămașă
		piese.append(cub("Guler camasa", (0.08, 0.014, 0.04), (0, fata(0.52, 0.002), z0 + 0.52 * h), s["camasa"]))
		piese.append(cub("Camasa", (0.05, 0.012, 0.1), (0, fata(0.46), z0 + 0.46 * h), s["camasa"]))
		for z in (0.38, 0.29, 0.2, 0.11):
			piese.append(cilindru("Nasture", 0.01, 0.01, 0.008, (0, fata(z, 0.002), z0 + z * h), s.get("nasturi", NEGRU), laturi=6, rot=(1.5708, 0, 0)))
		piese.append(cub("Buzunar", (0.08, 0.01, 0.06), (0.1, fata(0.12, -0.03), z0 + 0.12 * h), umbra))
	elif stil == "trening":
		piese.append(cub("Fermoar", (0.012, 0.012, 0.42), (0, fata(0.3), z0 + 0.3 * h), ALB))
		piese.append(trunchi("Guler", [((0, 0.02, z0 + 0.53 * h), 0.09, 0.075), ((0, 0.02, z0 + 0.6 * h), 0.085, 0.07)], haina, laturi=10, capete=False))
		for k in (-1, 1):
			piese.append(cub("Dunga", (0.012, 0.01, 0.34), (0.15 * k, fata(0.3, -0.02), z0 + 0.3 * h), s.get("dungi_maneca", ALB)))
	elif stil == "rochie":  # rochie fără mâneci: pielea de la decolteu până la gât
		piese.append(cub("Decolteu", (0.12, 0.012, 0.11), (0, fata(0.5), z0 + 0.49 * h), s["piele"]))
		piese.append(cub("Decolteu", (0.07, 0.012, 0.05), (0, fata(0.44), z0 + 0.425 * h), s["piele"]))
		for k in (-1, 1):
			piese.append(cub("Bretea", (0.035, 0.012, 0.14), (0.11 * k, fata(0.5, -0.04), z0 + 0.52 * h), haina, rot=(0, 0, 0.2 * k)))
	elif stil == "vesta":  # vestă de piele peste cămașa în carouri (cowboy): cămașa în V larg, nasturi-capse, cravata bolo
		cam, car = s["camasa"], s.get("carouri", umbra)
		for z, w in ((0.5, 0.11), (0.44, 0.1), (0.38, 0.085), (0.32, 0.07), (0.26, 0.055), (0.2, 0.04)):
			piese.append(cub("Camasa", (w, 0.012, 0.062), (0, fata(z), z0 + z * h), cam))
			piese.append(cub("Carou", (w + 0.002, 0.012, 0.012), (0, fata(z, 0.008), z0 + (z + 0.02) * h), car))
		piese.append(cub("Carou", (0.012, 0.012, 0.3), (0.025, fata(0.36, 0.016), z0 + 0.36 * h), car))
		piese.append(cub("Carou", (0.012, 0.012, 0.3), (-0.025, fata(0.36, 0.016), z0 + 0.36 * h), car))
		for k in (-1, 1):
			piese.append(cub("Guler", (0.06, 0.03, 0.05), (0.06 * k, fata(0.53, -0.012), z0 + 0.535 * h), cam, rot=(0.35, 0, 0.5 * k)))
			piese.append(cub("Margine vesta", (0.016, 0.014, 0.32), (0.07 * k, fata(0.36, 0.004), z0 + 0.36 * h), umbra, rot=(0, -0.25 * k, 0)))
		for z in (0.42, 0.33, 0.24):
			piese.append(cilindru("Capsa", 0.007, 0.007, 0.008, (0, fata(z, 0.008), z0 + z * h), ALB, laturi=6, rot=(1.5708, 0, 0)))
		if s.get("bolo"):
			for k in (-1, 1):
				piese.append(cub("Snur bolo", (0.005, 0.006, 0.17), (0.012 * k, fata(0.4, 0.016), z0 + 0.4 * h), NEGRU))
			piese.append(sfera("Bolo", 0.024, (0, fata(0.49, 0.02), z0 + 0.49 * h), s["bolo"], scara=(1, 0.4, 1.2), segmente=8, inele=5))
			piese.append(sfera("Rama bolo", 0.028, (0, fata(0.49, 0.014), z0 + 0.49 * h), AUR, scara=(1, 0.3, 1.2), segmente=8, inele=5))
	elif stil == "tricou":  # tricou simplu cu guler rotund (barmanul)
		piese.append(trunchi("Guler tricou", [((0, 0.018, z0 + 0.535 * h), 0.085, 0.07), ((0, 0.018, z0 + 0.555 * h), 0.08, 0.066)], umbra,
			laturi=10, capete=False))
		if s.get("scris_tricou"):
			piese.append(cub("Sigla tricou", (0.12, 0.012, 0.07), (0, fata(0.42), z0 + 0.42 * h), s["scris_tricou"]))
	elif stil == "hawaiana":  # cămașă hawaiiană descheiată la gât (Johnny): pielea în V, nasturii, florile imprimate
		for z, w in ((0.53, 0.1), (0.48, 0.08), (0.43, 0.055), (0.39, 0.03)):
			piese.append(cub("Decolteu", (w, 0.012, 0.055), (0, fata(z), z0 + z * h), s["piele"]))
		if s.get("par_piept"):
			for k in range(9):
				piese.append(cub("Par piept", (0.006, 0.004, 0.006), ((k % 3 - 1) * 0.018, fata(0.48 - 0.03 * (k // 3), 0.004),
					z0 + (0.49 - 0.03 * (k // 3)) * h), s["par_piept"]))
		for k in (-1, 1):
			piese.append(cub("Guler", (0.07, 0.03, 0.05), (0.07 * k, fata(0.53, -0.012), z0 + 0.535 * h), umbra, rot=(0.35, 0, 0.55 * k)))
			piese.append(cub("Margine camasa", (0.012, 0.012, 0.16), (0.035 * k, fata(0.44, 0.002), z0 + 0.445 * h), umbra, rot=(0, -0.3 * k, 0)))
		for z in (0.33, 0.24, 0.15):
			piese.append(cilindru("Nasture", 0.009, 0.009, 0.008, (0, fata(z, 0.004), z0 + z * h), s.get("nasturi", ALB), laturi=6, rot=(1.5708, 0, 0)))
		# florile: pete rotunde pe față și pe laterale, puse pe suprafața elipsei inelului cel mai apropiat
		rr = random.Random(7)
		for k in range(34):
			z = rr.uniform(0.05, 0.5)
			x = rr.uniform(-0.17, 0.17)
			if abs(x) < 0.06 and z > 0.37:
				continue  # decolteul
			zz, y, rx, ry = min(inele, key=lambda t: abs(t[0] - z))
			if abs(x) > rx * 0.92:
				continue
			yf = y - ry * math.sqrt(max(0.0, 1.0 - (x / rx) ** 2)) - 0.004
			cul = s["flori"][k % len(s["flori"])] if k % 3 else s.get("frunze", umbra)
			piese.append(sfera("Floare", rr.uniform(0.016, 0.026), (x, yf, z0 + z * h), cul, scara=(1.0, 0.35, 1.0), segmente=6, inele=3))
	if s.get("sort"):  # șorțul de barman: de la brâu până sub genunchi, cu șnurul și buzunarul
		piese.append(cub("Sort", (0.34, 0.012, 0.62), (0, 0.03 - 0.14 - 0.02 - 0.04 * burta, z0 - 0.2), s["sort"]))
		piese.append(cub("Buzunar sort", (0.2, 0.01, 0.12), (0, 0.03 - 0.14 - 0.032 - 0.04 * burta, z0 - 0.08), umbra))
		piese.append(trunchi("Snur sort", [((0, 0.03, z0 + 0.03 * h), 0.18 + 0.03 * burta, 0.142 + 0.04 * burta),
			((0, 0.03, z0 + 0.045 * h), 0.18 + 0.03 * burta, 0.142 + 0.04 * burta)], s["sort"], laturi=12, capete=False))
	if s.get("curea"):  # cureaua lată cu catarama mare, de rodeo
		piese.append(trunchi("Curea", [((0, 0.03, z0 + 0.0 * h), 0.178, 0.138), ((0, 0.03, z0 + 0.045 * h), 0.18, 0.14)], s["curea"],
			laturi=12, capete=False))
		piese.append(cub("Catarama", (0.085, 0.014, 0.062), (0, 0.03 - 0.14 - 0.008, z0 + 0.022 * h), AUR))
		piese.append(cub("Catarama mijloc", (0.05, 0.01, 0.036), (0, 0.03 - 0.14 - 0.019, z0 + 0.022 * h), p("a56850")))
	if s.get("toc_pistol"):  # tocul de piele pe șoldul drept, cu mânerul pistolului afară
		piese.append(cub("Toc pistol", (0.05, 0.13, 0.2), (-0.21, 0.04, z0 - 0.06), s["toc_pistol"], rot=(0.1, 0, 0)))
		piese.append(cub("Maner pistol", (0.032, 0.05, 0.1), (-0.21, 0.07, z0 + 0.07), NEGRU, rot=(-0.3, 0, 0)))
	if s.get("lant"):
		for k in range(13):
			u = math.pi * (0.1 + 0.8 * k / 12)
			x = math.cos(u) * 0.085
			z = 0.535 - math.sin(u) * (0.13 if not fem else 0.07)
			piese.append(sfera("Za", 0.012, (x, fata(z, 0.008), z0 + z * h), s["lant"], scara=(1.0, 0.6, 1.0), segmente=6, inele=4))
		if s.get("medalion"):
			piese.append(cub("Medalion", (0.04, 0.012, 0.05), (0, fata(0.38, 0.012), z0 + 0.38 * h), s["lant"]))
	if s.get("brosa"):
		piese.append(sfera("Brosa", 0.018, (-0.09, fata(0.44, 0.01), z0 + 0.44 * h), s["brosa"], scara=(1, 0.5, 1), segmente=6, inele=4))
	pant, pantofi = s.get("pantaloni", haina), s.get("pantofi", NEGRU)
	if s.get("in_picioare"):
		# în picioare: picioarele drepte (blugi), cizme de cowboy cu tocul înalt și vârful ascuțit. Merg în `picioare`
		# (alt obiect, fără respirație: altfel tălpile s-ar mișca prin podea)
		pp = picioare if picioare is not None else piese
		for k in (-1, 1):
			sold, genunchi, glezna = (0.1 * k, 0.03, z0 + 0.04 * h), (0.105 * k, 0.0, 0.5), (0.11 * k, 0.02, 0.1)
			pp.append(trunchi("Coapsa", [(sold, 0.09, 0.088), (genunchi, 0.066, 0.066)], pant, laturi=8, ref=(1, 0, 0)))
			pp.append(sfera("Genunchi", 0.067, genunchi, pant, segmente=8, inele=5))
			pp.append(trunchi("Gamba", [(genunchi, 0.064, 0.064), ((0.107 * k, 0.03, 0.33), 0.062, 0.066), (glezna, 0.05, 0.05)], pant,
				laturi=8, ref=(1, 0, 0)))
			# cizma: carâmbul până la jumătatea gambei, laba lungă și ascuțită, tocul
			pp.append(trunchi("Caramb", [((0.11 * k, 0.025, 0.06), 0.058, 0.064), ((0.109 * k, 0.03, 0.3), 0.068, 0.072)], pantofi,
				laturi=8, ref=(1, 0, 0), capete=False))
			pp.append(trunchi("Cizma", [((0.11 * k, 0.06, 0.05), 0.0, 0.0), ((0.11 * k, 0.05, 0.06), 0.055, 0.05),
				((0.11 * k, -0.06, 0.05), 0.05, 0.035), ((0.11 * k, -0.17, 0.035), 0.03, 0.022), ((0.11 * k, -0.21, 0.03), 0.0, 0.0)],
				pantofi, laturi=8, ref=(1, 0, 0)))
			pp.append(cub("Talpa", (0.09, 0.26, 0.012), (0.11 * k, -0.07, 0.016), NEGRU))
			pp.append(cub("Toc", (0.07, 0.07, 0.05), (0.11 * k, 0.05, 0.025), NEGRU))
			pp.append(os_intre("Cusatura", (0.11 * k, -0.075, 0.075), (0.11 * k, 0.04, 0.16), 0.004, AUR, laturi=4))
		return inele
	# picioarele: coapsele înainte pe scaun, gambele în jos, pantofii
	for k in (-1, 1):
		sold, genunchi, glezna = (0.1 * k, 0.0, z0 + 0.06 * h), (0.115 * k, -0.42, z0 + 0.06 * h), (0.12 * k, -0.47, 0.09)
		piese.append(trunchi("Coapsa", [(sold, 0.088, 0.085), (genunchi, 0.07, 0.068)], pant, laturi=8, ref=(0, 0, 1)))
		piese.append(sfera("Genunchi", 0.072, genunchi, pant, segmente=8, inele=5))
		piese.append(trunchi("Gamba", [(genunchi, 0.066, 0.066), (glezna, 0.052, 0.05)], pant if not fem else s["piele"], laturi=8, ref=(0, 0, 1)))
		if fem:  # pantofi cu toc
			piese.append(trunchi("Pantof", [((0.12 * k, -0.47, 0.07), 0.04, 0.04), ((0.12 * k, -0.56, 0.03), 0.04, 0.025),
				((0.12 * k, -0.6, 0.015), 0.0, 0.0)], pantofi, laturi=6))
			piese.append(cub("Toc", (0.015, 0.015, 0.07), (0.12 * k, -0.45, 0.035), pantofi))
		else:
			piese.append(trunchi("Pantof", [((0.12 * k, -0.43, 0.045), 0.0, 0.0), ((0.12 * k, -0.44, 0.05), 0.05, 0.045),
				((0.12 * k, -0.55, 0.04), 0.052, 0.035), ((0.12 * k, -0.62, 0.03), 0.0, 0.0)], pantofi, laturi=8))
			piese.append(cub("Talpa", (0.1, 0.2, 0.014), (0.12 * k, -0.53, 0.007), NEGRU if pantofi != NEGRU else p("48313b")))
	return inele


def om(cale, nume, s, saminta):
	"""Un om așezat la masă (sau la tejghea): `s` = stilul (culori, păr, pălărie, haine), vezi OAMENI."""
	curata()
	r = random.Random(saminta)
	z0 = s.get("sezut", 0.48)
	masa = s.get("masa", 0.77)
	corp, picioare = [], []
	_tors(corp, z0, s, picioare)
	ob_corp = uneste(corp, "Corp", (0, 0.03, z0 + 0.06))
	if picioare:
		uneste(picioare, "Picioare")

	# capul (originea în gât)
	gat = (0, 0.015, z0 + 0.665)
	cap = []
	_cap(cap, gat, s, r)
	ob_cap = uneste(cap, "Cap", gat)
	ob_cap.scale = (1.12, 1.12, 1.12)  # capul puțin mai mare: la 480x270 fețele mici nu se citesc
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	_parinte(ob_cap, ob_corp)

	# brațele, pe masă: cotul sprijinit SUS pe bordura capitonată (la masa de poker e la 0,36…0,40 m în fața omului și
	# urcă la 0,10 peste postav), palma pe postav, dincolo de bordură; așa antebrațul trece peste ea, nu prin ea.
	# La tejgheaua bătrânei (`masa` dat, fără bordură) cotul stă pe blat.
	gros = s.get("gros_brat", 1.0)
	bordura = "masa" not in s
	for k, l in ((-1, "D"), (1, "S")):
		umar = (0.19 * k, 0.01, z0 + 0.555)
		if bordura:
			cot = (0.24 * k, -0.38, masa + 0.12 + 0.05 * gros)
			inch = (0.11 * k, -0.62, masa + 0.035)
		else:
			cot = (0.24 * k, -0.27, masa + 0.045)
			inch = (0.11 * k, -0.52, masa + 0.03)
		if s.get("poza_" + l):  # altă poză de repaus pentru brațul ăsta
			cot, inch = s["poza_" + l]
		brat, antebrat = [], []
		_brat(brat, antebrat, umar, cot, inch, s, l)
		directie = _norm(_scade(inch, cot))
		mana_pt = _mana(antebrat, inch, (directie[0], directie[1], 0.0), s, strans=s.get("tigara") is not None and l == "D")
		ob_brat = uneste(brat, "Brat" + l, umar)
		_parinte(ob_brat, ob_corp)
		ob_antebrat = uneste(antebrat, "Antebrat" + l, cot)
		_parinte(ob_antebrat, ob_brat)
		_punct("Mana", mana_pt, ob_antebrat)
		if l == "D" and s.get("tigara"):
			# țigara / trabucul între degete, cu vârful aprins (`Jar`, strălucește în joc)
			trabuc = s["tigara"] == "trabuc"
			lung, raza = (0.1, 0.01) if trabuc else (0.075, 0.0045)
			d = (directie[0], directie[1], 0.0)
			a = _add(mana_pt, (-d[1] * 0.02 * k, d[0] * 0.02 * k, 0.005))
			b = _add(a, (d[0] * lung * 0.7 - d[1] * lung * 0.7 * k, d[1] * lung * 0.7 + d[0] * lung * 0.7 * k, 0.01))
			ob_t = uneste([os_intre("Tigara", a, b, raza, p("5e363e") if trabuc else ALB, laturi=6),
				os_intre("Filtru", a, _lerp(a, b, 0.25), raza * 1.05, p("a56850") if not trabuc else p("7b383a"), laturi=6)], "Tigara", a)
			_parinte(ob_t, ob_antebrat)
			ob_jar = uneste([os_intre("Jar", b, _add(b, tuple((bb - aa) * 0.06 for aa, bb in zip(a, b))), raza * 1.02,
				p("904a40"), laturi=6)], "Jar", b)
			_parinte(ob_jar, ob_t)
	exporta(os.path.join(cale, nume + ".glb"))


# Stilurile: 5 jucători (2 fumează: „Don”-ul cu trabucul și slăbănogul) + bătrâna de la casă.
OAMENI = {
	# „Don”-ul: gras, costum în dungi, fedora, trabuc, inele de aur, mustață căruntă
	"jucator_poker_1": ({
		"piele": p("a56850"), "piele_umbra": p("904a40"), "haina": p("2a3c3d"), "haina_umbra": p("262d2f"), "camasa": ALB,
		"cravata": p("7b383a"), "dungi": p("6f6d7f"), "pantaloni": p("2a3c3d"), "par": p("7e8d87"), "stil_par": "chel",
		"palarie": "fedora", "culoare_palarie": p("262d2f"), "culoare_palarie_umbra": p("2a3c3d"), "banda": p("7b383a"),
		"mustata": p("7e8d87"), "gras": 0.8, "burta": 1.0, "gros_brat": 1.15, "tigara": "trabuc", "inele": AUR,
		"nas": 1.25, "nas_rosu": True, "incruntat": 0.3, "batista": p("7b383a"), "manseta": ALB, "riduri": True,
	}, 11),
	# slăbănogul cu geacă de piele, ochelari de soare, păr dat cu gel, lanț de aur, țigară
	"jucator_poker_2": ({
		"piele": p("a56850"), "piele_umbra": p("904a40"), "haina": p("262d2f"), "haina_umbra": p("2a3c3d"), "camasa": p("48313b"),
		"stil_haina": "geaca", "pantaloni": p("2a3c3d"), "par": p("262d2f"), "stil_par": "spate", "ochelari": "soare",
		"slab": 0.8, "lant": AUR, "tigara": "tigara", "tepi": p("48313b"), "gros_brat": 0.9, "pantofi": p("48313b"),
	}, 22),
	# bunicul: cardigan, șapcă de stofă, ochelari, țepi albi, aparat auditiv
	"jucator_poker_3": ({
		"piele": p("a56850"), "piele_umbra": p("904a40"), "haina": p("7a7b59"), "haina_umbra": p("5b6d4e"), "camasa": p("7e8d87"),
		"stil_haina": "pulover", "nasturi": p("48313b"), "pantaloni": p("5e5356"), "par": p("83b3b0"), "stil_par": "chel",
		"palarie": "sapca", "culoare_palarie": p("5e5356"), "culoare_palarie_umbra": p("48313b"), "ochelari": "vedere",
		"rama": p("48313b"), "tepi": p("7e8d87"), "slab": 0.5, "riduri": True, "aparat_auditiv": True, "spranceana": 0.01,
		"pantofi": p("48313b"),
	}, 33),
	# femeia: rochie roșie, păr buclat, perle, cercei, ruj
	"jucator_poker_4": ({
		"piele": p("a56850"), "piele_umbra": p("904a40"), "haina": p("7b383a"), "haina_umbra": p("5e363e"), "camasa": p("7b383a"),
		"stil_haina": "rochie", "brate_goale": True, "femeie": True, "par": p("a18463"), "par_suvita": p("a56850"),
		"stil_par": "voluminos", "lant": ALB, "cercei": AUR, "buze": p("7b383a"), "gura": p("5e363e"), "unghii": p("7b383a"),
		"pantofi": p("262d2f"), "gros_brat": 0.78, "inele": AUR, "spranceana": 0.012, "incruntat": -0.1,
	}, 44),
	# tânărul în trening cu dungi, cap ras, lanț cu medalion, țigară
	"jucator_poker_5": ({
		"piele": p("a56850"), "piele_umbra": p("904a40"), "haina": p("295555"), "haina_umbra": p("2a3c3d"), "camasa": ALB,
		"stil_haina": "trening", "dungi_maneca": ALB, "pantaloni": p("295555"), "par": p("48313b"), "stil_par": "ras",
		"lant": AUR, "medalion": True, "tepi": p("48313b"), "pantofi": ALB, "ceas": AUR,
	}, 55),
	# bătrâna de la casă: permanent cărunt, ochelari „ochi de pisică” pe lănțișor, cardigan, perle, ruj; stă pe un
	# scaun înalt, cu coatele pe tejghea (tejgheaua e mai înaltă decât masa de poker)
	"batrana_casino": ({
		"piele": p("a56850"), "piele_umbra": p("904a40"), "haina": p("904a40"), "haina_umbra": p("7b383a"), "camasa": p("83b3b0"),
		"stil_haina": "pulover", "nasturi": AUR, "pantaloni": p("5e5356"), "femeie": True, "par": p("83b3b0"),
		"par_suvita": p("7e8d87"), "stil_par": "permanent", "ochelari": "pisica", "rama": p("7b383a"), "lantisor_ochelari": True,
		"lant": ALB, "brosa": AUR, "buze": p("7b383a"), "gura": p("5e363e"), "riduri": True, "unghii": p("7b383a"),
		"inele": AUR, "sezut": 0.72, "masa": 1.06, "pantofi": p("48313b"), "gros_brat": 0.85, "spranceana": 0.015,
	}, 66),
}


def toate(cale):
	for nume, (s, saminta) in OAMENI.items():
		om(cale, nume, s, saminta)
