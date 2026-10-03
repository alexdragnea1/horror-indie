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
