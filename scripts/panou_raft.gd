class_name PanouRaft
extends Control
## Fereastra raftului din camera ta (o deschide Stare când apeși E pe raft): sus compartimentele raftului, jos
## inventarul. Click pe un obiect din inventar = îl pui pe raft; click pe unul de pe raft = îl iei înapoi.
## Nu ține minte nimic singură: Stare îi dă ce e pe raft și în inventar (actualizeaza) și mută obiectele.

signal raft_apasat(index: int)
signal inventar_apasat(index: int)

const MARIME_SLOT := 44

var _raft: Array[Label] = []
var _inventar: Array[Label] = []


func _init(locuri_raft: int, locuri_inventar: int) -> void:
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
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panou.add_child(col)
	col.add_child(_titlu("SHELF"))
	col.add_child(_rand(locuri_raft, _raft, raft_apasat))
	col.add_child(_titlu("INVENTORY"))
	col.add_child(_rand(locuri_inventar, _inventar, inventar_apasat))
	var ajutor := Label.new()
	ajutor.text = "[Click] Move   [E] Close"
	ajutor.add_theme_font_size_override("font_size", 8)
	ajutor.add_theme_color_override("font_color", Color("5e5356"))
	col.add_child(ajutor)


## raft și obiecte = id -> nume, în ordine.
func actualizeaza(raft: Dictionary, obiecte: Dictionary) -> void:
	_umple(_raft, raft)
	_umple(_inventar, obiecte)


func _umple(sloturi: Array[Label], continut: Dictionary) -> void:
	var nume := continut.values()
	for i in sloturi.size():
		var plin := i < nume.size()
		sloturi[i].text = str(nume[i]) if plin else ""
		(sloturi[i].get_parent() as PanelContainer).add_theme_stylebox_override("panel",
			_cutie(Color("48313b") if plin else Color("2a3c3d"), Color("a18463") if plin else Color("5e5356"), 2))


func _rand(numar: int, sloturi: Array[Label], semnal: Signal) -> HBoxContainer:
	var rand := HBoxContainer.new()
	rand.add_theme_constant_override("separation", 4)
	for i in numar:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(MARIME_SLOT, MARIME_SLOT)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var index := i
		slot.gui_input.connect(func(ev: InputEvent) -> void:
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				semnal.emit(index))
		var nume := Label.new()
		nume.add_theme_font_size_override("font_size", 8)
		nume.add_theme_color_override("font_color", Color("83b3b0"))
		nume.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nume.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		nume.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nume.max_lines_visible = 3
		slot.add_child(nume)
		sloturi.append(nume)
		rand.add_child(slot)
	return rand


func _titlu(text: String) -> Label:
	var eticheta := Label.new()
	eticheta.text = text
	eticheta.add_theme_color_override("font_color", Color("83b3b0"))
	return eticheta


func _tema() -> Theme:
	var tema := Theme.new()
	tema.default_font_size = 11
	tema.set_stylebox("panel", "PanelContainer", _cutie(Color("262d2f"), Color("a18463"), 10))
	return tema


func _cutie(fundal: Color, margine: Color, spatiu: int) -> StyleBoxFlat:
	var cutie := StyleBoxFlat.new()
	cutie.bg_color = fundal
	cutie.border_color = margine
	cutie.set_border_width_all(1)
	cutie.set_content_margin_all(spatiu)
	return cutie
