class_name PeisajDeparte
extends Node3D
## Ce se vede în jurul blocului M7, departe (owner 10.11: „să nu mai fie așa de gol în jur”): un inel de teren făcut
## din cod în jurul nodului (care stă în mijlocul curții), plat aproape (sub iarba din scenă, se pierde în ceață) și
## tot mai deluros spre orizont: dealuri line, în spatele lor o culme mai înaltă, și un munte cu zăpadă pe vârf
## (`munte`). Pe un deal stă un turn de antenă cu lumini roșii care clipesc. Nu se poate ajunge acolo (`Limite`).
## Culorile le ia din ce a făcut scena (noapte, zi, apus, seara: ZiBloc / ApusBloc / SearaBloc le schimbă în _ready):
## ceața, cerul și lumina (`lumina`, Luna din scenă). Când lumina e jos (apusul), dealurile se lasă într-o șa exact
## în dreptul ei, ca soarele să apună la vedere, nu în spatele unui deal. Ascunde și dunga de cer albastru care se
## vedea la orizont dincolo de capătul ierbii.
## Shaderul: shaders/peisaj_departe.gdshader (fără ceața scenei; ceața lui e făcută de mână).

@export var mediu: WorldEnvironment
@export var lumina: DirectionalLight3D
@export var saminta := 7
## De unde până unde merge terenul (m, de la nod).
@export var raza_interioara := 55.0
@export var raza_exterioara := 1700.0
## Cât de des e plasa: bucăți pe cerc și inele (fațete mari, PS2).
@export var segmente := 300
@export var inele := 54
## Muntele: pe ce direcție (grade, de la +X spre +Z), cât de departe, cât de înalt și cât de lat.
@export var munte_unghi := 128.0
@export var munte_distanta := 1150.0
@export var munte_inaltime := 330.0
@export var munte_latime := 230.0
## Turnul de antenă: direcția (grade), distanța și înălțimea lui.
@export var turn_unghi := 55.0
@export var turn_distanta := 420.0
@export var turn_inaltime := 48.0
## Cât de pierdut în ceață e turnul și becurile lui (0 = clar, 1 = deloc; owner 10.11: „mai în fog, aceeași culoare
## ca environmentul”). Becurile puțin mai puțin, ca roșul să se ghicească.
@export_range(0.0, 1.0) var turn_ceata := 0.78
@export_range(0.0, 1.0) var becuri_ceata := 0.5

const SHADER := preload("res://shaders/peisaj_departe.gdshader")
## Ceața scenei (fog_light_color, „r,g,b”) -> [culoarea ierbii pierdute în ceață, culoarea cerului de deasupra
## dealurilor], ca uniform: măsurate pe ecran (Claude, 10.11: un teren roșu ca să găsești unde e, apoi culoarea
## ajustată până iese ca pixelii scenei). Dacă schimbi ceața dintr-un moment, refă măsurătoarea; altfel se folosește
## direct culoarea ceții (se vede o dungă mai rece la orizont).
const PALETE := {
	"0.20,0.22,0.26": [Color(0.252, 0.204, 0.193), Color(0.277, 0.207, 0.191)],  # noaptea (și meniul principal)
	"0.64,0.66,0.69": [Color(0.514, 0.535, 0.537), Color(0.520, 0.534, 0.555)],  # ziua (ZiBloc)
	"0.66,0.44,0.46": [Color(0.494, 0.292, 0.283), Color(0.637, 0.378, 0.470)],  # apusul (ApusBloc)
	"0.15,0.22,0.46": [Color(0.187, 0.186, 0.310), Color(0.207, 0.190, 0.365)],  # seara (SearaBloc)
}

var _zgomot := FastNoiseLite.new()
var _culme := FastNoiseLite.new()
var _sa := Vector2.ZERO  # direcția (pe orizontală) în care se lasă dealurile; zero = nicăieri
var _material := ShaderMaterial.new()
var _becuri: Array[MeshInstance3D] = []
var _ceas := 0.0


func _ready() -> void:
	_zgomot.seed = saminta
	_zgomot.frequency = 0.0035
	_zgomot.fractal_octaves = 3
	_culme.seed = saminta + 1
	_culme.noise_type = FastNoiseLite.TYPE_PERLIN
	_culme.frequency = 0.0019
	_culme.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_culme.fractal_octaves = 3
	# ZiBloc / ApusBloc / SearaBloc își schimbă mediul tot în _ready: culorile le iau după ei
	await get_tree().process_frame
	_culori()
	_construieste()
	_padure()
	_turn()


func _process(delta: float) -> void:
	_ceas += delta
	# luminile turnului: clipesc încet, pe rând
	for i in _becuri.size():
		_becuri[i].visible = fmod(_ceas + i * 0.5, 2.4) < 1.1


## Ia culorile din mediul scenei (cum l-au lăsat ZiBloc / ApusBloc / SearaBloc) și din lumină.
func _culori() -> void:
	_material.shader = SHADER
	var env := mediu.environment if mediu else null
	var ceata := Color(0.2, 0.22, 0.26)
	var cer := ceata
	var densitate := 0.03
	if env:
		ceata = env.fog_light_color
		densitate = env.fog_density
		cer = ceata
	var luminos := ceata.get_luminance()
	# ceața volumetrică a scenei (luminată de felinare, de ambient) acoperă și iarba, și cerul, iar dealurile nu o
	# primesc: culorile care ies pe ecran la fel ca ele sunt măsurate pentru fiecare moment (vezi PALETE)
	var cheie := "%.2f,%.2f,%.2f" % [ceata.r, ceata.g, ceata.b]
	if PALETE.has(cheie):
		cer = PALETE[cheie][1]
		ceata = PALETE[cheie][0]
	var directie := Vector3(0.3, 0.7, 0.6)
	var culoare_lumina := Color(0.6, 0.7, 0.95)
	var putere := 0.2
	if lumina:
		directie = lumina.global_basis.z  # lumina vine dinspre +Z-ul ei
		culoare_lumina = lumina.light_color
		putere = clampf(lumina.light_energy * 0.45, 0.06, 0.6)
	var jos := directie.y < 0.2  # soarele la apus
	if jos:
		_sa = Vector2(directie.x, directie.z).normalized()
	# silueta: ceața, mai închisă și puțin spre mov (noaptea aproape neagră, la apus mov închis)
	var baza := cer.darkened(0.55).lerp(Color(0.16, 0.13, 0.24), 0.25)
	_material.set_shader_parameter("culoare_baza", baza)
	_material.set_shader_parameter("culoare_ceata", ceata)
	_material.set_shader_parameter("culoare_cer", cer)
	_material.set_shader_parameter("culoare_lumina", culoare_lumina)
	_material.set_shader_parameter("directie_lumina", directie)
	# noaptea luna (albastră) ar vopsi dealurile: abia le atinge; zăpada doar se ghicește
	_material.set_shader_parameter("putere_lumina", putere * (0.35 if luminos < 0.3 else 1.0))
	_material.set_shader_parameter("lumina_zapada", clampf(luminos * 1.4, 0.22, 1.0) if not jos else 1.0)
	_material.set_shader_parameter("densitate_aproape", densitate)
	# ziua ceața e albă și deasă: dealurile abia se ghicesc; noaptea și la apus se văd mai bine
	_material.set_shader_parameter("ceata_max", 0.86 if luminos > 0.5 else (0.62 if jos else 0.7))
	_material.set_shader_parameter("ceata_vale", 0.75 if luminos > 0.5 else 0.6)


## Cât de înalt e terenul în punctul (x, z) (față de nod).
func inaltime(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	# dealurile din față: line, tot mai înalte spre orizont
	var dealuri := (0.55 + 0.45 * _zgomot.get_noise_2d(x, z)) * lerpf(14.0, 75.0, smoothstep(250.0, 1200.0, r))
	dealuri *= smoothstep(raza_interioara + 50.0, 380.0, r)
	# culmea din spate: muchii ascuțite
	var culme := (0.5 + 0.5 * _culme.get_noise_2d(x, z)) * 120.0 * smoothstep(520.0, 1000.0, r)
	var h := dealuri + culme
	# șaua în dreptul soarelui de la apus
	if _sa != Vector2.ZERO:
		var unghi := absf(Vector2(x, z).normalized().angle_to(_sa))
		h *= 1.0 - 0.88 * exp(-pow(unghi / 0.2, 2.0))
	# muntele, cu creste de la zgomot
	var m := Vector2.from_angle(deg_to_rad(munte_unghi)) * munte_distanta
	var dm := Vector2(x, z).distance_to(m)
	var forma := exp(-pow(dm / munte_latime, 2.0))
	var creasta := 0.8 + 0.35 * _culme.get_noise_2d(x * 2.6, z * 2.6)
	h = maxf(h, munte_inaltime * forma * creasta)
	return h - 0.15


func _construieste() -> void:
	var raze := PackedFloat32Array()
	for i in inele + 1:
		# inelele se răresc spre orizont (de aproape se văd fațetele, de departe nu)
		raze.append(raza_interioara * pow(raza_exterioara / raza_interioara, float(i) / inele))
	var puncte: Array[PackedVector3Array] = []
	for i in raze.size():
		var rand := PackedVector3Array()
		for k in segmente:
			var dir := Vector2.from_angle(TAU * k / segmente)
			var p := dir * raze[i]
			rand.append(Vector3(p.x, inaltime(p.x, p.y), p.y))
		puncte.append(rand)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)  # fațete plate
	for i in raze.size() - 1:
		for k in segmente:
			var k2 := (k + 1) % segmente
			var a := puncte[i][k]
			var b := puncte[i][k2]
			var c := puncte[i + 1][k]
			var d := puncte[i + 1][k2]
			# în sens invers acelor de ceas văzut de sus, ca fața să fie în sus
			st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
			st.add_vertex(b); st.add_vertex(c); st.add_vertex(d)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Teren"
	mi.mesh = st.commit()
	mi.material_override = _material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 400.0
	add_child(mi)


## Turnul de antenă de pe deal: un stâlp zăbrelit (din cutii subțiri) cu becuri roșii pe el.
func _turn() -> void:
	var loc := Vector2.from_angle(deg_to_rad(turn_unghi)) * turn_distanta
	var jos := inaltime(loc.x, loc.y) - 1.0
	var turn := Node3D.new()
	turn.name = "Turn"
	add_child(turn)
	turn.position = Vector3(loc.x, jos, loc.y)
	# același shader ca dealurile, dar cu ceață deasă: ia culoarea ceții și a cerului din jur
	var mat_turn := _in_ceata(turn_ceata)
	var mat_bec := _in_ceata(becuri_ceata)
	mat_bec.set_shader_parameter("culoare_baza", Color(1.0, 0.1, 0.06))
	mat_bec.set_shader_parameter("putere_lumina", 0.0)
	mat_bec.set_shader_parameter("lumina_zapada", 0.0)
	for i in 4:
		var lat := lerpf(3.2, 0.6, float(i) / 4.0)
		var bucata := MeshInstance3D.new()
		var cutie := BoxMesh.new()
		cutie.size = Vector3(lat, turn_inaltime / 4.0, lat)
		bucata.mesh = cutie
		bucata.material_override = mat_turn
		bucata.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bucata.position.y = turn_inaltime / 4.0 * (i + 0.5)
		turn.add_child(bucata)
	for y in [turn_inaltime * 0.5, turn_inaltime * 0.78, turn_inaltime + 0.8]:
		var bec := MeshInstance3D.new()
		var sfera := SphereMesh.new()
		sfera.radius = 3.2  # de la 400 m, la rezoluția PS2, un bec mai mic nici nu se vede
		sfera.height = 6.4
		sfera.radial_segments = 6
		sfera.rings = 3
		bec.mesh = sfera
		bec.material_override = mat_bec
		bec.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bec.position.y = y
		turn.add_child(bec)
		_becuri.append(bec)


## Pâlcuri de brazi pe dealuri (un singur MultiMesh de piramide): de aproape dau dealurilor o margine zimțată, de
## departe se pierd în ceața din văi. Nu în șaua soarelui și nu pe munte.
func _padure() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = saminta + 2
	var pete := FastNoiseLite.new()
	pete.seed = saminta + 3
	pete.frequency = 0.006
	var transformari: Array[Transform3D] = []
	var pas := 13.0
	var x := -850.0
	while x < 850.0:
		var z := -850.0
		while z < 850.0:
			var px := x + r.randf_range(-0.45, 0.45) * pas
			var pz := z + r.randf_range(-0.45, 0.45) * pas
			z += pas
			var d := Vector2(px, pz).length()
			if d < 170.0 or d > 820.0 or pete.get_noise_2d(px, pz) < 0.12:
				continue
			# doar pe dealuri (pe șes ar fi un gard de conuri): marginea zimțată de pe culmi
			if inaltime(px, pz) < 7.0:
				continue
			if _sa != Vector2.ZERO and absf(Vector2(px, pz).normalized().angle_to(_sa)) < 0.3:
				continue
			var m := Vector2.from_angle(deg_to_rad(munte_unghi)) * munte_distanta
			if Vector2(px, pz).distance_to(m) < munte_latime * 1.3:
				continue
			var h := r.randf_range(9.0, 17.0) * lerpf(1.0, 1.6, smoothstep(200.0, 800.0, d))
			var lat := h * r.randf_range(0.3, 0.42)
			var baza := Basis(Vector3.UP, r.randf_range(0.0, TAU)).scaled(Vector3(lat, h, lat))
			transformari.append(Transform3D(baza, Vector3(px, inaltime(px, pz) - 0.5, pz)))
		x += pas
	var con := CylinderMesh.new()
	con.top_radius = 0.0
	con.bottom_radius = 1.0
	con.height = 1.0
	con.radial_segments = 5
	con.rings = 1
	con.cap_bottom = false
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = con
	mm.instance_count = transformari.size()
	for i in transformari.size():
		# conul are mijlocul în origine: ridicat pe jumătate, ca să stea pe teren
		var t := transformari[i]
		mm.set_instance_transform(i, t.translated_local(Vector3(0.0, 0.5, 0.0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Padure"
	mmi.multimesh = mm
	mmi.material_override = _copie({"culoare_baza": 0.62, "ceata_vale": 0.12, "putere_lumina": 0.5})
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)



## Materialul dealurilor, dar cu ceața de departe ajunsă (de la câteva sute de metri) la `cat`.
func _in_ceata(cat: float) -> ShaderMaterial:
	var m := _material.duplicate() as ShaderMaterial
	m.set_shader_parameter("ceata_max", cat)
	m.set_shader_parameter("densitate_departe", 0.012)
	return m


## O copie a materialului dealurilor cu câțiva parametri schimbați: numerele sunt înmulțite cu ce era (culoarea
## de bază mai închisă pentru brazi, ceață mai deasă pe turn).
func _copie(schimbari: Dictionary) -> ShaderMaterial:
	var m := _material.duplicate() as ShaderMaterial
	for nume: String in schimbari:
		var vechi = _material.get_shader_parameter(nume)
		m.set_shader_parameter(nume, vechi * schimbari[nume])
	return m
