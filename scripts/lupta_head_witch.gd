extends LuptaBoss
## Lupta finală cu Head Witch, în piața rotundă din City Center (centru.tscn, nodul `LuptaHeadWitch`; owner, 10.10).
## Partea comună cu lupta cu Warlock-ul (viața, armele, atacurile de bază, „YOU DIED”, efectele) e în lupta_boss.gd.
##  1. Înainte: Head Witch plutește deasupra pieței (VrajitoareBoss), cu brațele ridicate; oamenii (Civil) tremură și
##     țipă. Când intri în piață (`declansator`) pornește intro-ul (Cutscena, planuri „de film”): îi omoară pe rând
##     (o vrajă, un fulger, doi ridicați în aer și trântiți, unul care fuge, ultimul la picioarele tale), apoi te vede,
##     coboară spre tine și `replici_intro` (owner). → `marcaj_lupta`, `sarcina_lupta`. Pasajul se închide cu o ceață mov
##     (ca în Dark Souls) până o omori.
##  2. Faza întâi: `viata_maxima` (8000). Vrăji mov: salve, fulgere pe cercuri, globul care te urmărește, mătura (se
##     aruncă spre tine pe mătură, pe o linie arătată pe jos), ploaia de meteoriți, unda de șoc când stai lângă ea,
##     teleportul. Tot se oprește cu scutul (Ctrl); fântâna te ascunde de mătură.
##  3. La `prag_faza_doi` (1000 HP) se transformă (cutscene): urlă, se ridică în aer, fulgere în ea, vârtejul, cerul se
##     face verde, crapă de lumină, un fulger alb și e altă ființă (vrajitoare_sefa_demon.glb), își desface aripile,
##     coboară cu o undă de șoc. Bara se umple din nou: `viata_faza_doi` (5000), `nume_faza_doi`.
##  4. Faza a doua (verde, `putere_faza_doi` × damage, mai rapidă): tot ce avea, plus raza care mătură piața (te
##     ascunzi după ceva sau ții scutul) și nova (trei unde de șoc una după alta, pe toată piața: scutul).
##  5. Finalul (`_finalul`): urlă, se ridică, razele de lumină țâșnesc din ea, explodează („HEAD WITCH DEFEATED”); din
##     explozie începe să ningă peste oraș (Zapada); pălăria ei cade lin la picioarele tale; o ridici și o pui pe cap;
##     pe ecran `mesaj_final` („Fuck magic”, owner); negru; genericul (`scena_credite`).
## „YOU DIED”: o iei de la intrarea în piață; în faza a doua (`reia_din_faza_doi`) de la începutul fazei a doua.
## La Continue: în luptă = de la intrarea în piață (oamenii sunt deja morți); după explozie = de la pălărie; după
## final = ninge, nu mai e nimeni (pălăria e pe capul tău).
## Replicile și mesajul sunt ale owner-ului: nu le corecta.

@export var declansator: Area3D
## Oamenii din piață (copiii lui sunt Civil, în ordinea în care îi omoară, vezi `_intro`).
@export var civili: Node3D
@export var zapada: Zapada

@export_group("Marcaje")
## Pus la sfârșitul intro-ului: de aici e lupta.
@export var marcaj_lupta := "lupta_cu_head_witch"
## Pus după transformare.
@export var marcaj_faza_doi := "head_witch_faza_doi"
## Pus când explodează (de aici ninge).
@export var marcaj_moarta := "head_witch_moarta"
## Pus când îți pui pălăria pe cap.
@export var marcaj_palarie := "palaria_head_witch"
## Pus înainte de generic.
@export var marcaj_final := "jocul_terminat"
## Sarcina în luptă (a lui Claude).
@export var sarcina_lupta := "Kill the Head Witch."

@export_group("Replici")
@export_multiline var replici_intro: PackedStringArray = ["Head Witch: What are you doing here child?",
	"You: I knew you were stupid.", "You: I didn't know you're this retarded..",
	"Head Witch: Fear my power, you insolent child!", "You: Fear my dick bitch."]
@export var mesaj_final := "Fuck magic"
@export_file("*.tscn") var scena_credite := "res://scenes/credite.tscn"

@export_group("Faze")
## În faza întâi are `viata_maxima` (8000, din grupul „Viață și damage”); la `prag_faza_doi` HP se transformă.
@export var prag_faza_doi := 1000
@export var viata_faza_doi := 5000
@export var nume_faza_doi := "Head Witch, Hexmother"
## De câte ori mai tare lovesc atacurile ei în faza a doua.
@export var putere_faza_doi := 1.4
## Bifat = dacă mori în faza a doua, o iei de la începutul fazei a doua (nu iar de la 8000).
@export var reia_din_faza_doi := true
@export var damage_matura := 30.0
@export var damage_meteor := 20.0
## Raza din faza a doua: cât iei la fiecare atingere (de ~5 ori pe secundă cât stai în ea).
@export var damage_raza := 9.0
@export var damage_nova := 22.0

@export_group("Locuri")
## Mijlocul pieței (fântâna), la nivelul pavajului.
@export var centru := Vector3(0.0, 0.15, -22.0)
## Unde stă ea când pornește totul (în fața fântânii) și cât de sus plutește atunci.
@export var loc_scena := Vector3(0.0, 0.15, -17.0)
@export var plutire_intro := 2.2
## Unde ești pus la „YOU DIED” și la Continue (intrarea în piață).
@export var loc_intrare := Vector3(0.0, 0.17, -6.5)
## Unde o mută lupta (cercul pe care se teleportează, în jurul fântânii).
@export var raza_teleport := 9.5
## Fântâna (raza): mătura se oprește în ea, nu trece prin statuie.
@export var raza_fantana := 3.8
## Cât de departe de centru poate ajunge (piața are 16,5 m până la clădiri).
@export var raza_piata := 13.5

const SUNET_MUZICA := preload("res://sunete/muzica_warlock.ogg")
const SUNET_RAGET := preload("res://sunete/demon_raget.ogg")
const SUNET_CHEMARE := preload("res://sunete/demon_chemare.ogg")
const SUNET_DEZINTEGRARE := preload("res://sunete/demon_dezintegrare.ogg")
const SUNET_INIMA := preload("res://sunete/inima_rapida.ogg")
const SUNET_VAJAIT := preload("res://sunete/vajait.ogg")
const SUNET_UNDA := preload("res://sunete/vraja_unda.ogg")
const SUNET_COR := preload("res://sunete/vraja_cor.ogg")
const SUNET_VANT := preload("res://sunete/vant.ogg")
const SUNET_LUAT := preload("res://sunete/obiect_luat.ogg")
const SUNET_PUS := preload("res://sunete/obiect_pus.ogg")
const SUNET_DECOLARE := preload("res://sunete/zbor_decolare.ogg")
const MODEL_MATURA := preload("res://models/matura_zbor.glb")
const MODEL_PALARIE := preload("res://models/palarie_sefa.glb")
const MATERIAL := preload("res://shaders/material_model.tres")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MOV := VrajitoareBoss.MOV
const VERDE := VrajitoareBoss.VERDE

var _sefa: VrajitoareBoss
var _in_intro := false
var _transformare_pornita := false
## Damage-urile atacurilor de bază din faza întâi (faza a doua le înmulțește).
var _damage_initial := {}
## Mătura de sub ea și linia de pe jos (atacul cu mătura), raza: se șterg la moarte.
var _matura: Node3D
var _poarta: StaticBody3D
var _palarie: Node3D
var _mesaj: Label
var _vant: AudioStreamPlayer
## Cât e un număr (nu NAN), ea stă întoarsă așa (raza, mătura), nu spre tine.
var _unghi_fix := NAN


func _ready() -> void:
	var jucator := _jucator()
	if jucator == null:
		return
	_pregateste(SUNET_MUZICA)
	culoare = MOV
	fel_vraja = "mov"
	ceata_furie = Color(0.2, 0.08, 0.3)
	ambient_furie = Color(0.55, 0.3, 0.8)
	for k in ["damage_vraja", "damage_fulger", "damage_glob", "damage_unda", "damage_matura", "damage_meteor", "damage_raza",
			"damage_nova"]:
		_damage_initial[k] = get(k)
	# cercul pe care sare: 12 locuri în jurul fântânii, ocolind jardinierele (la 45°, 135°...)
	locuri_teleport = PackedVector3Array()
	for grade: float in [0.0, 25.0, 65.0, 90.0, 115.0, 155.0, 180.0, 205.0, 245.0, 270.0, 295.0, 335.0]:
		var u := deg_to_rad(grade)
		locuri_teleport.append(centru + Vector3(cos(u), 0.0, sin(u)) * raza_teleport)
	_fa_mesajul()
	if Stare.e_marcat(marcaj_moarta):
		_dupa_moarte()
		return
	_fa_vrajitoarea(loc_scena)
	for civ in _civili():
		civ.spre = _sefa
		var d := loc_scena - civ.global_position
		civ.rotation.y = atan2(d.x, d.z)
	if not Stare.e_marcat(marcaj_lupta):
		# înainte: plutește sus, cu brațele ridicate, și așteaptă să intri în piață
		_sefa.plutire = plutire_intro
		_sefa.ridica_toiagul(-2.4, 0.01)
		_sefa.ridica_mana(-2.2, 0.01, 0.5)
		_sefa.furie = 0.7
		if declansator:
			declansator.body_entered.connect(_la_intrare)
		return
	# Continue în luptă: oamenii sunt morți, o iei de la intrare
	if declansator:
		declansator.monitoring = false
	for civ in _civili():
		civ.omoara(Vector3.ZERO)
	await get_tree().process_frame
	while Tranzitie.activa:
		await get_tree().process_frame
	_pune_jucatorul(loc_intrare, loc_scena)
	_poarta_ceata(true)
	await get_tree().create_timer(1.0, false).timeout
	_porneste_lupta()


func _civili() -> Array[Civil]:
	var r: Array[Civil] = []
	if civili:
		for c in civili.get_children():
			if c is Civil and not (c as Civil).mort:
				r.append(c)
	return r


func _fa_vrajitoarea(poz: Vector3) -> void:
	_sefa = VrajitoareBoss.new()
	_fa_boss(_sefa, poz, 0.5, 2.3, 1.65)
	_forma_tinta.disabled = true
	inaltime_piept = 1.3


func _la_intrare(corp: Node3D) -> void:
	if not corp.is_in_group("jucator") or _in_intro or Stare.e_marcat(marcaj_lupta):
		return
	declansator.set_deferred("monitoring", false)
	_intro()


func _process(delta: float) -> void:
	super(delta)
	if is_instance_valid(_sefa) and not is_nan(_unghi_fix):
		_sefa.rotation.y = _unghi_fix
	if is_instance_valid(_sefa) and not _lupta_activa and not _in_intro and not Stare.e_marcat(marcaj_lupta):
		# în așteptare: se rotește încet deasupra pieței, ca și cum ar căuta pe cineva
		_sefa.rotation.y += delta * 0.25


# ---------------------------------------------------------------------------------------------------------------
# 1. Intro-ul: îi omoară pe oameni, te vede
# ---------------------------------------------------------------------------------------------------------------

func _intro() -> void:
	_in_intro = true
	var j := _jucator()
	var c := Cutscena.porneste(self)
	_hud(false)
	j.seteaza_purtat(true)
	Stare.seteaza_sarcina("")
	var oameni := _civili()
	await c.priveste(_piept_boss(), 1.0)
	await get_tree().create_timer(0.5, false).timeout

	# 1. plan larg, de jos, de lângă un felinar: ea deasupra pieței, oamenii, fântâna. O vrajă în primul om.
	_film(centru + Vector3(-10.0, 0.5, 9.5), _piept_boss(), 55.0, centru + Vector3(-9.0, 0.8, 8.2), 4.0)
	if oameni.size() > 0:
		await _vraja_in(oameni[0])
	await get_tree().create_timer(0.5, false).timeout

	# 2. un fulger mov în al doilea (plan din spatele lui, ea în fundal)
	if oameni.size() > 1:
		var om := oameni[1]
		var spre_ea := (_sefa.global_position - om.global_position) * Vector3(1, 0, 1)
		_film(om.global_position - spre_ea.normalized() * 4.5 + Vector3.UP * 1.4 + spre_ea.normalized().cross(Vector3.UP) * 1.5,
			om.global_position + Vector3.UP * 1.2, 50.0, om.global_position - spre_ea.normalized() * 3.8 + Vector3.UP * 1.2, 2.2)
		await _intoarce_spre(om.global_position, 0.35)
		_sefa.ridica_toiagul(-2.8, 0.4)
		VrajaAtac.sunet_la(self, SUNET_TUNET, om.global_position + Vector3.UP * 8.0, Sunet.VOLUM_EFECTE, 16.0)
		await get_tree().create_timer(0.6, false).timeout
		Fulger.loveste(self, om.global_position + Vector3(randf_range(-2, 2), 30.0, randf_range(-2, 2)), om.global_position,
			MOV, 0.3, true, 1.4)
		_fum(om.global_position + Vector3.UP * 0.5, 20)
		Zguduire.porneste(_camera_film, 0.03, 0.4)
		om.omoara(Vector3(randf_range(-40, 40), 260.0, randf_range(-40, 40)))
		_tipa_toti()
		await get_tree().create_timer(1.3, false).timeout

	# 3. doi oameni ridicați în aer, cu raze din palmele ei, și trântiți de pavaj
	if oameni.size() > 3:
		var a := oameni[2]
		var b := oameni[3]
		var mijloc := (a.global_position + b.global_position) * 0.5
		var lat := ((b.global_position - a.global_position) * Vector3(1, 0, 1)).normalized()
		# planul: din partea ta (dinspre pasaj), ea la mijloc, ei doi de o parte și de alta
		var fata := ((j.global_position - _sefa.global_position) * Vector3(1, 0, 1)).normalized()
		_film(_sefa.global_position + fata * 11.0 + Vector3.UP * 0.6, _piept_boss() + Vector3.UP * 0.5, 62.0,
			_sefa.global_position + fata * 10.0 + Vector3.UP * 1.0, 4.2)
		_sefa.ridica_toiagul(-1.6, 0.5)
		_sefa.ridica_mana(-1.6, 0.5, 0.0)
		_sefa.rotation.y = atan2(fata.x, fata.z)
		Sunet.reda(SUNET_COR, Sunet.VOLUM_EFECTE - 4.0, 0.05)
		a.tipa(-2.0)
		b.tipa(-4.0)
		a.ridica(2.6, 1.8)
		b.ridica(2.3, 1.8)
		var raza_a := _raza(MOV, 1.4)
		var raza_b := _raza(MOV, 1.4)
		var tine := create_tween()
		tine.tween_method(func(_k: float) -> void:
			if is_instance_valid(raza_a) and not a.mort:
				_aseaza_raza(raza_a, _sefa.varf_toiag(), a.global_position + Vector3.UP * (1.2 + a.get_node("Model").position.y))
			if is_instance_valid(raza_b) and not b.mort:
				_aseaza_raza(raza_b, _sefa.palma(), b.global_position + Vector3.UP * (1.2 + b.get_node("Model").position.y)), 0.0, 1.0, 2.3)
		await get_tree().create_timer(2.3, false).timeout
		raza_a.queue_free()
		raza_b.queue_free()
		# strânge pumnii: îi trântește
		_sefa.ridica_toiagul(0.2, 0.15)
		_sefa.ridica_mana(0.2, 0.15, 0.0)
		VrajaAtac.sunet_la(self, SUNET_ORB_BUM, mijloc, Sunet.VOLUM_EFECTE, 14.0)
		a.omoara(Vector3(0, -520.0, 0) + lat * -60.0)
		b.omoara(Vector3(0, -520.0, 0) + lat * 60.0)
		await get_tree().create_timer(0.35, false).timeout
		Zguduire.porneste(_camera_film, 0.04, 0.4)
		_praf(a.global_position)
		_praf(b.global_position)
		_tipa_toti()
		await get_tree().create_timer(1.0, false).timeout

	# 4. din ochii tăi: unul o ia la fugă spre pasaj, spre tine; globul îl ajunge din urmă
	_camera_jucator.make_current()
	var j_poz := j.global_position
	if oameni.size() > 4:
		var om := oameni[4]
		await c.priveste(om.global_position + Vector3.UP * 1.3, 0.5)
		om.fugi(j_poz + (om.global_position - j_poz).normalized() * 3.5, 4.2)
		await _intoarce_spre(om.global_position, 0.3)
		_sefa.ridica_toiagul(-2.6, 0.4)
		var glob := _glob_mic()
		var t := 0.0
		while t < 0.9:
			await get_tree().process_frame
			t += get_process_delta_time()
			glob.global_position = _sefa.varf_toiag() + Vector3.UP * 0.35
			glob.scale = Vector3.ONE * lerpf(0.2, 0.8, minf(t / 0.9, 1.0))
			_priveste_acum(om.global_position + Vector3.UP * 1.2)
		_sefa.ridica_toiagul(-1.3, 0.2)
		var de_la := glob.global_position
		var zbor := create_tween()
		zbor.tween_method(func(k: float) -> void:
			glob.global_position = de_la.lerp(om.global_position + Vector3.UP * 1.2, k)
			_priveste_acum(om.global_position + Vector3.UP * 1.2), 0.0, 1.0, 0.45)
		Sunet.reda(SUNET_ORB_ZBOR, Sunet.VOLUM_EFECTE - 4.0)
		await zbor.finished
		glob.queue_free()
		_explozie_vraja(om.global_position + Vector3.UP * 1.0, 1.2)
		var spre_tine := (j_poz - om.global_position) * Vector3(1, 0, 1)
		om.omoara(spre_tine.normalized() * 300.0 + Vector3.UP * 160.0)
		Zguduire.porneste(_camera_jucator, 0.03, 0.4)
		_sefa.ridica_toiagul(0.0, 0.6)
		await get_tree().create_timer(1.2, false).timeout

	# 5. ultimul fuge drept spre tine și cade la picioarele tale, cu o vrajă în spate
	if oameni.size() > 5:
		var om := oameni[5]
		await c.priveste(om.global_position + Vector3.UP * 1.3, 0.6)
		om.fugi(j_poz + (om.global_position - j_poz).normalized() * 1.6, 4.6)
		var t := 0.0
		while t < 1.6 and om.global_position.distance_to(j_poz) > 3.0:
			await get_tree().process_frame
			t += get_process_delta_time()
			_priveste_acum(om.global_position + Vector3.UP * 1.2)
		var v := VrajaAtac.trage(self, _sefa.palma(), om.global_position + Vector3.UP * 1.2, "mov", 0.8, 0.3, 0.1, false)
		_sefa.ridica_mana(-1.5, 0.2, 0.0)
		while is_instance_valid(v) and not v._gata:
			await get_tree().process_frame
			v._la = om.global_position + Vector3.UP * 1.2
			_priveste_acum(om.global_position + Vector3.UP * 1.1)
		var spre_tine := (j_poz - om.global_position) * Vector3(1, 0, 1)
		om.omoara(spre_tine.normalized() * 200.0 + Vector3.UP * 30.0)
		_sefa.ridica_mana(0.0, 0.6, 0.0)
		await c.priveste(om.global_position + spre_tine.normalized() * 1.2 + Vector3.DOWN * 0.2, 0.7)
		await get_tree().create_timer(1.2, false).timeout

	# 6. te vede: se întoarce încet, coboară și vine spre tine
	await c.priveste(_piept_boss(), 0.8)
	_sefa.priveste(j.get_node("Cap").global_position)
	await _intoarce_spre(j.global_position, 1.2)
	var fata_ea := _sefa.global_position + Vector3.UP * (_sefa.plutire + 1.6)
	var spre_mine := ((j.global_position - _sefa.global_position) * Vector3(1, 0, 1)).normalized()
	_film(fata_ea + spre_mine * 2.4 + Vector3.UP * 0.1, fata_ea, 42.0, fata_ea + spre_mine * 1.9 + Vector3.UP * 0.05, 2.4, _sefa,
		_sefa.plutire + 1.6)
	_sefa.furie = 1.0
	Sunet.reda(SUNET_CHEMARE, Sunet.VOLUM_EFECTE - 6.0, 0.05)
	await get_tree().create_timer(2.4, false).timeout
	_camera_jucator.make_current()
	var unde := j.global_position + (_sefa.global_position - j.global_position) * Vector3(1, 0, 1)
	unde = j.global_position + (unde - j.global_position).normalized() * 6.5
	unde.y = loc_scena.y
	var vine := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	vine.tween_property(_sefa, "global_position", unde, 2.4)
	vine.tween_property(_sefa, "plutire", 0.6, 2.4)
	vine.tween_method(func(_k: float) -> void: _priveste_acum(_piept_boss() + Vector3.UP * 0.3), 0.0, 1.0, 2.4)
	_sefa.ridica_toiagul(0.0, 1.2)
	_sefa.ridica_mana(0.0, 1.2, 0.0)
	await vine.finished
	_sefa.furie = 0.5
	Dialog.spune(replici_intro)
	if Dialog.activ:
		await Dialog.terminat
	# „Fear my dick bitch.” → lupta
	VrajaAtac.sunet_la(self, SUNET_RAGET, _piept_boss(), Sunet.VOLUM_EFECTE - 2.0, 14.0)
	_sefa.ridica_toiagul(-2.6, 0.4)
	_sefa.ridica_mana(-2.4, 0.4, 0.6)
	_lumina_scurta(_piept_boss(), MOV, 8.0, 14.0, 0.8)
	Zguduire.porneste(_camera_jucator, 0.03, 0.5)
	_poarta_ceata(false)
	await get_tree().create_timer(0.8, false).timeout
	_sefa.ridica_toiagul(0.0, 0.5)
	_sefa.ridica_mana(0.0, 0.5, 0.0)
	Stare.marcheaza(marcaj_lupta)
	Stare.seteaza_sarcina(sarcina_lupta)
	j.seteaza_purtat(false)
	_hud(true)
	_in_intro = false
	await c.opreste()
	_porneste_lupta()


## Planurile „de film” rămân în piață (sau în pasaj): oriunde ar fi ea, camera nu intră în clădiri.
func _film(poz: Vector3, tinta: Vector3, fov: float, poz2: Vector3, durata: float, urmarit: Node3D = null, inaltime := 1.5) -> void:
	super(_in_piata(poz), tinta, fov, _in_piata(poz2), durata, urmarit, inaltime)


func _in_piata(p: Vector3) -> Vector3:
	var d := Vector2(p.x - centru.x, p.z - centru.z)
	if p.z > centru.z + 15.0:
		# în pasaj (spre bulevard): doar între clădirile de pe margini
		p.x = clampf(p.x, centru.x - 5.3, centru.x + 5.3)
	elif d.length() > 15.0:
		d = d.normalized() * 15.0
		p = Vector3(centru.x + d.x, p.y, centru.z + d.y)
	p.y = maxf(p.y, centru.y + 0.3)
	return p


## Se întoarce spre `punct` în `durata` s.
func _intoarce_spre(punct: Vector3, durata: float) -> void:
	var d := punct - _sefa.global_position
	var start := _sefa.rotation.y
	var tinta := start + angle_difference(start, atan2(d.x, d.z))
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(_sefa, "rotation:y", tinta, durata)
	await t.finished


## O vrajă mov din palma ei în `om`: zboară, îl lovește, îl aruncă pe spate.
func _vraja_in(om: Civil) -> void:
	await _intoarce_spre(om.global_position, 0.35)
	_sefa.priveste(om.global_position + Vector3.UP * 1.5)
	_sefa.ridica_mana(-1.5, 0.35, 0.0)
	await get_tree().create_timer(0.4, false).timeout
	var v := VrajaAtac.trage(self, _sefa.palma(), om.global_position + Vector3.UP * 1.3, "mov", 1.0, 0.5, 0.3, false)
	await v.lovit
	var spate := (om.global_position - _sefa.global_position) * Vector3(1, 0, 1)
	om.omoara(spate.normalized() * 240.0 + Vector3.UP * 90.0)
	_sefa.ridica_mana(0.0, 0.6, 0.0)
	_tipa_toti()


func _tipa_toti() -> void:
	for civ in _civili():
		if randf() < 0.7:
			civ.tipa(randf_range(-10.0, -4.0))


## Ceața mov peste pasaj (ca porțile de ceață din Dark Souls): nu mai ieși din piață cât ține lupta. `pe_loc` = fără
## animație (Continue).
func _poarta_ceata(pe_loc: bool) -> void:
	if _poarta:
		return
	_poarta = StaticBody3D.new()
	add_child(_poarta)
	_poarta.global_position = Vector3(0.0, 2.5, -5.2)
	var forma := CollisionShape3D.new()
	var cutie := BoxShape3D.new()
	cutie.size = Vector3(12.4, 5.0, 0.4)
	forma.shape = cutie
	_poarta.add_child(forma)
	var perete := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(12.4, 5.0)
	perete.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_RAZA
	mat.set_shader_parameter("culoare", MOV)
	mat.set_shader_parameter("putere", 0.0 if not pe_loc else 0.45)
	perete.material_override = mat
	perete.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_poarta.add_child(perete)
	var spate := perete.duplicate() as MeshInstance3D
	spate.rotation.y = PI
	_poarta.add_child(spate)
	var fum := VrajaAtac.particule(_poarta, 60, 2.5, 0.5, [Color(MOV, 0.0), Color(MOV.darkened(0.2), 0.35), Color(MOV.darkened(0.6), 0.0)])
	fum.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fum.emission_box_extents = Vector3(6.0, 2.2, 0.2)
	fum.direction = Vector3.UP
	fum.spread = 30.0
	fum.initial_velocity_min = 0.2
	fum.initial_velocity_max = 0.6
	fum.gravity = Vector3.ZERO
	fum.preprocess = 2.0
	fum.emitting = true
	if not pe_loc:
		create_tween().tween_method(func(v: float) -> void: mat.set_shader_parameter("putere", v), 0.0, 0.45, 1.2)
		VrajaAtac.sunet_la(self, SUNET_UNDA, _poarta.global_position, Sunet.VOLUM_EFECTE - 4.0, 10.0)


func _deschide_poarta() -> void:
	if not _poarta:
		return
	var p := _poarta
	_poarta = null
	var t := create_tween()
	t.tween_property(p, "scale:y", 0.01, 1.5).set_trans(Tween.TRANS_SINE)
	t.tween_callback(p.queue_free)


# ---------------------------------------------------------------------------------------------------------------
# 2. Lupta
# ---------------------------------------------------------------------------------------------------------------

func _porneste_lupta() -> void:
	var faza_doi := reia_din_faza_doi and Stare.e_marcat(marcaj_faza_doi)
	if faza_doi and not _sefa.demon:
		_devine_demon()
	elif not faza_doi and _sefa.demon:
		# o iei de la capăt: e iar ea, cea de dinainte
		var unde := _sefa.global_position
		_sefa.queue_free()
		_fa_vrajitoarea(unde)
		_faza_unu()
	_runda += 1
	_faza_doi = faza_doi
	_transformare_pornita = faza_doi
	_viata = viata_faza_doi if faza_doi else viata_maxima
	_viata_jucator = viata_jucator
	_faza_doi_ceruta = false
	_ascuns = false
	_lupta_activa = true
	_forma_tinta.set_deferred("disabled", false)
	_bara.arata(nume_faza_doi if faza_doi else nume_boss)
	_bara.viata_jucator(_viata_jucator, viata_jucator)
	_muzica.pitch_scale = 1.1 if faza_doi else 1.0
	_muzica.volume_db = -30.0
	_muzica.play()
	create_tween().tween_property(_muzica, "volume_db", Sunet.VOLUM_MUZICA, 2.0)
	_sefa.plutire = 0.8 if faza_doi else 0.5
	_sefa.furie = 0.8 if faza_doi else 0.5
	if faza_doi:
		_tween_cer(0.6, 1.0)
	_lupta()


func _viata_minima() -> float:
	return 0.0 if _faza_doi else float(prag_faza_doi)


func _viata_bara_maxima() -> float:
	return float(viata_faza_doi) if _faza_doi else float(viata_maxima)


func _dupa_lovitura() -> void:
	if _faza_doi:
		if _viata <= 0.0:
			_invins()
	elif _viata <= prag_faza_doi and not _transformare_pornita:
		_transformare_pornita = true
		_transformare()


func _lupta() -> void:
	var r := _runda
	var atacuri := 0
	if not await _asteapta(1.0):
		return
	while r == _runda and _lupta_activa:
		var j := _jucator()
		var distanta := Vector2(j.global_position.x - _sefa.global_position.x, j.global_position.z - _sefa.global_position.z).length()
		if distanta < (5.5 if _faza_doi else 4.5):
			await _unda(10.0 if _faza_doi else 7.0)
			if r != _runda:
				return
			await _teleport()
			atacuri = 0
		else:
			var alese := ["salva", "fulgere", "glob", "matura", "ploaie", "salva"]
			if _faza_doi:
				alese = ["salva", "fulgere", "glob", "matura", "ploaie", "raza", "nova", "raza"]
			alese.erase(_ultimul_atac)
			_ultimul_atac = alese.pick_random()
			match _ultimul_atac:
				"salva":
					await _salva(7 if _faza_doi else 4, 19.0 if _faza_doi else 15.0)
				"fulgere":
					await _fulgere(3 if _faza_doi else 2, 4 if _faza_doi else 2)
				"glob":
					await _glob_mare(1.3 if _faza_doi else 1.0)
					if _faza_doi and r == _runda:
						await _salva(3, 20.0)
				"matura":
					await _atac_matura()
				"ploaie":
					await _ploaie(16 if _faza_doi else 9)
				"raza":
					await _raza_care_matura()
				"nova":
					await _nova()
			if r != _runda:
				return
			atacuri += 1
			if atacuri >= (2 if _faza_doi else 3) or randf() < 0.15:
				await _teleport()
				atacuri = 0
		if r != _runda:
			return
		var pauza := randf_range(0.6, 1.1) if _faza_doi else randf_range(1.2, 2.0)
		if not await _asteapta(pauza):
			return


## Mătura: o mătură îi apare sub ea, o linie mov pe jos arată pe unde vine, apoi zboară drept prin tine. Se oprește în
## fântână (după ea ești la adăpost) și la marginea pieței.
func _atac_matura() -> void:
	var r := _runda
	var j := _jucator()
	var start := _sefa.global_position
	var dir := (j.global_position - start) * Vector3(1, 0, 1)
	if dir.length() < 0.5:
		return
	dir = dir.normalized()
	var lungime := clampf(start.distance_to(j.global_position) + 7.0, 8.0, 26.0)
	lungime = minf(lungime, _pana_la_fantana_sau_margine(start, dir, lungime))
	if lungime < 3.0:
		return
	var capat := start + dir * lungime
	_unghi_fix = atan2(dir.x, dir.z)
	# mătura sub ea, culcată pe direcția zborului
	_matura = MODEL_MATURA.instantiate() as Node3D
	_matura.set_script(SCRIPT_MODEL)
	_matura.set("material", MATERIAL)
	add_child(_matura)
	_de_sters.append(_matura)
	var aplecare := create_tween().set_parallel()
	aplecare.tween_property(_sefa, "plutire", 0.9, 0.5)
	_sefa.ridica_mana(-0.8, 0.4, 0.6)
	_sefa.ridica_toiagul(-0.8, 0.4)
	var linie := _linie_pe_jos(start, capat, 1.3)
	VrajaAtac.sunet_la(self, SUNET_DECOLARE, start + Vector3.UP, Sunet.VOLUM_EFECTE - 4.0, 12.0)
	var asteapta := 0.6 if _faza_doi else 0.9
	var t := 0.0
	while t < asteapta:
		await get_tree().process_frame
		if r != _runda:
			_unghi_fix = NAN
			return
		if get_tree().paused:
			continue
		t += get_process_delta_time()
		_aseaza_matura()
	# zboară
	VrajaAtac.sunet_la(self, SUNET_VAJAIT, start + Vector3.UP, Sunet.VOLUM_EFECTE, 14.0)
	var viteza := 22.0 if _faza_doi else 17.0
	var durata := lungime / viteza
	var lovit := false
	t = 0.0
	while t < durata:
		await get_tree().process_frame
		if r != _runda:
			_unghi_fix = NAN
			return
		if get_tree().paused:
			continue
		t += get_process_delta_time()
		var k := minf(t / durata, 1.0)
		_sefa.global_position = start.lerp(capat, k)
		_aseaza_matura()
		var d := Vector2(j.global_position.x - _sefa.global_position.x, j.global_position.z - _sefa.global_position.z).length()
		if not lovit and d < 1.4:
			lovit = true
			if ScutJucator.activ:
				_scut_lovit(_piept_boss())
			else:
				_raneste(damage_matura, _sefa.global_position - dir, true, 7.0)
	if is_instance_valid(linie):
		linie.queue_free()
	if is_instance_valid(_matura):
		_matura.queue_free()
	_unghi_fix = NAN
	_fum(_sefa.global_position + Vector3.UP, 16)
	create_tween().tween_property(_sefa, "plutire", 0.8 if _faza_doi else 0.5, 0.4)
	_sefa.ridica_mana(0.0, 0.5, 0.0)
	_sefa.ridica_toiagul(0.0, 0.5)


func _aseaza_matura() -> void:
	if not is_instance_valid(_matura):
		return
	var dir := Vector3(sin(_sefa.rotation.y), 0.0, cos(_sefa.rotation.y))
	_matura.global_position = _sefa.global_position + Vector3.UP * (_sefa.plutire + 0.55)
	# coada (-Z a măturii) înainte, ca la zborul spre casă (sefa_vrajitoare.gd)
	_matura.global_basis = Basis.looking_at(dir, Vector3.UP)


## Până unde poate zbura pe `dir` din `start` (cel mult `lungime`): se oprește înainte de fântână și de clădiri.
func _pana_la_fantana_sau_margine(start: Vector3, dir: Vector3, lungime: float) -> float:
	var cel_mult := lungime
	# fântâna: intersecția cu cercul de rază raza_fantana din centru
	var f := Vector2(centru.x - start.x, centru.z - start.z)
	var d := Vector2(dir.x, dir.z)
	var proiectie := f.dot(d)
	if proiectie > 0.0:
		var departe2 := f.length_squared() - proiectie * proiectie
		if departe2 < raza_fantana * raza_fantana:
			cel_mult = minf(cel_mult, proiectie - sqrt(raza_fantana * raza_fantana - departe2) - 0.4)
	# marginea pieței
	var pas := 0.0
	while pas < cel_mult:
		var p := start + dir * pas
		if Vector2(p.x - centru.x, p.z - centru.z).length() > raza_piata:
			return maxf(pas - 0.5, 0.0)
		pas += 0.5
	return cel_mult


## O dungă plată pe pavaj de la `a` la `b` (avertizarea măturii), lată `lat` metri.
func _linie_pe_jos(a: Vector3, b: Vector3, lat: float) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(lat, 0.02, a.distance_to(b))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(culoare, 0.55)
	mat.disable_fog = true
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var mijloc := (a + b) * 0.5
	mijloc.y = centru.y + 0.04
	mi.global_position = mijloc
	var d := (b - a) * Vector3(1, 0, 1)
	mi.rotation.y = atan2(d.x, d.z)
	_de_sters.append(mi)
	# pâlpâie, ca să bată la ochi
	var t := mi.create_tween().set_loops(8)
	t.tween_property(mat, "albedo_color:a", 0.25, 0.08)
	t.tween_property(mat, "albedo_color:a", 0.6, 0.08)
	return mi


## Ploaia de meteoriți: își ridică brațele spre cer și din cer cad globuri pe cercuri care apar pe jos în jurul tău
## (primul exact unde vei fi).
func _ploaie(cate: int) -> void:
	var r := _runda
	_sefa.ridica_toiagul(-2.9, 0.5)
	_sefa.ridica_mana(-2.9, 0.5, 0.4)
	VrajaAtac.sunet_la(self, SUNET_TUNET, _sefa.global_position + Vector3.UP * 8.0, Sunet.VOLUM_EFECTE - 4.0, 16.0)
	if not await _asteapta(0.6):
		return
	for i in cate:
		var j := _jucator()
		var unde := j.global_position + j.velocity * Vector3(0.6, 0.0, 0.6)
		if i > 0:
			var u := randf() * TAU
			unde = j.global_position + Vector3(cos(u), 0.0, sin(u)) * randf_range(1.5, 6.0)
		# nu în fântână și nu în clădiri
		var de_la_centru := Vector2(unde.x - centru.x, unde.z - centru.z)
		if de_la_centru.length() > raza_piata:
			de_la_centru = de_la_centru.normalized() * raza_piata
		unde = Vector3(centru.x + de_la_centru.x, centru.y, centru.z + de_la_centru.y)
		_meteor_pe(unde, 1.0 if _faza_doi else 1.25, r)
		if not await _asteapta(0.16 if _faza_doi else 0.24):
			return
	await _asteapta(0.8)
	if r == _runda:
		_sefa.ridica_toiagul(0.0, 0.6)
		_sefa.ridica_mana(0.0, 0.6, 0.0)


func _meteor_pe(unde: Vector3, avertizare: float, r: int) -> void:
	var inel := _inel(unde + Vector3.UP * 0.04, 1.5, Color(culoare, 0.9))
	inel.scale = Vector3(0.2, 0.04, 0.2)
	create_tween().tween_property(inel, "scale", Vector3(1.0, 0.04, 1.0), avertizare).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# pleacă din cer cu o jumătate de secundă înainte să se termine avertizarea
	await get_tree().create_timer(maxf(avertizare - 0.45, 0.05), false).timeout
	if r != _runda or not _lupta_activa:
		return
	var sus := unde + Vector3(randf_range(-4, 4), 24.0, randf_range(-4, 4))
	var v := VrajaAtac.trage(self, sus, unde + Vector3.UP * 0.1, fel_vraja, 1.2, 0.45, 0.0, true)
	await v.lovit
	if is_instance_valid(inel):
		inel.queue_free()
	if r != _runda or not _lupta_activa:
		return
	var j := _jucator()
	var d := Vector2(j.global_position.x - unde.x, j.global_position.z - unde.z).length()
	if d < 1.6:
		if ScutJucator.activ:
			_scut_lovit(unde + Vector3.UP * 2.0)
		else:
			_raneste(damage_meteor, unde, false, 5.0)


## Faza a doua: raza din palmă care mătură piața dintr-o parte în alta. Te ferești după fântână, după o bancă, sau cu scutul.
func _raza_care_matura() -> void:
	var r := _runda
	var j := _jucator()
	_sefa.ridica_mana(-1.55, 0.4, 0.0)
	_sefa.ridica_toiagul(-1.0, 0.4)
	var incarcare := _sunet_incarcare()
	var glob := _glob_mic()
	var t := 0.0
	while t < 1.0:
		await get_tree().process_frame
		if r != _runda:
			incarcare.queue_free()
			return
		if get_tree().paused:
			continue
		t += get_process_delta_time()
		glob.global_position = _sefa.palma()
		glob.scale = Vector3.ONE * lerpf(0.2, 0.7, t)
	incarcare.queue_free()
	var spre := (j.global_position - _sefa.global_position) * Vector3(1, 0, 1)
	var u0 := atan2(spre.x, spre.z)
	var sens := 1.0 if randf() < 0.5 else -1.0
	var arc := deg_to_rad(130.0)
	var durata := 2.2
	var raza := _raza(VERDE.lightened(0.3), 4.0)
	_de_sters.append(raza)
	VrajaAtac.sunet_la(self, SUNET_ABSORBTIE, _piept_boss(), Sunet.VOLUM_EFECTE, 16.0)
	var scantei := VrajaAtac.particule(self, 40, 0.5, 0.06, [Color(1, 1, 1), VERDE, Color(VERDE, 0.0)])
	scantei.spread = 70.0
	scantei.initial_velocity_min = 2.0
	scantei.initial_velocity_max = 5.0
	scantei.gravity = Vector3(0, -6, 0)
	scantei.emitting = true
	_de_sters.append(scantei)
	var ultima_atingere := -1.0
	t = 0.0
	while t < durata:
		await get_tree().process_frame
		if r != _runda:
			_unghi_fix = NAN
			return
		if get_tree().paused:
			continue
		t += get_process_delta_time()
		var u := u0 + sens * (t / durata - 0.5) * arc
		_unghi_fix = u
		var de_la := _sefa.palma()
		glob.global_position = de_la
		var dir := Vector3(sin(u), 0.0, cos(u))
		var capat := Vector3(de_la.x, centru.y + 1.15, de_la.z) + dir * 34.0
		# raza se oprește în ce e în cale (fântâna, clădirile, băncile)
		var cerere := PhysicsRayQueryParameters3D.create(de_la, capat, 1)
		cerere.exclude = _corpuri(_sefa) + [j.get_rid()]
		var lovit := get_world_3d().direct_space_state.intersect_ray(cerere)
		if not lovit.is_empty():
			capat = lovit.position
		_aseaza_raza(raza, de_la, capat)
		scantei.global_position = capat
		# te atinge dacă ești pe linia ei și mai aproape decât capătul
		var spre_tine := _piept_jucator() - de_la
		var pe_linie := (capat - de_la).normalized()
		var de_a_lungul := spre_tine.dot(pe_linie)
		var departe := (spre_tine - pe_linie * de_a_lungul).length()
		if departe < 0.75 and de_a_lungul > 0.0 and de_a_lungul < de_la.distance_to(capat) + 0.3 and t - ultima_atingere > 0.2:
			ultima_atingere = t
			if ScutJucator.activ:
				_scut_lovit(_piept_jucator() - pe_linie * 1.1)
			else:
				_raneste(damage_raza, de_la, false, 2.5)
	_unghi_fix = NAN
	raza.queue_free()
	scantei.emitting = false
	get_tree().create_timer(0.6, false).timeout.connect(scantei.queue_free)
	glob.queue_free()
	_sefa.ridica_mana(0.0, 0.6, 0.0)
	_sefa.ridica_toiagul(0.0, 0.6)


## Faza a doua: se ridică, bate din aripi, și trei unde de șoc pleacă una după alta din ea, până la marginea pieței.
## Fără scut nu scapi (decât dacă ești foarte departe).
func _nova() -> void:
	var r := _runda
	var c := _sefa.global_position
	create_tween().tween_property(_sefa, "plutire", 2.4, 0.9).set_trans(Tween.TRANS_SINE)
	_sefa.ridica_toiagul(-2.4, 0.6)
	_sefa.ridica_mana(-2.4, 0.6, 0.8)
	var avertizare := _inel(Vector3(c.x, centru.y + 0.05, c.z), 1.0, Color(culoare, 0.9))
	avertizare.scale = Vector3(0.5, 0.04, 0.5)
	create_tween().tween_property(avertizare, "scale", Vector3(2.5, 0.04, 2.5), 1.1)
	VrajaAtac.sunet_la(self, SUNET_CHEMARE, _piept_boss(), Sunet.VOLUM_EFECTE - 2.0, 16.0)
	_bara.indicatie_scut(1.1)
	if not await _asteapta(1.1):
		_bara.indicatie_scut(0.0)
		return
	_bara.indicatie_scut(0.0)
	avertizare.queue_free()
	for k in 3:
		VrajaAtac.sunet_la(self, SUNET_ORB_BUM, c, Sunet.VOLUM_EFECTE - 2.0, 16.0)
		_lumina_scurta(c + Vector3.UP * 2.0, culoare, 10.0, 18.0, 0.5)
		Zguduire.porneste(_camera_jucator, 0.02, 0.3)
		_val_de_soc(Vector3(c.x, centru.y, c.z), 18.0, 1.4, damage_nova, r)
		if not await _asteapta(0.9):
			return
	await _asteapta(0.6)
	if r == _runda:
		create_tween().tween_property(_sefa, "plutire", 0.8, 0.8).set_trans(Tween.TRANS_SINE)
		_sefa.ridica_toiagul(0.0, 0.6)
		_sefa.ridica_mana(0.0, 0.6, 0.0)


func _seteaza_putere(k: float) -> void:
	for nume in _damage_initial:
		set(nume, _damage_initial[nume] * k)


# ---------------------------------------------------------------------------------------------------------------
# 3. Transformarea (faza a doua)
# ---------------------------------------------------------------------------------------------------------------

func _transformare() -> void:
	_lupta_activa = false
	_runda += 1
	_curata()
	_forma_tinta.set_deferred("disabled", true)
	var j := _jucator()
	var cap: Node3D = j.get_node("Cap")
	var c := Cutscena.porneste(self)
	_hud(false)
	j.seteaza_purtat(true)
	create_tween().set_parallel().tween_property(cap, "position", Vector3(0.0, 1.55, 0.0), 0.5)
	create_tween().tween_property(_camera_jucator, "rotation:z", 0.0, 0.5)
	_jos = false
	create_tween().tween_property(_muzica, "volume_db", -40.0, 1.5)
	_bara.ascunde(0.6)
	# urlă, se îndoaie, tresare
	_sefa.tresare(_sefa.global_position - j.global_position, 2.5)
	VrajaAtac.sunet_la(self, SUNET_RAGET, _piept_boss(), Sunet.VOLUM_EFECTE + 2.0, 20.0)
	_lumina_scurta(_piept_boss(), MOV, 10.0, 14.0, 0.8)
	await c.priveste(_piept_boss(), 0.5)
	await get_tree().create_timer(0.6, false).timeout
	# se mută (pe pixeli) în fața fântânii, ca să fie loc de ea
	await _sefa.ascunde(0.4).finished
	_sefa.global_position = loc_scena
	_intoarce_boss(j.global_position, 1.0)
	_fum(loc_scena + Vector3.UP, 30)
	await _sefa.aparitie(0.4).finished
	_muzica.stop()

	# 1. plan de jos, de departe: se ridică în aer, cu brațele desfăcute și capul pe spate; cerul se face verde
	var spre_tine := ((j.global_position - loc_scena) * Vector3(1, 0, 1)).normalized()
	var lat := spre_tine.cross(Vector3.UP)
	_film(loc_scena + spre_tine * 11.0 + lat * 3.0 + Vector3.UP * 0.4, loc_scena + Vector3.UP * 3.0, 60.0,
		loc_scena + spre_tine * 9.5 + lat * 2.4 + Vector3.UP * 0.5, 6.0, _sefa, 3.5)
	_sefa.smuls(3.0)
	create_tween().tween_property(_sefa, "plutire", 4.0, 3.5).set_trans(Tween.TRANS_SINE)
	ceata_furie = Color(0.08, 0.26, 0.16)
	ambient_furie = Color(0.3, 0.8, 0.45)
	_tween_cer(1.0, 4.0)
	Sunet.reda(SUNET_COR, Sunet.VOLUM_EFECTE, 0.0, &"Efecte", 0.7)
	var vartej := _vartej()
	for k in 6:
		await get_tree().create_timer(0.55, false).timeout
		var tinta := _piept_boss() + Vector3(randf_range(-0.3, 0.3), randf_range(-0.3, 0.5), randf_range(-0.3, 0.3))
		Fulger.loveste(self, tinta + Vector3(randf_range(-6, 6), 30.0, randf_range(-6, 6)), tinta, MOV if k % 2 else VERDE, 0.3,
			true, 1.2)
		Zguduire.porneste(_camera_film, 0.02 + k * 0.006, 0.4)
	# 2. de aproape: fața ei în lumină, crapă
	var fata := _sefa.global_position + Vector3.UP * (_sefa.plutire + 1.6)
	_film(fata + spre_tine * 2.6 + lat * 0.8, fata, 45.0, fata + spre_tine * 2.0 + lat * 0.5, 2.6)
	Sunet.reda(SUNET_INIMA, Sunet.VOLUM_EFECTE, 0.0)
	for k in 4:
		_alb.color = Color(VERDE.lightened(0.6), 0.25 + k * 0.1)
		create_tween().tween_property(_alb, "color:a", 0.0, 0.35)
		_sefa._sclipire = 1.0
		Zguduire.porneste(_camera_film, 0.03, 0.3)
		await get_tree().create_timer(0.6, false).timeout
	# 3. lumina albă: altă ființă
	var flash := create_tween()
	flash.tween_property(_alb, "color", Color(1, 1, 1, 1), 0.2)
	await flash.finished
	VrajaAtac.sunet_la(self, SUNET_ORB_BUM, _piept_boss(), Sunet.VOLUM_EFECTE + 4.0, 30.0)
	Sunet.reda(SUNET_DEZINTEGRARE, Sunet.VOLUM_EFECTE)
	vartej.emitting = false
	get_tree().create_timer(2.0, false).timeout.connect(vartej.queue_free)
	_devine_demon()
	_sefa._tremura = false
	_sefa._aplecare = 0.0
	_sefa.aripi = 0.0
	_sefa.plutire = 3.6
	_sefa.furie = 1.0
	# 4. plan larg: atârnă în aer, își desface aripile, urlă
	_film(loc_scena + spre_tine * 13.0 - lat * 4.0 + Vector3.UP * 0.8, loc_scena + Vector3.UP * 5.0, 60.0,
		loc_scena + spre_tine * 12.0 - lat * 3.0 + Vector3.UP * 1.2, 4.5, _sefa, 5.5)
	var lumina := create_tween()
	lumina.tween_property(_alb, "color:a", 0.0, 1.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.8, false).timeout
	create_tween().tween_property(_sefa, "aripi", 1.0, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_sefa.ridica_toiagul(-1.0, 0.8)
	_sefa.ridica_mana(-1.0, 0.8, 0.5)
	VrajaAtac.sunet_la(self, SUNET_RAGET, _piept_boss(), Sunet.VOLUM_EFECTE + 4.0, 30.0)
	Zguduire.porneste(_camera_film, 0.05, 1.2)
	await get_tree().create_timer(1.8, false).timeout
	# 5. coboară cu o undă de șoc, din ochii tăi
	_camera_jucator.make_current()
	c.priveste(_piept_boss(), 0.4)
	var jos := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	jos.tween_property(_sefa, "plutire", 0.8, 0.7)
	jos.parallel().tween_method(func(_k: float) -> void: _priveste_acum(_piept_boss()), 0.0, 1.0, 0.7)
	await jos.finished
	VrajaAtac.sunet_la(self, SUNET_ORB_BUM, loc_scena, Sunet.VOLUM_EFECTE + 2.0, 20.0)
	_praf(loc_scena)
	_val_de_soc(loc_scena, 16.0, 0.9, 0.0, -1)
	Zguduire.porneste(_camera_jucator, 0.05, 0.6)
	_sefa.ridica_toiagul(0.0, 0.6)
	_sefa.ridica_mana(0.0, 0.6, 0.0)
	await get_tree().create_timer(0.6, false).timeout
	# 6. bara se umple iar, alt nume; de aici e mai rea
	Stare.marcheaza(marcaj_faza_doi)
	_faza_doi = true
	_viata = viata_faza_doi
	_viata_jucator = maxf(_viata_jucator, viata_jucator * 0.5)
	_bara.umple(nume_faza_doi, 1.6)
	_bara.viata_jucator(_viata_jucator, viata_jucator)
	_muzica.pitch_scale = 1.1
	_muzica.volume_db = -20.0
	_muzica.play()
	create_tween().tween_property(_muzica, "volume_db", Sunet.VOLUM_MUZICA, 1.5)
	_tween_cer(0.6, 2.0)
	j.seteaza_purtat(false)
	_hud(true)
	await c.opreste()
	_forma_tinta.set_deferred("disabled", false)
	_runda += 1
	_lupta_activa = true
	_sefa.furie = 0.8
	_lupta()


## Schimbă modelul în cel din faza a doua și tot ce ține de el (ținta mai mare, culorile vrăjilor, damage-ul).
func _devine_demon() -> void:
	_sefa.schimba_in_demon()
	inaltime_piept = 2.0
	var capsula := _forma_tinta.shape as CapsuleShape3D
	capsula.radius = 0.8
	capsula.height = 3.4
	_forma_tinta.position = Vector3.UP * 2.5
	culoare = VERDE
	fel_vraja = "verde"
	ceata_furie = Color(0.08, 0.26, 0.16)
	ambient_furie = Color(0.3, 0.8, 0.45)
	_seteaza_putere(putere_faza_doi)


## Înapoi la faza întâi (după „YOU DIED” fără `reia_din_faza_doi`).
func _faza_unu() -> void:
	culoare = MOV
	fel_vraja = "mov"
	ceata_furie = Color(0.2, 0.08, 0.3)
	ambient_furie = Color(0.55, 0.3, 0.8)
	_seteaza_putere(1.0)


## Vârtejul din jurul ei la transformare: particule mov și verzi care se rotesc și urcă.
func _vartej() -> CPUParticles3D:
	var p := VrajaAtac.particule(self, 160, 2.0, 0.12, [Color(MOV, 0.0), Color(MOV, 0.9), Color(VERDE, 0.9), Color(VERDE, 0.0)])
	p.global_position = loc_scena + Vector3.UP * 0.3
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 4.5
	p.emission_ring_inner_radius = 3.5
	p.emission_ring_height = 0.5
	p.direction = Vector3.UP
	p.spread = 10.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3.ZERO
	p.tangential_accel_min = 14.0
	p.tangential_accel_max = 20.0
	p.radial_accel_min = -4.0
	p.radial_accel_max = -2.0
	p.emitting = true
	return p


## Pe negru, după „YOU DIED”: ea în fața fântânii, tu la intrarea în piață.
func _reia_lupta() -> void:
	_unghi_fix = NAN
	if is_instance_valid(_matura):
		_matura.queue_free()
	_sefa.global_position = loc_scena
	_sefa.ridica_toiagul(0.0, 0.01)
	_sefa.ridica_mana(0.0, 0.01, 0.0)
	ModelPS2.disparitie(_sefa._model, 0.0)
	if not (reia_din_faza_doi and Stare.e_marcat(marcaj_faza_doi)):
		_tween_cer(0.0, 0.01)
	_pune_jucatorul(loc_intrare, loc_scena)
	_intoarce_boss(_jucator().global_position, 1.0)


# ---------------------------------------------------------------------------------------------------------------
# 4. Finalul: explodează, ninge, pălăria pe cap, „Fuck magic”, genericul
# ---------------------------------------------------------------------------------------------------------------

func _la_invins() -> void:
	Stare.seteaza_sarcina("")


func _finalul(_din_lupta: bool) -> void:
	var j := _jucator()
	var cap: Node3D = j.get_node("Cap")
	var c := Cutscena.porneste(self)
	_hud(false)
	j.seteaza_purtat(true)
	create_tween().set_parallel().tween_property(cap, "position", Vector3(0.0, 1.55, 0.0), 0.5)
	create_tween().tween_property(_camera_jucator, "rotation:z", 0.0, 0.5)
	_jos = false
	_forma_tinta.set_deferred("disabled", true)
	create_tween().tween_property(_muzica, "volume_db", -40.0, 2.0)
	_bara.ascunde(0.6)
	_sefa.tresare(_sefa.global_position - j.global_position, 3.0)
	VrajaAtac.sunet_la(self, SUNET_RAGET, _piept_boss(), Sunet.VOLUM_EFECTE + 4.0, 30.0)
	_lumina_scurta(_piept_boss(), VERDE, 10.0, 14.0, 0.8)
	await c.priveste(_piept_boss(), 0.5)
	await get_tree().create_timer(0.5, false).timeout
	# 1. se ridică, cu brațele desfăcute, tremurând; razele de lumină țâșnesc din ea una câte una
	var w := _sefa.global_position
	var spre_tine := ((j.global_position - w) * Vector3(1, 0, 1)).normalized()
	if spre_tine.length() < 0.1:
		spre_tine = Vector3.BACK
	var lat := spre_tine.cross(Vector3.UP)
	_film(w + spre_tine * 10.0 + lat * 3.5 + Vector3.UP * 0.6, w + Vector3.UP * 3.5, 58.0,
		w + spre_tine * 8.5 + lat * 2.8 + Vector3.UP * 0.9, 5.5, _sefa, 3.8)
	_sefa.smuls(3.5)
	create_tween().tween_property(_sefa, "plutire", 3.0, 3.5).set_trans(Tween.TRANS_SINE)
	Sunet.reda(SUNET_INIMA, Sunet.VOLUM_EFECTE, 0.0)
	var raze: Array[MeshInstance3D] = []
	var directii: Array[Vector3] = []
	for k in 9:
		await get_tree().create_timer(0.45, false).timeout
		var d := Vector3(randf_range(-1, 1), randf_range(-0.4, 1.0), randf_range(-1, 1)).normalized()
		var raza := _raza(Color(0.85, 1.0, 0.9), 3.0 + k * 0.3)
		raze.append(raza)
		directii.append(d)
		VrajaAtac.sunet_la(self, SUNET_VRAJA, _piept_boss(), Sunet.VOLUM_EFECTE - 2.0, 14.0, 0.2)
		_sefa._sclipire = 1.0
		Zguduire.porneste(_camera_film, 0.015 + k * 0.006, 0.4)
		_alb.color = Color(1, 1, 1, 0.1 + k * 0.03)
		create_tween().tween_property(_alb, "color:a", 0.0, 0.3)
	var tine := create_tween()
	tine.tween_method(func(_k: float) -> void:
		var p := _piept_boss()
		for i in raze.size():
			if is_instance_valid(raze[i]):
				_aseaza_raza(raze[i], p + directii[i] * 9.0, p), 0.0, 1.0, 1.2)
	await get_tree().create_timer(1.2, false).timeout
	# 2. explodează
	var unde := _piept_boss()
	var alb := create_tween()
	alb.tween_property(_alb, "color", Color(1, 1, 1, 1), 0.12)
	await alb.finished
	for r in raze:
		r.queue_free()
	Explozie.creeaza(self, unde, Vector3.UP, 2.5)
	_cenusa(unde)
	_sefa.hide()
	Stare.marcheaza(marcaj_moarta)
	_deschide_poarta()
	_camera_jucator.make_current()
	_priveste_acum(unde)
	await get_tree().create_timer(0.3, false).timeout
	create_tween().tween_property(_alb, "color:a", 0.0, 2.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_muzica.stop()
	# 3. din explozie începe să ningă: fulgii pleacă din ea în toate părțile, apoi ninge peste tot orașul
	_fulgi_din_explozie(unde)
	_vant = AudioStreamPlayer.new()
	_vant.stream = SUNET_VANT
	_vant.bus = &"Ambianta"
	_vant.volume_db = -40.0
	add_child(_vant)
	_vant.play()
	create_tween().tween_property(_vant, "volume_db", Sunet.VOLUM_AMBIANTA + 2.0, 4.0)
	_spre_iarna(6.0)
	await get_tree().create_timer(1.0, false).timeout
	if zapada:
		zapada.porneste(1.0, 7.0)
	Sunet.reda(SUNET_DOBORAT, Sunet.VOLUM_EFECTE)
	await _bara.mesaj("HEAD WITCH DEFEATED", BaraBoss.AURIU, 2.6)
	_sefa.queue_free()
	await _palaria(unde)


## Cerul și ceața spre o seară de iarnă (fulgii se văd pe un albastru deschis, ceața e albă).
func _spre_iarna(durata: float) -> void:
	if _env == null:
		return
	var de_la := {"fog_light_color": _env.fog_light_color, "fog_density": _env.fog_density,
		"ambient_light_color": _env.ambient_light_color, "ambient_light_energy": _env.ambient_light_energy}
	create_tween().tween_method(func(x: float) -> void:
		_env.fog_light_color = (de_la["fog_light_color"] as Color).lerp(Color(0.62, 0.68, 0.8), x)
		_env.fog_density = lerpf(de_la["fog_density"], 0.035, x)
		_env.ambient_light_color = (de_la["ambient_light_color"] as Color).lerp(Color(0.62, 0.7, 0.92), x)
		_env.ambient_light_energy = lerpf(de_la["ambient_light_energy"], 0.75, x), 0.0, 1.0, durata)


## Fulgii care pleacă din explozie: un nor alb care se lărgește încet și cade, ca primii fulgi.
func _fulgi_din_explozie(unde: Vector3) -> void:
	var p := VrajaAtac.particule(self, 220, 6.0, 0.08, [Color(1, 1, 1, 0.0), Color(0.95, 0.97, 1.0, 1.0), Color(0.9, 0.93, 1.0, 0.0)])
	p.global_position = unde
	p.one_shot = true
	p.explosiveness = 0.85
	p.emission_sphere_radius = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 9.0
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.gravity = Vector3(0, -0.5, 0)
	p.emitting = true
	get_tree().create_timer(7.0, false).timeout.connect(p.queue_free)


## Pălăria cade din explozie, lin, ca o frunză, în fața ta; o ridici, te uiți la ea, o pui pe cap. Apoi mesajul și genericul.
func _palaria(de_unde: Vector3) -> void:
	var j := _jucator()
	var cap: Node3D = j.get_node("Cap")
	var inainte := ((de_unde - j.global_position) * Vector3(1, 0, 1)).normalized()
	if inainte.length() < 0.1:
		inainte = -j.global_basis.z
	inainte = _spre_loc_liber(j, inainte, 2.4)
	var jos := j.global_position + inainte * 2.4
	jos.y = centru.y + 0.02
	_palarie = MODEL_PALARIE.instantiate() as Node3D
	_palarie.set_script(SCRIPT_MODEL)
	_palarie.set("material", MATERIAL)
	add_child(_palarie)
	var start := Vector3(jos.x, de_unde.y + 1.0, jos.z) - inainte * 1.5
	_palarie.global_position = start
	var cadere := create_tween()
	cadere.tween_method(func(k: float) -> void:
		# coboară legănându-se dintr-o parte în alta și rotindu-se încet
		var leganat := inainte.cross(Vector3.UP) * sin(k * TAU * 2.0) * 0.9 * (1.0 - k)
		_palarie.global_position = start.lerp(jos, k) + leganat
		_palarie.rotation = Vector3(sin(k * TAU * 2.0) * 0.5 * (1.0 - k), k * 5.0, cos(k * TAU * 2.0) * 0.3 * (1.0 - k))
		_priveste_acum(_palarie.global_position + Vector3.UP * 0.2), 0.0, 1.0, 4.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await cadere.finished
	Sunet.reda_la(SUNET_PUS, jos, Sunet.VOLUM_EFECTE - 6.0, 0.05)
	await get_tree().create_timer(1.0, false).timeout
	# te apropii, te apleci și o ridici
	var la := jos - inainte * 0.75
	la.y = j.global_position.y
	var mers := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	mers.tween_property(j, "global_position", la, 1.2)
	mers.tween_method(func(_k: float) -> void: _priveste_acum(_palarie.global_position + Vector3.UP * 0.1), 0.0, 1.0, 1.2)
	await mers.finished
	var apleci := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	apleci.tween_property(cap, "position:y", 0.75, 0.7)
	apleci.tween_method(func(_k: float) -> void: _priveste_acum(_palarie.global_position + Vector3.UP * 0.1), 0.0, 1.0, 0.7)
	await apleci.finished
	Sunet.reda(SUNET_LUAT, Sunet.VOLUM_EFECTE - 3.0, 0.05)
	# în mâini, în fața ochilor (copilul camerei)
	var in_mana := Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0.0, -0.32, -0.62))
	var de_pe_jos := _palarie.global_transform
	var ridica := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ridica.tween_method(func(k: float) -> void:
		var tinta := _camera_jucator.global_transform * in_mana
		_palarie.global_transform = de_pe_jos.interpolate_with(tinta, k), 0.0, 1.0, 0.8)
	ridica.tween_property(cap, "position:y", 1.55, 1.0).set_delay(0.3)
	ridica.tween_property(cap, "rotation:x", -0.35, 1.0).set_delay(0.3)
	await ridica.finished
	_palarie.reparent(_camera_jucator)
	_palarie.transform = in_mana
	await get_tree().create_timer(2.0, false).timeout
	await _pune_palaria_pe_cap(cap)


## O pui pe cap: o ridici deasupra capului (te uiți după ea), o tragi pe cap (se vede borul în partea de sus a
## ecranului, până la final), apoi te uiți în sus, la zăpadă. Apoi mesajul și genericul.
func _pune_palaria_pe_cap(cap: Node3D) -> void:
	# în sus, în fața ochilor, apoi peste cap
	var deasupra := Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0.0, 0.22, -0.5))
	var pe_cap := Transform3D(Basis(Vector3.RIGHT, -0.1), Vector3(0.0, 0.13, 0.05))
	var de_la := _palarie.transform
	var sus := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sus.tween_method(func(k: float) -> void: _palarie.transform = de_la.interpolate_with(deasupra, k), 0.0, 1.0, 1.1)
	sus.tween_property(cap, "rotation:x", 0.15, 1.1)
	await sus.finished
	await get_tree().create_timer(0.3, false).timeout
	# pe cap: coboară, privirea revine înainte, capul se lasă puțin sub ea
	var jos := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	jos.tween_method(func(k: float) -> void: _palarie.transform = deasupra.interpolate_with(pe_cap, k), 0.0, 1.0, 0.45)
	jos.tween_property(cap, "rotation:x", 0.0, 0.45)
	await jos.finished
	Sunet.reda(SUNET_PUS, Sunet.VOLUM_EFECTE - 2.0, 0.05)
	var y := cap.position.y
	var apasat := create_tween().set_trans(Tween.TRANS_SINE)
	apasat.tween_property(cap, "position:y", y - 0.05, 0.12)
	apasat.tween_property(cap, "position:y", y, 0.4)
	await apasat.finished
	Stare.marcheaza(marcaj_palarie)
	await get_tree().create_timer(1.0, false).timeout
	# te uiți în sus, la zăpada care cade peste oraș, cu borul ei deasupra ochilor
	var cer := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cer.tween_property(cap, "rotation:x", 0.32, 2.5)
	await cer.finished
	await get_tree().create_timer(0.5, false).timeout
	# „Fuck magic”
	var t := create_tween()
	t.tween_property(_mesaj, "modulate:a", 1.0, 1.8).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(_mesaj, "scale", Vector2.ONE * 1.05, 5.5)
	await get_tree().create_timer(4.0, false).timeout
	# negru, apoi genericul
	var negru := create_tween().set_parallel()
	negru.tween_property(_negru, "color:a", 1.0, 2.5).set_trans(Tween.TRANS_SINE)
	negru.tween_property(_mesaj, "modulate:a", 0.0, 2.5)
	if _vant:
		negru.tween_property(_vant, "volume_db", -40.0, 2.5)
	await negru.finished
	Stare.marcheaza(marcaj_final)
	Salvare.salveaza(false)
	await get_tree().create_timer(0.8, false).timeout
	Stare.meniu_deschis = false
	Tranzitie.mergi_la(scena_credite)


## Direcția (cât mai aproape de `dir`) în care pălăria poate cădea la `departe` metri de tine: pe pavaj liber, nu în
## fântână, nu pe o bancă / un felinar, și fără nimic între tine și ea (te duci după ea).
func _spre_loc_liber(j: CharacterBody3D, dir: Vector3, departe: float) -> Vector3:
	var spatiu := get_world_3d().direct_space_state
	for i in 13:
		var unghi := ceilf(i / 2.0) * 0.45 * (1.0 if i % 2 == 0 else -1.0)
		var d := dir.rotated(Vector3.UP, unghi)
		var p := j.global_position + d * departe
		var de_la_centru := Vector2(p.x - centru.x, p.z - centru.z).length()
		if de_la_centru < raza_fantana + 1.2 or de_la_centru > raza_piata - 0.8:
			continue
		# nimic pe drum (la înălțimea genunchilor) și pavaj gol sub ea
		var drum := PhysicsRayQueryParameters3D.create(j.global_position + Vector3.UP * 0.4, p + Vector3.UP * 0.4, 1)
		drum.exclude = [j.get_rid()]
		if not spatiu.intersect_ray(drum).is_empty():
			continue
		var sub := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3.0, p + Vector3.DOWN, 1)
		sub.exclude = [j.get_rid()]
		var lovit := spatiu.intersect_ray(sub)
		if lovit.is_empty() or (lovit.position as Vector3).y > centru.y + 0.15:
			continue
		return d
	return dir


## „Fuck magic” pe mijlocul ecranului (mare, cu umbră), sub negru (așa dispare odată cu el).
func _fa_mesajul() -> void:
	var strat := CanvasLayer.new()
	strat.layer = 18
	add_child(strat)
	_mesaj = Label.new()
	_mesaj.text = mesaj_final
	_mesaj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mesaj.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mesaj.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mesaj.pivot_offset = Vector2(240, 135)
	_mesaj.add_theme_font_size_override("font_size", 30)
	_mesaj.add_theme_color_override("font_color", Color("83b3b0"))
	_mesaj.add_theme_color_override("font_shadow_color", Color("262d2f"))
	_mesaj.add_theme_constant_override("shadow_offset_x", 2)
	_mesaj.add_theme_constant_override("shadow_offset_y", 2)
	_mesaj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mesaj.modulate.a = 0.0
	strat.add_child(_mesaj)


## După final (Continue): ninge, e seară de iarnă; nu mai e nimeni în piață. Dacă ai ieșit
## între explozie și generic, finalul o ia de la pălărie.
func _dupa_moarte() -> void:
	if declansator:
		declansator.monitoring = false
	if civili:
		civili.hide()
	_spre_iarna(0.01)
	if Stare.e_marcat(marcaj_final):
		return
	# între explozie și generic: de la pălărie
	await get_tree().process_frame
	while Tranzitie.activa:
		await get_tree().process_frame
	_pune_jucatorul(loc_intrare + Vector3(0, 0, -6.0), loc_scena)
	Cutscena.porneste(self)
	_hud(false)
	_jucator().seteaza_purtat(true)
	_vant = AudioStreamPlayer.new()
	_vant.stream = SUNET_VANT
	_vant.bus = &"Ambianta"
	_vant.volume_db = Sunet.VOLUM_AMBIANTA + 2.0
	add_child(_vant)
	_vant.play()
	await get_tree().create_timer(1.0, false).timeout
	await _palaria(loc_scena + Vector3.UP * 4.0)
