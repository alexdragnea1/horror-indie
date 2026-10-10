class_name ChemareDemon
extends Interactabil
## Ce au în comun locurile în care arunci pisica moartă (`ID_PISICA`, vezi pisica.gd) ca să chemi **demonul**:
## ceaunul din camera ta (ceaun_acasa.gd) și șemineul din conac (semineu_conac.gd). Aici: aruncatul pisicii în arc,
## demonul care urcă prin podea, replica lui și ce-i răspunzi (cu pistol: îl împuști și se dezintegrează; fără: se
## teleportează), plus efectele (zguduitul camerei, urechile care țiuie, stâlpul de lumină, particulele).
## Replicile sunt ale owner-ului; le poate schimba din Inspector.

const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")
const SHADER_RAZA := preload("res://shaders/raza_vraja.gdshader")
const MODEL_PISICA := preload("res://models/pisica.glb")
const DEMON := preload("res://scenes/demon.tscn")
const SUNET_PLESCAIT := preload("res://sunete/cazan_plescait.ogg")
const SUNET_TIUIT := preload("res://sunete/tiuit.ogg")
const SUNET_CHEMARE := preload("res://sunete/demon_chemare.ogg")
const SUNET_VOCE_DEMON := preload("res://sunete/demon_voce.ogg")
const SUNET_LUMANARE := preload("res://sunete/minge_foc_aprinsa.ogg")
const ID_PISICA := "cadavru_pisica"

@export var marcaj_demon := "demonul_chemat"
@export var replica_demon := "Demon: There's a special place in hell for people like you."
@export var replica_cu_pistol := "You: You're a bitch lmao."
@export var replica_fara_pistol := "You: Kill yourself."
## Câte gloanțe tragi în demon.
@export var gloante := 3

var _jucator: CharacterBody3D
var _camera: Camera3D


## Pisica pleacă din brațele tale și zboară în arc (moale, dându-se peste cap) până deasupra lui `tinta`.
## Întoarce nodul pisicii (cine cheamă hotărăște ce se întâmplă cu ea: se scufundă, arde).
func _arunca_pisica(tinta: Vector3, inaltime_arc := 0.6, durata := 0.6) -> Node3D:
	var pisica := MODEL_PISICA.instantiate() as Node3D
	pisica.set_script(SCRIPT_MODEL)
	pisica.set("material", MATERIAL)
	get_tree().current_scene.add_child(pisica)
	# culcată pe o parte, cu ochii închiși
	var ochi := pisica.get_node_or_null("Cap/Ochi") as Node3D
	if ochi:
		ochi.scale.y = 0.15
	var start := _camera.global_position - _camera.global_basis.z * 0.55 + Vector3.DOWN * 0.5
	var rot_start := Vector3(0.0, _jucator.rotation.y, PI / 2.0)
	var rot_capat := rot_start + Vector3(-2.6, 0.4, 0.3)
	pisica.global_position = start
	pisica.rotation = rot_start
	var t := create_tween()
	t.tween_method(func(f: float) -> void:
		pisica.global_position = start.lerp(tinta, f) + Vector3.UP * sin(f * PI) * inaltime_arc
		pisica.rotation = rot_start.lerp(rot_capat, f), 0.0, 1.0, durata)
	await t.finished
	return pisica


## Demonul urcă prin podea în `centru` (copil al lui `parinte`), cu fața spre tine; camera îl urmărește.
func _ridica_demonul(c: Cutscena, centru: Vector3, parinte: Node) -> Demon:
	var demon := DEMON.instantiate() as Demon
	parinte.add_child(demon)
	demon.global_position = centru
	var spre := _jucator.global_position - centru
	demon.rotation.y = atan2(spre.x, spre.z)
	demon.privire = _camera
	c.priveste(centru + Vector3.UP * 2.0, 2.6)
	get_tree().create_timer(2.9).timeout.connect(_zguduie.bind(0.35, 1.6))
	await demon.aparitie(2.6)
	return demon


## Replica demonului, apoi a ta: cu pistol (roz sau de aur) îl împuști și se dezintegrează, fără se teleportează.
## Pune `marcaj_demon` = „dezintegrat” / „teleportat”.
func _vorbeste_cu_demonul(c: Cutscena, demon: Demon) -> void:
	var cap_demon := demon.global_position + Vector3.UP * 1.8  # puțin sub cap: se vede și pieptul, nu doar tavanul
	await c.priveste(cap_demon, 0.4)
	demon.vorbeste = true
	Dialog.spune([replica_demon])
	Sunet.reda_la(SUNET_VOCE_DEMON, cap_demon, Sunet.VOLUM_EFECTE, 0.0)  # respirația și mârâitul lui, sub bipurile replicii
	# falca se mișcă doar cât se scrie replica (45 de litere pe secundă, ca în Dialog)
	var taci := func() -> void:
		if is_instance_valid(demon):
			demon.vorbeste = false
	get_tree().create_timer(replica_demon.length() / 45.0).timeout.connect(taci)
	await Dialog.terminat
	demon.vorbeste = false
	var id_pistol := _pistolul()
	if id_pistol != "":
		await _impusca_demonul(c, demon, id_pistol)
		Stare.marcheaza(marcaj_demon, "dezintegrat")
	else:
		Dialog.spune([replica_fara_pistol])
		await Dialog.terminat
		demon.mareste_furia(0.25, 0.4)
		await get_tree().create_timer(0.9).timeout
		demon.teleporteaza()
		await get_tree().create_timer(1.2).timeout
		Stare.marcheaza(marcaj_demon, "teleportat")


## Scoți pistolul, îi spui replica și tragi în pieptul lui; se dezintegrează.
func _impusca_demonul(c: Cutscena, demon: Demon, id_pistol: String) -> void:
	Stare.tine_in_mana(id_pistol)
	Pistol.in_scena = true
	await get_tree().create_timer(0.45).timeout
	Dialog.spune([replica_cu_pistol])
	await Dialog.terminat
	demon.mareste_furia(0.6, 0.3)
	var pistol := _pistol_din_mana(id_pistol)
	for i in gloante:
		var tinta := demon.to_global(Vector3(randf_range(-0.08, 0.08), 1.45 + randf_range(-0.1, 0.12), 0.2))
		await c.priveste(tinta, 0.35 if i == 0 else 0.12)
		if pistol:
			pistol.trage_acum()
		await get_tree().create_timer(0.4).timeout
	demon.mareste_furia(0.0, 0.2)
	demon.dezintegreaza()
	await c.priveste(demon.global_position + Vector3.UP * 1.6, 0.8)
	await get_tree().create_timer(3.0).timeout
	Pistol.in_scena = false


## Pistolul din inventar: cel din mână, altfel cel roz, altfel cel de aur; "" = n-ai pistol.
func _pistolul() -> String:
	if Stare.in_mana in [Pistol.ID, Pistol.ID_AUR]:
		return Stare.in_mana
	if Stare.are_obiect(Pistol.ID):
		return Pistol.ID
	if Stare.are_obiect(Pistol.ID_AUR):
		return Pistol.ID_AUR
	return ""


func _pistol_din_mana(id: String) -> Pistol:
	for copil in _camera.get_children():
		if copil is Pistol and (copil as Pistol).id == id:
			return copil
	return null


# ---------------------------------------------------------------- efecte

## Camera se zguduie (`putere` 1 = explozia de lângă tine) și se liniștește în `durata` secunde.
func _zguduie(putere: float, durata: float) -> void:
	if _camera == null:
		return
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		_camera.h_offset = randf_range(-1.0, 1.0) * 0.05 * putere * v
		_camera.v_offset = randf_range(-1.0, 1.0) * 0.05 * putere * v, 1.0, 0.0, durata)
	await t.finished
	_camera.h_offset = 0.0
	_camera.v_offset = 0.0


## Îți țiuie urechile: tot ce se aude (efecte, ambianță, muzică) trece prin filtru și se aude înfundat, apoi revine în
## `durata` secunde; peste, un țiuit (pe canalul Interfata, nefiltrat).
func _asurzeste(durata: float) -> void:
	# pocnetul exploziei se aude curat (0,35 s), abia apoi se înfundă: rămân basul și vuietul
	await get_tree().create_timer(0.35).timeout
	var filtre := []
	for nume in [&"Efecte", &"Ambianta", &"Muzica"]:
		var i := AudioServer.get_bus_index(nume)
		if i < 0:
			continue
		var f := AudioEffectLowPassFilter.new()
		f.cutoff_hz = 300.0
		AudioServer.add_bus_effect(i, f)
		filtre.append([i, f])
	Sunet.reda(SUNET_TIUIT, Sunet.VOLUM_EFECTE - 10.0, 0.0, &"Interfata")
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		for x in filtre:
			(x[1] as AudioEffectLowPassFilter).cutoff_hz = v, 300.0, 20000.0, durata).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	await t.finished
	for x in filtre:
		var i: int = x[0]
		for k in range(AudioServer.get_bus_effect_count(i) - 1, -1, -1):
			if AudioServer.get_bus_effect(i, k) == x[1]:
				AudioServer.remove_bus_effect(i, k)


## Stâlpul de lumină de pe locul chemării (ca unda de la cazanul din pădure, raza_vraja.gdshader), `inaltime` metri.
func _stalp_lumina(culoare: Color, inaltime := 2.95, raza := 0.9) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = raza * 0.9
	mesh.bottom_radius = raza
	mesh.height = inaltime
	mesh.radial_segments = 16
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_RAZA
	mat.set_shader_parameter("culoare", culoare)
	mat.set_shader_parameter("putere", 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = inaltime * 0.5 + 0.02
	return mi


## Particule: pătrățele întoarse spre cameră (`rotunde` = cercuri moi, Arma.cerc_moale), cu culoarea după viață
## (`culori`, de la naștere la moarte).
func _particule(cate: int, viata: float, marime: float, culori: PackedColorArray, aditiv: bool, rotunde := false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * marime
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if aditiv:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_fog = true
	if rotunde:
		mat.albedo_texture = Arma.cerc_moale()
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	quad.material = mat
	p.mesh = quad
	p.amount = cate
	p.lifetime = viata
	p.local_coords = false
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	for i in culori.size():
		offsets.append(float(i) / (culori.size() - 1))
	gradient.offsets = offsets
	gradient.colors = culori
	p.color_ramp = gradient
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## O singură izbucnire de particule în `punct`.
func _unic(p: CPUParticles3D, punct: Vector3) -> void:
	p.one_shot = true
	p.explosiveness = 1.0  # altfel particulele care n-au pornit încă se văd ca un pătrat negru în `punct`
	get_tree().current_scene.add_child(p)
	p.global_position = punct
	p.emitting = true
	get_tree().create_timer(p.lifetime + 0.5).timeout.connect(p.queue_free)
