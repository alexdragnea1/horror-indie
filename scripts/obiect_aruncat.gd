class_name ObiectAruncat
extends ObiectLuat
## Un obiect din inventar aruncat pe jos (click dreapta în inventar). Îl pune ObiecteLume.pune_jos; rămâne în
## `Stare.aruncate` (și în salvare), deci îl găsești tot acolo când revii. La E îl iei înapoi.


func interactioneaza() -> void:
	if not Stare.adauga_obiect(id_obiect, nume_obiect):
		return  # inventarul e plin: rămâne pe jos
	Stare.uita_aruncat(id_obiect)
	folosit.emit()
	queue_free()
