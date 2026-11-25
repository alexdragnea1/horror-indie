extends LuptaBoss
## Dimineața de după final (owner 25.11), în curtea blocului (afara_bloc.tscn, nodul `LuptaVrajitor`). După ce Mom ți-a
## zis în bucătărie de noul tutore (`marcaj_mom`, acasa_noaptea.gd), ieși pe scara blocului și începe direct:
##  1. Intro (Cutscena): pe alee cade un fulger roșu și apare vrăjitorul care îl ajuta pe Warlock (VrajitorBoss,
##     models/vrajitor_3.glb); `replici_intro` (owner) → `marcaj_aparut`, `sarcina_lupta`.
##  2. Lupta (LuptaBoss, BaraBoss „Wizard”): `viata_maxima` 1000 (owner), atacă DOAR cu mingi de foc roșii (`_salva`,
##     felul „foc_rosu” din VrajaAtac); între salve se mută prin curte (teleportul, nu e atac). Sub jumătate trage mai
##     des. „YOU DIED” → de la ușa blocului.
##  3. Finalul: rămâne jos (`prabusire`), „WIZARD DEFEATED”, `replici_final` (owner), apoi se destramă în particule
##     roșii care urcă spre cer (`VrajitorBoss.destramare`) → `marcaj_disparut`.
##  4. La 3 s după: mesaj pe telefon de la Mom (`mesaje_mom`, owner) → `marcaj_mesaj`; imediat după ce bagi telefonul
##     în buzunar, `replici_sala` (owner) → `marcaj_gata`, `sarcina_dupa`.
## Cât ține lupta, orarul din stație și ușa blocului nu merg (`blocate_in_lupta`).
## Continue: în luptă = de la ușă; după „l-ai învins” = finalul de la el jos; după ce a dispărut = mesajul / replica.
## Replicile sunt ale owner-ului: nu le corecta. Sarcinile sunt ale lui Claude.

## Ce nu merge cât e vrăjitorul în curte (orarul, ușa blocului).
@export var blocate_in_lupta: Array[Interactabil] = []

@export_group("Marcaje")
@export var marcaj_final := "jocul_terminat"
@export var marcaj_somn_final := "nopti_dupa_final"
## Pus de Mom în bucătărie (acasa_noaptea.gd): de aici vrăjitorul te așteaptă afară.
@export var marcaj_mom := "a_vorbit_cu_mom_tutore"
@export var marcaj_aparut := "vrajitor_a_aparut"
@export var marcaj_invins := "vrajitor_invins"
@export var marcaj_disparut := "vrajitor_disparut"
@export var marcaj_mesaj := "mesaj_mom_tata"
@export var marcaj_gata := "vrea_la_sala"
@export var sarcina_lupta := "Defeat the Wizard."
@export var sarcina_dupa := "Go to the gym."

@export_group("Replici")
@export_multiline var replici_intro: PackedStringArray = ["Wizard: You killed our leader!",
	"Wizard: Now the Head Witch is going to kill everyone!", "You: You're a little late buddy.",
	"You: I also killed the Head Witch last night.", "Wizard: Nonsense, this is another one of your lies!",
	"Wizard: Prepare to die!", "You: It's not that deep lil bro.."]
@export_multiline var replici_final: PackedStringArray = ["You: Everyone in this town is a little retarded, it's ok.",
	"Wizard: You really defeated the Head Witch..", "You: Wow, you're really slow."]
@export var contact := "Mom"
@export var ora := "10:52"
@export_multiline var mesaje_mom: PackedStringArray = ["Mom: Your father is in town.",
	"You: You never talk about that retard, who is he anyway?", "Mom: I never wanted you to find out like this..",
	"Mom: He's a vampire.", "Mom: He wants to turn you into a vampire as well.", "You: ok??",
	"Mom: Just go into hiding for a bit, I will confront him.", "You: bitch idgaf, do wtv u want ig"]
@export_multiline var replici_sala: PackedStringArray = ["You: This family is so retarded, I'm going to the gym to relax a bit."]
## Cât după ce a dispărut vine mesajul (owner: 3 s).
@export var intarziere_mesaj := 3.0

@export_group("Locuri")
## Unde ieși din bloc (ca ZiBloc.loc_iesire) și unde apare el (pe alee, în fața ta).
@export var loc_iesire := Vector3(0.0, 0.1, 2.9)
@export var loc_aparitie := Vector3(0.5, 0.0, 9.5)

const SUNET_MUZICA := preload("res://sunete/muzica_lupta_warlock.ogg")
const SUNET_DURERE := preload("res://sunete/warlock_durere.ogg")
const SUNET_RAS := preload("res://sunete/warlock_ras.ogg")
const SUNET_STINGER := preload("res://sunete/stinger_aparitie.ogg")
const SUNET_MOARE := preload("res://sunete/warlock_moare.ogg")


func _ready() -> void:
	if _jucator() == null or not _e_ziua_lui() or Stare.e_marcat(marcaj_gata):
		return
	nume_boss = "Wizard"
	culoare = ROSU
	fel_vraja = "foc_rosu"
	inaltime_piept = 1.15
	# curtea: pe iarbă și pe alee, departe de copaci, de bancă și de bătător
	locuri_teleport = PackedVector3Array([loc_aparitie, Vector3(-4.0, 0, 9.0), Vector3(4.8, 0, 9.3),
		Vector3(-7.5, 0, 8.5), Vector3(8.5, 0, 5.5), Vector3(-3.8, 0, 4.8), Vector3(2.4, 0, 5.4),
		Vector3(-8.0, 0, 12.0), Vector3(7.2, 0, 12.4), Vector3(-0.8, 0, 12.6)])
	_pregateste(SUNET_MUZICA)
	sunet_durere = SUNET_DURERE
	sunet_ras = SUNET_RAS
	var intro := not Stare.e_marcat(marcaj_aparut)
	if intro:
		# direct cum ieși pe scară: nu te mai miști până vorbește el
		_hud(false)
		_jucator().seteaza_purtat(true)
	# ZiBloc te pune la ușa blocului abia după un cadru (și abia atunci scena e `current_scene`, pentru Cutscena)
	await get_tree().process_frame
	await get_tree().process_frame
	var c: Cutscena = Cutscena.porneste(self) if intro else null
	while Tranzitie.activa:
		await get_tree().process_frame
	if intro:
		await _intro(c)
	elif Stare.e_marcat(marcaj_disparut):
		if Stare.e_marcat(marcaj_mesaj):
			await get_tree().create_timer(1.0, false).timeout
			await _replica_sala()
		else:
			await _mesajul()
	elif Stare.e_marcat(marcaj_invins):
		_blocheaza(true)
		_fa_vrajitor(loc_aparitie)
		_boss.prabusire(0.01)
		_pune_jucatorul(loc_aparitie + Vector3(0.0, 0.0, -4.5), loc_aparitie)
		await get_tree().create_timer(0.6, false).timeout
		await _finalul(false)
	else:
		_blocheaza(true)
		_pune_jucatorul(loc_iesire, loc_aparitie)
		_fa_vrajitor(loc_aparitie)
		Stare.seteaza_sarcina(sarcina_lupta)
		await get_tree().create_timer(1.0, false).timeout
		_porneste_lupta()


## Dimineața (oricare) de după final, după ce ai vorbit cu Mom de tutore.
func _e_ziua_lui() -> bool:
	return Stare.e_marcat(marcaj_final) and int(Stare.valoare_marcaj(marcaj_somn_final, 0)) >= 1 \
		and Stare.e_marcat(marcaj_mom)


func _fa_vrajitor(poz: Vector3) -> void:
	_fa_boss(VrajitorBoss.new(), poz, 0.45, 1.9, 1.05)
	_boss.plutire = 0.0


## Orarul și ușa blocului: nu merg cât e el în curte.
func _blocheaza(da: bool) -> void:
	for n in blocate_in_lupta:
		if is_instance_valid(n):
			n.activ = not da


# ---------------------------------------------------------------------------------------------------------------
# 1. Intro
# ---------------------------------------------------------------------------------------------------------------

func _intro(c: Cutscena) -> void:
	var j := _jucator()
	Stare.seteaza_sarcina("")
	_blocheaza(true)
	_pune_jucatorul(loc_iesire, loc_aparitie)
	await get_tree().create_timer(0.5, false).timeout
	# fulger roșu pe alee: apare el
	_fa_vrajitor(loc_aparitie)
	_boss.furie = 0.8
	ModelPS2.disparitie(_boss._model, 1.0)
	Stare.marcheaza(marcaj_aparut)
	var cer := loc_aparitie + Vector3(randf_range(-4, 4), 40, randf_range(-3, 3))
	Fulger.loveste(self, cer, loc_aparitie, ROSU, 0.3, true, 1.4)
	VrajaAtac.sunet_la(self, SUNET_TELEPORT, loc_aparitie + Vector3.UP, Sunet.VOLUM_EFECTE + 2.0, 18.0)
	Sunet.reda(SUNET_STINGER, Sunet.VOLUM_EFECTE - 2.0)
	_lumina_scurta(loc_aparitie + Vector3.UP * 2.0, ROSU, 12.0, 22.0, 1.0)
	_fum(loc_aparitie + Vector3.UP * 0.8, 36)
	Zguduire.porneste(_camera_jucator, 0.025, 0.45)
	await c.priveste(_piept_boss(), 0.45)
	_boss.aparitie(1.0)
	_boss.priveste((j.get_node("Cap") as Node3D).global_position)
	_muzica.volume_db = Sunet.VOLUM_MUZICA
	_muzica.play()
	await get_tree().create_timer(1.3, false).timeout
	Dialog.spune(replici_intro)
	if Dialog.activ:
		await Dialog.terminat
	# își aprinde mingea de foc în palmă și începe
	_boss.ridica_mana(-0.6, 0.4, 0.0)
	_lumina_scurta(_boss.palma(), ROSU, 5.0, 6.0, 0.6)
	await get_tree().create_timer(0.5, false).timeout
	_boss.ridica_mana(0.0, 0.4, 0.0)
	Stare.seteaza_sarcina(sarcina_lupta)
	j.seteaza_purtat(false)
	_hud(true)
	await c.opreste()
	_porneste_lupta()


# ---------------------------------------------------------------------------------------------------------------
# 2. Lupta: doar mingi de foc roșii
# ---------------------------------------------------------------------------------------------------------------

func _lupta() -> void:
	var r := _runda
	var salve := 0
	if not await _asteapta(1.0):
		return
	while r == _runda and _lupta_activa:
		if _faza_doi_ceruta and not _faza_doi:
			# sub jumătate: se înfurie, trage mai des (tot doar mingi de foc)
			_faza_doi = true
			create_tween().tween_property(_boss, "furie", 1.0, 1.0)
			_rade()
		await _salva()
		if r != _runda:
			return
		salve += 1
		if salve >= (2 if _faza_doi else 3) or randf() < 0.2:
			await _teleport()
			salve = 0
		if r != _runda:
			return
		if not await _asteapta(randf_range(0.8, 1.3) if _faza_doi else randf_range(1.3, 2.0)):
			return


## Pe negru, după „YOU DIED”: tu la ușa blocului, el pe alee.
func _reia_lupta() -> void:
	_boss.global_position = loc_aparitie
	_boss.furie = 0.5
	_boss.ridica_mana(0.0, 0.01, 0.0)
	ModelPS2.disparitie(_boss._model, 0.0)
	_pune_jucatorul(loc_iesire, loc_aparitie)


# ---------------------------------------------------------------------------------------------------------------
# 3. Finalul: rămâne jos, replicile, se destramă spre cer
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
		VrajaAtac.sunet_la(self, SUNET_MOARE, _piept_boss(), Sunet.VOLUM_EFECTE, 14.0, 0.1)
		await c.priveste(_piept_boss(), 0.5)
		# cade jos (plan din lateral)
		var w := _boss.global_position
		var spre_tine := (j.global_position - w) * Vector3(1, 0, 1)
		spre_tine = spre_tine.normalized() if spre_tine.length() > 0.1 else Vector3.BACK
		var latura := spre_tine.cross(Vector3.UP)
		_film(w + spre_tine * 4.6 + latura * 2.4 + Vector3.UP * 1.2, w + Vector3.UP * 0.9, 50.0,
			w + spre_tine * 3.9 + latura * 2.0 + Vector3.UP * 1.0, 4.0, _boss, 0.8)
		await _boss.prabusire(1.2).finished
		VrajaAtac.sunet_la(self, SUNET_CAZI, _boss.global_position, Sunet.VOLUM_EFECTE + 2.0, 10.0)
		_praf(_boss.global_position)
		Sunet.reda(SUNET_DOBORAT, Sunet.VOLUM_EFECTE)
		_bara.ascunde(0.6)
		await _bara.mesaj("WIZARD DEFEATED", BaraBoss.AURIU, 2.4)
		_muzica.stop()
		_camera_jucator.make_current()
	# te duci la el (cât să nu-l calci) și te uiți în jos, la el
	var w2 := _boss.global_position
	var de_la_el := (j.global_position - w2) * Vector3(1, 0, 1)
	de_la_el = de_la_el.normalized() if de_la_el.length() > 0.1 else Vector3.BACK
	var langa := w2 + de_la_el * 2.2
	langa.y = j.global_position.y
	if j.global_position.distance_to(langa) > 0.3:
		c.priveste(_boss.global_position + Vector3.UP * 0.9, 0.5)
		var mers := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		mers.tween_property(j, "global_position", langa, clampf(j.global_position.distance_to(langa) / 2.5, 0.6, 3.0))
		await mers.finished
	await c.priveste(_boss.global_position + Vector3.UP * 0.9, 0.5)
	_boss.priveste(cap.global_position)
	await get_tree().create_timer(0.4, false).timeout
	Dialog.spune(replici_final)
	if Dialog.activ:
		await Dialog.terminat
	await get_tree().create_timer(0.6, false).timeout
	# se destramă: particule roșii care urcă spre cer; te uiți după ele
	VrajaAtac.sunet_la(self, SUNET_ABSORBTIE, _piept_boss(), Sunet.VOLUM_EFECTE - 2.0, 12.0, 0.0)
	_forma_tinta.set_deferred("disabled", true)
	var sus := _boss.global_position + Vector3.UP * 9.0
	var dispare: Tween = (_boss as VrajitorBoss).destramare(3.0)
	await get_tree().create_timer(1.2, false).timeout
	c.priveste(sus, 2.6)
	# (destrămarea ține 3 s: se termină înaintea privirii, de aceea nu aștept privirea întâi)
	await dispare.finished
	await get_tree().create_timer(1.6, false).timeout
	# privirea coboară iar, drept înainte (altfel primești controlul uitându-te la cer)
	var inainte := -j.global_basis.z * Vector3(1, 0, 1)
	await c.priveste(cap.global_position + inainte.normalized() * 6.0 - Vector3.UP * 0.3, 1.0)
	Stare.marcheaza(marcaj_disparut)
	await get_tree().create_timer(0.3, false).timeout
	_boss.queue_free()
	j.seteaza_purtat(false)
	_hud(true)
	await c.opreste()
	_blocheaza(false)
	await _mesajul()


# ---------------------------------------------------------------------------------------------------------------
# 4. Mesajul de la Mom și replica de după
# ---------------------------------------------------------------------------------------------------------------

func _mesajul() -> void:
	await get_tree().create_timer(intarziere_mesaj, false).timeout
	# nu în mijlocul unui dialog, al unui meniu sau al unei tranziții
	while Dialog.activ or Stare.meniu_deschis or Tranzitie.activa:
		await get_tree().create_timer(0.3, false).timeout
	if not is_inside_tree():
		return
	await Telefon.conversatie(self, contact, mesaje_mom, ora)
	Stare.marcheaza(marcaj_mesaj)
	await _replica_sala()


func _replica_sala() -> void:
	Dialog.spune(replici_sala)
	if Dialog.activ:
		await Dialog.terminat
	Stare.marcheaza(marcaj_gata)
	Stare.seteaza_sarcina(sarcina_dupa)
