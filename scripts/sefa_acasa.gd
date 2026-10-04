extends "res://scripts/sefa_vrajitoare.gd"
## Head Witch în bucătărie, dimineața după somn (`marcaj_dimineata`, pus de pat.gd), în locul lui Mom.
## La E: `replici` (scrise de owner), apoi `marcaj_dupa` și `sarcina_noua`, își face semn cu mâna și dispare
## într-un fum mov (pe pixeli, vezi ModelPS2.disparitie): te așteaptă afară (vezi sefa_antrenament.gd).
## Înainte de dimineață sau după ce ai vorbit cu ea nu e aici.

@export var marcaj_dimineata := "e_dimineata"
## Cât durează dispariția (secunde).
@export var durata_disparitie := 0.9


func _ready() -> void:
	super()
	if not Stare.e_marcat(marcaj_dimineata) or Stare.e_marcat(marcaj_dupa):
		queue_free()


func poate_fi_folosit() -> bool:
	return not _vorbeste


func interactioneaza() -> void:
	if _vorbeste:
		return
	_vorbeste = true
	folosit.emit()
	intoarce_spre(_jucator())
	Dialog.spune(replici)
	if Dialog.activ:
		await Dialog.terminat
	Stare.marcheaza(marcaj_dupa)
	await get_tree().create_timer(0.4).timeout
	await _dispare()
	if sarcina_noua != "":
		Stare.seteaza_sarcina(sarcina_noua)
	queue_free()


## Ridică mâna, pocnește din degete: fum mov și se risipește pe pixeli, de jos în sus cu fumul.
func _dispare() -> void:
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(brat, "rotation", Vector3(-1.1, 0.0, -0.35), 0.45)
	await tween.finished
	await get_tree().create_timer(0.25).timeout
	Sunet.reda_la(SUNET_MATURA, global_position + Vector3.UP, Sunet.VOLUM_EFECTE, 0.05)
	for inaltime in [0.3, 0.9, 1.5]:
		_fum(global_position + Vector3.UP * inaltime)
	_dezactiveaza_coliziunea()
	var model := get_node("Model")
	tween = create_tween()
	tween.tween_method(func(v: float) -> void: ModelPS2.disparitie(model, v), 0.0, 1.0, durata_disparitie)
	await tween.finished
