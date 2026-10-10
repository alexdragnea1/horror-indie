extends ChemareDemon
## Ceaunul din camera ta (scenes/dormitor.tscn, nodul `Ceaun`). Folosibil doar cu pisica moartă din conac în inventar
## (`ID_PISICA`, vezi pisica.gd): „[E] Throw the cat in” pornește scena (cu benzi negre, vezi Cutscena):
##   1. faci un pas spre ceaun și arunci pisica înăuntru (pleoscăit, stropi);
##   2. poțiunea se face roșie ca sângele, fierbe tot mai tare, ceaunul se încinge la roșu de jos în sus (`incins` în
##      ps2.gdshader), se zgâlțâie și scoate aburi; tu te dai înapoi lângă pat (`loc_jucator`), cu ochii pe el;
##   3. explodează: bubuitură, fulger, cioburile încinse (`ceaun_spart.glb`) zboară prin cameră ca bucăți fizice și se
##      răcesc, poțiunea stropește tot, fum, lumânările se sting, camera se zguduie, îți țiuie urechile (sunetele se
##      aud înfundat câteva secunde); pe podea rămân arsura și balta roșie;
##   4. pentagrama de pe covor se aprinde roșu, lumânările se reaprind una câte una cu flăcări roșii, un stâlp de lumină
##      și un inel de fum, iar **demonul** (Demon) urcă prin podea pe pentagramă, se uită la tine și răcnește;
##   5. „Demon: There's a special place in hell for people like you.” Apoi, după cum ai sau nu pistol în inventar
##      (roz sau de aur): „You: You're a bitch lmao.” → îl scoți, tragi `gloante` gloanțe în el și se dezintegrează;
##      fără pistol: „You: Kill yourself.” → se teleportează și dispare.
## Marcaje: `marcaj_explodat` (valoarea = unde au rămas cioburile, ca la Continue să fie tot acolo) și `marcaj_demon`
## („dezintegrat” / „teleportat”; după el pentagrama mai mocnește puțin).
## Replicile sunt ale owner-ului; le poate schimba din Inspector.

const CEAUN_SPART := preload("res://models/ceaun_spart.glb")
const SUNET_INCINS := preload("res://sunete/ceaun_incins.ogg")
const SUNET_EXPLOZIE := preload("res://sunete/ceaun_explozie.ogg")
## Înălțimea poțiunii în ceaun (față de podea) și culoarea ei din model (materialul o înmulțește).
const GURA := 0.55
const CULOARE_MODEL_LICHID := Color("61a19f")
## Culoarea obișnuită a lumânărilor (lumanare.tscn), ca să revină după scenă.
const CULOARE_LUMANARE := Color(1.0, 0.68, 0.4)

@export var marcaj_explodat := "ceaunul_a_explodat"
## Cât se încinge până explodează (secunde; sunetul `ceaun_incins` e cam atât de lung).
@export var durata_incingere := 4.0
## Unde te dai înapoi cât se încinge ceaunul și de unde vezi demonul (în camera ta: centrul ei e originea; lângă
## noptieră, la ~2,5 m de pentagramă, ca să-l vezi întreg).
@export var loc_jucator := Vector3(2.2, 0.0, -0.35)
## Culorile: metalul încins, poțiunea care se face roșie, pentagrama aprinsă.
@export var culoare_jar := Color(1.0, 0.3, 0.1)
@export var culoare_potiune := Color(0.8, 0.07, 0.05)
@export var culoare_pentagrama := Color(1.0, 0.12, 0.06)

var _in_curs := false
var _tremur := 0.0
var _timp := 0.0
var _spart: Node3D  # ceaunul spart (după explozie)

@onready var _model: Node3D = $Model
@onready var _lichid: MeshInstance3D = $Model/Lichid
@onready var _lumina: OmniLight3D = $Lumina
@onready var _fierbe: AudioStreamPlayer3D = $Fierbe
@onready var _covor: Node3D = get_parent().get_node("Covor")
@onready var _pentagrama: MeshInstance3D = get_parent().get_node("Covor/Pentagrama")


func _ready() -> void:
	indiciu = "[E] Throw the cat in"
	if Stare.e_marcat(marcaj_explodat):
		_doar_cioburi()
	if Stare.e_marcat(marcaj_demon):
		_pentagrama.set_instance_shader_parameter("incins", Color(culoare_pentagrama, 0.3))


func poate_fi_folosit() -> bool:
	return activ and not _in_curs and not Stare.e_marcat(marcaj_explodat) and Stare.are_obiect(ID_PISICA)


func _process(delta: float) -> void:
	_timp += delta
	if _tremur > 0.0:
		_model.position = Vector3(randf_range(-1.0, 1.0), randf_range(0.0, 0.4), randf_range(-1.0, 1.0)) * 0.014 * _tremur
		_model.rotation = Vector3(sin(_timp * 37.0), 0.0, sin(_timp * 41.0 + 1.0)) * 0.035 * _tremur


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	Stare.scoate_obiect(ID_PISICA)
	var c := Cutscena.porneste(self)
	_jucator = get_tree().get_first_node_in_group("jucator") as CharacterBody3D
	_camera = _jucator.get_node("Cap/Camera3D")
	_jucator.seteaza_purtat(true)
	var gura := global_position + Vector3.UP * GURA
	# un pas spre ceaun, ca să vezi poțiunea
	var dinspre := _jucator.global_position - global_position
	dinspre.y = 0.0
	var loc := global_position + dinspre.normalized() * 1.05
	loc.y = _jucator.global_position.y
	var pas := create_tween().set_trans(Tween.TRANS_SINE)
	pas.tween_property(_jucator, "global_position", loc, 0.6)
	await c.priveste(gura + Vector3.DOWN * 0.1, 0.6)

	# 1. arunci pisica
	await _pisica_in_ceaun(gura)
	await get_tree().create_timer(0.8).timeout

	# 2. se încinge
	await _incinge(c, gura)

	# 3. explodează
	_explodeaza()
	await get_tree().create_timer(2.8).timeout

	# 4. demonul
	var demon := await _cheama_demonul(c)
	await get_tree().create_timer(0.5).timeout

	# 5. ce-i spune și ce-i răspunzi (ChemareDemon)
	await _vorbeste_cu_demonul(c, demon)

	# după: pentagrama se stinge până mai mocnește doar, lumânările revin la flacăra lor
	await _stinge_chemarea()
	_jucator.seteaza_purtat(false)
	_in_curs = false
	await c.opreste()


## Pisica zboară din brațele tale peste buză (ChemareDemon._arunca_pisica) și se scufundă în poțiune.
func _pisica_in_ceaun(gura: Vector3) -> void:
	var sus := gura + Vector3.UP * 0.12
	var pisica := await _arunca_pisica(sus)
	Sunet.reda_la(SUNET_PLESCAIT, gura, Sunet.VOLUM_EFECTE, 0.05, 1.15)
	var stropi := _particule(30, 0.9, 0.05, PackedColorArray([CULOARE_MODEL_LICHID, Color(CULOARE_MODEL_LICHID, 0.0)]), false)
	stropi.direction = Vector3.UP
	stropi.spread = 40.0
	stropi.initial_velocity_min = 1.5
	stropi.initial_velocity_max = 3.0
	stropi.gravity = Vector3(0, -9.8, 0)
	stropi.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	stropi.emission_sphere_radius = 0.15
	_unic(stropi, gura)
	var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(pisica, "global_position", sus + Vector3.DOWN * 0.5, 0.6)
	await t.finished
	pisica.queue_free()


## Poțiunea se înroșește, fierbe tot mai tare, metalul se încinge și se zgâlțâie; tu te dai înapoi.
func _incinge(c: Cutscena, gura: Vector3) -> void:
	Sunet.reda_la(SUNET_INCINS, gura, Sunet.VOLUM_EFECTE, 0.0)
	var mat := (_lichid.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	_lichid.material_override = mat
	var aburi := _particule(36, 1.6, 0.14, PackedColorArray([Color(0.6, 0.55, 0.55, 0.0), Color(0.55, 0.5, 0.5, 0.45),
		Color(0.4, 0.38, 0.38, 0.0)]), false)
	aburi.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	aburi.emission_sphere_radius = 0.2
	aburi.direction = Vector3.UP
	aburi.spread = 15.0
	aburi.initial_velocity_min = 0.4
	aburi.initial_velocity_max = 0.9
	aburi.gravity = Vector3(0, 0.6, 0)
	# pornește plin (particulele care n-au pornit încă fac un pătrat negru în mijlocul poțiunii), dar nevăzut:
	# aburul apare treptat
	aburi.preprocess = aburi.lifetime
	var mat_aburi := (aburi.mesh as QuadMesh).material as StandardMaterial3D
	mat_aburi.albedo_color.a = 0.0
	add_child(aburi)
	aburi.position = Vector3.UP * (GURA + 0.05)
	aburi.emitting = true
	create_tween().tween_property(mat_aburi, "albedo_color:a", 1.0, durata_incingere * 0.4)
	var potiune := Color(culoare_potiune.r / CULOARE_MODEL_LICHID.r, culoare_potiune.g / CULOARE_MODEL_LICHID.g,
		culoare_potiune.b / CULOARE_MODEL_LICHID.b)
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	t.tween_method(func(v: Color) -> void: mat.set_shader_parameter("culoare", v), Color.WHITE, potiune, durata_incingere * 0.4)
	t.tween_method(_incins_ceaun, 0.0, 1.0, durata_incingere).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_lumina, "light_color", culoare_jar, durata_incingere * 0.6)
	t.tween_property(_lumina, "energie_normala", 3.0, durata_incingere)
	t.tween_property(_fierbe, "pitch_scale", 1.9, durata_incingere)
	t.tween_property(_fierbe, "volume_db", _fierbe.volume_db + 12.0, durata_incingere)
	t.tween_property(self, "_tremur", 1.0, durata_incingere).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_property(aburi, "speed_scale", 2.5, durata_incingere)
	# după o clipă îți dai seama ce urmează și te dai înapoi, cu ochii pe el
	await get_tree().create_timer(durata_incingere * 0.3).timeout
	var loc := (get_parent() as Node3D).to_global(loc_jucator)
	loc.y = _jucator.global_position.y
	var pas := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pas.tween_property(_jucator, "global_position", loc, 1.5)
	var pana := Time.get_ticks_msec() + int(durata_incingere * 700.0)
	while Time.get_ticks_msec() < pana:
		await c.priveste(gura, 0.1)
	if t.is_running():  # poate s-a terminat deja (await pe un tween terminat așteaptă la nesfârșit)
		await t.finished
	aburi.emitting = false
	get_tree().create_timer(2.0).timeout.connect(aburi.queue_free)


func _incins_ceaun(v: float) -> void:
	var c := Color(culoare_jar, v)
	for mesh in _model.find_children("*", "MeshInstance3D", true, false):
		if mesh != _lichid:
			(mesh as MeshInstance3D).set_instance_shader_parameter("incins", c)


## Bubuitura: ceaunul întreg dispare, în locul lui cioburile încinse zboară prin cameră.
func _explodeaza() -> void:
	var centru := global_position + Vector3.UP * 0.35
	Sunet.reda(SUNET_EXPLOZIE, Sunet.VOLUM_EFECTE)  # stereo, cu ecoul camerei: 2D
	_tremur = 0.0
	_model.hide()
	$Coliziune.set_deferred("disabled", true)
	_fierbe.stop()
	$Galgait.queue_free()
	# fulgerul
	_lumina.set_process(false)  # nu mai pâlpâie singură (lumina_palpaie)
	_lumina.light_color = Color(1.0, 0.6, 0.3)
	_lumina.light_energy = 14.0
	_lumina.omni_range = 9.0
	var t := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(_lumina, "light_energy", 0.0, 1.1)
	t.tween_callback(_lumina.hide)
	# cioburile
	_spart = _ceaun_spart()
	for corp in _bucati_fizice():
		var spre := corp.global_position - centru
		spre.y = 0.0
		corp.linear_velocity = (spre.normalized() + Vector3.UP * randf_range(0.4, 1.1)).normalized() * randf_range(3.5, 7.5)
		corp.angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 14.0
	# se răcesc încet
	create_tween().tween_method(func(v: float) -> void:
		for mesh in _spart.find_children("*", "MeshInstance3D", true, false):
			if not _e_pe_podea(mesh):
				(mesh as MeshInstance3D).set_instance_shader_parameter("incins", Color(culoare_jar, v)), 1.0, 0.0, 6.0)
	# poțiunea, focul, scânteile, fumul
	var potiune := _particule(90, 1.2, 0.06, PackedColorArray([culoare_potiune, Color(culoare_potiune.darkened(0.4), 0.0)]), false)
	potiune.direction = Vector3.UP
	potiune.spread = 85.0
	potiune.initial_velocity_min = 3.0
	potiune.initial_velocity_max = 7.0
	potiune.gravity = Vector3(0, -9.8, 0)
	_unic(potiune, centru)
	var foc := _particule(60, 0.7, 0.3, PackedColorArray([Color(1.0, 0.9, 0.6, 0.95), Color(1.0, 0.5, 0.2, 0.8),
		Color(0.6, 0.15, 0.08, 0.4), Color(0.2, 0.18, 0.18, 0.0)]), true)
	foc.spread = 180.0
	foc.initial_velocity_min = 1.5
	foc.initial_velocity_max = 4.0
	foc.damping_min = 4.0
	foc.damping_max = 6.0
	foc.gravity = Vector3(0, 1.5, 0)
	_unic(foc, centru)
	var scantei := _particule(50, 1.0, 0.03, PackedColorArray([Color(1.0, 0.85, 0.5), culoare_jar, Color(culoare_jar, 0.0)]), true)
	scantei.spread = 180.0
	scantei.initial_velocity_min = 4.0
	scantei.initial_velocity_max = 10.0
	scantei.gravity = Vector3(0, -7.0, 0)
	_unic(scantei, centru)
	var fum := _particule(55, 4.5, 0.4, PackedColorArray([Color(0.22, 0.2, 0.2, 0.0), Color(0.2, 0.18, 0.18, 0.35),
		Color(0.17, 0.16, 0.16, 0.2), Color(0.15, 0.15, 0.15, 0.0)]), false)
	fum.spread = 180.0
	fum.initial_velocity_min = 0.8
	fum.initial_velocity_max = 2.5
	fum.damping_min = 0.8
	fum.damping_max = 1.4
	fum.gravity = Vector3(0, 0.12, 0)
	fum.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fum.emission_sphere_radius = 0.3
	_unic(fum, centru)
	# lumânările se sting de suflu
	for lumanare in _lumanari():
		lumanare.get_node("Lumina").hide()
		lumanare.get_node("Model/Flacara").hide()
	_zguduie(1.0, 1.2)
	_asurzeste(3.5)
	Stare.marcheaza(marcaj_explodat, {})
	# după ce se liniștesc, ții minte unde au rămas
	await get_tree().create_timer(5.0).timeout
	_tine_minte_cioburile()


## Pentagrama se aprinde, lumânările se reaprind roșii, stâlpul de lumină, inelul de fum, apoi demonul urcă prin podea.
func _cheama_demonul(c: Cutscena) -> Demon:
	var centru := _covor.global_position
	c.priveste(centru + Vector3.UP * 0.2, 1.4)
	Sunet.reda(SUNET_CHEMARE, Sunet.VOLUM_EFECTE)
	var lumina := OmniLight3D.new()
	lumina.name = "LuminaChemare"
	lumina.light_color = culoare_pentagrama
	lumina.light_energy = 0.0
	lumina.omni_range = 5.5
	lumina.shadow_enabled = true
	_covor.add_child(lumina)
	lumina.position = Vector3.UP * 0.35
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	t.tween_method(func(v: float) -> void: _pentagrama.set_instance_shader_parameter("incins", Color(culoare_pentagrama, v)),
		0.0, 1.0, 2.0)
	t.tween_property(lumina, "light_energy", 2.5, 2.0)
	# inelul de fum de pe marginea covorului
	var inel := _particule(50, 2.4, 0.22, PackedColorArray([Color(0.3, 0.06, 0.05, 0.0), Color(0.3, 0.07, 0.06, 0.6),
		Color(0.15, 0.08, 0.09, 0.0)]), false)
	inel.name = "InelFum"
	inel.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	inel.emission_ring_axis = Vector3.UP
	inel.emission_ring_radius = 0.95
	inel.emission_ring_inner_radius = 0.8
	inel.emission_ring_height = 0.05
	inel.direction = Vector3.UP
	inel.spread = 10.0
	inel.initial_velocity_min = 0.2
	inel.initial_velocity_max = 0.5
	inel.gravity = Vector3(0, 0.2, 0)
	inel.preprocess = inel.lifetime  # pornește plin: altfel particulele care n-au pornit încă fac un pătrat negru în mijloc
	_covor.add_child(inel)
	inel.position = Vector3.UP * 0.05
	inel.emitting = true
	# lumânările, una câte una, cu flăcări roșii
	for lumanare in _lumanari():
		await get_tree().create_timer(0.3).timeout
		var l: OmniLight3D = lumanare.get_node("Lumina")
		l.light_color = culoare_pentagrama
		l.show()
		var flacara: MeshInstance3D = lumanare.get_node("Model/Flacara")
		flacara.show()
		flacara.set_instance_shader_parameter("incins", Color(culoare_pentagrama, 1.0))
		Sunet.reda_la(SUNET_LUMANARE, flacara.global_position, Sunet.VOLUM_EFECTE - 8.0, 0.1, 0.8)
	if t.is_running():
		await t.finished
	# stâlpul de lumină până în tavan
	var raza := _stalp_lumina(culoare_pentagrama, 2.95, 0.95)
	_covor.add_child(raza)
	var mat: ShaderMaterial = raza.material_override
	t = create_tween()
	t.tween_method(func(v: float) -> void: mat.set_shader_parameter("putere", v), 0.0, 1.0, 0.25)
	t.tween_method(func(v: float) -> void: mat.set_shader_parameter("putere", v), 1.0, 0.0, 3.0)
	t.tween_callback(raza.queue_free)
	# demonul, cu fața spre tine
	return await _ridica_demonul(c, centru, get_parent())


## După demon: pentagrama mai mocnește, lumina roșie se stinge, lumânările revin la flacăra lor.
func _stinge_chemarea() -> void:
	var lumina := _covor.get_node_or_null("LuminaChemare") as OmniLight3D
	var inel := _covor.get_node_or_null("InelFum") as CPUParticles3D
	if inel:
		inel.emitting = false
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	t.tween_method(func(v: float) -> void: _pentagrama.set_instance_shader_parameter("incins", Color(culoare_pentagrama, v)),
		1.0, 0.3, 2.5)
	if lumina:
		t.tween_property(lumina, "light_energy", 0.0, 2.5)
	for lumanare in _lumanari():
		var flacara: MeshInstance3D = lumanare.get_node("Model/Flacara")
		t.tween_method(func(v: float) -> void: flacara.set_instance_shader_parameter("incins", Color(culoare_pentagrama, v)),
			1.0, 0.0, 2.5)
		t.tween_property(lumanare.get_node("Lumina"), "light_color", CULOARE_LUMANARE, 2.5)
	await t.finished
	if lumina:
		lumina.queue_free()
	if inel:
		get_tree().create_timer(3.0).timeout.connect(inel.queue_free)


# ---------------------------------------------------------------- ceaunul spart

## Ceaunul spart, cu materialul PS2, în locul celui întreg (bucățile stau unde erau în ceaunul întreg).
func _ceaun_spart() -> Node3D:
	var spart := CEAUN_SPART.instantiate() as Node3D
	spart.name = "Spart"
	spart.set_script(SCRIPT_MODEL)
	spart.set("material", MATERIAL)
	add_child(spart)
	return spart


## Arsura și balta stau lipite de podea; restul sunt cioburi.
func _e_pe_podea(mesh: Node) -> bool:
	return String(mesh.name).begins_with("Arsura") or String(mesh.name).begins_with("Balta")


## Face din fiecare ciob un corp fizic (cu forma lui, convexă), pe stratul cadavrelor: jucătorul nu se împiedică de el,
## dar glonțul îl împinge.
func _bucati_fizice() -> Array[RigidBody3D]:
	var corpuri: Array[RigidBody3D] = []
	for mesh in _spart.get_children():
		if not mesh is MeshInstance3D or _e_pe_podea(mesh):
			continue
		var nume := String(mesh.name)
		var corp := RigidBody3D.new()
		corp.collision_layer = Ragdoll.STRAT
		corp.collision_mask = 1
		corp.mass = 1.5
		corp.angular_damp = 1.5
		corp.continuous_cd = true  # bucăți mici și repezi: altfel unele trec prin podea
		_spart.add_child(corp)
		# puțin mai sus: picioarele ating podeaua și ar porni din ea
		corp.global_transform = (mesh as MeshInstance3D).global_transform.translated(Vector3.UP * 0.02)
		var forma := CollisionShape3D.new()
		forma.shape = (mesh as MeshInstance3D).mesh.create_convex_shape()
		corp.add_child(forma)
		mesh.reparent(corp, true)
		corp.name = nume  # abia acum: cât era bucata lângă el, numele era ocupat
		corpuri.append(corp)
	return corpuri


## Unde au rămas cioburile (față de ceaun): în marcaj, ca la Continue să fie tot acolo.
func _tine_minte_cioburile() -> void:
	if not is_instance_valid(_spart):
		return
	var unde := {}
	for corp in _spart.get_children():
		if corp is RigidBody3D:
			var t: Transform3D = _spart.global_transform.affine_inverse() * (corp as RigidBody3D).global_transform
			var e := t.basis.get_euler()
			unde[String(corp.name)] = [t.origin.x, t.origin.y, t.origin.z, e.x, e.y, e.z]
	Stare.marcheaza(marcaj_explodat, unde)


## La Continue (sau la noua zi): ceaunul e spart, cioburile stau pe jos unde au rămas.
func _doar_cioburi() -> void:
	_model.hide()
	$Coliziune.disabled = true
	_fierbe.autoplay = false
	_fierbe.stop()
	$Galgait.queue_free()
	_lumina.hide()
	_lumina.set_process(false)
	_spart = _ceaun_spart()
	var unde: Variant = Stare.valoare_marcaj(marcaj_explodat, {})
	if not unde is Dictionary:
		unde = {}
	for mesh in _spart.get_children():
		if not mesh is MeshInstance3D or _e_pe_podea(mesh):
			continue
		var n := mesh as Node3D
		var v: Array = (unde as Dictionary).get(String(n.name), [])
		# (dacă totuși a căzut prin podea sau a ieșit din cameră, îl punem pe jos lângă arsură)
		if v.size() == 6 and float(v[1]) > -0.1 and absf(float(v[0])) < 5.0 and absf(float(v[2])) < 5.0:
			n.position = Vector3(v[0], v[1], v[2])
			n.rotation = Vector3(v[3], v[4], v[5])
		else:
			# n-a apucat să le țină minte: împrăștiate pe jos, în jurul arsurii
			var spre := Vector3(n.position.x, 0.0, n.position.z).normalized()
			n.position = spre * randf_range(0.6, 1.2) + Vector3.UP * 0.04
			n.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)


# ---------------------------------------------------------------- efecte

func _lumanari() -> Array[Node3D]:
	var lista: Array[Node3D] = []
	for i in range(1, 6):
		var l := get_parent().get_node_or_null("Lumanare%d" % i) as Node3D
		if l:
			lista.append(l)
	return lista


