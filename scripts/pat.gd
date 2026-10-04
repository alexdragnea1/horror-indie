extends Interactabil
## Patul din camera jucătorului. După ce ai venit acasă noaptea (`marcaj_necesar`) și până dormi: „[E] Sleep”.
## Somnul: te așezi pe marginea patului, oftezi (`replici_somn`), te întinzi cu capul pe pernă, te uiți la tavan,
## pleoapele se lasă greu de câteva ori și se închid; sunetul se stinge, apoi `marcaj_dormit` și „To be continued...”.
## La Continue după somn (fără `marcaj_trezit`): te trezești în pat (pleoapele se deschid) și te ridici.
## Coordonatele sunt în spațiul patului (tăblia spre +X, partea liberă spre +Z).

@export var marcaj_necesar := "a_venit_acasa"
@export var marcaj_dormit := "a_dormit"
@export var marcaj_trezit := "s_a_trezit_in_pat"
@export_multiline var replici_somn: PackedStringArray = ["You: What a fucking night..."]
## Unde stai lângă pat, unde te așezi pe margine și unde îți sunt picioarele când ești întins.
@export var loc_langa := Vector3(0.1, 0.0, 1.0)
@export var loc_sezut := Vector3(0.1, 0.0, 0.5)
@export var loc_intins := Vector3(0.55, 0.0, 0.0)
## Înălțimea ochilor: așezat pe margine și întins cu capul pe pernă (față de podea).
@export var ochi_sezut := 1.0
@export var ochi_intins := 0.8
@export var sunet_scartait: AudioStream
@export var sunet_patura: AudioStream
## Gol = „To be continued...” și meniul principal.
@export_file("*.tscn") var scena_dupa := ""

var _in_curs := false
var _pleoape: Array[ColorRect] = []
var _strat: CanvasLayer
var _cap: Node3D
## Capul: x = cât privești în sus, y = cât e întors într-o parte (în jurul gâtului, nu al trupului:
## întins pe spate, asta îl întoarce pe pernă spre cameră, ceea ce un simplu rotation.y n-ar face).
var _cap_poza := Vector2.ZERO:
	set(v):
		_cap_poza = v
		if _cap:
			_cap.basis = Basis(Vector3.RIGHT, v.x) * Basis(Vector3.UP, v.y)


func _ready() -> void:
	indiciu = "[E] Sleep"
	await get_tree().process_frame
	if Stare.e_marcat(marcaj_dormit) and not Stare.e_marcat(marcaj_trezit):
		var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
		if jucator:
			_trezeste(jucator)


func poate_fi_folosit() -> bool:
	return not _in_curs and Stare.e_marcat(marcaj_necesar) and not Stare.e_marcat(marcaj_dormit)


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	var cap: Node3D = jucator.get_node("Cap")
	var inaltime_ochi := cap.position.y
	_cap = cap
	_cap_poza = Vector2(cap.rotation.x, 0.0)
	var c := Cutscena.porneste(self)
	jucator.seteaza_purtat(true)
	# te duci lângă pat, cu fața spre el
	await c.priveste(to_global(Vector3(0.4, 0.5, 0.0)), 0.6)
	var tween := _tween()
	tween.tween_property(jucator, "global_position", to_global(loc_langa), 0.7)
	await tween.finished
	# te așezi pe margine, cu spatele la perete
	tween = _tween()
	tween.tween_property(jucator, "global_position", to_global(loc_sezut), 0.8)
	tween.tween_property(cap, "position:y", ochi_sezut, 0.8)
	tween.tween_property(jucator, "rotation:y", _unghi_spre(Vector3(0, 0, 1)), 0.8)
	tween.tween_property(self, "_cap_poza", Vector2(-0.35, 0.0), 0.8)
	await get_tree().create_timer(0.55).timeout
	Sunet.reda_la(sunet_scartait, to_global(loc_sezut), Sunet.VOLUM_EFECTE, 0.05, 1.25)
	await tween.finished
	await get_tree().create_timer(0.5).timeout
	if not replici_somn.is_empty():
		Dialog.spune(replici_somn)
		if Dialog.activ:
			await Dialog.terminat
	await get_tree().create_timer(0.4).timeout
	# te întinzi: capul pe pernă (+X), picioarele spre -X, privirea spre tavan, capul puțin într-o parte
	Sunet.reda_la(sunet_patura, to_global(loc_intins), Sunet.VOLUM_EFECTE, 0.05, 0.7)
	tween = _tween()
	tween.tween_property(jucator, "global_position", to_global(loc_intins), 1.3)
	tween.tween_property(jucator, "rotation:y", jucator.rotation.y + angle_difference(jucator.rotation.y, _unghi_spre(Vector3(-1, 0, 0))), 1.3)
	tween.tween_property(cap, "position:y", ochi_intins, 1.3)
	tween.tween_property(self, "_cap_poza", Vector2(1.32, 0.0), 1.3)
	await get_tree().create_timer(0.7).timeout
	Sunet.reda_la(sunet_scartait, to_global(loc_intins), Sunet.VOLUM_EFECTE, 0.05, 0.9)
	await tween.finished
	var lanterna: SpotLight3D = cap.get_node("Camera3D/Lanterna")
	if lanterna.visible:
		await get_tree().create_timer(0.4).timeout
		lanterna.visible = false
		Sunet.reda(jucator.lanterna_oprita, Sunet.VOLUM_EFECTE, 0.05)
	await c.opreste()
	Stare.meniu_deschis = true
	await get_tree().create_timer(1.5).timeout
	# capul alunecă pe pernă spre cameră, pleoapele se lasă
	_tween().tween_property(self, "_cap_poza", Vector2(0.6, 1.1), 6.0)
	_fa_pleoape(0.0)
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_method(_pleoape_la, 0.0, 0.6, 1.6)
	t.tween_method(_pleoape_la, 0.6, 0.15, 0.5)
	t.tween_interval(0.6)
	t.tween_method(_pleoape_la, 0.15, 0.85, 1.4)
	t.tween_method(_pleoape_la, 0.85, 0.5, 0.7)
	t.tween_interval(0.4)
	t.tween_method(_pleoape_la, 0.5, 1.0, 2.0)
	t.parallel().tween_method(func(db: float) -> void: AudioServer.set_bus_volume_db(0, db), 0.0, -40.0, 3.0)
	await t.finished
	await get_tree().create_timer(1.5).timeout
	# pe negru: te pune lângă pat, ca salvarea să nu te lase înțepenit în saltea
	jucator.global_position = to_global(loc_langa)
	jucator.rotation.y = _unghi_spre(Vector3(0, 0, -1))
	cap.position.y = inaltime_ochi
	cap.rotation = Vector3.ZERO
	jucator.seteaza_purtat(false)
	Stare.marcheaza(marcaj_dormit)
	Salvare.salveaza(false)
	if scena_dupa != "":
		Tranzitie.mergi_la(scena_dupa)
	else:
		await _de_continuat()


## La Continue după somn: ești întins, deschizi ochii greu și te ridici lângă pat.
func _trezeste(jucator: Node3D) -> void:
	_in_curs = true
	var cap: Node3D = jucator.get_node("Cap")
	var inaltime_ochi := cap.position.y
	_cap = cap
	_cap_poza = Vector2(cap.rotation.x, 0.0)
	jucator.seteaza_purtat(true)
	jucator.global_position = to_global(loc_intins)
	jucator.rotation.y = _unghi_spre(Vector3(-1, 0, 0))
	cap.position.y = ochi_intins
	_cap_poza = Vector2(0.6, 1.1)
	Stare.meniu_deschis = true
	_fa_pleoape(1.0)
	while Tranzitie.activa:
		await get_tree().process_frame
	await get_tree().create_timer(1.0).timeout
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_method(_pleoape_la, 1.0, 0.55, 0.9)
	t.tween_method(_pleoape_la, 0.55, 0.95, 0.4)
	t.tween_interval(0.5)
	t.tween_method(_pleoape_la, 0.95, 0.0, 1.2)
	t.parallel().tween_property(self, "_cap_poza", Vector2(1.32, 0.0), 1.2)
	await t.finished
	await get_tree().create_timer(0.8).timeout
	Sunet.reda_la(sunet_patura, to_global(loc_intins), Sunet.VOLUM_EFECTE, 0.05, 0.8)
	var tween := _tween()
	tween.tween_property(jucator, "global_position", to_global(loc_sezut), 1.2)
	tween.tween_property(jucator, "rotation:y", jucator.rotation.y + angle_difference(jucator.rotation.y, _unghi_spre(Vector3(0, 0, 1))), 1.2)
	tween.tween_property(cap, "position:y", ochi_sezut, 1.2)
	tween.tween_property(self, "_cap_poza", Vector2(-0.2, 0.0), 1.2)
	await tween.finished
	Sunet.reda_la(sunet_scartait, to_global(loc_sezut), Sunet.VOLUM_EFECTE, 0.05, 1.1)
	tween = _tween()
	tween.tween_property(jucator, "global_position", to_global(loc_langa), 0.9)
	tween.tween_property(cap, "position:y", inaltime_ochi, 0.9)
	tween.tween_property(self, "_cap_poza", Vector2.ZERO, 0.9)
	await tween.finished
	_strat.queue_free()
	_pleoape.clear()
	jucator.seteaza_purtat(false)
	Stare.meniu_deschis = false
	Stare.marcheaza(marcaj_trezit)
	_in_curs = false


func _tween() -> Tween:
	return create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Unghiul (rotation.y) cu care jucătorul privește în direcția `directie`, dată în spațiul patului.
func _unghi_spre(directie: Vector3) -> float:
	var d := global_basis * directie
	return atan2(-d.x, -d.z)


## Două pleoape negre, sus și jos, pe stratul 19 (sub Tranzitie, peste HUD și dialog).
func _fa_pleoape(inchise: float) -> void:
	_strat = CanvasLayer.new()
	_strat.layer = 19
	add_child(_strat)
	for i in 2:
		var p := ColorRect.new()
		p.color = Color.BLACK
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.anchor_left = 0.0
		p.anchor_right = 1.0
		_strat.add_child(p)
		_pleoape.append(p)
	_pleoape_la(inchise)


## 0 = ochii deschiși, 1 = închiși. Pleoapa de sus coboară mai mult decât urcă cea de jos.
func _pleoape_la(cat: float) -> void:
	if _pleoape.size() < 2:
		return
	_pleoape[0].anchor_top = 0.0
	_pleoape[0].anchor_bottom = 0.56 * cat
	_pleoape[1].anchor_top = 1.0 - 0.44 * cat
	_pleoape[1].anchor_bottom = 1.0
	for p in _pleoape:
		p.offset_top = 0.0
		p.offset_bottom = 0.0


func _de_continuat() -> void:
	var strat := CanvasLayer.new()
	strat.layer = 19
	add_child(strat)
	var negru := ColorRect.new()
	negru.color = Color.BLACK
	negru.set_anchors_preset(Control.PRESET_FULL_RECT)
	strat.add_child(negru)
	var text := Label.new()
	text.text = "To be continued..."
	text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 16)
	text.add_theme_color_override("font_color", Color("a18463"))
	text.modulate.a = 0.0
	strat.add_child(text)
	var tween := create_tween()
	tween.tween_property(text, "modulate:a", 1.0, 1.2)
	tween.tween_interval(3.0)
	tween.tween_property(text, "modulate:a", 0.0, 1.0)
	await tween.finished
	Tranzitie.mergi_la("res://scenes/meniu_principal.tscn")
