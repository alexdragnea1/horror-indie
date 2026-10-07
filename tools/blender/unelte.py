# Funcții comune pentru scripturile de modele (rulate de Blender, nu de Godot).
# Fiecare piesă primește o singură culoare, pusă în "culorile vârfurilor" (atributul Col).
# În Godot, shader-ul ps2 înmulțește textura cu culoarea asta.
# Axe Blender: Z în sus, fața modelului spre -Y (în Godot devine +Z).
import os

import bpy
from mathutils import Vector

# Paleta jocului (owner-ul a ales-o): toate culorile modelelor vin DOAR de aici.
PALETA_CALE = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
	"textures", "paleta culori.hex")
with open(PALETA_CALE, encoding="utf-8") as f:
	PALETA = [r.strip().lower().lstrip("#") for r in f if r.strip()]


def p(cod):
	"""Culoare din paletă după codul hex ("7b383a"). Dacă nu e în paletă, oprește scriptul."""
	cod = cod.lower()
	if cod not in PALETA:
		raise ValueError("Culoarea %s nu e în paleta din %s" % (cod, PALETA_CALE))
	return tuple(int(cod[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def curata():
	bpy.ops.wm.read_factory_settings(use_empty=True)


def _coloreaza(ob, culoare):
	cod = "".join("%02x" % round(c * 255) for c in culoare[:3])
	if cod not in PALETA:
		raise ValueError("Piesa %s are culoarea %s, care nu e în paletă. Folosește p(\"...\")." % (ob.name, cod))
	me = ob.data
	attr = me.color_attributes.new(name="Col", type='BYTE_COLOR', domain='CORNER')
	for d in attr.data:
		d.color_srgb = (culoare[0], culoare[1], culoare[2], 1.0)
	me.color_attributes.active_color = attr
	me.color_attributes.render_color_index = 0


def _termina(ob, nume, culoare, scara=None):
	ob.name = nume
	if scara:
		ob.scale = (ob.scale[0] * scara[0], ob.scale[1] * scara[1], ob.scale[2] * scara[2])
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	_coloreaza(ob, culoare)
	return ob


def cub(nume, dim, loc, culoare, rot=(0, 0, 0)):
	bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
	ob = bpy.context.active_object
	ob.scale = dim
	return _termina(ob, nume, culoare)


def cilindru(nume, raza_jos, raza_sus, inaltime, loc, culoare, laturi=8, rot=(0, 0, 0), scara=None):
	bpy.ops.mesh.primitive_cone_add(vertices=laturi, radius1=raza_jos, radius2=raza_sus,
		depth=inaltime, location=loc, rotation=rot)
	return _termina(bpy.context.active_object, nume, culoare, scara)


def sfera(nume, raza, loc, culoare, scara=None, segmente=8, inele=6):
	bpy.ops.mesh.primitive_uv_sphere_add(segments=segmente, ring_count=inele, radius=raza, location=loc)
	return _termina(bpy.context.active_object, nume, culoare, scara)


def os_intre(nume, a, b, raza, culoare, laturi=6):
	"""Cilindru de la punctul a la punctul b (brațe, picioare)."""
	a = Vector(a)
	b = Vector(b)
	d = b - a
	rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_euler()
	return cilindru(nume, raza, raza * 0.9, d.length, (a + b) / 2, culoare, laturi, rot)


def sfera_deschisa(nume, raza, loc, culoare, z_taiere, grosime=0.03, scara=None, segmente=10, inele=8):
	"""Sferă cu capacul tăiat deasupra lui z_taiere și cu pereți groși (ceaun, vas).
	Grosimea face și fețele dinăuntru, altfel shader-ul (cull_back) nu le desenează."""
	import bmesh
	bpy.ops.mesh.primitive_uv_sphere_add(segments=segmente, ring_count=inele, radius=raza, location=loc)
	ob = bpy.context.active_object
	ob.name = nume
	if scara:
		ob.scale = scara
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	bm = bmesh.new()
	bm.from_mesh(ob.data)
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > z_taiere], context='VERTS')
	bm.to_mesh(ob.data)
	bm.free()
	mod = ob.modifiers.new("grosime", 'SOLIDIFY')
	mod.thickness = grosime
	bpy.ops.object.modifier_apply(modifier=mod.name)
	_coloreaza(ob, culoare)
	return ob


def inel(nume, raza, grosime, loc, culoare, segmente=12):
	"""Inel (tor) culcat: buza ceaunului, banda pălăriei."""
	bpy.ops.mesh.primitive_torus_add(major_segments=segmente, minor_segments=4,
		major_radius=raza, minor_radius=grosime, location=loc)
	return _termina(bpy.context.active_object, nume, culoare)


def linie(nume, a, b, latime, grosime, z, culoare):
	"""Bandă plată pe orizontală de la a=(x,y) la b=(x,y) (liniile pentagramei)."""
	import math
	dx, dy = b[0] - a[0], b[1] - a[1]
	return cub(nume, (math.hypot(dx, dy), latime, grosime), ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, z),
		culoare, rot=(0, 0, math.atan2(dy, dx)))


def text(nume, continut, loc, marime, culoare, rot=(1.5708, 0, 0)):
	"""Text 3D subțire. Implicit stă în picioare, cu fața spre -Y (fața modelului)."""
	bpy.ops.object.text_add(location=loc, rotation=rot)
	ob = bpy.context.active_object
	ob.data.body = continut
	ob.data.size = marime
	ob.data.extrude = 0.002
	ob.data.resolution_u = 1
	ob.data.align_x = 'CENTER'
	ob.data.align_y = 'CENTER'
	bpy.ops.object.convert(target='MESH')
	ob = bpy.context.active_object
	return _termina(ob, nume, culoare)


def uneste(piese, nume, origine=(0, 0, 0)):
	"""Lipește piesele într-un singur obiect. Originea = punctul în jurul căruia se rotește în joc."""
	verifica_fete(piese, nume)
	for ob in piese:
		_eticheteaza(ob)
	bpy.ops.object.select_all(action='DESELECT')
	for p in piese:
		p.select_set(True)
	bpy.context.view_layer.objects.active = piese[0]
	if len(piese) > 1:
		bpy.ops.object.join()
	ob = bpy.context.active_object
	ob.name = nume
	ob.data.name = nume
	bpy.context.scene.cursor.location = origine
	bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
	bpy.ops.object.shade_flat()
	return ob


def exporta(cale):
	for me in bpy.data.meshes:
		if ATRIBUT_PIESA in me.attributes:
			me.attributes.remove(me.attributes[ATRIBUT_PIESA])
	bpy.ops.object.select_all(action='SELECT')
	bpy.ops.export_scene.gltf(filepath=cale, export_format='GLB', use_selection=True,
		export_apply=True, export_yup=True)
	print("Exportat:", cale)


def trunchi(nume, inele, culoare, laturi=8, ref=(1, 0, 0), faza=0.0, capete=True):
	"""Formă organică din inele (lofting): inele = [(centru, rx, ry), ...], în ordine de-a lungul formei.
	Fiecare inel stă perpendicular pe drum; rx merge pe direcția `ref` (proiectată pe inel), ry pe cealaltă.
	Între inele direcția se „transportă” fără răsucire, deci drumul poate cotii (braț, baston, nas coroiat).
	Un inel cu rx = ry = 0 devine vârf. Bun pentru trunchi, haine, membre, fețe, nasuri."""
	import math
	import bmesh
	bm = bmesh.new()
	n = len(inele)
	centre = [Vector(i[0]) for i in inele]
	randuri = []
	u_prec = None
	for i, (_, rx, ry) in enumerate(inele):
		a, b = centre[max(i - 1, 0)], centre[min(i + 1, n - 1)]
		t = (b - a).normalized()
		u = Vector(ref) if u_prec is None else u_prec
		u = u - t * u.dot(t)
		if u.length < 1e-6:
			u = Vector((0, 0, 1)) - t * t.z
		u.normalize()
		u_prec = u
		v = t.cross(u)
		if rx < 1e-6 and ry < 1e-6:
			randuri.append([bm.verts.new(centre[i])])
			continue
		randuri.append([bm.verts.new(centre[i] + u * rx * math.cos(faza + 2 * math.pi * k / laturi)
			+ v * ry * math.sin(faza + 2 * math.pi * k / laturi)) for k in range(laturi)])
	for r0, r1 in zip(randuri, randuri[1:]):
		for k in range(laturi):
			if len(r0) == 1:
				bm.faces.new((r0[0], r1[k], r1[(k + 1) % laturi]))
			elif len(r1) == 1:
				bm.faces.new((r0[k], r0[(k + 1) % laturi], r1[0]))
			else:
				bm.faces.new((r0[k], r0[(k + 1) % laturi], r1[(k + 1) % laturi], r1[k]))
	if capete:
		for r in (randuri[0], randuri[-1]):
			if len(r) > 2:
				bm.faces.new(r)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	me = bpy.data.meshes.new(nume)
	bm.to_mesh(me)
	bm.free()
	ob = bpy.data.objects.new(nume, me)
	bpy.context.scene.collection.objects.link(ob)
	_coloreaza(ob, culoare)
	return ob


# Sub atâta (metri), două fețe paralele care se acoperă „se bat” pe ecran (z-fighting): textura pâlpâie
# și se rupe, mai ales de departe. Un detaliu lipit pe o suprafață (rugină, bandă, număr) trebuie să iasă
# în față cel puțin atât.
DISTANTA_MINIMA_FETE = 0.008


def _cutie(ob):
	"""(min, max) dacă piesa e o cutie aliniată pe axe (8 vârfuri, câte 2 valori pe axă), altfel None."""
	v = [ob.matrix_world @ x.co for x in ob.data.vertices]
	if len(v) != 8:
		return None
	mn, mx = [], []
	for a in range(3):
		valori = sorted({round(p[a], 5) for p in v})
		if len(valori) != 2:
			return None
		mn.append(valori[0])
		mx.append(valori[1])
	return mn, mx


def verifica_fete(piese, nume):
	"""Caută perechi de cutii cu fețe paralele, cu aceeași orientare, la mai puțin de
	DISTANTA_MINIMA_FETE una de alta și care se acoperă (z-fighting). Întoarce lista problemelor."""
	# sortate după X: două cutii cu fețe apropiate se suprapun pe toate axele (cu toleranța), deci pentru fiecare cutie
	# e de ajuns să le verifici pe cele care încep înainte să se termine ea pe X (altfel la mii de piese durează ore)
	cutii = sorted(((p.name, c) for p in piese for c in [_cutie(p)] if c), key=lambda t: t[1][0][0])
	probleme = []
	for i in range(len(cutii)):
		na, (amn, amx) = cutii[i]
		for j in range(i + 1, len(cutii)):
			nb, (bmn, bmx) = cutii[j]
			if bmn[0] > amx[0] + DISTANTA_MINIMA_FETE:
				break
			for a in range(3):
				b1, b2 = [k for k in range(3) if k != a]
				arie = (min(amx[b1], bmx[b1]) - max(amn[b1], bmn[b1])) * (min(amx[b2], bmx[b2]) - max(amn[b2], bmn[b2]))
				if min(amx[b1], bmx[b1]) - max(amn[b1], bmn[b1]) <= 0.001 or min(amx[b2], bmx[b2]) - max(amn[b2], bmn[b2]) <= 0.001:
					continue
				for fa, fb, semn in ((amx[a], bmx[a], "+"), (amn[a], bmn[a], "-")):
					if abs(fa - fb) < DISTANTA_MINIMA_FETE:
						probleme.append("%s: %s / %s, fețele %s%s la %.1f mm (arie %.3f m²)"
							% (nume, na, nb, semn, "xyz"[a], abs(fa - fb) * 1000, arie))
	for pr in probleme:
		print("FETE SUPRAPUSE", pr)
	return probleme


# ---------------------------------------------------------------------------------------------------------------
# Fețe lipite pe orice formă (nu doar cutii drepte): `desparte_fete`
# ---------------------------------------------------------------------------------------------------------------

# Fiecare piesă își ține numărul (și numele în PIESE) în fețele ei, ca să se poată recunoaște și după `uneste`.
# `exporta` îl scoate înainte să scrie .glb-ul.
ATRIBUT_PIESA = "piesa"
PIESE = []
# culoarea fiecărei piese: două bucăți din aceeași piesă, de aceeași culoare (bucățile unei crăpături, care se
# încalecă la încheieturi), nu se văd bătându-se pe ecran
CULORI_PIESE = []
# Cât de departe ajung să fie, după `desparte_fete`, două fețe care se acopereau. Mai mult decât DISTANTA_MINIMA_FETE:
# de sus, de pe mătură, sau de pe partea cealaltă a parcării, la 4–8 mm tot pâlpâie.
DISTANTA_DESPARTIRE = 0.015


def _eticheteaza(ob):
	if ob.type != 'MESH' or ATRIBUT_PIESA in ob.data.attributes:
		return
	PIESE.append(ob.name.split(".")[0])
	cul = ob.data.color_attributes.get("Col")
	CULORI_PIESE.append(tuple(round(c, 3) for c in cul.data[0].color) if cul and len(cul.data) else None)
	at = ob.data.attributes.new(ATRIBUT_PIESA, 'INT', 'FACE')
	at.data.foreach_set("value", [len(PIESE) - 1] * len(ob.data.polygons))


def _arie_2d(poli):
	return sum(poli[i - 1][0] * poli[i][1] - poli[i][0] * poli[i - 1][1] for i in range(len(poli))) / 2


def _taie(poli, a, b):
	"""Partea poligonului `poli` din stânga muchiei a→b (2D)."""
	ramas = []
	st = lambda q: (b[0] - a[0]) * (q[1] - a[1]) - (b[1] - a[1]) * (q[0] - a[0])
	for i in range(len(poli)):
		q, r = poli[i], poli[(i + 1) % len(poli)]
		sq, sr = st(q), st(r)
		if sq >= 0:
			ramas.append(q)
		if (sq >= 0) != (sr >= 0):
			t = sq / (sq - sr)
			ramas.append((q[0] + (r[0] - q[0]) * t, q[1] + (r[1] - q[1]) * t))
	return ramas


def _triunghiuri(obiecte):
	"""[(vârfuri în lume, normală, (obiect, piesă), arie)] pentru toate fețele obiectelor."""
	import bmesh
	tri = []
	for ob in obiecte:
		bm = bmesh.new()
		bm.from_mesh(ob.data)
		bm.transform(ob.matrix_world)
		strat = bm.faces.layers.int.get(ATRIBUT_PIESA)
		bmesh.ops.triangulate(bm, faces=bm.faces)
		for f in bm.faces:
			a = f.calc_area()
			if a > 1e-6:
				tri.append(([v.co.copy() for v in f.verts], f.normal.copy(), (ob.name, f[strat] if strat else -1), a))
		bm.free()
	return tri


def _fete_lipite(tri, prag, sub_ochi):
	"""Perechile de triunghiuri din piese diferite, aproape paralele, cu aceeași orientare, la mai puțin de `prag`
	și care se acoperă: [(i, j, abaterea medie a lui j față de planul lui i, pe normala lui i; aria comună)].
	Le lasă pe cele care nu se văd: fețele de dedesubt mai jos de `sub_ochi` și cele lipite de o față întoarsă invers
	(fundul unei pete pe podea, spatele unei plăci pe perete)."""
	import math
	from collections import defaultdict
	paralel = math.cos(math.radians(5))
	grila = defaultdict(list)
	for i, (v, n, piesa, a) in enumerate(tri):
		mn = [min(q[k] for q in v) for k in range(3)]
		mx = [max(q[k] for q in v) for k in range(3)]
		for x in range(math.floor(mn[0]), math.floor(mx[0]) + 1):
			for y in range(math.floor(mn[1]), math.floor(mx[1]) + 1):
				for z in range(math.floor(mn[2]), math.floor(mx[2]) + 1):
					grila[(x, y, z)].append(i)

	def acoperit(i):
		v, n, piesa, a = tri[i]
		c = sum(v, Vector()) / 3
		if n.z < -0.7 and c.z < sub_ochi:
			return True
		for j in grila[tuple(math.floor(k) for k in c)]:
			w, m, pj, _ = tri[j]
			if pj == piesa or n.dot(m) > -paralel or abs(m.dot(c - w[0])) > 0.002:
				continue
			# c în triunghiul j (coordonate baricentrice)
			e0, e1, e2 = w[1] - w[0], w[2] - w[0], c - w[0]
			d00, d01, d11, d20, d21 = e0.dot(e0), e0.dot(e1), e1.dot(e1), e2.dot(e0), e2.dot(e1)
			num = d00 * d11 - d01 * d01
			if num <= 0:
				continue
			b1 = (d11 * d20 - d01 * d21) / num
			b2 = (d00 * d21 - d01 * d20) / num
			if b1 >= -1e-4 and b2 >= -1e-4 and b1 + b2 <= 1 + 1e-4:
				return True
		return False

	ascuns = {}
	vazut = set()
	perechi = []
	for lista in grila.values():
		for k, i in enumerate(lista):
			vi, ni, pi, _ = tri[i]
			for j in lista[k + 1:]:
				vj, nj, pj, _ = tri[j]
				if pi == pj or ni.dot(nj) < paralel or (i, j) in vazut or _aceeasi_piesa(pi, pj):
					continue
				abateri = [ni.dot(q - vi[0]) for q in vj]
				if max(abs(d) for d in abateri) >= prag:
					continue
				vazut.add((i, j))
				u = (vi[1] - vi[0]).normalized()
				w = ni.cross(u)
				A = [((q - vi[0]).dot(u), (q - vi[0]).dot(w)) for q in vi]
				B = [((q - vi[0]).dot(u), (q - vi[0]).dot(w)) for q in vj]
				if _arie_2d(A) < 0:
					A.reverse()
				if _arie_2d(B) < 0:
					B.reverse()
				for m in range(3):
					B = _taie(B, A[m], A[(m + 1) % 3])
					if len(B) < 3:
						break
				if len(B) < 3 or abs(_arie_2d(B)) < 1e-4:
					continue
				for t in (i, j):
					if t not in ascuns:
						ascuns[t] = acoperit(t)
				if ascuns[i] or ascuns[j]:
					continue
				perechi.append((i, j, sum(abateri) / 3, abs(_arie_2d(B))))
	return perechi


def desparte_fete(obiecte=None, distanta=DISTANTA_DESPARTIRE, fixe=(), sub_ochi=1.0, pasi=12):
	"""Caută fețele care se bat pe ecran (z-fighting) între piesele lipite cu `uneste`, pe orice formă (plăci rotite,
	cilindri, text, prisme), și le desparte: piesa mai mică (pata, petecul, litera, scândura bătută peste alta) se
	mută pe normala feței până ajunge la `distanta` de cealaltă, în partea în care era deja (la egalitate: în față).
	Piesele cu numele în `fixe` (pereți, podele, asfaltul) nu se mută niciodată: se mută cealaltă. Fețele de dedesubt
	mai jos de `sub_ochi` nu contează (nu le vezi niciodată). Se repetă până nu mai rămâne nimic (o mutare poate lipi
	piesa de alta). De chemat înainte de `exporta`. Întoarce perechile pe care nu le-a putut despărți."""
	from collections import defaultdict
	if obiecte is None:
		obiecte = [ob for ob in bpy.data.objects if ob.type == 'MESH' and not ob.name.startswith("Coliziune")]
	obiect = {ob.name: ob for ob in obiecte}
	mutate = defaultdict(Vector)
	motiv = {}
	tri, perechi, ramase = [], [], []
	for pas in range(pasi):
		tri = _triunghiuri(obiecte)
		perechi = _fete_lipite(tri, distanta - 0.0005, sub_ochi)
		arii = defaultdict(float)
		for v, n, piesa, a in tri:
			arii[piesa] += a
		mobila = lambda piesa: piesa[1] >= 0 and PIESE[piesa[1]] not in fixe
		ramase = [t for t in perechi if not mobila(tri[t[0]][2]) and not mobila(tri[t[1]][2])]
		# o singură mutare pe piesă la fiecare pas (cea cu suprafața comună cea mai mare); restul, la pasul următor
		alese = {}
		for i, j, abatere, arie in sorted(perechi, key=lambda t: -t[3]):
			pi, pj = tri[i][2], tri[j][2]
			if not mobila(pi) and not mobila(pj):
				continue
			if not mobila(pj) or (mobila(pi) and arii[pi] < arii[pj]):
				piesa, alta, abatere = pi, pj, -abatere
			else:
				piesa, alta = pj, pi
			if piesa in alese:
				continue
			alese[piesa] = tri[i][1] * ((distanta if abatere >= 0 else -distanta) - abatere)
			motiv.setdefault(piesa, PIESE[alta[1]] if alta[1] >= 0 else alta[0])
		if not alese:
			break
		for (nume_ob, id_piesa), delta in alese.items():
			ob = obiect[nume_ob]
			local = ob.matrix_world.inverted().to_3x3() @ delta
			at = ob.data.attributes[ATRIBUT_PIESA].data
			for k in {k for f in ob.data.polygons if at[f.index].value == id_piesa for k in f.vertices}:
				ob.data.vertices[k].co += local
			mutate[(nume_ob, id_piesa)] += delta
	for piesa, d in sorted(mutate.items(), key=lambda t: -t[1].length):
		c = sum((v[0][0] for v in tri if v[2] == piesa), Vector()) / max(1, sum(1 for v in tri if v[2] == piesa))
		print("DESPARTIT %s (lângă %s, la %.1f %.1f %.1f) cu (%.0f, %.0f, %.0f) mm" % (PIESE[piesa[1]], motiv.get(piesa, "?"),
			c.x, c.y, c.z, d.x * 1000, d.y * 1000, d.z * 1000))
	for i, j, abatere, arie in ramase:
		c = tri[i][0][0]
		print("FETE LIPITE RAMASE %s / %s la (%.2f, %.2f, %.2f): %.1f mm, %.4f m²" % (PIESE[tri[i][2][1]], PIESE[tri[j][2][1]],
			c.x, c.y, c.z, abatere * 1000, arie))
	return ramase


def _aceeasi_piesa(a, b):
	"""Două bucăți cu același nume și aceeași culoare (ex. bucățile frânte ale unei crăpături)."""
	return a[1] >= 0 and b[1] >= 0 and PIESE[a[1]] == PIESE[b[1]] and CULORI_PIESE[a[1]] == CULORI_PIESE[b[1]]
