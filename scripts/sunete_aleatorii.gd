extends Node3D
## Redă din când în când un sunet la întâmplare din listă: scârțâit de podea,
## ciocănit în pereți, gâlgâitul ceaunului... Nu se repetă același de două ori la rând.

@export var sunete: Array[AudioStream] = []
## Pauza dintre sunete, în secunde (alege la întâmplare între minim și maxim).
@export var pauza_minima := 20.0
@export var pauza_maxima := 50.0
## 0 = volumul comun al efectelor (Sunet.VOLUM_EFECTE).
@export var volum_db := 0.0
## Cât de mult variază înălțimea sunetului (0,1 = ±10%).
@export var variatie := 0.1
## Bifat = sunetul vine dintr-un loc la întâmplare în jurul jucătorului (sperieturi).
## Debifat = vine din locul nodului (ex. ceaunul).
@export var in_jurul_jucatorului := false
@export var distanta_minima := 3.0
@export var distanta_maxima := 8.0

var _pana_la_urmatorul := 0.0
var _ultimul: AudioStream


func _ready() -> void:
	_pana_la_urmatorul = randf_range(pauza_minima, pauza_maxima)


func _process(delta: float) -> void:
	if sunete.is_empty():
		return
	_pana_la_urmatorul -= delta
	if _pana_la_urmatorul > 0.0:
		return
	_pana_la_urmatorul = randf_range(pauza_minima, pauza_maxima)
	var pozitie := global_position
	if in_jurul_jucatorului:
		var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
		if jucator == null:
			return
		var unghi := randf() * TAU
		pozitie = jucator.global_position + Vector3(cos(unghi), 0.0, sin(unghi)) * randf_range(distanta_minima, distanta_maxima)
		pozitie.y += randf_range(0.0, 2.5)  # din podea, din pereți sau din tavan
	var sunet: AudioStream = sunete.pick_random()
	if sunete.size() > 1:
		while sunet == _ultimul:
			sunet = sunete.pick_random()
	_ultimul = sunet
	Sunet.reda_la(sunet, pozitie, volum_db, variatie)
