class_name Cadavre
extends RefCounted
## Cadavrele din inventar (bețivul, vrăjitoarele din cerc, Lexy, pisica): modelul fiecăruia, ca să-l poți ține în
## brațe (ObiectInMana) și arunca pe jos (click dreapta în inventar, Stare._arunca): pe jos cade ca un ragdoll și îl
## iei înapoi cu E. Rămâne în `Stare.aruncate`, deci îl găsești tot acolo când revii (cade din nou pe loc).
## Ca să adaugi un cadavru: o intrare în `MODELE` cu id-ul lui din inventar.

## id -> scena, `mijloc` (cât de sus e mijlocul corpului față de tălpi: acolo îl ții), `lipite` (bucăți care rămân prinse
## în ragdoll), `masa` (kg), `indiciu`, `mana` (unde îl ții, față de cameră).
const MODELE := {
	# bețivul e modelat așezat (genunchii îndoiți în model): în brațe îl duci cu fața în jos, ca genunchii să nu-ți vină în ochi
	"cadavru_betiv": {"scena": "res://models/betiv.glb", "mijloc": 0.85, "lipite": ["SticlaMana"], "cu_fata_in_jos": true,
		"indiciu": "[E] Pick up the drunkard"},
	"cadavru_vrajitoare1": {"scena": "res://models/vrajitoare_1.glb", "mijloc": 0.9, "lipite": ["Ochi"], "cu_fata_in_jos": true,
		"indiciu": "[E] Pick up the witch"},
	"cadavru_vrajitoare2": {"scena": "res://models/vrajitoare_2.glb", "mijloc": 0.9, "lipite": ["Ochi"], "cu_fata_in_jos": true,
		"indiciu": "[E] Pick up the witch"},
	"cadavru_vrajitoare3": {"scena": "res://models/vrajitoare_3.glb", "mijloc": 0.9, "lipite": ["Ochi"], "cu_fata_in_jos": true,
		"indiciu": "[E] Pick up the witch"},
	"cadavru_vrajitoare4": {"scena": "res://models/vrajitoare_4.glb", "mijloc": 0.9, "lipite": ["Ochi"], "cu_fata_in_jos": true,
		"indiciu": "[E] Pick up the witch"},
	"cadavru_vrajitoare5": {"scena": "res://models/vrajitoare_2.glb", "mijloc": 0.9, "lipite": ["Ochi"], "cu_fata_in_jos": true,
		"indiciu": "[E] Pick up the witch"},
	"cadavru_lexy": {"scena": "res://models/lexy.glb", "mijloc": 0.9, "indiciu": "[E] Pick up Lexy"},
	# cei de la barul URBAN (JocBar): omorâbili după ce ai pierdut la ei
	"cadavru_big_mike": {"scena": "res://models/jucator_darts.glb", "mijloc": 1.0, "indiciu": "[E] Pick up Big Mike"},
	"cadavru_fast_eddie": {"scena": "res://models/jucator_biliard.glb", "mijloc": 0.95, "indiciu": "[E] Pick up Fast Eddie"},
	"cadavru_pisica": {"scena": "res://models/pisica.glb", "mijloc": 0.12, "lipite": ["Ochi"], "masa": 3.0,
		"indiciu": "[E] Pick up the cat", "mic": true},
}
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")
const SUNET_CADERE := preload("res://sunete/corp_cazut.ogg")


static func e_cadavru(id: String) -> bool:
	return MODELE.has(id)


## Modelul, cu materialul PS2 și membrele moi (ca la gardul cimitirului; `in_brate` = cum atârnă când îl duci în brațe),
## într-un suport cu originea la mijlocul
## corpului (acolo îl ții / acolo se rotește).
static func suport(id: String, in_brate := false) -> Node3D:
	var date: Dictionary = MODELE[id]
	var s := Node3D.new()
	s.name = "Cadavru_" + id
	var model := (load(date.scena) as PackedScene).instantiate() as Node3D
	model.set_script(SCRIPT_MODEL)
	model.set("material", MATERIAL)
	model.name = "Model"
	s.add_child(model)
	model.position = Vector3.DOWN * float(date.mijloc)
	if in_brate:
		atarnat(model)
	else:
		moale(model)
	return s


## Corpul e moale: brațele îi atârnă puțin în lături, picioarele un pic îndoite.
static func moale(model: Node3D) -> void:
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


## Culcat pe spate, de-a curmezișul: capul (Y-ul modelului) spre `cap`, fața (Z) în sus.
static func culcat(cap: Vector3) -> Basis:
	cap = cap.normalized()
	return Basis(cap.cross(Vector3.UP), cap, Vector3.UP)


## Îl pune pe jos la `punct`, cu capul spre `unghi`: cade ca un ragdoll (cu `impuls`), iar după ce se oprește îl poți
## lua înapoi cu E (atunci iese din `Stare.aruncate`).
static func pune_jos(parinte: Node, cheie: String, id: String, nume: String, punct: Vector3, unghi: float, impuls := Vector3.ZERO) -> void:
	var date: Dictionary = MODELE[id]
	var s := suport(id)
	parinte.add_child(s)
	var cap := Vector3(sin(unghi), 0.0, cos(unghi))
	# omul: pe spate, de-a curmezișul; pisica: pe o parte (pe spate ar sta în fund, ca vie)
	var baza := Basis(Vector3.UP, unghi) * Basis(Vector3.BACK, PI / 2.0) if date.get("mic", false) else culcat(cap)
	s.global_transform = Transform3D(baza, punct + Vector3.UP * (0.15 if date.get("mic", false) else 0.3))
	await s.get_tree().process_frame
	var r := Ragdoll.din_model(s.get_node("Model"), impuls, PackedStringArray(date.get("lipite", [])), date.get("masa", 30.0))
	s.queue_free()
	if impuls != Vector3.ZERO:
		await r.get_tree().create_timer(0.35).timeout
		if is_instance_valid(r):
			Sunet.reda_la(SUNET_CADERE, r.centru(), Sunet.VOLUM_EFECTE - (6.0 if date.get("mic", false) else 0.0), 0.05)
	var asteptat := 0.0
	while is_instance_valid(r) and asteptat < 3.0 and not (asteptat > 0.5 and r.s_a_oprit()):
		await r.get_tree().create_timer(0.2).timeout
		asteptat += 0.2
	if not is_instance_valid(r):
		return
	var ridicare := r.pune_ridicare(id, nume, date.indiciu)
	if date.get("mic", false):
		(ridicare.get_child(0).shape as SphereShape3D).radius = 0.3
	ridicare.folosit.connect(func() -> void: _luat(r, cheie))


static func _luat(r: Ragdoll, cheie: String) -> void:
	Stare.uita_aruncat(cheie)
	if is_instance_valid(r):
		r.queue_free()


## În brațe, culcat pe spate: brațele îi atârnă în jos, peste brațul tău, iar picioarele trec peste celălalt braț, cu
## genunchii îndoiți și gambele atârnând.
static func atarnat(model: Node3D) -> void:
	for l in ["D", "S"]:
		var s := -1.0 if l == "D" else 1.0
		var brat := model.find_child("Brat" + l, true, false) as Node3D
		if brat:
			brat.rotation = Vector3(1.1, 0.0, s * 0.25)
		var antebrat := model.find_child("Antebrat" + l, true, false) as Node3D
		if antebrat:
			antebrat.rotation.x = -0.3
		var coapsa := model.find_child("Coapsa" + l, true, false) as Node3D
		if coapsa:
			coapsa.rotation.x = -0.55 if l == "D" else -0.45
		var gamba := model.find_child("Gamba" + l, true, false) as Node3D
		if gamba:
			gamba.rotation.x = 1.25
