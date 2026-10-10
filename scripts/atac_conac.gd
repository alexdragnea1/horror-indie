extends Node3D
## Atacul Warlock-ului asupra sediului coven-ului (conac.tscn, nodul `AtacConac`). Pornește când ieși din conac după ce
## ai învățat Fireball (`marcaj_necesar`) și încă n-a fost atacul (`marcaj_atac`). O scenă de film (~50 s, Cutscena):
##   1. cobori scara; cerul se întunecă și se înroșește, tună, felinarele se sting unul câte unul, cornul de război;
##   2. armata: `vrajitori` vrăjitori apar din fulgere roșii pe deal, dincolo de gard (plan larg, `CameraFilm`);
##   3. Warlock-ul coboară din cer într-un stâlp de lumină roșie (plan de jos), ridică privirea; prima vrajă sparge poarta;
##   4. bombardamentul: vrăji de foc, mov și roșii lovesc conacul, fulgere în turn și în turelă (plan din lateral), ferestrele
##      se sting; tobele de război;
##   5. vrăjitoarele coven-ului apar în curte și trag înapoi (scutul roșu al Warlock-ului le oprește vrăjile); Head Witch
##      apare lângă tine; armata le doboară pe rând;
##   6. vraja mare: Warlock-ul se ridică în aer, vrăjitorii îi trimit raze, globul roșu crește deasupra toiagului (plan peste
##      umărul lui), Head Witch ridică un scut mov în jurul vostru; globul zboară pe deasupra ta și lovește conacul:
##      alb, bubuitura, suflul sparge scutul și te aruncă pe spate; țiuit, inima, ochii se închid;
##   7. pe negru: conacul e ruină (`conac_distrus.glb`), arde, vrăjitoare moarte în curte, armata a plecat (`marcaj_atac`);
##   8. te trezești pe jos, vezi ruina, te ridici, Head Witch se ridică și ea (`marcaj_trezit`, `sarcina_dupa`).
## La Continue: fără `marcaj_atac` atacul pornește din nou; cu el e ruina (iar fără `marcaj_trezit`, trezirea).
## Ce urmează (vorbitul cu ea și zborul spre casă) e în sefa_ruine.gd.

const CONAC_DISTRUS := preload("res://models/conac_distrus.glb")
const MATERIAL := preload("res://shaders/material_model.tres")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const SCRIPT_FLACARA := preload("res://scripts/flacara.gd")
const SHADER_SCUT := preload("res://shaders/scut.gdshader")
const SHADER_RAZA := preload("res://shaders/raza_vraja.gdshader")
const VRAJITOARE := [preload("res://models/vrajitoare_salon_1.glb"), preload("res://models/vrajitoare_salon_2.glb"),
	preload("res://models/vrajitoare_salon_3.glb"), preload("res://models/vrajitoare_salon_4.glb")]
const SUNET_TUNET := preload("res://sunete/atac_tunet.ogg")
## Cornul „de film” (10.10): cornul sintetizat peste drone-ul de groază și metalul care rezonează (vezi sunete.sh).
const SUNET_CORN := preload("res://sunete/atac_corn_film.ogg")
const SUNET_SOSIRE := preload("res://sunete/warlock_sosire.ogg")
const SUNET_TOBE := preload("res://sunete/atac_tobe.ogg")
const SUNET_SCUT := preload("res://sunete/scut.ogg")
const SUNET_SCUT_SPART := preload("res://sunete/scut_spart.ogg")
const SUNET_INCARCARE := preload("res://sunete/orb_incarcare.ogg")
const SUNET_ORB_ZBOR := preload("res://sunete/orb_zbor.ogg")
const SUNET_ORB_BUM := preload("res://sunete/orb_explozie.ogg")
const SUNET_INIMA := preload("res://sunete/inima_lenta.ogg")
const SUNET_TIUIT := preload("res://sunete/tiuit.ogg")
const SUNET_FOC := preload("res://sunete/foc_trosnet.ogg")
const SUNET_MUZICA := preload("res://sunete/atac_tristete.ogg")
const SUNET_IMPACT := preload("res://sunete/atac_impact_vechi.ogg")
const SUNET_VRAJA_VECHE := preload("res://sunete/atac_vraja_veche.ogg")
const SUNET_FULGER := preload("res://sunete/atac_fulger_natural.ogg")
const SUNET_TUNET_NEBUN := preload("res://sunete/atac_tunet_nebun.ogg")
const SUNET_CUTREMUR := preload("res://sunete/atac_cutremur.ogg")
## Tunetul nebun vine după fulgerele care lovesc aproape, dar cel mult o dată la atâtea secunde (armata vine cu ~10
## fulgere unul după altul, toiagul primește unul la 0,5-0,9 s).
const PAUZA_TUNET := 1.4
const PASI := [preload("res://sunete/pas_poteca_1.ogg"), preload("res://sunete/pas_poteca_2.ogg"), preload("res://sunete/pas_poteca_3.ogg"),
	preload("res://sunete/pas_poteca_4.ogg")]

@export var marcaj_necesar := "a_invatat_fireball"
@export var marcaj_atac := "conacul_atacat"
@export var marcaj_trezit := "s_a_trezit_dupa_atac"
## După zborul spre casă cu Head Witch (sefa_ruine.gd): muzica tristă nu mai pornește.
@export var marcaj_plecat := "a_zburat_acasa_dupa_atac"
@export var sarcina_dupa := "Talk to the Head Witch."
@export var conac: Node3D
@export var usa: Interactabil
## Head Witch (sefa_ruine.gd): apare în atac lângă tine, după atac zace lângă tine.
@export var sefa: Node3D
@export var mediu: WorldEnvironment
@export var luna: DirectionalLight3D
@export var afara: Node3D
@export var deal: DealConac
## Luminile calde ale conacului (de la ușă, din geamuri): se sting.
@export var lumini_conac: Array[Light3D] = []
@export var vant: AudioStreamPlayer
@export var sperieturi: Node

@export_group("Locuri")
## De unde pornește atacul: ușa conacului (ca `DinConac`), chiar dacă la Continue erai în altă parte a curții.
@export var loc_usa := Vector3(0.0, 0.95, -7.1)
## Unde stai în atac (cu fața spre poartă) și cât te aruncă suflul spre poartă (metri).
@export var loc_jucator := Vector3(5.0, 0.05, 1.2)
@export var aruncat := 2.4
## Unde apare Head Witch în atac (lângă tine, în stânga).
@export var loc_sefa := Vector3(3.6, 0.05, 1.6)
## Warlock-ul: unde aterizează (pe deal, dincolo de poartă) și cât se ridică în aer la vraja mare.
@export var loc_warlock := Vector3(0.0, 0.0, 39.0)
@export var ridicare_warlock := 4.5
@export var vrajitori := 20
## Unde lovește vraja mare (ușa conacului).
@export var tinta_vraja_mare := Vector3(0.0, 6.0, -8.4)
## Camera planului cu vrăjitoarele coven-ului (pe podestul scării, în spatele lor).
@export var plan_aparatoare := Vector3(0.0, 2.7, -7.4)

@export_group("Culori")
@export var cer_furtuna := {"culoare_sus": Color(0.02, 0.012, 0.025), "culoare_mijloc": Color(0.07, 0.025, 0.05),
	"culoare_orizont": Color(0.24, 0.07, 0.07), "culoare_apus": Color(0.75, 0.16, 0.08)}
@export var cer_ruina := {"culoare_sus": Color(0.012, 0.012, 0.03), "culoare_mijloc": Color(0.05, 0.03, 0.05),
	"culoare_orizont": Color(0.32, 0.11, 0.06), "culoare_apus": Color(0.6, 0.22, 0.1)}

## Ținte pe fațada conacului (în lume) pentru bombardament: aripile, turnul, turela, mijlocul (acolo sunt găurile ruinei).
const TINTE := [Vector3(9.6, 7.6, -10.4), Vector3(-11.2, 8.0, -10.4), Vector3(15.9, 15.5, -8.8), Vector3(-15.8, 19.5, -8.6),
	Vector3(0.0, 9.5, -8.4), Vector3(-4.0, 11.5, -9.8), Vector3(4.5, 5.0, -9.8), Vector3(-5.0, 4.5, -9.8), Vector3(12.5, 3.5, -10.6),
	Vector3(-12.5, 4.0, -10.6), Vector3(0.0, 13.5, -9.0), Vector3(6.0, 10.0, -9.8), Vector3(-15.8, 9.0, -8.6), Vector3(15.9, 6.0, -8.8)]
## Focurile din ruină: poziție, mărime.
const FOCURI := [[Vector3(0.0, 1.6, -9.0), 1.6], [Vector3(-2.2, 4.6, -12.5), 1.1], [Vector3(2.4, 8.1, -13.0), 1.0],
	[Vector3(0.5, 1.6, -15.0), 1.2], [Vector3(9.8, 7.0, -11.0), 0.8], [Vector3(-11.2, 7.4, -12.4), 0.7],
	[Vector3(15.9, 13.8, -10.7), 0.8], [Vector3(-15.8, 17.8, -10.4), 0.7], [Vector3(-9.5, 1.0, -5.5), 0.8],
	[Vector3(9.8, 0.7, -9.6), 0.6], [Vector3(-4.0, 0.6, -6.0), 0.6]]
## Vrăjitoarele coven-ului care ies să lupte și mor: poziție (în lume), unghiul în care zac. Primele patru ies în atac.
const MORTI := [[Vector3(-5.2, 0.05, -1.4), 0.6], [Vector3(1.8, 0.05, -2.2), 2.4], [Vector3(8.6, 0.05, -2.8), -0.8],
	[Vector3(-8.8, 0.05, 2.4), 1.9], [Vector3(1.4, 0.05, 11.0), 3.0], [Vector3(-3.8, 0.05, 13.5), -2.2]]

var _c: Cutscena
var _camera_jucator: Camera3D
var _camera_film: Camera3D
var _strat: CanvasLayer
var _alb: ColorRect
var _pleoapa_sus: ColorRect
var _pleoapa_jos: ColorRect
var _env: Environment
var _cer: ShaderMaterial
var _warlock: Warlock
var _armata: Array[VrajitorArmata] = []
var _aparatoare: Array[Node3D] = []
var _de_sters: Array[Node] = []
var _ultimul_tunet := -100.0
var _tobe: AudioStreamPlayer
var _muzica: AudioStreamPlayer
var _ruina: Node3D
var _zguduit := 0.0
var _filtre := []
var _volum_coborat := false
## Fără tip: au metodele din scripturile lor (sefa_ruine.gd, afara_conac.gd).
var _sefa
var _afara


func _ready() -> void:
	_sefa = sefa
	_afara = afara
	var jucator := _jucator()
	if jucator == null or not Stare.e_marcat(marcaj_necesar):
		return
	_camera_jucator = jucator.get_node("Cap/Camera3D")
	# o copie: resursa e a scenei (s-ar păstra schimbată dacă scena e încă în memorie)
	_env = mediu.environment.duplicate(true) as Environment
	mediu.environment = _env
	_cer = _env.sky.sky_material as ShaderMaterial
	_fa_stratul()
	if Stare.e_marcat(marcaj_atac):
		_fa_ruina()
		if not Stare.e_marcat(marcaj_trezit):
			_pleoape_la(1.0)
			await get_tree().process_frame
			await _trezire(false)
		elif not Stare.e_marcat(marcaj_plecat):
			_porneste_muzica(4.0)
		return
	usa.activ = false
	await get_tree().process_frame
	# încă pe negru: stai în ușa conacului (și la Continue, oriunde ai fi fost în curte)
	jucator.global_position = loc_usa
	jucator.rotation.y = PI
	(jucator.get_node("Cap") as Node3D).rotation.x = 0.0
	while Tranzitie.activa:
		await get_tree().process_frame
	await _atacul()


func _jucator() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("jucator") as CharacterBody3D


func _exit_tree() -> void:
	VrajaAtac.volum_impact = 0.0
	Fulger.volum_sunet = 0.0
	Fulger.marime_sunet = 18.0
	Fulger.sunet_pocnet = Fulger.SUNET
	VrajaAtac.sunet_arunca = VrajaAtac.SUNET_ARUNCA
	VrajaAtac.sunet_lovit = VrajaAtac.SUNET_LOVIT
	_scoate_filtrele()
	# volumul general e și al Tranzitie: îl punem la loc doar dacă l-am coborât noi (leșinul) și nu l-am ridicat încă
	if _volum_coborat:
		AudioServer.set_bus_volume_db(0, 0.0)


func _process(_delta: float) -> void:
	# camera care se zgâlțâie (cutremurul vrăjii mari, exploziile): pe camera care se vede acum
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if _zguduit > 0.001:
		cam.h_offset = randf_range(-1.0, 1.0) * 0.06 * _zguduit
		cam.v_offset = randf_range(-1.0, 1.0) * 0.06 * _zguduit
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


## Zguduie camera: urcă la `putere` și se stinge în `durata` secunde.
func _zguduie(putere: float, durata: float) -> void:
	var t := create_tween()
	t.tween_property(self, "_zguduit", putere, 0.05)
	t.tween_property(self, "_zguduit", 0.0, durata).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------------------------------------------------
# Atacul
# ---------------------------------------------------------------------------------------------------------------

func _atacul() -> void:
	var jucator := _jucator()
	var cap: Node3D = jucator.get_node("Cap")
	_c = Cutscena.porneste(self)
	jucator.seteaza_purtat(true)
	_hud(false)
	# fulgerele cad la 30-40 m de tine: pocnetul lor (3D) mai tare și auzit de departe
	Fulger.volum_sunet = 8.0
	Fulger.marime_sunet = 45.0
	# sunetele de dinainte de 10.10 pentru vrăji (owner: „ăla primul era bun”) și un fulger natural, nu de magie
	Fulger.sunet_pocnet = SUNET_FULGER
	VrajaAtac.sunet_arunca = SUNET_VRAJA_VECHE
	VrajaAtac.sunet_lovit = SUNET_IMPACT
	_camera_film = Camera3D.new()
	_camera_film.fov = 52.0
	_camera_film.near = 0.1
	_camera_film.far = 600.0
	add_child(_camera_film)

	# 1. ieși pe ușă și cobori scara spre curte; cerul se întunecă, tună
	jucator.global_position = loc_usa
	jucator.rotation.y = PI
	cap.rotation.x = 0.0
	_tween_cer(cer_furtuna, 0.016, 0.42, 9.0)
	if vant:
		create_tween().tween_property(vant, "volume_db", Sunet.VOLUM_AMBIANTA + 6.0, 6.0)
	if sperieturi:
		sperieturi.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().create_timer(1.2).timeout.connect(func() -> void: Sunet.reda(SUNET_TUNET, Sunet.VOLUM_EFECTE + 2.0))
	get_tree().create_timer(2.4).timeout.connect(func() -> void: _fulger_departe(Vector3(-60, 0, 120)))
	_c.priveste(loc_warlock + Vector3.UP * 4.0, 2.5)
	await _mergi(jucator, [jucator.global_position, Vector3(0.6, 0.95, -6.6), Vector3(1.0, 0.05, -3.4), loc_jucator], 5.0)
	await _c.priveste(loc_warlock + Vector3.UP * 2.0, 1.0)

	# felinarele se sting unul câte unul, vântul tace, cornul de război
	if afara and afara.has_method("stinge_felinarele"):
		_afara.stinge_felinarele(true)
	await get_tree().create_timer(1.0).timeout
	if vant:
		create_tween().tween_property(vant, "volume_db", Sunet.VOLUM_AMBIANTA - 10.0, 2.0)
	Sunet.reda(SUNET_CORN, Sunet.VOLUM_EFECTE - 2.0)
	_fulger_departe(Vector3(40, 0, 140))
	await get_tree().create_timer(2.2).timeout

	# 2. armata apare din fulgere: primii trei îi vezi tu, restul în planul larg
	var locuri := _locuri_armata()
	for i in 3:
		_aduce_vrajitor(locuri[i], i)
		await get_tree().create_timer(0.55).timeout
	_film(Vector3(-13.0, 6.5, 17.0), Vector3(-1.0, 2.0, 38.0), 50.0, Vector3(-9.0, 5.0, 20.5), 5.2)
	_tobe = AudioStreamPlayer.new()
	_tobe.stream = SUNET_TOBE
	_tobe.bus = &"Efecte"
	_tobe.volume_db = -30.0
	add_child(_tobe)
	_tobe.play()
	create_tween().tween_property(_tobe, "volume_db", Sunet.VOLUM_EFECTE - 2.0, 2.0)
	for i in range(3, locuri.size()):
		_aduce_vrajitor(locuri[i], i)
		await get_tree().create_timer(0.22).timeout
	await get_tree().create_timer(1.0).timeout

	# 3. Warlock-ul coboară din cer, într-un stâlp de lumină roșie
	var sol := _sol(loc_warlock)
	_warlock = Warlock.new()
	add_child(_warlock)
	_warlock.global_position = sol + Vector3.UP * 14.0
	_warlock.rotation.y = PI  # spre conac
	_warlock.priveste(sol + Vector3(0, 2, -10))
	# camera jos, puțin în fața lui: îl urmărește cum coboară, cu stâlpul de lumină în spate
	_film(sol + Vector3(3.2, 1.0, -6.0), sol, 56.0, sol + Vector3(2.4, 1.2, -4.8), 6.0, _warlock, 1.7)
	Sunet.reda(SUNET_SOSIRE, Sunet.VOLUM_EFECTE)
	var stalp := _stalp_lumina(sol, 30.0, 1.3, Color(1.0, 0.18, 0.12))
	var coboara := create_tween()
	coboara.tween_property(_warlock, "global_position", sol, 3.0).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(2.9).timeout
	# aterizarea: cutremurul (valul de praf fuge pe jos, pământul huruie câteva secunde)
	Sunet.reda(SUNET_CUTREMUR, Sunet.VOLUM_EFECTE + 3.0)
	_zguduie(2.2, 3.5)
	_inel_praf(sol + Vector3.UP * 0.2, 9.0, Color(0.45, 0.2, 0.18))
	_lumina_scurta(sol + Vector3.UP * 2.0, Color(1.0, 0.25, 0.15), 18.0, 25.0, 1.0)
	create_tween().tween_method(func(v: float) -> void: (stalp.material_override as ShaderMaterial).set_shader_parameter("putere", v), 1.0, 0.0, 1.5)
	await get_tree().create_timer(1.6).timeout
	# ridică privirea spre conac, ochii se aprind
	_warlock.furie = 0.6
	_warlock.ridica_toiagul(-0.9, 0.8)
	await get_tree().create_timer(1.6).timeout

	# prima vrajă sparge poarta (o vezi cu ochii tăi)
	_camera_jucator.make_current()
	_c.priveste(sol + Vector3.UP * 2.0, 0.01)
	await get_tree().create_timer(0.5).timeout
	_warlock.ridica_mana(-1.6, 0.3)
	var poarta := Vector3(0.0, 1.4, 31.2)
	var v := VrajaAtac.trage(self, _warlock.palma(), poarta, "rosu", 1.6, 0.9, 1.0)
	await v.lovit
	_zguduie(0.6, 0.8)
	if afara and afara.has_method("strica_poarta"):
		_afara.strica_poarta()
	_warlock.ridica_mana(-0.2, 0.8)

	# 4. bombardamentul: toată armata trage în conac (în listă: lambda-ul ar ține o copie a unui bool)
	var bombardament := [true]
	var trage := func() -> void:
		var k := 0
		while bombardament[0]:
			var vr: VrajitorArmata = _armata.pick_random()
			var tinta: Vector3 = TINTE[k % TINTE.size()] + Vector3(randf_range(-1.2, 1.2), randf_range(-1.0, 1.0), 0.0)
			vr.arunca(tinta, randf_range(0.8, 1.2), randf_range(1.2, 1.7))
			k += 1
			await get_tree().create_timer(randf_range(0.18, 0.34)).timeout
	# zeci de impacturi deodată: mai încet, ca vraja mare de la final să fie vârful scenei
	VrajaAtac.volum_impact = -5.0
	trage.call()
	_stinge_conacul(7.0)
	await get_tree().create_timer(1.0).timeout
	await _c.priveste(Vector3(4.0, 7.0, -10.0), 1.4)
	get_tree().create_timer(0.8).timeout.connect(func() -> void: _fulger_in(Vector3(-15.8, 19.5, -10.4)))
	await get_tree().create_timer(2.2).timeout
	_film(Vector3(27.0, 5.5, 6.0), Vector3(0.0, 7.0, -9.0), 55.0, Vector3(25.0, 6.5, 2.5), 4.2)
	get_tree().create_timer(1.3).timeout.connect(func() -> void: _fulger_in(Vector3(15.9, 16.0, -10.7)))
	await get_tree().create_timer(4.2).timeout

	# 5. vrăjitoarele coven-ului apar în curte și trag înapoi: plan de pe podestul scării, din spatele lor, spre armată
	bombardament[0] = false
	get_tree().create_timer(1.6).timeout.connect(func() -> void: VrajaAtac.volum_impact = 0.0)
	var scut_warlock := _scut(sol + Vector3.UP * 1.6, 3.4, Color(1.0, 0.2, 0.15))
	_film(plan_aparatoare, loc_warlock + Vector3.UP * 2.5, 58.0, plan_aparatoare + Vector3(0.6, 0.15, 1.2), 9.5)
	for i in 4:
		_aparatoare.append(_vrajitoare_lupta(MORTI[i][0]))
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(0.5).timeout
	for i in 6:
		var w: Node3D = _aparatoare[i % _aparatoare.size()]
		_trage_aparatoare(w, sol + Vector3(randf_range(-1.5, 1.5), randf_range(1.0, 3.0), randf_range(-3.6, -2.6)), scut_warlock)
		await get_tree().create_timer(0.35).timeout
	await get_tree().create_timer(0.6).timeout
	# armata le doboară pe rând: zboară pe spate, spre conac (spre cameră)
	for i in _aparatoare.size():
		var w: Node3D = _aparatoare[i]
		var vr: VrajitorArmata = _armata[(i * 5 + 2) % _armata.size()]
		var vraja: VrajaAtac = await vr.arunca(w.global_position + Vector3.UP * 1.2, 1.1, 1.0)
		vraja.piatra = false
		vraja.lovit.connect(func(_p: Vector3) -> void: _doboara(w, vr.global_position))
		await get_tree().create_timer(0.45).timeout
	await get_tree().create_timer(1.6).timeout

	# Head Witch apare lângă tine (te întorci spre ea), apoi te uiți iar la Warlock
	_camera_jucator.make_current()
	_c.priveste(loc_sefa + Vector3.UP * 1.4, 0.01)
	await get_tree().create_timer(0.4).timeout
	if _sefa:
		_sefa.apari_langa(loc_sefa, loc_warlock)
	await get_tree().create_timer(1.3).timeout
	await _c.priveste(loc_warlock + Vector3.UP * 2.0, 0.9)

	# 6. vraja mare
	await _vraja_mare(jucator, cap, sol, scut_warlock)


## Vraja mare: Warlock-ul se ridică, globul crește, scutul lui Head Witch, globul zboară peste tine și lovește conacul.
func _vraja_mare(jucator: CharacterBody3D, cap: Node3D, sol: Vector3, scut_warlock: MeshInstance3D) -> void:
	if is_instance_valid(_tobe):
		create_tween().tween_property(_tobe, "volume_db", -40.0, 1.5)
	Sunet.reda(SUNET_INCARCARE, Sunet.VOLUM_EFECTE)
	var sus := sol + Vector3.UP * ridicare_warlock
	var urca := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	urca.tween_property(_warlock, "global_position", sus, 2.5)
	urca.tween_property(_warlock, "furie", 1.0, 6.0)
	_warlock.ridica_toiagul(-2.9, 1.2)
	_warlock.ridica_mana(-2.7, 1.2, 0.3)
	create_tween().tween_method(func(v: float) -> void: (scut_warlock.material_override as ShaderMaterial).set_shader_parameter("putere", v),
		0.6, 0.0, 1.0)
	_tween_cer({"culoare_sus": Color(0.06, 0.0, 0.01), "culoare_mijloc": Color(0.18, 0.02, 0.03), "culoare_orizont": Color(0.4, 0.06, 0.05),
		"culoare_apus": Color(0.9, 0.12, 0.06)}, 0.018, 0.5, 6.0)
	# globul, deasupra toiagului
	var glob := _glob()
	add_child(glob)
	glob.scale = Vector3.ONE * 0.1
	glob.create_tween().set_loops().tween_property(glob, "rotation:y", TAU, 1.2).from(0.0)
	var crestere := create_tween()
	crestere.tween_method(func(k: float) -> void:
		if is_instance_valid(_warlock):
			glob.global_position = _warlock.varf_toiag() + Vector3.UP * (0.6 + 2.6 * k)
		glob.scale = Vector3.ONE * lerpf(0.1, 3.4, k * k)
		_zguduit = maxf(_zguduit, k * 0.5), 0.0, 1.0, 7.5)
	# vrăjitorii îi trimit raze, fulgere în toiag
	await get_tree().create_timer(1.0).timeout
	for vr in _armata:
		vr.canalizeaza(_warlock.varf_toiag() + Vector3.UP * 2.0)
	var fulgere := [true]
	var loveste_toiagul := func() -> void:
		while fulgere[0]:
			if is_instance_valid(_warlock):
				var varf := _warlock.varf_toiag()
				Fulger.loveste(self, varf + Vector3(randf_range(-8, 8), 30, randf_range(-4, 8)), varf, Color(1.0, 0.35, 0.3), 0.3, true, 0.6)
				_tuna()
			await get_tree().create_timer(randf_range(0.5, 0.9)).timeout
	loveste_toiagul.call()
	# Head Witch ridică scutul în jurul vostru
	await get_tree().create_timer(0.8).timeout
	var mijloc := (loc_jucator + loc_sefa) * 0.5 + Vector3.UP * 1.0
	var scut := _scut(mijloc, 2.6, Color(0.7, 0.42, 1.0))
	(scut.material_override as ShaderMaterial).set_shader_parameter("putere", 0.0)
	if _sefa:
		_sefa.brat_scut(true)
	Sunet.reda(SUNET_SCUT, Sunet.VOLUM_EFECTE - 2.0)
	create_tween().tween_method(func(v: float) -> void: (scut.material_override as ShaderMaterial).set_shader_parameter("putere", v),
		0.0, 0.7, 0.8)
	await get_tree().create_timer(1.0).timeout
	# plan peste umărul Warlock-ului: globul imens, iar departe conacul și voi
	_film(sol + Vector3(3.2, ridicare_warlock + 3.0, 6.5), Vector3(0.0, 4.0, -6.0), 58.0, sol + Vector3(2.4, ridicare_warlock + 3.6, 5.0), 2.6)
	await get_tree().create_timer(2.6).timeout
	_camera_jucator.make_current()
	_c.priveste(glob.global_position, 0.01)
	await crestere.finished
	fulgere[0] = false

	# aruncă globul: zboară pe deasupra ta și lovește conacul
	for vr in _armata:
		vr.canalizeaza(Vector3.ZERO, Color.RED, true)
	_warlock.ridica_toiagul(-1.3, 0.25)
	_warlock.ridica_mana(-1.5, 0.25, 0.0)
	Sunet.reda(SUNET_ORB_ZBOR, Sunet.VOLUM_EFECTE)
	var de_la := glob.global_position
	var peste := loc_jucator + Vector3(0.0, 7.0, 0.0)
	var zbor := create_tween()
	zbor.tween_method(func(k: float) -> void:
		# o curbă Bezier: de la Warlock, pe deasupra ta, în ușa conacului
		var a := de_la.lerp(peste, k)
		var b := peste.lerp(tinta_vraja_mare, k)
		glob.global_position = a.lerp(b, k)
		var ochi: Vector3 = cap.global_position
		var d := glob.global_position - ochi
		jucator.rotation.y = lerp_angle(jucator.rotation.y, atan2(-d.x, -d.z), 0.25)
		cap.rotation.x = lerpf(cap.rotation.x, clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.4, 1.4), 0.25)
		_zguduit = maxf(_zguduit, 0.4), 0.0, 1.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await zbor.finished

	# 7. lovitura: alb, bubuitura, conacul se face ruină, suflul
	glob.queue_free()
	Sunet.reda(SUNET_ORB_BUM, Sunet.VOLUM_EFECTE + 3.0)  # vârful scenei: mai tare decât bombardamentul (îl prinde limitatorul)
	_alb.color.a = 1.0
	create_tween().tween_property(_alb, "color:a", 0.0, 0.9).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_zguduie(2.0, 3.0)
	_schimba_conacul()
	_explozie_mare(tinta_vraja_mare)
	_inel_praf(Vector3(tinta_vraja_mare.x, 0.3, tinta_vraja_mare.z), 40.0, Color(0.5, 0.32, 0.25))
	await get_tree().create_timer(0.35).timeout
	# scutul crapă și se sparge
	var mat_scut := scut.material_override as ShaderMaterial
	create_tween().tween_method(func(v: float) -> void: mat_scut.set_shader_parameter("crapat", v), 0.0, 1.0, 0.18)
	mat_scut.set_shader_parameter("lovit", 1.0)
	await get_tree().create_timer(0.2).timeout
	Sunet.reda(SUNET_SCUT_SPART, Sunet.VOLUM_EFECTE)
	_cioburi_scut(scut.global_position, 2.6, Color(0.75, 0.5, 1.0))
	scut.queue_free()
	_asurzeste()
	# te aruncă pe spate
	var spre := Vector3(loc_jucator.x - tinta_vraja_mare.x, 0.0, loc_jucator.z - tinta_vraja_mare.z).normalized()
	if _sefa:
		_sefa.cade(spre)
	var start := jucator.global_position
	var unde := start + spre * aruncat
	jucator.rotation.y = atan2(spre.x, spre.z)  # cu spatele spre unde zbori (te uiți la conac)
	var t := create_tween().set_parallel()
	t.tween_method(func(k: float) -> void:
		jucator.global_position = start.lerp(unde, k) + Vector3.UP * 0.6 * sin(k * PI), 0.0, 1.0, 0.75)
	t.tween_property(cap, "position:y", 0.22, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(cap, "rotation", Vector3(1.25, 0.0, 0.4), 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	Sunet.reda(PASI[0], Sunet.VOLUM_EFECTE, 0.0, &"Efecte", 0.6)
	_zguduie(0.8, 0.6)

	# 8. leșini: inima încetinește, ochii se închid
	await get_tree().create_timer(1.0).timeout
	Sunet.reda(SUNET_INIMA, Sunet.VOLUM_EFECTE, 0.0, &"Interfata")
	var ochi := create_tween()
	ochi.tween_method(_pleoape_la, 0.0, 0.55, 1.2)
	ochi.tween_method(_pleoape_la, 0.55, 0.2, 0.5)
	ochi.tween_interval(0.5)
	ochi.tween_method(_pleoape_la, 0.2, 0.8, 1.0)
	ochi.tween_method(_pleoape_la, 0.8, 0.6, 0.4)
	ochi.tween_method(_pleoape_la, 0.6, 1.0, 1.4)
	_volum_coborat = true
	ochi.parallel().tween_method(func(db: float) -> void: AudioServer.set_bus_volume_db(0, db), 0.0, -40.0, 2.5)
	await ochi.finished
	await get_tree().create_timer(1.2).timeout

	# pe negru: armata pleacă, rămâne ruina
	for n in _de_sters:
		if is_instance_valid(n):
			n.queue_free()
	_de_sters.clear()
	for vr in _armata:
		if is_instance_valid(vr):
			vr.queue_free()
	_armata.clear()
	if is_instance_valid(_warlock):
		_warlock.queue_free()
	for vr in get_children():
		if vr is Ragdoll:
			vr.queue_free()
	if is_instance_valid(_tobe):
		_tobe.queue_free()
	_camera_film.queue_free()
	_scoate_filtrele()
	_cer_ruina_acum()
	_focuri()
	_morti()
	_zguduit = 0.0
	Stare.marcheaza(marcaj_atac)
	_c.queue_free()
	await get_tree().create_timer(1.0).timeout
	await _trezire(true)


# ---------------------------------------------------------------------------------------------------------------
# Ruina
# ---------------------------------------------------------------------------------------------------------------

## Conacul distrus în locul celui întreg, cu tot ce ține de el (luminile se sting, ușa nu mai merge).
func _schimba_conacul() -> void:
	if is_instance_valid(conac):
		var t := conac.global_transform
		conac.queue_free()
		_ruina = CONAC_DISTRUS.instantiate() as Node3D
		_ruina.set_script(SCRIPT_MODEL)
		_ruina.set("material", MATERIAL)
		_ruina.set("stralucitoare", PackedStringArray(["Lumini"]))
		_ruina.set("stralucire", 2.0)
		_ruina.set("coliziune", 3)
		get_parent().add_child.call_deferred(_ruina)
		_ruina.set_deferred("global_transform", t)
		conac = null
	for l in lumini_conac:
		if is_instance_valid(l):
			l.hide()
	if usa:
		usa.activ = false


## Totul cum e după atac (la Continue).
func _fa_ruina() -> void:
	_schimba_conacul()
	if afara and afara.has_method("stinge_felinarele"):
		_afara.stinge_felinarele(false)
	if afara and afara.has_method("strica_poarta"):
		_afara.strica_poarta()
	if sperieturi:
		sperieturi.process_mode = Node.PROCESS_MODE_DISABLED
	_cer_ruina_acum()
	_focuri()
	_morti()


func _cer_ruina_acum() -> void:
	_seteaza_cer(cer_ruina)
	_env.fog_light_color = Color(0.22, 0.09, 0.06)
	_env.fog_density = 0.022
	_env.volumetric_fog_albedo = Color(0.6, 0.36, 0.26)
	_env.volumetric_fog_density = 0.016
	_env.ambient_light_color = Color(0.55, 0.32, 0.28)
	_env.ambient_light_energy = 0.42
	if luna:
		luna.light_color = Color(0.7, 0.45, 0.4)
		luna.light_energy = 0.12
	if vant:
		vant.volume_db = Sunet.VOLUM_AMBIANTA


## Focurile din ruină: lumina care pâlpâie, flăcări, fum care urcă, scântei; trosnetul lor la cele mari. Plus jarul care
## cade peste toată curtea.
func _focuri() -> void:
	for i in FOCURI.size():
		var poz: Vector3 = FOCURI[i][0]
		var m: float = FOCURI[i][1]
		var foc := Node3D.new()
		foc.name = "Foc%d" % i
		add_child(foc)
		foc.global_position = poz
		var lumina := OmniLight3D.new()
		lumina.set_script(SCRIPT_FLACARA)
		lumina.set("energie", 2.6 * m)
		lumina.set("tremur", 0.35)
		lumina.light_color = Color(1.0, 0.5, 0.2)
		lumina.omni_range = 7.0 * m + 2.0
		lumina.omni_attenuation = 1.3
		lumina.light_volumetric_fog_energy = 1.2
		lumina.position = Vector3.UP * 0.8 * m
		lumina.shadow_enabled = i < 2
		foc.add_child(lumina)
		var flacari := VrajaAtac.particule(foc, int(26 * m) + 6, 0.9, 0.75 * m, [Color(1.0, 0.85, 0.45, 0.95), Color(1.0, 0.45, 0.15, 0.85),
			Color(0.75, 0.18, 0.08, 0.5), Color(0.2, 0.08, 0.06, 0.0)])
		flacari.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		flacari.emission_box_extents = Vector3(0.7 * m, 0.15, 0.7 * m)
		flacari.direction = Vector3.UP
		flacari.spread = 12.0
		flacari.initial_velocity_min = 1.2 * m
		flacari.initial_velocity_max = 2.6 * m
		flacari.gravity = Vector3(0, 1.0, 0)
		flacari.preprocess = 1.0
		flacari.emitting = true
		var fum := VrajaAtac.particule(foc, int(10 * m) + 4, 7.0, 2.6 * m, [Color(0.25, 0.2, 0.2, 0.0), Color(0.2, 0.17, 0.17, 0.5),
			Color(0.16, 0.14, 0.15, 0.3), Color(0.12, 0.11, 0.12, 0.0)])
		fum.position = Vector3.UP * 1.2 * m
		fum.emission_sphere_radius = 0.5 * m
		fum.direction = Vector3(0.15, 1.0, 0.0)
		fum.spread = 10.0
		fum.initial_velocity_min = 1.2
		fum.initial_velocity_max = 2.0
		fum.gravity = Vector3(0.25, 0.15, 0)
		var creste := Curve.new()
		creste.add_point(Vector2(0.0, 0.4))
		creste.add_point(Vector2(1.0, 1.6))
		fum.scale_amount_curve = creste
		fum.preprocess = 7.0
		fum.emitting = true
		var scantei := VrajaAtac.particule(foc, int(8 * m) + 3, 2.5, 0.06, [Color(1.0, 0.8, 0.4, 1.0), Color(1.0, 0.4, 0.1, 1.0),
			Color(0.6, 0.15, 0.05, 0.0)])
		scantei.position = Vector3.UP * 0.5 * m
		scantei.direction = Vector3.UP
		scantei.spread = 30.0
		scantei.initial_velocity_min = 1.5
		scantei.initial_velocity_max = 3.5
		scantei.gravity = Vector3(0.3, -0.6, 0)
		scantei.preprocess = 2.5
		scantei.emitting = true
		if m >= 1.0:
			var sunet := AudioStreamPlayer3D.new()
			sunet.stream = SUNET_FOC
			sunet.bus = &"Ambianta"
			sunet.volume_db = Sunet.VOLUM_AMBIANTA + 6.0
			sunet.unit_size = 6.0 * m
			sunet.max_distance = 60.0
			sunet.pitch_scale = 0.8
			sunet.autoplay = true
			foc.add_child(sunet)
	# jarul și cenușa care cad peste curte
	var jar := VrajaAtac.particule(self, 140, 10.0, 0.06, [Color(1.0, 0.6, 0.25, 0.0), Color(1.0, 0.5, 0.2, 1.0), Color(0.8, 0.25, 0.1, 0.8),
		Color(0.3, 0.1, 0.05, 0.0)])
	jar.name = "Jar"
	jar.position = Vector3(2.0, 13.0, 0.0)
	jar.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	jar.emission_box_extents = Vector3(22.0, 1.0, 20.0)
	jar.direction = Vector3(0.3, -1.0, 0.1)
	jar.spread = 25.0
	jar.initial_velocity_min = 0.3
	jar.initial_velocity_max = 0.8
	jar.gravity = Vector3(0.15, -0.25, 0.05)
	jar.preprocess = 10.0
	jar.emitting = true


## Vrăjitoarele coven-ului moarte în curte (culcate, ca păpuși de cârpă).
func _morti() -> void:
	for i in MORTI.size():
		var poz: Vector3 = MORTI[i][0]
		var model := _vrajitoare_model(i)
		var cutie := model.get_parent() as Node3D
		cutie.global_position = poz + Vector3.UP * 0.3
		cutie.rotation.y = MORTI[i][1]
		model.rotation.x = -PI / 2.0 if i % 3 else PI / 2.0  # pe spate sau cu fața în jos
		Ragdoll.din_model(model, Vector3(randf_range(-20, 20), 0.0, randf_range(-20, 20)), PackedStringArray(["Ochi"]))


func _vrajitoare_model(i: int) -> Node3D:
	var cutie := Node3D.new()
	add_child(cutie)
	var model := (VRAJITOARE[i % VRAJITOARE.size()] as PackedScene).instantiate() as Node3D
	model.set_script(SCRIPT_MODEL)
	model.set("material", MATERIAL)
	model.set("stralucitoare", PackedStringArray(["Ochi"]))
	model.set("stralucire", 1.5)
	cutie.add_child(model)
	return model


# ---------------------------------------------------------------------------------------------------------------
# Trezirea
# ---------------------------------------------------------------------------------------------------------------

## Te trezești pe jos, pe spate, unde te-a aruncat suflul: ochii se deschid greu, vezi fumul și jarul, ruina care arde,
## te ridici, iar Head Witch se ridică și ea. `din_atac` = imediat după atac (altfel, la Continue).
func _trezire(din_atac: bool) -> void:
	var jucator := _jucator()
	var cap: Node3D = jucator.get_node("Cap")
	var inaltime_ochi := 1.55
	_c = Cutscena.porneste(self)
	jucator.seteaza_purtat(true)
	_hud(false)
	var spre := Vector3(loc_jucator.x - tinta_vraja_mare.x, 0.0, loc_jucator.z - tinta_vraja_mare.z).normalized()
	var unde := loc_jucator + spre * aruncat
	jucator.global_position = unde
	jucator.rotation.y = atan2(spre.x, spre.z)
	cap.position.y = 0.22
	cap.rotation = Vector3(1.25, 0.0, 0.4)
	if not din_atac:
		_pleoape_la(1.0)
		while Tranzitie.activa:
			await get_tree().process_frame
	AudioServer.set_bus_volume_db(0, 0.0)
	_volum_coborat = false
	await get_tree().create_timer(1.5).timeout
	_porneste_muzica(8.0)
	Sunet.reda(SUNET_TIUIT, Sunet.VOLUM_EFECTE - 18.0, 0.0, &"Interfata")
	# clipești: ochii se deschid greu, se închid la loc, apoi rămân deschiși
	var t := create_tween()
	t.tween_method(_pleoape_la, 1.0, 0.6, 0.9)
	t.tween_method(_pleoape_la, 0.6, 1.0, 0.3)
	t.tween_interval(0.8)
	t.tween_method(_pleoape_la, 1.0, 0.35, 0.9)
	t.tween_method(_pleoape_la, 0.35, 0.8, 0.3)
	t.tween_method(_pleoape_la, 0.8, 0.0, 1.0)
	await t.finished
	await get_tree().create_timer(1.6).timeout
	# lași capul în jos, spre picioare: dincolo de ele, conacul arde
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(cap, "rotation", Vector3(0.28, 0.0, 0.15), 2.2)
	await t.finished
	await get_tree().create_timer(2.4).timeout
	# te ridici: întâi în capul oaselor, apoi în picioare
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(cap, "rotation", Vector3(0.05, 0.0, 0.05), 1.0)
	t.parallel().tween_property(cap, "position:y", 0.8, 1.0)
	t.tween_property(cap, "position:y", inaltime_ochi, 1.0)
	t.parallel().tween_property(cap, "rotation", Vector3.ZERO, 1.0)
	await t.finished
	Sunet.reda(PASI[1], Sunet.VOLUM_PASI, 0.05)
	_hud(true)
	# te uiți în jur: vrăjitoarele moarte, Head Witch pe jos
	await _c.priveste(MORTI[0][0] + Vector3.UP * 0.3, 1.6)
	await get_tree().create_timer(0.8).timeout
	if sefa:
		# fața ei: culcată, capul e spre -Z-ul nodului, la vreo 1,5 m de tălpi
		var fata_ei := sefa.global_position - sefa.global_basis.z * 1.5 + Vector3.UP * 0.3
		await _c.priveste(fata_ei, 1.2)
		await get_tree().create_timer(0.6).timeout
		_c.priveste(sefa.global_position + Vector3.UP * 1.5, 2.6)
		await _sefa.ridica_te()
	Stare.marcheaza(marcaj_trezit)
	if sarcina_dupa != "":
		Stare.seteaza_sarcina(sarcina_dupa)
	jucator.seteaza_purtat(false)
	await _c.opreste()


func _porneste_muzica(intrare: float) -> void:
	if _muzica:
		return
	_muzica = AudioStreamPlayer.new()
	_muzica.stream = SUNET_MUZICA
	_muzica.bus = &"Muzica"
	_muzica.volume_db = -40.0
	add_child(_muzica)
	_muzica.play()
	create_tween().tween_property(_muzica, "volume_db", Sunet.VOLUM_MUZICA, intrare).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------------------------------------------------------
# Unelte
# ---------------------------------------------------------------------------------------------------------------

## Merge pe puncte (sus-jos pe scară), cu pași și capul care se clatină.
func _mergi(jucator: CharacterBody3D, puncte: Array, durata: float) -> void:
	var lungimi := [0.0]
	for i in range(1, puncte.size()):
		lungimi.append(lungimi[i - 1] + (puncte[i] as Vector3).distance_to(puncte[i - 1]))
	var total: float = lungimi[-1]
	var cap: Node3D = jucator.get_node("Cap")
	_pas_urmator = 0.4
	var t := create_tween()
	t.tween_method(_mergi_pas.bind(jucator, cap, puncte, lungimi, total), 0.0, 1.0, durata).set_trans(Tween.TRANS_SINE)
	await t.finished
	cap.position.y = 1.55


var _pas_urmator := 0.0


func _mergi_pas(k: float, jucator: CharacterBody3D, cap: Node3D, puncte: Array, lungimi: Array, total: float) -> void:
	var s := total * k
	var i := 1
	while i < puncte.size() - 1 and lungimi[i] < s:
		i += 1
	var a: Vector3 = puncte[i - 1]
	var b: Vector3 = puncte[i]
	var u: float = (s - lungimi[i - 1]) / maxf(lungimi[i] - lungimi[i - 1], 0.001)
	jucator.global_position = a.lerp(b, clampf(u, 0.0, 1.0))
	cap.position.y = 1.55 + sin(s * 4.2) * 0.035
	# un pas la fiecare 0,75 m (pietrișul, piatra scării)
	if s > _pas_urmator:
		_pas_urmator += 0.75
		Sunet.reda(PASI[randi() % PASI.size()], Sunet.VOLUM_PASI, 0.07)


## Unde apar vrăjitorii: două rânduri în arc, pe deal, dincolo de gard (lângă Warlock rămâne loc).
func _locuri_armata() -> Array[Vector3]:
	var locuri: Array[Vector3] = []
	var n_fata := int(vrajitori * 0.6)
	for i in vrajitori:
		var fata := i < n_fata
		var n := n_fata if fata else vrajitori - n_fata
		var k := i if fata else i - n_fata
		var u := deg_to_rad(lerpf(-42.0, 42.0, (k + 0.5) / n)) + randf_range(-0.03, 0.03)
		if fata and absf(u) < deg_to_rad(6.0):
			u += signf(u + 0.001) * deg_to_rad(6.0)
		var r := (36.5 if fata else 41.5) + randf_range(-0.8, 0.8)
		locuri.append(_sol(Vector3(sin(u) * r, 0.0, -0.5 + cos(u) * r)))
	# în ordinea în care apar: din mijloc spre margini, pe sărite
	locuri.shuffle()
	return locuri


func _sol(p: Vector3) -> Vector3:
	return Vector3(p.x, deal.inaltime(p.x, p.z) if deal else 0.0, p.z)


func _aduce_vrajitor(loc: Vector3, i: int) -> void:
	Fulger.loveste(self, loc + Vector3(randf_range(-6, 6), 34.0, randf_range(-3, 6)), loc, Color(1.0, 0.35, 0.3), 0.26, true, 0.8)
	_tuna()
	var vr := VrajitorArmata.creeaza(self, loc, i % 3, Vector3(0.0, 4.0, -8.0))
	_armata.append(vr)
	await get_tree().create_timer(0.08).timeout
	vr.apare()


## Fulger departe, fără să lovească ceva anume: luminează cerul o clipă.
func _fulger_departe(p: Vector3) -> void:
	var jos := _sol(p) if deal else p
	Fulger.loveste(self, jos + Vector3(randf_range(-20, 20), 70.0, 0.0), jos, Color(1.0, 0.5, 0.5), 0.9, false, 2.5)
	var e := _env.ambient_light_energy
	var t := create_tween()
	t.tween_property(_env, "ambient_light_energy", e + 0.7, 0.05)
	t.tween_property(_env, "ambient_light_energy", e, 0.4)
	get_tree().create_timer(0.9).timeout.connect(func() -> void: Sunet.reda(SUNET_TUNET, Sunet.VOLUM_EFECTE + 2.0, 0.1))


## Fulger în conac (turnul, turela): lovește, pocnește piatra.
func _fulger_in(p: Vector3) -> void:
	Fulger.loveste(self, p + Vector3(randf_range(-5, 5), 32.0, randf_range(-4, 4)), p, Color(1.0, 0.4, 0.35), 0.35, true, 1.5)
	_tuna()
	VrajaAtac.sunet_la(self, SUNET_IMPACT, p, Sunet.VOLUM_EFECTE, 16.0)
	_zguduie(0.4, 0.6)


## Ferestrele conacului se sting (cu pâlpâiri) în `durata` secunde.
func _stinge_conacul(durata: float) -> void:
	if not is_instance_valid(conac):
		return
	var geamuri := conac.get_node_or_null("Lumini") as GeometryInstance3D
	for l in lumini_conac:
		var lumina := l
		var t := create_tween()
		t.tween_interval(randf_range(0.5, durata))
		t.tween_property(lumina, "light_energy", 0.0, 0.4)
	if geamuri:
		create_tween().tween_method(_geamuri_pas.bind(geamuri), 0.0, 1.0, durata)


func _geamuri_pas(k: float, geamuri: GeometryInstance3D) -> void:
	if is_instance_valid(geamuri):
		var palpaie := 1.0 if randf() > 0.15 else 0.3
		geamuri.set_instance_shader_parameter("stralucire", 1.4 * (1.0 - k) * palpaie)


func _vrajitoare_lupta(poz: Vector3) -> Node3D:
	var i := _aparatoare.size()
	var model := _vrajitoare_model(i)
	var cutie := model.get_parent() as Node3D
	cutie.global_position = poz
	var d := loc_warlock - poz
	cutie.rotation.y = atan2(d.x, d.z)
	model.scale = Vector3(0.05, 1.3, 0.05)
	var unde := poz + Vector3.UP
	for k in 3:
		_fum_mov(unde + Vector3(0, k * 0.4 - 0.4, 0))
	Sunet.reda_la(preload("res://sunete/matura_scoasa.ogg"), unde, Sunet.VOLUM_EFECTE, 0.1)
	# se teleportează în curte: aceeași apariție ca vrăjitorii Warlock-ului
	VrajaAtac.sunet_la(self, preload("res://sunete/atac_aparitie.ogg"), unde, Sunet.VOLUM_EFECTE - 2.0, 10.0, 0.0)
	create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).tween_property(model, "scale", Vector3.ONE, 0.35)
	return model


## O vrăjitoare a coven-ului trage o vrajă verde spre Warlock: o oprește scutul lui (care sclipește).
func _trage_aparatoare(model: Node3D, tinta: Vector3, scut: MeshInstance3D) -> void:
	if not is_instance_valid(model):
		return
	var brat := model.get_node_or_null("BratDrept") as Node3D
	if brat:
		var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(brat, "rotation:x", -1.6, 0.25)
		await t.finished
	var de_la := brat.to_global(Vector3(0.0, -0.55, 0.06)) if brat else model.global_position + Vector3.UP * 1.3
	var v := VrajaAtac.trage(self, de_la, tinta, "verde", 0.9, 1.4, 2.0, false)
	v.lovit.connect(func(_p: Vector3) -> void:
		var mat := scut.material_override as ShaderMaterial
		mat.set_shader_parameter("putere", 1.0)
		mat.set_shader_parameter("lovit", 1.0)
		var t := create_tween()
		t.tween_method(func(x: float) -> void: mat.set_shader_parameter("lovit", x), 1.0, 0.0, 0.5)
		t.parallel().tween_method(func(x: float) -> void: mat.set_shader_parameter("putere", x), 1.0, 0.25, 0.8))
	if brat:
		create_tween().set_trans(Tween.TRANS_SINE).tween_property(brat, "rotation:x", -0.8, 0.6)


## Vraja armatei o nimerește: zboară pe spate ca o păpușă de cârpă.
func _doboara(model: Node3D, dinspre: Vector3) -> void:
	if not is_instance_valid(model):
		return
	var d := model.global_position - dinspre
	d.y = 0.0
	var impuls := (d.normalized() * 0.85 + Vector3.UP * 0.5).normalized() * 260.0
	Ragdoll.din_model(model, impuls, PackedStringArray(["Ochi"]))


## Stâlpul de lumină în care coboară Warlock-ul (ca unda de la cazan, raza_vraja.gdshader).
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
	_de_sters.append(mi)
	return mi


func _scut(centru: Vector3, raza: float, culoare: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = raza
	mesh.height = raza * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_SCUT
	mat.set_shader_parameter("culoare", culoare)
	mat.set_shader_parameter("putere", 0.25)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = centru
	_de_sters.append(mi)
	return mi


## Globul vrăjii mari: miez alb, straturi roșii adunate unele peste altele, energie trasă spre el, lumină roșie.
func _glob() -> Node3D:
	var g := Node3D.new()
	for strat in [[0.35, Color(1.0, 0.92, 0.88), false], [0.6, Color(1.0, 0.3, 0.2, 0.7), true], [1.0, Color(0.7, 0.06, 0.05, 0.45), true]]:
		var mi := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = strat[0]
		s.height = strat[0] * 2.0
		s.radial_segments = 14
		s.rings = 8
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
	lumina.light_color = Color(1.0, 0.25, 0.15)
	lumina.light_energy = 8.0
	lumina.omni_range = 18.0
	lumina.omni_attenuation = 1.0
	lumina.light_volumetric_fog_energy = 2.0
	g.add_child(lumina)
	var trase := VrajaAtac.particule(g, 70, 0.6, 0.12, [Color(1.0, 0.5, 0.4, 0.0), Color(1.0, 0.35, 0.25, 1.0), Color(1.0, 0.9, 0.85, 1.0)])
	trase.local_coords = true
	trase.emission_sphere_radius = 2.2
	trase.radial_accel_min = -40.0
	trase.radial_accel_max = -30.0
	trase.emitting = true
	return g


func _explozie_mare(p: Vector3) -> void:
	var minge := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 16
	s.rings = 8
	minge.mesh = s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.75, 0.45, 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_fog = true
	minge.material_override = mat
	add_child(minge)
	minge.global_position = p
	var t := create_tween().set_parallel()
	t.tween_property(minge, "scale", Vector3.ONE * 16.0, 1.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color", Color(0.6, 0.1, 0.05, 0.0), 1.4)
	t.chain().tween_callback(minge.queue_free)
	_lumina_scurta(p + Vector3(0, 2, 6), Color(1.0, 0.6, 0.35), 40.0, 60.0, 2.5)
	var foc := VrajaAtac.particule(self, 140, 2.2, 3.0, [Color(1.0, 0.9, 0.6, 1.0), Color(1.0, 0.45, 0.15, 0.9), Color(0.5, 0.12, 0.06, 0.6),
		Color(0.15, 0.1, 0.1, 0.0)])
	foc.global_position = p
	foc.one_shot = true
	foc.explosiveness = 1.0
	foc.emission_sphere_radius = 2.5
	foc.spread = 180.0
	foc.initial_velocity_min = 6.0
	foc.initial_velocity_max = 18.0
	foc.damping_min = 4.0
	foc.damping_max = 8.0
	foc.gravity = Vector3(0, 2.0, 0)
	foc.emitting = true
	var bucati := VrajaAtac.particule(self, 90, 3.0, 0.5, [Color(0.3, 0.27, 0.28), Color(0.25, 0.22, 0.23), Color(0.2, 0.18, 0.19)])
	bucati.global_position = p
	bucati.one_shot = true
	bucati.explosiveness = 1.0
	bucati.emission_sphere_radius = 2.0
	bucati.direction = Vector3(0, 0.5, 1)
	bucati.spread = 75.0
	bucati.initial_velocity_min = 10.0
	bucati.initial_velocity_max = 26.0
	bucati.gravity = Vector3(0, -9.8, 0)
	bucati.emitting = true
	# fumul: mulți nori mai mici, maro-cenușii (unul singur, mare și negru, acoperea flacăra ca o gaură neagră)
	var fum := VrajaAtac.particule(self, 70, 8.0, 3.6, [Color(0.4, 0.3, 0.26, 0.0), Color(0.34, 0.27, 0.24, 0.5), Color(0.24, 0.2, 0.2, 0.3),
		Color(0.16, 0.15, 0.15, 0.0)])
	fum.global_position = p + Vector3.UP * 3.0
	fum.one_shot = true
	fum.explosiveness = 0.5
	fum.emission_sphere_radius = 4.0
	fum.direction = Vector3.UP
	fum.spread = 40.0
	fum.initial_velocity_min = 2.0
	fum.initial_velocity_max = 5.0
	fum.damping_min = 0.5
	fum.damping_max = 1.0
	fum.emitting = true
	for n in [foc, bucati, fum]:
		get_tree().create_timer(9.0).timeout.connect((n as Node).queue_free)


## Un inel de praf care fuge pe pământ din `centru` până la `raza` (suflul).
func _inel_praf(centru: Vector3, raza: float, culoare: Color) -> void:
	var inel := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.85
	tor.outer_radius = 1.0
	tor.rings = 32
	tor.ring_segments = 6
	inel.mesh = tor
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(culoare, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.disable_fog = true
	inel.material_override = mat
	inel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inel)
	inel.global_position = centru
	inel.scale = Vector3(1.0, 0.6, 1.0)
	var durata := raza / 22.0
	var t := create_tween().set_parallel()
	t.tween_property(inel, "scale", Vector3(raza, 2.5, raza), durata).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, durata).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(inel.queue_free)
	var praf := VrajaAtac.particule(self, 80, 2.2, 1.6, [Color(culoare, 0.0), Color(culoare, 0.6), Color(culoare.darkened(0.4), 0.0)])
	praf.global_position = centru
	praf.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	praf.emission_ring_axis = Vector3.UP
	praf.emission_ring_radius = 1.5
	praf.emission_ring_inner_radius = 1.0
	praf.emission_ring_height = 0.2
	praf.one_shot = true
	praf.explosiveness = 1.0
	praf.radial_accel_min = raza * 3.0
	praf.radial_accel_max = raza * 4.0
	praf.damping_min = raza * 0.5
	praf.damping_max = raza * 0.8
	praf.gravity = Vector3(0, 0.5, 0)
	praf.emitting = true
	get_tree().create_timer(3.0).timeout.connect(praf.queue_free)


## Scutul se sparge: cioburi mov care zboară în toate părțile.
func _cioburi_scut(centru: Vector3, raza: float, culoare: Color) -> void:
	var c := VrajaAtac.particule(self, 90, 1.2, 0.18, [Color(1.0, 1.0, 1.0, 1.0), Color(culoare, 1.0), Color(culoare, 0.0)])
	c.global_position = centru
	c.emission_sphere_radius = raza
	c.one_shot = true
	c.explosiveness = 1.0
	c.radial_accel_min = 20.0
	c.radial_accel_max = 40.0
	c.gravity = Vector3(0, -6.0, 0)
	c.emitting = true
	get_tree().create_timer(2.0).timeout.connect(c.queue_free)


func _fum_mov(unde: Vector3) -> void:
	var p := VrajaAtac.particule(self, 24, 0.9, 0.3, [Color(0.75, 0.5, 0.95, 0.9), Color(0.4, 0.3, 0.5, 0.0)])
	p.global_position = unde
	p.one_shot = true
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.0
	p.gravity = Vector3(0, 0.4, 0)
	p.emission_sphere_radius = 0.2
	p.emitting = true
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


func _lumina_scurta(p: Vector3, culoare: Color, energie: float, raza: float, durata: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = culoare
	l.light_energy = energie
	l.omni_range = raza
	l.omni_attenuation = 0.8
	add_child(l)
	l.global_position = p
	var t := create_tween()
	t.tween_property(l, "light_energy", 0.0, durata).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_callback(l.queue_free)


## Plan „de film” cu `CameraFilm`: de la `poz` (spre `tinta`) alunecă încet până la `poz2` în `durata` secunde.
## `urmarit` (opțional) = camera se uită la el (la `inaltime` deasupra originii), nu la `tinta`.
func _film(poz: Vector3, tinta: Vector3, fov: float, poz2: Vector3, durata: float, urmarit: Node3D = null, inaltime := 1.8) -> void:
	_camera_film.fov = fov
	_camera_film.global_position = poz
	_camera_film.look_at(tinta)
	_camera_film.make_current()
	_urmarit = urmarit
	_inaltime_urmarit = inaltime
	create_tween().set_trans(Tween.TRANS_SINE).tween_method(_film_pas.bind(poz, poz2, tinta), 0.0, 1.0, durata)


var _urmarit: Node3D
var _inaltime_urmarit := 1.8


func _film_pas(k: float, poz: Vector3, poz2: Vector3, tinta: Vector3) -> void:
	if not is_instance_valid(_camera_film) or not _camera_film.current:
		return
	_camera_film.global_position = poz.lerp(poz2, k)
	if is_instance_valid(_urmarit):
		_camera_film.look_at(_urmarit.global_position + Vector3.UP * _inaltime_urmarit)
	else:
		_camera_film.look_at(tinta)


func _hud(vizibil: bool) -> void:
	var jucator := _jucator()
	var hud := jucator.get_node_or_null("HUD") as CanvasLayer if jucator else null
	if hud:
		hud.visible = vizibil


## Cerul: culorile din `culori` (parametrii lui cer_amurg.gdshader), ceața și lumina ambientală, lin în `durata` s.
func _tween_cer(culori: Dictionary, ceata: float, ambient: float, durata: float) -> void:
	var de_la := {}
	for k in culori:
		de_la[k] = _cer.get_shader_parameter(k)
	var ceata_start := _env.fog_density
	var ambient_start := _env.ambient_light_energy
	var ceata_culoare := _env.fog_light_color
	var luna_start := luna.light_energy if luna else 0.0
	var ambient_culoare := _env.ambient_light_color
	var t := create_tween()
	t.tween_method(func(x: float) -> void:
		for k in culori:
			_cer.set_shader_parameter(k, (de_la[k] as Color).lerp(culori[k], x))
		_env.fog_density = lerpf(ceata_start, ceata, x)
		_env.fog_light_color = ceata_culoare.lerp(Color(0.14, 0.05, 0.06), x)
		_env.ambient_light_energy = lerpf(ambient_start, ambient, x)
		_env.ambient_light_color = ambient_culoare.lerp(Color(0.55, 0.25, 0.3), x)
		_luna_la(lerpf(luna_start, 0.12, x)), 0.0, 1.0, durata).set_trans(Tween.TRANS_SINE)


func _luna_la(energie: float) -> void:
	if luna:
		luna.light_energy = energie


func _seteaza_cer(culori: Dictionary) -> void:
	for k in culori:
		_cer.set_shader_parameter(k, culori[k])


## Stratul de deasupra (sub Tranzitie): albul exploziei și pleoapele.
func _fa_stratul() -> void:
	_strat = CanvasLayer.new()
	_strat.layer = 19
	add_child(_strat)
	_alb = ColorRect.new()
	_alb.color = Color(1, 1, 1, 0)
	_alb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_strat.add_child(_alb)
	_pleoapa_sus = _pleoapa(true)
	_pleoapa_jos = _pleoapa(false)


func _pleoapa(sus: bool) -> ColorRect:
	var p := ColorRect.new()
	p.color = Color.BLACK
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.anchor_left = 0.0
	p.anchor_right = 1.0
	p.anchor_top = 0.0 if sus else 1.0
	p.anchor_bottom = 0.0 if sus else 1.0
	_strat.add_child(p)
	return p


## 0 = ochii deschiși, 1 = închiși (fiecare pleoapă acoperă jumătate de ecran).
func _pleoape_la(v: float) -> void:
	_pleoapa_sus.anchor_bottom = 0.5 * v + 0.001
	_pleoapa_jos.anchor_top = 1.0 - 0.5 * v - 0.001


## Țiuit în urechi: totul se aude înfundat și revine în câteva secunde (ca la explozia ceaunului de acasă).
func _asurzeste() -> void:
	_scoate_filtrele()
	for nume in [&"Efecte", &"Ambianta", &"Muzica"]:
		var i := AudioServer.get_bus_index(nume)
		if i < 0:
			continue
		var f := AudioEffectLowPassFilter.new()
		f.cutoff_hz = 400.0
		AudioServer.add_bus_effect(i, f)
		_filtre.append([i, f])
	Sunet.reda(SUNET_TIUIT, Sunet.VOLUM_EFECTE - 6.0, 0.0, &"Interfata")


func _scoate_filtrele() -> void:
	for x in _filtre:
		var i: int = x[0]
		for k in range(AudioServer.get_bus_effect_count(i) - 1, -1, -1):
			if AudioServer.get_bus_effect(i, k) == x[1]:
				AudioServer.remove_bus_effect(i, k)
	_filtre.clear()


## Tunetul nebun după un fulger care lovește aproape (din cap, nu 3D: la 40 m s-ar pierde), cel mult o dată la
## PAUZA_TUNET secunde; înălțimea variază puțin, ca să nu sune la fel de fiecare dată.
func _tuna() -> void:
	var acum := Time.get_ticks_msec() / 1000.0
	if acum - _ultimul_tunet < PAUZA_TUNET:
		return
	_ultimul_tunet = acum
	Sunet.reda(SUNET_TUNET_NEBUN, Sunet.VOLUM_EFECTE + 2.0, 0.08)
