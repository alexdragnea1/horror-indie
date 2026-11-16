class_name UsaPivnita
extends UsaScena
## Ușa pivniței, în spatele lui Jean (casa_jean.tscn, owner 16.11). **Fără cheie nu arată nimic**: nici „[E]”, nici
## replici (`poate_fi_folosit` e fals), arată doar ca o ușă veche. Cu cheia (`MasaSah.ID_CHEIE`, o scapă Jean pe tablă
## când îl bați): „[E] Open the cellar door” → descuiat, scârțâit, pivnita.tscn. La descuiere **cheia dispare din
## inventar** (`MARCAJ_DESCHISA`), iar ușa rămâne deschisă doar **până dai spin la roată** (`RoataNoroc.MARCAJ`):
## după aceea nu mai arată nimic (din pivniță ieși tot pe scară).

const MARCAJ_DESCHISA := "a_descuiat_pivnita"
const SUNET_DESCUIAT := preload("res://sunete/usa_incuiata.ogg")


func poate_fi_folosit() -> bool:
	if not super() or Stare.e_marcat(RoataNoroc.MARCAJ):
		return false
	return Stare.are_obiect(MasaSah.ID_CHEIE) or Stare.e_marcat(MARCAJ_DESCHISA)


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	if not Stare.e_marcat(MARCAJ_DESCHISA):
		Sunet.reda_la(SUNET_DESCUIAT, global_position + Vector3.UP, Sunet.VOLUM_EFECTE, 0.05)
		Stare.marcheaza(MARCAJ_DESCHISA)
		Stare.scoate_obiect(MasaSah.ID_CHEIE)  # cheia rămâne în broască
		await get_tree().create_timer(0.45).timeout
	super()


func _ready() -> void:
	# salvările de dinainte (owner 16.11): ușa descuiată deja, dar cheia rămăsese în inventar
	if Stare.e_marcat(MARCAJ_DESCHISA) and Stare.are_obiect(MasaSah.ID_CHEIE):
		Stare.scoate_obiect(MasaSah.ID_CHEIE)
