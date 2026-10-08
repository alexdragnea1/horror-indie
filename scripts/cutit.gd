class_name Cutit
extends Arma
## Cuțitul de la Gun Store ($5). Click = lovești, pe rând: o înjunghiere (îl tragi puțin înapoi și îl împingi drept
## înainte) și o tăietură în diagonală (din dreapta-sus spre stânga-jos). Atinge doar ce e la `bataie` metri: cine are
## `impuscat` îl primește (aceleași reguli ca la pistol), în perete sar scântei și se aude oțelul, în gol doar fâșâitul.

const ID := "cutit"
const NUME := "Knife"
const SUNET_FASAIT := preload("res://sunete/cutit_fasait.ogg")
const SUNET_CARNE := preload("res://sunete/cutit_carne.ogg")
const SUNET_PERETE := preload("res://sunete/cutit_perete.ogg")

## Până unde ajunge (metri, din ochi).
@export var bataie := 1.9

var _care := 0


func _init() -> void:
	id = ID
	scena = preload("res://models/cutit.glb")
	pozitie = Vector3(0.2, -0.2, -0.33)
	rotatie = Vector3(0.35, 0.3, -0.5)
	pozitie_jos = Vector3(0.24, -0.6, -0.22)


func _trage() -> void:
	gata = 0.5
	_care = 1 - _care
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	if _care == 1:
		# înjunghierea: înapoi, apoi drept înainte (lama spre mijlocul ecranului), apoi la loc
		t.tween_property(self, "anim_poz", Vector3(0.02, -0.02, 0.07), 0.09).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(self, "anim_rot", Vector3(-0.15, 0.0, 0.2), 0.09)
		t.tween_property(self, "anim_poz", Vector3(-0.07, 0.05, -0.14), 0.08).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(self, "anim_rot", Vector3(-0.3, -0.25, 0.5), 0.08)
		t.tween_callback(_loveste)
		t.tween_interval(0.06)
		t.tween_property(self, "anim_poz", Vector3.ZERO, 0.25).set_ease(Tween.EASE_IN_OUT)
		t.parallel().tween_property(self, "anim_rot", Vector3.ZERO, 0.25)
	else:
		# tăietura: ridicat în dreapta-sus, tras în diagonală până în stânga-jos, înapoi
		t.tween_property(self, "anim_poz", Vector3(0.05, 0.12, 0.02), 0.1).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(self, "anim_rot", Vector3(0.5, 0.2, -0.9), 0.1)
		t.tween_property(self, "anim_poz", Vector3(-0.3, -0.1, -0.12), 0.11).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(self, "anim_rot", Vector3(-0.4, 0.9, 0.9), 0.11)
		t.parallel().tween_callback(_loveste).set_delay(0.06)
		t.tween_interval(0.05)
		t.tween_property(self, "anim_poz", Vector3.ZERO, 0.28).set_ease(Tween.EASE_IN_OUT)
		t.parallel().tween_property(self, "anim_rot", Vector3.ZERO, 0.28)
	Sunet.reda(SUNET_FASAIT, Sunet.VOLUM_EFECTE - 3.0, 0.12)


func _loveste() -> void:
	var directie := _directie(0.02)
	var de_la := _camera.global_position
	var cerere := PhysicsRayQueryParameters3D.create(de_la, de_la + directie * bataie, 1 | Ragdoll.STRAT)
	cerere.exclude = [_jucator.get_rid()]
	var lovit := get_world_3d().direct_space_state.intersect_ray(cerere)
	if lovit.is_empty():
		return
	var tinta: Object = lovit.collider
	if tinta.has_method("lovit_de"):
		tinta.lovit_de(id, directie, lovit.position)
		Sunet.reda_la(SUNET_CARNE, lovit.position, Sunet.VOLUM_EFECTE, 0.1)
	elif tinta.has_method("impuscat"):
		tinta.impuscat(directie, lovit.position)
		Sunet.reda_la(SUNET_CARNE, lovit.position, Sunet.VOLUM_EFECTE, 0.1)
	elif tinta is RigidBody3D:
		(tinta as RigidBody3D).apply_impulse(directie * 8.0, lovit.position - (tinta as RigidBody3D).global_position)
		Sunet.reda_la(SUNET_CARNE, lovit.position, Sunet.VOLUM_EFECTE - 4.0, 0.1)
	else:
		Sunet.reda_la(SUNET_PERETE, lovit.position, Sunet.VOLUM_EFECTE - 3.0, 0.1)
		_scantei(lovit.position, lovit.normal)
	# un mic tremur în mână la impact
	var t := create_tween()
	t.tween_property(self, "anim_poz", anim_poz + Vector3(0.0, 0.0, 0.03), 0.04)


func _scantei(punct: Vector3, normala: Vector3) -> void:
	var p := _particule(8, 0.35, 0.02, Color(1.0, 0.85, 0.5))
	p.direction = normala
	p.spread = 50.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -8.0, 0)
	get_tree().current_scene.add_child(p)
	p.global_position = punct + normala * 0.02
	p.emitting = true
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)
