extends Interactabil
## Scaunul din fața barmanului de la „URBAN” (bar.tscn): „[E] Sit at the bar” → te așezi (ca la poker) și:
##  - prima dată: `replici_inceput` (owner), îi întinzi `mita` dolari peste tejghea, el se uită în stânga, apoi în dreapta
##    (să nu-l vadă nimeni), ia banii și îi bagă în buzunarul șorțului → `replica_dupa_mita` cu băuturile (owner);
##  - de a doua oară: direct băuturile (+ `optiune_nimic`), el nu mai zice nimic (owner).
## Alegi: berea o scoate rece de sub tejghea și o desface; la whiskey / vodcă / rom pune paharul, se duce la dulapul din
## spate după sticlă (`sticle`), toarnă și o pune la loc. Iei paharul și îl dai pe gât (`Betie` + `EfectBeat`).
## Prima dată, după băutură: `replici_vrajitoare` (owner), lași `bacsis` dolari pe tejghea și te ridici (marcaj
## `marcaj_aflat`, sarcina `sarcina_dupa`). După ce pleci, barmanul strânge paharul (și bacșișul).
## N-ai `mita` dolari cash: `replici_fara_bani` (Claude) și te ridici.

const BAUTURI := [
	{"nume": "Beer", "model": preload("res://models/bere_sticla.glb"), "sticla": "", "betie": 0.5, "efect": 6.0},
	{"nume": "Whiskey", "model": preload("res://models/pahar_whiskey.glb"), "sticla": "Whiskey", "betie": 1.0, "efect": 9.0},
	{"nume": "Vodka", "model": preload("res://models/pahar_vodka.glb"), "sticla": "Vodka", "betie": 1.0, "efect": 9.0},
	{"nume": "Rum", "model": preload("res://models/pahar_rom.glb"), "sticla": "Rom", "betie": 1.0, "efect": 9.0},
]
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")
const MODEL_BANCNOTA := preload("res://models/bancnota.glb")
const SUNET_BANI := preload("res://sunete/bancnota.ogg")
const SUNET_PAHAR := preload("res://sunete/bere_clinchet.ogg")
const SUNET_INGHITITURA := preload("res://sunete/bere_inghititura.ogg")
const SUNET_RAGAIT := preload("res://sunete/bere_ragait.ogg")
const SUNET_CAPAC := preload("res://sunete/capac_bere.ogg")
const SUNET_TURNAT := preload("res://sunete/turnat_bautura.ogg")
const SUNET_SCAUN := preload("res://sunete/canapea_asezat.ogg")
const SUNET_PASI := [preload("res://sunete/pas_lemn_1.ogg"), preload("res://sunete/pas_lemn_2.ogg"), preload("res://sunete/pas_lemn_3.ogg")]
## În coordonatele lui (fața spre +Z): sub tejghea, pe partea lui (blatul începe la ~0,27 m în fața lui), și unde ține
## sticla când merge cu ea (în fața burții, dar cu fundul deasupra blatului: mai jos intra în el la tejghea).
const SUB_TEJGHEA := Vector3(0.05, 0.85, 0.225)
const PURTARE := Vector3(-0.12, 1.16, 0.3)

@export var om: OmLaMasa
## Unde stai pe scaun (picioarele jucătorului) și cât de sus îți sunt ochii (față de picioare).
@export var loc_jucator: Marker3D
@export var ochi_sezut := 1.45
## Unde îți pune băutura (suportul de pahar alb de pe blat).
@export var pe_tejghea: Marker3D
## Sticlele de turnat de pe dulapul din spate (copiii: Whiskey, Vodka, Rom).
@export var sticle: Node3D
## Unde stă barmanul la dulapul din spate când ia o sticlă (global).
@export var loc_dulap: Marker3D
@export var mita := 100
@export var bacsis := 20
@export var marcaj_mituit := "a_mituit_barmanul"
@export var marcaj_aflat := "barmanul_a_zis_de_centru"
@export var sarcina_dupa := "Go to the city center."
@export var optiune_nimic := "Nothing"

@export_group("Replici")
@export_multiline var replici_inceput: PackedStringArray = ["Bartender: Aren't you a little young?",
	"You: Mind your own business retard.", "Bartender: Fuck you say to me?"]
@export var replica_dupa_mita := "Bartender: Nevermind, what do you want?"
@export_multiline var replici_vrajitoare: PackedStringArray = ["You: Do you know about the witch?",
	"Bartender: Yeah, I heard she's in the city center.", "Bartender: She's killing people, terrifying stuff.", "You: Aight."]
## Fără bani de mită (a lui Claude).
@export_multiline var replici_fara_bani: PackedStringArray = ["You: ...", "Bartender: That's what I thought. Get out of my bar, kid."]

var _in_curs := false
var _jucator: CharacterBody3D
var _cap: Node3D
var _camera: Camera3D
var _inaltime_ochi := 1.6
var _c: Cutscena
## Ce a rămas pe tejghea după tine (paharul gol, bacșișul): le strânge el după ce pleci.
var _de_strans: Array[Node3D] = []


func _ready() -> void:
	indiciu = "[E] Sit at the bar"
	await get_tree().process_frame
	_jucator = get_tree().get_first_node_in_group("jucator") as CharacterBody3D
	if _jucator:
		_cap = _jucator.get_node("Cap")
		_camera = _cap.get_node("Camera3D")
		om.privire = _cap


func poate_fi_folosit() -> bool:
	return not _in_curs and _jucator != null


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	await _aseaza_te()
	var ales := -1
	if not Stare.e_marcat(marcaj_mituit):
		await _spune(replici_inceput)
		if Bani.suma() < mita * 100:
			await _spune(replici_fara_bani)
			await _ridica_te()
			_in_curs = false
			return
		await _mita()
		Stare.marcheaza(marcaj_mituit)
		ales = await _intreaba(replica_dupa_mita, false)
	else:
		ales = await _intreaba("", true)
	if ales >= 0 and ales < BAUTURI.size():
		var bautura: Dictionary = BAUTURI[ales]
		var pahar := await _serveste(bautura)
		await _bea(pahar, bautura)
	var aflat_acum := false
	if not Stare.e_marcat(marcaj_aflat):
		await _spune(replici_vrajitoare)
		Stare.marcheaza(marcaj_aflat)
		aflat_acum = true
		await _lasa_bacsis()
	await _ridica_te()
	if aflat_acum and sarcina_dupa != "":
		Stare.seteaza_sarcina(sarcina_dupa)
	_in_curs = false
	_strange_tejgheaua()


func _intreaba(replica: String, cu_nimic: bool) -> int:
	var butoane := PackedStringArray()
	for b: Dictionary in BAUTURI:
		butoane.append(String(b.nume))
	if cu_nimic:
		butoane.append(optiune_nimic)
	var i := await Dialog.intreaba(replica, butoane)
	Stare.meniu_deschis = true  # (intreaba îl pune înapoi pe fals; scena merge mai departe)
	return i


# ---------------------------------------------------------------- așezat / ridicat

func _aseaza_te() -> void:
	_jucator.seteaza_purtat(true)
	_inaltime_ochi = _cap.position.y
	_c = Cutscena.porneste(self)
	var t := _tween()
	t.tween_property(_jucator, "global_position", loc_jucator.global_position, 0.8)
	t.tween_property(_cap, "position:y", ochi_sezut, 0.8)
	_c.priveste(_fata(), 0.8)
	await t.finished
	Sunet.reda_la(SUNET_SCAUN, loc_jucator.global_position, Sunet.VOLUM_EFECTE - 2.0, 0.05)


func _ridica_te() -> void:
	# te ridici înapoi, dinspre tejghea (în spatele scaunului), ca să nu rămâi prins în el
	var inapoi := loc_jucator.global_position + (loc_jucator.global_position - om.global_position).normalized() * 0.7
	inapoi.y = loc_jucator.global_position.y
	var t := _tween()
	t.tween_property(_jucator, "global_position", inapoi, 0.7)
	t.tween_property(_cap, "position:y", _inaltime_ochi, 0.7)
	t.tween_property(_cap, "rotation:x", 0.0, 0.7)
	await t.finished
	_jucator.seteaza_purtat(false)
	await _c.opreste()
	om.privire = _cap


# ---------------------------------------------------------------- mita și bacșișul

func _mita() -> void:
	# îi întinzi banii peste tejghea
	var teanc := _teanc(4)
	_camera.add_child(teanc)
	teanc.position = Vector3(0.16, -0.4, -0.22)
	teanc.reparent(get_tree().current_scene, true)
	var intins := pe_tejghea.global_position.lerp(_camera.global_position, 0.35) + Vector3.UP * 0.05
	_c.priveste(intins, 0.6)
	var t := _tween()
	t.tween_property(teanc, "global_position", intins, 0.7)
	await t.finished
	Sunet.reda_la(SUNET_BANI, intins, Sunet.VOLUM_EFECTE - 2.0, 0.05)
	await _asteapta(0.5)
	# se uită în stânga, apoi în dreapta (să vadă dacă se uită cineva)
	_c.priveste(_fata(), 0.5)
	om.privire = null
	om.priveste_punct = om.global_transform * Vector3(2.5, 1.5, 1.2)
	await _asteapta(0.9)
	om.priveste_punct = om.global_transform * Vector3(-2.5, 1.5, 1.2)
	await _asteapta(0.9)
	om.priveste_punct = teanc.global_position
	await _asteapta(0.35)
	# ia banii și îi bagă în buzunarul șorțului
	await om.du_mana("S", teanc.global_position + Vector3.UP * 0.02, 0.5)
	teanc.reparent(om.nod_mana("S"), true)
	Sunet.reda_la(SUNET_BANI, teanc.global_position, Sunet.VOLUM_EFECTE - 4.0, 0.05)
	Bani.plateste(mita * 100)
	om.priveste_punct = Vector3.INF
	om.privire = _cap
	# peste blat pe partea lui, apoi jos în buzunarul șorțului (nu prin tejghea)
	var la_el := om.global_transform * SUB_TEJGHEA
	await om.du_mana("S", Vector3(la_el.x, _peste_blat() + 0.04, la_el.z), 0.35)
	await om.du_mana("S", om.global_transform * Vector3(0.12, 0.72, 0.22), 0.45)
	teanc.queue_free()
	om.lasa_mana("S", 0.45)
	await _asteapta(0.3)


func _lasa_bacsis() -> void:
	var suma := mini(bacsis * 100, Bani.suma())
	if suma <= 0:
		return
	var teanc := _teanc(1)
	_camera.add_child(teanc)
	teanc.position = Vector3(0.16, -0.4, -0.22)
	teanc.reparent(get_tree().current_scene, true)
	var loc := pe_tejghea.global_transform * Vector3(0.14, 0.004, 0.05)
	_c.priveste(loc, 0.5)
	var t := _tween()
	t.tween_property(teanc, "global_position", loc, 0.6)
	await t.finished
	Bani.plateste(suma)
	Sunet.reda_la(SUNET_BANI, loc, Sunet.VOLUM_EFECTE - 3.0, 0.05)
	_de_strans.append(teanc)
	await _asteapta(0.4)


# ---------------------------------------------------------------- băutura

## Barmanul îți pune băutura pe suportul de pe blat și o întoarce (Node3D-ul ei).
func _serveste(bautura: Dictionary) -> Node3D:
	if not _de_strans.is_empty():
		await _strange_tejgheaua(true)
	var pahar := _model(bautura.model)
	get_tree().current_scene.add_child(pahar)
	var sub := om.global_transform * SUB_TEJGHEA  # sub tejghea, în fața lui (pe partea lui, nu sub blat)
	pahar.global_position = sub
	pahar.global_rotation = Vector3(0.0, randf_range(-0.5, 0.5), 0.0)
	var lichid := pahar.find_child("Lichid", true, false) as Node3D
	_c.priveste(pe_tejghea.global_position + Vector3.UP * 0.25, 0.6)
	# îl scoate de sub tejghea cu mâna (dreapta la bere, stânga la pahar) și îl pune pe suport
	var mana := "D" if bautura.sticla == "" else "S"
	var prinza := Marker3D.new()
	pahar.add_child(prinza)
	prinza.position = Vector3(0.0, 0.08, 0.0)
	await om.du_mana(mana, prinza, 0.5)
	if lichid:
		lichid.scale.y = 0.001
	# drept în sus pe partea lui (până deasupra blatului), peste blat până deasupra suportului, apoi jos: în linie
	# dreaptă trecea prin tejghea (owner 10.10)
	var t := _tween()
	t.tween_property(pahar, "global_position", Vector3(sub.x, _peste_blat(), sub.z), 0.3)
	await t.finished
	t = _tween()
	t.tween_property(pahar, "global_position", pe_tejghea.global_position + Vector3.UP * 0.06, 0.35)
	await t.finished
	t = _tween()
	t.tween_property(pahar, "global_position", pe_tejghea.global_position, 0.2)
	await t.finished
	Sunet.reda_la(SUNET_PAHAR, pe_tejghea.global_position, Sunet.VOLUM_EFECTE - 3.0, 0.08)
	if bautura.sticla == "":
		# berea: o desface (capacul sare în sus și dispare)
		var capac := pahar.find_child("Capac", true, false) as Node3D
		if capac:
			await om.du_mana("S", capac.global_position + Vector3.UP * 0.02, 0.35)
			Sunet.reda_la(SUNET_CAPAC, capac.global_position, Sunet.VOLUM_EFECTE - 2.0, 0.08)
			capac.reparent(get_tree().current_scene, true)
			var zbor := _tween()
			zbor.tween_property(capac, "global_position", capac.global_position + om.global_basis * Vector3(0.1, 0.25, -0.1), 0.25)
			zbor.tween_property(capac, "rotation", capac.rotation + Vector3(4.0, 2.0, 0.0), 0.25)
			zbor.chain().tween_callback(capac.queue_free)
			om.lasa_mana("S", 0.4)
		om.lasa_mana("D", 0.45)
	else:
		om.lasa_mana("S", 0.45)
		await _toarna(String(bautura.sticla), pahar, lichid)
	prinza.queue_free()
	await _asteapta(0.25)
	return pahar


## Se duce la dulapul din spate după sticla `nume`, o aduce, toarnă în `pahar` (`lichid` crește) și o duce la loc.
func _toarna(nume: String, pahar: Node3D, lichid: Node3D) -> void:
	var sticla := sticle.get_node_or_null(nume) as Node3D
	if sticla == null:
		if lichid:
			lichid.scale.y = 1.0
		return
	var repaus := om.transform
	var loc_sticla := sticla.global_transform
	var inalt := _inaltime(sticla)
	var parinte := om.get_parent() as Node3D
	var la_dulap := parinte.to_local(loc_dulap.global_position)
	la_dulap.y = om.position.y
	_c.priveste(om.global_position + Vector3.UP * 1.3, 0.8)
	await _mergi(la_dulap, PI, 1.1)
	# o ia de pe dulap și o ține în fața pieptului (așa merge cu ea înapoi la tejghea)
	var prinza := Marker3D.new()
	sticla.add_child(prinza)
	prinza.position = Vector3(0.0, inalt * 0.4, 0.0)
	await om.du_mana("D", prinza, 0.45)
	var purtare := Marker3D.new()
	om.add_child(purtare)
	purtare.position = PURTARE
	var t := _tween()
	t.tween_property(sticla, "global_position", purtare.global_position, 0.4)
	await t.finished
	sticla.reparent(purtare, true)
	await _mergi(repaus.origin, 0.0, 1.1)
	# turnatul: sticla se rotește în jurul gâtului și vine cu gâtul chiar deasupra paharului
	_c.priveste(pe_tejghea.global_position + Vector3.UP * 0.12, 0.4)
	var pivot := Node3D.new()
	get_tree().current_scene.add_child(pivot)
	pivot.global_position = sticla.global_position + Vector3.UP * inalt
	sticla.reparent(pivot, true)
	var spre := pe_tejghea.global_position - om.global_position
	spre.y = 0.0
	spre = spre.normalized()
	var axa := Vector3.UP.cross(spre).normalized()
	var drept := pivot.global_basis
	var sus := pivot.global_position
	var deasupra := pe_tejghea.global_position + Vector3.UP * (_inaltime(pahar) + 0.035) - spre * 0.02
	# întâi o apleacă sus, deasupra paharului (corpul sticlei trece peste blat), abia apoi coboară gâtul la pahar și
	# o apleacă de tot; aplecată în timp ce cobora, fundul ei intra în tejghea (owner 10.10)
	var aplecata := Basis(axa, 1.45) * drept
	var turnat := Basis(axa, 2.1) * drept
	t = _tween()
	t.tween_property(pivot, "global_position", deasupra + Vector3.UP * 0.2, 0.5)
	t.tween_property(pivot, "global_basis", aplecata, 0.5)
	await t.finished
	t = _tween()
	t.tween_property(pivot, "global_position", deasupra, 0.3)
	t.tween_property(pivot, "global_basis", turnat, 0.3)
	await t.finished
	Sunet.reda_la(SUNET_TURNAT, pe_tejghea.global_position, Sunet.VOLUM_EFECTE - 2.0, 0.05)
	if lichid:
		t = create_tween().set_trans(Tween.TRANS_SINE)
		t.tween_property(lichid, "scale:y", 1.0, 1.2)
		await t.finished
	else:
		await _asteapta(1.2)
	# înapoi la fel: întâi se ridică, apoi se îndreaptă
	t = _tween()
	t.tween_property(pivot, "global_position", deasupra + Vector3.UP * 0.2, 0.3)
	t.tween_property(pivot, "global_basis", aplecata, 0.3)
	await t.finished
	t = _tween()
	t.tween_property(pivot, "global_position", sus, 0.45)
	t.tween_property(pivot, "global_basis", drept, 0.45)
	await t.finished
	# o duce înapoi pe dulap
	sticla.reparent(purtare, true)
	pivot.queue_free()
	await _mergi(la_dulap, PI, 1.1)
	sticla.reparent(sticle, true)
	t = _tween()
	t.tween_property(sticla, "global_transform", loc_sticla, 0.4)
	await t.finished
	om.lasa_mana("D", 0.4)
	prinza.queue_free()
	purtare.queue_free()
	await _mergi(repaus.origin, 0.0, 1.1)
	_c.priveste(pe_tejghea.global_position + Vector3.UP * 0.1, 0.4)


## O dai pe gât: paharul vine la gură dinspre dreapta-jos, capul se lasă puțin pe spate, băutura scade, apoi îl pui
## gol la loc. Sticla de bere vine cu gâtul la gură și fundul în sus, spre dreapta (de pe lângă, nu din capăt: altfel
## umplea tot ecranul ca un stâlp).
func _bea(pahar: Node3D, bautura: Dictionary) -> void:
	var lichid := pahar.find_child("Lichid", true, false) as Node3D
	var loc := pahar.global_transform
	var inalt := _inaltime(pahar)
	await _c.priveste(pahar.global_position + Vector3.UP * 0.05, 0.4)
	pahar.reparent(_camera, true)
	_lumineaza(pahar, 0.3)
	var t := _tween()
	t.tween_property(pahar, "position", Vector3(0.06, -0.16, -0.3), 0.55)
	t.tween_property(pahar, "rotation", Vector3(0.0, 0.0, 0.0), 0.55)
	await t.finished
	var sus := _cap.rotation.x
	# axa paharului (de la fund la buză), în coordonatele camerei, când bei
	var axa := Vector3(-0.42, -0.4, 0.81).normalized() if bautura.sticla == "" else Vector3(-0.28, -0.62, 0.73).normalized()
	var buza := Vector3(0.02, -0.075, -0.1)
	var baza := Basis(Quaternion(Vector3.UP, axa))
	t = _tween()
	t.tween_property(pahar, "position", buza - axa * inalt, 0.6)
	t.tween_property(pahar, "basis", baza, 0.6)
	t.tween_property(_cap, "rotation:x", sus + 0.35, 0.6)
	await t.finished
	var inghitituri := 3 if bautura.sticla == "" else 1
	for i in inghitituri:
		Sunet.reda(SUNET_INGHITITURA, Sunet.VOLUM_EFECTE - 1.0, 0.1)
		await _asteapta(0.45)
	if lichid:
		t = create_tween()
		t.tween_property(lichid, "scale:y", 0.001, 0.3)
		await t.finished
	t = _tween()
	t.tween_property(pahar, "position", Vector3(0.06, -0.16, -0.3), 0.5)
	t.tween_property(pahar, "basis", Basis.IDENTITY, 0.5)
	t.tween_property(_cap, "rotation:x", sus, 0.5)
	await t.finished
	pahar.reparent(get_tree().current_scene, true)
	_lumineaza(pahar, 0.0)
	t = _tween()
	t.tween_property(pahar, "global_transform", loc, 0.5)
	await t.finished
	Sunet.reda_la(SUNET_PAHAR, loc.origin, Sunet.VOLUM_EFECTE - 1.0, 0.08)
	_de_strans.append(pahar)
	Betie.adauga(float(bautura.betie))
	EfectBeat.porneste(_jucator, float(bautura.efect))
	if bautura.sticla == "" and randf() < 0.6:
		await _asteapta(0.5)
		Sunet.reda(SUNET_RAGAIT, Sunet.VOLUM_EFECTE - 3.0, 0.05)
	await _asteapta(0.6)
	_c.priveste(_fata(), 0.6)


## După ce pleci: ia paharul gol (și bacșișul) de pe tejghea și le bagă sub ea. `acum` = fără așteptare, chiar dacă
## stai la bar (te-ai așezat iar repede: strânge întâi ce era pe suport, apoi îți pune altă băutură).
func _strange_tejgheaua(acum := false) -> void:
	if not acum:
		await _asteapta(1.2)
	while not _de_strans.is_empty():
		if _in_curs and not acum:
			return  # te-ai așezat iar: strânge _serveste, înainte de băutura nouă
		var obiect: Node3D = _de_strans.pop_back()
		if not is_instance_valid(obiect):
			continue
		await om.du_mana("S", obiect.global_position + Vector3.UP * 0.05, 0.5)
		obiect.reparent(om.nod_mana("S"), true)
		# sus, înapoi peste blat pe partea lui, apoi jos sub tejghea (nu prin ea)
		var sus := obiect.global_position + Vector3.UP * 0.08
		await om.du_mana("S", sus, 0.2)
		var la_el := om.global_transform * SUB_TEJGHEA
		await om.du_mana("S", Vector3(la_el.x, sus.y, la_el.z), 0.3)
		await om.du_mana("S", la_el + Vector3.UP * 0.05, 0.3)
		obiect.queue_free()
		om.lasa_mana("S", 0.4)
		await _asteapta(0.5)


# ---------------------------------------------------------------- unelte

## Merge (alunecă, cu un mic legănat și pașii) până la `unde` (coordonatele părintelui lui `om`), întors spre `unghi`.
func _mergi(unde: Vector3, unghi: float, durata: float) -> void:
	var de_la := om.position
	var unghi0 := om.rotation.y
	var pasi := 3
	var misca := func(v: float) -> void:
		om.position = de_la.lerp(unde, v) + Vector3.UP * absf(sin(v * PI * pasi)) * 0.02
		om.rotation.y = lerp_angle(unghi0, unghi, clampf(v * 1.6, 0.0, 1.0))
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(misca, 0.0, 1.0, durata)
	for i in pasi:
		Sunet.reda_la(SUNET_PASI[i % SUNET_PASI.size()], om.global_position, Sunet.VOLUM_PASI - 3.0, 0.1)
		await get_tree().create_timer(durata / pasi).timeout
	if t.is_running():
		await t.finished


## Înălțimea (globală) la care un pahar trece peste blat fără să-l atingă.
func _peste_blat() -> float:
	return pe_tejghea.global_position.y + 0.06


func _fata() -> Vector3:
	return om.global_position + om.global_basis * Vector3(0.0, 1.62, 0.0)


func _inaltime(nod: Node3D) -> float:
	var sus := 0.0
	for m in nod.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var aabb := mi.get_aabb()
		sus = maxf(sus, (mi.global_transform * (aabb.position + aabb.size)).y - nod.global_position.y)
	return sus


func _model(scena: PackedScene) -> Node3D:
	var n := scena.instantiate() as Node3D
	n.set_script(SCRIPT_MODEL)
	n.set("material", MATERIAL)
	n.set("umbre", false)
	n.set("sticla", "Geam")
	return n


## Ce stă lipit de cameră nu e prins de luminile din bar: puțin propria lumină (ca banii de la primar).
func _lumineaza(nod: Node3D, cat: float) -> void:
	for m in nod.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).set_instance_shader_parameter("stralucire", cat)


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


func _spune(replici: PackedStringArray) -> void:
	if replici.is_empty():
		return
	Dialog.spune(replici)
	if Dialog.activ:
		await Dialog.terminat
	Stare.meniu_deschis = true


func _asteapta(secunde: float) -> void:
	await get_tree().create_timer(secunde).timeout


func _tween() -> Tween:
	return create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
