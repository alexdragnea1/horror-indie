extends CanvasLayer
## Autoload "Stare": ține minte ce are jucătorul și ce s-a întâmplat în poveste.
##   Stare.adauga_obiect("cheie_hol", "Cheia de la hol")
##   Stare.are_obiect("cheie_hol")  /  Stare.scoate_obiect("cheie_hol")
##   Stare.marcheaza("a_citit_biletul")  /  Stare.e_marcat("a_citit_biletul")
## Tab arată inventarul în colțul din stânga sus.

signal schimbat

## Cât stă pe ecran mesajul „Ai luat: ...” (secunde).
const DURATA_MESAJ := 2.5
const SUNET_OBIECT := preload("res://sunete/obiect_luat.ogg")

## id -> numele afișat
var obiecte: Dictionary = {}
var marcaje: Dictionary = {}
## Numele scris de jucător în meniul de la ușa camerei.
var nume_jucator := ""
## Cât e deschis un meniu (ex. MeniuNume), jucătorul nu se mișcă și nu se uită în jur.
var meniu_deschis := false

var _mesaj: Label
var _lista: Label
var _tween: Tween


func _ready() -> void:
	layer = 6
	_mesaj = _eticheta(Vector2(8, 6))
	_lista = _eticheta(Vector2(8, 6))
	_lista.hide()


func _eticheta(pozitie: Vector2) -> Label:
	var e := Label.new()
	e.position = pozitie
	e.add_theme_font_size_override("font_size", 10)
	e.add_theme_color_override("font_color", Color("83b3b0"))
	e.add_theme_color_override("font_shadow_color", Color("262d2fe6"))
	e.modulate.a = 0.0
	add_child(e)
	return e


func adauga_obiect(id: String, nume: String) -> void:
	obiecte[id] = nume
	_arata_mesaj("Picked up: " + nume)
	Sunet.reda(SUNET_OBIECT, -6.0, 0.0, &"Interfata")
	schimbat.emit()


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


func _arata_mesaj(text: String) -> void:
	_mesaj.text = text
	if _tween:
		_tween.kill()
	_mesaj.modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(DURATA_MESAJ)
	_tween.tween_property(_mesaj, "modulate:a", 0.0, 0.6)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventar"):
		var text := "INVENTORY"
		if obiecte.is_empty():
			text += "\n  (empty)"
		for nume in obiecte.values():
			text += "\n  - " + str(nume)
		_lista.text = text
		_lista.modulate.a = 1.0
		_lista.show()
		_mesaj.hide()
	elif event.is_action_released("inventar"):
		_lista.hide()
		_mesaj.show()
