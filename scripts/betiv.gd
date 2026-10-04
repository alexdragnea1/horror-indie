extends Personaj
## Bețivul de pe dealul din dreapta (scenes/betiv.tscn). La E (doar până vorbești cu vrăjitoarele,
## marcajul `marcaj_blocare`) spune `replici`, apoi întreabă `intrebare` cu butoanele `optiuni`:
##   - prima opțiune (Yes): îți întinde berea, o iei, bei din ea (animație la persoana întâi, înghițituri,
##     râgâit), apoi ești beat `durata_beat` secunde (EfectBeat). El își ia altă bere de pe jos.
##   - a doua (No): se termină conversația.
## Între timp dă din cap pe muzica boombox-ului (Boombox.ritm), se clatină și capul îi cade într-o parte.
## Cu pistolul roz (de la Head Witch) îl omori dintr-un glonț: cade pe spate ca un ragdoll, iar apoi îl iei în
## inventar cu E (`omorabil` și restul din grupul „Moarte” al Personaj, puse în betiv.tscn).

@export var marcaj_blocare := "a_vorbit_cu_vrajitoarele"
@export var intrebare := "Drunkard: You want a beer?"
@export var optiuni: PackedStringArray = ["Yes", "No"]
@export var boombox: Boombox
## Brațul cu berea (originea în umăr) și sticla din mâna lui.
@export var brat: Node3D
@export var sticla_mana: Node3D
## Cât își ridică brațul ca să-ți dea berea (radiani, pe X).
@export var ridicare_brat := -0.55
## Sticla pe care o ții tu în mână cât bei.
@export var sticla_jucator: PackedScene
@export var durata_beat := 5.0
## Nodul cu berile pline de pe jos: când îți dă una, își ia alta de aici (dispare de pe jos).
@export var sticle_pline: Node3D

@export_group("Sunete")
@export var sunet_clinchet: AudioStream
@export var sunet_inghititura: AudioStream
@export var sunet_ragait: AudioStream

const MATERIAL := preload("res://shaders/material_model.tres")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")

var _cap_baza := Vector3.ZERO
var _timp_dans := 0.0


func _ready() -> void:
	super()
	if cap:
		_cap_baza = cap.rotation


func poate_fi_folosit() -> bool:
	return super() and not Stare.e_marcat(marcaj_blocare)


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_vorbeste = true
	folosit.emit()
	Dialog.spune(replici)
	if Dialog.activ:
		await Dialog.terminat
	var raspuns := await Dialog.intreaba(intrebare, optiuni)
	if raspuns == 0:
		await _da_bere()
	_vorbeste = false


func _process(delta: float) -> void:
	if mort:
		return  # l-ai împușcat: acum e un ragdoll (vezi Personaj.omoara)
	super(delta)  # respiră + capul se uită după tine (rotation.y)
	var ritm := boombox.ritm if boombox else 0.0
	_timp_dans += delta * (1.0 + ritm * 0.6)
	if cap:
		# dă din cap pe bas și i se lasă capul într-o parte, ca unui om care adoarme
		var tinta_x := _cap_baza.x - 0.12 + ritm * 0.16 + sin(_timp_dans * 2.4) * 0.03
		var tinta_z := _cap_baza.z + sin(_timp_dans * 0.45) * 0.16
		cap.rotation.x = lerpf(cap.rotation.x, tinta_x, 1.0 - exp(-delta * 10.0))
		cap.rotation.z = lerpf(cap.rotation.z, tinta_z, 1.0 - exp(-delta * 3.0))
	if _model:
		# tot corpul se clatină încet
		_model.rotation.z = sin(_timp_dans * 0.6) * 0.035
		_model.rotation.x = sin(_timp_dans * 0.37) * 0.02


func _da_bere() -> void:
	var jucator := _jucator()
	if jucator == null:
		return
	Stare.meniu_deschis = true  # cât bei nu te miști și nu te uiți în jur
	# îți întinde sticla
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(brat, "rotation:x", ridicare_brat, 0.7)
	await tw.finished
	Sunet.reda_la(sunet_clinchet, sticla_mana.global_position, Sunet.VOLUM_EFECTE, 0.05)
	sticla_mana.hide()
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(brat, "rotation:x", 0.0, 0.9)

	# berea ta, în fața camerei
	var camera: Camera3D = jucator.get_node("Cap/Camera3D")
	var cap_jucator: Node3D = jucator.get_node("Cap")
	var sticla := sticla_jucator.instantiate() as Node3D
	sticla.set_script(SCRIPT_MODEL)
	sticla.set("material", MATERIAL)
	sticla.set("umbre", false)
	camera.add_child(sticla)
	sticla.position = Vector3(0.2, -0.45, -0.32)
	sticla.rotation = Vector3(0.25, 0.0, 0.2)
	var privire := cap_jucator.rotation.x
	# o ridici la gură
	tw = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tw.tween_property(sticla, "position", Vector3(0.1, -0.2, -0.38), 0.55)
	tw.tween_property(sticla, "rotation", Vector3(0.45, 0.0, 0.15), 0.55)
	tw.tween_property(cap_jucator, "rotation:x", 0.0, 0.55)
	await tw.finished
	# o dai peste cap: fundul sticlei sus, capul pe spate
	tw = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tw.tween_property(sticla, "position", Vector3(0.03, -0.02, -0.28), 0.45)
	tw.tween_property(sticla, "rotation", Vector3(1.95, 0.0, 0.05), 0.45)
	tw.tween_property(cap_jucator, "rotation:x", 0.5, 0.45)
	await tw.finished
	for i in 3:
		Sunet.reda(sunet_inghititura, Sunet.VOLUM_EFECTE, 0.08)
		# sticla tresare puțin la fiecare înghițitură
		tw = create_tween().set_trans(Tween.TRANS_SINE)
		tw.tween_property(sticla, "rotation:x", 2.05, 0.2)
		tw.tween_property(sticla, "rotation:x", 1.95, 0.35)
		await tw.finished
	# o lași jos
	tw = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tw.tween_property(sticla, "position", Vector3(0.22, -0.5, -0.3), 0.6)
	tw.tween_property(sticla, "rotation", Vector3(0.2, 0.0, 0.3), 0.6)
	tw.tween_property(cap_jucator, "rotation:x", privire, 0.7)
	await tw.finished
	sticla.queue_free()
	Sunet.reda(sunet_ragait, Sunet.VOLUM_EFECTE, 0.03)
	Stare.meniu_deschis = false
	EfectBeat.porneste(jucator, durata_beat)
	# el își ia altă bere de pe jos
	await get_tree().create_timer(1.5).timeout
	if sticle_pline:
		for s in sticle_pline.get_children():
			if s.visible:
				s.hide()
				break
	sticla_mana.show()
