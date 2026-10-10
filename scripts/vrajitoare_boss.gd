class_name VrajitoareBoss
extends Warlock
## Head Witch în lupta din City Center (lupta_head_witch.gd, făcută din cod). Se mișcă la fel ca Warlock-ul (aceleași
## comenzi: `ridica_toiagul` = brațul drept, `ridica_mana` = brațul stâng, `plutire`, `furie`, `priveste`, `aparitie`,
## `ascunde`, `tresare`, `prabusire`, `smuls`), doar că are modelul ei și culorile ei:
##  - faza întâi: models/vrajitoare_sefa_lupta.glb (din tools/blender/centru.py), lumină mov;
##  - faza a doua (`schimba_in_demon`): models/vrajitoare_sefa_demon.glb, ~3,4 m, aripi de os care bat încet, lumină
##    verde. Ochii, miezul din piept și coroana de spini (`Lumini`) ard mai tare cu `furie`.
## Vrăjile pleacă din punctul gol `Palma` din fiecare braț. Fața modelului e spre +Z.

const MODEL_FAZA_UNU := preload("res://models/vrajitoare_sefa_lupta.glb")
const MODEL_DEMON := preload("res://models/vrajitoare_sefa_demon.glb")
const MOV := Color(0.72, 0.38, 1.0)
const VERDE := Color(0.38, 1.0, 0.6)

## Adevărat după transformare.
var demon := false
## 0 = aripile strânse pe spate, 1 = deschise (bat încet).
var aripi := 1.0

var _contur: OmniLight3D
var _aripa_d: Node3D
var _aripa_s: Node3D
var _repaus_aripa_d := Vector3.ZERO
var _repaus_aripa_s := Vector3.ZERO


func _ready() -> void:
	_pune_model(MODEL_FAZA_UNU)
	_lumina = OmniLight3D.new()
	_lumina.light_energy = 2.0
	_lumina.omni_range = 7.0
	_lumina.omni_attenuation = 1.2
	_lumina.light_volumetric_fog_energy = 1.5
	_lumina.position = Vector3(0, 1.6, 0.8)
	add_child(_lumina)
	# lumina de contur, din spate (roba închisă pe cerul de seară nu s-ar vedea)
	_contur = OmniLight3D.new()
	_contur.light_energy = 3.0
	_contur.omni_range = 4.5
	_contur.omni_attenuation = 1.0
	_contur.light_volumetric_fog_energy = 0.0
	_contur.position = Vector3(0, 2.3, -1.3)
	add_child(_contur)
	_jar = VrajaAtac.particule(self, 40, 2.5, 0.06, [Color(1, 1, 1, 1), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
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
	_culori(MOV)


func _pune_model(scena: PackedScene) -> void:
	if _model:
		_model.queue_free()
	_model = scena.instantiate() as Node3D
	_model.set_script(SCRIPT_MODEL)
	_model.set("material", MATERIAL)
	_model.set("stralucitoare", PackedStringArray(["Lumini", "Ochi"]))
	_model.set("stralucire", 1.6)
	add_child(_model)
	_cap = _model.get_node("Cap")
	_brat_d = _model.get_node("BratDrept")
	_brat_s = _model.get_node("BratStang")
	_cristal = null
	_aripa_d = _model.get_node_or_null("AripaDreapta")
	_aripa_s = _model.get_node_or_null("AripaStanga")
	if _aripa_d:
		_repaus_aripa_d = _aripa_d.rotation
		_repaus_aripa_s = _aripa_s.rotation


## Lumina din față, cea de contur și jarul care urcă din ea, în culoarea fazei.
func _culori(c: Color) -> void:
	_lumina.light_color = c
	_contur.light_color = c.lightened(0.15)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([c.lightened(0.5), Color(c, 0.9), Color(c.darkened(0.6), 0.0)])
	_jar.color_ramp = g


## Faza a doua: alt model (mai mare, cu aripi), lumina și jarul verzi. Apariția pe pixeli o face lupta.
func schimba_in_demon() -> void:
	demon = true
	_pune_model(MODEL_DEMON)
	_culori(VERDE)
	_lumina.position = Vector3(0, 2.4, 1.2)
	_lumina.omni_range = 10.0
	_contur.position = Vector3(0, 3.2, -1.6)
	_contur.omni_range = 6.0
	_jar.emission_box_extents = Vector3(1.2, 0.3, 1.2)
	_jar.amount = 70


func _process(delta: float) -> void:
	super(delta)
	if _aripa_d:
		# aripile bat încet (mai repede la furie); strânse = lipite de spate
		var bataie := sin(_timp * (1.4 + furie * 1.6)) * 0.22 * aripi
		var strans := (1.0 - aripi) * 1.1
		_aripa_d.rotation = _repaus_aripa_d + Vector3(0.0, -strans * 0.6, bataie - strans)
		_aripa_s.rotation = _repaus_aripa_s + Vector3(0.0, strans * 0.6, -bataie + strans)


## Mâna dreaptă (sus, în vârful brațului ridicat): aici își adună globurile, ca Warlock-ul în vârful toiagului.
func varf_toiag() -> Vector3:
	var p := _brat_d.get_node_or_null("Palma") as Node3D
	return p.global_position if p else global_position + Vector3.UP * 2.2


## Mâna stângă: de aici pleacă salvele.
func palma() -> Vector3:
	var p := _brat_s.get_node_or_null("Palma") as Node3D
	return p.global_position if p else global_position + Vector3.UP * 1.4


## Mâna dreaptă (raza din faza a doua, ploaia).
func palma_dreapta() -> Vector3:
	return varf_toiag()
