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
## „Vocea”: un bip scurt la fiecare câteva litere, ca în jocurile vechi.
const VOCE := preload("res://sunete/dialog_voce.ogg")
## Înălțimea vocii pentru fiecare personaj (1 = normal, mai mic = mai gros).
const INALTIME_VOCI := {"MOM": 0.62, "OLD HAG": 0.78}
const INALTIME_JUCATOR := 1.25
## Pentru replicile fără nume (descrieri, naratorul).
const INALTIME_FARA_NUME := 0.9
const LITERE_INTRE_BIPURI := 4
const VOLUM_VOCE_DB := -17.0

var activ := false

var _replici: PackedStringArray = []
var _index := 0
var _panou: PanelContainer
var _text: Label
var _eticheta: PanelContainer
var _nume: Label
var _tween: Tween
var _inaltime_voce := 1.0
var _litere_auzite := 0
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
	stil.bg_color = Color("262d2fe0")
	stil.border_color = Color("a18463")
	stil.set_border_width_all(1)
	stil.set_content_margin_all(6)
	_panou.add_theme_stylebox_override("panel", stil)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 12)
	_text.add_theme_color_override("font_color", Color("83b3b0"))
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
		_nume.add_theme_color_override("font_color", Color("61a19f") if e_jucator else Color("a56850"))
		_eticheta.show()
		_inaltime_voce = INALTIME_JUCATOR if e_jucator else INALTIME_VOCI.get(nume.to_upper(), 1.0)
	else:
		_eticheta.hide()
		_inaltime_voce = INALTIME_FARA_NUME
	_litere_auzite = 0
	_text.text = replica
	_text.visible_ratio = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_text, "visible_ratio", 1.0, _text.text.length() / LITERE_PE_SECUNDA)


func _process(_delta: float) -> void:
	if not activ or _text.visible_ratio >= 1.0:
		return
	var litere := int(_text.visible_ratio * _text.text.length())
	if litere - _litere_auzite >= LITERE_INTRE_BIPURI:
		_litere_auzite = litere
		Sunet.reda(VOCE, VOLUM_VOCE_DB, 0.06, &"Interfata", _inaltime_voce)


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
