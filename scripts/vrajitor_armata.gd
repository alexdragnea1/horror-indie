class_name VrajitorArmata
extends Node3D
## Un vrăjitor din armata Warlock-ului (models/vrajitor_1..3.glb, din tools/blender/warlock.py), făcut din cod de
## atac_conac.gd. Apare dintr-un fulger roșu (`apare`), stă legănându-se, cu ochii aprinși, și se uită la conac;
## `arunca(tinta, fel)` = ridică brațul drept spre țintă și trimite o vrajă (VrajaAtac); `canalizeaza(punct)` = ridică
## ambele brațe și trimite o rază de energie spre vraja mare a Warlock-ului. Fața spre +Z.

const MODELE := [preload("res://models/vrajitor_1.glb"), preload("res://models/vrajitor_2.glb"), preload("res://models/vrajitor_3.glb")]
const MATERIAL := preload("res://shaders/material_model.tres")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const SHADER_RAZA := preload("res://shaders/raza_vraja.gdshader")
const SUNET_APARE := preload("res://sunete/atac_aparitie.ogg")
## Mâinile, față de umăr (brațele atârnă; vezi vrajitor() în tools/blender/warlock.py).
const MANA_DREAPTA := Vector3(-0.03, -0.62, 0.07)
const MANA_STANGA := Vector3(0.03, -0.62, 0.07)
## Ce fel de vrăji aruncă fiecare model.
const FELURI := ["foc", "mov", "rosu"]

var fel := 0
var _model: Node3D
var _cap: Node3D
var _brat_d: Node3D
var _brat_s: Node3D
var _timp := randf() * 10.0
var _privire := Vector3.ZERO
var _raza: MeshInstance3D
var _raza_spre := Vector3.ZERO


static func creeaza(parinte: Node, pozitie: Vector3, fel_: int, spre: Vector3) -> VrajitorArmata:
	var v := VrajitorArmata.new()
	v.fel = fel_
	parinte.add_child(v)
	v.global_position = pozitie
	var d := spre - pozitie
	v.rotation.y = atan2(d.x, d.z)
	v._privire = spre
	return v


func _ready() -> void:
	_model = (MODELE[fel % MODELE.size()] as PackedScene).instantiate() as Node3D
	_model.set_script(SCRIPT_MODEL)
	_model.set("material", MATERIAL)
	_model.set("stralucitoare", PackedStringArray(["Lumini", "Ochi"]))
	_model.set("stralucire", 2.2)
	add_child(_model)
	_cap = _model.get_node("Cap")
	_brat_d = _model.get_node("BratDrept")
	_brat_s = _model.get_node("BratStang")
	ModelPS2.disparitie(_model, 1.0)
	hide()


func _process(delta: float) -> void:
	_timp += delta
	# se leagănă încet, ca într-un descântec
	_model.rotation.z = sin(_timp * 1.1) * 0.03
	_model.rotation.x = sin(_timp * 0.8 + 1.0) * 0.02
	if _privire != Vector3.ZERO:
		var local: Vector3 = (_cap.get_parent() as Node3D).to_local(_privire) - _cap.position
		_cap.rotation.y = lerp_angle(_cap.rotation.y, clampf(atan2(local.x, local.z), -0.9, 0.9), delta * 3.0)
		_cap.rotation.x = lerp_angle(_cap.rotation.x, clampf(-atan2(local.y, Vector2(local.x, local.z).length()), -0.6, 0.6), delta * 3.0)
	if _raza:
		_aseaza_raza()


## Apare dintr-o dată (fulgerul îl face scena): pe pixeli, cu un fum roșu la picioare.
func apare() -> void:
	show()
	VrajaAtac.sunet_la(self, SUNET_APARE, global_position + Vector3.UP, Sunet.VOLUM_EFECTE, 6.0, 0.15)
	var fum := VrajaAtac.particule(self, 22, 1.4, 0.7, [Color(0.6, 0.12, 0.1, 0.8), Color(0.3, 0.08, 0.08, 0.5), Color(0.12, 0.05, 0.06, 0.0)])
	fum.position = Vector3.UP * 0.4
	fum.one_shot = true
	fum.explosiveness = 1.0
	fum.emission_sphere_radius = 0.5
	fum.spread = 180.0
	fum.initial_velocity_min = 0.5
	fum.initial_velocity_max = 1.6
	fum.gravity = Vector3(0, 0.8, 0)
	fum.emitting = true
	var t := create_tween()
	t.tween_method(func(v: float) -> void: ModelPS2.disparitie(_model, v), 1.0, 0.0, 0.45)


## Ridică brațul drept spre `tinta` și aruncă o vrajă de felul lui (sau `fel_vraja`). Întoarce vraja (după ce a plecat).
func arunca(tinta: Vector3, marime := 0.9, durata := 1.3, fel_vraja := "") -> VrajaAtac:
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_brat_d, "rotation:x", -1.75, 0.3)
	await t.finished
	var de_la := _brat_d.to_global(MANA_DREAPTA)
	var vraja := VrajaAtac.trage(self, de_la, tinta, fel_vraja if fel_vraja != "" else FELURI[fel % FELURI.size()], marime, durata, randf_range(1.0, 3.0))
	# reculul, apoi brațul coboară
	t = create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(_brat_d, "rotation:x", -1.3, 0.12)
	t.tween_property(_brat_d, "rotation:x", -0.2, 0.7)
	return vraja


## Ambele brațe sus, spre `punct`, și o rază de energie din mâini până acolo (vraja mare a Warlock-ului). `oprit` = le lasă jos.
func canalizeaza(punct: Vector3, culoare := Color(0.95, 0.2, 0.15), oprit := false) -> void:
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	if oprit:
		t.tween_property(_brat_d, "rotation", Vector3.ZERO, 0.6)
		t.tween_property(_brat_s, "rotation", Vector3.ZERO, 0.6)
		if _raza:
			_raza.queue_free()
			_raza = null
		return
	_privire = punct
	t.tween_property(_brat_d, "rotation", Vector3(-2.5, 0.0, 0.15), 0.8)
	t.tween_property(_brat_s, "rotation", Vector3(-2.5, 0.0, -0.15), 0.8)
	await t.finished
	_raza_spre = punct
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.09
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_RAZA
	mat.set_shader_parameter("culoare", culoare)
	mat.set_shader_parameter("putere", 0.0)
	_raza = MeshInstance3D.new()
	_raza.mesh = mesh
	_raza.material_override = mat
	_raza.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(_raza)
	_aseaza_raza()
	create_tween().tween_method(func(v: float) -> void: mat.set_shader_parameter("putere", v), 0.0, 1.0, 0.6)


func _aseaza_raza() -> void:
	var a := (_brat_d.to_global(MANA_DREAPTA) + _brat_s.to_global(MANA_STANGA)) * 0.5
	var b := _raza_spre
	var d := b - a
	var lung := d.length()
	# cilindrul (înalt de 1 m, pe Y) întors spre punct și întins cât distanța (pe axa lui, nu pe a lumii)
	_raza.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, d.normalized())) * Basis.from_scale(Vector3(1.0, lung, 1.0)), (a + b) * 0.5)


## Dispare pe pixeli (după atac).
func dispari(durata := 0.6) -> void:
	if _raza:
		_raza.queue_free()
		_raza = null
	var t := create_tween()
	t.tween_method(func(v: float) -> void: ModelPS2.disparitie(_model, v), 0.0, 1.0, durata)
	t.tween_callback(queue_free)
