class_name RaftDepozit
extends Interactabil
## Etajera din camera ta (models/raft_depozit.glb în copilul `Model`): „[E] Shelf” deschide fereastra raftului
## (Stare.deschide_raft), unde muți obiecte între inventar și raft, cel mult `Stare.LOCURI_RAFT` (5).
## Ce e pe raft (`Stare.raft`) se vede în compartimente: fiecare obiect în compartimentul lui, în ordine; mătura nu
## încape, așa că stă rezemată de etajeră, în fața compartimentului ei. Modelele vin din ObiecteLume.

## Mijlocul compartimentului 1 și distanța dintre compartimente (pe X), și înălțimea fundului lor.
const PRIMUL := -0.62
const PAS := 0.31
const FUND := 0.08

var _afisate: Array[Node3D] = []


func _ready() -> void:
	indiciu = "[E] Shelf"
	Stare.schimbat.connect(_afiseaza)
	_afiseaza()


func interactioneaza() -> void:
	folosit.emit()
	Stare.deschide_raft()


## Pune în compartimente modelele obiectelor de pe raft (din nou, de fiecare dată când se schimbă ceva).
func _afiseaza() -> void:
	for nod in _afisate:
		nod.queue_free()
	_afisate.clear()
	var i := 0
	for id: String in Stare.raft:
		var model := ObiecteLume.model(id)
		if model == null:
			i += 1
			continue
		var date: Dictionary = ObiecteLume.MODELE[id]
		add_child(model)
		var x := PRIMUL + i * PAS
		if date.get("sprijinita", false):
			# rezemată de etajeră, pe podea, în fața compartimentului
			model.position = Vector3(x, 0.0, 0.32)
			model.rotation = Vector3(-0.2, 0.0, 0.05)
		else:
			model.position = Vector3(x, FUND + date.ridicare, -0.02)
			model.rotation = date.get("raft", date.jos)
		_afisate.append(model)
		i += 1
