extends Node3D
## Scena din autobuz (cutscene): stai pe scaun lângă geam și autobuzul merge noaptea pe lângă pădure.
## Când te uiți spre pădure (pe geamul din stânga), ceva aleargă foarte repede pe lângă autobuz,
## te depășește și dispare printre copaci. Dacă nu te uiți, întâi se aud crengi rupte în pădure,
## iar până la urmă privirea se întoarce singură. Apoi un mic dialog, autobuzul oprește la capăt de linie
## și scena se termină (`scena_urmatoare`, sau „To be continued...” și meniul, cât pădurea nu e gata).
##
## Autobuzul chiar merge (pe +Z); pădurea, stâlpii și liniile drumului sunt „bandă rulantă”:
## ce rămâne în urmă e mutat în față. Solul și asfaltul merg odată cu autobuzul, dar textura lor
## e luată din coordonatele lumii (uv_din_lume), deci par să stea pe loc.

@export var autobuz: Autobuz
@export var calator: Calator
@export var creatura: Creatura
## Nodul cu solul și drumul: îl ține mereu în dreptul autobuzului.
@export var teren: Node3D

## Viteza autobuzului (m/s; 13 ≈ 47 km/h).
@export var viteza := 13.0
## Cât de tare frânează la capăt (m/s²).
@export var decelerare := 2.8

@export_group("Creatura")
## După câte secunde poate apărea (să ai timp să te așezi).
@export var armare := 9.0
## Cât te uiți spre pădure până apare (secunde).
@export var timp_privire := 0.35
## Dacă nu te-ai uitat: după atâtea secunde se aud crengi rupte în pădure (momeala)...
@export var momeala := 10.0
## ...iar după atâtea, privirea se întoarce singură spre geam.
@export var fortat := 20.0
## Cât stă lângă geamul tău, ținând pasul cu autobuzul (secunde).
@export var timp_alaturi := 1.2
## Cât de repede te depășește (m/s în plus față de autobuz) și cât de departe de autobuz aleargă.
@export var viteza_creatura := 11.0
@export var distanta_creatura := 3.7

@export_group("Replici")
## Ce zici după ce te așezi, înainte să apară creatura (le-a scris owner-ul).
@export_multiline var replici_inainte: PackedStringArray = ["You: Why is my mom such a bitch..", "You: I should be selling weed instead of this witch bullshit.."]
## Ce zici când o vezi (le-a scris owner-ul).
@export_multiline var replici_creatura: PackedStringArray = ["You: Why is grandma always doing this...", "You: Always forgets her meds and running naked through the forest."]
## La câte secunde după ce creatura apare pe ecran pornesc replicile de mai sus.
@export var intarziere_replici := 2.5

@export_group("Pădurea")
@export var copaci_padure: Array[PackedScene] = []
@export var copaci_camp: Array[PackedScene] = []
@export var stalpisor: PackedScene
@export var stalp_lemn: PackedScene
@export var numar_copaci := 190
@export var numar_copaci_camp := 26

@export_group("Final")
## Scena de după (pădurea). Gol = „To be continued...” și înapoi în meniu.
@export_file("*.tscn") var scena_urmatoare := ""
@export_multiline var titlu_urmator := "Forest Road\n12:00 AM"

@export_group("Sunete")
@export var sunet_vajait: AudioStream
@export var sunet_crengi: AudioStream
@export var sunet_sperietura: AudioStream
@export var sunet_frana: AudioStream
@export var zornaieli: Array[AudioStream] = []

## Cât din drum ține minte în spate și cât desenează în față (metri).
const SPATE := 40.0
const FATA := 130.0
const MATERIAL := preload("res://shaders/material_model.tres")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")

var _v := 0.0
var _timp := 0.0
var _privit := 0.0
var _a_aparut := false
var _momeala_data := false
var _banda: Array[Dictionary] = []  # {nod, pas (m), x_min, x_max}
var _rng := RandomNumberGenerator.new()
var _pana_la_zornait := 3.0
var _lumini: Array[OmniLight3D] = []
var _neon: GeometryInstance3D
var _camera: Camera3D
## Creatura: 0 = ascunsă, 1 = aleargă pe lângă, 2 = cotește în pădure.
var _faza := 0
var _rel := 0.0
var _lateral := 0.0
var _timp_faza := 0.0
## Când a intrat creatura prima dată în cadru (-1 = încă nu).
var _vazuta_la := -1.0


func _ready() -> void:
	_rng.seed = 13
	_v = viteza
	for nume in ["NeonFata", "NeonMijloc"]:
		_lumini.append(autobuz.get_node("Corp/" + nume) as OmniLight3D)
	_neon = autobuz.get_node("Corp/Model").find_child("Lumini") as GeometryInstance3D
	creatura.visible = false
	_camera = calator.get_node("Camera3D")
	_construieste_drumul()
	_scenariu()


# ---------------------------------------------------------------- drumul

func _construieste_drumul() -> void:
	# pădurea, pe stânga (+X): deasă lângă drum, apoi tot mai rară
	for i in numar_copaci:
		var x := 5.2 + pow(_rng.randf(), 1.4) * 30.0
		_adauga(copaci_padure.pick_random(), x, _rng.randf_range(-SPATE, FATA), 0.0, 5.2, 35.2, true)
	# pe dreapta: câmp cu câțiva copaci și linia de stâlpi
	for i in numar_copaci_camp:
		var x := -_rng.randf_range(9.0, 45.0)
		_adauga(copaci_camp.pick_random(), x, _rng.randf_range(-SPATE, FATA), 0.0, -45.0, -9.0, true)
	var lungime := SPATE + FATA
	for z in range(0, int(lungime), 25):
		_adauga(stalpisor, 4.1, z - SPATE, 25.0, 4.1, 4.1, false, PI)
		_adauga(stalpisor, -4.1, z - SPATE + 12.0, 25.0, -4.1, -4.1, false, PI)
	for z in range(0, int(lungime), 42):
		_adauga(stalp_lemn, -5.8, z - SPATE, 42.0, -5.8, -5.8, false)
	# liniile întrerupte din mijlocul drumului (vopsea veche, ștearsă)
	var mat_linie := ShaderMaterial.new()
	mat_linie.shader = MATERIAL.shader
	mat_linie.set_shader_parameter("textura", MATERIAL.get_shader_parameter("textura"))
	mat_linie.set_shader_parameter("culoare", Color("7e8d87"))
	var linie := BoxMesh.new()
	linie.size = Vector3(0.12, 0.01, 3.0)
	linie.material = mat_linie
	for z in range(0, int(lungime), 9):
		var m := MeshInstance3D.new()
		m.mesh = linie
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		m.position = Vector3(0.0, 0.025, z - SPATE)
		_banda.append({"nod": m, "pas": 9.0, "x_min": 0.0, "x_max": 0.0})


## Pune un obiect în bandă. pas = 0 ⇒ la întoarcere primește alt loc la întâmplare.
func _adauga(scena: PackedScene, x: float, z: float, pas: float, x_min: float, x_max: float, aleator: bool,
		unghi := 0.0) -> void:
	if scena == null:
		return
	var nod := scena.instantiate() as Node3D
	if not nod is ModelPS2:
		nod.set_script(SCRIPT_MODEL)
		nod.set("material", MATERIAL)
		if nod.find_child("Reflector"):
			nod.set("stralucitoare", PackedStringArray(["Reflector"]))
			nod.set("stralucire", 0.8)
	add_child(nod)
	nod.position = Vector3(x, 0.0, z)
	nod.rotation.y = _rng.randf_range(0.0, TAU) if aleator else unghi
	if aleator:
		nod.scale = Vector3.ONE * _rng.randf_range(0.8, 1.35)
	_banda.append({"nod": nod, "pas": pas, "x_min": x_min, "x_max": x_max})


func _banda_rulanta() -> void:
	var z_bus := autobuz.global_position.z
	var lungime := SPATE + FATA
	for o in _banda:
		var nod: Node3D = o.nod
		if nod.position.z >= z_bus - SPATE:
			continue
		var pas: float = o.pas
		if pas > 0.0:
			# stâlpii: pasul fix, ca să rămână la distanțe egale
			nod.position.z += ceilf(lungime / pas) * pas
		else:
			nod.position.z += lungime
			nod.position.x = _rng.randf_range(o.x_min, o.x_max) if o.x_min < 0.0 \
				else o.x_min + pow(_rng.randf(), 1.4) * (o.x_max - o.x_min)
			nod.rotation.y = _rng.randf_range(0.0, TAU)


# ---------------------------------------------------------------- în fiecare cadru

func _process(delta: float) -> void:
	_timp += delta
	autobuz.global_position.z += _v * delta
	teren.global_position.z = autobuz.global_position.z
	_banda_rulanta()
	_zornaieli(delta)
	_creatura_pas(delta)
	if not _a_aparut and _timp >= armare and not Dialog.activ:
		if _te_uiti_la_padure():
			_privit += delta
		else:
			_privit = 0.0
		if _privit >= timp_privire:
			_porneste_creatura()


func _te_uiti_la_padure() -> bool:
	return calator.unghi_orizontal > 50.0 and calator.unghi_orizontal < 135.0 and calator.unghi_vertical > -35.0


## Autobuzul vechi zdrăngăne: geamuri, bare, compostoare.
func _zornaieli(delta: float) -> void:
	if zornaieli.is_empty() or _v < 1.0:
		return
	_pana_la_zornait -= delta
	if _pana_la_zornait > 0.0:
		return
	_pana_la_zornait = _rng.randf_range(1.5, 4.5)
	var p := AudioStreamPlayer3D.new()
	p.stream = zornaieli.pick_random()
	p.volume_db = _rng.randf_range(-26.0, -18.0)
	p.pitch_scale = _rng.randf_range(1.5, 2.2)
	p.unit_size = 2.0
	p.bus = &"Efecte"
	p.finished.connect(p.queue_free)
	autobuz.add_child(p)
	p.position = Vector3(_rng.randf_range(-1.1, 1.1), _rng.randf_range(1.0, 2.6), _rng.randf_range(-5.0, 4.0))
	p.play()


# ---------------------------------------------------------------- creatura

func _porneste_creatura() -> void:
	if _a_aparut:
		return
	_a_aparut = true
	_faza = 1
	_rel = -16.0
	_lateral = distanta_creatura
	creatura.visible = true
	creatura.alearga = true
	_creatura_pas(0.0)


func _creatura_pas(delta: float) -> void:
	if _faza == 0:
		return
	_timp_faza += delta
	var z_bus := autobuz.global_position.z
	var directie := Vector3(0, 0, 1)
	match _faza:
		1:  # vine din spate, prinde autobuzul din urmă
			_rel += viteza_creatura * delta
			if _rel >= -0.6:
				_faza = 2
				_timp_faza = 0.0
				_trece_pe_langa()
		2:  # ține pasul cu autobuzul, chiar sub geamul tău, și se uită la tine
			_rel += 0.6 * delta
			directie = Vector3(-0.45, 0, 1)
			if _timp_faza >= timp_alaturi:
				_faza = 3
				_timp_faza = 0.0
		3:  # țâșnește înainte
			_rel += viteza_creatura * 1.4 * delta
			if _rel > 7.0:
				_faza = 4
		4:  # cotește brusc în pădure
			_rel += viteza_creatura * 0.5 * delta
			_lateral += 16.0 * delta
			directie = Vector3(16.0, 0, _v + viteza_creatura * 0.5).normalized()
			if _lateral > 15.0:
				_faza = 0
				creatura.visible = false
				creatura.alearga = false
				Sunet.reda_la(sunet_crengi, creatura.global_position, -2.0, 0.05)
	creatura.global_position = Vector3(_lateral, 0.0, z_bus + _rel)
	if _vazuta_la < 0.0 and _camera.is_position_in_frustum(creatura.global_position + Vector3.UP * 1.4):
		_vazuta_la = _timp
	creatura.rotation.y = lerp_angle(creatura.rotation.y, atan2(directie.x, directie.z), 1.0 - exp(-delta * 12.0))


func _trece_pe_langa() -> void:
	# exact când e în dreptul geamului: vâjâit, lumina clipește, tresari
	var p := AudioStreamPlayer3D.new()
	p.stream = sunet_vajait
	p.volume_db = 2.0
	p.unit_size = 4.0
	p.bus = &"Efecte"
	p.finished.connect(p.queue_free)
	creatura.add_child(p)
	p.play()
	Sunet.reda(sunet_sperietura, -4.0)
	calator.zguduie(1.0)
	_clipeste_lumina()


func _clipeste_lumina() -> void:
	for i in 3:
		_aprinde(false)
		await get_tree().create_timer(randf_range(0.05, 0.12)).timeout
		_aprinde(true)
		await get_tree().create_timer(randf_range(0.06, 0.2)).timeout


func _aprinde(aprins: bool) -> void:
	for l in _lumini:
		l.visible = aprins
	if _neon:
		_neon.set_instance_shader_parameter("stralucire", 1.6 if aprins else 0.0)


# ---------------------------------------------------------------- povestea scenei

func _scenariu() -> void:
	await _asteapta(4.5)
	await _spune(replici_inainte)
	# până apare creatura: momeala, apoi privirea forțată
	var start := _timp
	while not _a_aparut:
		await get_tree().process_frame
		var trecut := _timp - start
		if trecut > momeala and not _momeala_data:
			_momeala_data = true
			Sunet.reda_la(sunet_crengi, autobuz.global_position + Vector3(9.0, 1.0, 14.0), -6.0, 0.05)
			_clipeste_lumina()
		if trecut > fortat and not Dialog.activ:
			await calator.priveste_spre(95.0, -4.0, 1.3)
			_porneste_creatura()
	# replicile pornesc la `intarziere_replici` după ce creatura intră în cadru
	# (dacă n-a apucat să intre deloc, când dispare)
	while _vazuta_la < 0.0 and _faza != 0:
		await get_tree().process_frame
	while _vazuta_la >= 0.0 and _timp < _vazuta_la + intarziere_replici:
		await get_tree().process_frame
	await _spune(replici_creatura)
	while _faza != 0:
		await get_tree().process_frame
	await _asteapta(3.0)
	await _franeaza()
	await _asteapta(0.6)
	await autobuz.deschide_usi()
	await _asteapta(1.5)
	Stare.marcheaza("a_ajuns_la_padure")
	_final()


func _franeaza() -> void:
	if sunet_frana:
		var p := AudioStreamPlayer3D.new()
		p.stream = sunet_frana
		p.unit_size = 5.0
		p.bus = &"Efecte"
		p.finished.connect(p.queue_free)
		autobuz.add_child(p)
		p.position = Vector3(0, 0.5, 2.0)
		p.play()
	while _v > 0.0:
		_v = maxf(_v - decelerare * get_process_delta_time(), 0.0)
		await get_tree().process_frame
	calator.zguduie(0.4)


func _final() -> void:
	if scena_urmatoare != "":
		Tranzitie.mergi_la(scena_urmatoare, titlu_urmator)
		return
	var strat := CanvasLayer.new()
	strat.layer = 19
	add_child(strat)
	var negru := ColorRect.new()
	negru.color = Color.BLACK
	negru.set_anchors_preset(Control.PRESET_FULL_RECT)
	negru.modulate.a = 0.0
	strat.add_child(negru)
	var text := Label.new()
	text.text = "To be continued..."
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 16)
	text.add_theme_color_override("font_color", Color("a18463"))
	text.modulate.a = 0.0
	strat.add_child(text)
	var tween := create_tween()
	tween.tween_property(negru, "modulate:a", 1.0, 2.0)
	tween.parallel().tween_method(func(db: float) -> void: AudioServer.set_bus_volume_db(0, db), 0.0, -40.0, 2.5)
	tween.tween_property(text, "modulate:a", 1.0, 1.2)
	tween.tween_interval(3.0)
	tween.tween_property(text, "modulate:a", 0.0, 1.0)
	await tween.finished
	Tranzitie.mergi_la("res://scenes/meniu_principal.tscn")


func _spune(replici: PackedStringArray) -> void:
	Dialog.spune(replici)
	if Dialog.activ:
		await Dialog.terminat


func _asteapta(secunde: float) -> void:
	await get_tree().create_timer(secunde).timeout
