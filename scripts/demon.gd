class_name Demon
extends StaticBody3D
## Demonul chemat pe pentagrama din camera ta (scenes/demon.tscn, modelul din tools/blender/demon.py). Îl pune și îl
## conduce ceaun_acasa.gd, după ce arunci pisica moartă în ceaun:
##   demon.privire = camera              # capul se uită după tine
##   await demon.aparitie(2.6)           # urcă prin podea, pe pentagramă, apoi răcnește cu aripile deschise
##   demon.vorbeste = true / false        # falca se mișcă cât e pe ecran replica lui
##   await demon.dezintegreaza()         # (după gloanțe) se aprinde ca jarul și se face scrum
##   await demon.teleporteaza()          # dispare într-o clipă, cu fum și un fulger roșu
## Glonțul (Pistol) îl lovește prin `impuscat`: tresare, îi sare sânge negru cu scântei.
## Stă pe loc și respiră: umerii urcă, aripile pe jumătate strânse se mișcă încet, coada se leagănă, ochii și pecetea
## de pe piept (pentagrama întoarsă) mocnesc. Modelul privește spre +Z.

const SUNET_RAGET := preload("res://sunete/demon_raget.ogg")
const SUNET_LOVIT := preload("res://sunete/demon_lovit.ogg")
const SUNET_DEZINTEGRARE := preload("res://sunete/demon_dezintegrare.ogg")
const SUNET_TELEPORT := preload("res://sunete/demon_teleport.ogg")

## Culoarea jarului (ochii, pecetea, corpul care arde la dezintegrare).
@export var culoare_jar := Color(1.0, 0.36, 0.12)
## Cât de tare strălucesc ochii și pecetea.
@export var stralucire_ochi := 2.2
## Cât de departe urcă prin podea (cât de jos începe, metri).
@export var adancime := 2.7

## Capul se uită spre nodul ăsta (camera ta).
var privire: Node3D
## Cât e true, falca se mișcă (vorbește).
var vorbeste := false

var _timp := 0.0
var _furie := 0.0     # 0 = stă, 1 = răcnește: brațele în lături, capul pe spate, gura căscată
var _aripi := 1.0     # 0 = deschise de tot, 1 = strânse pe spate
var _lovit := 0.0     # tresăritul de la un glonț (1 → 0)
var _agonie := 0.0    # dezintegrarea: se zbate, cu gura larg deschisă
var _tremur := 0.0    # tremurul corpului (dezintegrare)
var _poz_cap := Vector3.ZERO
var _poz_brat_s := Vector3.ZERO
var _poz_brat_d := Vector3.ZERO

@onready var _model: Node3D = $Model
@onready var _pecete: MeshInstance3D = $Model/Corp/Pecete
@onready var _cap: Node3D = $Model/Cap
@onready var _falca: Node3D = $Model/Cap/Falca
@onready var _ochi: MeshInstance3D = $Model/Cap/Ochi
@onready var _brat_s: Node3D = $Model/BratS
@onready var _brat_d: Node3D = $Model/BratD
@onready var _antebrat_s: Node3D = $Model/BratS/AntebratS
@onready var _antebrat_d: Node3D = $Model/BratD/AntebratD
@onready var _aripa_s: Node3D = $Model/AripaS
@onready var _aripa_d: Node3D = $Model/AripaD
@onready var _coada: Node3D = $Model/Coada
@onready var _lumina: OmniLight3D = $Lumina


func _ready() -> void:
	_poz_cap = _cap.position
	_poz_brat_s = _brat_s.position
	_poz_brat_d = _brat_d.position
	_timp = randf() * 10.0


func _process(delta: float) -> void:
	_timp += delta
	var respiratie := sin(_timp * 1.25)
	# umerii și capul urcă la inspirație (trunchiul e o singură bucată cu picioarele)
	var sus := Vector3.UP * (respiratie * 0.012)
	_cap.position = _poz_cap + sus
	_brat_s.position = _poz_brat_s + sus
	_brat_d.position = _poz_brat_d + sus
	# capul: după tine, mârâind ușor; la răcnet pe spate; în agonie se zbate
	var spre_y := 0.0
	var spre_x := 0.1
	if privire:
		var d := _model.to_local(privire.global_position) - _cap.position
		var orizontal := Vector2(d.x, d.z).length()
		spre_y = clampf(atan2(d.x, d.z), -0.8, 0.8)
		spre_x = clampf(atan2(-d.y, orizontal), -0.4, 0.5)  # + = în jos
	var zbatere := sin(_timp * 23.0) * 0.12 + sin(_timp * 13.0) * 0.08
	var cap_x := lerpf(spre_x, -0.6, maxf(_furie, _agonie)) - _lovit * 0.35 + zbatere * _agonie
	var cap_y := spre_y * (1.0 - _furie) + sin(_timp * 0.6) * 0.05 + zbatere * _agonie * 0.7
	var k := 1.0 - exp(-delta * 6.0)
	_cap.rotation.x = lerpf(_cap.rotation.x, cap_x, k)
	_cap.rotation.y = lerp_angle(_cap.rotation.y, cap_y, k)
	_cap.rotation.z = lerpf(_cap.rotation.z, sin(_timp * 0.45) * 0.06 + zbatere * _agonie * 0.5, k)
	# falca: întredeschisă (respiră pe gură); vorbește; căscată la răcnet și în agonie
	var gura := 0.06 + 0.03 * respiratie
	if vorbeste:
		gura += absf(sin(_timp * 8.5)) * 0.28 + absf(sin(_timp * 13.0)) * 0.08
	gura = maxf(gura, maxf(_furie * 0.62, _agonie * 0.7))
	_falca.rotation.x = lerpf(_falca.rotation.x, gura, 1.0 - exp(-delta * 18.0))
	# brațele: atârnă și ghearele se mișcă puțin; la răcnet în lături și în față, cu coatele îndoite
	var bratul := 0.1 + sin(_timp * 0.9) * 0.03
	var lateral := lerpf(bratul, 1.05, maxf(_furie, _agonie * 0.8)) + _agonie * sin(_timp * 17.0) * 0.1
	var fata := lerpf(sin(_timp * 0.7) * 0.05, -0.35, _furie) - _lovit * 0.3 + _agonie * 0.2
	_brat_s.rotation = Vector3(fata, 0.0, lateral)
	_brat_d.rotation = Vector3(fata + sin(_timp * 0.8) * 0.02, 0.0, -lateral)
	var cot := lerpf(-0.15 + sin(_timp * 1.1) * 0.04, -1.0, _furie) - _agonie * 0.5
	_antebrat_s.rotation.x = cot
	_antebrat_d.rotation.x = cot + sin(_timp * 1.3) * 0.03
	# aripile: pe spate (rotite spre -Z) sau deschise; bat încet
	var bataie := sin(_timp * 0.85) * 0.07 * (1.0 - _aripi * 0.5) + _agonie * sin(_timp * 19.0) * 0.15
	_aripa_s.rotation = Vector3(0.0, 0.95 * _aripi, bataie + 0.15 * _furie)
	_aripa_d.rotation = Vector3(0.0, -0.95 * _aripi, -bataie - 0.15 * _furie)
	_coada.rotation = Vector3(sin(_timp * 0.5) * 0.08, sin(_timp * 0.7) * 0.3 + _agonie * sin(_timp * 15.0) * 0.3, 0.0)
	# tot corpul: se dă pe spate când îl lovește un glonț, tremură când arde
	_model.rotation.x = -_lovit * 0.12 - _furie * 0.06
	_model.position.x = randf_range(-1.0, 1.0) * _tremur * 0.02
	_model.position.z = randf_range(-1.0, 1.0) * _tremur * 0.02
	# ochii și pecetea mocnesc
	var jar := stralucire_ochi * (0.85 + 0.15 * sin(_timp * 6.7) + 0.6 * _furie)
	_ochi.set_instance_shader_parameter("stralucire", jar)
	_pecete.set_instance_shader_parameter("stralucire", jar * (0.6 + 0.4 * sin(_timp * 1.25 + 1.0)))


## Urcă prin pentagramă (podeaua îi ascunde partea de jos), apoi răcnește cu aripile deschise.
func aparitie(durata := 2.6) -> void:
	_model.position.y = -adancime
	_aripi = 1.0
	ModelPS2.disparitie(_model, 0.6)
	var t := create_tween().set_parallel()
	t.tween_property(_model, "position:y", 0.0, durata).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v: float) -> void: ModelPS2.disparitie(_model, v), 0.6, 0.0, durata * 0.7)
	t.tween_property(_lumina, "light_energy", _lumina.light_energy, durata).from(0.0)
	await t.finished
	await get_tree().create_timer(0.3).timeout
	Sunet.reda(SUNET_RAGET, Sunet.VOLUM_EFECTE)  # stereo, cu ecoul camerei: 2D
	t = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "_furie", 1.0, 0.35)
	t.tween_property(self, "_aripi", 0.0, 0.5)
	await get_tree().create_timer(1.6).timeout
	t = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "_furie", 0.0, 0.9)
	t.tween_property(self, "_aripi", 0.4, 1.2)
	await t.finished


## Cât răcnește (0..1), pentru cine vrea să-l țină furios (ex. după replica ta).
func mareste_furia(cat: float, durata: float) -> void:
	create_tween().tween_property(self, "_furie", cat, durata).set_trans(Tween.TRANS_SINE)


## Îl lovește un glonț (Pistol): tresare și îi sare sânge negru cu scântei din rană.
func impuscat(directie: Vector3, punct := Vector3.ZERO) -> void:
	if punct == Vector3.ZERO:
		punct = global_position + Vector3.UP * 1.5
	_lovit = 1.0
	create_tween().tween_property(self, "_lovit", 0.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	Sunet.reda_la(SUNET_LOVIT, punct, Sunet.VOLUM_EFECTE, 0.1)
	var sange := _particule(18, 0.6, 0.05, PackedColorArray([Color(0.3, 0.05, 0.05), Color(0.15, 0.04, 0.05, 0.0)]), false)
	sange.direction = -directie + Vector3.UP * 0.3
	sange.spread = 35.0
	sange.initial_velocity_min = 1.5
	sange.initial_velocity_max = 3.5
	sange.gravity = Vector3(0, -9.8, 0)
	_unic(sange, punct)
	var scantei := _particule(14, 0.5, 0.025, PackedColorArray([Color(1.0, 0.85, 0.5), culoare_jar, Color(culoare_jar, 0.0)]), true)
	scantei.direction = -directie
	scantei.spread = 50.0
	scantei.initial_velocity_min = 2.0
	scantei.initial_velocity_max = 4.5
	scantei.gravity = Vector3(0, -4.0, 0)
	_unic(scantei, punct)


## Se aprinde ca jarul (de la gheare și copite spre trunchi), se zbate, apoi se face scrum și cenușă care cade.
func dezintegreaza() -> void:
	set_deferred("collision_layer", 0)
	Sunet.reda_la(SUNET_DEZINTEGRARE, global_position + Vector3.UP * 1.5, Sunet.VOLUM_EFECTE, 0.0)
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "_agonie", 1.0, 0.3)
	t.tween_property(self, "_aripi", 0.0, 0.4)
	t.tween_property(self, "_tremur", 1.0, 1.5)
	t.tween_method(_incinge, 0.0, 1.0, 1.5)
	t.tween_property(_lumina, "light_color", culoare_jar, 0.6)
	t.tween_property(_lumina, "light_energy", 4.0, 1.5)
	# scânteile care urcă din tot corpul
	var jar := _particule(90, 1.4, 0.04, PackedColorArray([Color(1.0, 0.9, 0.6), culoare_jar, Color(0.5, 0.1, 0.05, 0.0)]), true)
	jar.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	jar.emission_box_extents = Vector3(0.5, 1.1, 0.3)
	jar.direction = Vector3.UP
	jar.spread = 30.0
	jar.initial_velocity_min = 0.4
	jar.initial_velocity_max = 1.6
	jar.gravity = Vector3(0, 1.2, 0)
	jar.preprocess = jar.lifetime  # pornește plin (particulele care n-au pornit fac un pătrat negru în mijloc)
	add_child(jar)
	jar.position = Vector3(0, 1.3, 0.1)
	jar.emitting = true
	await get_tree().create_timer(1.5).timeout
	# se face scrum: dispare pe pixeli, cenușa cade, ultimele scântei zboară
	var cenusa := _particule(70, 2.2, 0.05, PackedColorArray([Color(0.35, 0.32, 0.32), Color(0.2, 0.2, 0.2, 0.0)]), false)
	cenusa.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	cenusa.emission_box_extents = Vector3(0.45, 1.0, 0.3)
	cenusa.direction = Vector3.DOWN
	cenusa.spread = 40.0
	cenusa.initial_velocity_min = 0.1
	cenusa.initial_velocity_max = 0.4
	cenusa.gravity = Vector3(0, -1.5, 0)
	cenusa.preprocess = cenusa.lifetime
	add_child(cenusa)
	cenusa.position = Vector3(0, 1.3, 0.1)
	cenusa.emitting = true
	t = create_tween().set_parallel()
	t.tween_method(func(v: float) -> void: ModelPS2.disparitie(_model, v), 0.0, 1.0, 1.4)
	t.tween_property(_lumina, "light_energy", 0.0, 1.8).set_delay(0.6)
	await get_tree().create_timer(1.0).timeout
	jar.emitting = false
	await get_tree().create_timer(0.4).timeout
	cenusa.emitting = false
	_model.hide()
	_tremur = 0.0
	await get_tree().create_timer(2.2).timeout
	queue_free()


## Dispare într-o clipă: se strânge, un fulger roșu, fumul care se adună spre el și apoi se împrăștie.
func teleporteaza() -> void:
	set_deferred("collision_layer", 0)
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "_furie", 0.35, 0.3)
	t.tween_property(self, "_aripi", 0.0, 0.3)
	t.tween_property(_model, "scale", Vector3(1.05, 0.92, 1.05), 0.35)  # se lasă pe vine, ca un arc
	# fumul se strânge spre el
	var fum := _particule(60, 0.5, 0.18, PackedColorArray([Color(0.1, 0.05, 0.07, 0.0), Color(0.12, 0.05, 0.07, 0.8),
		Color(0.4, 0.06, 0.05, 0.0)]), false)
	fum.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fum.emission_sphere_radius = 1.4
	fum.radial_accel_min = -9.0
	fum.radial_accel_max = -6.0
	fum.gravity = Vector3.ZERO
	fum.preprocess = fum.lifetime
	add_child(fum)
	fum.position = Vector3.UP * 1.2
	fum.emitting = true
	# pocnitura din sunet (la ~0,3 s) cade când dispare
	get_tree().create_timer(0.22).timeout.connect(Sunet.reda_la.bind(SUNET_TELEPORT, global_position + Vector3.UP * 1.3,
		Sunet.VOLUM_EFECTE, 0.0))
	await t.finished
	fum.emitting = false
	# pleacă: întins în sus, subțire, dispare pe pixeli
	_lumina.light_color = Color(1.0, 0.15, 0.1)
	_lumina.light_energy = 9.0
	_lumina.omni_range = 7.0
	t = create_tween().set_parallel().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_property(_model, "scale", Vector3(0.15, 1.7, 0.15), 0.18)
	t.tween_method(func(v: float) -> void: ModelPS2.disparitie(_model, v), 0.0, 1.0, 0.18)
	await t.finished
	_model.hide()
	var bum := _particule(70, 1.6, 0.2, PackedColorArray([Color(0.5, 0.08, 0.06, 0.7), Color(0.12, 0.06, 0.08, 0.5),
		Color(0.1, 0.08, 0.1, 0.0)]), false)
	bum.one_shot = true
	bum.explosiveness = 1.0
	bum.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bum.emission_sphere_radius = 0.4
	bum.spread = 180.0
	bum.initial_velocity_min = 1.0
	bum.initial_velocity_max = 3.0
	bum.damping_min = 2.0
	bum.damping_max = 3.0
	bum.gravity = Vector3(0, 0.3, 0)
	add_child(bum)
	bum.position = Vector3.UP * 1.2
	bum.emitting = true
	create_tween().tween_property(_lumina, "light_energy", 0.0, 0.7).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(2.0).timeout
	queue_free()


## Tot corpul se încinge ca jarul (vezi `incins` în ps2.gdshader).
func _incinge(v: float) -> void:
	var c := Color(culoare_jar, v)
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).set_instance_shader_parameter("incins", c)


## Particule: pătrățele întoarse spre cameră, cu culoarea după viață (`culori`, de la naștere la moarte).
func _particule(cate: int, viata: float, marime: float, culori: PackedColorArray, aditiv: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * marime
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if aditiv:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_fog = true
	quad.material = mat
	p.mesh = quad
	p.amount = cate
	p.lifetime = viata
	p.local_coords = false
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in culori.size():
		offsets.append(float(i) / (culori.size() - 1))
	gradient.offsets = offsets
	gradient.colors = culori
	p.color_ramp = gradient
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## O singură izbucnire de particule în `punct` (în scenă, nu pe el: rămâne acolo după ce dispare).
func _unic(p: CPUParticles3D, punct: Vector3) -> void:
	p.one_shot = true
	p.explosiveness = 1.0
	get_tree().current_scene.add_child(p)
	p.global_position = punct
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.5).timeout.connect(p.queue_free)
