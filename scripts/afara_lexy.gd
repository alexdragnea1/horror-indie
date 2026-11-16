extends Node3D
## Decorul de afară de la Lexy, pus din cod (aceeași așezare la fiecare pornire, `saminta`):
##  - cimitirul de peste drum (în spatele stației): morminte pe rânduri strâmbe, cruci, copaci morți, cripta în fund;
##  - gardurile de fier: al cimitirului (cu poarta la `x_poarta`) și cel din fața curților (owner 16.11: lung cât toate
##    trei casele, cu câte un gol de alee la fiecare);
##  - casele vecinilor, în ceață (același model ca a ei), cu ușă, alee și draperiile trase la toate geamurile
##    (owner 16.11: să nu se vadă înăuntru). Casa din stânga e a lui Jean: coliziune pe plasă (veranda, treptele) și
##    ușa `UsaJean` („Press E to knock”, apoi casa_jean.tscn); în fața ei punctul `SosireJean` (de acolo ieși, și acolo
##    te pune Retry după ce te-a împușcat). Cea din dreapta are o cutie de coliziune pe toată casa.
## Ca să muți ceva: schimbă numerele de mai jos (z-ul gardurilor, unde e cripta) sau `saminta` (alt cimitir).

@export var saminta := 13
## Gardul cimitirului: pe z, de la x_min la x_max, cu poarta (2,5 m) la x_poarta.
@export var z_gard_cimitir := 19.7
@export var x_poarta := -6.0
@export var cimitir_x := Vector2(-30.0, 30.0)
@export var cimitir_z := Vector2(21.5, 44.0)
@export var cripta := Vector3(2.0, 0.0, 36.0)
## Gardul curților: lui Lexy și ale vecinilor (cu golurile aleilor în dreptul ușilor).
@export var z_gard_curte := 7.3
@export var curte_x := Vector2(-30.5, 30.5)
## Casele vecinilor: [poziție, unghi]. Prima e a lui Jean (stânga).
@export var vecini: Array = [[Vector3(-21.0, 0.0, 0.5), 0.08], [Vector3(22.5, 0.0, -0.5), -0.06]]

const MATERIAL := preload("res://shaders/material_model.tres")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const GARD := preload("res://models/gard_fier.glb")
const POARTA := preload("res://models/poarta_cimitir.glb")
const MORMINTE := [preload("res://models/mormant_1.glb"), preload("res://models/mormant_2.glb"), preload("res://models/mormant_3.glb"),
	preload("res://models/cruce.glb")]
const CRIPTA := preload("res://models/cripta.glb")
const COPACI := [preload("res://models/copac_mort_1.glb"), preload("res://models/copac_mort_2.glb")]
const CASA := preload("res://models/casa_lexy.glb")


func _ready() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = saminta
	# --- gardul cimitirului, cu poarta
	_gard(z_gard_cimitir, cimitir_x.x, cimitir_x.y, x_poarta - 1.5, x_poarta + 1.5, true)
	var poarta := _pune(POARTA, Vector3(x_poarta, 0.0, z_gard_cimitir), 0.0)
	ColiziuneModel.pentru_nod(poarta, false)
	_gard_curti()
	# --- mormintele: rânduri (cu fața spre stradă), strâmbe, unele căzute într-o parte
	var z := cimitir_z.x
	while z < cimitir_z.y:
		var x := cimitir_x.x + 1.5 + r.randf_range(0.0, 1.0)
		while x < cimitir_x.y - 1.5:
			var langa_cripta := Vector2(x - cripta.x, z - cripta.z).length() < 4.0
			var pe_alee := absf(x - x_poarta) < 1.6
			if not langa_cripta and not pe_alee and r.randf() < 0.78:
				var m: PackedScene = MORMINTE[r.randi_range(0, MORMINTE.size() - 1)]
				var nod := _pune(m, Vector3(x + r.randf_range(-0.3, 0.3), 0.0, z + r.randf_range(-0.3, 0.3)), PI + r.randf_range(-0.12, 0.12))
				nod.rotation.z = r.randf_range(-0.08, 0.08)
				nod.rotation.x = r.randf_range(-0.06, 0.1)
				nod.scale = Vector3.ONE * r.randf_range(0.9, 1.1)
			x += r.randf_range(2.0, 2.8)
		z += r.randf_range(2.6, 3.2)
	_pune(CRIPTA, cripta, PI)
	# --- copaci morți printre morminte și câțiva pe marginea străzii
	for i in 9:
		var p := Vector3(r.randf_range(cimitir_x.x, cimitir_x.y), 0.0, r.randf_range(cimitir_z.x + 1.0, cimitir_z.y))
		var copac := _pune(COPACI[i % 2], p, r.randf_range(0.0, TAU))
		copac.scale = Vector3.ONE * r.randf_range(0.8, 1.25)
	# --- casele vecinilor, în ceață, cu ușă, alee și draperiile trase
	for i in vecini.size():
		var casa := _pune(CASA, vecini[i][0], vecini[i][1], "Geam", 3 if i == 0 else 0)
		if i > 0:
			# cutia care cuprinde casa: ieșea peste `Limite` și treceai prin ea (owner 10.11)
			ColiziuneModel.pentru_nod(casa, false)
		_usa_vecin(casa, i == 0)
		if i == 0:
			_intuneric_jean(casa)
		_draperii(casa)
		# fără draperie în geamul ușii: triunghiul e prea mic, falduri ieșeau peste el ca niște bare (owner 16.11)
		_alee(casa)
	_punct_sosire(_casa_jean())


const USA := preload("res://models/usa_lexy.glb")
const DRAPERIE := preload("res://models/draperie.glb")
const SUNET_USA := preload("res://sunete/usa_scartait.ogg")
const SUNETE_INTRARE: Array[AudioStream] = [preload("res://sunete/pas_lemn_1.ogg"), preload("res://sunete/pas_lemn_2.ogg"),
	preload("res://sunete/usa_inchisa.ogg")]
## Balamaua ușii la casa_lexy.glb (ca `UsaIntrare` din casa_lexy.tscn), în coordonatele casei.
const BALAMA := Vector3(-0.5, 0.45, -0.1)


func _casa_jean() -> Node3D:
	return _case.get(0)


var _case := {}


## Ușa (închisă) a unei case vecine. La Jean: `UsaJean` (bați, apoi intri); la cealaltă, o ușă fără nimic.
func _usa_vecin(casa: Node3D, a_lui_jean: bool) -> Node3D:
	_case[_case.size()] = casa
	var corp := (UsaJean.new() if a_lui_jean else StaticBody3D.new()) as StaticBody3D
	corp.name = "UsaJean" if a_lui_jean else "UsaVecin"
	if a_lui_jean:
		var usa_jean := corp as UsaJean
		usa_jean.scena = "res://scenes/casa_jean.tscn"
		usa_jean.titlu = "Jean's house"
		usa_jean.sosire = "SosireUsa"
		usa_jean.sunet_usa = SUNET_USA
		usa_jean.sunete_tranzitie = SUNETE_INTRARE
	casa.add_child(corp)
	corp.position = BALAMA
	var model := USA.instantiate() as Node3D
	model.name = "Model"
	model.set_script(SCRIPT_MODEL)
	model.set("material", MATERIAL)
	model.set("sticla", "Geam")
	corp.add_child(model)
	var forma := CollisionShape3D.new()
	forma.name = "Coliziune"
	var cutie := BoxShape3D.new()
	cutie.size = Vector3(1.0, 2.18, 0.05)
	forma.shape = cutie
	forma.position = Vector3(0.5, 1.09, 0.0)
	corp.add_child(forma)
	return model


## Draperii trase în spatele fiecărui geam (`Geam*`) din `model`: o draperie cât geamul, la 4 cm spre interior.
func _draperii(model: Node3D) -> void:
	var centru := _cutie(model).get_center()
	for m in model.find_children("Geam*", "MeshInstance3D", true, false):
		var geam := m as MeshInstance3D
		# toate geamurile casei sunt o singură piesă (`Geamuri`): fiecare geam = o bucată de triunghiuri lipite
		for a: AABB in _insule(geam.mesh):
			var subtire_x := a.size.x < a.size.z
			var latime := a.size.z if subtire_x else a.size.x
			if latime < 0.05 or a.size.y < 0.05:
				continue
			var d := DRAPERIE.instantiate() as Node3D
			d.set_script(SCRIPT_MODEL)
			d.set("material", MATERIAL)
			geam.add_child(d)
			d.position = a.get_center()
			# draperia (în planul XY al ei, fața spre +Z) se întoarce cu fața spre geam, adică spre afară
			var spre_interior := geam.to_local(centru) - a.get_center()
			if subtire_x:
				d.rotation.y = -PI / 2 if spre_interior.x > 0.0 else PI / 2
				d.position.x += signf(spre_interior.x) * 0.04
			else:
				d.rotation.y = PI if spre_interior.z > 0.0 else 0.0
				d.position.z += signf(spre_interior.z) * 0.04
			d.scale = Vector3(latime * 1.04, a.size.y * 1.02, 1.0)


static var _insule_cache := {}


## Cutiile bucăților dintr-un mesh (triunghiuri care au vârfuri comune = aceeași bucată). Ținute minte pe mesh.
static func _insule(mesh: Mesh) -> Array:
	if _insule_cache.has(mesh):
		return _insule_cache[mesh]
	var rezultat: Array = []
	for s in mesh.get_surface_count():
		var date := mesh.surface_get_arrays(s)
		var v: PackedVector3Array = date[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = date[Mesh.ARRAY_INDEX] if date[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			idx.resize(v.size())
			for i in v.size():
				idx[i] = i
		# vârfurile cu aceeași poziție (glTF le dublează pe muchii) sunt același punct
		var pe_poz := {}
		var parinte: Array[int] = []  # Array, nu Packed: lambda de mai jos trebuie să vadă schimbările
		parinte.resize(v.size())
		for i in v.size():
			var cheie := v[i].snapped(Vector3.ONE * 0.001)
			if not pe_poz.has(cheie):
				pe_poz[cheie] = i
			parinte[i] = pe_poz[cheie]
		var radacina := func(x: int) -> int:
			while parinte[x] != x:
				x = parinte[x]
			return x
		for t in range(0, idx.size(), 3):
			var a: int = radacina.call(idx[t])
			for k in [1, 2]:
				var b: int = radacina.call(idx[t + k])
				if a != b:
					parinte[b] = a
		var cutii := {}
		for i in v.size():
			var r: int = radacina.call(i)
			if cutii.has(r):
				cutii[r] = (cutii[r] as AABB).expand(v[i])
			else:
				cutii[r] = AABB(v[i], Vector3.ZERO)
		rezultat.append_array(cutii.values())
	_insule_cache[mesh] = rezultat
	return rezultat


func _cutie(nod: Node3D) -> AABB:
	var total := AABB()
	var prima := true
	for m in nod.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var a := nod.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		total = a if prima else total.merge(a)
		prima = false
	return nod.global_transform * total


## Aleea de beton de la ușă până la gard (ca a lui Lexy, `Teren/Alee`), cu pașii pe beton.
func _alee(casa: Node3D) -> void:
	var lexy := get_node_or_null("../Teren/Alee") as CSGBox3D
	if lexy:
		var noua := lexy.duplicate() as CSGBox3D
		lexy.get_parent().add_child(noua)
		noua.global_position = Vector3(casa.global_position.x + lexy.position.x, lexy.position.y, lexy.position.z)
	var beton := get_node_or_null("../Beton/Alee") as CollisionShape3D
	if beton:
		var noua := beton.duplicate() as CollisionShape3D
		beton.get_parent().add_child(noua)
		noua.position.x = casa.global_position.x + beton.position.x
	var lemn := get_node_or_null("../Lemn/Casa") as CollisionShape3D
	if lemn:
		var noua := lemn.duplicate() as CollisionShape3D
		lemn.get_parent().add_child(noua)
		noua.global_transform = casa.global_transform * lemn.transform


## `SosireJean`: în fața ușii lui Jean, pe verandă, cu spatele la ușă (cu fața spre stradă).
func _punct_sosire(casa: Node3D) -> void:
	var p := PunctSosire.new()
	p.name = MasaSah.SOSIRE_RETRY
	casa.add_child(p)
	p.position = Vector3(0.0, 0.47, 1.1)
	p.rotation.y = PI


## Gardul din fața curților, cu câte un gol de 1,8 m în dreptul fiecărei alei (la Lexy x = 0, la vecini în dreptul ușii).
func _gard_curti() -> void:
	var goluri: Array[float] = [0.0]
	for v in vecini:
		goluri.append((v[0] as Vector3).x + BALAMA.x + 0.5)
	goluri.sort()
	var x := curte_x.x
	for g in goluri:
		_gard_bucata(z_gard_curte, x, g - 0.9)
		x = g + 0.9
	_gard_bucata(z_gard_curte, x, curte_x.y)


func _gard_bucata(z: float, a: float, b: float) -> void:
	var x := a
	while x < b - 0.1:
		var bucata := _pune(GARD, Vector3(x, 0.0, z), 0.0)
		bucata.scale.x = minf(2.4, b - x) / 2.4
		x += 2.4
	var corp := StaticBody3D.new()
	add_child(corp)
	var forma := CollisionShape3D.new()
	var cutie := BoxShape3D.new()
	cutie.size = Vector3(b - a, 1.5, 0.12)
	forma.shape = cutie
	corp.add_child(forma)
	forma.position = Vector3((a + b) * 0.5, 0.75, z)


func _pune(scena: PackedScene, pozitie: Vector3, unghi: float, sticla := "", coliziune := 0) -> Node3D:
	var nod := scena.instantiate() as Node3D
	nod.set_script(SCRIPT_MODEL)
	nod.set("material", MATERIAL)
	nod.set("sticla", sticla)
	nod.set("coliziune", coliziune)
	nod.position = pozitie
	nod.rotation.y = unghi
	add_child(nod)
	nod.position = pozitie
	nod.rotation.y = unghi
	return nod


## Un șir de bucăți de gard pe z, de la `a` la `b`, cu un gol între `gol_a` și `gol_b`. Coliziune: o cutie subțire.
func _gard(z: float, a: float, b: float, gol_a: float, gol_b: float, inalt: bool) -> void:
	for capete: Vector2 in [Vector2(a, gol_a), Vector2(gol_b, b)]:
		var x := capete.x
		while x < capete.y - 0.1:
			var bucata := _pune(GARD, Vector3(x, 0.0, z), 0.0)
			var lung := minf(2.4, capete.y - x)
			bucata.scale.x = lung / 2.4
			x += 2.4
		var corp := StaticBody3D.new()
		add_child(corp)
		var forma := CollisionShape3D.new()
		var cutie := BoxShape3D.new()
		cutie.size = Vector3(capete.y - capete.x, 1.6 if inalt else 1.5, 0.12)
		forma.shape = cutie
		corp.add_child(forma)
		forma.position = Vector3((capete.x + capete.y) * 0.5, cutie.size.y * 0.5, z)


const LUMANARE := preload("res://models/lumanare.glb")


## În spatele ușii lui Jean (owner 16.11): când se deschide, nu se vede interiorul casei (e casa lui Lexy), ci negru
## și câteva lumânări pe jos. O cutie neagră văzută dinăuntru (doar fețele din spate), fără ceață, cu o lumină mică.
func _intuneric_jean(casa: Node3D) -> void:
	var cutie := MeshInstance3D.new()
	cutie.name = "IntunericUsa"
	var forma := BoxMesh.new()
	forma.size = Vector3(1.5, 2.38, 1.3)
	cutie.mesh = forma
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.018, 0.014, 0.014)
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.disable_fog = true
	cutie.material_override = mat
	cutie.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	casa.add_child(cutie)
	# fundul cutiei la 1 cm deasupra podelei casei (0,45): la aceeași înălțime se băteau texturile una prin alta
	cutie.position = Vector3(0.0, BALAMA.y + 0.01 + 1.19, BALAMA.z - 0.08 - 0.65)
	for loc in [Vector3(-0.42, 0.0, -1.18), Vector3(0.36, 0.0, -1.1), Vector3(0.08, 0.0, -1.32), Vector3(-0.15, 0.0, -0.95)]:
		var l := LUMANARE.instantiate() as Node3D
		l.set_script(SCRIPT_MODEL)
		l.set("material", MATERIAL)
		l.set("stralucitoare", PackedStringArray(["Flacara"]))
		l.set("stralucire", 2.4)
		casa.add_child(l)
		l.position = Vector3(loc.x, BALAMA.y + 0.01, loc.z)
		l.scale = Vector3.ONE * (0.8 + absf(loc.x) * 0.6)
	var lumina := OmniLight3D.new()
	lumina.light_color = Color(1.0, 0.6, 0.3)
	lumina.light_energy = 0.7
	lumina.omni_range = 1.8
	lumina.set_script(preload("res://scripts/flacara.gd"))
	lumina.set("energie", 0.7)
	casa.add_child(lumina)
	lumina.position = Vector3(0.0, BALAMA.y + 0.5, -1.05)
