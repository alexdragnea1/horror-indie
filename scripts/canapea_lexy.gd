extends Interactabil
## Canapeaua din livingul lui Lexy. Lexy stă pe locul din stânga (`loc_lexy`), fumează și se uită la știri (se uită
## la tine când ești aproape). „[E] Sit down” = scena de pe canapea (Cutscena):
##   te așezi lângă ea → `replici_inceput` → ți-l dă, tragi un fum, sufli, i-l dai înapoi (trage și ea) →
##   `replici_mijloc` → încă o dată → `replici_final` → îl stinge în scrumieră, se ridică și pleacă în bucătărie
##   (pe `drum_bucatarie`) → te ridici și tu. În bucătărie se așază pe `scaun_bucatarie` și mănâncă pizza.
## După asta (`marcaj_gata`, rămâne în salvare) e în bucătărie, la masă, iar jointul stins e în scrumieră.
## Coordonatele `loc_*` sunt în spațiul canapelei (fața ei spre +Z). Replicile sunt ale owner-ului: nu le corecta.

@export var lexy: Lexy
@export var scrumiera: Node3D
## Unde se uită Lexy cât stă pe canapea (ecranul televizorului).
@export var televizor: Node3D
## Punctele (copiii lui, în ordine) pe care merge Lexy până în spatele scaunului din bucătărie.
@export var drum_bucatarie: Node3D
## Scaunul ei din bucătărie: poziția (sub șolduri, la podea) și încotro privește (rotation.y).
@export var scaun_bucatarie: Node3D
@export var cutie_pizza: Node3D
@export var marcaj_gata := "a_fumat_cu_lexy"
@export var loc_lexy := Vector3(0.6, 0.0, 0.15)
@export var loc_jucator := Vector3(-0.6, 0.0, 0.05)
## Înălțimea ochilor tăi când stai pe canapea (față de podea).
@export var ochi_sezut := 1.1
@export var sunet_asezat: AudioStream
@export var sunet_stins: AudioStream

@export_group("Replici")
@export_multiline var replici_inceput: PackedStringArray = []
@export_multiline var replici_mijloc: PackedStringArray = []
@export_multiline var replici_final: PackedStringArray = []

const SUNET_TRAS := preload("res://sunete/fum_tras.ogg")
const SUNET_SUFLAT := preload("res://sunete/fum_suflat.ogg")
## Unde ții jointul în mână și unde îl duci la gură (față de cameră).
const IN_MANA := Vector3(0.11, -0.14, -0.3)
const LA_GURA := Vector3(0.012, -0.07, -0.085)

var _in_curs := false
var _jucator: CharacterBody3D
var _cap: Node3D
var _camera: Camera3D


func _ready() -> void:
	indiciu = "[E] Sit down"
	await get_tree().process_frame
	_jucator = get_tree().get_first_node_in_group("jucator") as CharacterBody3D
	if _jucator:
		_cap = _jucator.get_node("Cap")
		_camera = _cap.get_node("Camera3D")
	if Stare.e_marcat(marcaj_gata):
		# a fost: e la masă în bucătărie, iar jointul stins e în scrumieră
		lexy.global_position = scaun_bucatarie.global_position
		lexy.rotation.y = scaun_bucatarie.rotation.y
		lexy.sezut = 1.0
		var j := lexy.da_joint()
		await get_tree().process_frame
		lexy.stinge_jar()
		_pune_in_scrumiera(j, false)
		lexy.incepe_pizza(cutie_pizza.global_position)
		return
	lexy.global_position = to_global(loc_lexy)
	lexy.rotation.y = global_rotation.y
	lexy.sezut = 1.0
	lexy.da_joint()
	lexy.fumeaza = true


func _process(_delta: float) -> void:
	# pe canapea: se uită la televizor, dar când vii aproape se uită la tine
	if _in_curs or Stare.e_marcat(marcaj_gata) or _cap == null:
		return
	lexy.privire = _cap if _cap.global_position.distance_to(lexy.global_position) < 2.8 else televizor


func poate_fi_folosit() -> bool:
	return not _in_curs and not Stare.e_marcat(marcaj_gata)


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	var c := Cutscena.porneste(self)
	_jucator.velocity = Vector3.ZERO
	_jucator.seteaza_purtat(true)
	var ochi_in_picioare := _cap.position.y
	lexy.fumeaza = false
	while lexy.mana_ocupata("D"):
		await get_tree().process_frame
	# te duci în fața locului tău și te lași pe canapea, cu fața spre televizor
	var in_fata := to_global(loc_jucator + Vector3(0, 0, 0.65))
	await c.priveste(to_global(loc_jucator + Vector3(0, 0.45, 0)), 0.45)
	var t := _tween()
	t.tween_property(_jucator, "global_position", in_fata, 0.6)
	await t.finished
	t = _tween()
	t.tween_property(_jucator, "global_position", to_global(loc_jucator), 0.75)
	t.tween_property(_cap, "position:y", ochi_sezut, 0.75)
	t.tween_property(_jucator, "rotation:y", _jucator.rotation.y + angle_difference(_jucator.rotation.y, global_rotation.y + PI), 0.75)
	t.tween_property(_cap, "rotation:x", -0.1, 0.75)
	await get_tree().create_timer(0.5).timeout
	Sunet.reda_la(sunet_asezat, to_global(loc_jucator), Sunet.VOLUM_EFECTE, 0.05)
	await t.finished
	lexy.privire = _cap
	await c.priveste(lexy.gura() + Vector3.UP * 0.04, 0.6)
	await _spune(replici_inceput)
	await _paseaza(c)
	await _spune(replici_mijloc)
	await _paseaza(c)
	await _spune(replici_final)
	await _stinge(c)
	# se ridică și pleacă în bucătărie; o urmărești din ochi, apoi te ridici și tu
	lexy.privire = null
	await lexy.ridica_te()
	var drum: Array[Vector3] = []
	for punct in drum_bucatarie.get_children():
		drum.append((punct as Node3D).global_position)
	_la_bucatarie(drum)
	for i in 6:
		await c.priveste(lexy.global_position + Vector3.UP * 1.4, 0.35)
	t = _tween()
	t.tween_property(_cap, "position:y", ochi_in_picioare, 0.8)
	t.tween_property(_jucator, "global_position", in_fata, 0.8)
	await t.finished
	_jucator.seteaza_purtat(false)
	Stare.marcheaza(marcaj_gata)
	Stare.seteaza_sarcina("")
	await c.opreste()


func _la_bucatarie(drum: Array[Vector3]) -> void:
	await lexy.mergi(drum)
	await lexy.asaza_te(scaun_bucatarie.global_position, scaun_bucatarie.rotation.y)
	await get_tree().create_timer(0.6).timeout
	await lexy.incepe_pizza(cutie_pizza.global_position)


func _tween() -> Tween:
	return create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _spune(replici: PackedStringArray) -> void:
	if replici.is_empty():
		return
	Dialog.spune(replici)
	if Dialog.activ:
		await Dialog.terminat


## Unde își dau jointul: între voi, puțin în față și mai jos decât ochii.
func _predare() -> Vector3:
	var mijloc := (lexy.global_position + _jucator.global_position) * 0.5
	return Vector3(mijloc.x, _camera.global_position.y - 0.32, mijloc.z) + global_basis.z * 0.22


## Ți-l dă, tragi un fum, sufli și i-l dai înapoi; apoi trage și ea.
func _paseaza(c: Cutscena) -> void:
	var j := lexy.joint
	await c.priveste(_predare() + Vector3.UP * 0.12, 0.4)
	await lexy.du_mana("D", _predare(), 0.8)
	# trece în mâna ta (la persoana întâi): îl ții în dreapta jos
	j.reparent(_camera, true)
	lexy.lasa_mana("D", 0.7)
	var in_mana := Basis.from_euler(Vector3(0.35, PI / 2.0 + 0.55, 0.15))
	var la_gura := Basis.from_euler(Vector3(-0.1, PI / 2.0 + 0.05, 0.0))
	var t := _tween()
	t.tween_property(j, "position", IN_MANA, 0.5)
	t.tween_property(j, "basis", in_mana, 0.5)
	t.tween_property(_cap, "rotation:x", -0.05, 0.5)
	t.tween_property(_jucator, "rotation:y", _jucator.rotation.y + angle_difference(_jucator.rotation.y, global_rotation.y + PI), 0.5)
	await t.finished
	await get_tree().create_timer(0.35).timeout
	# la gură; tragi: jarul se aprinde, capul se dă puțin pe spate
	t = _tween()
	t.tween_property(j, "position", LA_GURA, 0.6)
	t.tween_property(j, "basis", la_gura, 0.6)
	await t.finished
	Sunet.reda(SUNET_TRAS, Sunet.VOLUM_EFECTE - 2.0, 0.03)
	t = create_tween()
	t.tween_method(lexy.jar, 0.0, 1.0, 0.7)
	t.parallel().tween_property(_cap, "rotation:x", 0.05, 1.2).set_trans(Tween.TRANS_SINE)
	t.tween_interval(0.5)
	t.tween_method(lexy.jar, 1.0, 0.0, 0.6)
	await get_tree().create_timer(1.3).timeout
	t = _tween()
	t.tween_property(j, "position", IN_MANA, 0.55)
	t.tween_property(j, "basis", in_mana, 0.55)
	await t.finished
	# ții fumul o clipă, apoi sufli (norul iese în fața ta și se ridică)
	await get_tree().create_timer(0.6).timeout
	Sunet.reda(SUNET_SUFLAT, Sunet.VOLUM_EFECTE - 2.0, 0.03)
	var fum := Lexy.fum(_camera, 1.0)
	fum.position = Vector3(0.0, -0.07, -0.24)
	fum.scale_amount_max = 1.7
	fum.direction = Vector3(0.0, 0.15, -1.0)
	fum.amount = 44
	fum.emitting = true
	fum.finished.connect(fum.queue_free)
	var cap_jos := create_tween().set_trans(Tween.TRANS_SINE)
	cap_jos.tween_property(_cap, "rotation:x", -0.08, 1.2)
	await get_tree().create_timer(1.6).timeout
	# i-l dai înapoi: mâna ta spre ea, mâna ei spre a ta
	await c.priveste(lexy.gura() + Vector3.UP * 0.04, 0.4)
	var predare := _predare()
	j.reparent(get_tree().current_scene, true)
	t = _tween()
	t.tween_property(j, "global_position", predare, 0.7)
	await get_tree().create_timer(0.1).timeout
	await lexy.du_mana("D", predare, 0.6)
	if t.is_running():  # (poate s-a terminat deja: un await pe un tween terminat ar aștepta la nesfârșit)
		await t.finished
	lexy.tine_in_mana(j, "D")
	await lexy.lasa_mana("D", 0.7)
	await get_tree().create_timer(0.4).timeout
	await lexy.trage_un_fum()
	await get_tree().create_timer(0.5).timeout


## Îl stinge în scrumieră: se apleacă, îl strivește (sfârâie, un fir de fum), îl lasă acolo și se lasă pe spate.
func _stinge(c: Cutscena) -> void:
	var j := lexy.joint
	var deasupra := scrumiera.global_position + Vector3.UP * 0.1
	c.priveste(scrumiera.global_position + Vector3.UP * 0.1, 0.8)
	lexy.privire = scrumiera
	lexy.apleaca(0.5, 0.8)
	await lexy.du_mana("D", deasupra, 0.9)
	await lexy.du_mana("D", scrumiera.global_position + Vector3.UP * 0.045, 0.25)
	Sunet.reda_la(sunet_stins, scrumiera.global_position, Sunet.VOLUM_EFECTE, 0.05)
	lexy.stinge_jar()
	var puf := Lexy.fum(get_tree().current_scene, 1.0)
	puf.global_position = scrumiera.global_position + Vector3.UP * 0.05
	puf.direction = Vector3.UP
	puf.amount = 16
	puf.initial_velocity_max = 0.25
	puf.emitting = true
	puf.finished.connect(puf.queue_free)
	# îl răsucește o dată, apeșat
	var t := create_tween()
	t.tween_property(j, "rotation:x", j.rotation.x + 1.2, 0.35)
	await t.finished
	_pune_in_scrumiera(j, true)
	await lexy.du_mana("D", deasupra, 0.25)
	lexy.lasa_mana("D", 0.7)
	await lexy.apleaca(0.0, 0.8)
	await get_tree().create_timer(0.4).timeout


## Jointul rămâne în scrumieră, culcat pe margine.
func _pune_in_scrumiera(j: Node3D, animat: bool) -> void:
	j.reparent(scrumiera, true)
	var loc := Vector3(-0.045, 0.04, 0.01)
	var rot := Basis.from_euler(Vector3(0.0, 0.5, -0.12))
	if animat:
		var t := _tween()
		t.tween_property(j, "position", loc, 0.3)
		t.tween_property(j, "basis", rot, 0.3)
	else:
		j.position = loc
		j.basis = rot
