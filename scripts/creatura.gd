class_name Creatura
extends Node3D
## Ce aleargă prin pădure. Scriptul face doar mișcarea membrelor și pașii;
## pe unde aleargă hotărăște scena (ex. drum_autobuz.gd mută nodul).
## Modelul privește spre +Z: acolo aleargă.

## Câți pași pe secundă (cu cât mai mulți, cu atât pare mai grăbit și mai „greșit”).
@export var pasi_pe_secunda := 7.5
## Cât de tare balansează picioarele și brațele (grade).
@export var amplitudine_picioare := 55.0
@export var amplitudine_brate := 70.0
## Cât de aplecat în față aleargă (grade).
@export var aplecare := 28.0
## Pașii pe frunze; se alege unul la întâmplare la fiecare pas.
@export var pasi: Array[AudioStream] = []

var alearga := false

@onready var _model: Node3D = $Model
@onready var _sunet_pasi: AudioStreamPlayer3D = $Pasi
var _brate: Array[Node3D] = []
var _picioare: Array[Node3D] = []
var _faza := 0.0
var _pas_anterior := 0


func _ready() -> void:
	for nume in ["BratS", "BratD"]:
		_brate.append(_model.find_child(nume) as Node3D)
	for nume in ["PiciorS", "PiciorD"]:
		_picioare.append(_model.find_child(nume) as Node3D)


func _process(delta: float) -> void:
	if not alearga:
		return
	_faza += delta * pasi_pe_secunda * PI  # un ciclu întreg = doi pași
	var u := sin(_faza)
	for i in 2:
		var semn := 1.0 if i == 0 else -1.0
		if _picioare[i]:
			_picioare[i].rotation.x = deg_to_rad(amplitudine_picioare) * u * semn
		if _brate[i]:
			# brațele lungi se bălăngăne pe dos față de picioare, și puțin în lături
			_brate[i].rotation.x = -deg_to_rad(amplitudine_brate) * u * semn - deg_to_rad(20.0)
			_brate[i].rotation.z = deg_to_rad(8.0) * semn
	_model.rotation.x = deg_to_rad(aplecare)
	# saltă la fiecare pas, cu capul smucit
	_model.position.y = absf(cos(_faza)) * 0.12
	_model.rotation.z = sin(_faza) * deg_to_rad(6.0)
	var pas := int(_faza / PI)
	if pas != _pas_anterior:
		_pas_anterior = pas
		if not pasi.is_empty():
			_sunet_pasi.stream = pasi.pick_random()
			_sunet_pasi.pitch_scale = randf_range(1.15, 1.4)
			_sunet_pasi.play()
