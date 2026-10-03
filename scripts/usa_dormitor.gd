extends Usa
## Ușa camerei jucătorului. Prima dată când încerci s-o deschizi apare meniul
## cu numele (MeniuNume), apoi replicile de mai jos, și abia apoi se deschide.

## Ce se spune după ce ți-ai ales numele.
@export_multiline var replici_dupa_nume: PackedStringArray = ["Ok little bitch, go talk to your mother."]

const MARCAJ_NUME := "si_a_ales_numele"

var _in_curs := false


func poate_fi_folosit() -> bool:
	return not _in_curs


func interactioneaza() -> void:
	if _in_curs:
		return
	if not Stare.e_marcat(MARCAJ_NUME):
		_in_curs = true
		var meniu := MeniuNume.new()
		get_tree().root.add_child(meniu)
		Stare.nume_jucator = await meniu.ales
		Stare.marcheaza(MARCAJ_NUME)
		Dialog.spune(replici_dupa_nume)
		if Dialog.activ:
			await Dialog.terminat
		_in_curs = false
	super.interactioneaza()
