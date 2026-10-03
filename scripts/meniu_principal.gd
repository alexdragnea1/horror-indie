extends Node3D
## Meniul principal (prima scenă a jocului): Start / Continue, Select Save File, Settings, Quit.
## În spate e curtea blocului adevărată (afara_bloc.tscn, fără jucător), văzută de o cameră care
## plutește încet. Toată interfața e făcută din cod, cu TemaMeniu.
## Esc = înapoi. Setările le ține Setari, fișierele de salvare Salvare.

const SCENA_FUNDAL := "res://scenes/afara_bloc.tscn"
const SUNET_STING := preload("res://sunete/ui_sting.ogg")
const SUNET_CLIC := preload("res://sunete/ui_clic.ogg")

## De unde se uită camera și spre ce (în coordonatele scenei de afară).
@export var pozitie_camera := Vector3(1.2, 1.35, 10.4)
@export var tinta_camera := Vector3(-4.5, 1.2, 7.8)
## Cât de mult plutește camera (metri).
@export var plutire := 0.2
@export var volum_muzica_db := -6.0

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
var _ecran_complet: Button
var _procente := {}
var _butoane_taste := {}
var _mesaj_taste: Label
var _asteapta_tasta := ""
var _timp := 0.0
var _ultim_clic := 0.0
var _plecat := false


func _ready() -> void:
	Salvare.in_joc = false
	Stare.meniu_deschis = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fundal()
	_interfata()
	_arata("principal")
	_muzica.volume_db = -40.0
	_muzica.play()
	create_tween().tween_property(_muzica, "volume_db", volum_muzica_db, 3.0)


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


func _input(event: InputEvent) -> void:
	if _asteapta_tasta.is_empty():
		return
	var e_tasta: bool = event is InputEventKey and event.pressed and not event.echo
	var e_mouse: bool = event is InputEventMouseButton and event.pressed
	if not (e_tasta or e_mouse):
		return
	get_viewport().set_input_as_handled()
	var actiune := _asteapta_tasta
	_asteapta_tasta = ""
	if e_tasta and event.physical_keycode == KEY_ESCAPE:
		_mesaj_taste.text = ""
	else:
		var schimbata := Setari.schimba_tasta(actiune, event)
		_mesaj_taste.text = ("Swapped with " + schimbata) if not schimbata.is_empty() else ""
		Sunet.reda(SUNET_CLIC, -8.0, 0.05, &"Interfata")
	_actualizeaza_taste()
	_butoane_taste[actiune].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _ecran_curent != "principal" and not _plecat:
		get_viewport().set_input_as_handled()
		Sunet.reda(SUNET_CLIC, -8.0, 0.05, &"Interfata")
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


func _arata(nume: String) -> void:
	_ecran_curent = nume
	_asteapta_tasta = ""
	for cheie in _ecrane:
		_ecrane[cheie].visible = cheie == nume
	match nume:
		"principal":
			_actualizeaza_principal()
			_buton_start.grab_focus.call_deferred()
		"salvari":
			_actualizeaza_salvari()
		"setari":
			_mesaj_taste.text = ""
			_actualizeaza_taste()
			_ecran_complet.grab_focus.call_deferred()
		"confirmare":
			_confirmare_text.text = "Delete File %d?\nThis can't be undone." % _de_sters


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
	_titlu.text = String(ProjectSettings.get_setting("application/config/name")).to_upper()
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
	if _plecat:
		return
	_plecat = true
	for ecran in _ecrane.values():
		ecran.propagate_call("set", ["disabled", true])
	Sunet.reda(SUNET_STING, -8.0, 0.0, &"Interfata")
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	if Salvare.exista(Setari.slot):
		Salvare.continua()
	else:
		Salvare.joc_nou()


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
	var panou := _panou(parinte, "SETTINGS")
	# 480×270 e puțin: aici butoanele sunt mai scunde, ca să încapă toate tastele
	var tema := TemaMeniu.creeaza()
	for stil in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var cutie: StyleBoxFlat = tema.get_stylebox(stil, "Button")
		cutie.content_margin_top = 1
		cutie.content_margin_bottom = 1
	var cutie_panou: StyleBoxFlat = tema.get_stylebox("panel", "PanelContainer")
	cutie_panou.content_margin_top = 6
	cutie_panou.content_margin_bottom = 6
	panou.get_parent().theme = tema
	panou.add_theme_constant_override("separation", 4)
	var coloane := HBoxContainer.new()
	coloane.add_theme_constant_override("separation", 22)
	panou.add_child(coloane)

	var stanga := VBoxContainer.new()
	stanga.add_theme_constant_override("separation", 5)
	coloane.add_child(stanga)
	stanga.add_child(_antet("DISPLAY"))
	_ecran_complet = _rand_buton(stanga, "Fullscreen", func() -> void:
		Setari.seteaza_ecran_complet(not Setari.ecran_complet)
		_ecran_complet.text = "On" if Setari.ecran_complet else "Off")
	_ecran_complet.text = "On" if Setari.ecran_complet else "Off"
	stanga.add_child(_spatiu(4))
	stanga.add_child(_antet("AUDIO"))
	_rand_volum(stanga, "Music", "muzica", Setari.volum_muzica)
	_rand_volum(stanga, "Effects", "efecte", Setari.volum_efecte)

	var dreapta := VBoxContainer.new()
	dreapta.add_theme_constant_override("separation", 2)
	coloane.add_child(dreapta)
	dreapta.add_child(_antet("CONTROLS"))
	for pereche in Setari.ACTIUNI:
		var actiune: String = pereche[0]
		_butoane_taste[actiune] = _rand_buton(dreapta, pereche[1], func() -> void:
			_asteapta_tasta = actiune
			_butoane_taste[actiune].text = "Press a key"
			_mesaj_taste.text = "Esc = cancel")
	var jos := HBoxContainer.new()
	jos.add_theme_constant_override("separation", 6)
	dreapta.add_child(jos)
	var reset := TemaMeniu.buton(jos, "Reset controls", func() -> void:
		Setari.reseteaza_tastele()
		_mesaj_taste.text = ""
		_actualizeaza_taste())
	reset.add_theme_font_size_override("font_size", 10)
	_mesaj_taste = Label.new()
	_mesaj_taste.add_theme_font_size_override("font_size", 9)
	_mesaj_taste.add_theme_color_override("font_color", TemaMeniu.ACCENT)
	jos.add_child(_mesaj_taste)

	panou.add_child(_spatiu(2))
	TemaMeniu.buton(panou, "Back", func() -> void: _arata("principal"))
	return panou.get_parent().get_parent()


func _actualizeaza_taste() -> void:
	for actiune in _butoane_taste:
		_butoane_taste[actiune].text = Setari.nume_tasta(actiune)


func _rand_buton(parinte: Control, text: String, la_apasare: Callable) -> Button:
	var rand := HBoxContainer.new()
	parinte.add_child(rand)
	rand.add_child(_eticheta_rand(text))
	var buton := TemaMeniu.buton(rand, "", la_apasare)
	buton.custom_minimum_size = Vector2(78, 0)
	buton.add_theme_font_size_override("font_size", 10)
	return buton


func _rand_volum(parinte: Control, text: String, tip: String, valoare: float) -> void:
	var rand := HBoxContainer.new()
	rand.add_theme_constant_override("separation", 6)
	parinte.add_child(rand)
	rand.add_child(_eticheta_rand(text))
	var glisor := HSlider.new()
	glisor.min_value = 0.0
	glisor.max_value = 1.0
	glisor.step = 0.05
	glisor.value = valoare
	glisor.custom_minimum_size = Vector2(80, 12)
	glisor.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rand.add_child(glisor)
	var procent := Label.new()
	procent.custom_minimum_size.x = 28
	procent.add_theme_font_size_override("font_size", 10)
	procent.text = "%d%%" % roundi(valoare * 100)
	rand.add_child(procent)
	glisor.value_changed.connect(func(v: float) -> void:
		Setari.seteaza_volum(tip, v)
		procent.text = "%d%%" % roundi(v * 100)
		# la efecte se aude un clic, ca să știi cât de tare e
		if tip == "efecte" and _timp - _ultim_clic > 0.09:
			_ultim_clic = _timp
			Sunet.reda(SUNET_CLIC, -8.0, 0.05, &"Interfata"))


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


func _antet(text: String) -> Label:
	var eticheta := Label.new()
	eticheta.text = text
	eticheta.add_theme_font_size_override("font_size", 9)
	eticheta.add_theme_color_override("font_color", TemaMeniu.STINS)
	return eticheta


func _eticheta_rand(text: String) -> Label:
	var eticheta := Label.new()
	eticheta.text = text
	eticheta.custom_minimum_size.x = 70
	eticheta.add_theme_font_size_override("font_size", 10)
	return eticheta


func _spatiu(inaltime: int) -> Control:
	var spatiu := Control.new()
	spatiu.custom_minimum_size.y = inaltime
	return spatiu
