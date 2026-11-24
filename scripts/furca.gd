class_name Furca
extends Arma
## Furca rezemată de spatele casei din dreapta primăriei (FurcaJos, furca_jos.gd; owner 24.11). O ții cu ambele mâini,
## în dreapta-jos, cu dinții spre mijlocul ecranului. Click = un împuns cu avânt: o tragi puțin înapoi, apoi te
## arunci înainte (`Jucator.avant`, `viteza_avant` m/s timp de `durata_avant` s) și împungi. Cât ține avântul, ce
## ajunge în dinți (`bataie` metri din ochi, trei raze pe lățimea furcii) e lovit o dată: bossii iau
## `LuptaBoss.damage_furca` (100, `lovit_de("furca")`), restul primesc `impuscat`, ca de la un glonț; avântul se
## oprește în ce ai lovit (și în pereți, unde sar scântei).

const ID := "furca"
const NUME := "Pitchfork"
const SUNET_FASAIT := preload("res://sunete/gauntlet_aer.ogg")
const SUNET_CARNE := preload("res://sunete/cutit_carne.ogg")
const SUNET_PERETE := preload("res://sunete/gauntlet_perete.ogg")

## Până unde ajung dinții (metri, din ochi).
@export var bataie := 2.3
## Cât de lată e furca (radiani, de o parte și de alta a privirii).
@export var latime := 0.1
## Avântul: viteza (m/s) și cât ține (s); 11 × 0,22 ≈ 2,4 m.
@export var viteza_avant := 11.0
@export var durata_avant := 0.22

var _impunge := 0.0
var _lovit_deja := false


func _init() -> void:
	id = ID
	scena = preload("res://models/furca.glb")
	# coada trece pe lângă cameră din dreapta-jos (capătul ei rămâne în spatele ochilor), capul furcii e la ~1,1 m în față
	pozitie = Vector3(0.22, -0.3, 0.05)
	rotatie = Vector3(0.24, 0.17, 0.12)
	pozitie_jos = Vector3(0.26, -0.85, 0.05)


func _trage() -> void:
	gata = 0.8
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	# trasă înapoi și puțin în sus (iei elan), apoi împunsă drept înainte, spre mijlocul ecranului, apoi la loc
	t.tween_property(self, "anim_poz", Vector3(0.04, 0.03, 0.18), 0.12).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "anim_rot", Vector3(0.08, 0.05, 0.0), 0.12)
	t.tween_callback(_porneste_avantul)
	t.tween_property(self, "anim_poz", Vector3(-0.12, 0.05, -0.38), 0.09).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "anim_rot", Vector3(-0.04, -0.1, 0.0), 0.09)
	t.tween_interval(0.12)
	t.tween_property(self, "anim_poz", Vector3.ZERO, 0.32).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "anim_rot", Vector3.ZERO, 0.32)


func _porneste_avantul() -> void:
	var inainte := -_jucator.global_basis.z
	inainte.y = 0.0
	if _jucator.has_method("avant"):
		_jucator.avant(inainte.normalized() * viteza_avant, durata_avant)
	_impunge = durata_avant + 0.05
	_lovit_deja = false
	Sunet.reda(SUNET_FASAIT, Sunet.VOLUM_EFECTE - 1.0, 0.1, &"Efecte", 0.85)


func _actualizeaza(delta: float) -> void:
	if _impunge <= 0.0:
		return
	_impunge -= delta
	if not _lovit_deja:
		_loveste()


## O rază pe mijloc și câte una în fiecare parte (cât sunt dinții de lați); primul lucru atins e lovit și avântul se oprește.
func _loveste() -> void:
	var de_la := _camera.global_position
	var privire := _directie(0.0)
	for unghi: float in [0.0, -latime, latime]:
		var directie := privire.rotated(Vector3.UP, unghi)
		var cerere := PhysicsRayQueryParameters3D.create(de_la, de_la + directie * bataie, 1 | Ragdoll.STRAT)
		cerere.exclude = [_jucator.get_rid()]
		var lovit := get_world_3d().direct_space_state.intersect_ray(cerere)
		if lovit.is_empty():
			continue
		var tinta: Object = lovit.collider
		var punct: Vector3 = lovit.position
		var normala: Vector3 = lovit.normal
		if tinta.has_method("lovit_de"):
			tinta.lovit_de(id, directie, punct)
			Sunet.reda_la(SUNET_CARNE, punct, Sunet.VOLUM_EFECTE, 0.1)
		elif tinta.has_method("impuscat"):
			tinta.impuscat(directie, punct)
			Sunet.reda_la(SUNET_CARNE, punct, Sunet.VOLUM_EFECTE, 0.1)
		elif tinta is RigidBody3D:
			(tinta as RigidBody3D).apply_impulse(directie * 20.0, punct - (tinta as RigidBody3D).global_position)
			Sunet.reda_la(SUNET_CARNE, punct, Sunet.VOLUM_EFECTE - 3.0, 0.1)
		else:
			# doar un perete aproape oprește avântul (unul la capătul bătăii încă nu e în dinți)
			if de_la.distance_to(punct) > bataie * 0.75:
				continue
			Sunet.reda_la(SUNET_PERETE, punct, Sunet.VOLUM_EFECTE - 2.0, 0.1)
			_praf(punct, normala)
			_scantei(punct, normala)
		_lovit_deja = true
		_impunge = 0.0
		if _jucator.has_method("avant"):
			_jucator.avant(Vector3.ZERO, 0.0)
		_recul_cap(0.02, randf_range(-0.01, 0.01))
		var t := create_tween()
		t.tween_property(self, "anim_poz", anim_poz + Vector3(0.0, 0.01, 0.08), 0.06)
		return


func _scantei(punct: Vector3, normala: Vector3) -> void:
	var p := _particule(10, 0.35, 0.02, Color(1.0, 0.75, 0.4))
	p.direction = normala
	p.spread = 55.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -8.0, 0)
	get_tree().current_scene.add_child(p)
	p.global_position = punct + normala * 0.02
	p.emitting = true
	get_tree().create_timer(0.7).timeout.connect(p.queue_free)
