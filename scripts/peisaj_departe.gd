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
## Ceața scenei (fog_light_color, „r,g,b”) -> [culoarea ierbii pierdute în ceață, culoarea cerului de deasupra
## dealurilor, cum iese pe ecran iarba din ceață], ca uniform: măsurate pe ecran (Claude, 10.11: un teren roșu ca să găsești unde e, apoi culoarea
## ajustată până iese ca pixelii scenei). Dacă schimbi ceața dintr-un moment, refă măsurătoarea; altfel se folosește
## direct culoarea ceții (se vede o dungă mai rece la orizont).
const PALETE := {
	"0.20,0.22,0.26": [Color(0.252, 0.204, 0.193), Color(0.277, 0.207, 0.191), Color(0.206, 0.168, 0.160)],  # noaptea (și meniul principal)
	"0.64,0.66,0.69": [Color(0.514, 0.535, 0.537), Color(0.520, 0.534, 0.555), Color(0.421, 0.439, 0.444)],  # ziua (ZiBloc)
	"0.66,0.44,0.46": [Color(0.494, 0.292, 0.283), Color(0.637, 0.378, 0.470), Color(0.404, 0.239, 0.230)],  # apusul (ApusBloc)
	"0.15,0.22,0.46": [Color(0.187, 0.186, 0.310), Color(0.207, 0.190, 0.365), Color(0.179, 0.182, 0.301)],  # seara (SearaBloc)
}

var _zgomot := FastNoiseLite.new()
var _culme := FastNoiseLite.new()
var _sa := Vector2.ZERO  # direcția (pe orizontală) în care se lasă dealurile; zero = nicăieri
var _material := ShaderMaterial.new()
var _becuri: Array[MeshInstance3D] = []
var _ceas := 0.0
## Culoarea ceții potrivită din mers (vezi `_masoara`): cea de acum și spre ce merge.
var _ceata_acum := Color(0.25, 0.2, 0.19)
var _ceata_tinta := Color(0.25, 0.2, 0.19)
var _ceas_masura := 0.0
var _materiale: Array[ShaderMaterial] = []
## Cât de mult trebuie înmulțită o culoare de pe ecran ca să iasă la fel din shader (tonemap + efectul PS2).
var _pe_ecran := Color(1.22, 1.21, 1.21)
var _imprastiere := 0.0
var _culoare_lumina := Color(1, 1, 1)
var _spre_lumina := Vector3.UP
## Siluetele se pierd spre o culoare cu atât mai închisă decât ceața (ca să nu iasă dealuri mai luminoase ca cerul).
const INCHIS := 0.8
## Cât de departe în fața ta e locul de iarbă din ceață după care se potrivesc culorile (m).
const DEPARTE_MASURA := 120.0


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
	_ceas_masura += delta
	if _ceas_masura > 0.3:
		_ceas_masura = 0.0
		_masoara()
	# lin, ca să nu pâlpâie
	if _ceata_acum != _ceata_tinta:
		_ceata_acum = _ceata_acum.lerp(_ceata_tinta, minf(delta * 2.5, 1.0))
		for m in _materiale:
			m.set_shader_parameter("culoare_ceata", _ceata_acum)
			m.set_shader_parameter("culoare_cer", _ceata_acum * INCHIS)


## Ia culorile din mediul scenei (cum l-au lăsat ZiBloc / ApusBloc / SearaBloc) și din lumină.
func _culori() -> void:
	_material.shader = SHADER
	_materiale.append(_material)
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
		var iesit: Color = PALETE[cheie][2]
		var u: Color = PALETE[cheie][0]
		_pe_ecran = Color(u.r / iesit.r, u.g / iesit.g, u.b / iesit.b)
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
	_material.set_shader_parameter("culoare_cer", cer * INCHIS)
	_ceata_acum = ceata
	_ceata_tinta = ceata
	_material.set_shader_parameter("culoare_lumina", culoare_lumina)
	_material.set_shader_parameter("directie_lumina", directie)
	# noaptea luna (albastră) ar vopsi dealurile: abia le atinge; zăpada doar se ghicește
	_material.set_shader_parameter("putere_lumina", putere * (0.35 if luminos < 0.3 else 1.0))
	# ceața scenei se aprinde spre soare (`fog_sun_scatter`, la apus): și cea a dealurilor
	_imprastiere = (env.fog_sun_scatter * (lumina.light_energy if lumina else 1.0)) if env else 0.0
	_material.set_shader_parameter("imprastiere_soare", _imprastiere)
	_culoare_lumina = culoare_lumina
	_spre_lumina = directie.normalized()
	_material.set_shader_parameter("lumina_zapada", clampf(luminos * 1.4, 0.22, 1.0) if not jos else 1.0)
	_material.set_shader_parameter("densitate_aproape", densitate)
	_material.set_shader_parameter("inaltime_zapada", munte_inaltime * 0.55)
	# iarba imașului: noaptea aproape neagră, ziua verde-măslinie
	_material.set_shader_parameter("culoare_iarba", Color(0.17, 0.18, 0.1) * clampf(luminos * 2.0, 0.4, 1.2))
	# ziua ceața e albă și deasă: dealurile abia se ghicesc; noaptea și la apus se văd mai bine
	_material.set_shader_parameter("ceata_max", 0.86 if luminos > 0.5 else (0.62 if jos else 0.7))
	_material.set_shader_parameter("ceata_vale", 1.0)
	# poalele dealurilor intră complet în ceața de pe iarbă și ies din ea treptat (owner 10.11: „nu vreau să văd cerul
	# sub dealuri” — dunga de ceață luminată de soare de pe șes părea cer)
	_material.set_shader_parameter("inaltime_ceata", 34.0)


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
	mmi.material_override = _copie({"culoare_baza": 0.62, "ceata_vale": 1.0, "putere_lumina": 0.5})
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)



## Materialul dealurilor, dar cu ceața de departe ajunsă (de la câteva sute de metri) la `cat`.
func _in_ceata(cat: float) -> ShaderMaterial:
	var m := _material.duplicate() as ShaderMaterial
	_materiale.append(m)
	m.set_shader_parameter("ceata_max", cat)
	m.set_shader_parameter("densitate_departe", 0.012)
	m.set_shader_parameter("culoare_iarba", m.get_shader_parameter("culoare_baza"))
	return m


## O copie a materialului dealurilor cu câțiva parametri schimbați: numerele sunt înmulțite cu ce era (culoarea
## de bază mai închisă pentru brazi, ceață mai deasă pe turn).
func _copie(schimbari: Dictionary) -> ShaderMaterial:
	var m := _material.duplicate() as ShaderMaterial
	_materiale.append(m)
	for nume: String in schimbari:
		var vechi = _material.get_shader_parameter(nume)
		m.set_shader_parameter(nume, vechi * schimbari[nume])
	# copacii (și turnul) n-au iarbă pe creștet
	m.set_shader_parameter("culoare_iarba", m.get_shader_parameter("culoare_baza"))
	return m


## Locurile din scenă (în coordonatele lumii) unde terenul trebuie să rămână plat și fără copaci: curtea cu gardul și
## copacii ei, strada cu trotuarele (merge autobuzul pe ea, de la un capăt la altul), blocul de vizavi, cel lateral.
const LOCURI_PLATE := [Rect2(-21, -27, 42, 57), Rect2(-400, 12, 800, 15), Rect2(-21, 35, 32, 18), Rect2(-45, -7, 18, 30)]
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


## Ceața scenei arată altfel în fiecare colț al curții (cea volumetrică e luminată de felinare): o dată la 0,3 s se uită
## pe ecran la iarba din ceață din fața ta, la `DEPARTE_MASURA` m (podeaua făcută cu iarba scenei, `sol`), și
## potrivește ceața dealurilor după ea. Dacă ceva stă în cale (un bloc, un copac) sau locul nu e pe ecran, lasă
## culoarea cum era. Din culoarea de pe ecran în cea din shader: înmulțită cu `_pe_ecran` (măsurat, vezi PALETE).
func _masoara() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _materiale.is_empty():
		return
	var inainte := -cam.global_basis.z
	inainte.y = 0.0
	if inainte.length() < 0.1:
		return
	var c := cam.global_position
	var p := c + inainte.normalized() * DEPARTE_MASURA
	p.y = inaltime(p.x - position.x, p.z - position.z) + position.y + 0.3
	if cam.is_position_behind(p):
		return
	var s := cam.unproject_position(p)
	var marime := get_viewport().get_visible_rect().size
	if s.x < 2 or s.y < 2 or s.x > marime.x - 3 or s.y > marime.y - 3:
		return
	# ce stă în cale (pereții invizibili ai curții, `Limite`, și jucătorul nu contează: nu se văd)
	var q := PhysicsRayQueryParameters3D.create(c, p)
	var ocolite: Array[RID] = []
	var jucator := get_tree().get_first_node_in_group("jucator") as CollisionObject3D
	if jucator:
		ocolite.append(jucator.get_rid())
	for incercare in 4:
		q.exclude = ocolite
		var lovit := get_world_3d().direct_space_state.intersect_ray(q)
		if lovit.is_empty() or c.distance_to(lovit.position) >= DEPARTE_MASURA - 15.0:
			break
		var cine := lovit.collider as Node
		if cine and (cine.name == "Limite" or String(cine.name).begins_with("Limit")):
			ocolite.append(lovit.rid)
			continue
		return
	var img := get_viewport().get_texture().get_image()
	var k := Vector2i(int(s.x * img.get_width() / marime.x), int(s.y * img.get_height() / marime.y))
	var suma := Color(0, 0, 0)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			suma += img.get_pixel(clampi(k.x + dx, 0, img.get_width() - 1), clampi(k.y + dy, 0, img.get_height() - 1))
	var o := suma / 9.0
	var masurat := Color(o.r * _pe_ecran.r, o.g * _pe_ecran.g, o.b * _pe_ecran.b)
	# pe ecran ceața din fața ta e deja aprinsă de soare (dacă te uiți spre el): o scoate, shaderul o pune la loc
	# pentru fiecare direcție
	var sc := pow(maxf(inainte.normalized().dot(_spre_lumina), 0.0), 8.0) * _imprastiere
	masurat -= _culoare_lumina * sc
	_ceata_tinta = Color(clampf(masurat.r, 0, 1), clampf(masurat.g, 0, 1), clampf(masurat.b, 0, 1))
