extends Node3D
## Decorul de afară de la Lexy, pus din cod (aceeași așezare la fiecare pornire, `saminta`):
##  - cimitirul de peste drum (în spatele stației): morminte pe rânduri strâmbe, cruci, copaci morți, cripta în fund;
##  - gardurile de fier: al cimitirului (cu poarta la `x_poarta`) și cel din fața curții lui Lexy (cu golul aleii);
##  - casele vecinilor, în ceață (același model ca a ei, fără coliziune).
## Ca să muți ceva: schimbă numerele de mai jos (z-ul gardurilor, unde e cripta) sau `saminta` (alt cimitir).

@export var saminta := 13
## Gardul cimitirului: pe z, de la x_min la x_max, cu poarta (2,5 m) la x_poarta.
@export var z_gard_cimitir := 19.7
@export var x_poarta := -6.0
@export var cimitir_x := Vector2(-30.0, 30.0)
@export var cimitir_z := Vector2(21.5, 44.0)
@export var cripta := Vector3(2.0, 0.0, 36.0)
## Gardul curții lui Lexy (golul aleii la x = 0).
@export var z_gard_curte := 7.3
@export var curte_x := Vector2(-13.0, 13.0)

const MATERIAL := preload("res://shaders/material_model.tres")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const GARD := preload("res://models/gard_fier.glb")
const POARTA := preload("res://models/poarta_cimitir.glb")
const MORMINTE := [preload("res://models/mormant_1.glb"), preload("res://models/mormant_2.glb"), preload("res://models/mormant_3.glb"),
	preload("res://models/cruce.glb")]
const CRIPTA := preload("res://models/cripta.glb")
const COPACI := [preload("res://models/copac_mort_1.glb"), preload("res://models/copac_mort_2.glb")]
const CASA := preload("res://models/casa_lexy.glb")


func _ready() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = saminta
	# --- gardul cimitirului, cu poarta
	_gard(z_gard_cimitir, cimitir_x.x, cimitir_x.y, x_poarta - 1.5, x_poarta + 1.5, true)
	var poarta := _pune(POARTA, Vector3(x_poarta, 0.0, z_gard_cimitir), 0.0)
	ColiziuneModel.pentru_nod(poarta, false)
	_gard(z_gard_curte, curte_x.x, curte_x.y, -0.9, 0.9, false)
	# --- mormintele: rânduri (cu fața spre stradă), strâmbe, unele căzute într-o parte
	var z := cimitir_z.x
	while z < cimitir_z.y:
		var x := cimitir_x.x + 1.5 + r.randf_range(0.0, 1.0)
		while x < cimitir_x.y - 1.5:
			var langa_cripta := Vector2(x - cripta.x, z - cripta.z).length() < 4.0
			var pe_alee := absf(x - x_poarta) < 1.6
			if not langa_cripta and not pe_alee and r.randf() < 0.78:
				var m: PackedScene = MORMINTE[r.randi_range(0, MORMINTE.size() - 1)]
				var nod := _pune(m, Vector3(x + r.randf_range(-0.3, 0.3), 0.0, z + r.randf_range(-0.3, 0.3)), PI + r.randf_range(-0.12, 0.12))
				nod.rotation.z = r.randf_range(-0.08, 0.08)
				nod.rotation.x = r.randf_range(-0.06, 0.1)
				nod.scale = Vector3.ONE * r.randf_range(0.9, 1.1)
			x += r.randf_range(2.0, 2.8)
		z += r.randf_range(2.6, 3.2)
	_pune(CRIPTA, cripta, PI)
	# --- copaci morți printre morminte și câțiva pe marginea străzii
	for i in 9:
		var p := Vector3(r.randf_range(cimitir_x.x, cimitir_x.y), 0.0, r.randf_range(cimitir_z.x + 1.0, cimitir_z.y))
		var copac := _pune(COPACI[i % 2], p, r.randf_range(0.0, TAU))
		copac.scale = Vector3.ONE * r.randf_range(0.8, 1.25)
	# --- casele vecinilor, în ceață
	_pune(CASA, Vector3(-21.0, 0.0, 0.5), 0.08, "Geam")
	_pune(CASA, Vector3(22.5, 0.0, -0.5), -0.06, "Geam")


func _pune(scena: PackedScene, pozitie: Vector3, unghi: float, sticla := "") -> Node3D:
	var nod := scena.instantiate() as Node3D
	nod.set_script(SCRIPT_MODEL)
	nod.set("material", MATERIAL)
	nod.set("sticla", sticla)
	add_child(nod)
	nod.position = pozitie
	nod.rotation.y = unghi
	return nod


## Un șir de bucăți de gard pe z, de la `a` la `b`, cu un gol între `gol_a` și `gol_b`. Coliziune: o cutie subțire.
func _gard(z: float, a: float, b: float, gol_a: float, gol_b: float, inalt: bool) -> void:
	for capete: Vector2 in [Vector2(a, gol_a), Vector2(gol_b, b)]:
		var x := capete.x
		while x < capete.y - 0.1:
			var bucata := _pune(GARD, Vector3(x, 0.0, z), 0.0)
			var lung := minf(2.4, capete.y - x)
			bucata.scale.x = lung / 2.4
			x += 2.4
		var corp := StaticBody3D.new()
		add_child(corp)
		var forma := CollisionShape3D.new()
		var cutie := BoxShape3D.new()
		cutie.size = Vector3(capete.y - capete.x, 1.6 if inalt else 1.5, 0.12)
		forma.shape = cutie
		corp.add_child(forma)
		forma.position = Vector3((capete.x + capete.y) * 0.5, cutie.size.y * 0.5, z)
