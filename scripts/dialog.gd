extends CanvasLayer
## Caseta de text de jos (autoload "Dialog").
## Oriunde în joc: Dialog.spune(["Prima replică.", "A doua."])
## Apeși E (sau click) ca să treci mai departe.
## Dacă replica începe cu un nume și două puncte ("MOM: Salut!"), numele apare
## într-o etichetă separată deasupra casetei.

signal terminat

const LITERE_PE_SECUNDA := 45.0
## Numele care înseamnă „personajul nostru” (eticheta lor e albăstruie, a celorlalți roșiatică).
const NUME_JUCATOR := ["You", "Tu", "Eu"]

var activ := false

var _replici: PackedStringArray = []
var _index := 0
var _panou: PanelContainer
var _text: Label
var _eticheta: PanelContainer
var _nume: Label
var _tween: Tween
var _regex_nume := RegEx.create_from_string("^([^:\"]{1,14}):\\s+(.*)$")


func _ready() -> void:
	layer = 10
	_panou = PanelContainer.new()
	_panou.anchor_left = 0.0
	_panou.anchor_right = 1.0
	_panou.anchor_top = 1.0
	_panou.anchor_bottom = 1.0
	_panou.offset_left = 16
	_panou.offset_right = -16
	_panou.offset_top = -64
	_panou.offset_bottom = -10
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color(0, 0, 0, 0.85)
	stil.border_color = Color(0.6, 0.55, 0.45)
	stil.set_border_width_all(1)
	stil.set_content_margin_all(6)
	_panou.add_theme_stylebox_override("panel", stil)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 12)
	_text.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	_panou.add_child(_text)
	add_child(_panou)
	_panou.hide()

	# eticheta cu numele celui care vorbește, lipită de colțul din stânga sus al casetei
	_eticheta = PanelContainer.new()
	_eticheta.anchor_top = 1.0
	_eticheta.anchor_bottom = 1.0
	_eticheta.offset_left = 22
	_eticheta.offset_top = -79
	_eticheta.offset_bottom = -64
	_eticheta.add_theme_stylebox_override("panel", stil.duplicate())
	_nume = Label.new()
	_nume.add_theme_font_size_override("font_size", 10)
	_eticheta.add_child(_nume)
	add_child(_eticheta)
	_eticheta.hide()


func spune(replici: PackedStringArray) -> void:
	if replici.is_empty():
		return
	_replici = replici
	_index = 0
	activ = true
	_panou.show()
	_arata_replica()


func _arata_replica() -> void:
	var replica := _replici[_index]
	var gasit := _regex_nume.search(replica)
	if gasit:
		var nume := gasit.get_string(1).strip_edges()
		replica = gasit.get_string(2)
		_nume.text = nume
		var e_jucator := nume in NUME_JUCATOR
		_nume.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0) if e_jucator else Color(1.0, 0.55, 0.6))
		_eticheta.show()
	else:
		_eticheta.hide()
	_text.text = replica
	_text.visible_ratio = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_text, "visible_ratio", 1.0, _text.text.length() / LITERE_PE_SECUNDA)


func _input(event: InputEvent) -> void:
	if not activ:
		return
	var apasat: bool = event.is_action_pressed("interact") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if not apasat:
		return
	get_viewport().set_input_as_handled()
	if _text.visible_ratio < 1.0:
		_tween.kill()
		_text.visible_ratio = 1.0
		return
	_index += 1
	if _index < _replici.size():
		_arata_replica()
	else:
		_panou.hide()
		_eticheta.hide()
		activ = false
		terminat.emit()
