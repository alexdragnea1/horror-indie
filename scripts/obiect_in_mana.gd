class_name ObiectInMana
extends Node3D
## Ce ții în mână la persoana întâi, în afară de pistol (care are scriptul lui, Pistol). Îl pune jucator.gd sub cameră.
## Arată modelul din `MODELE` pentru `Stare.in_mana` (banii și jetoanele sunt făcute din cod), iar cadavrele (Cadavre)
## le ții în brațe, culcate de-a curmezișul, jos în fața ta.
## La schimbare: cel vechi coboară din cadru, apoi urcă cel nou. Cât e deschis un meniu / o scenă sau e ecranul negru,
## îl lași jos, ca pistolul.
## Un obiect cu `"mancare": true` (bomboana) se mănâncă la click (acțiunea "trage"): îl desfaci, ambalajul (`Ambalaj`)
## cade, iar ce e dinăuntru (`Bomboana`) îl duci la gură și îl ronțăi din două mușcături; apoi iese din inventar.
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
		# lanterna nu prinde ce e lipit de cameră: un pic de luciu, ca la o bomboană tare
		"stralucitoare": ["Bomboana", "Ambalaj"],
		"stralucire": 0.3,
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
## O scenă din cod îl poate ține la vedere cât e Stare.meniu_deschis (ex. mătura pusă jos la antrenament).
static var in_scena := false

var _id := ""
var _model: Node3D
var _jos := 1.0  # 0 = în mână, 1 = lăsat jos (nu se vede)
var _timp := 0.0
var _mananca := false


func _process(delta: float) -> void:
	_timp += delta
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


## Îl scoate din mână pe loc, fără să-l coboare (când îl ia o scenă din cod, ex. mătura pusă jos la antrenament).
## Pune întâi `Stare.in_mana` = "", altfel urcă la loc.
func scoate_acum() -> Transform3D:
	var unde := _model.global_transform if _model else global_transform
	_jos = 1.0
	_schimba("")
	visible = false
	return unde


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("trage") and _poate_manca():
		get_viewport().set_input_as_handled()
		_mananca_acum()


func _poate_manca() -> bool:
	return _model != null and _date(_id).get("mancare", false) and not _mananca and _jos < 0.05 \
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
	Stare.scoate_obiect(id)
	_jos = 1.0
	_schimba("")
	visible = false
	_mananca = false


## Capul tresare puțin la o mușcătură (camera în jos și înapoi).
func _tresare(camera: Camera3D, cat := 1.0) -> void:
	var t := create_tween()
	t.tween_property(camera, "rotation:x", -0.035 * cat, 0.06)
	t.tween_property(camera, "rotation:x", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
