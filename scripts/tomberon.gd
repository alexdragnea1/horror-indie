extends Interactabil
## Tomberonul din curtea blocului. La E ridici capacul, scotocești prin gunoi și găsești o bomboană (`id_obiect`),
## care intră în inventar. O dată pe joc (`marcaj`, rămâne în salvare); după aceea nu mai e nimic de căutat.
## Bomboana o ții în mână și o mănânci cu click (vezi ObiectInMana).

@export var id_obiect := "bomboana"
@export var nume_obiect := "Candy"
@export var marcaj := "a_gasit_bomboana"
## Cât se ridică capacul (radiani, în jurul balamalei din spate).
@export var deschidere := 1.15

const SUNET_CAPAC := preload("res://sunete/tomberon_capac.ogg")
const SUNET_RASCOLIT := preload("res://sunete/tomberon_rascolit.ogg")

var _capac: Node3D
var _cauta := false


func _ready() -> void:
	indiciu = "[E] Search"
	_capac = find_child("Capac", true, false) as Node3D


func poate_fi_folosit() -> bool:
	return not _cauta and not Stare.e_marcat(marcaj)


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	if Stare.obiecte.size() >= Stare.LOCURI_INVENTAR and not Stare.are_obiect(id_obiect):
		Stare.adauga_obiect(id_obiect, nume_obiect)  # doar scrie „Inventory full”
		return
	_cauta = true
	var sus := global_position + Vector3.UP * 1.2
	# capacul se ridică dintr-o smucitură și rămâne sus cât scotocești
	Sunet.reda_la(SUNET_CAPAC, sus, Sunet.VOLUM_EFECTE, 0.05, 1.1)
	var t := create_tween()
	t.tween_property(_capac, "rotation:x", deschidere, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t.finished
	Sunet.reda_la(SUNET_RASCOLIT, sus, Sunet.VOLUM_EFECTE, 0.05)
	# capacul tresare cât răscolești
	t = create_tween()
	for i in 3:
		t.tween_property(_capac, "rotation:x", deschidere - 0.08, 0.12)
		t.tween_property(_capac, "rotation:x", deschidere, 0.18)
	await t.finished
	await get_tree().create_timer(0.2).timeout
	Stare.adauga_obiect(id_obiect, nume_obiect)
	Stare.marcheaza(marcaj)
	folosit.emit()
	await get_tree().create_timer(0.35).timeout
	# îl lași să cadă: trântit
	t = create_tween()
	t.tween_property(_capac, "rotation:x", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	Sunet.reda_la(SUNET_CAPAC, sus, Sunet.VOLUM_EFECTE, 0.05, 0.85)
	t = create_tween()
	t.tween_property(_capac, "rotation:x", 0.05, 0.06)
	t.tween_property(_capac, "rotation:x", 0.0, 0.08)
	_cauta = false
