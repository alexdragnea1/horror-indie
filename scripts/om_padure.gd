extends Node3D
## Omul care se ușurează în pădure, pe urcușul spre platou (scenes/om_padure.tscn, în padure.tscn sub PePamant).
## Stă ghinuit printre copaci, aproape de potecă, și se screme (mormăieli, pârțuri, câte un pleoscăit). Când te
## apropii (`raza_vazut`) îngheață și se uită la tine; dacă vii lângă el (`raza_fuga`) țipă, sare în picioare și o ia la
## fugă cu pantalonii în vine, departe de potecă: trece prin zidul invizibil (nu e un corp fizic) și se topește în ceață.
## Rămâne în urmă grămăjoara (`Caca`). O singură dată (`marcaj`); la Continue nu mai e acolo.
## Modelul (`om_padure.glb`, tools/blender/padure.py) e în picioare: ghemuitul și fuga se fac din piese.

@export var teren: TerenPadure
@export var marcaj := "omul_din_padure_a_fugit"
@export var raza_vazut := 8.0
@export var raza_fuga := 4.0
## Cât de repede fuge (m/s) și cât fuge până dispare (s).
@export var viteza := 5.5
@export var durata_fuga := 5.0

@export_group("Sunete")
@export var icnit: Array[AudioStream] = []
@export var part: Array[AudioStream] = []
@export var plop: AudioStream
@export var tipat: AudioStream
@export var pasi: Array[AudioStream] = []
@export var fosnet: Array[AudioStream] = []
@export var crengi: AudioStream

## Ghemuit: modelul coborât (bazinul la ~0,41 m) și dus puțin în spate, ca tălpile să stea sub genunchi.
const GHEMUIT := Vector3(0.0, -0.49, -0.16)

enum { SE_SCREME, INGHETAT, FUGE, PLECAT }
var _stare := SE_SCREME
var _pana_la_sunet := 1.5
var _timp := 0.0
var _faza := 0.0
var _directie := Vector3.FORWARD
var _ultimul_pas := 0

@onready var _model: Node3D = $Model
@onready var _corp: Node3D = $Model.find_child("Corp") as Node3D
@onready var _cap: Node3D = $Model.find_child("Cap") as Node3D
@onready var _brate: Array[Node3D] = [$Model.find_child("BratS") as Node3D, $Model.find_child("BratD") as Node3D]
@onready var _coapse: Array[Node3D] = [$Model.find_child("CoapsaS") as Node3D, $Model.find_child("CoapsaD") as Node3D]
@onready var _gambe: Array[Node3D] = [$Model.find_child("GambaS") as Node3D, $Model.find_child("GambaD") as Node3D]


func _ready() -> void:
	if Stare.e_marcat(marcaj):
		_model.queue_free()
		_stare = PLECAT
		set_process(false)
		return
	_ghemuit(0.0)


func _process(delta: float) -> void:
	_timp += delta
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	match _stare:
		SE_SCREME:
			_ghemuit(_timp)
			_pana_la_sunet -= delta
			if _pana_la_sunet <= 0.0:
				_se_screme()
			if jucator and _distanta(jucator) < raza_vazut:
				_stare = INGHETAT
		INGHETAT:
			_ghemuit(0.0)
			if jucator:
				_priveste(jucator, delta)
				if _distanta(jucator) < raza_fuga:
					_fugi(jucator)
				elif _distanta(jucator) > raza_vazut + 3.0:
					_stare = SE_SCREME
					_pana_la_sunet = 2.0
		FUGE:
			_alearga(delta)


func _distanta(jucator: Node3D) -> float:
	return Vector2(jucator.global_position.x - global_position.x, jucator.global_position.z - global_position.z).length()


## Poza ghemuită; `t` > 0 = se screme (tremură puțin și se apleacă în ritmul mormăielii).
func _ghemuit(t: float) -> void:
	_model.position = GHEMUIT
	var efort := maxf(sin(t * 1.3), 0.0) if t > 0.0 else 0.0
	_corp.rotation = Vector3(deg_to_rad(28.0 + efort * 6.0), 0.0, sin(t * 37.0) * 0.012 * efort)
	for i in 2:
		_coapse[i].rotation = Vector3(deg_to_rad(-100.0), 0.0, deg_to_rad(8.0) * (-1.0 if i == 0 else 1.0))
		_gambe[i].rotation = Vector3(deg_to_rad(110.0), 0.0, 0.0)
		_brate[i].rotation = Vector3(deg_to_rad(-62.0), 0.0, deg_to_rad(12.0) * (-1.0 if i == 0 else 1.0))
	if t > 0.0:
		_cap.rotation = Vector3(deg_to_rad(-10.0 + efort * 12.0), sin(t * 0.4) * 0.5, 0.0)


func _se_screme() -> void:
	_pana_la_sunet = randf_range(3.5, 6.5)
	var sus := global_position + Vector3.UP * 0.6
	Sunet.reda_la(icnit.pick_random(), sus, 0.0, 0.06)
	var noroc := randf()
	if noroc < 0.55 and not part.is_empty():
		await get_tree().create_timer(randf_range(0.7, 1.0)).timeout
		if _stare == SE_SCREME:
			Sunet.reda_la(part.pick_random(), global_position + Vector3.UP * 0.4, 0.0, 0.08)
	if noroc < 0.3:
		await get_tree().create_timer(0.6).timeout
		if _stare == SE_SCREME:
			Sunet.reda_la(plop, global_position, 0.0, 0.1)


## Capul se întoarce spre tine (cât poate, fără să se învârtă cu totul).
func _priveste(jucator: Node3D, delta: float) -> void:
	var spre := _cap.global_position.direction_to(jucator.global_position + Vector3.UP * 1.5)
	var local := global_basis.inverse() * spre
	var yaw := clampf(atan2(local.x, local.z), -1.3, 1.3)
	var pitch := clampf(-asin(clampf(local.y, -1.0, 1.0)), -0.6, 0.4)
	_cap.rotation.y = lerp_angle(_cap.rotation.y, yaw, minf(delta * 6.0, 1.0))
	_cap.rotation.x = lerpf(_cap.rotation.x, pitch - _corp.rotation.x, minf(delta * 6.0, 1.0))


func _fugi(jucator: Node3D) -> void:
	_stare = FUGE
	Stare.marcheaza(marcaj)
	Sunet.reda_la(tipat, global_position + Vector3.UP * 1.2)
	# departe de potecă și de tine
	var dinspre := global_position - jucator.global_position
	dinspre.y = 0.0
	var poteca := global_position - _cel_mai_apropiat_de_poteca()
	poteca.y = 0.0
	_directie = (poteca.normalized() * 2.0 + dinspre.normalized()).normalized()
	_timp = 0.0
	# sare în picioare și se întoarce
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_model, "position", Vector3.ZERO, 0.35)
	t.tween_property(self, "rotation:y", atan2(_directie.x, _directie.z), 0.35)
	t.tween_property(_cap, "rotation", Vector3.ZERO, 0.3)
	Sunet.reda_la(crengi, global_position + _directie * 4.0 + Vector3.UP)
	await get_tree().create_timer(durata_fuga * 0.45).timeout
	if _stare == FUGE:
		Sunet.reda_la(part.back(), global_position + Vector3.UP * 0.4)
		Sunet.reda_la(crengi, global_position + Vector3.UP)


## Fuga cu pantalonii în vine: pași mărunți și repezi, brațele dau din lături, rola de hârtie fluturată deasupra capului.
func _alearga(delta: float) -> void:
	var porneste := minf(_timp / 0.35, 1.0)
	if _timp < 0.35:
		# se ridică: picioarele se îndreaptă din ghemuit
		for i in 2:
			_coapse[i].rotation.x = lerpf(deg_to_rad(-100.0), 0.0, porneste)
			_gambe[i].rotation.x = lerpf(deg_to_rad(110.0), 0.0, porneste)
		_corp.rotation.x = lerpf(deg_to_rad(28.0), deg_to_rad(18.0), porneste)
		return
	var accel := minf((_timp - 0.35) / 0.6, 1.0)
	global_position += _directie * viteza * accel * delta
	global_position.y = teren.inaltime(global_position.x, global_position.z)
	_faza += delta * TAU * 4.2
	var u := sin(_faza)
	for i in 2:
		var semn := 1.0 if i == 0 else -1.0
		_coapse[i].rotation = Vector3(deg_to_rad(-30.0) * u * semn - deg_to_rad(10.0), 0.0, 0.0)
		_gambe[i].rotation = Vector3(deg_to_rad(45.0) * maxf(u * semn, 0.0) + deg_to_rad(10.0), 0.0, 0.0)
	_brate[0].rotation = Vector3(deg_to_rad(-50.0) * u - deg_to_rad(20.0), 0.0, deg_to_rad(-35.0 - 15.0 * u))
	_brate[1].rotation = Vector3(deg_to_rad(-160.0) + sin(_faza * 0.5) * 0.4, 0.0, deg_to_rad(15.0))
	# pe la jumătate se împiedică în pantaloni și aproape cade
	var impiedicat := clampf(1.0 - absf(_timp - durata_fuga * 0.45) / 0.25, 0.0, 1.0)
	_corp.rotation = Vector3(deg_to_rad(18.0 + impiedicat * 35.0), 0.0, sin(_faza * 0.5) * 0.08)
	_cap.rotation.x = deg_to_rad(-10.0 - impiedicat * 20.0)
	_model.position.y = absf(cos(_faza)) * 0.07
	var pas := int(_faza / PI)
	if pas != _ultimul_pas:
		_ultimul_pas = pas
		Sunet.reda_la(pasi.pick_random(), global_position, Sunet.VOLUM_PASI, 0.08)
		if pas % 2 == 0 and not fosnet.is_empty():
			Sunet.reda_la(fosnet.pick_random(), global_position + Vector3.UP, -6.0, 0.1)
	if _timp > durata_fuga:
		# se topește în ceață (pe pixeli, ca celelalte modele PS2)
		_stare = PLECAT
		var t := create_tween()
		t.tween_method(func(v: float) -> void: ModelPS2.disparitie(_model, v), 0.0, 1.0, 0.8)
		t.tween_callback(_model.queue_free)
		set_process(false)


func _cel_mai_apropiat_de_poteca() -> Vector3:
	var q := Vector2(global_position.x, global_position.z)
	var cel := q
	var d_min := INF
	for drum: PackedVector2Array in [teren.poteca_principala, teren.poteca_dreapta, teren.poteca_stanga]:
		for i in drum.size() - 1:
			var p := Geometry2D.get_closest_point_to_segment(q, drum[i], drum[i + 1])
			if p.distance_to(q) < d_min:
				d_min = p.distance_to(q)
				cel = p
	return Vector3(cel.x, global_position.y, cel.y)
