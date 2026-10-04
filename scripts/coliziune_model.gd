class_name ColiziuneModel
extends RefCounted
## Coliziune făcută din mărimea unui model (cutia care-l cuprinde), pentru obiecte puse din cod
## sau din editor care altfel n-ar avea „hitbox”: pietre, bușteni, cruci.
##   ColiziuneModel.adauga(corp, scena, transform, true)   -> cilindru (pietre: n-au colțuri de agățat)
##   ColiziuneModel.adauga(corp, scena, transform, false)  -> cutie (bușteni, cruci)
##   ColiziuneModel.pentru_nod(model, true)                -> același lucru pentru un model deja în scenă
## corp = StaticBody3D-ul în care intră forma; transform = unde stă modelul, în coordonatele corpului.

## Pietrele sunt colțuroase și mai înguste sus: cilindrul ia doar o parte din lățimea lor,
## ca să nu te oprești în aer, la o palmă de piatră.
const LATIME_CILINDRU := 0.8

static var _cutii := {}


## Cutia care cuprinde tot modelul (în coordonatele lui), ținută minte pentru fiecare scenă.
static func cutie(scena: PackedScene) -> AABB:
	if not _cutii.has(scena):
		var model := scena.instantiate()
		_cutii[scena] = cutie_nod(model)
		model.free()
	return _cutii[scena]


static func cutie_nod(radacina: Node) -> AABB:
	var rezultat := AABB()
	var prima := true
	for nod in radacina.find_children("*", "MeshInstance3D", true, false):
		var mi := nod as MeshInstance3D
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != radacina and n is Node3D:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var c := t * mi.mesh.get_aabb()
		rezultat = c if prima else rezultat.merge(c)
		prima = false
	return rezultat


static func adauga(corp: CollisionObject3D, scena: PackedScene, t: Transform3D, rotund: bool) -> void:
	forma(corp, cutie(scena), t, rotund)


## Pune un StaticBody3D cu coliziune pe un model care stă deja în scenă.
static func pentru_nod(model: Node3D, rotund: bool) -> StaticBody3D:
	var corp := StaticBody3D.new()
	corp.name = "Coliziune"
	model.add_child(corp)
	forma(corp, cutie_nod(model), Transform3D.IDENTITY, rotund)
	return corp


static func forma(corp: CollisionObject3D, c: AABB, t: Transform3D, rotund: bool) -> void:
	# formele nu se scalează (fizica nu le suportă bine): mărimea intră direct în dimensiuni
	var marime := t.basis.get_scale().x
	var baza := t.basis.orthonormalized()
	var centru := c.get_center()
	var nod := CollisionShape3D.new()
	if rotund:
		var cilindru := CylinderShape3D.new()
		cilindru.radius = maxf(c.size.x, c.size.z) * 0.5 * LATIME_CILINDRU * marime
		cilindru.height = c.size.y * marime
		nod.shape = cilindru
	else:
		var box := BoxShape3D.new()
		box.size = c.size * marime
		nod.shape = box
	nod.transform = Transform3D(baza, t.origin + baza * (centru * marime))
	corp.add_child(nod)
