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


def uneste(piese, nume, origine=(0, 0, 0)):
	"""Lipește piesele într-un singur obiect. Originea = punctul în jurul căruia se rotește în joc."""
	bpy.ops.object.select_all(action='DESELECT')
	for p in piese:
		p.select_set(True)
	bpy.context.view_layer.objects.active = piese[0]
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
