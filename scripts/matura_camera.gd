extends Interactabil
## Mătura din camera jucătorului (sprijinită de perete). După ce Head Witch ți-a zis s-o iei (`marcaj_necesar`),
## la E te întreabă „Pick up the broom?” (Yes / No); Yes = intră în inventar (`ID`) și dispare de pe perete.
## Cât e în inventarul tău nu e aici; dacă iese din inventar (după antrenament „se teleportează” acasă), e la loc.

const ID := "matura"

@export var marcaj_necesar := "a_vorbit_cu_sefa_acasa"
@export var nume := "Broom"
@export var intrebare := "Pick up the broom?"
@export var sunet_luat: AudioStream

var _intreaba := false


func _ready() -> void:
	indiciu = "[E] Pick up the broom"
	Stare.schimbat.connect(_actualizeaza)
	_actualizeaza()


func _actualizeaza() -> void:
	var aici := not Stare.are_obiect(ID)
	visible = aici
	for copil in get_children():
		if copil is CollisionShape3D:
			copil.set_deferred("disabled", not aici)


func poate_fi_folosit() -> bool:
	return not _intreaba and Stare.e_marcat(marcaj_necesar) and not Stare.are_obiect(ID)


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_intreaba = true
	var ales := await Dialog.intreaba(intrebare, PackedStringArray(["Yes", "No"]))
	_intreaba = false
	if ales != 0:
		return
	if Stare.adauga_obiect(ID, nume):
		Sunet.reda_la(sunet_luat, global_position + Vector3.UP, Sunet.VOLUM_EFECTE, 0.05)
		folosit.emit()
