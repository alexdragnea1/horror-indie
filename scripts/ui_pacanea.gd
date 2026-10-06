class_name UIPacanea
extends CanvasLayer
## Ecranul jocului de la păcănea („40 BURNING 7s”, în stilul EGT): 5 role x 3 rânduri, 10 linii, fructe, clopoțel,
## șeptari și steaua (scatter, plătește oriunde pe ecran). Creditul = jetoanele tale (Jetoane), pariul pe rotire se alege
## din `PARIURI`. După un câștig poți încerca „Gamble” (roșu / negru pe o carte: dublezi sau pierzi tot).
## Șansa de câștig la o rotire e `sansa_castig` (60%, cerută de owner): jocul hotărăște întâi dacă rotirea câștigă, apoi
## alege simbolurile ca să iasă așa (o linie câștigătoare sau niciuna).
## Space = Spin, Esc = Leave. Semnalul `inchis` când pleci.

signal inchis

const PARIURI := [10, 20, 50, 100, 200]
const LINII := [
	[1, 1, 1, 1, 1], [0, 0, 0, 0, 0], [2, 2, 2, 2, 2], [0, 1, 2, 1, 0], [2, 1, 0, 1, 2],
	[0, 0, 1, 2, 2], [2, 2, 1, 0, 0], [1, 0, 0, 0, 1], [1, 2, 2, 2, 1], [0, 1, 1, 1, 0],
]
## Cât plătește o linie de 3 / 4 / 5 simboluri la fel (de câte ori pariul).
const PLATI := {
	"cirese": [0.5, 1.0, 3.0], "lamaie": [0.8, 3.0, 8.0], "portocala": [0.8, 3.0, 8.0], "pruna": [0.8, 3.0, 8.0],
	"struguri": [2.0, 6.0, 20.0], "pepene": [2.0, 6.0, 20.0], "clopot": [3.0, 10.0, 30.0], "sapte": [5.0, 20.0, 100.0],
}
## Steaua: 3 / 4 / 5 oriunde pe ecran.
const PLATI_STEA := [2.0, 10.0, 50.0]
## Cât de des apare fiecare simbol pe role (și cât de des e ales pentru o linie câștigătoare).
const GREUTATI := {"cirese": 30, "lamaie": 16, "portocala": 16, "pruna": 16, "struguri": 7, "pepene": 7, "clopot": 5,
	"sapte": 3, "stea": 3}
const LUNGIMI := [[3, 86], [4, 12], [5, 2]]
const MARIME := 30  # o celulă de pe rolă (simbolul are 12 px x 2, plus margine)

@export var sansa_castig := 0.6

var credit := 0
var _pariu_index := 1
var _castig := 0
var _ruleaza := false
var _grila: Array = []          # [rola][rand] = simbol
var _role: Array[Control] = []
var _celule: Array = []         # [rola] = TextureRect-uri (4: unul în plus pentru derulare)
var _eticheta_credit: Label
var _eticheta_pariu: Label
var _eticheta_castig: Label
var _eticheta_mesaj: Label
var _b_spin: Button
var _b_gamble: Button
var _b_minus: Button
var _b_plus: Button
var _b_pleaca: Button
var _linii_desen: Control
var _linii_castig: Array = []   # [[linie, cate]]
var _panou_gamble: Control
var _carte_gamble: TextureRect
var _sunet_rulare: AudioStreamPlayer
var _clipire := 0.0

const SUNET_RULARE := preload("res://sunete/pacanea_rulare.ogg")
const SUNET_OPRIRE := preload("res://sunete/pacanea_oprire.ogg")
const SUNET_CASTIG := preload("res://sunete/pacanea_castig.ogg")
const SUNET_NUMARARE := preload("res://sunete/pacanea_numarare.ogg")
const SUNET_CARTE := preload("res://sunete/carte_intoarsa.ogg")
const SUNET_PIERDERE := preload("res://sunete/poker_pierdere.ogg")

const FUNDAL := Color("262d2f")
const ROSU := Color("7b383a")
const AUR := Color("a18463")
const TEXT := Color("83b3b0")


func _ready() -> void:
	layer = 7
	process_mode = Node.PROCESS_MODE_ALWAYS
	credit = Jetoane.suma()
	_grila = _grila_aleatoare()
	_construieste()
	_arata_grila()
	_actualizeaza()
	_sunet_rulare = AudioStreamPlayer.new()
	_sunet_rulare.stream = SUNET_RULARE
	_sunet_rulare.volume_db = Sunet.VOLUM_EFECTE - 4.0
	_sunet_rulare.bus = &"Efecte"
	add_child(_sunet_rulare)


func _construieste() -> void:
	var umbra := ColorRect.new()
	umbra.color = Color(0, 0, 0, 0.55)
	umbra.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(umbra)
	var ecran := PanelContainer.new()
	ecran.theme = TemaMeniu.creeaza()
	ecran.theme.default_font_size = 10
	ecran.add_theme_stylebox_override("panel", TemaMeniu.cutie(FUNDAL, AUR, 6))
	ecran.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ecran.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ecran.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(ecran)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	ecran.add_child(col)
	var titlu := Label.new()
	titlu.text = "40 BURNING 7s"
	titlu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titlu.add_theme_font_size_override("font_size", 13)
	titlu.add_theme_color_override("font_color", AUR)
	titlu.add_theme_color_override("font_outline_color", ROSU)
	titlu.add_theme_constant_override("outline_size", 4)
	col.add_child(titlu)
	# rolele
	var cadru := PanelContainer.new()
	cadru.add_theme_stylebox_override("panel", TemaMeniu.cutie(Color("48313b"), ROSU, 3))
	cadru.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(cadru)
	var zona := Control.new()
	zona.custom_minimum_size = Vector2(MARIME * 5 + 4 * 4, MARIME * 3)
	cadru.add_child(zona)
	for r in 5:
		var rola := Control.new()
		rola.clip_contents = true
		rola.position = Vector2(r * (MARIME + 4), 0)
		rola.size = Vector2(MARIME, MARIME * 3)
		var fond := ColorRect.new()
		fond.color = Color("553e4d")
		fond.size = rola.size
		rola.add_child(fond)
		zona.add_child(rola)
		_role.append(rola)
		var celule: Array[TextureRect] = []
		for k in 4:
			var t := TextureRect.new()
			t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			t.size = Vector2(MARIME, MARIME)
			t.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			t.position = Vector2(0, k * MARIME)
			rola.add_child(t)
			celule.append(t)
		_celule.append(celule)
	_linii_desen = Control.new()
	_linii_desen.size = zona.custom_minimum_size
	_linii_desen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_linii_desen.draw.connect(_deseneaza_linii)
	zona.add_child(_linii_desen)
	# cartea de la Gamble (peste role, ascunsă)
	_panou_gamble = ColorRect.new()
	(_panou_gamble as ColorRect).color = Color(FUNDAL, 0.92)
	_panou_gamble.size = zona.custom_minimum_size
	_panou_gamble.hide()
	zona.add_child(_panou_gamble)
	_carte_gamble = TextureRect.new()
	_carte_gamble.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_carte_gamble.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_carte_gamble.size = Vector2(Carti.LATIME * 1.8, Carti.INALTIME * 1.8)
	_carte_gamble.position = (_panou_gamble.size - _carte_gamble.size) / 2.0
	_panou_gamble.add_child(_carte_gamble)
	# contoarele
	var rand := HBoxContainer.new()
	rand.add_theme_constant_override("separation", 10)
	rand.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(rand)
	_eticheta_credit = _contor(rand)
	_eticheta_pariu = _contor(rand)
	_eticheta_castig = _contor(rand)
	_eticheta_mesaj = Label.new()
	_eticheta_mesaj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eticheta_mesaj.add_theme_color_override("font_color", AUR)
	col.add_child(_eticheta_mesaj)
	# butoanele
	var butoane := HBoxContainer.new()
	butoane.add_theme_constant_override("separation", 3)
	butoane.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(butoane)
	_b_minus = TemaMeniu.buton(butoane, "Bet -", _schimba_pariul.bind(-1))
	_b_minus.custom_minimum_size.x = 36
	_b_plus = TemaMeniu.buton(butoane, "Bet +", _schimba_pariul.bind(1))
	_b_plus.custom_minimum_size.x = 36
	_b_spin = TemaMeniu.buton(butoane, "Spin", _spin)
	_b_gamble = TemaMeniu.buton(butoane, "Gamble", _gamble)
	_b_pleaca = TemaMeniu.buton(butoane, "Leave", _pleaca)
	ecran.reset_size()
	ecran.position = (Vector2(480, 270) - ecran.size) / 2.0


func _contor(parinte: Control) -> Label:
	var e := Label.new()
	e.add_theme_color_override("font_color", TEXT)
	parinte.add_child(e)
	return e


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if not _ruleaza:
			_pleaca()
	elif event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		if not _ruleaza and not _panou_gamble.visible:
			_spin()


func _process(delta: float) -> void:
	_clipire += delta
	if not _linii_castig.is_empty():
		_linii_desen.queue_redraw()


func _pariu() -> int:
	return PARIURI[_pariu_index]


func _schimba_pariul(semn: int) -> void:
	_pariu_index = clampi(_pariu_index + semn, 0, PARIURI.size() - 1)
	_actualizeaza()


func _actualizeaza() -> void:
	_eticheta_credit.text = "CREDIT %s" % Jetoane.bani(credit)
	_eticheta_pariu.text = "BET %s" % Jetoane.bani(_pariu())
	_eticheta_castig.text = "WIN %s" % Jetoane.bani(_castig)
	_b_spin.disabled = _ruleaza or credit < _pariu()
	_b_minus.disabled = _ruleaza
	_b_plus.disabled = _ruleaza
	_b_gamble.disabled = _ruleaza or _castig <= 0
	_b_pleaca.disabled = _ruleaza


# ---------------------------------------------------------------- rotirea

func _spin() -> void:
	if _ruleaza or credit < _pariu():
		return
	# câștigul nejucat la Gamble intră în credit
	_ia_castigul()
	_ruleaza = true
	credit -= _pariu()
	_linii_castig.clear()
	_linii_desen.queue_redraw()
	_eticheta_mesaj.text = ""
	_actualizeaza()
	var castiga := randf() < sansa_castig
	var noua := _grila_castigatoare() if castiga else _grila_pierzatoare()
	_sunet_rulare.play()
	# fiecare rolă se învârte și se oprește, una după alta, de la stânga la dreapta
	var timp := 0.0
	var opriri := [0.7, 0.95, 1.2, 1.45, 1.7]
	var oprita := [false, false, false, false, false]
	var deplasare := [0.0, 0.0, 0.0, 0.0, 0.0]
	var benzi: Array = []
	for r in 5:
		benzi.append(_banda_aleatoare())
	while not oprita[4]:
		var dt := get_process_delta_time()
		timp += dt
		for r in 5:
			if oprita[r]:
				continue
			if timp >= opriri[r]:
				oprita[r] = true
				_grila[r] = noua[r]
				_arata_rola(r, 0.0)
				Sunet.reda(SUNET_OPRIRE, Sunet.VOLUM_EFECTE - 3.0, 0.05, &"Interfata")
				# o mică săltătură la oprire
				var t := create_tween()
				t.tween_property(_role[r], "position:y", 3.0, 0.05)
				t.tween_property(_role[r], "position:y", 0.0, 0.08)
				continue
			deplasare[r] += dt * 620.0
			if deplasare[r] >= MARIME:
				deplasare[r] -= MARIME
				(benzi[r] as Array).push_front((benzi[r] as Array).pop_back())
			for k in 4:
				_celule[r][k].texture = Carti.simbol((benzi[r] as Array)[k], 2)
				_celule[r][k].position.y = (k - 1) * MARIME + deplasare[r]
		await get_tree().process_frame
	_sunet_rulare.stop()
	var c := _calculeaza()
	_castig = c
	if _castig > 0:
		Sunet.reda(SUNET_CASTIG, Sunet.VOLUM_EFECTE - 2.0, 0.0, &"Interfata")
		_eticheta_mesaj.text = "WIN %s!" % Jetoane.bani(_castig) if _castig >= _pariu() * 5 else "WIN"
	_ruleaza = false
	_actualizeaza()
	Jetoane.seteaza(credit + _castig)


## Câștigul de pe ecran (liniile și steaua); ține minte liniile câștigătoare (clipesc).
func _calculeaza() -> int:
	var total := 0.0
	_linii_castig.clear()
	for li in LINII.size():
		var linie: Array = LINII[li]
		var primul: String = _grila[0][linie[0]]
		if primul == "stea":
			continue
		var cate := 1
		for r in range(1, 5):
			if _grila[r][linie[r]] == primul:
				cate += 1
			else:
				break
		if cate >= 3:
			total += float(PLATI[primul][cate - 3])
			_linii_castig.append([li, cate])
	var stele := 0
	for r in 5:
		for k in 3:
			if _grila[r][k] == "stea":
				stele += 1
	if stele >= 3:
		total += PLATI_STEA[mini(stele, 5) - 3]
	return int(round(total * _pariu()))


func _ia_castigul() -> void:
	if _castig > 0:
		credit += _castig
		Sunet.reda(SUNET_NUMARARE, Sunet.VOLUM_EFECTE - 4.0, 0.0, &"Interfata")
	_castig = 0
	_panou_gamble.hide()


func _simbol_aleator() -> String:
	var s := 0
	for v: int in GREUTATI.values():
		s += v
	var x := randi() % s
	for k: String in GREUTATI:
		x -= int(GREUTATI[k])
		if x < 0:
			return k
	return "cirese"


func _grila_aleatoare() -> Array:
	var g: Array = []
	for r in 5:
		g.append([_simbol_aleator(), _simbol_aleator(), _simbol_aleator()])
	return g


func _banda_aleatoare() -> Array:
	return [_simbol_aleator(), _simbol_aleator(), _simbol_aleator(), _simbol_aleator()]


## O grilă fără nicio linie câștigătoare (și cu mai puțin de 3 stele).
func _grila_pierzatoare() -> Array:
	var vechi := _grila
	for incercare in 300:
		_grila = _grila_aleatoare()
		if _calculeaza() == 0:
			var g := _grila
			_grila = vechi
			return g
	_grila = vechi
	return [["cirese", "lamaie", "pruna"], ["pruna", "cirese", "lamaie"], ["lamaie", "pruna", "cirese"],
		["struguri", "pepene", "clopot"], ["pepene", "clopot", "struguri"]]


## O grilă cu cel puțin o linie câștigătoare: simbolul și lungimea alese după GREUTATI / LUNGIMI.
func _grila_castigatoare() -> Array:
	var vechi := _grila
	var g := _grila_pierzatoare()
	var simbol := _simbol_aleator()
	while simbol == "stea":
		simbol = _simbol_aleator()
	var x := randi() % 100
	var lungime := 3
	for l: Array in LUNGIMI:
		x -= int(l[1])
		if x < 0:
			lungime = l[0]
			break
	var linie: Array = LINII.pick_random()
	for r in lungime:
		g[r][linie[r]] = simbol
	# după linie, o rolă cu alt simbol, ca să nu iasă mai lungă decât s-a ales
	if lungime < 5 and g[lungime][linie[lungime]] == simbol:
		g[lungime][linie[lungime]] = "cirese" if simbol != "cirese" else "lamaie"
	_grila = vechi
	return g


func _arata_grila() -> void:
	for r in 5:
		_arata_rola(r, 0.0)


func _arata_rola(r: int, deplasare: float) -> void:
	for k in 4:
		var t: TextureRect = _celule[r][k]
		if k < 3:
			t.texture = Carti.simbol(_grila[r][k], 2)
			t.position.y = k * MARIME + deplasare
		else:
			t.texture = null


func _deseneaza_linii() -> void:
	if _linii_castig.is_empty() or fmod(_clipire, 0.5) > 0.32:
		return
	for lc: Array in _linii_castig:
		var linie: Array = LINII[lc[0]]
		var puncte := PackedVector2Array()
		for r in lc[1]:
			puncte.append(Vector2(r * (MARIME + 4) + MARIME / 2.0, linie[r] * MARIME + MARIME / 2.0))
		_linii_desen.draw_polyline(puncte, AUR, 2.0)
		for r in lc[1]:
			_linii_desen.draw_rect(Rect2(r * (MARIME + 4), linie[r] * MARIME, MARIME, MARIME), AUR, false, 1.0)


# ---------------------------------------------------------------- Gamble (roșu / negru)

func _gamble() -> void:
	if _castig <= 0 or _ruleaza:
		return
	_ruleaza = true
	_actualizeaza()
	_panou_gamble.show()
	_carte_gamble.texture = Carti.spate()
	_eticheta_mesaj.text = "Red or black? Win %s or lose it all." % Jetoane.bani(_castig * 2)
	var alegere := await _alege_culoarea()
	var carte := randi() % 52
	# cartea „clipește” între spate și fețe la întâmplare, apoi se oprește
	for k in 8:
		_carte_gamble.texture = Carti.textura(randi() % 52) if k % 2 else Carti.spate()
		Sunet.reda(SUNET_CARTE, Sunet.VOLUM_EFECTE - 6.0, 0.1, &"Interfata")
		await get_tree().create_timer(0.07).timeout
	_carte_gamble.texture = Carti.textura(carte)
	if Carti.e_rosie(carte) == (alegere == 0):
		_castig *= 2
		Sunet.reda(SUNET_CASTIG, Sunet.VOLUM_EFECTE - 2.0, 0.0, &"Interfata")
		_eticheta_mesaj.text = "WIN %s!" % Jetoane.bani(_castig)
	else:
		_castig = 0
		Sunet.reda(SUNET_PIERDERE, Sunet.VOLUM_EFECTE - 2.0, 0.0, &"Interfata")
		_eticheta_mesaj.text = "Lost."
	_linii_castig.clear()
	_linii_desen.queue_redraw()
	await get_tree().create_timer(1.0).timeout
	_panou_gamble.hide()
	_ruleaza = false
	_actualizeaza()
	Jetoane.seteaza(credit + _castig)


signal _culoare(index: int)


func _alege_culoarea() -> int:
	var rand := HBoxContainer.new()
	rand.add_theme_constant_override("separation", 6)
	rand.position = Vector2(4, _panou_gamble.size.y - 22)
	_panou_gamble.add_child(rand)
	var r := TemaMeniu.buton(rand, "Red", func() -> void: _culoare.emit(0))
	r.add_theme_color_override("font_color", Color("904a40"))
	TemaMeniu.buton(rand, "Black", func() -> void: _culoare.emit(1))
	var ales: int = await _culoare
	rand.queue_free()
	return ales


func _pleaca() -> void:
	if _ruleaza:
		return
	_ia_castigul()
	Jetoane.seteaza(credit)
	inchis.emit()
	queue_free()
