class_name VrajitorBoss
extends Warlock
## Vrăjitorul care îl ajuta pe Warlock (models/vrajitor_3.glb, cel cu vrăji roșii din armata de la conac), ca boss în
## curtea blocului, în dimineața de după final (lupta_vrajitor.gd). Se mișcă la fel ca Warlock-ul (aceleași comenzi:
## `ridica_mana`, `ridica_toiagul` = brațul drept, `priveste`, `aparitie`, `ascunde`, `tresare`, `prabusire`), doar că
## n-are toiag și stă pe pământ (`plutire` 0). Vrăjile pleacă din palma stângă. Fața modelului e spre +Z.

const MODEL_VRAJITOR := preload("res://models/vrajitor_3.glb")
## Mâinile, față de umăr (ca în vrajitor_armata.gd).
const MANA_S := Vector3(0.03, -0.62, 0.07)
const MANA_D := Vector3(-0.03, -0.62, 0.07)
const ROSU_VRAJITOR := Color(1.0, 0.2, 0.12)


func _ready() -> void:
	_model = MODEL_VRAJITOR.instantiate() as Node3D
	_model.set_script(SCRIPT_MODEL)
	_model.set("material", MATERIAL)
	_model.set("stralucitoare", PackedStringArray(["Lumini", "Ochi"]))
	_model.set("stralucire", 2.2)
	add_child(_model)
	_cap = _model.get_node("Cap")
	_brat_d = _model.get_node("BratDrept")
	_brat_s = _model.get_node("BratStang")
	_cristal = null
	_lumina = OmniLight3D.new()
	_lumina.light_color = ROSU_VRAJITOR
	_lumina.light_energy = 2.0
	_lumina.omni_range = 6.0
	_lumina.omni_attenuation = 1.2
	_lumina.light_volumetric_fog_energy = 1.0
	_lumina.position = Vector3(0, 1.5, 0.8)
	add_child(_lumina)
	_jar = VrajaAtac.particule(self, 24, 2.0, 0.05, [Color(1.0, 0.7, 0.4, 1.0), Color(0.95, 0.2, 0.1, 0.9), Color(0.4, 0.1, 0.1, 0.0)])
	_jar.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_jar.emission_box_extents = Vector3(0.5, 0.2, 0.5)
	_jar.position = Vector3(0, 0.3, 0)
	_jar.direction = Vector3.UP
	_jar.spread = 25.0
	_jar.initial_velocity_min = 0.3
	_jar.initial_velocity_max = 1.0
	_jar.gravity = Vector3(0, 0.3, 0)
	_jar.preprocess = 2.0
	_jar.emitting = true


func palma() -> Vector3:
	return _brat_s.to_global(MANA_S)


## N-are toiag: „vârful” e mâna dreaptă.
func varf_toiag() -> Vector3:
	return _brat_d.to_global(MANA_D)


## Se destramă în particule roșii care urcă spre cer (finalul, owner 25.11): modelul se topește pe pixeli, lumina se
## stinge, iar din el urcă scântei roșii tot mai sus. Apoi dispare din scenă.
func destramare(durata: float) -> Tween:
	_privire = Vector3.ZERO
	_jar.emitting = false
	var p := VrajaAtac.particule(get_parent(), 260, 3.5, 0.07, [Color(1.0, 0.75, 0.55, 1.0), Color(1.0, 0.22, 0.12, 0.95),
		Color(0.85, 0.08, 0.05, 0.6), Color(0.4, 0.04, 0.04, 0.0)])
	p.global_position = global_position + Vector3.UP * (plutire + 0.8)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.35, 0.8, 0.35)
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, 3.0, 0)
	p.emitting = true
	var lumina := OmniLight3D.new()
	lumina.light_color = ROSU_VRAJITOR
	lumina.light_energy = 0.0
	lumina.omni_range = 6.0
	get_parent().add_child(lumina)
	lumina.global_position = global_position + Vector3.UP * 1.2
	var aprinde := lumina.create_tween()
	aprinde.tween_property(lumina, "light_energy", 4.0, durata * 0.3)
	aprinde.tween_property(lumina, "light_energy", 0.0, durata * 0.7 + 1.5)
	aprinde.tween_callback(lumina.queue_free)
	# particulele mai urcă după ce el nu mai e (sunt ale scenei, nu ale lui)
	var scantei := p.create_tween()
	scantei.tween_interval(durata)
	scantei.tween_callback(func() -> void: p.emitting = false)
	scantei.tween_interval(4.0)
	scantei.tween_callback(p.queue_free)
	var t := create_tween().set_parallel()
	t.tween_method(func(v: float) -> void: ModelPS2.disparitie(_model, v), 0.0, 1.0, durata)
	t.tween_property(_lumina, "light_energy", 0.0, durata)
	t.chain().tween_callback(hide)
	return t
