class_name UIGraffiti
extends CanvasLayer
## Interfața de la peretele cu graffiti (graffiti.gd): în stânga cutiile de spray (culorile, tastele 1–9), mărimea
## jetului, Undo / Clear / Done; jos ajutorul. Mouse-ul sistemului e ascuns: cursorul îl desenează ea, în pixeli mari ca
## restul jocului (pe perete un cerc cât jetul, în culoarea aleasă; peste panou o săgeată).
## Esc = gata (semnalul `inchis`).

signal culoare_aleasa(index: int)
signal marime_aleasa(index: int)
## rotița: -1 = mai mic, 1 = mai mare
signal marime_schimbata(pas: int)
signal anuleaza
signal sterge_tot
signal inchis

const MARIMI := ["S", "M", "L"]

var _casute: Array[Panel] = []
var _marimi: Array[Button] = []
var _culori: Array[Color] = []
var _buton_sterge: Button
var _confirma_stergerea := false
var _panou: PanelContainer
var _cursor: Control
## ce desenează cursorul: raza (în pixeli de ecran) și culoarea jetului; raza 0 = săgeată (peste panou)
var _raza_cursor := 0.0
var _culoare_cursor := Color.WHITE


func _init(culori: Array[Color]) -> void:
	_culori = culori


func _ready() -> void:
	layer = 7
	_construieste()
	alege_culoarea(0)
	alege_marimea(1)


func _construieste() -> void:
	_panou = PanelContainer.new()
	_panou.theme = TemaMeniu.creeaza()
	_panou.theme.default_font_size = 10
	_panou.add_theme_stylebox_override("panel", TemaMeniu.cutie(Color(TemaMeniu.FUNDAL, 0.92), TemaMeniu.ACCENT, 5))
	_panou.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_panou.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panou.offset_left = 6
	add_child(_panou)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_panou.add_child(col)
	var titlu := Label.new()
	titlu.text = "SPRAY"
	titlu.add_theme_color_override("font_color", TemaMeniu.ACCENT)
	titlu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(titlu)
	# cutiile: 3 × 3 pătrățele în culorile vopselei, cu tasta în colț
	var grila := GridContainer.new()
	grila.columns = 3
	grila.add_theme_constant_override("h_separation", 3)
	grila.add_theme_constant_override("v_separation", 3)
	col.add_child(grila)
	for i in _culori.size():
		var c := Panel.new()
		c.custom_minimum_size = Vector2(16, 16)
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.gui_input.connect(_clic_casuta.bind(i))
		var tasta := Label.new()
		tasta.text = str(i + 1)
		tasta.add_theme_font_size_override("font_size", 8)
		# cifra se citește pe orice culoare: deschisă pe cele închise, închisă pe cele deschise
		tasta.add_theme_color_override("font_color", TemaMeniu.FUNDAL if _culori[i].get_luminance() > 0.45 else TemaMeniu.TEXT)
		tasta.position = Vector2(2, 1)
		tasta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(tasta)
		grila.add_child(c)
		_casute.append(c)
	var rand := HBoxContainer.new()
	rand.add_theme_constant_override("separation", 2)
	rand.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(rand)
	for i in MARIMI.size():
		var b := Button.new()
		b.text = MARIMI[i]
		b.custom_minimum_size = Vector2(16, 0)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			Sunet.reda(TemaMeniu.SUNET_CLIC, Sunet.VOLUM_EFECTE, 0.05, &"Interfata")
			alege_marimea(i)
			marime_aleasa.emit(i))
		rand.add_child(b)
		_marimi.append(b)
	for nume in ["Undo", "Clear", "Done"]:
		var b := TemaMeniu.buton(col, nume, _apasat.bind(nume))
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_FILL
		if nume == "Clear":
			_buton_sterge = b
	var ajutor := Label.new()
	ajutor.text = "LMB spray  RMB wipe  Wheel size  1-9 color  Ctrl+Z undo  Esc done"
	ajutor.theme = _panou.theme
	ajutor.add_theme_color_override("font_color", TemaMeniu.TEXT)
	ajutor.add_theme_color_override("font_outline_color", TemaMeniu.FUNDAL)
	ajutor.add_theme_constant_override("outline_size", 3)
	ajutor.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	ajutor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ajutor.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ajutor.offset_bottom = -4
	add_child(ajutor)
	_cursor = Control.new()
	_cursor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.draw.connect(_deseneaza_cursorul)
	add_child(_cursor)


## Mouse-ul e peste panou (atunci nu se pictează și cursorul e săgeată).
func pe_panou() -> bool:
	return _panou.get_global_rect().grow(2).has_point(_cursor.get_global_mouse_position())


func alege_culoarea(i: int) -> void:
	for j in _casute.size():
		var stil := TemaMeniu.cutie(_culori[j], TemaMeniu.ACCENT if j == i else TemaMeniu.STINS, 0)
		stil.set_border_width_all(2 if j == i else 1)
		_casute[j].add_theme_stylebox_override("panel", stil)


func alege_marimea(i: int) -> void:
	for j in _marimi.size():
		_marimi[j].add_theme_color_override("font_color", TemaMeniu.ACCENT if j == i else TemaMeniu.STINS)


## Cursorul de pe perete: cerc de `raza` pixeli de ecran, în culoarea jetului (0 = săgeată).
func seteaza_cursorul(raza: float, culoare: Color) -> void:
	_raza_cursor = raza
	_culoare_cursor = culoare
	_cursor.queue_redraw()


func _process(_delta: float) -> void:
	_cursor.queue_redraw()


func _deseneaza_cursorul() -> void:
	var m := _cursor.get_local_mouse_position().round()
	if pe_panou() or _raza_cursor <= 0.0:
		# săgeata: un triunghi plin cu contur închis
		var varfuri := PackedVector2Array([m, m + Vector2(0, 9), m + Vector2(2.5, 6.5), m + Vector2(5, 11),
			m + Vector2(6.5, 10), m + Vector2(4.5, 6), m + Vector2(7, 6)])
		_cursor.draw_colored_polygon(varfuri, TemaMeniu.TEXT)
		varfuri.append(m)
		_cursor.draw_polyline(varfuri, TemaMeniu.FUNDAL, 1.0)
		return
	# cercul cât jetul: inel închis + inel în culoarea vopselei, ca să se vadă pe orice perete
	var r := maxf(_raza_cursor, 2.0)
	_cursor.draw_arc(m, r + 1.0, 0.0, TAU, 24, TemaMeniu.FUNDAL, 1.0)
	_cursor.draw_arc(m, r, 0.0, TAU, 24, _culoare_cursor, 1.0)
	_cursor.draw_rect(Rect2(m - Vector2(0.5, 0.5), Vector2(1, 1)), _culoare_cursor)


func _clic_casuta(event: InputEvent, i: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		alege_culoarea(i)
		culoare_aleasa.emit(i)


func _apasat(nume: String) -> void:
	match nume:
		"Undo":
			anuleaza.emit()
		"Clear":
			# a doua apăsare confirmă: un clic scăpat nu-ți șterge desenul
			if _confirma_stergerea:
				_confirma_stergerea = false
				_buton_sterge.text = "Clear"
				sterge_tot.emit()
			else:
				_confirma_stergerea = true
				_buton_sterge.text = "Sure?"
				await get_tree().create_timer(2.5).timeout
				if is_instance_valid(_buton_sterge):
					_confirma_stergerea = false
					_buton_sterge.text = "Clear"
		"Done":
			inchis.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		inchis.emit()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.physical_keycode == KEY_Z and k.ctrl_pressed:
			get_viewport().set_input_as_handled()
			anuleaza.emit()
			return
		var cifra := k.physical_keycode - KEY_1
		if cifra >= 0 and cifra < _culori.size():
			get_viewport().set_input_as_handled()
			alege_culoarea(cifra)
			culoare_aleasa.emit(cifra)
	elif event is InputEventMouseButton and event.pressed:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_WHEEL_UP or b.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			get_viewport().set_input_as_handled()
			marime_schimbata.emit(-1 if b.button_index == MOUSE_BUTTON_WHEEL_DOWN else 1)
