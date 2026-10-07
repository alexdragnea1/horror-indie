class_name ObiectAruncat
extends ObiectLuat
## Un obiect din inventar aruncat pe jos (click dreapta în inventar). Îl pune ObiecteLume.pune_jos; rămâne în
## `Stare.aruncate` (și în salvare), deci îl găsești tot acolo când revii. La E îl iei înapoi.
## Banii (cash, jetoane) își țin suma în `valoare`: la E se adaugă la ce ai deja.

## Locul lui în `Stare.aruncate` (de obicei id-ul; banii aruncați de mai multe ori au chei diferite).
var cheie := ""
## Suma (cenți), pentru cash și jetoane.
var valoare := 0


func interactioneaza() -> void:
	if id_obiect == Jetoane.ID or id_obiect == Bani.ID:
		if not Stare.are_obiect(id_obiect) and Stare.obiecte.size() >= Stare.LOCURI_INVENTAR:
			Stare.adauga_obiect(id_obiect, nume_obiect)  # doar scrie „Inventory full”
			return
		if id_obiect == Jetoane.ID:
			Jetoane.adauga(valoare)
		else:
			Bani.adauga(valoare)
	elif not Stare.adauga_obiect(id_obiect, nume_obiect):
		return  # inventarul e plin: rămâne pe jos
	Stare.uita_aruncat(cheie if cheie != "" else id_obiect)
	folosit.emit()
	queue_free()
