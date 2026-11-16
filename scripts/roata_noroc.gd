class_name RoataNoroc
extends Interactabil
## Roata din pivnița lui Jean (pivnita.tscn, owner 16.11). „Press E to spin” → o singură dată (`MARCAJ`, cu felia
## ieșită ca valoare): discul se învârte câteva ture și încetinește, limba de sus tresare la fiecare țintă (clic),
## se oprește pe una din cele 5 felii, cu șanse egale (`randi() % 5`):
##   Gri = Knife, Verde = Shotgun, Albastru = Swift Boots (`ID_GHETE`: cât le ai în inventar mergi și fugi cu
##   `BONUS_GHETE` = 30% mai repede, vezi jucator.gd), Mov = AK-47, Portocaliu = Gauntlet (350 pe lovitură la bossi).
## Arma intră în inventar și o ții în mână (ghetele doar în inventar); cu inventarul plin rămâne pe jos în fața roții.
## Modelul: roata.glb (`Disc` se rotește pe Z, feliile `Seg*` primesc culorile `CULORI`, `Limba`).

const MARCAJ := "a_invartit_roata"
const FELII := ["SegGri", "SegVerde", "SegAlbastru", "SegMov", "SegPortocaliu"]
const CULORI := [Color(0.48, 0.48, 0.5), Color(0.2, 0.62, 0.26), Color(0.2, 0.36, 0.86), Color(0.56, 0.24, 0.78),
	Color(0.96, 0.5, 0.14)]
const NUME_CULORI := ["GREY", "GREEN", "BLUE", "PURPLE", "ORANGE"]
## Swift Boots (owner 16.11, în locul Energy Ball-ului): cât le ai în inventar, viteza ta × `BONUS_GHETE`.
const ID_GHETE := "swift_boots"
const NUME_GHETE := "Swift Boots"
const BONUS_GHETE := 1.3
## Ce primești pe fiecare felie: [id din inventar, nume].
const PREMII := [["cutit", "Knife"], ["shotgun", "Shotgun"], [ID_GHETE, NUME_GHETE], ["ak47", "AK-47"], ["gauntlet", "Gauntlet"]]
## Culoarea vârfurilor feliilor în model (ALB din jean.py): materialul o împarte ca să iasă exact `CULORI`.
const CULOARE_MODEL := Color("83b3b0")
const FELIE := TAU / 5.0
const SUNET_CLIC := preload("res://sunete/ui_clic.ogg")
const SUNET_CASTIG := preload("res://sunete/pacanea_castig.ogg")
const SUNET_START := preload("res://sunete/scartait_podea.ogg")

@export var ture := Vector2i(5, 7)
@export var durata := 6.5

var _disc: Node3D
var _limba: Node3D
var _in_curs := false
var _ultima_tinta := 0
var _limba_tresare := 0.0


func _ready() -> void:
	indiciu = "Press %s to spin" % Setari.nume_tasta("interact")
	var model := $Model as Node3D
	_disc = model.find_child("Disc", true, false) as Node3D
	_limba = model.find_child("Limba", true, false) as Node3D
	for i in FELII.size():
		var felie := model.find_child(FELII[i], true, false) as GeometryInstance3D
		if felie == null:
			continue
		var mat := (felie.material_override as ShaderMaterial).duplicate() as ShaderMaterial
		var c: Color = CULORI[i]
		mat.set_shader_parameter("culoare", Color(c.r / CULOARE_MODEL.r, c.g / CULOARE_MODEL.g, c.b / CULOARE_MODEL.b, 1.0))
		felie.material_override = mat
	if Stare.e_marcat(MARCAJ):
		# rămâne oprită pe felia ieșită
		_disc.rotation.z = int(Stare.valoare_marcaj(MARCAJ, 0)) * FELIE


func poate_fi_folosit() -> bool:
	return super() and not _in_curs and not Stare.e_marcat(MARCAJ)


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	var rezultat := randi() % 5
	# marcat înainte să se învârtă: dacă ieși din joc la mijloc, nu mai primești încă o încercare
	Stare.marcheaza(MARCAJ, rezultat)
	var c := Cutscena.porneste(self)
	await c.priveste(_disc.global_position, 0.6)
	Sunet.reda_la(SUNET_START, _disc.global_position, Sunet.VOLUM_EFECTE - 4.0, 0.05)
	# felia i e sus la rotația i·72° (jean.py, FELII); se învârte în sensul acelor de ceas, câteva ture
	var start := _disc.rotation.z
	var nr_ture := randi_range(ture.x, ture.y)
	var final := rezultat * FELIE - TAU * nr_ture + randf_range(-0.32, 0.32) * FELIE
	_ultima_tinta = _tinta(start)
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		_disc.rotation.z = lerpf(start, final, 1.0 - pow(1.0 - v, 3.2))
		var acum := _tinta(_disc.rotation.z)
		if acum != _ultima_tinta:
			_ultima_tinta = acum
			_limba_tresare = 1.0
			Sunet.reda_la(SUNET_CLIC, _limba.global_position, Sunet.VOLUM_EFECTE - 8.0, 0.15), 0.0, 1.0, durata)
	await t.finished
	await get_tree().create_timer(0.5).timeout
	Sunet.reda(SUNET_CASTIG, Sunet.VOLUM_EFECTE - 3.0, 0.0)
	await _arata_rezultat(rezultat)
	var premiu: Array = PREMII[rezultat]
	_da_arma(premiu[0], premiu[1])
	await get_tree().create_timer(0.4).timeout
	await c.opreste()
	_in_curs = false


## A câta țintă (între felii) a trecut de limbă, după rotație: se schimbă la fiecare 72°.
func _tinta(rotatie: float) -> int:
	return floori((rotatie - FELIE * 0.5) / FELIE)


func _process(delta: float) -> void:
	# limba tresare la fiecare țintă și revine
	if _limba:
		_limba_tresare = move_toward(_limba_tresare, 0.0, delta * 7.0)
		_limba.rotation.z = -0.45 * sin(_limba_tresare * PI * 0.5)


## Culoarea ieșită, mare, pe mijlocul ecranului (în culoarea feliei), apoi ce primești.
func _arata_rezultat(i: int) -> void:
	var strat := CanvasLayer.new()
	strat.layer = 11
	add_child(strat)
	var e := Label.new()
	e.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var premiu: Array = PREMII[i]
	e.text = "%s\n%s" % [NUME_CULORI[i], premiu[1]]
	e.add_theme_font_size_override("font_size", 22)
	e.add_theme_constant_override("line_spacing", -4)
	e.add_theme_color_override("font_color", (CULORI[i] as Color).lightened(0.15))
	e.add_theme_color_override("font_shadow_color", Color("262d2fe6"))
	e.add_theme_constant_override("shadow_offset_x", 2)
	e.add_theme_constant_override("shadow_offset_y", 2)
	e.modulate.a = 0.0
	e.pivot_offset = Vector2(240, 135)
	strat.add_child(e)
	var t := create_tween().set_parallel()
	t.tween_property(e, "modulate:a", 1.0, 0.25)
	t.tween_property(e, "scale", Vector2.ONE, 0.35).from(Vector2.ONE * 1.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(1.8).timeout
	var t2 := create_tween()
	t2.tween_property(e, "modulate:a", 0.0, 0.5)
	t2.tween_callback(strat.queue_free)


func _da_arma(id: String, nume: String) -> void:
	if Stare.adauga_obiect(id, nume):
		if id != ID_GHETE:  # ghetele nu se țin în mână: merg cât le ai în inventar
			Stare.tine_in_mana(id)
		return
	# inventarul plin: arma rămâne pe jos, în fața roții
	var obiect := ObiectLuat.new()
	obiect.id_obiect = id
	obiect.nume_obiect = nume
	obiect.indiciu = "[E] Take the %s" % nume
	var forma := CollisionShape3D.new()
	var cutie := BoxShape3D.new()
	cutie.size = Vector3(0.5, 0.15, 0.3)
	forma.shape = cutie
	forma.position.y = 0.07
	obiect.add_child(forma)
	var model := ObiecteLume.model(id)
	obiect.add_child(model)
	var jos: Vector3 = ObiecteLume.MODELE.get(id, {}).get("jos", Vector3.ZERO)
	model.rotation = jos
	model.position.y = ObiecteLume.MODELE.get(id, {}).get("ridicare", 0.03)
	get_parent().add_child(obiect)
	obiect.global_position = global_position + global_basis.z * 0.8
	obiect.global_rotation.y = global_rotation.y + 0.4

