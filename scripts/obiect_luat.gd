class_name ObiectLuat
extends Interactabil
## Un obiect pe care jucătorul îl ia cu E (cheie, baterie, bilet de păstrat...).
## Intră în inventar ("Stare"), spune "replici" și dispare din lume.

## Numele intern, folosit de uși ("cheie_necesara") și de cod. Fără spații.
@export var id_obiect := "cheie"
## Numele pe care îl vede jucătorul în inventar.
@export var nume_obiect := "Key"


func interactioneaza() -> void:
	if not Stare.adauga_obiect(id_obiect, nume_obiect):
		return  # inventarul e plin: obiectul rămâne pe loc
	Dialog.spune(replici)
	folosit.emit()
	queue_free()
