class_name VrajaFoc
extends Node3D
## Vraja Fireball (de la Helga), „în mână” la persoana întâi, ca pistolul: o alegi din inventar (`ID`), îți vezi mâna
## dreaptă cu palma în sus și un foc mic care pâlpâie în ea; la click (acțiunea "trage") împingi palma înainte și din ea
## pleacă o minge de foc (MingeFoc) spre locul la care te uiți. Focul din palmă se stinge și crește la loc (`pauza`).
## A ta e mai mică decât a lui Helga (`MARIME`), cum a cerut owner-ul: „mai micuț, dar tot e ok”.
## Îl pune jucator.gd sub cameră (nodul `VrajaFoc`). La lecția cu Helga (helga.gd) mâna apare înainte să ai vraja:
## `demonstratie` + `stinge()` / `aprinde()` / `arunca_acum()`.

const ID := "vraja_foc"
const NUME := "Fireball Spell"
const MODEL := preload("res://models/mana_jucator.glb")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")
const SUNET_ARUNCA := preload("res://sunete/minge_foc_aruncata.ogg")
const SUNET_APRINS := preload("res://sunete/minge_foc_aprinsa.ogg")
## Cât de mare e mingea ta față de a lui Helga (1).
const MARIME := 0.6
## Unde stă focul, față de mijlocul palmei.
const FOC := Vector3(0.0, 0.075, 0.0)

## Lecția cu Helga: mâna se vede și când n-ai vraja în inventar (și cât e scena cu benzi negre).
static var demonstratie := false

## Unde ții mâna (față de cameră) și unde stă când e lăsată jos.
@export var pozitie := Vector3(0.19, -0.2, -0.38)
@export var pozitie_jos := Vector3(0.24, -0.62, -0.26)
## Cum e întoarsă mâna (dreaptă!), dată prin direcții față de cameră: încotro arată degetele și încotro privește
## palma. În repaus: palma în sus (puțin spre tine, să vezi focul), degetele înainte și puțin spre mijlocul ecranului,
## deci degetul mare iese în dreapta și antebrațul vine din colțul din dreapta-jos.
@export var degete_repaus := Vector3(-0.35, 0.22, -1.0)
@export var palma_repaus := Vector3(-0.2, 1.0, 0.3)
## La aruncare: palma spre înainte, degetele în sus; vezi dosul palmei, cu degetul mare spre mijlocul ecranului.
@export var degete_impins := Vector3(-0.15, 1.0, -0.2)
@export var palma_impins := Vector3(0.08, 0.2, -1.0)
@export var pauza := 0.9
@export var bataie := 60.0

var _camera: Camera3D
var _cap: Node3D
var _jucator: CharacterBody3D
var _model: Node3D
var _foc: MingeFoc
var _jos := 1.0
var _impins := 0.0
var _gata := 0.0
var _timp := 0.0
var _aprins := 1.0  # cât de mare e focul din palmă (0..1)
var _scantei: CPUParticles3D


func _ready() -> void:
	_camera = get_parent() as Camera3D
	_cap = _camera.get_parent() as Node3D
	_jucator = _cap.get_parent() as CharacterBody3D
	_model = MODEL.instantiate()
	_model.set_script(SCRIPT_MODEL)
	_model.set("material", MATERIAL)
	_model.set("umbre", false)
	# lipită de cameră, lanterna n-o prinde: puțin luciu, ca pielea să nu fie neagră (focul o luminează oricum)
	_model.set("stralucitoare", PackedStringArray(["Mana"]))
	_model.set("stralucire", 0.08)
	add_child(_model)
	_foc = MingeFoc.creeaza(_model, MARIME * 0.45)
	_foc.position = FOC
	# în palmă focul e la o palmă de ochi: flăcările mai mici și mai puține, rămân lângă mână când te întorci
	var dara: CPUParticles3D = _foc._dara
	dara.local_coords = true
	dara.amount = 14
	dara.lifetime = 0.3
	(dara.mesh as QuadMesh).size *= 0.45
	_scantei = CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.012
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = MingeFoc.FLACARA
	mat.disable_fog = true
	quad.material = mat
	_scantei.mesh = quad
	_scantei.amount = 10
	_scantei.lifetime = 0.35
	_scantei.explosiveness = 0.6
	_scantei.spread = 60.0
	_scantei.direction = Vector3.UP
	_scantei.initial_velocity_min = 0.2
	_scantei.initial_velocity_max = 0.6
	_scantei.gravity = Vector3(0, -1.0, 0)
	_scantei.emitting = false
	_scantei.position = FOC
	_model.add_child(_scantei)
	visible = false


func _process(delta: float) -> void:
	_timp += delta
	var are := Stare.in_mana == ID or demonstratie
	var jos := not are or (Stare.meniu_deschis and not demonstratie) or Tranzitie.activa
	_jos = move_toward(_jos, 1.0 if jos else 0.0, delta * 3.2)
	visible = are and _jos < 0.99
	_gata = maxf(_gata - delta, 0.0)
	if not demonstratie:
		_aprins = move_toward(_aprins, 1.0 if _gata <= 0.0 else 0.0, delta * 2.5)
	_foc.marime_vizibila = ease(_aprins, 0.6)
	_foc._sunet.stream_paused = not visible  # focul din palmă se aude doar cât ții mâna sus
	var k := ease(_jos, 2.0)
	var respiratie := Vector3(sin(_timp * 1.3) * 0.002, sin(_timp * 2.1) * 0.003, 0.0)
	# împins înainte: palma se ridică cu degetele în sus și se întoarce spre înainte
	var impins := Vector3(-0.03, 0.06, -0.14) * _impins
	position = pozitie.lerp(pozitie_jos, k) + respiratie + impins
	var q_repaus := orientare(degete_repaus, palma_repaus).get_rotation_quaternion()
	var q_impins := orientare(degete_impins, palma_impins).get_rotation_quaternion()
	_model.basis = Basis(q_repaus.slerp(q_impins, _impins))
	rotation.x = -k * 0.5


## Rotația modelului mâinii (în model: degetele spre -Z, palma spre +Y, degetul mare spre +X) care duce degetele
## pe `degete` și palma pe `palma`. Fiind doar o rotație, mâna rămâne dreaptă orice direcții i-ai da.
static func orientare(degete: Vector3, palma: Vector3) -> Basis:
	var z := -degete.normalized()
	var x := palma.cross(z).normalized()
	return Basis(x, z.cross(x), z)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("trage") and _poate_arunca():
		arunca_acum()


func _poate_arunca() -> bool:
	return Stare.in_mana == ID and visible and _jos < 0.05 and _gata <= 0.0 and _aprins > 0.9 \
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not Dialog.activ and not Stare.meniu_deschis \
		and not Tranzitie.activa and not get_tree().paused


## Lecția: focul din palmă dispare (mâna e goală).
func stinge() -> void:
	_aprins = 0.0


## Lecția: „gândește-te la foc”: întâi doar câteva scântei care se sting, apoi focul se aprinde și crește în palmă.
func aprinde(durata := 2.2) -> void:
	_scantei.emitting = true
	Sunet.reda(SUNET_APRINS, Sunet.VOLUM_EFECTE - 6.0, 0.05)
	await get_tree().create_timer(durata * 0.45).timeout
	_scantei.emitting = false
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "_aprins", 0.35, durata * 0.2)
	t.tween_property(self, "_aprins", 0.15, durata * 0.1)
	t.tween_property(self, "_aprins", 1.0, durata * 0.25)
	await t.finished


## Împinge palma înainte și aruncă mingea de foc spre ce e în mijlocul ecranului. Întoarce mingea (are semnalul `explodat`).
func arunca_acum() -> MingeFoc:
	_gata = pauza
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "_impins", 1.0, 0.12)
	await t.finished
	Sunet.reda(SUNET_ARUNCA, Sunet.VOLUM_EFECTE - 2.0, 0.06)
	var de_la := _foc.global_position
	var tinta := _camera.global_position - _camera.global_basis.z * bataie
	var cerere := PhysicsRayQueryParameters3D.create(_camera.global_position, tinta, 1 | Ragdoll.STRAT)
	cerere.exclude = [_jucator.get_rid()]
	var lovit := get_world_3d().direct_space_state.intersect_ray(cerere)
	if not lovit.is_empty():
		tinta = lovit.position
	var minge := MingeFoc.arunca(self, de_la, tinta - de_la, MARIME, [_jucator.get_rid()])
	_aprins = 0.0
	_cap.rotation.x = clampf(_cap.rotation.x + 0.015, deg_to_rad(-85), deg_to_rad(85))
	var inapoi := create_tween().set_trans(Tween.TRANS_SINE)
	inapoi.tween_property(self, "_impins", 0.0, 0.4)
	return minge
