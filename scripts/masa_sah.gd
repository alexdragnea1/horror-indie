class_name MasaSah
extends Interactabil
## Masa de șah a lui Jean (casa_jean.tscn, owner 16.11). „[E] Play chess” → te așezi → „Jean: Would you like to make
## a wager?” cu Life / Money / No (Money e gri fără cel puțin $1 cash):
##  - No: „Jean: Stop wasting my time.”, scoate pușca de sub masă și te împușcă (`_te_impusca`): YOU DIED + Retry, care
##    te pune în fața casei lui (UsaScena.sosire_urmatoare = SOSIRE_RETRY, în casa_lexy.tscn).
##  - Money: „Jean: Don't get your hopes up.” / „You: Why are you larping?”, apoi meciul. Pierzi: îi dai dolarul
##    (`MIZA`), „Jean: Thank you for your donation.” / „You: It's not that deep.”, te ridici. Câștigi: „Jean: I've never
##    felt more humiliated.” și se împușcă singur (`_se_impusca`).
##  - Life: „Jean: There are easier ways to end your life, child.” / „You: You're not him bro.”, apoi meciul. Pierzi: te
##    împușcă el; câștigi: se împușcă el.
## Meciul (reguli în Sah): tu ești albul și începi. Click pe o piesă de-a ta = o ridici și apar pătratele în care poate
## merge; click pe unul = mutarea (pe altă piesă de-a ta = o alegi pe aia; în altă parte = o lași jos). E = resign
## (pierzi pe loc). Jean gândește pe alt fir (WorkerThreadPool), cel puțin `gandire_minima` secunde; piesa lui se mută singură (fără mână: owner 16.11).
## Remiză (pat, material insuficient, 50 de mutări, repetiție) = „Jean: A draw. Again.” și o luați de la capăt.
## După ce moare (`MARCAJ_MORT`), Jean rămâne căzut lângă tron și masa nu se mai folosește.

const MARCAJ_MORT := "jean_mort"
## Cheia pivniței (owner 16.11): când îl bați, o scapă pe tabla de șah; cu ea se deschide UsaPivnita.
const ID_CHEIE := "cheie_pivnita"
const NUME_CHEIE := "Cellar Key"
const MARCAJ_CHEIE := "a_luat_cheia_pivnitei"
const SUNET_CHEIE := preload("res://sunete/tub_cazut.ogg")
## Unde apari după Retry (PunctSosire din casa_lexy.tscn, pus de afara_lexy.gd).
const SOSIRE_RETRY := "SosireJean"
const SCENA_AFARA := "res://scenes/casa_lexy.tscn"
## Cât pariezi la „Money” (cenți).
const MIZA := 100
const PATRAT := 0.055
const TIPURI := ["", "Pion", "Cal", "Nebun", "Tura", "Regina", "Rege"]
const PIESE := preload("res://models/piese_sah.glb")
const MATERIAL := preload("res://shaders/material_model.tres")
const SUNET_SCAUN := preload("res://sunete/canapea_asezat.ogg")
const SUNET_PIESA := preload("res://sunete/obiect_pus.ogg")
const SUNET_FOC := preload("res://sunete/shotgun_foc.ogg")
const SUNET_POMPA := preload("res://sunete/shotgun_pompa.ogg")
const SUNET_CADERE := preload("res://sunete/corp_cazut.ogg")
const BANCNOTA := preload("res://models/bancnota.glb")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
# culori din paletă
const C_ALES := Color("a18463")
const C_MUTARE := Color("83b3b0")
const C_CAPTURA := Color("904a40")
const C_ULTIMA := Color("5b6d4e")
const C_TEXT := Color("83b3b0")
const C_ROSU := Color("904a40")

@export var jean: OmLaMasa
## Unde stai pe scaun (podeaua de sub ochii tăi) și cât de sus îți sunt ochii așezat.
@export var loc_jucator: Marker3D
@export var ochi_sezut := 1.14
## Mijlocul tablei, pe fața pătratelor; -Z = spre Jean (negrul).
@export var centru_tabla: Marker3D
## Pușca de sub masă (Node3D cu `Model`, `Maner`, `Tub`, `Gura`), și unde stă când e scoasă.
@export var pusca: Node3D
@export var adancime := 2
## Câți centipioni de „gust” la întâmplare pune Jean pe fiecare mutare (mai mult = mai ușor de bătut).
@export var zgomot := 35
@export var gandire_minima := Vector2(0.9, 2.2)

var _sah: Sah
var _piese := {}  # pătrat -> Node3D
var _meshuri := {}  # "Pion_A" -> Mesh
var _jucator: Node3D
var _cap: Node3D
var _c: Cutscena
var _in_curs := false
var _inaltime_ochi := 1.6
var _miza := ""
## Ce se întâmplă acum în meci: "" = nimic, "tu" = e rândul tău, "jean" = gândește / mută el.
var _faza := ""
var _ales := -1
var _legale: Array[int] = []
var _abandon := false
var _marcaje: Array[MeshInstance3D] = []
var _sub_mouse: MeshInstance3D
var _ultima: Array[MeshInstance3D] = []
var _capturate := [0, 0]  # câte piese a luat fiecare (pentru locul de lângă tablă)
var _hud: CanvasLayer
var _stare: Label
var _resign: Label
var _vedere_text: Label
var _pusca_acasa := Transform3D.IDENTITY
var _cadavru: Ragdoll

signal _mutare_aleasa(m: int)


func _ready() -> void:
	indiciu = "[E] Play chess"
	_jucator = get_tree().get_first_node_in_group("jucator") as Node3D
	if _jucator:
		_cap = _jucator.get_node("Cap")
	var sursa := PIESE.instantiate()
	for c in sursa.find_children("*", "MeshInstance3D", true, false):
		_meshuri[String(c.name).get_slice(".", 0)] = (c as MeshInstance3D).mesh
	sursa.free()
	_sah = Sah.new()
	if pusca:
		_pusca_acasa = pusca.transform
	if Stare.e_marcat(MARCAJ_MORT):
		activ = false
		_mort_la_incarcare.call_deferred()
		return
	_aseaza_piesele()
	if jean:
		jean.fumeaza = false
		jean.privire = _cap


func poate_fi_folosit() -> bool:
	return activ and not _in_curs and _jucator != null


## DOAR PENTRU TESTE (owner 16.11, butonul `ButonTest` din casa_jean.tscn): te așezi și sari direct la finalul în
## care câștigi pe viață (Jean se împușcă, cheia pe tablă, dispare). Scoate-l înainte de build-ul final.
func debug_castiga() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	await _aseaza_te()
	_miza = "viata"
	jean.privire = _cap
	await _se_impusca()


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	await _aseaza_te()
	var fara_bani := Bani.suma() < MIZA
	var ales := await Dialog.intreaba("Jean: Would you like to make a wager?",
		PackedStringArray(["Life", "Money", "No"]), [1] if fara_bani else [])
	Stare.meniu_deschis = true
	match ales:
		0:
			await _spune(["Jean: There are easier ways to end your life, child.", "You: You're not him bro."])
			_miza = "viata"
		1:
			await _spune(["Jean: Don't get your hopes up.", "You: Why are you larping?"])
			_miza = "bani"
		_:
			await _spune(["Jean: Stop wasting my time."])
			await _te_impusca()
			return
	await _meci()


func _spune(replici: PackedStringArray) -> void:
	Dialog.spune(replici)
	if Dialog.activ:
		await Dialog.terminat
	Stare.meniu_deschis = true


# ---------------------------------------------------------------- așezat / ridicat

func _aseaza_te() -> void:
	_jucator.seteaza_purtat(true)
	_inaltime_ochi = _cap.position.y
	_c = Cutscena.porneste(self)
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_jucator, "global_position", loc_jucator.global_position, 0.8)
	t.tween_property(_cap, "position:y", ochi_sezut, 0.8)
	_c.priveste(_privire_masa(), 0.8)
	await t.finished
	Sunet.reda_la(SUNET_SCAUN, loc_jucator.global_position, Sunet.VOLUM_EFECTE - 2.0, 0.05)
	await _c.priveste(jean.global_position + Vector3.UP * 1.05, 0.5)


func _ridica_te() -> void:
	var inapoi := loc_jucator.global_position + (loc_jucator.global_position - global_position).normalized() * 0.75
	inapoi.y = loc_jucator.global_position.y
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_jucator, "global_position", inapoi, 0.7)
	t.tween_property(_cap, "position:y", _inaltime_ochi, 0.7)
	t.tween_property(_cap, "rotation:x", 0.0, 0.7)
	await t.finished
	_jucator.seteaza_purtat(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(_c):
		await _c.opreste()
	Stare.meniu_deschis = false
	_in_curs = false


## Punctul spre care te uiți cât joci: puțin dincolo de mijlocul tablei, ca să vezi toată tabla și fața lui Jean.
func _privire_masa() -> Vector3:
	return centru_tabla.global_position + Vector3.UP * 0.13 - centru_tabla.global_basis.z * 0.1


# ---------------------------------------------------------------- tabla 3D

func _poz(p: int) -> Vector3:
	return centru_tabla.to_global(Vector3(((p & 7) - 3.5) * PATRAT, 0.0, (3.5 - (p >> 3)) * PATRAT))


func _patrat_din(punct: Vector3) -> int:
	var l := centru_tabla.to_local(punct)
	var c := floori(l.x / PATRAT + 4.0)
	var r := floori(4.0 - l.z / PATRAT)
	return -1 if c < 0 or c > 7 or r < 0 or r > 7 else r * 8 + c


func _piesa_noua(piesa: int) -> Node3D:
	var nod := MeshInstance3D.new()
	nod.mesh = _meshuri[TIPURI[Sah.tip(piesa)] + ("_A" if piesa <= 6 else "_N")]
	nod.material_override = MATERIAL
	add_child(nod)
	nod.global_basis = centru_tabla.global_basis
	if piesa > 6:
		nod.rotate_y(PI)  # caii negri se uită spre tine
	return nod


func _aseaza_piesele() -> void:
	for n in _piese.values():
		(n as Node3D).queue_free()
	for n in get_children():
		if n.has_meta("capturata"):
			n.queue_free()
	_piese.clear()
	_capturate = [0, 0]
	for p in 64:
		var x := _sah.tabla[p]
		if x != 0:
			var nod := _piesa_noua(x)
			nod.global_position = _poz(p)
			_piese[p] = nod


func _marcaj(culoare: Color, p: int, mic := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2.ONE * (PATRAT * (0.36 if mic else 0.92))
	m.mesh = plan
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(culoare, 0.55 if mic else 0.4)
	mat.no_depth_test = false
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_basis = centru_tabla.global_basis
	m.global_position = _poz(p) + Vector3.UP * 0.0015
	return m


func _sterge_marcajele() -> void:
	for m in _marcaje:
		m.queue_free()
	_marcaje.clear()


func _arata_ultima() -> void:
	for m in _ultima:
		m.queue_free()
	_ultima.clear()
	if _sah.ultima >= 0:
		_ultima.append(_marcaj(C_ULTIMA, Sah.de_la(_sah.ultima)))
		_ultima.append(_marcaj(C_ULTIMA, Sah.la(_sah.ultima)))


## Mută piesele 3D după mutarea `m` (ÎNAINTE de _sah.muta): ridicată, purtată, pusă jos; capturile ies lângă tablă.
func _anima_mutarea(m: int) -> void:
	var a := Sah.de_la(m)
	var b := Sah.la(m)
	var nod: Node3D = _piese.get(a)
	var captura := _sah.patrat_capturat(m)
	var luat: Node3D = _piese.get(captura) if _sah.capturat_de(m) != 0 else null
	_piese.erase(a)
	if luat:
		_piese.erase(captura)
	var sus := Vector3.UP * 0.045
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(nod, "global_position", nod.global_position + sus, 0.14)
	t.tween_property(nod, "global_position", _poz(b) + sus, 0.32)
	t.tween_property(nod, "global_position", _poz(b), 0.12)
	if luat:
		_scoate_piesa(luat, Sah.culoare(_sah.tabla[a]))
	await t.finished
	Sunet.reda_la(SUNET_PIESA, _poz(b), Sunet.VOLUM_EFECTE - 4.0, 0.12)
	_piese[b] = nod
	if Sah.fel(m) == Sah.FEL_ROCADA:
		var de_tura := b + 1 if b > a else b - 2
		var la_tura := b - 1 if b > a else b + 1
		var tura: Node3D = _piese.get(de_tura)
		_piese.erase(de_tura)
		var t2 := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t2.tween_property(tura, "global_position", tura.global_position + sus, 0.12)
		t2.tween_property(tura, "global_position", _poz(la_tura) + sus, 0.25)
		t2.tween_property(tura, "global_position", _poz(la_tura), 0.1)
		await t2.finished
		Sunet.reda_la(SUNET_PIESA, _poz(la_tura), Sunet.VOLUM_EFECTE - 5.0, 0.12)
		_piese[la_tura] = tura
	if Sah.promovare(m) != 0:
		var piesa_noua := Sah.promovare(m) + (0 if Sah.culoare(_sah.tabla[a]) == Sah.ALB else 6)
		var regina := _piesa_noua(piesa_noua)
		regina.global_position = _poz(b)
		nod.queue_free()
		_piese[b] = regina


## Piesa luată pleacă lângă tablă, în dreapta celui care a luat-o (pe rânduri de câte 8).
func _scoate_piesa(nod: Node3D, cine_ia: int) -> void:
	var i: int = _capturate[cine_ia]
	_capturate[cine_ia] += 1
	var semn := 1.0 if cine_ia == Sah.ALB else -1.0
	var local := Vector3(semn * (4.9 + float(i / 8)) * PATRAT, 0.0, semn * (3.5 - float(i % 8)) * PATRAT)
	var tinta := centru_tabla.to_global(local)
	nod.set_meta("capturata", true)
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(nod, "global_position", nod.global_position + Vector3.UP * 0.06, 0.15)
	t.tween_property(nod, "global_position", tinta + Vector3.UP * 0.06, 0.3)
	t.tween_property(nod, "global_position", tinta - Vector3.UP * 0.006, 0.12)
	t.tween_callback(Sunet.reda_la.bind(SUNET_PIESA, tinta, Sunet.VOLUM_EFECTE - 7.0, 0.15))


# ---------------------------------------------------------------- meciul

func _meci() -> void:
	_sah.reseteaza()
	_aseaza_piesele()
	_arata_ultima()
	_abandon = false
	_fa_hud()
	jean.privire = null
	jean.priveste_punct = centru_tabla.global_position
	await _vedere(true, 0.8)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var castigator := -1  # Sah.ALB = tu, Sah.NEGRU = Jean
	while true:
		var rez := _sah.rezultat()
		if rez == Sah.REZ_MAT:
			castigator = 1 - _sah.la_mutare
			break
		if rez != Sah.REZ_NIMIC:
			_scrie("Draw")
			await get_tree().create_timer(1.0).timeout
			await _spune(["Jean: A draw. Again."])
			_sah.reseteaza()
			_aseaza_piesele()
			_arata_ultima()
			continue
		_scrie("Check!" if _sah.in_sah() else "")
		var m := -1
		if _sah.la_mutare == Sah.ALB:
			_faza = "tu"
			_legale = _sah.mutari_legale()
			m = await _mutare_aleasa
			_faza = ""
			_lasa_jos()
			if _abandon:
				castigator = Sah.NEGRU
				break
		else:
			_faza = "jean"
			m = await _gandeste()
			_faza = ""
		await _anima_mutarea(m)
		_sah.muta(m)
		_arata_ultima()
	_faza = ""
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not _abandon:
		_scrie("Checkmate")
		await get_tree().create_timer(1.4).timeout
	await _vedere(false, 0.6)
	_sterge_hud()
	jean.priveste_punct = Vector3.INF
	jean.privire = _cap
	await _c.priveste(jean.global_position + Vector3.UP * 1.05, 0.6)
	if castigator == Sah.ALB:
		if _miza == "bani":
			await _spune(["Jean: I've never felt more humiliated."])
		await _se_impusca()
	elif _miza == "bani":
		await _platesti()
		await _spune(["Jean: Thank you for your donation.", "You: It's not that deep."])
		_ridica_te()
	else:
		await _te_impusca()


## Jean se gândește (pe alt fir, ca jocul să nu înghețe), apoi se uită la piesa pe care o mută.
func _gandeste() -> int:
	var copie := _sah.copie()
	var rezultat := [-1]
	var de_facut := func() -> void: rezultat[0] = copie.cea_mai_buna(adancime, zgomot)
	var sarcina := WorkerThreadPool.add_task(de_facut, false, "Jean gândește")
	var minim := randf_range(gandire_minima.x, gandire_minima.y)
	var start := Time.get_ticks_msec()
	while not WorkerThreadPool.is_task_completed(sarcina) or (Time.get_ticks_msec() - start) * 0.001 < minim:
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(sarcina)
	var m: int = rezultat[0]
	# fără mână pe piese (owner 16.11): se uită la piesă, apoi la pătratul în care o mută; restul îl face _anima_mutarea
	var a := Sah.de_la(m)
	jean.priveste_punct = _poz(a)
	await get_tree().create_timer(0.35).timeout
	jean.priveste_punct = _poz(Sah.la(m))
	_priveste_tabla_dupa()
	return m


func _priveste_tabla_dupa() -> void:
	await get_tree().create_timer(0.9).timeout
	jean.priveste_punct = centru_tabla.global_position


func _unhandled_input(event: InputEvent) -> void:
	# clic dreapta, oricând în meci (și cât gândește sau mută Jean): de sus pe tablă ↔ pe scaun, cu privirea la Jean
	if is_instance_valid(_hud) and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		if not _vedere_in_miscare:
			_vedere(not _vedere_sus, 0.5)
		return
	if _faza != "tu":
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_abandon = true
		_mutare_aleasa.emit(-1)
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		var p := _patrat_sub_mouse()
		if p < 0:
			_lasa_jos()
			return
		if _ales >= 0:
			for m in _legale:
				if Sah.de_la(m) == _ales and Sah.la(m) == p:
					_mutare_aleasa.emit(m)
					return
		var x := _sah.tabla[p]
		if x != 0 and Sah.culoare(x) == Sah.ALB and p != _ales:
			_ridica(p)
		else:
			_lasa_jos()


func _patrat_sub_mouse() -> int:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return -1
	var poz := get_viewport().get_mouse_position()
	var de_la := cam.project_ray_origin(poz)
	var dir := cam.project_ray_normal(poz)
	if absf(dir.y) < 0.001:
		return -1
	var y0 := centru_tabla.global_position.y
	var t := (y0 - de_la.y) / dir.y
	if t < 0.0:
		return -1
	return _patrat_din(de_la + dir * t)


func _ridica(p: int) -> void:
	_lasa_jos()
	_ales = p
	var nod: Node3D = _piese.get(p)
	if nod:
		create_tween().tween_property(nod, "global_position", _poz(p) + Vector3.UP * 0.018, 0.1)
	_marcaje.append(_marcaj(C_ALES, p))
	for m in _legale:
		if Sah.de_la(m) == p:
			var captura := _sah.capturat_de(m) != 0
			_marcaje.append(_marcaj(C_CAPTURA if captura else C_MUTARE, Sah.la(m), not captura))
	Sunet.reda_la(SUNET_PIESA, _poz(p), Sunet.VOLUM_EFECTE - 9.0, 0.2)


func _lasa_jos() -> void:
	if _ales >= 0:
		var nod: Node3D = _piese.get(_ales)
		if nod:
			create_tween().tween_property(nod, "global_position", _poz(_ales), 0.08)
	_ales = -1
	_sterge_marcajele()


func _process(_delta: float) -> void:
	if _faza != "tu":
		if is_instance_valid(_sub_mouse):
			_sub_mouse.queue_free()
		return
	var p := _patrat_sub_mouse()
	if p < 0:
		if is_instance_valid(_sub_mouse):
			_sub_mouse.queue_free()
		return
	if not is_instance_valid(_sub_mouse):
		_sub_mouse = _marcaj(C_TEXT, p)
		(_sub_mouse.material_override as StandardMaterial3D).albedo_color.a = 0.22
	_sub_mouse.global_position = _poz(p) + Vector3.UP * 0.001


# ---------------------------------------------------------------- HUD

func _fa_hud() -> void:
	_sterge_hud()
	_hud = CanvasLayer.new()
	_hud.layer = 7
	add_child(_hud)
	_resign = _eticheta("Press %s to resign" % Setari.nume_tasta("interact"), 9, C_TEXT)
	_resign.position = Vector2(10, 34)
	_vedere_text = _eticheta("Right Click: look at Jean", 9, C_TEXT)
	_vedere_text.position = Vector2(10, 46)
	_stare = _eticheta("", 14, C_ROSU)
	_stare.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_stare.position.y = 34
	_stare.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stare.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _eticheta(text: String, marime: int, culoare: Color) -> Label:
	var e := Label.new()
	e.text = Limbaj.curata(text)
	e.add_theme_font_size_override("font_size", marime)
	e.add_theme_color_override("font_color", culoare)
	e.add_theme_color_override("font_shadow_color", Color("262d2fe6"))
	e.add_theme_constant_override("shadow_offset_x", 1)
	e.add_theme_constant_override("shadow_offset_y", 1)
	_hud.add_child(e)
	return e


func _scrie(text: String) -> void:
	if is_instance_valid(_stare):
		_stare.text = text


func _sterge_hud() -> void:
	if is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null
	_sterge_marcajele()
	for m in _ultima:
		m.queue_free()
	_ultima.clear()


# ---------------------------------------------------------------- banii

## Îi dai dolarul: bancnota iese din dreptul tău, alunecă pe masă până la el, el o ia și o bagă în buzunar.
func _platesti() -> void:
	Bani.plateste(MIZA)
	var nota := BANCNOTA.instantiate() as Node3D
	nota.set_script(SCRIPT_MODEL)
	nota.set("material", MATERIAL)
	add_child(nota)
	var spre_jean := -centru_tabla.global_basis.z
	var start := centru_tabla.global_position - spre_jean * 0.33 + centru_tabla.global_basis.x * 0.12 - Vector3.UP * 0.004
	nota.global_position = start
	nota.global_basis = centru_tabla.global_basis.rotated(Vector3.UP, 0.25)
	Sunet.reda_la(SUNET_PIESA, start, Sunet.VOLUM_EFECTE - 10.0, 0.1)
	var capat := centru_tabla.global_position + spre_jean * 0.3 + centru_tabla.global_basis.x * 0.1 - Vector3.UP * 0.004
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(nota, "global_position", capat, 0.7)
	await t.finished
	await jean.du_mana("S", nota, 0.5)
	var mana := jean.nod_mana("S")
	nota.reparent(mana)
	jean.du_mana("S", jean.global_position + Vector3(0.12, 1.0, 0.1), 0.6)
	await get_tree().create_timer(0.6).timeout
	nota.queue_free()
	jean.lasa_mana("S", 0.5)


# ---------------------------------------------------------------- pușca

## Pușca de sub masă în mâinile lui (mâinile urmăresc `Maner` și `Tub`), ridicată deasupra blatului.
func _scoate_pusca() -> void:
	pusca.show()
	pusca.transform = _pusca_acasa
	jean.priveste_punct = Vector3.INF
	# pușca e prinsă sub marginea blatului dinspre el, deasupra genunchilor (`Pusca`). Mâinile se ridică întâi de pe
	# masă și vin înapoi, deasupra marginii (în linie dreaptă treceau prin blat), apoi intră pe sub margine la ea:
	# de acolo până la pușcă drumul trece pe sub blat, nu prin el, și pe deasupra genunchilor.
	var b := jean.global_basis
	var j := jean.global_position
	jean.du_mana("D", j + b * Vector3(-0.22, 0.88, 0.3), 0.3)
	await jean.du_mana("S", j + b * Vector3(0.22, 0.88, 0.3), 0.3)
	jean.du_mana("D", pusca.get_node("Maner"), 0.35)
	await jean.du_mana("S", pusca.get_node("Tub"), 0.35)
	Sunet.reda_la(SUNET_SCAUN, pusca.global_position, Sunet.VOLUM_EFECTE - 6.0, 0.1)
	# o trage întâi spre el, de sub blat (orizontal, pe deasupra genunchilor), apoi o ridică drept în sus
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(pusca, "global_position", pusca.global_position - b.z * 0.12, 0.25)
	t.tween_property(pusca, "global_position", pusca.global_position - b.z * 0.12 + Vector3.UP * 0.4, 0.3)
	await t.finished


func _tine_pusca(spre: Vector3, gura_la: Vector3, durata: float) -> void:
	# pușca privește spre -Z; o așezăm cu gura în `gura_la`, îndreptată spre `spre`
	var dir := (spre - gura_la).normalized()
	var baza := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else jean.global_basis.z)
	var gura_local: Vector3 = (pusca.get_node("Gura") as Node3D).position
	var tinta := Transform3D(baza, gura_la - baza * gura_local)
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(pusca, "global_transform", tinta, durata)
	await t.finished


func _pompeaza() -> void:
	var tub := pusca.get_node("Tub") as Node3D
	var p0: Vector3 = tub.position
	Sunet.reda_la(SUNET_POMPA, pusca.global_position, Sunet.VOLUM_EFECTE, 0.03)
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(tub, "position", p0 + Vector3(0, 0, 0.09), 0.13)
	t.tween_property(tub, "position", p0, 0.13)
	var model := pusca.get_node("Model") as Node3D
	var pompa := model.find_child("Pompa", true, false) as Node3D
	if pompa:
		var q0 := pompa.position
		var t2 := create_tween().set_trans(Tween.TRANS_SINE)
		t2.tween_property(pompa, "position", q0 + Vector3(0, 0, 0.09), 0.13)
		t2.tween_property(pompa, "position", q0, 0.13)
	await t.finished


func _foc() -> void:
	var gura := (pusca.get_node("Gura") as Node3D).global_position
	Sunet.reda_la(SUNET_FOC, gura, Sunet.VOLUM_EFECTE + 2.0, 0.02)
	var lumina := OmniLight3D.new()
	lumina.light_color = Color(1.0, 0.7, 0.4)
	lumina.light_energy = 7.0
	lumina.omni_range = 6.0
	lumina.shadow_enabled = true
	get_parent().add_child(lumina)
	lumina.global_position = gura
	var flacara := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.45, 0.45)
	flacara.mesh = q
	var mat := Arma.material_particule(true)
	mat.albedo_color = Color(1.0, 0.75, 0.4)
	flacara.material_override = mat
	get_parent().add_child(flacara)
	flacara.global_position = gura
	# reculul
	var t0 := pusca.transform
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(pusca, "transform", t0.translated_local(Vector3(0, 0.03, 0.08)).rotated_local(Vector3.RIGHT, 0.25), 0.07)
	t.tween_property(pusca, "transform", t0, 0.35)
	await get_tree().create_timer(0.06).timeout
	flacara.queue_free()
	var t2 := create_tween()
	t2.tween_property(lumina, "light_energy", 0.0, 0.18)
	t2.tween_callback(lumina.queue_free)
	_fum(gura)


func _fum(punct: Vector3) -> void:
	var fum := CPUParticles3D.new()
	fum.amount = 14
	fum.lifetime = 1.6
	fum.one_shot = true
	fum.explosiveness = 0.85
	fum.direction = Vector3.UP
	fum.spread = 50.0
	fum.initial_velocity_min = 0.1
	fum.initial_velocity_max = 0.35
	fum.gravity = Vector3(0, 0.12, 0)
	fum.scale_amount_min = 0.6
	fum.scale_amount_max = 1.2
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	fum.mesh = q
	var mat := Arma.material_particule(false)
	mat.albedo_color = Color(0.55, 0.55, 0.55, 0.35)
	fum.material_override = mat
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.5))
	g.set_color(1, Color(1, 1, 1, 0.0))
	fum.color_ramp = g
	get_parent().add_child(fum)
	fum.global_position = punct
	fum.emitting = true
	get_tree().create_timer(2.0).timeout.connect(fum.queue_free)


func _sange(punct: Vector3, directie: Vector3) -> void:
	var s := CPUParticles3D.new()
	s.amount = 46
	s.lifetime = 1.1
	s.one_shot = true
	s.explosiveness = 1.0
	s.direction = directie
	s.spread = 32.0
	s.initial_velocity_min = 1.2
	s.initial_velocity_max = 3.6
	s.gravity = Vector3(0, -9.0, 0)
	s.scale_amount_min = 0.5
	s.scale_amount_max = 1.4
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	s.mesh = q
	var mat := Arma.material_particule(false)
	mat.albedo_color = Color(0.42, 0.05, 0.06)
	s.material_override = mat
	get_parent().add_child(s)
	s.global_position = punct
	s.emitting = true
	get_tree().create_timer(1.6).timeout.connect(s.queue_free)


## Te împușcă (la „No” sau când pierzi pe viață): pușca scoasă și îndreptată spre tine, pompa, focul; cazi pe spate,
## YOU DIED, Retry → în fața casei lui.
func _te_impusca() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	jean.privire = _cap
	await _scoate_pusca()
	# întâi în diagonală pe piept (gura sus în stânga lui, mânerul la șoldul drept: se vede toată pușca și pompa), apoi spre tine
	var b := jean.global_basis
	var gura_sus := jean.global_position + b * Vector3(0.38, 1.3, 0.28)
	await _tine_pusca(gura_sus + b * Vector3(0.8, 0.6, 0.0), gura_sus, 0.55)
	await _c.priveste(jean.global_position + Vector3.UP * 1.15, 0.2)
	await _pompeaza()
	await get_tree().create_timer(0.45).timeout
	var piept := jean.global_position + b * Vector3(0.05, 1.05, 0.38)
	await _tine_pusca(_cap.global_position, piept + b.z * 0.42 + b.x * 0.06, 0.3)
	await get_tree().create_timer(0.35).timeout
	await _foc()
	# lovitura: ecranul se face roșu, capul zboară pe spate, cazi
	var strat := CanvasLayer.new()
	strat.layer = 8
	get_parent().add_child(strat)
	var rosu := ColorRect.new()
	rosu.color = Color(C_ROSU, 0.85)
	rosu.set_anchors_preset(Control.PRESET_FULL_RECT)
	rosu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strat.add_child(rosu)
	create_tween().tween_property(rosu, "color:a", 0.45, 1.2)
	_sange(_cap.global_position + jean.global_basis.z * 0.05, jean.global_basis.z + Vector3.UP * 0.3)
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_cap, "rotation:x", deg_to_rad(70), 0.55)
	t.tween_property(_cap, "rotation:z", deg_to_rad(-28), 0.7)
	t.tween_property(_cap, "position:y", 0.22, 0.75)
	t.tween_property(_jucator, "global_position", _jucator.global_position + jean.global_basis.z * 0.55, 0.6)
	await t.finished
	Sunet.reda_la(SUNET_CADERE, _cap.global_position, Sunet.VOLUM_EFECTE, 0.05)
	var bara := BaraBoss.new()
	get_parent().add_child(bara)
	await bara.mesaj_cu_buton("YOU DIED", BaraBoss.ROSU_DESCHIS, "Retry")
	Stare.meniu_deschis = false
	UsaScena.sosire_urmatoare = SOSIRE_RETRY
	Tranzitie.mergi_la(SCENA_AFARA, "", [])


## Pierde Jean: pușca sub bărbie și se împușcă; cade pe spate în tron, pușca îi cade din mâini.
func _se_impusca() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await _scoate_pusca()
	await _pompeaza()
	jean.priveste_punct = jean.global_position + jean.global_basis * Vector3(0, 0.6, 1.2)
	var barbie := jean.global_position + jean.global_basis * Vector3(0.0, 1.13, 0.07)
	var de_jos := barbie + jean.global_basis * Vector3(0.0, -0.8, 0.32)
	await _tine_pusca(barbie + (barbie - de_jos), barbie, 0.9)
	await _c.priveste(barbie, 0.4)
	await get_tree().create_timer(1.1).timeout
	await _foc()
	Stare.marcheaza(MARCAJ_MORT)
	activ = false
	var sus := (barbie - de_jos).normalized()
	_sange(barbie + sus * 0.15, sus)
	_lasa_pusca_sa_cada()
	jean.set_process(false)
	# brânciul: mai mult înapoi, în spătar, decât în sus (altfel zbura peste tron)
	_cadavru = Ragdoll.din_model(jean.get_node("Model"), (Vector3.UP * 0.35 - jean.global_basis.z).normalized() * 4.5)
	# îi sare cheia din buzunarul de la piept și cade pe tablă
	_pune_cheia(jean.global_position + jean.global_basis * Vector3(0.1, 1.0, 0.15))
	await get_tree().create_timer(0.5).timeout
	Sunet.reda_la(SUNET_CADERE, jean.global_position + Vector3.UP * 0.6, Sunet.VOLUM_EFECTE, 0.05)
	await get_tree().create_timer(1.6).timeout
	await _dispare_jean(1.5)
	await get_tree().create_timer(0.4).timeout
	_ridica_te()


func _lasa_pusca_sa_cada() -> void:
	var corp := RigidBody3D.new()
	corp.mass = 3.5
	corp.collision_layer = 4
	corp.collision_mask = 1
	get_parent().add_child(corp)
	corp.global_transform = pusca.global_transform
	var forma := CollisionShape3D.new()
	var cutie := BoxShape3D.new()
	cutie.size = Vector3(0.08, 0.14, 0.95)
	forma.shape = cutie
	forma.position = Vector3(0, 0, -0.2)
	corp.add_child(forma)
	pusca.reparent(corp)
	# brânciul în capătul țevii (spre masă și într-o parte), ca să se răstoarne, nu să rămână în picioare pe pat
	corp.apply_impulse((jean.global_basis.z + jean.global_basis.x * 0.6) * 1.6, corp.global_basis * Vector3(0, 0, -0.6))


## Corpul lui, pușca și piesele se destramă pe pixeli (ModelPS2.disparitie) și dispar: pe masă rămâne doar cheia.
func _dispare_jean(durata: float) -> void:
	var de_sters: Array[Node] = []
	if is_instance_valid(_cadavru):
		de_sters.append(_cadavru)
	if is_instance_valid(pusca):
		de_sters.append(pusca.get_parent() if pusca.get_parent() is RigidBody3D else pusca)
	for n in _piese.values():
		de_sters.append(n)
	for n in get_children():
		if n.has_meta("capturata"):
			de_sters.append(n)
	_sterge_marcajele()
	for m in _ultima:
		m.queue_free()
	_ultima.clear()
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		for n in de_sters:
			if is_instance_valid(n):
				ModelPS2.disparitie(n, v), 0.0, 1.0, durata)
	await t.finished
	for n in de_sters:
		if is_instance_valid(n):
			if n == pusca:
				pusca.hide()
			else:
				n.queue_free()
	_piese.clear()


## Cheia pivniței, culcată pe mijlocul tablei („[E] Take the key”). Cu `din`, zboară acolo în arc și clinchetește.
func _pune_cheia(din := Vector3.INF) -> void:
	var cheie := ObiectLuat.new()
	cheie.name = "CheiePivnita"
	cheie.id_obiect = ID_CHEIE
	cheie.nume_obiect = NUME_CHEIE
	cheie.indiciu = "[E] Take the key"
	var forma := CollisionShape3D.new()
	var cutie := BoxShape3D.new()
	cutie.size = Vector3(0.16, 0.05, 0.09)
	forma.shape = cutie
	forma.position.y = 0.02
	cheie.add_child(forma)
	cheie.add_child(ObiecteLume.model(ID_CHEIE))
	cheie.folosit.connect(func() -> void: Stare.marcheaza(MARCAJ_CHEIE))
	get_parent().add_child(cheie)
	var tinta := centru_tabla.global_position + centru_tabla.global_basis.x * 0.02
	cheie.global_basis = centru_tabla.global_basis.rotated(Vector3.UP, 0.5)
	if din == Vector3.INF:
		cheie.global_position = tinta
		return
	cheie.global_position = din
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		cheie.global_position = din.lerp(tinta, v) + Vector3.UP * sin(v * PI) * 0.22
		cheie.rotation.z = (1.0 - v) * 5.0, 0.0, 1.0, 0.55)
	await t.finished
	Sunet.reda_la(SUNET_CHEIE, tinta, Sunet.VOLUM_EFECTE - 2.0, 0.05)
	var t2 := create_tween()
	t2.tween_property(cheie, "global_position", tinta + Vector3.UP * 0.02, 0.07)
	t2.tween_property(cheie, "global_position", tinta, 0.1)


## La Continue / când revii după ce a murit: nu mai e nimeni în tron; pe tablă e cheia, dacă n-ai luat-o.
func _mort_la_incarcare() -> void:
	if jean:
		jean.set_process(false)
		jean.hide()
	if pusca:
		pusca.hide()
	if not Stare.e_marcat(MARCAJ_CHEIE):
		_pune_cheia()


# ---------------------------------------------------------------- vederea de sus (owner 16.11)

## Cât de sus deasupra tablei îți sunt ochii în vederea de sus și cât de în fața mijlocului ei (spre tine).
const INALTIME_SUS := 0.5
const DEPARTARE_SUS := 0.1

var _vedere_sus := false
var _vedere_in_miscare := false


## În meci te apleci deasupra tablei și te uiți aproape drept în jos (`sus`), ca să vezi bine toate pătratele;
## clic dreapta te ridică înapoi pe scaun, cu privirea spre Jean (și invers).
func _vedere(sus: bool, durata := 0.6) -> void:
	_vedere_in_miscare = true
	_vedere_sus = sus
	var corp := loc_jucator.global_position
	var ochi := ochi_sezut
	var spre := _privire_masa()
	if sus:
		corp = centru_tabla.global_position + centru_tabla.global_basis.z * DEPARTARE_SUS
		corp.y = loc_jucator.global_position.y
		ochi = centru_tabla.global_position.y + INALTIME_SUS - corp.y
		spre = centru_tabla.global_position
	var d := spre - (corp + Vector3.UP * ochi)
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_jucator, "global_position", corp, durata)
	t.tween_property(_cap, "position:y", ochi, durata)
	_c.roteste(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()), durata)
	await t.finished
	_vedere_in_miscare = false
	if is_instance_valid(_vedere_text):
		_vedere_text.text = "Right Click: look at Jean" if sus else "Right Click: look at the board"
