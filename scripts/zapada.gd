class_name Zapada
extends Node3D
## Zăpada care cade peste oraș după ce moare Head Witch (City Center, lupta_head_witch.gd): fulgi albi, mari (PS2), care
## cad încet și se leagănă, dintr-o cutie largă deasupra pieței. `intensitate` (0..1) = cât de deasă e; o crește lupta
## încet, din explozie: fulgii sunt în `STRATURI` straturi care pornesc unul după altul (un strat pornit începe să
## ningă de sus, deci nu apare nimic dintr-odată). Stratul de pe jos (`pe_jos`, un disc alb care se așterne peste
## pavaj) crește odată cu ea. După final (Continue, `marcaj`) ninge de la început, cu stratul așternut.

## Cât de mare e cutia din care cad (pe X și Z, metri) și de la ce înălțime.
@export var latime := 70.0
@export var inaltime := 26.0
## Câți fulgi sunt în aer la intensitate maximă (în toate straturile).
@export var fulgi := 1400
## Discul de zăpadă de pe pavaj: raza și înălțimea (peste piață).
@export var raza_strat := 16.4
@export var y_strat := 0.172
## După acest marcaj (finalul văzut) ninge de la început.
@export var marcaj := "head_witch_moarta"

const STRATURI := 4

var intensitate := 0.0:
	set(v):
		intensitate = clampf(v, 0.0, 1.0)
		for i in _fulgi.size():
			_fulgi[i].emitting = intensitate > float(i) / STRATURI + 0.001
var pe_jos := 0.0:
	set(v):
		pe_jos = clampf(v, 0.0, 1.0)
		if _mat_strat:
			_mat_strat.albedo_color.a = pe_jos * 0.62
			_strat.visible = pe_jos > 0.001

var _fulgi: Array[CPUParticles3D] = []
var _strat: MeshInstance3D
var _mat_strat: StandardMaterial3D


func _ready() -> void:
	var deja := Stare.e_marcat(marcaj)
	for i in STRATURI:
		_fulgi.append(_strat_fulgi(deja))
	_strat = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = raza_strat
	disc.bottom_radius = raza_strat
	disc.height = 0.004
	disc.radial_segments = 48
	disc.rings = 1
	_strat.mesh = disc
	_mat_strat = StandardMaterial3D.new()
	_mat_strat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_strat.albedo_color = Color(0.9, 0.92, 0.97, 0.0)
	_mat_strat.roughness = 1.0
	_strat.material_override = _mat_strat
	_strat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_strat.position = Vector3.UP * y_strat
	_strat.visible = false
	add_child(_strat)
	if deja:
		intensitate = 1.0
		pe_jos = 1.0
	else:
		intensitate = 0.0


## Un strat de fulgi. `plin` = ninge deja (Continue după final): fulgii sunt de la început în tot aerul.
func _strat_fulgi(plin: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.07
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = VrajaAtac.textura_moale()
	mat.albedo_color = Color(0.93, 0.95, 1.0, 0.95)
	quad.material = mat
	p.mesh = quad
	p.amount = maxi(fulgi / STRATURI, 1)
	p.lifetime = 9.0
	p.preprocess = 9.0 if plin else 0.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(latime * 0.5, 0.5, latime * 0.5)
	p.position = Vector3.UP * inaltime
	p.direction = Vector3.DOWN
	p.spread = 12.0
	p.gravity = Vector3(0.15, -0.6, 0.0)
	p.initial_velocity_min = 1.8
	p.initial_velocity_max = 2.6
	p.damping_min = 0.6
	p.damping_max = 1.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.visibility_aabb = AABB(Vector3(-latime * 0.5, -inaltime - 2.0, -latime * 0.5), Vector3(latime, inaltime + 4.0, latime))
	p.emitting = false
	add_child(p)
	return p


## Ninge tot mai tare, până la `spre` (0..1), în `durata` s; stratul de pe jos se așterne mai încet.
func porneste(spre: float, durata: float) -> void:
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "intensitate", spre, durata)
	t.tween_property(self, "pe_jos", spre, durata * 3.0)
