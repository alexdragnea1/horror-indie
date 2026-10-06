class_name Shotgun
extends Arma
## Shotgun-ul cu pompă de la Gun Store ($25). Click = bubuitura: `alice` raze împrăștiate în con (cine are `impuscat`
## îl primește o dată, pereții primesc praf și găuri, cadavrele sunt aruncate), flacăra mare, fumul, reculul care-ți
## aruncă arma și capul în sus. Apoi arma se înclină și tragi de pompă: `Pompa` merge înapoi (sare tubul roșu din
## fereastra de evacuare), apoi înainte; abia după asta poți trage din nou.

const ID := "shotgun"
const NUME := "Shotgun"
const SUNET_FOC := preload("res://sunete/shotgun_foc.ogg")
const SUNET_POMPA := preload("res://sunete/shotgun_pompa.ogg")
## Gura țevii și fereastra de evacuare, în coordonatele modelului.
const GURA := Vector3(0, 0.022, -0.675)
const EVACUARE := Vector3(0.03, 0.014, -0.09)
## Cât merge pompa înapoi.
const CURSA_POMPA := 0.09

@export var alice := 9
@export var imprastiere := 0.075
@export var bataie := 45.0

var _pompa: Node3D
var _pompa_repaus := Vector3.ZERO


func _init() -> void:
	id = ID
	scena = preload("res://models/shotgun.glb")
	pozitie = Vector3(0.17, -0.2, -0.3)
	rotatie = Vector3(0.02, 0.05, 0.0)
	pozitie_jos = Vector3(0.22, -0.65, -0.15)


func _pregateste() -> void:
	_pompa = _piesa("Pompa")
	if _pompa:
		_pompa_repaus = _pompa.position


func _trage() -> void:
	gata = 1.15
	Sunet.reda(SUNET_FOC, Sunet.VOLUM_EFECTE + 2.0, 0.04)
	_fulger(GURA, 2.2, 0.06)
	_fum_gura(GURA, 2.0)
	_anunta("shotgun")
	var deja := []
	for i in alice:
		_glont(_directie(imprastiere), bataie, 18.0, deja)
	_recul_cap(0.09, randf_range(-0.015, 0.015))
	Zguduire.porneste(_camera, 0.012, 0.18)
	# reculul: arma sare înapoi și în sus, revine
	var t := create_tween()
	t.tween_property(self, "anim_poz", Vector3(0.0, 0.03, 0.14), 0.05).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "anim_rot", Vector3(0.45, 0.04, 0.06), 0.05).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "anim_poz", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "anim_rot", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_SINE)
	t.tween_interval(0.05)
	# pompa: arma înclinată spre stânga, pompa trasă înapoi (tubul sare), apoi înainte
	t.tween_property(self, "anim_rot", Vector3(0.12, 0.0, 0.32), 0.12).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(self, "anim_poz", Vector3(-0.02, 0.01, 0.0), 0.12)
	t.tween_callback(Sunet.reda.bind(SUNET_POMPA, Sunet.VOLUM_EFECTE - 1.0, 0.04))
	if _pompa:
		t.tween_property(_pompa, "position", _pompa_repaus + Vector3(0, 0, CURSA_POMPA), 0.1).set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(self, "anim_poz", Vector3(-0.02, 0.0, 0.03), 0.1)
		t.tween_callback(_tub.bind(EVACUARE, Color("7b383a"), 0.06, 0.011))
		t.tween_interval(0.05)
		t.tween_property(_pompa, "position", _pompa_repaus, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(self, "anim_poz", Vector3(-0.02, 0.01, -0.01), 0.09)
	t.tween_property(self, "anim_rot", Vector3.ZERO, 0.16).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(self, "anim_poz", Vector3.ZERO, 0.16)
