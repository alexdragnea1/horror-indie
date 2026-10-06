extends Personaj
## Helga, profesoara de vrăji, în camera din dreapta de sus a conacului (conac_interior.tscn, nodul `Helga`).
## La E: `replici` (până la „I will be teaching you Fireball.”), apoi lecția, cu benzi negre:
##   1. te duce lângă ea (`loc_lectie`); ea se întoarce spre manechin, ridică brațul, în palmă îi crește o minge de foc
##      și o aruncă: zboară (te uiți după ea) și lovește manechinul, care se clatină;
##   2. `replici_explicatie` („Try to think about fire...”);
##   3. încerci și tu: îți ridici mâna (VrajaFoc, `demonstratie`), întâi doar scântei, apoi se aprinde un foc mic
##      și împingi palma: mingea ta, mai mică, lovește și ea manechinul;
##   4. `replici_final`; primești vraja („Fireball Spell”, VrajaFoc.ID) în inventar și în mână (`marcaj_lectie`).
## Cu inventarul plin (5 obiecte, fără vrajă), E nu pornește conversația: doar „Inventory full” (cerut de owner).
## După lecție nu mai are ce să-ți spună. Dacă vraja nu mai e în inventar, la E ți-o dă din nou.
## Replicile sunt ale owner-ului: nu le corecta.

@export var brat: Node3D
@export var palma: Node3D
@export var manechin: Node3D
@export var marcaj_lectie := "a_invatat_fireball"
## Unde stai cât ține lecția (în lume) și încotro te uiți (radiani, ca jucator.rotation.y).
@export var loc_lectie := Vector3(11.3, 3.6, -12.7)
@export var unghi_lectie := -PI / 2.0
## Cât își ridică brațul ca să arunce (radiani pe X; minus = înainte).
@export var ridicare_brat := -1.45

@export_group("Replici")
@export_multiline var replici_explicatie: PackedStringArray = []
@export_multiline var replici_final: PackedStringArray = []

const SUNET_APRINS := preload("res://sunete/minge_foc_aprinsa.ogg")
const SUNET_ARUNCA := preload("res://sunete/minge_foc_aruncata.ogg")
const SUNET_PRIMIT := preload("res://sunete/vraja_unda.ogg")

var _c: Cutscena


func _ready() -> void:
	super()
	indiciu = "[E] Talk to Helga"


func poate_fi_folosit() -> bool:
	if _vorbeste:
		return false
	return not Stare.e_marcat(marcaj_lectie) or not Stare.are_obiect(VrajaFoc.ID)


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	# inventarul plin: nici nu începe lecția (vraja n-ar avea unde să intre), doar scrie „Inventory full” (ca tomberonul)
	if Stare.obiecte.size() >= Stare.LOCURI_INVENTAR and not Stare.are_obiect(VrajaFoc.ID):
		Stare.adauga_obiect(VrajaFoc.ID, VrajaFoc.NUME)
		return
	_vorbeste = true
	folosit.emit()
	if Stare.e_marcat(marcaj_lectie):
		_da_vraja()
		_vorbeste = false
		return
	await intoarce_spre(_jucator()).finished
	Dialog.spune(replici)
	if Dialog.activ:
		await Dialog.terminat
	_c = Cutscena.porneste(self)
	await _lectia_ei()
	await _spune(replici_explicatie)
	await _incercarea_ta()
	var cap_ei: Vector3 = cap.global_position if cap else global_position + Vector3.UP * 1.6
	intoarce_spre(_jucator())
	await _c.priveste(cap_ei, 0.6)
	await _spune(replici_final)
	Stare.marcheaza(marcaj_lectie)
	_da_vraja()
	Stare.seteaza_sarcina("")
	_vorbeste = false
	await _c.opreste()


func _spune(linii: PackedStringArray) -> void:
	Dialog.spune(linii)
	if Dialog.activ:
		await Dialog.terminat


func _da_vraja() -> void:
	if Stare.adauga_obiect(VrajaFoc.ID, VrajaFoc.NUME):
		Stare.tine_in_mana(VrajaFoc.ID)
		Sunet.reda(SUNET_PRIMIT, Sunet.VOLUM_EFECTE - 4.0, 0.05)


func _tinta() -> Vector3:
	return manechin.global_position + Vector3.UP * 1.18


## Ea aruncă: se întoarce spre manechin, ridică brațul, focul îi crește în palmă, apoi îl aruncă.
func _lectia_ei() -> void:
	var jucator := _jucator() as CharacterBody3D
	var cap_jucator: Node3D = jucator.get_node("Cap")
	# te așază lângă ea, cu fața spre manechin
	var mers := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mers.tween_property(jucator, "global_position", loc_lectie, 0.9)
	mers.tween_property(jucator, "rotation:y", jucator.rotation.y + angle_difference(jucator.rotation.y, unghi_lectie), 0.9)
	mers.tween_property(cap_jucator, "rotation:x", -0.05, 0.9)
	var privire_dupa := distanta_privire
	distanta_privire = 0.0
	var spre := _tinta() - global_position
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "rotation:y", rotation.y + angle_difference(rotation.y, atan2(spre.x, spre.z)), 0.7)
	await mers.finished
	await _c.priveste(global_position + Vector3.UP * 1.3, 0.5)
	# ridică brațul spre manechin; în palmă se aprinde focul și crește
	var ridica := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ridica.tween_property(brat, "rotation", Vector3(ridicare_brat, 0.0, 0.1), 0.5)
	await ridica.finished
	var minge := MingeFoc.creeaza(palma, 1.0)
	minge.position = Vector3(0.0, -0.06, 0.04)
	minge.marime_vizibila = 0.0
	Sunet.reda_la(SUNET_APRINS, palma.global_position, Sunet.VOLUM_EFECTE, 0.05)
	_c.priveste(palma.global_position, 0.6)
	var creste := create_tween().set_trans(Tween.TRANS_SINE)
	creste.tween_property(minge, "marime_vizibila", 1.0, 1.1)
	await creste.finished
	await get_tree().create_timer(0.35).timeout
	# trage brațul puțin înapoi și îl aruncă înainte
	var arunca := create_tween().set_trans(Tween.TRANS_SINE)
	arunca.tween_property(brat, "rotation:x", ridicare_brat + 0.35, 0.22)
	arunca.tween_property(brat, "rotation:x", ridicare_brat - 0.2, 0.09)
	await get_tree().create_timer(0.27).timeout
	Sunet.reda_la(SUNET_ARUNCA, palma.global_position, Sunet.VOLUM_EFECTE, 0.05)
	minge.lanseaza(_tinta() - minge.global_position, [get_rid(), jucator.get_rid()])
	await _urmareste(minge)
	await get_tree().create_timer(0.6).timeout
	var coboara := create_tween().set_trans(Tween.TRANS_SINE)
	coboara.tween_property(brat, "rotation", Vector3.ZERO, 0.6)
	distanta_privire = privire_dupa
	intoarce_spre(jucator)
	await _c.priveste(cap.global_position if cap else global_position + Vector3.UP * 1.6, 0.6)


## Te uiți după minge până explodează (apoi la manechin).
func _urmareste(minge: MingeFoc) -> void:
	var gata := [false]
	minge.explodat.connect(func(_p: Vector3) -> void: gata[0] = true)
	while not gata[0] and is_instance_valid(minge):
		_c.priveste(minge.global_position.lerp(_tinta(), 0.35), 0.1)
		await get_tree().process_frame
	await _c.priveste(_tinta(), 0.25)


## Încerci și tu: mâna se ridică goală, „te gândești la foc” (scântei, apoi un foc mic) și împingi palma.
func _incercarea_ta() -> void:
	var jucator := _jucator()
	var vraja := jucator.get_node("Cap/Camera3D/VrajaFoc") as VrajaFoc
	await _c.priveste(_tinta() + Vector3.UP * 0.05, 0.6)
	vraja.stinge()
	VrajaFoc.demonstratie = true
	await get_tree().create_timer(0.8).timeout
	await vraja.aprinde(2.4)
	await get_tree().create_timer(0.45).timeout
	var minge: MingeFoc = await vraja.arunca_acum()
	var gata := [false]
	minge.explodat.connect(func(_p: Vector3) -> void: gata[0] = true)
	while not gata[0] and is_instance_valid(minge):
		await get_tree().process_frame
	await get_tree().create_timer(0.9).timeout
	VrajaFoc.demonstratie = false
	await get_tree().create_timer(0.3).timeout
