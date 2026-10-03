class_name MeniuNume
extends CanvasLayer
## Meniul în care jucătorul își scrie numele. Se deschide din cod:
##   var meniu := MeniuNume.new()
##   get_tree().root.add_child(meniu)
##   var nume: String = await meniu.ales
## După nume vine o întrebare cu OK / No. Orice răspunde, meniul se închide la fel.

signal ales(nume: String)

const SUNET_STING := preload("res://sunete/ui_sting.ogg")
const SUNET_TASTA := preload("res://sunete/dialog_voce.ogg")

## Titlul de la primul pas.
@export var titlu := "WHAT IS YOUR NAME?"
## Textul gri din căsuța goală.
@export var indiciu_casuta := "Type your name..."
## Întrebarea de la al doilea pas (orice nume ai scrie, jocul tot așa te strigă).
@export var intrebare := "Are you sure your name is little bitch?"
## Câte litere poate avea numele.
@export var lungime_maxima := 16

var _casuta: LineEdit
var _ok_nume: Button
var _pas_nume: VBoxContainer
var _pas_intrebare: VBoxContainer


func _ready() -> void:
	layer = 20
	Stare.meniu_deschis = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var fundal := ColorRect.new()
	fundal.color = Color("262d2fd9")
	fundal.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fundal)  # oprește click-urile să ajungă la joc

	var centru := CenterContainer.new()
	centru.set_anchors_preset(Control.PRESET_FULL_RECT)
	centru.theme = TemaMeniu.creeaza()
	add_child(centru)
	var panou := PanelContainer.new()
	centru.add_child(panou)
	var continut := VBoxContainer.new()
	panou.add_child(continut)

	# pasul 1: numele
	_pas_nume = _pas(continut, titlu)
	_casuta = LineEdit.new()
	_casuta.placeholder_text = indiciu_casuta
	_casuta.max_length = lungime_maxima
	_casuta.custom_minimum_size.x = 170
	_casuta.text_changed.connect(_scris)
	_casuta.text_submitted.connect(func(_t: String) -> void: _confirma_nume())
	_pas_nume.add_child(_casuta)
	_ok_nume = _buton(_pas_nume, "OK", _confirma_nume)
	_ok_nume.disabled = true

	# pasul 2: întrebarea
	_pas_intrebare = _pas(continut, intrebare)
	var rand := HBoxContainer.new()
	rand.alignment = BoxContainer.ALIGNMENT_CENTER
	rand.add_theme_constant_override("separation", 12)
	_pas_intrebare.add_child(rand)
	_buton(rand, "OK", _termina)
	_buton(rand, "No", _termina)
	_pas_intrebare.hide()

	_casuta.grab_focus.call_deferred()


func _pas(parinte: Control, text: String) -> VBoxContainer:
	var pas := VBoxContainer.new()
	pas.add_theme_constant_override("separation", 8)
	var eticheta := Label.new()
	eticheta.text = text
	eticheta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eticheta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eticheta.custom_minimum_size.x = 200
	pas.add_child(eticheta)
	parinte.add_child(pas)
	return pas


func _buton(parinte: Control, text: String, la_apasare: Callable) -> Button:
	return TemaMeniu.buton(parinte, text, la_apasare)


func _nume_curat() -> String:
	return _casuta.text.strip_edges()


func _confirma_nume() -> void:
	if _nume_curat().is_empty():
		return
	_pas_nume.hide()
	_pas_intrebare.show()
	Sunet.reda(SUNET_STING, Sunet.VOLUM_EFECTE, 0.0, &"Interfata")
	_pas_intrebare.get_child(1).get_child(0).grab_focus()


func _termina() -> void:
	Stare.meniu_deschis = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ales.emit(_nume_curat())
	queue_free()


func _scris(_text: String) -> void:
	_ok_nume.disabled = _nume_curat().is_empty()
	Sunet.reda(SUNET_TASTA, Sunet.VOLUM_EFECTE, 0.1, &"Interfata", 1.6)
