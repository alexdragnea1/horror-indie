extends Node
## Slăbănogul de la sala „Iron Pump” (sala.tscn, owner 25.11): stă în fața oglinzii și ridică, pe rând, câte o
## ganteră roz de 1 kg (gantera_roz.glb, în palme), încet și cu chinul unuia care ridică 50 (mâna tremură sus,
## icnește). Modelul e slabanog_sala.glb (OmLaMasa); se uită drept înainte, în oglindă.

@export var om: OmLaMasa
## Unde ajunge palma sus (față de om: x în afară, y în sus, z în față; D = -X).
@export var sus := Vector3(0.2, 1.3, 0.16)
@export var pauza := Vector2(0.6, 1.6)

const GANTERA := preload("res://models/gantera_roz.glb")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")
const SUNETE_ICNET := [preload("res://sunete/om_icnit_1.ogg"), preload("res://sunete/om_icnit_2.ogg")]


func _ready() -> void:
	await get_tree().process_frame
	for l in ["D", "S"]:
		var g := GANTERA.instantiate() as Node3D
		g.set_script(SCRIPT_MODEL)
		g.set("material", MATERIAL)
		om.nod_mana(l).add_child(g)
	_ciclu()


func _ciclu() -> void:
	var l := "D"
	while is_inside_tree():
		var s := -1.0 if l == "D" else 1.0
		var tinta := Node3D.new()
		om.add_child(tinta)
		tinta.position = Vector3(sus.x * s, sus.y, sus.z)
		await om.du_mana(l, tinta, randf_range(1.3, 1.7))
		Sunet.reda_la(SUNETE_ICNET.pick_random(), om.gura(), Sunet.VOLUM_EFECTE - 14.0, 0.1, 1.35)
		# tremură sus (1 kg!)
		for k in 6:
			tinta.position = Vector3(sus.x * s + randf_range(-0.012, 0.012), sus.y + randf_range(-0.015, 0.01), sus.z)
			await get_tree().create_timer(0.07).timeout
		await om.lasa_mana(l, 1.0)
		tinta.queue_free()
		await get_tree().create_timer(randf_range(pauza.x, pauza.y)).timeout
		l = "S" if l == "D" else "D"
