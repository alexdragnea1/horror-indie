class_name IntrareAutobuz
extends Interactabil
## Golul unei uși de autobuz: „[E] Get on the bus” apare doar cât ușile sunt deschise.
## Ce se întâmplă la urcare hotărăște cine ascultă semnalul `folosit` (ex. sosire_autobuz.gd).

var deschisa := false


func poate_fi_folosit() -> bool:
	return deschisa


func interactioneaza() -> void:
	if deschisa:
		folosit.emit()
