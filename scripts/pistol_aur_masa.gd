extends ObiectLuat
## Easter egg-ul din spatele conacului (conac.tscn, nodul `PistolAur` de pe `MasaPistol`): pistolul placat cu aur,
## pe o pernuță de catifea, lângă cartonul „Free shit”. La E intră în inventar („Gold Pistol”, `Pistol.ID_AUR`) și
## trage ca pistolul roz. Odată luat nu mai apare pe masă (`marcaj_luat`), chiar dacă îl arunci sau îl pui pe raft.

@export var marcaj_luat := "a_luat_pistolul_de_aur"


func _ready() -> void:
	id_obiect = Pistol.ID_AUR
	if Stare.e_marcat(marcaj_luat):
		queue_free()
		return
	folosit.connect(func() -> void: Stare.marcheaza(marcaj_luat))
