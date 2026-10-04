extends AudioStreamPlayer
## Muzica unui loc (ex. în fața blocului): pornește încet când intri în scenă și merge în buclă
## (bucla vine din importul .ogg-ului: loop = true). Canalul e „Muzica”, deci o reglează
## glisorul Music din setări. Se oprește singură când pleci: Tranzitie stinge sunetul și schimbă scena.
## Dacă scena e doar fundal (meniul principal folosește curtea blocului fără Jucator), tace.

## Cât de tare (aceeași valoare ca muzica din meniul principal: fișierele au toate -20 LUFS).
@export var volum_db := -6.0
## În câte secunde urcă de la liniște la volum_db.
@export var intrare := 4.0


func _ready() -> void:
	bus = &"Muzica"
	if not get_parent().has_node("Jucator"):
		return
	volume_db = -40.0
	play()
	create_tween().tween_property(self, "volume_db", volum_db, intrare)
