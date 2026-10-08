class_name Warlock
extends Node3D
## Warlock-ul (models/warlock.glb, din tools/blender/warlock.py), făcut din cod de atac_conac.gd. Plutește puțin deasupra
## pământului (`plutire`), runele de pe robă și cristalul toiagului pulsează, ochii ard, o lumină roșie și jar care urcă
## în jurul lui. Mișcările le comandă scena: `ridica_toiagul`, `ridica_mana`, `priveste`, `aparitie`, `dispari`.
## Fața modelului e spre +Z (îl întorci cu rotation.y).

const MODEL := preload("res://models/warlock.glb")
const MATERIAL := preload("res://shaders/material_model.tres")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
## Mâna stângă, față de umăr (brațul atârnă; vezi warlock() în tools/blender/warlock.py).
const MANA_STANGA := Vector3(0.05, -0.74, 0.08)

## Cât de sus plutește (metri).
var plutire := 0.5
## 0..1: cât de tare ard runele, ochii și cristalul (crește la vraja mare).
var furie := 0.3

var _model: Node3D
var _cap: Node3D
var _brat_d: Node3D
var _brat_s: Node3D
var _cristal: Node3D
var _lumina: OmniLight3D
var _jar: CPUParticles3D
var _timp := randf() * 10.0
var _privire := Vector3.ZERO


func _ready() -> void:
	_model = MODEL.instantiate() as Node3D
	_model.set_script(SCRIPT_MODEL)
	_model.set("material", MATERIAL)
	_model.set("stralucitoare", PackedStringArray(["Lumini", "Ochi", "Cristal"]))
	_model.set("stralucire", 1.6)
	add_child(_model)
	_cap = _model.get_node("Cap")
	_brat_d = _model.get_node("BratDrept")
	_brat_s = _model.get_node("BratStang")
	_cristal = _model.find_child("Cristal", true, false)
	_lumina = OmniLight3D.new()
	_lumina.light_color = Color(1.0, 0.22, 0.15)
	_lumina.light_energy = 2.0
	_lumina.omni_range = 7.0
	_lumina.omni_attenuation = 1.2
	_lumina.light_volumetric_fog_energy = 1.5
	_lumina.position = Vector3(0, 1.6, 0.8)
	add_child(_lumina)
	# lumina de contur, din spate (roba neagră pe cerul de noapte nu s-ar vedea deloc)
	var contur := OmniLight3D.new()
	contur.light_color = Color(1.0, 0.35, 0.28)
	contur.light_energy = 3.5
	contur.omni_range = 4.5
	contur.omni_attenuation = 1.0
	contur.light_volumetric_fog_energy = 0.0
	contur.position = Vector3(0, 2.3, -1.3)
	add_child(contur)
	_jar = VrajaAtac.particule(self, 40, 2.5, 0.06, [Color(1.0, 0.7, 0.4, 1.0), Color(0.95, 0.2, 0.1, 0.9), Color(0.4, 0.1, 0.1, 0.0)])
	_jar.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_jar.emission_box_extents = Vector3(0.8, 0.2, 0.8)
	_jar.position = Vector3(0, 0.3, 0)
	_jar.direction = Vector3.UP
	_jar.spread = 25.0
	_jar.initial_velocity_min = 0.4
	_jar.initial_velocity_max = 1.4
	_jar.gravity = Vector3(0, 0.3, 0)
	_jar.preprocess = 2.5
	_jar.emitting = true


func _process(delta: float) -> void:
	_timp += delta
	_model.position.y = plutire + sin(_timp * 1.3) * 0.07 * clampf(plutire * 2.0, 0.0, 1.0)
	_model.rotation.z = sin(_timp * 0.7) * 0.02
	if _aplecare != 0.0 or _tremura:
		_model.rotation.x = _aplecare
	if _tremura:
		var j := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.025
		_model.position = Vector3(j.x, _model.position.y + j.y, j.z)
	var puls := 0.5 + 0.5 * sin(_timp * (3.0 + furie * 9.0))
	var arde := 1.0 + furie * 2.5 + puls * (0.4 + furie) + _sclipire * 4.0
	for nume in ["Lumini", "Cap/Ochi"]:
		var m := _model.get_node_or_null(nume) as GeometryInstance3D
		if m:
			m.set_instance_shader_parameter("stralucire", arde)
	if _cristal:
		(_cristal as GeometryInstance3D).set_instance_shader_parameter("stralucire", arde * 1.4)
	_lumina.light_energy = (1.5 + furie * 5.0) * (0.85 + 0.15 * puls)
	if _privire != Vector3.ZERO:
		var local: Vector3 = (_cap.get_parent() as Node3D).to_local(_privire) - _cap.position
		var unghi := atan2(local.x, local.z)
		var sus := atan2(local.y, Vector2(local.x, local.z).length())
		_cap.rotation.y = lerp_angle(_cap.rotation.y, clampf(unghi, -1.0, 1.0), delta * 4.0)
		_cap.rotation.x = lerp_angle(_cap.rotation.x, clampf(-sus, -0.6, 0.6), delta * 4.0)


## Capul se întoarce spre `punct` (în lume); Vector3.ZERO = drept înainte.
func priveste(punct: Vector3) -> void:
	_privire = punct


## Brațul cu toiagul: `cat` radiani pe X (minus = înainte și în sus; -2,9 = toiagul drept spre cer).
func ridica_toiagul(cat: float, durata: float) -> Tween:
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_brat_d, "rotation:x", cat, durata)
	return t


## Brațul stâng (cu ghearele): `cat` ca la toiag; `lateral` = cât îl deschide în lături (Z).
func ridica_mana(cat: float, durata: float, lateral := 0.0) -> Tween:
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_brat_s, "rotation:x", cat, durata)
	t.tween_property(_brat_s, "rotation:z", lateral, durata)
	return t


func varf_toiag() -> Vector3:
	return _cristal.global_position if _cristal else global_position + Vector3.UP * 2.6


func palma() -> Vector3:
	return _brat_s.to_global(MANA_STANGA)


## Apare (pe pixeli, ca demonul) în `durata` secunde.
func aparitie(durata: float) -> Tween:
	ModelPS2.disparitie(_model, 1.0)
	var t := create_tween()
	t.tween_method(func(v: float) -> void: ModelPS2.disparitie(_model, v), 1.0, 0.0, durata)
	return t


func dispari(durata: float) -> Tween:
	var t := create_tween()
	t.tween_method(func(v: float) -> void: ModelPS2.disparitie(_model, v), 0.0, 1.0, durata)
	t.parallel().tween_property(_lumina, "light_energy", 0.0, durata)
	t.tween_callback(queue_free)
	return t


# ---------------------------------------------------------------- lupta de la motel (lupta_warlock.gd)

var _sclipire := 0.0
var _aplecare := 0.0
var _tremura := false


## Se topește pe pixeli fără să plece din scenă (teleportul: apoi `aparitie` în alt loc).
func ascunde(durata: float) -> Tween:
	var t := create_tween()
	t.tween_method(func(v: float) -> void: ModelPS2.disparitie(_model, v), 0.0, 1.0, durata)
	return t


## L-a lovit ceva: tresare (se dă puțin înapoi), runele și ochii sclipesc o clipă.
func tresare(dinspre: Vector3, putere := 1.0) -> void:
	var d := global_basis.inverse() * Vector3(dinspre.x, 0.0, dinspre.z).normalized()
	_model.rotation.x = _aplecare + clampf(d.z, -1.0, 1.0) * 0.12 * putere
	_model.rotation.y = clampf(-d.x, -1.0, 1.0) * 0.1 * putere
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	t.tween_property(_model, "rotation:x", _aplecare, 0.25)
	t.tween_property(_model, "rotation:y", 0.0, 0.25)
	_sclipire = 1.0
	t.tween_property(self, "_sclipire", 0.0, 0.2)


## Învins: cade pe pământ (nu mai plutește), se apleacă în față, toiagul și brațul îi atârnă, focul din el se stinge.
func prabusire(durata: float) -> Tween:
	_privire = Vector3.ZERO
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(self, "plutire", -0.3, durata)
	t.tween_property(self, "_aplecare", 0.45, durata)
	t.tween_property(self, "furie", 0.0, durata)
	t.tween_property(_brat_d, "rotation:x", 0.35, durata)
	t.tween_property(_brat_d, "rotation:z", 0.15, durata)
	t.tween_property(_brat_s, "rotation:x", 0.1, durata)
	t.tween_property(_brat_s, "rotation:z", 0.0, durata)
	t.tween_property(_cap, "rotation:x", 0.5, durata)
	t.tween_property(_cap, "rotation:y", 0.0, durata)
	return t


## Head Witch îi trage puterile: se ridică în aer, cu brațele desfăcute și capul pe spate, și tremură.
func smuls(durata: float) -> Tween:
	_tremura = true
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "plutire", 0.7, durata)
	t.tween_property(self, "_aplecare", -0.25, durata)
	t.tween_property(_brat_d, "rotation:z", 1.1, durata)
	t.tween_property(_brat_d, "rotation:x", -0.4, durata)
	t.tween_property(_brat_s, "rotation:z", -1.1, durata)
	t.tween_property(_brat_s, "rotation:x", -0.4, durata)
	t.tween_property(_cap, "rotation:x", -0.55, durata)
	t.tween_property(self, "furie", 1.0, durata * 0.6)
	return t
