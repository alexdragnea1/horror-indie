extends Interactabil
## Gun Clerk, vânzătorul de la „Freedom” (magazin_arme.tscn): un cowboy modern, în picioare după tejghea (animat de
## OmLaMasa: respiră, se uită la tine, mâinile cu IK). E → `replica_intrebare` (a owner-ului) cu butoanele din `OFERTA`
## (ordonate după preț, fără ce ai deja) + `optiune_nimic`. Alegi:
##  - n-ai destui bani (cash, Bani, plus bancnota de 5 dolari): `replici_fara_bani`, sau `replici_jetoane` dacă ai
##    destule jetoane (Jetoane; cash out la bătrâna de la casino);
##  - inventarul e plin: `replici_plin`;
##  - altfel o scenă: pui banii pe tejghea, el îi strânge, se întoarce la peretele cu arme, ia arma (cu ambele mâini,
##    dacă e lungă), se întoarce și ți-o pune pe tejghea, `replici_dupa` (owner: „Excellent choice.”), o iei: intră în
##    inventar și o ții deja în mână.
## Armele de pe perete sunt nodurile din `raft` (Cutit, Shotgun, AK47, Bazooka); ce ai deja nu mai stă pe perete.
## Fără bani și fără nimic de vândut la Johnny: „Rob him” (vezi grupul Jaful) și îți dă mereu bazooka, cu aceeași scenă.
## La perete merge până în dreptul armei (`_loc_la_raft`), ca s-o prindă cu mâinile pe ea.

const OFERTA := [
	{"id": "cutit", "nume": "Knife", "pret": 5, "raft": "Cutit"},
	{"id": "shotgun", "nume": "Shotgun", "pret": 25, "raft": "Shotgun"},
	{"id": "ak47", "nume": "AK-47", "pret": 250, "raft": "AK47"},
	{"id": "bazooka", "nume": "Bazooka", "pret": 500, "raft": "Bazooka"},
]
## Unde prinde fiecare armă cu mâna stângă (în coordonatele armei; dreapta e mânerul, originea); null = o mână.
const PRINZA_S := {"Cutit": null, "Shotgun": Vector3(0, -0.01, -0.33), "AK47": Vector3(0, 0, -0.3), "Bazooka": Vector3(0, -0.09, -0.3)}
## Cât de departe de mâner (spre țeavă) îi vine mijlocul corpului când o ia de pe perete.
const CENTRU := {"Cutit": 0.22, "Shotgun": 0.17, "AK47": 0.15, "Bazooka": 0.15}
## Cum stă arma culcată pe tejghea (îndreptată spre +X) și cât o ridici ca să nu intre în sticlă.
const CULCAT_DREAPTA := Basis(Vector3(0, 1, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0))
const CULCAT_STANGA := Basis(Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0))
const PE_TEJGHEA := {"Cutit": [CULCAT_DREAPTA, 0.018], "Shotgun": [CULCAT_DREAPTA, 0.027], "AK47": [CULCAT_DREAPTA, 0.026],
	"Bazooka": [CULCAT_STANGA, 0.066]}
const SUNET_BANI := preload("res://sunete/bancnota.ogg")
const MODEL_BANCNOTA := preload("res://models/bancnota.glb")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")
const SUNET_BANI_STRANSI := preload("res://sunete/bancnota.ogg")
const SUNET_PUSA := preload("res://sunete/arma_pe_tejghea.ogg")
const SUNET_LUATA := preload("res://sunete/arma_scoasa.ogg")
const SUNET_PASI := [preload("res://sunete/pas_lemn_1.ogg"), preload("res://sunete/pas_lemn_2.ogg"), preload("res://sunete/pas_lemn_3.ogg")]
## Ce cumpără Johnny de la amanet (pentru jaf: „nu mai ai ce vinde”).
const JOHNNY := preload("res://scripts/johnny_amanet.gd")

@export var om: OmLaMasa
## Peretele cu armele de vânzare (copiii: Cutit, Shotgun, AK47, Bazooka).
@export var raft: Node3D
## Unde îi pune arma pe tejghea și unde pui tu jetoanele.
@export var pe_tejghea: Marker3D
@export var plata: Marker3D
## Cât face un pas înapoi spre perete (metri) când se întoarce după armă.
@export var pas_spre_raft := 1.22
@export var replica_intrebare := "Gun Clerk: What can I do for you today?"
@export var optiune_nimic := "Nothing"
@export_multiline var replici_dupa: PackedStringArray = ["Gun Clerk: Excellent choice."]
@export_multiline var replici_fara_bani: PackedStringArray = ["Gun Clerk: You can't afford that, partner."]
@export_multiline var replici_plin: PackedStringArray = ["Gun Clerk: Your hands are full, partner."]
## Ai destule jetoane, dar nu și cash (replica lui Claude): jetoanele se schimbă pe bani la bătrâna de la casino.
@export_multiline var replici_jetoane: PackedStringArray = ["Gun Clerk: We don't take casino chips, partner. Cash only."]

@export_group("Jaful")
## Când n-ai niciun ban (cash, bancnota de 5, jetoane) și nimic de vândut la Johnny (johnny_amanet.gd), iar bazooka nu e
## a ta: apare `optiune_jaf`, `replici_jaf` și el ți-o aduce ca la cumpărare, doar că fără bani; apoi
## `replici_dupa_jaf` (replicile owner-ului, 08.10). Marcaj `marcaj_jaf`.
@export var optiune_jaf := "Rob him"
@export var id_jaf := "bazooka"
@export var marcaj_jaf := "a_jefuit_gun_store"
@export_multiline var replici_jaf: PackedStringArray = ["You: Give me the bazooka bitch!"]
@export_multiline var replici_dupa_jaf: PackedStringArray = ["You: Thanks bitch."]

var _in_curs := false
## La jaf: vraja ridicată (de coborât la final) și unde stătea mâna înainte.
var _vraja_jaf: VrajaFoc
var _pozitie_vraja := Vector3.ZERO


func _ready() -> void:
	indiciu = "[E] Talk to the Gun Clerk"
	await get_tree().process_frame
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	if jucator and om:
		om.privire = jucator.get_node("Cap")
	for o in OFERTA:
		var arma := raft.get_node_or_null(String(o.raft)) as Node3D
		if arma:
			arma.visible = not _o_are(o.id)


func poate_fi_folosit() -> bool:
	return not _in_curs


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	var disponibile := OFERTA.filter(func(o: Dictionary) -> bool: return not _o_are(o.id))
	var butoane := PackedStringArray()
	for o in disponibile:
		butoane.append("%s - $%d" % [o.nume, o.pret])
	var poate_jefui := _poate_jefui()
	if poate_jefui:
		butoane.append(optiune_jaf)
	butoane.append(optiune_nimic)
	var i := await Dialog.intreaba(replica_intrebare, butoane)
	if poate_jefui and i == disponibile.size():
		_ridica_fireball()
		await _spune(replici_jaf)
		if Stare.obiecte.size() >= Stare.LOCURI_INVENTAR:
			await _spune(replici_plin)
		else:
			for o: Dictionary in OFERTA:
				if o.id == id_jaf:
					await _vinde(o, true)
		_coboara_fireball()
	elif i < disponibile.size():
		var o: Dictionary = disponibile[i]
		var pret: int = o.pret * 100
		if Bani.de_platit() < pret:
			await _spune(replici_jetoane if Jetoane.suma() >= pret else replici_fara_bani)
		elif _locuri_dupa_plata(pret) >= Stare.LOCURI_INVENTAR:
			await _spune(replici_plin)
		else:
			await _vinde(o)
	_in_curs = false


## Jaful: niciun ban (cash, bancnota de 5, jetoane), nimic ce cumpără Johnny în inventar, iar bazooka n-o ai deja.
func _poate_jefui() -> bool:
	if _o_are(id_jaf) or Bani.de_platit() > 0 or Jetoane.suma() > 0:
		return false
	for id: String in Stare.obiecte.keys():
		if JOHNNY.OFERTA.has(id):
			return false
	return true


## Jaful îl faci cu Fireball-ul în mână (owner, 09.10): focul se aprinde în palmă (scântei, apoi flacăra) și stă sus
## toată scena (`demonstratie`, ca la lecția cu Helga: și în dialog, și cu benzile negre), chiar dacă vraja nu e în
## inventar: dacă e, o ții în mână până iei bazooka; dacă nu, mâinile rămân goale și focul coboară când îți întinde
## arma (acolo se oprește `demonstratie`). Cât e jaful, mâna stă mai sus și mai spre mijloc (`POZITIE_JAF`), întinsă
## spre el, deasupra casetei de dialog (jos în dreapta o acoperea caseta).
const POZITIE_JAF := Vector3(0.13, -0.07, -0.42)
func _ridica_fireball() -> void:
	var jucator := get_tree().get_first_node_in_group("jucator")
	var vraja := jucator.get_node_or_null("Cap/Camera3D/VrajaFoc") as VrajaFoc if jucator else null
	if vraja == null:
		return
	Stare.tine_in_mana(VrajaFoc.ID if Stare.are_obiect(VrajaFoc.ID) else "")
	VrajaFoc.demonstratie = true
	_vraja_jaf = vraja
	_pozitie_vraja = vraja.pozitie
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(vraja, "pozitie", POZITIE_JAF, 0.6)
	vraja.stinge()
	vraja.aprinde(1.2)


## Sfârșitul jafului: mâna revine unde era, iar fără vraja în inventar focul coboară.
func _coboara_fireball() -> void:
	VrajaFoc.demonstratie = false
	if is_instance_valid(_vraja_jaf):
		create_tween().set_trans(Tween.TRANS_SINE).tween_property(_vraja_jaf, "pozitie", _pozitie_vraja, 0.5)
		_vraja_jaf = null


## Câte obiecte ai în inventar după ce plătești `pret` (cash-ul dispare dacă dai tot).
func _locuri_dupa_plata(pret: int) -> int:
	return Stare.obiecte.size() - (1 if Bani.suma() <= pret else 0)


## Ai deja arma (în inventar, aruncată pe jos sau pe raftul de acasă).
func _o_are(id: String) -> bool:
	return Stare.are_obiect(id) or Stare.e_aruncat(id) or Stare.e_pe_raft(id)


func _spune(replici: PackedStringArray) -> void:
	if replici.is_empty():
		return
	Dialog.spune(replici)
	if Dialog.activ:
		await Dialog.terminat



# ---------------------------------------------------------------- vânzarea

## `jaf` = îți dă arma fără bani (Rob him): fără pașii 1–2, iar la final `replici_dupa_jaf` și `marcaj_jaf`.
func _vinde(o: Dictionary, jaf := false) -> void:
	var jucator := get_tree().get_first_node_in_group("jucator") as CharacterBody3D
	var camera: Camera3D = jucator.get_node("Cap/Camera3D")
	var scena := get_tree().current_scene
	var c := Cutscena.porneste(self)
	if jaf:
		await c.priveste(om.global_position + Vector3.UP * 1.55, 0.5)
	else:
		await c.priveste(plata.global_position, 0.5)
		await _plateste(o, camera, scena)
	var t: Tween
	# 3. se întoarce la peretele cu arme și face pașii până la el
	var arma_raft := raft.get_node(String(o.raft)) as Node3D
	c.priveste(arma_raft.global_position + Vector3.DOWN * 0.3, 0.9)
	var repaus_om := om.transform
	var loc_raft := _loc_la_raft(arma_raft, o.raft)
	var durata_drum := 0.7 + om.position.distance_to(loc_raft) * 0.35
	await _mergi(loc_raft, PI, durata_drum)
	# 4. ia arma de pe perete (o copie; cea de pe perete dispare)
	var arma := arma_raft.duplicate() as Node3D
	scena.add_child(arma)
	arma.global_transform = arma_raft.global_transform
	arma_raft.hide()
	var prinza_d := Marker3D.new()
	arma.add_child(prinza_d)
	var prinza_s: Marker3D = null
	om.du_mana("D", prinza_d, 0.55)
	if PRINZA_S[o.raft] != null:
		prinza_s = Marker3D.new()
		arma.add_child(prinza_s)
		prinza_s.position = PRINZA_S[o.raft]
		om.du_mana("S", prinza_s, 0.6)
	await get_tree().create_timer(0.65).timeout
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(arma, "global_position", arma.global_position + Vector3(0, 0.06, 0.18), 0.35)
	await t.finished
	# o coboară în fața pieptului (mânerul în dreapta lui, țeava spre stânga): așa o duce, nu sus la nivelul raftului,
	# unde la întoarcere îi încrucișa brațele (owner, 08.10)
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(arma, "global_position", om.to_global(Vector3(-float(CENTRU[o.raft]), 1.12, 0.38)), 0.45)
	await t.finished
	# 5. se întoarce cu ea (arma merge cu el) și o pune culcată pe tejghea
	arma.reparent(om, true)
	c.priveste(pe_tejghea.global_position, 1.0)
	await _mergi(repaus_om.origin, 0.0, durata_drum)
	arma.reparent(scena, true)
	var culcat: Array = PE_TEJGHEA[o.raft]
	var tinta := Transform3D(culcat[0], pe_tejghea.global_position + Vector3.UP * float(culcat[1]))
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(arma, "global_transform", tinta, 0.7)
	await t.finished
	Sunet.reda_la(SUNET_PUSA, pe_tejghea.global_position, Sunet.VOLUM_EFECTE - 1.0, 0.05)
	om.lasa_mana("D", 0.5)
	if prinza_s:
		om.lasa_mana("S", 0.5)
	await get_tree().create_timer(0.3).timeout
	await _spune(replici_dupa_jaf if jaf else replici_dupa)
	# 6. o iei: vine spre tine și intră în inventar, deja în mână (la jaf, Fireball-ul de până acum o lasă locul)
	_coboara_fireball()
	await c.priveste(arma.global_position, 0.3)
	arma.reparent(camera, true)
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(arma, "position", Vector3(0.25, -0.5, -0.15), 0.45)
	await t.finished
	arma.queue_free()
	Sunet.reda(SUNET_LUATA, Sunet.VOLUM_EFECTE - 2.0, 0.05)
	Stare.adauga_obiect(o.id, o.nume)
	Stare.tine_in_mana(o.id)
	Stare.marcheaza("a_cumparat_arma")  # după el, la ieșire, mesajul lui Head Witch (MesajSefa)
	if jaf:
		Stare.marcheaza(marcaj_jaf)
	await c.opreste()


## Pașii 1–2 ai cumpărării: pui banii pe tejghea, el îi strânge cu stânga și îi bagă sub tejghea.
func _plateste(o: Dictionary, camera: Camera3D, scena: Node) -> void:
	var teanc := _teanc(clampi(int(o.pret / 25) + 1, 1, 8))
	camera.add_child(teanc)
	teanc.position = Vector3(0.18, -0.42, -0.2)
	teanc.reparent(scena, true)
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(teanc, "global_position", plata.global_position, 0.55)
	await t.finished
	Sunet.reda_la(SUNET_BANI, plata.global_position, Sunet.VOLUM_EFECTE, 0.05)
	Bani.plateste(int(o.pret) * 100)
	await om.du_mana("S", plata.global_position + Vector3.UP * 0.05, 0.55)
	teanc.reparent(om.nod_mana("S"), true)
	Sunet.reda_la(SUNET_BANI_STRANSI, plata.global_position, Sunet.VOLUM_EFECTE - 2.0, 0.05)
	await om.du_mana("S", om.global_position + om.global_basis * Vector3(0.25, 0.85, 0.05), 0.5)
	teanc.queue_free()
	om.lasa_mana("S", 0.4)


## Unde stă în fața peretelui (în coordonatele părintelui lui `om`): cu arma în fața lui, mânerul spre dreapta lui și
## restul armei în stânga, ca să n-ajungă cu brațele încrucișate sau să nu ajungă deloc la ea (owner, 08.10: cuțitul,
## care e mai încolo pe perete, îi rămânea în aer).
func _loc_la_raft(arma_raft: Node3D, nume: String) -> Vector3:
	var teava := -arma_raft.global_basis.z.normalized()
	var mijloc := arma_raft.global_position + teava * float(CENTRU[nume])
	var loc: Vector3 = (om.get_parent() as Node3D).to_local(Vector3(mijloc.x, om.global_position.y, mijloc.z))
	return Vector3(loc.x, om.position.y, om.position.z - pas_spre_raft)


## Merge (alunecă, cu un mic legănat la fiecare pas și sunetul pașilor) până la `unde` (în coordonatele părintelui lui
## `om`), întorcându-se spre `unghi` (0 = spre tejghea, PI = spre perete).
func _mergi(unde: Vector3, unghi: float, durata: float) -> void:
	var de_la := om.position
	var unghi0 := om.rotation.y
	var pasi := 3
	var misca := func(v: float) -> void:
		om.position = de_la.lerp(unde, v) + Vector3.UP * absf(sin(v * PI * pasi)) * 0.025
		om.rotation.y = lerp_angle(unghi0, unghi, clampf(v * 1.6, 0.0, 1.0))
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(misca, 0.0, 1.0, durata)
	for i in pasi:
		Sunet.reda_la(SUNET_PASI[i % SUNET_PASI.size()], om.global_position, Sunet.VOLUM_PASI - 2.0, 0.1)
		await get_tree().create_timer(durata / pasi).timeout
	if t.is_running():
		await t.finished


## Un teanc de bancnote (plata), puțin răsfirate.
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
