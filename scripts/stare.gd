extends CanvasLayer
## Autoload "Stare": ține minte ce are jucătorul și ce s-a întâmplat în poveste.
##   Stare.adauga_obiect("cheie_hol", "Hall key")   -> false dacă inventarul e plin
##   Stare.are_obiect("cheie_hol")  /  Stare.scoate_obiect("cheie_hol")
##   Stare.marcheaza("a_vorbit_cu_mom")  /  Stare.e_marcat("a_vorbit_cu_mom")
##   Stare.seteaza_sarcina("Meet with the coven.")  -> apare sus câteva secunde
## Tab deschide / închide inventarul (sloturile + sarcina curentă). Click pe un slot = îl ții în mână
## (`in_mana`, vezi Pistol și ObiectInMana); click pe un slot gol sau pe cel din mână = mâinile goale.
## Click dreapta pe un slot = îl arunci pe jos (`aruncate`, rămâne și în salvare; vezi ObiecteLume, ObiectAruncat).
## Raftul din camera ta (RaftDepozit) ține până la `LOCURI_RAFT` obiecte (`raft`); E pe el = fereastra raftului.

signal schimbat

## Câte obiecte încap în inventar.
const LOCURI_INVENTAR := 5
## Câte obiecte încap pe raftul din camera ta.
const LOCURI_RAFT := 5
## Cât stă pe ecran mesajul „Picked up: ...” (secunde).
const DURATA_MESAJ := 2.5
## Cât stă sus „Task: ...” când primești o sarcină nouă (secunde).
const DURATA_SARCINA := 5.0
const SUNET_OBIECT := preload("res://sunete/obiect_luat.ogg")
const SUNET_SARCINA := preload("res://sunete/sarcina_noua.ogg")
const SUNET_DESCHIDE := preload("res://sunete/inventar_deschis.ogg")
const SUNET_INCHIDE := preload("res://sunete/inventar_inchis.ogg")
const SUNET_ARUNCAT := preload("res://sunete/obiect_aruncat.ogg")
const SUNET_PUS := preload("res://sunete/obiect_pus.ogg")

## id -> numele afișat, în ordinea în care le-ai luat.
var obiecte: Dictionary = {}
var marcaje: Dictionary = {}
## Ce trebuie să faci acum ("" = nimic).
var sarcina := ""
## Numele scris de jucător în meniul de la ușa camerei.
var nume_jucator := ""
## Cât e deschis un meniu (MeniuNume, inventarul), jucătorul nu se mișcă și nu se uită în jur.
var meniu_deschis := false
## Id-ul obiectului din mână ('' = nimic). Se schimbă cu tine_in_mana().
var in_mana := ""
## Ce e pe raftul din camera ta: id -> nume, în ordine.
var raft: Dictionary = {}
## Ce ai aruncat pe jos: id -> {scena, nume, poz: [x, y, z], unghi}.
var aruncate: Dictionary = {}
## Lanterna aprinsă sau stinsă; rămâne așa și în scena următoare, și în salvare.
var lanterna := true

var _mesaj: Label
var _sarcina_sus: Label
var _inventar: Inventar
var _panou_raft: PanouRaft
var _tween_mesaj: Tween
var _tween_sarcina: Tween


func _ready() -> void:
	layer = 6
	_mesaj = _eticheta()
	_mesaj.position = Vector2(8, 6)
	_sarcina_sus = _eticheta()
	_sarcina_sus.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_sarcina_sus.offset_top = 16
	_sarcina_sus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sarcina_sus.add_theme_font_size_override("font_size", 13)
	_sarcina_sus.add_theme_color_override("font_color", Color("a18463"))
	_inventar = Inventar.new(LOCURI_INVENTAR)
	_inventar.slot_apasat.connect(_la_slot)
	_inventar.slot_aruncat.connect(_arunca)
	add_child(_inventar)
	_inventar.hide()
	_panou_raft = PanouRaft.new(LOCURI_RAFT, LOCURI_INVENTAR)
	_panou_raft.raft_apasat.connect(_ia_de_pe_raft)
	_panou_raft.inventar_apasat.connect(_pune_pe_raft)
	add_child(_panou_raft)
	_panou_raft.hide()


func _eticheta() -> Label:
	var e := Label.new()
	e.add_theme_font_size_override("font_size", 10)
	e.add_theme_color_override("font_color", Color("83b3b0"))
	e.add_theme_color_override("font_shadow_color", Color("262d2fe6"))
	e.add_theme_constant_override("shadow_offset_x", 1)
	e.add_theme_constant_override("shadow_offset_y", 1)
	e.modulate.a = 0.0
	add_child(e)
	return e


## Joc nou: inventar gol, niciun marcaj, nicio sarcină.
func reseteaza() -> void:
	obiecte = {}
	marcaje = {}
	sarcina = ""
	nume_jucator = ""
	in_mana = ""
	raft = {}
	aruncate = {}
	lanterna = true
	meniu_deschis = false
	_inventar.hide()
	_panou_raft.hide()
	_mesaj.show()


## Șterge de pe ecran „Task: …” și „Picked up: …” (la ieșirea în meniul principal).
func ascunde_mesaje() -> void:
	for tween in [_tween_sarcina, _tween_mesaj]:
		if tween:
			tween.kill()
	_sarcina_sus.modulate.a = 0.0
	_mesaj.modulate.a = 0.0


## Ce intră în fișierul de salvare (vezi salvare.gd).
func exporta() -> Dictionary:
	return {"obiecte": obiecte, "marcaje": marcaje, "sarcina": sarcina, "nume_jucator": nume_jucator, "in_mana": in_mana,
		"raft": raft, "aruncate": aruncate, "lanterna": lanterna}


func importa(date: Dictionary) -> void:
	obiecte = date.get("obiecte", {})
	marcaje = date.get("marcaje", {})
	sarcina = date.get("sarcina", "")
	nume_jucator = date.get("nume_jucator", "")
	raft = date.get("raft", {})
	aruncate = date.get("aruncate", {})
	lanterna = date.get("lanterna", true)
	# salvările de dinainte de mână: pistolul era mereu în mână cât îl aveai
	in_mana = date.get("in_mana", "pistol_roz" if obiecte.has("pistol_roz") else "")
	# salvările de dinainte ca bancnota de 5 dolari să intre în cash: o adunăm acum
	if obiecte.has(LexyMasa.ID_BANI):
		var mana_pe_bancnota := in_mana == LexyMasa.ID_BANI
		obiecte.erase(LexyMasa.ID_BANI)
		var suma := Bani.suma() + Bani.BANCNOTA
		marcaje[Bani.MARCAJ] = suma
		obiecte[Bani.ID] = Bani.nume(suma)
		if mana_pe_bancnota:
			in_mana = Bani.ID
	if not obiecte.has(in_mana):
		in_mana = ""


func adauga_obiect(id: String, nume: String) -> bool:
	# banii se adună mereu într-un singur obiect: bancnotele de la Lexy (5 dolari la jaf, 20 la împrumut) intră în cash
	var suma_noua := -1
	if id == LexyMasa.ID_BANI or id == LexyMasa.ID_BANI_IMPRUMUT:
		suma_noua = Bani.suma() + (Bani.BANCNOTA if id == LexyMasa.ID_BANI else Bani.BANCNOTA_IMPRUMUT)
		id = Bani.ID
	if obiecte.size() >= LOCURI_INVENTAR and not obiecte.has(id):
		_arata_mesaj("Inventory full")
		return false
	if suma_noua >= 0:
		marcaje[Bani.MARCAJ] = suma_noua
		obiecte[id] = Bani.nume(suma_noua)
	else:
		obiecte[id] = nume
	_arata_mesaj("Picked up: " + nume)
	Sunet.reda(SUNET_OBIECT, Sunet.VOLUM_EFECTE, 0.0, &"Interfata")
	schimbat.emit()
	return true


func are_obiect(id: String) -> bool:
	return obiecte.has(id)


func scoate_obiect(id: String) -> void:
	if obiecte.erase(id):
		if in_mana == id:
			in_mana = ""
		schimbat.emit()


## Pune marcajul. `valoare` = ce ții minte odată cu el, dacă e nevoie (ex. unde a căzut ceva), vezi valoare_marcaj().
func marcheaza(marcaj: String, valoare: Variant = true) -> void:
	marcaje[marcaj] = valoare
	schimbat.emit()


func valoare_marcaj(marcaj: String, implicit: Variant = null) -> Variant:
	return marcaje.get(marcaj, implicit)


func e_marcat(marcaj: String) -> bool:
	return marcaje.has(marcaj)


## `anunta` = false: sarcina se schimbă pe loc (inventar, salvare), fără „Task: ...” sus și fără sunet.
func seteaza_sarcina(text: String, anunta := true) -> void:
	sarcina = text
	schimbat.emit()
	if text.is_empty() or not anunta:
		return
	_sarcina_sus.text = "Task: " + text
	if _tween_sarcina:
		_tween_sarcina.kill()
	_tween_sarcina = create_tween()
	_tween_sarcina.tween_property(_sarcina_sus, "modulate:a", 1.0, 0.4)
	_tween_sarcina.tween_interval(DURATA_SARCINA)
	_tween_sarcina.tween_property(_sarcina_sus, "modulate:a", 0.0, 0.8)
	Sunet.reda(SUNET_SARCINA, Sunet.VOLUM_EFECTE, 0.0, &"Interfata")


func _arata_mesaj(text: String) -> void:
	_mesaj.text = text
	move_child(_mesaj, -1)  # deasupra ferestrelor (raftul, inventarul)
	_mesaj.show()
	if _tween_mesaj:
		_tween_mesaj.kill()
	_mesaj.modulate.a = 1.0
	_tween_mesaj = create_tween()
	_tween_mesaj.tween_interval(DURATA_MESAJ)
	_tween_mesaj.tween_property(_mesaj, "modulate:a", 0.0, 0.6)


# _input (nu _unhandled_input), ca Tab/Esc să ajungă aici înaintea jucătorului.
func _input(event: InputEvent) -> void:
	if _panou_raft.visible:
		if event.is_action_pressed("inventar") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
			inchide_raft()
			get_viewport().set_input_as_handled()
	elif _inventar.visible:
		if event.is_action_pressed("inventar") or event.is_action_pressed("ui_cancel"):
			_inchide_inventar()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventar") and not meniu_deschis and not Dialog.activ and not Tranzitie.activa:
		_deschide_inventar()
		get_viewport().set_input_as_handled()


func _deschide_inventar() -> void:
	_inventar.actualizeaza(obiecte, sarcina, in_mana)
	_inventar.show()
	_mesaj.hide()
	meniu_deschis = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sunet.reda(SUNET_DESCHIDE, Sunet.VOLUM_EFECTE, 0.05, &"Interfata")


func _inchide_inventar() -> void:
	_inventar.hide()
	_mesaj.show()
	meniu_deschis = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sunet.reda(SUNET_INCHIDE, Sunet.VOLUM_EFECTE, 0.05, &"Interfata")


## Pune în mână obiectul `id` din inventar ('' sau un obiect pe care nu-l ai = mâinile goale).
func tine_in_mana(id: String) -> void:
	if not obiecte.has(id):
		id = ""
	if id == in_mana:
		return
	in_mana = id
	schimbat.emit()


## Click pe slotul `index` din inventar: îl iei în mână; pe slotul din mână sau pe unul gol, îl lași.
func _la_slot(index: int) -> void:
	var id: String = obiecte.keys()[index] if index < obiecte.size() else ""
	tine_in_mana("" if id == in_mana else id)
	_inventar.actualizeaza(obiecte, sarcina, in_mana)
	Sunet.reda(SUNET_DESCHIDE, Sunet.VOLUM_EFECTE, 0.05, &"Interfata", 1.3)


# ---------------------------------------------------------------- aruncat pe jos

## Click dreapta pe slotul `index` din inventar: obiectul cade pe jos în fața ta (îl iei înapoi cu E).
func _arunca(index: int) -> void:
	if index >= obiecte.size():
		return
	var id: String = obiecte.keys()[index]
	var nume: String = obiecte[id]
	var jucator := get_tree().get_first_node_in_group("jucator") as CharacterBody3D
	if jucator == null:
		return
	if not ObiecteLume.se_poate_arunca(id):
		_arata_mesaj("You can't drop a spell." if id == VrajaFoc.ID else "Can't drop that.")
		_mesaj.show()
		return
	# în fața ta, pe podea (nu în perete: dacă e unul aproape, cade lângă el)
	var spatiu := jucator.get_world_3d().direct_space_state
	var fata := -jucator.global_basis.z
	fata.y = 0.0
	fata = fata.normalized()
	var start := jucator.global_position + Vector3.UP * 0.5
	# puțin într-o parte la întâmplare, ca două obiecte aruncate unul după altul să nu cadă unul în altul
	var tinta := start + fata * randf_range(0.75, 1.0) + fata.cross(Vector3.UP) * randf_range(-0.3, 0.3)
	var raza := PhysicsRayQueryParameters3D.create(start, tinta)
	raza.exclude = [jucator.get_rid()]
	var lovit := spatiu.intersect_ray(raza)
	if lovit:
		tinta = lovit.position - fata * 0.25
	raza = PhysicsRayQueryParameters3D.create(tinta + Vector3.UP * 0.4, tinta + Vector3.DOWN * 3.0)
	raza.exclude = [jucator.get_rid()]
	lovit = spatiu.intersect_ray(raza)
	var punct: Vector3 = lovit.position if lovit else Vector3(tinta.x, jucator.global_position.y, tinta.z)
	var unghi := jucator.rotation.y + randf_range(-0.6, 0.6)
	var a := {"id": id, "scena": get_tree().current_scene.scene_file_path, "nume": nume, "poz": [punct.x, punct.y, punct.z],
		"unghi": unghi}
	var impuls := Vector3.ZERO
	if Cadavre.e_cadavru(id):
		# îl lași să cadă din brațe în fața ta, culcat de-a curmezișul
		a.unghi = jucator.rotation.y + PI / 2.0
		impuls = fata * 25.0 * float(Cadavre.MODELE[id].get("masa", 30.0)) / 30.0  # pisica e de 10 ori mai ușoară
	# banii își duc suma cu ei; dacă ai mai aruncat bani, cheia e alta (fiecare grămadă e a ei)
	var cheie := id
	if id == Jetoane.ID or id == Bani.ID:
		a.valoare = Jetoane.suma() if id == Jetoane.ID else Bani.suma()
		var n := 2
		while aruncate.has(cheie):
			cheie = "%s_%d" % [id, n]
			n += 1
	# întâi în `aruncate`, apoi scos din inventar (cine ascultă `schimbat` îl vede deja pe jos, ex. mătura de pe perete)
	aruncate[cheie] = a
	if id == Jetoane.ID:
		Jetoane.seteaza(0)
	elif id == Bani.ID:
		Bani.seteaza(0)
	else:
		scoate_obiect(id)
	ObiecteLume.pune_jos(get_tree().current_scene, cheie, a, impuls)
	Sunet.reda_la(SUNET_ARUNCAT, punct, Sunet.VOLUM_EFECTE, 0.08)
	_inventar.actualizeaza(obiecte, sarcina, in_mana)


## L-ai luat înapoi de pe jos (ObiectAruncat).
func uita_aruncat(id: String) -> void:
	aruncate.erase(id)


## Adevărat dacă `id` e aruncat pe jos undeva.
func e_aruncat(id: String) -> bool:
	return aruncate.has(id)


## Pune înapoi pe jos ce ai aruncat în scena de acum (o cheamă jucătorul când intră în scenă).
func pune_aruncate() -> void:
	var scena := get_tree().current_scene
	if scena == null:
		return
	for cheie: String in aruncate:
		var a: Dictionary = aruncate[cheie]
		if a.scena == scena.scene_file_path and ObiecteLume.se_poate_arunca(a.get("id", cheie)):
			ObiecteLume.pune_jos(scena, cheie, a)


# ---------------------------------------------------------------- raftul din camera ta

func deschide_raft() -> void:
	_panou_raft.actualizeaza(raft, obiecte)
	_panou_raft.show()
	meniu_deschis = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Sunet.reda(SUNET_DESCHIDE, Sunet.VOLUM_EFECTE, 0.05, &"Interfata", 1.2)


func inchide_raft() -> void:
	_panou_raft.hide()
	meniu_deschis = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Sunet.reda(SUNET_INCHIDE, Sunet.VOLUM_EFECTE, 0.05, &"Interfata", 1.2)


## Adevărat dacă `id` stă pe raftul din camera ta.
func e_pe_raft(id: String) -> bool:
	return raft.has(id)


func _pune_pe_raft(index: int) -> void:
	if index >= obiecte.size():
		return
	var id: String = obiecte.keys()[index]
	if raft.size() >= LOCURI_RAFT:
		_arata_mesaj("The shelf is full")
	elif not ObiecteLume.are_model(id) or id == Jetoane.ID or id == Bani.ID:
		_arata_mesaj("That doesn't go on a shelf.")
	else:
		raft[id] = obiecte[id]
		scoate_obiect(id)
		Sunet.reda(SUNET_PUS, Sunet.VOLUM_EFECTE, 0.05)
	_panou_raft.actualizeaza(raft, obiecte)


func _ia_de_pe_raft(index: int) -> void:
	if index >= raft.size():
		return
	var id: String = raft.keys()[index]
	if id == LexyMasa.ID_BANI:
		# bancnota pusă pe raft într-o salvare veche: intră în cash
		if adauga_obiect(id, raft[id]):
			raft.erase(id)
	elif obiecte.size() >= LOCURI_INVENTAR:
		_arata_mesaj("Inventory full")
	else:
		obiecte[id] = raft[id]
		raft.erase(id)
		Sunet.reda(SUNET_OBIECT, Sunet.VOLUM_EFECTE, 0.0, &"Interfata")
		schimbat.emit()
	_panou_raft.actualizeaza(raft, obiecte)
