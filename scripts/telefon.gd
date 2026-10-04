class_name Telefon
extends CanvasLayer
## Telefonul jucătorului, pe ecran, ca o aplicație de mesaje (nu caseta de dialog):
## vibrează în buzunar, îl scoți, pe ecranul blocat apare notificarea, o apeși și se deschide conversația.
## Mesajele ei vin după „typing” (trei puncte), pe ale tale le scrii literă cu literă în bara de jos și le trimiți.
## La sfârșit „Seen”, apoi bagi telefonul la loc în buzunar. Cât e scos, nu te miști (Stare.meniu_deschis).
##   await Telefon.conversatie(self, "School Whore", ["Her: Hey...", "You: Aight bet"], "1:02")
## Prefixul ("You:" = tu, în dreapta; orice altceva = ea, în stânga) alege doar partea: pe ecran nu apare.

const LATIME := 150
const INALTIME := 252
## Unde stă telefonul când îl ții în mână (colțul din stânga sus, în pixelii jocului: 480 × 270).
const LOC_SUS := Vector2(170, 10)
const LATIME_BULA := 100
const LITERE_PE_SECUNDA := 13.0

# culorile paletei
const C_CORP := Color("262d2f")
const C_RAMA := Color("5e5356")
const C_FUNDAL := Color("2a3c3d")
const C_ANTET := Color("32453b")
const C_EA := Color("553e4d")
const C_TU := Color("30716f")
const C_TEXT := Color("83b3b0")
const C_SLAB := Color("7e8d87")
const C_ACCENT := Color("61a19f")

const SUNET_VIBRATIE := preload("res://sunete/telefon_vibratie.ogg")
const SUNET_BUZUNAR := preload("res://sunete/telefon_buzunar.ogg")
const SUNET_NOTIFICARE := preload("res://sunete/telefon_notificare.ogg")
const SUNET_TASTA := preload("res://sunete/telefon_tasta.ogg")
const SUNET_TRIMIS := preload("res://sunete/telefon_trimis.ogg")
const SUNET_PRIMIT := preload("res://sunete/telefon_primit.ogg")

var contact := ""
var mesaje: PackedStringArray = []
var ora := "1:02"

var _umbra: ColorRect
var _corp: Panel
var _ecran: Panel
var _blocat: Control
var _notificare: PanelContainer
var _chat: Control
var _lista: VBoxContainer
var _camp: Label
var _trimite: Panel
var _scris := false
var _timp := 0.0
var _sus := 0.0  # 0 = în buzunar, 1 = în mână (pentru legănat)


## Scoate telefonul, arată conversația și îl bagă la loc. Se termină după ce telefonul a coborât.
static func conversatie(nod: Node, cu_cine: String, ce: PackedStringArray, cat_e_ora := "1:02") -> void:
	var t := Telefon.new()
	t.contact = cu_cine
	t.mesaje = ce
	t.ora = cat_e_ora
	nod.get_tree().current_scene.add_child(t)
	await t._ruleaza()
	t.queue_free()


func _ready() -> void:
	layer = 8  # sub benzile de cutscene (9) și sub dialog (10)
	_umbra = ColorRect.new()
	_umbra.color = Color(C_CORP, 0.0)
	_umbra.set_anchors_preset(Control.PRESET_FULL_RECT)
	_umbra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_umbra)
	_construieste()


func _process(delta: float) -> void:
	_timp += delta
	# în mână se mișcă puțin (respirația, mâna care nu stă perfect pe loc)
	if _sus > 0.0:
		var leganat := Vector2(sin(_timp * 1.1) * 1.2, sin(_timp * 1.7) * 1.0) * _sus
		_corp.position = _corp.position.lerp(_loc() + leganat, 1.0 - exp(-delta * 12.0))


func _loc() -> Vector2:
	return LOC_SUS.lerp(Vector2(LOC_SUS.x + 40, 290), 1.0 - _sus)


# ---------------------------------------------------------------- construcția ecranului

func _cutie(culoare: Color, raza: int, rama := Color.TRANSPARENT, grosime := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = culoare
	s.set_corner_radius_all(raza)
	if grosime > 0:
		s.border_color = rama
		s.set_border_width_all(grosime)
	s.anti_aliasing = false  # pixeli curați, ca restul jocului
	return s


func _text(continut: String, marime: int, culoare: Color) -> Label:
	var l := Label.new()
	l.text = continut
	l.add_theme_font_size_override("font_size", marime)
	l.add_theme_color_override("font_color", culoare)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panou(parinte: Control, pozitie: Vector2, marime: Vector2, stil: StyleBox) -> Panel:
	var p := Panel.new()
	p.position = pozitie
	p.size = marime
	p.add_theme_stylebox_override("panel", stil)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parinte.add_child(p)
	return p


func _construieste() -> void:
	_corp = Panel.new()
	_corp.size = Vector2(LATIME, INALTIME)
	_corp.pivot_offset = Vector2(LATIME * 0.5, INALTIME)
	_corp.position = _loc()
	_corp.add_theme_stylebox_override("panel", _cutie(C_CORP, 16, C_RAMA, 2))
	add_child(_corp)
	# butoanele de pe laterale, difuzorul și camera de sus
	_panou(_corp, Vector2(-2, 52), Vector2(2, 22), _cutie(C_RAMA, 1))
	_panou(_corp, Vector2(-2, 80), Vector2(2, 22), _cutie(C_RAMA, 1))
	_panou(_corp, Vector2(LATIME, 64), Vector2(2, 30), _cutie(C_RAMA, 1))
	_panou(_corp, Vector2(LATIME * 0.5 - 14, 6), Vector2(28, 3), _cutie(C_RAMA, 2))
	_panou(_corp, Vector2(LATIME * 0.5 + 20, 5), Vector2(5, 5), _cutie(Color("2a3c3d"), 3))

	_ecran = _panou(_corp, Vector2(6, 14), Vector2(LATIME - 12, INALTIME - 26), _cutie(C_FUNDAL, 10))
	_ecran.clip_contents = true
	var w := _ecran.size.x
	var h := _ecran.size.y

	# --- ecranul blocat: un fundal în două tonuri, ceasul mare, notificarea
	_blocat = Control.new()
	_blocat.size = _ecran.size
	_blocat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ecran.add_child(_blocat)
	_panou(_blocat, Vector2(0, h * 0.45), Vector2(w, h * 0.55), _cutie(Color("295555"), 0))
	_panou(_blocat, Vector2(0, h * 0.72), Vector2(w, h * 0.28), _cutie(Color("30716f"), 0))
	var ceas := _text(ora, 30, C_TEXT)
	ceas.position = Vector2(0, 26)
	ceas.size = Vector2(w, 40)
	ceas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blocat.add_child(ceas)
	var deschide := _text("Swipe up to open", 7, C_SLAB)
	deschide.position = Vector2(0, h - 16)
	deschide.size = Vector2(w, 10)
	deschide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_blocat.add_child(deschide)

	_notificare = PanelContainer.new()
	var stil_notif := _cutie(Color("48313b"), 6)
	stil_notif.set_content_margin_all(5)
	_notificare.add_theme_stylebox_override("panel", stil_notif)
	_notificare.position = Vector2(5, 84)
	_notificare.custom_minimum_size = Vector2(w - 10, 0)
	_notificare.pivot_offset = Vector2((w - 10) * 0.5, 16)
	_notificare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notificare.modulate.a = 0.0
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	var rand := HBoxContainer.new()
	var nume_notif := _text(contact, 8, C_TEXT)
	nume_notif.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rand.add_child(nume_notif)
	rand.add_child(_text("now", 7, C_SLAB))
	col.add_child(rand)
	var primul := _text(_fara_nume(mesaje[0]) if not mesaje.is_empty() else "", 8, C_SLAB)
	primul.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	primul.custom_minimum_size.x = w - 20
	col.add_child(primul)
	_notificare.add_child(col)
	_blocat.add_child(_notificare)

	# --- aplicația de mesaje: antetul cu numele, lista, bara de scris
	_chat = Control.new()
	_chat.size = _ecran.size
	_chat.position = Vector2(w, 0)
	_chat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ecran.add_child(_chat)
	_panou(_chat, Vector2.ZERO, _ecran.size, _cutie(C_CORP, 0))
	var antet := _panou(_chat, Vector2(0, 0), Vector2(w, 40), _cutie(C_ANTET, 0))
	var inapoi := _text("<", 12, C_ACCENT)
	inapoi.position = Vector2(4, 14)
	antet.add_child(inapoi)
	var avatar := _panou(antet, Vector2(16, 15), Vector2(20, 20), _cutie(Color("a18463"), 10))
	var initiala := _text(contact.left(1), 11, C_CORP)
	initiala.size = avatar.size
	initiala.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initiala.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar.add_child(initiala)
	var nume := _text(contact, 9, C_TEXT)
	nume.position = Vector2(41, 13)
	antet.add_child(nume)
	var online := _text("online", 7, C_ACCENT)
	online.position = Vector2(41, 25)
	antet.add_child(online)

	var zona := Control.new()
	zona.position = Vector2(0, 40)
	zona.size = Vector2(w, h - 40 - 26)
	zona.clip_contents = true
	zona.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chat.add_child(zona)
	_lista = VBoxContainer.new()
	_lista.add_theme_constant_override("separation", 4)
	_lista.anchor_left = 0.0
	_lista.anchor_right = 1.0
	_lista.anchor_top = 1.0
	_lista.anchor_bottom = 1.0
	_lista.offset_left = 5
	_lista.offset_right = -5
	_lista.offset_bottom = -4
	_lista.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_lista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zona.add_child(_lista)
	var azi := _text("Today", 7, C_SLAB)
	azi.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lista.add_child(azi)

	var bara := _panou(_chat, Vector2(0, h - 26), Vector2(w, 26), _cutie(C_ANTET, 0))
	var camp := _panou(bara, Vector2(5, 5), Vector2(w - 32, 16), _cutie(C_CORP, 8))
	_camp = _text("Message", 8, C_SLAB)
	_camp.position = Vector2(7, 1)
	_camp.size = Vector2(w - 44, 14)
	_camp.clip_text = true
	_camp.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_camp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT  # textul lung fuge spre stânga, ca la tastat
	camp.add_child(_camp)
	_trimite = _panou(bara, Vector2(w - 23, 4), Vector2(18, 18), _cutie(C_RAMA, 9))
	_trimite.pivot_offset = Vector2(9, 9)
	var sageata := _text(">", 10, C_TEXT)
	sageata.size = _trimite.size
	sageata.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sageata.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_trimite.add_child(sageata)

	# --- bara de sus (peste ambele ecrane): ora, semnalul, bateria
	var ora_mica := _text(ora, 7, C_TEXT)
	ora_mica.position = Vector2(9, 1)
	_ecran.add_child(ora_mica)
	for i in 4:
		_panou(_ecran, Vector2(w - 34 + i * 3, 7 - i * 1.5), Vector2(2, 2 + i * 1.5), _cutie(C_TEXT, 0))
	_panou(_ecran, Vector2(w - 20, 3), Vector2(12, 6), _cutie(Color.TRANSPARENT, 1, C_TEXT, 1))
	_panou(_ecran, Vector2(w - 8, 5), Vector2(1, 2), _cutie(C_TEXT, 0))
	_panou(_ecran, Vector2(w - 18, 5), Vector2(6, 2), _cutie(C_TEXT, 0))  # 60%


func _fara_nume(replica: String) -> String:
	var i := replica.find(":")
	return replica.substr(i + 1).strip_edges() if i >= 0 and i < 12 else replica


func _e_al_meu(replica: String) -> bool:
	return replica.begins_with("You:")


## O bulă de mesaj (stânga = ea, dreapta = tu), cu ora în colț. Apare cu un mic „pop”.
func _bula(continut: String, al_meu: bool) -> Control:
	var rand := HBoxContainer.new()
	rand.alignment = BoxContainer.ALIGNMENT_END if al_meu else BoxContainer.ALIGNMENT_BEGIN
	rand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bula := PanelContainer.new()
	var stil := _cutie(C_TU if al_meu else C_EA, 7)
	stil.content_margin_left = 6
	stil.content_margin_right = 6
	stil.content_margin_top = 3
	stil.content_margin_bottom = 3
	# colțul dinspre tine e ascuțit, ca la aplicațiile adevărate
	if al_meu:
		stil.corner_radius_bottom_right = 1
	else:
		stil.corner_radius_bottom_left = 1
	bula.add_theme_stylebox_override("panel", stil)
	bula.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	var text := _text(continut, 9, C_TEXT)
	var font := text.get_theme_font("font")
	var lat := font.get_string_size(continut, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	if lat > LATIME_BULA:
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = LATIME_BULA
	col.add_child(text)
	var cand := _text(ora, 6, Color("83b3b0") if al_meu else C_SLAB)
	cand.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(cand)
	bula.add_child(col)
	rand.add_child(bula)
	_lista.add_child(rand)
	_pop(bula, al_meu)
	return rand


func _pop(c: Control, dreapta: bool) -> void:
	c.modulate.a = 0.0
	await get_tree().process_frame
	c.pivot_offset = Vector2(c.size.x if dreapta else 0.0, c.size.y)
	c.scale = Vector2(0.7, 0.7)
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(c, "scale", Vector2.ONE, 0.22)
	t.tween_property(c, "modulate:a", 1.0, 0.12)


## Bula cu trei puncte care sar („typing”), cât `durata` secunde.
func _scrie_ea(durata: float) -> void:
	var rand := HBoxContainer.new()
	var bula := PanelContainer.new()
	var stil := _cutie(C_EA, 7)
	stil.set_content_margin_all(5)
	stil.corner_radius_bottom_left = 1
	bula.add_theme_stylebox_override("panel", stil)
	var puncte := HBoxContainer.new()
	puncte.add_theme_constant_override("separation", 3)
	var lista_puncte: Array[ColorRect] = []
	for i in 3:
		var loc := Control.new()
		loc.custom_minimum_size = Vector2(4, 8)
		var punct := ColorRect.new()
		punct.color = C_SLAB
		punct.size = Vector2(4, 4)
		punct.position = Vector2(0, 3)
		loc.add_child(punct)
		puncte.add_child(loc)
		lista_puncte.append(punct)
	bula.add_child(puncte)
	rand.add_child(bula)
	_lista.add_child(rand)
	_pop(bula, false)
	var trecut := 0.0
	while trecut < durata:
		await get_tree().process_frame
		trecut += get_process_delta_time()
		for i in 3:
			var faza := fposmod(trecut * 2.2 - i * 0.18, 1.0)
			lista_puncte[i].position.y = 3.0 - 3.0 * maxf(sin(faza * TAU), 0.0) * float(faza < 0.5)
			lista_puncte[i].color = C_TEXT if faza < 0.5 else C_SLAB
	rand.queue_free()
	await get_tree().process_frame


## Scrii mesajul în bara de jos (literă cu literă, cu „tac” la fiecare tastă), apoi îl trimiți.
func _scrie_tu(continut: String) -> void:
	_camp.add_theme_color_override("font_color", C_TEXT)
	_camp.text = ""
	for i in continut.length():
		_camp.text = continut.left(i + 1)
		if continut[i] != " ":
			Sunet.reda(SUNET_TASTA, Sunet.VOLUM_EFECTE - 8.0, 0.0, &"Interfata", randf_range(0.9, 1.15))
		var pauza := 1.0 / LITERE_PE_SECUNDA * randf_range(0.6, 1.5)
		if continut[i] == " ":
			pauza *= 1.6
		await get_tree().create_timer(pauza).timeout
	await get_tree().create_timer(0.35).timeout
	# apeși pe săgeată
	var t := create_tween()
	t.tween_property(_trimite, "scale", Vector2(0.8, 0.8), 0.06)
	t.tween_callback(func() -> void: _trimite.add_theme_stylebox_override("panel", _cutie(C_ACCENT, 9)))
	t.tween_property(_trimite, "scale", Vector2.ONE, 0.1)
	await t.finished
	Sunet.reda(SUNET_TRIMIS, Sunet.VOLUM_EFECTE - 4.0, 0.0, &"Interfata")
	_camp.text = "Message"
	_camp.add_theme_color_override("font_color", C_SLAB)
	_trimite.add_theme_stylebox_override("panel", _cutie(C_RAMA, 9))
	_bula(continut, true)


func _asteapta(secunde: float) -> void:
	await get_tree().create_timer(secunde).timeout


# ---------------------------------------------------------------- toată scena

func _ruleaza() -> void:
	Stare.meniu_deschis = true
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	var cap := jucator.get_node("Cap") as Node3D if jucator else null
	var privire_inainte := cap.rotation.x if cap else 0.0
	# 1. vibrează în buzunar (de două ori)
	Sunet.reda(SUNET_VIBRATIE, Sunet.VOLUM_EFECTE)
	await _asteapta(1.4)
	# 2. îl scoți: urcă din colțul de jos, capul se apleacă spre el, lumea din jur se întunecă puțin
	Sunet.reda(SUNET_BUZUNAR, Sunet.VOLUM_EFECTE - 3.0, 0.05)
	_corp.rotation = 0.25
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "_sus", 1.0, 0.65)
	t.tween_property(_corp, "rotation", -0.035, 0.65)
	t.tween_property(_umbra, "color:a", 0.45, 0.65)
	if cap:
		t.tween_property(cap, "rotation:x", -0.3, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	# 3. notificarea coboară pe ecranul blocat
	await _asteapta(0.35)
	Sunet.reda(SUNET_NOTIFICARE, Sunet.VOLUM_EFECTE - 2.0)
	_notificare.position.y -= 14
	t = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_notificare, "position:y", _notificare.position.y + 14, 0.3)
	t.tween_property(_notificare, "modulate:a", 1.0, 0.2)
	await _asteapta(1.9)
	# 4. o apeși: se deschide conversația (vine din dreapta)
	Sunet.reda(SUNET_TASTA, Sunet.VOLUM_EFECTE - 4.0)
	t = create_tween()
	t.tween_property(_notificare, "scale", Vector2(0.94, 0.94), 0.08)
	t.tween_property(_notificare, "scale", Vector2.ONE, 0.1)
	await t.finished
	t = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_chat, "position:x", 0.0, 0.35)
	t.tween_property(_blocat, "position:x", -_ecran.size.x * 0.3, 0.35)
	await t.finished
	_blocat.hide()
	# 5. conversația: primul mesaj al ei e deja acolo (din notificare)
	var ultimul_al_meu: Control = null
	for i in mesaje.size():
		var replica := mesaje[i]
		var continut := _fara_nume(replica)
		if _e_al_meu(replica):
			await _asteapta(0.9)
			ultimul_al_meu = await _scrie_tu_si_bula(continut)
		elif i == 0:
			_bula(continut, false)
			await _asteapta(maxf(1.4, continut.length() * 0.06))
		else:
			await _scrie_ea(clampf(continut.length() * 0.04, 1.0, 2.2))
			Sunet.reda(SUNET_PRIMIT, Sunet.VOLUM_EFECTE - 4.0)
			_bula(continut, false)
			await _asteapta(maxf(1.6, continut.length() * 0.065))
	# 6. „Seen” sub ultimul tău mesaj
	await _asteapta(1.0)
	if ultimul_al_meu:
		var vazut := _text("Seen", 6, C_SLAB)
		vazut.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_lista.add_child(vazut)
		vazut.modulate.a = 0.0
		create_tween().tween_property(vazut, "modulate:a", 1.0, 0.3)
	await _asteapta(1.6)
	# 7. îl bagi la loc în buzunar
	Sunet.reda(SUNET_BUZUNAR, Sunet.VOLUM_EFECTE - 3.0, 0.05, &"Efecte", 1.1)
	t = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(self, "_sus", 0.0, 0.5)
	t.tween_property(_corp, "rotation", 0.2, 0.5)
	t.tween_property(_umbra, "color:a", 0.0, 0.5)
	if cap:
		t.tween_property(cap, "rotation:x", privire_inainte, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	Stare.meniu_deschis = false


func _scrie_tu_si_bula(continut: String) -> Control:
	await _scrie_tu(continut)
	return _lista.get_child(_lista.get_child_count() - 1) as Control
