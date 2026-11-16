class_name UsaPivnita
extends UsaScena
## Ușa pivniței, în spatele lui Jean (casa_jean.tscn, owner 16.11). **Fără cheie nu arată nimic**: nici „[E]”, nici
## replici (`poate_fi_folosit` e fals), arată doar ca o ușă veche. Cu cheia (`MasaSah.ID_CHEIE`, o scapă Jean pe tablă
## când îl bați): „[E] Open the cellar door” → descuiat, scârțâit, pivnita.tscn. După prima dată (`MARCAJ_DESCHISA`)
## rămâne descuiată și fără cheie.

const MARCAJ_DESCHISA := "a_descuiat_pivnita"
const SUNET_DESCUIAT := preload("res://sunete/usa_incuiata.ogg")


func poate_fi_folosit() -> bool:
	return super() and (Stare.are_obiect(MasaSah.ID_CHEIE) or Stare.e_marcat(MARCAJ_DESCHISA))


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	if not Stare.e_marcat(MARCAJ_DESCHISA):
		Sunet.reda_la(SUNET_DESCUIAT, global_position + Vector3.UP, Sunet.VOLUM_EFECTE, 0.05)
		Stare.marcheaza(MARCAJ_DESCHISA)
		await get_tree().create_timer(0.45).timeout
	super()
