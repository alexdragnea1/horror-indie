class_name VrajaAtac
extends Node3D
## O vrajă de luptă din atacul asupra conacului (atac_conac.gd): un glob de energie care zboară pe un arc, de la `de_la`
## la `la`, în `durata` secunde, cu o dâră în urmă și o lumină care merge cu el. Unde ajunge explodează: un fulger de
## lumină, scântei, flăcări sau energie, fum, pietre care sar, și bubuitura (3D, se aude de departe).
## Culoarea după `fel`: "foc" (portocaliu), "rosu" (vrăjile Warlock-ului), "mov" (vrăjitorii lui), "verde" (vrăjitoarele
## coven-ului). Zborul e socotit pe timp, nu pe coliziuni: lovește exact unde a ales scena.
##   VrajaAtac.trage(self, de_la, la, "mov", 0.8, 1.2)
##   await vraja.lovit

signal lovit(punct: Vector3)

const SUNET_ARUNCA := preload("res://sunete/atac_vraja.ogg")
const SUNET_LOVIT := preload("res://sunete/atac_impact.ogg")
## Cât înfundă distanța sunetul (Godot implicit: -24 dB, care la 40 m lasă doar un huruit). Vezi sunet_la.
const FILTRU_DEPARTE_DB := -6.0
## [miezul, culoarea vrăjii, fumul] pentru fiecare fel.
const CULORI := {
	"foc": [Color(1.0, 0.92, 0.7), Color(1.0, 0.5, 0.18), Color(0.36, 0.3, 0.28)],
	"rosu": [Color(1.0, 0.78, 0.72), Color(0.95, 0.14, 0.1), Color(0.3, 0.13, 0.12)],
	"mov": [Color(0.96, 0.86, 1.0), Color(0.6, 0.28, 0.95), Color(0.24, 0.17, 0.3)],
	"verde": [Color(0.86, 1.0, 0.86), Color(0.28, 0.95, 0.42), Color(0.17, 0.27, 0.2)],
}

var fel := "foc"
var marime := 1.0
var durata := 1.2
## Cât de sus urcă arcul la mijloc (metri).
var arc := 1.5
## Lovește piatra: sar pietre și praf (la conac); altfel doar energie (scutul, oamenii).
var piatra := true
var cu_sunet := true

var _de_la := Vector3.ZERO
var _la := Vector3.ZERO
var _t := 0.0
var _gata := false
var _miez: MeshInstance3D
var _halou: MeshInstance3D
var _lumina: OmniLight3D
var _dara: CPUParticles3D


static func trage(nod: Node, de_la: Vector3, la: Vector3, fel_ := "foc", marime_ := 1.0, durata_ := 1.2, arc_ := 1.5,
		piatra_ := true, sunet_ := true) -> VrajaAtac:
	var v := VrajaAtac.new()
	v.fel = fel_
	v.marime = marime_
	v.durata = durata_
	v.arc = arc_
	v.piatra = piatra_
	v.cu_sunet = sunet_
	v._de_la = de_la
	v._la = la
	nod.get_tree().current_scene.add_child(v)
	v.global_position = de_la
	return v


## Un AudioStreamPlayer3D care se aude de departe (Sunet.reda_la se oprește la 25 m; câmpul de luptă are 50).
## Mixaj de film, nu de simulare: armata stă la 36–42 m de tine, iar la căderea reală (1/distanță) vrăjile, fulgerele și
## teleporturile ei s-ar pierde sub tobe. De aceea `marime_sunet` e mare la cei care cheamă (14–18: la 40 m doar ~7–9 dB
## mai încet decât de aproape) și filtrul de distanță e blând (FILTRU_DEPARTE_DB), ca sunetele să rămână clare, nu înfundate.
static func sunet_la(nod: Node, stream: AudioStream, pozitie: Vector3, volum := 0.0, marime_sunet := 8.0, variatie := 0.08) -> void:
	var s := AudioStreamPlayer3D.new()
	s.stream = stream
	s.bus = &"Efecte"
	s.volume_db = volum
	s.unit_size = marime_sunet
	s.max_distance = 160.0
	s.attenuation_filter_db = FILTRU_DEPARTE_DB
	s.pitch_scale = 1.0 + randf_range(-variatie, variatie)
	s.finished.connect(s.queue_free)
	nod.get_tree().current_scene.add_child(s)
	s.global_position = pozitie
	s.play()


func _ready() -> void:
	var c: Array = CULORI.get(fel, CULORI["foc"])
	_miez = _sfera(0.12 * marime, c[0], false)
	_halou = _sfera(0.3 * marime, Color(c[1], 0.6), true)
	_lumina = OmniLight3D.new()
	_lumina.light_color = c[1]
	_lumina.light_energy = 2.5 * marime
	_lumina.omni_range = 6.0 * marime
	_lumina.omni_attenuation = 1.2
	_lumina.light_volumetric_fog_energy = 2.0
	add_child(_lumina)
	_dara = particule(self, 90, 0.5, 0.22 * marime, [Color(c[0], 0.9), Color(c[1], 0.7), Color(c[2], 0.35), Color(c[2], 0.0)])
	_dara.emission_sphere_radius = 0.1 * marime
	_dara.spread = 180.0
	_dara.initial_velocity_max = 0.4
	_dara.gravity = Vector3(0, 0.6, 0)
	_dara.preprocess = 0.5
	_dara.emitting = true
	if cu_sunet:
		sunet_la(self, SUNET_ARUNCA, _de_la, Sunet.VOLUM_EFECTE, 14.0 * marime, 0.12)


func _sfera(raza: float, culoare: Color, aditiv: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = raza
	s.height = raza * 2.0
	s.radial_segments = 8
	s.rings = 5
	mi.mesh = s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = culoare
	mat.disable_fog = true
	if aditiv:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


static var _textura_moale: GradientTexture2D


## Un cerc moale (alb în mijloc, transparent spre margini), mic și fără netezire, ca la PS2: particulele nu mai sunt pătrate.
static func textura_moale() -> Texture2D:
	if _textura_moale == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
		_textura_moale = GradientTexture2D.new()
		_textura_moale.gradient = g
		_textura_moale.fill = GradientTexture2D.FILL_RADIAL
		_textura_moale.fill_from = Vector2(0.5, 0.5)
		_textura_moale.fill_to = Vector2(1.0, 0.5)
		_textura_moale.width = 16
		_textura_moale.height = 16
	return _textura_moale


## Particule (cercuri moi întoarse spre cameră), cu culorile `culori` (de la naștere la stingere). Pentru dâre, explozii, fum.
static func particule(parinte: Node, cate: int, viata: float, marime_bucata: float, culori: Array) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	# pornește doar când îl aprinde cine l-a cerut (după ce l-a reglat): altfel, în primul cadru, emite cu setările
	# implicite și desenează un pătrat negru la sursă
	p.emitting = false
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * marime_bucata
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.disable_fog = true
	mat.albedo_texture = textura_moale()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.vertex_color_is_srgb = true  # culorile de mai jos sunt cum le vezi (altfel fumul de 0,2 iese gri deschis)
	quad.material = mat
	p.mesh = quad
	p.amount = cate
	p.lifetime = viata
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.1
	var gradient := Gradient.new()
	var offs := PackedFloat32Array()
	for i in culori.size():
		offs.append(float(i) / float(culori.size() - 1))
	gradient.offsets = offs
	gradient.colors = PackedColorArray(culori)
	p.color_ramp = gradient
	var curba := Curve.new()
	curba.add_point(Vector2(0.0, 1.0))
	curba.add_point(Vector2(1.0, 0.35))
	p.scale_amount_curve = curba
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parinte.add_child(p)
	return p


func _process(delta: float) -> void:
	if _gata:
		return
	_t += delta / durata
	var k := minf(_t, 1.0)
	global_position = _de_la.lerp(_la, k) + Vector3.UP * arc * 4.0 * k * (1.0 - k)
	var tremur := 1.0 + sin(Time.get_ticks_msec() * 0.03) * 0.1
	_halou.scale = Vector3.ONE * tremur
	_lumina.light_energy = 2.5 * marime * tremur
	if _t >= 1.0:
		_explodeaza()


func _explodeaza() -> void:
	_gata = true
	var c: Array = CULORI.get(fel, CULORI["foc"])
	_miez.hide()
	_halou.hide()
	_dara.emitting = false
	var spre := (_de_la - _la).normalized()
	if cu_sunet:
		sunet_la(self, SUNET_LOVIT, _la, Sunet.VOLUM_EFECTE, 10.0 * marime, 0.12)
	# energia / flăcările care se umflă și se fac fum
	var foc := particule(self, int(40 * marime) + 10, 0.8, 0.5 * marime, [Color(c[0], 1.0), Color(c[1], 0.9), Color(c[2], 0.6), Color(c[2], 0.0)])
	foc.one_shot = true
	foc.explosiveness = 1.0
	foc.emission_sphere_radius = 0.3 * marime
	foc.spread = 180.0
	foc.direction = spre
	foc.initial_velocity_min = 1.5 * marime
	foc.initial_velocity_max = 5.0 * marime
	foc.damping_min = 3.0
	foc.damping_max = 6.0
	foc.gravity = Vector3(0, 1.5, 0)
	foc.emitting = true
	var scantei := particule(self, int(26 * marime) + 8, 0.7, 0.07, [Color(c[0], 1.0), Color(c[1], 1.0), Color(c[1], 0.0)])
	scantei.one_shot = true
	scantei.explosiveness = 1.0
	scantei.spread = 80.0
	scantei.direction = spre
	scantei.initial_velocity_min = 4.0
	scantei.initial_velocity_max = 10.0 * marime
	scantei.gravity = Vector3(0, -9.0, 0)
	scantei.emitting = true
	if piatra:
		# pietre și praf care sar din zid
		var pietre := particule(self, int(18 * marime) + 6, 1.6, 0.18 * marime, [Color(0.36, 0.33, 0.34), Color(0.3, 0.27, 0.28),
			Color(0.24, 0.22, 0.23)])
		pietre.one_shot = true
		pietre.explosiveness = 1.0
		pietre.spread = 60.0
		pietre.direction = spre
		pietre.initial_velocity_min = 3.0
		pietre.initial_velocity_max = 7.0
		pietre.gravity = Vector3(0, -9.8, 0)
		pietre.emitting = true
		var praf := particule(self, 14, 3.0, 1.6 * marime, [Color(0.2, 0.17, 0.17, 0.5), Color(0.14, 0.12, 0.13, 0.32), Color(0.1, 0.1, 0.11, 0.0)])
		praf.one_shot = true
		praf.explosiveness = 0.9
		praf.emission_sphere_radius = 0.6 * marime
		praf.spread = 180.0
		praf.direction = spre
		praf.initial_velocity_min = 0.5
		praf.initial_velocity_max = 2.0
		praf.damping_min = 1.0
		praf.damping_max = 2.0
		praf.gravity = Vector3(0, 0.4, 0)
		praf.emitting = true
	_lumina.light_energy = 14.0 * marime
	_lumina.omni_range = 14.0 * marime
	var t := create_tween()
	t.tween_property(_lumina, "light_energy", 0.0, 0.6).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	lovit.emit(_la)
	await get_tree().create_timer(3.2).timeout
	queue_free()
