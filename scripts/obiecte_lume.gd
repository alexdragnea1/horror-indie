class_name ObiecteLume
extends RefCounted
## Obiectele din inventar care pot sta și în lume: aruncate pe jos (click dreapta în inventar, vezi ObiectAruncat) sau
## puse pe raftul din camera ta (RaftDepozit). Pentru fiecare id: modelul, cum stă culcat pe jos (rotație și cât îl
## ridici ca să nu intre în podea) și cum stă în compartimentul raftului. Ce nu e aici (cadavrele) nu se poate
## arunca sau pune pe raft.
## Ca să adaugi un obiect nou: o intrare în `MODELE` cu id-ul lui din inventar.

const MODELE := {
	"pistol_roz": {
		"scena": "res://models/pistol_roz.glb",
		"material": "res://shaders/material_roz.tres",
		"stralucitoare": ["Strasuri"],
		"jos": Vector3(0.0, 0.0, PI / 2.0),  # culcat pe o parte
		"ridicare": 0.025,
		"raft": Vector3(0.0, 0.0, PI / 2.0),
	},
	"pistol_aur": {  # easter egg-ul din spatele conacului (pistol_aur_masa.gd)
		"scena": "res://models/pistol_aur.glb",
		"material": "res://shaders/material_aur.tres",
		"stralucitoare": ["Luciu"],
		"jos": Vector3(0.0, 0.0, PI / 2.0),
		"ridicare": 0.02,
		"raft": Vector3(0.0, 0.0, PI / 2.0),
	},
	"matura": {
		"scena": "res://models/matura.glb",
		"jos": Vector3(PI / 2.0, 0.0, 0.0),  # culcată pe podea
		"ridicare": 0.12,
		"sprijinita": true,  # pe raft nu încape: stă rezemată de el, pe podea, în dreptul compartimentului
	},
	"bomboana": {
		"scena": "res://models/bomboana.glb",
		"jos": Vector3.ZERO,
		"ridicare": 0.02,
		"raft": Vector3(0.0, 0.4, 0.0),
		# are doar 6 cm și e roșu închis: fără puțin luciu, pe podeaua întunecată era doar un punct negru
		"stralucitoare": ["Ambalaj", "Bomboana"],
		"stralucire": 0.45,
		"marime": 1.5,
	},
	# armele de la Gun Store (magazin_arme.tscn): pe jos culcate pe o parte; pe raft cuțitul stă în compartiment, cele
	# lungi în picioare în fața lui, cu patul pe podea, rezemate
	"cutit": {
		"scena": "res://models/cutit.glb",
		"jos": Vector3(0.0, 0.0, PI / 2.0),
		"ridicare": 0.016,
		"raft": Vector3(0.0, 0.0, PI / 2.0),
	},
	"shotgun": {
		"scena": "res://models/shotgun.glb",
		"jos": Vector3(0.0, 0.0, PI / 2.0),
		"ridicare": 0.026,
		"sprijinita": true,
		"sprijin": Vector3(PI / 2.0 - 0.2, 0.0, 0.0),
		"sprijin_y": 0.45,
	},
	"ak47": {
		"scena": "res://models/ak47.glb",
		"jos": Vector3(0.0, 0.0, PI / 2.0),
		"ridicare": 0.026,
		"sprijinita": true,
		"sprijin": Vector3(PI / 2.0 - 0.2, 0.0, 0.0),
		"sprijin_y": 0.47,
	},
	"bazooka": {
		"scena": "res://models/bazooka.glb",
		"jos": Vector3(0.0, 0.0, -PI / 2.0),
		"ridicare": 0.066,
		"sprijinita": true,
		"sprijin": Vector3(PI / 2.0 - 0.15, 0.0, 0.0),
		"sprijin_y": 0.92,
	},
	"bani_5": {  # bancnota de 5 dolari de la Lexy (lexy_masa.gd); modelul e deja culcat
		"scena": "res://models/bancnota.glb",
		"jos": Vector3.ZERO,
		"ridicare": 0.002,
		"raft": Vector3(0.0, 0.3, 0.0),
	},
}
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")


static func are_model(id: String) -> bool:
	return MODELE.has(id)


## Modelul obiectului `id`, gata de pus în scenă (cu materialul PS2), sau null dacă n-are.
static func model(id: String) -> Node3D:
	if not MODELE.has(id):
		return null
	var date: Dictionary = MODELE[id]
	var nod := (load(date.scena) as PackedScene).instantiate() as Node3D
	nod.set_script(SCRIPT_MODEL)
	nod.set("material", load(date.material) if date.has("material") else MATERIAL)
	if date.has("stralucitoare"):
		nod.set("stralucitoare", PackedStringArray(date.stralucitoare))
		nod.set("stralucire", date.get("stralucire", 1.0))
	return nod


## Pune obiectul `id` jos, la `punct` (pe podea), întors spre `unghi`, ca să-l poți lua înapoi cu E.
static func pune_jos(parinte: Node, id: String, nume: String, punct: Vector3, unghi: float) -> ObiectAruncat:
	var obiect := ObiectAruncat.new()
	obiect.id_obiect = id
	obiect.nume_obiect = nume
	obiect.indiciu = "[E] Pick up " + nume.to_lower()
	parinte.add_child(obiect)
	obiect.global_position = punct
	obiect.rotation.y = unghi
	var m := model(id)
	m.rotation = MODELE[id].jos
	# obiectele foarte mici sunt puțin mai mari pe jos (`marime`), altfel de la înălțimea ochilor nu le vezi
	var marime: float = MODELE[id].get("marime", 1.0)
	m.scale = Vector3.ONE * marime
	m.position.y = MODELE[id].ridicare * marime
	obiect.add_child(m)
	# o cutie de prins cu privirea, puțin mai mare decât obiectul (nu te împiedici de ea: e pe alt strat)
	var cutie := ColiziuneModel.cutie_nod(obiect)
	cutie = cutie.grow(0.05)
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = cutie.size
	forma.shape = box
	forma.position = cutie.get_center()
	obiect.add_child(forma)
	obiect.collision_layer = 8
	obiect.collision_mask = 0
	return obiect
