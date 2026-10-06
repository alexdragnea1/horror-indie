extends Node3D
## O mașină de spălat din spălătorie (`masina_spalat.tscn`, modelul `masina_spalat.glb`). Cu `merge` bifat: tamburul
## se învârte (încet într-o parte, apoi în cealaltă, din când în când centrifughează), carcasa tremură, afișajul
## strălucește și se aude huruitul (3D). `usa_deschisa` = ușa stă deschisă (mașină liberă).

@export var merge := false
@export var usa_deschisa := false
## Cât de deschisă e ușa (grade).
@export var unghi_usa := 105.0
@export var sunet: AudioStream = preload("res://sunete/masina_spalat.ogg")

var _tambur: Node3D
var _corp: Node3D
var _usa: Node3D
var _afisaj: GeometryInstance3D
var _timp := 0.0
var _viteza := 0.0
var _viteza_dorita := 3.0
var _pana_la_schimbare := 3.0


func _ready() -> void:
	_tambur = find_child("Tambur", true, false) as Node3D
	_corp = $Model
	_usa = find_child("Usa", true, false) as Node3D
	_afisaj = find_child("Afisaj", true, false) as GeometryInstance3D
	_timp = randf() * 10.0
	if usa_deschisa and _usa:
		_usa.rotation.y = deg_to_rad(-unghi_usa)
	if _afisaj:
		_afisaj.set_instance_shader_parameter("stralucire", 1.4 if merge else 0.0)
	if merge:
		var p := AudioStreamPlayer3D.new()
		p.stream = sunet
		p.volume_db = Sunet.VOLUM_AMBIANTA + 2.0
		p.unit_size = 2.0
		p.max_distance = 18.0
		p.bus = &"Ambianta"
		p.autoplay = true
		add_child(p)
		p.position.y = 0.5
		p.pitch_scale = randf_range(0.92, 1.08)
	set_process(merge)


func _process(delta: float) -> void:
	_timp += delta
	_pana_la_schimbare -= delta
	if _pana_la_schimbare <= 0.0:
		# spălatul: câteva secunde într-o parte, o pauză, apoi în cealaltă; uneori centrifugă
		if randf() < 0.15:
			_viteza_dorita = 22.0 * signf(_viteza_dorita + 0.01)
			_pana_la_schimbare = randf_range(4.0, 7.0)
		elif absf(_viteza_dorita) > 0.5:
			_viteza_dorita = 0.0
			_pana_la_schimbare = randf_range(0.8, 1.5)
		else:
			_viteza_dorita = randf_range(2.5, 3.5) * (1.0 if randf() < 0.5 else -1.0)
			_pana_la_schimbare = randf_range(3.0, 5.0)
	_viteza = move_toward(_viteza, _viteza_dorita, delta * 6.0)
	if _tambur:
		_tambur.rotate_object_local(Vector3.FORWARD, _viteza * delta)
	# carcasa tremură mai tare la centrifugă
	var tremur := 0.0012 + absf(_viteza) * 0.00012
	_corp.position = Vector3(sin(_timp * 41.0) * tremur, absf(sin(_timp * 37.0)) * tremur * 0.6, cos(_timp * 33.0) * tremur * 0.5)
