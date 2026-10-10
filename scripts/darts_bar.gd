extends JocBar
## „Big Mike”, omul de la darts din barul „URBAN” (bar.tscn). Pariul, plecarea cu E și moartea sunt în JocBar.
## Jucați `runde` runde, câte 3 săgeți fiecare; câștigă scorul mai mare (la egalitate încă o rundă).
## Rândul tău: camera stă la linia de aruncare (`linie`), mouse-ul mută ținta pe tablă, dar mâna tremură (mai tare cu
## cât ai băut: `Betie`); click dreapta ținut = îți ții respirația (tremură mult mai puțin câteva secunde, apoi mai
## tare); click stânga = arunci. Rândul lui: camera din lateral (`loc_spectator`), el vine la linie și aruncă spre
## triplul 20 cu `precizie` (abaterea, în metri), apoi se întoarce la locul lui (stătea la linie, cu capul fix în
## camera ta, și cozorocul șepcii acoperea tabla: owner 10.10). Scorul e cel de pe o tablă adevărată (razele din bar.py).
## Replicile lui Big Mike sunt ale lui Claude (owner-ul le poate schimba).

signal _gata_aruncat

const SECTOARE := [20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5]
const R_BULL := 0.00635
const R_25 := 0.0159
const R_T0 := 0.099
const R_T1 := 0.107
const R_D0 := 0.162
const R_D1 := 0.17
const R_TABLA := 0.2255
const SAGEATA_TU := preload("res://models/sageata_rosie.glb")
const SAGEATA_EL := preload("res://models/sageata_albastra.glb")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")
const SUNET_ARUNCAT := preload("res://sunete/darts_aruncat.ogg")
const SUNET_INFIPT := preload("res://sunete/darts_infipt.ogg")
const SUNET_RATAT := preload("res://sunete/obiect_aruncat.ogg")
const SUNET_CASTIG := preload("res://sunete/poker_castig.ogg")
const SUNET_PIERDERE := preload("res://sunete/poker_pierdere.ogg")

## Ținta (originea = centrul, fața spre +Z local).
@export var tabla: Node3D
## Linia de aruncare (unde stai, cu fața spre tablă).
@export var linie: Marker3D
## De unde se vede rândul lui (camera, privește spre `tabla`).
@export var loc_spectator: Marker3D
@export var runde := 3
## Cât de bine aruncă el (abaterea de la ținta lui, în metri). 0,015 ≈ 21 de puncte pe săgeată (Monte Carlo); tu,
## ochind fix pe triplul 20 cu tremurul de bază, ≈ 29: îl bați dacă ochești bine și nu ești beat.
@export var precizie := 0.015
## Cât tremură mâna ta (metri) fără băutură.
@export var tremur := 0.017
@export var ochi := 1.62

var _cam: Camera3D
var _hud: CanvasLayer
var _eticheta_scor: Label
var _eticheta_runda: Label
var _eticheta_mesaj: Label
var _eticheta_sageti: Label
var _cerc: Panel
var _ajutor: Label
var _scor := [0, 0]
var _infipte: Array[Node3D] = []
## Ochitul tău (în coordonatele tablei, metri), timpul pentru tremur, respirația ținută.
var _tinta := Vector2.ZERO
var _timp := 0.0
var _ochesti := false
var _respiratie := 0.0
var _tinut := 0.0
var _obosit := 0.0


func _init() -> void:
	nume_el = "Big Mike"
	marcaj_castig = "a_castigat_la_darts"
	marcaj_pierdut = "a_pierdut_la_darts"
	marcaj_mort = "big_mike_mort"
	marcaj_luat = "big_mike_luat"
	id_cadavru = "cadavru_big_mike"
	nume_cadavru = "Big Mike"
	indiciu_cadavru = "[E] Pick up Big Mike"
	replica_oferta = "Big Mike: You wanna lose some money at darts, kid?"
	replici_fara_bani = ["Big Mike: Come back when you got some cash, kid."]
	replici_reguli = ["Big Mike: Three rounds, three darts each.", "Big Mike: Highest score takes the money."]
	replici_refuz = ["Big Mike: Chicken."]
	replici_castigi = ["Big Mike: Beginner's luck.", "Big Mike: Here, take your damn money."]
	replici_pierzi = ["Big Mike: Better luck next time, kid.", "Big Mike: Pay up."]
	replici_parasit = ["Big Mike: Walking out on me? That's a forfeit, kid.", "Big Mike: Pay up."]


# ---------------------------------------------------------------- jocul

func _joaca() -> bool:
	_jucator.seteaza_purtat(true)
	Stare.meniu_deschis = true
	om.privire = null
	_scor = [0, 0]
	_cam = Camera3D.new()
	get_tree().current_scene.add_child(_cam)
	_fa_hud()
	var runda := 1
	while not _parasit:
		_arata_runda(runda)
		await _randul_tau()
		if _parasit:
			break
		await _randul_lui()
		if _parasit:
			break
		if runda >= runde and _scor[0] != _scor[1]:
			break
		if runda >= runde:
			_mesaj("Tie! One more round.")
			await _asteapta(1.5)
		runda += 1
	var castigat: bool = _scor[0] > _scor[1] and not _parasit
	if not _parasit:
		_mesaj("You win!" if castigat else "%s wins." % nume_el)
		Sunet.reda(SUNET_CASTIG if castigat else SUNET_PIERDERE, Sunet.VOLUM_EFECTE - 2.0)
		await _asteapta(2.2)
	_ochesti = false
	_curata_sagetile()
	_hud.queue_free()
	_cam.queue_free()
	(_jucator.get_node("Cap/Camera3D") as Camera3D).make_current()
	om.priveste_punct = Vector3.INF
	om.lasa_mana("D", 0.3)
	if not om.transform.is_equal_approx(_repaus_om):
		await _mergi_om(_repaus_om, 1.0)
	om.privire = _jucator.get_node("Cap")
	_jucator.seteaza_purtat(false)
	Stare.meniu_deschis = false
	return castigat


func _randul_tau() -> void:
	_curata_sagetile()
	_cam.fov = 30.0
	_cam.global_position = linie.global_position + Vector3.UP * ochi
	_cam.look_at(tabla.global_position, Vector3.UP)
	_cam.make_current()
	_tinta = Vector2(0.0, 0.06)
	_ajutor.text = "Mouse: aim    Hold right click: hold your breath    Left click: throw"
	_ajutor.show()
	_mesaj("Your turn.")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for k in 3:
		if _parasit:
			break
		_arata_sageti(3 - k)
		_ochesti = true
		_cerc.show()
		await _gata_aruncat
		_cerc.hide()
		if _parasit:
			break
		var unde := _tinta + _tremur_acum() + Vector2(randfn(0.0, 0.004), randfn(0.0, 0.004)) * (1.0 + Betie.nivel() * 0.5)
		_respiratie = 0.0
		_tinut = 0.0
		var de_la := _cam.global_transform * Vector3(0.1, -0.12, -0.25)
		await _arunca(SAGEATA_TU, de_la, unde, 0)
		await _asteapta(0.5)
	_arata_sageti(0)
	_ajutor.hide()
	if not _parasit:
		await _asteapta(0.8)


func _randul_lui() -> void:
	_curata_sagetile()
	_vedere_laterala()
	_cam.make_current()
	_mesaj("%s's turn." % nume_el)
	# vine la linie, cu fața spre tablă
	var dinspre_tabla := linie.global_position - tabla.global_position
	dinspre_tabla.y = 0.0  # (altfel stătea aplecat pe spate, cu ochii la tablă)
	var la_linie := Transform3D(Basis.looking_at(dinspre_tabla, Vector3.UP), linie.global_position)
	var parinte := om.get_parent() as Node3D
	await _mergi_om(parinte.global_transform.affine_inverse() * la_linie, 1.2)
	om.priveste_punct = tabla.global_position
	for k in 3:
		await _asteapta(0.6)
		if _parasit:
			break
		# brațul în spate, lângă ureche, apoi înainte, repede: săgeata pleacă din mână
		await om.du_mana("D", om.global_transform * Vector3(-0.2, 1.72, 0.05), 0.45)
		await _asteapta(0.35)
		om.du_mana("D", om.global_transform * Vector3(-0.12, 1.62, 0.6), 0.12)
		await _asteapta(0.08)
		var tinta := Vector2(0.0, (R_T0 + R_T1) / 2.0)
		var unde := tinta + Vector2(randfn(0.0, precizie), randfn(0.0, precizie))
		var de_la := om.punct_mana("D")
		om.lasa_mana("D", 0.5)
		await _arunca(SAGEATA_EL, de_la, unde, 1)
		# prim-plan pe tablă, să vezi unde a nimerit, apoi înapoi din lateral
		_cam.fov = 34.0
		_cam.global_position = tabla.global_transform * Vector3(-0.35, 0.05, 1.7)
		_cam.look_at(tabla.global_position, Vector3.UP)
		await _asteapta(1.1)
		_vedere_laterala()
	om.priveste_punct = Vector3.INF
	if _parasit:
		return
	# înapoi la locul lui, din calea ta: la linie camera ta ar fi în capul lui (cozorocul acoperea tabla)
	await _asteapta(0.4)
	await _mergi_om(_repaus_om, 1.0)
	await _asteapta(0.3)


## E în timpul jocului (JocBar): dacă ochești, renunți la aruncare.
func _la_parasire() -> void:
	if _ochesti:
		_ochesti = false
		_gata_aruncat.emit()


## Săgeata zboară în arc de la `de_la` la punctul `unde` de pe tablă (coordonatele ei) și se înfige; scorul îl ia
## `cine` (0 = tu, 1 = el).
func _arunca(model: PackedScene, de_la: Vector3, unde: Vector2, cine: int) -> void:
	var sageata := model.instantiate() as Node3D
	sageata.set_script(SCRIPT_MODEL)
	sageata.set("material", MATERIAL)
	sageata.set("umbre", false)
	sageata.set("stralucitoare", PackedStringArray())
	sageata.scale = Vector3.ONE * 1.4  # (mai mare decât una adevărată: la 480x270 altfel nu se vede pe tablă)
	get_tree().current_scene.add_child(sageata)
	var r := unde.length()
	var pe_tabla := r <= R_TABLA
	var tinta := tabla.global_transform * Vector3(unde.x, unde.y, -0.012)
	Sunet.reda_la(SUNET_ARUNCAT, de_la, Sunet.VOLUM_EFECTE - 2.0, 0.1)
	var durata := clampf(de_la.distance_to(tinta) / 9.0, 0.18, 0.4)
	var zbor := func(t: float) -> void:
		var p := de_la.lerp(tinta, t) + Vector3.UP * 0.18 * 4.0 * t * (1.0 - t)
		var urm := de_la.lerp(tinta, minf(t + 0.05, 1.0)) + Vector3.UP * 0.18 * 4.0 * minf(t + 0.05, 1.0) * (1.0 - minf(t + 0.05, 1.0))
		sageata.global_position = p
		if urm.distance_to(p) > 0.001:
			sageata.look_at(urm, Vector3.UP)
	var tw := create_tween()
	tw.tween_method(zbor, 0.0, 1.0, durata)
	await tw.finished
	_infipte.append(sageata)
	if pe_tabla:
		# înfiptă: aproape perpendicular pe tablă, cu o mică înclinare la întâmplare
		var baza := tabla.global_basis * Basis.from_euler(Vector3(randf_range(-0.08, 0.08) + 0.32, randf_range(-0.12, 0.12), 0.0)) * Basis.from_scale(Vector3.ONE * 1.4)
		sageata.global_transform = Transform3D(baza, tinta)
		Sunet.reda_la(SUNET_INFIPT, tinta, Sunet.VOLUM_EFECTE - 1.0, 0.1)
	else:
		# pe lângă: lovește peretele și cade pe jos
		Sunet.reda_la(SUNET_RATAT, tinta, Sunet.VOLUM_EFECTE - 3.0, 0.1)
		var jos := tinta + tabla.global_basis.z * 0.3
		jos.y = linie.global_position.y + 0.01
		var cade := create_tween().set_parallel()
		cade.tween_property(sageata, "global_position", jos, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		cade.tween_property(sageata, "rotation", sageata.rotation + Vector3(1.4, 0.6, 0.0), 0.45)
	var puncte := _puncte(unde)
	_scor[cine] += int(puncte[0])
	_mesaj("%s%s" % ["" if cine == 0 else nume_el + ": ", String(puncte[1])])
	_arata_scor()


## Câte puncte face un punct de pe tablă (coordonatele ei, metri) și cum se zice: [puncte, text].
func _puncte(unde: Vector2) -> Array:
	var r := unde.length()
	if r <= R_BULL:
		return [50, "BULLSEYE! 50"]
	if r <= R_25:
		return [25, "Bull 25"]
	if r > R_D1:
		return [0, "Miss"]
	var unghi := fposmod(atan2(unde.x, unde.y), TAU)  # din vârf (20), în sensul acelor de ceas
	var sector: int = SECTOARE[int(floor((unghi + PI / 20.0) / (PI / 10.0))) % 20]
	if r > R_T0 and r <= R_T1:
		return [sector * 3, "Triple %d = %d" % [sector, sector * 3]]
	if r > R_D0:
		return [sector * 2, "Double %d = %d" % [sector, sector * 2]]
	return [sector, str(sector)]


func _tremur_acum() -> Vector2:
	var a := tremur * (1.0 + Betie.nivel() * 0.6)
	# respirația ținută: tremură mai puțin până obosești, apoi mai tare
	a *= lerpf(1.0, 0.3, _respiratie) * (1.0 + _obosit * 0.8)
	return Vector2(sin(_timp * 1.3) * 0.6 + sin(_timp * 2.9 + 1.0) * 0.3 + sin(_timp * 0.6 + 2.0) * 0.35,
		sin(_timp * 1.1 + 0.5) * 0.55 + sin(_timp * 2.3 + 2.4) * 0.35 + cos(_timp * 0.8) * 0.3) * a


func _process(delta: float) -> void:
	if not _ochesti or _cam == null:
		return
	_timp += delta
	var tine := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and _obosit <= 0.0
	if tine:
		_tinut += delta
		_respiratie = move_toward(_respiratie, 1.0, delta * 3.0)
		if _tinut > 2.8:
			_obosit = 1.5
	else:
		_respiratie = move_toward(_respiratie, 0.0, delta * 2.0)
		_tinut = maxf(0.0, _tinut - delta * 2.0)
	_obosit = maxf(0.0, _obosit - delta * 0.6)
	var p := tabla.global_transform * Vector3(_tinta.x + _tremur_acum().x, _tinta.y + _tremur_acum().y, 0.0)
	if not _cam.is_position_behind(p):
		var ecran := _cam.unproject_position(p)
		_cerc.position = ecran - _cerc.size / 2.0
		_cerc.modulate = Color(1, 1, 1, 1) if _respiratie < 0.5 else Color(0.7, 1.0, 0.9, 1)


func _input(event: InputEvent) -> void:
	super(event)  # E = pleci (JocBar)
	if not _ochesti:
		return
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		_tinta += Vector2(m.screen_relative.x, -m.screen_relative.y) * 0.00028
		_tinta = _tinta.limit_length(0.32)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.pressed and b.button_index == MOUSE_BUTTON_LEFT:
			_ochesti = false
			get_viewport().set_input_as_handled()
			_gata_aruncat.emit()


# ---------------------------------------------------------------- unelte

func _curata_sagetile() -> void:
	for s in _infipte:
		if is_instance_valid(s):
			var t := create_tween()
			t.tween_method(func(v: float) -> void: ModelPS2.disparitie(s, v), 0.0, 1.0, 0.3)
			t.tween_callback(s.queue_free)
	_infipte.clear()


func _fa_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 7
	add_child(_hud)
	var radacina := Control.new()
	radacina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radacina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radacina.theme = TemaMeniu.creeaza()
	_hud.add_child(radacina)
	var sus := VBoxContainer.new()
	sus.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	sus.offset_top = 6
	sus.alignment = BoxContainer.ALIGNMENT_CENTER
	sus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radacina.add_child(sus)
	_eticheta_runda = _eticheta(sus, 9, Color("a18463"))
	_eticheta_scor = _eticheta(sus, 12, Color("83b3b0"))
	_eticheta_mesaj = _eticheta(sus, 10, Color("61a19f"))
	_eticheta_sageti = _eticheta(radacina, 10, Color("83b3b0"))
	_eticheta_sageti.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_eticheta_sageti.offset_left = 10
	_eticheta_sageti.offset_top = -22
	_ajutor = _eticheta(radacina, 8, Color("7e8d87"))
	_ajutor.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_ajutor.offset_top = -16
	_ajutor.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# cercul de ochire (o ramă rotundă, cu un punct în mijloc)
	_cerc = Panel.new()
	_cerc.size = Vector2(10, 10)
	_cerc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color(0, 0, 0, 0)
	stil.border_color = Color("83b3b0")
	stil.set_border_width_all(1)
	stil.set_corner_radius_all(5)
	_cerc.add_theme_stylebox_override("panel", stil)
	var punct := ColorRect.new()
	punct.color = Color("7b383a")
	punct.size = Vector2(2, 2)
	punct.position = Vector2(4, 4)
	punct.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cerc.add_child(punct)
	_cerc.hide()
	radacina.add_child(_cerc)
	_arata_scor()


func _eticheta(parinte: Control, marime: int, cul: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", marime)
	l.add_theme_color_override("font_color", cul)
	l.add_theme_color_override("font_outline_color", Color("262d2f"))
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parinte.add_child(l)
	return l


func _arata_scor() -> void:
	if _eticheta_scor:
		_eticheta_scor.text = "You  %d   -   %d  %s" % [_scor[0], _scor[1], nume_el]


func _arata_runda(runda: int) -> void:
	_eticheta_runda.text = "ROUND %d / %d" % [runda, runde] if runda <= runde else "EXTRA ROUND"


func _arata_sageti(cate: int) -> void:
	_eticheta_sageti.text = "Darts: " + "I ".repeat(cate) if cate > 0 else ""


func _mesaj(text: String) -> void:
	if _eticheta_mesaj:
		_eticheta_mesaj.text = text


## Rândul lui, din spate și puțin din dreapta lui (`loc_spectator`): el în stânga cadrului, tabla spre mijloc (din
## lateral pur tabla se vedea doar din profil).
func _vedere_laterala() -> void:
	_cam.fov = 50.0
	_cam.global_position = loc_spectator.global_position
	_cam.look_at(tabla.global_position.lerp(linie.global_position, 0.22), Vector3.UP)
