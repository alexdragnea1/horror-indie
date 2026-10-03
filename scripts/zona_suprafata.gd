extends Area3D
## O zonă în care pașii jucătorului sună altfel (ex. pe covor).
## Pune-i o CollisionShape3D cât suprafața; când ieși, pașii revin la suprafata_implicita a jucătorului.

## Numele suprafeței; jucătorul trebuie să aibă pași pentru ea (vezi jucator.gd).
@export var suprafata := "covor"


func _ready() -> void:
	body_entered.connect(func(corp: Node3D) -> void:
		if corp.is_in_group("jucator"):
			corp.suprafata = suprafata)
	body_exited.connect(func(corp: Node3D) -> void:
		if corp.is_in_group("jucator") and corp.suprafata == suprafata:
			corp.suprafata = corp.suprafata_implicita)
