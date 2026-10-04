class_name ObiectInMana
extends Node3D
## Ce ții în mână la persoana întâi, în afară de pistol (care are scriptul lui, Pistol). Îl pune jucator.gd sub cameră.
## Arată modelul din `MODELE` pentru `Stare.in_mana`; un obiect care nu e în listă (ex. un cadavru) nu se vede.
## La schimbare: cel vechi coboară din cadru, apoi urcă cel nou. Cât e deschis un meniu / o scenă sau e ecranul negru,
## îl lași jos, ca pistolul.
## Ca să adaugi un obiect: o intrare în `MODELE` cu id-ul din inventar (vezi ObiectLuat.id_obiect).

## id -> scena modelului, unde îl ții (față de cameră; originea modelului), cum e rotit.
const MODELE := {
	"matura": {
		"scena": preload("res://models/matura.glb"),
		"pozitie": Vector3(0.44, -0.64, -0.66),
		"rotatie": Vector3(-0.4, 0.15, 0.3),
	},
}
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")
## Cât coboară când îl lași jos.
const JOS := Vector3(0.05, -0.55, 0.12)
## O scenă din cod îl poate ține la vedere cât e Stare.meniu_deschis (ex. mătura pusă jos la antrenament).
static var in_scena := false

var _id := ""
var _model: Node3D
var _jos := 1.0  # 0 = în mână, 1 = lăsat jos (nu se vede)
var _timp := 0.0


func _process(delta: float) -> void:
	_timp += delta
	var vrut := Stare.in_mana if MODELE.has(Stare.in_mana) else ""
	var jos := vrut != _id or vrut == "" or (Stare.meniu_deschis and not in_scena) or Tranzitie.activa
	_jos = move_toward(_jos, 1.0 if jos else 0.0, delta * 3.0)
	if _jos >= 1.0 and vrut != _id:
		_schimba(vrut)
	visible = _model != null and _jos < 0.99
	if _model == null:
		return
	var date: Dictionary = MODELE[_id]
	var k := ease(_jos, 2.0)
	# se leagănă puțin cât îl ții
	var respiratie := Vector3(sin(_timp * 1.3) * 0.003, sin(_timp * 2.1) * 0.004, 0.0)
	_model.position = date.pozitie + JOS * k + respiratie
	_model.rotation = date.rotatie + Vector3(-0.5 * k, 0.0, 0.0)


func _schimba(id: String) -> void:
	if _model:
		_model.queue_free()
		_model = null
	_id = id
	if id == "":
		return
	_model = (MODELE[id].scena as PackedScene).instantiate()
	_model.set_script(SCRIPT_MODEL)
	_model.set("material", MATERIAL)
	_model.set("umbre", false)
	add_child(_model)


## Îl scoate din mână pe loc, fără să-l coboare (când îl ia o scenă din cod, ex. mătura pusă jos la antrenament).
## Pune întâi `Stare.in_mana` = "", altfel urcă la loc.
func scoate_acum() -> Transform3D:
	var unde := _model.global_transform if _model else global_transform
	_jos = 1.0
	_schimba("")
	visible = false
	return unde
