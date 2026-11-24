extends Personaj
## Mom pe banca din fața blocului (afara_bloc.tscn, nodul `MamaBanca`; owner 24.11): te așteaptă când vii acasă după
## ce ai omorât-o pe Head Witch (de la `marcaj_de_la` până dormi prima dată după final, `marcaj_pana_la`). Stă jos,
## deci doar capul se întoarce după tine. Până nu vorbești cu ea (`marcaj_dupa`) ușa blocului nu te lasă sus
## (usa_bloc.gd). Replicile sunt ale owner-ului, scrise exact cum le-a dat.

## De când și până când stă pe bancă.
@export var marcaj_de_la := "jocul_terminat"
@export var marcaj_pana_la := "nopti_dupa_final"


func _ready() -> void:
	if not Stare.e_marcat(marcaj_de_la) or Stare.e_marcat(marcaj_pana_la):
		queue_free()
		return
	super()
