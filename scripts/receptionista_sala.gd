extends Interactabil
## Fata de la recepția sălii „Iron Pump” (sala.tscn, owner 25.11): în picioare după birou (OmLaMasa: respiră, se uită
## la tine, palmele pe birou).
## La E: „Girl: Hey, would you like a day pass?” cu Yes / No (replica e a owner-ului).
##  - No: doar se închide caseta (turnichetul rămâne închis, peretele invizibil din sala.gd).
##  - Yes: îți ia singură $5 din cash (`pret`): pui bancnota pe birou, ea o ia și o bagă în sertar, turnichetul se
##    deschide (Sala.da_pass). Dacă n-ai $5, nu-ți ia nimic: `replici_fara_bani` și rămâne închis.
## Cu pass-ul luat: `replici_are_pass`. Replicile în afară de întrebare sunt ale lui Claude (owner-ul le poate schimba).

@export var om: OmLaMasa
## Unde pui bancnota pe birou și unde o bagă ea (sertarul).
@export var plata: Marker3D
@export var sertar: Marker3D
@export var replica_intrebare := "Girl: Hey, would you like a day pass?"
@export var optiune_da := "Yes"
@export var optiune_nu := "No"
## Prețul, în dolari.
@export var pret := 5
@export_multiline var replici_platit: PackedStringArray = ["Girl: Here you go. Enjoy your workout!"]
@export_multiline var replici_fara_bani: PackedStringArray = ["Girl: It's five bucks, sweetie. Come back when you have it."]
@export_multiline var replici_are_pass: PackedStringArray = ["Girl: You're all set. Go get your pump."]

const SUNET_BANI := preload("res://sunete/bancnota.ogg")
const MODEL_BANCNOTA := preload("res://models/bancnota.glb")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")

var _in_curs := false


func _ready() -> void:
	indiciu = "[E] Talk to the receptionist"
	await get_tree().process_frame
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	if jucator and om:
		om.privire = jucator.get_node("Cap")


func poate_fi_folosit() -> bool:
	return activ and not _in_curs


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	if Sala.are_pass():
		await _spune(replici_are_pass)
		_in_curs = false
		return
	var ales := await Dialog.intreaba(replica_intrebare, PackedStringArray([optiune_da, optiune_nu]))
	if ales == 0:
		if Bani.suma() >= pret * 100:
			await _plateste()
		else:
			await _spune(replici_fara_bani)
	_in_curs = false


func _spune(replici: PackedStringArray) -> void:
	if replici.is_empty():
		return
	Dialog.spune(replici)
	if Dialog.activ:
		await Dialog.terminat


func _plateste() -> void:
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	var camera: Camera3D = jucator.get_node("Cap/Camera3D")
	var scena := get_tree().current_scene
	var c := Cutscena.porneste(self)
	await c.priveste(plata.global_position + Vector3.UP * 0.25, 0.45)
	# pui bancnota pe birou (banii ies din cash)
	var bancnota := MODEL_BANCNOTA.instantiate() as Node3D
	bancnota.set_script(SCRIPT_MODEL)
	bancnota.set("material", MATERIAL)
	bancnota.set("umbre", false)
	camera.add_child(bancnota)
	bancnota.position = Vector3(0.15, -0.4, -0.3)
	bancnota.reparent(scena, true)
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(bancnota, "global_transform", Transform3D(Basis(Vector3.UP, 0.25), plata.global_position + Vector3.UP * 0.003), 0.55)
	await t.finished
	Sunet.reda_la(SUNET_BANI, plata.global_position, Sunet.VOLUM_EFECTE - 1.0, 0.05)
	Bani.plateste(pret * 100)
	await get_tree().create_timer(0.25).timeout
	# ea o ia cu stânga și o bagă în sertar
	await om.du_mana("S", plata.global_position + Vector3.UP * 0.02, 0.5)
	bancnota.reparent(om.nod_mana("S"), true)
	Sunet.reda_la(SUNET_BANI, plata.global_position, Sunet.VOLUM_EFECTE - 4.0, 0.05)
	await om.du_mana("S", sertar.global_position, 0.5)
	bancnota.queue_free()
	om.lasa_mana("S", 0.5)
	Sala.da_pass()
	var sala := get_tree().get_first_node_in_group("sala")
	if sala:
		sala.deschide()
	await get_tree().create_timer(0.2).timeout
	await _spune(replici_platit)
	await c.opreste()
