class_name ObiectLuat
extends Interactabil
## Un obiect pe care jucătorul îl ia cu E (cheie, baterie, bilet de păstrat...).
## Intră în inventar ("Stare"), spune "replici" și dispare din lume.

## Numele intern, folosit de uși ("cheie_necesara") și de cod. Fără spații.
@export var id_obiect := "cheie"
## Numele pe care îl vede jucătorul în inventar.
@export var nume_obiect := "Cheie"


func interactioneaza() -> void:
	Stare.adauga_obiect(id_obiect, nume_obiect)
	Dialog.spune(replici)
	folosit.emit()
	queue_free()
