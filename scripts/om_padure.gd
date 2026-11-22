extends Node3D
## Omul care se ușurează în pădure, pe urcușul spre platou (scenes/om_padure.tscn, în padure.tscn sub PePamant).
## Stă ghinuit printre copaci, aproape de potecă, și se screme (mormăieli, pârțuri, câte un pleoscăit). Când te
## apropii (`raza_vazut`) îngheață și se uită la tine; dacă vii lângă el (`raza_fuga`) țipă, sare în picioare și o ia la
## fugă cu pantalonii în vine, departe de potecă: trece prin zidul invizibil (nu e un corp fizic) și se topește în ceață.
## Rămâne în urmă grămăjoara (`Caca`). Marcajul `marcaj`: la Continue nu mai e acolo.
## Modelul (`om_padure.glb`, tools/blender/padure.py) e în picioare: ghemuitul și fuga se fac din piese.
##
## Se poate omorî (owner, 15.11): are un hitbox (`Hitbox`, cutie pe stratul 1) și un glonț îl omoară ca pe bețiv
## (Personaj.omoara: ragdoll pe spate, apoi „[E] Pick up the guy”), doar cât n-ai omorât pe nimeni
## (`Personaj.MARCAJ_CRIMA`; altfel glonțul doar îl sperie și fuge). E în grupul „cadavre”, deci îl poți arunca în
## cazan în locul bețivului (cazan.gd). Owner 22.11: îl prinzi O SINGURĂ DATĂ — dacă a fugit, nu mai revine.
## (Varianta veche, doar cu `revine` bifat: după ce ai primit
## pistolul (`marcaj_intors`) și până la vrajă se întoarce la locul lui; o singură dată: dacă fuge iar,
## `marcaj_fugit_iar`, nu mai vine). Dacă îl împuști din fugă, cadavrul cade în pădure: acolo se poate umbla
## (cercul lui din `cercuri_extra`, limite_padure.gd).

@export var teren: TerenPadure
@export var marcaj := "omul_din_padure_a_fugit"
@export var raza_vazut := 8.0
@export var raza_fuga := 4.0
## Cât de repede fuge (m/s) și cât fuge până dispare (s).
@export var viteza := 5.5
@export var durata_fuga := 5.0

@export_group("Moarte")
## După pistol (sefa_vrajitoare.gd) se întoarce, dacă fugise; după vrajă nu mai vine.
@export var marcaj_intors := "a_vorbit_cu_vrajitoarele"
@export var marcaj_vraja := "vraja_facuta"
@export var marcaj_fugit_iar := "omul_din_padure_a_fugit_iar"
## Bifat = după ce a fugit, se întoarce o dată după pistol. Owner 22.11: NU (îl prinzi o singură dată, apoi a plecat de tot).
@export var revine := false
@export var marcaj_mort := "omul_din_padure_e_mort"
@export var marcaj_luat := "omul_din_padure_luat"
@export var id_cadavru := "cadavru_om_padure"
@export var nume_cadavru := "Guy"
@export var indiciu_cadavru := "[E] Pick up the guy"
@export var forta_glont := 320.0
@export var sunet_cadere: AudioStream = preload("res://sunete/corp_cazut.ogg")
@export var sunet_luat: AudioStream = preload("res://sunete/corp_luat.ogg")

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
## Hitbox-ul: ghemuit și în picioare (mărime, mijloc).
const CUTIE_GHEMUIT := [Vector3(0.6, 1.15, 0.75), Vector3(0.0, 0.58, -0.05)]
const CUTIE_PICIOARE := [Vector3(0.55, 1.75, 0.5), Vector3(0.0, 0.88, 0.0)]

enum { SE_SCREME, INGHETAT, FUGE, PLECAT, MORT }
var _stare := SE_SCREME
var _pana_la_sunet := 1.5
var _timp := 0.0
var _faza := 0.0
var _directie := Vector3.FORWARD
var _ultimul_pas := 0
var _loc_start := Vector3.ZERO
var _unghi_start := 0.0
var _scena_model := ""
var _sarit: Tween
var _hitbox: StaticBody3D
var _forma: BoxShape3D
var _cadavru: Ragdoll
var mort := false

@onready var _model: Node3D = $Model
@onready var _caca: Node3D = get_node_or_null("Caca")
@onready var _corp: Node3D = $Model.find_child("Corp") as Node3D
@onready var _cap: Node3D = $Model.find_child("Cap") as Node3D
@onready var _brate: Array[Node3D] = [$Model.find_child("BratS") as Node3D, $Model.find_child("BratD") as Node3D]
@onready var _coapse: Array[Node3D] = [$Model.find_child("CoapsaS") as Node3D, $Model.find_child("CoapsaD") as Node3D]
@onready var _gambe: Array[Node3D] = [$Model.find_child("GambaS") as Node3D, $Model.find_child("GambaD") as Node3D]


func _ready() -> void:
	add_to_group("cadavre")  # cazanul îl caută aici (cazan.gd)
	_scena_model = _model.scene_file_path
	_unghi_start = rotation.y
	_fa_hitbox()
	if Stare.e_marcat(marcaj_luat):
		# l-ai luat deja (în inventar sau în cazan): rămâne doar grămăjoara
		mort = true
		_stare = MORT
		Stare.marcheaza(Personaj.MARCAJ_CRIMA)
		_model.queue_free()
		_hitbox.queue_free()
		set_process(false)
		return
	_ghemuit(0.0)
	if Stare.e_marcat(marcaj_mort):
		# mort de dinainte (Continue): cade pe loc, după ce scena e așezată pe teren
		mort = true
		_stare = MORT
		set_process(false)
		await get_tree().process_frame
		_omoara(Vector3.ZERO, 0.0)
		return
	if Stare.e_marcat(marcaj):
		_ascunde()
	await get_tree().process_frame
	_loc_start = global_position  # după ce l-a pus PePamant pe teren


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
		PLECAT:
			if _timp > 1.0:
				_timp = 0.0
				if _poate_reveni(jucator):
					_revino()


func _distanta(jucator: Node3D) -> float:
	return Vector2(jucator.global_position.x - global_position.x, jucator.global_position.z - global_position.z).length()


## Cutia în care intră gloanțele (și de care te lovești). Pe stratul 1, ca pistolul s-o vadă.
func _fa_hitbox() -> void:
	_hitbox = StaticBody3D.new()
	_hitbox.name = "Hitbox"
	_hitbox.set_script(preload("res://scripts/om_padure_hitbox.gd"))
	_hitbox.set("om", self)
	var forma := CollisionShape3D.new()
	_forma = BoxShape3D.new()
	forma.shape = _forma
	_hitbox.add_child(forma)
	add_child(_hitbox)
	_cutie(CUTIE_GHEMUIT)


func _cutie(c: Array) -> void:
	if not is_instance_valid(_hitbox):
		return
	_forma.size = c[0]
	(_hitbox.get_child(0) as CollisionShape3D).position = c[1]


func _hitbox_activ(da: bool) -> void:
	if is_instance_valid(_hitbox):
		(_hitbox.get_child(0) as CollisionShape3D).set_deferred("disabled", not da)


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
	# a doua oară (după ce s-a întors) nu mai vine înapoi
	Stare.marcheaza(marcaj_fugit_iar if Stare.e_marcat(marcaj) else marcaj)
	# grămăjoara rămâne pe loc (owner, 17.10): era copilul nostru și fugea cu noi
	_lasa_caca()
	_cutie(CUTIE_PICIOARE)
	Sunet.reda_la(tipat, global_position + Vector3.UP * 1.2)
	# departe de potecă și de tine
	var dinspre := global_position - jucator.global_position
	dinspre.y = 0.0
	var poteca := global_position - _cel_mai_apropiat_de_poteca()
	poteca.y = 0.0
	_directie = (poteca.normalized() * 2.0 + dinspre.normalized()).normalized()
	_timp = 0.0
	# sare în picioare și se întoarce
	_sarit = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sarit.tween_property(_model, "position", Vector3.ZERO, 0.35)
	_sarit.tween_property(self, "rotation:y", atan2(_directie.x, _directie.z), 0.35)
	_sarit.tween_property(_cap, "rotation", Vector3.ZERO, 0.3)
	Sunet.reda_la(crengi, global_position + _directie * 4.0 + Vector3.UP)
	await get_tree().create_timer(durata_fuga * 0.45).timeout
	if _stare == FUGE:
		Sunet.reda_la(part.back(), global_position + Vector3.UP * 0.4)
		Sunet.reda_la(crengi, global_position + Vector3.UP)


func _lasa_caca() -> void:
	if is_instance_valid(_caca) and _caca.get_parent() == self:
		_caca.reparent(get_parent(), true)


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
		_timp = 0.0
		_hitbox_activ(false)
		var t := create_tween()
		t.tween_method(func(v: float) -> void: ModelPS2.disparitie(_model, v), 0.0, 1.0, 0.8)
		t.tween_callback(_model.hide)


## Plecat (la Continue, după ce a fugit): nu se vede, gloanțele trec prin locul lui.
func _ascunde() -> void:
	_stare = PLECAT
	_model.hide()
	_hitbox_activ(false)


## Se întoarce doar după pistol, înainte de vrajă, o singură dată, și cât nu ești pe aproape să-l vezi apărând.
func _poate_reveni(jucator: Node3D) -> bool:
	if not revine or jucator == null or Stare.e_marcat(marcaj_fugit_iar) or not Stare.e_marcat(marcaj_intors):
		return false
	if Stare.e_marcat(marcaj_vraja) or Stare.e_marcat(Personaj.MARCAJ_CRIMA):
		return false
	return jucator.global_position.distance_to(_loc_start) > 25.0


func _revino() -> void:
	global_position = _loc_start
	rotation.y = _unghi_start
	_cap.rotation = Vector3.ZERO
	_ghemuit(0.0)
	ModelPS2.disparitie(_model, 0.0)
	_model.show()
	_cutie(CUTIE_GHEMUIT)
	_hitbox_activ(true)
	_pana_la_sunet = 1.5
	_timp = 0.0
	_stare = SE_SCREME


## Glonțul (prin Hitbox, om_padure_hitbox.gd). Moare doar dacă n-ai mai omorât pe nimeni; altfel doar se sperie.
func impuscat(directie: Vector3, _punct := Vector3.ZERO) -> void:
	if mort or _stare == PLECAT:
		return
	if Stare.e_marcat(Personaj.MARCAJ_CRIMA):
		var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
		if jucator and _stare != FUGE:
			_fugi(jucator)
		return
	_omoara(directie, forta_glont)


## Ca Personaj.omoara: cade moale pe spate, iar după ce se liniștește îl iei cu E.
func _omoara(directie: Vector3, forta: float) -> void:
	mort = true
	_stare = MORT
	set_process(false)
	Stare.marcheaza(Personaj.MARCAJ_CRIMA)
	Stare.marcheaza(marcaj_mort)
	if _sarit and _sarit.is_valid():
		_sarit.kill()
	_lasa_caca()
	if is_instance_valid(_hitbox):
		_hitbox.queue_free()
	ModelPS2.disparitie(_model, 0.0)
	_model.show()
	var spate := -global_basis.z  # modelele privesc spre +Z
	var orizontal := Vector3(directie.x, 0.0, directie.z).normalized()
	var impuls := (spate * 0.8 + orizontal * 0.2 + Vector3.UP * 0.15).normalized() * forta
	_cadavru = Ragdoll.din_model(_model, impuls)
	if forta > 0.0:
		await get_tree().create_timer(0.45).timeout
		if is_instance_valid(_cadavru):
			Sunet.reda_la(sunet_cadere, _cadavru.centru(), Sunet.VOLUM_EFECTE, 0.05)
	var asteptat := 0.0
	while is_instance_valid(_cadavru) and asteptat < 3.0 and not (asteptat > 0.6 and _cadavru.s_a_oprit()):
		await get_tree().create_timer(0.2).timeout
		asteptat += 0.2
	if is_instance_valid(_cadavru):
		_cadavru.pune_ridicare(id_cadavru, nume_cadavru, indiciu_cadavru).folosit.connect(_luat)


func _luat() -> void:
	Stare.marcheaza(marcaj_luat)
	Sunet.reda(sunet_luat, Sunet.VOLUM_EFECTE, 0.05)
	_cadavru.queue_free()


## Modelul aruncat în cazan (același .glb).
func model_cadavru() -> PackedScene:
	return load(_scena_model) if _scena_model != "" else null


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
