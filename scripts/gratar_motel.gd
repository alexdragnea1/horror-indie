extends Node3D
## Grătarul boschetarilor de pe acoperișul recepției de la Paradise Motel (owner 22.10). Nodul stă pe grila
## butoiului (`_gratar` din tools/blender/motel.py, modelul e în `motel_receptie.glb`); de aici vin lumina jarului
## care pâlpâie, flăcăruile, fumul care urcă și trosnetul. `gratar` (OmLaMasa, cel cu mâna spre grilă) întoarce din
## când în când cârnații: își duce mâna pe grilă și înapoi. Pe acoperiș nu se poate ajunge (grilajul de pe pasarelă).

const SCRIPT_FLACARA := preload("res://scripts/flacara.gd")
const SUNET_FOC := preload("res://sunete/foc_trosnet.ogg")

@export var gratar: OmLaMasa
## Cât de des întoarce cârnații (secunde).
@export var pauza_intors := Vector2(3.0, 6.0)

var _pana_la_intors := 2.0


func _ready() -> void:
	var lumina := OmniLight3D.new()
	lumina.set_script(SCRIPT_FLACARA)
	lumina.set("energie", 1.6)
	lumina.set("tremur", 0.3)
	lumina.light_color = Color(1.0, 0.5, 0.2)
	lumina.omni_range = 5.0
	lumina.omni_attenuation = 1.3
	lumina.position = Vector3.UP * 0.35
	add_child(lumina)
	var flacari := VrajaAtac.particule(self, 14, 0.5, 0.16, [Color(1.0, 0.85, 0.45, 0.95), Color(1.0, 0.45, 0.15, 0.85),
		Color(0.75, 0.18, 0.08, 0.5), Color(0.2, 0.08, 0.06, 0.0)])
	flacari.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flacari.emission_box_extents = Vector3(0.32, 0.02, 0.12)
	flacari.direction = Vector3.UP
	flacari.spread = 12.0
	flacari.initial_velocity_min = 0.3
	flacari.initial_velocity_max = 0.7
	flacari.gravity = Vector3(0, 0.6, 0)
	flacari.preprocess = 0.5
	flacari.emitting = true
	var fum := VrajaAtac.particule(self, 10, 5.0, 0.7, [Color(0.25, 0.2, 0.2, 0.0), Color(0.2, 0.17, 0.17, 0.45),
		Color(0.16, 0.14, 0.15, 0.25), Color(0.12, 0.11, 0.12, 0.0)])
	fum.position = Vector3.UP * 0.3
	fum.emission_sphere_radius = 0.2
	fum.direction = Vector3(0.1, 1.0, 0.0)
	fum.spread = 10.0
	fum.initial_velocity_min = 0.5
	fum.initial_velocity_max = 0.9
	fum.gravity = Vector3(0.2, 0.1, 0)
	var creste := Curve.new()
	creste.add_point(Vector2(0.0, 0.4))
	creste.add_point(Vector2(1.0, 1.8))
	fum.scale_amount_curve = creste
	fum.preprocess = 5.0
	fum.emitting = true
	var sunet := AudioStreamPlayer3D.new()
	sunet.stream = SUNET_FOC
	sunet.bus = &"Ambianta"
	sunet.volume_db = Sunet.VOLUM_AMBIANTA
	sunet.unit_size = 3.0
	sunet.max_distance = 25.0
	sunet.autoplay = true
	add_child(sunet)


func _process(delta: float) -> void:
	if gratar == null:
		return
	_pana_la_intors -= delta
	if _pana_la_intors <= 0.0:
		_pana_la_intors = randf_range(pauza_intors.x, pauza_intors.y)
		gratar.gest(global_position + Vector3(randf_range(-0.25, 0.25), 0.06, randf_range(-0.1, 0.1)), 0.5)
