class_name Tigari
extends RefCounted
## Pachetul de țigări din magazinul satului (casiera_magazin.gd, owner 17.11): $10, 20 de folosiri. Fiecare click cu
## țigara în mână (o aprinzi, apoi tragi din ea, ObiectInMana „fumat”) e o folosire; după a 20-a pachetul dispare din
## inventar. Câte ai folosit stă în marcajul `MARCAJ` (deci intră în salvare), iar numele din inventar arată câte au
## rămas: „Cigarettes (17)”. Berea (`ID_BERE`, $3) se bea o dată și dispare.

const ID := "tigari"
const ID_BERE := "bere"
const NUME_BERE := "Beer"
const MARCAJ := "tigari_folosite"
const FOLOSIRI := 20


static func ramase() -> int:
	return FOLOSIRI - int(Stare.valoare_marcaj(MARCAJ, 0)) if Stare.are_obiect(ID) else 0


static func nume(ramase_: int) -> String:
	return "Cigarettes (%d)" % ramase_


## Un pachet nou (cumpărat): 20 de folosiri.
static func pachet_nou() -> bool:
	Stare.marcheaza(MARCAJ, 0)
	return Stare.adauga_obiect(ID, nume(FOLOSIRI))


## O folosire. Întoarce true dacă a fost ultima (pachetul a dispărut din inventar).
static func foloseste() -> bool:
	var folosite := int(Stare.valoare_marcaj(MARCAJ, 0)) + 1
	Stare.marcaje[MARCAJ] = folosite
	if folosite >= FOLOSIRI:
		Stare.scoate_obiect(ID)
		return true
	Stare.obiecte[ID] = nume(FOLOSIRI - folosite)
	Stare.schimbat.emit()
	return false
