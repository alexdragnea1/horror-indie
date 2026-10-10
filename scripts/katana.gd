class_name Katana
extends Arma
## Katana găsită în parcarea barului „URBAN”, în colțul din spatele tomberonului (KatanaJos, owner 10.10). O ții în
## dreapta-jos, cu lama în sus, aplecată spre mijlocul ecranului. Click = o tăietură mare, pe rând: în diagonală (din
## dreapta-sus spre stânga-jos), apoi în lateral (din stânga spre dreapta). Ajunge mai departe decât cuțitul (`bataie`)
## și prinde și ce e puțin în lateral (trei raze pe lățimea tăieturii): cine are `impuscat` îl primește (aceleași reguli
## ca la pistol), în perete sar scântei.

const ID := "katana"
const NUME := "Katana"
const SUNET_FASAIT := preload("res://sunete/cutit_fasait.ogg")
const SUNET_CARNE := preload("res://sunete/cutit_carne.ogg")
const SUNET_PERETE := preload("res://sunete/cutit_perete.ogg")

## Până unde ajunge (metri, din ochi).
@export var bataie := 2.5
## Cât de lată e tăietura (radiani, de o parte și de alta a privirii).
@export var latime := 0.16

var _care := 0


func _init() -> void:
	id = ID
	scena = preload("res://models/katana.glb")
	pozitie = Vector3(0.26, -0.3, -0.42)
	rotatie = Vector3(1.0, 0.42, 0.25)
	pozitie_jos = Vector3(0.3, -0.75, -0.3)


func _trage() -> void:
	gata = 0.6
	_care = 1 - _care
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	if _care == 1:
		# în diagonală: ridicată peste umărul drept, trasă până în stânga-jos, înapoi
		t.tween_property(self, "anim_poz", Vector3(0.06, 0.12, 0.06), 0.13).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(self, "anim_rot", Vector3(0.25, -0.5, -0.5), 0.13)
		t.tween_property(self, "anim_poz", Vector3(-0.36, -0.14, -0.12), 0.12).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(self, "anim_rot", Vector3(-1.3, 1.0, 0.9), 0.12)
		t.parallel().tween_callback(_loveste).set_delay(0.06)
		t.tween_interval(0.06)
		t.tween_property(self, "anim_poz", Vector3.ZERO, 0.32).set_ease(Tween.EASE_IN_OUT)
		t.parallel().tween_property(self, "anim_rot", Vector3.ZERO, 0.32)
	else:
		# în lateral: dusă în stânga, culcată, apoi trasă orizontal spre dreapta
		t.tween_property(self, "anim_poz", Vector3(-0.3, 0.08, 0.04), 0.14).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(self, "anim_rot", Vector3(-0.75, 0.9, 1.2), 0.14)
		t.tween_property(self, "anim_poz", Vector3(0.18, 0.02, -0.14), 0.12).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(self, "anim_rot", Vector3(-0.85, -0.7, 1.3), 0.12)
		t.parallel().tween_callback(_loveste).set_delay(0.06)
		t.tween_interval(0.06)
		t.tween_property(self, "anim_poz", Vector3.ZERO, 0.32).set_ease(Tween.EASE_IN_OUT)
		t.parallel().tween_property(self, "anim_rot", Vector3.ZERO, 0.32)
	Sunet.reda(SUNET_FASAIT, Sunet.VOLUM_EFECTE - 2.0, 0.12, &"Efecte", 0.8)  # (mai grav: lamă lungă)


func _loveste() -> void:
	var de_la := _camera.global_position
	var privire := _directie(0.0)
	var lovit_perete := {}
	var deja: Array = []
	var a_taiat := false
	for unghi: float in [0.0, -latime, latime]:
		var directie := privire.rotated(Vector3.UP, unghi)
		var cerere := PhysicsRayQueryParameters3D.create(de_la, de_la + directie * bataie, 1 | Ragdoll.STRAT)
		cerere.exclude = [_jucator.get_rid()]
		var lovit := get_world_3d().direct_space_state.intersect_ray(cerere)
		if lovit.is_empty():
			continue
		var tinta: Object = lovit.collider
		if tinta in deja:
			continue
		deja.append(tinta)
		if tinta.has_method("lovit_de"):
			tinta.lovit_de(id, directie, lovit.position)
			a_taiat = true
		elif tinta.has_method("impuscat"):
			tinta.impuscat(directie, lovit.position)
			a_taiat = true
		elif tinta is RigidBody3D:
			(tinta as RigidBody3D).apply_impulse(directie * 10.0, lovit.position - (tinta as RigidBody3D).global_position)
			a_taiat = true
		elif lovit_perete.is_empty():
			lovit_perete = lovit
		if a_taiat:
			Sunet.reda_la(SUNET_CARNE, lovit.position, Sunet.VOLUM_EFECTE, 0.1)
			break
	if not a_taiat and not lovit_perete.is_empty():
		Sunet.reda_la(SUNET_PERETE, lovit_perete.position, Sunet.VOLUM_EFECTE - 3.0, 0.1)
		_scantei(lovit_perete.position, lovit_perete.normal)
	# un mic recul în mână la impact
	if a_taiat or not lovit_perete.is_empty():
		var t := create_tween()
		t.tween_property(self, "anim_poz", anim_poz + Vector3(0.0, 0.0, 0.04), 0.04)


func _scantei(punct: Vector3, normala: Vector3) -> void:
	var p := _particule(10, 0.35, 0.02, Color(1.0, 0.85, 0.5))
	p.direction = normala
	p.spread = 50.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -8.0, 0)
	get_tree().current_scene.add_child(p)
	p.global_position = punct + normala * 0.02
	p.emitting = true
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)
