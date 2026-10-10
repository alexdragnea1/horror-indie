extends LuptaBoss
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
##     Viața ta: `viata_jucator` (doar în lupta asta). La 0: „YOU DIED” cu butonul „Retry” (owner 10.10), apoi lupta o ia de la capăt de la ușă.
##  3. Finalul (când „îl omori”, `marcaj_invins`): cade în genunchi, „WARLOCK DEFEATED”, Head Witch se ridică, vine la
##     el și îi absoarbe puterile (raza roșie, el se ridică în aer și se face cenușă), vine la tine, `replici_final`
##     (owner), apoi dispare (sefa_motel.gd, `marcaj_plecata`). → `sarcina_dupa`.
## La Continue: în lupta începută o iei de la ușă; după `marcaj_invins`, finalul de la ridicarea ei.
## Replicile sunt ale owner-ului: nu le corecta.
## Partea comună cu lupta din City Center (viața, armele, atacurile, „YOU DIED”, efectele) e în lupta_boss.gd.

@export var usa: Interactabil
@export var sefa: Node3D

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

@export_group("Locuri")
## Unde stai când bați la ușă și mijlocul ușii 122.
@export var loc_usa := Vector3(0.72, 0.15, -8.85)
@export var mijloc_usa := Vector3(0.725, 1.2, -9.92)
## Unde se teleportează în intro (mijlocul parcării) și unde poate sări în luptă.
@export var loc_aparitie := Vector3(-5.5, 0.0, 3.5)
## Încotro o aruncă vraja pe Head Witch (de-a lungul trotuarului, nu în perete) și cât de departe.
@export var cadere_sefa := Vector3(1.0, 0.0, -0.25)
@export var departe_sefa := 1.6

const SUNET_CIOCANIT := preload("res://sunete/usa_ciocanit.ogg")
const SUNET_PAS := preload("res://sunete/pas_lemn_2.ogg")
const SUNET_MUZICA := preload("res://sunete/muzica_lupta_warlock.ogg")
## Vocea lui și stingerul de la apariție (10.10, pachetele noi; vezi sunete.sh).
const SUNET_DURERE := preload("res://sunete/warlock_durere.ogg")
const SUNET_RAS := preload("res://sunete/warlock_ras.ogg")
const SUNET_URLET := preload("res://sunete/warlock_urlet.ogg")
const SUNET_MOARE := preload("res://sunete/warlock_moare.ogg")
const SUNET_STINGER := preload("res://sunete/stinger_aparitie.ogg")

## Raza dintre Warlock și palma ei (finalul): capetele, actualizate în fiecare cadru.
var _raza_absorbtie: MeshInstance3D
var _sefa_ref  # fără tip: are metodele din sefa_motel.gd


func _ready() -> void:
	_sefa_ref = sefa
	var jucator := _jucator()
	if jucator == null or usa == null:
		return
	_pregateste(SUNET_MUZICA)
	sunet_durere = SUNET_DURERE
	sunet_ras = SUNET_RAS
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
		_boss.plutire = -0.3
		_boss.prabusire(0.01)
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


## Zborul lui Head Witch spre Warlock (finalul), owner 09.10: „trece prin mașină”. Pe jos, drumul ocolește ce e înalt
## (stâlpii pasarelei: `_drum_sefa`), iar peste ce e jos (mașinile) trece pe deasupra (`_profil_peste`).
const PASI_PROFIL := 48


func _excluse_zbor() -> Array:
	return _corpuri(_sefa_ref) + _corpuri(_boss) + [_jucator().get_rid()]


## Punctul de la `k` (0..1) din lungimea drumului (linie frântă).
func _pe_drum(drum: PackedVector3Array, k: float) -> Vector3:
	var total := 0.0
	for i in drum.size() - 1:
		total += drum[i].distance_to(drum[i + 1])
	var rest := clampf(k, 0.0, 1.0) * total
	for i in drum.size() - 1:
		var l := drum[i].distance_to(drum[i + 1])
		if rest <= l or i == drum.size() - 2:
			return drum[i].lerp(drum[i + 1], clampf(rest / maxf(l, 0.001), 0.0, 1.0))
		rest -= l
	return drum[drum.size() - 1]


## Bucata `a` → `b` e blocată de ceva prin care nu poate trece pe deasupra: stâlpi, pereți? Raze orizontale la 1,9 și
## 2,5 m (peste mașini, sub pasarelă), din 15 în 15 cm pe toată lățimea ei (±0,45 m; cu raze rare, stâlpul de 20 cm
## al pasarelei trecea printre ele).
func _blocat_sus(a: Vector3, b: Vector3, excluse: Array) -> bool:
	var spatiu := get_world_3d().direct_space_state
	var lat := ((b - a) * Vector3(1, 0, 1)).normalized().cross(Vector3.UP)
	for h: float in [1.9, 2.5]:
		for k in range(-3, 4):
			var d := lat * (k * 0.15)
			var c := PhysicsRayQueryParameters3D.create(a + d + Vector3.UP * h, b + d + Vector3.UP * h, 1)
			c.exclude = excluse
			c.hit_back_faces = true
			if not spatiu.intersect_ray(c).is_empty():
				return true
	return false


## Drumul ei: drept, sau (dacă e un stâlp în cale) printr-un punct de ocolire la 0,8–2,5 m de ea, cel mai scurt care
## lasă ambele bucăți libere.
func _drum_sefa(de_la: Vector3, la: Vector3) -> PackedVector3Array:
	var excluse := _excluse_zbor()
	if not _blocat_sus(de_la, la, excluse):
		return PackedVector3Array([de_la, la])
	var spre := ((la - de_la) * Vector3(1, 0, 1)).normalized()
	var cel_mai_bun := PackedVector3Array([de_la, la])
	var lungime := INF
	for d: float in [0.8, 1.3, 1.8, 2.5]:
		for grade: float in [20.0, -20.0, 40.0, -40.0, 60.0, -60.0, 85.0, -85.0]:
			var p := de_la + spre.rotated(Vector3.UP, deg_to_rad(grade)) * d
			p.y = de_la.y
			var l := de_la.distance_to(p) + p.distance_to(la)
			if l < lungime and not _blocat_sus(de_la, p, excluse) and not _blocat_sus(p, la, excluse):
				lungime = l
				cel_mai_bun = PackedVector3Array([de_la, p, la])
	return cel_mai_bun


## Cât e de înaltă Head Witch cu pălărie cu tot (pentru tavanul de deasupra ei: pasarela, streașina).
const INALTIME_SEFA := 1.95


## Pe `drum`, în PASI_PROFIL puncte (pe mijloc și la ±0,4 m în lateral, cât e ea de lată): cât de sus trebuie să-i fie
## tălpile ca să treacă pe deasupra a ce e acolo (mașini, bănci, borduri înalte), cu 0,3 m loc liber; 0 = drum liber.
## Întoarce [peste, tavan]: `tavan` = cât poate urca acolo fără să dea cu pălăria de ce e deasupra (99 = cer liber).
func _profil_peste(drum: PackedVector3Array) -> Array:
	var profil := PackedFloat32Array()
	profil.resize(PASI_PROFIL + 1)
	var tavan := PackedFloat32Array()
	tavan.resize(PASI_PROFIL + 1)
	var spatiu := get_world_3d().direct_space_state
	var excluse := _excluse_zbor()
	for i in PASI_PROFIL + 1:
		var k := float(i) / PASI_PROFIL
		var p := _pe_drum(drum, k)
		var inainte := _pe_drum(drum, minf(k + 0.02, 1.0)) - _pe_drum(drum, maxf(k - 0.02, 0.0))
		var lat := (inainte * Vector3(1, 0, 1)).normalized().cross(Vector3.UP) * 0.4
		var cel_mai_sus := 0.0
		for d: Vector3 in [Vector3.ZERO, lat, -lat]:
			# de la 2,6 m în jos: sub streașina aleii (de deasupra ar fi „văzut” acoperișul ca obstacol)
			var c := PhysicsRayQueryParameters3D.create(p + d + Vector3.UP * 2.6, p + d + Vector3.DOWN * 0.3, 1)
			c.exclude = excluse
			var r := spatiu.intersect_ray(c)
			if not r.is_empty():
				cel_mai_sus = maxf(cel_mai_sus, (r.position as Vector3).y - p.y)
		profil[i] = cel_mai_sus + 0.3 if cel_mai_sus > 0.2 else 0.0
		var sus := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.3, p + Vector3.UP * 8.0, 1)
		sus.exclude = excluse
		var r_sus := spatiu.intersect_ray(sus)
		tavan[i] = 99.0 if r_sus.is_empty() else maxf((r_sus.position as Vector3).y - p.y - INALTIME_SEFA - 0.1, 0.0)
	return [profil, tavan]


## Înălțimea zborului în punctul `k` (0..1) pe un drum de `lungime` metri: „cortul” peste fiecare obstacol din profil
## (urcă lin pe RAMPA_ZBOR metri înainte, e exact la înălțime deasupra lui, coboară lin după), deci nu taie colțurile;
## dar niciodată peste tavanul de acolo (sub pasarelă rămâne jos și urcă abia după ce iese de sub ea).
const RAMPA_ZBOR := 1.2
func _sus_pe_profil(profil: Array, k: float, lungime: float) -> float:
	var peste: PackedFloat32Array = profil[0]
	var tavan: PackedFloat32Array = profil[1]
	var lat := RAMPA_ZBOR / maxf(lungime, 0.1)
	var sus := 0.0
	for i in peste.size():
		if peste[i] <= 0.0:
			continue
		var cat := 1.0 - absf(k - float(i) / PASI_PROFIL) / lat
		if cat > 0.0:
			sus = maxf(sus, peste[i] * ease(minf(cat * 1.6, 1.0), -1.8))
	var j := clampi(roundi(k * PASI_PROFIL), 0, PASI_PROFIL)
	return minf(sus, tavan[j])


## Lângă Warlock, la 2,4 m: întâi din direcția din care vine ea, apoi tot mai într-o parte, până nu mai e nimic acolo
## (o cutie cât ea; altfel ateriza în mașina lângă care căzuse el).
func _loc_liber_langa_warlock(dinspre: Vector3) -> Vector3:
	var w := _boss.global_position
	var forma := BoxShape3D.new()
	forma.size = Vector3(0.7, 1.5, 0.7)
	var cerere := PhysicsShapeQueryParameters3D.new()
	cerere.shape = forma
	cerere.collision_mask = 1
	cerere.exclude = _corpuri(_sefa_ref) + _corpuri(_boss) + [_jucator().get_rid()]
	for grade: float in [0.0, 35.0, -35.0, 70.0, -70.0, 110.0, -110.0, 150.0, -150.0, 180.0]:
		var loc := w - dinspre.rotated(Vector3.UP, deg_to_rad(grade)) * 2.4
		loc.y = w.y
		cerere.transform = Transform3D(Basis.IDENTITY, loc + Vector3.UP * 0.95)
		if get_world_3d().direct_space_state.intersect_shape(cerere, 1).is_empty():
			return loc
	var loc := w - dinspre * 2.4
	loc.y = w.y
	return loc


func _loc_sefa_cazuta() -> Vector3:
	var loc: Vector3 = _sefa_ref.loc_la_usa
	return loc + cadere_sefa.normalized() * departe_sefa


# ---------------------------------------------------------------------------------------------------------------
# Warlock-ul
# ---------------------------------------------------------------------------------------------------------------

func _fa_warlock(poz: Vector3) -> void:
	_fa_boss(Warlock.new(), poz)


func _process(delta: float) -> void:
	super(delta)
	if is_instance_valid(_raza_absorbtie) and is_instance_valid(_boss):
		_aseaza_raza(_raza_absorbtie, _piept_boss(), _sefa_ref.palma())


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
	# muzica luptei pornește imediat după bătaie (owner, 10.10), tare, și merge mai departe în luptă
	_muzica.volume_db = Sunet.VOLUM_MUZICA
	_muzica.play()
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
	_boss.furie = 0.8
	ModelPS2.disparitie(_boss._model, 1.0)
	var cer := loc_aparitie + Vector3(randf_range(-4, 4), 40, randf_range(-3, 3))
	Fulger.loveste(self, cer, loc_aparitie, ROSU, 0.35, true, 1.6)
	VrajaAtac.sunet_la(self, SUNET_TELEPORT, loc_aparitie + Vector3.UP, Sunet.VOLUM_EFECTE + 2.0, 18.0)
	Sunet.reda(SUNET_STINGER, Sunet.VOLUM_EFECTE - 2.0)
	_lumina_scurta(loc_aparitie + Vector3.UP * 2.0, ROSU, 14.0, 26.0, 1.2)
	_fum(loc_aparitie + Vector3.UP * 0.8, 40)
	Zguduire.porneste(_camera_jucator, 0.03, 0.5)
	if _sefa_ref.has_method("intoarce_spre"):
		_sefa_ref.intoarce_spre(_boss)
	await get_tree().create_timer(0.25, false).timeout
	await c.priveste(_piept_boss(), 0.45)
	# plan de jos, între voi și el: se încheagă din pixeli în lumina roșie
	var stalp := _stalp_lumina(loc_aparitie, 30.0, 0.9, ROSU)
	_boss.aparitie(1.4)
	_boss.priveste(_sefa_ref.global_position + Vector3.UP * 1.6)
	get_tree().create_timer(0.9, false).timeout.connect(_rade)
	var d := (loc_usa - loc_aparitie)
	d.y = 0.0
	d = d.normalized()
	var lateral := d.cross(Vector3.UP)
	_film(loc_aparitie + d * 4.2 + lateral * 1.2 + Vector3.UP * 0.35, _piept_boss() + Vector3.UP * 0.3, 50.0,
		loc_aparitie + d * 3.4 + lateral * 0.7 + Vector3.UP * 0.45, 2.6)
	var stinge := create_tween()
	stinge.tween_interval(1.2)
	stinge.tween_method(func(v: float) -> void: (stalp.material_override as ShaderMaterial).set_shader_parameter("putere", v), 1.0, 0.0, 1.0)
	stinge.tween_callback(stalp.queue_free)
	await get_tree().create_timer(2.6, false).timeout
	_camera_jucator.make_current()

	# o vrajă în Head Witch: cade și rămâne jos
	_boss.ridica_mana(-1.5, 0.35, 0.0)
	await get_tree().create_timer(0.35, false).timeout
	var tinta_sefa: Vector3 = _sefa_ref.global_position + Vector3.UP * 1.2
	var v := VrajaAtac.trage(self, _boss.palma(), tinta_sefa, "rosu", 1.0, 0.6, 0.4, false)
	await get_tree().create_timer(0.3, false).timeout
	_sefa_ref.brat_scut(true, 0.25)  # prea târziu
	await v.lovit
	_sefa_ref.cade(cadere_sefa, departe_sefa)
	Zguduire.porneste(_camera_jucator, 0.02, 0.4)
	_boss.ridica_mana(0.0, 0.6, 0.0)
	c.priveste(tinta_sefa + cadere_sefa.normalized() * departe_sefa - Vector3.UP * 0.6, 0.35)
	await get_tree().create_timer(1.0, false).timeout

	# acum tu: își încarcă toiagul, iar tu ai `fereastra_scut` secunde pentru scut
	await c.priveste(_piept_boss(), 0.5)
	_boss.priveste(cap.global_position)
	_boss.ridica_toiagul(-2.6, 0.8)
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
		glob.global_position = _boss.varf_toiag() + Vector3.UP * 0.35
		glob.scale = Vector3.ONE * lerpf(0.2, 1.0, minf(timp / 1.2, 1.0))
		_boss.furie = lerpf(0.8, 1.0, minf(timp / fereastra_scut, 1.0))
	_asteapta_scut = false
	_bara.indicatie_scut(0.0)
	var scut := get_tree().get_first_node_in_group("scut_jucator")
	if _scut_apasat and scut:
		scut.call("ridica_din_scena")
		await get_tree().create_timer(0.3, false).timeout
	incarcare.queue_free()
	# aruncă
	_boss.ridica_toiagul(-1.3, 0.2)
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
	Sunet.reda(SUNET_GLOB_BUM, Sunet.VOLUM_EFECTE + 2.0, 0.05)
	if aparat:
		_scut_lovit(unde)
		Zguduire.porneste(_camera_jucator, 0.03, 0.4)
		# te împinge puțin înapoi, în scut
		var spate := (jucator.global_position - _boss.global_position) * Vector3(1, 0, 1)
		create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).tween_property(jucator, "global_position",
			jucator.global_position + spate.normalized() * 0.35, 0.4)
		await get_tree().create_timer(1.4, false).timeout
	else:
		_alb.color = Color(1.0, 0.55, 0.5, 0.8)
		create_tween().tween_property(_alb, "color:a", 0.0, 0.6)
		await _cazi_jos(_boss.global_position, 0.9, false)
	_boss.ridica_toiagul(0.0, 0.6)
	Stare.marcheaza(marcaj_lupta)
	Stare.seteaza_sarcina(sarcina_lupta)
	jucator.seteaza_purtat(false)
	_hud(true)
	await c.opreste()
	_porneste_lupta()


# ---------------------------------------------------------------------------------------------------------------
# 2. Lupta
# ---------------------------------------------------------------------------------------------------------------

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
		var distanta := Vector2(j.global_position.x - _boss.global_position.x, j.global_position.z - _boss.global_position.z).length()
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


## Sub jumătate de viață: urcă în aer, fulgere în jurul lui, cerul și ceața se înroșesc; de acum e mai rapid.
func _treci_in_faza_doi() -> void:
	_faza_doi = true
	var r := _runda
	var centru := _boss.global_position
	_boss.ridica_toiagul(-2.9, 0.6)
	_boss.ridica_mana(-2.6, 0.6, 0.5)
	create_tween().tween_property(_boss, "furie", 1.0, 1.5)
	create_tween().tween_property(_boss, "plutire", 1.1, 1.5).set_trans(Tween.TRANS_SINE)
	VrajaAtac.sunet_la(self, SUNET_TUNET, centru + Vector3.UP * 8.0, Sunet.VOLUM_EFECTE, 18.0)
	VrajaAtac.sunet_la(self, SUNET_URLET, _piept_boss(), Sunet.VOLUM_EFECTE + 2.0, 16.0, 0.0)
	_tween_cer(1.0, 2.5)
	for k in 4:
		var u := k * TAU / 4.0 + randf() * 0.5
		var jos := centru + Vector3(cos(u), 0.0, sin(u)) * randf_range(2.5, 4.0)
		Fulger.loveste(self, jos + Vector3(0, 30, 0), jos, ROSU, 0.3, k == 0, 1.0)
		if not await _asteapta(0.3):
			return
	await _asteapta(0.6)
	if r == _runda:
		create_tween().tween_property(_boss, "plutire", 0.5, 1.0).set_trans(Tween.TRANS_SINE)
		_boss.ridica_toiagul(0.0, 0.6)
		_boss.ridica_mana(0.0, 0.6, 0.0)


## Pe negru, după „YOU DIED”: tu la ușă, el în mijlocul parcării.
func _reia_lupta() -> void:
	_boss.global_position = loc_aparitie
	_boss.plutire = 0.5
	_boss.ridica_toiagul(0.0, 0.01)
	_boss.ridica_mana(0.0, 0.01, 0.0)
	ModelPS2.disparitie(_boss._model, 0.0)
	_pune_jucatorul(loc_usa, loc_aparitie)


# ---------------------------------------------------------------------------------------------------------------
# 3. Finalul: Head Witch îi ia puterile
# ---------------------------------------------------------------------------------------------------------------

func _la_invins() -> void:
	Stare.marcheaza(marcaj_invins)
	Stare.seteaza_sarcina("")


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
		_boss.tresare(_boss.global_position - j.global_position, 2.5)
		_lumina_scurta(_piept_boss(), ROSU, 8.0, 10.0, 0.6)
		Sunet.reda(SUNET_IMPACT, Sunet.VOLUM_EFECTE - 3.0)
		VrajaAtac.sunet_la(self, SUNET_MOARE, _piept_boss(), Sunet.VOLUM_EFECTE + 2.0, 14.0, 0.0)
		await c.priveste(_piept_boss(), 0.5)
		# cade în genunchi (plan din lateral, de jos: de unde stai tu poate fi o mașină în cale)
		var w := _boss.global_position
		var spre_tine := (j.global_position - w) * Vector3(1, 0, 1)
		spre_tine = spre_tine.normalized() if spre_tine.length() > 0.1 else Vector3.BACK
		var latura := spre_tine.cross(Vector3.UP)
		_film(w + spre_tine * 5.2 + latura * 2.8 + Vector3.UP * 1.3, w + Vector3.UP * 1.2, 50.0,
			w + spre_tine * 4.4 + latura * 2.3 + Vector3.UP * 1.1, 4.5, _boss, 1.0)
		await _boss.prabusire(1.3).finished
		VrajaAtac.sunet_la(self, SUNET_CAZI, _boss.global_position, Sunet.VOLUM_EFECTE + 3.0, 10.0)
		_praf(_boss.global_position)
		Zguduire.porneste(_camera_jucator, 0.02, 0.3)
		Sunet.reda(SUNET_DOBORAT, Sunet.VOLUM_EFECTE)
		_bara.ascunde(0.6)
		await _bara.mesaj("WARLOCK DEFEATED", BaraBoss.AURIU, 2.4)
		_muzica.stop()
	else:
		await c.priveste(_piept_boss(), 0.01)

	# Head Witch se ridică (plan de pe trotuar, dinspre ușa 122; din parcare ar fi mașina neagră în cale)
	var jos_ea: Vector3 = _sefa_ref.global_position
	_film(jos_ea + Vector3(-3.2, 1.3, 0.55), jos_ea + Vector3.UP * 0.6, 50.0, jos_ea + Vector3(-2.6, 1.5, 0.6), 4.0, _sefa_ref, 0.9)
	c.priveste(jos_ea + Vector3.UP * 0.6, 0.01)
	await _sefa_ref.ridica_te()
	await get_tree().create_timer(0.4, false).timeout
	# plutește până la el
	_sefa_ref.distanta_privire = 0.0
	var start: Vector3 = _sefa_ref.global_position
	var spre := _boss.global_position - start
	spre.y = 0.0
	var oprire := _loc_liber_langa_warlock(spre.normalized())
	var dir := ((_boss.global_position - oprire) * Vector3(1, 0, 1)).normalized()
	_sefa_ref.rotation.y = atan2(dir.x, dir.z)
	var lateral := dir.cross(Vector3.UP)
	# pe lângă stâlpul pasarelei și peste mașini (owner, 09.10: trecea prin mașina neagră din fața lui 122)
	var drum := _drum_sefa(start, oprire)
	var profil := _profil_peste(drum)
	var peste := 0.0
	for h: float in profil[0]:
		peste = maxf(peste, h)
	var lungime := 0.0
	for i in drum.size() - 1:
		lungime += drum[i].distance_to(drum[i + 1])
	var durata := clampf(lungime / 4.0, 1.5, 4.0) + (0.7 if peste > 0.0 else 0.0)
	var mijloc := (start + oprire) * 0.5
	_film(mijloc + lateral * 7.0 + Vector3.UP * (1.6 + peste * 0.6), mijloc + Vector3.UP * (1.2 + peste * 0.5), 55.0,
		mijloc + lateral * 6.0 + dir * 1.5 + Vector3.UP * (1.8 + peste * 0.6), durata, _sefa_ref, 1.3)
	var zbor := create_tween()
	zbor.tween_method(func(k: float) -> void:
		var sus := maxf(0.25 * sin(k * PI), _sus_pe_profil(profil, k, lungime))
		_sefa_ref.global_position = _pe_drum(drum, k) + Vector3.UP * sus, 0.0, 1.0, durata) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await zbor.finished

	# îi trage puterile: raza roșie din pieptul lui în palma ei
	var piept := _piept_boss() + Vector3.UP * 0.3
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
	_boss.smuls(3.5)
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
			var jos := _boss.global_position + Vector3(cos(u), 0.0, sin(u)) * randf_range(3.0, 6.0)
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
	_cenusa(_piept_boss())
	if is_instance_valid(_raza_absorbtie):
		_raza_absorbtie.queue_free()
	curgere.emitting = false
	get_tree().create_timer(1.0, false).timeout.connect(curgere.queue_free)
	_boss.dispari(0.6)
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


## Energia care curge din el spre palma ei (particule trase spre ea).
func _curgere() -> CPUParticles3D:
	var p := VrajaAtac.particule(self, 90, 0.7, 0.04, [Color(1.0, 0.5, 0.4, 0.0), Color(1.0, 0.3, 0.2, 1.0), Color(1.0, 0.85, 0.8, 1.0)])
	var de_la := _piept_boss()
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

