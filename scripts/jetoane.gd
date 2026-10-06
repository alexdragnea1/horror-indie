class_name Jetoane
extends RefCounted
## Jetoanele de la „Casino” (spălătoria din oraș): suma e în cenți, ținută în marcajul `MARCAJ` (deci intră în salvare),
## iar în inventar apar ca un obiect („Chips ($12.50)”, id `ID`), care dispare când rămâi fără ele.
## Le primești de la bătrâna de la casă pe bancnota de 5 dolari (batrana_casino.gd); le joci la poker (masa_poker.gd)
## și la păcănele (pacanea_joc.gd).

const ID := "jetoane"
const MARCAJ := "jetoane_suma"


static func suma() -> int:
	return int(Stare.valoare_marcaj(MARCAJ, 0))


## Pune suma (în cenți) și actualizează numele din inventar. 0 = jetoanele dispar din inventar.
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
	return "Chips (%s)" % bani(centi)


## 1250 -> „$12.50”.
static func bani(centi: int) -> String:
	var semn := "-" if centi < 0 else ""
	centi = absi(centi)
	return "%s$%d.%02d" % [semn, centi / 100, centi % 100]
