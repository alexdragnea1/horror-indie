class_name UsaTeleport
extends Interactabil
## O ușă care te duce în alt loc din ACEEAȘI scenă, prin ecran negru (Tranzitie.teleporteaza): ușa „EMPLOYEES ONLY” din
## barul URBAN te scoate în curtea din spate (unde e sabia din piatră), iar ușa de metal din curte te bagă înapoi.
## Apari la `destinatie` (un Marker3D), cu fața spre -Z-ul lui.

@export var destinatie: Node3D
@export var sunet_usa: AudioStream
## Ce se aude pe negru (ușa care se închide în urma ta, pașii).
@export var sunete_tranzitie: Array[AudioStream] = []


func interactioneaza() -> void:
	if not poate_fi_folosit() or destinatie == null or Tranzitie.activa:
		return
	Sunet.reda_la(sunet_usa, global_position, Sunet.VOLUM_EFECTE, 0.05)
	folosit.emit()
	Tranzitie.teleporteaza(destinatie, sunete_tranzitie)
