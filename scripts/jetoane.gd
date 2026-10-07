class_name Jetoane
extends RefCounted
## Jetoanele de la „Casino” (spălătoria din oraș): suma e în cenți, ținută în marcajul `MARCAJ` (deci intră în salvare),
## iar în inventar apar ca un obiect („Chips ($12.50)”, id `ID`), care dispare când rămâi fără ele.
## Le primești de la bătrâna de la casă pe bancnota de 5 dolari (batrana_casino.gd); le joci la poker (masa_poker.gd)
## și la păcănele (pacanea_joc.gd).

const ID := "jetoane"
const MARCAJ := "jetoane_suma"


static func suma() -> int:
	return int(Stare.valoare_marcaj(MARCAJ, 0)) if Stare.are_obiect(ID) else 0


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


## Un teanc de jetoane (pentru pe jos și în mână): două coloane, culorile mesei de poker. `neluminat` = culorile
## fără lumină (în mână: lanterna nu prinde ce e lipit de cameră).
static func model_teanc(neluminat := false) -> Node3D:
	var n := Node3D.new()
	var m := CylinderMesh.new()
	m.top_radius = MasaPoker.RAZA_JETON
	m.bottom_radius = MasaPoker.RAZA_JETON
	m.height = MasaPoker.GROSIME_JETON
	m.radial_segments = 10
	var culori := ["83b3b0", "7b383a", "30716f", "a18463"]
	var materiale := []
	for c in culori:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(c)
		mat.roughness = 0.8
		if neluminat:
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.albedo_color = Color(c).darkened(0.25)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		materiale.append(mat)
	for coloana in 2:
		var cate := 7 if coloana == 0 else 4
		for k in cate:
			var j := MeshInstance3D.new()
			j.mesh = m
			j.material_override = materiale[(k + coloana * 2) % materiale.size()]
			j.position = Vector3(coloana * MasaPoker.RAZA_JETON * 2.1 + randf_range(-0.001, 0.001),
				MasaPoker.GROSIME_JETON * (k + 0.5), randf_range(-0.001, 0.001))
			n.add_child(j)
	return n
