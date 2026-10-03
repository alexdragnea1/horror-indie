class_name Usa
extends Interactabil
## O ușă care se rotește în jurul balamalei. Originea nodului = balamaua,
## deci pune mesh-ul și coliziunea ca fii, deplasate pe X cu jumătate din lățime.
## Dacă "cheie_necesara" nu e gol, ușa e încuiată până ai cheia aia în inventar.

signal deschisa
signal descuiata

## Id-ul cheii (vezi ObiectLuat.id_obiect). Gol = ușa nu e încuiată.
@export var cheie_necesara := ""
## Ce zice personajul când ușa e încuiată și n-are cheia.
@export_multiline var replici_incuiata: PackedStringArray = ["It's locked."]
## Ce zice când o descuie.
@export_multiline var replici_descuiere: PackedStringArray = []
## Dacă e bifat, cheia dispare din inventar după ce descuie ușa.
@export var consuma_cheia := true
## Ușa nu se deschide până nu s-a întâmplat ceva în poveste (un marcaj din Stare,
## ex. "a_vorbit_cu_mom"). Gol = fără condiție.
@export var marcaj_necesar := ""
## Ce zice personajul cât timp marcajul de mai sus lipsește.
@export_multiline var replici_fara_marcaj: PackedStringArray = []
## Clanța care zornăie când ușa nu se deschide (încuiată sau blocată de poveste).
@export var sunet_incuiata: AudioStream
## Cu cât se rotește ușa (grade). Semnul alege partea în care se deschide.
@export var unghi_deschidere := 95.0
## Cât durează deschiderea (secunde).
@export var durata := 0.7
@export var indiciu_inchisa := "[E] Open"
@export var indiciu_deschisa := "[E] Close"
## Sunetul de la deschidere (scârțâit) și cel de la închidere (se aude când ușa ajunge la loc).
@export var sunet_deschidere: AudioStream
@export var sunet_inchidere: AudioStream
@export var volum_db := -4.0

@export_group("Iesire din scena")
## Dacă e completat, deschiderea ușii te duce în scena asta (prin ecran negru, vezi Tranzitie).
@export_file("*.tscn") var scena_urmatoare := ""
## Numele locului, arătat jos în stânga după tranziție (Enter = rând nou).
@export_multiline var titlu_locatie := ""
## Ce se aude pe ecranul negru, în ordine (pași pe scări, o ușă trântită...).
@export var sunete_tranzitie: Array[AudioStream] = []

var deschisa_acum := false

var _unghi_inchis := 0.0
var _tween: Tween


func _ready() -> void:
	_unghi_inchis = rotation_degrees.y
	indiciu = indiciu_inchisa


func interactioneaza() -> void:
	if marcaj_necesar != "" and not Stare.e_marcat(marcaj_necesar):
		Sunet.reda_la(sunet_incuiata, global_position + Vector3.UP, volum_db, 0.05)
		Dialog.spune(replici_fara_marcaj)
		return
	if cheie_necesara != "":
		if not Stare.are_obiect(cheie_necesara):
			Sunet.reda_la(sunet_incuiata, global_position + Vector3.UP, volum_db, 0.05)
			Dialog.spune(replici_incuiata)
			return
		if consuma_cheia:
			Stare.scoate_obiect(cheie_necesara)
		cheie_necesara = ""
		Dialog.spune(replici_descuiere)
		descuiata.emit()
	_misca(not deschisa_acum)
	folosit.emit()
	if deschisa_acum and scena_urmatoare != "":
		# ușa apucă să se deschidă puțin, apoi se întunecă ecranul
		await get_tree().create_timer(0.35).timeout
		Tranzitie.mergi_la(scena_urmatoare, titlu_locatie, sunete_tranzitie)


func _misca(deschide: bool) -> void:
	deschisa_acum = deschide
	indiciu = indiciu_deschisa if deschide else indiciu_inchisa
	if deschide:
		deschisa.emit()
	var tinta := _unghi_inchis + (unghi_deschidere if deschide else 0.0)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "rotation_degrees:y", tinta, durata)
	if deschide:
		Sunet.reda_la(sunet_deschidere, global_position + Vector3.UP, volum_db, 0.05)
	else:
		_tween.finished.connect(func() -> void: Sunet.reda_la(sunet_inchidere, global_position + Vector3.UP, volum_db, 0.05))
