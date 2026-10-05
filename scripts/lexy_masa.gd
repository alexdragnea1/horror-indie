class_name LexyMasa
extends Interactabil
## Lexy la masa din bucătărie, după scena de pe canapea (`marcaj_canapea`), cât mănâncă pizza. Nodul stă pe scaunul
## ei (ScaunLexy) și are forma ei (o capsulă): pe el apeși E și în el intră gloanțele.
## La E apar butoanele (fără replică înainte):
##   - `optiune_jaf` („Rob her at gun point”), doar dacă ai pistolul la tine (în inventar) și n-ai jefuit-o deja:
##     scoți pistolul, ea ridică mâinile cu felia în mână (tremură), `replici_jaf`, apoi scoate din buzunarul
##     hanoracului o bancnotă de 5 dolari și ți-o întinde; o iei („$5” în inventar), ea lasă mâinile jos, pune felia
##     în cutie și nu mai mănâncă, doar se uită la tine (`marcaj_jaf`);
##   - `optiune_plecare` („Leave Lexy's House”): `replici_plecare`, sau `replici_plecare_dupa_jaf` după jaf.
## După jaf o poți împușca: cade de pe scaun ca un ragdoll (`marcaj_moarta`), iar apoi o iei în inventar cu E
## („Lexy”, `ID_CADAVRU`, `marcaj_luata`). O poți arunca peste gardul cimitirului (gard_cimitir.gd).
## Replicile sunt ale owner-ului: nu le corecta.

const ID_BANI := "bani_5"
const NUME_BANI := "$5"
const ID_CADAVRU := "cadavru_lexy"
const NUME_CADAVRU := "Lexy"

@export var lexy: Lexy
@export var marcaj_canapea := "a_fumat_cu_lexy"
@export var marcaj_jaf := "a_jefuit_lexy"
@export var marcaj_moarta := "lexy_moarta"
@export var marcaj_luata := "lexy_luata"
@export var optiune_jaf := "Rob her at gun point"
@export var optiune_plecare := "Leave Lexy's House"
@export var indiciu_cadavru := "[E] Pick up Lexy"
## Unde stai cât o jefuiești (față de nod, la podea): în diagonală, în fața ei, unde lampa de deasupra mesei
## nu-ți acoperă fața ei.
@export var loc_jaf := Vector3(1.55, 0.0, 0.9)
## Cât de tare o împinge glonțul (N·s).
@export var forta_glont := 140.0
## După „Leave Lexy's House” (sau după ce ai aruncat-o peste gard, vezi gard_cimitir.gd): vine autobuzul spre casă
## (nodul `AutobuzAcasa`) și primești `sarcina_plecare`.
@export var marcaj_plecare := "gata_la_lexy"
@export var sarcina_plecare := "Take the bus home."
@export var sunet_cadere: AudioStream = preload("res://sunete/corp_cazut.ogg")
@export var sunet_luat: AudioStream = preload("res://sunete/corp_luat.ogg")
@export var sunet_bancnota: AudioStream = preload("res://sunete/bancnota.ogg")

@export_group("Replici")
@export_multiline var replici_jaf_inceput: PackedStringArray = ["You: Put your hands up bitch!"]
@export_multiline var replici_jaf: PackedStringArray = ["Lexy: What the fuck are you doing??", "You: Give me your money.",
	"Lexy: Are you seriously robbing me?", "You: Shut the fuck up and give me your money!"]
@export_multiline var replici_plecare: PackedStringArray = ["You: Imma head out..", "Lexy: Aight bitch, be careful out there."]
@export_multiline var replici_plecare_dupa_jaf: PackedStringArray = ["You: Imma head out..",
	"Lexy: Don't come here again you piece of shit.."]

var _in_curs := false
var _cadavru: Ragdoll
var _jucator: CharacterBody3D
var _cap: Node3D
var _camera: Camera3D

@onready var _forma: CollisionShape3D = $Forma


func _ready() -> void:
	indiciu = "[E] Talk to Lexy"
	_seteaza_forma()
	Stare.schimbat.connect(_seteaza_forma)
	await get_tree().process_frame
	_jucator = get_tree().get_first_node_in_group("jucator") as CharacterBody3D
	if _jucator:
		_cap = _jucator.get_node("Cap")
		_camera = _cap.get_node("Camera3D")
	# canapea_lexy.gd o pune pe scaun la primul cadru; abia apoi o lăsăm moartă / speriată
	await get_tree().process_frame
	if Stare.e_marcat(marcaj_luata):
		lexy.hide()
		lexy.mort = true
		lexy.set_process(false)
	elif Stare.e_marcat(marcaj_moarta):
		_moare(Vector3.ZERO, 0.0)
	elif Stare.e_marcat(marcaj_jaf):
		_speriata()


## Capsula e acolo doar cât Lexy stă (sau ar trebui să stea) pe scaun, vie.
func _seteaza_forma() -> void:
	var la_masa := Stare.e_marcat(marcaj_canapea) and not Stare.e_marcat(marcaj_moarta)
	_forma.set_deferred("disabled", not la_masa)


func poate_fi_folosit() -> bool:
	return not _in_curs and not lexy.mort and Stare.e_marcat(marcaj_canapea) and _sta_pe_scaun()


func _sta_pe_scaun() -> bool:
	var d := lexy.global_position - global_position
	return Vector2(d.x, d.z).length() < 0.3 and lexy.sezut > 0.95


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	var optiuni: PackedStringArray = []
	var poate_jefui := Stare.are_obiect(Pistol.ID) and not Stare.e_marcat(marcaj_jaf)
	if poate_jefui:
		optiuni.append(optiune_jaf)
	optiuni.append(optiune_plecare)
	var ales := await Dialog.intreaba("", optiuni)
	if poate_jefui and ales == 0:
		await _jefuieste()
	else:
		await _spune(replici_plecare_dupa_jaf if Stare.e_marcat(marcaj_jaf) else replici_plecare)
		pleaca(marcaj_plecare, sarcina_plecare)
	_in_curs = false


func _spune(replici: PackedStringArray) -> void:
	if replici.is_empty():
		return
	Dialog.spune(replici)
	if Dialog.activ:
		await Dialog.terminat


# ---------------------------------------------------------------- jaful

func _jefuieste() -> void:
	var c := Cutscena.porneste(self)
	_jucator.seteaza_purtat(true)
	# scoți pistolul și o ții la țintă (rămâne la vedere cât ține scena); faci un pas în fața ei
	Stare.tine_in_mana(Pistol.ID)
	Pistol.in_scena = true
	lexy.privire = _cap
	var loc := to_global(loc_jaf)
	loc.y = _jucator.global_position.y
	var pas := _tween()
	pas.tween_property(_jucator, "global_position", loc, 0.7)
	c.priveste(_la_ea(), 0.7)
	await pas.finished
	await c.priveste(_la_ea(), 0.2)
	# se sperie la jumătatea replicii și ridică mâinile
	Dialog.spune(replici_jaf_inceput)
	await get_tree().create_timer(0.45).timeout
	lexy.maini_sus()
	if Dialog.activ:
		await Dialog.terminat
	await _spune(replici_jaf)
	# scoate bancnota din buzunar și ți-o întinde (te uiți la mâna ei)
	var predare := _predare()
	c.priveste(lexy.global_position + Vector3.UP * 0.75, 0.8)
	var bancnota := await lexy.scoate_bancnota(predare)
	await c.priveste(predare + Vector3.UP * 0.05, 0.35)
	await get_tree().create_timer(0.3).timeout
	# o iei: ți-o aduci în fața ochilor, te uiți la ea, o bagi în buzunar
	bancnota.reparent(_camera, true)
	# lipită de cameră n-o prinde nicio lumină: un pic de luciu, ca să se vadă desenul
	for m in bancnota.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).set_instance_shader_parameter("stralucire", 0.45)
	Sunet.reda(sunet_bancnota, Sunet.VOLUM_EFECTE - 2.0, 0.05)
	lexy.du_mana("S", lexy.global_position + Vector3.UP * 0.35 + (predare - lexy.global_position) * 0.3, 0.6)
	var t := _tween()
	t.tween_property(bancnota, "position", Vector3(-0.03, -0.06, -0.3), 0.55)
	t.tween_property(bancnota, "basis", Basis(Vector3.RIGHT, PI / 2.0 - 0.25) * Basis(Vector3.UP, 0.05), 0.55)
	await t.finished
	await get_tree().create_timer(0.7).timeout
	t = _tween()
	t.tween_property(bancnota, "position", Vector3(-0.2, -0.45, -0.18), 0.4)
	t.tween_property(bancnota, "basis", Basis(Vector3.RIGHT, 0.4) * Basis(Vector3.FORWARD, 0.6), 0.4)
	await t.finished
	bancnota.queue_free()
	Stare.adauga_obiect(ID_BANI, NUME_BANI)
	Stare.marcheaza(marcaj_jaf)
	# lasă mâinile jos, încet, și pune felia înapoi în cutie; de acum doar se uită la tine
	await c.priveste(_la_ea(), 0.5)
	await lexy.maini_jos(1.3)
	lexy.frica = 0.6
	lexy.lasa_felia()
	Pistol.in_scena = false
	_jucator.seteaza_purtat(false)
	await c.opreste()


## Unde te uiți la ea: între față și mâinile ridicate.
func _la_ea() -> Vector3:
	return lexy.global_position + Vector3.UP * 0.85


## Unde îți întinde bancnota: între voi, la înălțimea pieptului tău, mai aproape de tine.
func _predare() -> Vector3:
	var de_la := lexy.global_position + Vector3.UP * 0.55
	var la := _camera.global_position + Vector3.DOWN * 0.35
	return de_la.lerp(la, 0.55)


## După jaf (și la Continue): nu mai mănâncă, stă cu ochii pe tine.
func _speriata() -> void:
	lexy.frica = 0.6
	lexy.mananca = false
	lexy.privire = _cap


func _tween() -> Tween:
	return create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ---------------------------------------------------------------- moartea

## O lovește un glonț (pistol.gd). Moare doar după ce ai jefuit-o.
func impuscat(directie: Vector3, _punct := Vector3.ZERO) -> void:
	if not lexy.mort and Stare.e_marcat(marcaj_jaf) and _sta_pe_scaun():
		_moare(directie, forta_glont)


## Cade de pe scaun ca un ragdoll, iar după ce se oprește o poți lua cu E. Ca Personaj.omoara.
func _moare(directie: Vector3, forta: float) -> void:
	Stare.marcheaza(marcaj_moarta)
	var spate := -lexy.global_basis.z  # modelul privește spre +Z (spre masă)
	var orizontal := Vector3(directie.x, 0.0, directie.z).normalized()
	var impuls := (spate * 0.6 + orizontal * 0.4 + Vector3.UP * 0.15).normalized() * forta
	_cadavru = lexy.omoara(impuls)
	if forta > 0.0:
		await get_tree().create_timer(0.45).timeout
		if is_instance_valid(_cadavru):
			Sunet.reda_la(sunet_cadere, _cadavru.centru(), Sunet.VOLUM_EFECTE, 0.05)
	var asteptat := 0.0
	while is_instance_valid(_cadavru) and asteptat < 3.0 and not (asteptat > 0.6 and _cadavru.s_a_oprit()):
		await get_tree().create_timer(0.2).timeout
		asteptat += 0.2
	if is_instance_valid(_cadavru):
		_cadavru.pune_ridicare(ID_CADAVRU, NUME_CADAVRU, indiciu_cadavru).folosit.connect(_luata)


func _luata() -> void:
	Stare.marcheaza(marcaj_luata)
	Sunet.reda(sunet_luat, Sunet.VOLUM_EFECTE, 0.05)
	_cadavru.queue_free()
	lexy.hide()


## Gata la Lexy: autobuzul spre casă vine în stație (o singură dată primești sarcina).
static func pleaca(marcaj: String, sarcina: String) -> void:
	if Stare.e_marcat(marcaj):
		return
	Stare.marcheaza(marcaj)
	if sarcina != "":
		Stare.seteaza_sarcina(sarcina)
