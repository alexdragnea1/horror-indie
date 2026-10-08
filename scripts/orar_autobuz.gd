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
## Marcajul după care locul dispare din orar, în aceeași ordine (gol = rămâne mereu; ex. Lexy's Place după
## `lexy_moarta`).
@export var ascunse_dupa: PackedStringArray = []
## Marcajul fără de care locul nu apare încă în orar, în aceeași ordine (gol = apare de la început; ex. Home abia
## după mesajul lui Head Witch, `a_primit_mesajul_sefei`).
@export var vizibile_dupa: PackedStringArray = []
## Marcajul până la care locul, cât timp se vede în orar, e singurul (în afară de `optiune_anulare`), în aceeași
## ordine (gol = nu). Ex. Town Hall: de când citești știrile (`a_citit_stirile`) până iei banii de la primar
## (`a_luat_banii_de_la_primar`).
@export var singur_pana_la: PackedStringArray = []
@export var optiune_anulare := "Not now"
## Locurile fără scenă (scrise de Claude, owner-ul le poate schimba).
@export_multiline var replici_indisponibil: PackedStringArray = ["You: Nah, not today."]
## Sarcina după ce ai chemat autobuzul (gol = niciuna).
@export var sarcina_chemat := ""
## Sarcina care dispare când chemi autobuzul (dacă e cea curentă).
@export var sarcina_de_sters := "Check the bus schedule."
## Între `blocat_de_la` (pus) și `blocat_pana_la` (încă nepus) nu mai vine niciun autobuz: spui doar `replici_blocat`.
## Ex. la bloc, noaptea după Warlock (`warlock_absorbit`), până dormi (`ziua_primariei`).
@export var blocat_de_la := ""
@export var blocat_pana_la := ""
## Scrisă de Claude; owner-ul o poate schimba.
@export_multiline var replici_blocat: PackedStringArray = ["You: No more buses tonight. I need some sleep."]
@export_group("Alte titluri")
## Între `titluri_noi_de_la` (pus) și `titluri_noi_pana_la` (încă nepus), titlul locului `i` e `titluri_noi[i]` (gol =
## cel obișnuit). Ex.: după mesajul lui Head Witch, „Home” = „Block M7, Entrance B / 7:24 PM”, până înveți scutul.
@export var titluri_noi_de_la := ""
@export var titluri_noi_pana_la := ""
@export var titluri_noi: PackedStringArray = []

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
	if blocat_de_la != "" and Stare.e_marcat(blocat_de_la) and (blocat_pana_la == "" or not Stare.e_marcat(blocat_pana_la)):
		Dialog.spune(replici_blocat)
		if Dialog.activ:
			await Dialog.terminat
		_in_curs = false
		return
	# doar locurile care se mai văd: `locuri[k]` = indexul din `optiuni` al butonului k
	var locuri: Array[int] = []
	var butoane := PackedStringArray()
	for i in optiuni.size():
		if i < ascunse_dupa.size() and ascunse_dupa[i] != "" and Stare.e_marcat(ascunse_dupa[i]):
			continue
		if i < vizibile_dupa.size() and vizibile_dupa[i] != "" and not Stare.e_marcat(vizibile_dupa[i]):
			continue
		if i < singur_pana_la.size() and singur_pana_la[i] != "" and not Stare.e_marcat(singur_pana_la[i]):
			# doar el (ex. Town Hall în ziua primăriei)
			locuri = [i]
			butoane = PackedStringArray([optiuni[i]])
			break
		locuri.append(i)
		butoane.append(optiuni[i])
	butoane.append(optiune_anulare)
	var buton := await Dialog.intreaba("", butoane)
	var ales := locuri[buton] if buton >= 0 and buton < locuri.size() else -1
	if ales >= 0:
		var scena := scene[ales] if ales < scene.size() else ""
		if scena == "":
			Dialog.spune(replici_indisponibil)
			if Dialog.activ:
				await Dialog.terminat
		else:
			var titlu := titluri[ales] if ales < titluri.size() else optiuni[ales]
			if titluri_noi_de_la != "" and Stare.e_marcat(titluri_noi_de_la) \
					and (titluri_noi_pana_la == "" or not Stare.e_marcat(titluri_noi_pana_la)) \
					and ales < titluri_noi.size() and titluri_noi[ales] != "":
				titlu = titluri_noi[ales]
			sosire.cheama(scena, titlu)
			if sarcina_chemat != "":
				Stare.seteaza_sarcina(sarcina_chemat)
			elif Stare.sarcina == sarcina_de_sters:
				# ai făcut ce zicea („Check the bus schedule.”): dispare, fără mesaj nou
				Stare.sarcina = ""
				Stare.schimbat.emit()
	_in_curs = false
