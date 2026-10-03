extends OmniLight3D
## Bec care pâlpâie. Pune-l pe orice OmniLight3D.
## Dacă îi dai și "sticla" (mesh-ul becului), sticla se aprinde și se stinge odată cu lumina.

@export var energie_normala := 1.2
## Cât de des se stinge de tot (0 = niciodată, 1 = mereu).
@export_range(0.0, 1.0) var sansa_stingere := 0.12
## Mesh-ul care strălucește odată cu lumina (opțional).
@export var sticla: GeometryInstance3D
## Cât de tare strălucește sticla când becul arde normal.
@export var stralucire_sticla := 3.0
## Bâzâitul electric (opțional): tace când becul se stinge și se aude iar când se aprinde.
@export var bazait: AudioStreamPlayer3D

var _pana_la_schimbare := 0.0
var _volum_bazait := 0.0


func _ready() -> void:
	if bazait:
		_volum_bazait = bazait.volume_db


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
	if sticla:
		sticla.set_instance_shader_parameter("stralucire", light_energy / energie_normala * stralucire_sticla)
	if bazait:
		bazait.volume_db = _volum_bazait + linear_to_db(maxf(light_energy / energie_normala, 0.001))
