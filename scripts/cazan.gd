extends Interactabil
## Cazanul mare din mijlocul coven-ului (scenes/coven.tscn). Cu un cadavru în inventar (bețivul sau o vrăjitoare din cerc:
## orice nod din grupul „cadavre”, cu `id_cadavru`, `nume_cadavru` și `model_cadavru()`), E îl aruncă
## înăuntru și pornește vraja (la persoana întâi, cu benzi negre, vezi Cutscena):
##   1. corpul zboară din brațele tale în cazan și se scufundă (pleoscăit, stropi);
##   2. poțiunea se face verde, fierbe mai tare, vrăjitoarele din cerc își ridică brațele;
##   3. din cazan pleacă spre cer o undă de lumină verde, `durata_unda` secunde (te uiți după ea);
##   4. unda dispare, bubuie, iar din cazan țâșnesc particule roșii (vraja e gata); unele rămân să plutească.
## Pune marcajul `marcaj_vraja` și sarcina `sarcina_dupa`. La Continue, cu marcajul pus, cazanul e deja verde.
## Focul de sub cazan pâlpâie și luminează roșiatic; poțiunea strălucește în culoarea ei.

@export var marcaj_vraja := "vraja_facuta"
@export var sarcina_dupa := "Talk to the Head Witch."
## Cât stă unda de lumină pe cer (secunde).
@export var durata_unda := 2.0
## Poțiunea de la început (mov) și cea după vrajă (verde otravă).
@export var culoare_inceput := Color("655269")
@export var culoare_vraja := Color(0.45, 1.0, 0.3)
## Particulele de la sfârșit.
@export var culoare_particule := Color(1.0, 0.12, 0.08)

const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")
const SHADER_RAZA := preload("res://shaders/raza_vraja.gdshader")
const SUNET_PLESCAIT := preload("res://sunete/cazan_plescait.ogg")
const SUNET_COR := preload("res://sunete/vraja_cor.ogg")
const SUNET_UNDA := preload("res://sunete/vraja_unda.ogg")
const SUNET_BUM := preload("res://sunete/vraja_bum.ogg")
## Culoarea vârfurilor poțiunii din model (cea mai deschisă din paletă); materialul o înmulțește până la culoarea dorită.
const CULOARE_MODEL := Color("83b3b0")
## Înălțimea gurii cazanului (unde e poțiunea) și cât de înaltă e unda.
const GURA := 1.22
const INALTIME_UNDA := 140.0
## Corul, unda și bubuitura sunt sunete „de film”: stereo, peste tot (nu din cazan), puțin mai tari decât efectele.
const VOLUM_VRAJA := Sunet.VOLUM_EFECTE + 3.0

var _lichid: MeshInstance3D
var _foc: MeshInstance3D
var _mat_lichid: ShaderMaterial
var _culoare := Color.WHITE
var _lumina_foc: OmniLight3D
var _lumina_potiune: OmniLight3D
var _lumina_unda: OmniLight3D
var _unda: Node3D
var _mat_unda: ShaderMaterial
var _scantei: CPUParticles3D
var _timp := 0.0
var _in_vraja := false
var _cadavru: Node  # al cui cadavru e în inventar (vezi _cadavru_din_inventar)

@onready var _fierbere: AudioStreamPlayer3D = $Fierbere


func _ready() -> void:
	_lichid = $Model/Lichid
	_foc = $Model/Foc
	_mat_lichid = (_lichid.material_override as ShaderMaterial).duplicate()
	_lichid.material_override = _mat_lichid
	_lichid.set_instance_shader_parameter("stralucire", 1.6)
	_lumina_foc = _lumina(Color(1.0, 0.5, 0.2), 2.0, 7.0, Vector3(0, 0.35, 0))
	_lumina_potiune = _lumina(culoare_inceput, 1.2, 6.0, Vector3(0, GURA + 0.5, 0))
	_lumina_unda = _lumina(culoare_vraja, 0.0, 30.0, Vector3(0, GURA + 3.0, 0))
	_fa_unda()
	_scantei = _particule(false)
	var gata := Stare.e_marcat(marcaj_vraja)
	_seteaza_culoare(culoare_vraja if gata else culoare_inceput)
	if gata:
		_lichid.set_instance_shader_parameter("stralucire", 3.0)
	_scantei.emitting = gata


func poate_fi_folosit() -> bool:
	if _in_vraja or Stare.e_marcat(marcaj_vraja):
		return false
	_cadavru = _cadavru_din_inventar()
	if _cadavru == null:
		return false
	indiciu = "[E] Throw the %s in" % String(_cadavru.nume_cadavru).to_lower()
	return true


## Primul cadavru din inventar (bețivul sau o vrăjitoare), sau null.
func _cadavru_din_inventar() -> Node:
	for nod in get_tree().get_nodes_in_group("cadavre"):
		if Stare.are_obiect(nod.id_cadavru):
			return nod
	return null


func _process(delta: float) -> void:
	_timp += delta
	# focul pâlpâie
	var p := 0.85 + sin(_timp * 13.0) * 0.08 + sin(_timp * 23.0 + 1.0) * 0.06 + randf() * 0.05
	_foc.scale = Vector3(1.0, p, 1.0)
	_foc.set_instance_shader_parameter("stralucire", 1.6 + p)
	_lumina_foc.light_energy = 2.0 * p
	# poțiunea se învârte încet, bulele se mișcă
	_lichid.rotation.y += delta * 0.25
	_lichid.position.y = sin(_timp * 2.0) * 0.008


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_vraja = true
	folosit.emit()
	Stare.scoate_obiect(_cadavru.id_cadavru)
	var model: PackedScene = _cadavru.model_cadavru()
	var c := Cutscena.porneste(self)
	var gura := global_position + Vector3.UP * GURA
	# faci un pas spre cazan, ca să vezi poțiunea dinăuntru
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	var dinspre := jucator.global_position - global_position
	dinspre.y = 0.0
	var loc := global_position + dinspre.normalized() * 1.4
	var pas := create_tween().set_trans(Tween.TRANS_SINE)
	pas.tween_property(jucator, "global_position", Vector3(loc.x, jucator.global_position.y, loc.z), 0.6)
	await c.priveste(gura + Vector3.DOWN * 0.15, 0.6)

	# 1. îl arunci
	await _arunca_corpul(gura, model)
	await get_tree().create_timer(0.5).timeout

	# 2. poțiunea se face verde, fierbe mai tare, vrăjitoarele ridică brațele, corul se umflă
	Sunet.reda(SUNET_COR, VOLUM_VRAJA)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tween.tween_method(_seteaza_culoare, culoare_inceput, culoare_vraja, 1.6)
	tween.tween_method(func(v: float) -> void: _lichid.set_instance_shader_parameter("stralucire", v), 1.6, 3.0, 1.6)
	tween.tween_property(_lumina_potiune, "light_energy", 2.5, 1.6)
	tween.tween_property(_fierbere, "pitch_scale", 1.35, 1.6)
	tween.tween_property(_fierbere, "volume_db", _fierbere.volume_db + 8.0, 1.6)
	get_tree().call_group("vrajitoare_cerc", "ridica_bratele", true, 1.4)
	await get_tree().create_timer(1.5).timeout

	# 3. unda de lumină spre cer
	Sunet.reda(SUNET_UNDA, VOLUM_VRAJA)
	_unda.show()
	_unda.scale = Vector3(0.3, 0.01, 0.3)
	_mat_unda.set_shader_parameter("putere", 1.0)
	tween = create_tween().set_parallel().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(_unda, "scale", Vector3(1.0, INALTIME_UNDA, 1.0), 0.35)
	tween.tween_property(_lumina_unda, "light_energy", 9.0, 0.25)
	c.priveste(gura + Vector3.UP * 40.0, 0.8)
	await get_tree().create_timer(durata_unda).timeout

	# 4. unda dispare; bum și particulele roșii
	tween = create_tween().set_parallel()
	tween.tween_method(func(v: float) -> void: _mat_unda.set_shader_parameter("putere", v), 1.0, 0.0, 0.3)
	tween.tween_property(_unda, "scale:x", 0.05, 0.3)
	tween.tween_property(_unda, "scale:z", 0.05, 0.3)
	tween.tween_property(_lumina_unda, "light_energy", 0.0, 0.3)
	await c.priveste(gura + Vector3.UP * 0.4, 0.5)
	_unda.hide()
	Sunet.reda(SUNET_BUM, VOLUM_VRAJA)
	var bum := _particule(true)
	bum.emitting = true
	get_tree().create_timer(4.0).timeout.connect(bum.queue_free)
	_scantei.emitting = true
	_lumina_potiune.light_color = culoare_particule
	_lumina_potiune.light_energy = 7.0
	tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_lumina_potiune, "light_energy", 2.0, 1.5)
	tween.tween_property(_lumina_potiune, "light_color", culoare_vraja, 1.5)
	tween.tween_property(_fierbere, "pitch_scale", 1.0, 2.0)
	get_tree().call_group("vrajitoare_cerc", "ridica_bratele", false, 1.6)
	await get_tree().create_timer(1.8).timeout

	Stare.marcheaza(marcaj_vraja)
	Stare.seteaza_sarcina(sarcina_dupa)
	_in_vraja = false
	c.opreste()


## Corpul pleacă de sub privirea ta, zboară în arc peste buză și se scufundă în poțiune.
func _arunca_corpul(gura: Vector3, model: PackedScene) -> void:
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	if model == null or jucator == null:
		return
	var camera: Camera3D = jucator.get_node("Cap/Camera3D")
	var corp := model.instantiate() as Node3D
	corp.set_script(SCRIPT_MODEL)
	corp.set("material", MATERIAL)
	get_tree().current_scene.add_child(corp)
	# modelul are originea la sol, sub el; mijlocul corpului e cam la 0,7 m deasupra
	var mijloc := Vector3.UP * 0.7
	var start := camera.global_position - camera.global_basis.z * 0.9 + Vector3.DOWN * 0.7 - mijloc
	var sus := gura - mijloc + Vector3.UP * 0.2
	corp.global_position = start
	corp.rotation = Vector3(0.3, jucator.rotation.y, 0.0)
	var rot_start := corp.rotation
	var rot_capat := rot_start + Vector3(-2.2, randf_range(-0.6, 0.6), 0.5)
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		corp.global_position = start.lerp(sus, t) + Vector3.UP * sin(t * PI) * 0.9
		corp.rotation = rot_start.lerp(rot_capat, t), 0.0, 1.0, 0.7)
	await tween.finished
	Sunet.reda_la(SUNET_PLESCAIT, gura, Sunet.VOLUM_EFECTE, 0.05)
	_stropi(gura)
	tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(corp, "global_position", sus + Vector3.DOWN * 1.6, 0.9)
	await tween.finished
	corp.queue_free()


func _seteaza_culoare(c: Color) -> void:
	_culoare = c
	# materialul înmulțește culoarea vârfurilor: împărțim la ea, ca să iasă exact culoarea cerută
	_mat_lichid.set_shader_parameter("culoare", Color(c.r / CULOARE_MODEL.r, c.g / CULOARE_MODEL.g, c.b / CULOARE_MODEL.b))
	_lumina_potiune.light_color = c


func _lumina(culoare: Color, energie: float, raza_lumina: float, pozitie: Vector3) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = culoare
	l.light_energy = energie
	l.omni_range = raza_lumina
	l.position = pozitie
	add_child(l)
	return l


## Unda: un cilindru deschis, cu originea jos (în poțiune), pe care îl întindem în sus.
func _fa_unda() -> void:
	_unda = Node3D.new()
	_unda.position = Vector3.UP * GURA
	add_child(_unda)
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	_mat_unda = ShaderMaterial.new()
	_mat_unda.shader = SHADER_RAZA
	_mat_unda.set_shader_parameter("culoare", culoare_vraja)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat_unda
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.5
	_unda.add_child(mi)
	_unda.hide()


## Particulele roșii: `bum` = țâșnesc toate odată din cazan; altfel = scântei care urcă încet, mereu.
func _particule(bum: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (0.09 if bum else 0.06)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_fog = true
	quad.material = mat
	p.mesh = quad
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([culoare_particule * 1.6, culoare_particule, Color(culoare_particule, 0.0) * 0.3])
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	p.color_ramp = gradient
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.45
	p.direction = Vector3.UP
	if bum:
		p.one_shot = true
		p.amount = 160
		p.lifetime = 2.2
		p.explosiveness = 0.95
		p.spread = 75.0
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 6.5
		p.gravity = Vector3(0, -2.5, 0)
		p.damping_min = 1.0
		p.damping_max = 2.0
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.6
	else:
		p.amount = 50
		p.lifetime = 3.5
		p.spread = 25.0
		p.initial_velocity_min = 0.2
		p.initial_velocity_max = 0.7
		p.gravity = Vector3(0, 0.25, 0)
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.2
		p.emitting = false
	p.position = Vector3.UP * (GURA + 0.05)
	add_child(p)
	return p


## Stropi de poțiune când cade corpul.
func _stropi(unde: Vector3) -> void:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.07
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = _culoare
	quad.material = mat
	p.mesh = quad
	p.one_shot = true
	p.amount = 40
	p.lifetime = 1.0
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -9.8, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	get_tree().current_scene.add_child(p)
	p.global_position = unde
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)
