extends "res://scripts/sefa_conac.gd"
## Head Witch la motelul din orașul vecin (motel.tscn, nodul `HeadWitchMotel`): prima dată scena începe în aer, pe
## mătură (aterizarea e cea din sefa_conac.gd: `drum`, `priveste_spre`, `priveste_la_final` = geamul roșu al camerei 122),
## coborâți în parcare, mătura îi dispare din mână. Apoi, la E: `replici_motel` (owner). Nu dispare și nu intră nicăieri
## (`marcaj_intrat` gol); după ce afli camera de la receptioneră (`marcaj_camera`) nu mai are ce să-ți spună.
## Replicile sunt ale owner-ului: nu le corecta.

@export_multiline var replici_motel: PackedStringArray = []
## După el (pus de receptionera.gd) nu mai vorbește cu tine aici.
@export var marcaj_camera := "stie_camera_warlock"


func poate_fi_folosit() -> bool:
	return not _vorbeste and not mort and Stare.e_marcat(marcaj_sosire) and not Stare.e_marcat(marcaj_camera)


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_vorbeste = true
	folosit.emit()
	var intoarcere := intoarce_spre(_jucator())
	if intoarcere:
		await intoarcere.finished
	Dialog.spune(replici_motel)
	if Dialog.activ:
		await Dialog.terminat
	_vorbeste = false
