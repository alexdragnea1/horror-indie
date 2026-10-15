class_name Graffiti
extends Interactabil
## Peretele cu graffiti (owner 15.10): peretele lateral din dreapta al blocului, lângă cutiile de spray de pe jos
## (`spray_jos.glb`). „[E] Spray paint” → te dai la `distanta` de perete, cu fața la el, și pictezi cu mouse-ul
## (UIGraffiti): click stânga = spray, click dreapta = ștergi, rotița = mărimea jetului, 1–9 = culoarea, Ctrl+Z = undo,
## Esc = gata. Cutia din mână (`spray_mana.glb`) e de culoarea aleasă și se uită spre cursor.
##
## Desenul e o imagine mică (`pixeli_pe_metru`, ca să arate a PS2) pe o placă lipită de perete (`Desen`,
## shaders/graffiti.gdshader). Jetul e ca la un spray adevărat: des în mijloc, rar pe margini; dacă ții pe loc,
## vopseaua se strânge și se scurge în jos. Desenul rămâne în salvare (`Stare.graffiti`, PNG în base64).
##
## Nodul stă pe perete cu axa +Z spre afară (spre jucător); mijlocul nodului = mijlocul desenului.

const SPRAY_MANA := preload("res://models/spray_mana.glb")
const SUNET_SPRAY := preload("res://sunete/spray_bucla.ogg")
const SUNET_AGITAT := preload("res://sunete/spray_agitat.ogg")
const MATERIAL_MODEL := preload("res://shaders/material_model.tres")
## Aceleași culori și în aceeași ordine ca în tools/blender/afara.py (CULORI_SPRAY), toate din paletă.
const CULORI: Array[Color] = [Color("262d2f"), Color("83b3b0"), Color("904a40"), Color("a56850"), Color("a18463"),
	Color("5b6d4e"), Color("438b88"), Color("778c96"), Color("655269")]
## Raza jetului în pixeli de desen, pentru S / M / L.
const RAZE := [1.3, 2.5, 4.5]
## Cât jet primește cel puțin fiecare ștampilă (s): fără el, o linie trasă repede ieșea doar din puncte rare.
const JET_MINIM := 0.012
## Câți pași de undo păstrează (fiecare e o copie a desenului, ~46 KB).
const PASI_UNDO := 25

## Mărimea desenului pe perete (m).
@export var latime := 3.6
@export var inaltime := 2.0
## Câți pixeli are desenul pe metru. Mai puțini = pixeli mai mari (mai „PS2”).
@export var pixeli_pe_metru := 40
## Cât de departe de perete stai cât pictezi (m). Tot desenul trebuie să încapă pe ecran.
@export var distanta := 1.65
## Cât de repede acoperă jetul (mai mare = vopseaua se pune mai repede).
@export var viteza_vopsea := 32.0
## Cât trebuie să ții pe loc până se scurge vopseaua (secunde de jet în același pixel, aproximativ).
@export var prag_scurgere := 0.55
## Replica de la prima folosire (a lui Claude; owner-ul o poate schimba).
@export var replici_prima_data := PackedStringArray(["You: Who leaves free spray paint lying around?"])
@export var marcaj_prima_data := "a_gasit_sprayurile"

var _img: Image
var _tex: ImageTexture
var _desen: MeshInstance3D
var _l := 0
var _h := 0
var _in_curs := false
var _ui: UIGraffiti
var _camera: Camera3D
var _cutie_mana: Node3D
var _culoare := 0
var _marime := 1
## 1 = spray, -1 = ștergi, 0 = nimic apăsat
var _apasat := 0
var _ultimul := Vector2(-1, -1)
var _undo: Array[Image] = []
var _murdar := false
## vopseaua udă: index pixel -> cât s-a strâns (se usucă în timp)
var _ud := {}
## scurgerile care curg acum: {x, y, ramas, viteza, pas, culoare}
var _scurgeri: Array[Dictionary] = []
var _sunet: AudioStreamPlayer3D
var _volum_sunet := -80.0
## Lanterna jucătorului: cât pictezi luminează unde e cursorul (noaptea vezi doar în cercul ei).
var _lanterna: SpotLight3D
var _lanterna_initial: Transform3D


func _ready() -> void:
	indiciu = "[E] Spray paint"
	_l = roundi(latime * pixeli_pe_metru)
	_h = roundi(inaltime * pixeli_pe_metru)
	_img = Image.create_empty(_l, _h, false, Image.FORMAT_RGBA8)
	_incarca(Stare.graffiti)
	_tex = ImageTexture.create_from_image(_img)
	_desen = MeshInstance3D.new()
	_desen.name = "Desen"
	var placa := QuadMesh.new()
	placa.size = Vector2(latime, inaltime)
	_desen.mesh = placa
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/graffiti.gdshader")
	mat.set_shader_parameter("desen", _tex)
	_desen.material_override = mat
	_desen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_desen)
	_sunet = AudioStreamPlayer3D.new()
	_sunet.stream = SUNET_SPRAY
	_sunet.bus = &"Efecte"
	_sunet.unit_size = 3.0
	_sunet.volume_db = -80.0
	add_child(_sunet)
	set_process(false)


func poate_fi_folosit() -> bool:
	return activ and not _in_curs


## Desenul din salvare (PNG în base64); gol sau stricat = perete curat.
func _incarca(date: String) -> void:
	_img.fill(Color(0, 0, 0, 0))
	if date.is_empty():
		return
	var citit := Image.new()
	if citit.load_png_from_buffer(Marshalls.base64_to_raw(date)) != OK:
		return
	citit.convert(Image.FORMAT_RGBA8)
	if citit.get_size() != _img.get_size():
		citit.resize(_l, _h, Image.INTERPOLATE_NEAREST)
	_img.copy_from(citit)


func _salveaza() -> void:
	var gol := _img.is_invisible()
	var date := "" if gol else Marshalls.raw_to_base64(_img.save_png_to_buffer())
	if date != Stare.graffiti:
		Stare.graffiti = date
		Stare.schimbat.emit()  # autosalvarea


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	if not Stare.e_marcat(marcaj_prima_data):
		Stare.marcheaza(marcaj_prima_data)
		Dialog.spune(replici_prima_data)
		await Dialog.terminat
	var jucator := get_tree().get_first_node_in_group("jucator") as CharacterBody3D
	var cap: Node3D = jucator.get_node("Cap")
	_camera = cap.get_node("Camera3D")
	var c := Cutscena.porneste(self)
	jucator.seteaza_purtat(true)
	var fata := global_basis.z.normalized()
	var loc := global_position + fata * distanta
	loc.y = jucator.global_position.y
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(jucator, "global_position", loc, 0.7)
	var d := global_position - (loc + Vector3.UP * cap.position.y)
	await c.roteste(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()), 0.7)
	if t.is_running():
		await t.finished
	c.queue_free()
	# noaptea, fără lanternă, n-ai vedea nimic: o aprinzi (rămâne aprinsă, o stingi cu F ca de obicei)
	_lanterna = _camera.get_node_or_null("Lanterna") as SpotLight3D
	if _lanterna:
		_lanterna_initial = _lanterna.transform
		if not _lanterna.visible:
			_lanterna.visible = true
			Stare.lanterna = true
			Sunet.reda(jucator.get("lanterna_pornita"), Sunet.VOLUM_EFECTE, 0.05)
	Stare.meniu_deschis = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_ia_cutia()
	_ui = UIGraffiti.new(CULORI)
	_ui.culoare_aleasa.connect(_alege_culoarea)
	_ui.marime_aleasa.connect(func(i: int) -> void: _marime = i)
	_ui.marime_schimbata.connect(func(pas: int) -> void:
		_marime = clampi(_marime + pas, 0, RAZE.size() - 1)
		_ui.alege_marimea(_marime))
	_ui.anuleaza.connect(_anuleaza)
	_ui.sterge_tot.connect(_sterge_tot)
	get_tree().current_scene.add_child(_ui)
	_ui.alege_culoarea(_culoare)
	_ui.alege_marimea(_marime)
	_alege_culoarea(_culoare)
	set_process(true)
	await _ui.inchis
	set_process(false)
	_opreste_jetul()
	_volum_sunet = -80.0
	_sunet.stop()
	# scurgerile care încă curgeau se termină pe loc, ca desenul salvat să fie cel final
	while not _scurgeri.is_empty():
		_curg_scurgerile(1.0)
	_ud.clear()
	_tex.update(_img)
	_salveaza()
	_ui.queue_free()
	_ui = null
	_cutie_mana.queue_free()
	_cutie_mana = null
	if _lanterna:
		create_tween().tween_property(_lanterna, "transform", _lanterna_initial, 0.4)
	# un pas înapoi, de perete
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(jucator, "global_position", loc + fata * 0.3, 0.4)
	t.parallel().tween_property(cap, "rotation:x", 0.0, 0.4)
	await t.finished
	jucator.seteaza_purtat(false)
	Stare.meniu_deschis = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_in_curs = false


## Cutia din mână: toate culorile sunt în model (`Spray1` … `Spray9`), se vede doar cea aleasă.
func _ia_cutia() -> void:
	_cutie_mana = SPRAY_MANA.instantiate()
	for m in _cutie_mana.find_children("*", "MeshInstance3D", true, false):
		var mesh := m as MeshInstance3D
		mesh.material_override = MATERIAL_MODEL
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# lipită de cameră, lanterna n-o prinde: strălucește puțin singură
		mesh.set_instance_shader_parameter("stralucire", 0.3)
		mesh.position = Vector3.ZERO
	_camera.add_child(_cutie_mana)
	_cutie_mana.position = Vector3(0.26, -0.25, -0.5)


func _alege_culoarea(i: int) -> void:
	_culoare = i
	if _cutie_mana:
		for m in _cutie_mana.get_children():
			(m as Node3D).visible = m.name == "Spray%d" % (i + 1)
		# o agiți: bila clămpăne, cutia sare de câteva ori
		Sunet.reda_la(SUNET_AGITAT, _camera.global_position, Sunet.VOLUM_EFECTE, 0.05)
		var t := create_tween()
		for k in 5:
			t.tween_property(_cutie_mana, "position:y", -0.2, 0.07)
			t.tween_property(_cutie_mana, "position:y", -0.26, 0.08)


func _unhandled_input(event: InputEvent) -> void:
	if _ui == null or not event is InputEventMouseButton:
		return
	var b := event as InputEventMouseButton
	if b.button_index != MOUSE_BUTTON_LEFT and b.button_index != MOUSE_BUTTON_RIGHT:
		return
	get_viewport().set_input_as_handled()
	if b.pressed and _apasat == 0 and not _ui.pe_panou():
		_apasat = 1 if b.button_index == MOUSE_BUTTON_LEFT else -1
		_ultimul = Vector2(-1, -1)
		_undo.append(_img.duplicate() as Image)
		if _undo.size() > PASI_UNDO:
			_undo.pop_front()
	elif not b.pressed and _apasat == (1 if b.button_index == MOUSE_BUTTON_LEFT else -1):
		_opreste_jetul()


func _opreste_jetul() -> void:
	_apasat = 0
	_ultimul = Vector2(-1, -1)


func _anuleaza() -> void:
	if _undo.is_empty():
		return
	_img.copy_from(_undo.pop_back())
	_scurgeri.clear()
	_ud.clear()
	_murdar = true


func _sterge_tot() -> void:
	_undo.append(_img.duplicate() as Image)
	_img.fill(Color(0, 0, 0, 0))
	_scurgeri.clear()
	_ud.clear()
	_murdar = true


## Unde cade pe desen punctul de pe ecran (în pixeli de desen, poate fi și în afară); null dacă nu nimerește peretele.
func _punct_pe_desen(ecran: Vector2) -> Variant:
	var o := _camera.project_ray_origin(ecran)
	var n := _camera.project_ray_normal(ecran)
	var plan := Plane(global_basis.z.normalized(), global_position)
	var lovit: Variant = plan.intersects_ray(o, n)
	if lovit == null:
		return null
	var local := to_local(lovit)
	return Vector2((local.x / latime + 0.5) * _l, (0.5 - local.y / inaltime) * _h)


func _process(delta: float) -> void:
	var mouse := get_viewport().get_mouse_position()
	var p: Variant = _punct_pe_desen(mouse)
	var raza: float = RAZE[_marime]
	# cursorul: cât e jetul pe ecran (doi pixeli de desen depărtați cu `raza`, proiectați înapoi pe ecran)
	if p != null:
		var a := _camera.unproject_position(_in_lume(p))
		var b := _camera.unproject_position(_in_lume(p + Vector2(raza, 0)))
		_ui.seteaza_cursorul(a.distance_to(b), CULORI[_culoare] if _apasat >= 0 else Color("70706e"))
	if _apasat != 0 and p != null and not _ui.pe_panou():
		var acum: Vector2 = p
		var de_la := acum if _ultimul.x < -0.5 else _ultimul
		_jet(de_la, acum, raza, delta)
		_ultimul = acum
	_curg_scurgerile(delta)
	_usuca(delta)
	# sunetul: șuieră doar cât apeși (la ștergere tace: e o cârpă, nu un spray)
	var tinta := 0.0 if _apasat == 1 and p != null else -80.0
	_volum_sunet = move_toward(_volum_sunet, tinta, delta * (400.0 if tinta > _volum_sunet else 160.0))
	if _volum_sunet > -79.0:
		if not _sunet.playing:
			_sunet.play(randf() * 1.5)
		_sunet.volume_db = _volum_sunet
		if p != null:
			_sunet.global_position = _in_lume(p)
	elif _sunet.playing:
		_sunet.stop()
	_misca_cutia(mouse, delta)
	if _lanterna and p != null:
		var spre := _in_lume(p) - _lanterna.global_position
		var dorit := Basis.looking_at(spre, Vector3.UP)
		_lanterna.global_basis = _lanterna.global_basis.slerp(dorit, minf(1.0, delta * 6.0)).orthonormalized()
	if _murdar:
		_murdar = false
		_tex.update(_img)


func _in_lume(p: Vector2) -> Vector3:
	return to_global(Vector3((p.x / _l - 0.5) * latime, (0.5 - p.y / _h) * inaltime, 0.0))


## Cutia din mână se ține în dreapta-jos și se înclină spre cursor; cât apeși tremură puțin.
func _misca_cutia(mouse: Vector2, delta: float) -> void:
	if _cutie_mana == null:
		return
	var ecran := get_viewport().get_visible_rect().size
	var ndc := (mouse / ecran) * 2.0 - Vector2.ONE
	var tinta := Vector3(0.26 + ndc.x * 0.07, -0.25 - ndc.y * 0.05, -0.5)
	_cutie_mana.position.x = lerpf(_cutie_mana.position.x, tinta.x, minf(1.0, delta * 12.0))
	_cutie_mana.position.z = tinta.z
	# înclinată cu vârful (duza) spre punctul în care pictezi
	var spre := Vector3(ndc.x * 0.6 - 0.35, -ndc.y * 0.5 + 0.15, -1.0).normalized()
	var baza := Basis.looking_at(spre, Vector3.UP)
	# modelul stă în picioare cu duza spre -Z: îl aplecăm puțin în față, spre perete
	baza = baza * Basis(Vector3.RIGHT, -0.35)
	if _apasat == 1:
		baza = baza * Basis(Vector3.FORWARD, randf_range(-0.02, 0.02))
	_cutie_mana.basis = _cutie_mana.basis.slerp(baza.orthonormalized(), minf(1.0, delta * 10.0))


## Jetul de la `a` la `b` (pixeli de desen) în `delta` secunde: ștampile la fiecare jumătate de rază; dacă muți repede,
## fiecare primește mai puțin timp, deci linia iese mai subțire și mai pătată, ca la un spray adevărat.
func _jet(a: Vector2, b: Vector2, raza: float, delta: float) -> void:
	var pasi := maxi(1, ceili(a.distance_to(b) / maxf(raza * 0.5, 0.75)))
	for i in pasi:
		_stampila(a.lerp(b, float(i + 1) / pasi), raza, maxf(delta / pasi, JET_MINIM))


func _stampila(c: Vector2, raza: float, dt: float) -> void:
	var culoare := CULORI[_culoare]
	var sterge := _apasat < 0
	var r_max := raza * (1.15 if sterge else 1.7)
	var x0 := maxi(0, floori(c.x - r_max))
	var x1 := mini(_l - 1, ceili(c.x + r_max))
	var y0 := maxi(0, floori(c.y - r_max))
	var y1 := mini(_h - 1, ceili(c.y + r_max))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c) / raza
			if sterge:
				# cârpa: un disc aproape plin, cu marginea zdrențuită
				if d < 1.0 or randf() < (1.15 - d) * 4.0 * dt * viteza_vopsea:
					_img.set_pixel(x, y, Color(0, 0, 0, 0))
					_murdar = true
				continue
			# jetul: gaussian în mijloc, plus un pic de stropi rari pe margine
			var intensitate := exp(-d * d * 2.2)
			if d > 1.0:
				intensitate = 0.02 * (1.7 - d)
			# miezul jetului se pune mereu: altfel o linie trasă repede ieșea doar din puncte
			if d < 0.45 or randf() < 1.0 - exp(-viteza_vopsea * dt * intensitate):
				_img.set_pixel(x, y, culoare)
				_murdar = true
			if d < 0.6:
				var idx := y * _l + x
				var ud: float = _ud.get(idx, 0.0) + dt * intensitate
				if ud > prag_scurgere and y < _h - 2:
					_scurgeri.append({"x": x, "y": y, "ramas": randi_range(6, 20) * maxf(1.0, raza / 3.0),
						"viteza": randf_range(7.0, 11.0), "pas": 0.0, "culoare": culoare})
					ud = -prag_scurgere * 1.5  # până să mai curgă o dată din același loc trebuie să mai stai mult
				_ud[idx] = ud


## Scurgerile coboară pixel cu pixel, tot mai încet, și se termină cu o picătură.
func _curg_scurgerile(delta: float) -> void:
	for i in range(_scurgeri.size() - 1, -1, -1):
		var s := _scurgeri[i]
		s.pas += s.viteza * delta
		while s.pas >= 1.0 and s.ramas > 0:
			s.pas -= 1.0
			s.y += 1
			s.ramas -= 1
			s.viteza *= 0.93
			if s.y >= _h:
				s.ramas = 0
				break
			_img.set_pixel(s.x, s.y, s.culoare)
			_murdar = true
		if s.ramas <= 0 or s.viteza < 0.6:
			# picătura de la capăt: un pixel mai lat
			if s.y < _h and s.x + 1 < _l:
				_img.set_pixel(s.x + 1, mini(s.y, _h - 1), s.culoare)
			_scurgeri.remove_at(i)
		if delta >= 1.0:
			s.viteza = maxf(s.viteza, 8.0)  # la închidere se termină toate repede


## Vopseaua se usucă: ce s-a strâns într-un pixel scade în timp (altfel orice trecere lentă ar curge).
func _usuca(delta: float) -> void:
	for idx in _ud.keys():
		var v := move_toward(_ud[idx], 0.0, delta * 0.35)
		if is_zero_approx(v):
			_ud.erase(idx)
		else:
			_ud[idx] = v
