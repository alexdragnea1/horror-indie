extends Node
## În fața blocului, noaptea (11:38 PM), după ce te-a adus Head Witch de la conacul distrus (`marcaj_zbor`, pus în
## sefa_ruine.gd). Ea nu mai e aici. Prima dată (fără `marcaj_gata`) te pune în fața scării, iar după tranziție (după ce a
## stat puțin pe ecran numele locului cu ora) spui singur `replici` (ale owner-ului, nu le corecta).
## Curtea e noapte, ca la început: SearaBloc nu mai face „blue hour” după `marcaj_zbor` (vezi `marcaj_noapte` acolo).
## Fără `Jucator` (fundalul din meniul principal) nu face nimic.

@export var marcaj_zbor := "a_zburat_acasa_dupa_atac"
@export var marcaj_gata := "a_ajuns_acasa_dupa_atac"
## Unde apari și încotro te uiți (radiani; 0 = spre bloc).
@export var loc := Vector3(1.2, 0.1, 6.0)
@export var unghi := 0.25
## Cât stă pe ecran numele locului (cu ora) înainte să înceapă replicile (secunde).
@export var pauza_inainte := 4.0
@export_multiline var replici: PackedStringArray = []
## Sarcina de după replici (gol = niciuna).
@export var sarcina_noua := ""


func _ready() -> void:
	var jucator := get_parent().get_node_or_null("Jucator") as Node3D
	if jucator == null or not Stare.e_marcat(marcaj_zbor) or Stare.e_marcat(marcaj_gata):
		return
	await get_tree().process_frame
	jucator.global_position = loc
	jucator.rotation.y = unghi
	jucator.get_node("Cap").rotation.x = 0.0
	while Tranzitie.activa:
		await get_tree().process_frame
	await get_tree().create_timer(pauza_inainte).timeout
	Dialog.spune(replici)
	if Dialog.activ:
		await Dialog.terminat
	Stare.marcheaza(marcaj_gata)
	if sarcina_noua != "":
		Stare.seteaza_sarcina(sarcina_noua)
