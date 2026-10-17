extends Node3D
## Maimuța care se ușurează în spatele primăriei (owner, 17.10; scenes/maimuta_caca.tscn, în primarie.tscn), pe
## culoarul dintre zidul din spate și gard, în spatele biroului de la Taxe. Stă ghemuită cu fața spre gard și se
## screme (mormăieli mici, pârțuri, câte un pleoscăit), ca omul din pădure (om_padure.gd). Când te VEDE (ești în
## `raza_vazut` și nu e un zid între voi) îngheață o clipă cu capul spre tine, țipă („uh-uh-AAH-AAH”), sare în
## picioare și peste gard (`aterizare`) și o ia la fugă pe câmp până se topește (pe pixeli, ca celelalte modele PS2).
## Rămâne în urmă grămăjoara (`Caca`). O singură dată (`marcaj`); la Continue nu mai e acolo.
## Modelul (`maimuta_caca.glb`, tools/blender/primarie.py) e în picioare, cu fața spre +Z: ghemuitul și fuga se fac
## din piese (Corp, Cap, BratS/D, CoapsaS/D → GambaS/D).

@export var marcaj := "maimuta_din_spatele_primariei_a_fugit"
## Unde aterizează dincolo de gard (tălpile); de acolo fuge mai departe în aceeași direcție.
@export var aterizare: Marker3D
@export var raza_vazut := 9.0
## Cât stă înghețată, uitându-se la tine, înainte să țipe și să fugă.
@export var timp_inghetat := 0.55
## Cât de repede fuge (m/s) și cât fuge după gard până dispare (s).
@export var viteza := 6.5
@export var durata_fuga := 3.5
## Cât de sus sare peste gard (bazinul, peste înălțimea lui în picioare).
@export var inaltime_salt := 1.45

@export_group("Sunete")
@export var icnit: Array[AudioStream] = []
@export var part: Array[AudioStream] = []
@export var plop: AudioStream
@export var tipat: AudioStream
@export var gard: AudioStream
@export var pasi: Array[AudioStream] = []

## Bazinul deasupra tălpilor, în picioare (originea lui `Corp`).
const BAZIN := 0.6
## Ghemuit: modelul coborât (bazinul la ~0,27 m) și dus puțin în spate, ca tălpile să stea sub genunchi.
const GHEMUIT := Vector3(0.0, -0.33, -0.12)

enum { SE_SCREME, INGHETAT, FUGE, PLECAT }
var _stare := SE_SCREME
var _pana_la_sunet := 1.2
var _timp := 0.0
var _faza := 0.0
var _directie := Vector3.FORWARD
var _ultimul_pas := 0
var _jucator: Node3D

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
	if _jucator == null:
		_jucator = get_tree().get_first_node_in_group("jucator") as Node3D
	match _stare:
		SE_SCREME:
			_ghemuit(_timp)
			_pana_la_sunet -= delta
			if _pana_la_sunet <= 0.0:
				_se_screme()
			if _jucator and _te_vede():
				_stare = INGHETAT
				_timp = 0.0
		INGHETAT:
			_ghemuit(0.0)
			if _jucator:
				_priveste(_jucator, delta)
			if _timp >= timp_inghetat:
				_fugi()
		FUGE:
			_alearga(delta)


## Ești aproape și nu e nimic între capul ei și al tău (zidul primăriei, colțul clădirii).
func _te_vede() -> bool:
	var d := Vector2(_jucator.global_position.x - global_position.x, _jucator.global_position.z - global_position.z)
	if d.length() > raza_vazut:
		return false
	var de_la := _cap.global_position + Vector3.UP * 0.1
	var pana_la := _jucator.global_position + Vector3.UP * 1.5
	var q := PhysicsRayQueryParameters3D.create(de_la, pana_la, 1)
	if _jucator is CollisionObject3D:
		q.exclude = [(_jucator as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Poza ghemuită; `t` > 0 = se screme (tremură puțin și se apleacă în ritmul mormăielii).
func _ghemuit(t: float) -> void:
	_model.position = GHEMUIT
	var efort := maxf(sin(t * 1.3), 0.0) if t > 0.0 else 0.0
	_corp.rotation = Vector3(deg_to_rad(22.0 + efort * 6.0), 0.0, sin(t * 37.0) * 0.015 * efort)
	for i in 2:
		var semn := 1.0 if i == 0 else -1.0
		_coapse[i].rotation = Vector3(deg_to_rad(-100.0), 0.0, deg_to_rad(-14.0) * semn)
		_gambe[i].rotation = Vector3(deg_to_rad(112.0), 0.0, 0.0)
		# antebrațele sprijinite pe genunchi, mâinile atârnă în față
		_brate[i].rotation = Vector3(deg_to_rad(-48.0), 0.0, deg_to_rad(-6.0) * semn)
	if t > 0.0:
		_cap.rotation = Vector3(deg_to_rad(-8.0 + efort * 14.0), sin(t * 0.5) * 0.6, 0.0)


func _se_screme() -> void:
	_pana_la_sunet = randf_range(3.0, 5.5)
	var sus := global_position + Vector3.UP * 0.5
	if not icnit.is_empty():
		Sunet.reda_la(icnit.pick_random(), sus, 0.0, 0.08)
	var noroc := randf()
	if noroc < 0.55 and not part.is_empty():
		await get_tree().create_timer(randf_range(0.6, 0.9)).timeout
		if _stare == SE_SCREME:
			Sunet.reda_la(part.pick_random(), global_position + Vector3.UP * 0.3, 0.0, 0.1)
	if noroc < 0.3 and plop:
		await get_tree().create_timer(0.5).timeout
		if _stare == SE_SCREME:
			Sunet.reda_la(plop, global_position, 0.0, 0.1)


## Capul se întoarce spre tine (cât poate, fără să se învârtă cu totul).
func _priveste(jucator: Node3D, delta: float) -> void:
	var spre := _cap.global_position.direction_to(jucator.global_position + Vector3.UP * 1.5)
	var local := global_basis.inverse() * spre
	var yaw := clampf(atan2(local.x, local.z), -1.5, 1.5)
	var pitch := clampf(-asin(clampf(local.y, -1.0, 1.0)), -0.6, 0.4)
	_cap.rotation.y = lerp_angle(_cap.rotation.y, yaw, minf(delta * 10.0, 1.0))
	_cap.rotation.x = lerpf(_cap.rotation.x, pitch - _corp.rotation.x, minf(delta * 10.0, 1.0))


## Țipă, sare în picioare și peste gard, apoi fuge mai departe (`_alearga`).
func _fugi() -> void:
	_stare = PLECAT  # cât sare, nu mai face nimic altceva
	Stare.marcheaza(marcaj)
	# grămăjoara rămâne pe loc (owner, 17.10): era copilul nostru și fugea cu noi
	var caca := get_node_or_null("Caca") as Node3D
	if caca:
		caca.reparent(get_parent(), true)
	if tipat:
		Sunet.reda_la(tipat, _cap.global_position)
	var start := global_position
	var tinta := aterizare.global_position if aterizare else start + global_basis.z * 2.5
	_directie = Vector3(tinta.x - start.x, 0.0, tinta.z - start.z).normalized()
	# se ridică dintr-o smucitură și se întoarce spre gard
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_model, "position", Vector3.ZERO, 0.25)
	t.tween_property(self, "rotation:y", atan2(_directie.x, _directie.z), 0.25)
	t.tween_property(_cap, "rotation", Vector3.ZERO, 0.25)
	t.tween_property(_corp, "rotation", Vector3(deg_to_rad(15.0), 0.0, 0.0), 0.25)
	for i in 2:
		t.tween_property(_coapse[i], "rotation", Vector3.ZERO, 0.2)
		t.tween_property(_gambe[i], "rotation", Vector3.ZERO, 0.2)
		t.tween_property(_brate[i], "rotation", Vector3(deg_to_rad(-150.0), 0.0, deg_to_rad(20.0) * (1.0 if i == 0 else -1.0)), 0.25)
	await t.finished
	# săritura: un arc peste gard, picioarele strânse, brațele sus; scapă un pârț de frică în vârf
	var durata := 0.75
	var timp := 0.0
	var a_zanganit := false
	while timp < durata:
		await get_tree().process_frame
		if not is_instance_valid(_model):
			return
		timp += get_process_delta_time()
		var v := minf(timp / durata, 1.0)
		global_position = start.lerp(tinta, v) + Vector3.UP * sin(v * PI) * inaltime_salt
		for i in 2:
			_coapse[i].rotation.x = lerpf(_coapse[i].rotation.x, deg_to_rad(-80.0), 0.3)
			_gambe[i].rotation.x = lerpf(_gambe[i].rotation.x, deg_to_rad(100.0), 0.3)
		if v > 0.45 and not a_zanganit:
			a_zanganit = true
			if gard:
				Sunet.reda_la(gard, global_position + Vector3.DOWN * 0.6, -3.0, 0.05)
			if not part.is_empty():
				Sunet.reda_la(part.pick_random(), global_position, 0.0, 0.1)
	global_position = tinta
	if not pasi.is_empty():
		Sunet.reda_la(pasi.pick_random(), global_position, Sunet.VOLUM_PASI, 0.08)
	_timp = 0.0
	_stare = FUGE


## Fuga pe două picioare, legănată, cu brațele lungi bălăngănindu-se deasupra capului.
func _alearga(delta: float) -> void:
	var accel := minf(_timp / 0.4, 1.0)
	global_position += _directie * viteza * (0.5 + 0.5 * accel) * delta
	_faza += delta * TAU * 3.6
	var u := sin(_faza)
	for i in 2:
		var semn := 1.0 if i == 0 else -1.0
		_coapse[i].rotation = Vector3(deg_to_rad(-40.0) * u * semn - deg_to_rad(10.0), 0.0, deg_to_rad(-10.0) * semn)
		_gambe[i].rotation = Vector3(deg_to_rad(55.0) * maxf(u * semn, 0.0) + deg_to_rad(10.0), 0.0, 0.0)
		_brate[i].rotation = Vector3(deg_to_rad(-150.0) + u * semn * 0.5, 0.0, deg_to_rad(25.0 + 10.0 * u) * semn)
	_corp.rotation = Vector3(deg_to_rad(20.0), 0.0, sin(_faza) * 0.12)
	_cap.rotation = Vector3(deg_to_rad(-10.0), 0.0, sin(_faza * 0.5) * 0.15)
	_model.position.y = absf(cos(_faza)) * 0.08
	var pas := int(_faza / PI)
	if pas != _ultimul_pas:
		_ultimul_pas = pas
		if not pasi.is_empty():
			Sunet.reda_la(pasi.pick_random(), global_position, Sunet.VOLUM_PASI - 2.0, 0.1)
	if _timp > durata_fuga:
		_stare = PLECAT
		var t := create_tween()
		t.tween_method(func(v: float) -> void: ModelPS2.disparitie(_model, v), 0.0, 1.0, 0.8)
		t.tween_callback(_model.queue_free)
		set_process(false)
