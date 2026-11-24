extends ObiectLuat
## Furca rezemată de peretele din spate al casei din dreapta primăriei (primarie.tscn, nodul `FurcaJos`; owner 24.11).
## La E intră în inventar („Pitchfork”, `Furca.ID`), „You: I think nobody saw me.” (owner), și se ține ca o armă
## (furca.gd). Odată luată nu mai apare acolo (`marcaj_luat`), chiar dacă o arunci sau o pui pe raft.

@export var marcaj_luat := "a_luat_furca"


func _ready() -> void:
	id_obiect = Furca.ID
	nume_obiect = Furca.NUME
	if Stare.e_marcat(marcaj_luat):
		queue_free()
		return
	folosit.connect(func() -> void: Stare.marcheaza(marcaj_luat))
