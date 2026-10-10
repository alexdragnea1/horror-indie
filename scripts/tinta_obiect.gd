class_name TintaObiect
extends StaticBody3D
## O țintă pentru lucruri care se strică când trag în ele (televizorul lui Lexy): orice glonț, cuțitul, Fireball-ul sau
## o explozie îi dau semnalul `lovit`. Ce se întâmplă hotărăște cine îl ascultă.
## Pune-o din cod: `TintaObiect.adauga(parinte, cutie)` (cutie = AABB în coordonatele părintelui).

signal lovit(directie: Vector3, punct: Vector3, foc: bool)


static func adauga(parinte: Node3D, cutie: AABB) -> TintaObiect:
	var t := TintaObiect.new()
	t.name = "Tinta"
	parinte.add_child(t)
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = cutie.size
	forma.shape = box
	forma.position = cutie.get_center()
	t.add_child(forma)
	return t


func impuscat(directie: Vector3, punct := Vector3.ZERO) -> void:
	lovit.emit(directie, punct if punct != Vector3.ZERO else global_position, false)


func lovit_de_foc(directie: Vector3, punct := Vector3.ZERO) -> void:
	lovit.emit(directie, punct if punct != Vector3.ZERO else global_position, true)
