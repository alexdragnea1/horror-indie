class_name Boombox
extends Node3D
## Boombox-ul bețivului de pe deal. Muzica (`Muzica`, AudioStreamPlayer3D în buclă) se aude după cât de
## aproape ești: nimic de la `departe` metri (cam la jumătatea urcușului), apoi crește până la volum plin
## la `aproape` metri (pe platou). Cu cât ești mai departe, cu atât sună mai înfundat (doar basul trece
## prin pădure): filtrul trece-jos de pe canalul „Boombox” se deschide pe măsură ce te apropii.
## Canalul „Boombox” merge în „Muzica”, deci glisorul Music din setări îl reglează și pe el.
## `ritm` (0..1) = cât de tare bate basul acum: difuzoarele pulsează, iar bețivul dă din cap după el.
## Cu pistolul roz îl strici (`impuscat`): muzica moare ca o casetă mâncată (se îneacă și se oprește), plasticul
## crapă, sar scântei, iese fum, afișajul și lumina se sting, difuzorul lovit se turtește, antena se îndoaie, iar
## boombox-ul sare puțin într-o parte. Marcajul `marcaj_stricat` îl ține stricat și la Continue (fără muzică).

@export var aproape := 14.0
@export var departe := 38.0
## Volumul când ești lângă el: 0 = Sunet.VOLUM_MUZICA, la fel ca efectele (fișierele au toate -20 LUFS).
@export var volum_db := 0.0
## Cât de înfundat se aude de departe (Hz) și cât de deschis de aproape.
@export var filtru_departe := 600.0
@export var filtru_aproape := 16000.0
## Cât de mult se umflă difuzoarele pe bas.
@export var puls_difuzoare := 0.12
## Marcajul pus când îl strici (și, dacă ai nimerit difuzorul stâng, `marcaj_stricat + "_s"`, ca să rămână turtit același).
@export var marcaj_stricat := "boombox_stricat"
## Cât de repede moare muzica după glonț (secunde).
@export var durata_moarte_muzica := 0.7

const CANAL := &"Boombox"
const SUNET_STRICAT := preload("res://sunete/boombox_stricat.ogg")
## Cum rămâne după glonț: difuzorul turtit, antena îndoită, boombox-ul împins (față de cum stătea).
const DIFUZOR_TURTIT := Vector3(0.92, 0.92, 0.25)
const ANTENA_INDOITA := Vector3(0.3, 0.0, -1.5)
const SARITURA := Vector3(0.0, 0.0, -0.07)
const ROTIRE_SARITURA := Vector3(0.0, 0.3, 0.04)

var stricat := false

var ritm := 0.0

@onready var _muzica: AudioStreamPlayer3D = $Muzica
@onready var _difuzoare: Array[Node3D] = [$Model/DifuzorS, $Model/DifuzorD]
@onready var _afisaj: MeshInstance3D = $Model/Afisaj
@onready var _lumina: OmniLight3D = $Lumina
@onready var _antena: Node3D = $Model/Antena

var _canal := -1
var _energie_lumina := 0.0


func _ready() -> void:
	_canal = AudioServer.get_bus_index(CANAL)
	_muzica.bus = CANAL
	_muzica.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	_muzica.panning_strength = 0.5
	_energie_lumina = _lumina.light_energy
	if Stare.e_marcat(marcaj_stricat):
		_strica_pe_loc(Stare.e_marcat(marcaj_stricat + "_s"))
		return
	_actualizeaza_volum()
	# pornește de la un loc oarecare din piesă: el ascultă de mult, nu de când ai venit tu
	_muzica.play(randf() * 120.0)


func _process(delta: float) -> void:
	if stricat:
		ritm = lerpf(ritm, 0.0, 1.0 - exp(-delta * 6.0))
		return
	_actualizeaza_volum()
	# basul (40-160 Hz) de pe canal, fără volumul nostru, ca pulsul să nu depindă de cât de departe ești
	var bas := 0.0
	if _canal >= 0 and _muzica.volume_db > -60.0:
		var analizor := AudioServer.get_bus_effect_instance(_canal, 1) as AudioEffectSpectrumAnalyzerInstance
		if analizor:
			bas = analizor.get_magnitude_for_frequency_range(40.0, 160.0).length() / db_to_linear(_muzica.volume_db)
	var tinta := clampf((linear_to_db(maxf(bas, 0.00001)) + 30.0) / 15.0, 0.0, 1.0)
	# urcă repede pe lovitură, coboară încet
	ritm = lerpf(ritm, tinta, 1.0 - exp(-delta * (25.0 if tinta > ritm else 6.0)))
	var umflare := ritm * puls_difuzoare
	for d in _difuzoare:
		# conul iese în față (+Z) mai mult decât se lărgește
		d.scale = Vector3(1.0 + umflare, 1.0 + umflare, 1.0 + umflare * 3.0)
	_afisaj.set_instance_shader_parameter("stralucire", 0.6 + ritm * 0.8)
	_lumina.light_energy = _energie_lumina * (0.85 + ritm * 0.3)


func _actualizeaza_volum() -> void:
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	var d := INF if jucator == null else global_position.distance_to(jucator.global_position)
	var cat := 1.0 - smoothstep(aproape, departe, d)
	_muzica.volume_db = volum_db + linear_to_db(maxf(cat, 0.0001))
	if _canal >= 0:
		var filtru := AudioServer.get_bus_effect(_canal, 0) as AudioEffectLowPassFilter
		if filtru:
			filtru.cutoff_hz = lerpf(filtru_departe, filtru_aproape, cat * cat)


## Glonțul din pistol (pistol.gd). `punct` = unde a lovit: difuzorul cel mai apropiat se turtește.
func impuscat(_directie: Vector3, punct := Vector3.ZERO) -> void:
	if stricat:
		return
	var stang := punct.distance_to(_difuzoare[0].global_position) < punct.distance_to(_difuzoare[1].global_position)
	Stare.marcheaza(marcaj_stricat)
	if stang:
		Stare.marcheaza(marcaj_stricat + "_s")
	stricat = true
	Sunet.reda_la(SUNET_STRICAT, global_position + Vector3.UP * 0.2, Sunet.VOLUM_EFECTE, 0.05)
	# muzica se îneacă: caseta încetinește și se stinge
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_muzica, "pitch_scale", 0.25, durata_moarte_muzica)
	tw.tween_property(_muzica, "volume_db", _muzica.volume_db - 30.0, durata_moarte_muzica)
	tw.chain().tween_callback(_muzica.stop)
	# afișajul și lumina pâlpâie de câteva ori și se sting
	var stingere := create_tween()
	for i in 4:
		stingere.tween_callback(_aprins.bind(false))
		stingere.tween_interval(randf_range(0.05, 0.12))
		stingere.tween_callback(_aprins.bind(true))
		stingere.tween_interval(randf_range(0.04, 0.15))
	stingere.tween_callback(_aprins.bind(false))
	# sare puțin înapoi, difuzorul se turtește, antena se îndoaie
	var difuzor := _difuzoare[0] if stang else _difuzoare[1]
	var miscare := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	miscare.tween_property(self, "global_position", global_position + global_transform.basis * SARITURA, 0.25)
	miscare.tween_property(self, "rotation", rotation + ROTIRE_SARITURA * (1.0 if stang else -1.0), 0.25)
	miscare.tween_property(difuzor, "scale", DIFUZOR_TURTIT, 0.08)
	miscare.tween_property(_antena, "rotation", ANTENA_INDOITA, 0.5).set_trans(Tween.TRANS_ELASTIC)
	var gura := difuzor.global_position
	_scantei(gura, 40, 0.0)
	for i in 3:  # mai sar câteva scântei după, din ce în ce mai puține
		_scantei(gura, 12 - i * 3, 0.5 + i * 0.6 + randf() * 0.3)
	_fum(gura)


## La Continue: e deja stricat, tăcut, cu difuzorul turtit și antena îndoită.
func _strica_pe_loc(stang: bool) -> void:
	stricat = true
	_muzica.stop()
	_aprins(false)
	(_difuzoare[0] if stang else _difuzoare[1]).scale = DIFUZOR_TURTIT
	_antena.rotation = ANTENA_INDOITA
	position += global_transform.basis * SARITURA
	rotation += ROTIRE_SARITURA * (1.0 if stang else -1.0)


func _aprins(da: bool) -> void:
	_afisaj.set_instance_shader_parameter("stralucire", 1.2 if da else 0.0)
	_lumina.visible = da


func _scantei(unde: Vector3, cate: int, intarziere: float) -> void:
	if intarziere > 0.0:
		await get_tree().create_timer(intarziere).timeout
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.02, 0.08)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	quad.material = mat
	p.mesh = quad
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1.6, 1.5, 1.0), Color(1.4, 0.7, 0.2), Color(0.6, 0.15, 0.0, 0.0)])
	p.color_ramp = gradient
	p.one_shot = true
	p.amount = cate
	p.lifetime = 0.6
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	get_tree().current_scene.add_child(p)
	p.global_position = unde
	p.emitting = true
	# o clipă de lumină galbenă la fiecare scânteiere
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.8, 0.4)
	l.light_energy = 2.5 * cate / 40.0 + 0.6
	l.omni_range = 2.5
	p.add_child(l)
	create_tween().tween_property(l, "light_energy", 0.0, 0.15)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


## Fum gri care iese încet din difuzorul spart câteva secunde.
func _fum(unde: Vector3) -> void:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.1
	var mat := StandardMaterial3D.new()
	# rotocoale moi, nu pătrate
	var pata := GradientTexture2D.new()
	pata.fill = GradientTexture2D.FILL_RADIAL
	pata.fill_from = Vector2(0.5, 0.5)
	pata.fill_to = Vector2(0.5, 0.0)
	pata.gradient = Gradient.new()
	pata.gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	mat.albedo_texture = pata
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat
	p.mesh = quad
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.44, 0.44, 0.43, 0.0), Color(0.44, 0.44, 0.43, 0.4), Color(0.3, 0.3, 0.3, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	p.color_ramp = gradient
	p.amount = 24
	p.lifetime = 2.5
	p.direction = Vector3.UP
	p.spread = 15.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.45
	p.gravity = Vector3(0.05, 0.15, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.6
	var crestere := Curve.new()
	crestere.add_point(Vector2(0, 0.5))
	crestere.add_point(Vector2(1, 2.2))
	p.scale_amount_curve = crestere
	get_tree().current_scene.add_child(p)
	p.global_position = unde
	p.emitting = true
	await get_tree().create_timer(7.0).timeout
	p.emitting = false
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)
