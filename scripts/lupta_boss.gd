class_name LuptaBoss
extends Node3D
## Ce au în comun luptele cu boși „ca în Dark Souls”: Warlock-ul de la motel (lupta_warlock.gd) și Head Witch în
## City Center (lupta_head_witch.gd). Scriptul fiecărei lupte extinde clasa asta și scrie doar ce e al lui: intro-ul,
## ordinea atacurilor (`_lupta`), faza a doua și finalul (`_finalul`).
## Aici sunt:
##  - boss-ul (`_boss`, un Warlock sau ce-l extinde, ca VrajitoareBoss) și ținta pe care o lovesc armele (`Tinta`);
##  - viața lui și a ta, damage-ul după armă (`lovit_de` → `_lovit`), BaraBoss, „YOU DIED” și reluarea luptei;
##  - atacurile de bază, toate oprite de scut (Ctrl): salva de vrăji, fulgerele pe cercuri, globul care te urmărește,
##    unda de șoc, teleportul; culoarea lor e `culoare` / `fel_vraja`;
##  - efectele (planuri „de film”, lumini, fum, inele, raze) și cerul care se înroșește (`_tween_cer`).

@export var mediu: WorldEnvironment
@export var nume_boss := "Warlock"

@export_group("Viață și damage")
@export var viata_maxima := 2000
@export var damage_pistol := 5
@export var damage_cutit := 10
## Katana din parcarea barului URBAN (katana.gd).
@export var damage_katana := 20
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
## Unde poate sări boss-ul când se teleportează.
@export var locuri_teleport := PackedVector3Array([Vector3(-5.5, 0, 3.5), Vector3(-1.5, 0, 5.5), Vector3(5.5, 0, 3.0), Vector3(-6.0, 0, 10.5),
	Vector3(2.0, 0, 12.5), Vector3(-5.0, 0, 1.5), Vector3(6.5, 0, 12.0), Vector3(-9.0, 0, 13.5), Vector3(1.0, 0, 8.5)])

const SHADER_RAZA := preload("res://shaders/raza_vraja.gdshader")
const SUNET_TELEPORT := preload("res://sunete/atac_aparitie.ogg")
const SUNET_TUNET := preload("res://sunete/atac_tunet.ogg")
const SUNET_INCARCARE := preload("res://sunete/boss_incarcare.ogg")
const SUNET_ORB_ZBOR := preload("res://sunete/orb_zbor.ogg")
const SUNET_ORB_BUM := preload("res://sunete/orb_explozie.ogg")
const SUNET_IMPACT := preload("res://sunete/atac_impact.ogg")
const SUNET_VRAJA := preload("res://sunete/atac_vraja.ogg")
const SUNET_SCUT := preload("res://sunete/scut.ogg")
const SUNET_CAZUT := preload("res://sunete/corp_cazut.ogg")
const SUNET_TIUIT := preload("res://sunete/tiuit.ogg")
const SUNET_MURIT := preload("res://sunete/ai_murit.ogg")
const SUNET_DOBORAT := preload("res://sunete/inamic_doborat.ogg")
const SUNET_ABSORBTIE := preload("res://sunete/absorbtie.ogg")
## Refăcute „de film” (10.10, pachetele noi; vezi sunete.sh): globul / unda care lovesc (în loc de explozia de 8 s a
## conacului), cercul de dinainte de fulger, toiagul bătut în pământ, scutul care oprește ceva, tu lovit, el lovit, căzutul.
const SUNET_GLOB_BUM := preload("res://sunete/boss_glob_bum.ogg")
const SUNET_CERC := preload("res://sunete/boss_cerc.ogg")
const SUNET_UNDA_SOC := preload("res://sunete/boss_unda.ogg")
const SUNET_PARARE := preload("res://sunete/boss_parare.ogg")
const SUNET_LOVIT_TU := preload("res://sunete/jucator_lovit.ogg")
const SUNET_BOSS_LOVIT := preload("res://sunete/boss_lovit.ogg")
const SUNET_CAZI := preload("res://sunete/boss_cazi.ogg")
const ROSU := Color(1.0, 0.22, 0.15)

## Ținta pe care o lovesc armele (pe boss): trimite lovitura înapoi la luptă.
class Tinta extends StaticBody3D:
	var lupta: Node

	func lovit_de(arma: String, directie: Vector3, punct: Vector3) -> void:
		lupta.call("_lovit", arma, directie, punct)


## Culoarea vrăjilor lui (fulgere, globuri, inele, fum) și felul lor din VrajaAtac ("rosu", "mov", "verde", "foc").
var culoare := ROSU
var fel_vraja := "rosu"
## Spre ce merg ceața și lumina când se înfurie (`_tween_cer`, k = 1).
var ceata_furie := Color(0.32, 0.06, 0.06)
var ambient_furie := Color(0.6, 0.2, 0.22)
## Cât de sus îi e pieptul peste tălpi (fără plutire): acolo țintesc camerele și razele.
var inaltime_piept := 1.3
## Vocea lui (fiecare boss pune ce are): geme când îl lovești (cel mult o dată la `PAUZA_DURERE` ms) și râde la „YOU DIED”.
var sunet_durere: AudioStream = null
var sunet_ras: AudioStream = null
const PAUZA_DURERE := 1200
## Cel mult un sunet de lovitură la 70 ms (AK-ul trage repede, altfel se adună zeci).
const PAUZA_LOVIT := 70
var _ultim_lovit := 0
var _ultima_durere := 0

var _boss: Warlock
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
## Crește la orice oprire (moarte, final, schimbarea fazei): vrăjile și atacurile pornite înainte se opresc singure.
var _runda := 0
var _faza_doi := false
var _faza_doi_ceruta := false
var _ascuns := false
var _jos := false
var _ultimul_atac := ""
var _proiectile: Array = []  # [VrajaAtac, damage, raza, runda]
var _globuri: Array = []  # {nod, viteza, damage, timp, runda}
var _de_sters: Array[Node] = []
var _asteapta_scut := false
var _scut_apasat := false


## Camera „de film”, bara, ecranele albe și negre, muzica luptei, copia mediului (cerul se poate înroși).
func _pregateste(muzica: AudioStream) -> void:
	var jucator := _jucator()
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
	_muzica.stream = muzica
	_muzica.bus = &"Muzica"
	add_child(_muzica)
	if mediu:
		_env = mediu.environment.duplicate(true) as Environment
		mediu.environment = _env
		for k in ["fog_light_color", "fog_density", "ambient_light_color", "ambient_light_energy"]:
			_env_initial[k] = _env.get(k)


func _jucator() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("jucator") as CharacterBody3D


func _ecran(strat: CanvasLayer, culoare_ecran: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = culoare_ecran
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


## RID-urile tuturor corpurilor (coliziunilor) din `nod`, cu el cu tot.
func _corpuri(nod: Node) -> Array[RID]:
	var r: Array[RID] = []
	if nod is CollisionObject3D:
		r.append((nod as CollisionObject3D).get_rid())
	for c in nod.find_children("*", "CollisionObject3D", true, false):
		r.append((c as CollisionObject3D).get_rid())
	return r


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
# Boss-ul și ținta lui
# ---------------------------------------------------------------------------------------------------------------

## Pune `boss` în scenă la `poz`, cu ținta (o capsulă `raza` × `inaltime`, cu mijlocul la `mijloc` m deasupra lui).
func _fa_boss(boss: Warlock, poz: Vector3, raza := 0.5, inaltime := 2.3, mijloc := 1.65) -> void:
	_boss = boss
	add_child(_boss)
	_boss.global_position = poz
	_boss.plutire = 0.5
	_boss.furie = 0.4
	_tinta = Tinta.new()
	_tinta.lupta = self
	_forma_tinta = CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = raza
	capsula.height = inaltime
	_forma_tinta.shape = capsula
	_forma_tinta.position = Vector3.UP * mijloc
	_tinta.add_child(_forma_tinta)
	_boss.add_child(_tinta)
	_intoarce_boss(_jucator().global_position, 1.0)


func _piept_boss() -> Vector3:
	return _boss.global_position + Vector3.UP * (_boss.plutire + inaltime_piept)


func _piept_jucator() -> Vector3:
	return _jucator().global_position + Vector3.UP * 1.1


func _intoarce_boss(spre: Vector3, k: float) -> void:
	var d := spre - _boss.global_position
	_boss.rotation.y = lerp_angle(_boss.rotation.y, atan2(d.x, d.z), k)


func _process(delta: float) -> void:
	var jucator := _jucator()
	if jucator == null:
		return
	if is_instance_valid(_boss) and _lupta_activa:
		_intoarce_boss(jucator.global_position, 1.0 - exp(-delta * 5.0))
		_boss.priveste((jucator.get_node("Cap") as Node3D).global_position)
	_misca_proiectile()
	_misca_globuri(delta)


## Cât ia boss-ul de la `arma` (id-ul armei din inventar).
func _damage_arma(arma: String) -> int:
	match arma:
		"pistol_roz", "pistol_aur":
			return damage_pistol
		"cutit":
			return damage_cutit
		"katana":
			return damage_katana
		"shotgun":
			var d := _jucator().global_position.distance_to(_boss.global_position)
			return damage_shotgun_aproape if d <= distanta_shotgun else damage_shotgun_departe
		"ak47":
			return damage_ak47
		"bazooka":
			return damage_bazooka
		"vraja_foc":
			return damage_fireball
	return damage_pistol


## Cât poate coborî viața acum (o luptă cu două faze se oprește la pragul fazei a doua).
func _viata_minima() -> float:
	return 0.0


## Damage-ul de la armă (Tinta.lovit_de).
func _lovit(arma: String, directie: Vector3, punct: Vector3) -> void:
	if not _lupta_activa or _ascuns or _viata <= _viata_minima():
		return
	var damage := _damage_arma(arma)
	_viata = maxf(_viata - damage, _viata_minima())
	_bara.viata_boss(_viata, _viata_bara_maxima(), damage)
	_boss.tresare(-directie, clampf(damage / 25.0, 0.4, 2.0))
	_scantei_lovitura(punct, -directie, damage)
	_sunet_lovitura(punct, damage)
	_dupa_lovitura()


## Lovitura în el se aude (mai tare la armele grele), iar din când în când geme (`sunet_durere`).
func _sunet_lovitura(punct: Vector3, damage: int) -> void:
	var acum := Time.get_ticks_msec()
	if acum - _ultim_lovit > PAUZA_LOVIT:
		_ultim_lovit = acum
		VrajaAtac.sunet_la(self, SUNET_BOSS_LOVIT, punct, Sunet.VOLUM_EFECTE - 2.0 + clampf(damage / 20.0, 0.0, 6.0), 10.0, 0.12)
	if sunet_durere and acum - _ultima_durere > PAUZA_DURERE and (damage >= 20 or randf() < 0.25):
		_ultima_durere = acum
		VrajaAtac.sunet_la(self, sunet_durere, _piept_boss(), Sunet.VOLUM_EFECTE, 12.0, 0.08)


## Cât e bara plină (la Head Witch, în faza a doua, alt număr).
func _viata_bara_maxima() -> float:
	return viata_maxima


## După fiecare lovitură: la 0 l-ai învins; sub jumătate (Warlock-ul) cere faza a doua.
func _dupa_lovitura() -> void:
	if _viata <= 0.0:
		_invins()
	elif not _faza_doi and _viata <= viata_maxima * 0.5:
		_faza_doi_ceruta = true


func _scantei_lovitura(punct: Vector3, spre: Vector3, damage: int) -> void:
	var s := VrajaAtac.particule(self, 10 + mini(damage, 60), 0.5, 0.05, [Color(1.0, 0.85, 0.7), culoare, Color(culoare.darkened(0.7), 0.0)])
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
# Lupta
# ---------------------------------------------------------------------------------------------------------------

## Viața plină (și a ta), bara, muzica; apoi `_lupta()` (ordinea atacurilor, a fiecărui boss).
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
	# (la Warlock pornește deja din intro, după bătaia în ușă: n-o lua de la capăt)
	if not _muzica.playing:
		_muzica.volume_db = -30.0
		_muzica.play()
	create_tween().tween_property(_muzica, "volume_db", Sunet.VOLUM_MUZICA, 2.0)
	_boss.furie = 0.5
	_lupta()


## Atacurile, unul după altul, cât ține runda (vezi lupta_warlock.gd / lupta_head_witch.gd).
func _lupta() -> void:
	pass


## Salva: ridică mâna și aruncă 3 (în faza a doua 5) vrăji, una după alta, spre unde ești. Te poți feri.
func _salva(cate := -1, viteza := -1.0) -> void:
	var r := _runda
	_boss.ridica_mana(-1.5, 0.35, 0.0)
	if not await _asteapta(0.45):
		return
	if cate < 0:
		cate = 5 if _faza_doi else 3
	if viteza < 0.0:
		viteza = 17.0 if _faza_doi else 14.0
	for i in cate:
		var de_la := _boss.palma()
		var tinta := _piept_jucator()
		var dir := (tinta - de_la).normalized()
		# trece de tine și se oprește în pământ sau departe în spate
		var la := tinta + dir * 14.0
		if la.y < 0.0 and dir.y < -0.01:
			la = tinta + dir * minf(14.0, (tinta.y - 0.05) / -dir.y)
		var v := VrajaAtac.trage(self, de_la, la, fel_vraja, 0.8, de_la.distance_to(la) / viteza, 0.25, false)
		_proiectile.append([v, damage_vraja, 0.75, r])
		if not await _asteapta(0.32 if _faza_doi else 0.45):
			return
	_boss.ridica_mana(0.0, 0.5, 0.0)


## Fulgere: cercuri pe jos (unul sub tine, altele în jur), iar după o clipă loviturile din cer.
func _fulgere(valuri := -1, in_jur := -1) -> void:
	var r := _runda
	_boss.ridica_toiagul(-2.8, 0.5)
	VrajaAtac.sunet_la(self, SUNET_TUNET, _boss.global_position + Vector3.UP * 6.0, Sunet.VOLUM_EFECTE - 6.0, 16.0)
	if not await _asteapta(0.5):
		return
	if valuri < 0:
		valuri = 3 if _faza_doi else 2
	if in_jur < 0:
		in_jur = 3 if _faza_doi else 2
	for val in valuri:
		var j := _jucator()
		var centre: Array[Vector3] = [j.global_position + j.velocity * Vector3(0.5, 0.0, 0.5)]
		for k in in_jur:
			var u := randf() * TAU
			centre.append(j.global_position + Vector3(cos(u), 0.0, sin(u)) * randf_range(2.5, 5.0))
		for c in centre:
			_fulger_pe(Vector3(c.x, j.global_position.y, c.z), 1.0 if _faza_doi else 1.2, r)
		if not await _asteapta(0.9):
			return
	_boss.ridica_toiagul(0.0, 0.6)


func _fulger_pe(centru: Vector3, avertizare: float, r: int, raza := 1.6, damage := -1.0) -> void:
	# cercul de pe jos, o coloană slabă (să-l vezi și cu coada ochiului) și un sfârâit de energie
	var inel := _inel(centru + Vector3.UP * 0.04, raza - 0.1, Color(culoare, 0.9))
	inel.scale = Vector3(0.2, 0.04, 0.2)
	var coloana := _stalp_lumina(centru, 4.0, 0.25 * raza / 1.6, culoare)
	(coloana.material_override as ShaderMaterial).set_shader_parameter("putere", 0.0)
	VrajaAtac.sunet_la(self, SUNET_CERC, centru + Vector3.UP, Sunet.VOLUM_EFECTE, 6.0, 0.12)
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
	Fulger.loveste(self, centru + Vector3(randf_range(-3, 3), 30.0, randf_range(-3, 3)), centru, culoare, 0.28, true, 0.8)
	_fum(centru + Vector3.UP * 0.2, 12)
	var j := _jucator()
	var d := Vector2(j.global_position.x - centru.x, j.global_position.z - centru.z).length()
	if d < raza:
		if ScutJucator.activ:
			_scut_lovit(centru + Vector3.UP * 2.4)
		else:
			_raneste(damage_fulger if damage < 0.0 else damage, centru, false)


## Globul mare: îl încarcă deasupra toiagului (mâinii), apoi îl aruncă; te urmărește puțin. Te dărâmă fără scut.
func _glob_mare(marime := 1.0) -> void:
	var r := _runda
	_boss.ridica_toiagul(-2.6, 0.6)
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
		glob.global_position = _boss.varf_toiag() + Vector3.UP * 0.35 * marime
		glob.scale = Vector3.ONE * lerpf(0.2, marime, minf(t / durata, 1.0))
	incarcare.queue_free()
	_boss.ridica_toiagul(-1.3, 0.2)
	VrajaAtac.sunet_la(self, SUNET_ORB_ZBOR, glob.global_position, Sunet.VOLUM_EFECTE - 2.0, 14.0)
	var dir := (_piept_jucator() - glob.global_position).normalized()
	_globuri.append({"nod": glob, "viteza": dir * (11.0 if _faza_doi else 9.0), "timp": 0.0, "runda": r})
	await _asteapta(0.4)
	if r == _runda:
		_boss.ridica_toiagul(0.0, 0.6)


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
			Sunet.reda(SUNET_GLOB_BUM, Sunet.VOLUM_EFECTE - 4.0, 0.1)
			lovit = true
		elif nod.global_position.distance_to(_piept_jucator()) < 0.9:
			Sunet.reda(SUNET_GLOB_BUM, Sunet.VOLUM_EFECTE, 0.1)
			_alb.color = Color(culoare.lightened(0.5), 0.6)
			create_tween().tween_property(_alb, "color:a", 0.0, 0.5)
			_raneste(g.get("damage", damage_glob), nod.global_position - v, true)
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
			Sunet.reda(SUNET_GLOB_BUM, Sunet.VOLUM_EFECTE - 8.0, 0.1)
			_raneste(p[1], v.global_position - (v._la - v._de_la).normalized(), false)
			_proiectile.erase(p)


func _explodeaza_acum(v: VrajaAtac) -> void:
	v._la = v.global_position
	v._explodeaza()


## Unda de șoc (când stai lângă el): bate toiagul în pământ, un inel fuge pe jos și te aruncă.
func _unda(raza := 7.0) -> void:
	var r := _runda
	var centru := _boss.global_position
	_boss.ridica_toiagul(-2.9, 0.6)
	_boss.ridica_mana(-2.6, 0.6, 0.4)
	var avertizare := _inel(centru + Vector3.UP * 0.05, 1.0, Color(culoare, 0.8))
	avertizare.scale = Vector3(0.4, 0.04, 0.4)
	var lumina := _lumina_scurta(centru + Vector3.UP * 0.5, culoare, 0.5, 6.0, 0.01)
	var t := create_tween().set_parallel()
	t.tween_property(avertizare, "scale", Vector3(1.2, 0.04, 1.2), 0.9)
	t.tween_property(lumina, "light_energy", 4.0, 0.9)
	VrajaAtac.sunet_la(self, SUNET_CERC, centru + Vector3.UP, Sunet.VOLUM_EFECTE + 3.0, 10.0, 0.0)
	if not await _asteapta(0.9 if not _faza_doi else 0.7):
		avertizare.queue_free()
		return
	avertizare.queue_free()
	if is_instance_valid(lumina):
		lumina.queue_free()
	_boss.ridica_toiagul(-0.6, 0.12)
	_boss.ridica_mana(0.0, 0.3, 0.0)
	VrajaAtac.sunet_la(self, SUNET_UNDA_SOC, centru, Sunet.VOLUM_EFECTE, 12.0)
	_lumina_scurta(centru + Vector3.UP, culoare, 10.0, 14.0, 0.6)
	_fum(centru + Vector3.UP * 0.3, 30)
	await _val_de_soc(centru, raza, 0.45, damage_unda, r)
	if r == _runda:
		_boss.ridica_toiagul(0.0, 0.5)


## Un inel care fuge pe jos de la `centru` până la `raza` în `durata` s: te aruncă (fără scut) când trece prin tine.
func _val_de_soc(centru: Vector3, raza: float, durata: float, damage: float, r: int) -> void:
	var unda := _inel(centru + Vector3.UP * 0.06, 1.0, Color(culoare.lightened(0.15), 1.0))
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
				_raneste(damage, centru, false, 9.0)
	var tw := create_tween()
	tw.tween_method(pas, 0.0, 1.0, durata).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(a: float) -> void: (unda.material_override as StandardMaterial3D).albedo_color.a = a, 1.0, 0.0, durata + 0.05)
	await tw.finished
	unda.queue_free()


## Se topește într-un fum și apare în alt loc (`locuri_teleport`), departe de tine.
func _teleport() -> void:
	var r := _runda
	if not _lupta_activa:
		return
	var j := _jucator()
	var aici := _boss.global_position
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
	_fum(aici + Vector3.UP * 1.0, 24)
	_ascuns = true
	_forma_tinta.set_deferred("disabled", true)
	await _boss.ascunde(0.35).finished
	if r != _runda:
		return
	if not await _asteapta(0.35):
		return
	_boss.global_position = unde
	_intoarce_boss(_jucator().global_position, 1.0)
	VrajaAtac.sunet_la(self, SUNET_TELEPORT, unde + Vector3.UP, Sunet.VOLUM_EFECTE, 14.0)
	_fum(unde + Vector3.UP * 1.0, 24)
	_lumina_scurta(unde + Vector3.UP * 1.5, culoare, 6.0, 10.0, 0.5)
	await _boss.aparitie(0.35).finished
	_ascuns = false
	_forma_tinta.set_deferred("disabled", false)


## Scutul tău a oprit ceva: fulgeră, sar scântei din el și se aude lovitura (fără damage).
func _scut_lovit(punct: Vector3) -> void:
	var j := _jucator()
	var scut := get_tree().get_first_node_in_group("scut_jucator")
	if scut:
		scut.call("lovit")
	var centru := j.global_position + Vector3.UP * 1.3
	var n := punct - centru
	n = n.normalized() if n.length() > 0.01 else -j.global_basis.z
	var s := VrajaAtac.particule(self, 40, 0.45, 0.022, [Color(1, 1, 1, 1), Color(0.85, 0.6, 1.0, 1.0), Color(culoare, 0.8),
		Color(culoare, 0.0)])
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
	Sunet.reda(SUNET_PARARE, Sunet.VOLUM_EFECTE, 0.1)
	Zguduire.porneste(_camera_jucator, 0.015, 0.25)


## Te lovește ceva (fără scut): viața scade, roșu pe ecran, camera sare, ești împins; `doboara` = cazi jos.
func _raneste(damage: float, dinspre: Vector3, doboara: bool, impins := 4.0) -> void:
	if not _lupta_activa or _viata_jucator <= 0.0:
		return
	var j := _jucator()
	_viata_jucator = maxf(_viata_jucator - damage, 0.0)
	_bara.viata_jucator(_viata_jucator, viata_jucator)
	_bara.ranit(clampf(damage / 30.0, 0.5, 1.0))
	Sunet.reda(SUNET_LOVIT_TU, Sunet.VOLUM_EFECTE, 0.08)
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
	Sunet.reda(SUNET_CAZI, Sunet.VOLUM_EFECTE, 0.05)
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


## „YOU DIED”: cazi, totul se oprește, mesajul roșu, negru, `_reia_lupta()` (fiecare boss pune locurile ca la
## început), apoi lupta de la capăt.
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
	if sunet_ras:
		# râde de tine, după clopot
		get_tree().create_timer(1.3, false).timeout.connect(_rade)
	_bara.ascunde(1.0)
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(cap, "position:y", 0.25, 1.0)
	t.tween_property(cap, "rotation:x", 0.1, 1.0)
	t.tween_property(_camera_jucator, "rotation:z", 1.25, 1.0)
	# rămâne pe ecran până apeși „Retry” (owner 10.10)
	await _bara.mesaj_cu_buton("YOU DIED", BaraBoss.ROSU_DESCHIS, "Retry")
	var negru := create_tween()
	negru.tween_property(_negru, "color:a", 1.0, 1.0)
	await negru.finished
	_muzica.stop()
	_tween_cer(0.0, 0.01)
	_ascuns = false
	_forma_tinta.set_deferred("disabled", false)
	await _reia_lupta()
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


func _rade() -> void:
	if is_instance_valid(_boss) and sunet_ras:
		VrajaAtac.sunet_la(self, sunet_ras, _piept_boss(), Sunet.VOLUM_EFECTE, 16.0, 0.0)


## Pe negru, după „YOU DIED”: boss-ul și tu la locurile de început.
func _reia_lupta() -> void:
	pass


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


## La 0 HP: lupta se oprește, apoi `_finalul(true)`.
func _invins() -> void:
	_lupta_activa = false
	_runda += 1
	_curata()
	_la_invins()
	_finalul(true)


## Marcajele de la „l-ai învins” (fiecare boss pe ale lui).
func _la_invins() -> void:
	pass


func _finalul(_din_lupta: bool) -> void:
	pass


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


func _lumina_scurta(p: Vector3, culoare_lumina: Color, energie: float, raza: float, durata: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = culoare_lumina
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


## Un fum în culoarea vrăjilor lui (teleportul, loviturile).
func _fum(unde: Vector3, cat: int) -> void:
	var f := VrajaAtac.particule(self, cat, 1.2, 0.45, [Color(culoare.lightened(0.15), 0.8), Color(culoare.darkened(0.55), 0.5),
		Color(culoare.darkened(0.85), 0.0)])
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
	VrajaAtac.trage(self, unde, unde, fel_vraja, marime, 0.01, 0.0, false, false)
	VrajaAtac.sunet_la(self, SUNET_GLOB_BUM, unde, Sunet.VOLUM_EFECTE - 2.0, 8.0 * marime)


func _sunet_incarcare() -> AudioStreamPlayer3D:
	var s := AudioStreamPlayer3D.new()
	s.stream = SUNET_INCARCARE
	s.bus = &"Efecte"
	s.unit_size = 12.0
	s.max_distance = 120.0
	s.volume_db = Sunet.VOLUM_EFECTE
	_boss.add_child(s)
	s.position = Vector3.UP * 2.5
	s.play()
	return s


## Globul de pe toiag (miez alb, straturi în culoarea lui, lumină).
func _glob_mic() -> Node3D:
	var g := Node3D.new()
	for strat in [[0.16, Color(1.0, 0.92, 0.88), false], [0.3, Color(culoare.lightened(0.1), 0.7), true], [0.5, Color(culoare.darkened(0.35), 0.45), true]]:
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
	lumina.light_color = culoare
	lumina.light_energy = 4.0
	lumina.omni_range = 8.0
	g.add_child(lumina)
	var trase := VrajaAtac.particule(g, 30, 0.5, 0.06, [Color(culoare.lightened(0.3), 0.0), Color(culoare.lightened(0.15), 1.0), Color(1.0, 0.9, 0.85, 1.0)])
	trase.local_coords = true
	trase.emission_sphere_radius = 1.0
	trase.radial_accel_min = -18.0
	trase.radial_accel_max = -12.0
	trase.emitting = true
	add_child(g)
	g.global_position = _boss.varf_toiag() + Vector3.UP * 0.35
	g.scale = Vector3.ONE * 0.2
	_de_sters.append(g)
	return g


## Un inel plat pe jos (cercurile de avertizare, unda de șoc): raza exterioară `raza` (la scara 1).
func _inel(centru: Vector3, raza: float, culoare_inel: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = raza * 0.86
	mesh.outer_radius = raza
	mesh.rings = 32
	mesh.ring_segments = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = culoare_inel
	mat.disable_fog = true
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = centru
	mi.scale = Vector3(1.0, 0.04, 1.0)  # plat pe jos (cine îl scalează păstrează y-ul)
	_de_sters.append(mi)
	return mi


func _stalp_lumina(jos: Vector3, inalt: float, raza: float, culoare_stalp: Color) -> MeshInstance3D:
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
	mat.set_shader_parameter("culoare", culoare_stalp)
	mat.set_shader_parameter("putere", 1.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = jos + Vector3.UP * inalt * 0.5
	return mi


## O rază: un cilindru subțire (shader-ul undei), întins între două puncte în fiecare cadru (`_aseaza_raza`).
func _raza(culoare_raza: Color, groasa := 1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05 * groasa
	mesh.bottom_radius = 0.09 * groasa
	mesh.height = 1.0
	mesh.radial_segments = 10
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_RAZA
	mat.set_shader_parameter("culoare", culoare_raza)
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


## Cerul și ceața spre culorile furiei (`k` = 1) sau înapoi cum erau (0), în `durata` s.
func _tween_cer(k: float, durata: float) -> void:
	if _env == null:
		return
	var de_la := {"fog_light_color": _env.fog_light_color, "fog_density": _env.fog_density,
		"ambient_light_color": _env.ambient_light_color, "ambient_light_energy": _env.ambient_light_energy}
	var spre := {"fog_light_color": (_env_initial["fog_light_color"] as Color).lerp(ceata_furie, k),
		"fog_density": lerpf(_env_initial["fog_density"], _env_initial["fog_density"] * 1.6, k),
		"ambient_light_color": (_env_initial["ambient_light_color"] as Color).lerp(ambient_furie, k),
		"ambient_light_energy": lerpf(_env_initial["ambient_light_energy"], _env_initial["ambient_light_energy"] * 1.3, k)}
	create_tween().tween_method(func(x: float) -> void:
		_env.fog_light_color = (de_la["fog_light_color"] as Color).lerp(spre["fog_light_color"], x)
		_env.fog_density = lerpf(de_la["fog_density"], spre["fog_density"], x)
		_env.ambient_light_color = (de_la["ambient_light_color"] as Color).lerp(spre["ambient_light_color"], x)
		_env.ambient_light_energy = lerpf(de_la["ambient_light_energy"], spre["ambient_light_energy"], x), 0.0, 1.0, durata)
