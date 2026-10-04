extends Node
## Casa, după ce te-ai trezit în fața blocului (`marcaj_trezit`, vezi intoarcere_acasa.gd):
##  - Mom nu mai e în bucătărie (`mama` dispare);
##  - ușa de la intrare nu te mai lasă afară (`replici_usa`);
##  - prima dată (fără `marcaj_venit`) intri pe ușa de la intrare (`loc_intrare`) și primești `sarcina_noua`.
##    Patul (pat.gd) face restul: te culci.
## La Continue nu te mai mută la ușă: rămâi unde te-a salvat jocul.
## Dimineața (`marcaj_dimineata`, după somn): ușa de la intrare se deschide abia după ce ai vorbit cu Head Witch în
## bucătărie (`marcaj_iesire_dimineata`; până atunci `replici_usa_dimineata`), iar afară e ziuă (`titlu_afara_dimineata`).

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

const USA_BLOC := preload("res://scripts/usa_bloc.gd")

@export_group("Dimineața")
@export var marcaj_dimineata := "e_dimineata"
@export var marcaj_iesire_dimineata := "a_vorbit_cu_sefa_acasa"
@export_multiline var replici_usa_dimineata: PackedStringArray = ["You: Hold up. Somebody's in the kitchen."]
@export_multiline var titlu_afara_dimineata := "Block M7, Entrance B\n12:41 PM"


func _ready() -> void:
	if not Stare.e_marcat(marcaj_trezit):
		return
	if is_instance_valid(mama):
		mama.queue_free()
	if usa_intrare:
		usa_intrare.marcaj_necesar = marcaj_iesire
		usa_intrare.replici_fara_marcaj = replici_usa
		if Stare.e_marcat(marcaj_dimineata):
			usa_intrare.marcaj_necesar = marcaj_iesire_dimineata
			usa_intrare.replici_fara_marcaj = replici_usa_dimineata
			usa_intrare.titlu_locatie = titlu_afara_dimineata
		# ieși pe ușă: afară te pune în fața scării (vezi zi_bloc.gd)
		usa_intrare.deschisa.connect(func() -> void: ZiBloc.din_casa = true)
	await get_tree().process_frame
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	var pe_usa: bool = USA_BLOC.intrat_pe_usa
	USA_BLOC.intrat_pe_usa = false
	if jucator == null or (Stare.e_marcat(marcaj_venit) and not pe_usa):
		return
	jucator.global_position = loc_intrare
	jucator.rotation.y = unghi_intrare
	jucator.get_node("Cap").rotation.x = 0.0
	if Stare.e_marcat(marcaj_venit):
		return
	Stare.marcheaza(marcaj_venit)
	while Tranzitie.activa:
		await get_tree().process_frame
	await get_tree().create_timer(0.8).timeout
	if sarcina_noua != "":
		Stare.seteaza_sarcina(sarcina_noua)
