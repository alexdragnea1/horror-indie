extends Node3D
## Lupta cu Warlock-ul la Paradise Motel (motel.tscn, nodul `LuptaWarlock`). După ce afli camera (`marcaj_camera`),
## Head Witch te așteaptă la ușa camerei 122 (sefa_motel.gd) și pe ușă scrie „[E] Knock” (`usa`):
##  1. Intro (Cutscena): bați de două ori, `replici_usa` (owner) prin ușă; liniște; în spatele vostru, în mijlocul parcării
##     (`loc_aparitie`), Warlock-ul se teleportează într-un fulger roșu (plan „de film” de jos); aruncă o vrajă în Head
##     Witch, care cade și rămâne jos; își încarcă toiagul spre tine și apare „Press Ctrl to shield!” cu `fereastra_scut`
##     secunde: cu scutul ridicat la timp vraja se sparge în el, altfel te lovește, cazi și te ridici repede.
##     → `marcaj_lupta`, `sarcina_lupta`.
##  2. Lupta (ca un boss din Dark Souls, BaraBoss): Warlock-ul are `viata_maxima` (2000); damage-ul vine după armă
##     (`lovit_de`, chemat de pistol, Arma, cuțit, rachetă / explozie, mingea de foc; vezi `damage_*`). Atacurile lui se
##     opresc toate cu scutul (Ctrl): salve de vrăji roșii (te poți și feri), fulgere din cer pe cercuri roșii de pe asfalt,
##     globul mare care te urmărește și te dărâmă, iar dacă stai lângă el, unda de șoc (te aruncă), apoi se teleportează.
##     Sub jumătate de viață (`faza a doua`) se înfurie: cerul se înroșește, atacă mai des și mai mult.
##     Viața ta: `viata_jucator` (doar în lupta asta). La 0: „YOU DIED”, apoi lupta o ia de la capăt de la ușă.
##  3. Finalul (când „îl omori”, `marcaj_invins`): cade în genunchi, „WARLOCK DEFEATED”, Head Witch se ridică, vine la
##     el și îi absoarbe puterile (raza roșie, el se ridică în aer și se face cenușă), vine la tine, `replici_final`
##     (owner), apoi dispare (sefa_motel.gd, `marcaj_plecata`). → `sarcina_dupa`.
## La Continue: în lupta începută o iei de la ușă; după `marcaj_invins`, finalul de la ridicarea ei.
## Replicile sunt ale owner-ului: nu le corecta.

@export var usa: Interactabil
@export var sefa: Node3D
@export var mediu: WorldEnvironment

@export_group("Marcaje")
@export var marcaj_camera := "stie_camera_warlock"
## Pus la sfârșitul intro-ului: de aici e lupta.
@export var marcaj_lupta := "lupta_cu_warlock"
## Pus când îi termini viața: de aici e finalul.
@export var marcaj_invins := "warlock_invins"
## Pus la sfârșitul finalului (Head Witch a plecat).
@export var marcaj_final := "warlock_absorbit"
## Sarcinile (ale lui Claude): în luptă și după.
@export var sarcina_lupta := "Defeat the Warlock."
@export var sarcina_dupa := ""

@export_group("Replici")
@export_multiline var replici_usa: PackedStringArray = ["Warlock: Who's there?", "You: Pizza delivery.",
	"Warlock: I didn't order any pizza..", "Warlock: I'm coming hold on.."]
@export_multiline var replici_final: PackedStringArray = ["Head Witch: Thank you child.", "You: Now what?",
	"Head Witch: Now I will kill every single person in the town..", "You: Huh?",
	"Head Witch: The warlock was keeping the coven from this goal..",
	"Head Witch: But now thanks to you that's no longer the case.", "You: Kill yourself."]
@export var nume_boss := "Warlock"

@export_group("Viață și damage")
@export var viata_maxima := 2000
@export var damage_pistol := 5
@export var damage_cutit := 10
## Shotgun: de aproape (sub `distanta_shotgun` metri) și de departe.
@export var damage_shotgun_aproape := 50
@export var damage_shotgun_departe := 10
@export var distanta_shotgun := 5.0
@export var damage_ak47 := 25
@export var damage_bazooka := 500
@export var damage_fireball := 15
## Viața ta în luptă și cât iei de la fiecare atac al lui.
@export var viata_jucator := 100.0
@export var damage_vraja := 15.0
@export var damage_fulger := 25.0
@export var damage_glob := 35.0
@export var damage_unda := 20.0
## Cât ai ca să ridici scutul în intro (secunde).
@export var fereastra_scut := 4.0

@export_group("Locuri")
## Unde stai când bați la ușă și mijlocul ușii 122.
@export var loc_usa := Vector3(0.72, 0.15, -8.85)
@export var mijloc_usa := Vector3(0.725, 1.2, -9.92)
## Unde se teleportează în intro (mijlocul parcării) și unde poate sări în luptă.
@export var loc_aparitie := Vector3(-5.5, 0.0, 3.5)
@export var locuri_teleport := PackedVector3Array([Vector3(-5.5, 0, 3.5), Vector3(-1.5, 0, 5.5), Vector3(5.5, 0, 3.0), Vector3(-6.0, 0, 10.5),
	Vector3(2.0, 0, 12.5), Vector3(-5.0, 0, 1.5), Vector3(6.5, 0, 12.0), Vector3(-9.0, 0, 13.5), Vector3(1.0, 0, 8.5)])
## Încotro o aruncă vraja pe Head Witch (de-a lungul trotuarului, nu în perete) și cât de departe.
@export var cadere_sefa := Vector3(1.0, 0.0, -0.25)
@export var departe_sefa := 1.6

const SHADER_RAZA := preload("res://shaders/raza_vraja.gdshader")
const SUNET_CIOCANIT := preload("res://sunete/usa_ciocanit.ogg")
const SUNET_PAS := preload("res://sunete/pas_lemn_2.ogg")
const SUNET_TELEPORT := preload("res://sunete/atac_aparitie.ogg")
const SUNET_TUNET := preload("res://sunete/atac_tunet.ogg")
const SUNET_INCARCARE := preload("res://sunete/orb_incarcare.ogg")
const SUNET_ORB_ZBOR := preload("res://sunete/orb_zbor.ogg")
const SUNET_ORB_BUM := preload("res://sunete/orb_explozie.ogg")
const SUNET_IMPACT := preload("res://sunete/atac_impact.ogg")
const SUNET_VRAJA := preload("res://sunete/atac_vraja.ogg")
const SUNET_SCUT := preload("res://sunete/scut.ogg")
const SUNET_CAZUT := preload("res://sunete/corp_cazut.ogg")
const SUNET_TIUIT := preload("res://sunete/tiuit.ogg")
const SUNET_MUZICA := preload("res://sunete/muzica_warlock.ogg")
const SUNET_MURIT := preload("res://sunete/ai_murit.ogg")
const SUNET_DOBORAT := preload("res://sunete/inamic_doborat.ogg")
const SUNET_ABSORBTIE := preload("res://sunete/absorbtie.ogg")
const ROSU := Color(1.0, 0.22, 0.15)

## Ținta pe care o lovesc armele (pe Warlock): trimite lovitura înapoi la luptă.
class Tinta extends StaticBody3D:
	var lupta: Node

	func lovit_de(arma: String, directie: Vector3, punct: Vector3) -> void:
		lupta.call("_lovit", arma, directie, punct)


var _warlock: Warlock
var _tinta: StaticBody3D
var _forma_tinta: CollisionShape3D
var _bara: BaraBoss
var _camera_jucator: Camera3D
var _camera_film: Camera3D
var _negru: ColorRect
var _alb: ColorRect
var _muzica: AudioStreamPlayer
var _env: Environment
var _env_initial: Dictionary = {}

var _viata := 0.0
var _viata_jucator := 0.0
var _lupta_activa := false
## Crește la orice oprire (moarte, final): vrăjile și atacurile pornite înainte se opresc singure.
var _runda := 0
var _faza_doi := false
var _faza_doi_ceruta := false
var _ascuns := false
var _jos := false
var _ultimul_atac := ""
var _proiectile: Array = []  # [VrajaAtac, damage, raza]
var _globuri: Array = []  # {nod, viteza, damage, timp, runda}
var _de_sters: Array[Node] = []
var _asteapta_scut := false
var _scut_apasat := false
## Raza dintre Warlock și palma ei (finalul): capetele, actualizate în fiecare cadru.
var _raza_absorbtie: MeshInstance3D
var _sefa_ref  # fără tip: are metodele din sefa_motel.gd


func _ready() -> void:
	_sefa_ref = sefa
	var jucator := _jucator()
	if jucator == null or usa == null:
		return
	_camera_jucator = jucator.get_node("Cap/Camera3D")
	_camera_film = Camera3D.new()
	_camera_film.near = 0.05
	_camera_film.far = 400.0
	add_child(_camera_film)
	_bara = BaraBoss.new()
	add_child(_bara)
	var strat := CanvasLayer.new()
	strat.layer = 19
	add_child(strat)
	_alb = _ecran(strat, Color(1, 1, 1, 0))
	_negru = _ecran(strat, Color(0, 0, 0, 0))
	_muzica = AudioStreamPlayer.new()
	_muzica.stream = SUNET_MUZICA
	_muzica.bus = &"Muzica"
	add_child(_muzica)
	if mediu:
		_env = mediu.environment.duplicate(true) as Environment
		mediu.environment = _env
		for k in ["fog_light_color", "fog_density", "ambient_light_color", "ambient_light_energy"]:
			_env_initial[k] = _env.get(k)
	usa.indiciu = "[E] Knock"
	usa.folosit.connect(_bate_la_usa)
	usa.activ = Stare.e_marcat(marcaj_camera) and not Stare.e_marcat(marcaj_lupta)
	if not Stare.e_marcat(marcaj_camera):
		Stare.schimbat.connect(_la_schimbare)
	if Stare.e_marcat(marcaj_final) or not Stare.e_marcat(marcaj_lupta):
		return
	# Continue: în luptă (de la ușă) sau în final (de la ridicarea ei)
	await get_tree().process_frame
	_sefa_ref.global_position = _loc_sefa_cazuta()
	var d := cadere_sefa.normalized()
	_sefa_ref.rotation.y = atan2(-d.x, -d.z)
	_sefa_ref.culca_te()
	while Tranzitie.activa:
		await get_tree().process_frame
	if Stare.e_marcat(marcaj_invins):
		_fa_warlock(loc_aparitie)
		_warlock.plutire = -0.3
		_warlock.prabusire(0.01)
		_pune_jucatorul(loc_aparitie + Vector3(0.0, 0.0, -5.0), loc_aparitie)
		await get_tree().create_timer(0.8, false).timeout
		await _finalul(false)
	else:
		_pune_jucatorul(loc_usa, loc_aparitie)
		_fa_warlock(loc_aparitie)
		await get_tree().create_timer(1.0, false).timeout
		_porneste_lupta()


func _la_schimbare() -> void:
	if Stare.e_marcat(marcaj_camera):
		Stare.schimbat.disconnect(_la_schimbare)
		usa.activ = true


func _jucator() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("jucator") as CharacterBody3D


func _ecran(strat: CanvasLayer, culoare: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = culoare
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	strat.add_child(r)
	return r


func _unhandled_input(event: InputEvent) -> void:
	if _asteapta_scut and event.is_action_pressed("scut"):
		_scut_apasat = true
		get_viewport().set_input_as_handled()


## Așteaptă `sec` secunde (pe pauză stă și el); false dacă între timp s-a oprit runda (moarte, final).
func _asteapta(sec: float) -> bool:
	var r := _runda
	await get_tree().create_timer(sec, false).timeout
	return r == _runda and _lupta_activa


func _hud(vizibil: bool) -> void:
	var jucator := _jucator()
	var hud := jucator.get_node_or_null("HUD") as CanvasLayer if jucator else null
	if hud:
		hud.visible = vizibil


func _loc_sefa_cazuta() -> Vector3:
	var loc: Vector3 = _sefa_ref.loc_la_usa
	return loc + cadere_sefa.normalized() * departe_sefa


## Privirea jucătorului drept spre `punct`, pe loc (în cutscene, cadru cu cadru).
func _priveste_acum(punct: Vector3) -> void:
	var j := _jucator()
	var cap: Node3D = j.get_node("Cap")
	var d := punct - cap.global_position
	j.rotation.y = atan2(-d.x, -d.z)
	cap.rotation.x = clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-85), deg_to_rad(85))


func _pune_jucatorul(poz: Vector3, priveste: Vector3) -> void:
	var j := _jucator()
	j.global_position = poz
	var d := priveste - poz
	j.rotation.y = atan2(-d.x, -d.z)
	(j.get_node("Cap") as Node3D).rotation.x = -0.05


# ---------------------------------------------------------------------------------------------------------------
# Warlock-ul și ținta lui
# ---------------------------------------------------------------------------------------------------------------

func _fa_warlock(poz: Vector3) -> void:
	_warlock = Warlock.new()
	add_child(_warlock)
	_warlock.global_position = poz
	_warlock.plutire = 0.5
	_warlock.furie = 0.4
	_tinta = Tinta.new()
	_tinta.lupta = self
	_forma_tinta = CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.5
	capsula.height = 2.3
	_forma_tinta.shape = capsula
	_forma_tinta.position = Vector3.UP * 1.65
	_tinta.add_child(_forma_tinta)
	_warlock.add_child(_tinta)
	_intoarce_warlock(_jucator().global_position, 1.0)


func _piept_warlock() -> Vector3:
	return _warlock.global_position + Vector3.UP * (_warlock.plutire + 1.3)


func _piept_jucator() -> Vector3:
	return _jucator().global_position + Vector3.UP * 1.1


func _intoarce_warlock(spre: Vector3, k: float) -> void:
	var d := spre - _warlock.global_position
	_warlock.rotation.y = lerp_angle(_warlock.rotation.y, atan2(d.x, d.z), k)


func _process(delta: float) -> void:
	var jucator := _jucator()
	if jucator == null:
		return
	if is_instance_valid(_warlock) and _lupta_activa:
		_intoarce_warlock(jucator.global_position, 1.0 - exp(-delta * 5.0))
		_warlock.priveste((jucator.get_node("Cap") as Node3D).global_position)
	_misca_proiectile()
	_misca_globuri(delta)
	if is_instance_valid(_raza_absorbtie) and is_instance_valid(_warlock):
		_aseaza_raza(_raza_absorbtie, _piept_warlock(), _sefa_ref.palma())


## Damage-ul de la armă (Tinta.lovit_de).
func _lovit(arma: String, directie: Vector3, punct: Vector3) -> void:
	if not _lupta_activa or _ascuns or _viata <= 0.0:
		return
	var damage := 0
	match arma:
		"pistol_roz", "pistol_aur":
			damage = damage_pistol
		"cutit":
			damage = damage_cutit
		"shotgun":
			var d := _jucator().global_position.distance_to(_warlock.global_position)
			damage = damage_shotgun_aproape if d <= distanta_shotgun else damage_shotgun_departe
		"ak47":
			damage = damage_ak47
		"bazooka":
			damage = damage_bazooka
		"vraja_foc":
			damage = damage_fireball
		_:
			damage = damage_pistol
	_viata = maxf(_viata - damage, 0.0)
	_bara.viata_boss(_viata, viata_maxima, damage)
	_warlock.tresare(-directie, clampf(damage / 25.0, 0.4, 2.0))
	_scantei_lovitura(punct, -directie, damage)
	if _viata <= 0.0:
		_invins()
	elif not _faza_doi and _viata <= viata_maxima * 0.5:
		_faza_doi_ceruta = true


func _scantei_lovitura(punct: Vector3, spre: Vector3, damage: int) -> void:
	var s := VrajaAtac.particule(self, 10 + mini(damage, 60), 0.5, 0.05, [Color(1.0, 0.85, 0.7), Color(1.0, 0.3, 0.2), Color(0.3, 0.05, 0.05, 0.0)])
	s.global_position = punct
	s.one_shot = true
	s.explosiveness = 1.0
	s.direction = spre
	s.spread = 50.0
	s.initial_velocity_min = 1.5
	s.initial_velocity_max = 4.0
	s.gravity = Vector3(0, -6, 0)
	s.emitting = true
	get_tree().create_timer(1.0, false).timeout.connect(s.queue_free)


# ---------------------------------------------------------------------------------------------------------------
# 1. La ușă: intro-ul
# ---------------------------------------------------------------------------------------------------------------

func _bate_la_usa() -> void:
	usa.activ = false
	var jucator := _jucator()
	var cap: Node3D = jucator.get_node("Cap")
	var c := Cutscena.porneste(self)
	_hud(false)
	jucator.seteaza_purtat(true)
	Stare.seteaza_sarcina("")
	# un pas în fața ușii
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(jucator, "global_position", loc_usa, 0.7)
	c.priveste(mijloc_usa + Vector3(0, 0.25, 0), 0.7)
	await t.finished
	await get_tree().create_timer(0.3, false).timeout
	# „knock knock”
	for k in 2:
		Sunet.reda_la(SUNET_CIOCANIT, mijloc_usa, Sunet.VOLUM_EFECTE, 0.06)
		var bat := create_tween()
		bat.tween_property(cap, "position:z", cap.position.z - 0.03, 0.05)
		bat.tween_property(cap, "position:z", cap.position.z, 0.12)
		await get_tree().create_timer(0.36, false).timeout
	await get_tree().create_timer(0.9, false).timeout
	Dialog.spune(replici_usa)
	if Dialog.activ:
		await Dialog.terminat
	# pașii lui, înăuntru, spre ușă... și se opresc
	for k in 3:
		Sunet.reda_la(SUNET_PAS, mijloc_usa + Vector3(0, -1.0, -2.0 + k * 0.6), Sunet.VOLUM_EFECTE - 8.0 + k * 2.0, 0.1)
		await get_tree().create_timer(0.55, false).timeout
	await get_tree().create_timer(1.3, false).timeout

	# în spatele vostru: fulger roșu, Warlock-ul în mijlocul parcării
	_fa_warlock(loc_aparitie)
	_warlock.furie = 0.8
	ModelPS2.disparitie(_warlock._model, 1.0)
	var cer := loc_aparitie + Vector3(randf_range(-4, 4), 40, randf_range(-3, 3))
	Fulger.loveste(self, cer, loc_aparitie, ROSU, 0.35, true, 1.6)
	VrajaAtac.sunet_la(self, SUNET_TELEPORT, loc_aparitie + Vector3.UP, Sunet.VOLUM_EFECTE + 2.0, 18.0)
	_lumina_scurta(loc_aparitie + Vector3.UP * 2.0, ROSU, 14.0, 26.0, 1.2)
	_fum_rosu(loc_aparitie + Vector3.UP * 0.8, 40)
	Zguduire.porneste(_camera_jucator, 0.03, 0.5)
	if _sefa_ref.has_method("intoarce_spre"):
		_sefa_ref.intoarce_spre(_warlock)
	await get_tree().create_timer(0.25, false).timeout
	await c.priveste(_piept_warlock(), 0.45)
	# plan de jos, între voi și el: se încheagă din pixeli în lumina roșie
	var stalp := _stalp_lumina(loc_aparitie, 30.0, 0.9, ROSU)
	_warlock.aparitie(1.4)
	_warlock.priveste(_sefa_ref.global_position + Vector3.UP * 1.6)
	var d := (loc_usa - loc_aparitie)
	d.y = 0.0
	d = d.normalized()
	var lateral := d.cross(Vector3.UP)
	_film(loc_aparitie + d * 4.2 + lateral * 1.2 + Vector3.UP * 0.35, _piept_warlock() + Vector3.UP * 0.3, 50.0,
		loc_aparitie + d * 3.4 + lateral * 0.7 + Vector3.UP * 0.45, 2.6)
	var stinge := create_tween()
	stinge.tween_interval(1.2)
	stinge.tween_method(func(v: float) -> void: (stalp.material_override as ShaderMaterial).set_shader_parameter("putere", v), 1.0, 0.0, 1.0)
	stinge.tween_callback(stalp.queue_free)
	await get_tree().create_timer(2.6, false).timeout
	_camera_jucator.make_current()

	# o vrajă în Head Witch: cade și rămâne jos
	_warlock.ridica_mana(-1.5, 0.35, 0.0)
	await get_tree().create_timer(0.35, false).timeout
	var tinta_sefa: Vector3 = _sefa_ref.global_position + Vector3.UP * 1.2
	var v := VrajaAtac.trage(self, _warlock.palma(), tinta_sefa, "rosu", 1.0, 0.6, 0.4, false)
	await get_tree().create_timer(0.3, false).timeout
	_sefa_ref.brat_scut(true, 0.25)  # prea târziu
	await v.lovit
	_sefa_ref.cade(cadere_sefa, departe_sefa)
	Zguduire.porneste(_camera_jucator, 0.02, 0.4)
	_warlock.ridica_mana(0.0, 0.6, 0.0)
	c.priveste(tinta_sefa + cadere_sefa.normalized() * departe_sefa - Vector3.UP * 0.6, 0.35)
	await get_tree().create_timer(1.0, false).timeout

	# acum tu: își încarcă toiagul, iar tu ai `fereastra_scut` secunde pentru scut
	await c.priveste(_piept_warlock(), 0.5)
	_warlock.priveste(cap.global_position)
	_warlock.ridica_toiagul(-2.6, 0.8)
	var incarcare := _sunet_incarcare()
	var glob := _glob_mic()
	var timp := 0.0
	_asteapta_scut = true
	_scut_apasat = false
	_bara.indicatie_scut(fereastra_scut)
	while timp < fereastra_scut and not _scut_apasat:
		await get_tree().process_frame
		if get_tree().paused:
			continue
		timp += get_process_delta_time()
		glob.global_position = _warlock.varf_toiag() + Vector3.UP * 0.35
		glob.scale = Vector3.ONE * lerpf(0.2, 1.0, minf(timp / 1.2, 1.0))
		_warlock.furie = lerpf(0.8, 1.0, minf(timp / fereastra_scut, 1.0))
	_asteapta_scut = false
	_bara.indicatie_scut(0.0)
	var scut := get_tree().get_first_node_in_group("scut_jucator")
	if _scut_apasat and scut:
		scut.call("ridica_din_scena")
		await get_tree().create_timer(0.3, false).timeout
	incarcare.queue_free()
	# aruncă
	_warlock.ridica_toiagul(-1.3, 0.2)
	Sunet.reda(SUNET_ORB_ZBOR, Sunet.VOLUM_EFECTE - 4.0)
	var de_la := glob.global_position
	var la := _piept_jucator()
	var aparat := ScutJucator.activ
	var oprire := 1.25 if aparat else 0.25
	var zbor := create_tween()
	zbor.tween_method(func(k: float) -> void:
		glob.global_position = de_la.lerp(la, k) + Vector3.UP * sin(k * PI) * 0.6, 0.0, 1.0 - oprire / de_la.distance_to(la), 0.55)
	await zbor.finished
	var unde := glob.global_position
	glob.queue_free()
	Sunet.reda(SUNET_ORB_BUM, Sunet.VOLUM_EFECTE - 3.0, 0.05)
	if aparat:
		_scut_lovit(unde)
		Zguduire.porneste(_camera_jucator, 0.03, 0.4)
		# te împinge puțin înapoi, în scut
		var spate := (jucator.global_position - _warlock.global_position) * Vector3(1, 0, 1)
		create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).tween_property(jucator, "global_position",
			jucator.global_position + spate.normalized() * 0.35, 0.4)
		await get_tree().create_timer(1.4, false).timeout
	else:
		_alb.color = Color(1.0, 0.55, 0.5, 0.8)
		create_tween().tween_property(_alb, "color:a", 0.0, 0.6)
		await _cazi_jos(_warlock.global_position, 0.9, false)
	_warlock.ridica_toiagul(0.0, 0.6)
	Stare.marcheaza(marcaj_lupta)
	Stare.seteaza_sarcina(sarcina_lupta)
	jucator.seteaza_purtat(false)
	_hud(true)
	await c.opreste()
	_porneste_lupta()


# ---------------------------------------------------------------------------------------------------------------
# 2. Lupta
# ---------------------------------------------------------------------------------------------------------------

func _porneste_lupta() -> void:
	_runda += 1
	_viata = viata_maxima
	_viata_jucator = viata_jucator
	_faza_doi = false
	_faza_doi_ceruta = false
	_ascuns = false
	_lupta_activa = true
	_bara.arata(nume_boss)
	_bara.viata_jucator(_viata_jucator, viata_jucator)
	_muzica.volume_db = -30.0
	_muzica.play()
	create_tween().tween_property(_muzica, "volume_db", Sunet.VOLUM_MUZICA, 2.0)
	_warlock.furie = 0.5
	_lupta()


func _lupta() -> void:
	var r := _runda
	var atacuri := 0
	if not await _asteapta(1.2):
		return
	while r == _runda and _lupta_activa:
		if _faza_doi_ceruta and not _faza_doi:
			await _treci_in_faza_doi()
			if r != _runda:
				return
		var j := _jucator()
		var distanta := Vector2(j.global_position.x - _warlock.global_position.x, j.global_position.z - _warlock.global_position.z).length()
		if distanta < 4.5:
			await _unda()
			if r != _runda:
				return
			await _teleport()
			atacuri = 0
		else:
			var alese := ["salva", "fulgere", "glob", "salva"]
			alese.erase(_ultimul_atac)
			_ultimul_atac = alese.pick_random()
			match _ultimul_atac:
				"salva":
					await _salva()
				"fulgere":
					await _fulgere()
				"glob":
					await _glob_mare()
			if r != _runda:
				return
			atacuri += 1
			if atacuri >= (2 if _faza_doi else 3) or randf() < 0.15:
				await _teleport()
				atacuri = 0
		if r != _runda:
			return
		var pauza := randf_range(1.0, 1.6) if _faza_doi else randf_range(1.5, 2.4)
		if not await _asteapta(pauza):
			return


## Salva: ridică mâna și aruncă 3 (în faza a doua 5) vrăji roșii, una după alta, spre unde ești. Te poți feri.
func _salva() -> void:
	var r := _runda
	_warlock.ridica_mana(-1.5, 0.35, 0.0)
	if not await _asteapta(0.45):
		return
	for i in (5 if _faza_doi else 3):
		var de_la := _warlock.palma()
		var tinta := _piept_jucator()
		var dir := (tinta - de_la).normalized()
		# trece de tine și se oprește în pământ sau departe în spate
		var la := tinta + dir * 14.0
		if la.y < 0.0 and dir.y < -0.01:
			la = tinta + dir * minf(14.0, (tinta.y - 0.05) / -dir.y)
		var viteza := 17.0 if _faza_doi else 14.0
		var v := VrajaAtac.trage(self, de_la, la, "rosu", 0.8, de_la.distance_to(la) / viteza, 0.25, false)
		_proiectile.append([v, damage_vraja, 0.75, r])
		if not await _asteapta(0.32 if _faza_doi else 0.45):
			return
	_warlock.ridica_mana(0.0, 0.5, 0.0)


## Fulgere: cercuri roșii pe asfalt (unul sub tine, altele în jur), iar după o clipă loviturile din cer.
func _fulgere() -> void:
	var r := _runda
	_warlock.ridica_toiagul(-2.8, 0.5)
	VrajaAtac.sunet_la(self, SUNET_TUNET, _warlock.global_position + Vector3.UP * 6.0, Sunet.VOLUM_EFECTE - 6.0, 16.0)
	if not await _asteapta(0.5):
		return
	var valuri := 3 if _faza_doi else 2
	for val in valuri:
		var j := _jucator()
		var centre: Array[Vector3] = [j.global_position + j.velocity * Vector3(0.5, 0.0, 0.5)]
		for k in (3 if _faza_doi else 2):
			var u := randf() * TAU
			centre.append(j.global_position + Vector3(cos(u), 0.0, sin(u)) * randf_range(2.5, 5.0))
		for c in centre:
			_fulger_pe(Vector3(c.x, j.global_position.y, c.z), 1.0 if _faza_doi else 1.2, r)
		if not await _asteapta(0.9):
			return
	_warlock.ridica_toiagul(0.0, 0.6)


func _fulger_pe(centru: Vector3, avertizare: float, r: int) -> void:
	# cercul de pe asfalt, o coloană roșie slabă (să-l vezi și cu coada ochiului) și un sfârâit de energie
	var inel := _inel(centru + Vector3.UP * 0.04, 1.5, Color(1.0, 0.2, 0.12, 0.9))
	inel.scale = Vector3(0.2, 0.04, 0.2)
	var coloana := _stalp_lumina(centru, 4.0, 0.25, Color(1.0, 0.2, 0.12))
	(coloana.material_override as ShaderMaterial).set_shader_parameter("putere", 0.0)
	VrajaAtac.sunet_la(self, SUNET_VRAJA, centru + Vector3.UP, Sunet.VOLUM_EFECTE - 6.0, 6.0, 0.15)
	var t := create_tween().set_parallel()
	t.tween_property(inel, "scale", Vector3(1.0, 0.04, 1.0), avertizare).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_method(func(v: float) -> void: (coloana.material_override as ShaderMaterial).set_shader_parameter("putere", v),
		0.0, 0.55, avertizare)
	await get_tree().create_timer(avertizare, false).timeout
	if is_instance_valid(inel):
		inel.queue_free()  # (la moarte îl șterge deja _curata)
	coloana.queue_free()
	if r != _runda or not _lupta_activa:
		return
	Fulger.loveste(self, centru + Vector3(randf_range(-3, 3), 30.0, randf_range(-3, 3)), centru, ROSU, 0.28, true, 0.8)
	_fum_rosu(centru + Vector3.UP * 0.2, 12)
	var j := _jucator()
	var d := Vector2(j.global_position.x - centru.x, j.global_position.z - centru.z).length()
	if d < 1.6:
		if ScutJucator.activ:
			_scut_lovit(centru + Vector3.UP * 2.4)
		else:
			_raneste(damage_fulger, centru, false)


## Globul mare: îl încarcă deasupra toiagului, apoi îl aruncă; te urmărește puțin. Te dărâmă dacă nu ai scutul.
func _glob_mare() -> void:
	var r := _runda
	_warlock.ridica_toiagul(-2.6, 0.6)
	var incarcare := _sunet_incarcare()
	var glob := _glob_mic()
	var t := 0.0
	var durata := 1.0 if _faza_doi else 1.4
	while t < durata:
		await get_tree().process_frame
		if r != _runda or not is_instance_valid(glob):
			if is_instance_valid(glob):
				glob.queue_free()
			incarcare.queue_free()
			return
		if get_tree().paused:
			continue
		t += get_process_delta_time()
		glob.global_position = _warlock.varf_toiag() + Vector3.UP * 0.35
		glob.scale = Vector3.ONE * lerpf(0.2, 1.0, minf(t / durata, 1.0))
	incarcare.queue_free()
	_warlock.ridica_toiagul(-1.3, 0.2)
	VrajaAtac.sunet_la(self, SUNET_ORB_ZBOR, glob.global_position, Sunet.VOLUM_EFECTE - 2.0, 14.0)
	var dir := (_piept_jucator() - glob.global_position).normalized()
	_globuri.append({"nod": glob, "viteza": dir * (11.0 if _faza_doi else 9.0), "timp": 0.0, "runda": r})
	await _asteapta(0.4)
	if r == _runda:
		_warlock.ridica_toiagul(0.0, 0.6)


func _misca_globuri(delta: float) -> void:
	if get_tree().paused:
		return
	for g in _globuri.duplicate():
		var nod: Node3D = g["nod"]
		if not is_instance_valid(nod) or g["runda"] != _runda:
			if is_instance_valid(nod):
				nod.queue_free()
			_globuri.erase(g)
			continue
		g["timp"] += delta
		var v: Vector3 = g["viteza"]
		# te urmărește în prima secundă și jumătate (se întoarce încet spre tine), apoi merge drept
		if g["timp"] < 1.5:
			var spre := (_piept_jucator() - nod.global_position).normalized() * v.length()
			v = v.lerp(spre, 1.0 - exp(-delta * 1.6))
			g["viteza"] = v
		nod.global_position += v * delta
		var scut_centru := _jucator().global_position + Vector3.UP * 1.3
		var lovit := false
		if ScutJucator.activ and nod.global_position.distance_to(scut_centru) < 1.6:
			_scut_lovit(nod.global_position)
			Sunet.reda(SUNET_ORB_BUM, Sunet.VOLUM_EFECTE - 6.0, 0.1)
			lovit = true
		elif nod.global_position.distance_to(_piept_jucator()) < 0.9:
			Sunet.reda(SUNET_ORB_BUM, Sunet.VOLUM_EFECTE - 3.0, 0.1)
			_alb.color = Color(1.0, 0.5, 0.45, 0.6)
			create_tween().tween_property(_alb, "color:a", 0.0, 0.5)
			_raneste(damage_glob, nod.global_position - v, true)
			lovit = true
		elif nod.global_position.y < 0.1 or g["timp"] > 4.0:
			_explozie_vraja(nod.global_position, 1.3)
			lovit = true
		if lovit:
			nod.queue_free()
			_globuri.erase(g)


func _misca_proiectile() -> void:
	if _proiectile.is_empty() or get_tree().paused:
		return
	var j := _jucator()
	var scut_centru := j.global_position + Vector3.UP * 1.3
	for p in _proiectile.duplicate():
		var v: VrajaAtac = p[0]
		if not is_instance_valid(v) or v._gata:
			_proiectile.erase(p)
			continue
		if p[3] != _runda:
			_explodeaza_acum(v)
			_proiectile.erase(p)
			continue
		# lângă tine nu explodează (particulele ar acoperi tot ecranul): se stinge în scut sau în tine
		if ScutJucator.activ and v.global_position.distance_to(scut_centru) < 1.45:
			v.queue_free()
			_scut_lovit(v.global_position)
			_proiectile.erase(p)
		elif v.global_position.distance_to(_piept_jucator()) < p[2]:
			v.queue_free()
			Sunet.reda(SUNET_ORB_BUM, Sunet.VOLUM_EFECTE - 10.0, 0.1)
			_raneste(p[1], v.global_position - (v._la - v._de_la).normalized(), false)
			_proiectile.erase(p)


func _explodeaza_acum(v: VrajaAtac) -> void:
	v._la = v.global_position
	v._explodeaza()


## Unda de șoc (când stai lângă el): bate toiagul în pământ, un inel roșu fuge pe asfalt și te aruncă.
func _unda() -> void:
	var r := _runda
	var centru := _warlock.global_position
	_warlock.ridica_toiagul(-2.9, 0.6)
	_warlock.ridica_mana(-2.6, 0.6, 0.4)
	var avertizare := _inel(centru + Vector3.UP * 0.05, 1.0, Color(1.0, 0.25, 0.15, 0.8))
	avertizare.scale = Vector3(0.4, 0.04, 0.4)
	var lumina := _lumina_scurta(centru + Vector3.UP * 0.5, ROSU, 0.5, 6.0, 0.01)
	var t := create_tween().set_parallel()
	t.tween_property(avertizare, "scale", Vector3(1.2, 0.04, 1.2), 0.9)
	t.tween_property(lumina, "light_energy", 4.0, 0.9)
	VrajaAtac.sunet_la(self, SUNET_VRAJA, centru + Vector3.UP, Sunet.VOLUM_EFECTE, 10.0)
	if not await _asteapta(0.9 if not _faza_doi else 0.7):
		avertizare.queue_free()
		return
	avertizare.queue_free()
	if is_instance_valid(lumina):
		lumina.queue_free()
	_warlock.ridica_toiagul(-0.6, 0.12)
	_warlock.ridica_mana(0.0, 0.3, 0.0)
	VrajaAtac.sunet_la(self, SUNET_ORB_BUM, centru, Sunet.VOLUM_EFECTE - 4.0, 12.0)
	_lumina_scurta(centru + Vector3.UP, ROSU, 10.0, 14.0, 0.6)
	_fum_rosu(centru + Vector3.UP * 0.3, 30)
	var unda := _inel(centru + Vector3.UP * 0.06, 1.0, Color(1.0, 0.35, 0.2, 1.0))
	var raza := 7.0
	var lovit := [false]
	var pas := func(k: float) -> void:
		var rz := lerpf(0.5, raza, k)
		unda.scale = Vector3(rz, 0.04, rz)
		if lovit[0] or r != _runda:
			return
		var j := _jucator()
		var d := Vector2(j.global_position.x - centru.x, j.global_position.z - centru.z).length()
		if d <= rz and d > rz - 1.5:
			lovit[0] = true
			if ScutJucator.activ:
				_scut_lovit(j.global_position + Vector3.UP * 1.3 + (centru - j.global_position).normalized() * 1.1)
			else:
				_raneste(damage_unda, centru, false, 9.0)
	var tw := create_tween()
	tw.tween_method(pas, 0.0, 1.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(a: float) -> void: (unda.material_override as StandardMaterial3D).albedo_color.a = a, 1.0, 0.0, 0.5)
	await tw.finished
	unda.queue_free()
	if r == _runda:
		_warlock.ridica_toiagul(0.0, 0.5)


## Se topește într-un fum roșu și apare în alt loc din parcare, departe de tine.
func _teleport() -> void:
	var r := _runda
	if not _lupta_activa:
		return
	var j := _jucator()
	var aici := _warlock.global_position
	var bune: Array[Vector3] = []
	for p in locuri_teleport:
		var d := Vector2(p.x - j.global_position.x, p.z - j.global_position.z).length()
		if d > 7.0 and d < 24.0 and p.distance_to(aici) > 3.0:
			bune.append(p)
	if bune.is_empty():
		for p in locuri_teleport:
			if p.distance_to(aici) > 3.0:
				bune.append(p)
	var unde: Vector3 = bune.pick_random()
	VrajaAtac.sunet_la(self, SUNET_TELEPORT, aici + Vector3.UP, Sunet.VOLUM_EFECTE, 14.0)
	_fum_rosu(aici + Vector3.UP * 1.0, 24)
	_ascuns = true
	_forma_tinta.set_deferred("disabled", true)
	await _warlock.ascunde(0.35).finished
	if r != _runda:
		return
	if not await _asteapta(0.35):
		return
	_warlock.global_position = unde
	_intoarce_warlock(_jucator().global_position, 1.0)
	VrajaAtac.sunet_la(self, SUNET_TELEPORT, unde + Vector3.UP, Sunet.VOLUM_EFECTE, 14.0)
	_fum_rosu(unde + Vector3.UP * 1.0, 24)
	_lumina_scurta(unde + Vector3.UP * 1.5, ROSU, 6.0, 10.0, 0.5)
	await _warlock.aparitie(0.35).finished
	_ascuns = false
	_forma_tinta.set_deferred("disabled", false)


## Sub jumătate de viață: urcă în aer, fulgere în jurul lui, cerul și ceața se înroșesc; de acum e mai rapid.
func _treci_in_faza_doi() -> void:
	_faza_doi = true
	var r := _runda
	var centru := _warlock.global_position
	_warlock.ridica_toiagul(-2.9, 0.6)
	_warlock.ridica_mana(-2.6, 0.6, 0.5)
	create_tween().tween_property(_warlock, "furie", 1.0, 1.5)
	create_tween().tween_property(_warlock, "plutire", 1.1, 1.5).set_trans(Tween.TRANS_SINE)
	VrajaAtac.sunet_la(self, SUNET_TUNET, centru + Vector3.UP * 8.0, Sunet.VOLUM_EFECTE, 18.0)
	_tween_cer(1.0, 2.5)
	for k in 4:
		var u := k * TAU / 4.0 + randf() * 0.5
		var jos := centru + Vector3(cos(u), 0.0, sin(u)) * randf_range(2.5, 4.0)
		Fulger.loveste(self, jos + Vector3(0, 30, 0), jos, ROSU, 0.3, k == 0, 1.0)
		if not await _asteapta(0.3):
			return
	await _asteapta(0.6)
	if r == _runda:
		create_tween().tween_property(_warlock, "plutire", 0.5, 1.0).set_trans(Tween.TRANS_SINE)
		_warlock.ridica_toiagul(0.0, 0.6)
		_warlock.ridica_mana(0.0, 0.6, 0.0)


## Scutul tău a oprit ceva: fulgeră, sar scântei din el și se aude lovitura (fără damage).
func _scut_lovit(punct: Vector3) -> void:
	var j := _jucator()
	var scut := get_tree().get_first_node_in_group("scut_jucator")
	if scut:
		scut.call("lovit")
	var centru := j.global_position + Vector3.UP * 1.3
	var n := punct - centru
	n = n.normalized() if n.length() > 0.01 else -j.global_basis.z
	var s := VrajaAtac.particule(self, 40, 0.45, 0.022, [Color(1, 1, 1, 1), Color(0.85, 0.6, 1.0, 1.0), Color(1.0, 0.3, 0.2, 0.8),
		Color(1.0, 0.3, 0.2, 0.0)])
	s.global_position = centru + n * 1.25
	s.one_shot = true
	s.explosiveness = 1.0
	s.direction = n
	s.spread = 75.0
	s.initial_velocity_min = 2.0
	s.initial_velocity_max = 6.0
	s.gravity = Vector3(0, -5, 0)
	s.emitting = true
	get_tree().create_timer(1.0, false).timeout.connect(s.queue_free)
	_lumina_scurta(centru + n * 1.4, Color(0.8, 0.5, 1.0), 3.0, 5.0, 0.3)
	Sunet.reda(SUNET_SCUT, Sunet.VOLUM_EFECTE - 6.0, 0.1)
	Sunet.reda(SUNET_IMPACT, Sunet.VOLUM_EFECTE - 8.0, 0.1)
	Zguduire.porneste(_camera_jucator, 0.015, 0.25)


## Te lovește ceva (fără scut): viața scade, roșu pe ecran, camera sare, ești împins; `doboara` = cazi jos.
func _raneste(damage: float, dinspre: Vector3, doboara: bool, impins := 4.0) -> void:
	if not _lupta_activa or _viata_jucator <= 0.0:
		return
	var j := _jucator()
	_viata_jucator = maxf(_viata_jucator - damage, 0.0)
	_bara.viata_jucator(_viata_jucator, viata_jucator)
	_bara.ranit(clampf(damage / 30.0, 0.5, 1.0))
	Sunet.reda(SUNET_IMPACT, Sunet.VOLUM_EFECTE - 3.0, 0.1)
	Zguduire.porneste(_camera_jucator, 0.04, 0.4)
	var spate := j.global_position - dinspre
	spate.y = 0.0
	if spate.length() > 0.01 and not _jos:
		j.velocity += spate.normalized() * impins
	if _viata_jucator <= 0.0:
		_ai_murit()
	elif doboara and not _jos:
		_cazi_jos(dinspre, 0.5, true)


## Cazi pe spate (camera jos, privirea spre cer) și te ridici. `in_lupta` = jocul merge mai departe după.
func _cazi_jos(dinspre: Vector3, cat_stai: float, in_lupta: bool) -> void:
	_jos = true
	var j := _jucator()
	var cap: Node3D = j.get_node("Cap")
	var cap_inainte := cap.position
	var era_purtat := not j.is_physics_processing()
	j.seteaza_purtat(true)
	if in_lupta:
		Stare.meniu_deschis = true
	var spate := j.global_position - dinspre
	spate.y = 0.0
	spate = spate.normalized() if spate.length() > 0.01 else -j.global_basis.z
	# cât te poate împinge înapoi fără să intri în ceva
	var departe := 1.1
	var cerere := PhysicsRayQueryParameters3D.create(j.global_position + Vector3.UP * 0.5, j.global_position + Vector3.UP * 0.5 + spate * 1.6)
	cerere.exclude = [j.get_rid()]
	var lovit := get_world_3d().direct_space_state.intersect_ray(cerere)
	if not lovit.is_empty():
		departe = maxf(j.global_position.distance_to(lovit.position) - 0.5, 0.0)
	Sunet.reda(SUNET_CAZUT, Sunet.VOLUM_EFECTE, 0.05)
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(j, "global_position", j.global_position + spate * departe, 0.4).set_ease(Tween.EASE_OUT)
	t.tween_property(cap, "position:y", 0.3, 0.4)
	t.tween_property(cap, "rotation:x", 0.75, 0.4)
	t.tween_property(_camera_jucator, "rotation:z", 0.3, 0.4)
	await t.finished
	Zguduire.porneste(_camera_jucator, 0.03, 0.3)
	await get_tree().create_timer(cat_stai, false).timeout
	if in_lupta and _viata_jucator <= 0.0:
		return  # ai murit cât erai jos: „YOU DIED” se ocupă de cameră
	var sus := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sus.tween_property(cap, "position", cap_inainte, 0.6)
	sus.tween_property(cap, "rotation:x", 0.0, 0.6)
	sus.tween_property(_camera_jucator, "rotation:z", 0.0, 0.6)
	await sus.finished
	if in_lupta and _viata_jucator <= 0.0:
		return
	if not era_purtat:
		j.seteaza_purtat(false)
	if in_lupta and _lupta_activa:
		Stare.meniu_deschis = false
	_jos = false


## „YOU DIED”: cazi, totul se oprește, mesajul roșu, negru, apoi lupta de la capăt (de la ușă).
func _ai_murit() -> void:
	_lupta_activa = false
	_runda += 1
	_curata()
	var j := _jucator()
	var cap: Node3D = j.get_node("Cap")
	j.seteaza_purtat(true)
	Stare.meniu_deschis = true
	_hud(false)
	create_tween().tween_property(_muzica, "volume_db", -40.0, 1.5)
	Sunet.reda(SUNET_MURIT, Sunet.VOLUM_EFECTE)
	_bara.ascunde(1.0)
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(cap, "position:y", 0.25, 1.0)
	t.tween_property(cap, "rotation:x", 0.1, 1.0)
	t.tween_property(_camera_jucator, "rotation:z", 1.25, 1.0)
	await _bara.mesaj("YOU DIED", BaraBoss.ROSU_DESCHIS, 3.2)
	var negru := create_tween()
	negru.tween_property(_negru, "color:a", 1.0, 1.0)
	await negru.finished
	_muzica.stop()
	# de la capăt: tu la ușă, el în mijlocul parcării, viața plină, cerul ca înainte
	_tween_cer(0.0, 0.01)
	_warlock.global_position = loc_aparitie
	_warlock.plutire = 0.5
	_warlock.ridica_toiagul(0.0, 0.01)
	_warlock.ridica_mana(0.0, 0.01, 0.0)
	_ascuns = false
	_forma_tinta.set_deferred("disabled", false)
	ModelPS2.disparitie(_warlock._model, 0.0)
	_pune_jucatorul(loc_usa, loc_aparitie)
	cap.position = Vector3(0.0, 1.55, 0.0)
	_camera_jucator.rotation.z = 0.0
	_jos = false
	await get_tree().create_timer(0.6, false).timeout
	j.seteaza_purtat(false)
	Stare.meniu_deschis = false
	_hud(true)
	var lumina := create_tween()
	lumina.tween_property(_negru, "color:a", 0.0, 1.0)
	await lumina.finished
	_porneste_lupta()


## Scoate vrăjile din aer, globurile, cercurile.
func _curata() -> void:
	for p in _proiectile:
		if is_instance_valid(p[0]) and not p[0]._gata:
			_explodeaza_acum(p[0])
	_proiectile.clear()
	for g in _globuri:
		if is_instance_valid(g["nod"]):
			g["nod"].queue_free()
	_globuri.clear()
	for n in _de_sters:
		if is_instance_valid(n):
			n.queue_free()
	_de_sters.clear()


# ---------------------------------------------------------------------------------------------------------------
# 3. Finalul: Head Witch îi ia puterile
# ---------------------------------------------------------------------------------------------------------------

func _invins() -> void:
	_lupta_activa = false
	_runda += 1
	_curata()
	Stare.marcheaza(marcaj_invins)
	Stare.seteaza_sarcina("")
	_finalul(true)


func _finalul(din_lupta: bool) -> void:
	var j := _jucator()
	var c := Cutscena.porneste(self)
	_hud(false)
	j.seteaza_purtat(true)
	# (dacă erai jos când l-ai terminat: te ridici)
	var cap: Node3D = j.get_node("Cap")
	create_tween().set_parallel().tween_property(cap, "position", Vector3(0.0, 1.55, 0.0), 0.5)
	create_tween().tween_property(_camera_jucator, "rotation:z", 0.0, 0.5)
	if din_lupta:
		create_tween().tween_property(_muzica, "volume_db", -40.0, 2.0)
		_warlock.tresare(_warlock.global_position - j.global_position, 2.5)
		_lumina_scurta(_piept_warlock(), ROSU, 8.0, 10.0, 0.6)
		Sunet.reda(SUNET_IMPACT, Sunet.VOLUM_EFECTE)
		await c.priveste(_piept_warlock(), 0.5)
		# cade în genunchi (plan din lateral, de jos: de unde stai tu poate fi o mașină în cale)
		var w := _warlock.global_position
		var spre_tine := (j.global_position - w) * Vector3(1, 0, 1)
		spre_tine = spre_tine.normalized() if spre_tine.length() > 0.1 else Vector3.BACK
		var latura := spre_tine.cross(Vector3.UP)
		_film(w + spre_tine * 5.2 + latura * 2.8 + Vector3.UP * 1.3, w + Vector3.UP * 1.2, 50.0,
			w + spre_tine * 4.4 + latura * 2.3 + Vector3.UP * 1.1, 4.5, _warlock, 1.0)
		await _warlock.prabusire(1.3).finished
		VrajaAtac.sunet_la(self, SUNET_CAZUT, _warlock.global_position, Sunet.VOLUM_EFECTE + 4.0, 10.0)
		_praf(_warlock.global_position)
		Zguduire.porneste(_camera_jucator, 0.02, 0.3)
		Sunet.reda(SUNET_DOBORAT, Sunet.VOLUM_EFECTE)
		_bara.ascunde(0.6)
		await _bara.mesaj("WARLOCK DEFEATED", BaraBoss.AURIU, 2.4)
		_muzica.stop()
	else:
		await c.priveste(_piept_warlock(), 0.01)

	# Head Witch se ridică (plan de pe trotuar, dinspre ușa 122; din parcare ar fi mașina neagră în cale)
	var jos_ea: Vector3 = _sefa_ref.global_position
	_film(jos_ea + Vector3(-3.2, 1.3, 0.55), jos_ea + Vector3.UP * 0.6, 50.0, jos_ea + Vector3(-2.6, 1.5, 0.6), 4.0, _sefa_ref, 0.9)
	c.priveste(jos_ea + Vector3.UP * 0.6, 0.01)
	await _sefa_ref.ridica_te()
	await get_tree().create_timer(0.4, false).timeout
	# plutește până la el
	_sefa_ref.distanta_privire = 0.0
	var start: Vector3 = _sefa_ref.global_position
	var spre := _warlock.global_position - start
	spre.y = 0.0
	var dir := spre.normalized()
	var oprire := _warlock.global_position - dir * 2.4
	oprire.y = _warlock.global_position.y
	_sefa_ref.rotation.y = atan2(dir.x, dir.z)
	var lateral := dir.cross(Vector3.UP)
	var durata := clampf(start.distance_to(oprire) / 4.0, 1.5, 4.0)
	var mijloc := (start + oprire) * 0.5
	_film(mijloc + lateral * 7.0 + Vector3.UP * 1.6, mijloc + Vector3.UP * 1.2, 55.0, mijloc + lateral * 6.0 + dir * 1.5 + Vector3.UP * 1.8,
		durata, _sefa_ref, 1.3)
	var zbor := create_tween()
	zbor.tween_method(func(k: float) -> void:
		_sefa_ref.global_position = start.lerp(oprire, k) + Vector3.UP * 0.25 * sin(k * PI), 0.0, 1.0, durata) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await zbor.finished

	# îi trage puterile: raza roșie din pieptul lui în palma ei
	var piept := _piept_warlock() + Vector3.UP * 0.3
	await _sefa_ref.intinde_bratul(piept, 0.5).finished
	Sunet.reda(SUNET_ABSORBTIE, Sunet.VOLUM_EFECTE)
	# peste umărul ei, de pe partea fără braț (altfel brațul și pălăria acoperă tot)
	var palma_parte := signf((_sefa_ref.palma() - oprire).dot(lateral))
	if palma_parte == 0.0:
		palma_parte = 1.0
	_film(oprire - dir * 2.6 - lateral * palma_parte * 1.9 + Vector3.UP * 2.1, piept, 50.0,
		oprire - dir * 2.2 - lateral * palma_parte * 1.6 + Vector3.UP * 2.2, 2.4)
	_raza_absorbtie = _raza(ROSU)
	var curgere := _curgere()
	_warlock.smuls(3.5)
	_tween_cer(1.0, 3.0)
	var aura := OmniLight3D.new()
	aura.light_color = Color(0.95, 0.25, 0.3)
	aura.light_energy = 0.0
	aura.omni_range = 5.0
	_sefa_ref.add_child(aura)
	aura.position = Vector3.UP * 1.3
	create_tween().tween_property(aura, "light_energy", 4.0, 4.0)
	var fulgere := func() -> void:
		for k in 3:
			await get_tree().create_timer(0.8, false).timeout
			var u := randf() * TAU
			var jos := _warlock.global_position + Vector3(cos(u), 0.0, sin(u)) * randf_range(3.0, 6.0)
			Fulger.loveste(self, jos + Vector3(0, 30, 0), jos, ROSU, 0.25, true, 0.7)
	fulgere.call()
	await get_tree().create_timer(2.4, false).timeout
	# de aproape: fața ei în lumina roșie
	var fata: Vector3 = _sefa_ref.global_position + Vector3.UP * 1.6
	# (de partea cealaltă a brațului întins, ca raza să nu treacă prin fața camerei)
	var spre_palma: Vector3 = _sefa_ref.palma() - fata
	spre_palma -= dir * spre_palma.dot(dir)
	spre_palma.y = 0.0
	spre_palma = spre_palma.normalized() if spre_palma.length() > 0.01 else lateral
	# (din profil, aproape în dreptul feței: raza pleacă din palmă înainte, deci departe de cameră)
	_film(fata + dir * 0.15 - spre_palma * 1.6 + Vector3.UP * 0.05, fata, 45.0, fata + dir * 0.2 - spre_palma * 1.3, 2.4)
	await get_tree().create_timer(2.4, false).timeout
	# implozia: el se face cenușă, raza se rupe
	_alb.color = Color(1.0, 0.75, 0.7, 0.9)
	create_tween().tween_property(_alb, "color:a", 0.0, 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	Zguduire.porneste(_camera_film, 0.04, 0.5)
	_cenusa(_piept_warlock())
	if is_instance_valid(_raza_absorbtie):
		_raza_absorbtie.queue_free()
	curgere.emitting = false
	get_tree().create_timer(1.0, false).timeout.connect(curgere.queue_free)
	_warlock.dispari(0.6)
	_tween_cer(0.0, 3.0)
	create_tween().tween_property(aura, "light_energy", 1.2, 1.5)
	_sefa_ref.brat_scut(false, 0.8)
	await get_tree().create_timer(1.6, false).timeout

	# vine la tine
	_camera_jucator.make_current()
	await c.priveste(_sefa_ref.global_position + Vector3.UP * 1.5, 0.8)
	var de_la: Vector3 = _sefa_ref.global_position
	var spre_ea := de_la - j.global_position
	spre_ea.y = 0.0
	var la := j.global_position + spre_ea.normalized() * 2.2
	la.y = j.global_position.y
	_sefa_ref.rotation.y = atan2(-spre_ea.x, -spre_ea.z)
	var vine := create_tween()
	var timp_vine := clampf(de_la.distance_to(la) / 4.0, 0.8, 3.5)
	vine.tween_method(func(k: float) -> void:
		_sefa_ref.global_position = de_la.lerp(la, k) + Vector3.UP * 0.2 * sin(k * PI)
		_priveste_acum(_sefa_ref.global_position + Vector3.UP * 1.5), 0.0, 1.0, timp_vine).set_trans(Tween.TRANS_SINE)
	await vine.finished
	_sefa_ref.distanta_privire = 9.0
	var intoarcere = _sefa_ref.intoarce_spre(j)
	if intoarcere:
		await intoarcere.finished
	await c.priveste(_sefa_ref.global_position + Vector3.UP * 1.55, 0.4)
	Dialog.spune(replici_final)
	if Dialog.activ:
		await Dialog.terminat
	await _sefa_ref.dispari_de_tot(Color(0.9, 0.3, 0.4))
	Stare.marcheaza(marcaj_final)
	Stare.seteaza_sarcina(sarcina_dupa)
	await get_tree().create_timer(1.0, false).timeout
	j.seteaza_purtat(false)
	_hud(true)
	await c.opreste()


# ---------------------------------------------------------------------------------------------------------------
# Efecte
# ---------------------------------------------------------------------------------------------------------------

## Plan „de film”: de la `poz` (spre `tinta`) alunecă la `poz2` în `durata` s; `urmarit` = se uită după el.
func _film(poz: Vector3, tinta: Vector3, fov: float, poz2: Vector3, durata: float, urmarit: Node3D = null, inaltime := 1.5) -> void:
	_camera_film.fov = fov
	_camera_film.global_position = poz
	_camera_film.look_at(tinta)
	_camera_film.make_current()
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_method(func(k: float) -> void:
		if not _camera_film.current:
			return
		_camera_film.global_position = poz.lerp(poz2, k)
		if is_instance_valid(urmarit):
			_camera_film.look_at(urmarit.global_position + Vector3.UP * inaltime)
		else:
			_camera_film.look_at(tinta), 0.0, 1.0, durata)


func _lumina_scurta(p: Vector3, culoare: Color, energie: float, raza: float, durata: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = culoare
	l.light_energy = energie
	l.omni_range = raza
	l.omni_attenuation = 0.8
	add_child(l)
	l.global_position = p
	if durata > 0.05:
		var t := create_tween()
		t.tween_property(l, "light_energy", 0.0, durata).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_callback(l.queue_free)
	else:
		_de_sters.append(l)
	return l


func _fum_rosu(unde: Vector3, cat: int) -> void:
	var f := VrajaAtac.particule(self, cat, 1.2, 0.45, [Color(1.0, 0.35, 0.25, 0.8), Color(0.45, 0.08, 0.08, 0.5), Color(0.15, 0.05, 0.05, 0.0)])
	f.global_position = unde
	f.one_shot = true
	f.explosiveness = 1.0
	f.emission_sphere_radius = 0.6
	f.spread = 180.0
	f.initial_velocity_min = 0.5
	f.initial_velocity_max = 2.0
	f.damping_min = 1.0
	f.damping_max = 2.0
	f.gravity = Vector3(0, 0.8, 0)
	f.emitting = true
	get_tree().create_timer(1.8, false).timeout.connect(f.queue_free)


func _praf(unde: Vector3) -> void:
	var f := VrajaAtac.particule(self, 18, 1.4, 0.5, [Color(0.3, 0.28, 0.28, 0.5), Color(0.2, 0.18, 0.18, 0.3), Color(0.1, 0.1, 0.1, 0.0)])
	f.global_position = unde + Vector3.UP * 0.2
	f.one_shot = true
	f.explosiveness = 1.0
	f.emission_sphere_radius = 0.5
	f.direction = Vector3.UP
	f.spread = 90.0
	f.initial_velocity_min = 0.5
	f.initial_velocity_max = 1.5
	f.damping_min = 1.0
	f.damping_max = 2.0
	f.emitting = true
	get_tree().create_timer(1.8, false).timeout.connect(f.queue_free)


func _cenusa(unde: Vector3) -> void:
	var f := VrajaAtac.particule(self, 80, 2.2, 0.08, [Color(1.0, 0.6, 0.4, 1.0), Color(0.5, 0.15, 0.1, 0.9), Color(0.15, 0.12, 0.12, 0.0)])
	f.global_position = unde
	f.one_shot = true
	f.explosiveness = 0.9
	f.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	f.emission_box_extents = Vector3(0.4, 1.0, 0.4)
	f.direction = Vector3.UP
	f.spread = 60.0
	f.initial_velocity_min = 0.6
	f.initial_velocity_max = 2.2
	f.gravity = Vector3(0, 0.6, 0)
	f.emitting = true
	get_tree().create_timer(2.6, false).timeout.connect(f.queue_free)


func _explozie_vraja(unde: Vector3, marime: float) -> void:
	VrajaAtac.trage(self, unde, unde, "rosu", marime, 0.01, 0.0, false, false)
	VrajaAtac.sunet_la(self, SUNET_ORB_BUM, unde, Sunet.VOLUM_EFECTE - 6.0, 8.0 * marime)


func _sunet_incarcare() -> AudioStreamPlayer3D:
	var s := AudioStreamPlayer3D.new()
	s.stream = SUNET_INCARCARE
	s.bus = &"Efecte"
	s.unit_size = 12.0
	s.max_distance = 120.0
	s.volume_db = Sunet.VOLUM_EFECTE - 4.0
	_warlock.add_child(s)
	s.position = Vector3.UP * 2.5
	s.play()
	return s


## Globul roșu de pe toiag (miez alb, straturi roșii, lumină).
func _glob_mic() -> Node3D:
	var g := Node3D.new()
	for strat in [[0.16, Color(1.0, 0.92, 0.88), false], [0.3, Color(1.0, 0.3, 0.2, 0.7), true], [0.5, Color(0.7, 0.06, 0.05, 0.45), true]]:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = strat[0]
		s.height = strat[0] * 2.0
		s.radial_segments = 12
		s.rings = 6
		mi.mesh = s
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = strat[1]
		mat.disable_fog = true
		if strat[2]:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.add_child(mi)
	var lumina := OmniLight3D.new()
	lumina.light_color = ROSU
	lumina.light_energy = 4.0
	lumina.omni_range = 8.0
	g.add_child(lumina)
	var trase := VrajaAtac.particule(g, 30, 0.5, 0.06, [Color(1.0, 0.5, 0.4, 0.0), Color(1.0, 0.35, 0.25, 1.0), Color(1.0, 0.9, 0.85, 1.0)])
	trase.local_coords = true
	trase.emission_sphere_radius = 1.0
	trase.radial_accel_min = -18.0
	trase.radial_accel_max = -12.0
	trase.emitting = true
	add_child(g)
	g.global_position = _warlock.varf_toiag() + Vector3.UP * 0.35
	g.scale = Vector3.ONE * 0.2
	_de_sters.append(g)
	return g


## Un inel plat pe asfalt (cercurile de avertizare, unda de șoc): raza exterioară `raza` (la scara 1).
func _inel(centru: Vector3, raza: float, culoare: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = raza * 0.86
	mesh.outer_radius = raza
	mesh.rings = 32
	mesh.ring_segments = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = culoare
	mat.disable_fog = true
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = centru
	mi.scale = Vector3(1.0, 0.04, 1.0)  # plat pe asfalt (cine îl scalează păstrează y-ul)
	_de_sters.append(mi)
	return mi


func _stalp_lumina(jos: Vector3, inalt: float, raza: float, culoare: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = raza
	mesh.bottom_radius = raza * 1.2
	mesh.height = inalt
	mesh.radial_segments = 16
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_RAZA
	mat.set_shader_parameter("culoare", culoare)
	mat.set_shader_parameter("putere", 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = jos + Vector3.UP * inalt * 0.5
	return mi


## Raza absorbției: un cilindru subțire (shader-ul undei), întins între două puncte în fiecare cadru (`_aseaza_raza`).
func _raza(culoare: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.09
	mesh.height = 1.0
	mesh.radial_segments = 10
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_RAZA
	mat.set_shader_parameter("culoare", culoare)
	mat.set_shader_parameter("putere", 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Cilindrul (axa Y, jos = UV.y 1, partea groasă și albă) de la `de_la` (sus, se pierde) la `la` (jos, strălucește).
func _aseaza_raza(mi: MeshInstance3D, de_la: Vector3, la: Vector3) -> void:
	var d := de_la - la
	var lungime := d.length()
	if lungime < 0.01:
		return
	var y := d / lungime
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	mi.global_transform = Transform3D(Basis(x, y * lungime, z), (de_la + la) * 0.5)


## Energia care curge din el spre palma ei (particule trase spre ea).
func _curgere() -> CPUParticles3D:
	var p := VrajaAtac.particule(self, 90, 0.7, 0.04, [Color(1.0, 0.5, 0.4, 0.0), Color(1.0, 0.3, 0.2, 1.0), Color(1.0, 0.85, 0.8, 1.0)])
	var de_la := _piept_warlock()
	var la: Vector3 = _sefa_ref.palma()
	p.global_position = de_la
	p.emission_sphere_radius = 0.6
	p.direction = (la - de_la).normalized()
	p.spread = 6.0
	var v := de_la.distance_to(la) / 0.7
	p.initial_velocity_min = v * 0.9
	p.initial_velocity_max = v * 1.05
	p.gravity = Vector3.ZERO
	p.emitting = true
	return p


## Cerul și ceața spre roșu (`k` = 1) sau înapoi cum erau (0), în `durata` s.
func _tween_cer(k: float, durata: float) -> void:
	if _env == null:
		return
	var de_la := {"fog_light_color": _env.fog_light_color, "fog_density": _env.fog_density,
		"ambient_light_color": _env.ambient_light_color, "ambient_light_energy": _env.ambient_light_energy}
	var spre := {"fog_light_color": (_env_initial["fog_light_color"] as Color).lerp(Color(0.32, 0.06, 0.06), k),
		"fog_density": lerpf(_env_initial["fog_density"], _env_initial["fog_density"] * 1.6, k),
		"ambient_light_color": (_env_initial["ambient_light_color"] as Color).lerp(Color(0.6, 0.2, 0.22), k),
		"ambient_light_energy": lerpf(_env_initial["ambient_light_energy"], _env_initial["ambient_light_energy"] * 1.3, k)}
	create_tween().tween_method(func(x: float) -> void:
		_env.fog_light_color = (de_la["fog_light_color"] as Color).lerp(spre["fog_light_color"], x)
		_env.fog_density = lerpf(de_la["fog_density"], spre["fog_density"], x)
		_env.ambient_light_color = (de_la["ambient_light_color"] as Color).lerp(spre["ambient_light_color"], x)
		_env.ambient_light_energy = lerpf(de_la["ambient_light_energy"], spre["ambient_light_energy"], x), 0.0, 1.0, durata)
