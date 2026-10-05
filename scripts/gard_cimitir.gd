extends Interactabil
## Gardul de fier al cimitirului de vizavi de Lexy (nodul `GardCimitir` din casa_lexy.tscn: o cutie peste tot gardul,
## puțin mai groasă decât coliziunea lui, ca raza ta s-o prindă pe ea). Cu Lexy în inventar (LexyMasa),
## „[E] Throw Lexy over the fence” (la persoana întâi, cu benzi negre, ca la cazan):
##   o ții în brațe, culcată, și o arunci peste gard: zboară în arc, se rostogolește, trece de vârfurile gardului
##   (zăngănit), iar de acolo cade ca un ragdoll între gard și primele morminte; te uiți după ea până se oprește.
## Unde a căzut rămâne în salvare (`marcaj_aruncata` cu [x, z, unghi]); la Continue e tot acolo, culcată.

const MODEL := preload("res://models/lexy.glb")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")
## Mijlocul corpului ei față de tălpi (originea modelului).
const MIJLOC := 0.9

@export var marcaj_aruncata := "lexy_peste_gard"
## Poarta (n-o arunci peste ea: e mai înaltă și are crucea deasupra) și cât de lată e.
@export var x_poarta := -6.0
@export var latime_poarta := 3.4
## Până unde poți arunca de-a lungul gardului (limitele străzii).
@export var x_maxim := 14.5
## Vârfurile gardului (înălțimea lui, cu sulițe).
@export var inaltime_gard := 1.65
## Brânciul de la capătul aruncării (N·s pe trunchi): înainte, peste gard, și puțin în jos.
@export var forta := 95.0
@export var sunet_aruncat: AudioStream = preload("res://sunete/vajait.ogg")
@export var sunet_gard: AudioStream = preload("res://sunete/gard_zanganit.ogg")
@export var sunet_cadere: AudioStream = preload("res://sunete/corp_cazut.ogg")

var _in_curs := false


func _ready() -> void:
	indiciu = "[E] Throw Lexy over the fence"
	await get_tree().process_frame
	var loc: Variant = Stare.valoare_marcaj(marcaj_aruncata)
	if loc is Array and loc.size() >= 3:
		_culcata(Vector3(loc[0], 0.0, loc[1]), loc[2])


func poate_fi_folosit() -> bool:
	return not _in_curs and Stare.are_obiect(LexyMasa.ID_CADAVRU)


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	Stare.scoate_obiect(LexyMasa.ID_CADAVRU)
	var jucator := get_tree().get_first_node_in_group("jucator") as CharacterBody3D
	var camera: Camera3D = jucator.get_node("Cap/Camera3D")
	var c := Cutscena.porneste(self)
	jucator.velocity = Vector3.ZERO
	# locul de pe gard din fața ta (nu peste poartă)
	var x := clampf(jucator.global_position.x, -x_maxim, x_maxim)
	if absf(x - x_poarta) < latime_poarta * 0.5:
		x = x_poarta + latime_poarta * 0.5 * (1.0 if x >= x_poarta else -1.0)
	var z_gard := global_position.z
	await c.priveste(Vector3(x, inaltime_gard + 0.3, z_gard + 1.5), 0.6)

	# o ții în brațe, culcată pe spate, de-a curmezișul (capul spre stânga ta)
	var suport := Node3D.new()
	get_tree().current_scene.add_child(suport)
	var model := MODEL.instantiate() as Node3D
	model.set_script(SCRIPT_MODEL)
	model.set("material", MATERIAL)
	suport.add_child(model)
	model.position = Vector3.DOWN * MIJLOC
	_moale(model)
	var dreapta := camera.global_basis.x
	dreapta.y = 0.0
	dreapta = dreapta.normalized()
	var spre_gard := Vector3.BACK  # cimitirul e spre +Z
	# axele modelului: Y (capul) spre stânga ta, Z (fața) în sus, X = Y × Z
	var b0 := Basis((-dreapta).cross(Vector3.UP), -dreapta, Vector3.UP)
	# în aer se dă peste cap o dată, pe lungime
	var b1 := Basis(-dreapta, 2.4) * b0
	var start := camera.global_position + spre_gard * 0.8 + Vector3.DOWN * 0.6
	start.x = lerpf(start.x, x, 0.5)
	var varf := Vector3(x, inaltime_gard + 0.85, z_gard + 0.35)
	suport.global_transform = Transform3D(b0, start)
	model.hide()
	await get_tree().process_frame
	model.show()
	# o ridici puțin, apoi o arunci
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(suport, "global_position", start + Vector3.UP * 0.25 - spre_gard * 0.1, 0.45)
	await t.finished
	Sunet.reda_la(sunet_aruncat, suport.global_position, Sunet.VOLUM_EFECTE - 4.0, 0.05)
	var de_la := suport.global_position
	var q0 := b0.get_rotation_quaternion()
	var q1 := b1.get_rotation_quaternion()
	c.priveste(varf, 0.6)
	t = create_tween()
	t.tween_method(func(v: float) -> void:
		suport.global_position = de_la.lerp(varf, v) + Vector3.UP * sin(v * PI) * 0.35
		suport.global_basis = Basis(q0.slerp(q1, v)), 0.0, 1.0, 0.65)
	await t.finished

	# peste vârfuri: de aici o ia fizica
	Sunet.reda_la(sunet_gard, Vector3(x, inaltime_gard, z_gard), Sunet.VOLUM_EFECTE - 3.0, 0.05)
	var cadavru := Ragdoll.din_model(model, (spre_gard * 0.9 + Vector3.DOWN * 0.2).normalized() * forta)
	suport.queue_free()
	var auzit := false
	var asteptat := 0.0
	while asteptat < 3.5 and not (asteptat > 1.0 and cadavru.s_a_oprit()):
		c.priveste(cadavru.centru(), 0.15)
		if not auzit and cadavru.centru().y < 0.45:
			auzit = true
			Sunet.reda_la(sunet_cadere, cadavru.centru(), Sunet.VOLUM_EFECTE, 0.05)
		await get_tree().create_timer(0.15).timeout
		asteptat += 0.15
	# unde a rămas (la Continue o pui la loc acolo)
	var corp := cadavru.centru()
	var ax := cadavru.trunchi.global_basis.y
	Stare.marcheaza(marcaj_aruncata, [corp.x, corp.z, atan2(ax.x, ax.z)])
	await get_tree().create_timer(0.6).timeout
	_in_curs = false
	await c.opreste()


## Corpul e moale: brațele îi atârnă puțin în lături, picioarele un pic îndoite.
func _moale(model: Node3D) -> void:
	for l in ["D", "S"]:
		var s := -1.0 if l == "D" else 1.0
		var brat := model.find_child("Brat" + l, true, false) as Node3D
		if brat:
			brat.rotation = Vector3(-0.3, 0.0, s * 0.5)
		var antebrat := model.find_child("Antebrat" + l, true, false) as Node3D
		if antebrat:
			antebrat.rotation.x = -0.4
		var coapsa := model.find_child("Coapsa" + l, true, false) as Node3D
		if coapsa:
			coapsa.rotation.x = -0.25 if l == "D" else -0.1
		var gamba := model.find_child("Gamba" + l, true, false) as Node3D
		if gamba:
			gamba.rotation.x = 0.4


## La Continue: e întinsă pe spate unde a căzut (cade de la câțiva centimetri și se așază singură).
func _culcata(punct: Vector3, unghi: float) -> void:
	var suport := Node3D.new()
	get_tree().current_scene.add_child(suport)
	var model := MODEL.instantiate() as Node3D
	model.set_script(SCRIPT_MODEL)
	model.set("material", MATERIAL)
	suport.add_child(model)
	model.position = Vector3.DOWN * MIJLOC
	_moale(model)
	# Y-ul modelului (capul) spre `unghi`, fața în sus
	var cap := Vector3(sin(unghi), 0.0, cos(unghi))
	suport.global_transform = Transform3D(Basis(cap.cross(Vector3.UP), cap, Vector3.UP), punct + Vector3.UP * 0.3)
	await get_tree().process_frame
	Ragdoll.din_model(model, Vector3.ZERO)
	suport.queue_free()
