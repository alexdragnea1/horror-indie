extends Interactabil
## Funcționara de la ghișeul primăriei (primarie.tscn, „Employee”): stă pe scaunul înalt, după geam, cu coatele pe blat
## (animată de OmLaMasa: respiră, se uită la tine). Forma pe care o ochești e geamul din dreptul ei.
## E → `replici_inainte`, apoi scoți cea mai tare armă pe care o ai (`ARME`; fără arme, Fireball-ul), ea ridică
## mâinile, `replici_dupa_arma`, lasă mâinile jos → `marcaj_gata` (ușa biroului de sus se deschide) și `sarcina_noua`.
## După aceea, la E: `replici_dupa`.
## Replicile sunt ale owner-ului (nu le corecta); `sarcina_noua` și `replici_dupa` sunt ale lui Claude.

@export var om: OmLaMasa
@export var marcaj_gata := "angajata_a_zis_de_primar"
@export var sarcina_noua := "Go to the Mayor's office upstairs."
@export_multiline var replici_inainte: PackedStringArray = ["You: I'm here to talk to the Mayor about the witch situation.",
	"Employee: Mayor Smegma is quite a busy man, child."]
@export_multiline var replici_dupa_arma: PackedStringArray = ["You: Bitch don't waste my time..",
	"Employee: The mayor is upstairs in his office.", "You: Why is everyone so difficult.."]
@export_multiline var replici_dupa: PackedStringArray = ["Employee: Upstairs. Please don't hurt me."]

const SUNET_MAINI_SUS := preload("res://sunete/maini_sus.ogg")
## De la cea mai „șmecheră” la cea mai slabă; fără niciuna, Fireball-ul.
const ARME := ["bazooka", "ak47", "shotgun", "pistol_aur", "pistol_roz", "katana", "cutit", "vraja_foc"]

var _in_curs := false


func _ready() -> void:
	indiciu = "[E] Talk to the employee"
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
	if Stare.e_marcat(marcaj_gata):
		await _spune(replici_dupa)
		_in_curs = false
		return
	await _spune(replici_inainte)
	var arma := _arma_de_aratat()
	if arma != "":
		Stare.tine_in_mana(arma)
		await get_tree().create_timer(0.55).timeout  # cât urcă arma în cadru
	await _maini_sus(true)
	await _spune(replici_dupa_arma)
	_maini_sus(false)
	Stare.marcheaza(marcaj_gata)
	if sarcina_noua != "":
		Stare.seteaza_sarcina(sarcina_noua)
	_in_curs = false


func _spune(linii: PackedStringArray) -> void:
	if linii.is_empty():
		return
	Dialog.spune(linii)
	if Dialog.activ:
		await Dialog.terminat


func _arma_de_aratat() -> String:
	for id in ARME:
		if Stare.are_obiect(id):
			return id
	return ""


## Ridică mâinile (sus, lângă cap, cu palmele spre tine) sau le lasă înapoi pe blat.
func _maini_sus(sus: bool) -> void:
	if om == null:
		return
	if not sus:
		om.lasa_mana("D", 0.8)
		om.lasa_mana("S", 0.8)
		return
	Sunet.reda_la(SUNET_MAINI_SUS, om.global_position + Vector3.UP * 1.2, Sunet.VOLUM_EFECTE - 4.0, 0.05)
	om.tresare(om.global_basis * Vector3.FORWARD)  # se trage înapoi, de la tine
	var cap := om.global_position + om.global_basis * Vector3(0.0, 1.32, 0.0)
	om.du_mana("D", cap + om.global_basis * Vector3(-0.32, 0.3, 0.1), 0.3)
	await om.du_mana("S", cap + om.global_basis * Vector3(0.32, 0.3, 0.1), 0.3)
