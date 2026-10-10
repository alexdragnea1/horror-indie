class_name UIPian
extends CanvasLayer
## Claviatura de pe ecran pentru pianul din conac (pian_conac.gd): două octave, do3 – do5 (15 clape albe, 10 negre).
## Tastatura ca la pianele de pe net (după poziția tastelor, nu după litere, deci merge pe orice aranjament):
##   rândul de jos  Z X C V B N M = do3 ... si3, cu S D  G H J  pentru cele negre;
##   rândul de sus  Q W E R T Y U I = do4 ... do5, cu 2 3  5 6 7 pentru cele negre.
## Merge și cu mouse-ul (click pe clapă). Space ținut = pedala. Esc = te ridici (semnalul `inchis`).

signal apasata(nota: int)
signal ridicata(nota: int)
signal pedala(apasata: bool)
signal inchis

## tasta fizică -> nota (0 = do3)
const TASTE := {
	KEY_Z: 0, KEY_S: 1, KEY_X: 2, KEY_D: 3, KEY_C: 4, KEY_V: 5, KEY_G: 6, KEY_B: 7, KEY_H: 8, KEY_N: 9, KEY_J: 10, KEY_M: 11,
	KEY_Q: 12, KEY_2: 13, KEY_W: 14, KEY_3: 15, KEY_E: 16, KEY_R: 17, KEY_5: 18, KEY_T: 19, KEY_6: 20, KEY_Y: 21,
	KEY_7: 22, KEY_U: 23, KEY_I: 24,
}
## pozițiile notelor negre într-o octavă (1 = do#, ...)
const NEGRE := [1, 3, 6, 8, 10]
const LATIME_ALBA := 18
const INALTIME_ALBA := 58
const LATIME_NEAGRA := 12
const INALTIME_NEAGRA := 36

const FILDES := Color("d8cdb4")
const ABANOS := Color("1b1718")
const APASAT := Color("b0473f")  # roșu: pe fildeș, auriul abia se vedea

var _clape := {}       # nota -> ColorRect
var _apasate := {}     # nota -> true (de la tastatură sau mouse)
var _mouse := -1       # nota ținută cu mouse-ul
var _eticheta_pedala: Label


func _ready() -> void:
	layer = 7
	_construieste()


func _construieste() -> void:
	var cutie := PanelContainer.new()
	cutie.theme = TemaMeniu.creeaza()
	cutie.theme.default_font_size = 10
	cutie.add_theme_stylebox_override("panel", TemaMeniu.cutie(Color(TemaMeniu.FUNDAL, 0.92), TemaMeniu.ACCENT, 5))
	cutie.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	cutie.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cutie.grow_vertical = Control.GROW_DIRECTION_BEGIN
	cutie.offset_bottom = -6
	add_child(cutie)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	cutie.add_child(col)
	var claviatura := Control.new()
	claviatura.custom_minimum_size = Vector2(15 * LATIME_ALBA, INALTIME_ALBA)
	col.add_child(claviatura)
	var albe := 0
	var negre: Array[ColorRect] = []
	for n in 25:
		var neagra := (n % 12) in NEGRE
		var r := ColorRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_STOP
		if neagra:
			r.color = ABANOS
			r.position = Vector2(albe * LATIME_ALBA - LATIME_NEAGRA / 2.0, 0)
			r.size = Vector2(LATIME_NEAGRA, INALTIME_NEAGRA)
			negre.append(r)
		else:
			r.color = FILDES
			r.position = Vector2(albe * LATIME_ALBA, 0)
			r.size = Vector2(LATIME_ALBA - 1, INALTIME_ALBA)
			claviatura.add_child(r)
			albe += 1
		r.gui_input.connect(_mouse_pe_clapa.bind(n))
		_clape[n] = r
		var litera := Label.new()
		litera.text = OS.get_keycode_string(TASTE.find_key(n))
		litera.add_theme_font_size_override("font_size", 8)
		litera.add_theme_color_override("font_color", TemaMeniu.ACCENT if neagra else ABANOS)
		litera.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		litera.mouse_filter = Control.MOUSE_FILTER_IGNORE
		litera.size = Vector2(r.size.x, 10)
		litera.position = Vector2(0, r.size.y - 12)
		r.add_child(litera)
	# negrele peste albe (și primele la click)
	for r in negre:
		claviatura.add_child(r)
	var jos := HBoxContainer.new()
	jos.add_theme_constant_override("separation", 10)
	col.add_child(jos)
	var ajutor := Label.new()
	ajutor.text = "Hold Space: pedal    Esc: stand up"
	ajutor.add_theme_color_override("font_color", TemaMeniu.TEXT)
	ajutor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jos.add_child(ajutor)
	_eticheta_pedala = Label.new()
	_eticheta_pedala.text = "PEDAL"
	_eticheta_pedala.add_theme_color_override("font_color", TemaMeniu.STINS)
	jos.add_child(_eticheta_pedala)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_pleaca()
		return
	if not event is InputEventKey:
		return
	var k := event as InputEventKey
	if k.echo:
		get_viewport().set_input_as_handled()
		return
	if k.physical_keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		pedala.emit(k.pressed)
		_eticheta_pedala.add_theme_color_override("font_color", TemaMeniu.ACCENT if k.pressed else TemaMeniu.STINS)
		return
	if TASTE.has(k.physical_keycode):
		get_viewport().set_input_as_handled()
		var n: int = TASTE[k.physical_keycode]
		if k.pressed:
			_jos(n)
		else:
			_sus(n)


func _mouse_pe_clapa(event: InputEvent, n: int) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse = n
			_jos(n)
		elif _mouse >= 0:
			_sus(_mouse)
			_mouse = -1


func _jos(n: int) -> void:
	_apasate[n] = true
	(_clape[n] as ColorRect).color = APASAT
	apasata.emit(n)


func _sus(n: int) -> void:
	if not _apasate.has(n):
		return
	_apasate.erase(n)
	(_clape[n] as ColorRect).color = ABANOS if (n % 12) in NEGRE else FILDES
	ridicata.emit(n)


func _pleaca() -> void:
	for n in _apasate.keys():
		_sus(n)
	inchis.emit()
	queue_free()
