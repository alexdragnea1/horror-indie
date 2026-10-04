extends Node3D
## „Semnele” de pe poteca din stânga, care coboară în vale: cu cât cobori, cu atât sunt mai multe.
## Întâi o cruce strâmbă pe margine, apoi păpuși de paie atârnate de crăci, mai multe cruci, iar în
## fundul văii un cerc de cruci cu lumânări aprinse, iar în mijlocul lui coven-ul (scenes/coven.tscn): cazanul și
## vrăjitoarele. Pozițiile sunt date ca fracție din lungimea potecii (0 = bifurcația, 1 = capătul)
## și ca distanță în lateral (pozitiv = în dreapta cui coboară).

@export var teren: TerenPadure
@export var cruce: PackedScene
@export var copac_craca: PackedScene
@export var papusa: PackedScene
@export var lumanare: PackedScene
@export var piatra: PackedScene

## [fracție, ce, lateral]. ce: "cruce", "papusa" (copac cu cracă + păpușă), "piatra".
const SEMNE := [
	[0.22, "cruce", -2.8],
	[0.38, "papusa", 3.3],
	[0.5, "cruce", 2.6], [0.52, "cruce", -3.4], [0.54, "piatra", 3.6],
	[0.63, "papusa", -3.5],
	[0.71, "papusa", 3.1],
	[0.78, "cruce", -2.6], [0.8, "cruce", 2.8], [0.81, "cruce", -3.8],
	[0.88, "papusa", 3.4], [0.9, "papusa", -3.2],
]
## Unde e cârligul crăcii față de copac (vezi copac_craca() în tools/blender/padure.py).
const CARLIG := Vector3(1.6, 3.56, 0)

const MATERIAL := preload("res://shaders/material_model.tres")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")

var _papusi: Array[Node3D] = []
var _timp := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 66
	var drum := teren.poteca_stanga
	for s in SEMNE:
		var f: float = s[0]
		var p := teren.punct_pe_poteca(drum, f)
		var inainte := (teren.punct_pe_poteca(drum, minf(f + 0.02, 1.0)) - teren.punct_pe_poteca(drum, maxf(f - 0.02, 0.0))).normalized()
		var dreapta := Vector2(-inainte.y, inainte.x)
		var lateral: float = s[2]
		var q := p + dreapta * lateral
		match s[1]:
			"cruce":
				# cu fața spre potecă, strâmbă
				_pune(cruce, q, atan2(-dreapta.x * signf(lateral), -dreapta.y * signf(lateral)), _rng.randf_range(-0.25, 0.25))
			"piatra":
				_pune(piatra, q, _rng.randf_range(0, TAU), 0.0)
			"papusa":
				# craca (spre +X-ul copacului) întinsă peste marginea potecii
				var spre_poteca := -dreapta * signf(lateral)
				var unghi := atan2(-spre_poteca.y, spre_poteca.x)
				var copac := _pune(copac_craca, q, unghi, 0.0)
				_atarna(copac.global_transform * CARLIG)
	_cerc()


## Fundul văii: cercul de cruci (în mijloc stă coven-ul, scenes/coven.tscn, cu cazanul), câte o lumânare
## aprinsă în fața fiecărei cruci și o păpușă deasupra.
func _cerc() -> void:
	var c := teren.centru_vale
	for k in 7:
		var u := k * TAU / 7.0
		var q := c + Vector2(cos(u), sin(u)) * 4.2
		var l := lumanare.instantiate() as Node3D
		add_child(l)
		var ql := c + Vector2(cos(u), sin(u)) * 3.75
		l.global_position = Vector3(ql.x, teren.inaltime(ql.x, ql.y), ql.y)
		# cu fața spre cazan, fiecare puțin altfel aplecată
		_pune(cruce, q, atan2(c.x - q.x, c.y - q.y), _rng.randf_range(-0.2, 0.2))
	var unde := c + Vector2(-6.0, -1.5)
	var spre := c - unde
	var copac := _pune(copac_craca, unde, atan2(-spre.y, spre.x), 0.0)
	_atarna(copac.global_transform * CARLIG)


func _pune(scena: PackedScene, q: Vector2, unghi_y: float, aplecare: float) -> Node3D:
	var n := scena.instantiate() as Node3D
	if not n is ModelPS2 and n.get_script() == null:
		n.set_script(SCRIPT_MODEL)
		n.set("material", MATERIAL)
	# pietrele și crucile au „hitbox”, la copacul cu cracă doar trunchiul (pe sub cracă se trece)
	if scena == piatra or scena == cruce:
		n.set("coliziune", 1 if scena == piatra else 2)
	add_child(n)
	n.global_position = Vector3(q.x, teren.inaltime(q.x, q.y) - 0.05, q.y)
	n.rotation = Vector3(aplecare, unghi_y, aplecare * 0.5)
	if scena == copac_craca:
		var corp := StaticBody3D.new()
		var forma := CollisionShape3D.new()
		var cilindru := CylinderShape3D.new()
		cilindru.radius = 0.3
		cilindru.height = 4.0
		forma.shape = cilindru
		forma.position.y = 2.0
		corp.add_child(forma)
		n.add_child(corp)
	return n


func _atarna(punct: Vector3) -> void:
	var n := papusa.instantiate() as Node3D
	n.set_script(SCRIPT_MODEL)
	n.set("material", MATERIAL)
	add_child(n)
	n.global_position = punct
	n.rotation.y = _rng.randf_range(0, TAU)
	_papusi.append(n)


func _process(delta: float) -> void:
	_timp += delta
	# păpușile se răsucesc încet pe sfoară și se leagănă puțin, fiecare în ritmul ei
	for i in _papusi.size():
		var p := _papusi[i]
		var t := _timp * (0.35 + i * 0.07) + i * 1.7
		p.rotation = Vector3(sin(t * 1.3) * 0.05, p.rotation.y + sin(t) * delta * 0.4, sin(t * 0.9) * 0.04)
