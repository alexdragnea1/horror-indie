class_name OrarAutobuz
extends Interactabil
## Orarul din stație (rama de pe stâlpul din dreapta, vezi `statie()` din autobuz.py), în ziua în care mergi prin oraș
## (după `marcaj_necesar`). E → butoanele cu locurile (`optiuni`) + `optiune_anulare`. Alegi un loc → în `intarziere` s
## vine autobuzul (`sosire`, un SosireAutobuz cu `marcaj` gol, chemat cu `cheama`), urci și te duce în `scene[i]`, cu
## `titluri[i]` jos în stânga. Un loc cu scena goală (încă nefăcut) spune doar `replici_indisponibil`.
## În scena în care cobori, `plecare_autobuz.gd` cu `doar_din_orar` te pune în stație și autobuzul pleacă.

## Adevărat de la urcarea într-un autobuz chemat de aici până te lasă scena următoare în stație.
static var cu_autobuzul := false

@export var marcaj_necesar := "vrea_in_oras"
## Nodul SosireAutobuz din scenă (cu `marcaj` gol: vine doar când îl chemi de aici).
@export var sosire: Node
@export var optiuni: PackedStringArray = []
## Scena fiecărui loc, în aceeași ordine (gol = încă nu se poate merge acolo).
@export var scene: PackedStringArray = []
## Ce scrie jos în stânga după drum (Enter = rând nou).
@export var titluri: PackedStringArray = []
@export var optiune_anulare := "Not now"
## Locurile fără scenă (scrise de Claude, owner-ul le poate schimba).
@export_multiline var replici_indisponibil: PackedStringArray = ["You: Nah, not today."]
## Sarcina după ce ai chemat autobuzul (gol = niciuna).
@export var sarcina_chemat := ""
## Sarcina care dispare când chemi autobuzul (dacă e cea curentă).
@export var sarcina_de_sters := "Check the bus schedule."

var _in_curs := false


func _ready() -> void:
	indiciu = "[E] Check the bus schedule"


func poate_fi_folosit() -> bool:
	return not _in_curs and Stare.e_marcat(marcaj_necesar) and sosire != null and sosire.poate_fi_chemat()


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	var butoane := optiuni.duplicate()
	butoane.append(optiune_anulare)
	var ales := await Dialog.intreaba("", butoane)
	if ales >= 0 and ales < optiuni.size():
		var scena := scene[ales] if ales < scene.size() else ""
		if scena == "":
			Dialog.spune(replici_indisponibil)
			if Dialog.activ:
				await Dialog.terminat
		else:
			var titlu := titluri[ales] if ales < titluri.size() else optiuni[ales]
			sosire.cheama(scena, titlu)
			if sarcina_chemat != "":
				Stare.seteaza_sarcina(sarcina_chemat)
			elif Stare.sarcina == sarcina_de_sters:
				# ai făcut ce zicea („Check the bus schedule.”): dispare, fără mesaj nou
				Stare.sarcina = ""
				Stare.schimbat.emit()
	_in_curs = false
