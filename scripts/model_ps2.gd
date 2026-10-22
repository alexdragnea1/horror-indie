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
## Bucăți cu alt material decât `material` (după nume → ShaderMaterial), pentru culori din afara paletei. Ex. pe
## `Cladire` din motel.tscn: „GraffitiRoz” → material_roz.tres (graffiti-ul roz, owner 22.10).
@export var materiale: Dictionary = {}
## Bucățile de sticlă: cele al căror nume începe cu asta (ex. "Geam") devin transparente.
## Gol = nicio bucată de sticlă.
@export var sticla := ""
## Pe ce straturi de randare stau bucățile (luminile aleg ce straturi luminează). Subsolul conacului e pe stratul 2,
## ca torțele de acolo (care luminează doar stratul 2) să nu treacă prin podea în sală.
@export_flags_3d_render var straturi := 1
## Coliziune făcută din mărimea modelului (pentru modele puse fără StaticBody): Cilindru = pietre,
## Cutie = bușteni, cruci, lăzi; Plasa = exact forma lui (casa lui Lexy, mobila: pereți, trepte, verandă).
## Vezi ColiziuneModel.
@export_enum("Fara", "Cilindru", "Cutie", "Plasa") var coliziune := 0

const MATERIAL_STICLA := preload("res://shaders/material_sticla.tres")


func _ready() -> void:
	# varianta family friendly (Stare.familie, vezi Limbaj): dacă lângă model e unul cu „_pg” (același model, dar fără
	# scrisul urât: panou_ocol_pg.glb, masa_pistol_pg.glb), îl punem pe ăla
	if Stare.familie and scene_file_path.ends_with(".glb"):
		var cale_pg := scene_file_path.get_basename() + "_pg.glb"
		if ResourceLoader.exists(cale_pg):
			_schimba_cu(load(cale_pg))
	for nod in find_children("*", "MeshInstance3D", true, false):
		var mesh := nod as MeshInstance3D
		if mesh.name == &"Coliziune":
			mesh.visible = false  # forma simplă pentru coliziune (din Blender), nu se vede niciodată
			continue
		if straturi != 1:
			mesh.layers = straturi
		if materiale.has(String(mesh.name)):
			mesh.material_override = materiale[String(mesh.name)]
		elif material:
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


## Bucățile din .glb (al căror owner e modelul) sunt înlocuite cu cele din `scena`; ce s-a pus peste în scenă
## (ex. lumina lumânării de pe MasaPistol) rămâne.
func _schimba_cu(scena: PackedScene) -> void:
	for copil in get_children():
		if copil.owner == self:
			remove_child(copil)
			copil.free()
	var nou := scena.instantiate()
	var bucati := nou.find_children("*", "", true, false)
	for bucata in bucati:
		bucata.owner = null  # altfel Godot se plânge că owner-ul (modelul _pg, care dispare) nu mai e deasupra lor
	for copil in nou.get_children():
		nou.remove_child(copil)
		add_child(copil)
	for bucata in bucati:
		bucata.owner = self
	nou.free()


## Face să dispară (pe pixeli, vezi `disparitie` în ps2.gdshader) toate bucățile de sub `nod`: 0 = întreg, 1 = dispărut.
## Merge pe orice model cu materialul PS2 (de pus în tween_method).
static func disparitie(nod: Node, valoare: float) -> void:
	for mesh in nod.find_children("*", "GeometryInstance3D", true, false):
		(mesh as GeometryInstance3D).set_instance_shader_parameter("disparitie", valoare)
	if nod is GeometryInstance3D:
		(nod as GeometryInstance3D).set_instance_shader_parameter("disparitie", valoare)
