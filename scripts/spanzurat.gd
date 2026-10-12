extends Node3D
## Un om spânzurat de mâini în camera de tortură din subsolul conacului (owner 12.10, conac_interior.tscn, `Spanzurati`).
## Nodul stă în cârligul grinzii (unde se termină frânghia); copilul `Model` = spanzurat_N.glb (casino_oameni.om, cu
## frânghia până la 2,28 m deasupra tălpilor, deci `Model` e la y = -2,28). Se leagănă încet și se răsucește pe frânghie,
## capul îi atârnă în piept; din când în când geme și ridică puțin capul (mai des când ești aproape).

@export var gemete: Array[AudioStream] = []
@export var volum := -12.0
## Cât de des geme (secunde, între cele două valori).
@export var pauza_geamat := Vector2(7.0, 18.0)

var _cap: Node3D
var _timp := 0.0
var _faza := 0.0
var _pana_la_geamat := 0.0
var _ridicat := 0.0


func _ready() -> void:
	_cap = find_child("Cap", true, false) as Node3D
	_faza = randf() * TAU
	_pana_la_geamat = randf_range(2.0, pauza_geamat.y)


func _process(delta: float) -> void:
	_timp += delta
	var t := _timp + _faza
	# legănatul pe frânghie: puțin înainte-înapoi și într-o parte, plus o răsucire lentă
	rotation = Vector3(sin(t * 0.8) * 0.03, sin(t * 0.21) * 0.4, sin(t * 0.63 + 1.0) * 0.025)
	# capul atârnă în piept; când geme îl ridică puțin, apoi îl lasă iar
	_ridicat = move_toward(_ridicat, 0.0, delta * 0.35)
	if _cap:
		_cap.rotation.x = lerpf(0.5, 0.08, ease(_ridicat, 0.5)) + sin(t * 1.3) * 0.02
	_pana_la_geamat -= delta
	if _pana_la_geamat <= 0.0:
		var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
		var aproape := jucator != null and jucator.global_position.distance_to(global_position) < 5.0
		_pana_la_geamat = randf_range(pauza_geamat.x, pauza_geamat.y) * (0.6 if aproape else 1.0)
		if not gemete.is_empty() and _cap:
			Sunet.reda_la(gemete.pick_random(), _cap.global_position, volum, 0.0, randf_range(0.78, 0.92))
		_ridicat = 1.0
