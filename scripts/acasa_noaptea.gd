extends Node
## Casa, după ce te-ai trezit în fața blocului (`marcaj_trezit`, vezi intoarcere_acasa.gd):
##  - Mom nu mai e în bucătărie (`mama` dispare);
##  - ușa de la intrare nu te mai lasă afară (`replici_usa`);
##  - prima dată (fără `marcaj_venit`) intri pe ușa de la intrare (`loc_intrare`) și primești `sarcina_noua`.
##    Patul (pat.gd) face restul: te culci.
## La Continue nu te mai mută la ușă: rămâi unde te-a salvat jocul.

@export var marcaj_trezit := "s_a_trezit_la_bloc"
@export var marcaj_venit := "a_venit_acasa"
@export var sarcina_noua := "Go to sleep."
@export var mama: Node3D
@export var usa_intrare: Usa
## Marcajul care va deschide iar ușa de la intrare (încă nu-l pune nimic).
@export var marcaj_iesire := "poate_iesi_din_casa"
@export_multiline var replici_usa: PackedStringArray = ["You: I'm not going back out there. I need some sleep."]
## Unde stai după ce ai închis ușa în urma ta, și încotro te uiți (radiani; PI = spre bucătărie).
@export var loc_intrare := Vector3(0.0, 0.02, -13.35)
@export var unghi_intrare := PI


func _ready() -> void:
	if not Stare.e_marcat(marcaj_trezit):
		return
	if is_instance_valid(mama):
		mama.queue_free()
	if usa_intrare:
		usa_intrare.marcaj_necesar = marcaj_iesire
		usa_intrare.replici_fara_marcaj = replici_usa
	await get_tree().process_frame
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	if jucator == null or Stare.e_marcat(marcaj_venit):
		return
	jucator.global_position = loc_intrare
	jucator.rotation.y = unghi_intrare
	jucator.get_node("Cap").rotation.x = 0.0
	Stare.marcheaza(marcaj_venit)
	while Tranzitie.activa:
		await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	if sarcina_noua != "":
		Stare.seteaza_sarcina(sarcina_noua)
