extends Interactabil
## Casiera de la „GENERAL STORE”, magazinul satului de lângă primărie (magazin_sat.tscn, pus în primarie.tscn; owner
## 17.11): în picioare după tejghea (animată de OmLaMasa: respiră, se uită la tine, mâinile cu IK).
## La E: „Clerk: What would you like?” cu Beer ($3), Cigarettes ($10) și Nothing; ce nu-ți permiți e gri.
## Vânzarea: scoate produsul de sub tejghea și îl pune pe blat, tu pui bancnota pe tejghea (banii ies din cash), ea o
## ia și o bagă în casa de marcat, „Have a nice day.”, iar tu iei produsul (intră în inventar).
## Berea o bei din mână la click (dispare); țigările: pachetul are 20 de folosiri (Tigari, ObiectInMana).
## Replicile în afară de întrebare sunt ale lui Claude (owner-ul le poate schimba).

## id → numele din inventar și prețul (dolari).
const PRODUSE := [
	{"id": "bere", "nume": "Beer", "pret": 3},
	{"id": "tigari", "nume": "Cigarettes", "pret": 10},
]
const SUNET_BANI := preload("res://sunete/bancnota.ogg")
const SUNET_STICLA := preload("res://sunete/bere_clinchet.ogg")
const SUNET_PACHET := preload("res://sunete/obiect_pus.ogg")
const MODEL_BANCNOTA := preload("res://models/bancnota.glb")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")

@export var om: OmLaMasa
## Unde pune produsul pe tejghea, unde pui tu banii și casa de marcat (unde bagă banii).
@export var pe_tejghea: Marker3D
@export var plata: Marker3D
@export var casa: Marker3D
@export var replica_intrebare := "Clerk: What would you like?"
@export var optiune_nimic := "Nothing"
@export_multiline var replici_dupa: PackedStringArray = ["Clerk: Have a nice day."]
@export_multiline var replici_are_bere: PackedStringArray = ["Clerk: You've still got one, honey."]
@export_multiline var replici_are_tigari: PackedStringArray = ["Clerk: Finish the pack you have first."]

var _in_curs := false


func _ready() -> void:
	indiciu = "[E] Talk to the clerk"
	await get_tree().process_frame
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	if jucator and om:
		om.privire = jucator.get_node("Cap")


func poate_fi_folosit() -> bool:
	return not _in_curs


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	var butoane := PackedStringArray()
	var gri := []
	for i in PRODUSE.size():
		butoane.append("%s - $%d" % [PRODUSE[i].nume, PRODUSE[i].pret])
		if Bani.suma() < int(PRODUSE[i].pret) * 100:
			gri.append(i)
	butoane.append(optiune_nimic)
	var ales := await Dialog.intreaba(replica_intrebare, butoane, gri)
	if ales < 0 or ales >= PRODUSE.size() or ales in gri:
		_in_curs = false
		return
	var produs: Dictionary = PRODUSE[ales]
	if Stare.are_obiect(produs.id):
		await _spune(replici_are_bere if produs.id == Tigari.ID_BERE else replici_are_tigari)
	elif Stare.obiecte.size() >= Stare.LOCURI_INVENTAR and Bani.suma() > int(produs.pret) * 100:
		# (dacă dai toți banii, locul lor din inventar se eliberează)
		Stare._arata_mesaj("Inventory full")
	else:
		await _vinde(produs)
	_in_curs = false


func _spune(replici: PackedStringArray) -> void:
	if replici.is_empty():
		return
	Dialog.spune(replici)
	if Dialog.activ:
		await Dialog.terminat


func _vinde(produs: Dictionary) -> void:
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	var camera: Camera3D = jucator.get_node("Cap/Camera3D")
	var scena := get_tree().current_scene
	var c := Cutscena.porneste(self)
	await c.priveste(pe_tejghea.global_position + Vector3.UP * 0.3, 0.5)
	# 1. îl scoate de sub tejghea cu mâna dreaptă și îl pune pe blat, în fața ta
	var obiect := ObiecteLume.model(produs.id)
	var sub := om.global_position + om.global_basis * Vector3(-0.22, 0.8, 0.12)
	await om.du_mana("D", sub, 0.45)
	om.nod_mana("D").add_child(obiect)
	obiect.position = Vector3.ZERO
	await om.du_mana("D", pe_tejghea.global_position + Vector3.UP * 0.03, 0.6)
	obiect.reparent(scena, true)
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(obiect, "global_transform", Transform3D(Basis(Vector3.UP, 0.4), pe_tejghea.global_position + Vector3.UP * 0.002), 0.15)
	Sunet.reda_la(SUNET_STICLA if produs.id == Tigari.ID_BERE else SUNET_PACHET, pe_tejghea.global_position, Sunet.VOLUM_EFECTE - 2.0, 0.05)
	om.lasa_mana("D", 0.5)
	await get_tree().create_timer(0.3).timeout
	# 2. tu pui bancnota pe tejghea (banii ies din cash)
	var bancnota := _bancnota()
	camera.add_child(bancnota)
	bancnota.position = Vector3(0.15, -0.4, -0.3)
	bancnota.reparent(scena, true)
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(bancnota, "global_transform", Transform3D(Basis(Vector3.UP, -0.3), plata.global_position + Vector3.UP * 0.003), 0.55)
	await t.finished
	Sunet.reda_la(SUNET_BANI, plata.global_position, Sunet.VOLUM_EFECTE - 1.0, 0.05)
	Bani.seteaza(Bani.suma() - int(produs.pret) * 100)
	await get_tree().create_timer(0.25).timeout
	# 3. ea ia bancnota cu stânga și o bagă în casa de marcat
	await om.du_mana("S", plata.global_position + Vector3.UP * 0.02, 0.5)
	bancnota.reparent(om.nod_mana("S"), true)
	Sunet.reda_la(SUNET_BANI, plata.global_position, Sunet.VOLUM_EFECTE - 4.0, 0.05)
	await om.du_mana("S", casa.global_position, 0.5)
	bancnota.queue_free()
	om.lasa_mana("S", 0.5)
	await get_tree().create_timer(0.2).timeout
	await _spune(replici_dupa)
	# 4. iei produsul: vine spre tine și intră în inventar
	obiect.reparent(camera, true)
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(obiect, "position", Vector3(0.2, -0.45, -0.15), 0.4)
	await t.finished
	obiect.queue_free()
	if produs.id == Tigari.ID:
		Tigari.pachet_nou()
	else:
		Stare.adauga_obiect(produs.id, produs.nume)
	await c.opreste()


func _bancnota() -> Node3D:
	var b := MODEL_BANCNOTA.instantiate() as Node3D
	b.set_script(SCRIPT_MODEL)
	b.set("material", MATERIAL)
	b.set("umbre", false)
	return b
