class_name DealConac
extends StaticBody3D
## Dealul cu sediul coven-ului (conac.tscn), făcut din cod: platoul din vârf e plat (y = 0, `raza_platou`),
## coastele coboară rotunjit până la `adancime` sub el (la `raza_deal`), iar mai departe se ridică dealuri joase,
## ca orizontul să nu fie gol. Poteca (`poteca`) coboară de la poartă, șerpuind. Culorile (din paletă) sunt în
## vârfuri: iarbă închisă pe platou, coaste pătate, poteca deschisă la culoare. Coliziunea e doar în jurul platoului
## (gardul nu te lasă mai departe).

@export var raza_platou := 36.0
@export var raza_deal := 125.0
@export var adancime := 26.0
## Cât de mare e terenul (metri, pătrat, centrat în origine) și distanța dintre vârfuri.
@export var marime := 460.0
@export var pas := 2.5
## Poteca de la poartă la vale (puncte X, Z), cu lățimea ei.
@export var poteca := PackedVector2Array([Vector2(0, 31), Vector2(3, 42), Vector2(-4, 55), Vector2(2, 70),
	Vector2(13, 88), Vector2(9, 110), Vector2(-2, 135), Vector2(-6, 170)])
@export var latime_poteca := 3.4

var _zgomot := FastNoiseLite.new()
var _zgomot_mare := FastNoiseLite.new()


func _ready() -> void:
	_zgomot.seed = 7
	_zgomot.frequency = 0.045
	_zgomot_mare.seed = 19
	_zgomot_mare.frequency = 0.008
	_construieste()


## Înălțimea terenului în (x, z).
func inaltime(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	if r <= raza_platou:
		return 0.0
	var t := clampf((r - raza_platou) / (raza_deal - raza_platou), 0.0, 1.0)
	# vârful rotunjit: la început coboară încet, apoi abrupt, iar jos se îndulcește
	var h := -adancime * (1.0 - cos(pow(t, 0.85) * PI)) * 0.5
	h += _zgomot.get_noise_2d(x, z) * 2.2 * minf(t * 3.0, 1.0)
	# dealurile din depărtare
	var departe := maxf(r - raza_deal - 45.0, 0.0)
	h += minf(departe * 0.22, 22.0) * (0.55 + 0.45 * _zgomot_mare.get_noise_2d(x, z))
	return h


func distanta_poteca(x: float, z: float) -> float:
	var q := Vector2(x, z)
	var cel_mai_mic := INF
	for i in poteca.size() - 1:
		var a := poteca[i]
		var b := poteca[i + 1]
		var ab := b - a
		var t := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		cel_mai_mic = minf(cel_mai_mic, q.distance_to(a + ab * t))
	return cel_mai_mic


func _culoare(x: float, z: float, h: float) -> Color:
	var r := Vector2(x, z).length()
	var n := _zgomot.get_noise_2d(x * 2.3, z * 2.3)
	if r > raza_platou + 2.0 and distanta_poteca(x, z) < latime_poteca * 0.5:
		return Color("7e8d87") if n > -0.1 else Color("70706e")
	if r <= raza_platou + 1.0:
		return Color("32453b") if n > -0.35 else Color("445d46")
	if h < -adancime * 0.85 or r > raza_deal + 40.0:
		return Color("2a3c3d") if n > 0.0 else Color("32453b")
	if n > 0.35:
		return Color("5b6d4e")
	return Color("445d46") if n > -0.25 else Color("32453b")


func _construieste() -> void:
	var n := int(marime / pas) + 1
	var start := -marime * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n:
		for i in n:
			var x := start + i * pas
			var z := start + j * pas
			var h := inaltime(x, z)
			st.set_color(_culoare(x, z, h))
			st.set_uv(Vector2(x, z))
			st.add_vertex(Vector3(x, h, z))
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d := c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = st.commit()
	mi.material_override = _material()
	add_child(mi)
	# coliziunea: doar platoul și începutul coastelor (o rețea mai mică, cu aceeași formă)
	var raza := raza_platou + 12.0
	var fete := PackedVector3Array()
	var m := int(raza * 2.0 / pas) + 1
	for j in m - 1:
		for i in m - 1:
			var x0 := -raza + i * pas
			var z0 := -raza + j * pas
			var p00 := Vector3(x0, inaltime(x0, z0), z0)
			var p10 := Vector3(x0 + pas, inaltime(x0 + pas, z0), z0)
			var p01 := Vector3(x0, inaltime(x0, z0 + pas), z0 + pas)
			var p11 := Vector3(x0 + pas, inaltime(x0 + pas, z0 + pas), z0 + pas)
			fete.append_array([p00, p10, p01, p10, p11, p01])
	var forma := ConcavePolygonShape3D.new()
	forma.set_faces(fete)
	var coliziune := CollisionShape3D.new()
	coliziune.shape = forma
	add_child(coliziune)


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
