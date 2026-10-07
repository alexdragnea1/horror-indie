class_name Arma
extends Node3D
## Baza armelor de la Gun Store (Cutit, Shotgun, AK47, Bazooka), ținute la persoana întâi ca pistolul (Pistol): le pune
## jucator.gd sub cameră și se văd doar cât ai `Stare.in_mana` = `id` (le alegi din inventar). Fiecare are animația ei
## de tras în `_trage()` (click stânga, acțiunea "trage"); aici e ce au în comun:
##  - ridicat / lăsat jos (cât e deschis un meniu, o scenă din cod sau ecranul negru), sunetul de scos arma;
##  - balansul: rămâne puțin în urma privirii când întorci capul și se leagănă când mergi;
##  - `anim_poz` / `anim_rot`: cât o mișcă animația acum (reculul, pompa, reîncărcarea), peste poza de repaus;
##  - ajutoare: `_glont()` (o rază ca glonțul pistolului: `impuscat(directie, punct)`, cadavrele împinse, praf și o gaură
##    în perete), `_fulger()` (flacăra de la gura țevii), `_fum_gura()`, `_tub()` (tubul gol care sare), `_recul_cap()`;
##  - `_anunta()`: cei din grupul "aude_impuscaturi" află că s-a tras (deocamdată nu ascultă nimeni).
## Modelul e un .glb din tools/blender/magazin_arme.py (originea în mâner, țeava spre -Z).

const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")
const SUNET_SCOASA := preload("res://sunete/arma_scoasa.ogg")
const SUNET_TUB := preload("res://sunete/tub_cazut.ogg")
## Câte găuri de glonț rămân pe pereți (cele mai vechi dispar).
const MAX_GAURI := 60
## O scenă din cod o poate ține la vedere cât e Stare.meniu_deschis (ex. arma scoasă în fața lui Head Witch, sefa_apus.gd).
static var in_scena := false
static var _gauri: Array[Node3D] = []
static var _textura_cerc: Texture2D


## Un cerc moale (alb în mijloc, transparent spre margini), 16 px, fără netezire (ca la PS2): textura flăcărilor, a
## fumului și a prafului (altfel particulele sunt pătrate).
static func cerc_moale() -> Texture2D:
	if _textura_cerc == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 16
		t.height = 16
		_textura_cerc = t
	return _textura_cerc


## Materialul particulelor: cercul moale, culoarea din particulă, întors spre cameră; `aditiv` = foc (strălucește).
static func material_particule(aditiv: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = cerc_moale()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if aditiv:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.disable_fog = true
	return mat

## Ce id are în inventar și ce model.
var id := ""
var scena: PackedScene
## Unde o ții (față de cameră), cum e întoarsă, unde stă când e lăsată jos.
var pozitie := Vector3(0.18, -0.2, -0.35)
var rotatie := Vector3.ZERO
var pozitie_jos := Vector3(0.2, -0.6, -0.25)
## Cât o mișcă acum animația (se adună peste poza de repaus).
var anim_poz := Vector3.ZERO
var anim_rot := Vector3.ZERO
## Cât timp nu se poate trage (secunde); cât e `ocupata` (reîncărcare) nici atât.
var gata := 0.0
var ocupata := false

var _camera: Camera3D
var _cap: Node3D
var _jucator: CharacterBody3D
var _model: Node3D
var _jos := 1.0
var _timp := 0.0
var _avea := false
var _balans := Vector3.ZERO
var _ultima_privire := Vector2.ZERO
var _pas := 0.0
var _lumina: OmniLight3D
var _flacara: Node3D


func _ready() -> void:
	_camera = get_parent() as Camera3D
	_cap = _camera.get_parent() as Node3D
	_jucator = _cap.get_parent() as CharacterBody3D
	_model = scena.instantiate()
	_model.set_script(SCRIPT_MODEL)
	_model.set("material", MATERIAL)
	_model.set("umbre", false)
	add_child(_model)
	_lumina = OmniLight3D.new()
	_lumina.light_color = Color(1.0, 0.75, 0.45)
	_lumina.light_energy = 0.0
	_lumina.omni_range = 7.0
	_lumina.light_volumetric_fog_energy = 0.0
	_model.add_child(_lumina)
	_pregateste()
	visible = false


## Pentru clasele copil: piesele modelului (pompa, încărcătorul), flacăra etc.
func _pregateste() -> void:
	pass


## Pentru clasele copil: în fiecare cadru, înainte să se pună poza (ex. AK-47 trage cât ții apăsat).
func _actualizeaza(_delta: float) -> void:
	pass


## Pentru clasele copil: animația de tras.
func _trage() -> void:
	pass


func _process(delta: float) -> void:
	_timp += delta
	var are := Stare.in_mana == id
	var jos := not are or (Stare.meniu_deschis and not in_scena) or Tranzitie.activa
	if are and not _avea:
		Sunet.reda(SUNET_SCOASA, Sunet.VOLUM_EFECTE - 4.0, 0.05)
	_avea = are
	_jos = move_toward(_jos, 1.0 if jos else 0.0, delta * 3.2)
	visible = are and _jos < 0.99
	gata = maxf(gata - delta, 0.0)
	_actualizeaza(delta)
	# balansul: rămâne în urma privirii (cât te-ai întors în cadrul ăsta) și se leagănă la mers
	var privire := Vector2(_jucator.rotation.y, _cap.rotation.x)
	var dif := privire - _ultima_privire
	_ultima_privire = privire
	var tinta := Vector3(clampf(dif.x * 1.2, -0.05, 0.05), clampf(-dif.y * 1.2, -0.04, 0.04), 0.0)
	_balans = _balans.lerp(tinta, clampf(delta * 8.0, 0.0, 1.0))
	var viteza := Vector2(_jucator.velocity.x, _jucator.velocity.z).length()
	_pas += delta * viteza * 2.6
	var mers := Vector3(sin(_pas) * 0.006, -absf(cos(_pas)) * 0.008, 0.0) * clampf(viteza / 2.5, 0.0, 1.5)
	var respiratie := Vector3(sin(_timp * 1.3) * 0.002, sin(_timp * 2.1) * 0.003, 0.0)
	var k := ease(_jos, 2.0)
	position = pozitie.lerp(pozitie_jos, k) + respiratie + mers + _balans + anim_poz
	rotation = rotatie + anim_rot + Vector3(-k * 0.7, _balans.x * 2.0, _balans.x * 3.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("trage") and poate_trage():
		_trage()


func poate_trage() -> bool:
	return visible and _jos < 0.05 and gata <= 0.0 and not ocupata and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
		and not Dialog.activ and not Stare.meniu_deschis and not Tranzitie.activa and not get_tree().paused


## O piesă a modelului (Pompa, Incarcator, Manivela, Racheta).
func _piesa(nume: String) -> Node3D:
	return _model.find_child(nume, true, false) as Node3D


# ---------------------------------------------------------------- ajutoare pentru tras

## Un glonț pe `directie` (din ochi): cine are `impuscat` îl primește (o singură dată pe foc: `deja`), un cadavru e
## împins, iar în rest rămâne praf și o gaură. Întoarce ce a lovit (gol = nimic).
func _glont(directie: Vector3, bataie: float, impuls: float, deja: Array = []) -> Dictionary:
	var de_la := _camera.global_position
	var cerere := PhysicsRayQueryParameters3D.create(de_la, de_la + directie * bataie, 1 | Ragdoll.STRAT)
	cerere.exclude = [_jucator.get_rid()]
	var lovit := get_world_3d().direct_space_state.intersect_ray(cerere)
	if lovit.is_empty():
		return lovit
	var tinta: Object = lovit.collider
	if tinta.has_method("impuscat"):
		if not tinta in deja:
			deja.append(tinta)
			tinta.impuscat(directie, lovit.position)
	elif tinta is RigidBody3D:
		(tinta as RigidBody3D).apply_impulse(directie * impuls, lovit.position - (tinta as RigidBody3D).global_position)
	else:
		_praf(lovit.position, lovit.normal)
		_gaura(lovit.position, lovit.normal)
	return lovit


## Direcția privirii, împrăștiată la întâmplare într-un con de `unghi` radiani.
func _directie(unghi: float) -> Vector3:
	var b := _camera.global_basis
	var r := sqrt(randf()) * unghi
	var u := randf() * TAU
	return (-b.z + b.x * tan(r) * cos(u) + b.y * tan(r) * sin(u)).normalized()


## Flacăra de la gura țevii (`gura`, în coordonatele modelului): o stea de foc (două plăci în cruce și un miez), lumina.
func _fulger(gura: Vector3, marime := 1.0, durata := 0.05) -> void:
	if _flacara == null:
		_flacara = Node3D.new()
		_model.add_child(_flacara)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.8, 0.4)
		mat.albedo_texture = cerc_moale()
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.disable_fog = true
		for i in 2:  # flacăra lungă, în lungul țevii, în cruce
			var q := MeshInstance3D.new()
			var m := QuadMesh.new()
			m.size = Vector2(0.07, 0.16)
			q.mesh = m
			q.material_override = mat
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			q.rotation = Vector3(-PI / 2.0, 0.0, 0.0) if i == 0 else Vector3(-PI / 2.0, PI / 2.0, 0.0)
			q.position = Vector3(0, 0, -0.07)
			_flacara.add_child(q)
		var miez := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.04
		s.height = 0.06
		s.radial_segments = 6
		s.rings = 3
		miez.mesh = s
		var mat_miez := mat.duplicate() as StandardMaterial3D
		mat_miez.albedo_texture = null
		mat_miez.albedo_color = Color(1.0, 0.85, 0.55, 0.85)
		miez.material_override = mat_miez
		miez.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flacara.add_child(miez)
	_flacara.position = gura
	_flacara.rotation.z = randf() * TAU
	_flacara.scale = Vector3.ONE * marime * randf_range(0.8, 1.25)
	_flacara.show()
	_lumina.position = gura
	_lumina.light_energy = 3.0 * marime
	await get_tree().create_timer(durata).timeout
	_flacara.hide()
	var t := create_tween()
	t.tween_property(_lumina, "light_energy", 0.0, 0.09)


## Un nor mic de fum din gura țevii (rămâne în lume, nu merge cu tine).
func _fum_gura(gura: Vector3, cat := 1.0) -> void:
	var p := _particule(int(8 * cat) + 3, 0.9, 0.05 * cat, Color(0.6, 0.58, 0.56, 0.35))
	p.direction = -_camera.global_basis.z
	p.spread = 25.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.0 * cat
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.gravity = Vector3(0, 0.35, 0)
	get_tree().current_scene.add_child(p)
	p.global_position = _model.global_transform * gura
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


## Tubul gol care sare din fereastra de evacuare (`unde`, în coordonatele modelului) spre dreapta-sus și cade.
func _tub(unde: Vector3, culoare: Color, lung := 0.025, raza := 0.006) -> void:
	var tub := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = raza
	m.bottom_radius = raza
	m.height = lung
	m.radial_segments = 6
	m.rings = 1
	tub.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = culoare
	mat.emission_enabled = true
	mat.emission = culoare * 0.35  # se vede și în umbră
	tub.material_override = mat
	tub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(tub)
	var p0 := _model.global_transform * unde
	var b := _camera.global_basis
	var v := b.x * randf_range(1.6, 2.4) + b.y * randf_range(1.2, 2.0) + b.z * randf_range(0.0, 0.6) + _jucator.velocity
	var rot := Vector3(randf_range(-20, 20), randf_range(-20, 20), randf_range(-20, 20))
	tub.global_position = p0
	var zbor := func(s: float) -> void:
		if is_instance_valid(tub):
			tub.global_position = p0 + v * s + Vector3.DOWN * 4.9 * s * s
			tub.rotation = rot * s
	var cade := func() -> void:
		if is_instance_valid(tub):
			Sunet.reda_la(SUNET_TUB, tub.global_position, Sunet.VOLUM_EFECTE - 14.0, 0.15)
			tub.queue_free()
	var t := get_tree().create_tween()
	t.tween_method(zbor, 0.0, 0.7, 0.7)
	t.tween_callback(cade)


## Capul sare în sus (și puțin într-o parte) de la recul.
func _recul_cap(sus: float, lateral := 0.0) -> void:
	_cap.rotation.x = clampf(_cap.rotation.x + sus, deg_to_rad(-85), deg_to_rad(85))
	_jucator.rotate_y(lateral)


## Le spune celor din jur (grupul "aude_impuscaturi") că ai tras de aici.
func _anunta(arma: String) -> void:
	get_tree().call_group("aude_impuscaturi", "a_auzit_impuscatura", _camera.global_position, arma)


## Praf (și câteva scântei) unde a lovit glonțul.
func _praf(punct: Vector3, normala: Vector3) -> void:
	var p := _particule(10, 0.7, 0.05, Color("5e5356"))
	p.direction = normala
	p.spread = 60.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.8
	p.gravity = Vector3(0, -2.0, 0)
	get_tree().current_scene.add_child(p)
	p.global_position = punct + normala * 0.03
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


## O gaură de glonț pe perete (pătrățel închis, lipit pe suprafață).
func _gaura(punct: Vector3, normala: Vector3) -> void:
	var g := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 0.035)
	g.mesh = q
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("262d2f")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	g.material_override = mat
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(g)
	var sus := Vector3.UP if absf(normala.y) < 0.9 else Vector3.FORWARD
	g.look_at_from_position(punct + normala * 0.006, punct - normala, sus)
	g.rotation.z = randf() * TAU
	_gauri.append(g)
	while _gauri.size() > MAX_GAURI:
		var veche: Node3D = _gauri.pop_front()
		if is_instance_valid(veche):
			veche.queue_free()


## Particule-pătrățele întoarse spre cameră (fum, praf, scântei), oprite: le pornește cine le folosește.
func _particule(cate: int, viata: float, marime: float, culoare: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * marime
	quad.material = material_particule(culoare.v > 0.85 and culoare.r > 0.9)
	p.mesh = quad
	p.amount = cate
	p.lifetime = viata
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([culoare, Color(culoare, 0.0)])
	p.color_ramp = gradient
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
