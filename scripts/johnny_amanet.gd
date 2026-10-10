extends Interactabil
## Johnny, patronul amanetului de lângă spălătorie (amanet.tscn, pus în casino.tscn): în picioare după tejgheaua de
## sticlă, cu lupa de bijutier pe frunte (animat de OmLaMasa: respiră, se uită la tine, mâinile cu IK).
## E → `replica_intrebare` (a owner-ului) cu un buton pentru fiecare obiect din inventar pe care îl cumpără (`OFERTA`,
## în ordinea din inventar) + `optiune_nimic`. Dacă n-ai nimic de vândut: `replici_fara_marfa`.
## Alegi un obiect → o scenă: îl pui pe tejghea (iese din inventar; cadavrele le arunci cu totul pe tejghea), Johnny
## îl ridică în fața ochilor și se uită la el (cadavrele doar le privește), îl bagă sub tejghea (cadavrele le trage
## după tejghea), numără banii, îi pune pe tejghea, `replici_dupa` / `replici_cadavru`, iar tu îi iei: intră în cash (Bani).
## Prețurile sunt ale owner-ului. Ce vinzi de la Gun Store apare iar pe peretele de acolo, la prețul întreg.

## id din inventar -> numele de pe buton și prețul (dolari).
const OFERTA := {
	"pistol_roz": {"nume": "Pink Pistol", "pret": 10},
	"pistol_aur": {"nume": "Gold Pistol", "pret": 100},
	"shotgun": {"nume": "Shotgun", "pret": 5},
	"bomboana": {"nume": "Candy", "pret": 5},
	"cutit": {"nume": "Knife", "pret": 5},
	"ak47": {"nume": "AK-47", "pret": 50},
	"bazooka": {"nume": "Bazooka", "pret": 200},
	"cadavru_pisica": {"nume": "Dead Cat", "pret": 10},
	"cadavru_lexy": {"nume": "Lexy", "pret": 10},
	"cadavru_big_mike": {"nume": "Big Mike", "pret": 10},
	"cadavru_fast_eddie": {"nume": "Fast Eddie", "pret": 10},
	"katana": {"nume": "Katana", "pret": 40},
}
const SUNET_BANI := preload("res://sunete/bancnota.ogg")
const SUNET_ARMA := preload("res://sunete/arma_pe_tejghea.ogg")
const SUNET_OBIECT := preload("res://sunete/obiect_pus.ogg")
const SUNET_CADAVRU := preload("res://sunete/corp_cazut.ogg")
const MODEL_BANCNOTA := preload("res://models/bancnota.glb")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")
const ARME := ["pistol_roz", "pistol_aur", "shotgun", "cutit", "katana", "ak47", "bazooka"]

@export var om: OmLaMasa
## Unde pui obiectul pe tejghea (pe sticlă, în fața lui) și unde îți pune el banii.
@export var pe_tejghea: Marker3D
@export var plata: Marker3D
@export var replica_intrebare := "Johnny: What do you want to sell?"
@export var optiune_nimic := "Nothing"
## Replicile lui Claude (owner-ul le poate schimba): după ce ți-a cumpărat ceva, după un cadavru, când n-ai nimic.
@export_multiline var replici_dupa: PackedStringArray = ["Johnny: Pleasure doing business."]
@export_multiline var replici_cadavru: PackedStringArray = ["Johnny: I don't ask questions."]
@export_multiline var replici_fara_marfa: PackedStringArray = ["You: Nothing, just looking.", "Johnny: Then stop fogging up my glass."]

var _in_curs := false


func _ready() -> void:
	indiciu = "[E] Talk to Johnny"
	await get_tree().process_frame
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	if jucator and om:
		om.privire = jucator.get_node("Cap")


func poate_fi_folosit() -> bool:
	return not _in_curs


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	var marfa: Array[String] = []
	for id: String in Stare.obiecte.keys():
		if OFERTA.has(id):
			marfa.append(id)
	if marfa.is_empty():
		await _spune(PackedStringArray([replica_intrebare]) + replici_fara_marfa)
		_in_curs = false
		return
	var butoane := PackedStringArray()
	for id in marfa:
		butoane.append("%s - $%d" % [OFERTA[id].nume, OFERTA[id].pret])
	butoane.append(optiune_nimic)
	var i := await Dialog.intreaba(replica_intrebare, butoane)
	if i < marfa.size() and Stare.are_obiect(marfa[i]):
		await _cumpara(marfa[i])
	_in_curs = false


func _spune(replici: PackedStringArray) -> void:
	if replici.is_empty():
		return
	Dialog.spune(replici)
	if Dialog.activ:
		await Dialog.terminat


# ---------------------------------------------------------------- vânzarea

func _cumpara(id: String) -> void:
	var jucator := get_tree().get_first_node_in_group("jucator") as CharacterBody3D
	var camera: Camera3D = jucator.get_node("Cap/Camera3D")
	var scena := get_tree().current_scene
	var cadavru := Cadavre.e_cadavru(id)
	var pret: int = OFERTA[id].pret
	var c := Cutscena.porneste(self)
	await c.priveste(pe_tejghea.global_position + Vector3.UP * 0.35, 0.5)
	# 1. îl pui pe tejghea (din mână, de jos din fața ta); din clipa asta nu mai e al tău
	var obiect := _model(id)
	camera.add_child(obiect)
	if cadavru:
		obiect.position = Vector3(0.05, -0.55, -0.6)
		obiect.basis = Basis(Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0))
	else:
		obiect.position = Vector3(0.16, -0.32, -0.3)
	obiect.reparent(scena, true)
	Stare.scoate_obiect(id)
	var tinta := _pe_tejghea(id)
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(obiect, "global_transform", tinta, 0.75 if cadavru else 0.55)
	await t.finished
	if cadavru:
		Sunet.reda_la(SUNET_CADAVRU, tinta.origin, Sunet.VOLUM_EFECTE, 0.05)
	else:
		Sunet.reda_la(SUNET_ARMA if id in ARME else SUNET_OBIECT, tinta.origin, Sunet.VOLUM_EFECTE - 1.0, 0.05)
	await get_tree().create_timer(0.3).timeout
	# 2. se uită la el: obiectul îl ridică în fața ochilor, cadavrul doar îl privește lung
	om.priveste_punct = tinta.origin
	om.privire = null
	if cadavru:
		await get_tree().create_timer(1.4).timeout
		await _trage_dupa_tejghea(obiect)
	else:
		await _ridica_si_ia(obiect)
	om.priveste_punct = Vector3.INF
	om.privire = jucator.get_node("Cap")
	# 3. numără banii (de sub tejghea) și ți-i pune pe tejghea
	await get_tree().create_timer(0.2).timeout
	var teanc := _teanc(clampi(pret / 20 + 1, 1, 6))
	var sub := om.global_position + om.global_basis * Vector3(0.22, 0.8, 0.12)
	await om.du_mana("S", sub, 0.45)
	om.nod_mana("S").add_child(teanc)
	teanc.position = Vector3.ZERO
	Sunet.reda_la(SUNET_BANI, sub, Sunet.VOLUM_EFECTE - 3.0, 0.05)
	await om.du_mana("S", plata.global_position + Vector3.UP * 0.03, 0.6)
	teanc.reparent(scena, true)
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(teanc, "global_transform", Transform3D(Basis(Vector3.UP, 0.3), plata.global_position + Vector3.UP * 0.004), 0.15)
	Sunet.reda_la(SUNET_BANI, plata.global_position, Sunet.VOLUM_EFECTE, 0.05)
	om.lasa_mana("S", 0.5)
	await get_tree().create_timer(0.35).timeout
	await _spune(replici_cadavru if cadavru else replici_dupa)
	# 4. iei banii: vin spre tine și intră în cash
	teanc.reparent(camera, true)
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(teanc, "position", Vector3(0.2, -0.45, -0.15), 0.4)
	await t.finished
	teanc.queue_free()
	Sunet.reda(SUNET_BANI, Sunet.VOLUM_EFECTE - 2.0, 0.05)
	Bani.adauga(pret * 100)
	await c.opreste()


## Modelul obiectului vândut: cadavrele cu corpul moale (Cadavre), restul ca pe jos (ObiecteLume).
func _model(id: String) -> Node3D:
	if Cadavre.e_cadavru(id):
		return Cadavre.suport(id)
	var date: Dictionary = ObiecteLume.MODELE[id]
	var nod := Node3D.new()
	var m := ObiecteLume.model(id)
	var marime: float = date.get("marime", 1.0)
	m.rotation = date.jos
	m.scale = Vector3.ONE * marime
	m.position.y = float(date.ridicare) * marime
	nod.add_child(m)
	return nod


## Cum stă pe tejghea: obiectele culcate, întoarse puțin spre el; cadavrele culcate pe spate, de-a lungul tejghelei
## (pisica pe o parte).
func _pe_tejghea(id: String) -> Transform3D:
	var p := pe_tejghea.global_position
	if not Cadavre.e_cadavru(id):
		return Transform3D(Basis(Vector3.UP, 0.4), p)
	if Cadavre.MODELE[id].get("mic", false):
		return Transform3D(Basis(Vector3.BACK, PI / 2.0), p + Vector3.UP * 0.07)
	return Transform3D(Cadavre.culcat(Vector3.LEFT), p + Vector3.UP * 0.12)


## Obiectul îl ia cu dreapta, îl ridică în fața ochilor (lupa e pe frunte), îl învârte puțin, apoi îl bagă sub tejghea.
func _ridica_si_ia(obiect: Node3D) -> void:
	await om.du_mana("D", obiect.global_position + Vector3.UP * 0.02, 0.5)
	obiect.reparent(om.nod_mana("D"), true)
	var ochi := om.gura() + om.global_basis * Vector3(0.04, 0.06, 0.3)
	om.priveste_punct = ochi
	await om.du_mana("D", ochi, 0.6)
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(obiect, "rotation:y", obiect.rotation.y + 1.2, 0.8)
	t.tween_property(obiect, "rotation:y", obiect.rotation.y - 0.4, 0.6)
	await t.finished
	await om.du_mana("D", om.global_position + om.global_basis * Vector3(-0.2, 0.8, 0.1), 0.5)
	obiect.queue_free()
	om.lasa_mana("D", 0.4)


## Cadavrul îl prinde cu ambele mâini, îl trage spre el până la marginea din spate a tejghelei și îl lasă să cadă jos,
## între tejghea și el.
func _trage_dupa_tejghea(obiect: Node3D) -> void:
	var prinze: Array[Marker3D] = []
	for x in [-0.25, 0.25]:
		var m := Marker3D.new()
		obiect.add_child(m)
		m.global_position = obiect.global_position + Vector3(x, 0.05, 0.08)
		prinze.append(m)
	om.du_mana("D", prinze[0], 0.55)
	await om.du_mana("S", prinze[1], 0.55)
	await get_tree().create_timer(0.15).timeout
	# „spre el” = spre spatele tejghelei: jumătatea drumului dintre tejghea și el
	var margine := pe_tejghea.global_position.lerp(om.global_position, 0.75)
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(obiect, "global_position", Vector3(margine.x, obiect.global_position.y + 0.04, margine.z), 0.55)
	await t.finished
	om.lasa_mana("D", 0.3)
	om.lasa_mana("S", 0.3)
	t = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(obiect, "global_position:y", om.global_position.y + 0.1, 0.3)
	await t.finished
	Sunet.reda_la(SUNET_CADAVRU, obiect.global_position, Sunet.VOLUM_EFECTE - 2.0, 0.05)
	obiect.queue_free()


## Un teanc de bancnote, puțin răsfirate.
func _teanc(cate: int) -> Node3D:
	var n := Node3D.new()
	for k in cate:
		var b := MODEL_BANCNOTA.instantiate() as Node3D
		b.set_script(SCRIPT_MODEL)
		b.set("material", MATERIAL)
		b.set("umbre", false)
		b.position = Vector3(randf_range(-0.008, 0.008), 0.0015 * k, randf_range(-0.008, 0.008))
		b.rotation.y = randf_range(-0.25, 0.25)
		n.add_child(b)
	return n
