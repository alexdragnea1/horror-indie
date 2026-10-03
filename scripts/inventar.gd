class_name Inventar
extends Control
## Fereastra de inventar (o deschide Stare cu Tab): sloturile în stânga, sarcina curentă în dreapta.
## Nu ține minte nimic singură: Stare îi dă obiectele și sarcina cu actualizeaza().

const MARIME_SLOT := 44

var _sloturi: Array[Label] = []
var _sarcina: Label


func _init(numar_sloturi: int) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _tema()

	var fundal := ColorRect.new()
	fundal.color = Color("262d2f99")
	fundal.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fundal)

	var centru := CenterContainer.new()
	centru.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centru)
	var panou := PanelContainer.new()
	centru.add_child(panou)
	var coloane := HBoxContainer.new()
	coloane.add_theme_constant_override("separation", 12)
	panou.add_child(coloane)

	# stânga: sloturile
	var stanga := VBoxContainer.new()
	stanga.add_theme_constant_override("separation", 6)
	coloane.add_child(stanga)
	stanga.add_child(_titlu("INVENTORY"))
	var rand := HBoxContainer.new()
	rand.add_theme_constant_override("separation", 4)
	stanga.add_child(rand)
	for i in numar_sloturi:
		rand.add_child(_slot(i + 1))
	var ajutor := Label.new()
	ajutor.text = "[Tab] Close"
	ajutor.add_theme_font_size_override("font_size", 8)
	ajutor.add_theme_color_override("font_color", Color("5e5356"))
	stanga.add_child(ajutor)

	coloane.add_child(VSeparator.new())

	# dreapta: sarcina curentă
	var dreapta := VBoxContainer.new()
	dreapta.add_theme_constant_override("separation", 6)
	coloane.add_child(dreapta)
	dreapta.add_child(_titlu("CURRENT TASK"))
	_sarcina = Label.new()
	_sarcina.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sarcina.custom_minimum_size.x = 110
	dreapta.add_child(_sarcina)


## obiecte = id -> nume (în ordinea în care le-ai luat); sarcina = "" dacă nu ai niciuna.
func actualizeaza(obiecte: Dictionary, sarcina: String) -> void:
	var nume := obiecte.values()
	for i in _sloturi.size():
		var plin := i < nume.size()
		_sloturi[i].text = str(nume[i]) if plin else ""
		(_sloturi[i].get_parent() as PanelContainer).add_theme_stylebox_override("panel",
			_cutie(Color("48313b") if plin else Color("2a3c3d"), Color("a18463") if plin else Color("5e5356"), 2))
	if sarcina.is_empty():
		_sarcina.text = "Nothing right now."
		_sarcina.add_theme_color_override("font_color", Color("5e5356"))
	else:
		_sarcina.text = sarcina
		_sarcina.add_theme_color_override("font_color", Color("a18463"))


func _titlu(text: String) -> Label:
	var eticheta := Label.new()
	eticheta.text = text
	eticheta.add_theme_color_override("font_color", Color("83b3b0"))
	return eticheta


func _slot(numar: int) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(MARIME_SLOT, MARIME_SLOT)
	var nume := Label.new()
	nume.add_theme_font_size_override("font_size", 8)
	nume.add_theme_color_override("font_color", Color("83b3b0"))
	nume.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nume.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nume.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nume.max_lines_visible = 3
	slot.add_child(nume)
	var cifra := Label.new()  # numărul slotului, mic, în colț
	cifra.text = str(numar)
	cifra.add_theme_font_size_override("font_size", 7)
	cifra.add_theme_color_override("font_color", Color("5e5356"))
	cifra.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cifra.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	slot.add_child(cifra)
	_sloturi.append(nume)
	return slot


func _tema() -> Theme:
	var tema := Theme.new()
	tema.default_font_size = 11
	tema.set_stylebox("panel", "PanelContainer", _cutie(Color("262d2f"), Color("a18463"), 10))
	var linie := StyleBoxLine.new()
	linie.color = Color("5e5356")
	linie.vertical = true
	tema.set_stylebox("separator", "VSeparator", linie)
	return tema


func _cutie(fundal: Color, margine: Color, spatiu: int) -> StyleBoxFlat:
	var cutie := StyleBoxFlat.new()
	cutie.bg_color = fundal
	cutie.border_color = margine
	cutie.set_border_width_all(1)
	cutie.set_content_margin_all(spatiu)
	return cutie
