class_name Ragdoll
extends Node3D
## Corpul unui personaj mort, care cade moale, ca o păpușă de cârpă (ragdoll).
##   var r := Ragdoll.din_model($Model, impuls, ["SticlaMana"])
## Fiecare bucată a modelului (MeshInstance3D din .glb: Corp, Cap, BratBere, CoapsaS, GambaS...) devine un corp
## fizic (RigidBody3D) cu o cutie cât ea, legat de bucata-părinte printr-o încheietură (ConeTwistJoint3D) chiar în
## originea bucății: modelele au originea fiecărei bucăți în punctul în care se îndoaie (gât, umăr, șold, genunchi).
## Bucata de bază e `Corp`; bucățile din `lipite` (sticla din mână) rămân prinse de părintele lor.
## Bucățile nu se lovesc între ele (s-ar respinge, sunt lipite la încheieturi), doar de lume (stratul 1).
## Jucătorul nu se împiedică de ele (stau pe stratul STRAT, pe care jucătorul nu-l vede).

## Stratul de coliziune al bucăților (3 = valoarea 4).
const STRAT := 4
## Cât de mult se poate îndoi o încheietură față de cum stătea (radiani), și cât se poate răsuci.
const INDOIRE := 0.9
const RASUCIRE := 0.5

## Corpul de bază (trunchiul), de care se leagă tot restul.
var trunchi: RigidBody3D
var bucati: Array[RigidBody3D] = []

var _impuls := Vector3.ZERO
var _cadre := 0


## Face ragdoll din `model` (îl golește: bucățile lui trec în corpurile fizice) și îi dă un brânci `impuls`
## (N·s, în coordonate globale) în piept. Ragdoll-ul intră în scenă lângă model.
static func din_model(model: Node3D, impuls: Vector3, lipite: PackedStringArray = []) -> Ragdoll:
	var r := Ragdoll.new()
	r.name = "Cadavru"
	model.get_parent().get_parent().add_child(r)
	r.global_transform = Transform3D.IDENTITY
	var corpuri := {}
	r._fa_bucati(model, model, null, corpuri, lipite)
	r._leaga(corpuri)
	# brânciul se dă la al doilea cadru de fizică: abia atunci corpurile au masa pusă (altfel zboară ca un fulg)
	r._impuls = impuls
	return r


func _physics_process(_delta: float) -> void:
	_cadre += 1
	if _cadre == 2 and trunchi and _impuls != Vector3.ZERO:
		# în piept, puțin deasupra mijlocului: corpul se dă pe spate, nu alunecă
		trunchi.apply_impulse(_impuls, centru() - trunchi.global_position + Vector3.UP * 0.3)
		_impuls = Vector3.ZERO


## Parcurge modelul: fiecare MeshInstance3D care nu e în `lipite` devine un corp fizic.
func _fa_bucati(nod: Node, model: Node3D, parinte: RigidBody3D, corpuri: Dictionary, lipite: PackedStringArray) -> void:
	for copil in nod.get_children():
		var mesh := copil as MeshInstance3D
		if mesh == null:
			continue
		var corp := parinte
		if not mesh.name in lipite:
			corp = _corp_pentru(mesh)
			corpuri[corp] = parinte
		_fa_bucati(mesh, model, corp, corpuri, lipite)


func _corp_pentru(mesh: MeshInstance3D) -> RigidBody3D:
	var corp := RigidBody3D.new()
	corp.name = String(mesh.name)
	corp.collision_layer = STRAT
	corp.collision_mask = 1
	corp.linear_damp = 0.2
	corp.angular_damp = 2.0
	add_child(corp)
	var t := mesh.global_transform
	corp.global_transform = Transform3D(t.basis.orthonormalized(), t.origin)
	# cutia = cât bucata singură (fără copiii ei), puțin mai mică, ca să nu se înțepenească în pământ
	var cutie := mesh.mesh.get_aabb()
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = (cutie.size * 0.85).max(Vector3.ONE * 0.04)
	forma.shape = box
	forma.position = cutie.get_center()
	corp.add_child(forma)
	# un om de vreo 70 kg: trunchiul greu, membrele ușoare
	corp.mass = 30.0 if mesh.name == "Corp" else clampf(cutie.size.x * cutie.size.y * cutie.size.z * 150.0, 2.0, 8.0)
	mesh.reparent(corp, true)
	if mesh.name == "Corp":
		trunchi = corp
	bucati.append(corp)
	return corp


## Leagă fiecare corp de părintele lui, în originea lui. Axa încheieturii (X) arată spre mijlocul bucății.
func _leaga(corpuri: Dictionary) -> void:
	for corp: RigidBody3D in corpuri:
		# bucățile de pe primul nivel al modelului (Cap, brațele, coapsele) se prind de trunchi
		var parinte: RigidBody3D = corpuri[corp] if corpuri[corp] else trunchi
		if corp == trunchi or parinte == null:
			continue
		var forma := corp.get_child(0) as CollisionShape3D
		var spre := corp.global_transform.basis * forma.position
		if spre.length() < 0.001:
			spre = Vector3.DOWN
		var x := spre.normalized()
		var y := x.cross(Vector3.FORWARD if absf(x.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		var z := x.cross(y)
		var legatura := ConeTwistJoint3D.new()
		legatura.name = "Incheietura" + corp.name
		add_child(legatura)
		legatura.global_transform = Transform3D(Basis(x, y, z), corp.global_position)
		legatura.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, INDOIRE)
		legatura.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, RASUCIRE)
		legatura.node_a = legatura.get_path_to(parinte)
		legatura.node_b = legatura.get_path_to(corp)
	# bucățile nu se lovesc între ele
	for a in bucati:
		for b in bucati:
			if a != b:
				a.add_collision_exception_with(b)


## Mijlocul trunchiului (pentru „[E] Pick up”, sunetul căderii etc.).
func centru() -> Vector3:
	if trunchi == null:
		return global_position
	return trunchi.global_transform * (trunchi.get_child(0) as CollisionShape3D).position


## „[E] Pick up …”: o sferă care stă pe trunchi, pe stratul 4 (valoarea 8), pe care o vede doar raza jucătorului
## (bucățile ragdoll-ului nu se lovesc de ea). La E intră în inventar ca `id` / `nume` și emite `folosit`.
func pune_ridicare(id: String, nume: String, indiciu: String) -> ObiectLuat:
	var ridicare := ObiectLuat.new()
	ridicare.id_obiect = id
	ridicare.nume_obiect = nume
	ridicare.indiciu = indiciu
	ridicare.collision_layer = 8
	ridicare.collision_mask = 0
	var forma := CollisionShape3D.new()
	var sfera := SphereShape3D.new()
	sfera.radius = 0.55
	forma.shape = sfera
	ridicare.add_child(forma)
	trunchi.add_child(ridicare)
	ridicare.global_position = centru()
	return ridicare


## Adevărat după ce s-a liniștit (nu se mai mișcă aproape deloc).
func s_a_oprit() -> bool:
	for b in bucati:
		if b.linear_velocity.length() > 0.15:
			return false
	return true
