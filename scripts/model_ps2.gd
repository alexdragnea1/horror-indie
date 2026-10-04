class_name ModelPS2
extends Node3D
## Pune-l pe un model .glb adus în scenă (din tools/blender/modele.py):
## dă materialul PS2 tuturor bucăților lui. Culorile vin din model,
## iar textura din material adaugă murdăria / granulația.

## Materialul pus pe toate bucățile (de obicei shaders/material_model.tres).
@export var material: ShaderMaterial
## Debifează la obiecte care nu trebuie să arunce umbră (ex. becul, că lumina e în el).
@export var umbre := true
## Bucățile care strălucesc mereu (după nume, ex. "Glob"), fără lumină care să le aprindă.
@export var stralucitoare: PackedStringArray = []
## Cât de tare strălucesc bucățile de mai sus.
@export var stralucire := 1.0
## Bucățile de sticlă: cele al căror nume începe cu asta (ex. "Geam") devin transparente.
## Gol = nicio bucată de sticlă.
@export var sticla := ""
## Coliziune făcută din mărimea modelului (pentru modele puse fără StaticBody): Cilindru = pietre,
## Cutie = bușteni, cruci, lăzi; Plasa = exact forma lui (casa lui Lexy, mobila: pereți, trepte, verandă).
## Vezi ColiziuneModel.
@export_enum("Fara", "Cilindru", "Cutie", "Plasa") var coliziune := 0

const MATERIAL_STICLA := preload("res://shaders/material_sticla.tres")


func _ready() -> void:
	for nod in find_children("*", "MeshInstance3D", true, false):
		var mesh := nod as MeshInstance3D
		if material:
			mesh.material_override = material
		if not umbre:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh.name in stralucitoare:
			mesh.set_instance_shader_parameter("stralucire", stralucire)
		if sticla != "" and String(mesh.name).begins_with(sticla):
			mesh.material_override = MATERIAL_STICLA
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if coliziune == 3:
		ColiziuneModel.plasa(self)
	elif coliziune > 0:
		ColiziuneModel.pentru_nod(self, coliziune == 1)


## Face să dispară (pe pixeli, vezi `disparitie` în ps2.gdshader) toate bucățile de sub `nod`: 0 = întreg, 1 = dispărut.
## Merge pe orice model cu materialul PS2 (de pus în tween_method).
static func disparitie(nod: Node, valoare: float) -> void:
	for mesh in nod.find_children("*", "GeometryInstance3D", true, false):
		(mesh as GeometryInstance3D).set_instance_shader_parameter("disparitie", valoare)
	if nod is GeometryInstance3D:
		(nod as GeometryInstance3D).set_instance_shader_parameter("disparitie", valoare)
