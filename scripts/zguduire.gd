class_name Zguduire
extends Node
## Zgâlțâie o cameră (reculul armelor, explozia de bazooka) mutând-o puțin din `h_offset` / `v_offset`, fără să-i
## atingă rotația (pe care o mișcă jucătorul). Mai multe zguduiri odată se adună; fiecare se stinge în `durata`.
##   Zguduire.porneste(camera, 0.02, 0.3)

var _camera: Camera3D
var _valuri: Array = []  # [putere, durata, timp]
var _timp := 0.0


static func porneste(camera: Camera3D, putere: float, durata: float) -> void:
	if camera == null:
		return
	var z := camera.get_node_or_null("Zguduire") as Zguduire
	if z == null:
		z = Zguduire.new()
		z.name = "Zguduire"
		camera.add_child(z)
	z._valuri.append([putere, durata, 0.0])


func _ready() -> void:
	_camera = get_parent() as Camera3D


func _process(delta: float) -> void:
	_timp += delta
	var putere := 0.0
	for v in _valuri:
		v[2] += delta
		putere += v[0] * pow(maxf(1.0 - v[2] / v[1], 0.0), 2.0)
	_valuri = _valuri.filter(func(v: Array) -> bool: return v[2] < v[1])
	_camera.h_offset = (sin(_timp * 61.0) + sin(_timp * 37.0 + 1.7) * 0.6) * putere
	_camera.v_offset = (sin(_timp * 53.0 + 0.5) + sin(_timp * 29.0 + 2.3) * 0.6) * putere
