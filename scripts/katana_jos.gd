extends ObiectLuat
## Katana din parcarea barului „URBAN” (bar.tscn, nodul `KatanaJos`): pe jos, în colțul dintre zidul din spate și
## clădirea vecină, după tomberon (owner, 10.10). La E intră în inventar („Katana”, `Katana.ID`) și se ține ca armele
## de la Gun Store (katana.gd). Odată luată nu mai apare acolo (`marcaj_luat`), chiar dacă o arunci sau o pui pe raft.

@export var marcaj_luat := "a_luat_katana"


func _ready() -> void:
	id_obiect = Katana.ID
	nume_obiect = Katana.NUME
	if Stare.e_marcat(marcaj_luat):
		queue_free()
		return
	folosit.connect(func() -> void: Stare.marcheaza(marcaj_luat))
