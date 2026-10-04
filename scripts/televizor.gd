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

const LATIME := 192
const INALTIME := 112

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
