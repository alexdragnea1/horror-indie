class_name ScutJucator
extends Node3D
## Scutul tău (magie defensivă, te învață Head Witch la apus, sefa_apus.gd): după `MARCAJ`, tasta "scut" (Ctrl)
## ridică o sferă mov în jurul tău (același shader ca scutul ei de la conac, shaders/scut.gdshader).
## Prima dată ești începător (ca la Fireball, când focul nu ți-a ieșit din prima): te încordezi (camera tremură, scântei
## mov se adună în fața ta), îți scapă o dată, apoi scutul apare tremurat, pâlpâie, se umflă ca o gelatină și la sfârșit
## se sparge (crăpăturile din shader nu se folosesc: din interior ies dale uriașe). De a doua oară îți iese curat
## (owner: „să meargă bine de fiecare dată după ce l-ai învățat”): un puls scurt, scutul se deschide rotund și stabil,
## ține `durata` secunde și se stinge lin. După aceea mai poți abia după `pauza` secunde (owner: 2 s); dacă apeși
## înainte, ies doar câteva scântei și se stinge.
## Până la prima folosire, jos pe ecran scrie „Press Ctrl to use shield” (cu tasta aleasă în setări).
## Îl pune jucator.gd pe jucător (nu pe cameră). `activ` / `lovit()` sunt pentru vrăjile de mai târziu.

const MARCAJ := "a_invatat_scutul"
const MARCAJ_FOLOSIT := "a_folosit_scutul"
## Pus de Tom Berone, boschetarul din fața magazinului de băuturi (boschetar.gd), când îi dai bani: pauza scade la
## PAUZA_IMBUNATATITA (owner 11.10: „îți face o vrajă să ai shield-ul la o secundă”).
const MARCAJ_IMBUNATATIT := "scutul_imbunatatit_de_tom"
const PAUZA_IMBUNATATITA := 1.0
const SHADER := preload("res://shaders/scut.gdshader")
const SUNET_SCUT := preload("res://sunete/scut.ogg")
const SUNET_SPART := preload("res://sunete/scut_spart.ogg")
const SUNET_ESUAT := preload("res://sunete/vraja_esuata.ogg")
const SUNET_SCANTEI := preload("res://sunete/scantei_matura.ogg")
## Mov, ca scutul lui Head Witch (din paleta jocului, luminat).
const CULOARE := Color(0.7, 0.42, 1.0)

## Adevărat cât scutul e ridicat (o vrajă / un glonț de mai târziu poate întreba asta).
static var activ := false

## Raza sferei și unde e centrul ei, de la tălpi: aproape de ochi (camera e la ~1,6 m), ca să rămână în jurul
## camerei și când e încă mică (altfel o vezi ca pe un glob în fața ta).
@export var raza := 1.15
@export var inaltime := 1.3
## Cât ține scutul ridicat (secunde).
@export var durata := 2.5
## Cooldown-ul: după ce s-a spart, după câte secunde îl poți ridica din nou.
@export var pauza := 2.0
## Cât de tare strălucește când stă ridicat (parametrul `putere` din shader).
@export var putere := 0.95

var _jucator: CharacterBody3D
var _camera: Camera3D
var _sfera: MeshInstance3D
var _mat: ShaderMaterial
var _lumina: OmniLight3D
var _adunare: CPUParticles3D
var _indiciu_strat: CanvasLayer
var _indiciu: Label
var _ocupat := false
var _pauza_ramasa := 0.0
var _tremur := 0.0
var _gelatina := 0.0
var _marime := 1.0  # mărimea spre care tinde sfera (gelatina se pune peste)
var _indiciu_alfa := 0.0
var _timp := 0.0


func _ready() -> void:
	_jucator = get_parent() as CharacterBody3D
	_camera = _jucator.get_node("Cap/Camera3D")
	add_to_group("scut_jucator")
	activ = false
	position = Vector3.UP * inaltime
	var mesh := SphereMesh.new()
	mesh.radius = raza
	mesh.height = raza * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("culoare", CULOARE)
	_mat.set_shader_parameter("putere", 0.0)
	_sfera = MeshInstance3D.new()
	_sfera.mesh = mesh
	_sfera.material_override = _mat
	_sfera.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sfera.visible = false
	add_child(_sfera)
	_lumina = OmniLight3D.new()
	_lumina.light_color = CULOARE
	_lumina.light_energy = 0.0
	_lumina.omni_range = 3.5
	_lumina.omni_attenuation = 1.2
	_lumina.visible = false
	add_child(_lumina)
	# scânteile care se adună spre tine cât te încordezi (pornesc pe sferă și sunt trase spre mijloc)
	_adunare = VrajaAtac.particule(_camera, 40, 0.45, 0.012, [Color(CULOARE, 0.0), Color(0.85, 0.7, 1.0, 1.0), Color(1, 1, 1, 0.0)])
	_adunare.emission_sphere_radius = 0.45
	_adunare.local_coords = true
	_adunare.radial_accel_min = -5.0
	_adunare.radial_accel_max = -3.5
	_adunare.gravity = Vector3.ZERO
	_adunare.initial_velocity_min = 0.0
	_adunare.initial_velocity_max = 0.1
	# se adună într-un punct mic în fața pieptului (pe lângă cameră ar fi pete mari, neclare)
	_adunare.position = Vector3(0.0, -0.32, -0.65)
	await get_tree().process_frame
	if not Stare.e_marcat(MARCAJ):
		Stare.schimbat.connect(_la_schimbare)
	elif not Stare.e_marcat(MARCAJ_FOLOSIT):
		_arata_indiciul()


func _exit_tree() -> void:
	activ = false
	if _camera:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0


## Ai învățat scutul chiar acum (Head Witch pune marcajul la sfârșitul lecției): apare „Press Ctrl…”.
func _la_schimbare() -> void:
	if Stare.e_marcat(MARCAJ):
		Stare.schimbat.disconnect(_la_schimbare)
		if not Stare.e_marcat(MARCAJ_FOLOSIT):
			_arata_indiciul()


func _process(delta: float) -> void:
	_timp += delta
	_pauza_ramasa = maxf(_pauza_ramasa - delta, 0.0)
	# încordarea: camera tremură (h/v_offset, ca să nu se bată cu clătinarea pașilor de pe `position`)
	if _tremur > 0.001:
		_camera.h_offset = randf_range(-1.0, 1.0) * 0.012 * _tremur
		_camera.v_offset = randf_range(-1.0, 1.0) * 0.012 * _tremur - 0.02 * _tremur
	elif _camera.h_offset != 0.0 or _camera.v_offset != 0.0:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
	# scutul de începător nu stă rotund: se umflă și se strânge pe axe diferite, ca o gelatină
	if _sfera.visible:
		var g := _gelatina
		_sfera.scale = _sfera.scale.lerp(Vector3(1.0 + sin(_timp * 7.3) * 0.05 * g, 1.0 + sin(_timp * 5.1 + 1.0) * 0.06 * g,
			1.0 + sin(_timp * 6.2 + 2.0) * 0.05 * g) * _marime, 1.0 - exp(-delta * 18.0))
	if _indiciu:
		_indiciu_alfa = minf(_indiciu_alfa + delta * 2.0, 1.0)
		_indiciu.modulate.a = _indiciu_alfa * (0.8 + 0.2 * sin(_timp * 3.0))




func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("scut") or not Stare.e_marcat(MARCAJ):
		return
	if Dialog.activ or Stare.meniu_deschis or Tranzitie.activa or get_tree().paused \
			or not _jucator.is_physics_processing() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if _ocupat:
		return
	if _pauza_ramasa > 0.0:
		_fasait()
		return
	_ridica()


## Pe cooldown: te încordezi o clipă, ies două-trei scântei și se sting.
func _fasait() -> void:
	_ocupat = true
	Sunet.reda(SUNET_ESUAT, Sunet.VOLUM_EFECTE - 9.0, 0.08)
	_adunare.amount = 8
	_adunare.emitting = true
	var t := create_tween()
	t.tween_property(self, "_tremur", 0.5, 0.12)
	t.tween_property(self, "_tremur", 0.0, 0.25)
	await t.finished
	_adunare.emitting = false
	_adunare.amount = 40
	_ocupat = false


## Ridicat dintr-o scenă (lupta_warlock.gd: în cutscene tasta e blocată de Stare.meniu_deschis, deci scena ascultă ea
## tasta și cheamă asta). Iese mereu curat, chiar dacă nu l-ai folosit niciodată. Întoarce false dacă e deja ridicat.
func ridica_din_scena() -> bool:
	if _ocupat:
		return activ
	if not Stare.e_marcat(MARCAJ_FOLOSIT):
		Stare.marcheaza(MARCAJ_FOLOSIT)
		_ascunde_indiciul()
	_ocupat = true
	_ridica_stapanit_si_pauza()
	return true


func _ridica_stapanit_si_pauza() -> void:
	await _ridica_stapanit()
	activ = false
	_pauza_ramasa = pauza_acum()
	_ocupat = false


## Cooldown-ul de acum: `pauza`, sau PAUZA_IMBUNATATITA după vraja lui Tom Berone.
func pauza_acum() -> float:
	return minf(pauza, PAUZA_IMBUNATATITA) if Stare.e_marcat(MARCAJ_IMBUNATATIT) else pauza


## Gata de ridicat acum (nu e ridicat și nu e pe cooldown).
func poate_ridica() -> bool:
	return not _ocupat and _pauza_ramasa <= 0.0 and Stare.e_marcat(MARCAJ)


func _ridica() -> void:
	_ocupat = true
	if Stare.e_marcat(MARCAJ_FOLOSIT):
		await _ridica_stapanit()
	else:
		Stare.marcheaza(MARCAJ_FOLOSIT)
		_ascunde_indiciul()
		await _ridica_prima_data()
	activ = false
	_pauza_ramasa = pauza_acum()
	_ocupat = false


## De la a doua folosire îți iese curat: un puls scurt, scutul se deschide rotund și stabil, ține `durata` și se stinge lin.
func _ridica_stapanit() -> void:
	Sunet.reda(SUNET_SCUT, Sunet.VOLUM_EFECTE - 3.0, 0.06)
	activ = true
	_sfera.visible = true
	_lumina.visible = true
	_gelatina = 0.0
	_marime = 0.6
	_sfera.scale = Vector3.ONE * 0.6
	_mat.set_shader_parameter("lovit", 0.5)
	var forma := create_tween().set_parallel()
	forma.tween_property(self, "_marime", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	forma.tween_method(_seteaza_parametru.bind("lovit"), 0.5, 0.0, 0.3)
	forma.tween_method(_seteaza_parametru.bind("putere"), 0.0, putere, 0.2)
	forma.tween_property(_lumina, "light_energy", 0.9, 0.2)
	forma.tween_property(self, "_tremur", 0.2, 0.08)
	forma.chain().tween_property(self, "_tremur", 0.0, 0.15)
	await forma.finished
	await get_tree().create_timer(maxf(durata - 0.6, 0.1)).timeout
	if not is_inside_tree():
		return
	var stins := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	stins.tween_method(_seteaza_parametru.bind("putere"), putere, 0.0, 0.35)
	stins.tween_property(_lumina, "light_energy", 0.0, 0.35)
	stins.tween_property(self, "_marime", 1.06, 0.35)
	await stins.finished
	_sfera.visible = false
	_lumina.visible = false
	_mat.set_shader_parameter("lovit", 0.0)


## Prima dată (abia ai învățat): te încordezi, îți scapă o dată, apoi îți iese tremurat, cu pâlpâieli, și se sparge.
func _ridica_prima_data() -> void:
	# 1. te încordezi: „flex every muscle in your body”
	Sunet.reda(SUNET_SCANTEI, Sunet.VOLUM_EFECTE - 6.0, 0.05)
	_adunare.emitting = true
	var t := create_tween()
	t.tween_property(self, "_tremur", 1.0, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	await _scapa()
	t = create_tween()
	t.tween_property(self, "_tremur", 1.0, 0.45)
	await t.finished
	_adunare.emitting = false
	# 2. îți iese: crește tremurat (gelatina), cu un fulger alb, pâlpâind până se stabilizează
	Sunet.reda(SUNET_SCUT, Sunet.VOLUM_EFECTE - 3.0, 0.06)
	activ = true
	_sfera.visible = true
	_lumina.visible = true
	_marime = 0.5
	_sfera.scale = Vector3.ONE * 0.5
	_gelatina = 1.0
	_mat.set_shader_parameter("lovit", 0.6)
	var forma := create_tween().set_parallel()
	forma.tween_property(self, "_marime", 1.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	forma.tween_property(self, "_tremur", 0.25, 0.4)
	forma.tween_method(_seteaza_parametru.bind("lovit"), 0.6, 0.0, 0.35)
	forma.tween_property(_lumina, "light_energy", 0.9, 0.3)
	var palpaie := create_tween()
	_palpaie(palpaie, 0.0, [0.7, 0.2, 0.9, 0.35, 1.1, 1.0], 0.07, 0.03)
	await forma.finished
	create_tween().tween_property(self, "_gelatina", 0.35, 0.6)
	create_tween().tween_property(self, "_tremur", 0.0, 0.5)
	# 3. îl ții: din când în când îți scapă o clipă (pâlpâie), că abia ai învățat
	var ramas := durata - 0.4
	while ramas > 0.45:
		var pas := randf_range(0.35, 0.7)
		await get_tree().create_timer(minf(pas, ramas - 0.4)).timeout
		ramas -= pas
		if not is_inside_tree():
			return
		if randf() < 0.55:
			_seteaza_parametru(putere * randf_range(0.25, 0.5), "putere")
			await get_tree().create_timer(0.05).timeout
			_seteaza_parametru(putere, "putere")
	# 4. nu mai poți: pâlpâie, crapă și se sparge
	var final := create_tween()
	final.tween_property(self, "_gelatina", 1.2, 0.35)
	final.parallel().tween_method(_seteaza_parametru.bind("lovit"), 0.0, 0.5, 0.35)
	_palpaie(final, putere, [0.3, 1.0, 0.15, 0.8], 0.05)
	await final.finished
	Sunet.reda(SUNET_SPART, Sunet.VOLUM_EFECTE - 8.0, 0.06)
	_cioburi()
	var stins := create_tween().set_parallel()
	stins.tween_method(_seteaza_parametru.bind("putere"), _parametru("putere"), 0.0, 0.15)
	stins.tween_property(_lumina, "light_energy", 0.0, 0.25)
	stins.tween_property(self, "_marime", 1.12, 0.15)
	await stins.finished
	_sfera.visible = false
	_lumina.visible = false
	_mat.set_shader_parameter("lovit", 0.0)


## Prima dată: scutul apare o clipă, pe jumătate, și se stinge („nu l-a făcut din prima”).
func _scapa() -> void:
	Sunet.reda(SUNET_SCUT, Sunet.VOLUM_EFECTE - 10.0, 0.1)
	_sfera.visible = true
	_lumina.visible = true
	_marime = 0.6
	_sfera.scale = Vector3.ONE * 0.5
	_gelatina = 1.6
	_mat.set_shader_parameter("lovit", 0.3)
	var t := create_tween()
	_palpaie(t, 0.0, [0.4, 0.1, 0.5, 0.05], 0.08)
	t.parallel().tween_property(_lumina, "light_energy", 0.4, 0.2)
	await t.finished
	Sunet.reda(SUNET_ESUAT, Sunet.VOLUM_EFECTE - 5.0, 0.05)
	var stins := create_tween().set_parallel()
	stins.tween_method(_seteaza_parametru.bind("putere"), _parametru("putere"), 0.0, 0.2)
	stins.tween_property(self, "_marime", 0.45, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	stins.tween_property(_lumina, "light_energy", 0.0, 0.25)
	stins.tween_property(self, "_tremur", 0.15, 0.25)
	await stins.finished
	_sfera.visible = false
	_lumina.visible = false
	_mat.set_shader_parameter("lovit", 0.0)
	await get_tree().create_timer(0.35).timeout


## O vrajă / un glonț a lovit scutul: fulgeră alb o clipă.
func lovit() -> void:
	if not activ:
		return
	create_tween().tween_method(_seteaza_parametru.bind("lovit"), 1.0, 0.0, 0.3)


func _seteaza_parametru(valoare: float, nume: String) -> void:
	_mat.set_shader_parameter(nume, valoare)


func _parametru(nume: String) -> float:
	var v: Variant = _mat.get_shader_parameter(nume)
	return float(v) if v != null else 0.0


func _cioburi() -> void:
	var c := VrajaAtac.particule(get_tree().current_scene, 36, 0.7, 0.022,
		[Color(1.0, 1.0, 1.0, 1.0), Color(CULOARE, 1.0), Color(CULOARE, 0.0)])
	c.global_position = global_position
	c.emission_sphere_radius = raza
	c.one_shot = true
	c.explosiveness = 1.0
	c.radial_accel_min = 6.0
	c.radial_accel_max = 10.0
	c.gravity = Vector3(0, -5.0, 0)
	c.emitting = true
	get_tree().create_timer(1.5).timeout.connect(c.queue_free)


# ---------------------------------------------------------------- „Press Ctrl to use shield”

func _arata_indiciul() -> void:
	if _indiciu:
		return
	_indiciu_strat = CanvasLayer.new()
	_indiciu_strat.layer = 7
	add_child(_indiciu_strat)
	_indiciu = Label.new()
	_indiciu.text = "Press %s to use shield" % Setari.nume_tasta("scut")
	_indiciu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_indiciu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_indiciu.offset_left = -150
	_indiciu.offset_right = 150
	_indiciu.offset_top = -78
	_indiciu.offset_bottom = -60
	_indiciu.add_theme_font_size_override("font_size", 13)
	_indiciu.add_theme_color_override("font_color", Color("83b3b0"))
	_indiciu.add_theme_color_override("font_shadow_color", Color("262d2fe6"))
	_indiciu.add_theme_constant_override("shadow_offset_x", 1)
	_indiciu.add_theme_constant_override("shadow_offset_y", 1)
	_indiciu.modulate.a = 0.0
	_indiciu_strat.add_child(_indiciu)


func _ascunde_indiciul() -> void:
	if _indiciu == null:
		return
	var e := _indiciu
	_indiciu = null
	var t := create_tween()
	t.tween_property(e, "modulate:a", 0.0, 0.4)
	t.tween_callback(_indiciu_strat.queue_free)


## Pâlpâitul: `putere` trece pe rând prin `valori` (fracțiuni din `putere`), câte `pas` secunde fiecare.
func _palpaie(t: Tween, de_la: float, valori: Array, pas: float, pauza_intre := 0.0) -> void:
	var inainte := de_la
	for v in valori:
		var dupa: float = putere * float(v)
		t.tween_method(_seteaza_parametru.bind("putere"), inainte, dupa, pas)
		if pauza_intre > 0.0:
			t.tween_interval(pauza_intre)
		inainte = dupa
