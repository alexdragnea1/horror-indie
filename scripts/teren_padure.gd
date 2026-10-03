class_name TerenPadure
extends StaticBody3D
## Terenul pădurii Trivale, făcut din cod când pornește scena: un deal (în dreapta, cu platoul
## în vârf), o vale (în stânga, unde e zona care devine tot mai creepy), poteca de la șosea până
## la bifurcație și cele două ramuri. Poteca și platoul sunt netezite; restul are mici denivelări.
## Culorile terenului sunt în vârfuri (din paletă): pământ și frunze în pădure, iarbă pe platou,
## pământ bătătorit pe potecă, aproape negru în vale.
## Alte scripturi întreabă: inaltime(x, z), distanta_poteca(x, z), platou(x, z), creepy(x, z).
##
## Coordonate: șoseaua e pe X la z = 0, pădurea spre -Z.

## Cât de mare e terenul (metri) și unde e colțul lui de jos (cel mai apropiat de șosea).
@export var de_la := Vector2(-90, -170)
@export var pana_la := Vector2(90, 12)
## Distanța dintre vârfurile rețelei (metri). Mai mic = mai fin, dar mai greu.
@export var pas := 1.5

@export_group("Relief")
## Dealul cu platoul: centrul, înălțimea, cât de lat e.
@export var centru_platou := Vector2(30, -95)
@export var inaltime_deal := 22.0
@export var raza_deal := 32.0
@export var raza_platou := 16.0
## Valea din stânga: centrul (capătul potecii), adâncimea, lățimea.
@export var centru_vale := Vector2(-42, -108)
@export var adancime_vale := 12.0
@export var raza_vale := 26.0
## Cât urcă terenul spre nord, în general (metri la metru).
@export var panta := 0.06
## Denivelările mici din pădure (metri).
@export var denivelari := 1.2

@export_group("Poteci")
@export var latime_poteca := 2.6
## Poteca de la șosea până la bifurcație (prin barieră).
@export var poteca_principala := PackedVector2Array([Vector2(3, -4), Vector2(3, -14), Vector2(1.5, -28), Vector2(0, -45)])
## Ramura din dreapta, urcă spre platou.
@export var poteca_dreapta := PackedVector2Array([Vector2(0, -45), Vector2(8, -55), Vector2(19, -67), Vector2(26, -80), Vector2(30, -92)])
## Ramura din stânga, coboară în vale.
@export var poteca_stanga := PackedVector2Array([Vector2(0, -45), Vector2(-9, -56), Vector2(-20, -66), Vector2(-30, -79), Vector2(-37, -93), Vector2(-42, -106)])

var _zgomot := FastNoiseLite.new()
var _zgomot_culoare := FastNoiseLite.new()


func _ready() -> void:
	_zgomot.seed = 13
	_zgomot.frequency = 0.045
	_zgomot_culoare.seed = 7
	_zgomot_culoare.frequency = 0.09
	_construieste()


# ---------------------------------------------------------------- relieful

## Forma mare, fără denivelări (pe ea se așază poteca).
func _baza(x: float, z: float) -> float:
	var h := inaltime_deal * exp(-(pow(x - centru_platou.x, 2) + pow(z - centru_platou.y, 2)) / (2.0 * raza_deal * raza_deal))
	h -= adancime_vale * exp(-(pow(x - centru_vale.x, 2) + pow(z - centru_vale.y, 2)) / (2.0 * raza_vale * raza_vale))
	h += panta * clampf(-z - 8.0, 0.0, 60.0)
	# lângă șosea totul coboară lin la 0
	return h * smoothstep(-5.0, -13.0, z)


func inaltime(x: float, z: float) -> float:
	var h := _baza(x, z) + _zgomot.get_noise_2d(x, z) * denivelari * smoothstep(-5.0, -13.0, z)
	# platoul: neted, la înălțimea vârfului
	var d_platou := Vector2(x, z).distance_to(centru_platou)
	h = lerpf(h, _baza(centru_platou.x, centru_platou.y) + _zgomot.get_noise_2d(x, z) * 0.25,
		1.0 - smoothstep(raza_platou, raza_platou + 8.0, d_platou))
	# fundul văii: o poiană mică, plată
	var d_vale := Vector2(x, z).distance_to(centru_vale)
	h = lerpf(h, _baza(centru_vale.x, centru_vale.y), 1.0 - smoothstep(7.0, 12.0, d_vale))
	# poteca: netedă pe lățimea ei și se topește în teren pe margini
	var p := _cel_mai_apropiat(Vector2(x, z))
	var w := 1.0 - smoothstep(latime_poteca * 0.5, latime_poteca * 0.5 + 3.0, p.z)
	return lerpf(h, _baza(p.x, p.y), w)


## Cât de departe e punctul de cea mai apropiată potecă (metri).
func distanta_poteca(x: float, z: float) -> float:
	return _cel_mai_apropiat(Vector2(x, z)).z


## 1 pe platou, 0 departe de el.
func platou(x: float, z: float) -> float:
	return 1.0 - smoothstep(raza_platou - 2.0, raza_platou + 14.0, Vector2(x, z).distance_to(centru_platou))


## 0 la bifurcație și în restul pădurii, 1 în fundul văii: cât de „rău” e locul.
func creepy(x: float, z: float) -> float:
	if x > 2.0:
		return 0.0
	return 1.0 - smoothstep(8.0, 62.0, Vector2(x, z).distance_to(centru_vale))


## (x, z, distanța) pentru cel mai apropiat punct de pe oricare potecă.
func _cel_mai_apropiat(q: Vector2) -> Vector3:
	var cel_mai_bun := Vector3(0, 0, INF)
	for drum in [poteca_principala, poteca_dreapta, poteca_stanga]:
		var puncte: PackedVector2Array = drum
		for i in puncte.size() - 1:
			var p := Geometry2D.get_closest_point_to_segment(q, puncte[i], puncte[i + 1])
			var d := p.distance_to(q)
			if d < cel_mai_bun.z:
				cel_mai_bun = Vector3(p.x, p.y, d)
	return cel_mai_bun


## Un punct de pe o potecă, la fracția f din lungimea ei (0 = început, 1 = capăt).
func punct_pe_poteca(drum: PackedVector2Array, f: float) -> Vector2:
	var total := 0.0
	for i in drum.size() - 1:
		total += drum[i].distance_to(drum[i + 1])
	var ramas := clampf(f, 0.0, 1.0) * total
	for i in drum.size() - 1:
		var l := drum[i].distance_to(drum[i + 1])
		if ramas <= l:
			return drum[i].lerp(drum[i + 1], ramas / l)
		ramas -= l
	return drum[drum.size() - 1]


# ---------------------------------------------------------------- mesh-ul și coliziunea

func _culoare(x: float, z: float, h: float) -> Color:
	var n := _zgomot_culoare.get_noise_2d(x, z)
	var n2 := _zgomot_culoare.get_noise_2d(x * 2.7 + 100.0, z * 2.7)
	# pădurea: pământ închis, pete de frunze ruginii și mușchi
	var c := Color("553e4d") if n > 0.0 else Color("48313b")
	if n2 > 0.35:
		c = Color("904a40")
	elif n2 < -0.45:
		c = Color("445d46")
	# platoul: iarbă uscată
	var pl := platou(x, z)
	if pl > 0.35:
		c = Color("5b6d4e") if n > -0.2 else Color("7a7b59")
	# valea: tot mai închis, aproape negru, cu pete vineții
	var cr := creepy(x, z)
	if cr > 0.75:
		c = Color("262d2f") if n > -0.3 else Color("2a3c3d")
	elif cr > 0.45:
		c = Color("48313b") if n > 0.1 else Color("262d2f")
	# poteca: pământ bătătorit și pietriș
	var dp := distanta_poteca(x, z)
	if dp < latime_poteca * 0.5 + 0.3:
		c = Color("7e8d87") if n2 > -0.1 else Color("70706e")  # mai deschisă decât pădurea: se vede noaptea
		if cr > 0.6:
			c = Color("48313b")
	elif dp < latime_poteca * 0.5 + 1.0 and n2 > 0.0:
		c = Color("553e4d")
	# lângă șosea: pietriș
	if z > -7.0:
		c = Color("70706e") if n > 0.0 else Color("5e5356")
	return c


func _construieste() -> void:
	var nx := int((pana_la.x - de_la.x) / pas) + 1
	var nz := int((pana_la.y - de_la.y) / pas) + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inaltimi := PackedFloat32Array()
	inaltimi.resize(nx * nz)
	for j in nz:
		for i in nx:
			var x := de_la.x + i * pas
			var z := de_la.y + j * pas
			inaltimi[j * nx + i] = inaltime(x, z)
	for j in nz:
		for i in nx:
			var x := de_la.x + i * pas
			var z := de_la.y + j * pas
			var h := inaltimi[j * nx + i]
			st.set_color(_culoare(x, z, h))
			st.set_uv(Vector2(x, z))
			st.add_vertex(Vector3(x, h, z))
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			var b := a + 1
			var c := a + nx
			var d := c + 1
			# fața în sus (sensul acelor de ceas văzut de sus, cum vrea Godot)
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.material_override = _material()
	add_child(mi)
	var forma := CollisionShape3D.new()
	forma.shape = mesh.create_trimesh_shape()
	add_child(forma)


func _material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/ps2.gdshader")
	var zgomot := FastNoiseLite.new()
	zgomot.frequency = 0.12
	var tex := NoiseTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.seamless = true
	tex.noise = zgomot
	var rampa := Gradient.new()
	rampa.colors = PackedColorArray([Color(0.62, 0.62, 0.62), Color(1, 1, 1)])
	tex.color_ramp = rampa
	m.set_shader_parameter("textura", tex)
	m.set_shader_parameter("culoare", Color.WHITE)
	m.set_shader_parameter("uv_din_lume", true)
	m.set_shader_parameter("repetare_uv", Vector2(0.45, 0.45))
	return m
