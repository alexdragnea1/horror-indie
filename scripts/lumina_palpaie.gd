extends OmniLight3D
## Bec care pâlpâie. Pune-l pe orice OmniLight3D.

@export var energie_normala := 1.2
## Cât de des se stinge de tot (0 = niciodată, 1 = mereu).
@export_range(0.0, 1.0) var sansa_stingere := 0.12

var _pana_la_schimbare := 0.0


func _process(delta: float) -> void:
	_pana_la_schimbare -= delta
	if _pana_la_schimbare > 0.0:
		return
	if randf() < sansa_stingere:
		light_energy = 0.0
		_pana_la_schimbare = randf_range(0.03, 0.15)
	else:
		light_energy = energie_normala * randf_range(0.8, 1.05)
		_pana_la_schimbare = randf_range(0.05, 0.4)
