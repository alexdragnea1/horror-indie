extends Interactabil
## Ușa scării de bloc (în afara_bloc.tscn). Până te aduce Head Witch acasă (`marcaj_necesar`) spune doar
## `replici` („Nope. Mom's still up there.”); după aceea te duce înapoi în casă (`scena_acasa`), prin Tranzitie,
## cu pașii pe scări și ușa apartamentului pe ecranul negru. Ziua (`marcaj_dimineata`) scrie altă oră.
## Seara, după Lexy (`marcaj_seara`), nu te lasă sus: te așteaptă Head Witch (`replici_seara`).
## Casa te pune lângă ușa de la intrare (`intrat_pe_usa`, citit de acasa_noaptea.gd).

## Adevărat de la deschiderea ușii până te pune casa pe hol.
static var intrat_pe_usa := false

@export var marcaj_necesar := "s_a_trezit_la_bloc"
@export_file("*.tscn") var scena_acasa := "res://scenes/nivel_test.tscn"
@export_multiline var titlu_acasa := "Home\n1:16 AM"
@export var marcaj_dimineata := "e_dimineata"
@export_multiline var titlu_acasa_dimineata := "Home"
@export var marcaj_seara := "a_urcat_spre_casa"
@export_multiline var replici_seara: PackedStringArray = ["You: What the fuck does she want now..."]
## După atacul de la conac (te-a adus Head Witch la 11:38 PM): ce urmează n-a zis încă owner-ul, deci doar o replică
## (scrisă de Claude, owner-ul o poate schimba).
@export var marcaj_noapte := "a_zburat_acasa_dupa_atac"
@export_multiline var replici_noapte: PackedStringArray = ["You: I need a minute before I go up there..."]
## Ce se aude pe negru: ușa blocului, scările, ușa apartamentului.
@export var sunete_tranzitie: Array[AudioStream] = []
@export var sunet_usa: AudioStream


func interactioneaza() -> void:
	if not Stare.e_marcat(marcaj_necesar):
		super.interactioneaza()
		return
	if Stare.e_marcat(marcaj_noapte):
		Dialog.spune(replici_noapte)
		return
	if Stare.e_marcat(marcaj_seara):
		Dialog.spune(replici_seara)
		return
	Sunet.reda_la(sunet_usa, global_position + Vector3.UP, Sunet.VOLUM_EFECTE, 0.05)
	folosit.emit()
	intrat_pe_usa = true
	var titlu := titlu_acasa_dimineata if Stare.e_marcat(marcaj_dimineata) else titlu_acasa
	Tranzitie.mergi_la(scena_acasa, titlu, sunete_tranzitie)
