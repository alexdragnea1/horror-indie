extends Node3D
## Televizorul din livingul lui Lexy (models/televizor.glb în copilul `Model`), dat pe știri:
## pe `Ecran` se vede o emisiune desenată din cod într-un SubViewport (prezentatoarea care vorbește, banda roșie
## „BREAKING NEWS”, titlul, textul care curge jos, „LIVE” care clipește; din când în când imagini de la fața locului:
## pădurea în ceață cu o lumină verde peste ea). Lumina albăstruie din fața lui pâlpâie după cât de luminoasă e
## imaginea, iar vocea crainicului (`sunet`) se aude înfundat, în buclă.
## Textele (engleză, pentru jucător) sunt aici, ca să le schimbi ușor.

@export var titlu := "STRANGE LIGHTS OVER TRIVALE FOREST"
@export var banda_jos := "POLICE SEARCH TRIVALE FOREST AFTER NIGHT OF STRANGE LIGHTS  •  NIGHT BUS 13 DRIVER QUITS: \"I SAW SOMETHING RUN NEXT TO THE BUS\"  •  FOG WARNING FOR THE WHOLE WEEK  •  "
@export var sunet: AudioStream
@export_group("Spart")
## Tragi în el (orice armă, Fireball-ul, o explozie): ecranul se crapă și se stinge, scântei, fum, vocea tace.
## Rămâne spart (marcajul ăsta, și la Continue).
@export var marcaj_spart := "televizorul_lexy_spart"
@export var sunet_spart: AudioStream
@export var sunet_scantei: AudioStream

const LATIME := 192
const INALTIME := 112
## Ecranul, în coordonatele televizorului (pentru locul glonțului pe imagine): x ±0,46, y 0,62…1,16.
const ECRAN_X := 0.46
const ECRAN_Y := Vector2(0.62, 1.16)
## Cutia în care îl poți nimeri: doar televizorul (nu și comoda), trasă puțin în față cât să o prindă glonțul
## înaintea cutiei de coliziune a modelului (`coliziune` = Cutie, care e cât tot modelul).
const CUTIE_TINTA := AABB(Vector3(-0.5, 0.58, -0.12), Vector3(1.0, 0.63, 0.39))
const CULORI_CRAPATURI: Array[Color] = [Color("70706e"), Color("7e8d87"), Color("83b3b0")]

var spart := false
var _mat_ecran: StandardMaterial3D
var _voce: AudioStreamPlayer3D

var _ecran: SubViewport
var _prezentatoare: Control
var _gura: ColorRect
var _teren: Control
var _banda: Label
var _live: Label
var _lumina: OmniLight3D
var _timp := 0.0
var _la_fata_locului := false


func _ready() -> void:
	_ecran = SubViewport.new()
	_ecran.size = Vector2i(LATIME, INALTIME)
	_ecran.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_ecran.disable_3d = true
	add_child(_ecran)
	_deseneaza()
	var mesh := find_child("Ecran", true, false) as MeshInstance3D
	if mesh:
		# un dreptunghi drept în fața cutiei `Ecran` (UV-urile cutiei din Blender ar împărți imaginea pe fețe)
		var cutie := mesh.get_aabb()
		var plan := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(cutie.size.x, cutie.size.y)
		plan.mesh = quad
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = _ecran.get_texture()
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		plan.material_override = mat
		_mat_ecran = mat
		plan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.add_child(plan)
		plan.position = cutie.get_center() + Vector3(0, 0, cutie.size.z * 0.5 + 0.002)
	_lumina = OmniLight3D.new()
	_lumina.light_color = Color(0.55, 0.7, 1.0)
	_lumina.light_energy = 0.6
	_lumina.omni_range = 4.5
	_lumina.shadow_enabled = true
	_lumina.light_volumetric_fog_energy = 0.0
	add_child(_lumina)
	_lumina.position = Vector3(0, 0.9, 0.5)
	if sunet:
		var voce := AudioStreamPlayer3D.new()
		voce.stream = sunet
		voce.volume_db = Sunet.VOLUM_AMBIANTA
		voce.unit_size = 2.5
		voce.max_distance = 18.0
		voce.bus = &"Efecte"
		voce.autoplay = true
		add_child(voce)
		voce.position = Vector3(0, 0.9, 0)
		_voce = voce
	TintaObiect.adauga(self, CUTIE_TINTA).lovit.connect(_lovit)
	if Stare.e_marcat(marcaj_spart):
		_sparge(Vector3(0.12, 0.95, 0.0), false)


func _lovit(_directie: Vector3, punct: Vector3, _foc: bool) -> void:
	if spart:
		return
	Stare.marcheaza(marcaj_spart)
	_sparge(to_local(punct), true)


## Ecranul se crapă din punctul `local` (coordonatele televizorului) și se stinge. `efecte` = acum (sunet, fulger,
## scântei, fum); fără = deja spart la încărcare.
func _sparge(local: Vector3, efecte: bool) -> void:
	spart = true
	set_process(false)
	_ecran.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var uv := Vector2(clampf((local.x + ECRAN_X) / (2.0 * ECRAN_X), 0.08, 0.92),
		clampf(1.0 - (local.y - ECRAN_Y.x) / (ECRAN_Y.y - ECRAN_Y.x), 0.1, 0.9))
	if _mat_ecran:
		_mat_ecran.albedo_texture = _textura_crapata(uv)
	if _voce:
		_voce.stop()
	if not efecte:
		_lumina.light_energy = 0.0
		return
	var pe_ecran := to_global(Vector3((uv.x * 2.0 - 1.0) * ECRAN_X, lerpf(ECRAN_Y.y, ECRAN_Y.x, uv.y), 0.02))
	Sunet.reda_la(sunet_spart, pe_ecran, Sunet.VOLUM_EFECTE, 0.05)
	# fulgerul alb al ecranului care moare, apoi întuneric
	_lumina.light_color = Color(0.85, 0.95, 1.0)
	_lumina.light_energy = 3.0
	var t := create_tween()
	t.tween_property(_lumina, "light_energy", 0.0, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_scantei(pe_ecran, 40, 1.0)
	_fum(pe_ecran)
	# mai pârâie de câteva ori, tot mai rar
	for i in 4:
		await get_tree().create_timer(randf_range(0.4, 1.1) * (i + 1)).timeout
		if not is_inside_tree():
			return
		Sunet.reda_la(sunet_scantei, pe_ecran, Sunet.VOLUM_EFECTE - 6.0 - i * 2.0, 0.15)
		_scantei(pe_ecran + global_basis.x * randf_range(-0.15, 0.15) + Vector3.UP * randf_range(-0.1, 0.1), 10, 0.5)


## Un pumn de scântei care sar din ecran și cad (particule rotunde, aditive).
func _scantei(unde: Vector3, cate: int, putere: float) -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = cate
	p.lifetime = 0.9
	p.direction = Vector3(0, 0.3, 1)
	p.spread = 70.0
	p.initial_velocity_min = 1.0 * putere
	p.initial_velocity_max = 3.5 * putere
	p.gravity = Vector3(0, -9.8, 0)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.6, 0.2, 1.0), Color(0.9, 0.3, 0.1, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	p.color_ramp = g
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * 0.025
	mesh.material = Arma.material_particule(true)
	p.mesh = mesh
	add_child(p)
	p.global_position = unde
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


## Fumul subțire și gri care iese de după ecran câteva secunde.
func _fum(unde: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 18
	p.lifetime = 2.5
	p.preprocess = 2.5
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.35
	p.gravity = Vector3(0, 0.05, 0)
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.25, 0.24, 0.24, 0.0), Color(0.25, 0.24, 0.24, 0.35), Color(0.2, 0.2, 0.2, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	p.color_ramp = g
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * 0.18
	mesh.material = Arma.material_particule(false, 0.6)
	p.mesh = mesh
	add_child(p)
	p.global_position = unde + Vector3.UP * 0.25 - global_basis.z * 0.08
	p.emitting = true
	await get_tree().create_timer(5.0).timeout
	if is_instance_valid(p):
		p.emitting = false
		get_tree().create_timer(3.0).timeout.connect(p.queue_free)


## Ecranul spart: negru, crăpături care pleacă din locul glonțului (raze strâmbe + două inele rupte), o gaură în mijloc
## și câteva coloane de pixeli morți colorați, ca la un LCD stricat. Culorile din paletă.
func _textura_crapata(uv: Vector2) -> ImageTexture:
	var w := 96
	var h := 56
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color("262d2f"))
	var r := RandomNumberGenerator.new()
	r.seed = 13
	var morti: Array[Color] = [Color("61a19f"), Color("7b383a"), Color("83b3b0"), Color("438b88")]
	for c in morti:
		var x := r.randi_range(0, w - 1)
		for y in h:
			img.set_pixel(x, y, c.darkened(0.3))
	var c0 := uv * Vector2(w, h)
	for i in 11:
		var unghi := TAU * i / 11.0 + r.randf_range(-0.25, 0.25)
		var pasi := int(r.randf_range(14.0, 60.0))
		var p := c0
		var culoare: Color = CULORI_CRAPATURI[r.randi() % CULORI_CRAPATURI.size()]
		for k in pasi:
			unghi += r.randf_range(-0.12, 0.12)
			p += Vector2(cos(unghi), sin(unghi))
			if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
				break
			img.set_pixelv(Vector2i(p), culoare.darkened(float(k) / pasi * 0.5))
	for raza: float in [5.0, 11.0]:
		for k in 40:
			if r.randf() < 0.35:
				continue
			var a := TAU * k / 40.0
			var q := c0 + Vector2(cos(a), sin(a)) * raza * r.randf_range(0.85, 1.15)
			if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h:
				img.set_pixelv(Vector2i(q), CULORI_CRAPATURI[0])
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var q := Vector2i(c0) + Vector2i(dx, dy)
			if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and dx * dx + dy * dy <= 5:
				img.set_pixelv(q, Color("83b3b0") if dx * dx + dy * dy >= 4 else Color.BLACK)
	return ImageTexture.create_from_image(img)


func _dreptunghi(parinte: Control, culoare: Color, pozitie: Vector2, marime: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = culoare
	r.position = pozitie
	r.size = marime
	parinte.add_child(r)
	return r


func _text(parinte: Control, continut: String, marime: int, culoare: Color, pozitie: Vector2) -> Label:
	var l := Label.new()
	l.text = continut
	l.add_theme_font_size_override("font_size", marime)
	l.add_theme_color_override("font_color", culoare)
	l.position = pozitie
	parinte.add_child(l)
	return l


func _deseneaza() -> void:
	var fundal := Control.new()
	fundal.size = Vector2(LATIME, INALTIME)
	_ecran.add_child(fundal)
	# studioul: fundal albastru cu un glob stilizat și harta orașului
	_dreptunghi(fundal, Color("295555"), Vector2.ZERO, Vector2(LATIME, INALTIME))
	_dreptunghi(fundal, Color("2a3c3d"), Vector2(0, 0), Vector2(LATIME, 30))
	for i in 6:
		_dreptunghi(fundal, Color("30716f"), Vector2(110 + i * 12, 10 + (i % 3) * 9), Vector2(8, 30 - (i % 3) * 9))
	_dreptunghi(fundal, Color("438b88"), Vector2(104, 44), Vector2(80, 1))
	# prezentatoarea: păr închis, sacou roșu, în dreapta un ecran cu pădurea
	_prezentatoare = Control.new()
	fundal.add_child(_prezentatoare)
	_dreptunghi(_prezentatoare, Color("7b383a"), Vector2(30, 50), Vector2(52, 36))      # sacoul
	_dreptunghi(_prezentatoare, Color("83b3b0"), Vector2(50, 50), Vector2(12, 16))      # cămașa
	_dreptunghi(_prezentatoare, Color("a56850"), Vector2(51, 42), Vector2(10, 9))       # gâtul
	_dreptunghi(_prezentatoare, Color("262d2f"), Vector2(41, 18), Vector2(30, 32))      # părul
	_dreptunghi(_prezentatoare, Color("a56850"), Vector2(45, 22), Vector2(22, 24))      # fața
	_dreptunghi(_prezentatoare, Color("262d2f"), Vector2(49, 30), Vector2(4, 2))        # ochii
	_dreptunghi(_prezentatoare, Color("262d2f"), Vector2(59, 30), Vector2(4, 2))
	_gura = _dreptunghi(_prezentatoare, Color("5e363e"), Vector2(52, 40), Vector2(8, 2))
	_dreptunghi(fundal, Color("262d2f"), Vector2(0, 80), Vector2(LATIME, 6))           # pupitrul
	# ecranul din spatele ei: „imagini de la fața locului” în mic
	var mic := _dreptunghi(fundal, Color("262d2f"), Vector2(108, 48), Vector2(72, 32))
	_padure(mic, 0.45)
	# imaginile de la fața locului pe tot ecranul (din când în când)
	_teren = Control.new()
	_teren.size = Vector2(LATIME, 86)
	_teren.visible = false
	fundal.add_child(_teren)
	_dreptunghi(_teren, Color("2a3c3d"), Vector2.ZERO, Vector2(LATIME, 86))
	_padure(_teren, 1.0)
	_text(_teren, "TRIVALE FOREST", 8, Color("83b3b0"), Vector2(6, 4))
	# banda de jos: BREAKING NEWS, titlul, textul care curge
	_dreptunghi(fundal, Color("7b383a"), Vector2(0, 86), Vector2(LATIME, 12))
	_text(fundal, "BREAKING NEWS", 7, Color("83b3b0"), Vector2(3, 86))
	_dreptunghi(fundal, Color("83b3b0"), Vector2(66, 86), Vector2(LATIME - 66, 12))
	var t := _text(fundal, titlu, 7, Color("262d2f"), Vector2(69, 86))
	t.clip_text = true
	t.size = Vector2(LATIME - 70, 12)
	_dreptunghi(fundal, Color("262d2f"), Vector2(0, 98), Vector2(LATIME, 14))
	_banda = _text(fundal, banda_jos + banda_jos, 7, Color("a18463"), Vector2(LATIME, 99))
	_dreptunghi(fundal, Color("7b383a"), Vector2(4, 4), Vector2(22, 10))
	_live = _text(fundal, "LIVE", 7, Color("83b3b0"), Vector2(7, 3))
	_text(fundal, "CH 6", 7, Color("83b3b0"), Vector2(LATIME - 26, 4))


## Pădurea în ceață, desenată din brazi (triunghiuri din dreptunghiuri), cu o lumină verde care urcă din ea.
func _padure(parinte: Control, s: float) -> void:
	var w := parinte.size.x
	var h := parinte.size.y
	var r := RandomNumberGenerator.new()
	r.seed = 6
	_dreptunghi(parinte, Color("7e8d87"), Vector2(0, 0), Vector2(w, h * 0.55))
	_dreptunghi(parinte, Color("61a19f"), Vector2(w * 0.45, 0), Vector2(w * 0.1, h * 0.7))  # lumina verde
	for i in int(14 * s) + 6:
		var x := r.randf_range(0, w)
		var inalt := r.randf_range(h * 0.3, h * 0.6)
		var baza := h * 0.75 + r.randf_range(-4, 4) * s
		for k in 5:
			var lat := (k + 1) * inalt * 0.07
			_dreptunghi(parinte, Color("32453b") if i % 2 else Color("2a3c3d"), Vector2(x - lat / 2, baza - inalt + k * inalt * 0.18),
				Vector2(lat, inalt * 0.18))
	_dreptunghi(parinte, Color("262d2f"), Vector2(0, h * 0.8), Vector2(w, h * 0.2))


func _process(delta: float) -> void:
	_timp += delta
	# vorbește: gura se deschide în silabe, cu pauze între fraze
	var vorbeste := sin(_timp * 1.45) + 0.55 > 0.0
	_gura.size.y = (2.0 + 3.0 * absf(sin(_timp * 17.0))) if vorbeste else 2.0
	_banda.position.x -= delta * 22.0
	var lat := _banda.get_minimum_size().x * 0.5
	if _banda.position.x < -lat:
		_banda.position.x += lat
	_live.visible = fmod(_timp, 1.2) < 0.8
	# la fiecare ~12 s: 4 s de imagini de la fața locului
	var acum := fmod(_timp, 12.0) > 8.0
	if acum != _la_fata_locului:
		_la_fata_locului = acum
		_teren.visible = acum
		_prezentatoare.visible = not acum
	# lumina din cameră pâlpâie cu imaginea
	var tinta := (0.45 if acum else 0.65) + sin(_timp * 9.0) * 0.04 + (randf() * 0.06 if randf() < 0.1 else 0.0)
	_lumina.light_energy = lerpf(_lumina.light_energy, tinta, 1.0 - exp(-delta * 10.0))
