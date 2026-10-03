extends Node
## Capacul oalei de pe aragaz: din când în când saltă și zdrăngăne, ca atunci când fierbe ceva.
## `capac` = piesa Capac din aragaz.glb (originea ei e pe buza oalei, vezi aragaz() din tools/blender/bucatarie.py).

@export var capac: Node3D
## Zdrăngănitul (opțional).
@export var sunet: AudioStream
@export var pauza_min := 3.0
@export var pauza_max := 9.0

var _pana_la_salt := 2.0
var _salt := 0.0
var _pozitie := Vector3.ZERO


func _ready() -> void:
	if capac:
		_pozitie = capac.position


func _process(delta: float) -> void:
	if capac == null:
		return
	if _salt > 0.0:
		_salt -= delta
		# câteva sărituri mici, care se potolesc
		var t := maxf(_salt, 0.0)
		capac.position = _pozitie + Vector3(0, absf(sin(t * 40.0)) * 0.006 * t, 0)
		capac.rotation = Vector3(sin(t * 31.0) * 0.05 * t, 0, cos(t * 27.0) * 0.05 * t)
		return
	_pana_la_salt -= delta
	if _pana_la_salt <= 0.0:
		_pana_la_salt = randf_range(pauza_min, pauza_max)
		_salt = randf_range(0.5, 1.0)
		if sunet:
			Sunet.reda_la(sunet, capac.global_position, -20.0, 0.15, 2.2)
