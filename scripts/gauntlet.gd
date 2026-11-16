class_name Gauntlet
extends Arma
## Gauntlet-ul (felia portocalie a roții din pivnița lui Jean, owner 16.11): o mănușă de fier pe pumnul drept, cu
## țepi și o rună care arde. Click = un pumn greu: îl tragi înapoi, apoi lovești drept înainte, la mijlocul ecranului.
## Atinge ce e la `bataie` metri: bossii iau `LuptaBoss.damage_gauntlet` (350) pe lovitură (`lovit_de("gauntlet")`),
## restul (oameni, vrăjitoare, obiecte) primesc `impuscat`, ca de la un glonț; cadavrele zboară; în perete sar
## scântei portocalii și se zguduie privirea.

const ID := "gauntlet"
const NUME := "Gauntlet"
## Sunete grave, doar fizice (owner 16.11: „mai deep, nu așa de magie”): rețetele în tools/sunete.sh, secțiunea gauntlet.
const SUNET_FASAIT := preload("res://sunete/gauntlet_aer.ogg")
const SUNET_CARNE := preload("res://sunete/gauntlet_lovit.ogg")
const SUNET_PERETE := preload("res://sunete/gauntlet_perete.ogg")

## Până unde ajunge (metri, din ochi).
@export var bataie := 1.8

var _runa: GeometryInstance3D


func _init() -> void:
	id = ID
	scena = preload("res://models/gauntlet.glb")
	pozitie = Vector3(0.17, -0.15, -0.36)
	rotatie = Vector3(0.18, 0.3, 0.1)
	pozitie_jos = Vector3(0.24, -0.62, -0.2)


func _pregateste() -> void:
	_runa = _model.find_child("Runa", true, false) as GeometryInstance3D


func _actualizeaza(_delta: float) -> void:
	# runa arde și pulsează încet
	if _runa:
		_runa.set_instance_shader_parameter("stralucire", 2.2 + 0.6 * sin(_timp * 3.1))


func _trage() -> void:
	gata = 0.6
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	# înapoi și puțin în jos, apoi drept înainte spre mijlocul ecranului, apoi la loc
	t.tween_property(self, "anim_poz", Vector3(0.03, -0.03, 0.1), 0.1).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "anim_rot", Vector3(0.15, 0.1, -0.1), 0.1)
	t.tween_property(self, "anim_poz", Vector3(-0.15, 0.08, -0.3), 0.07).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "anim_rot", Vector3(-0.05, -0.25, 0.0), 0.07)
	t.tween_callback(_loveste)
	t.tween_interval(0.08)
	t.tween_property(self, "anim_poz", Vector3.ZERO, 0.3).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "anim_rot", Vector3.ZERO, 0.3)
	Sunet.reda(SUNET_FASAIT, Sunet.VOLUM_EFECTE - 2.0, 0.1)


func _loveste() -> void:
	var directie := _directie(0.01)
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
		(tinta as RigidBody3D).apply_impulse(directie * 25.0, lovit.position - (tinta as RigidBody3D).global_position)
		Sunet.reda_la(SUNET_CARNE, lovit.position, Sunet.VOLUM_EFECTE - 3.0, 0.1)
	else:
		Sunet.reda_la(SUNET_PERETE, lovit.position, Sunet.VOLUM_EFECTE - 2.0, 0.1)
		_praf(lovit.position, lovit.normal)
	_scantei(lovit.position, lovit.normal)
	# impactul: privirea se zguduie, pumnul sare puțin înapoi
	_recul_cap(0.025, randf_range(-0.015, 0.015))
	var t := create_tween()
	t.tween_property(self, "anim_poz", anim_poz + Vector3(0.0, 0.01, 0.06), 0.05)


func _scantei(punct: Vector3, normala: Vector3) -> void:
	var p := _particule(14, 0.4, 0.025, Color(1.0, 0.6, 0.25))
	p.direction = normala
	p.spread = 60.0
	p.initial_velocity_min = 1.8
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -8.0, 0)
	get_tree().current_scene.add_child(p)
	p.global_position = punct + normala * 0.02
	p.emitting = true
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)
