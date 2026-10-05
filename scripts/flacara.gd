extends OmniLight3D
## Lumina unei flăcări (lumânări, candelabru, șemineu, dovleci): pâlpâie lin, fiecare în ritmul ei (nu se stinge,
## ca bec_palpaie). `tremur` = cât de tare (0,05 la lumânări liniștite, 0,25 la focul din șemineu).

@export var energie := 1.0
@export_range(0.0, 0.5) var tremur := 0.1

var _faza := randf() * 100.0


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001 + _faza
	var unda := 0.5 * sin(t * 7.3) + 0.3 * sin(t * 13.1 + 1.3) + 0.2 * sin(t * 23.7 + 0.4)
	light_energy = energie * (1.0 + tremur * unda)
