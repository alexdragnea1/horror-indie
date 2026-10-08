class_name MingeFoc
extends Node3D
## O minge de foc (vraja Fireball, de la Helga): un miez alb-galben într-un halou portocaliu, cu o dâră de flăcări care se
## face fum, o lumină caldă care merge cu ea și un vuiet. Zboară drept; unde lovește explodează (flăcări, scântei, fum,
## un fulger de lumină, o bubuitură). Ce lovește primește `impuscat(directie, punct)`, ca de la un glonț (Pistol): aceleași
## reguli (bețivul, vrăjitoarele din cerc), manechinul se clatină, boombox-ul se strică; un cadavru e împins. Cine are
## `lovit_de_foc(directie, punct)` primește asta în loc de `impuscat` (pisica: arde).
##   var m := MingeFoc.creeaza(self, 0.6)      # ținută în palmă (nu zboară), crește cu `marime_vizibila`
##   m.lanseaza(directie, [jucator.get_rid()])  # pleacă
##   MingeFoc.arunca(self, de_la, directie, 0.6, [rid])  # direct
## `marime`: 1 = a lui Helga; a ta e mai mică (VrajaFoc.MARIME).

signal explodat(punct: Vector3)

const SUNET_ZBOR := preload("res://sunete/minge_foc_zbor.ogg")
const SUNET_BUM := preload("res://sunete/minge_foc_bum.ogg")
## Culorile focului (din paletă, luminate): miezul, flacăra, marginea, fumul.
const MIEZ := Color(1.0, 0.92, 0.7)
const FLACARA := Color(1.0, 0.62, 0.3)
const MARGINE := Color(0.85, 0.3, 0.16)
const FUM := Color(0.37, 0.33, 0.34)

var marime := 1.0
var viteza := 14.0
var bataie := 60.0
## Cât de mare se vede acum (0..1): în palmă crește, la lansare e 1.
var marime_vizibila := 1.0
var directie := Vector3.FORWARD
var exclude: Array[RID] = []

var _zboara := false
var _gata := false
var _parcurs := 0.0
var _timp := 0.0
var _miez: MeshInstance3D
var _halou: MeshInstance3D
var _lumina: OmniLight3D
var _dara: CPUParticles3D
var _sunet: AudioStreamPlayer3D


static func creeaza(parinte: Node, marime_ := 1.0) -> MingeFoc:
	var m := MingeFoc.new()
	m.marime = marime_
	parinte.add_child(m)
	return m


static func arunca(nod: Node, de_la: Vector3, directie_: Vector3, marime_ := 1.0, exclude_: Array[RID] = []) -> MingeFoc:
	var m := creeaza(nod.get_tree().current_scene, marime_)
	m.global_position = de_la
	m.lanseaza(directie_, exclude_)
	return m


func _ready() -> void:
	_miez = _sfera(0.075 * marime, MIEZ, false)
	_halou = _sfera(0.15 * marime, Color(FLACARA, 0.55), true)
	_lumina = OmniLight3D.new()
	_lumina.light_color = FLACARA
	_lumina.omni_range = 4.5 * marime
	_lumina.omni_attenuation = 1.3
	_lumina.light_volumetric_fog_energy = 2.0
	add_child(_lumina)
	_dara = _particule(36, 0.42, 0.07 * marime)
	_dara.gravity = Vector3(0, 0.8, 0)
	_dara.initial_velocity_min = 0.05
	_dara.initial_velocity_max = 0.35
	_dara.spread = 180.0
	add_child(_dara)
	_dara.emitting = true
	_sunet = AudioStreamPlayer3D.new()
	_sunet.stream = SUNET_ZBOR
	_sunet.bus = &"Efecte"
	_sunet.volume_db = Sunet.VOLUM_EFECTE - 8.0 + marime * 4.0
	_sunet.unit_size = 2.0
	_sunet.pitch_scale = 1.25 - marime * 0.25
	add_child(_sunet)
	_sunet.play()
	_actualizeaza(0.0)


func _sfera(raza: float, culoare: Color, aditiv: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = raza
	s.height = raza * 2.0
	s.radial_segments = 8
	s.rings = 5
	mi.mesh = s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = culoare
	mat.disable_fog = true
	if aditiv:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Particule de foc (pătrățele care se întorc spre cameră): galben → portocaliu → roșu → fum care se stinge.
func _particule(cate: int, viata: float, marime_bucata: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * marime_bucata * 1.2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.disable_fog = true
	quad.material = mat
	p.mesh = quad
	p.amount = cate
	p.lifetime = viata
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.06 * marime
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	gradient.colors = PackedColorArray([Color(MIEZ, 0.9), Color(FLACARA, 0.75), Color(MARGINE, 0.5), Color(FUM, 0.0)])
	p.color_ramp = gradient
	var curba := Curve.new()
	curba.add_point(Vector2(0.0, 1.0))
	curba.add_point(Vector2(1.0, 0.35))
	p.scale_amount_curve = curba
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Pornește: zboară pe `directie_` (dacă era în palmă, se desprinde de ea).
func lanseaza(directie_: Vector3, exclude_: Array[RID] = []) -> void:
	directie = directie_.normalized()
	exclude = exclude_
	marime_vizibila = 1.0
	var poz := global_position
	if get_parent() != get_tree().current_scene:
		reparent(get_tree().current_scene)
		global_position = poz
	_zboara = true


func _process(delta: float) -> void:
	_timp += delta
	_actualizeaza(delta)


## Pâlpâie: miezul și haloul își schimbă puțin mărimea, lumina tremură.
func _actualizeaza(_delta: float) -> void:
	if _gata:
		return
	var k := marime_vizibila
	var tremur := 1.0 + sin(_timp * 31.0) * 0.08 + sin(_timp * 17.0 + 1.3) * 0.06
	_miez.scale = Vector3.ONE * k * tremur
	_halou.scale = Vector3.ONE * k * (1.0 + sin(_timp * 23.0 + 0.7) * 0.12)
	_halou.rotation = Vector3(_timp * 3.0, _timp * 5.0, 0.0)
	_lumina.light_energy = (1.6 + 0.4 * sin(_timp * 19.0)) * marime * k
	_dara.emitting = k > 0.25
	_sunet.volume_db = Sunet.VOLUM_EFECTE - 8.0 + marime * 4.0 + linear_to_db(maxf(k, 0.05))


func _physics_process(delta: float) -> void:
	if not _zboara or _gata:
		return
	var pas := viteza * delta
	var de_la := global_position
	var la := de_la + directie * pas
	var cerere := PhysicsRayQueryParameters3D.create(de_la, la, 1 | Ragdoll.STRAT)
	cerere.exclude = exclude
	var lovit := get_world_3d().direct_space_state.intersect_ray(cerere)
	if not lovit.is_empty():
		_explodeaza(lovit.position, lovit.normal, lovit.collider)
		return
	global_position = la
	_parcurs += pas
	if _parcurs > bataie:
		_explodeaza(global_position, -directie, null)


func _explodeaza(punct: Vector3, normala: Vector3, tinta: Object) -> void:
	_gata = true
	global_position = punct + normala * 0.05
	if tinta and tinta.has_method("lovit_de"):
		tinta.lovit_de("vraja_foc", directie, punct)
	elif tinta and tinta.has_method("lovit_de_foc"):
		tinta.lovit_de_foc(directie, punct)
	elif tinta and tinta.has_method("impuscat"):
		tinta.impuscat(directie, punct)
	elif tinta is RigidBody3D:
		var corp := tinta as RigidBody3D
		corp.apply_impulse(directie * 30.0 * marime, punct - corp.global_position)
	Sunet.reda_la(SUNET_BUM, punct, Sunet.VOLUM_EFECTE - (1.0 - marime) * 8.0, 0.08)
	_miez.hide()
	_halou.hide()
	_dara.emitting = false
	_sunet.stop()
	# flăcările care se umflă și se fac fum, scânteile care sar, un fulger de lumină
	var foc := _particule(int(34 * marime) + 8, 0.6, 0.11 * marime)
	var rampa := Gradient.new()
	rampa.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	rampa.colors = PackedColorArray([Color(FLACARA, 0.95), Color(MARGINE, 0.8), Color(FUM, 0.5), Color(FUM, 0.0)])
	foc.color_ramp = rampa
	foc.one_shot = true
	foc.explosiveness = 1.0
	foc.emission_sphere_radius = 0.12 * marime
	foc.spread = 180.0
	foc.direction = normala
	foc.initial_velocity_min = 0.8 * marime
	foc.initial_velocity_max = 2.6 * marime
	foc.damping_min = 2.0
	foc.damping_max = 4.0
	foc.gravity = Vector3(0, 1.2, 0)
	add_child(foc)
	foc.emitting = true
	var scantei := _particule(int(20 * marime) + 6, 0.5, 0.025)
	scantei.one_shot = true
	scantei.explosiveness = 1.0
	scantei.spread = 70.0
	scantei.direction = normala
	scantei.initial_velocity_min = 2.0
	scantei.initial_velocity_max = 5.0 * marime
	scantei.gravity = Vector3(0, -6.0, 0)
	add_child(scantei)
	scantei.emitting = true
	_lumina.light_energy = 6.0 * marime
	_lumina.omni_range = 6.0 * marime
	var t := create_tween()
	t.tween_property(_lumina, "light_energy", 0.0, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	explodat.emit(punct)
	await get_tree().create_timer(1.3).timeout
	queue_free()
