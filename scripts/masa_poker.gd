class_name MasaPoker
extends Interactabil
## Masa de poker din camera de joc a „Casino”-ului (Texas Hold'em, fără limită). Nodul e locul liber de la masă: cu jetoane
## în inventar (Jetoane), „[E] Play poker” → te așezi, iar masa joacă mână după mână cu cei 5 adversari (`jucatori`,
## OmLaMasa), până te ridici („Leave table”, între mâini) sau rămâi fără jetoane.
## Regulile sunt cele normale: dealer-ul se mută, blind-urile (`small_blind`, `big_blind`), câte două cărți fiecare,
## pariuri înainte de flop, flop (3 cărți), turn, river, apoi arătatul cărților; pot-uri laterale când cineva e all-in.
## Singura „magie” (cerută de owner): când ajungi la arătat, câștigi cu `sansa_castig` (75%). Înainte de împărțire jocul
## alege dacă mâna asta o câștigi și amestecă pachetul până iese așa (cărțile tuturor și ale mesei sunt hotărâte de la
## început). Când pierzi, adversarul care te bate nu renunță pe drum.
## Banii mesei sunt în cenți; ai tăi sunt `Jetoane.suma()` (se salvează după fiecare mână).
## Cărțile 3D și jetoanele 3D se fac din cod; textul de pe ecran (HUD) tot.

signal _ales(tip: String, suma: int)

## Adversarii, în ordinea locurilor (în sensul acelor de ceas, începând din stânga ta).
@export var jucatori: Array[OmLaMasa] = []
## Câte un punct pe postav în fața fiecărui loc (0 = al tău), cu -Z spre mijlocul mesei.
@export var locuri: Array[Marker3D] = []
## Mijlocul mesei (pot-ul și cărțile comune).
@export var centru: Marker3D
## Unde stai (tălpile) cât joci; privirea se uită spre `centru`.
@export var loc_jucator: Marker3D
## Înălțimea ochilor cât stai jos.
@export var ochi_sezut := 1.12
## Cât de departe de loc (dinspre masă) te ridici: dincolo de cutia scaunului gol (LocLiber, 0,56 m) plus capsula ta (0,3 m).
@export var departare_ridicat := 0.75
@export var nume_jucatori: PackedStringArray = ["Big Sal", "Slick Tony", "Old Ass", "Trophy Wife", "Asshole"]
## Jetoanele adversarilor la început (cenți).
@export var bani_jucatori: PackedInt32Array = [34200, 14700, 22200, 18900, 9700]
@export var small_blind := 10
@export var big_blind := 20
@export_range(0.0, 1.0) var sansa_castig := 0.75

@export_group("Sunete")
@export var sunet_amestecat: AudioStream = preload("res://sunete/carti_amestecate.ogg")
@export var sunet_carte: AudioStream = preload("res://sunete/carte_impartita.ogg")
@export var sunet_intoarsa: AudioStream = preload("res://sunete/carte_intoarsa.ogg")
@export var sunet_jetoane: AudioStream = preload("res://sunete/jetoane_puse.ogg")
@export var sunet_strange: AudioStream = preload("res://sunete/jetoane_stranse.ogg")
@export var sunet_check: AudioStream = preload("res://sunete/bataie_masa.ogg")
@export var sunet_castig: AudioStream = preload("res://sunete/poker_castig.ogg")
@export var sunet_pierdere: AudioStream = preload("res://sunete/poker_pierdere.ogg")
@export var sunet_scaun: AudioStream = preload("res://sunete/canapea_asezat.ogg")

const SUNET_RIG := preload("res://sunete/vraja_unda.ogg")
const SUNET_RIG_SCANTEI := preload("res://sunete/scantei_matura.ogg")
const SUNET_RIG_SCHIMB := preload("res://sunete/vraja_bum.ogg")
const MARIME_CARTE := Vector2(0.075, 0.107)
## Jetoanele: valoarea (cenți) și culoarea, de la cea mai mare.
const VALORI_JETOANE := [[5000, "262d2f"], [1000, "655269"], [500, "7b383a"], [100, "83b3b0"], [25, "30716f"], [5, "a18463"]]
const GROSIME_JETON := 0.0045
const RAZA_JETON := 0.019

enum { NIMIC, PREFLOP, FLOP, TURN, RIVER }

var _asezat := false
var _jucator: CharacterBody3D
var _cap: Node3D
var _camera: Camera3D
var _inaltime_ochi := 1.55

# starea mesei (index 0 = tu)
var _bani: Array[int] = []
var _pariu: Array[int] = []      # cât a pus fiecare în runda asta
var _total: Array[int] = []      # cât a pus în toată mâna
var _renuntat: Array[bool] = []
var _all_in: Array[bool] = []
var _mana: Array = []            # cărțile fiecăruia ([a, b])
var _comune: Array[int] = []     # cele 5 cărți ale mesei (hotărâte de la început)
var _aratate := 0                # câte din ele sunt pe masă
var _dealer := 0
var _pariu_curent := 0
var _ultima_marire := 0
var _favorit := -1               # adversarul care te bate la arătat (când pierzi mâna asta)
var _faza := NIMIC
var _vrea_sa_plece := false
var _carti_impartite := false

# 3D
var _carti_3d: Array = []        # câte un Array de noduri pentru fiecare loc
var _comune_3d: Array[Node3D] = []
var _teancuri_pariu: Array[Node3D] = []
var _teancuri_bani: Array[Node3D] = []
var _teanc_pot: Node3D
var _buton_dealer: Node3D
var _materiale := {}

# HUD
var _hud: CanvasLayer
var _eticheta_pot: Label
var _eticheta_mesaj: Label
var _eticheta_bani: Label
var _eticheta_mana: Label
var _carti_hud: Array[TextureRect] = []
var _comune_hud: Array[TextureRect] = []
## Tot ce apare când e rândul tău: `_rand_marire` (Min / 1/2 Pot / Pot + slider-ul sumei) deasupra lui `_butoane`.
var _panou_tu: VBoxContainer
var _rand_marire: HBoxContainer
var _b_rapide: Array[Button] = []
## Slider-ul sumei: 0..PASI_GLISOR, pătratic (stânga = sume mici, precise; spre dreapta urcă repede până la all in).
var _glisor_marire: HSlider
const PASI_GLISOR := 200.0
## Cât timp codul mută slider-ul (după +/- sau Min/Pot), `_glisor_mutat` nu rescrie suma.
var _glisor_din_cod := false
var _butoane: HBoxContainer
var _b_fold: Button
var _b_call: Button
var _b_minus: Button
var _b_raise: Button
var _b_plus: Button
var _b_allin: Button
## „Rig cards”: doar la river, când e rândul tău, o dată pe mână (vezi `_rig`).
var _b_rig: Button
var _rig_folosit := false
var _intre_maini: HBoxContainer
var _etichete_jucatori: Array[Label] = []
var _suma_marire := 0


func _ready() -> void:
	indiciu = "[E] Play poker"
	_bani.resize(6)
	for i in 5:
		_bani[i + 1] = bani_jucatori[i] if i < bani_jucatori.size() else 3000
	await get_tree().process_frame
	_jucator = get_tree().get_first_node_in_group("jucator") as CharacterBody3D
	if _jucator:
		_cap = _jucator.get_node("Cap")
		_camera = _cap.get_node("Camera3D")
	_pregateste_3d()
	# hitbox-urile adversarilor (te oprești în ei, gloanțele îi nimeresc și tresar)
	for j in jucatori:
		TintaOm.adauga(j)
	# adversarii se uită unii la alții, la masă și la tine
	for j in jucatori:
		j.puncte_privire.append(centru.global_position)
		for alt in jucatori:
			if alt != j:
				j.puncte_privire.append(alt.global_position + Vector3.UP * 1.2)
	_actualizeaza_teancuri()


func poate_fi_folosit() -> bool:
	return not _asezat and Jetoane.suma() > 0 and _jucator != null


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	folosit.emit()
	await _aseaza_te()
	await _joaca()
	await _ridica_te()


# ---------------------------------------------------------------- așezat / ridicat

func _aseaza_te() -> void:
	_asezat = true
	_vrea_sa_plece = false
	Stare.meniu_deschis = true
	_jucator.seteaza_purtat(true)
	_inaltime_ochi = _cap.position.y
	var c := Cutscena.porneste(self)
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_jucator, "global_position", loc_jucator.global_position, 0.8)
	t.tween_property(_cap, "position:y", ochi_sezut, 0.8)
	c.priveste(centru.global_position + Vector3.DOWN * 0.05, 0.8)
	await t.finished
	Sunet.reda_la(sunet_scaun, loc_jucator.global_position, Sunet.VOLUM_EFECTE, 0.05)
	await c.priveste(centru.global_position + Vector3.DOWN * 0.05, 0.1)
	c.queue_free()
	Stare.meniu_deschis = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for j in jucatori:
		j.privire = null
	_bani[0] = Jetoane.suma()
	_fa_hud()
	_actualizeaza_teancuri()


func _ridica_te() -> void:
	_hud.queue_free()
	_hud = null
	_etichete_jucatori.clear()
	_carti_hud.clear()
	_comune_hud.clear()
	Jetoane.seteaza(_bani[0])
	_bani[0] = 0
	_actualizeaza_teancuri()
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# te ridici înapoi, dinspre masă, până în spatele scaunului (cutia lui de coliziune + capsula ta), ca să nu rămâi
	# prins în scaun sau în masă când coliziunea ta revine
	var dinspre_masa := loc_jucator.global_position - centru.global_position
	dinspre_masa.y = 0.0
	var inapoi := loc_jucator.global_position + dinspre_masa.normalized() * departare_ridicat
	t.tween_property(_jucator, "global_position", inapoi, 0.7)
	t.tween_property(_cap, "position:y", _inaltime_ochi, 0.7)
	t.tween_property(_cap, "rotation:x", 0.0, 0.7)
	await t.finished
	_jucator.seteaza_purtat(false)
	Stare.meniu_deschis = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_asezat = false


func _input(event: InputEvent) -> void:
	if not _asezat or _hud == null:
		return
	if event.is_action_pressed("ui_cancel") and _intre_maini.visible:
		get_viewport().set_input_as_handled()
		_pleaca()


# ---------------------------------------------------------------- jocul

func _joaca() -> void:
	_dealer = randi() % 6
	_mesaj("Welcome to the table.")
	await _asteapta(1.0)
	while true:
		await _o_mana()
		Jetoane.seteaza(_bani[0])
		if _bani[0] <= 0:
			_mesaj("You're out of chips.")
			await _asteapta(2.5)
			return
		# între mâini: „Next hand” (sau singur, după câteva secunde) / „Leave table”
		_intre_maini.show()
		var t := 0.0
		while t < 4.0 and not _vrea_sa_plece and _intre_maini.visible:
			await get_tree().process_frame
			t += get_process_delta_time()
		_intre_maini.hide()
		if _vrea_sa_plece:
			return
		await _strange_cartile()


func _pleaca() -> void:
	_vrea_sa_plece = true


func _urmatoarea_mana() -> void:
	_intre_maini.hide()


func _o_mana() -> void:
	# adversarii fără bani mai scot un teanc din buzunar
	for i in range(1, 6):
		if _bani[i] <= 0:
			_bani[i] = randi_range(15, 50) * 100
			_mesaj("%s buys more chips." % _nume(i))
			await _asteapta(0.9)
	_pariu = [0, 0, 0, 0, 0, 0]
	_total = [0, 0, 0, 0, 0, 0]
	_renuntat = [false, false, false, false, false, false]
	_all_in = [false, false, false, false, false, false]
	_aratate = 0
	_rig_folosit = false
	_faza = PREFLOP
	_dealer = _urmatorul_cu_bani(_dealer)
	_muta_butonul()
	_imparte_hotarat()
	_actualizeaza_hud()
	# blind-urile
	var sb := _urmatorul_cu_bani(_dealer)
	var bb := _urmatorul_cu_bani(sb)
	await _pune(sb, mini(small_blind, _bani[sb]))
	await _pune(bb, mini(big_blind, _bani[bb]))
	_pariu_curent = big_blind
	_ultima_marire = big_blind
	_mesaj("Blinds %s / %s" % [Jetoane.bani(small_blind), Jetoane.bani(big_blind)])
	# împărțitul: câte o carte, de două ori, începând din stânga dealer-ului
	Sunet.reda_la(sunet_amestecat, centru.global_position, Sunet.VOLUM_EFECTE, 0.05)
	await _asteapta(0.8)
	for runda in 2:
		var i := _urmatorul_cu_bani(_dealer)
		for k in 6:
			await _da_carte(i, runda)
			i = _urmatorul_cu_bani(i)
			if i == _urmatorul_cu_bani(_dealer):
				break
	_carti_impartite = true
	_actualizeaza_hud()
	# rundele de pariuri
	if not await _runda(_urmatorul_cu_bani(bb)):
		await _final()
		return
	for faza in [FLOP, TURN, RIVER]:
		_faza = faza
		await _aduna_pariurile()
		var cate := 3 if faza == FLOP else 1
		for k in cate:
			await _intoarce_comuna(_aratate)
			_aratate += 1
		_actualizeaza_hud()
		_mesaj(["", "", "The flop.", "The turn.", "The river."][faza])
		if _pot_actiona() >= 2:
			_pariu_curent = 0
			_ultima_marire = big_blind
			if not await _runda(_urmatorul_activ(_dealer)):
				break
		await _asteapta(0.4)
	await _final()


## Alege cărțile mâinii: cu `sansa_castig` câștigi la arătat (cea mai bună mână), altfel te bate cineva.
func _imparte_hotarat() -> void:
	var castigi := randf() < sansa_castig
	var pachet: Array = []
	for c in 52:
		pachet.append(c)
	_favorit = -1
	for incercare in 400:
		pachet.shuffle()
		_mana = []
		for i in 6:
			_mana.append([pachet[i * 2], pachet[i * 2 + 1]] if _bani[i] > 0 else [])
		_comune.clear()
		for k in 5:
			_comune.append(pachet[12 + k])
		var al_tau := _scor(0)
		var cel_mai_bun := -1
		var cine := -1
		for i in range(1, 6):
			if _mana[i].is_empty():
				continue
			var s := _scor(i)
			if s > cel_mai_bun:
				cel_mai_bun = s
				cine = i
		if castigi and al_tau > cel_mai_bun:
			return
		if not castigi and cel_mai_bun > al_tau:
			_favorit = cine
			return


func _scor(i: int) -> int:
	var toate: Array = (_mana[i] as Array).duplicate()
	toate.append_array(_comune)
	return ManaPoker.scor(toate)


## O rundă de pariuri, începând cu locul `start`. Întoarce false dacă a rămas un singur jucător.
func _runda(start: int) -> bool:
	var a_actionat := [false, false, false, false, false, false]
	var i := start
	var pasi := 0
	while pasi < 200:
		pasi += 1
		if _ramasi() <= 1:
			return false
		var gata := true
		for k in 6:
			if _in_mana(k) and not _all_in[k] and (not a_actionat[k] or _pariu[k] < _pariu_curent):
				gata = false
		if gata:
			return true
		# un singur jucător mai poate pune bani (ceilalți sunt all-in) și a dat cât trebuie: n-are cu cine să parieze
		if _pot_actiona() <= 1:
			var nimeni := true
			for k in 6:
				if _in_mana(k) and not _all_in[k] and _pariu[k] < _pariu_curent:
					nimeni = false
			if nimeni:
				return true
		if _in_mana(i) and not _all_in[i] and not (a_actionat[i] and _pariu[i] >= _pariu_curent):
			var inainte := _pariu_curent
			await _actioneaza(i)
			a_actionat[i] = true
			if _pariu_curent > inainte:
				for k in 6:
					if k != i:
						a_actionat[k] = false
		i = (i + 1) % 6
	return true


func _actioneaza(i: int) -> void:
	_evidentiaza(i)
	var de_dat := _pariu_curent - _pariu[i]
	var tip := ""
	var suma := 0
	if i == 0:
		var r: Array = await _alege_tu(de_dat)
		tip = r[0]
		suma = r[1]
	else:
		await _asteapta(randf_range(0.35, 0.9))
		var r := _decide_ai(i, de_dat)
		tip = r[0]
		suma = r[1]
	match tip:
		"fold":
			_renuntat[i] = true
			_mesaj("%s %s." % [_nume(i), _verb(i, "fold", "folds")])
			await _arunca_cartile(i)
		"check":
			_mesaj("%s %s." % [_nume(i), _verb(i, "check", "checks")])
			Sunet.reda_la(sunet_check, locuri[i].global_position, Sunet.VOLUM_EFECTE, 0.1)
			if i > 0:
				jucatori[i - 1].bate_masa()
		"call":
			var cat := mini(de_dat, _bani[i])
			await _pune(i, cat)
			_mesaj("%s %s." % [_nume(i), _verb(i, "go all in", "goes all in") if _all_in[i] else _verb(i, "call", "calls")])
		"raise":
			# `suma` = până la cât crește pariul în runda asta
			var pana_la := mini(suma, _pariu[i] + _bani[i])
			var marire := pana_la - _pariu_curent
			if marire >= _ultima_marire:
				_ultima_marire = marire
			_pariu_curent = maxi(_pariu_curent, pana_la)
			await _pune(i, pana_la - _pariu[i])
			if _all_in[i]:
				_mesaj("%s %s!" % [_nume(i), _verb(i, "go all in", "goes all in")])
			else:
				_mesaj("%s %s to %s." % [_nume(i), _verb(i, "raise", "raises"), Jetoane.bani(pana_la)])
	_evidentiaza(-1)
	_actualizeaza_hud()


## Ce face un adversar: [tip, suma]. Ține cont de cât de bună e mâna, cât trebuie să dea și un pic de noroc (bluf).
func _decide_ai(i: int, de_dat: int) -> Array:
	var masa: Array = _comune.slice(0, _aratate)
	var p := ManaPoker.putere(_mana[i], masa)
	var favorit := i == _favorit
	if favorit:
		p = maxf(p, 0.68)
	# când mâna e a ta, adversarii te plătesc mai des (mai rar renunță), ca un câștig să valoreze ceva;
	# cel care te bate măsoară mai cu grijă cât mărește
	var pe_tine := _favorit < 0
	var pot := _pot_total()
	var r := randf()
	var marire_min := _pariu_curent + maxi(_ultima_marire, big_blind)
	var marime := randf_range(0.35, 0.6) if favorit else randf_range(0.45, 0.9)
	var marire := _pariu_curent + maxi(maxi(_ultima_marire, big_blind), _rotunjeste(int(pot * marime)))
	if de_dat <= 0:
		var sansa_marire := 0.35 if favorit else 0.55
		if (p > 0.62 and r < sansa_marire) or r < 0.06:
			return ["raise", maxi(marire, marire_min)]
		return ["check", 0]
	var cota := float(de_dat) / float(pot + de_dat)
	var prag := cota + (0.02 if pe_tine else 0.12)
	if not favorit and p < prag and r > (0.3 if pe_tine else 0.07):
		return ["fold", 0]
	if p > 0.78 and r < (0.25 if favorit else 0.4) and _pariu_curent < big_blind * 30:
		return ["raise", maxi(marire, marire_min)]
	return ["call", de_dat]


func _rotunjeste(c: int) -> int:
	return maxi(5, int(round(c / 5.0)) * 5)


## Tu: butoanele de jos. Întoarce [tip, suma].
func _alege_tu(de_dat: int) -> Array:
	_b_fold.disabled = false
	_b_call.text = "Check" if de_dat <= 0 else "Call %s" % Jetoane.bani(mini(de_dat, _bani[0]))
	var maxim := _pariu[0] + _bani[0]
	var minim := mini(_pariu_curent + maxi(_ultima_marire, big_blind), maxim)
	_suma_marire = minim
	var poate_mari := maxim > _pariu_curent and _bani[0] > de_dat
	_b_raise.disabled = not poate_mari
	_b_minus.disabled = not poate_mari
	_b_plus.disabled = not poate_mari
	_b_allin.disabled = _bani[0] <= 0
	# slider-ul are rost doar dacă ai între ce alege (altfel minimul e chiar all in)
	_rand_marire.visible = poate_mari and maxim > minim
	_actualizeaza_marire()
	var r: Array = []
	while true:
		_b_rig.visible = _faza == RIVER and not _rig_folosit
		_panou_tu.show()
		_mesaj("Your turn." if de_dat <= 0 else "Your turn. %s to call." % Jetoane.bani(mini(de_dat, _bani[0])))
		r = await _ales
		_panou_tu.hide()
		if r[0] != "rig":
			break
		# magia, apoi tot rândul tău (cu mâna nouă)
		await _rig()
		await _asteapta(0.6)
	match r[0]:
		"call":
			return ["check", 0] if de_dat <= 0 else ["call", de_dat]
		"raise":
			return ["raise", clampi(_suma_marire, minim, maxim)]
		"allin":
			if maxim <= _pariu_curent:
				return ["call", de_dat]
			return ["raise", maxim]
	return ["fold", 0]


func _apasat(tip: String) -> void:
	_ales.emit(tip, _suma_marire)


## Cât poți mări cel puțin / cel mult acum (sumele sunt „până la”, ca pe butonul Raise).
func _limite_marire() -> Vector2i:
	var maxim := _pariu[0] + _bani[0]
	return Vector2i(mini(_pariu_curent + maxi(_ultima_marire, big_blind), maxim), maxim)


func _schimba_marirea(semn: int) -> void:
	var l := _limite_marire()
	var pas := big_blind if _suma_marire < big_blind * 10 else big_blind * 5
	_suma_marire = clampi(_suma_marire + semn * pas, l.x, l.y)
	_actualizeaza_marire()


## Min / 1/2 Pot / Pot: mărirea de mărimea pot-ului după ce plătești (regula obișnuită: call + pot).
func _marire_rapida(parte: float) -> void:
	var l := _limite_marire()
	if parte <= 0.0:
		_suma_marire = l.x
	else:
		var de_dat := _pariu_curent - _pariu[0]
		var suma := _pariu_curent + _rotunjeste(int((_pot_total() + de_dat) * parte))
		_suma_marire = clampi(suma, l.x, l.y)
	_actualizeaza_marire()


## Slider-ul: pătratic între minim și all in, rotunjit la big blind (capătul din dreapta = exact tot ce ai).
func _glisor_mutat(valoare: float) -> void:
	if _glisor_din_cod:
		return
	var l := _limite_marire()
	var t := valoare / PASI_GLISOR
	if t >= 1.0:
		_suma_marire = l.y
	else:
		var suma := l.x + int((l.y - l.x) * t * t)
		_suma_marire = clampi(int(round(float(suma) / big_blind)) * big_blind, l.x, l.y)
	_actualizeaza_marire(false)


func _actualizeaza_marire(muta_glisorul := true) -> void:
	var l := _limite_marire()
	_b_raise.text = ("All in %s" if _suma_marire >= l.y else "Raise to %s") % Jetoane.bani(_suma_marire)
	if muta_glisorul and _glisor_marire and l.y > l.x:
		_glisor_din_cod = true
		_glisor_marire.value = sqrt(clampf(float(_suma_marire - l.x) / (l.y - l.x), 0.0, 1.0)) * PASI_GLISOR
		_glisor_din_cod = false


## Sfârșitul mâinii: arătatul cărților (dacă au rămas mai mulți) și împărțirea pot-urilor.
func _final() -> void:
	await _aduna_pariurile()
	_faza = NIMIC
	var ramasi: Array[int] = []
	for i in 6:
		if _in_mana(i):
			ramasi.append(i)
	if ramasi.size() == 1:
		var cine := ramasi[0]
		var castig := _pot_total()
		_mesaj("%s %s %s." % [_nume(cine), "win" if cine == 0 else "wins", Jetoane.bani(castig)])
		await _plateste({cine: castig})
		return
	# cărțile mesei care n-au apucat să iasă (all-in înainte de river)
	while _aratate < 5:
		await _intoarce_comuna(_aratate)
		_aratate += 1
		await _asteapta(0.35)
	_actualizeaza_hud()
	# arătatul: adversarii rămași își întorc cărțile
	for i in ramasi:
		if i != 0:
			for nod: Node3D in _carti_3d[i]:
				_intoarce(nod, true)
			Sunet.reda_la(sunet_intoarsa, locuri[i].global_position, Sunet.VOLUM_EFECTE, 0.1)
			_eticheta_mana_jucator(i, ManaPoker.nume(_scor(i)))
			await _asteapta(0.45)
	await _asteapta(0.6)
	# pot-urile (cu cele laterale): pe straturi, după cât a pus fiecare
	var castiguri := {}
	var niveluri: Array[int] = []
	for i in 6:
		if _total[i] > 0 and not niveluri.has(_total[i]):
			niveluri.append(_total[i])
	niveluri.sort()
	var jos := 0
	for nivel in niveluri:
		var bucata := 0
		for i in 6:
			bucata += clampi(_total[i] - jos, 0, nivel - jos)
		var eligibili: Array[int] = []
		for i in ramasi:
			if _total[i] >= nivel:
				eligibili.append(i)
		if eligibili.is_empty():
			eligibili = ramasi.duplicate()
		var maxim := -1
		var castigatori: Array[int] = []
		for i in eligibili:
			var s := _scor(i)
			if s > maxim:
				maxim = s
				castigatori = [i]
			elif s == maxim:
				castigatori.append(i)
		var parte := bucata / castigatori.size()
		for k in castigatori.size():
			var c := castigatori[k]
			castiguri[c] = int(castiguri.get(c, 0)) + parte + (bucata - parte * castigatori.size() if k == 0 else 0)
		jos = nivel
	# mesajul: cine a luat cel mai mult
	var principal := -1
	for c: int in castiguri:
		if principal < 0 or castiguri[c] > castiguri[principal]:
			principal = c
	var mana_castigatoare := ManaPoker.nume(_scor(principal))
	if principal == 0:
		_mesaj("You win %s with %s!" % [Jetoane.bani(castiguri[0]), mana_castigatoare])
	else:
		_mesaj("%s wins %s with %s." % [_nume(principal), Jetoane.bani(castiguri[principal]), mana_castigatoare])
	await _plateste(castiguri)


func _plateste(castiguri: Dictionary) -> void:
	var ai_castigat := castiguri.has(0)
	Sunet.reda(sunet_castig if ai_castigat else sunet_pierdere, Sunet.VOLUM_EFECTE - 2.0, 0.0, &"Interfata")
	# teancul din mijloc alunecă spre câștigător
	for c: int in castiguri:
		var teanc := _teanc(castiguri[c])
		add_child(teanc)
		teanc.global_position = centru.global_position
		var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(teanc, "global_position", locuri[c].global_position + locuri[c].global_basis.z * 0.05, 0.7)
		t.tween_callback(teanc.queue_free)
		_bani[c] += castiguri[c]
	_total = [0, 0, 0, 0, 0, 0]
	_pariu = [0, 0, 0, 0, 0, 0]
	_seteaza_pot_3d(0)
	Sunet.reda_la(sunet_strange, centru.global_position, Sunet.VOLUM_EFECTE, 0.05)
	await _asteapta(0.75)
	_actualizeaza_teancuri()
	_actualizeaza_hud()
	if ai_castigat:
		for j in jucatori:
			j.priveste_punct = _cap.global_position
		await _asteapta(1.2)
		for j in jucatori:
			j.priveste_punct = Vector3.INF


# ---------------------------------------------------------------- ajutătoare pentru reguli

func _in_mana(i: int) -> bool:
	return not _renuntat[i] and not (_mana[i] as Array).is_empty()


func _ramasi() -> int:
	var n := 0
	for i in 6:
		if _in_mana(i):
			n += 1
	return n


## Câți mai pot pune bani (în joc și nu all-in).
func _pot_actiona() -> int:
	var n := 0
	for i in 6:
		if _in_mana(i) and not _all_in[i]:
			n += 1
	return n


func _urmatorul_cu_bani(i: int) -> int:
	for k in range(1, 7):
		var j := (i + k) % 6
		if _bani[j] > 0 or (_total.size() == 6 and _total[j] > 0):
			return j
	return i


func _urmatorul_activ(i: int) -> int:
	for k in range(1, 7):
		var j := (i + k) % 6
		if _in_mana(j) and not _all_in[j]:
			return j
	return i


func _pot_total() -> int:
	var s := 0
	for i in 6:
		s += _total[i]
	return s


func _nume(i: int) -> String:
	return "You" if i == 0 else nume_jucatori[i - 1]


## Pune `cat` cenți din banii lui `i` în pariul lui (cu jetoanele care alunecă pe masă).
func _pune(i: int, cat: int) -> void:
	cat = mini(cat, _bani[i])
	if cat <= 0:
		return
	_bani[i] -= cat
	_pariu[i] += cat
	_total[i] += cat
	if _bani[i] <= 0:
		_all_in[i] = true
	if i > 0:
		jucatori[i - 1].gest(_loc_pariu(i))
	var teanc := _teanc(cat)
	add_child(teanc)
	teanc.global_position = locuri[i].global_position + locuri[i].global_basis.x * 0.16
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(teanc, "global_position", _loc_pariu(i), 0.35)
	Sunet.reda_la(sunet_jetoane, _loc_pariu(i), Sunet.VOLUM_EFECTE, 0.1)
	await t.finished
	teanc.queue_free()
	_actualizeaza_teancuri()
	_actualizeaza_hud()


## Pariurile rundei alunecă în pot.
func _aduna_pariurile() -> void:
	var a_fost := false
	for i in 6:
		if _pariu[i] > 0:
			a_fost = true
			var teanc := _teancuri_pariu[i]
			var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			t.tween_property(teanc, "global_position", centru.global_position, 0.4)
	if not a_fost:
		return
	Sunet.reda_la(sunet_strange, centru.global_position, Sunet.VOLUM_EFECTE - 3.0, 0.05)
	await _asteapta(0.45)
	for i in 6:
		_pariu[i] = 0
	_actualizeaza_teancuri()
	_actualizeaza_hud()


func _asteapta(secunde: float) -> void:
	await get_tree().create_timer(secunde).timeout


# ---------------------------------------------------------------- 3D: cărți și jetoane

func _pregateste_3d() -> void:
	_carti_3d.resize(6)
	for i in 6:
		_carti_3d[i] = []
		var p := Node3D.new()
		add_child(p)
		_teancuri_pariu.append(p)
		var b := Node3D.new()
		add_child(b)
		_teancuri_bani.append(b)
	_teanc_pot = Node3D.new()
	add_child(_teanc_pot)
	_buton_dealer = Node3D.new()
	add_child(_buton_dealer)
	var disc := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.03
	m.bottom_radius = 0.03
	m.height = 0.008
	m.radial_segments = 12
	disc.mesh = m
	disc.material_override = _material("83b3b0")
	_buton_dealer.add_child(disc)
	var d := Label3D.new()
	d.text = "D"
	d.font_size = 32
	d.pixel_size = 0.0012
	d.modulate = Color("262d2f")
	d.outline_size = 0
	d.rotation.x = -PI / 2.0
	d.position.y = 0.0045
	d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_buton_dealer.add_child(d)
	_buton_dealer.global_position = locuri[0].global_position + Vector3.UP * 0.004


func _material(hex: String) -> StandardMaterial3D:
	if _materiale.has(hex):
		return _materiale[hex]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(hex)
	mat.roughness = 0.8
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_materiale[hex] = mat
	return mat


func _material_carte(tex: Texture2D) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.9
	return mat


## O carte pe masă: două plăci (fața în sus pe +Y, spatele în jos). Întoarsă = rotită 180° în jurul axei Z a ei.
func _carte_3d(c: int, cu_fata: bool) -> Node3D:
	var n := Node3D.new()
	var fata := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = MARIME_CARTE
	fata.mesh = q
	fata.material_override = _material_carte(Carti.textura(c))
	fata.rotation.x = -PI / 2.0
	fata.position.y = 0.0006
	n.add_child(fata)
	var spate := MeshInstance3D.new()
	spate.mesh = q
	spate.material_override = _material_carte(Carti.spate())
	spate.rotation.x = PI / 2.0
	n.add_child(spate)
	n.set_meta("carte", c)
	if not cu_fata:
		n.rotation.z = PI
	return n


func _intoarce(nod: Node3D, cu_fata: bool) -> void:
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(nod, "position:y", nod.position.y + 0.04, 0.12)
	t.parallel().tween_property(nod, "rotation:z", 0.0 if cu_fata else PI, 0.24)
	t.tween_property(nod, "position:y", nod.position.y, 0.12)


## Împarte o carte locului `i` (din mijlocul mesei, în zbor), a doua oară puțin mai la dreapta.
func _da_carte(i: int, runda: int) -> void:
	var c: int = _mana[i][runda]
	var nod := _carte_3d(c, i == 0)
	add_child(nod)
	nod.global_position = centru.global_position + Vector3.UP * 0.01
	var loc := locuri[i]
	var tinta := loc.global_position + loc.global_basis.x * (-0.045 + runda * 0.09) + Vector3.UP * (0.002 + runda * 0.001)
	var unghi := loc.global_rotation.y + (randf() - 0.5) * 0.15
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(nod, "global_position", tinta, 0.22)
	t.tween_property(nod, "rotation:y", unghi + TAU, 0.22)
	Sunet.reda_la(sunet_carte, tinta, Sunet.VOLUM_EFECTE, 0.15)
	(_carti_3d[i] as Array).append(nod)
	await _asteapta(0.13)


## Pune cartea comună `k` pe masă, cu fața în sus.
func _intoarce_comuna(k: int) -> void:
	var nod := _carte_3d(_comune[k], false)
	add_child(nod)
	nod.global_position = centru.global_position + Vector3.UP * 0.01
	var tinta := centru.global_position + centru.global_basis.x * ((k - 2) * (MARIME_CARTE.x + 0.012)) - centru.global_basis.z * 0.12 + Vector3.UP * 0.002
	nod.rotation.y = centru.global_rotation.y
	var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(nod, "global_position", tinta, 0.2)
	Sunet.reda_la(sunet_carte, tinta, Sunet.VOLUM_EFECTE, 0.15)
	await t.finished
	_intoarce(nod, true)
	Sunet.reda_la(sunet_intoarsa, tinta, Sunet.VOLUM_EFECTE - 2.0, 0.1)
	_comune_3d.append(nod)
	await _asteapta(0.28)


func _arunca_cartile(i: int) -> void:
	for nod: Node3D in _carti_3d[i]:
		var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(nod, "global_position", centru.global_position + centru.global_basis.z * 0.22 + Vector3(randf() - 0.5, 0, randf() - 0.5) * 0.1, 0.3)
		t.tween_callback(nod.queue_free)
	(_carti_3d[i] as Array).clear()
	Sunet.reda_la(sunet_carte, locuri[i].global_position, Sunet.VOLUM_EFECTE - 3.0, 0.15)
	if i > 0:
		jucatori[i - 1].gest(locuri[i].global_position - locuri[i].global_basis.z * 0.1)
	await _asteapta(0.3)


func _strange_cartile() -> void:
	_carti_impartite = false
	for i in 6:
		for nod: Node3D in _carti_3d[i]:
			nod.queue_free()
		(_carti_3d[i] as Array).clear()
	for nod in _comune_3d:
		nod.queue_free()
	_comune_3d.clear()
	for i in range(1, 6):
		_eticheta_mana_jucator(i, "")
	_eticheta_mana.text = ""
	for r in _carti_hud + _comune_hud:
		r.texture = null
	Sunet.reda_la(sunet_amestecat, centru.global_position, Sunet.VOLUM_EFECTE - 4.0, 0.05)
	await _asteapta(0.3)


func _loc_pariu(i: int) -> Vector3:
	return locuri[i].global_position - locuri[i].global_basis.z * 0.26 + Vector3.UP * 0.002


func _muta_butonul() -> void:
	var loc := locuri[_dealer]
	var tinta := loc.global_position + loc.global_basis.x * 0.2 - loc.global_basis.z * 0.12 + Vector3.UP * 0.004
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(_buton_dealer, "global_position", tinta, 0.4)


## Un teanc de jetoane pentru suma `centi`: coloane (câte o culoare), cel mult 12 jetoane pe coloană.
func _teanc(centi: int) -> Node3D:
	var n := Node3D.new()
	var rest := centi
	var coloana := 0
	var m := CylinderMesh.new()
	m.top_radius = RAZA_JETON
	m.bottom_radius = RAZA_JETON
	m.height = GROSIME_JETON
	m.radial_segments = 10
	for v: Array in VALORI_JETOANE:
		var cate := rest / int(v[0])
		if cate <= 0:
			continue
		rest -= cate * int(v[0])
		cate = mini(cate, 12)
		var x := (coloana % 3) * RAZA_JETON * 2.1
		var z := (coloana / 3) * RAZA_JETON * 2.1
		for k in cate:
			var j := MeshInstance3D.new()
			j.mesh = m
			j.material_override = _material(v[1])
			j.position = Vector3(x + randf_range(-0.001, 0.001), GROSIME_JETON * (k + 0.5), z + randf_range(-0.001, 0.001))
			n.add_child(j)
		coloana += 1
	if centi > 0 and n.get_child_count() == 0:
		var j := MeshInstance3D.new()
		j.mesh = m
		j.material_override = _material("a18463")
		j.position.y = GROSIME_JETON * 0.5
		n.add_child(j)
	return n


func _actualizeaza_teancuri() -> void:
	if locuri.size() < 6:
		return
	for i in 6:
		_inlocuieste(_teancuri_pariu[i], _pariu[i] if _pariu.size() == 6 else 0)
		_teancuri_pariu[i].global_position = _loc_pariu(i)
		_inlocuieste(_teancuri_bani[i], _bani[i])
		_teancuri_bani[i].global_position = locuri[i].global_position + locuri[i].global_basis.x * 0.17 + locuri[i].global_basis.z * 0.02
	_seteaza_pot_3d(_pot_total() - _suma(_pariu) if _total.size() == 6 else 0)


func _seteaza_pot_3d(centi: int) -> void:
	_inlocuieste(_teanc_pot, centi)
	_teanc_pot.global_position = centru.global_position + centru.global_basis.z * 0.08


func _inlocuieste(parinte: Node3D, centi: int) -> void:
	for c in parinte.get_children():
		c.queue_free()
	if centi > 0:
		var t := _teanc(centi)
		for c in t.get_children():
			t.remove_child(c)
			parinte.add_child(c)
		t.free()


func _suma(a: Array) -> int:
	var s := 0
	for v: int in a:
		s += v
	return s


# ---------------------------------------------------------------- HUD

func _fa_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 7
	add_child(_hud)
	var radacina := Control.new()
	radacina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radacina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radacina.theme = TemaMeniu.creeaza()
	radacina.theme.default_font_size = 10
	_hud.add_child(radacina)
	# sus: pot-ul și cărțile mesei (mici), mesajul
	var sus := VBoxContainer.new()
	sus.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	sus.offset_top = 4
	sus.alignment = BoxContainer.ALIGNMENT_CENTER
	sus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radacina.add_child(sus)
	_eticheta_pot = _eticheta(sus, "", 11, Color("a18463"))
	var rand_comune := HBoxContainer.new()
	rand_comune.alignment = BoxContainer.ALIGNMENT_CENTER
	rand_comune.add_theme_constant_override("separation", 3)
	sus.add_child(rand_comune)
	for k in 5:
		var r := TextureRect.new()
		r.custom_minimum_size = Vector2(Carti.LATIME, Carti.INALTIME)
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rand_comune.add_child(r)
		_comune_hud.append(r)
	_eticheta_mesaj = _eticheta(sus, "", 10, Color("83b3b0"))
	sus.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# jos în stânga: banii tăi, cărțile tale (mari), ce mână ai
	var jos := VBoxContainer.new()
	jos.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	jos.offset_left = 6
	jos.offset_bottom = -4
	jos.grow_vertical = Control.GROW_DIRECTION_BEGIN
	jos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radacina.add_child(jos)
	_eticheta_mana = _eticheta(jos, "", 10, Color("a18463"))
	var rand_carti := HBoxContainer.new()
	rand_carti.add_theme_constant_override("separation", 3)
	jos.add_child(rand_carti)
	for k in 2:
		var r := TextureRect.new()
		r.custom_minimum_size = Vector2(Carti.LATIME * 2, Carti.INALTIME * 2)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rand_carti.add_child(r)
		_carti_hud.append(r)
	_eticheta_bani = _eticheta(jos, "", 10, Color("83b3b0"))
	# jos în dreapta: butoanele (sus rândul cu slider-ul sumei, jos acțiunile)
	_panou_tu = VBoxContainer.new()
	_panou_tu.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_panou_tu.offset_right = -6
	_panou_tu.offset_bottom = -6
	_panou_tu.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panou_tu.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panou_tu.alignment = BoxContainer.ALIGNMENT_END
	_panou_tu.add_theme_constant_override("separation", 3)
	radacina.add_child(_panou_tu)
	_rand_marire = HBoxContainer.new()
	_rand_marire.alignment = BoxContainer.ALIGNMENT_END
	_rand_marire.add_theme_constant_override("separation", 3)
	_panou_tu.add_child(_rand_marire)
	for p: Array in [["Min", 0.0], ["1/2 Pot", 0.5], ["Pot", 1.0]]:
		var b := TemaMeniu.buton(_rand_marire, p[0], _marire_rapida.bind(p[1]))
		b.custom_minimum_size.x = 46 if p[0] == "1/2 Pot" else 38
		b.add_theme_font_size_override("font_size", 9)
		_b_rapide.append(b)
	_glisor_marire = HSlider.new()
	_glisor_marire.min_value = 0.0
	_glisor_marire.max_value = PASI_GLISOR
	_glisor_marire.step = 1.0
	_glisor_marire.custom_minimum_size = Vector2(150, 12)
	_glisor_marire.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_glisor_marire.value_changed.connect(_glisor_mutat)
	_rand_marire.add_child(_glisor_marire)
	_butoane = HBoxContainer.new()
	_butoane.alignment = BoxContainer.ALIGNMENT_END
	_butoane.add_theme_constant_override("separation", 3)
	_panou_tu.add_child(_butoane)
	_b_fold = TemaMeniu.buton(_butoane, "Fold", _apasat.bind("fold"))
	_b_call = TemaMeniu.buton(_butoane, "Check", _apasat.bind("call"))
	_b_minus = TemaMeniu.buton(_butoane, "-", _schimba_marirea.bind(-1))
	_b_minus.custom_minimum_size.x = 16
	_b_raise = TemaMeniu.buton(_butoane, "Raise", _apasat.bind("raise"))
	_b_raise.custom_minimum_size.x = 96
	_b_plus = TemaMeniu.buton(_butoane, "+", _schimba_marirea.bind(1))
	_b_plus.custom_minimum_size.x = 16
	_b_allin = TemaMeniu.buton(_butoane, "All in", _apasat.bind("allin"))
	_b_rig = TemaMeniu.buton(_butoane, "Rig cards", _apasat.bind("rig"))
	_b_rig.add_theme_color_override("font_color", Color(0.78, 0.6, 1.0))
	_b_rig.add_theme_color_override("font_hover_color", Color(0.9, 0.78, 1.0))
	_b_rig.hide()
	_panou_tu.hide()
	_intre_maini = HBoxContainer.new()
	_intre_maini.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_intre_maini.offset_right = -6
	_intre_maini.offset_bottom = -6
	_intre_maini.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_intre_maini.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_intre_maini.add_theme_constant_override("separation", 4)
	radacina.add_child(_intre_maini)
	TemaMeniu.buton(_intre_maini, "Next hand", _urmatoarea_mana).custom_minimum_size.x = 70
	TemaMeniu.buton(_intre_maini, "Leave table", _pleaca).custom_minimum_size.x = 76
	_intre_maini.hide()
	# numele adversarilor, deasupra capului (cu banii și ce au făcut)
	for i in 5:
		var e := Label.new()
		e.add_theme_font_size_override("font_size", 9)
		e.add_theme_color_override("font_color", Color("83b3b0"))
		e.add_theme_color_override("font_outline_color", Color("262d2f"))
		e.add_theme_constant_override("outline_size", 3)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		radacina.add_child(e)
		_etichete_jucatori.append(e)
	_actualizeaza_hud()


func _eticheta(parinte: Control, text: String, marime: int, cul: Color) -> Label:
	var e := Label.new()
	e.text = text
	e.add_theme_font_size_override("font_size", marime)
	e.add_theme_color_override("font_color", cul)
	e.add_theme_color_override("font_outline_color", Color("262d2f"))
	e.add_theme_constant_override("outline_size", 3)
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parinte.add_child(e)
	return e


func _mesaj(text: String) -> void:
	if _eticheta_mesaj:
		_eticheta_mesaj.text = text


var _evidentiat := -1


func _evidentiaza(i: int) -> void:
	_evidentiat = i


var _texte_mana := ["", "", "", "", "", ""]


func _eticheta_mana_jucator(i: int, text: String) -> void:
	_texte_mana[i] = text


func _actualizeaza_hud() -> void:
	if _hud == null:
		return
	var pot := _pot_total() if _total.size() == 6 else 0
	_eticheta_pot.text = "Pot: %s" % Jetoane.bani(pot) if pot > 0 else " "
	_eticheta_bani.text = "Your chips: %s" % Jetoane.bani(_bani[0])
	var are_carti := _carti_impartite and _mana.size() == 6 and (_mana[0] as Array).size() == 2
	for k in 2:
		_carti_hud[k].texture = Carti.textura(_mana[0][k]) if are_carti and not _renuntat[0] else null
	for k in 5:
		_comune_hud[k].texture = Carti.textura(_comune[k]) if k < _aratate else null
	if are_carti and not _renuntat[0]:
		var toate: Array = (_mana[0] as Array).duplicate()
		toate.append_array(_comune.slice(0, _aratate))
		_eticheta_mana.text = ManaPoker.nume(ManaPoker.scor(toate)) if toate.size() >= 5 else ("Pair" if _mana[0][0] % 13 == _mana[0][1] % 13 else "")
	elif _renuntat.size() == 6 and _renuntat[0]:
		_eticheta_mana.text = "Folded"


func _process(_delta: float) -> void:
	if _hud == null or _camera == null:
		return
	for i in 5:
		var e := _etichete_jucatori[i]
		# pe masă, în fața lui (deasupra capului ieșea din ecran)
		var punct := locuri[i + 1].global_position + locuri[i + 1].global_basis.z * 0.12 + Vector3.UP * 0.05
		if _camera.is_position_behind(punct):
			e.hide()
			continue
		e.show()
		var p := _camera.unproject_position(punct)
		var text := "%s\n%s" % [nume_jucatori[i], Jetoane.bani(_bani[i + 1])]
		if _renuntat.size() == 6 and _renuntat[i + 1] and _faza != NIMIC:
			text += "\nfolded"
		elif _texte_mana[i + 1] != "":
			text += "\n" + _texte_mana[i + 1]
		e.text = text
		e.add_theme_color_override("font_color", Color("a18463") if _evidentiat == i + 1 else Color("83b3b0"))
		e.reset_size()
		e.position = p - Vector2(e.size.x / 2.0, e.size.y / 2.0)


## Verbul potrivit: „You check.” / „Big Sal checks.”.
func _verb(i: int, tu: String, el: String) -> String:
	return tu if i == 0 else el


# ---------------------------------------------------------------- Rig cards (magia)

## Cele mai bune două cărți posibile pentru masa de acum, din cărțile care nu sunt pe masă și nici în mâna nimănui
## (nici ale celor care au renunțat: sunt pe masă, cu fața în jos).
func _cea_mai_buna_mana() -> Array:
	var ocupate := {}
	for c in _comune:
		ocupate[c] = true
	for i in range(1, 6):
		for c in _mana[i]:
			ocupate[c] = true
	var libere: Array[int] = []
	for c in 52:
		if not ocupate.has(c):
			libere.append(c)
	var cea_mai_buna: Array = _mana[0]
	var maxim := -1
	for a in libere.size():
		for b in range(a + 1, libere.size()):
			var toate: Array = [libere[a], libere[b]]
			toate.append_array(_comune)
			var s := ManaPoker.scor(toate)
			if s > maxim:
				maxim = s
				cea_mai_buna = [libere[a], libere[b]]
	return cea_mai_buna


## Magia: cărțile tale se ridică de pe postav, se învârt tot mai repede într-o lumină mov, cu scântei, iar la vârf își
## schimbă fața (cea mai bună mână posibilă); apoi coboară la loc. Ecranul pâlpâie mov o clipă.
func _rig() -> void:
	_rig_folosit = true
	var noi := _cea_mai_buna_mana()
	var carti: Array = _carti_3d[0]
	if carti.size() < 2:
		return
	_mesaj("...")
	var mijloc := ((carti[0] as Node3D).global_position + (carti[1] as Node3D).global_position) / 2.0
	# lumina mov și scânteile
	var lumina := OmniLight3D.new()
	lumina.light_color = Color(0.62, 0.3, 1.0)
	lumina.light_energy = 0.0
	lumina.omni_range = 0.9
	lumina.light_volumetric_fog_energy = 0.0
	add_child(lumina)
	lumina.global_position = mijloc + Vector3.UP * 0.12
	var scantei := _scantei_magie()
	add_child(scantei)
	scantei.global_position = mijloc + Vector3.UP * 0.06
	scantei.emitting = true
	Sunet.reda(SUNET_RIG_SCANTEI, Sunet.VOLUM_EFECTE - 4.0, 0.05)
	Sunet.reda(SUNET_RIG, Sunet.VOLUM_EFECTE - 3.0, 0.0, &"Efecte", 1.25)
	# 1. se ridică și încep să se învârtă
	var baze: Array[Transform3D] = []
	for nod: Node3D in carti:
		baze.append(nod.global_transform)
	var urca := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	urca.tween_property(lumina, "light_energy", 2.2, 0.5)
	await _invarte(carti, baze, true, 0.9)
	# 2. la vârf: fulgerul mov, fețele se schimbă
	_fulger_mov()
	Sunet.reda(SUNET_RIG_SCHIMB, Sunet.VOLUM_EFECTE - 6.0, 0.05)
	for k in 2:
		var fata := (carti[k] as Node3D).get_child(0) as MeshInstance3D
		fata.material_override = _material_carte(Carti.textura(noi[k]))
		(carti[k] as Node3D).set_meta("carte", noi[k])
	_mana[0] = noi
	_actualizeaza_hud()
	# 3. încetinesc și coboară la loc
	await _invarte(carti, baze, false, 0.9)
	for k in carti.size():
		(carti[k] as Node3D).global_transform = baze[k]
	scantei.emitting = false
	var stinge := create_tween()
	stinge.tween_property(lumina, "light_energy", 0.0, 0.6)
	stinge.tween_callback(lumina.queue_free)
	get_tree().create_timer(1.5).timeout.connect(scantei.queue_free)
	_mesaj("Your cards look... different.")


## Urcarea (`urca`) sau coborârea cărților, în `durata` secunde: 3 ture fiecare, tot mai repede la urcare și tot mai
## încet la coborâre, deci se opresc exact cum erau (fără salt).
func _invarte(carti: Array, baze: Array[Transform3D], urca: bool, durata: float) -> void:
	var t := create_tween()
	t.tween_method(_pas_rig.bind(carti, baze, urca), 0.0, 1.0, durata)
	await t.finished


func _pas_rig(p: float, carti: Array, baze: Array[Transform3D], urca: bool) -> void:
	var inaltime := ease(p, 0.5) if urca else 1.0 - ease(p, 2.0)
	var unghi := TAU * 3.0 * (p * p if urca else 1.0 - (1.0 - p) * (1.0 - p))
	for k in carti.size():
		var nod := carti[k] as Node3D
		var b: Transform3D = baze[k]
		# cartea se ridică în picioare (fața spre tine), plutește puțin și se rotește în jurul axei verticale
		var ridicata := Basis(b.basis.x.normalized(), PI / 2.0 * inaltime) * b.basis
		var plutire := sin(p * TAU * 2.0 + k * 1.7) * 0.006 * inaltime
		var lateral := b.basis.x.normalized() * (k - 0.5) * 0.03 * inaltime
		nod.global_transform = Transform3D(Basis(Vector3.UP, unghi) * ridicata,
			b.origin + Vector3.UP * (0.1 * inaltime + plutire) + lateral)


## Scântei mov care urcă de pe cărți (cercuri moi, aditive).
func _scantei_magie() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 40
	p.lifetime = 0.9
	p.preprocess = 0.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.07
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 0.08
	p.initial_velocity_max = 0.25
	p.gravity = Vector3(0, 0.15, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.018, 0.018)
	mesh.material = Arma.material_particule(true)
	p.mesh = mesh
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.6, 1.0, 1.0))
	g.set_color(1, Color(0.45, 0.15, 0.9, 0.0))
	p.color_ramp = g
	return p


## Ecranul pâlpâie mov o clipă (peste HUD-ul mesei).
func _fulger_mov() -> void:
	if _hud == null:
		return
	var r := ColorRect.new()
	r.color = Color(0.55, 0.25, 0.95, 0.45)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(r)
	var t := create_tween()
	t.tween_property(r, "color:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_callback(r.queue_free)
