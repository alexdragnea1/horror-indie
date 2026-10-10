class_name Civil
extends Node3D
## Un om din piața din City Center (centru.tscn), îngrozit de Head Witch: tremură, se uită la ea, din când în când țipă.
## Modelul e copilul `Model` (models/civil_N.glb, din tools/blender/centru.py; stă în picioare, cu mâinile sus sau la
## gură). Îl omoară intro-ul luptei (lupta_head_witch.gd): `ridica` (îl ia în aer), `omoara` (ragdoll).

const SUNET_TIPAT := preload("res://sunete/om_tipat.ogg")
const SUNETE_ICNIT := [preload("res://sunete/om_icnit_1.ogg"), preload("res://sunete/om_icnit_2.ogg")]

## Spre ce se uită (pus de lupta_head_witch.gd: Head Witch).
var spre: Node3D
## Cât de tare tremură (0..1).
var frica := 1.0
var mort := false

var _model: Node3D
var _cap: Node3D
var _timp := randf() * 10.0
var _pauza_tipat := randf_range(2.0, 7.0)
var _fuga := Vector3.ZERO
var _viteza_fuga := 0.0


func _ready() -> void:
	_model = get_node("Model")
	_cap = _model.get_node_or_null("Corp/Cap")


func _process(delta: float) -> void:
	if mort:
		return
	_timp += delta
	if _viteza_fuga > 0.0:
		# fuge: aplecat în față, sare din pas în pas
		var d := _fuga - global_position
		d.y = 0.0
		if d.length() > 0.1:
			global_position += d.normalized() * minf(_viteza_fuga * delta, d.length())
		_model.position.y = absf(sin(_timp * 9.0)) * 0.07
		_model.rotation.x = 0.22
		return
	# tremură și se leagănă pe loc, ca cineva care nu știe încotro să fugă
	_model.position.x = sin(_timp * 31.0) * 0.006 * frica
	_model.rotation.z = sin(_timp * 1.7) * 0.03 * frica
	_model.rotation.x = -0.05 * frica + sin(_timp * 23.0) * 0.008 * frica
	if is_instance_valid(spre) and _cap:
		var local := (_cap.get_parent() as Node3D).to_local(spre.global_position + Vector3.UP * 1.6) - _cap.position
		_cap.rotation.y = lerp_angle(_cap.rotation.y, clampf(atan2(local.x, local.z), -0.9, 0.9), delta * 3.0)
		_cap.rotation.x = lerp_angle(_cap.rotation.x, clampf(-atan2(local.y, Vector2(local.x, local.z).length()), -0.5, 0.4), delta * 3.0)
	_pauza_tipat -= delta
	if _pauza_tipat <= 0.0:
		_pauza_tipat = randf_range(5.0, 12.0)
		tipa(-14.0)


func tipa(volum := -6.0) -> void:
	Sunet.reda_la(SUNET_TIPAT, global_position + Vector3.UP * 1.6, Sunet.VOLUM_EFECTE + volum, 0.15)


## O ia la fugă spre `unde` (pe jos, fără coliziuni: e în cutscene), cu `viteza` m/s.
func fugi(unde: Vector3, viteza := 4.0) -> void:
	_fuga = unde
	_viteza_fuga = viteza
	var d := unde - global_position
	rotation.y = atan2(d.x, d.z)
	if _cap:
		_cap.rotation = Vector3.ZERO
	tipa(-4.0)


## Îl ridică în aer (vraja ei): urcă `cat` metri în `durata` s, cu picioarele bălăngănindu-se și corpul răsucit.
func ridica(cat: float, durata: float) -> Tween:
	frica = 2.5
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_model, "position:y", cat, durata)
	t.tween_property(self, "rotation:y", rotation.y + randf_range(-1.2, 1.2), durata)
	return t


## Moare: modelul devine ragdoll, cu brânciul `impuls` (N·s); un icnet. Întoarce ragdoll-ul.
func omoara(impuls: Vector3) -> Ragdoll:
	if mort:
		return null
	mort = true
	Sunet.reda_la(SUNETE_ICNIT.pick_random(), global_position + Vector3.UP * 1.5, Sunet.VOLUM_EFECTE - 2.0, 0.1)
	return Ragdoll.din_model(_model, impuls, [], 30.0)
