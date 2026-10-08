extends Node
## O replică spusă singur, o dată, când ajungi în scenă: cu `marcaj_necesar` pus și fără `marcaj_gata`, după Tranzitie
## și `pauza_inainte` (cât stă pe ecran numele locului: un dialog l-ar ascunde) → `replici` → `marcaj_gata` + `sarcina_noua`.
## Ex. `ZiOras` din `afara_bloc.tscn`: dimineața de după atac, când ieși din bloc, „I should check the bus schedule…”.
## Fără `Jucator` (fundalul din meniul principal) nu face nimic.

@export var marcaj_necesar := "ziua_orasului"
@export var marcaj_gata := "vrea_in_oras"
## După marcajul ăsta nu mai are sens (gol = nicio limită), ex. replica de noapte nu se spune a doua zi.
@export var marcaj_oprire := ""
@export var pauza_inainte := 3.5
@export_multiline var replici: PackedStringArray = []
## Gol = niciuna.
@export var sarcina_noua := ""


func _ready() -> void:
	if get_parent().get_node_or_null("Jucator") == null:
		return
	if not Stare.e_marcat(marcaj_necesar) or Stare.e_marcat(marcaj_gata):
		return
	if marcaj_oprire != "" and Stare.e_marcat(marcaj_oprire):
		return
	await get_tree().process_frame
	while Tranzitie.activa:
		await get_tree().process_frame
	await get_tree().create_timer(pauza_inainte).timeout
	while Dialog.activ:
		await Dialog.terminat
	Dialog.spune(replici)
	if Dialog.activ:
		await Dialog.terminat
	Stare.marcheaza(marcaj_gata)
	if sarcina_noua != "":
		Stare.seteaza_sarcina(sarcina_noua)
