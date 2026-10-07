extends Interactabil
## Receptionera de la „Paradise Motel” (motel.tscn): stă pe scaunul înalt, după geamul antiglonț, cu coatele pe
## tejghea (animată de OmLaMasa: respiră, se uită la tine). Forma pe care o ochești e geamul din dreptul ei.
## E → `replica_intrebare` (owner) cu `optiune_minciuna` / `optiune_adevar`:
##  - Lie: `replici_minciuna`;
##  - Tell the truth: `replici_adevar`, apoi scoți cea mai tare armă pe care o ai (`ARME`; fără arme, Fireball-ul), ea
##    ridică mâinile, și `replici_adevar_final`.
## La sfârșit: `marcaj_gata` (știi că Warlock-ul e în camera 122) și `sarcina_noua`. După aceea nu mai e nimic de vorbit.
## Replicile sunt ale owner-ului: nu le corecta (nici „exeptions”).

@export var om: OmLaMasa
@export var marcaj_gata := "stie_camera_warlock"
## Sarcina după ce afli camera (a lui Claude).
@export var sarcina_noua := "Go to room 122."
@export var replica_intrebare := "Receptionist: Good evening, what can I help you with?"
@export var optiune_minciuna := "Lie"
@export var optiune_adevar := "Tell the truth"
@export_multiline var replici_minciuna: PackedStringArray = []
@export_multiline var replici_adevar: PackedStringArray = []
@export_multiline var replici_adevar_final: PackedStringArray = []

const SUNET_MAINI_SUS := preload("res://sunete/maini_sus.ogg")
## De la cea mai „șmecheră” la cea mai slabă; fără niciuna, Fireball-ul.
const ARME := ["bazooka", "ak47", "shotgun", "pistol_aur", "pistol_roz", "cutit", "vraja_foc"]

var _in_curs := false


func _ready() -> void:
	indiciu = "[E] Talk to the receptionist"
	await get_tree().process_frame
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	if jucator and om:
		om.privire = jucator.get_node("Cap")


func poate_fi_folosit() -> bool:
	return not _in_curs and not Stare.e_marcat(marcaj_gata)


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	var ales := await Dialog.intreaba(replica_intrebare, PackedStringArray([optiune_minciuna, optiune_adevar]))
	if ales == 0:
		await _spune(replici_minciuna)
	elif ales == 1:
		await _spune(replici_adevar)
		var arma := _arma_de_aratat()
		if arma != "":
			Stare.tine_in_mana(arma)
			await get_tree().create_timer(0.55).timeout  # cât urcă arma în cadru
		await _maini_sus(true)
		await _spune(replici_adevar_final)
		_maini_sus(false)
	else:
		_in_curs = false
		return
	Stare.marcheaza(marcaj_gata)
	if sarcina_noua != "":
		Stare.seteaza_sarcina(sarcina_noua)
	_in_curs = false


func _spune(linii: PackedStringArray) -> void:
	Dialog.spune(linii)
	if Dialog.activ:
		await Dialog.terminat


func _arma_de_aratat() -> String:
	for id in ARME:
		if Stare.are_obiect(id):
			return id
	return ""


## Ridică mâinile (sus, lângă cap, cu palmele spre tine) sau le lasă înapoi pe tejghea.
func _maini_sus(sus: bool) -> void:
	if om == null:
		return
	if not sus:
		om.lasa_mana("D", 0.6)
		om.lasa_mana("S", 0.6)
		return
	Sunet.reda_la(SUNET_MAINI_SUS, om.global_position + Vector3.UP * 1.2, Sunet.VOLUM_EFECTE - 4.0, 0.05)
	var cap := om.global_position + om.global_basis * Vector3(0.0, 1.32, 0.0)
	om.du_mana("D", cap + om.global_basis * Vector3(-0.32, 0.3, 0.1), 0.3)
	await om.du_mana("S", cap + om.global_basis * Vector3(0.32, 0.3, 0.1), 0.3)
