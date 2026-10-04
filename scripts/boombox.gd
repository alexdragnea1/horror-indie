class_name Boombox
extends Node3D
## Boombox-ul bețivului de pe deal. Muzica (`Muzica`, AudioStreamPlayer3D în buclă) se aude după cât de
## aproape ești: nimic de la `departe` metri (cam la jumătatea urcușului), apoi crește până la volum plin
## la `aproape` metri (pe platou). Cu cât ești mai departe, cu atât sună mai înfundat (doar basul trece
## prin pădure): filtrul trece-jos de pe canalul „Boombox” se deschide pe măsură ce te apropii.
## Canalul „Boombox” merge în „Muzica”, deci glisorul Music din setări îl reglează și pe el.
## `ritm` (0..1) = cât de tare bate basul acum: difuzoarele pulsează, iar bețivul dă din cap după el.

@export var aproape := 14.0
@export var departe := 38.0
## Volumul când ești lângă el: 0 = Sunet.VOLUM_MUZICA, la fel ca efectele (fișierele au toate -20 LUFS).
@export var volum_db := 0.0
## Cât de înfundat se aude de departe (Hz) și cât de deschis de aproape.
@export var filtru_departe := 600.0
@export var filtru_aproape := 16000.0
## Cât de mult se umflă difuzoarele pe bas.
@export var puls_difuzoare := 0.12

const CANAL := &"Boombox"

var ritm := 0.0

@onready var _muzica: AudioStreamPlayer3D = $Muzica
@onready var _difuzoare: Array[Node3D] = [$Model/DifuzorS, $Model/DifuzorD]
@onready var _afisaj: MeshInstance3D = $Model/Afisaj
@onready var _lumina: OmniLight3D = $Lumina

var _canal := -1
var _energie_lumina := 0.0


func _ready() -> void:
	_canal = AudioServer.get_bus_index(CANAL)
	_muzica.bus = CANAL
	_muzica.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	_muzica.panning_strength = 0.5
	_energie_lumina = _lumina.light_energy
	_actualizeaza_volum()
	# pornește de la un loc oarecare din piesă: el ascultă de mult, nu de când ai venit tu
	_muzica.play(randf() * 120.0)


func _process(delta: float) -> void:
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
