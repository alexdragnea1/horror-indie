class_name CampuriSat
extends Node3D
## Lanurile din jurul satului primăriei (primarie.tscn, owner 17.11: „lanuri de porumb sau de floarea-soarelui să nu
## fie total gol”): fiecare dreptunghi din `lanuri` (x/z, în coordonatele lumii) se umple cu rânduri de `tipuri[i]`
## („porumb” / „floare”), modelele din tools/blender/sat_campuri.py. Rândurile merg pe X, plantele sunt puțin mișcate,
## rotite, mai mari / mai mici, din loc în loc lipsește una. Florile-soarelui se uită toate spre `spre` (satul), ca să
## le vezi fața. Totul e MultiMesh, pe bucăți de `BUCATA` m care nu se mai desenează dincolo de `vizibil_pana_la` (în
## ceața de acolo oricum nu se mai văd). Fără coliziune: sunt dincolo de zidurile invizibile.

const MODELE := {
	"porumb": preload("res://models/porumb.glb"),
	"floare": preload("res://models/floarea_soarelui.glb"),
}
const MATERIAL := preload("res://shaders/material_model.tres")
## Distanța dintre rânduri și dintre plante pe rând (m).
const RANDURI := {"porumb": 1.0, "floare": 0.9}
const PE_RAND := {"porumb": 0.55, "floare": 0.6}
const BUCATA := 20.0

@export var lanuri: Array[Rect2] = []
@export var tipuri: PackedStringArray = []
## Spre ce punct (x, z) își întorc florile capul.
@export var spre := Vector2(0.0, 0.0)
@export var vizibil_pana_la := 140.0
@export var saminta := 3


func _ready() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = saminta
	var bucati := {}  # [tip, Vector2i] -> Array[Transform3D] (în coordonatele lumii)
	for i in lanuri.size():
		var lan := lanuri[i]
		var tip := tipuri[i] if i < tipuri.size() else "porumb"
		var z := lan.position.y + 0.5
		while z < lan.end.y:
			var x := lan.position.x + r.randf_range(0.0, 0.3)
			while x < lan.end.x:
				var px := x + r.randf_range(-0.1, 0.1)
				var pz := z + r.randf_range(-0.12, 0.12)
				x += PE_RAND[tip] * r.randf_range(0.85, 1.15)
				if r.randf() < 0.05:
					continue  # un gol în rând
				var unghi := r.randf_range(0.0, TAU)
				if tip == "floare":
					unghi = atan2(spre.x - px, spre.y - pz) + r.randf_range(-0.35, 0.35)
				var marime := r.randf_range(0.85, 1.15)
				var baza := Basis(Vector3.UP, unghi) * Basis(Vector3.RIGHT, r.randf_range(-0.06, 0.06)) \
					* Basis(Vector3.FORWARD, r.randf_range(-0.06, 0.06))
				baza = baza.scaled(Vector3(marime, marime * r.randf_range(0.9, 1.12), marime))
				var cheie := [tip, Vector2i(floori(px / BUCATA), floori(pz / BUCATA))]
				if not bucati.has(cheie):
					bucati[cheie] = []
				bucati[cheie].append(Transform3D(baza, Vector3(px, 0.0, pz)))
			z += RANDURI[tip]
	var plase := {}
	for tip: String in MODELE:
		plase[tip] = _plasa(MODELE[tip])
	for cheie: Array in bucati:
		var transformari: Array = bucati[cheie]
		var centru := Vector3((cheie[1].x + 0.5) * BUCATA, 0.0, (cheie[1].y + 0.5) * BUCATA)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = plase[cheie[0]]
		mm.instance_count = transformari.size()
		for k in transformari.size():
			var t: Transform3D = transformari[k]
			t.origin -= centru
			mm.set_instance_transform(k, t)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Lan_%s_%d_%d" % [cheie[0], cheie[1].x, cheie[1].y]
		mmi.multimesh = mm
		mmi.material_override = MATERIAL
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = vizibil_pana_la
		mmi.visibility_range_end_margin = 10.0
		add_child(mmi)
		mmi.global_position = centru


## Plasa din modelul .glb (un singur obiect lipit în Blender).
func _plasa(scena: PackedScene) -> Mesh:
	var nod := scena.instantiate()
	var mi := nod.find_children("*", "MeshInstance3D", true, false)
	var plasa: Mesh = (mi[0] as MeshInstance3D).mesh if not mi.is_empty() else null
	nod.free()
	return plasa
