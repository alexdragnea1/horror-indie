extends CanvasLayer
## Autoload "Tranzitie": trece în altă scenă prin ecran negru.
##   Tranzitie.mergi_la("res://scenes/afara_bloc.tscn")
##   Tranzitie.mergi_la(cale, "Block M7\n11:57 PM", [pas, pas, usa])
## Ecranul se întunecă, sunetul se stinge, se încarcă scena nouă, pe negru se aud sunetele
## date (ce se întâmplă „între” scene: scări, o ușă), apoi imaginea revine și apare numele locului.
## Cât rulează, jucătorul nu se poate mișca (vezi Tranzitie.activa în jucator.gd).

## Cât durează întunecarea și luminarea (secunde).
const DURATA_INTUNECARE := 0.9
const DURATA_LUMINARE := 1.6
## Pauza minimă dintre sunetele de pe negru (cele lungi primesc mai mult timp).
const PAUZA_SUNETE := 0.38
## Cât stă pe ecran numele locului.
const DURATA_TITLU := 3.5

var activa := false

var _negru: ColorRect
var _titlu: Label
var _tween_titlu: Tween


func _ready() -> void:
	layer = 20  # peste tot: filtrul PS2, dialogul, inventarul
	process_mode = Node.PROCESS_MODE_ALWAYS
	_negru = ColorRect.new()
	_negru.color = Color.BLACK  # negru curat, nu din paletă: owner-ul a cerut „black screen”
	_negru.set_anchors_preset(Control.PRESET_FULL_RECT)
	_negru.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_negru.modulate.a = 0.0
	add_child(_negru)
	_titlu = Label.new()
	_titlu.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_titlu.offset_left = 14
	_titlu.offset_top = -58
	_titlu.offset_bottom = -14
	_titlu.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_titlu.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_titlu.add_theme_font_size_override("font_size", 12)
	_titlu.add_theme_color_override("font_color", Color("83b3b0"))
	_titlu.add_theme_color_override("font_shadow_color", Color("262d2fe6"))
	_titlu.add_theme_constant_override("shadow_offset_x", 1)
	_titlu.add_theme_constant_override("shadow_offset_y", 1)
	_titlu.modulate.a = 0.0
	add_child(_titlu)


## titlu = numele locului, arătat jos în stânga după tranziție ("" = nimic).
## sunete = ce se aude pe negru, în ordine.
func mergi_la(cale: String, titlu := "", sunete: Array[AudioStream] = []) -> void:
	if activa:
		return
	activa = true
	var tween := create_tween()
	tween.tween_property(_negru, "modulate:a", 1.0, DURATA_INTUNECARE)
	tween.parallel().tween_method(_volum_general, 0.0, -40.0, DURATA_INTUNECARE)
	await tween.finished

	get_tree().change_scene_to_file(cale)
	get_tree().paused = false  # dacă venim din meniul de pauză
	await get_tree().process_frame
	_volum_general(0.0)
	# pe negru suntem „între” locuri (o scară de bloc): ecou mare, de beton
	Acustica.seteaza(0.8, 0.4, 0.3)
	await _asteapta(0.3)
	for sunet in sunete:
		if sunet == null:
			continue
		# sunetele scurte (pași) mai încet, cele lungi (ușa trântită) mai tare, ca să iasă în față
		var volum := Sunet.VOLUM_EFECTE
		Sunet.reda(sunet, volum, 0.05)
		await _asteapta(maxf(PAUZA_SUNETE, minf(sunet.get_length(), 1.4) * 0.7))
	await _asteapta(0.3)
	get_tree().call_group("acustica", "aplica")

	tween = create_tween()
	tween.tween_property(_negru, "modulate:a", 0.0, DURATA_LUMINARE).set_trans(Tween.TRANS_SINE)
	await _asteapta(DURATA_LUMINARE * 0.5)
	activa = false
	if not titlu.is_empty():
		_arata_titlu(titlu)


func _arata_titlu(text: String) -> void:
	if Dialog.activ:
		return  # a început deja o conversație: numele locului nu mai apare
	_titlu.text = text
	_tween_titlu = create_tween()
	_tween_titlu.tween_property(_titlu, "modulate:a", 1.0, 1.0)
	_tween_titlu.tween_interval(DURATA_TITLU)
	_tween_titlu.tween_property(_titlu, "modulate:a", 0.0, 1.5)


func _process(_delta: float) -> void:
	# o conversație începută cât e pe ecran numele locului îl face să dispară pe loc,
	# altfel textele se suprapun
	if Dialog.activ and _titlu.modulate.a > 0.0:
		if _tween_titlu:
			_tween_titlu.kill()
			_tween_titlu = null
		_titlu.modulate.a = 0.0


func _asteapta(secunde: float) -> void:
	await get_tree().create_timer(secunde).timeout


func _volum_general(db: float) -> void:
	AudioServer.set_bus_volume_db(0, db)
