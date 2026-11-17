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
@export var raza_interioara := 22.0
@export var raza_exterioara := 1700.0
## Până unde terenul e făcut din iarba scenei (`sol`, cu ceața ei): podeaua curții continuă fără nicio margine până
## în dealuri (owner 10.11: „să fie conectată podeaua”); mai departe e shaderul dealurilor.
@export var sol: CSGBox3D
@export var raza_sol := 160.0
## Cât de des e plasa: bucăți pe cerc și inele (fațete mari, PS2).
@export var segmente := 300
@export var inele := 80
## Muntele: pe ce direcție (grade, de la +X spre +Z), cât de departe, cât de înalt și cât de lat.
@export var munte_unghi := 128.0
@export var munte_distanta := 1150.0
@export var munte_inaltime := 380.0
@export var munte_latime := 260.0
## Turnul de antenă: direcția (grade), distanța și înălțimea lui.
@export var turn_unghi := 55.0
@export var turn_distanta := 420.0
@export var turn_inaltime := 48.0
## Cât de pierdut în ceață e turnul și becurile lui (0 = clar, 1 = deloc; owner 10.11: „mai în fog, aceeași culoare
## ca environmentul”). Becurile puțin mai puțin, ca roșul să se ghicească.
@export_range(0.0, 1.0) var turn_ceata := 0.78
@export_range(0.0, 1.0) var becuri_ceata := 0.5

const SHADER := preload("res://shaders/peisaj_departe.gdshader")

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
	_copaci_imas()
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
	# culoarea „obiectului” înainte de ceață: ce ar avea un perete cenușiu în lumina ambientală a momentului (ca blocurile);
	# ceața o pune scena peste el (vezi shaderul)
	var ambient := Color(0.36, 0.4, 0.52) * 0.55
	if env:
		ambient = env.ambient_light_color * env.ambient_light_energy
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
	var luminos := ambient.get_luminance()
	_material.set_shader_parameter("culoare_baza", ambient * 0.75)
	_material.set_shader_parameter("culoare_lumina", culoare_lumina)
	_material.set_shader_parameter("directie_lumina", directie)
	_material.set_shader_parameter("putere_lumina", putere * 0.6)
	# zăpada: noaptea doar se ghicește
	_material.set_shader_parameter("lumina_zapada", clampf(luminos * 1.1, 0.15, 1.0))
	_material.set_shader_parameter("inaltime_zapada", munte_inaltime * 0.55)
	# cât de „aproape” stau în ceață (m): cât blocurile din jur, ca să le vezi ca pe ele
	_material.set_shader_parameter("ceata_aproape", 24.0)
	_material.set_shader_parameter("ceata_departe", 50.0)
	_material.set_shader_parameter("ceata_vale", 16.0)


## Cât de înalt e terenul în punctul (x, z) (față de nod).
func inaltime(x: float, z: float) -> float:
	var r := Vector2(x, z).length()
	# dealurile din față: line, tot mai înalte spre orizont
	var dealuri := (0.55 + 0.45 * _zgomot.get_noise_2d(x, z)) * lerpf(14.0, 75.0, smoothstep(250.0, 1200.0, r))
	dealuri *= smoothstep(105.0, 380.0, r)
	# culmea din spate: muchii ascuțite
	var culme := (0.5 + 0.5 * _culme.get_noise_2d(x, z)) * 120.0 * smoothstep(520.0, 1000.0, r)
	# imașul de lângă curte (owner 10.11: „pare că e un lac” între curte și dealuri): ușor vălurit chiar de la marginea
	# ierbii din scenă, ca să nu fie o fâșie plată pierdută în ceață
	var imas := (3.2 + 3.0 * _zgomot.get_noise_2d(x * 3.0, z * 3.0)) * smoothstep(raza_interioara, raza_interioara + 30.0, r)
	# curtea, strada (pe unde trece autobuzul) și blocurile din scenă rămân pe teren plat
	var h := maxf(dealuri, imas) * liber(x, z) + culme
	# șaua în dreptul soarelui de la apus
	if _sa != Vector2.ZERO:
		var unghi := absf(Vector2(x, z).normalized().angle_to(_sa))
		h *= 1.0 - 0.88 * exp(-pow(unghi / 0.2, 2.0))
	# muntele nu ajunge în curte / pe stradă (poalele lui largi ridicau terenul de acolo peste ochii jucătorului și
	# se vedea cerul prin podea, de dedesubt)
	return maxf(h, _munte(x, z) * liber(x, z)) - 0.15


## Masivul (owner 10.11: „muntele nu arată terminat”): vârful mare, doi umeri mai mici într-o parte și alta (puțin
## mai în spate), dealuri late la poale, și creste adânci tăiate de zgomot, ca să nu fie o movilă netedă.
func _munte(x: float, z: float) -> float:
	var radial := Vector2.from_angle(deg_to_rad(munte_unghi))
	var lateral := Vector2(-radial.y, radial.x)
	var m := radial * munte_distanta
	var q := Vector2(x, z) - m
	var u := q.dot(lateral)
	var v := q.dot(radial)
	var varfuri := [[0.0, 0.0, 1.0, 1.0], [300.0, 140.0, 0.7, 0.85], [-260.0, 210.0, 0.58, 0.8], [520.0, 300.0, 0.42, 0.9]]
	var h := 0.0
	for vf in varfuri:
		var d: float = Vector2(u - vf[0], v - vf[1]).length() / (munte_latime * vf[3])
		# mai ascuțit decât un clopot: pantele drepte, vârful îngust
		h = maxf(h, munte_inaltime * vf[2] * exp(-pow(d, 1.5)))
	# creste: muchii în zgomotul „ridged”, mai adânci spre poale
	var creasta := _culme.get_noise_2d(x * 2.2, z * 2.2) * 0.5 + 0.5
	h *= lerpf(0.7, 1.05, creasta)
	# poalele: dealuri late în jurul masivului
	var dp := Vector2(u * 0.6, v).length()
	# poalele se termină de tot la ~3 lățimi de munte (altfel ridicau cu câțiva metri tot terenul, până în curte)
	var poale := munte_inaltime * 0.26 * exp(-pow(dp / (munte_latime * 2.4), 2.0)) * (1.0 - smoothstep(munte_latime * 2.2, munte_latime * 3.2, dp))
	return maxf(h, poale * (0.75 + 0.35 * creasta))


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
	# aproape: aceeași iarbă și aceeași ceață ca podeaua curții, ca să nu se vadă unde se termină
	var aproape := SurfaceTool.new()
	aproape.begin(Mesh.PRIMITIVE_TRIANGLES)
	aproape.set_smooth_group(-1)
	# din afară spre înăuntru: dealurile sunt transparente spre depărtare, iar cele din față trebuie desenate peste
	# cele din spate
	for i in range(raze.size() - 2, -1, -1):
		var unde := aproape if raze[i + 1] <= raza_sol and sol != null else st
		for k in segmente:
			var k2 := (k + 1) % segmente
			var a := puncte[i][k]
			var b := puncte[i][k2]
			var c := puncte[i + 1][k]
			var d := puncte[i + 1][k2]
			# în sens invers acelor de ceas văzut de sus, ca fața să fie în sus
			unde.add_vertex(a); unde.add_vertex(c); unde.add_vertex(b)
			unde.add_vertex(b); unde.add_vertex(c); unde.add_vertex(d)
	if sol != null:
		aproape.generate_normals()
		var podea := MeshInstance3D.new()
		podea.name = "Podea"
		podea.mesh = aproape.commit()
		podea.material_override = sol.material
		podea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(podea)
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
		sfera.radius = 1.8  # owner 10.11: mai mici (la 3,2 m erau prea mari)
		sfera.height = 3.6
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
	mmi.material_override = _copie({"culoare_baza": 0.85, "putere_lumina": 0.5})
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)



## Copacii de pe imașul din jurul curții (owner 15.11: „e spațiu gol … când zbori pe mătură se vede urât”): pâlcuri de
## copaci cu coroană rotundă și trunchi, de la 34 m până la `raza_cartier` m. Blocurile din jur au fost scoase (owner
## 17.11). Trunchiul pornește de sub cel mai jos punct al terenului din jurul lui (pe pantă nu plutește), iar coroana
## stă pe el. Nu pe stradă, nu în curte, nu lângă blocurile din scenă (`liber`).
@export_group("Copaci imas")
@export var raza_cartier := 300.0

func _copaci_imas() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = saminta + 5
	var pete := FastNoiseLite.new()
	pete.seed = saminta + 6
	pete.frequency = 0.02
	var copaci: Array[Transform3D] = []
	var trunchiuri: Array[Transform3D] = []
	var pas := 7.0
	var x := -raza_cartier
	while x < raza_cartier:
		var z := -raza_cartier
		while z < raza_cartier:
			var px := x + r.randf_range(-0.45, 0.45) * pas
			var pz := z + r.randf_range(-0.45, 0.45) * pas
			z += pas
			var d := Vector2(px, pz).length()
			if d < 34.0 or d > raza_cartier or pete.get_noise_2d(px, pz) < 0.05 or liber(px, pz) < 0.999:
				continue
			var s := r.randf_range(4.5, 8.0)
			var inalt_coroana := s * r.randf_range(1.0, 1.4)
			var rot := r.randf_range(0.0, TAU)
			# solul: în centru și cel mai de jos punct din jurul trunchiului (plasa terenului are fațete plate)
			var sol_mijloc := inaltime(px, pz)
			var sol_jos := sol_mijloc
			for k in 6:
				var o := Vector2.from_angle(TAU * k / 6.0) * 1.5
				sol_jos = minf(sol_jos, inaltime(px + o.x, pz + o.y))
			var trunchi := s * r.randf_range(0.45, 0.6)  # cât se vede din trunchi până la coroană
			var gros := clampf(s * 0.07, 0.35, 0.55)
			var jos := sol_jos - 1.0
			var sus := sol_mijloc + trunchi + inalt_coroana * 0.3  # intră în coroană, să nu se vadă capătul
			trunchiuri.append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3(gros, sus - jos, gros)), Vector3(px, (jos + sus) * 0.5, pz)))
			# coroana: partea de jos puțin sub vârful trunchiului
			var coroana := Basis(Vector3.UP, rot).scaled(Vector3(s, inalt_coroana, s))
			copaci.append(Transform3D(coroana, Vector3(px, sol_mijloc + trunchi + inalt_coroana * 0.4, pz)))
		x += pas
	var sfera := SphereMesh.new()
	sfera.radius = 0.5
	sfera.height = 1.0
	sfera.radial_segments = 6
	sfera.rings = 3
	_multimesh("CopaciCartier", sfera, copaci, _copie({"culoare_baza": 0.8, "putere_lumina": 0.5}))
	var cilindru := CylinderMesh.new()
	cilindru.top_radius = 0.5
	cilindru.bottom_radius = 0.5
	cilindru.height = 1.0
	cilindru.radial_segments = 5
	cilindru.rings = 1
	cilindru.cap_top = false
	cilindru.cap_bottom = false
	_multimesh("TrunchiuriCartier", cilindru, trunchiuri, _copie({"culoare_baza": 0.55, "putere_lumina": 0.4}))


func _multimesh(nume: String, mesh: Mesh, transformari: Array[Transform3D], mat: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transformari.size()
	for i in transformari.size():
		mm.set_instance_transform(i, transformari[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nume
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Materialul dealurilor, dar cu ceața de departe ajunsă (de la câteva sute de metri) la `cat`.
func _in_ceata(cat: float) -> ShaderMaterial:
	var m := _material.duplicate() as ShaderMaterial
	# cât de pierdut e: metri în plus „în ceață” (1 = cât e nevoie ca să nu se mai vadă nici noaptea, nici ziua)
	m.set_shader_parameter("ceata_extra", cat * 60.0)
	return m


## O copie a materialului dealurilor cu câțiva parametri schimbați: numerele sunt înmulțite cu ce era (culoarea
## de bază mai închisă pentru brazi, ceață mai deasă pe turn).
func _copie(schimbari: Dictionary) -> ShaderMaterial:
	var m := _material.duplicate() as ShaderMaterial
	for nume: String in schimbari:
		var vechi = _material.get_shader_parameter(nume)
		m.set_shader_parameter(nume, vechi * schimbari[nume])
	return m


## Locurile din scenă (în coordonatele lumii) unde terenul trebuie să rămână plat și fără copaci: curtea cu gardul și
## copacii ei, strada cu trotuarele (merge autobuzul pe ea, de la un capăt la altul), blocul de vizavi, cel lateral.
const LOCURI_PLATE := [Rect2(-21, -27, 42, 57), Rect2(-400, 12, 800, 15), Rect2(-21, 35, 32, 18), Rect2(-45, -15, 18, 31)]
const MARGINE_PLAT := 3.0

## 1 = liber (pot fi dealuri și copaci), 0 = în curte / pe stradă / lângă un bloc, cu o pantă de `MARGINE_PLAT` m.
func liber(x: float, z: float) -> float:
	var p := Vector2(x, z) + Vector2(position.x, position.z)
	var rez := 1.0
	for loc: Rect2 in LOCURI_PLATE:
		var dx := maxf(maxf(loc.position.x - p.x, p.x - loc.end.x), 0.0)
		var dz := maxf(maxf(loc.position.y - p.y, p.y - loc.end.y), 0.0)
		rez = minf(rez, smoothstep(0.0, MARGINE_PLAT, Vector2(dx, dz).length()))
	return rez

