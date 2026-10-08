class_name Racheta
extends Node3D
## Racheta de bazooka în zbor: modelul (racheta.glb), flacăra din duză, o lumină caldă, dâra de fum care rămâne în aer
## și vâjâitul. Pleacă cu `viteza_start` și accelerează până la `viteza_max`; unde lovește ceva (sau după `bataie`
## metri) face Explozie. Ce lovește direct primește mai întâi `impuscat` (sau `lovit_de_foc`), ca la mingea de foc.
##   Racheta.lanseaza(nod, de_la, directie, [jucator.get_rid()])

const MODEL := preload("res://models/racheta.glb")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")
const SUNET_ZBOR := preload("res://sunete/racheta_zbor.ogg")

var directie := Vector3.FORWARD
var exclude: Array[RID] = []
var viteza_start := 22.0
var viteza_max := 70.0
var acceleratie := 90.0
var bataie := 150.0

var _viteza := 0.0
var _parcurs := 0.0
var _gata := false
var _dara: CPUParticles3D
var _flacara: MeshInstance3D
var _lumina: OmniLight3D
var _sunet: AudioStreamPlayer3D
var _timp := 0.0


static func lanseaza(nod: Node, de_la: Vector3, directie_: Vector3, exclude_: Array[RID] = []) -> Racheta:
	var r := Racheta.new()
	r.directie = directie_.normalized()
	r.exclude = exclude_
	nod.get_tree().current_scene.add_child(r)
	r.global_position = de_la
	var sus := Vector3.UP if absf(r.directie.y) < 0.95 else Vector3.FORWARD
	r.look_at(de_la + r.directie, sus)
	return r


func _ready() -> void:
	_viteza = viteza_start
	var m := MODEL.instantiate() as Node3D
	m.set_script(SCRIPT_MODEL)
	m.set("material", MATERIAL)
	add_child(m)
	# flacăra din duză (în spate, +Z), alb-galbenă, care pâlpâie
	_flacara = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.05
	s.height = 0.22
	s.radial_segments = 6
	s.rings = 3
	_flacara.mesh = s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.5)
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_fog = true
	_flacara.material_override = mat
	_flacara.rotation.x = PI / 2.0
	_flacara.position = Vector3(0, 0, 0.3)
	_flacara.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flacara)
	_lumina = OmniLight3D.new()
	_lumina.light_color = Color(1.0, 0.7, 0.4)
	_lumina.light_energy = 2.5
	_lumina.omni_range = 6.0
	_lumina.light_volumetric_fog_energy = 1.5
	_lumina.position = Vector3(0, 0, 0.35)
	add_child(_lumina)
	# dâra de fum: rămâne în lume, cu foc la început
	_dara = CPUParticles3D.new()
	_dara.emitting = false
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.22)
	quad.material = Arma.material_particule(false)
	_dara.mesh = quad
	_dara.amount = 90
	_dara.lifetime = 2.2
	_dara.local_coords = false
	_dara.direction = Vector3(0, 0, 1)
	_dara.spread = 12.0
	_dara.initial_velocity_min = 0.3
	_dara.initial_velocity_max = 1.0
	_dara.damping_min = 1.0
	_dara.damping_max = 2.0
	_dara.gravity = Vector3(0, 0.3, 0)
	var curba := Curve.new()
	curba.add_point(Vector2(0.0, 0.5))
	curba.add_point(Vector2(1.0, 3.0))
	_dara.scale_amount_curve = curba
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.08, 0.25, 1.0])
	gradient.colors = PackedColorArray([Color(1.0, 0.8, 0.45, 0.9), Color(0.9, 0.5, 0.3, 0.7), Color(0.62, 0.6, 0.6, 0.55),
		Color(0.62, 0.6, 0.6, 0.0)])
	_dara.color_ramp = gradient
	_dara.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dara.position = Vector3(0, 0, 0.28)
	add_child(_dara)
	_dara.emitting = true
	_sunet = AudioStreamPlayer3D.new()
	_sunet.stream = SUNET_ZBOR
	_sunet.bus = &"Efecte"
	_sunet.volume_db = Sunet.VOLUM_EFECTE + 2.0
	_sunet.unit_size = 4.0
	add_child(_sunet)
	_sunet.play()


func _process(delta: float) -> void:
	_timp += delta
	if not _gata:
		_flacara.scale = Vector3.ONE * (1.0 + sin(_timp * 47.0) * 0.25 + randf() * 0.2)
		_lumina.light_energy = 2.2 + randf() * 0.8


func _physics_process(delta: float) -> void:
	if _gata:
		return
	_viteza = minf(_viteza + acceleratie * delta, viteza_max)
	var pas := _viteza * delta
	var de_la := global_position
	var la := de_la + directie * pas
	var cerere := PhysicsRayQueryParameters3D.create(de_la, la, 1 | Ragdoll.STRAT)
	cerere.exclude = exclude
	var lovit := get_world_3d().direct_space_state.intersect_ray(cerere)
	if not lovit.is_empty():
		_explodeaza(lovit.position, lovit.normal, lovit.collider)
		return
	global_position = la
	rotate_object_local(Vector3.FORWARD, delta * 9.0)  # se rotește în jurul axei (aripioarele)
	_parcurs += pas
	if _parcurs > bataie:
		_explodeaza(global_position, -directie, null)


func _explodeaza(punct: Vector3, normala: Vector3, tinta: Object) -> void:
	_gata = true
	if tinta and tinta.has_method("lovit_de"):
		tinta.lovit_de("bazooka", directie, punct)  # Warlock-ul (explozia îl sare: e în `deja`)
	elif tinta and tinta.has_method("lovit_de_foc"):
		tinta.lovit_de_foc(directie, punct)
	elif tinta and tinta.has_method("impuscat"):
		tinta.impuscat(directie, punct)
	Explozie.creeaza(self, punct, normala, 1.4, [tinta] if tinta else [])
	# dâra rămâne în aer și se stinge; racheta dispare
	var poz := _dara.global_position
	_dara.reparent(get_tree().current_scene)
	_dara.global_position = poz
	_dara.emitting = false
	get_tree().create_timer(_dara.lifetime + 0.2).timeout.connect(_dara.queue_free)
	queue_free()
