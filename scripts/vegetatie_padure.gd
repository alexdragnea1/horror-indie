extends Node3D
## Copacii pădurii Trivale, puși din cod pe terenul generat (TerenPadure), ca să fie mulți și ieftini:
## fiecare fel de copac e un singur MultiMesh, iar trunchiurile au coliziune (cilindri).
## Pe potecă, pe platou și lângă șosea nu crește nimic. Cu cât e locul mai „creepy” (valea din stânga),
## cu atât copacii sunt mai morți: întâi se amestecă copaci goi, apoi rămân doar cei morți.
## Tot de aici se pun și pietrele și buștenii de pe marginea potecii, și „semnele” de pe ramura din stânga.

@export var teren: TerenPadure
## Câți metri între copaci (în medie); mai mic = pădure mai deasă.
@export var distanta_copaci := 3.3
## Cât de deasă e pădurea (0..1), în afara potecilor și a platoului.
@export var densitate := 0.62
## Copacii vii (brazi și foioase de toamnă) și cei morți (pentru vale).
@export var copaci_vii: Array[PackedScene] = []
@export var copaci_goi: Array[PackedScene] = []
@export var copaci_morti: Array[PackedScene] = []
@export var pietre: Array[PackedScene] = []
@export var bustean: PackedScene
@export var saminta := 21
## Unde nu crește nimic (x, z, lățime, adâncime): stația, bariera, panoul verde (altfel un brad îl acoperă).
@export var zone_libere: Array[Rect2] = []

const MATERIAL := preload("res://shaders/material_model.tres")

var _rng := RandomNumberGenerator.new()
## scena -> lista de Transform3D
var _instante: Dictionary = {}
var _corp: StaticBody3D


func _ready() -> void:
	_rng.seed = saminta
	_corp = StaticBody3D.new()
	_corp.name = "Trunchiuri"
	add_child(_corp)
	_padure()
	_margini_poteca()
	_construieste_multimesh()


func _padure() -> void:
	var de_la := teren.de_la + Vector2(2, 2)
	var pana_la := Vector2(teren.pana_la.x - 2, -9.0)
	var z := de_la.y
	while z < pana_la.y:
		var x := de_la.x
		while x < pana_la.x:
			var px := x + _rng.randf_range(-0.45, 0.45) * distanta_copaci
			var pz := z + _rng.randf_range(-0.45, 0.45) * distanta_copaci
			x += distanta_copaci
			if _rng.randf() > densitate:
				continue
			if teren.distanta_poteca(px, pz) < teren.latime_poteca * 0.5 + 1.6:
				continue
			if teren.platou(px, pz) > 0.25:
				continue
			if zone_libere.any(func(r: Rect2) -> bool: return r.has_point(Vector2(px, pz))):
				continue
			var cr := teren.creepy(px, pz)
			var scena: PackedScene
			var r := _rng.randf()
			if cr > 0.62 or (cr > 0.3 and r < cr):
				scena = copaci_morti.pick_random() if r < 0.75 else copaci_goi.pick_random()
			elif r < 0.12:
				scena = copaci_goi.pick_random()
			else:
				scena = copaci_vii.pick_random()
			_copac(scena, px, pz, _rng.randf_range(0.8, 1.3))
		z += distanta_copaci


func _copac(scena: PackedScene, x: float, z: float, marime: float) -> void:
	var y := teren.inaltime(x, z) - 0.15
	var baza := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * marime)
	# copacii morți stau puțin strâmbi
	if scena in copaci_morti:
		baza = Basis(Vector3(1, 0, 0), _rng.randf_range(-0.08, 0.08)) * baza
	_adauga(scena, Transform3D(baza, Vector3(x, y, z)))
	var forma := CollisionShape3D.new()
	var cilindru := CylinderShape3D.new()
	cilindru.radius = 0.3 * marime
	cilindru.height = 4.0
	forma.shape = cilindru
	forma.position = Vector3(x, y + 2.0, z)
	_corp.add_child(forma)


func _adauga(scena: PackedScene, t: Transform3D) -> void:
	if not _instante.has(scena):
		_instante[scena] = []
	_instante[scena].append(t)


## Pietre și bușteni pe marginea potecilor, ca să nu fie o fâșie goală.
func _margini_poteca() -> void:
	for drum in [teren.poteca_principala, teren.poteca_dreapta, teren.poteca_stanga]:
		var puncte: PackedVector2Array = drum
		for k in 14:
			var f := _rng.randf()
			var p := teren.punct_pe_poteca(puncte, f)
			if p.y > -16.0:
				continue
			var lat := (teren.latime_poteca * 0.5 + _rng.randf_range(0.9, 2.2)) * (1.0 if _rng.randf() < 0.5 else -1.0)
			# perpendiculara pe potecă, aproximată din doi vecini
			var inainte := (teren.punct_pe_poteca(puncte, minf(f + 0.02, 1.0)) - teren.punct_pe_poteca(puncte, maxf(f - 0.02, 0.0))).normalized()
			var q := p + Vector2(-inainte.y, inainte.x) * lat
			if teren.distanta_poteca(q.x, q.y) < teren.latime_poteca * 0.5 + 0.6 or teren.platou(q.x, q.y) > 0.3:
				continue
			var y := teren.inaltime(q.x, q.y) - 0.1
			if _rng.randf() < 0.75 or bustean == null:
				var baza := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * _rng.randf_range(0.6, 1.2))
				var t := Transform3D(baza, Vector3(q.x, y, q.y))
				var scena: PackedScene = pietre.pick_random()
				_adauga(scena, t)
				ColiziuneModel.adauga(_corp, scena, t, true)
			else:
				var unghi := atan2(inainte.x, inainte.y) + _rng.randf_range(-0.3, 0.3)
				var t := Transform3D(Basis(Vector3.UP, unghi), Vector3(q.x, y, q.y))
				_adauga(bustean, t)
				ColiziuneModel.adauga(_corp, bustean, t, false)


func _construieste_multimesh() -> void:
	for scena in _instante:
		var lista: Array = _instante[scena]
		var model := (scena as PackedScene).instantiate()
		for nod in model.find_children("*", "MeshInstance3D", true, false):
			var mi := nod as MeshInstance3D
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mi.mesh
			mm.instance_count = lista.size()
			for i in lista.size():
				mm.set_instance_transform(i, lista[i] * _transform_in_model(mi, model))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = MATERIAL
			add_child(mmi)
		model.free()


## Unde stă bucata de mesh în model (un .glb poate avea mai multe obiecte, fiecare cu originea lui).
func _transform_in_model(nod: Node3D, radacina: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = nod
	while n != radacina and n is Node3D:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
