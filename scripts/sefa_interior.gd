extends Personaj
## Head Witch în living room-ul conacului (conac_interior.tscn, nodul `HeadWitchInterior`), lângă scara din dreapta.
## Până înveți vraja de la Helga (`marcaj_helga`) îți spune `replici` (e sus, la Helga) și primești `sarcina_noua`;
## după lecție conversația asta nu mai apare (nu se mai poate vorbi cu ea, până continuă povestea).
## Replicile sunt ale owner-ului: nu le corecta.

@export var marcaj_helga := "a_invatat_fireball"


func poate_fi_folosit() -> bool:
	return super() and not Stare.e_marcat(marcaj_helga)
