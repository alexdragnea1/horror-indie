class_name Inventar
extends Control
## Fereastra de inventar (o deschide Stare cu Tab): sloturile în stânga, sarcina curentă în dreapta.
## Nu ține minte nimic singură: Stare îi dă obiectele și sarcina cu actualizeaza().
## Sloturile se apasă cu mouse-ul (`slot_apasat`): Stare pune obiectul în mână. Slotul din mână are ramă deschisă
## și scrie „IN HAND” sub nume. Click dreapta (`slot_aruncat`) = îl arunci pe jos.

signal slot_apasat(index: int)
## Click dreapta pe un slot: Stare aruncă obiectul pe jos.
signal slot_aruncat(index: int)

const MARIME_SLOT := 44

var _sloturi: Array[Label] = []
var _in_mana: Array[Label] = []
var _peste := -1
var _ultimele: Array = []
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
	ajutor.text = "[Click] Hold in hand   [Right click] Drop   [Tab] Close"
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
func actualizeaza(obiecte: Dictionary, sarcina: String, in_mana := "") -> void:
	var nume := obiecte.values()
	var iduri := obiecte.keys()
	_ultimele = [nume, iduri, in_mana]
	for i in _sloturi.size():
		var plin := i < nume.size()
		var tinut: bool = plin and iduri[i] == in_mana
		_sloturi[i].text = str(nume[i]) if plin else ""
		_in_mana[i].visible = tinut
		_coloreaza(i, plin, tinut)
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
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var index := numar - 1
	slot.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			slot_apasat.emit(index)
		elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			slot_aruncat.emit(index))
	slot.mouse_entered.connect(_la_mouse.bind(index, true))
	slot.mouse_exited.connect(_la_mouse.bind(index, false))
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
	var tinut := Label.new()  # „IN HAND”, jos, pe slotul din mână
	tinut.text = "IN HAND"
	tinut.add_theme_font_size_override("font_size", 6)
	tinut.add_theme_color_override("font_color", Color("a18463"))
	tinut.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tinut.size_flags_vertical = Control.SIZE_SHRINK_END
	tinut.hide()
	slot.add_child(tinut)
	_in_mana.append(tinut)
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


## Rama slotului: plin / gol, în mână (ramă deschisă, fundal mai cald), sub mouse (ramă albăstruie).
func _coloreaza(i: int, plin: bool, tinut: bool) -> void:
	var fundal := Color("48313b") if plin else Color("2a3c3d")
	var margine := Color("a18463") if plin else Color("5e5356")
	if tinut:
		fundal = Color("7b383a")
		margine = Color("83b3b0")
	elif i == _peste:
		margine = Color("438b88")
	(_sloturi[i].get_parent() as PanelContainer).add_theme_stylebox_override("panel", _cutie(fundal, margine, 2))


func _la_mouse(i: int, intra: bool) -> void:
	_peste = i if intra else (-1 if _peste == i else _peste)
	if _ultimele.size() == 3:
		var plin: bool = i < _ultimele[0].size()
		_coloreaza(i, plin, plin and _ultimele[1][i] == _ultimele[2])
