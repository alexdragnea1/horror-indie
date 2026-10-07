class_name OmLaMasa
extends Node3D
## Un om așezat (jucătorii de la masa de poker, bătrâna de la casă), animat din cod. Copilul `Model` = un .glb din
## casino_oameni.py (`Corp` → `Cap`, `BratD/S` → `AntebratD/S` → `Mana`; fumătorii au `Tigara` cu `Jar`).
##  - respiră, își mută privirea (`privire` = un Node3D, sau `priveste_punct`), din când în când se uită în altă parte;
##  - `fumeaza`: la câteva secunde duce țigara la gură, jarul se aprinde, suflă fumul; firul de fum urcă din jar;
##  - `await du_mana("D", punct, durata)` / `lasa_mana("D")`: brațul ajunge singur acolo (IK cu două oase, cotul se îndoaie
##    spre partea în care era în model, deci în repaus brațul stă exact ca în model);
##  - gesturi pentru poker: `await gest(punct)` (întinde mâna până acolo și o retrage), `await bate_masa()` (check).
## D = mâna dreaptă a lui (spre -X; modelul privește spre +Z).

## Spre ce se uită (null = drept înainte, sau `priveste_punct`).
@export var privire: Node3D
@export var fumeaza := true
## Cât de des trage din țigară (secunde, între două fumuri).
@export var pauza_fum := Vector2(7.0, 13.0)
## Cât de repede își mută capul.
@export var viteza_cap := 3.0
## Cât de des se uită „în altă parte” singur (secunde); 0 = niciodată.
@export var pauza_privire := Vector2(3.0, 7.0)
## Unde se uită când se uită „în altă parte” (puncte globale; gol = doar drept înainte).
var puncte_privire: Array[Vector3] = []
var priveste_punct := Vector3.INF

const GURA := Vector3(0.0, 0.112, 0.11)  # în coordonatele capului (originea în gât)
const SUNET_TRAS := preload("res://sunete/fum_tras.ogg")
const SUNET_SUFLAT := preload("res://sunete/fum_suflat.ogg")

var _model: Node3D
var _corp: Node3D
var _cap: Node3D
var _brat := {}
var _antebrat := {}
var _mana := {}
var _v1 := {}
var _v2 := {}
var _pol := {}
var _repaus := {}
var _spre := {"D": null, "S": null}
var _cat := {"D": 0.0, "S": 0.0}
var _ocupata := {"D": false, "S": false}
var _tw := {"D": null, "S": null}
var _jar: GeometryInstance3D
var _lumina_jar: OmniLight3D
var _timp := 0.0
var _pana_la_fum := 4.0
var _pana_la_privire := 2.0
var _privire_temp := Vector3.INF
var _cap_rot := Vector2.ZERO
var _corp_baza := Vector3.ONE
var _faza := 0.0
var _corp_rotatie := Vector3.ZERO
## Tresăritul (1 → 0) și direcția glonțului, în coordonatele lui.
var _tresarire := 0.0
var _smucit := Vector3.ZERO


func _ready() -> void:
	_model = $Model
	_corp = _model.find_child("Corp", true, false)
	_cap = _model.find_child("Cap", true, false)
	_faza = randf() * TAU
	_corp_baza = _corp.scale
	_corp_rotatie = _corp.rotation
	for l in ["D", "S"]:
		_brat[l] = _model.find_child("Brat" + l, true, false)
		_antebrat[l] = _model.find_child("Antebrat" + l, true, false)
		# „Mana” (în Blender a doua se numește „Mana.001”, deci aici „Mana_001”)
		for c in (_antebrat[l] as Node3D).get_children():
			if c.name.begins_with("Mana"):
				_mana[l] = c
		_v1[l] = (_antebrat[l] as Node3D).position
		_v2[l] = (_mana[l] as Node3D).position
		# cotul se îndoaie spre unde era în model (în coordonatele corpului)
		_pol[l] = (_brat[l] as Node3D).basis * (_v1[l] as Vector3)
		# repausul mâinii, în coordonatele corpului
		_repaus[l] = (_brat[l] as Node3D).position + (_brat[l] as Node3D).basis * ((_v1[l] as Vector3) + (_v2[l] as Vector3))
	var tigara := _model.find_child("Tigara", true, false)
	if tigara == null:
		fumeaza = false
	else:
		_pregateste_jar.call_deferred()
	_pana_la_fum = randf_range(1.0, pauza_fum.y)
	_pana_la_privire = randf_range(0.5, 3.0)


func _pregateste_jar() -> void:
	await get_tree().process_frame
	_jar = _model.find_child("Jar", true, false) as GeometryInstance3D
	if _jar == null:
		return
	_lumina_jar = OmniLight3D.new()
	_lumina_jar.light_color = Color(1.0, 0.5, 0.25)
	_lumina_jar.light_energy = 0.2
	_lumina_jar.omni_range = 0.6
	_lumina_jar.light_volumetric_fog_energy = 0.0
	_jar.add_child(_lumina_jar)
	Lexy.fir_de_fum(_jar, Vector3.ZERO)
	jar(0.0)


## Cât de tare arde jarul (0 = mocnește, 1 = trage din țigară).
func jar(cat: float) -> void:
	if is_instance_valid(_jar):
		_jar.set_instance_shader_parameter("stralucire", lerpf(0.9, 3.2, cat))
	if is_instance_valid(_lumina_jar):
		_lumina_jar.light_energy = lerpf(0.2, 1.2, cat)


func _process(delta: float) -> void:
	_timp += delta
	# respirația: pieptul se umflă puțin
	_corp.scale = _corp_baza * Vector3(1.0 + sin(_timp * 1.7 + _faza) * 0.008, 1.0 + sin(_timp * 1.7 + _faza) * 0.012, 1.0)
	# tresăritul de la un glonț: trunchiul smucit înapoi și într-o parte, apoi revine
	_tresarire = move_toward(_tresarire, 0.0, delta * 2.5)
	var k := ease(_tresarire, 0.4)
	_corp.rotation = _corp_rotatie + Vector3(_smucit.z * 0.22 * k, 0.0, -_smucit.x * 0.18 * k)
	_priveste(delta)
	for l in ["D", "S"]:
		if _cat[l] > 0.0:
			_ik(l, _tinta_globala(l))
		else:
			(_brat[l] as Node3D).basis = Basis.IDENTITY
			(_antebrat[l] as Node3D).basis = Basis.IDENTITY
	if fumeaza:
		_pana_la_fum -= delta
		if _pana_la_fum <= 0.0 and not _ocupata["D"]:
			_pana_la_fum = randf_range(pauza_fum.x, pauza_fum.y)
			trage_un_fum()
	if pauza_privire.x > 0.0 and not puncte_privire.is_empty():
		_pana_la_privire -= delta
		if _pana_la_privire <= 0.0:
			_pana_la_privire = randf_range(pauza_privire.x, pauza_privire.y)
			_privire_temp = puncte_privire.pick_random() if randf() < 0.75 else Vector3.INF


func _priveste(delta: float) -> void:
	var tinta := Vector3.INF
	if is_instance_valid(privire):
		tinta = privire.global_position
	elif priveste_punct != Vector3.INF:
		tinta = priveste_punct
	elif _privire_temp != Vector3.INF:
		tinta = _privire_temp
	var dorit := Vector2.ZERO
	if tinta != Vector3.INF:
		var parinte := _cap.get_parent() as Node3D
		var d := parinte.global_basis.inverse() * (tinta - _cap.global_position)
		var orizontal := Vector2(d.x, d.z).length()
		dorit = Vector2(clampf(atan2(-d.y, orizontal), -0.5, 0.6), clampf(atan2(d.x, d.z), -1.1, 1.1))
	_cap_rot = _cap_rot.lerp(dorit, clampf(delta * viteza_cap, 0.0, 1.0))
	_cap.rotation = Vector3(_cap_rot.x, _cap_rot.y, 0.0)


# ---------------------------------------------------------------- brațele (IK)

## Duce mâna `l` la `tinta` (Node3D sau punct global) în `durata` secunde.
func du_mana(l: String, tinta: Variant, durata: float) -> void:
	_ocupata[l] = true
	var t := _tween_mana(l)
	if _cat[l] > 0.01:
		var de_la := _tinta_globala(l)
		_cat[l] = 1.0
		_spre[l] = de_la
		t.tween_method(func(v: float) -> void: _spre[l] = de_la.lerp(_punct(tinta), v), 0.0, 1.0, durata)
		await t.finished
		_spre[l] = tinta
		return
	_spre[l] = tinta
	t.tween_method(func(v: float) -> void: _cat[l] = v, _cat[l], 1.0, durata)
	await t.finished


func lasa_mana(l: String, durata := 0.6) -> void:
	var t := _tween_mana(l)
	t.tween_method(func(v: float) -> void: _cat[l] = v, _cat[l], 0.0, durata)
	await t.finished
	_ocupata[l] = false


func mana_ocupata(l: String) -> bool:
	return _ocupata[l]


## Unde e acum punctul dintre degete (global).
func punct_mana(l: String) -> Vector3:
	return (_mana[l] as Node3D).global_position


func nod_mana(l: String) -> Node3D:
	return _mana[l]


func gura() -> Vector3:
	return _cap.global_transform * GURA


func _tween_mana(l: String) -> Tween:
	var vechi: Tween = _tw[l]
	if vechi and vechi.is_valid():
		vechi.kill()
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw[l] = t
	return t


func _punct(tinta: Variant) -> Vector3:
	return (tinta as Node3D).global_position if tinta is Node3D else tinta


func _tinta_globala(l: String) -> Vector3:
	var repaus: Vector3 = _corp.global_transform * (_repaus[l] as Vector3)
	var spre: Variant = _spre[l]
	if _cat[l] <= 0.0 or spre == null or (spre is Object and not is_instance_valid(spre)):
		return repaus
	return repaus.lerp(_punct(spre), _cat[l])


func _ik(l: String, tinta: Vector3) -> void:
	var brat: Node3D = _brat[l]
	var antebrat: Node3D = _antebrat[l]
	var t := _corp.global_transform.affine_inverse() * tinta - brat.position
	var v1: Vector3 = _v1[l]
	var v2: Vector3 = _v2[l]
	var l1 := v1.length()
	var l2 := v2.length()
	var d := clampf(t.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.005)
	var dir := t.normalized() if t.length() > 0.001 else Vector3.FORWARD
	var cos_a := (l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d)
	var a := acos(clampf(cos_a, -1.0, 1.0))
	var axa := dir.cross(_pol[l] as Vector3)
	if axa.length() < 0.001:
		axa = Vector3.RIGHT
	axa = axa.normalized()
	var u := dir.rotated(axa, a)
	var cot := u * l1
	var f := (dir * d - cot).normalized()
	var r1 := Basis(Quaternion(v1.normalized(), u))
	var r2 := Basis(Quaternion((r1 * v2).normalized(), f)) * r1
	brat.basis = r1
	antebrat.basis = r1.inverse() * r2


# ---------------------------------------------------------------- gesturi

## Trage din țigară: mâna la gură, jarul se aprinde, apoi suflă un nor de fum.
func trage_un_fum() -> void:
	if not fumeaza or _ocupata["D"]:
		return
	var la_gura := Node3D.new()
	_cap.add_child(la_gura)
	la_gura.position = GURA + Vector3(-0.02, -0.02, 0.06)
	await du_mana("D", la_gura, 0.9)
	Sunet.reda_la(SUNET_TRAS, gura(), Sunet.VOLUM_EFECTE - 10.0, 0.1)
	var t := create_tween()
	t.tween_method(jar, 0.0, 1.0, 0.5)
	await get_tree().create_timer(1.1).timeout
	jar(0.4)
	await lasa_mana("D", 0.8)
	la_gura.queue_free()
	await get_tree().create_timer(0.3).timeout
	jar(0.0)
	Sunet.reda_la(SUNET_SUFLAT, gura(), Sunet.VOLUM_EFECTE - 12.0, 0.1)
	var nor := Node3D.new()
	get_tree().current_scene.add_child(nor)
	nor.global_position = gura() + global_basis.z * 0.06
	Lexy.fum(nor, 0.7)
	get_tree().create_timer(4.0).timeout.connect(nor.queue_free)


## Întinde mâna până la `punct` (ex. pune jetoane în pot) și o retrage. Folosește mâna liberă (fumătorii, stânga).
func gest(punct: Vector3, durata := 0.55) -> void:
	var l := "S" if (fumeaza or _ocupata["D"]) else "D"
	if _ocupata[l]:
		return
	await du_mana(l, punct, durata)
	await get_tree().create_timer(0.15).timeout
	await lasa_mana(l, durata)


## „Check”: bate de două ori cu degetele în masă.
func bate_masa() -> void:
	var l := "S" if (fumeaza or _ocupata["D"]) else "D"
	if _ocupata[l]:
		return
	var repaus: Vector3 = _corp.global_transform * (_repaus[l] as Vector3)
	for i in 2:
		await du_mana(l, repaus + Vector3.UP * 0.07, 0.12)
		await du_mana(l, repaus + Vector3.UP * 0.005, 0.08)
	await lasa_mana(l, 0.2)


## Un glonț (TintaOm): trunchiul e smucit în direcția lui, apoi revine.
func tresare(directie: Vector3) -> void:
	var local := global_basis.inverse() * directie
	local.y = 0.0
	_smucit = local.normalized() if local.length() > 0.01 else Vector3.BACK
	_tresarire = 1.0
