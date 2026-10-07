class_name CapTinta
extends CollisionShape3D
## Capul ca țintă pentru gloanțe. Formele fixe ale personajelor (capsule, cutii) nu țin pasul cu capul când se
## apleacă sau se uită în jur, așa că un glonț în cap trecea uneori pe lângă (Lexy la masă, vrăjitoarele aplecate
## peste cazan). Sfera asta e un copil al corpului care primește `impuscat` și stă pe cap la fiecare cadru de fizică.
## Se oprește odată cu celelalte forme ale corpului (`disabled`), deci nu trebuie oprită separat la moarte.

## Nodul capului din model (originea în gât, ca `Cap` din tools/blender).
var cap: Node3D
## Cât de sus e centrul capului față de gât (în coordonatele capului, deci se apleacă odată cu el).
var sus := 0.16


## Pune o sferă de `raza` metri pe capul `cap` al corpului `corp`. Întoarce null dacă nu are ce urmări.
static func adauga(corp: Node, cap_model: Node3D, raza := 0.12) -> CapTinta:
	if not (corp is CollisionObject3D) or cap_model == null:
		return null
	var t := CapTinta.new()
	t.name = "CapTinta"
	t.cap = cap_model
	var sfera := SphereShape3D.new()
	sfera.radius = raza
	t.shape = sfera
	corp.add_child(t)
	return t


func _ready() -> void:
	_urmareste()


func _physics_process(_delta: float) -> void:
	_urmareste()


func _urmareste() -> void:
	if is_instance_valid(cap) and cap.is_inside_tree():
		global_position = cap.global_transform * Vector3(0.0, sus, 0.0)
