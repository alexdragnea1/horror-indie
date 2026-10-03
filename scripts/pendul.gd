extends Node3D
## Se leagănă ușor, ca un bec atârnat de fir (umbrele se mișcă și ele, efect bun de horror).
## Originea nodului = punctul de prindere (tavanul).

## Cât de mult se leagănă (grade).
@export var amplitudine_grade := 2.5
## Cât de repede se leagănă.
@export var viteza := 0.8

var _timp := randf() * 10.0


func _process(delta: float) -> void:
	_timp += delta * viteza
	var a := deg_to_rad(amplitudine_grade)
	rotation = Vector3(sin(_timp) * a, 0.0, sin(_timp * 0.73 + 1.3) * a * 0.6)
