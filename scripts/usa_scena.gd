class_name UsaScena
extends Interactabil
## O ușă care te duce în altă scenă, prin Tranzitie (ușa conacului: curtea ↔ înăuntru). În scena nouă apari la
## `PunctSosire`-ul cu numele `sosire` (vezi punct_sosire.gd). Până la `marcaj_necesar` e încuiată: se aude
## `sunet_incuiat` și spui `replici` (gol = nimic).

## Numele punctului de sosire din scena în care tocmai intri (îl citește PunctSosire și îl golește).
static var sosire_urmatoare := ""

@export_file("*.tscn") var scena := ""
@export_multiline var titlu := ""
@export var sosire := ""
@export var marcaj_necesar := ""
@export var sunet_usa: AudioStream
@export var sunet_incuiat: AudioStream
## Ce se aude pe negru (pașii, ușa care se închide în urma ta).
@export var sunete_tranzitie: Array[AudioStream] = []


func interactioneaza() -> void:
	if marcaj_necesar != "" and not Stare.e_marcat(marcaj_necesar):
		Sunet.reda_la(sunet_incuiat, global_position, Sunet.VOLUM_EFECTE, 0.05)
		Dialog.spune(replici)
		return
	Sunet.reda_la(sunet_usa, global_position, Sunet.VOLUM_EFECTE, 0.05)
	folosit.emit()
	sosire_urmatoare = sosire
	Tranzitie.mergi_la(scena, titlu, sunete_tranzitie)
