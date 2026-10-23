extends Interactabil
## Sicriul din spatele casei lui Lexy (owner, 15.10), nodul `Sicriu` din casa_lexy.tscn. „[E] Open the coffin”:
## o scenă scurtă, la persoana întâi, cu benzi negre (Cutscena):
##   1. lumea tace, din sicriu se aude ciocănit de două ori (capacul tresare);
##   2. capacul sare în aer, scheletul se ridică dintr-o smucitură drept în fața ochilor tăi și urlă (jumpscare:
##      `sunet_tipat`, camera se zguduie), apoi te icnești;
##   3. sare din sicriu și o ia la fugă pe după colțul casei (te uiți după el);
##   4. plan larg din stradă (`camera_film`): trece prin curtea laterală, sare gardul curții, traversează strada pe lângă
##      cameră, sare gardul cimitirului și fuge printre morminte, râzând, până dispare (pe pixeli, ca demonul);
##   5. înapoi la tine: `replici_dupa`.
## Pe unde fuge: `drum` (Marker3D-uri în ordine; cele al căror nume începe cu „Salt” sunt sărituri peste un gard).
## La Continue (`marcaj`): sicriul e deschis și gol, capacul pe grămada de pământ, fără E.

@export var marcaj := "scheletul_a_fugit"
## Unde stai când deschizi sicriul (privești spre capac).
@export var loc_jucator: Marker3D
## Drumul scheletului (coordonate în lume).
@export var drum: Node3D
## Planul larg din stradă: de unde filmează (se uită mereu la schelet) și unde ajunge, încet, până la sfârșit.
@export var camera_film: Marker3D
@export var camera_film_final: Marker3D
## Câți metri pe secundă aleargă (mai repede decât tine: 4,5 la sprint).
@export var viteza := 7.5
## Cât de sus sare peste garduri (bazinul, peste înălțimea lui de om în picioare).
@export var inaltime_salt := 1.35
## La ce punct din `drum` (numărând de la 0) se taie spre planul larg: când a ajuns la el (colțul casei).
@export var punct_taietura := 2
## Spre ce punct fugind începe să râdă (după gardul cimitirului).
@export var punct_ras := 8
## Spre ce punct fugind se topește (ultimul bucățică de drum).
@export var punct_disparitie := 9
## Ce zici după (Claude, owner le poate schimba).
@export_multiline var replici_dupa: PackedStringArray = ["You: Nope.", "You: I didn't see shit."]

@export_group("Sunete")
@export var sunet_bataie: AudioStream = preload("res://sunete/sicriu_bataie.ogg")
@export var sunet_capac: AudioStream = preload("res://sunete/sicriu_capac.ogg")
@export var sunet_tipat: AudioStream = preload("res://sunete/schelet_tipat.ogg")
@export var sunet_oase: AudioStream = preload("res://sunete/schelet_oase.ogg")
@export var sunet_ras: AudioStream = preload("res://sunete/schelet_ras.ogg")
@export var sunet_icnet: AudioStream = preload("res://sunete/jucator_icnet.ogg")
@export var sunet_gard: AudioStream = preload("res://sunete/gard_zanganit.ogg")
@export var sunet_capac_jos: AudioStream = preload("res://sunete/corp_cazut.ogg")
@export var pasi: Array[AudioStream] = [preload("res://sunete/schelet_pas_1.ogg"), preload("res://sunete/schelet_pas_2.ogg"),
	preload("res://sunete/schelet_pas_3.ogg")]

## Bazinul scheletului deasupra tălpilor (originea nodului `Schelet` e în bazin).
const BAZIN := 0.98
## Unde e craniul față de bazin (cât stă drept).
const CRANIU := Vector3(0.0, 0.74, 0.0)
## Cât coboară lumea (canalele Ambianta și Muzica) cât ține scena (dB), ca la păpușa din pădure.
const LINISTE := -24.0
## Capacul căzut pe grămada de pământ (față de sicriu): poziția și rotația.
const CAPAC_JOS := Vector3(0.15, 0.36, -0.95)
const CAPAC_JOS_ROT := Vector3(-0.32, 0.35, 0.1)

@onready var _schelet: Node3D = $Schelet
@onready var _model_schelet: Node3D = $Schelet/Model
@onready var _capac: Node3D = $Model.find_child("Capac") as Node3D

var _corp: Node3D
var _cap: Node3D
var _falca: Node3D
var _brate: Array[Node3D] = []
var _picioare: Array[Node3D] = []
var _in_curs := false
## Ce face scheletul în fiecare cadru: aleargă (brațe, picioare, saltă), clănțăne din fălci, își strânge picioarele (salt).
var _alearga := false
var _clantane := false
var _strans := false
var _faza := 0.0
var _ultimul_pas := 0
var _duck: Array = []
## Cine se uită după el: jucătorul (persoana întâi) sau camera de film.
var _jucator: CharacterBody3D
var _privire_jucator := false
var _film: Camera3D


func _ready() -> void:
	indiciu = "[E] Open the coffin"
	_corp = _model_schelet.find_child("Corp") as Node3D
	_cap = _model_schelet.find_child("Cap") as Node3D
	_falca = _model_schelet.find_child("Falca") as Node3D
	for nume in ["BratS", "BratD"]:
		_brate.append(_model_schelet.find_child(nume) as Node3D)
	for nume in ["PiciorS", "PiciorD"]:
		_picioare.append(_model_schelet.find_child(nume) as Node3D)
	_culcat()
	if Stare.e_marcat(marcaj):
		_schelet.queue_free()
		_capac.position = CAPAC_JOS
		_capac.rotation = CAPAC_JOS_ROT
		activ = false


func poate_fi_folosit() -> bool:
	return super() and not _in_curs and not Stare.e_marcat(marcaj)


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	_jucator = get_tree().get_first_node_in_group("jucator") as CharacterBody3D
	var camera: Camera3D = _jucator.get_node("Cap/Camera3D")
	var c := Cutscena.porneste(self)
	_jucator.seteaza_purtat(true)
	_coboara_lumea(true, 0.6)

	# 1. te așezi lângă sicriu și te uiți la capac
	var loc := loc_jucator.global_position
	loc.y = _jucator.global_position.y
	var pas := create_tween().set_trans(Tween.TRANS_SINE)
	pas.tween_property(_jucator, "global_position", loc, 0.6)
	await c.priveste(to_global(Vector3(-0.1, 0.45, 0.0)), 0.6)
	if pas.is_running():
		await pas.finished
	await get_tree().create_timer(0.35).timeout
	# ciocănește de două ori dinăuntru (bătăile din sicriu_bataie.ogg: la 0 și la ~0,38 s), capacul tresare
	Sunet.reda_la(sunet_bataie, to_global(Vector3(-0.3, 0.4, 0.0)))
	_tresare_capac()
	await get_tree().create_timer(0.38).timeout
	_tresare_capac()
	await get_tree().create_timer(0.7).timeout

	# 2. capacul sare, scheletul îți sare în față și urlă
	Stare.marcheaza(marcaj)
	Sunet.reda_la(sunet_capac, to_global(Vector3(0.0, 0.5, 0.0)))
	Sunet.reda(sunet_tipat)
	_zboara_capacul()
	Zguduire.porneste(camera, 0.045, 0.9)
	_clantane = true
	await _in_fata(camera, 0.14)
	# tresari: capul ți se dă puțin pe spate
	var tresarire := create_tween().set_trans(Tween.TRANS_SINE)
	var cap_jucator: Node3D = _jucator.get_node("Cap")
	tresarire.tween_property(cap_jucator, "rotation:x", cap_jucator.rotation.x + 0.12, 0.08)
	await get_tree().create_timer(0.75).timeout
	Sunet.reda(sunet_icnet, Sunet.VOLUM_EFECTE - 2.0)

	# 3. se trage înapoi, se ridică în picioare în sicriu și sare afară, spre capătul cu picioarele
	_clantane = false
	var puncte := _puncte_drum()
	await _inapoi_in_sicriu(0.3)
	Sunet.reda_la(sunet_oase, _schelet.global_position)
	_alearga = true
	_privire_jucator = true
	await _sari(puncte[0], 0.6, 0.45)
	for i in range(1, puncte.size()):
		if i == punct_taietura + 1:
			_porneste_filmul()
		if i == punct_ras:
			_rade()
		if String(drum.get_child(i).name).begins_with("Salt"):
			Sunet.reda_la(sunet_oase, _schelet.global_position)
			await _sari(puncte[i], inaltime_salt, puncte[i - 1].distance_to(puncte[i]) / viteza * 1.25)
			Sunet.reda_la(sunet_gard, (puncte[i - 1] + puncte[i]) * 0.5 + Vector3.UP * 1.4, Sunet.VOLUM_EFECTE - 3.0, 0.05)
		else:
			await _fugi(puncte[i - 1], puncte[i], i >= punct_disparitie)
	_alearga = false
	_schelet.visible = false

	# 4. înapoi la tine
	await get_tree().create_timer(0.6).timeout
	if _film:
		_film.queue_free()
		_film = null
	camera.make_current()
	_hud(true)
	_privire_jucator = false
	await c.priveste(to_global(Vector3(-0.1, 0.3, 0.0)), 0.01)
	_coboara_lumea(false, 3.0)
	if not replici_dupa.is_empty():
		Dialog.spune(replici_dupa)
		if Dialog.activ:
			await Dialog.terminat
	_schelet.queue_free()
	_jucator.seteaza_purtat(false)
	activ = false
	_in_curs = false
	await c.opreste()


func _process(delta: float) -> void:
	if not is_instance_valid(_schelet) or not _schelet.visible:
		return
	_anima(delta)
	var tinta := _schelet.global_position + Vector3.UP * 0.3
	if _film:
		# camera de film se uită după el, cu o mică întârziere (ca un operator)
		var dorit := _film.global_transform.looking_at(tinta, Vector3.UP).basis.get_rotation_quaternion()
		_film.quaternion = _film.quaternion.slerp(dorit, 1.0 - exp(-delta * 10.0))
	elif _privire_jucator and _jucator:
		var cap: Node3D = _jucator.get_node("Cap")
		var d := tinta - cap.global_position
		var unghi := atan2(-d.x, -d.z)
		var sus := atan2(d.y, Vector2(d.x, d.z).length())
		var k := 1.0 - exp(-delta * 9.0)
		_jucator.rotation.y = lerp_angle(_jucator.rotation.y, unghi, k)
		cap.rotation.x = lerpf(cap.rotation.x, clampf(sus, -1.2, 1.2), k)


# ---------------------------------------------------------------- scheletul

## Culcat pe spate în sicriu: capul spre -X (pe pernă), picioarele spre +X, fața în sus.
func _culcat() -> void:
	_schelet.transform = Transform3D(_baza_culcat(), Vector3(-0.08, 0.2, 0.0))
	for p in _picioare:
		p.rotation = Vector3.ZERO


## Axele modelului culcat: Y (capul) spre -X, Z (fața) în sus, X = Y × Z.
func _baza_culcat() -> Basis:
	return Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0))


## Se ridică dintr-o smucitură și vine cu craniul la o palmă de ochii tăi, la înălțimea lor, cu fața spre tine;
## privirea ta (care era în jos, pe capac) se smucește în sus după el.
func _in_fata(camera: Camera3D, durata: float) -> void:
	var ochi := camera.global_position
	var inainte := -camera.global_basis.z
	inainte.y = 0.0
	inainte = inainte.normalized()
	var craniu := ochi + inainte * 0.45 + Vector3.DOWN * 0.05
	var b1 := Basis.looking_at(inainte, Vector3.UP)  # looking_at: -Z spre direcție, deci fața (+Z) spre tine
	var bazin := craniu - b1 * CRANIU
	var cap_jucator: Node3D = _jucator.get_node("Cap")
	var privire := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	privire.tween_property(cap_jucator, "rotation:x", atan2(-0.05, 0.45), durata * 1.2)
	var q0 := _schelet.basis.get_rotation_quaternion()
	var q1 := b1.get_rotation_quaternion()
	var p0 := _schelet.global_position
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v: float) -> void:
		_schelet.global_position = p0.lerp(bazin, v)
		_schelet.basis = Basis(q0.slerp(q1, clampf(v, 0.0, 1.0)))
		# în genunchi în sicriu (picioarele în jos, nu se văd), brațele vin spre tine, cu ghearele
		for i in 2:
			_brate[i].rotation = Vector3(-1.25 * v, 0.0, (0.35 if i == 0 else -0.35) * v)
		_cap.rotation.x = -0.1 * v, 0.0, 1.0, durata)
	await t.finished


## Se trage înapoi în sicriu și se ridică în picioare, cu fața spre capătul cu picioarele (+X).
func _inapoi_in_sicriu(durata: float) -> void:
	var p0 := _schelet.global_position
	var p1 := to_global(Vector3(0.35, BAZIN + 0.08, 0.0))
	var q0 := _schelet.global_basis.get_rotation_quaternion()
	var q1 := Basis(Vector3.UP, PI / 2.0).get_rotation_quaternion()  # fața (+Z) spre +X
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_method(func(v: float) -> void:
		_schelet.global_position = p0.lerp(p1, v)
		_schelet.global_basis = Basis(q0.slerp(q1, v))
		for i in 2:
			_brate[i].rotation = _brate[i].rotation.lerp(Vector3.ZERO, v)
		_cap.rotation = Vector3(-0.1 * (1.0 - v), 0.0, 0.0), 0.0, 1.0, durata)
	await t.finished


## Săritura de unde e acum până la `b` (tălpile), cu bazinul la `inaltime` peste mers, în `durata` secunde;
## picioarele strânse.
func _sari(b: Vector3, inaltime: float, durata: float) -> void:
	var start := _schelet.global_position
	var sfarsit := b + Vector3.UP * BAZIN
	_intoarce_spre(sfarsit - start, 1.0)
	_strans = true
	var t := 0.0
	while t < durata:
		await get_tree().process_frame
		t += get_process_delta_time()
		var v := minf(t / durata, 1.0)
		_schelet.global_position = start.lerp(sfarsit, v) + Vector3.UP * sin(v * PI) * inaltime
	_strans = false
	_pas()


## Fuga pe jos de la `a` la `b`; `dispare` = se topește pe pixeli pe drum.
func _fugi(a: Vector3, b: Vector3, dispare: bool) -> void:
	var lung := a.distance_to(b)
	var parcurs := 0.0
	while parcurs < lung:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		parcurs = minf(parcurs + viteza * dt, lung)
		var p := a.lerp(b, parcurs / lung)
		p.y = _sol(p) + BAZIN
		_schelet.global_position = p
		_intoarce_spre(b - a, 1.0 - exp(-dt * 14.0))
		if dispare:
			ModelPS2.disparitie(_model_schelet, parcurs / lung)


func _intoarce_spre(directie: Vector3, k: float) -> void:
	if Vector2(directie.x, directie.z).length() < 0.01:
		return
	var unghi := atan2(directie.x, directie.z)  # modelul privește spre +Z
	var b := _schelet.global_basis.get_rotation_quaternion()
	_schelet.global_basis = Basis(b.slerp(Basis(Vector3.UP, unghi).get_rotation_quaternion(), k))


## Mișcarea oaselor în fiecare cadru: alergatul (picioarele și brațele, aplecat, saltă, capul smucit), fălcile care
## clănțăne, picioarele strânse în salt.
func _anima(delta: float) -> void:
	if _clantane:
		_falca.rotation.x = 0.5 + 0.15 * sin(Time.get_ticks_msec() * 0.06)
		_cap.rotation.z = 0.12 * sin(Time.get_ticks_msec() * 0.045)
	if not _alearga:
		return
	_faza += delta * viteza * 1.25
	var u := sin(_faza)
	for i in 2:
		var semn := 1.0 if i == 0 else -1.0
		if _strans:
			_picioare[i].rotation.x = lerpf(_picioare[i].rotation.x, -1.3, 1.0 - exp(-delta * 20.0))
			_brate[i].rotation = _brate[i].rotation.lerp(Vector3(-2.4, 0.0, semn * 0.5), 1.0 - exp(-delta * 15.0))
		else:
			_picioare[i].rotation = Vector3(0.75 * u * semn, 0.0, 0.0)
			_brate[i].rotation = Vector3(-0.9 * u * semn - 0.3, 0.0, semn * 0.2)
	_corp.rotation.x = 0.22
	_model_schelet.position.y = -BAZIN + absf(cos(_faza)) * 0.08
	_cap.rotation = Vector3(-0.15 + 0.1 * sin(_faza * 2.0), 0.0, 0.15 * sin(_faza * 0.5))
	# fălcile se bălăngăne (râde de tine)
	_falca.rotation.x = 0.25 + 0.2 * sin(_faza * 3.0)
	# un pas la fiecare jumătate de ciclu
	var pas := int(floor(_faza / PI))
	if pas != _ultimul_pas and not _strans:
		_ultimul_pas = pas
		_pas()


func _pas() -> void:
	if pasi.is_empty() or not is_instance_valid(_schelet):
		return
	Sunet.reda_la(pasi.pick_random(), _schelet.global_position - Vector3.UP * BAZIN, Sunet.VOLUM_EFECTE - 2.0, 0.1)


## Râsul de pe el (3D, se mișcă odată cu el).
func _rade() -> void:
	var r := AudioStreamPlayer3D.new()
	r.stream = sunet_ras
	r.unit_size = 10.0
	r.max_distance = 70.0
	r.bus = &"Efecte"
	_schelet.add_child(r)
	r.play()


## Drumul, cu tălpile pe sol (y-ul îl ia de la coliziunea de dedesubt: bordurile, trotuarele).
func _puncte_drum() -> Array[Vector3]:
	var puncte: Array[Vector3] = []
	for m in drum.get_children():
		var p := (m as Node3D).global_position
		p.y = _sol(p)
		puncte.append(p)
	return puncte


func _sol(p: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 2.0, p.z), Vector3(p.x, -1.0, p.z))
	q.exclude = [get_rid()]
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty() or (r.position as Vector3).y > 0.4:
		return 0.0
	return (r.position as Vector3).y


# ---------------------------------------------------------------- capacul

func _tresare_capac() -> void:
	var t := create_tween()
	t.tween_property(_capac, "position:y", _capac.position.y + 0.03, 0.05)
	t.parallel().tween_property(_capac, "rotation:z", randf_range(-0.03, 0.03), 0.05)
	t.tween_property(_capac, "position:y", _capac.position.y, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_capac, "rotation:z", 0.0, 0.12)


## Capacul sare în sus, se dă peste cap și cade pe grămada de pământ din spatele sicriului.
func _zboara_capacul() -> void:
	var p0 := _capac.position
	var q0 := _capac.quaternion
	var q1 := Quaternion.from_euler(CAPAC_JOS_ROT)
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		_capac.position = p0.lerp(CAPAC_JOS, v) + Vector3.UP * sin(v * PI) * 1.1
		# o tură întreagă pe lungime în aer, apoi se așază
		_capac.quaternion = q0.slerp(q1, v) * Quaternion(Vector3.RIGHT, TAU * v), 0.0, 1.0, 0.7)
	t.tween_callback(func() -> void:
		_capac.position = CAPAC_JOS
		_capac.rotation = CAPAC_JOS_ROT
		Sunet.reda_la(sunet_capac_jos, to_global(CAPAC_JOS), Sunet.VOLUM_EFECTE - 4.0, 0.1))


# ---------------------------------------------------------------- planul larg

func _porneste_filmul() -> void:
	_film = Camera3D.new()
	_film.fov = 55.0
	_film.near = 0.05
	_film.far = 400.0
	get_tree().current_scene.add_child(_film)
	_film.global_position = camera_film.global_position
	_film.look_at(_schelet.global_position, Vector3.UP)
	_film.make_current()
	_hud(false)
	if camera_film_final:
		var t := create_tween().set_trans(Tween.TRANS_SINE)
		t.tween_property(_film, "global_position", camera_film_final.global_position, 5.0)


func _hud(vizibil: bool) -> void:
	var hud := _jucator.get_node_or_null("HUD") as CanvasLayer if _jucator else null
	if hud:
		hud.visible = vizibil


# ---------------------------------------------------------------- liniștea

## Coboară (sau ridică la loc) canalele Ambianta și Muzica (ca în sperietura_papusa.gd).
func _coboara_lumea(jos: bool, durata: float) -> void:
	if jos and _duck.is_empty():
		for nume: StringName in [&"Ambianta", &"Muzica"]:
			var i := AudioServer.get_bus_index(nume)
			if i >= 0:
				var a := AudioEffectAmplify.new()
				AudioServer.add_bus_effect(i, a)
				_duck.append([i, a])
	var t := create_tween()
	t.tween_method(func(db: float) -> void:
		for x in _duck:
			(x[1] as AudioEffectAmplify).volume_db = db, 0.0 if jos else LINISTE, LINISTE if jos else 0.0, durata)
	await t.finished
	if not jos:
		_scoate_duck()


func _scoate_duck() -> void:
	for x in _duck:
		var i: int = x[0]
		for k in range(AudioServer.get_bus_effect_count(i) - 1, -1, -1):
			if AudioServer.get_bus_effect(i, k) == x[1]:
				AudioServer.remove_bus_effect(i, k)
	_duck.clear()


func _exit_tree() -> void:
	_scoate_duck()
