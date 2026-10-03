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
## Cât de repede se întoarce spre tine când vorbiți (secunde).
@export var durata_intoarcere := 0.5

@export_group("După prima conversație")
## Marcajul pus în Stare după prima conversație (ex. "a_vorbit_cu_mom"; gol = niciunul).
@export var marcaj_dupa := ""
## Sarcina pe care o primești după prima conversație (apare sus câteva secunde; gol = niciuna).
@export var sarcina_noua := ""
## Ce spune când vorbești cu el a doua oară (gol = repetă "replici").
@export_multiline var replici_dupa: PackedStringArray = []

var _a_vorbit := false
var _vorbeste := false
var _timp := 0.0
var _model: Node3D


func _ready() -> void:
	_model = get_node_or_null("Model")


func poate_fi_folosit() -> bool:
	return not _vorbeste


func interactioneaza() -> void:
	if _vorbeste:
		return
	_vorbeste = true
	folosit.emit()
	var jucator := _jucator()
	if jucator:
		var d := jucator.global_position - global_position
		var tinta := atan2(d.x, d.z)  # modelele privesc spre +Z
		var tween := create_tween().set_trans(Tween.TRANS_SINE)
		tween.tween_property(self, "rotation:y", rotation.y + angle_difference(rotation.y, tinta), durata_intoarcere)
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


func _process(delta: float) -> void:
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
