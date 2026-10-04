extends CanvasLayer
## Autoload "Pauza": Esc în joc oprește tot și deschide meniul de pauză:
## Resume, Go to main menu, Settings, Quit. Esc din nou = înapoi / închide.
## Se deschide singur și când fereastra pierde focusul (Alt+Tab).
## Nu se deschide în meniul principal, în tranziții și cât e deschis alt meniu
## (inventarul, meniul cu numele: toate pun Stare.meniu_deschis).
## Jocul se salvează singur (Salvare), deci la Go to main menu / Quit doar mai salvăm o dată poziția.

const SCENA_MENIU := "res://scenes/meniu_principal.tscn"
const SUNET_DESCHIDE := preload("res://sunete/ui_clic.ogg")

var deschisa := false

var _radacina: Control
var _principal: Control
var _setari: PanouSetari
var _sarcina: Label
var _buton_reluare: Button


func _ready() -> void:
	layer = 15  # peste dialog (10), sub tranziție (20)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_radacina = Control.new()
	_radacina.set_anchors_preset(Control.PRESET_FULL_RECT)
	_radacina.theme = TemaMeniu.creeaza()
	_radacina.hide()
	add_child(_radacina)
	# lumea rămâne în spate, întunecată
	var umbra := ColorRect.new()
	umbra.color = Color(TemaMeniu.FUNDAL, 0.78)
	umbra.set_anchors_preset(Control.PRESET_FULL_RECT)
	_radacina.add_child(umbra)
	_principal = _ecran_principal()
	_radacina.add_child(_principal)
	_setari = PanouSetari.new()
	_setari.inapoi.connect(_arata_principal)
	_setari.hide()
	_radacina.add_child(_setari)


# _input (nu _unhandled_input), ca Esc să ajungă aici înaintea jucătorului.
func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if deschisa:
		get_viewport().set_input_as_handled()
		if _setari.visible:
			_arata_principal()
		else:
			reia()
	elif poate_deschide():
		get_viewport().set_input_as_handled()
		deschide()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not deschisa and poate_deschide():
		deschide()


func poate_deschide() -> bool:
	var scena := get_tree().current_scene
	return scena != null and scena.scene_file_path != SCENA_MENIU \
		and not Stare.meniu_deschis and not Tranzitie.activa


func deschide() -> void:
	deschisa = true
	get_tree().paused = true
	Stare.meniu_deschis = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_sarcina.text = ("Task: " + Stare.sarcina) if not Stare.sarcina.is_empty() else ""
	_sarcina.visible = not _sarcina.text.is_empty()
	_radacina.show()
	_arata_principal()
	Sunet.reda(SUNET_DESCHIDE, Sunet.VOLUM_EFECTE, 0.05, &"Interfata")


func reia() -> void:
	_inchide()
	get_tree().paused = false
	Stare.meniu_deschis = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _inchide() -> void:
	deschisa = false
	_radacina.hide()


func _arata_principal() -> void:
	_setari.hide()
	_principal.show()
	_buton_reluare.grab_focus.call_deferred()


func _arata_setari() -> void:
	_principal.hide()
	_setari.show()
	_setari.deschide()


func _meniu_principal() -> void:
	if Tranzitie.activa:
		return
	Salvare.salveaza(false)
	Salvare.in_joc = false
	_inchide()
	Stare.ascunde_mesaje()
	# lumea rămâne oprită cât se întunecă ecranul; Tranzitie o pornește în scena nouă
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	Tranzitie.mergi_la(SCENA_MENIU)


func _iesi() -> void:
	Salvare.salveaza(false)
	get_tree().quit()


func _ecran_principal() -> Control:
	var centru := CenterContainer.new()
	centru.set_anchors_preset(Control.PRESET_FULL_RECT)
	var panou := PanelContainer.new()
	centru.add_child(panou)
	var coloana := VBoxContainer.new()
	coloana.add_theme_constant_override("separation", 6)
	panou.add_child(coloana)
	var titlu := Label.new()
	titlu.text = "PAUSED"
	titlu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titlu.add_theme_font_size_override("font_size", 16)
	titlu.add_theme_color_override("font_color", TemaMeniu.ACCENT)
	coloana.add_child(titlu)
	_sarcina = Label.new()
	_sarcina.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sarcina.add_theme_font_size_override("font_size", 9)
	_sarcina.add_theme_color_override("font_color", TemaMeniu.STINS)
	coloana.add_child(_sarcina)
	var spatiu := Control.new()
	spatiu.custom_minimum_size.y = 4
	coloana.add_child(spatiu)
	_buton_reluare = _buton(coloana, "Resume", reia)
	_buton(coloana, "Go to main menu", _meniu_principal)
	_buton(coloana, "Settings", _arata_setari)
	_buton(coloana, "Quit", _iesi)
	return centru


func _buton(parinte: Control, text: String, la_apasare: Callable) -> Button:
	var buton := TemaMeniu.buton(parinte, text, la_apasare)
	buton.custom_minimum_size.x = 140
	return buton
