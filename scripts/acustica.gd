class_name Acustica
extends Node
## Cât de tare răsună locul: pune un nod din ăsta în fiecare nivel.
## Schimbă ecoul (Reverb) de pe canalul „Efecte” când pornește scena:
## în casă e o cameră mică, afară aproape nu e ecou, pe scara blocului răsună tare.

@export_range(0.0, 1.0) var marime_camera := 0.35
## Cât de repede se pierd frecvențele înalte din ecou (mai mare = ecou mai înfundat).
@export_range(0.0, 1.0) var amortizare := 0.65
## Cât ecou se aude peste sunet (0 = deloc).
@export_range(0.0, 1.0) var ecou := 0.14


func _ready() -> void:
	add_to_group("acustica")
	aplica()


func aplica() -> void:
	Acustica.seteaza(marime_camera, amortizare, ecou)


static func seteaza(marime: float, amortizare_noua: float, ecou_nou: float) -> void:
	var canal := AudioServer.get_bus_index(&"Efecte")
	if canal < 0 or AudioServer.get_bus_effect_count(canal) == 0:
		return
	var reverb := AudioServer.get_bus_effect(canal, 0) as AudioEffectReverb
	if reverb:
		reverb.room_size = marime
		reverb.damping = amortizare_noua
		reverb.wet = ecou_nou
