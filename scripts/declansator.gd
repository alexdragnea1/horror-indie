class_name Declansator
extends Area3D
## Zonă invizibilă: când jucătorul intră în ea se întâmplă ceva din poveste.
## Adaugă-i un CollisionShape3D ca fiu (cutia în care trebuie să intre jucătorul).

signal declansat

## Ce zice personajul când intră în zonă (poate fi gol).
@export_multiline var replici: PackedStringArray = []
## Marcajul pus în "Stare" când se declanșează (gol = niciunul).
@export var marcaj := ""
## Merge doar dacă marcajul ăsta e deja pus (gol = merge oricând).
@export var marcaj_necesar := ""
## Noduri care apar (devin vizibile) când se declanșează.
@export var de_aratat: Array[Node3D] = []
## Noduri care dispar (lumini stinse, obiecte care „nu mai sunt acolo”).
@export var de_ascuns: Array[Node3D] = []
## Debifează dacă vrei să meargă de fiecare dată când intri.
@export var o_singura_data := true

var _gata := false


func _ready() -> void:
	body_entered.connect(_la_intrare)


func _la_intrare(corp: Node3D) -> void:
	if _gata or not corp.is_in_group("jucator"):
		return
	if marcaj_necesar != "" and not Stare.e_marcat(marcaj_necesar):
		return
	# s-a întâmplat deja (ex. înainte de un Continue)
	if o_singura_data and marcaj != "" and Stare.e_marcat(marcaj):
		return
	_gata = o_singura_data
	for nod in de_aratat:
		nod.show()
	for nod in de_ascuns:
		nod.hide()
	if marcaj != "":
		Stare.marcheaza(marcaj)
	declansat.emit()
	if Dialog.activ:
		await Dialog.terminat
	Dialog.spune(replici)
