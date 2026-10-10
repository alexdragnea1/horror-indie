class_name Bani
extends RefCounted
## Banii adevărați (cash), ca Jetoane: suma e în cenți, ținută în marcajul `MARCAJ` (deci intră în salvare), iar în
## inventar apar ca un obiect („Cash ($12.50)”, id `ID`), care dispare când rămâi fără ei.
## Îi primești de la bătrâna de la casino, când dai „Cash out” pe jetoane (batrana_casino.gd); cu ei plătești la Gun Store
## (vanzator_arme.gd). Bancnota de 5 dolari de la Lexy intră și ea aici (`BANCNOTA`): toți banii sunt un singur obiect.
## Aruncați pe jos (ObiecteLume), suma rămâne în obiectul de pe jos: `suma()` numără doar ce ai în inventar.

const ID := "cash"
const MARCAJ := "cash_suma"
## Bancnota de 5 dolari de la Lexy (`LexyMasa.ID_BANI`), în cenți: n-are obiect al ei, intră mereu în cash
## (Stare.adauga_obiect o adună, Stare.importa unește salvările vechi).
const BANCNOTA := 500
## Bancnota de 20 de dolari pe care ți-o dă Lexy la împrumut (`LexyMasa.ID_BANI_IMPRUMUT`), tot în cenți, tot în cash.
const BANCNOTA_IMPRUMUT := 2000


static func suma() -> int:
	return int(Stare.valoare_marcaj(MARCAJ, 0)) if Stare.are_obiect(ID) else 0


## Pune suma (în cenți) și actualizează numele din inventar. 0 = banii dispar din inventar.
static func seteaza(centi: int) -> void:
	centi = maxi(centi, 0)
	Stare.marcaje[MARCAJ] = centi
	if centi <= 0:
		if Stare.are_obiect(ID):
			Stare.scoate_obiect(ID)
		else:
			Stare.schimbat.emit()
		return
	if Stare.are_obiect(ID):
		Stare.obiecte[ID] = nume(centi)
		Stare.schimbat.emit()
	else:
		Stare.adauga_obiect(ID, nume(centi))


static func adauga(centi: int) -> void:
	seteaza(suma() + centi)


static func nume(centi: int) -> String:
	return "Cash (%s)" % Jetoane.bani(centi)


## Tot ce poți plăti (bancnota de 5 dolari e deja în cash).
static func de_platit() -> int:
	return suma()


static func plateste(centi: int) -> void:
	seteaza(suma() - centi)
