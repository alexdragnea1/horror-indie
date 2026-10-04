extends StaticBody3D
## Zidul invizibil din pădure: poți ieși de pe potecă și intra printre copaci, dar nu departe.
## Locul în care poți umbla e reunirea a patru zone:
##   - o fâșie de `departe_de_poteca` metri de o parte și de alta a fiecărei poteci,
##   - platoul (cerc de `raza_platou` în jurul lui TerenPadure.centru_platou),
##   - poiana din fundul văii (cerc de `raza_vale` în jurul lui centru_vale),
##   - `zona_start` (șoseaua cu stația și bariera).
## Marginea zonei e găsită pe o rețea (marching squares) și ridicată ca perete vertical,
## un singur ConcavePolygonShape3D. Copacii cresc și dincolo de zid, deci pădurea pare că nu se termină.

@export var teren: TerenPadure
## Cât de departe de mijlocul potecii poți merge (metri; poteca are 2,6 m lățime).
@export var departe_de_poteca := 9.0
@export var raza_platou := 24.0
@export var raza_vale := 15.0
## Dreptunghiul de lângă șosea (x, z, lățime, adâncime).
@export var zona_start := Rect2(-20, -16, 40, 22)
## Pasul rețelei (metri): mai mic = zid mai neted, dar mai multe triunghiuri.
@export var pas := 1.0
## Arată zidul (roșu, semi-transparent), ca să vezi pe unde trece. Doar pentru teste.
@export var arata := false

const SUB_TEREN := 3.0
const DEASUPRA := 8.0


func _ready() -> void:
	var fete := PackedVector3Array()
	var x0 := teren.de_la.x
	var z0 := teren.de_la.y
	var nx := int((teren.pana_la.x - x0) / pas) + 1
	var nz := int((teren.pana_la.y - z0) / pas) + 1
	# valorile în colțurile rețelei: < 0 = poți umbla, > 0 = nu
	var v := PackedFloat32Array()
	v.resize(nx * nz)
	for j in nz:
		for i in nx:
			v[j * nx + i] = valoare(x0 + i * pas, z0 + j * pas)
	for j in nz - 1:
		for i in nx - 1:
			var colturi := [Vector2(x0 + i * pas, z0 + j * pas), Vector2(x0 + (i + 1) * pas, z0 + j * pas),
				Vector2(x0 + (i + 1) * pas, z0 + (j + 1) * pas), Vector2(x0 + i * pas, z0 + (j + 1) * pas)]
			var val := [v[j * nx + i], v[j * nx + i + 1], v[(j + 1) * nx + i + 1], v[(j + 1) * nx + i]]
			# unde trece marginea pe fiecare latură a celulei (interpolat, ca zidul să fie neted)
			var taieturi: Array[Vector2] = []
			for k in 4:
				var a: float = val[k]
				var b: float = val[(k + 1) % 4]
				if (a < 0.0) != (b < 0.0):
					taieturi.append((colturi[k] as Vector2).lerp(colturi[(k + 1) % 4], a / (a - b)))
			# 2 tăieturi = un segment; 4 = celulă în șa, două segmente
			for k in range(0, taieturi.size() - 1, 2):
				_perete(fete, taieturi[k], taieturi[k + 1])
	var forma := ConcavePolygonShape3D.new()
	forma.backface_collision = true
	forma.set_faces(fete)
	var nod := CollisionShape3D.new()
	nod.shape = forma
	add_child(nod)
	if arata:
		_arata_zidul(fete)


## Negativ înăuntru (unde poți umbla), pozitiv afară; 0 pe zid.
func valoare(x: float, z: float) -> float:
	var q := Vector2(x, z)
	var d := teren.distanta_poteca(x, z) - departe_de_poteca
	d = minf(d, q.distance_to(teren.centru_platou) - raza_platou)
	d = minf(d, q.distance_to(teren.centru_vale) - raza_vale)
	# distanța (cu semn) până la marginea dreptunghiului
	var centru := zona_start.get_center()
	var jumatate := zona_start.size * 0.5
	var dx := absf(x - centru.x) - jumatate.x
	var dz := absf(z - centru.y) - jumatate.y
	var dr := Vector2(maxf(dx, 0.0), maxf(dz, 0.0)).length() + minf(maxf(dx, dz), 0.0)
	return minf(d, dr)


func poate_umbla(x: float, z: float) -> bool:
	return valoare(x, z) < 0.0


func _perete(fete: PackedVector3Array, a: Vector2, b: Vector2) -> void:
	var ha := teren.inaltime(a.x, a.y)
	var hb := teren.inaltime(b.x, b.y)
	var a_jos := Vector3(a.x, ha - SUB_TEREN, a.y)
	var a_sus := Vector3(a.x, ha + DEASUPRA, a.y)
	var b_jos := Vector3(b.x, hb - SUB_TEREN, b.y)
	var b_sus := Vector3(b.x, hb + DEASUPRA, b.y)
	fete.append_array([a_jos, b_jos, b_sus, a_jos, b_sus, a_sus])


func _arata_zidul(fete: PackedVector3Array) -> void:
	var mesh := ArrayMesh.new()
	var date := []
	date.resize(Mesh.ARRAY_MAX)
	date[Mesh.ARRAY_VERTEX] = fete
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, date)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1, 0, 0, 0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	add_child(mi)
