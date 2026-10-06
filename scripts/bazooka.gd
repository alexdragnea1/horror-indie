class_name Bazooka
extends Arma
## Bazooka de la Gun Store ($500), pe umărul drept. Click = racheta (`Racheta`) pleacă din tub cu o flacără în față și
## un nor de foc și fum în spate, tubul îți sare pe umăr și te zgâlțâie; unde lovește: Explozie (cea mare, vezi
## explozie.gd). Apoi reîncarci: tubul coboară, o rachetă nouă intră pe la spate (vârful ei apare iar în gura tubului),
## clic metalic, înapoi pe umăr.

const ID := "bazooka"
const NUME := "Bazooka"
const SUNET_LANSARE := preload("res://sunete/bazooka_lansare.ogg")
const SUNET_INCARCARE := preload("res://sunete/bazooka_incarcare.ogg")
const GURA := Vector3(0, 0, -0.68)
const SPATE := Vector3(0, 0, 0.93)

var _racheta: Node3D
var _racheta_repaus := Vector3.ZERO


func _init() -> void:
	id = ID
	scena = preload("res://models/bazooka.glb")
	pozitie = Vector3(0.21, -0.12, -0.2)
	rotatie = Vector3(0.0, 0.04, 0.0)
	pozitie_jos = Vector3(0.3, -0.6, 0.05)


func _pregateste() -> void:
	_racheta = _piesa("Racheta")
	if _racheta:
		_racheta_repaus = _racheta.position


func _trage() -> void:
	ocupata = true
	Sunet.reda(SUNET_LANSARE, Sunet.VOLUM_EFECTE + 3.0, 0.03)
	_anunta("bazooka")
	var de_la := _model.global_transform * (GURA + Vector3(0, 0, -0.1))
	# racheta zboară spre ce e în mijlocul ecranului (nu paralel cu tubul, care stă în dreapta)
	var tinta := _camera.global_position - _camera.global_basis.z * 200.0
	var cerere := PhysicsRayQueryParameters3D.create(_camera.global_position, tinta, 1 | Ragdoll.STRAT)
	cerere.exclude = [_jucator.get_rid()]
	var lovit := get_world_3d().direct_space_state.intersect_ray(cerere)
	if not lovit.is_empty():
		tinta = lovit.position
	var directie := (tinta - de_la).normalized()
	if (tinta - de_la).length() < 1.0:
		directie = -_camera.global_basis.z
	Racheta.lanseaza(self, de_la, directie, [_jucator.get_rid()])
	if _racheta:
		_racheta.hide()
	_fulger(GURA, 3.0, 0.08)
	_fum_gura(GURA, 3.0)
	_flacara_spate()
	_recul_cap(0.07, randf_range(-0.02, 0.02))
	Zguduire.porneste(_camera, 0.03, 0.45)
	var t := create_tween()
	t.tween_property(self, "anim_poz", Vector3(0.01, 0.03, 0.09), 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "anim_rot", Vector3(0.16, 0.03, 0.05), 0.07).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "anim_poz", Vector3.ZERO, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "anim_rot", Vector3.ZERO, 0.5).set_trans(Tween.TRANS_SINE)
	await t.finished
	await get_tree().create_timer(0.35).timeout
	# reîncărcarea: tubul coboară și se înclină, racheta nouă intră din spate
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "anim_poz", Vector3(-0.04, -0.14, 0.1), 0.35)
	t.parallel().tween_property(self, "anim_rot", Vector3(-0.35, 0.5, 0.25), 0.35)
	await t.finished
	if _racheta:
		_racheta.position = _racheta_repaus + Vector3(0, 0, 0.5)
		_racheta.show()
		t = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(_racheta, "position", _racheta_repaus, 0.45)
		await t.finished
	Sunet.reda(SUNET_INCARCARE, Sunet.VOLUM_EFECTE - 1.0, 0.04)
	t = create_tween()
	t.tween_property(self, "anim_poz", anim_poz + Vector3(0, 0.02, -0.02), 0.06)
	await t.finished
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "anim_poz", Vector3.ZERO, 0.4)
	t.parallel().tween_property(self, "anim_rot", Vector3.ZERO, 0.4)
	await t.finished
	ocupata = false


## Flacăra și norul de fum care ies prin spatele tubului (backblast).
func _flacara_spate() -> void:
	var spate := _model.global_transform * SPATE
	var inapoi := _model.global_basis.z.normalized()
	var foc := _particule(18, 0.35, 0.18, Color(1.0, 0.7, 0.35, 0.9))
	foc.direction = inapoi
	foc.spread = 25.0
	foc.initial_velocity_min = 4.0
	foc.initial_velocity_max = 8.0
	foc.damping_min = 8.0
	foc.damping_max = 12.0
	var fum := _particule(26, 1.6, 0.35, Color(0.62, 0.6, 0.58, 0.55))
	fum.direction = inapoi
	fum.spread = 40.0
	fum.initial_velocity_min = 2.0
	fum.initial_velocity_max = 6.0
	fum.damping_min = 3.0
	fum.damping_max = 5.0
	fum.gravity = Vector3(0, 0.4, 0)
	for p in [foc, fum]:
		get_tree().current_scene.add_child(p)
		p.global_position = spate
		p.emitting = true
		get_tree().create_timer(2.0).timeout.connect(p.queue_free)
