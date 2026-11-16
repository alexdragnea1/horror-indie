class_name UsaJean
extends UsaScena
## Ușa casei din stânga lui Lexy (a lui Jean, owner 16.11), pusă de afara_lexy.gd. „Press E to knock” → bați la ușă,
## „You: Is there anyone home?”, ușa se deschide singură, scârțâind, și intri (casa_jean.tscn, la `SosireUsa`).
## Originea = balamaua (ca la ușa lui Lexy); `Model` = usa_lexy.glb.

const SUNET_CIOCANIT := preload("res://sunete/usa_ciocanit.ogg")

var _in_curs := false


func _ready() -> void:
	indiciu = "Press %s to knock" % Setari.nume_tasta("interact")


func poate_fi_folosit() -> bool:
	return not _in_curs and super()


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	indiciu = ""
	Sunet.reda_la(SUNET_CIOCANIT, global_position + Vector3.UP * 1.3, Sunet.VOLUM_EFECTE, 0.03)
	await get_tree().create_timer(0.9).timeout
	Dialog.spune(PackedStringArray(["You: Is there anyone home?"]))
	if Dialog.activ:
		await Dialog.terminat
	await get_tree().create_timer(0.7).timeout
	# ușa se deschide încet, singură
	Sunet.reda_la(sunet_usa, global_position, Sunet.VOLUM_EFECTE, 0.05)
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "rotation:y", rotation.y + deg_to_rad(70), 1.4)
	$Coliziune.set_deferred("disabled", true)
	await get_tree().create_timer(0.9).timeout
	folosit.emit()
	sosire_urmatoare = sosire
	Tranzitie.mergi_la(scena, titlu, sunete_tranzitie)
