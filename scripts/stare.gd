extends CanvasLayer
## Autoload "Stare": ține minte ce are jucătorul și ce s-a întâmplat în poveste.
##   Stare.adauga_obiect("cheie_hol", "Hall key")   -> false dacă inventarul e plin
##   Stare.are_obiect("cheie_hol")  /  Stare.scoate_obiect("cheie_hol")
##   Stare.marcheaza("a_vorbit_cu_mom")  /  Stare.e_marcat("a_vorbit_cu_mom")
##   Stare.seteaza_sarcina("Meet with the coven.")  -> apare sus câteva secunde
## Tab deschide / închide inventarul (sloturile + sarcina curentă).

signal schimbat

## Câte obiecte încap în inventar.
const LOCURI_INVENTAR := 5
## Cât stă pe ecran mesajul „Picked up: ...” (secunde).
const DURATA_MESAJ := 2.5
## Cât stă sus „Task: ...” când primești o sarcină nouă (secunde).
const DURATA_SARCINA := 5.0
const SUNET_OBIECT := preload("res://sunete/obiect_luat.ogg")
const SUNET_SARCINA := preload("res://sunete/sarcina_noua.ogg")
const SUNET_DESCHIDE := preload("res://sunete/inventar_deschis.ogg")
const SUNET_INCHIDE := preload("res://sunete/inventar_inchis.ogg")

## id -> numele afișat, în ordinea în care le-ai luat.
var obiecte: Dictionary = {}
var marcaje: Dictionary = {}
## Ce trebuie să faci acum ("" = nimic).
var sarcina := ""
## Numele scris de jucător în meniul de la ușa camerei.
var nume_jucator := ""
## Cât e deschis un meniu (MeniuNume, inventarul), jucătorul nu se mișcă și nu se uită în jur.
var meniu_deschis := false

var _mesaj: Label
var _sarcina_sus: Label
var _inventar: Inventar
var _tween_mesaj: Tween
var _tween_sarcina: Tween


func _ready() -> void:
	layer = 6
	_mesaj = _eticheta()
	_mesaj.position = Vector2(8, 6)
	_sarcina_sus = _eticheta()
	_sarcina_sus.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_sarcina_sus.offset_top = 16
	_sarcina_sus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sarcina_sus.add_theme_font_size_override("font_size", 13)
	_sarcina_sus.add_theme_color_override("font_color", Color("a18463"))
	_inventar = Inventar.new(LOCURI_INVENTAR)
	add_child(_inventar)
	_inventar.hide()


func _eticheta() -> Label:
	var e := Label.new()
	e.add_theme_font_size_override("font_size", 10)
	e.add_theme_color_override("font_color", Color("83b3b0"))
	e.add_theme_color_override("font_shadow_color", Color("262d2fe6"))
	e.add_theme_constant_override("shadow_offset_x", 1)
	e.add_theme_constant_override("shadow_offset_y", 1)
	e.modulate.a = 0.0
	add_child(e)
	return e


## Joc nou: inventar gol, niciun marcaj, nicio sarcină.
func reseteaza() -> void:
	obiecte = {}
	marcaje = {}
	sarcina = ""
	nume_jucator = ""
	meniu_deschis = false
	_inventar.hide()
	_mesaj.show()


## Șterge de pe ecran „Task: …” și „Picked up: …” (la ieșirea în meniul principal).
func ascunde_mesaje() -> void:
	for tween in [_tween_sarcina, _tween_mesaj]:
		if tween:
			tween.kill()
	_sarcina_sus.modulate.a = 0.0
	_mesaj.modulate.a = 0.0


## Ce intră în fișierul de salvare (vezi salvare.gd).
func exporta() -> Dictionary:
	return {"obiecte": obiecte, "marcaje": marcaje, "sarcina": sarcina, "nume_jucator": nume_jucator}


func importa(date: Dictionary) -> void:
	obiecte = date.get("obiecte", {})
	marcaje = date.get("marcaje", {})
	sarcina = date.get("sarcina", "")
	nume_jucator = date.get("nume_jucator", "")


func adauga_obiect(id: String, nume: String) -> bool:
	if obiecte.size() >= LOCURI_INVENTAR and not obiecte.has(id):
		_arata_mesaj("Inventory full")
		return false
	obiecte[id] = nume
	_arata_mesaj("Picked up: " + nume)
	Sunet.reda(SUNET_OBIECT, Sunet.VOLUM_EFECTE, 0.0, &"Interfata")
	schimbat.emit()
	return true


func are_obiect(id: String) -> bool:
	return obiecte.has(id)


func scoate_obiect(id: String) -> void:
	if obiecte.erase(id):
		schimbat.emit()


func marcheaza(marcaj: String) -> void:
	marcaje[marcaj] = true
	schimbat.emit()


func e_marcat(marcaj: String) -> bool:
	return marcaje.has(marcaj)


func seteaza_sarcina(text: String) -> void:
	sarcina = text
	schimbat.emit()
	if text.is_empty():
		return
	_sarcina_sus.text = "Task: " + text
	if _tween_sarcina:
		_tween_sarcina.kill()
	_tween_sarcina = create_tween()
	_tween_sarcina.tween_property(_sarcina_sus, "modulate:a", 1.0, 0.4)
	_tween_sarcina.tween_interval(DURATA_SARCINA)
	_tween_sarcina.tween_property(_sarcina_sus, "modulate:a", 0.0, 0.8)
	Sunet.reda(SUNET_SARCINA, Sunet.VOLUM_EFECTE, 0.0, &"Interfata")


func _arata_mesaj(text: String) -> void:
	_mesaj.text = text
	if _tween_mesaj:
		_tween_mesaj.kill()
	_mesaj.modulate.a = 1.0
	_tween_mesaj = create_tween()
	_tween_mesaj.tween_interval(DURATA_MESAJ)
	_tween_mesaj.tween_property(_mesaj, "modulate:a", 0.0, 0.6)


# _input (nu _unhandled_input), ca Tab/Esc să ajungă aici înaintea jucătorului.
func _input(event: InputEvent) -> void:
	if _inventar.visible:
		if event.is_action_pressed("inventar") or event.is_action_pressed("ui_cancel"):
			_inchide_inventar()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventar") and not meniu_deschis and not Dialog.activ and not Tranzitie.activa:
		_deschide_inventar()
		get_viewport().set_input_as_handled()


func _deschide_inventar() -> void:
	_inventar.actualizeaza(obiecte, sarcina)
	_inventar.show()
	_mesaj.hide()
	meniu_deschis = true
	Sunet.reda(SUNET_DESCHIDE, Sunet.VOLUM_EFECTE, 0.05, &"Interfata")


func _inchide_inventar() -> void:
	_inventar.hide()
	_mesaj.show()
	meniu_deschis = false
	Sunet.reda(SUNET_INCHIDE, Sunet.VOLUM_EFECTE, 0.05, &"Interfata")
