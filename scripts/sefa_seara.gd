extends "res://scripts/sefa_vrajitoare.gd"
## Head Witch în fața blocului, seara (afara_bloc.tscn, nodul `HeadWitchSeara`). Te așteaptă la scară după ce te-ai
## întors de la Lexy cu autobuzul (`marcaj_seara`), până pleci cu ea (`marcaj_plecare`).
## La E: `replici`, sau `replici_vrajitoare` dacă în pădure ai omorât o vrăjitoare în locul bețivului. Apoi scoate
## mătura, te urci în spatele ei și decolați spre stradă (`directie_zbor`). La `dupa_decolare` s se face negru și
## ajungeți la sediul coven-ului (`scena_conac`; aterizarea e în sefa_conac.gd).
## Replicile sunt ale owner-ului: nu le corecta.

@export var marcaj_seara := "a_urcat_spre_casa"
@export var marcaj_plecare := "a_zburat_la_conac"
@export_file("*.tscn") var scena_conac := "res://scenes/conac.tscn"
@export_multiline var titlu_conac := "Coven Headquarters\n7:12 PM"
## Câte vrăjitoare sunt în cercul din pădure (marcajele lor sunt `vrajitoareN_moarta`, vezi vrajitoare.gd).
@export var vrajitoare_in_cerc := 5

@export_group("Replici")
## În loc de `replici`, dacă ai omorât o vrăjitoare în pădure.
@export_multiline var replici_vrajitoare: PackedStringArray = []


func _ready() -> void:
	super()
	if not get_parent().has_node("Jucator") or not Stare.e_marcat(marcaj_seara) or Stare.e_marcat(marcaj_plecare):
		queue_free()


func poate_fi_folosit() -> bool:
	return not _vorbeste and not mort


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_vorbeste = true
	folosit.emit()
	intoarce_spre(_jucator())
	Dialog.spune(replici_vrajitoare if a_omorat_o_vrajitoare() else replici)
	if Dialog.activ:
		await Dialog.terminat
	Stare.seteaza_sarcina("")
	# pe negru: un vâjâit, încă sunteți în aer (aterizați în scena conacului)
	var sunete: Array[AudioStream] = [SUNET_DECOLARE]
	await _zboara_cu_tine(scena_conac, titlu_conac, sunete, marcaj_plecare)


## Ai omorât o vrăjitoare din cerc (nu bețivul)?
func a_omorat_o_vrajitoare() -> bool:
	for i in range(1, vrajitoare_in_cerc + 1):
		if Stare.e_marcat("vrajitoare%d_moarta" % i):
			return true
	return false
