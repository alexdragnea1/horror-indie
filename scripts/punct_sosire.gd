class_name PunctSosire
extends Marker3D
## Unde apari când intri în scenă pe o ușă (UsaScena cu `sosire` = numele nodului ăstuia), cu fața încotro privește
## markerul (-Z, ca jucătorul). La Continue nu face nimic: rămâi unde te-a salvat jocul.


func _ready() -> void:
	if UsaScena.sosire_urmatoare != name:
		return
	UsaScena.sosire_urmatoare = ""
	await get_tree().process_frame
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	if jucator == null:
		return
	jucator.global_position = global_position
	jucator.rotation.y = global_rotation.y
	jucator.get_node("Cap").rotation.x = 0.0
