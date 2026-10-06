extends Node3D
## Învârte la nesfârșit copilul `piesa` (căutat după nume în model) în jurul axei Y: ventilatorul din tavan.

@export var piesa := "Pale"
## Rotații pe secundă.
@export var viteza := 0.9

var _nod: Node3D


func _ready() -> void:
	_nod = find_child(piesa, true, false) as Node3D


func _process(delta: float) -> void:
	if _nod:
		_nod.rotate_y(viteza * TAU * delta)
