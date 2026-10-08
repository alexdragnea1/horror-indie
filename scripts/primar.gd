extends Interactabil
## Primarul Smegma, în biroul oval de la etajul primăriei (primarie.tscn). Stă la birou (OmLaMasa `om`, pe fotoliul
## `scaun`), cu fața spre ușă. Când intri pe ușă (`zona`, după `marcaj_necesar` = ți-a zis funcționara de el):
##  1. sare în picioare, speriat, cu mâinile sus (fotoliul fuge în spate) → `replici_inceput`;
##  2. se lasă încet înapoi pe scaun, tu vii în fața biroului (`loc_jucator`) → `replici_oferta` (ultima rămâne pe ecran
##     cu butoanele `optiune_haggle` / `optiune_accept`);
##  3. Haggle → `replici_haggle_1` (oferta `sume[1]`), iar Haggle → `replici_haggle_2` (`sume[2]`), iar Haggle →
##     `replici_haggle_3` (la prima replică tresare și ridică mâinile; `sume[3]`, fără butoane); Accept oricând →
##     `replici_accept` cu suma de atunci;
##  4. scoate teancul de bani din sertar și ți-l întinde peste birou; îl iei → cash (Bani), `marcaj_gata` + `marcaj_suma`.
## După aceea, la E: `replici_dupa`. Replicile sunt ale owner-ului (nu le corecta); `replici_dupa` e a lui Claude.

@export var om: OmLaMasa
## Fotoliul lui (fuge în spate când sare în picioare).
@export var scaun: Node3D
## Zona din dreptul ușii: când intri în ea, începe scena.
@export var zona: Area3D
@export var teanc: PackedScene
@export var marcaj_necesar := "angajata_a_zis_de_primar"
@export var marcaj_gata := "a_luat_banii_de_la_primar"
## Câți dolari ți-a dat (valoarea marcajului).
@export var marcaj_suma := "bani_de_la_primar"
## Sarcina de după (gol = niciuna).
@export var sarcina_noua := ""
## Unde stai în fața biroului cât negociați (global) și unde îți întinde banii (față de el, în coordonatele lui).
@export var loc_jucator := Vector3(0.0, 4.0, -2.95)
@export var loc_predare := Vector3(0.1, 0.95, 1.05)
## Sertarul din dreapta lui, de unde scoate banii (în coordonatele lui).
@export var loc_sertar := Vector3(-0.62, 0.45, 0.25)
## Cât se ridică și cât se trage în spate când sare în picioare (în coordonatele lui), cât fuge fotoliul.
@export var ridicare := Vector3(0.0, 0.42, -0.18)
@export var fuga_scaun := 0.22

@export_group("Replici")
@export_multiline var replici_inceput: PackedStringArray = ["Mayor Smegma: Who are you?!",
	"You: I can take care of the witch problem for you."]
@export_multiline var replici_oferta: PackedStringArray = ["Mayor Smegma: That's wonderful.", "You: But I don't come cheap..",
	"Mayor Smegma: Oh..It's money you're after, huh?", "Mayor Smegma: Very well..I can give you $100."]
@export_multiline var replici_haggle_1: PackedStringArray = ["You: Are you retarded?", "You: Like genuinely.",
	"Mayor Smegma: Ok dear, I'm sorry.", "Mayor Smegma: I can do $200"]
@export_multiline var replici_haggle_2: PackedStringArray = ["You: 5 bands or I'm out..",
	"Mayor Smegma: Can we maybe meet in the middle and do $2500?"]
@export_multiline var replici_haggle_3: PackedStringArray = ["You: $5000 or I kill your family instead.",
	"Mayor Smegma: OK! OK! I Will do $5000...", "You: Bitch ass.."]
@export_multiline var replici_accept: PackedStringArray = ["You: Ok bitch, let's do this."]
@export var optiune_haggle := "Haggle"
@export var optiune_accept := "Accept"
## Ofertele lui, în dolari: prima, după Haggle 1, 2, 3.
@export var sume: PackedInt32Array = [100, 200, 2500, 5000]
@export_multiline var replici_dupa: PackedStringArray = ["Mayor Smegma: Please.. I have a town to run.."]
## Cât de gros e teancul (scara pe înălțime) pentru fiecare sumă din `sume`.
@export var grosimi: PackedFloat32Array = [0.3, 0.5, 2.0, 3.5]

const SUNET_MAINI_SUS := preload("res://sunete/maini_sus.ogg")
const SUNET_SCAUN := preload("res://sunete/scartait_podea.ogg")
const SUNET_SERTAR := preload("res://sunete/obiect_pus.ogg")
const SUNET_BANI := preload("res://sunete/bancnota.ogg")

var _in_curs := false
var _jucator: Node3D
var _cap: Node3D
var _camera: Camera3D
var _om_jos: Vector3
var _scaun_jos: Vector3


func _ready() -> void:
	indiciu = "[E] Talk to the mayor"
	_om_jos = om.position
	if scaun:
		_scaun_jos = scaun.position
	await get_tree().process_frame
	_jucator = get_tree().get_first_node_in_group("jucator") as Node3D
	if _jucator == null:
		return
	_cap = _jucator.get_node("Cap")
	_camera = _cap.get_node("Camera3D")
	om.privire = _cap
	if zona:
		zona.body_entered.connect(_la_intrare)


func poate_fi_folosit() -> bool:
	return not _in_curs and Stare.e_marcat(marcaj_gata)


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	folosit.emit()
	Dialog.spune(replici_dupa)


func _la_intrare(corp: Node3D) -> void:
	if _in_curs or not corp.is_in_group("jucator") or not Stare.e_marcat(marcaj_necesar) or Stare.e_marcat(marcaj_gata):
		return
	# banii trebuie să încapă în inventar (ca la Lexy): altfel îți spune jocul „Inventory full” și mai încerci
	if Stare.obiecte.size() >= Stare.LOCURI_INVENTAR and not Stare.are_obiect(Bani.ID):
		Stare.adauga_obiect(Bani.ID, Bani.nume(0))
		return
	_in_curs = true
	await _scena()
	_in_curs = false


func _scena() -> void:
	var c := Cutscena.porneste(self)
	_jucator.seteaza_purtat(true)
	# 1. sare în picioare, speriat
	c.priveste(_fata(), 0.35)
	Sunet.reda_la(SUNET_SCAUN, om.global_position, Sunet.VOLUM_EFECTE, 0.05, 1.4)
	Sunet.reda_la(SUNET_MAINI_SUS, om.global_position + Vector3.UP * 1.2, Sunet.VOLUM_EFECTE - 4.0, 0.05)
	var t := _tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(om, "position", _om_jos + om.basis * ridicare, 0.45)
	if scaun:
		t.tween_property(scaun, "position", _scaun_jos + scaun.basis * Vector3(0, 0, -fuga_scaun), 0.4)
	om.tresare(om.global_basis * Vector3.FORWARD)
	_maini_sus()
	await t.finished
	await c.priveste(_fata(), 0.3)
	await _spune(replici_inceput)
	# 2. se lasă încet înapoi pe scaun; tu vii în fața biroului
	om.lasa_mana("D", 1.4)
	om.lasa_mana("S", 1.4)
	t = _tween()
	t.tween_property(om, "position", _om_jos, 1.6)
	if scaun:
		t.tween_property(scaun, "position", _scaun_jos, 1.4)
	var loc := loc_jucator
	var pas := _tween()
	pas.tween_property(_jucator, "global_position", loc, 1.8)
	await pas.finished
	await c.priveste(_fata(), 0.4)
	# 3. negocierea
	var runda := 0
	var linii := replici_oferta
	while true:
		await _spune(linii.slice(0, linii.size() - 1))
		var ales := await Dialog.intreaba(linii[linii.size() - 1], PackedStringArray([optiune_haggle, optiune_accept]))
		if ales != 0:
			await _spune(replici_accept)
			break
		runda += 1
		if runda == 1:
			linii = replici_haggle_1
		elif runda == 2:
			linii = replici_haggle_2
		else:
			# ultima: amenințarea; tresare, ridică mâinile și cedează
			await _spune(replici_haggle_3.slice(0, 1))
			Sunet.reda_la(SUNET_MAINI_SUS, om.global_position + Vector3.UP * 1.2, Sunet.VOLUM_EFECTE - 4.0, 0.05)
			om.tresare(om.global_basis * Vector3.FORWARD)
			await _maini_sus()
			await _spune(replici_haggle_3.slice(1, 2))
			om.lasa_mana("D", 0.9)
			om.lasa_mana("S", 0.9)
			await _spune(replici_haggle_3.slice(2))
			break
	var suma := sume[mini(runda, sume.size() - 1)]
	# 4. banii: scoate teancul din sertar și ți-l întinde peste birou
	await _da_banii(c, suma, grosimi[mini(runda, grosimi.size() - 1)])
	Stare.marcheaza(marcaj_suma, suma)
	Stare.marcheaza(marcaj_gata)
	await c.priveste(_fata(), 0.5)
	_jucator.seteaza_purtat(false)
	await c.opreste()
	if sarcina_noua != "":
		Stare.seteaza_sarcina(sarcina_noua)


func _da_banii(c: Cutscena, suma: int, grosime: float) -> void:
	# se apleacă spre sertar (mâna dreaptă jos, sub birou), sertarul, scoate teancul
	c.priveste(om.global_transform * Vector3(-0.3, 0.75, 0.3), 0.6)
	await om.du_mana("D", om.global_transform * loc_sertar, 0.6)
	Sunet.reda_la(SUNET_SERTAR, om.global_transform * loc_sertar, Sunet.VOLUM_EFECTE - 2.0, 0.05, 0.7)
	await get_tree().create_timer(0.45).timeout
	var bani: Node3D = teanc.instantiate()
	om.nod_mana("D").add_child(bani)
	bani.global_basis = om.global_basis * Basis.from_scale(Vector3(1.0, grosime, 1.0))
	bani.global_position = om.punct_mana("D") + Vector3.UP * 0.02
	await get_tree().create_timer(0.2).timeout
	# ți-l întinde: brațul peste birou, spre tine; te uiți la mâna lui
	var predare := om.global_transform * loc_predare
	c.priveste(predare, 0.8)
	await om.du_mana("D", predare, 0.9)
	await get_tree().create_timer(0.5).timeout
	# îl iei: ți-l aduci în fața ochilor, apoi în buzunar
	bani.reparent(_camera, true)
	for m in bani.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).set_instance_shader_parameter("stralucire", 0.45)
	Sunet.reda(SUNET_BANI, Sunet.VOLUM_EFECTE - 2.0, 0.05)
	om.lasa_mana("D", 0.8)
	var t := _tween()
	t.tween_property(bani, "position", Vector3(0.0, -0.07, -0.32), 0.55)
	t.tween_property(bani, "basis", Basis(Vector3.RIGHT, 1.1) * Basis.from_scale(Vector3(1.0, grosime, 1.0)), 0.55)
	await t.finished
	await get_tree().create_timer(0.8).timeout
	t = _tween()
	t.tween_property(bani, "position", Vector3(-0.2, -0.45, -0.18), 0.4)
	await t.finished
	bani.queue_free()
	Bani.adauga(suma * 100)


## Mâinile sus, lângă cap, cu palmele spre tine (speriat).
func _maini_sus() -> void:
	var cap := om.global_position + om.global_basis * Vector3(0.0, 1.32, 0.0)
	om.du_mana("D", cap + om.global_basis * Vector3(-0.34, 0.28, 0.12), 0.3)
	await om.du_mana("S", cap + om.global_basis * Vector3(0.34, 0.28, 0.12), 0.3)


## Unde te uiți la el: fața (în picioare sau așezat).
func _fata() -> Vector3:
	return om.global_position + om.global_basis * Vector3(0.0, 1.25, 0.0)


func _spune(linii: PackedStringArray) -> void:
	if linii.is_empty():
		return
	Dialog.spune(linii)
	if Dialog.activ:
		await Dialog.terminat


func _tween() -> Tween:
	return create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
