extends Interactabil
## Bătrâna de la casa camerei de joc („Old bitch”, la tejghea, imediat după ușă). La început e singura cu care poți
## vorbi (masa de poker și păcănelele merg doar cu jetoane). E → `replici` (ale owner-ului), apoi:
##  - cu bani (cash, `Bani`; bancnota de 5 dolari de la Lexy e și ea în el): îi scoți și i-i întinzi prin ghișeu (o
##    bancnotă), ea îi ia, îi bagă în cutia de bani și îți împinge pe tejghea un teanc de jetoane cât toată suma;
##  - fără: `replici_fara_bani` (owner).
## Cu jetoane în inventar, E = direct butoanele (cu prima replică deasupra): `optiune_schimb` (doar cu cash,
## schimbă tot), `optiune_cash_out` (toate jetoanele → „Cash ($X)”, Bani; `_cash_out`), `optiune_nimic`.
## După prima conversație: `marcaj_vorbit` (de el depinde și gândul „Maybe Lexy could lend me some money..” de la ieșire).

@export var om: OmLaMasa
## Ghișeul (unde îi întinzi bancnota), cutia de bani (unde o bagă) și tava cu jetoane (de unde le ia).
@export var ghiseu: Marker3D
@export var cutie_bani: Marker3D
@export var tava: Marker3D
@export var marcaj_vorbit := "a_vorbit_cu_batrana_casino"
@export var marcaj_schimb := "a_schimbat_banii"
@export_multiline var replici_inceput: PackedStringArray = ["Old bitch: Hey sweetie, you can exchange cash here.",
	"Old bitch: Do you have any?"]
@export_multiline var replici_fara_bani: PackedStringArray = ["Old bitch: Come here when you have money poor bitch.",
	"You: Kill yourself.", "Old bitch: Try the pawn shop next door."]
## Butoanele când ai jetoane (`%s` = cât valorează jetoanele).
@export var optiune_schimb := "Exchange cash"
@export var optiune_cash_out := "Cash out (%s)"
@export var optiune_nimic := "Nothing"
## Sarcinile care dispar după schimb (dacă e una din ele cea curentă).
@export var sarcini_de_sters: PackedStringArray = ["Go to the casino.", "Ask Lexy for money."]
@export var sunet_bancnota: AudioStream = preload("res://sunete/bancnota.ogg")
@export var sunet_jetoane: AudioStream = preload("res://sunete/jetoane_puse.ogg")
@export var sunet_luat: AudioStream = preload("res://sunete/jetoane_stranse.ogg")

const MODEL_BANCNOTA := preload("res://models/bancnota.glb")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")

var _in_curs := false


func _ready() -> void:
	indiciu = "[E] Talk to the old lady"
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
	var ai_cash := Bani.suma() > 0
	if Jetoane.suma() <= 0:
		# fără jetoane, ca la început: replicile owner-ului, apoi schimbul (sau „poor bitch”)
		await _spune(replici_inceput)
		Stare.marcheaza(marcaj_vorbit)
		if ai_cash:
			await _schimba()
		else:
			await _spune(replici_fara_bani)
	else:
		# cu jetoane: butoanele (schimbul, dacă ai cash; cash out-ul; nimic)
		var optiuni := PackedStringArray()
		if ai_cash:
			optiuni.append(optiune_schimb)
		optiuni.append(optiune_cash_out % Jetoane.bani(Jetoane.suma()))
		optiuni.append(optiune_nimic)
		var i := await Dialog.intreaba(replici_inceput[0], optiuni)
		if ai_cash and i == 0:
			await _schimba()
		elif i == optiuni.size() - 2:
			await _cash_out()
	_in_curs = false


func _spune(replici: PackedStringArray) -> void:
	if replici.is_empty():
		return
	Dialog.spune(replici)
	if Dialog.activ:
		await Dialog.terminat


## Bancnota pe jetoane: tu o întinzi prin ghișeu, ea o ia și o bagă în cutie, apoi îți împinge jetoanele.
func _schimba() -> void:
	# tot cash-ul (și bancnota de 5 dolari de la Lexy e în el)
	var valoare := Bani.suma()
	var jucator := get_tree().get_first_node_in_group("jucator") as CharacterBody3D
	var cap: Node3D = jucator.get_node("Cap")
	var camera: Camera3D = cap.get_node("Camera3D")
	var c := Cutscena.porneste(self)
	jucator.seteaza_purtat(true)
	await c.priveste(ghiseu.global_position, 0.5)
	# scoți bancnota din buzunar (jos în dreapta) și o întinzi
	var b := MODEL_BANCNOTA.instantiate() as Node3D
	b.set_script(SCRIPT_MODEL)
	b.set("material", MATERIAL)
	b.set("umbre", false)
	camera.add_child(b)
	for m in b.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).set_instance_shader_parameter("stralucire", 0.45)
	b.position = Vector3(0.2, -0.45, -0.2)
	b.basis = Basis(Vector3.RIGHT, 0.4) * Basis(Vector3.FORWARD, 0.6)
	Sunet.reda(sunet_bancnota, Sunet.VOLUM_EFECTE - 2.0, 0.05)
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(b, "position", Vector3(0.03, -0.08, -0.32), 0.5)
	t.tween_property(b, "basis", Basis(Vector3.RIGHT, PI / 2.0 - 0.25), 0.5)
	await t.finished
	await get_tree().create_timer(0.3).timeout
	# o întinzi până la ghișeu
	b.reparent(get_tree().current_scene, true)
	var predare := ghiseu.global_position + Vector3.UP * 0.12
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(b, "global_position", predare, 0.6)
	om.du_mana("D", predare, 0.7)
	await t.finished
	await om.du_mana("D", predare, 0.15)
	# o ia: bancnota trece în mâna ei
	b.reparent(om.nod_mana("D"), true)
	Sunet.reda_la(sunet_bancnota, predare, Sunet.VOLUM_EFECTE - 3.0, 0.05)
	Bani.seteaza(0)
	await c.priveste(om.global_position + Vector3.UP * 1.3, 0.5)
	await om.du_mana("D", cutie_bani.global_position + Vector3.UP * 0.12, 0.6)
	b.queue_free()
	Sunet.reda_la(sunet_bancnota, cutie_bani.global_position, Sunet.VOLUM_EFECTE - 6.0, 0.1)
	await get_tree().create_timer(0.2).timeout
	# ia un teanc de jetoane din tavă și ți-l împinge pe tejghea, până la ghișeu
	await om.du_mana("D", tava.global_position + Vector3.UP * 0.05, 0.6)
	var teanc := _teanc()
	om.nod_mana("D").add_child(teanc)
	teanc.position = Vector3(0, -0.03, 0)
	Sunet.reda_la(sunet_jetoane, tava.global_position, Sunet.VOLUM_EFECTE - 3.0, 0.05)
	var pe_tejghea := ghiseu.global_position + Vector3.UP * 0.005
	await om.du_mana("D", pe_tejghea + Vector3.UP * 0.04, 0.8)
	teanc.reparent(get_tree().current_scene, true)
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(teanc, "global_position", pe_tejghea, 0.2)
	Sunet.reda_la(sunet_jetoane, pe_tejghea, Sunet.VOLUM_EFECTE, 0.05)
	om.lasa_mana("D", 0.8)
	await c.priveste(pe_tejghea, 0.4)
	await get_tree().create_timer(0.3).timeout
	# le iei: vin spre tine și dispar în buzunar
	teanc.reparent(camera, true)
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(teanc, "position", Vector3(0.18, -0.4, -0.15), 0.45)
	await t.finished
	teanc.queue_free()
	Sunet.reda(sunet_luat, Sunet.VOLUM_EFECTE - 2.0, 0.05)
	Jetoane.adauga(valoare)
	Stare.marcheaza(marcaj_schimb)
	# sarcinile drumului după bani s-au făcut: dispar, fără mesaj nou
	if Stare.sarcina in sarcini_de_sters:
		Stare.sarcina = ""
		Stare.schimbat.emit()
	await c.priveste(om.global_position + Vector3.UP * 1.3, 0.4)
	jucator.seteaza_purtat(false)
	await c.opreste()


## Cash out: împingi jetoanele pe tejghea prin ghișeu, ea le strânge în tavă, scoate banii din cutie și ți-i întinde;
## îi iei (toate jetoanele devin „Cash ($X)”).
func _cash_out() -> void:
	var valoare := Jetoane.suma()
	var jucator := get_tree().get_first_node_in_group("jucator") as CharacterBody3D
	var camera: Camera3D = jucator.get_node("Cap/Camera3D")
	var scena := get_tree().current_scene
	var c := Cutscena.porneste(self)
	jucator.seteaza_purtat(true)
	await c.priveste(ghiseu.global_position, 0.5)
	# 1. scoți jetoanele din buzunar și le pui pe tejghea, la ghișeu
	var teanc := _teanc()
	camera.add_child(teanc)
	teanc.position = Vector3(0.18, -0.42, -0.2)
	teanc.reparent(scena, true)
	var pe_tejghea := ghiseu.global_position + Vector3.UP * 0.005
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(teanc, "global_position", pe_tejghea, 0.6)
	await t.finished
	Sunet.reda_la(sunet_jetoane, pe_tejghea, Sunet.VOLUM_EFECTE, 0.05)
	Jetoane.seteaza(0)
	# 2. ea le ia și le pune în tavă
	await c.priveste(om.global_position + Vector3.UP * 1.3, 0.5)
	await om.du_mana("D", pe_tejghea + Vector3.UP * 0.04, 0.7)
	teanc.reparent(om.nod_mana("D"), true)
	Sunet.reda_la(sunet_luat, pe_tejghea, Sunet.VOLUM_EFECTE - 3.0, 0.05)
	await om.du_mana("D", tava.global_position + Vector3.UP * 0.05, 0.6)
	teanc.queue_free()
	Sunet.reda_la(sunet_jetoane, tava.global_position, Sunet.VOLUM_EFECTE - 4.0, 0.05)
	await get_tree().create_timer(0.2).timeout
	# 3. scoate banii din cutie și ți-i întinde prin ghișeu
	await om.du_mana("D", cutie_bani.global_position + Vector3.UP * 0.12, 0.6)
	var b := MODEL_BANCNOTA.instantiate() as Node3D
	b.set_script(SCRIPT_MODEL)
	b.set("material", MATERIAL)
	b.set("umbre", false)
	om.nod_mana("D").add_child(b)
	b.position = Vector3(0, -0.02, 0)
	Sunet.reda_la(sunet_bancnota, cutie_bani.global_position, Sunet.VOLUM_EFECTE - 3.0, 0.05)
	var predare := ghiseu.global_position + Vector3.UP * 0.12
	await om.du_mana("D", predare, 0.8)
	await c.priveste(predare, 0.3)
	# 4. îi iei: vin spre tine și intră în buzunar
	b.reparent(camera, true)
	om.lasa_mana("D", 0.8)
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	t.tween_property(b, "position", Vector3(0.2, -0.45, -0.2), 0.45)
	await t.finished
	b.queue_free()
	Sunet.reda(sunet_bancnota, Sunet.VOLUM_EFECTE - 2.0, 0.05)
	Bani.adauga(valoare)
	await c.priveste(om.global_position + Vector3.UP * 1.3, 0.4)
	jucator.seteaza_purtat(false)
	await c.opreste()


## Teancul de jetoane: 5 jetoane albe de câte un dolar.
func _teanc() -> Node3D:
	var n := Node3D.new()
	var m := CylinderMesh.new()
	m.top_radius = MasaPoker.RAZA_JETON
	m.bottom_radius = MasaPoker.RAZA_JETON
	m.height = MasaPoker.GROSIME_JETON
	m.radial_segments = 10
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("83b3b0")
	var dunga := StandardMaterial3D.new()
	dunga.albedo_color = Color("7b383a")
	for k in 5:
		var j := MeshInstance3D.new()
		j.mesh = m
		j.material_override = dunga if k % 2 else mat
		j.position.y = MasaPoker.GROSIME_JETON * (k + 0.5)
		n.add_child(j)
	return n
