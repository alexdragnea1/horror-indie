class_name Betie
extends RefCounted
## Cât de beat ești acum (de la băuturile din barul „URBAN”): fiecare pahar adaugă (`adauga`), iar nivelul scade singur
## cu `SCADERE_PE_MINUT`. Nu se salvează: după o tranziție sau un Continue ți-a trecut oricum.
## Îl folosesc jocurile din bar: la darts ținta tremură mai tare, la biliard tacul fuge puțin.

const SCADERE_PE_MINUT := 0.5

static var _nivel := 0.0
static var _ultima_ms := 0


## Nivelul de acum (0 = treaz; o bere ≈ 0,5, un whiskey ≈ 1).
static func nivel() -> float:
	var acum := Time.get_ticks_msec()
	_nivel = maxf(0.0, _nivel - float(acum - _ultima_ms) / 60000.0 * SCADERE_PE_MINUT)
	_ultima_ms = acum
	return _nivel


static func adauga(cat: float) -> void:
	_nivel = minf(nivel() + cat, 4.0)
