extends Interactabil
## Parry Hotter (owner 12.10), în debaraua de sub scara din stânga a conacului (conac_interior.tscn): stă pe marginea
## patului și citește la lumânare. `om` = OmLaMasa (parry_hotter.glb, micșorat: e un copil), `carte` = punctul în care
## se uită cât citește. E → ridică ochii spre tine, replicile owner-ului, apoi se întoarce la carte. Fără cutscene.

@export var om: Node3D
@export var carte: Node3D

var _vorbeste := false


func _ready() -> void:
	if replici.is_empty():
		replici = PackedStringArray(["Parry Hotter: Hey, get out of my room!", "You: ..."])
	if indiciu == "[E] Examine":
		indiciu = "[E] Talk"
	_la_carte()


func _la_carte() -> void:
	if om:
		om.set("privire", carte)


func poate_fi_folosit() -> bool:
	return activ and not _vorbeste


func interactioneaza() -> void:
	if not poate_fi_folosit() or Dialog.activ:
		return
	_vorbeste = true
	folosit.emit()
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	if om and jucator:
		om.set("privire", jucator.get_node("Cap"))
	Dialog.spune(replici)
	await Dialog.terminat
	await get_tree().create_timer(0.6).timeout
	_la_carte()
	_vorbeste = false
