class_name SabieBlestemata
extends Arma
## Sabia blestemată din piatra din curtea barului URBAN (sabie_piatra.gd, owner 11.10). O ții în dreapta-jos, cu lama în
## sus; pe lamă arde mereu un foc verde (rămâne în urmă când o miști: dâră de foc), runele, ochii craniului și gema
## strălucesc și pulsează, o lumină verde slabă cade pe ce e în jur, iar focul se aude încet.
## Click = combo de trei lovituri „de film” (dacă mai dai click în `timp_combo` secunde după una, urmează următoarea):
##  1. tăietură în diagonală (din dreapta-sus în stânga-jos), 2. tăietură în lateral (din stânga în dreapta),
##  3. izbitura: o ridici peste cap și o trântești în pământ: unda de foc verde lovește tot ce e în `raza_izbitura`.
## Fiecare lăsă în aer un arc de foc verde (`_arc`), camera se apleacă pe direcția tăieturii, FOV-ul „împinge”, iar
## când lovești ceva jocul îngheață o clipă (hit-stop). Damage: 600 pe lovitură la boși (`damage_sabie` în
## lupta_boss.gd); restul (oameni, vrăjitoare, obiecte) mor / se strică dintr-o lovitură, ca la celelalte arme.

const ID := "sabie_blestemata"
const NUME := "Cursed Sword"
const VERDE := Color(0.4, 1.0, 0.32)
const VERDE_ALB := Color(0.82, 1.0, 0.78)
const VERDE_INCHIS := Color(0.08, 0.3, 0.1)
const SUNETE_ATAC := [preload("res://sunete/sabie_atac_1.ogg"), preload("res://sunete/sabie_atac_2.ogg"),
	preload("res://sunete/sabie_atac_3.ogg")]
const SUNET_LOVIT := preload("res://sunete/sabie_lovit.ogg")
const SUNET_BUM := preload("res://sunete/sabie_bum.ogg")
const SUNET_AURA := preload("res://sunete/sabie_aura.ogg")
const SUNET_PERETE := preload("res://sunete/cutit_perete.ogg")
## Lama, în coordonatele modelului: de la gardă la vârf (spre -Z).
const LAMA_DE_LA := Vector3(0, 0, -0.14)
const LAMA_LA := Vector3(0, 0, -1.0)

## Cât ia un boss de la o lovitură (lupta_boss.gd o citește de aici, prin `damage_sabie`).
@export var damage := 600
## Până unde ajunge o tăietură (metri, din ochi) și cât de lată e (radiani, de o parte și de alta a privirii).
@export var bataie := 3.2
@export var latime := 0.4
## Izbitura (a treia lovitură): raza undei de foc și cât de departe în față cade.
@export var raza_izbitura := 3.2
@export var departe_izbitura := 1.9
## În cât timp după o lovitură trebuie să dai click ca să continui combo-ul (altfel o ia de la prima).
@export var timp_combo := 1.0
## Cât îngheață jocul când lovești ceva (secunde reale).
@export var hit_stop := 0.07

static var _mesh_arc: ArrayMesh
static var _mat_rune: StandardMaterial3D

var _pas_combo := 0
var _gata_la := 0.0
var _foc: CPUParticles3D
var _lumina_verde: OmniLight3D
var _aura: AudioStreamPlayer
var _fov_initial := 70.0


func _init() -> void:
	id = ID
	scena = preload("res://models/sabie_blestemata.glb")
	pozitie = Vector3(0.27, -0.36, -0.56)
	rotatie = Vector3(0.88, 0.38, 0.3)
	pozitie_jos = Vector3(0.3, -0.85, -0.3)


## Materialul care strălucește verde (runele, ochii craniului, gema): fără umbre, fără ceață.
static func material_rune() -> StandardMaterial3D:
	if _mat_rune == null:
		_mat_rune = StandardMaterial3D.new()
		_mat_rune.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_rune.albedo_color = VERDE
		_mat_rune.disable_fog = true
	return _mat_rune


## Pune materialul verde pe piesa `Rune` a unui model al sabiei (în mână, în piatră, pe jos).
static func aprinde_rune(model: Node) -> void:
	var rune := model.find_child("Rune", true, false) as MeshInstance3D
	if rune:
		rune.material_override = material_rune()


func _pregateste() -> void:
	aprinde_rune(_model)
	_fov_initial = _camera.fov
	# focul verde de pe lamă: particule în lume (rămân în urmă când miști sabia = dâra de foc)
	_foc = foc_pe_lama(_model, 44, 0.38)
	# lumina verde slabă de pe lamă
	_lumina_verde = OmniLight3D.new()
	_lumina_verde.light_color = VERDE
	_lumina_verde.light_energy = 0.0
	_lumina_verde.omni_range = 3.0
	_lumina_verde.light_volumetric_fog_energy = 0.0
	_lumina_verde.position = (LAMA_DE_LA + LAMA_LA) / 2.0
	_model.add_child(_lumina_verde)
	_aura = AudioStreamPlayer.new()
	_aura.stream = SUNET_AURA
	_aura.volume_db = Sunet.VOLUM_EFECTE - 9.0
	_aura.bus = &"Efecte"
	add_child(_aura)


## Focul verde care arde pe o lamă (`model` = sabia; în mână, în piatră sau cât plutește): particule care urcă și se
## sting, în coordonatele lumii.
static func foc_pe_lama(model: Node3D, cate: int, viata: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.04
	quad.material = Arma.material_particule(true, 0.35)
	p.mesh = quad
	p.amount = cate
	p.lifetime = viata
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.006, 0.02, (LAMA_DE_LA.z - LAMA_LA.z) / 2.0)
	p.position = (LAMA_DE_LA + LAMA_LA) / 2.0
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.gravity = Vector3(0, 2.2, 0)
	p.damping_min = 0.5
	p.damping_max = 1.0
	var curba := Curve.new()
	curba.add_point(Vector2(0.0, 0.5))
	curba.add_point(Vector2(0.25, 1.0))
	curba.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curba
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(VERDE_ALB, 0.9), Color(VERDE, 0.75), Color(VERDE_INCHIS, 0.0)])
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(p)
	return p


func _actualizeaza(_delta: float) -> void:
	var la_vedere := Stare.in_mana == id and _jos < 0.99
	_foc.emitting = la_vedere
	# lumina și runele pulsează (bătăile unei inimi), și se aprind tare cât lovești
	var puls := 0.75 + 0.25 * sin(_timp * 3.1) + 0.12 * sin(_timp * 11.0)
	_lumina_verde.light_energy = (0.9 * puls if la_vedere else 0.0)
	if Stare.in_mana == id:
		material_rune().albedo_color = VERDE * (0.8 + 0.35 * puls)
	if la_vedere and not _aura.playing:
		_aura.play()
	elif not la_vedere and _aura.playing:
		_aura.stop()
	if _pas_combo != 0 and Time.get_ticks_msec() / 1000.0 > _gata_la + timp_combo:
		_pas_combo = 0


func _trage() -> void:
	var pas := _pas_combo
	_pas_combo = (_pas_combo + 1) % 3
	match pas:
		0:
			_taietura(Vector3(0.12, 0.2, 0.08), Vector3(0.45, -0.65, -0.6), Vector3(-0.42, -0.2, -0.16), Vector3(-1.45, 1.1, 1.0),
				deg_to_rad(38.0), false, -0.06)
		1:
			_taietura(Vector3(-0.34, 0.06, 0.04), Vector3(-0.75, 0.95, 1.25), Vector3(0.22, 0.0, -0.18), Vector3(-0.85, -0.8, 1.35),
				deg_to_rad(-8.0), true, 0.05)
		2:
			_izbitura()
	Sunet.reda(SUNETE_ATAC[pas], Sunet.VOLUM_EFECTE - 1.0, 0.08)


## O tăietură: ridicată în `poz0`/`rot0`, trasă până în `poz1`/`rot1`; arcul de foc rotit cu `rulaj` (oglindit dacă
## `spre_dreapta`), capul se apleacă cu `aplecare` radiani pe direcția tăieturii.
func _taietura(poz0: Vector3, rot0: Vector3, poz1: Vector3, rot1: Vector3, rulaj: float, spre_dreapta: bool, aplecare: float) -> void:
	gata = 0.42
	_gata_la = Time.get_ticks_msec() / 1000.0 + gata
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "anim_poz", poz0, 0.11).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "anim_rot", rot0, 0.11)
	t.tween_property(self, "anim_poz", poz1, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "anim_rot", rot1, 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.parallel().tween_callback(_arc.bind(rulaj, spre_dreapta, false)).set_delay(0.02)
	t.parallel().tween_callback(_loveste).set_delay(0.06)
	t.parallel().tween_callback(_impinge_camera.bind(aplecare, 6.0)).set_delay(0.03)
	t.tween_interval(0.07)
	t.tween_property(self, "anim_poz", Vector3.ZERO, 0.3).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "anim_rot", Vector3.ZERO, 0.3)


## A treia lovitură: peste cap, apoi trântită în pământ în fața ta.
func _izbitura() -> void:
	gata = 0.9
	_gata_la = Time.get_ticks_msec() / 1000.0 + gata
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "anim_poz", Vector3(-0.16, 0.24, 0.12), 0.2).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(self, "anim_rot", Vector3(0.75, -0.4, -0.28), 0.2)
	t.tween_interval(0.05)
	t.tween_property(self, "anim_poz", Vector3(-0.2, -0.24, -0.2), 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(self, "anim_rot", Vector3(-2.0, -0.4, -0.28), 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.parallel().tween_callback(_arc.bind(deg_to_rad(80.0), false, true)).set_delay(0.01)
	t.parallel().tween_callback(_impinge_camera.bind(0.0, 10.0)).set_delay(0.03)
	t.tween_callback(_trantit)
	t.tween_interval(0.22)
	t.tween_property(self, "anim_poz", Vector3.ZERO, 0.38).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(self, "anim_rot", Vector3.ZERO, 0.38)


## Capul se apleacă puțin pe direcția tăieturii și FOV-ul se strânge, apoi revin (senzația de „greutate”).
func _impinge_camera(aplecare: float, fov: float) -> void:
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(_camera, "fov", _fov_initial - fov, 0.06).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_cap, "rotation:z", aplecare, 0.08)
	t.tween_property(_camera, "fov", _fov_initial, 0.35).set_ease(Tween.EASE_IN_OUT)
	t.parallel().tween_property(_cap, "rotation:z", 0.0, 0.4)
	_recul_cap(0.0, -aplecare * 0.25)


## Tăietura propriu-zisă: raze pe lățimea ei (de la stânga la dreapta privirii); fiecare țintă o singură dată.
func _loveste() -> void:
	var de_la := _camera.global_position
	var privire := -_camera.global_basis.z
	var deja: Array = []
	var perete := {}
	var lovit_ceva := false
	for i in 7:
		var unghi := lerpf(-latime, latime, i / 6.0)
		var directie := privire.rotated(_camera.global_basis.y, unghi)
		var cerere := PhysicsRayQueryParameters3D.create(de_la, de_la + directie * bataie, 1 | Ragdoll.STRAT)
		cerere.exclude = [_jucator.get_rid()]
		var lovit := get_world_3d().direct_space_state.intersect_ray(cerere)
		if lovit.is_empty():
			continue
		var tinta: Object = lovit.collider
		if tinta in deja:
			continue
		deja.append(tinta)
		if _raneste(tinta, directie, lovit.position):
			lovit_ceva = true
			explozie_verde(self, lovit.position, 0.6)
			Sunet.reda_la(SUNET_LOVIT, lovit.position, Sunet.VOLUM_EFECTE, 0.1)
		elif perete.is_empty():
			perete = lovit
	if lovit_ceva:
		_ingheata()
		Zguduire.porneste(_camera, 0.02, 0.2)
	elif not perete.is_empty():
		Sunet.reda_la(SUNET_PERETE, perete.position, Sunet.VOLUM_EFECTE - 2.0, 0.1)
		explozie_verde(self, perete.position + perete.normal * 0.03, 0.3)


## Lovește `tinta` dacă se poate (boss, om, obiect, cadavru); întoarce true dacă a fost ceva „viu” sau mișcabil.
func _raneste(tinta: Object, directie: Vector3, punct: Vector3) -> bool:
	if tinta.has_method("lovit_de"):
		tinta.lovit_de(id, directie, punct)
	elif tinta.has_method("impuscat"):
		tinta.impuscat(directie, punct)
	elif tinta is RigidBody3D:
		(tinta as RigidBody3D).apply_impulse(directie * 14.0 + Vector3.UP * 4.0, punct - (tinta as RigidBody3D).global_position)
	else:
		return false
	return true


## Izbitura în pământ: unda de foc verde pe sol, coloana de flăcări, pietrele, lumina, zguduitura, și tot ce e în rază
## e lovit (o singură dată).
func _trantit() -> void:
	var fata := -_camera.global_basis.z
	fata.y = 0.0
	fata = fata.normalized() if fata.length() > 0.01 else -_jucator.global_basis.z
	var deasupra := _jucator.global_position + fata * departe_izbitura + Vector3.UP * 1.5
	var cerere := PhysicsRayQueryParameters3D.create(deasupra, deasupra + Vector3.DOWN * 4.0)
	cerere.exclude = [_jucator.get_rid()]
	var jos := get_world_3d().direct_space_state.intersect_ray(cerere)
	var punct: Vector3 = jos.position if not jos.is_empty() else _jucator.global_position + fata * departe_izbitura
	Sunet.reda(SUNET_BUM, Sunet.VOLUM_EFECTE, 0.05)
	Zguduire.porneste(_camera, 0.06, 0.55)
	unda_verde(self, punct, raza_izbitura)
	explozie_verde(self, punct + Vector3.UP * 0.1, 1.6)
	# tot ce e în rază
	var forma := SphereShape3D.new()
	forma.radius = raza_izbitura
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = forma
	q.transform = Transform3D(Basis(), punct + Vector3.UP * 0.8)
	q.collision_mask = 1 | Ragdoll.STRAT
	q.exclude = [_jucator.get_rid()]
	var deja: Array = []
	var lovit_ceva := false
	for r in get_world_3d().direct_space_state.intersect_shape(q, 64):
		var tinta: Object = r.collider
		if tinta in deja or tinta is StaticBody3D and not (tinta.has_method("lovit_de") or tinta.has_method("impuscat")):
			continue
		deja.append(tinta)
		var poz: Vector3 = (tinta as Node3D).global_position if tinta is Node3D else punct
		var directie := poz - punct
		directie.y = 0.0
		directie = directie.normalized() if directie.length() > 0.01 else fata
		if _raneste(tinta, directie, poz + Vector3.UP * 0.9):
			lovit_ceva = true
	if lovit_ceva:
		_ingheata(1.6)


## Hit-stop: jocul aproape se oprește o clipă (timp real), apoi merge mai departe.
func _ingheata(cat := 1.0) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.05
	# legat de Engine, nu de sabie: dacă sabia dispare între timp (altă scenă), timpul tot revine
	get_tree().create_timer(hit_stop * cat, true, false, true).timeout.connect(Engine.set_time_scale.bind(1.0))


## Arcul de foc lăsat în aer de tăietură: un semicerc în fața ta (în planul tăieturii), aprins la capătul din față și
## stins spre coadă, care se rotește puțin pe direcția tăieturii și se stinge în 0,22 s.
func _arc(rulaj: float, spre_dreapta: bool, mare: bool) -> void:
	var arc := MeshInstance3D.new()
	arc.mesh = mesh_arc()
	arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# amestec normal, nu aditiv: pe ceața gri de zi, aditivul ieșea alb-spălăcit
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_fog = true
	arc.material_override = mat
	_camera.add_child(arc)
	# sub privire (și, la izbitură, într-o parte): un arc la nivelul ochilor s-ar vedea din profil, ca o linie subțire
	arc.position = Vector3(0.32, -0.15, 0.15) if mare else Vector3(0.0, -0.35, 0.15)
	arc.rotation = Vector3(0.0, 0.0, rulaj)
	var s := 1.25 if mare else 1.0
	arc.scale = Vector3(-s if spre_dreapta else s, s, s)
	var sens := -1.0 if spre_dreapta else 1.0
	var t := arc.create_tween().set_parallel()
	t.tween_property(arc, "rotation:y", sens * 0.35, 0.22).as_relative()
	t.tween_property(mat, "albedo_color:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(arc.queue_free)


## Plasa arcului (o singură dată): o bandă pe un sfert de cerc mai lat (de la -80° la +80° în fața camerei, în planul XZ),
## de la raza 0,75 la 1,7. Culoarea: transparent înăuntru, alb-verde aproape de margine, verde la margine; capătul din
## stânga (-80°) e cel aprins, coada (+80°) stinsă.
static func mesh_arc() -> ArrayMesh:
	if _mesh_arc != null:
		return _mesh_arc
	var raze: Array[float] = [0.75, 1.2, 1.5, 1.62, 1.72]
	var alfa_raze: Array[float] = [0.0, 0.7, 0.95, 0.9, 0.0]
	var culori_raze: Array[Color] = [VERDE_INCHIS, VERDE, VERDE_ALB, VERDE, VERDE_INCHIS]
	var pasi := 24
	var v := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	for i in pasi + 1:
		var u := i / float(pasi)
		var unghi := deg_to_rad(lerpf(-80.0, 80.0, u))
		var aprins := pow(1.0 - u, 1.6)
		for k in raze.size():
			var r := raze[k]
			v.append(Vector3(sin(unghi) * r, 0.0, -cos(unghi) * r))
			c.append(Color(culori_raze[k], alfa_raze[k] * aprins))
	var n := raze.size()
	for i in pasi:
		for k in n - 1:
			var a := i * n + k
			var b := (i + 1) * n + k
			idx.append_array([a, b, a + 1, a + 1, b, b + 1])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_INDEX] = idx
	_mesh_arc = ArrayMesh.new()
	_mesh_arc.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return _mesh_arc


## Explozie de foc verde în `punct` (lovitura în cineva, sabia smulsă din piatră): flăcări care țâșnesc în toate
## părțile, scântei, o lumină care se stinge. `marime` 1 = cât un om.
static func explozie_verde(nod: Node, punct: Vector3, marime := 1.0) -> void:
	var lume := nod.get_tree().current_scene
	var flacari := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.22 * marime
	quad.material = Arma.material_particule(true, 0.6)
	flacari.mesh = quad
	flacari.amount = int(26 * clampf(marime, 0.5, 2.0))
	flacari.lifetime = 0.55
	flacari.one_shot = true
	flacari.explosiveness = 0.95
	flacari.local_coords = false
	flacari.direction = Vector3.UP
	flacari.spread = 180.0
	flacari.initial_velocity_min = 1.0 * marime
	flacari.initial_velocity_max = 3.2 * marime
	flacari.damping_min = 3.0
	flacari.damping_max = 5.0
	flacari.gravity = Vector3(0, 2.5, 0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(VERDE_ALB, 1.0), Color(VERDE, 0.85), Color(VERDE_INCHIS, 0.0)])
	flacari.color_ramp = g
	var curba := Curve.new()
	curba.add_point(Vector2(0.0, 0.6))
	curba.add_point(Vector2(0.3, 1.0))
	curba.add_point(Vector2(1.0, 0.1))
	flacari.scale_amount_curve = curba
	flacari.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lume.add_child(flacari)
	flacari.global_position = punct
	flacari.emitting = true
	var scantei := CPUParticles3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2.ONE * 0.035
	q2.material = Arma.material_particule(true)
	scantei.mesh = q2
	scantei.amount = int(18 * clampf(marime, 0.5, 2.0))
	scantei.lifetime = 0.7
	scantei.one_shot = true
	scantei.explosiveness = 1.0
	scantei.local_coords = false
	scantei.spread = 180.0
	scantei.initial_velocity_min = 3.0 * marime
	scantei.initial_velocity_max = 6.0 * marime
	scantei.gravity = Vector3(0, -6.0, 0)
	scantei.color = VERDE_ALB
	scantei.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lume.add_child(scantei)
	scantei.global_position = punct
	scantei.emitting = true
	var lumina := OmniLight3D.new()
	lumina.light_color = VERDE
	lumina.light_energy = 4.0 * marime
	lumina.omni_range = 4.0 * marime
	lumina.light_volumetric_fog_energy = 0.0
	lume.add_child(lumina)
	lumina.global_position = punct + Vector3.UP * 0.2
	var t := lumina.create_tween()
	t.tween_property(lumina, "light_energy", 0.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	nod.get_tree().create_timer(1.2).timeout.connect(func() -> void:
		for x: Node in [flacari, scantei, lumina]:
			if is_instance_valid(x):
				x.queue_free())


## Unda de foc verde care fuge pe pământ din `punct` până la `raza` (izbitura, piatra care crapă): un inel plat care
## crește și se stinge, cu flăcări care țâșnesc de pe marginea lui.
static func unda_verde(nod: Node, punct: Vector3, raza: float) -> void:
	var lume := nod.get_tree().current_scene
	var inel := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.88
	tor.outer_radius = 1.0
	tor.rings = 24
	tor.ring_segments = 4
	inel.mesh = tor
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(VERDE, 0.85)
	mat.disable_fog = true
	inel.material_override = mat
	inel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lume.add_child(inel)
	inel.global_position = punct + Vector3.UP * 0.06
	inel.scale = Vector3(0.2, 0.15, 0.2)
	var t := inel.create_tween().set_parallel()
	t.tween_property(inel, "scale", Vector3(raza, 0.6, raza), 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.5).set_delay(0.1)
	t.chain().tween_callback(inel.queue_free)
	# flăcările de pe margine: un cerc de particule care țâșnesc în sus și spre afară
	var foc := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.3
	quad.material = Arma.material_particule(true, 0.8)
	foc.mesh = quad
	foc.amount = 60
	foc.lifetime = 0.6
	foc.one_shot = true
	foc.explosiveness = 1.0
	foc.local_coords = false
	foc.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	foc.emission_ring_axis = Vector3.UP
	foc.emission_ring_radius = raza * 0.35
	foc.emission_ring_inner_radius = raza * 0.25
	foc.emission_ring_height = 0.05
	foc.direction = Vector3.UP
	foc.spread = 35.0
	foc.initial_velocity_min = 2.0
	foc.initial_velocity_max = 5.0
	foc.radial_accel_min = 6.0
	foc.radial_accel_max = 10.0
	foc.damping_min = 2.0
	foc.damping_max = 3.0
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	g.colors = PackedColorArray([Color(VERDE_ALB, 1.0), Color(VERDE, 0.8), Color(VERDE_INCHIS, 0.0)])
	foc.color_ramp = g
	foc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lume.add_child(foc)
	foc.global_position = punct + Vector3.UP * 0.1
	foc.emitting = true
	# pietrele și bulgării de pământ care sar
	var pietre := CPUParticles3D.new()
	var cub := BoxMesh.new()
	cub.size = Vector3.ONE * 0.07
	var mp := StandardMaterial3D.new()
	mp.albedo_color = Color("48313b")
	cub.material = mp
	pietre.mesh = cub
	pietre.amount = 16
	pietre.lifetime = 1.0
	pietre.one_shot = true
	pietre.explosiveness = 1.0
	pietre.local_coords = false
	pietre.direction = Vector3.UP
	pietre.spread = 45.0
	pietre.initial_velocity_min = 3.0
	pietre.initial_velocity_max = 6.0
	pietre.gravity = Vector3(0, -12.0, 0)
	pietre.angular_velocity_min = -400.0
	pietre.angular_velocity_max = 400.0
	pietre.scale_amount_min = 0.5
	pietre.scale_amount_max = 1.3
	lume.add_child(pietre)
	pietre.global_position = punct + Vector3.UP * 0.1
	pietre.emitting = true
	nod.get_tree().create_timer(1.6).timeout.connect(func() -> void:
		for x: Node in [foc, pietre]:
			if is_instance_valid(x):
				x.queue_free())
