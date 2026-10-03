class_name Creatura
extends Node3D
## Ce aleargă prin pădure. Scriptul face doar mișcarea membrelor și pașii;
## pe unde aleargă hotărăște scena (ex. drum_autobuz.gd mută nodul).
## Modelul privește spre +Z: acolo aleargă.

## Câți pași pe secundă (cu cât mai mulți, cu atât pare mai grăbit și mai „greșit”).
@export var pasi_pe_secunda := 5.0
## Cât de tare balansează picioarele și brațele (grade).
@export var amplitudine_picioare := 55.0
@export var amplitudine_brate := 70.0
## Cât de aplecat în față aleargă (grade).
@export var aplecare := 28.0
## Pașii (sunetele creatura_pas_*: grei, umezi, cu pocnet de oase); unul la întâmplare la fiecare bătaie.
@export var pasi: Array[AudioStream] = []
## Cât de tare se aud pașii (dB).
@export var volum_pasi_db := 3.0

var alearga := false

@onready var _model: Node3D = $Model
var _brate: Array[Node3D] = []
var _picioare: Array[Node3D] = []
var _faza := 0.0
## Unde cad pașii într-un ciclu (0..1): două perechi, inegal, ca un galop șchiop.
const BATAI: Array[float] = [0.0, 0.09, 0.5, 0.56]
var _ultima_bataie: Array[float] = [-1.0, -1.0, -1.0, -1.0]


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
	# pașii: nu un mers normal, ci un galop șchiop, pe patru „picioare” (tălpile și pumnii),
	# în perechi apropiate — ta-tam ... ta-tam — grei, umezi, cu încheieturi care pocnesc
	var ciclu := _faza / TAU
	for i in BATAI.size():
		var moment: float = floorf(ciclu - BATAI[i]) + BATAI[i]
		if moment > _ultima_bataie[i] and ciclu >= moment:
			_ultima_bataie[i] = moment
			_pas(i)


func _pas(i: int) -> void:
	if pasi.is_empty():
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = pasi.pick_random()
	# a doua bătaie din pereche e mai ușoară (pumnul), prima mai grea (talpa)
	p.volume_db = volum_pasi_db - (4.0 if i % 2 == 1 else 0.0) + randf_range(-1.5, 1.5)
	p.pitch_scale = randf_range(0.78, 0.95)
	p.unit_size = 6.0
	p.max_distance = 45.0
	p.bus = &"Efecte"
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()
