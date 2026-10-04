class_name PanouSetari
extends CenterContainer
## Ecranul de setări (Fullscreen, volumele, tastele), același în meniul principal și în pauză.
##   var setari := PanouSetari.new()
##   parinte.add_child(setari)
##   setari.inapoi.connect(...)   -> butonul Back (Esc îl tratează cine folosește panoul)
##   setari.deschide()            -> reîmprospătează valorile și pune focusul pe primul buton
## Cât așteaptă o tastă nouă („Press a key”), panoul prinde el orice tastă, inclusiv Esc (= anulează).

signal inapoi

const SUNET_CLIC := preload("res://sunete/ui_clic.ogg")

var _ecran_complet: Button
var _glisoare := {}
var _procente := {}
var _butoane_taste := {}
var _mesaj_taste: Label
var _asteapta_tasta := ""
var _ultim_clic := 0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_construieste()


func deschide() -> void:
	_asteapta_tasta = ""
	_mesaj_taste.text = ""
	_ecran_complet.text = "On" if Setari.ecran_complet else "Off"  # F11 îl poate schimba oricând
	_pune_volum("muzica", Setari.volum_muzica)
	_pune_volum("efecte", Setari.volum_efecte)
	_actualizeaza_taste()
	_ecran_complet.grab_focus.call_deferred()


func _pune_volum(tip: String, valoare: float) -> void:
	_glisoare[tip].set_value_no_signal(valoare)
	_procente[tip].text = "%d%%" % roundi(valoare * 100)


## Adevărat cât scrie „Press a key” (atunci Esc nu înseamnă „înapoi”).
func asteapta_tasta() -> bool:
	return not _asteapta_tasta.is_empty()


func _input(event: InputEvent) -> void:
	if _asteapta_tasta.is_empty() or not is_visible_in_tree():
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
		Sunet.reda(SUNET_CLIC, Sunet.VOLUM_EFECTE, 0.05, &"Interfata")
	_actualizeaza_taste()
	_butoane_taste[actiune].grab_focus()


func _construieste() -> void:
	var panou := PanelContainer.new()
	add_child(panou)
	# 480×270 e puțin: aici butoanele sunt mai scunde, ca să încapă toate tastele
	var tema := TemaMeniu.creeaza()
	for stil in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var cutie: StyleBoxFlat = tema.get_stylebox(stil, "Button")
		cutie.content_margin_top = 1
		cutie.content_margin_bottom = 1
	var cutie_panou: StyleBoxFlat = tema.get_stylebox("panel", "PanelContainer")
	cutie_panou.content_margin_top = 6
	cutie_panou.content_margin_bottom = 6
	panou.theme = tema
	var continut := VBoxContainer.new()
	continut.add_theme_constant_override("separation", 4)
	panou.add_child(continut)
	var titlu := Label.new()
	titlu.text = "SETTINGS"
	titlu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titlu.add_theme_color_override("font_color", TemaMeniu.ACCENT)
	continut.add_child(titlu)
	var coloane := HBoxContainer.new()
	coloane.add_theme_constant_override("separation", 22)
	continut.add_child(coloane)

	var stanga := VBoxContainer.new()
	stanga.add_theme_constant_override("separation", 5)
	coloane.add_child(stanga)
	stanga.add_child(_antet("DISPLAY"))
	_ecran_complet = _rand_buton(stanga, "Fullscreen", func() -> void:
		Setari.seteaza_ecran_complet(not Setari.ecran_complet)
		_ecran_complet.text = "On" if Setari.ecran_complet else "Off")
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

	continut.add_child(_spatiu(2))
	TemaMeniu.buton(continut, "Back", func() -> void: inapoi.emit())


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
	_glisoare[tip] = glisor
	var procent := Label.new()
	procent.custom_minimum_size.x = 28
	procent.add_theme_font_size_override("font_size", 10)
	procent.text = "%d%%" % roundi(valoare * 100)
	rand.add_child(procent)
	_procente[tip] = procent
	glisor.value_changed.connect(func(v: float) -> void:
		procent.text = "%d%%" % roundi(v * 100)
		Setari.seteaza_volum(tip, v)
		# la efecte se aude un clic, ca să știi cât de tare e
		var acum := Time.get_ticks_msec()
		if tip == "efecte" and acum - _ultim_clic > 90:
			_ultim_clic = acum
			Sunet.reda(SUNET_CLIC, Sunet.VOLUM_EFECTE, 0.05, &"Interfata"))


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
