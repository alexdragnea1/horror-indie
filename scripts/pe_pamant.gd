extends Node3D
## Pune-l pe un nod-părinte: când pornește scena, fiecare copil e coborât/ridicat pe terenul
## generat (TerenPadure). Înălțimea copilului din editor se adaugă peste teren (0 = direct pe pământ),
## deci obiectele se pot muta liniștit în editor doar pe X și Z.

@export var teren: TerenPadure


func _ready() -> void:
	for copil in get_children():
		var n := copil as Node3D
		if n:
			n.position.y += teren.inaltime(n.global_position.x, n.global_position.z)
