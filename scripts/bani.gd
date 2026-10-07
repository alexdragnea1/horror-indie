class_name Bani
extends RefCounted
## Banii adevărați (cash), ca Jetoane: suma e în cenți, ținută în marcajul `MARCAJ` (deci intră în salvare), iar în
## inventar apar ca un obiect („Cash ($12.50)”, id `ID`), care dispare când rămâi fără ei.
## Îi primești de la bătrâna de la casino, când dai „Cash out” pe jetoane (batrana_casino.gd); cu ei plătești la Gun Store
## (vanzator_arme.gd), unde se socotește și bancnota de 5 dolari de la Lexy (`LexyMasa.ID_BANI`).
## Aruncați pe jos (ObiecteLume), suma rămâne în obiectul de pe jos: `suma()` numără doar ce ai în inventar.

const ID := "cash"
const MARCAJ := "cash_suma"


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


## Tot ce poți plăti: cash-ul plus bancnota de 5 dolari.
static func de_platit() -> int:
	return suma() + (500 if Stare.are_obiect(LexyMasa.ID_BANI) else 0)


## Plătește `centi`: întâi din cash, apoi bancnota de 5 dolari (restul, dacă rămâne, intră în cash).
static func plateste(centi: int) -> void:
	var din_cash := mini(centi, suma())
	var rest := centi - din_cash
	if rest > 0 and Stare.are_obiect(LexyMasa.ID_BANI):
		Stare.scoate_obiect(LexyMasa.ID_BANI)
		seteaza(suma() - din_cash + 500 - rest)
	else:
		seteaza(suma() - din_cash)
