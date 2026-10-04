extends Personaj
## Head Witch: șefa coven-ului din fundul văii (scenes/coven.tscn). Te așteaptă lângă cercul de vrăjitoare.
##  - Prima conversație: `replici` (ultima e „Here.”: își ridică brațul cu pistolul roz în mână), apoi pistolul
##    trece la tine (în inventar și în mâna ta, vezi Pistol) și urmează `replici_pistol`. Primești `sarcina_noua`
##    și marcajul `marcaj_dupa` (după el bețivul nu mai vorbește cu tine).
##  - Până faci vraja (cazan.gd) n-are ce să-ți spună: nu se poate vorbi cu ea.
##  - După vrajă (`marcaj_vraja`): `replici_acasa`, apoi scoate o mătură, se urcă pe ea, tu te urci în spatele ei
##    și decolați. La `dupa_decolare` secunde de la decolare: ecran negru și te trezești în fața blocului
##    (`scena_acasa`; marcajul `marcaj_zbor`, vezi intoarcere_acasa.gd).

@export_multiline var replici_pistol: PackedStringArray = []
@export var marcaj_vraja := "vraja_facuta"
@export_multiline var replici_acasa: PackedStringArray = []
@export var marcaj_zbor := "a_zburat_acasa"
## La câte secunde de la decolare se face negru.
@export var dupa_decolare := 3.0
@export_file("*.tscn") var scena_acasa := "res://scenes/afara_bloc.tscn"
@export_multiline var titlu_acasa := "Block M7, Entrance B\n1:13 AM"
## Brațul drept al modelului (originea în umăr): ține pistolul, scoate mătura.
@export var brat: Node3D
## Cât își ridică brațul ca să-ți dea pistolul (radiani pe X; minus = înainte).
@export var ridicare_brat := -1.35
@export var model_pistol: PackedScene
@export var model_matura: PackedScene
## La ce înălțime plutește mătura (cât șoldul ei) și unde stați pe ea, de la mijlocul cozii (metri): ea în față
## (`loc_ea` înainte), tu în spatele ei (`loc_tu` înapoi), puțin într-o parte, ca să vezi pe lângă ea.
@export var inaltime_matura := 0.88
@export var loc_ea := 0.35
@export var loc_tu := 0.5

const MATERIAL := preload("res://shaders/material_model.tres")
const MATERIAL_ROZ := preload("res://shaders/material_roz.tres")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const SUNET_PISTOL := preload("res://sunete/pistol_primit.ogg")
const SUNET_MATURA := preload("res://sunete/matura_scoasa.ogg")
const SUNET_DECOLARE := preload("res://sunete/zbor_decolare.ogg")
const SUNET_VANT := preload("res://sunete/vant.ogg")
const SUNET_ATERIZARE := preload("res://sunete/corp_cazut.ogg")
## Mâna dreaptă, față de umăr (brațul atârnă; vezi vrajitoare_sefa() în tools/blender/coven.py).
const MANA := Vector3(-0.025, -0.58, 0.05)

## Cât zburați, ea și tu stați pe mătură (poziția față de mătură e ținută aici).
var _matura: Node3D
var _pe_matura := false
var _ea_pe_matura := Vector3.ZERO
var _tu_pe_matura := Vector3.ZERO
var _tremur := 0.0


func poate_fi_folosit() -> bool:
	if not super():
		return false
	if Stare.e_marcat(marcaj_zbor):
		return false
	return not Stare.e_marcat(marcaj_dupa) or Stare.e_marcat(marcaj_vraja)


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_vorbeste = true
	folosit.emit()
	intoarce_spre(_jucator())
	if not Stare.e_marcat(marcaj_dupa):
		await _da_pistolul()
		_vorbeste = false
	else:
		await _zbor_acasa()


func _da_pistolul() -> void:
	var inainte := replici.slice(0, replici.size() - 1)
	Dialog.spune(inainte)
	if Dialog.activ:
		await Dialog.terminat
	# „Here.”: scoate pistolul și ți-l întinde
	var pistol := _pistol_in_mana()
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(brat, "rotation:x", ridicare_brat, 0.6)
	Dialog.spune(replici.slice(replici.size() - 1))
	if Dialog.activ:
		await Dialog.terminat
	# îl iei: zboară din mâna ei în a ta, iar replicile merg mai departe
	_ia_pistolul(pistol)
	Dialog.spune(replici_pistol)
	if Dialog.activ:
		await Dialog.terminat
	_a_vorbit = true
	Stare.marcheaza(marcaj_dupa)
	if sarcina_noua != "":
		Stare.seteaza_sarcina(sarcina_noua)


## Pistolul în mâna ei, culcat, cu țeava spre stânga ei (în dreapta ta), ca să-l vezi bine când îl întinde.
func _pistol_in_mana() -> Node3D:
	var pistol := model_pistol.instantiate() as Node3D
	pistol.set_script(SCRIPT_MODEL)
	pistol.set("material", MATERIAL_ROZ)
	pistol.set("stralucitoare", PackedStringArray(["Strasuri"]))
	brat.add_child(pistol)
	# orientarea dorită când brațul e ridicat (în coordonatele modelului), adusă în coordonatele brațului
	var ridicat := Basis(Vector3.RIGHT, ridicare_brat)
	pistol.basis = ridicat.inverse() * Basis(Vector3.UP, -PI / 2.0)
	pistol.position = MANA + Vector3(0.0, -0.02, 0.03)
	pistol.scale = Vector3.ONE * 0.01
	create_tween().tween_property(pistol, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return pistol


func _ia_pistolul(pistol: Node3D) -> void:
	var jucator := _jucator()
	Sunet.reda(SUNET_PISTOL, Sunet.VOLUM_EFECTE, 0.03)
	var camera: Camera3D = jucator.get_node("Cap/Camera3D")
	var start := pistol.global_position
	var tween := create_tween()
	tween.tween_method(func(t: float) -> void:
		var tinta := camera.global_position - camera.global_basis.z * 0.35 + camera.global_basis.x * 0.15 - camera.global_basis.y * 0.15
		pistol.global_position = start.lerp(tinta, t), 0.0, 1.0, 0.35).set_trans(Tween.TRANS_SINE)
	await tween.finished
	pistol.queue_free()
	Stare.adauga_obiect(Pistol.ID, "Pink pistol")
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(brat, "rotation:x", 0.0, 0.8)


func _zbor_acasa() -> void:
	Dialog.spune(replici_acasa)
	if Dialog.activ:
		await Dialog.terminat
	var jucator := _jucator() as CharacterBody3D
	var c := Cutscena.porneste(self)
	var cap: Node3D = jucator.get_node("Cap")
	var camera: Camera3D = cap.get_node("Camera3D")
	# direcția zborului: dinspre tine spre ea (tu stai în spatele ei)
	var d := global_position - jucator.global_position
	d.y = 0.0
	d = d.normalized() if d.length() > 0.01 else global_transform.basis.z
	var sol := global_position.y

	# 1. scoate mătura: îi apare în mână, în picioare, cu un fum mov
	var bratul := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bratul.tween_property(brat, "rotation", Vector3(-0.5, 0.0, -0.6), 0.45)
	await bratul.finished
	_matura = model_matura.instantiate() as Node3D
	_matura.set_script(SCRIPT_MODEL)
	_matura.set("material", MATERIAL)
	get_tree().current_scene.add_child(_matura)
	var mana := brat.global_transform * MANA
	_matura.global_position = mana + Vector3.UP * 0.25
	_matura.global_basis = Basis(Vector3.RIGHT, PI / 2.0).rotated(Vector3.UP, rotation.y)  # coada în sus, paiele jos
	_matura.scale = Vector3.ONE * 0.05
	Sunet.reda_la(SUNET_MATURA, mana, Sunet.VOLUM_EFECTE, 0.05)
	_fum(mana)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_matura, "scale", Vector3.ONE, 0.35)
	await get_tree().create_timer(0.6).timeout

	# 2. se întoarce cu spatele la tine; mătura se culcă în aer, de-a lungul zborului, cât șoldul ei
	var unghi := atan2(d.x, d.z)
	var mijloc := Vector3(global_position.x, sol + inaltime_matura, global_position.z) - d * loc_ea
	var culcata := Basis.looking_at(d, Vector3.UP)  # coada (-Z a măturii) înainte
	tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation:y", rotation.y + angle_difference(rotation.y, unghi), 0.7)
	tween.tween_property(_matura, "global_position", mijloc, 0.8)
	var q_start := _matura.global_basis.get_rotation_quaternion()
	var q_culcata := culcata.get_rotation_quaternion()
	tween.tween_method(func(t: float) -> void: _matura.global_basis = Basis(q_start.slerp(q_culcata, t)), 0.0, 1.0, 0.8)
	tween.tween_property(brat, "rotation", Vector3(-0.45, 0.0, 0.0), 0.8)
	await tween.finished

	# 3. se urcă pe ea (sare puțin), apoi tu te așezi în spatele ei
	tween = create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "global_position:y", sol + 0.3, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position:y", sol + 0.12, 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	jucator.seteaza_purtat(true)
	var loc := mijloc - d * loc_tu + d.cross(Vector3.UP) * 0.28
	var ochi := 0.68  # cât de sus îți sunt ochii deasupra cozii, așezat (te uiți pe lângă umărul ei)
	var tinta_jucator := Vector3(loc.x, loc.y + ochi - cap.position.y, loc.z)
	tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(jucator, "global_position", tinta_jucator, 1.0)
	# te uiți puțin în dreapta și în jos: o vezi pe ea într-o parte, coada măturii și pământul de sub voi
	c.roteste(atan2(-d.x, -d.z) - 0.4, -0.55, 1.0)
	await tween.finished
	_ea_pe_matura = _matura.to_local(global_position)
	_tu_pe_matura = _matura.to_local(jucator.global_position)
	_pe_matura = true

	# 4. plutește o clipă, apoi decolați
	tween = create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_matura, "global_position:y", mijloc.y + 0.12, 0.45)
	tween.tween_property(_matura, "global_position:y", mijloc.y - 0.05, 0.4)
	await tween.finished
	Sunet.reda(SUNET_DECOLARE, Sunet.VOLUM_EFECTE)
	var vant := AudioStreamPlayer.new()
	vant.stream = SUNET_VANT
	vant.bus = &"Efecte"
	vant.volume_db = -30.0
	add_child(vant)
	vant.play()
	create_tween().tween_property(vant, "volume_db", Sunet.VOLUM_EFECTE, 2.0)
	var fov := camera.fov
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(camera, "fov", fov + 12.0, 2.5)
	# ieșiți din ceața văii: se rărește și apar stelele (atmosfera pădurii se oprește cât zburați)
	var scena := get_tree().current_scene
	var atmosfera := scena.find_child("Atmosfera", false)
	if atmosfera:
		atmosfera.set_process(false)
	for mediu: WorldEnvironment in scena.find_children("*", "WorldEnvironment", false):
		var cer := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
		cer.tween_property(mediu.environment, "fog_density", 0.012, 2.5).set_delay(0.6)
		cer.tween_property(mediu.environment, "fog_sky_affect", 0.0, 2.5).set_delay(0.6)
		cer.tween_property(mediu.environment, "ambient_light_energy", 0.4, 2.5).set_delay(0.6)
	# la decolare ridici privirea: vezi cum urcați peste copaci, spre cer
	c.roteste(atan2(-d.x, -d.z) - 0.25, 0.1, 2.5)
	var start := _matura.global_position
	var baza := _matura.global_basis
	tween = create_tween()
	tween.tween_method(func(t: float) -> void:
		# întâi sare drept în sus, apoi o ia înainte și tot mai sus, tot mai repede
		var sus := 1.6 * ease(minf(t / 0.7, 1.0), 0.4) + maxf(t - 0.5, 0.0) * maxf(t - 0.5, 0.0) * 3.5 + maxf(t - 0.5, 0.0) * 3.0
		var inainte := maxf(t - 0.4, 0.0) * maxf(t - 0.4, 0.0) * 3.0
		_matura.global_position = start + Vector3.UP * sus + d * inainte
		# vârful cozii se ridică la decolare
		_matura.global_basis = baza * Basis(Vector3.RIGHT, minf(t * 0.25, 0.3))
		_tremur = clampf(t * 0.6, 0.0, 1.0), 0.0, dupa_decolare + 2.0, dupa_decolare + 2.0)
	await get_tree().create_timer(dupa_decolare).timeout

	# 5. ecran negru: te trezești în fața blocului (pe negru: vântul, apoi o bufnitură — ai aterizat)
	Stare.marcheaza(marcaj_zbor)
	Stare.meniu_deschis = false
	var sunete: Array[AudioStream] = [SUNET_ATERIZARE]
	Tranzitie.mergi_la(scena_acasa, titlu_acasa, sunete)


func _process(delta: float) -> void:
	super(delta)
	if not _pe_matura or not is_instance_valid(_matura):
		return
	# ea și tu stați pe mătură oriunde ar zbura; capul ți se zgâlțâie puțin în vânt
	global_position = _matura.to_global(_ea_pe_matura)
	var jucator := _jucator()
	if jucator:
		jucator.global_position = _matura.to_global(_tu_pe_matura)
		var camera: Camera3D = jucator.get_node("Cap/Camera3D")
		camera.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * 0.006 * _tremur
		camera.rotation.z = sin(Time.get_ticks_msec() * 0.003) * 0.03 * _tremur


## Un fum mov când îi apare mătura în mână.
func _fum(unde: Vector3) -> void:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.12
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat
	p.mesh = quad
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.75, 0.5, 0.95, 0.9), Color(0.4, 0.3, 0.5, 0.0)])
	p.color_ramp = gradient
	p.one_shot = true
	p.amount = 24
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.0
	p.gravity = Vector3(0, 0.4, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2
	get_tree().current_scene.add_child(p)
	p.global_position = unde
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)
