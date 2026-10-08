class_name Cutscena
extends CanvasLayer
## O scenă „de film” la persoana întâi (cazanul, zborul pe mătură): benzi negre sus și jos, jucătorul nu se mai
## mișcă și nu se mai uită singur în jur (Stare.meniu_deschis), iar camera o întorci din cod spre ce trebuie văzut.
##   var c := Cutscena.porneste(self)
##   await c.priveste(punct, 0.8)
##   c.opreste()
## Dacă se schimbă scena (Tranzitie), benzile pleacă odată cu ea; `opreste()` nu mai e nevoie.

## Cât din înălțimea ecranului acoperă fiecare bandă.
const BANDA := 0.11

var _sus: ColorRect
var _jos: ColorRect
var _jucator: Node3D
var _cap: Node3D


static func porneste(nod: Node) -> Cutscena:
	var c := Cutscena.new()
	nod.get_tree().current_scene.add_child(c)
	return c


func _ready() -> void:
	layer = 9  # sub dialog (10), peste HUD (5): replicile se văd peste benzi
	_jucator = get_tree().get_first_node_in_group("jucator") as Node3D
	if _jucator:
		_cap = _jucator.get_node("Cap")
	Stare.meniu_deschis = true
	_sus = _banda(true)
	_jos = _banda(false)
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_sus, "anchor_bottom", BANDA, 0.6)
	tween.tween_property(_jos, "anchor_top", 1.0 - BANDA, 0.6)


func _banda(sus: bool) -> ColorRect:
	var b := ColorRect.new()
	b.color = Color.BLACK
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.anchor_left = 0.0
	b.anchor_right = 1.0
	b.anchor_top = 0.0 if sus else 1.0
	b.anchor_bottom = 0.0 if sus else 1.0
	add_child(b)
	return b


## Întoarce privirea jucătorului (corpul pe orizontală, capul pe verticală) spre `punct`, în `durata` secunde.
func priveste(punct: Vector3, durata: float) -> void:
	if _jucator == null:
		return
	var ochi := _cap.global_position
	var d := punct - ochi
	var unghi := atan2(-d.x, -d.z)  # jucătorul privește spre -Z
	var sus := atan2(d.y, Vector2(d.x, d.z).length())
	await roteste(unghi, sus, durata)


## Ca `priveste`, dar cu unghiurile date direct (radiani): `unghi` pe orizontală, `sus` = cât ridici capul.
func roteste(unghi: float, sus: float, durata: float) -> void:
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# pornește de la unghiul de acum, fixat: dacă trece de ±180°, Godot îl poate citi după un cadru cu ±360°, iar un
	# tween_property ar porni de acolo și camera ar face o tură întreagă (se vedea la ceaunul de acasă)
	var start := _jucator.rotation.y
	tween.tween_method(func(v: float) -> void: _jucator.rotation.y = v, start, start + angle_difference(start, unghi),
		durata)
	tween.tween_property(_cap, "rotation:x", clampf(sus, deg_to_rad(-85), deg_to_rad(85)), durata)
	await tween.finished


## Scoate benzile și îi dă jucătorului controlul înapoi.
func opreste() -> void:
	Stare.meniu_deschis = false
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_sus, "anchor_bottom", 0.0, 0.5)
	tween.tween_property(_jos, "anchor_top", 1.0, 0.5)
	await tween.finished
	queue_free()
