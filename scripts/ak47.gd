class_name AK47
extends Arma
## AK-47 de la Gun Store ($250). Automat: cât ții apăsat click stânga trage `cadenta` gloanțe pe secundă; fiecare
## glonț: flacăra, `Manivela` (maneta de armare) sare înapoi, un tub de alamă zboară în dreapta, arma tresare și
## privirea urcă puțin (tot mai împrăștiat cât ții apăsat). După `incarcator` gloanțe reîncarcă singur: arma se
## înclină, `Incarcator` cade, vine altul, îl bagi, tragi de manetă.

const ID := "ak47"
const NUME := "AK-47"
const SUNET_FOC := preload("res://sunete/ak_foc.ogg")
const SUNET_SCOS := preload("res://sunete/ak_incarcator_scos.ogg")
const SUNET_PUS := preload("res://sunete/ak_incarcator_pus.ogg")
const SUNET_ARMAT := preload("res://sunete/ak_armat.ogg")
const GURA := Vector3(0, 0.012, -0.645)
const EVACUARE := Vector3(0.03, 0.03, -0.07)

@export var cadenta := 10.0
@export var incarcator := 30
@export var bataie := 80.0

var _gloante := 30
var _imprastiere := 0.0
var _manivela: Node3D
var _manivela_repaus := Vector3.ZERO
var _inc: Node3D
var _inc_repaus := Transform3D.IDENTITY


func _init() -> void:
	id = ID
	scena = preload("res://models/ak47.glb")
	pozitie = Vector3(0.16, -0.19, -0.3)
	rotatie = Vector3(0.02, 0.05, 0.0)
	pozitie_jos = Vector3(0.22, -0.65, -0.15)


func _pregateste() -> void:
	_gloante = incarcator
	_manivela = _piesa("Manivela")
	if _manivela:
		_manivela_repaus = _manivela.position
	_inc = _piesa("Incarcator")
	if _inc:
		_inc_repaus = _inc.transform


## Automat: trage cât ții apăsat (primul glonț vine tot de aici, nu din _unhandled_input).
func _unhandled_input(_event: InputEvent) -> void:
	pass


func _actualizeaza(delta: float) -> void:
	var apasat := Input.is_action_pressed("trage")
	if not apasat:
		_imprastiere = move_toward(_imprastiere, 0.0, delta * 0.12)
	if apasat and poate_trage():
		_foc()
	# reculul se stinge repede
	anim_poz = anim_poz.lerp(Vector3.ZERO, clampf(delta * 14.0, 0.0, 1.0)) if not ocupata else anim_poz
	anim_rot = anim_rot.lerp(Vector3.ZERO, clampf(delta * 12.0, 0.0, 1.0)) if not ocupata else anim_rot


func _foc() -> void:
	gata = 1.0 / cadenta
	_gloante -= 1
	Sunet.reda(SUNET_FOC, Sunet.VOLUM_EFECTE, 0.06)
	_fulger(GURA, 1.3, 0.04)
	if randf() < 0.4:
		_fum_gura(GURA, 0.8)
	_anunta("ak47")
	_glont(_directie(0.006 + _imprastiere), bataie, 10.0)
	_imprastiere = minf(_imprastiere + 0.004, 0.05)
	_recul_cap(0.012 + randf() * 0.006, randf_range(-0.006, 0.006))
	Zguduire.porneste(_camera, 0.004, 0.08)
	anim_poz += Vector3(randf_range(-0.004, 0.004), 0.006, 0.045)
	anim_rot += Vector3(0.06, randf_range(-0.02, 0.02), randf_range(-0.03, 0.03))
	_tub(EVACUARE, Color("a18463"))
	if _manivela:
		var t := create_tween()
		t.tween_property(_manivela, "position", _manivela_repaus + Vector3(0, 0, 0.06), 0.03)
		t.tween_property(_manivela, "position", _manivela_repaus, 0.04)
	if _gloante <= 0:
		_reincarca()


func _reincarca() -> void:
	ocupata = true
	await get_tree().create_timer(0.15).timeout
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# arma înclinată spre tine, cu încărcătorul în față
	t.tween_property(self, "anim_rot", Vector3(0.3, -0.25, 0.6), 0.3)
	t.parallel().tween_property(self, "anim_poz", Vector3(-0.05, 0.03, 0.02), 0.3)
	await t.finished
	# încărcătorul gol cade din cadru
	Sunet.reda(SUNET_SCOS, Sunet.VOLUM_EFECTE - 2.0, 0.05)
	if _inc:
		t = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(_inc, "position", _inc_repaus.origin + Vector3(0.0, -0.35, 0.05), 0.3)
		t.parallel().tween_property(_inc, "rotation", Vector3(0.6, 0.0, 0.3), 0.3)
		await t.finished
		_inc.hide()
		await get_tree().create_timer(0.3).timeout
		# cel nou vine de jos și intră la loc
		_inc.transform = _inc_repaus
		_inc.position += Vector3(0.0, -0.3, 0.08)
		_inc.show()
		t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		t.tween_property(_inc, "position", _inc_repaus.origin + Vector3(0, -0.02, 0.0), 0.3)
		await t.finished
		t = create_tween()
		t.tween_property(_inc, "position", _inc_repaus.origin, 0.06)
		t.parallel().tween_property(self, "anim_poz", anim_poz + Vector3(0, 0.02, 0), 0.06)
		Sunet.reda(SUNET_PUS, Sunet.VOLUM_EFECTE - 1.0, 0.05)
		await t.finished
	# tragi de manetă: arma se întoarce cu maneta spre tine
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "anim_rot", Vector3(0.15, 0.3, -0.35), 0.22)
	t.parallel().tween_property(self, "anim_poz", Vector3(-0.03, 0.02, 0.0), 0.22)
	await t.finished
	Sunet.reda(SUNET_ARMAT, Sunet.VOLUM_EFECTE - 1.0, 0.05)
	if _manivela:
		t = create_tween()
		t.tween_property(_manivela, "position", _manivela_repaus + Vector3(0, 0, 0.09), 0.1)
		t.tween_property(_manivela, "position", _manivela_repaus, 0.05)
		await t.finished
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "anim_rot", Vector3.ZERO, 0.25)
	t.parallel().tween_property(self, "anim_poz", Vector3.ZERO, 0.25)
	await t.finished
	_gloante = incarcator
	ocupata = false
