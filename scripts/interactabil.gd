class_name Interactabil
extends StaticBody3D
## Pune scriptul ăsta pe orice obiect cu care jucătorul poate interacționa.
## Când te uiți la el apare "indiciu"; la E se spun "replici" în caseta de jos.
## Pentru lucruri mai complicate (uși, chei, scene) leagă-te de semnalul "folosit".

signal folosit

@export var indiciu := "[E] Examine"
@export_multiline var replici: PackedStringArray = []
## Dacă e bifat, după prima folosire nu mai face nimic.
@export var o_singura_data := false

var _folosit := false


func poate_fi_folosit() -> bool:
	return not (o_singura_data and _folosit)


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_folosit = true
	Dialog.spune(replici)
	folosit.emit()
