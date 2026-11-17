extends Node3D
## O vacă care paște în ceață, departe (primarie.tscn, owner 17.11: „o vacă sau două în depărtare, în ceață”):
## modelul `Model` (vaca.glb din sat_campuri.py) cu `Cap` (originea în ceafă) și `Coada` (originea la rădăcină).
## Paște: capul jos câteva secunde (rumegă: capul se mișcă puțin), apoi îl ridică și se uită în jur; dă din coadă.
## Fără coliziune: e dincolo de zidurile invizibile.

## Cât de jos își lasă capul să pască (radiani, pe X).
@export var cap_jos := 0.75
@export var saminta := 1

var _cap: Node3D
var _coada: Node3D
var _timp := 0.0
var _r := RandomNumberGenerator.new()


func _ready() -> void:
	_r.seed = saminta
	_timp = _r.randf_range(0.0, 10.0)
	_cap = find_child("Cap", true, false) as Node3D
	_coada = find_child("Coada", true, false) as Node3D
	if _cap:
		_cap.rotation.x = cap_jos
		_paste()


func _process(delta: float) -> void:
	_timp += delta
	if _coada:
		# coada se leagănă încet, iar din când în când o plesnește peste o muscă
		var plesnit := maxf(0.0, sin(_timp * 0.4 + saminta)) ** 12
		_coada.rotation.z = sin(_timp * 1.6) * 0.18 + sin(_timp * 9.0) * 0.4 * plesnit
		_coada.rotation.x = -0.1 + plesnit * 0.3


## Ciclul: paște (capul jos, rumegă) câteva secunde, apoi ridică puțin capul și se uită într-o parte, și iar.
func _paste() -> void:
	while is_inside_tree():
		var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(_cap, "rotation", Vector3(cap_jos, _r.randf_range(-0.2, 0.2), 0.0), 1.4)
		for k in _r.randi_range(4, 8):
			t.tween_property(_cap, "rotation:x", cap_jos + 0.06, 0.45)
			t.tween_property(_cap, "rotation:x", cap_jos, 0.45)
		t.tween_property(_cap, "rotation", Vector3(_r.randf_range(-0.1, 0.15), _r.randf_range(-0.5, 0.5), 0.0), 1.6)
		t.tween_interval(_r.randf_range(2.0, 4.5))
		await t.finished
