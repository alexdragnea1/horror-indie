extends Node3D
## O vrăjitoare din cercul din jurul cazanului (scenes/vrajitoare.tscn). Stă aplecată spre cazan cu brațele
## întinse peste el și descântă: se leagănă, mâinile fac cercuri mici, capul se uită în cazan.
## La vrajă (cazan.gd) își ridică brațele și capul spre cer: ridica_bratele(true / false).
## Modelul are `Brate` (originea între umeri) și `Cap` (originea în gât), vezi tools/blender/coven.py.

## Ca să nu se miște toate la fel (secunde).
@export var faza := 0.0
## Cât de repede descântă.
@export var viteza := 1.0

var _timp := 0.0
var _ridicare := 0.0  # 0 = peste cazan, 1 = brațele la cer
var _tween: Tween

@onready var _model: Node3D = $Model
@onready var _brate: Node3D = $Model/Brate
@onready var _cap: Node3D = $Model/Cap


func _ready() -> void:
	_timp = faza


func _process(delta: float) -> void:
	_timp += delta * viteza
	# se leagănă încet, din tot corpul
	_model.rotation.z = sin(_timp * 0.8) * 0.035
	_model.rotation.x = sin(_timp * 0.55 + 1.0) * 0.02
	# mâinile fac cercuri mici peste cazan; la vrajă urcă spre cer (-X = în sus pentru brațele întinse înainte)
	var cerc := Vector2(sin(_timp * 1.7), cos(_timp * 1.7)) * 0.07 * (1.0 - _ridicare * 0.5)
	_brate.rotation = Vector3(cerc.y - _ridicare * 1.25, cerc.x * 0.6, 0.0)
	# capul: în cazan, apoi pe spate, spre cer
	_cap.rotation = Vector3(0.25 - _ridicare * 0.75 + sin(_timp * 1.1) * 0.04, sin(_timp * 0.4) * 0.12, sin(_timp * 0.7) * 0.06)


func ridica_bratele(sus: bool, durata := 0.8) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "_ridicare", 1.0 if sus else 0.0, durata)
