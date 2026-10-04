class_name Personaj
extends Interactabil
## Un personaj cu care vorbești (ex. Mom). În "replici" scrii fiecare rând cu numele în față:
##   MOM: Today is your birthday!
##   You: Ok...
## Când vorbești cu el se întoarce spre tine. Capul te urmărește cât ești aproape.

## Capul modelului (se rotește spre jucător). Opțional.
@export var cap: Node3D
## De la ce distanță începe să se uite după tine (metri).
@export var distanta_privire := 5.0
## Cât de mult își poate întoarce capul (grade).
@export var unghi_maxim_cap := 70.0
## Debifează la personajele care stau jos (ex. baba de pe bancă): atunci se uită doar cu capul.
@export var se_intoarce := true
## Cât de repede se întoarce spre tine când vorbiți (secunde).
@export var durata_intoarcere := 0.5

@export_group("După prima conversație")
## Marcajul pus în Stare după prima conversație (ex. "a_vorbit_cu_mom"; gol = niciunul).
@export var marcaj_dupa := ""
## Sarcina pe care o primești după prima conversație (apare sus câteva secunde; gol = niciuna).
@export var sarcina_noua := ""
## Ce spune când vorbești cu el a doua oară (gol = repetă "replici").
@export_multiline var replici_dupa: PackedStringArray = []

@export_group("Moarte")
## Bifat = îl omoară un glonț din pistol (cade moale pe spate, vezi Ragdoll). Doar pe cine a zis owner-ul
## (bețivul; vrăjitoarele din cerc au codul lor, în vrajitoare.gd); pe ceilalți gloanțele nu-i fac nimic.
@export var omorabil := false
## Marcajul pus când moare și cel pus când îl iei în inventar (la Continue rămâne mort / dispare).
@export var marcaj_mort := ""
@export var marcaj_luat := ""
## Ce intră în inventar când apeși E pe el după ce a murit.
@export var id_cadavru := ""
@export var nume_cadavru := ""
@export var indiciu_cadavru := "[E] Pick up the body"
## Bucățile modelului care rămân prinse de părintele lor în ragdoll (ex. sticla din mână).
@export var lipite_ragdoll: PackedStringArray = []
## Cât de tare îl împinge glonțul (N·s).
@export var forta_glont := 320.0
@export var sunet_cadere: AudioStream
@export var sunet_luat: AudioStream

var mort := false
var _a_vorbit := false
var _vorbeste := false
var _timp := 0.0
var _model: Node3D
var _cadavru: Ragdoll


func _ready() -> void:
	_model = get_node_or_null("Model")
	if id_cadavru != "":
		add_to_group("cadavre")  # cazanul îl caută aici (cazan.gd)
	if marcaj_luat != "" and Stare.e_marcat(marcaj_luat):
		# l-ai luat deja (în inventar sau în cazan): nu mai e aici
		mort = true
		hide()
		_dezactiveaza_coliziunea()
	elif marcaj_mort != "" and Stare.e_marcat(marcaj_mort):
		# e mort de dinainte (Continue): cade pe loc, după ce scena e așezată pe teren
		mort = true
		_dezactiveaza_coliziunea()
		await get_tree().process_frame
		omoara(Vector3.ZERO, 0.0)


## Modelul aruncat în cazan (același .glb ca al lui).
func model_cadavru() -> PackedScene:
	return load(_model.scene_file_path) if _model and _model.scene_file_path != "" else null


func poate_fi_folosit() -> bool:
	return not _vorbeste and not mort


## Îl lovește un glonț (pistol.gd). Moare doar dacă e `omorabil`.
func impuscat(directie: Vector3) -> void:
	if omorabil and not mort:
		omoara(directie, forta_glont)


## Moare: cade moale pe spate (oricum ar fi fost împușcat, cum a cerut owner-ul), iar după ce se oprește,
## îl poți lua în inventar cu E.
func omoara(directie: Vector3, forta: float) -> void:
	mort = true
	_vorbeste = false
	_dezactiveaza_coliziunea()
	if marcaj_mort != "":
		Stare.marcheaza(marcaj_mort)
	if _model == null:
		return
	_model.scale = Vector3.ONE
	var spate := -global_transform.basis.z  # modelele privesc spre +Z
	var orizontal := Vector3(directie.x, 0.0, directie.z).normalized()
	var impuls := (spate * 0.8 + orizontal * 0.2 + Vector3.UP * 0.15).normalized() * forta
	_cadavru = Ragdoll.din_model(_model, impuls, lipite_ragdoll)
	if forta > 0.0:
		await get_tree().create_timer(0.45).timeout
		if is_instance_valid(_cadavru):
			Sunet.reda_la(sunet_cadere, _cadavru.centru(), Sunet.VOLUM_EFECTE, 0.05)
	# se poate lua după ce s-a liniștit (sau oricum după 3 s)
	var asteptat := 0.0
	while is_instance_valid(_cadavru) and asteptat < 3.0 and not (asteptat > 0.6 and _cadavru.s_a_oprit()):
		await get_tree().create_timer(0.2).timeout
		asteptat += 0.2
	if is_instance_valid(_cadavru) and id_cadavru != "":
		_pune_ridicare()


## „[E] Pick up the body” pe trunchiul cadavrului (vezi Ragdoll.pune_ridicare).
func _pune_ridicare() -> void:
	_cadavru.pune_ridicare(id_cadavru, nume_cadavru, indiciu_cadavru).folosit.connect(_luat)


func _luat() -> void:
	if marcaj_luat != "":
		Stare.marcheaza(marcaj_luat)
	Sunet.reda(sunet_luat, Sunet.VOLUM_EFECTE, 0.05)
	_cadavru.queue_free()
	hide()


func _dezactiveaza_coliziunea() -> void:
	for copil in get_children():
		if copil is CollisionShape3D:
			copil.set_deferred("disabled", true)


func interactioneaza() -> void:
	if _vorbeste:
		return
	_vorbeste = true
	folosit.emit()
	if se_intoarce:
		intoarce_spre(_jucator())
	Dialog.spune(replici_dupa if _a_vorbit and not replici_dupa.is_empty() else replici)
	if Dialog.activ:
		await Dialog.terminat
	_vorbeste = false
	if not _a_vorbit:
		_a_vorbit = true
		if marcaj_dupa != "":
			Stare.marcheaza(marcaj_dupa)
		if sarcina_noua != "":
			Stare.seteaza_sarcina(sarcina_noua)


## Se întoarce cu fața spre `nod` (jucătorul), în `durata_intoarcere` secunde.
func intoarce_spre(nod: Node3D) -> Tween:
	if nod == null:
		return null
	var d := nod.global_position - global_position
	var tinta := atan2(d.x, d.z)  # modelele privesc spre +Z
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "rotation:y", rotation.y + angle_difference(rotation.y, tinta), durata_intoarcere)
	return tween


func _process(delta: float) -> void:
	if mort:
		return
	_timp += delta
	# respiră: se umflă puțin pe verticală
	if _model:
		_model.scale.y = 1.0 + sin(_timp * 2.2) * 0.008
	if cap == null:
		return
	var tinta := 0.0
	var jucator := _jucator()
	if jucator and global_position.distance_to(jucator.global_position) < distanta_privire:
		var local := to_local(jucator.global_position)
		tinta = clampf(atan2(local.x, local.z), -deg_to_rad(unghi_maxim_cap), deg_to_rad(unghi_maxim_cap))
	cap.rotation.y = lerp_angle(cap.rotation.y, tinta, 1.0 - exp(-delta * 5.0))


func _jucator() -> Node3D:
	return get_tree().get_first_node_in_group("jucator") as Node3D
