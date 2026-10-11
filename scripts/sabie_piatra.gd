extends Interactabil
## Sabia din piatră din curtea barului URBAN (bar.tscn, nodul `SabiePiatra`; ajungi pe ușa „EMPLOYEES ONLY”), owner 11.10.
## La E: „???: Are you worthy?” cu Yes / Nah (Nah = nimic). La Yes te apropii, pui mâinile pe mâner și ai `timp_limita`
## secunde să dai click (spam) până umpli bara: fiecare click o ridică puțin (`putere_click`), dar bara scade singură
## (`scadere` pe secundă). Nu reușești → sabia alunecă la loc („???: Pathetic.”); poți încerca de câte ori vrei.
## Reușești → scena „de film”: sabia e smulsă cu o explozie de foc verde, piatra crapă, cerul se întunecă și se face
## verde, sabia plutește deasupra pietrei și se întoarce cu vârful în sus, focul verde o cuprinde, runele se aprind, corul
## fantomelor, flacăra mare, apoi zboară în mâna ta. Intră în inventar („Cursed Sword”, SabieBlestemata) și o ții în mână.
## Marcaj: `marcaj` (după el, piatra rămâne goală, cu fum verde din fantă).

const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")
const MODEL_SABIE := preload("res://models/sabie_blestemata.glb")
const MODEL_PUMN := preload("res://models/pumn_jucator.glb")
const SUNET_TRAGE := preload("res://sunete/sabie_trage.ogg")
const SUNET_CADE := preload("res://sunete/sabie_cade.ogg")
const SUNET_SCOASA := preload("res://sunete/sabie_scoasa.ogg")
const SUNET_BLESTEM := preload("res://sunete/sabie_blestem.ogg")
const SUNET_PRINS := preload("res://sunete/corp_luat.ogg")
const SUNET_INIMA := preload("res://sunete/inima_rapida.ogg")
const VERDE := SabieBlestemata.VERDE
const PIATRA_STINSA := Color(0.16, 0.19, 0.19)

@export var marcaj := "a_scos_sabia"
@export var replica_intrebare := "???: Are you worthy?"
@export var optiune_da := "Yes"
@export var optiune_nu := "Nah"
@export_multiline var replici_esec: PackedStringArray = ["???: Pathetic."]
@export_multiline var replici_succes: PackedStringArray = ["???: Finally... a worthy vessel.", "You: Cool. Free sword."]
@export_group("Minijocul")
## Câte secunde ai ca să o scoți.
@export var timp_limita := 6.0
## Cât umple bara un click (1 = plină).
@export var putere_click := 0.05
## Cât scade bara singură, pe secundă.
@export var scadere := 0.1
@export_group("Locuri")
## Unde stă mânerul (de la originea pietrei, în sus) și unde stai tu când tragi (în fața pietrei, spre +Z).
@export var inaltime_maner := 1.35
@export var departare_jucator := 0.72

var _in_curs := false
var _sabie: Node3D        # nodul care se mișcă: modelul sabiei + mâinile
var _model_sabie: Node3D
var _maini: Array[Node3D] = []
var _mat_crapaturi: StandardMaterial3D
var _fum: CPUParticles3D
var _minijoc := false
var _progres := 0.0
var _reusit := false
var _tremur := Vector3.ZERO
var _ui: CanvasLayer
var _bara: ColorRect
var _bara_timp: ColorRect
var _text: Label
var _inima: AudioStreamPlayer


func _ready() -> void:
	indiciu = "[E] Pull the sword"
	_sabie = Node3D.new()
	_sabie.name = "Sabie"
	add_child(_sabie)
	_sabie.position = Vector3(0, inaltime_maner, 0)
	_model_sabie = _model(MODEL_SABIE, _sabie)
	# lama în jos (-Z al modelului spre -Y), craniul de pe gardă spre tine (+Z)
	_model_sabie.basis = Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0))
	SabieBlestemata.aprinde_rune(_model_sabie)
	for k in 2:
		var mana := _model(MODEL_PUMN, _sabie)
		mana.position = Vector3(0, 0.045, 0) if k == 0 else Vector3(0, -0.055, 0)
		if k == 1:
			mana.scale = Vector3(-1, 1, 1)  # mâna stângă = dreapta oglindită
		mana.visible = false
		_maini.append(mana)
	# crăpăturile pietrei: stinse până tragi
	var crap := find_child("Crapaturi", true, false) as MeshInstance3D
	if crap:
		_mat_crapaturi = StandardMaterial3D.new()
		_mat_crapaturi.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_crapaturi.albedo_color = PIATRA_STINSA
		crap.material_override = _mat_crapaturi
	if Stare.e_marcat(marcaj):
		_sabie.visible = false
		_crapaturi(0.35)
		_porneste_fum()


func _model(scena: PackedScene, parinte: Node3D) -> Node3D:
	var m := scena.instantiate() as Node3D
	m.set_script(SCRIPT_MODEL)
	m.set("material", MATERIAL)
	parinte.add_child(m)
	return m


func poate_fi_folosit() -> bool:
	return activ and not _in_curs and not Stare.e_marcat(marcaj)


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	if Stare.obiecte.size() >= Stare.LOCURI_INVENTAR:
		Dialog.spune(PackedStringArray(["You: My hands are full."]))
		return
	_in_curs = true
	var ales := await Dialog.intreaba(replica_intrebare, PackedStringArray([optiune_da, optiune_nu]))
	if ales == 0:
		await _incearca()
	_in_curs = false


func _jucator() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("jucator") as CharacterBody3D


# ---------------------------------------------------------------- minijocul

func _incearca() -> void:
	while Dialog.activ:
		await get_tree().process_frame
	var jucator := _jucator()
	var c := Cutscena.porneste(self)
	jucator.seteaza_purtat(true)
	# te apropii: în fața pietrei, cu fața spre ea
	var loc := global_position + global_basis.z * departare_jucator
	loc.y = jucator.global_position.y
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(jucator, "global_position", loc, 0.6)
	await c.priveste(_sabie.global_position + Vector3(0, -0.05, 0), 0.6)
	# pui mâinile pe mâner
	Sunet.reda_la(SUNET_PRINS, _sabie.global_position, Sunet.VOLUM_EFECTE - 4.0, 0.05)
	for m in _maini:
		m.visible = true
	await get_tree().create_timer(0.35).timeout
	# minijocul
	_fa_ui()
	_progres = 0.0
	_reusit = false
	var ramas := timp_limita
	_inima = AudioStreamPlayer.new()
	_inima.stream = SUNET_INIMA
	_inima.volume_db = Sunet.VOLUM_EFECTE - 30.0
	_inima.bus = &"Efecte"
	add_child(_inima)
	_inima.play()
	var camera := jucator.get_node("Cap/Camera3D") as Camera3D
	var fov := camera.fov
	_minijoc = true
	while ramas > 0.0 and not _reusit:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		ramas -= dt
		_progres = maxf(_progres - scadere * dt, 0.0)
		_tremur = _tremur.lerp(Vector3.ZERO, clampf(dt * 14.0, 0.0, 1.0))
		_sabie.position = Vector3(0, inaltime_maner + _progres * 0.2, 0) + _tremur * (0.4 + _progres)
		_crapaturi(_progres)
		camera.fov = lerpf(fov, fov - 10.0, _progres)
		_inima.volume_db = lerpf(Sunet.VOLUM_EFECTE - 30.0, Sunet.VOLUM_EFECTE - 4.0, _progres)
		_bara.size.x = 200.0 * _progres
		_bara_timp.size.x = 200.0 * ramas / timp_limita
		_text.scale = _text.scale.lerp(Vector2.ONE, clampf(dt * 10.0, 0.0, 1.0))
	_minijoc = false
	_inima.queue_free()
	_ui.queue_free()
	camera.fov = fov
	if _reusit:
		await _succes(c, jucator)
	else:
		await _esec(c, jucator)


func _input(event: InputEvent) -> void:
	if not _minijoc or not event.is_action_pressed("trage"):
		return
	get_viewport().set_input_as_handled()
	_progres = minf(_progres + putere_click, 1.0)
	if _progres >= 1.0:
		_reusit = true
	_tremur = Vector3(randf_range(-0.02, 0.02), randf_range(0.0, 0.025), randf_range(-0.02, 0.02))
	Sunet.reda_la(SUNET_TRAGE, _sabie.global_position, Sunet.VOLUM_EFECTE - 2.0, 0.08, 0.85 + _progres * 0.4)
	Zguduire.porneste(_jucator().get_node("Cap/Camera3D") as Camera3D, 0.004 + _progres * 0.012, 0.12)
	_text.scale = Vector2.ONE * 1.25
	_praf(_progres > 0.45)


## Bara: textul „SPAM [LMB]!” care sare la fiecare click, bara verde (cât ai tras) și bara subțire a timpului.
func _fa_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 11
	add_child(_ui)
	var jos := Control.new()
	jos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jos.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	jos.position.y -= 58.0
	_ui.add_child(jos)
	_text = Label.new()
	_text.text = "SPAM [LMB]!"
	_text.add_theme_font_size_override("font_size", 16)
	_text.add_theme_color_override("font_color", Color("83b3b0"))
	_text.add_theme_color_override("font_shadow_color", Color("262d2fe6"))
	_text.add_theme_constant_override("shadow_offset_x", 1)
	_text.add_theme_constant_override("shadow_offset_y", 1)
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.size = Vector2(200, 22)
	_text.position = Vector2(-100, -26)
	_text.pivot_offset = Vector2(100, 11)
	jos.add_child(_text)
	var fundal := ColorRect.new()
	fundal.color = Color("262d2f")
	fundal.position = Vector2(-102, 0)
	fundal.size = Vector2(204, 10)
	jos.add_child(fundal)
	_bara = ColorRect.new()
	_bara.color = Color("61a19f")
	_bara.position = Vector2(-100, 2)
	_bara.size = Vector2(0, 6)
	jos.add_child(_bara)
	_bara_timp = ColorRect.new()
	_bara_timp.color = Color("a18463")
	_bara_timp.position = Vector2(-100, 13)
	_bara_timp.size = Vector2(200, 2)
	jos.add_child(_bara_timp)


## Crăpăturile pietrei: de la stinse (0) la verde aprins (1).
func _crapaturi(k: float) -> void:
	if _mat_crapaturi:
		_mat_crapaturi.albedo_color = PIATRA_STINSA.lerp(VERDE, clampf(k, 0.0, 1.0))


## Praful din fantă la fiecare click (și scântei verzi după jumătate).
func _praf(cu_scantei: bool) -> void:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.05
	quad.material = Arma.material_particule(cu_scantei)
	p.mesh = quad
	p.amount = 8
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.gravity = Vector3(0, -4.0, 0)
	p.color = VERDE if cu_scantei else Color("70706e")
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(p)
	p.global_position = _fanta()
	p.emitting = true
	get_tree().create_timer(0.8).timeout.connect(p.queue_free)


## Unde intră lama în piatră (vârful pietrei, sub mâner).
func _fanta() -> Vector3:
	return global_position + Vector3(0, 0.87, 0)


func _esec(c: Cutscena, jucator: CharacterBody3D) -> void:
	# alunecă la loc, cu bufnitură și praf
	var t := create_tween()
	t.tween_property(_sabie, "position", Vector3(0, inaltime_maner, 0), 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.1).timeout
	Sunet.reda_la(SUNET_CADE, _sabie.global_position, Sunet.VOLUM_EFECTE, 0.05)
	Zguduire.porneste(jucator.get_node("Cap/Camera3D") as Camera3D, 0.03, 0.35)
	_praf(false)
	_praf(false)
	var stingere := create_tween()
	stingere.tween_method(_crapaturi, _progres, 0.0, 0.6)
	await get_tree().create_timer(0.4).timeout
	for m in _maini:
		m.visible = false
	Dialog.spune(replici_esec)
	await Dialog.terminat
	await _termina(c, jucator)


## Gata scena: te dă puțin înapoi de lângă piatră (ca să nu rămâi în coliziunea ei) și îți dă controlul.
func _termina(c: Cutscena, jucator: CharacterBody3D) -> void:
	var inapoi := global_position + global_basis.z * (departare_jucator + 0.35)
	inapoi.y = jucator.global_position.y
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(jucator, "global_position", inapoi, 0.4)
	await t.finished
	c.opreste()
	jucator.seteaza_purtat(false)


# ---------------------------------------------------------------- scena „de film”

func _succes(c: Cutscena, jucator: CharacterBody3D) -> void:
	Stare.marcheaza(marcaj)
	var camera := jucator.get_node("Cap/Camera3D") as Camera3D
	var cer := _cerul()
	# 1. smulsă: explozia de foc verde din piatră, unda pe pământ, piatra crapă de tot, ecranul albit, ești împins înapoi
	Sunet.reda(SUNET_SCOASA, Sunet.VOLUM_EFECTE, 0.0)
	_crapaturi(1.0)
	SabieBlestemata.explozie_verde(self, _fanta(), 1.8)
	SabieBlestemata.unda_verde(self, _fanta() + Vector3.DOWN * 0.8, 4.0)
	Zguduire.porneste(camera, 0.09, 0.9)
	_fulger_ecran(Color(0.82, 1.0, 0.78), 0.85, 0.6)
	for m in _maini:
		m.visible = false
	var sus := Vector3(0, inaltime_maner + 0.95, 0)
	var t := create_tween()
	t.tween_property(_sabie, "position", sus, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var inapoi := global_position + global_basis.z * (departare_jucator + 0.55)
	inapoi.y = jucator.global_position.y
	var t2 := create_tween()
	t2.tween_property(jucator, "global_position", inapoi, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_tween_cer(cer, 1.0, 1.4)
	# te uiți după ea abia după ce te-a împins (altfel unghiul e socotit de unde erai și sabia iese jos din cadru)
	await t2.finished
	c.priveste(global_position + sus + Vector3(0, 0.15, 0), 0.5)
	# 2. plutește deasupra pietrei și se întoarce cu vârful în sus; focul verde o cuprinde, lumina pulsează
	await get_tree().create_timer(0.15).timeout
	Sunet.reda(SUNET_BLESTEM, Sunet.VOLUM_EFECTE, 0.0)
	var foc := SabieBlestemata.foc_pe_lama(_model_sabie, 90, 0.9)
	(foc.mesh as QuadMesh).size = Vector2.ONE * 0.12
	var lumina := OmniLight3D.new()
	lumina.light_color = VERDE
	lumina.light_energy = 0.0
	lumina.omni_range = 9.0
	lumina.shadow_enabled = true
	lumina.light_volumetric_fog_energy = 0.5
	_sabie.add_child(lumina)
	var vartej := _vartej()
	var rot := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rot.tween_property(_sabie, "rotation:x", PI, 1.3)        # vârful în sus
	rot.tween_property(_sabie, "rotation:y", TAU, 2.6).set_delay(1.0)  # apoi se rotește încet în jurul ei
	rot.tween_property(lumina, "light_energy", 3.5, 1.5)
	rot.tween_property(_sabie, "position:y", sus.y + 0.25, 3.6)
	var puls := create_tween().set_loops(8)
	puls.tween_method(_rune, 0.6, 1.6, 0.22)
	puls.tween_method(_rune, 1.6, 0.9, 0.23)
	await get_tree().create_timer(3.75).timeout
	# 3. flacăra mare (odată cu sunetul de la 4,2 s): explozie, fulger verde, zguduire
	SabieBlestemata.explozie_verde(self, _sabie.global_position, 2.2)
	_fulger_ecran(VERDE, 0.6, 0.5)
	Zguduire.porneste(camera, 0.05, 0.6)
	var f := create_tween()
	f.tween_property(lumina, "light_energy", 8.0, 0.08)
	f.tween_property(lumina, "light_energy", 3.0, 0.5)
	await get_tree().create_timer(0.9).timeout
	# 4. zboară în mâna ta
	var tinta := camera.global_transform * Vector3(0.25, -0.32, -0.6)
	var zbor := create_tween().set_parallel()
	zbor.tween_property(_sabie, "global_position", tinta, 0.3).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	zbor.tween_property(_sabie, "scale", Vector3.ONE * 0.6, 0.3)
	await zbor.finished
	_fulger_ecran(Color(0.82, 1.0, 0.78), 0.7, 0.45)
	Zguduire.porneste(camera, 0.03, 0.3)
	_sabie.visible = false
	lumina.queue_free()
	vartej.emitting = false
	_rune(1.0)
	Stare.adauga_obiect(SabieBlestemata.ID, SabieBlestemata.NUME)
	Stare.tine_in_mana(SabieBlestemata.ID)
	Arma.in_scena = true  # o vezi în mână cât mai ține scena
	_tween_cer(cer, 0.0, 2.5)
	_porneste_fum()
	var stins := create_tween()
	stins.tween_method(_crapaturi, 1.0, 0.35, 2.0)
	await get_tree().create_timer(1.0).timeout
	Dialog.spune(replici_succes)
	await Dialog.terminat
	Arma.in_scena = false
	vartej.queue_free()
	await _termina(c, jucator)


func _rune(k: float) -> void:
	SabieBlestemata.material_rune().albedo_color = VERDE * k


## Vârtejul de foc verde din jurul sabiei care plutește (particule pe un inel, care urcă și se rotesc).
func _vartej() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.09
	quad.material = Arma.material_particule(true, 0.6)
	p.mesh = quad
	p.amount = 110
	p.lifetime = 1.3
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.9
	p.emission_ring_inner_radius = 0.6
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 10.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.2
	p.gravity = Vector3.ZERO
	p.tangential_accel_min = 3.0
	p.tangential_accel_max = 5.0
	p.radial_accel_min = -1.2
	p.radial_accel_max = -0.6
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(SabieBlestemata.VERDE_ALB, 0.0), Color(VERDE, 0.8), Color(SabieBlestemata.VERDE_INCHIS, 0.0)])
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	p.position = Vector3(0, inaltime_maner + 0.9, 0)
	return p


## Fumul verde care iese din fanta goală, după ce ai scos sabia (și la fiecare intrare în scenă de atunci).
func _porneste_fum() -> void:
	if _fum:
		return
	_fum = CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.16
	quad.material = Arma.material_particule(false)
	_fum.mesh = quad
	_fum.amount = 14
	_fum.lifetime = 2.6
	_fum.local_coords = false
	_fum.direction = Vector3.UP
	_fum.spread = 12.0
	_fum.initial_velocity_min = 0.15
	_fum.initial_velocity_max = 0.35
	_fum.gravity = Vector3(0.05, 0.12, 0)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	g.colors = PackedColorArray([Color(VERDE, 0.0), Color(VERDE, 0.35), Color(0.2, 0.3, 0.22, 0.0)])
	_fum.color_ramp = g
	var curba := Curve.new()
	curba.add_point(Vector2(0.0, 0.4))
	curba.add_point(Vector2(1.0, 1.0))
	_fum.scale_amount_curve = curba
	_fum.scale_amount_min = 1.0
	_fum.scale_amount_max = 1.6
	_fum.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fum)
	_fum.position = Vector3(0, 0.9, 0)


## Un fulger colorat pe tot ecranul, care se stinge.
func _fulger_ecran(culoare: Color, cat: float, durata: float) -> void:
	var strat := CanvasLayer.new()
	strat.layer = 8
	var r := ColorRect.new()
	r.color = Color(culoare, cat)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	strat.add_child(r)
	get_tree().current_scene.add_child(strat)
	var t := strat.create_tween()
	t.tween_property(r, "color:a", 0.0, durata).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(strat.queue_free)


## Cerul și lumina scenei, ca să le poți face verzi-întunecate (k = 1) și apoi înapoi (k = 0): [mediul, soarele,
## culorile de la început].
func _cerul() -> Array:
	var scena := get_tree().current_scene
	var mediu := scena.find_child("Mediu", false, false) as WorldEnvironment
	var soare := scena.find_child("Soare", false, false) as DirectionalLight3D
	if mediu == null or mediu.environment == null:
		return []
	var e := mediu.environment
	return [e, soare, e.background_color, e.ambient_light_color, e.ambient_light_energy, e.fog_light_color,
		soare.light_energy if soare else 0.0]


func _tween_cer(cer: Array, k: float, durata: float) -> void:
	if cer.is_empty():
		return
	var e := cer[0] as Environment
	var soare := cer[1] as DirectionalLight3D
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	t.tween_property(e, "background_color", (cer[2] as Color).lerp(Color(0.05, 0.12, 0.07), k), durata)
	t.tween_property(e, "ambient_light_color", (cer[3] as Color).lerp(Color(0.3, 0.6, 0.35), k), durata)
	t.tween_property(e, "ambient_light_energy", lerpf(cer[4], 0.35, k), durata)
	t.tween_property(e, "fog_light_color", (cer[5] as Color).lerp(Color(0.08, 0.2, 0.1), k), durata)
	if soare:
		t.tween_property(soare, "light_energy", lerpf(cer[6], 0.1, k), durata)
