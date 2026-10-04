extends "res://scripts/sefa_vrajitoare.gd"
## Head Witch în fața scării blocului, dimineața (afara_bloc.tscn, nodul `HeadWitchZi`): te așteaptă după ce ți-a zis
## în bucătărie să-ți iei mătura (`marcaj_necesar`). Când ieși din bloc pornește singură scena (cu `Cutscena`):
##  - cu mătura în inventar (matura_camera.gd): `replici_cu_matura`, o pui jos, scântei, mătura tresare de trei ori și
##    nu zboară (vraja „defectă”), `replici_dupa_incercare` (pe „put a cap” scoți pistolul), apoi mătura se
##    teleportează acasă (iese din inventar, apare la loc în cameră);
##  - fără mătură: `replici_fara_matura`, „I got this glock.” (scoți pistolul), `replici_fara_matura_final`;
##  - apoi pleacă: scoate mătura ei, se urcă și zboară peste copaci, topindu-se pe pixeli (ModelPS2.disparitie), cu o
##    dâră de scântei mov; după asta `replici_final` („I hate this bitch.”) și `marcaj_gata`.
## Înainte (sau după) nu e aici. Replicile sunt ale owner-ului: nu le corecta.

@export var marcaj_dimineata := "e_dimineata"
@export var marcaj_necesar := "a_vorbit_cu_sefa_acasa"
@export var marcaj_gata := "antrenament_cu_matura"

@export_group("Replici")
@export_multiline var replici_cu_matura: PackedStringArray = []
## Prima e spusă înainte să scoți pistolul, restul după.
@export_multiline var replici_dupa_incercare: PackedStringArray = []
@export_multiline var replici_fara_matura: PackedStringArray = []
@export_multiline var replici_glock: PackedStringArray = []
@export_multiline var replici_fara_matura_final: PackedStringArray = []
@export_multiline var replici_final: PackedStringArray = []
## Debifat = „I hate this bitch.” doar când pleacă fără să fi încercat mătura.
@export var final_si_cu_matura := true

@export_group("Antrenament")
## Mătura ta (cea din cameră) și cât de departe de tine o pui jos.
@export var model_matura_ta: PackedScene
@export var distanta_matura := 1.05
@export var sunet_pus_jos: AudioStream
@export var sunet_scantei: AudioStream
@export var sunet_esuat: AudioStream
## Cât zboară până dispare de tot (secunde).
@export var durata_plecare := 4.5

const ID_MATURA := "matura"

var _matura_ta: Node3D
var _privit: Node3D
var _calare := false


func _ready() -> void:
	super()
	var jucator := _jucator()
	if jucator == null or not Stare.e_marcat(marcaj_dimineata) or not Stare.e_marcat(marcaj_necesar) \
			or Stare.e_marcat(marcaj_gata):
		queue_free()
		return
	await get_tree().process_frame
	while Tranzitie.activa:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	await _antrenament()


func poate_fi_folosit() -> bool:
	return false


# dacă scena se întrerupe (meniul principal), pistolul nu rămâne „la vedere” / înclinat
func _exit_tree() -> void:
	ObiectInMana.in_scena = false
	Pistol.in_scena = false
	Pistol.inclinare = 0.0


func _antrenament() -> void:
	_vorbeste = true
	var c := Cutscena.porneste(self)
	var jucator := _jucator() as CharacterBody3D
	jucator.velocity = Vector3.ZERO
	await c.priveste(cap.global_position, 0.8)
	var a_incercat := Stare.are_obiect(ID_MATURA)
	if a_incercat:
		await _cu_matura(c)
	else:
		await _fara_matura()
	await _pleaca(c)
	if final_si_cu_matura or not a_incercat:
		await _spune(replici_final)
	Stare.marcheaza(marcaj_gata)
	Stare.seteaza_sarcina("")
	Pistol.in_scena = false
	Pistol.inclinare = 0.0
	c.opreste()
	queue_free()


func _cu_matura(c: Cutscena) -> void:
	await _spune(replici_cu_matura)
	var jucator := _jucator()
	var cap_jucator: Node3D = jucator.get_node("Cap")
	var inaltime_ochi := cap_jucator.position.y
	# o iei în mână
	ObiectInMana.in_scena = true
	Stare.tine_in_mana(ID_MATURA)
	await get_tree().create_timer(1.1).timeout
	# te apleci și o pui jos între tine și ea, culcată de-a curmezișul
	var d := global_position - jucator.global_position
	d.y = 0.0
	d = d.normalized()
	var de_a_lungul := d.cross(Vector3.UP).normalized()
	var punct := jucator.global_position + d * distanta_matura
	punct.y = jucator.global_position.y
	var culcata := Basis(de_a_lungul.cross(Vector3.UP), de_a_lungul, Vector3.UP)
	var origine := punct - de_a_lungul * 0.75 + Vector3.UP * 0.08
	Stare.tine_in_mana("")
	var din_mana := Transform3D(Basis(), cap_jucator.global_position)
	for nod in jucator.get_node("Cap/Camera3D").get_children():
		if nod is ObiectInMana:
			din_mana = (nod as ObiectInMana).scoate_acum()
	ObiectInMana.in_scena = false
	_matura_ta = model_matura_ta.instantiate() as Node3D
	_matura_ta.set_script(SCRIPT_MODEL)
	_matura_ta.set("material", MATERIAL)
	get_tree().current_scene.add_child(_matura_ta)
	_matura_ta.global_transform = din_mana
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cap_jucator, "position:y", inaltime_ochi - 0.55, 0.9)
	tween.tween_property(_matura_ta, "global_position", origine, 0.9)
	var q0 := din_mana.basis.get_rotation_quaternion()
	var q1 := culcata.get_rotation_quaternion()
	tween.tween_method(func(t: float) -> void: _matura_ta.global_basis = Basis(q0.slerp(q1, t)), 0.0, 1.0, 0.9)
	c.priveste(punct, 0.9)
	await tween.finished
	Sunet.reda_la(sunet_pus_jos, punct, Sunet.VOLUM_EFECTE, 0.05, 1.3)
	await get_tree().create_timer(0.35).timeout
	# te ridici, cu ochii pe ea
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(cap_jucator, "position:y", inaltime_ochi, 0.8)
	c.priveste(punct + Vector3.UP * (inaltime_ochi * 0.25), 0.8)
	await tween.finished
	await get_tree().create_timer(0.7).timeout

	# trei încercări: scântei, mătura tresare tot mai tare... și cade la loc
	var centru := punct + Vector3.UP * 0.1
	for incercare in 3:
		var putere := 0.5 + incercare * 0.35
		_scantei(centru, putere)
		Sunet.reda_la(sunet_scantei, centru, Sunet.VOLUM_EFECTE, 0.05, 1.0 + incercare * 0.08)
		var sus := 0.04 + incercare * 0.07
		tween = create_tween().set_trans(Tween.TRANS_SINE)
		tween.tween_property(_matura_ta, "global_position:y", origine.y + sus, 0.18).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(_matura_ta, "global_basis", culcata.rotated(d, randf_range(-0.12, 0.12) * putere), 0.18)
		if incercare == 2:
			# ultima: rămâne o clipă în aer, tremură... și cade
			tween.tween_method(func(t: float) -> void:
				_matura_ta.global_position = Vector3(origine.x, origine.y + sus, origine.z) + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.012 * t, 0.0, 1.0, 0.8)
		tween.tween_property(_matura_ta, "global_position", origine, 0.16).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(_matura_ta, "global_basis", culcata, 0.16)
		await tween.finished
		Sunet.reda_la(sunet_pus_jos, punct, Sunet.VOLUM_EFECTE, 0.05, 1.1 + incercare * 0.1)
		await get_tree().create_timer(0.75 if incercare < 2 else 0.2).timeout
	# vraja se dezumflă: un fum gri și o ultimă scânteie
	Sunet.reda_la(sunet_esuat, centru, Sunet.VOLUM_EFECTE, 0.0)
	_fum_culoare(centru, Color(0.55, 0.55, 0.55, 0.8), 14, 0.5)
	await get_tree().create_timer(0.9).timeout
	_scantei(centru, 0.15)
	await get_tree().create_timer(0.8).timeout

	await c.priveste(cap.global_position, 0.7)
	await _spune(replici_dupa_incercare.slice(0, 1))
	# „If you talk more shit...”: scoți pistolul
	_scoate_pistolul()
	await _spune(replici_dupa_incercare.slice(1))
	# mătura se teleportează acasă (iese din inventar; matura_camera.gd o pune la loc pe perete)
	Sunet.reda_la(SUNET_MATURA, centru, Sunet.VOLUM_EFECTE, 0.05, 1.2)
	_fum(centru)
	var matura := _matura_ta
	create_tween().tween_method(func(v: float) -> void: ModelPS2.disparitie(matura, v), 0.0, 1.0, 0.5)
	Stare.scoate_obiect(ID_MATURA)
	await get_tree().create_timer(0.6).timeout
	matura.queue_free()


func _fara_matura() -> void:
	await _spune(replici_fara_matura)
	# „I got this glock.”: îl scoți și îl întorci pe o parte; fără pistol (aruncat, pe raft) replica asta se sare
	if Stare.are_obiect(Pistol.ID):
		_scoate_pistolul()
		await get_tree().create_timer(0.45).timeout
		Pistol.inclinare = 1.25
		await _spune(replici_glock)
		Pistol.inclinare = 0.0
	await _spune(replici_fara_matura_final)


## Scoate pistolul roz (dacă îl ai).
func _scoate_pistolul() -> void:
	if Stare.are_obiect(Pistol.ID):
		Stare.tine_in_mana(Pistol.ID)
		Pistol.in_scena = true


## Pleacă: scoate mătura ei, se urcă pe ea și zboară peste copaci, topindu-se în aer.
func _pleaca(c: Cutscena) -> void:
	var jucator := _jucator()
	var d := global_position - jucator.global_position
	d.y = 0.0
	d = d.normalized()
	# zboară pe lângă tine (în dreapta ta și puțin în față), ca s-o vezi din profil: drept de la tine ai vedea doar
	# paiele măturii, ca un soare
	d = (d.cross(Vector3.UP) * 0.85 + d * 0.5).normalized()
	var sol := global_position.y
	# 1. mătura îi apare în mână, cu fum mov
	var bratul := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bratul.tween_property(brat, "rotation", Vector3(-0.5, 0.0, -0.6), 0.45)
	await bratul.finished
	_matura = model_matura.instantiate() as Node3D
	_matura.set_script(SCRIPT_MODEL)
	_matura.set("material", MATERIAL)
	get_tree().current_scene.add_child(_matura)
	var mana := brat.global_transform * MANA
	_matura.global_position = mana + Vector3.UP * 0.25
	_matura.global_basis = Basis(Vector3.RIGHT, PI / 2.0).rotated(Vector3.UP, rotation.y)
	_matura.scale = Vector3.ONE * 0.05
	Sunet.reda_la(SUNET_MATURA, mana, Sunet.VOLUM_EFECTE, 0.05)
	_fum(mana)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_matura, "scale", Vector3.ONE, 0.35)
	await get_tree().create_timer(0.6).timeout
	# 2. se întoarce în direcția zborului; mătura se culcă în aer, cât șoldul ei
	var unghi := atan2(d.x, d.z)
	var mijloc := Vector3(global_position.x, sol + inaltime_matura, global_position.z) - d * loc_ea
	var culcata := Basis.looking_at(d, Vector3.UP)
	tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation:y", rotation.y + angle_difference(rotation.y, unghi), 0.7)
	tween.tween_property(_matura, "global_position", mijloc, 0.8)
	var q0 := _matura.global_basis.get_rotation_quaternion()
	var q1 := culcata.get_rotation_quaternion()
	tween.tween_method(func(t: float) -> void: _matura.global_basis = Basis(q0.slerp(q1, t)), 0.0, 1.0, 0.8)
	tween.tween_property(brat, "rotation", Vector3(-0.45, 0.0, 0.0), 0.8)
	await tween.finished
	# 3. se urcă (sare puțin) și plutește o clipă
	tween = create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "global_position:y", sol + 0.3, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position:y", sol + 0.12, 0.25).set_ease(Tween.EASE_IN)
	await tween.finished
	_ea_pe_matura = _matura.to_local(global_position)
	_calare = true
	tween = create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_matura, "global_position:y", mijloc.y + 0.12, 0.45)
	tween.tween_property(_matura, "global_position:y", mijloc.y - 0.05, 0.4)
	await tween.finished
	# 4. decolează: drept în sus, apoi peste copaci; camera se uită după ea, ea se topește pe pixeli
	Sunet.reda_la(SUNET_DECOLARE, _matura.global_position, Sunet.VOLUM_EFECTE)
	_dara()
	_privit = self
	var start := _matura.global_position
	var baza := _matura.global_basis
	var model := get_node("Model")
	var matura := _matura
	tween = create_tween()
	tween.tween_method(func(t: float) -> void:
		var x := t * 2.2
		var dupa := maxf(x - 0.3, 0.0)
		var sus := 1.2 * ease(minf(x / 0.6, 1.0), 0.4) + dupa * 1.8 + dupa * dupa * 1.2
		var inainte := dupa * 2.0 + dupa * dupa * 5.0
		matura.global_position = start + Vector3.UP * sus + d * inainte
		matura.global_basis = baza * Basis(Vector3.RIGHT, minf(x * 0.25, 0.3))
		# se topește în a doua jumătate a zborului
		var topit := clampf((t - 0.3) / 0.55, 0.0, 1.0)
		ModelPS2.disparitie(model, topit)
		ModelPS2.disparitie(matura, topit), 0.0, 1.0, durata_plecare)
	await tween.finished
	_calare = false
	_privit = null
	matura.queue_free()
	hide()
	_dezactiveaza_coliziunea()
	await get_tree().create_timer(0.6).timeout
	await c.roteste(_jucator().rotation.y, 0.0, 0.8)


func _process(delta: float) -> void:
	super(delta)
	if _calare and is_instance_valid(_matura):
		global_position = _matura.to_global(_ea_pe_matura)
	if _privit:
		# camera o urmărește lin cât zboară
		var jucator := _jucator()
		var cap_jucator: Node3D = jucator.get_node("Cap")
		var de := _privit.global_position + Vector3.UP * 0.8 - cap_jucator.global_position
		var unghi := atan2(-de.x, -de.z)
		var sus := clampf(atan2(de.y, Vector2(de.x, de.z).length()), deg_to_rad(-85), deg_to_rad(85))
		var k := 1.0 - exp(-delta * 3.0)
		jucator.rotation.y = lerp_angle(jucator.rotation.y, unghi, k)
		cap_jucator.rotation.x = lerpf(cap_jucator.rotation.x, sus, k)


func _spune(replici_de_spus: PackedStringArray) -> void:
	if replici_de_spus.is_empty():
		return
	Dialog.spune(replici_de_spus)
	if Dialog.activ:
		await Dialog.terminat


## Scântei mov-verzi care sar din mătură (vraja care încearcă să prindă) și o clipă de lumină.
func _scantei(unde: Vector3, putere: float) -> void:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.06
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_fog = true
	quad.material = mat
	p.mesh = quad
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.85, 0.45, 1.0), Color(0.45, 1.0, 0.6), Color(0.3, 0.1, 0.45, 0.0)])
	p.color_ramp = gradient
	p.one_shot = true
	p.amount = int(8 + 30 * putere)
	p.lifetime = 0.6
	p.explosiveness = 0.85
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.8 * putere
	p.initial_velocity_max = 2.6 * putere
	p.gravity = Vector3(0, -6.0, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.4, 0.04, 0.4)
	get_tree().current_scene.add_child(p)
	p.global_position = unde
	p.emitting = true
	var lumina := OmniLight3D.new()
	lumina.light_color = Color(0.8, 0.55, 1.0)
	lumina.light_energy = 1.6 * putere
	lumina.omni_range = 3.5
	get_tree().current_scene.add_child(lumina)
	lumina.global_position = unde + Vector3.UP * 0.3
	var tween := lumina.create_tween()
	tween.tween_property(lumina, "light_energy", 0.0, 0.35)
	tween.tween_callback(lumina.queue_free)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


## Un pufăit de fum de o culoare dată (gri = vraja s-a dezumflat).
func _fum_culoare(unde: Vector3, culoare: Color, cate: int, raza: float) -> void:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.14
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat
	p.mesh = quad
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([culoare, Color(culoare.r, culoare.g, culoare.b, 0.0)])
	p.color_ramp = gradient
	p.one_shot = true
	p.amount = cate
	p.lifetime = 1.4
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 40.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.5
	p.gravity = Vector3(0, 0.35, 0)
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(raza, 0.05, raza)
	get_tree().current_scene.add_child(p)
	p.global_position = unde
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


## Dâra de scântei mov din spatele măturii cât zboară.
func _dara() -> void:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.05
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_fog = true
	quad.material = mat
	p.mesh = quad
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.9, 0.65, 1.0), Color(0.45, 0.25, 0.6, 0.0)])
	p.color_ramp = gradient
	p.amount = 40
	p.lifetime = 0.9
	p.local_coords = false
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.3
	p.gravity = Vector3(0, -0.6, 0)
	_matura.add_child(p)
	# la paie (capătul din spate al măturii; coada e spre -Z)
	p.position = Vector3(0, 0, 0.75)
	p.emitting = true
