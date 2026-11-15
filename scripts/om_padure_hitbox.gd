extends StaticBody3D
## Hitbox-ul omului din pădure (îl face om_padure.gd din cod): pistolul și celelalte arme cheamă `impuscat`
## pe ce lovesc, iar cutia îl trimite omului.

var om: Node


func impuscat(directie: Vector3, punct := Vector3.ZERO) -> void:
	if is_instance_valid(om):
		om.impuscat(directie, punct)


func lovit_de_foc(directie: Vector3, punct := Vector3.ZERO) -> void:
	impuscat(directie, punct)
