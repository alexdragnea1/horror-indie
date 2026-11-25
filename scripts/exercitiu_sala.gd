class_name ExercitiuSala
extends Interactabil
## Un aparat din sala „Iron Pump” (sala.tscn, owner 25.11) pe care faci un set, la persoana întâi, ca o mică cutscenă
## (Cutscena: benzi negre, nu te miști): îți vezi pumnii (pumn_sala.glb) pe bară / pe gantere.
##  - `bench`: te culci pe bancă (capul spre suporturi), scoți bara de pe suporturi, `repetari` împinse, o pui la loc.
##  - `squat`: intri sub bara din cușcă, o iei pe spate (nu o vezi), un pas în față, `repetari` genuflexiuni, o pui la loc.
##  - `biceps`: iei perechea de gantere de pe rastel (`gantere`), ridici pe rând cu fiecare mână, le pui la loc.
## Coordonatele sunt ale nodului: originea la podea; la bancă în capul ei (perna merge spre +Z, spre tălpi), la cușcă
## între montanții din față (te uiți spre +Z, spre hol), la rastel în dreptul perechii (stai la +Z, te uiți spre -Z).
## După primul set gata dispare sarcina „Work out.” (`sarcina`) și se pune `marcaj_antrenat`.

@export_enum("bench", "squat", "biceps") var fel := "bench"
## Bara (bench, squat): stă pe suporturi la `loc_bara` (coordonatele nodului).
@export var bara: Node3D
## Biceps: cele două gantere de pe rastel (stânga, dreapta).
@export var gantere: Array[Node3D] = []
@export var repetari := 5
@export var indiciu_aparat := "[E] Bench press"
## Ce spui după set (scrise de Claude; owner-ul le poate schimba).
@export_multiline var replici_gata: PackedStringArray = []
@export var marcaj_antrenat := "s_a_antrenat"
@export var sarcina := "Work out."
## Fără day pass (`Sala.are_pass()` fals) aparatul nu merge (n-ai cum ajunge la el oricum; e doar o plasă de siguranță).
@export var cere_pass := true

const PUMN := preload("res://models/pumn_sala.glb")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")
const SUNET_ICNET := preload("res://sunete/jucator_icnet.ogg")
const SUNET_BARA := preload("res://sunete/bara_pusa.ogg")
const SUNET_GANTERA := preload("res://sunete/gantera_pusa.ogg")
## Bench: unde stă bara pe suporturi, sus deasupra pieptului (brațele întinse) și jos, aproape de piept.
const BENCH_SUPORT := Vector3(0.0, 1.04, -0.09)
const BENCH_SUS := Vector3(0.0, 1.12, 0.3)
const BENCH_JOS := Vector3(0.0, 0.78, 0.34)
## Bench: ochii tăi culcat, cât te uiți în sus (radiani) și umerii (spre ei merg antebrațele).
const BENCH_OCHI := Vector3(0.0, 0.58, 0.12)
const BENCH_PRIVIRE := 1.13
const BENCH_UMAR := Vector3(0.2, 0.51, 0.32)
## Squat: bara pe cârlige, unde stă pe spatele tău (față de ochi: puțin mai jos, în spate) și cât de jos cobori.
const SQUAT_SUPORT := Vector3(0.0, 1.42, 0.36)
const SQUAT_PE_SPATE := Vector3(0.0, -0.14, 0.12)
const SQUAT_ADANC := 0.6
## Lățimea prizei (de la mijlocul barei).
const PRIZA := 0.42
## Biceps: unde stai, cotul (față de cameră) și lungimea antebrațului.
const BICEPS_LOC := Vector3(0.0, 0.0, 1.15)
const BICEPS_COT := Vector3(0.2, -0.5, -0.04)
const ANTEBRAT := 0.3

var _in_curs := false
var _jucator: CharacterBody3D
var _cap: Node3D
var _camera: Camera3D
var _pumni: Array[Node3D] = []
## Unde „pleacă” antebrațele fiecărui pumn (global; actualizat în _process).
var _umeri: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]


func _ready() -> void:
	indiciu = indiciu_aparat
	set_process(false)
	await get_tree().process_frame
	_jucator = get_tree().get_first_node_in_group("jucator") as CharacterBody3D
	if _jucator:
		_cap = _jucator.get_node("Cap")
		_camera = _cap.get_node("Camera3D")
	for g in gantere:
		g.set_meta("loc", g.global_position)
		g.set_meta("rot", g.global_rotation)


func poate_fi_folosit() -> bool:
	return activ and not _in_curs and _jucator != null and (not cere_pass or Sala.are_pass())


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	var c := Cutscena.porneste(self)
	_jucator.velocity = Vector3.ZERO
	var poz := _jucator.global_position
	var rot := _jucator.rotation.y
	var cap_y := _cap.position.y
	var cap_x := _cap.rotation.x
	# întâi te întorci spre aparat, apoi te „pune” acolo (fără fizică)
	# ce ții în mână (arma, mătura) îl lași deoparte cât faci setul: ai nevoie de ambele mâini
	var in_mana := Stare.in_mana
	Stare.tine_in_mana("")
	await c.priveste(global_position + Vector3.UP * 0.9, 0.4)
	_jucator.seteaza_purtat(true)
	match fel:
		"bench":
			await _bench()
		"squat":
			await _squat()
		_:
			await _biceps()
	# te ridici înapoi unde erai
	var t := _tween()
	t.tween_property(_jucator, "global_position", poz, 0.6)
	t.tween_property(_cap, "position:y", cap_y, 0.6)
	t.tween_property(_cap, "rotation:x", clampf(cap_x, -0.3, 0.3), 0.6)
	t.tween_method(func(v: float) -> void: _jucator.rotation.y = v, _jucator.rotation.y,
		_jucator.rotation.y + angle_difference(_jucator.rotation.y, rot), 0.6)
	await t.finished
	_jucator.seteaza_purtat(false)
	Stare.tine_in_mana(in_mana)
	if not replici_gata.is_empty():
		Dialog.spune(replici_gata)
		if Dialog.activ:
			await Dialog.terminat
	await c.opreste()
	if not Stare.e_marcat(marcaj_antrenat):
		Stare.marcheaza(marcaj_antrenat)
		if Stare.sarcina == sarcina:
			Stare.seteaza_sarcina("")
	_in_curs = false


func _tween() -> Tween:
	return create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Duce camera (ochii) în punctul global `ochi`, cu privirea spre unghiul `unghi` (în jurul lui Y; 0 = spre -Z) și
## `sus` (radiani), în `durata` secunde.
func _du_camera(ochi: Vector3, unghi: float, sus: float, durata: float) -> void:
	var t := _tween()
	t.tween_property(_jucator, "global_position", Vector3(ochi.x, global_position.y, ochi.z), durata)
	t.tween_property(_cap, "position:y", ochi.y - global_position.y, durata)
	t.tween_property(_cap, "rotation:x", sus, durata)
	t.tween_method(func(v: float) -> void: _jucator.rotation.y = v, _jucator.rotation.y,
		_jucator.rotation.y + angle_difference(_jucator.rotation.y, unghi), durata)
	await t.finished


## Unghiul (în jurul lui Y) cu care te uiți spre direcția locală `d` a nodului.
func _unghi_spre(d: Vector3) -> float:
	var g := global_basis * d
	return atan2(-g.x, -g.z)


# ---------------------------------------------------------------- pumnii

func _pumn() -> Node3D:
	var p := PUMN.instantiate() as Node3D
	p.set_script(SCRIPT_MODEL)
	p.set("material", MATERIAL)
	p.set("umbre", false)
	return p


func _pune_pumni(pe: Node3D, priza: float) -> void:
	for s in [-1.0, 1.0]:
		var p := _pumn()
		pe.add_child(p)
		p.position = Vector3(s * priza, 0.0, 0.0)
		_pumni.append(p)
	set_process(true)


func _scoate_pumni() -> void:
	set_process(false)
	for p in _pumni:
		if is_instance_valid(p):
			p.queue_free()
	_pumni.clear()


func _process(_delta: float) -> void:
	# fiecare pumn: antebrațul (+Y al modelului) spre umărul lui, dosul palmei (+Z) spre cameră (bench, squat) sau
	# dinspre ea (biceps: palma spre tine); axa barei (X) rămâne a barei / a ganterei
	var ochi := _camera.global_position
	for i in _pumni.size():
		var p := _pumni[i]
		if not is_instance_valid(p):
			continue
		var y := (_umeri[i] - p.global_position).normalized()
		var spre := (ochi - p.global_position).normalized() * (-1.0 if fel == "biceps" else 1.0)
		var z := (spre - y * y.dot(spre)).normalized()
		var x := y.cross(z)
		p.global_basis = Basis(x, y, z)


func _actualizeaza_umeri_bench() -> void:
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		_umeri[i] = to_global(Vector3(BENCH_UMAR.x * s, BENCH_UMAR.y, BENCH_UMAR.z))


func _umeri_camera(cot: Vector3) -> void:
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		_umeri[i] = _camera.global_transform * Vector3(cot.x * s, cot.y, cot.z)


# ---------------------------------------------------------------- bench

func _bench() -> void:
	# te așezi pe capătul băncii, apoi te culci (capul sub bară, tălpile spre +Z)
	var spre_talpi := _unghi_spre(Vector3.BACK)
	await _du_camera(to_global(Vector3(0.0, 1.2, 0.7)), spre_talpi, -0.3, 0.6)
	Sunet.reda_la(preload("res://sunete/canapea_asezat.ogg"), to_global(Vector3(0, 0.5, 0.6)), Sunet.VOLUM_EFECTE - 4.0, 0.1)
	await _du_camera(to_global(BENCH_OCHI), spre_talpi, BENCH_PRIVIRE, 0.9)
	_actualizeaza_umeri_bench()
	_pune_pumni(bara, PRIZA)
	await get_tree().create_timer(0.4).timeout
	# scoți bara de pe suporturi
	Sunet.reda_la(SUNET_BARA, bara.global_position, Sunet.VOLUM_EFECTE - 4.0, 0.1, 1.15)
	await _misca_bara(to_global(BENCH_SUS), 0.8)
	for i in repetari:
		var greu := float(i) / maxf(repetari - 1, 1)
		await _misca_bara(to_global(BENCH_JOS), 1.1 + greu * 0.3)
		Sunet.reda(SUNET_ICNET, Sunet.VOLUM_EFECTE - 8.0 + greu * 4.0, 0.1)
		_tremura(0.6 + greu * 0.7, 0.004 + greu * 0.006)
		await _misca_bara(to_global(BENCH_SUS), 0.75 + greu * 0.8)
	# înapoi pe suporturi, cu zăngănit
	await _misca_bara(to_global(BENCH_SUPORT), 0.8)
	Sunet.reda_la(SUNET_BARA, bara.global_position, Sunet.VOLUM_EFECTE - 2.0, 0.1)
	_zguduie(0.25)
	_scoate_pumni()
	await get_tree().create_timer(0.5).timeout
	await _du_camera(to_global(Vector3(0.0, 1.2, 0.7)), spre_talpi, -0.2, 0.9)


func _misca_bara(unde: Vector3, durata: float) -> void:
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(bara, "global_position", unde, durata)
	await t.finished


## Bara (și pumnii) tremură puțin cât împingi (`cat` = cât de tare, în metri).
func _tremura(durata: float, cat: float) -> void:
	var baza := bara.position
	var t := create_tween()
	var n := int(durata / 0.05)
	for k in n:
		t.tween_property(bara, "position", baza + Vector3(randf_range(-1, 1) * cat * 0.4, randf_range(-1, 1) * cat * 0.3, randf_range(-1, 1) * cat), 0.05)
	t.tween_property(bara, "position", baza, 0.05)


func _zguduie(cat: float) -> void:
	var t := create_tween()
	t.tween_property(_camera, "rotation:z", 0.02 * cat * 4.0, 0.05)
	t.tween_property(_camera, "rotation:z", -0.015 * cat * 4.0, 0.06)
	t.tween_property(_camera, "rotation:z", 0.0, 0.08)


# ---------------------------------------------------------------- squat

func _squat() -> void:
	# genuflexiuni cu bara pe spate (owner 25.11: „normal stă pe spate”): nu vezi nici bara, nici mâinile, doar
	# camera coboară și urcă; bara (în spatele capului) merge după tine
	var spre_hol := _unghi_spre(Vector3.BACK)
	var bara_sus := to_global(SQUAT_SUPORT)
	# te lași puțin sub bară, cu spatele la ea, și te ridici cu ea pe umeri
	var ochi_sub := to_global(Vector3(0.0, 1.55, SQUAT_SUPORT.z + 0.12))
	await _du_camera(ochi_sub - Vector3.UP * 0.12, spre_hol, -0.05, 0.8)
	await get_tree().create_timer(0.3).timeout
	Sunet.reda_la(SUNET_BARA, bara.global_position, Sunet.VOLUM_EFECTE - 4.0, 0.1, 1.15)
	var urmareste := func(_v: float) -> void:
		bara.global_position = _corp() * SQUAT_PE_SPATE
	var t := _tween()
	t.tween_property(_cap, "position:y", ochi_sub.y - global_position.y, 0.5)
	t.tween_method(urmareste, 0.0, 1.0, 0.5)
	await t.finished
	# un pas în față, afară din cușcă
	var ochi_afara := to_global(Vector3(0.0, 1.55, SQUAT_SUPORT.z + 0.55))
	t = _tween()
	t.tween_property(_jucator, "global_position", Vector3(ochi_afara.x, global_position.y, ochi_afara.z), 0.7)
	t.tween_method(urmareste, 0.0, 1.0, 0.7)
	await t.finished
	var sus := _cap.position.y
	for i in repetari:
		var greu := float(i) / maxf(repetari - 1, 1)
		t = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(_cap, "position:y", sus - SQUAT_ADANC, 1.1 + greu * 0.2)
		t.tween_property(_cap, "rotation:x", -0.2, 1.1 + greu * 0.2)
		t.tween_method(urmareste, 0.0, 1.0, 1.1 + greu * 0.2)
		await t.finished
		Sunet.reda(SUNET_ICNET, Sunet.VOLUM_EFECTE - 8.0 + greu * 4.0, 0.1, &"Efecte", 0.9)
		t = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(_cap, "position:y", sus, 0.8 + greu * 0.7)
		t.tween_property(_cap, "rotation:x", -0.05, 0.8 + greu * 0.7)
		t.tween_method(urmareste, 0.0, 1.0, 0.8 + greu * 0.7)
		await t.finished
	# pasul înapoi și bara înapoi pe cârlige
	t = _tween()
	t.tween_property(_jucator, "global_position", Vector3(ochi_sub.x, global_position.y, ochi_sub.z), 0.7)
	t.tween_method(urmareste, 0.0, 1.0, 0.7)
	await t.finished
	t = _tween()
	t.tween_property(_cap, "position:y", ochi_sub.y - 0.12 - global_position.y, 0.5)
	t.tween_property(bara, "global_position", bara_sus, 0.5)
	await t.finished
	Sunet.reda_la(SUNET_BARA, bara.global_position, Sunet.VOLUM_EFECTE - 2.0, 0.1)
	_zguduie(0.25)
	await get_tree().create_timer(0.4).timeout


# ---------------------------------------------------------------- biceps

func _biceps() -> void:
	var spre_rastel := _unghi_spre(Vector3.FORWARD)
	await _du_camera(to_global(BICEPS_LOC + Vector3.UP * 1.55), spre_rastel, -0.6, 0.6)
	# te apleci și iei ganterele: zboară din rastel în pumni
	var pumni: Array[Node3D] = []
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		var p := _pumn()
		add_child(p)
		p.global_position = _mana_biceps(s, 0.0)
		pumni.append(p)
		_pumni.append(p)
	for i in 2:
		_umeri[i] = _corp() * Vector3(BICEPS_COT.x * (-1.0 if i == 0 else 1.0), BICEPS_COT.y, BICEPS_COT.z)
	set_process(true)
	for i in 2:
		var g := gantere[i] if i < gantere.size() else null
		if g:
			g.reparent(pumni[i], true)
			var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t.tween_property(g, "position", Vector3.ZERO, 0.35)
			t.parallel().tween_property(g, "rotation", Vector3.ZERO, 0.35)
	Sunet.reda_la(SUNET_GANTERA, global_position + Vector3.UP * 0.6, Sunet.VOLUM_EFECTE - 6.0, 0.1)
	await get_tree().create_timer(0.45).timeout
	for i in repetari * 2:
		var s := -1.0 if i % 2 == 0 else 1.0
		var p := pumni[0 if s < 0 else 1]
		var greu := float(i) / maxf(repetari * 2 - 1, 1)
		var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_method(func(a: float) -> void: p.global_position = _mana_biceps(s, a), 0.0, 1.0, 0.75 + greu * 0.35)
		await t.finished
		if i >= repetari * 2 - 3:
			Sunet.reda(SUNET_ICNET, Sunet.VOLUM_EFECTE - 10.0 + greu * 3.0, 0.1, &"Efecte", 1.05)
		t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_method(func(a: float) -> void: p.global_position = _mana_biceps(s, a), 1.0, 0.0, 0.65)
		await t.finished
	# le pui la loc pe rastel
	for i in 2:
		var g := gantere[i] if i < gantere.size() else null
		if g:
			var loc: Vector3 = g.get_meta("loc", g.global_position)
			g.reparent(get_parent(), true)
			var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t.tween_property(g, "global_position", loc, 0.4)
			t.parallel().tween_property(g, "global_rotation", g.get_meta("rot", Vector3.ZERO), 0.4)
	await get_tree().create_timer(0.42).timeout
	Sunet.reda_la(SUNET_GANTERA, global_position + Vector3.UP * 0.6, Sunet.VOLUM_EFECTE - 4.0, 0.1)
	_scoate_pumni()


## Mâna (pumnul) de pe latura `s` la ridicarea `a` (0 = brațul în jos, 1 = sus, la umăr), global: antebrațul se rotește
## în jurul cotului, din jos spre înainte și în sus.
func _mana_biceps(s: float, a: float) -> Vector3:
	var u := lerpf(0.15, 2.6, a)
	var cot := Vector3(BICEPS_COT.x * s, BICEPS_COT.y, BICEPS_COT.z)
	var local := cot + (Vector3.FORWARD * sin(u) + Vector3.DOWN * cos(u)) * ANTEBRAT + Vector3(-0.04 * s * a, 0, 0)
	# camera e aplecată în jos: cotul și mâna le ții față de corp (privirea pe orizontală), nu față de cameră

	return _corp() * local


func _corp() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, _jucator.rotation.y), _camera.global_position)
