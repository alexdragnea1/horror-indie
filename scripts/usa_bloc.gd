extends Interactabil
## Ușa scării de bloc (în afara_bloc.tscn). Până te aduce Head Witch acasă (`marcaj_necesar`) spune doar
## `replici` („Nope. Mom's still up there.”); după aceea te duce înapoi în casă (`scena_acasa`), prin Tranzitie,
## cu pașii pe scări și ușa apartamentului pe ecranul negru.

@export var marcaj_necesar := "s_a_trezit_la_bloc"
@export_file("*.tscn") var scena_acasa := "res://scenes/nivel_test.tscn"
@export_multiline var titlu_acasa := "Home\n1:16 AM"
## Ce se aude pe negru: ușa blocului, scările, ușa apartamentului.
@export var sunete_tranzitie: Array[AudioStream] = []
@export var sunet_usa: AudioStream


func interactioneaza() -> void:
	if not Stare.e_marcat(marcaj_necesar):
		super.interactioneaza()
		return
	Sunet.reda_la(sunet_usa, global_position + Vector3.UP, Sunet.VOLUM_EFECTE, 0.05)
	folosit.emit()
	Tranzitie.mergi_la(scena_acasa, titlu_acasa, sunete_tranzitie)
