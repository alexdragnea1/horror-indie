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


func _ready() -> void:
	for nod in find_children("*", "MeshInstance3D", true, false):
		var mesh := nod as MeshInstance3D
		if material:
			mesh.material_override = material
		if not umbre:
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mesh.name in stralucitoare:
			mesh.set_instance_shader_parameter("stralucire", stralucire)
