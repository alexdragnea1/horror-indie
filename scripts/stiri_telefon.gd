extends Node
## Știrea de pe telefon (nodul `StiriDimineata` din nivel_test.tscn): dimineața de după Warlock, fix când te ridici din
## pat (`marcaj_dupa_care`, pus de pat.gd la trezire), îți vibrează telefonul: notificarea `notificare` de la `sursa`, o
## apeși și se deschide site-ul cu `titlu_articol` (sub el doar mâzgăleli), îl închizi (Telefon.stiri) → `replici` →
## `marcaj_gata` + `sarcina_noua`. La Continue, dacă n-ai apucat să citești știrea, vine din nou.
## Textele sunt ale owner-ului (nu le corecta); sarcina e a lui Claude.

@export var marcaj_dupa_care := "s_a_trezit_ziua_primariei"
@export var marcaj_gata := "a_citit_stirile"
## Cât după trezire (secunde).
@export var intarziere := 0.4
@export var sursa := "NEWS"
@export var notificare := "WITCH WANTS TO DESTROY TOWN"
@export var titlu_articol := "Witch becomes powerful and threatens small town."
## Ora de pe telefon.
@export var ora := "10:32"
@export_multiline var replici: PackedStringArray = ["You: I need to find and kill this bitch."]
@export var sarcina_noua := "Check the bus schedule."


func _ready() -> void:
	set_process(false)
	await get_tree().process_frame
	if get_tree().get_first_node_in_group("jucator") == null or Stare.e_marcat(marcaj_gata):
		return
	set_process(true)


func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 6 != 0 or not Stare.e_marcat(marcaj_dupa_care):
		return
	set_process(false)
	await get_tree().create_timer(intarziere).timeout
	while Dialog.activ or Stare.meniu_deschis or Tranzitie.activa:
		await get_tree().create_timer(0.2).timeout
	if not is_inside_tree():
		return
	await Telefon.stiri(self, sursa, notificare, titlu_articol, ora)
	Dialog.spune(replici)
	if Dialog.activ:
		await Dialog.terminat
	Stare.marcheaza(marcaj_gata)
	if sarcina_noua != "":
		Stare.seteaza_sarcina(sarcina_noua)
