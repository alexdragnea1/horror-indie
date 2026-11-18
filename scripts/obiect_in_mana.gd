class_name ObiectInMana
extends Node3D
## Ce ții în mână la persoana întâi, în afară de pistol (care are scriptul lui, Pistol). Îl pune jucator.gd sub cameră.
## Arată modelul din `MODELE` pentru `Stare.in_mana` (banii și jetoanele sunt făcute din cod), iar cadavrele (Cadavre)
## le ții în brațe, culcate de-a curmezișul, jos în fața ta.
## La schimbare: cel vechi coboară din cadru, apoi urcă cel nou. Cât e deschis un meniu / o scenă sau e ecranul negru,
## îl lași jos, ca pistolul.
## Un obiect cu `"mancare": true` (bomboana) se mănâncă la click (acțiunea "trage"): îl desfaci, ambalajul (`Ambalaj`)
## cade, iar ce e dinăuntru (`Bomboana`) îl duci la gură și îl ronțăi din două mușcături; apoi iese din inventar.
## Cu `"voma": true` (bomboana din tomberon) te ia cu greață și vomiți pe jos (`_vomita`, Voma).
## Ca să adaugi un obiect: o intrare în `MODELE` cu id-ul din inventar (vezi ObiectLuat.id_obiect).

## id -> scena modelului, unde îl ții (față de cameră; originea modelului), cum e rotit; opțional `mancare`
## și bucățile care strălucesc puțin (`stralucitoare`, `stralucire`, ca la ModelPS2).
const MODELE := {
	"matura": {
		"scena": preload("res://models/matura.glb"),
		"pozitie": Vector3(0.44, -0.64, -0.66),
		"rotatie": Vector3(-0.4, 0.15, 0.3),
	},
	# banii: o bancnotă ținută ridicată spre tine (cash-ul = trei bancnote răsfirate), jetoanele = un teanc în palmă
	"bani_5": {
		"scena": preload("res://models/bancnota.glb"),
		"pozitie": Vector3(0.15, -0.16, -0.32),
		"rotatie": Vector3(1.15, 0.25, -0.15),
		"stralucire_toate": 0.35,
	},
	"cash": {
		"cod": "cash",
		"pozitie": Vector3(0.15, -0.16, -0.32),
		"rotatie": Vector3(1.15, 0.25, -0.15),
		"stralucire_toate": 0.35,
	},
	"jetoane": {
		"cod": "jetoane",
		"pozitie": Vector3(0.14, -0.19, -0.33),
		"rotatie": Vector3(0.45, 0.4, 0.0),
	},
	"bomboana": {
		"scena": preload("res://models/bomboana.glb"),
		"pozitie": Vector3(0.15, -0.15, -0.34),
		"rotatie": Vector3(0.35, 0.55, 0.25),
		"mancare": true,
		# e din tomberon: după ce o mănânci, vomiți (owner 11.10)
		"voma": true,
		# lanterna nu prinde ce e lipit de cameră: un pic de luciu, ca la o bomboană tare
		"stralucitoare": ["Bomboana", "Ambalaj"],
		"stralucire": 0.3,
	},
	# din magazinul satului (casiera_magazin.gd, owner 17.11): berea ($3) se bea la click și dispare; țigările ($10):
	# în mână e o singură țigară, la primul click o aprinzi (iese din cadru, bricheta, focul, revine aprinsă), apoi
	# fiecare click e un fum; după 20 de folosiri pachetul dispare (Tigari)
	"bere": {
		"scena": preload("res://models/bere_sticla.glb"),
		"pozitie": Vector3(0.17, -0.25, -0.36),
		"rotatie": Vector3(0.05, 0.4, -0.12),
		"bautura": true,
		"stralucire_toate": 0.3,
	},
	"tigari": {
		"scena": preload("res://models/tigara.glb"),
		# filtrul jos, vârful spre stânga-sus-înainte, ca între degete; mai spre mijlocul cadrului (owner 18.11: „stă cam
		# într-o parte”, era la x 0,1)
		"pozitie": Vector3(0.035, -0.11, -0.25),
		"rotatie": Vector3(0.0, 2.24, 0.35),
		"fumat": true,
		"stralucire_toate": 0.35,
	},
}
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")
## Cât coboară când îl lași jos.
const JOS := Vector3(0.05, -0.55, 0.12)
## Unde duci mâncarea: în fața ochilor (o desfaci), apoi la gură.
const LA_DESFACUT := Vector3(0.04, -0.11, -0.28)
const LA_GURA := Vector3(0.0, -0.075, -0.12)
const SUNET_AMBALAJ := preload("res://sunete/bomboana_ambalaj.ogg")
const SUNET_RONTA := preload("res://sunete/bomboana_ronta.ogg")
const SUNET_CAPAC := preload("res://sunete/capac_bere.ogg")
const SUNET_INGHITITURA := preload("res://sunete/bere_inghititura.ogg")
const SUNET_RAGAIT := preload("res://sunete/bere_ragait.ogg")
const SUNET_BRICHETA := preload("res://sunete/tigara_bricheta.ogg")
const SUNET_FOC := preload("res://sunete/tigara_foc.ogg")
const SUNET_TRAS := preload("res://sunete/fum_tras.ogg")
const SUNET_SUFLAT := preload("res://sunete/fum_suflat.ogg")
## Țigara: cât strălucește jarul (normal / când tragi din ea).
const JAR_NORMAL := 1.6
const JAR_TRAS := 4.0
## O scenă din cod îl poate ține la vedere cât e Stare.meniu_deschis (ex. mătura pusă jos la antrenament).
static var in_scena := false

var _id := ""
var _model: Node3D
var _jos := 1.0  # 0 = în mână, 1 = lăsat jos (nu se vede)
var _timp := 0.0
var _mananca := false
## Țigara din mână e aprinsă (o stingi când o pui deoparte: data viitoare aprinzi alta).
var _aprinsa := false
var _lumina_jar: OmniLight3D
var _fum_jar: CPUParticles3D


func _process(delta: float) -> void:
	_timp += delta
	# fumul țigării aprinse urcă din vârful ei (particulele sunt în lume, deci le muți tu după vârf)
	if is_instance_valid(_fum_jar) and _model:
		var jar := _model.find_child("Jar", true, false) as Node3D
		if jar:
			_fum_jar.global_position = jar.global_position
	if _mananca:
		return  # animația de mâncat mișcă singură modelul
	var vrut := Stare.in_mana if are_model(Stare.in_mana) else ""
	var jos := vrut != _id or vrut == "" or (Stare.meniu_deschis and not in_scena) or Tranzitie.activa
	_jos = move_toward(_jos, 1.0 if jos else 0.0, delta * 3.0)
	if _jos >= 1.0 and vrut != _id:
		_schimba(vrut)
	visible = _model != null and _jos < 0.99
	if _model == null:
		return
	var date := _date(_id)
	var k := ease(_jos, 2.0)
	# se leagănă puțin cât îl ții
	var respiratie := Vector3(sin(_timp * 1.3) * 0.003, sin(_timp * 2.1) * 0.004, 0.0)
	_model.position = date.pozitie + JOS * k + respiratie
	if date.has("baza"):
		# cadavrele: culcat = unghiuri drepte (Euler-ul ar fi blocat, gimbal lock), deci direct baza
		_model.basis = Basis(Vector3.RIGHT, -0.5 * k) * (date.baza as Basis)
	else:
		_model.rotation = date.rotatie + Vector3(-0.5 * k, 0.0, 0.0)


## Are ce arăta în mână: un obiect din `MODELE` sau un cadavru (Cadavre).
static func are_model(id: String) -> bool:
	return MODELE.has(id) or Cadavre.e_cadavru(id)


## Datele obiectului: din `MODELE`, iar pentru cadavre poza din brațe: culcat pe spate, de-a curmezișul, capul spre
## stânga ta (ca la gardul cimitirului), jos în fața ta; pisica mai aproape.
func _date(id: String) -> Dictionary:
	if MODELE.has(id):
		return MODELE[id]
	var mic: bool = Cadavre.MODELE[id].get("mic", false)
	var in_brate := Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0))
	if Cadavre.MODELE[id].get("cu_fata_in_jos", false):
		in_brate = Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0))
	return {"cod": "cadavru", "pozitie": Vector3(0.04, -0.26, -0.42) if mic else Vector3(0.05, -0.43, -0.74),
		"baza": Basis(Vector3.RIGHT, 0.25) * in_brate, "stralucire_toate": 0.12}


func _schimba(id: String) -> void:
	if _model:
		_model.queue_free()
		_model = null
	# țigara pusă deoparte se stinge (fumul ei din aer se oprește)
	_aprinsa = false
	if is_instance_valid(_fum_jar):
		_fum_jar.emitting = false
		get_tree().create_timer(2.0).timeout.connect(_fum_jar.queue_free)
	_fum_jar = null
	_lumina_jar = null
	_id = id
	if id == "":
		return
	var date := _date(id)
	match date.get("cod", ""):
		"cadavru":
			_model = Cadavre.suport(id, true)
		"jetoane":
			_model = Jetoane.model_teanc(true)
		"cash":
			# trei bancnote răsfirate ca un evantai
			_model = Node3D.new()
			for k in 3:
				var b := (preload("res://models/bancnota.glb") as PackedScene).instantiate() as Node3D
				b.set_script(SCRIPT_MODEL)
				b.set("material", MATERIAL)
				b.set("umbre", false)
				b.rotation.y = (k - 1) * 0.22
				b.position = Vector3((k - 1) * 0.012, k * 0.0015, 0.0)
				_model.add_child(b)
		_:
			_model = (date.scena as PackedScene).instantiate()
			_model.set_script(SCRIPT_MODEL)
			_model.set("material", MATERIAL)
			_model.set("umbre", false)
			if date.has("stralucitoare"):
				_model.set("stralucitoare", PackedStringArray(date.stralucitoare))
				_model.set("stralucire", date.stralucire)
	add_child(_model)
	for m in _model.find_children("*", "GeometryInstance3D", true, false):
		(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# lanterna nu prinde ce e lipit de cameră: un pic de luciu pe tot
		if date.has("stralucire_toate") and (m as GeometryInstance3D).material_override is ShaderMaterial:
			(m as GeometryInstance3D).set_instance_shader_parameter("stralucire", date.stralucire_toate)
	if date.get("fumat", false):
		_arata_varful()


## Îl scoate din mână pe loc, fără să-l coboare (când îl ia o scenă din cod, ex. mătura pusă jos la antrenament).
## Pune întâi `Stare.in_mana` = "", altfel urcă la loc.
func scoate_acum() -> Transform3D:
	var unde := _model.global_transform if _model else global_transform
	_jos = 1.0
	_schimba("")
	visible = false
	return unde


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("trage") or not _poate_folosi():
		return
	var date := _date(_id)
	if date.get("mancare", false):
		get_viewport().set_input_as_handled()
		_mananca_acum()
	elif date.get("bautura", false):
		get_viewport().set_input_as_handled()
		_bea_acum()
	elif date.get("fumat", false):
		get_viewport().set_input_as_handled()
		_fumeaza_acum()


## Poți folosi ce ții (mânca / bea / fuma): e în mână de tot, nu e altă animație în curs, nu e meniu / dialog.
func _poate_folosi() -> bool:
	return _model != null and not _mananca and _jos < 0.05 \
		and _id == Stare.in_mana and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
		and not Dialog.activ and not Stare.meniu_deschis and not Tranzitie.activa


func _mananca_acum() -> void:
	_mananca = true
	var id := _id
	var camera := get_parent() as Camera3D
	var ambalaj := _model.find_child("Ambalaj", true, false) as Node3D
	var miez := _model.find_child("Bomboana", true, false) as Node3D
	# 1. o aduci în fața ochilor, culcată, și o desfaci: o răsucești de capete
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_model, "position", LA_DESFACUT, 0.3)
	t.parallel().tween_property(_model, "rotation", Vector3(0.15, 0.0, 0.0), 0.3)
	t.tween_callback(Sunet.reda.bind(SUNET_AMBALAJ, Sunet.VOLUM_EFECTE, 0.05))
	t.tween_property(_model, "rotation:x", 0.15 + TAU, 0.45)
	await t.finished
	# 2. ambalajul îți scapă printre degete și cade din cadru
	if ambalaj:
		var cadere := ambalaj.global_position + camera.global_basis * Vector3(0.06, -0.35, 0.05)
		var c := create_tween().set_parallel()
		c.tween_property(ambalaj, "global_position", cadere, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		c.tween_property(ambalaj, "rotation", ambalaj.rotation + Vector3(2.0, 1.0, 3.0), 0.5)
		c.chain().tween_callback(ambalaj.hide)
	await get_tree().create_timer(0.25).timeout
	# 3. două mușcături: la gură, cronț (bomboana scade, capul tresare), înapoi puțin
	for i in 2:
		t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(_model, "position", LA_GURA, 0.28 if i == 0 else 0.16)
		t.parallel().tween_property(_model, "rotation", Vector3(0.0, 0.35, -0.2), 0.28 if i == 0 else 0.16)
		await t.finished
		Sunet.reda(SUNET_RONTA, Sunet.VOLUM_EFECTE, 0.0, &"Efecte", randf_range(0.92, 1.08))
		if miez:
			miez.scale = Vector3.ONE * (0.55 if i == 0 else 0.0)
			miez.position.x = 0.012 if i == 0 else 0.0  # mușcată dintr-o parte
		_tresare(camera)
		if i == 0:
			t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			t.tween_property(_model, "position", LA_GURA + Vector3(0.03, -0.03, -0.05), 0.3)
			await t.finished
	_model.hide()
	# 4. o molfăi: încă două ronțăieli, tot mai înfundate
	for pas in [[0.85, -5.0], [0.75, -9.0]]:  # [înălțime, volum]
		await get_tree().create_timer(0.38).timeout
		Sunet.reda(SUNET_RONTA, Sunet.VOLUM_EFECTE + pas[1], 0.0, &"Efecte", pas[0])
		_tresare(camera, 0.5)
	var voma: bool = _date(id).get("voma", false)
	Stare.scoate_obiect(id)
	_jos = 1.0
	_schimba("")
	visible = false
	if voma:
		await _vomita(camera)
	_mananca = false


## Bomboana din tomberon: stomacul chiorăie, două sughițuri de greață, apoi te apleci și vomiți pe jos (două valuri),
## tușești și te ridici. Balta rămâne acolo. Replica e a owner-ului (11.10).
func _vomita(camera: Camera3D) -> void:
	var jucator := get_tree().get_first_node_in_group("jucator") as CharacterBody3D
	if jucator == null:
		return
	await get_tree().create_timer(1.0).timeout
	Voma.sunet(Voma.SUNET_STOMAC)
	await get_tree().create_timer(1.8).timeout
	var c := Cutscena.porneste(self)
	Voma.sunet(Voma.SUNET_GREATA)
	_tresare(camera, 3.0)
	await get_tree().create_timer(0.65).timeout
	_tresare(camera, 4.0)
	await get_tree().create_timer(0.45).timeout
	await c.roteste(jucator.rotation.y, deg_to_rad(-50), 0.3)
	var v := Voma.porneste(get_tree().current_scene, [jucator.get_rid()])
	var inainte := -jucator.global_basis.z
	inainte.y = 0.0
	inainte = inainte.normalized()
	for val in [[1.4, 1.0, 0.0], [0.7, 0.75, -5.0]]:  # [durata, putere, volum]
		Voma.sunet(Voma.SUNET_JET, Vector3.INF, val[2], 1.0 if val[2] == 0.0 else 1.08)
		var gura := camera.global_position + camera.global_basis * Vector3(0.0, -0.1, -0.12)
		var tremur := create_tween().set_loops(int(val[0] / 0.2))
		tremur.tween_callback(_tresare.bind(camera, 1.5))
		tremur.tween_interval(0.2)
		await v.jet(gura, (inainte * 1.3 + Vector3.DOWN * 0.6) * val[1], val[0])
		tremur.kill()
		await get_tree().create_timer(0.45).timeout
	v.opreste()
	Voma.sunet(Voma.SUNET_TUSE)
	await get_tree().create_timer(0.9).timeout
	await c.roteste(jucator.rotation.y, 0.0, 0.8)
	Dialog.spune(PackedStringArray(["You: That wasn't very yummy.."]))
	if Dialog.activ:
		await Dialog.terminat
	await c.opreste()


## Capul tresare puțin la o mușcătură (camera în jos și înapoi).
func _tresare(camera: Camera3D, cat := 1.0) -> void:
	var t := create_tween()
	t.tween_property(camera, "rotation:x", -0.035 * cat, 0.06)
	t.tween_property(camera, "rotation:x", 0.0, 0.2).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------- berea și țigările (magazinul satului)

## Berea: o aduci în fața ta și o desfaci (capacul sare), o duci la gură cu fundul în sus, capul se lasă pe spate, două
## înghițituri, apoi o lași; dispare din inventar. Te ia puțin (Betie, EfectBeat, ca la bar) și uneori râgâi.
func _bea_acum() -> void:
	_mananca = true
	var camera := get_parent() as Camera3D
	var capac := _model.find_child("Capac", true, false) as Node3D
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_model, "position", Vector3(0.06, -0.17, -0.3), 0.35)
	t.parallel().tween_property(_model, "rotation", Vector3.ZERO, 0.35)
	await t.finished
	Sunet.reda(SUNET_CAPAC, Sunet.VOLUM_EFECTE, 0.05)
	if capac:
		var c := create_tween().set_parallel()
		c.tween_property(capac, "position", capac.position + Vector3(0.04, 0.12, 0.0), 0.25).set_ease(Tween.EASE_OUT)
		c.tween_property(capac, "rotation", Vector3(2.5, 1.0, 3.0), 0.25)
		c.chain().tween_callback(capac.hide)
	await get_tree().create_timer(0.35).timeout
	# la gură: sticla vine cu gâtul la buze și fundul în sus, spre dreapta (ca la bar, barman.gd)
	var axa := Vector3(-0.28, -0.62, 0.73).normalized()
	var buza := Vector3(0.02, -0.075, -0.1)
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel()
	t.tween_property(_model, "position", buza - axa * 0.23, 0.6)
	t.tween_property(_model, "basis", Basis(Quaternion(Vector3.UP, axa)), 0.6)
	t.tween_property(camera, "rotation:x", 0.3, 0.6)
	await t.finished
	for i in 2:
		Sunet.reda(SUNET_INGHITITURA, Sunet.VOLUM_EFECTE - 1.0, 0.1)
		await get_tree().create_timer(0.5).timeout
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel()
	t.tween_property(_model, "position", Vector3(0.06, -0.3, -0.3), 0.45)
	t.tween_property(_model, "basis", Basis.IDENTITY, 0.45)
	t.tween_property(camera, "rotation:x", 0.0, 0.45)
	await t.finished
	Stare.scoate_obiect(Tigari.ID_BERE)
	_jos = 1.0
	_schimba("")
	visible = false
	Betie.adauga(0.5)
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	if jucator:
		EfectBeat.porneste(jucator, 6.0)
	_mananca = false
	if randf() < 0.6:
		await get_tree().create_timer(0.5).timeout
		Sunet.reda(SUNET_RAGAIT, Sunet.VOLUM_EFECTE - 3.0, 0.05)


## Țigara: stinsă, o aprinzi (coboară din cadru, bricheta, flacăra luminează de jos, revine aprinsă, cu jarul și fumul
## de la vârf); aprinsă, tragi un fum (la gură, jarul se întețește, apoi sufli fumul în fața ta). Fiecare click e o
## folosire din cele 20 ale pachetului (Tigari); după ultima, pachetul dispare din inventar și țigara coboară.
func _fumeaza_acum() -> void:
	_mananca = true
	var camera := get_parent() as Camera3D
	var date := _date(_id)
	if not _aprinsa:
		var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		t.tween_property(_model, "position", date.pozitie + JOS, 0.35)
		await t.finished
		Sunet.reda(SUNET_BRICHETA, Sunet.VOLUM_EFECTE, 0.05)
		await get_tree().create_timer(0.38).timeout
		# flacăra brichetei, sub cadru: o lumină portocalie care pâlpâie de jos
		var flacara := OmniLight3D.new()
		flacara.light_color = Color(1.0, 0.62, 0.3)
		flacara.omni_range = 1.4
		flacara.light_energy = 0.0
		camera.add_child(flacara)
		flacara.position = Vector3(0.06, -0.38, -0.3)
		Sunet.reda(SUNET_FOC, Sunet.VOLUM_EFECTE - 2.0, 0.05)
		var p := create_tween()
		for k in 6:
			p.tween_property(flacara, "light_energy", randf_range(0.6, 1.3), 0.1)
		p.tween_property(flacara, "light_energy", 0.0, 0.15)
		p.tween_callback(flacara.queue_free)
		await get_tree().create_timer(0.55).timeout
		_aprinsa = true
		_arata_varful()
		t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(_model, "position", date.pozitie, 0.45)
		await t.finished
	else:
		var jar := _model.find_child("Jar", true, false) as GeometryInstance3D
		var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel()
		t.tween_property(_model, "position", Vector3(0.0, -0.065, -0.1), 0.4)
		t.tween_property(_model, "rotation", Vector3(0.0, 1.27, -0.2), 0.4)
		await t.finished
		Sunet.reda(SUNET_TRAS, Sunet.VOLUM_EFECTE - 2.0, 0.05)
		Tigari.porneste_bonus()  # un minut cu 10% mai repede (owner 18.11)
		var aprinde := func(v: float) -> void:
			if is_instance_valid(jar):
				jar.set_instance_shader_parameter("stralucire", v)
		if jar:
			create_tween().tween_method(aprinde, JAR_NORMAL, JAR_TRAS, 0.9)
		if is_instance_valid(_lumina_jar):
			create_tween().tween_property(_lumina_jar, "light_energy", 0.7, 0.9)
		await get_tree().create_timer(1.1).timeout
		t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).set_parallel()
		t.tween_property(_model, "position", date.pozitie, 0.45)
		t.tween_property(_model, "rotation", date.rotatie, 0.45)
		if jar:
			t.tween_method(aprinde, JAR_TRAS, JAR_NORMAL, 0.6)
		if is_instance_valid(_lumina_jar):
			t.tween_property(_lumina_jar, "light_energy", 0.25, 0.6)
		await t.finished
		await get_tree().create_timer(0.2).timeout
		Sunet.reda(SUNET_SUFLAT, Sunet.VOLUM_EFECTE - 2.0, 0.05)
		_sufla_fum(camera)
	_mananca = false
	# ultima țigară din pachet: pachetul iese din inventar, țigara coboară și dispare (_process)
	Tigari.foloseste()


## Vârful țigării: hârtia albă cât e stinsă; aprinsă = jarul care strălucește (cu o lumină mică portocalie) și cenușa,
## iar din vârf urcă un fir subțire de fum.
func _arata_varful() -> void:
	if _model == null:
		return
	var capat := _model.find_child("Capat", true, false) as Node3D
	var jar := _model.find_child("Jar", true, false) as Node3D
	var scrum := _model.find_child("Scrum", true, false) as Node3D
	if capat:
		capat.visible = not _aprinsa
	if scrum:
		scrum.visible = _aprinsa
	if jar == null:
		return
	jar.visible = _aprinsa
	if not _aprinsa:
		return
	if jar is GeometryInstance3D:
		(jar as GeometryInstance3D).set_instance_shader_parameter("stralucire", JAR_NORMAL)
	_lumina_jar = OmniLight3D.new()
	_lumina_jar.light_color = Color(1.0, 0.45, 0.2)
	_lumina_jar.omni_range = 0.5
	_lumina_jar.light_energy = 0.25
	jar.add_child(_lumina_jar)
	_fum_jar = _particule_fum(6, 1.6, 0.012, Color(0.75, 0.75, 0.75, 0.3))
	_fum_jar.direction = Vector3.UP
	_fum_jar.spread = 12.0
	_fum_jar.initial_velocity_min = 0.03
	_fum_jar.initial_velocity_max = 0.06
	_fum_jar.gravity = Vector3(0.0, 0.05, 0.0)
	_fum_jar.global_position = jar.global_position
	_fum_jar.preprocess = 1.6
	_fum_jar.emitting = true


## Fumul suflat: un nor mic care iese din gură în fața ta și se risipește.
func _sufla_fum(camera: Camera3D) -> void:
	var nor := _particule_fum(18, 1.4, 0.05, Color(0.78, 0.78, 0.78, 0.35))
	nor.one_shot = true
	# tot norul deodată: particulele încă nepornite ale unui one_shot apar ca un disc negru (lecția de la ceaun)
	nor.explosiveness = 1.0
	nor.global_position = camera.global_transform * Vector3(0.0, -0.08, -0.22)
	nor.direction = -camera.global_basis.z + Vector3.UP * 0.15
	nor.spread = 20.0
	nor.initial_velocity_min = 0.35
	nor.initial_velocity_max = 0.6
	nor.damping_min = 0.4
	nor.damping_max = 0.6
	nor.gravity = Vector3(0.0, 0.08, 0.0)
	nor.emitting = true
	get_tree().create_timer(2.0).timeout.connect(nor.queue_free)


## Particule de fum în lume (nu lipite de cameră): cercul moale de 16 px al armelor, gri, care se stinge.
## Pornite oprite; `emitting` = true după reglaje (altfel apare un pătrat negru la sursă).
func _particule_fum(cate: int, viata: float, marime: float, culoare: Color) -> CPUParticles3D:
	var fum := CPUParticles3D.new()
	fum.emitting = false
	fum.amount = cate
	fum.lifetime = viata
	fum.local_coords = false
	var quad := QuadMesh.new()
	quad.size = Vector2(marime, marime)
	var mat := Arma.material_particule(false)
	mat.vertex_color_is_srgb = true
	quad.material = mat
	fum.mesh = quad
	var rampa := Gradient.new()
	rampa.set_color(0, culoare)
	rampa.set_color(1, Color(culoare, 0.0))
	fum.color_ramp = rampa
	fum.scale_amount_min = 1.0
	fum.scale_amount_max = 1.6
	get_tree().current_scene.add_child(fum)
	return fum
