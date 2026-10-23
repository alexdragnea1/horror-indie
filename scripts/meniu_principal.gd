extends Node3D
## Meniul principal (prima scenă a jocului): Start / Continue, Select Save File, Settings, Quit, plus butonul mic
## „Music” din dreapta jos (cine a făcut muzica, `MUZICA`).
## În spate e curtea blocului adevărată (afara_bloc.tscn, fără jucător), văzută de o cameră care
## plutește încet. Toată interfața e făcută din cod, cu TemaMeniu.
## Esc = înapoi. Setările le ține Setari, fișierele de salvare Salvare.

const SCENA_FUNDAL := "res://scenes/afara_bloc.tscn"
const SUNET_STING := preload("res://sunete/ui_sting.ogg")
const SUNET_CLIC := preload("res://sunete/ui_clic.ogg")
## Numele jocului din meniu. Nu e `application/config/name` („Horror Indie”): pe ăla îl folosește Godot și pentru
## folderul salvărilor (app_userdata\Horror Indie), deci dacă l-am schimba s-ar pierde salvările.
const TITLU := "Unlucky Spells"
## Ecranul „Music” (butonul mic din dreapta jos, owner 17.10): cine a făcut muzica, fără locul din joc.
## [artist, [piese], notă mică (licența) sau ""]. Luate din etichetele fișierelor din Sound/Music.
const MUZICA := [
	["Human Gazpacho (CW Lomneth)", ["Ranger's Lament", "Necromancy in the Underdark", "Antechamber of Madness",
		"That Slowmotion Montage Where We Fall in Love", "Cryptic Chamber"], ""],
	["Ion (Romania) feat. Herodot", ["I.E"], "CC BY-NC-SA 3.0 - freemusicarchive.org"],
	["Made with Udio", ["Whispers of the Void"], ""],
]

## De unde se uită camera și spre ce (în coordonatele scenei de afară).
@export var pozitie_camera := Vector3(1.2, 1.35, 10.4)
@export var tinta_camera := Vector3(-4.5, 1.2, 7.8)
## Cât de mult plutește camera (metri).
@export var plutire := 0.2
## 0 = Sunet.VOLUM_MUZICA (la fel de tare ca efectele).
@export var volum_muzica_db := 0.0

@onready var _muzica: AudioStreamPlayer = $Muzica

var _camera: Camera3D
var _ecrane := {}
var _ecran_curent := ""
var _titlu: Label
var _buton_start: Button
var _info_fisier: Label
var _randuri_salvari: VBoxContainer
var _confirmare_text: Label
var _de_sters := 0
var _setari: PanouSetari
var _grila_controale: GridContainer
var _buton_joaca: Button
var _buton_familie_nu: Button
## Ce ai ales la „family friendly” pentru jocul nou (Stare.familie, vezi Limbaj).
var _familie := false
var _buton_muzica: Button
var _timp := 0.0
var _plecat := false
## Loading screen-ul apare doar la prima deschidere a meniului de la pornirea jocului, nu și când revii din joc.
static var _a_pornit := false


func _ready() -> void:
	Salvare.in_joc = false
	Stare.meniu_deschis = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_process(false)
	# prima dată de la pornirea jocului: loading screen cât se încarcă curtea din fundal (owner 23.10)
	var ecran: EcranIncarcare = null
	if not _a_pornit:
		_a_pornit = true
		ecran = EcranIncarcare.new()
		add_child(ecran)
		await ecran.incarca([SCENA_FUNDAL])
	_fundal()
	_interfata()
	_arata("principal")
	_muzica.volume_db = -40.0
	_muzica.play()
	create_tween().tween_property(_muzica, "volume_db", volum_muzica_db, 3.0)
	set_process(true)
	if ecran:
		ecran.dispare()


func _process(delta: float) -> void:
	_timp += delta
	_camera.position = pozitie_camera + Vector3(sin(_timp * 0.13), sin(_timp * 0.21) * 0.3, cos(_timp * 0.09) * 0.6) * plutire
	_camera.look_at(tinta_camera + Vector3(sin(_timp * 0.07) * 0.3, 0, 0))
	# titlul pâlpâie din când în când, ca un neon pe ducă
	if _titlu.modulate.a >= 1.0 and randf() < delta * 0.25:
		var t := create_tween()
		for i in randi_range(1, 3):
			t.tween_property(_titlu, "modulate:a", randf_range(0.2, 0.6), 0.04)
			t.tween_property(_titlu, "modulate:a", 1.0, 0.06)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _ecran_curent not in ["principal", ""] and not _plecat:
		get_viewport().set_input_as_handled()
		Sunet.reda(SUNET_CLIC, Sunet.VOLUM_EFECTE, 0.05, &"Interfata")
		_arata("salvari" if _ecran_curent == "confirmare" else "principal")


# ---------------------------------------------------------------- fundalul 3D

func _fundal() -> void:
	var lume: Node = load(SCENA_FUNDAL).instantiate()
	var jucator := lume.get_node_or_null("Jucator")
	if jucator:
		lume.remove_child(jucator)
		jucator.free()
	add_child(lume)
	_camera = Camera3D.new()
	_camera.fov = 62.0
	add_child(_camera)
	_camera.make_current()


# ---------------------------------------------------------------- interfața

func _interfata() -> void:
	var strat := CanvasLayer.new()
	strat.layer = 5
	add_child(strat)
	var radacina := Control.new()
	radacina.set_anchors_preset(Control.PRESET_FULL_RECT)
	radacina.theme = TemaMeniu.creeaza()
	strat.add_child(radacina)

	# umbra din stânga, ca textul să se citească peste curte
	var umbra := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(TemaMeniu.FUNDAL, 0.92))
	gradient.set_color(1, Color(TemaMeniu.FUNDAL, 0.0))
	var textura := GradientTexture2D.new()
	textura.gradient = gradient
	textura.fill_to = Vector2(1, 0)
	umbra.texture = textura
	umbra.stretch_mode = TextureRect.STRETCH_SCALE
	umbra.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	umbra.custom_minimum_size.x = 260
	umbra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radacina.add_child(umbra)

	_ecrane["principal"] = _ecran_principal(radacina)
	_ecrane["salvari"] = _ecran_salvari(radacina)
	_ecrane["confirmare"] = _ecran_confirmare(radacina)
	_ecrane["setari"] = _ecran_setari(radacina)
	_ecrane["familie"] = _ecran_familie(radacina)
	_ecrane["controale"] = _ecran_controale(radacina)
	_ecrane["muzica"] = _ecran_muzica(radacina)

	# butonul mic „Music” din dreapta jos (doar pe ecranul principal)
	_buton_muzica = TemaMeniu.buton(radacina, "Music", func() -> void: _arata("muzica"))
	_buton_muzica.add_theme_font_size_override("font_size", 9)
	_buton_muzica.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	_buton_muzica.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_buton_muzica.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _arata(nume: String) -> void:
	_ecran_curent = nume
	for cheie in _ecrane:
		_ecrane[cheie].visible = cheie == nume
	_buton_muzica.visible = nume == "principal"
	match nume:
		"principal":
			_actualizeaza_principal()
			_buton_start.grab_focus.call_deferred()
		"salvari":
			_actualizeaza_salvari()
		"setari":
			_setari.deschide()
		"confirmare":
			_confirmare_text.text = "Delete File %d?\nThis can't be undone." % _de_sters
		"familie":
			_buton_familie_nu.grab_focus.call_deferred()
		"controale":
			_actualizeaza_controale()
			_buton_joaca.grab_focus.call_deferred()


func _ecran_principal(parinte: Control) -> Control:
	var ecran := MarginContainer.new()
	ecran.set_anchors_preset(Control.PRESET_FULL_RECT)
	ecran.add_theme_constant_override("margin_left", 30)
	parinte.add_child(ecran)
	var coloana := VBoxContainer.new()
	coloana.alignment = BoxContainer.ALIGNMENT_CENTER
	coloana.add_theme_constant_override("separation", 5)
	ecran.add_child(coloana)

	_titlu = Label.new()
	_titlu.text = TITLU.to_upper()
	_titlu.add_theme_font_size_override("font_size", 26)
	_titlu.add_theme_color_override("font_color", TemaMeniu.ACCENT)
	_titlu.add_theme_color_override("font_shadow_color", Color("7b383a"))
	_titlu.add_theme_constant_override("shadow_offset_x", 2)
	_titlu.add_theme_constant_override("shadow_offset_y", 2)
	coloana.add_child(_titlu)
	coloana.add_child(_spatiu(12))

	_buton_start = _buton_meniu(coloana, "Start", _start)
	_info_fisier = Label.new()
	_info_fisier.add_theme_font_size_override("font_size", 9)
	_info_fisier.add_theme_color_override("font_color", TemaMeniu.STINS)
	coloana.add_child(_info_fisier)
	coloana.add_child(_spatiu(2))
	_buton_meniu(coloana, "Select Save File", func() -> void: _arata("salvari"))
	_buton_meniu(coloana, "Settings", func() -> void: _arata("setari"))
	_buton_meniu(coloana, "Quit", func() -> void: get_tree().quit())
	return ecran


func _actualizeaza_principal() -> void:
	var date := Salvare.info(Setari.slot)
	_buton_start.text = "Continue" if not date.is_empty() else "Start"
	if date.is_empty():
		_info_fisier.text = "File %d  -  new game" % Setari.slot
	else:
		_info_fisier.text = "File %d  -  %s  -  %s" % [Setari.slot, date.get("loc", "?"), Salvare.timp_ca_text(date.get("timp", 0.0))]


func _start() -> void:
	# joc nou: întâi întrebarea „family friendly”, apoi ecranul cu toate tastele, abia de acolo pornește jocul
	if not Salvare.exista(Setari.slot) and _ecran_curent == "principal":
		Sunet.reda(SUNET_CLIC, Sunet.VOLUM_EFECTE, 0.05, &"Interfata")
		_arata("familie")
		return
	if _plecat:
		return
	_plecat = true
	for ecran in _ecrane.values():
		ecran.propagate_call("set", ["disabled", true])
	Sunet.reda(SUNET_STING, Sunet.VOLUM_EFECTE, 0.0, &"Interfata")
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if Salvare.exista(Setari.slot):
		Salvare.continua()
	else:
		Salvare.joc_nou(_familie)


# -------- fișierele de salvare

func _ecran_salvari(parinte: Control) -> Control:
	var panou := _panou(parinte, "SELECT SAVE FILE")
	_randuri_salvari = VBoxContainer.new()
	_randuri_salvari.add_theme_constant_override("separation", 6)
	panou.add_child(_randuri_salvari)
	panou.add_child(_spatiu(4))
	TemaMeniu.buton(panou, "Back", func() -> void: _arata("principal"))
	return panou.get_parent().get_parent()


func _actualizeaza_salvari() -> void:
	for copil in _randuri_salvari.get_children():
		copil.queue_free()
	var de_focus: Button
	for loc in range(1, Salvare.LOCURI + 1):
		var date := Salvare.info(loc)
		var rand := HBoxContainer.new()
		rand.add_theme_constant_override("separation", 6)
		_randuri_salvari.add_child(rand)
		var ales := loc == Setari.slot
		var text := "%s FILE %d" % [">" if ales else " ", loc]
		if date.is_empty():
			text += "\n   - empty -"
		else:
			var cine: String = date.get("stare", {}).get("nume_jucator", "")
			text += "   %s   %s\n   %s" % [date.get("loc", "?"), Salvare.timp_ca_text(date.get("timp", 0.0)),
				_scurt(date.get("stare", {}).get("sarcina", ""), cine)]
		var buton := TemaMeniu.buton(rand, text, _alege_slot.bind(loc))
		buton.custom_minimum_size = Vector2(230, 0)
		buton.alignment = HORIZONTAL_ALIGNMENT_LEFT
		buton.add_theme_font_size_override("font_size", 10)
		if ales:
			buton.add_theme_color_override("font_color", TemaMeniu.ACCENT)
			de_focus = buton
		var sterge := TemaMeniu.buton(rand, "Delete", func() -> void:
			_de_sters = loc
			_arata("confirmare"))
		sterge.add_theme_font_size_override("font_size", 10)
		sterge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sterge.disabled = date.is_empty()
	if de_focus:
		de_focus.grab_focus.call_deferred()


func _scurt(sarcina: String, nume: String) -> String:
	if not sarcina.is_empty():
		return "Task: " + sarcina
	return "\"%s\"" % nume if not nume.is_empty() else "Just woke up."


func _alege_slot(loc: int) -> void:
	Setari.seteaza_slot(loc)
	_arata("principal")


func _ecran_confirmare(parinte: Control) -> Control:
	var panou := _panou(parinte, "")
	_confirmare_text = panou.get_child(0)
	var rand := HBoxContainer.new()
	rand.alignment = BoxContainer.ALIGNMENT_CENTER
	rand.add_theme_constant_override("separation", 12)
	panou.add_child(rand)
	TemaMeniu.buton(rand, "Yes", func() -> void:
		Salvare.sterge(_de_sters)
		_arata("salvari"))
	var nu := TemaMeniu.buton(rand, "No", func() -> void: _arata("salvari"))
	panou.visibility_changed.connect(func() -> void:
		if panou.is_visible_in_tree():
			nu.grab_focus.call_deferred())
	return panou.get_parent().get_parent()


# -------- setările

func _ecran_setari(parinte: Control) -> Control:
	_setari = PanouSetari.new()
	_setari.inapoi.connect(func() -> void: _arata("principal"))
	parinte.add_child(_setari)
	return _setari


# -------- family friendly (owner 22.10: la un joc nou, înainte de controale)

func _ecran_familie(parinte: Control) -> Control:
	var panou := _panou(parinte, "Do you want the family friendly version?")
	var avertisment := Label.new()
	avertisment.text = "(Warning: Crude Language)"
	avertisment.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avertisment.add_theme_font_size_override("font_size", 10)
	avertisment.add_theme_color_override("font_color", TemaMeniu.STINS)
	panou.add_child(avertisment)
	panou.add_child(_spatiu(4))
	var rand := HBoxContainer.new()
	rand.alignment = BoxContainer.ALIGNMENT_CENTER
	rand.add_theme_constant_override("separation", 12)
	panou.add_child(rand)
	TemaMeniu.buton(rand, "Yes", _alege_familie.bind(true))
	_buton_familie_nu = TemaMeniu.buton(rand, "No", _alege_familie.bind(false))
	return panou.get_parent().get_parent()


func _alege_familie(da: bool) -> void:
	_familie = da
	_arata("controale")


# -------- controalele (apar o dată, la un joc nou)

func _ecran_controale(parinte: Control) -> Control:
	var panou := _panou(parinte, "CONTROLS")
	_grila_controale = GridContainer.new()
	_grila_controale.columns = 4  # două perechi tastă / ce face pe fiecare rând, ca să încapă pe înălțime
	_grila_controale.add_theme_constant_override("h_separation", 10)
	_grila_controale.add_theme_constant_override("v_separation", 3)
	panou.add_child(_grila_controale)
	panou.add_child(_spatiu(4))
	var rand := HBoxContainer.new()
	rand.alignment = BoxContainer.ALIGNMENT_CENTER
	rand.add_theme_constant_override("separation", 12)
	panou.add_child(rand)
	TemaMeniu.buton(rand, "Back", func() -> void: _arata("principal"))
	_buton_joaca = TemaMeniu.buton(rand, "Start", _start)
	return panou.get_parent().get_parent()


## Tastele se citesc din Setari la fiecare deschidere (pot fi schimbate din Settings).
func _actualizeaza_controale() -> void:
	for copil in _grila_controale.get_children():
		copil.queue_free()
	var randuri := []
	for pereche in Setari.ACTIUNI:
		# scutul îl înveți abia mai târziu (Head Witch, la apus): nu-l spunem de la început
		if pereche[0] == "scut":
			continue
		randuri.append([Setari.nume_tasta(pereche[0]), pereche[1]])
	randuri.append_array([
		["Mouse", "Look around"],
		["Left Click", "Shoot / use what you hold"],
		["Left Click", "Inventory: hold in hand"],
		["Right Click", "Inventory: drop"],
		["Esc", "Pause"],
		["F11", "Fullscreen"],
	])
	for rand in randuri:
		var tasta := Label.new()
		tasta.text = rand[0]
		tasta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tasta.add_theme_font_size_override("font_size", 10)
		tasta.add_theme_color_override("font_color", TemaMeniu.ACCENT)
		_grila_controale.add_child(tasta)
		var ce_face := Label.new()
		ce_face.text = rand[1]
		ce_face.add_theme_font_size_override("font_size", 10)
		_grila_controale.add_child(ce_face)


# -------- muzica (cine a făcut-o)

func _ecran_muzica(parinte: Control) -> Control:
	var panou := _panou(parinte, "MUSIC")
	for intrare in MUZICA:
		var artist := Label.new()
		artist.text = intrare[0]
		artist.add_theme_font_size_override("font_size", 10)
		artist.add_theme_color_override("font_color", TemaMeniu.ACCENT)
		panou.add_child(artist)
		var piese := Label.new()
		piese.text = "\n".join(PackedStringArray(intrare[1].map(func(p: String) -> String: return "   " + p)))
		piese.add_theme_font_size_override("font_size", 9)
		piese.add_theme_constant_override("line_spacing", -2)
		panou.add_child(piese)
		if intrare[2] != "":
			var nota := Label.new()
			nota.text = "   " + intrare[2]
			nota.add_theme_font_size_override("font_size", 8)
			nota.add_theme_color_override("font_color", TemaMeniu.STINS)
			panou.add_child(nota)
	panou.add_theme_constant_override("separation", 2)
	panou.add_child(_spatiu(4))
	var inapoi := TemaMeniu.buton(panou, "Back", func() -> void: _arata("principal"))
	panou.visibility_changed.connect(func() -> void:
		if panou.is_visible_in_tree():
			inapoi.grab_focus.call_deferred())
	return panou.get_parent().get_parent()


# -------- bucăți comune

func _panou(parinte: Control, titlu: String) -> VBoxContainer:
	var centru := CenterContainer.new()
	centru.set_anchors_preset(Control.PRESET_FULL_RECT)
	parinte.add_child(centru)
	var panou := PanelContainer.new()
	centru.add_child(panou)
	var continut := VBoxContainer.new()
	continut.add_theme_constant_override("separation", 6)
	panou.add_child(continut)
	var eticheta := Label.new()
	eticheta.text = titlu
	eticheta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eticheta.add_theme_color_override("font_color", TemaMeniu.ACCENT)
	continut.add_child(eticheta)
	return continut


func _buton_meniu(parinte: Control, text: String, la_apasare: Callable) -> Button:
	var buton := TemaMeniu.buton(parinte, text, la_apasare)
	buton.custom_minimum_size.x = 120
	buton.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	buton.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return buton


func _spatiu(inaltime: int) -> Control:
	var spatiu := Control.new()
	spatiu.custom_minimum_size.y = inaltime
	return spatiu
