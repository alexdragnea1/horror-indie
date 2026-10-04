extends Node3D
## Pune-l pe un nod-părinte: când pornește scena, fiecare copil e coborât/ridicat pe terenul
## generat (TerenPadure). Înălțimea copilului din editor se adaugă peste teren (0 = direct pe pământ),
## deci obiectele se pot muta liniștit în editor doar pe X și Z.
## Un copil din grupul „pe_pamant_cu_copii” (ex. Coven: cazanul, vrăjitoarele, torțele) are și copiii lui
## puși fiecare pe teren, acolo unde stă (pământul nu e perfect plat nici în poiană).

@export var teren: TerenPadure


func _ready() -> void:
	for copil in get_children():
		var n := copil as Node3D
		if n == null:
			continue
		var aici := teren.inaltime(n.global_position.x, n.global_position.z)
		if n.is_in_group("pe_pamant_cu_copii"):
			for nepot in n.get_children():
				var m := nepot as Node3D
				if m:
					m.position.y += teren.inaltime(m.global_position.x, m.global_position.z) - aici
		n.position.y += aici
