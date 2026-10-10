class_name JocBar
extends Interactabil
## Baza pentru jucătorii de la barul „URBAN” (Big Mike la darts, `darts_bar.gd`; Fast Eddie la biliard,
## `biliard_bar.gd`): pariul, plecarea din joc și moartea.
##  - E → `replica_oferta` cu mizele (doar cele pe care le ai în cash) + `optiune_refuz`; pariezi → `_joaca()` (în
##    clasa copil). Câștigi → primești miza (`marcaj_castig`); pierzi → o plătești (`marcaj_pierdut`).
##  - În timpul jocului, E = pleci (owner, 10.10): se socotește că ai pierdut (`replici_parasit`, plătești miza). Clasa
##    copil verifică `_parasit` după fiecare pas al jocului și iese; `_la_parasire()` îi deblochează așteptările.
##  - După ce ai pierdut la el (sau ai plecat), îl poți omorî cu orice armă (owner, 10.10): cade ca un ragdoll
##    (`marcaj_mort`), apoi îl iei cu E în inventar (`id_cadavru`, `marcaj_luat`). Înainte doar tresare.
##  - `_teleporteaza_om`: dispare pe pixeli și apare în alt loc (Eddie, owner 10.10: mersul în jurul mesei trecea prin ea).

const SUNET_BANI := preload("res://sunete/bancnota.ogg")
const SUNET_CARNE := preload("res://sunete/cutit_carne.ogg")
const SUNET_CADERE := preload("res://sunete/corp_cazut.ogg")
const SUNET_PASI := [preload("res://sunete/pas_lemn_1.ogg"), preload("res://sunete/pas_lemn_2.ogg"), preload("res://sunete/pas_lemn_3.ogg")]

@export var om: OmLaMasa
@export var nume_el := ""
@export var mize: PackedInt32Array = [10, 20, 50, 100]
@export var marcaj_castig := ""
## Ai pierdut la el (sau ai plecat din joc): de atunci e omorâbil.
@export var marcaj_pierdut := ""
@export var marcaj_mort := ""
@export var marcaj_luat := ""
@export var id_cadavru := ""
@export var nume_cadavru := ""
@export var indiciu_cadavru := ""
## Cât de tare îl împinge glonțul când moare.
@export var forta_glont := 9.0

@export_group("Replici")
@export var replica_oferta := ""
@export var optiune_refuz := "Nah"
@export_multiline var replici_fara_bani: PackedStringArray = []
@export_multiline var replici_reguli: PackedStringArray = []
@export_multiline var replici_refuz: PackedStringArray = []
@export_multiline var replici_castigi: PackedStringArray = []
@export_multiline var replici_pierzi: PackedStringArray = []
## Ai apăsat E în timpul jocului (a lui Claude).
@export_multiline var replici_parasit: PackedStringArray = []

var _in_curs := false
var _jucator: CharacterBody3D
var _repaus_om: Transform3D
## Jocul rulează (E = pleci) / ai plecat.
var _joc_activ := false
var _parasit := false
var _pornit_la := 0
var _mort := false
var _cadavru: Ragdoll
var _hud_parasire: CanvasLayer


func _ready() -> void:
	indiciu = "[E] Talk to %s" % nume_el
	await get_tree().process_frame
	_jucator = get_tree().get_first_node_in_group("jucator") as CharacterBody3D
	if _jucator and om:
		om.privire = _jucator.get_node("Cap")
	_repaus_om = om.transform
	var tinta := TintaOm.adauga(om)
	if tinta:
		tinta.stapan = self
	if Stare.e_marcat(marcaj_luat):
		_mort = true
		om.hide()
		om.set_process(false)
		_opreste_formele()
	elif Stare.e_marcat(marcaj_mort):
		_moare(Vector3.ZERO, 0.0)


func poate_fi_folosit() -> bool:
	return not _in_curs and not _mort and _jucator != null


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	var posibile: Array[int] = []
	for m in mize:
		if Bani.suma() >= m * 100:
			posibile.append(m)
	if posibile.is_empty():
		await _spune(replici_fara_bani)
		_in_curs = false
		return
	var butoane := PackedStringArray()
	for m in posibile:
		butoane.append("$%d" % m)
	butoane.append(optiune_refuz)
	var i := await Dialog.intreaba(replica_oferta, butoane)
	if i < 0 or i >= posibile.size():
		await _spune(replici_refuz)
		_in_curs = false
		return
	var miza: int = posibile[i]
	await _spune(replici_reguli)
	_parasit = false
	_joc_activ = true
	_pornit_la = Time.get_ticks_msec()
	_arata_parasire(true)
	var castigat: bool = await _joaca()
	_joc_activ = false
	_arata_parasire(false)
	if _parasit:
		await _spune(replici_parasit)
		castigat = false
	elif castigat:
		await _spune(replici_castigi)
	else:
		await _spune(replici_pierzi)
	if castigat:
		Bani.adauga(miza * 100)
		Stare.marcheaza(marcaj_castig)
	else:
		Bani.plateste(mini(miza * 100, Bani.suma()))
		Stare.marcheaza(marcaj_pierdut)
	Sunet.reda(SUNET_BANI, Sunet.VOLUM_EFECTE - 2.0, 0.05)
	_in_curs = false


## Clasa copil: jocul propriu-zis. Întoarce adevărat dacă ai câștigat.
func _joaca() -> bool:
	return false


## Clasa copil: deblochează ce așteaptă jocul acum (click-ul de aruncat / de tras), ca să vadă `_parasit`.
func _la_parasire() -> void:
	pass


func _input(event: InputEvent) -> void:
	if not _joc_activ or _parasit or Dialog.activ or not event.is_action_pressed("interact"):
		return
	if Time.get_ticks_msec() - _pornit_la < 400:
		return  # (E-ul cu care ai închis regulile)
	get_viewport().set_input_as_handled()
	_parasit = true
	if _hud_parasire:
		(_hud_parasire.get_child(0) as Label).text = "Leaving..."
	_la_parasire()


## „[E] Leave” în colțul din dreapta sus, cât ține jocul.
func _arata_parasire(arata: bool) -> void:
	if not arata:
		if _hud_parasire:
			_hud_parasire.queue_free()
			_hud_parasire = null
		return
	_hud_parasire = CanvasLayer.new()
	_hud_parasire.layer = 8
	add_child(_hud_parasire)
	var l := Label.new()
	l.text = "[E] Leave"
	l.theme = TemaMeniu.creeaza()
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Color("7e8d87"))
	l.add_theme_color_override("font_outline_color", Color("262d2f"))
	l.add_theme_constant_override("outline_size", 3)
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l.offset_right = -8
	l.offset_top = 6
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_parasire.add_child(l)


# ---------------------------------------------------------------- moartea

## Hitbox-ul de pe trunchi / cap (TintaOm.stapan): moare doar după ce ai pierdut la el și nu jucați acum.
func lovit_om(directie: Vector3, _punct: Vector3) -> bool:
	if _mort or _in_curs or not Stare.e_marcat(marcaj_pierdut):
		return false
	_moare(directie, forta_glont)
	return true


## Capsula lui (ce te oprește când mergi): ca hitbox-ul.
func impuscat(directie: Vector3, punct := Vector3.ZERO) -> void:
	if _mort:
		return
	if not lovit_om(directie, punct):
		om.tresare(directie)
		Sunet.reda_la(SUNET_CARNE, punct if punct != Vector3.ZERO else om.global_position + Vector3.UP * 1.2, Sunet.VOLUM_EFECTE, 0.1)


func lovit_de_foc(directie: Vector3, punct := Vector3.ZERO) -> void:
	impuscat(directie, punct)


## Cade moale pe spate (ragdoll), iar după ce se oprește îl poți lua cu E. Ca Personaj.omoara.
func _moare(directie: Vector3, forta: float) -> void:
	_mort = true
	Stare.marcheaza(marcaj_mort)
	om.set_process(false)
	om.privire = null
	_opreste_formele()
	var spate := -om.global_basis.z  # modelele privesc spre +Z
	var orizontal := Vector3(directie.x, 0.0, directie.z).normalized()
	var impuls := (spate * 0.7 + orizontal * 0.3 + Vector3.UP * 0.15).normalized() * forta
	_cadavru = Ragdoll.din_model(om.get_node("Model"), impuls, [], 30.0)
	if forta > 0.0:
		await get_tree().create_timer(0.45).timeout
		if is_instance_valid(_cadavru):
			Sunet.reda_la(SUNET_CADERE, _cadavru.centru(), Sunet.VOLUM_EFECTE, 0.05)
	var asteptat := 0.0
	while is_instance_valid(_cadavru) and asteptat < 3.0 and not (asteptat > 0.6 and _cadavru.s_a_oprit()):
		await get_tree().create_timer(0.2).timeout
		asteptat += 0.2
	if is_instance_valid(_cadavru) and id_cadavru != "":
		_cadavru.pune_ridicare(id_cadavru, nume_cadavru, indiciu_cadavru).folosit.connect(_luat)


func _luat() -> void:
	Stare.marcheaza(marcaj_luat)
	if is_instance_valid(_cadavru):
		_cadavru.queue_free()


## Capsula lui și hitbox-ul de pe trunchi / cap nu mai opresc nimic.
func _opreste_formele() -> void:
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", true)
	var hitbox := om.get_node_or_null("Hitbox")
	if hitbox:
		hitbox.queue_free()


# ---------------------------------------------------------------- unelte

## Merge (alunecă, cu un mic legănat și pașii) până la `unde` (transform în coordonatele părintelui lui `om`).
func _mergi_om(unde: Transform3D, durata: float) -> void:
	var de_la := om.transform
	var pasi := 4
	var misca := func(v: float) -> void:
		var tr := de_la.interpolate_with(unde, v)
		tr.origin += Vector3.UP * absf(sin(v * PI * pasi)) * 0.02
		om.transform = tr
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(misca, 0.0, 1.0, durata)
	for i in pasi:
		Sunet.reda_la(SUNET_PASI[i % SUNET_PASI.size()], om.global_position, Sunet.VOLUM_PASI - 3.0, 0.1)
		await get_tree().create_timer(durata / pasi).timeout
	if t.is_running():
		await t.finished


## Dispare pe pixeli (ModelPS2.disparitie) și apare la `unde` (transform în coordonatele părintelui lui `om`).
func _teleporteaza_om(unde: Transform3D, durata := 0.25) -> void:
	var model := om.get_node("Model")
	var t := create_tween()
	t.tween_method(func(v: float) -> void: ModelPS2.disparitie(model, v), 0.0, 1.0, durata)
	await t.finished
	om.transform = unde
	await get_tree().create_timer(0.08).timeout
	t = create_tween()
	t.tween_method(func(v: float) -> void: ModelPS2.disparitie(model, v), 1.0, 0.0, durata)
	await t.finished


func _spune(replici: PackedStringArray) -> void:
	if replici.is_empty():
		return
	Dialog.spune(replici)
	if Dialog.activ:
		await Dialog.terminat


func _asteapta(secunde: float) -> void:
	await get_tree().create_timer(secunde).timeout
