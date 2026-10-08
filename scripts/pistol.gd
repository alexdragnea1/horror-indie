class_name Pistol
extends Node3D
## Pistolul roz de la Head Witch (sau cel de aur, `auriu()`), în mâna ta dreaptă (la persoana întâi). Îl pune jucator.gd sub cameră; se vede
## doar cât îl ții în mână (`Stare.in_mana` = `ID`; îl alegi din inventar). Click stânga (acțiunea "trage") = tragi: un glonț omoară pe loc doar
## personajele `omorabil` (Personaj.impuscat: bețivul) și, după ce ți-a cerut bețivul, vrăjitoarele din cerc; pe ceilalți nu-i
## atinge. Orice are `impuscat(directie, punct)` primește glonțul (ex. boombox-ul se strică). Un cadavru îl împinge,
## iar în rest ridică un pic de praf. Gloanțe câte vrei, câte unul la `pauza` secunde.
## Cât vorbești nu tragi; cât e deschis un meniu / o scenă (Stare.meniu_deschis) sau e ecranul negru, îl lași jos.

const ID := "pistol_roz"
const MODEL := preload("res://models/pistol_roz.glb")
## Modelul e în culorile paletei (cea mai deschisă); materialul ăsta îl face roz, cum a cerut owner-ul.
const MATERIAL_ROZ := preload("res://shaders/material_roz.tres")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const SUNET := preload("res://sunete/pistol_impuscatura.ogg")
## Gura țevii, în coordonatele modelului.
const GURA_TEVII := Vector3(0, 0.037, -0.155)
## Pistolul placat cu aur (easter egg-ul din spatele conacului, pistol_aur_masa.gd): trage la fel, dar e alt obiect
## în inventar. `Luciu` (muchiile de sus, medalioanele) sclipește puțin.
const ID_AUR := "pistol_aur"
const MODEL_AUR := preload("res://models/pistol_aur.glb")
## Modelul e în aurul din paletă; materialul ăsta îl face mai auriu (ca rozul la pistolul roz).
const MATERIAL_AUR := preload("res://shaders/material_aur.tres")
const GURA_TEVII_AUR := Vector3(0, 0.046, -0.19)

## O scenă din cod (sefa_antrenament.gd) îl poate ține la vedere cât merge ea (altfel coboară cât e Stare.meniu_deschis)
## și îl poate înclina pe o parte („gangsta”, radiani pe Z).
static var in_scena := false
static var inclinare := 0.0

## Unde îl ții (față de cameră) și unde stă când e lăsat jos.
@export var pozitie := Vector3(0.16, -0.15, -0.32)
@export var pozitie_jos := Vector3(0.18, -0.45, -0.26)
## Cât de departe ajunge glonțul (metri).
@export var bataie := 80.0
@export var pauza := 0.35

var _camera: Camera3D
var _cap: Node3D
var _jucator: CharacterBody3D
var _model: Node3D
var _jos := 1.0  # 0 = în mână, 1 = lăsat jos (nu se vede)
var _recul := 0.0
var _inclinat := 0.0
var _gata := 0.0
var _timp := 0.0
var _lumina: OmniLight3D
var _flacara: MeshInstance3D
## Care pistol e (jucator.gd pune câte unul din fiecare; se vede doar cel din mână).
var id := ID
var _scena: PackedScene = MODEL
var _material: Material = MATERIAL_ROZ
var _stralucitoare := PackedStringArray(["Strasuri"])
var _stralucire := 1.4
var _gura := GURA_TEVII


## Pistolul de aur.
static func auriu() -> Pistol:
	var p := Pistol.new()
	p.id = ID_AUR
	p._scena = MODEL_AUR
	p._material = MATERIAL_AUR
	p._stralucitoare = PackedStringArray(["Luciu"])
	p._stralucire = 0.6
	p._gura = GURA_TEVII_AUR
	return p


func _ready() -> void:
	_camera = get_parent() as Camera3D
	_cap = _camera.get_parent() as Node3D
	_jucator = _cap.get_parent() as CharacterBody3D
	_model = _scena.instantiate()
	_model.set_script(SCRIPT_MODEL)
	_model.set("material", _material)
	_model.set("umbre", false)
	_model.set("stralucitoare", _stralucitoare)
	_model.set("stralucire", _stralucire)
	add_child(_model)
	# țeava puțin spre mijlocul ecranului, ca la jocurile vechi
	_model.rotation = Vector3(0.04, 0.07, 0.0)
	_flacara = MeshInstance3D.new()
	var sfera := SphereMesh.new()
	sfera.radius = 0.035
	sfera.height = 0.05
	sfera.radial_segments = 6
	sfera.rings = 3
	_flacara.mesh = sfera
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.45)
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_fog = true
	_flacara.material_override = mat
	_flacara.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flacara.position = _gura + Vector3(0, 0, -0.03)
	_flacara.hide()
	_model.add_child(_flacara)
	_lumina = OmniLight3D.new()
	_lumina.light_color = Color(1.0, 0.75, 0.45)
	_lumina.light_energy = 0.0
	_lumina.omni_range = 6.0
	_lumina.position = _gura
	_model.add_child(_lumina)
	visible = false


func _process(delta: float) -> void:
	_timp += delta
	var are := Stare.in_mana == id
	var jos := not are or (Stare.meniu_deschis and not in_scena) or Tranzitie.activa
	_inclinat = move_toward(_inclinat, inclinare, delta * 4.0)
	_jos = move_toward(_jos, 1.0 if jos else 0.0, delta * 3.5)
	visible = are and _jos < 0.99
	_gata = maxf(_gata - delta, 0.0)
	_recul = move_toward(_recul, 0.0, delta * 7.0)
	var k := ease(_jos, 2.0)
	# respiră puțin în mână
	var respiratie := Vector3(sin(_timp * 1.3) * 0.002, sin(_timp * 2.1) * 0.003, 0.0)
	position = pozitie.lerp(pozitie_jos, k) + respiratie + Vector3(0, _recul * 0.01, _recul * 0.045)
	# înclinat pe o parte îl ridici în fața ochilor (altfel intră sub caseta de dialog)
	position += Vector3(-0.07, 0.1, 0.04) * (_inclinat / 1.25)
	rotation = Vector3(_recul * 0.35 - k * 0.6, 0.0, _inclinat)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("trage") and _poate_trage():
		_trage()


func _poate_trage() -> bool:
	return visible and _jos < 0.05 and _gata <= 0.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
		and not Dialog.activ and not Stare.meniu_deschis and not Tranzitie.activa and not get_tree().paused


## O scenă din cod trage singură (ceaun_acasa.gd, în demon): cu pistolul ridicat (`in_scena`), spre mijlocul ecranului.
func trage_acum() -> void:
	_trage()


func _trage() -> void:
	_gata = pauza
	_recul = 1.0
	Sunet.reda(SUNET, Sunet.VOLUM_EFECTE, 0.05)
	_fulger()
	# camera sare puțin în sus
	_cap.rotation.x = clampf(_cap.rotation.x + 0.03, deg_to_rad(-85), deg_to_rad(85))
	var de_la := _camera.global_position
	var directie := -_camera.global_basis.z
	var cerere := PhysicsRayQueryParameters3D.create(de_la, de_la + directie * bataie, 1 | Ragdoll.STRAT)
	cerere.exclude = [_jucator.get_rid()]
	var lovit := get_world_3d().direct_space_state.intersect_ray(cerere)
	if lovit.is_empty():
		return
	var tinta: Object = lovit.collider
	if tinta.has_method("lovit_de"):
		tinta.lovit_de(id, directie, lovit.position)  # Warlock-ul de la motel: damage după armă
	elif tinta.has_method("impuscat"):
		tinta.impuscat(directie, lovit.position)
	elif tinta is RigidBody3D:
		(tinta as RigidBody3D).apply_impulse(directie * 30.0, lovit.position - (tinta as RigidBody3D).global_position)
	else:
		_praf(lovit.position, lovit.normal)


## Flacăra de la gura țevii și lumina ei, o clipă.
func _fulger() -> void:
	_flacara.show()
	_flacara.rotation.z = randf() * TAU
	_flacara.scale = Vector3.ONE * randf_range(0.8, 1.3)
	_lumina.light_energy = 2.5
	await get_tree().create_timer(0.05).timeout
	_flacara.hide()
	var tween := create_tween()
	tween.tween_property(_lumina, "light_energy", 0.0, 0.08)


## Un pic de praf unde a lovit glonțul.
func _praf(punct: Vector3, normala: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 10
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 60.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, -2.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color("5e5356")
	quad.material = mat
	p.mesh = quad
	get_tree().current_scene.add_child(p)
	p.global_position = punct + normala * 0.03
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)
