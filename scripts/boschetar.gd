extends Personaj
## Tom Berone, boschetarul din fața magazinului de băuturi („LIQUOR”, lângă Gun Store, magazin_arme.tscn; owner 11.10).
## Stă jos pe un carton cu „SAVING MONEY FOR DRUGS”. La E: „Hey, do you have any change?” cu „Give him money” /
## „Don't give him anything”. Îi dai cât poți: $10, altfel $5, altfel $1 (Bani, în cenți); fără niciun dolar butonul e
## gri (Dialog.intreaba cu `dezactivate`). Prima dată când îi dai, Tom (magician în secret) ridică mâna și îți
## trimite o vrajă mov: scutul se reîncarcă de atunci într-o secundă (ScutJucator.MARCAJ_IMBUNATATIT). După aceea îi
## poți da bani și mai departe, dar doar îți mulțumește. „Don't give him anything” = gata.

const SUNET_BANI := preload("res://sunete/bancnota.ogg")
const SUNET_INCARCARE := preload("res://sunete/vraja_unda.ogg")
const SUNET_SCUT := preload("res://sunete/scut.ogg")
const SUNET_SCANTEI := preload("res://sunete/scantei_matura.ogg")
## Cât îi dai (cenți), în ordine: primul pe care îl ai.
const SUME := [1000, 500, 100]
const MOV := Color(0.7, 0.42, 1.0)

## Brațul drept (originea în umăr) și punctul din palmă (de acolo pleacă vraja).
@export var brat: Node3D
@export var palma: Node3D
## Cât își ridică brațul la vrajă (radiani, pe X: negativ = în față și în sus).
@export var ridicare_brat := -1.9

var _in_curs := false


func _ready() -> void:
	super()
	indiciu = "[E] Talk to Tom Berone"


func poate_fi_folosit() -> bool:
	return super() and not _in_curs


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	var suma := Bani.suma()
	var dai := 0
	for s in SUME:
		if suma >= s:
			dai = s
			break
	var ales := await Dialog.intreaba("Tom Berone: Hey, do you have any change?",
		PackedStringArray(["Give him money", "Don't give him anything"]), [] if dai > 0 else [0])
	if ales != 0 or dai <= 0:
		_in_curs = false
		return
	Bani.seteaza(Bani.suma() - dai)
	Sunet.reda(SUNET_BANI, Sunet.VOLUM_EFECTE)
	if Stare.e_marcat(ScutJucator.MARCAJ_IMBUNATATIT):
		await _spune(["Tom Berone: Thank you, I'll buy so many drugs."])
		_in_curs = false
		return
	await _spune(["Tom Berone: Thank you, I'll buy so many drugs.", "Tom Berone: Let me help you with something too."])
	await _vraja()
	Stare.marcheaza(ScutJucator.MARCAJ_IMBUNATATIT)
	await _spune(["Tom Berone: I've improved your shield spell.", "Tom Berone: Best of luck."])
	_in_curs = false


func _spune(replici_: Array) -> void:
	Dialog.spune(PackedStringArray(replici_))
	if Dialog.activ:
		await Dialog.terminat


## Vraja: ridică mâna dreaptă, în palmă se adună scântei mov și o lumină, apoi globul zboară în tine și te învăluie.
func _vraja() -> void:
	var jucator := _jucator() as Node3D
	var c := Cutscena.porneste(self)
	await c.priveste(palma.global_position, 0.6)
	var repaus := brat.rotation
	var sus := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	sus.tween_property(brat, "rotation:x", repaus.x + ridicare_brat, 0.7)
	Sunet.reda_la(SUNET_INCARCARE, palma.global_position, Sunet.VOLUM_EFECTE - 2.0)
	# în palmă: lumina care crește și scânteile care se strâng
	var lumina := OmniLight3D.new()
	lumina.light_color = MOV
	lumina.light_energy = 0.0
	lumina.omni_range = 3.0
	palma.add_child(lumina)
	var scantei := VrajaAtac.particule(palma, 40, 0.5, 0.03, [Color(1, 0.9, 1, 1), Color(MOV, 0.9), Color(MOV, 0.0)])
	scantei.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	scantei.emission_sphere_radius = 0.25
	scantei.radial_accel_min = -6.0
	scantei.radial_accel_max = -4.0
	scantei.gravity = Vector3.ZERO
	scantei.emitting = true
	create_tween().tween_property(lumina, "light_energy", 3.0, 1.6)
	await get_tree().create_timer(1.6).timeout
	# globul zboară din palmă în pieptul tău
	scantei.emitting = false
	var piept := jucator.global_position + Vector3.UP * 1.1
	var glob := VrajaAtac.trage(self, palma.global_position, piept, "mov", 0.5, 0.45, 0.3, false, false)
	Sunet.reda(SUNET_SCANTEI, Sunet.VOLUM_EFECTE)
	create_tween().tween_property(lumina, "light_energy", 0.0, 0.3)
	await glob.lovit
	# te învăluie: o lumină mov în jurul tău și scântei care urcă pe lângă tine, cu sunetul scutului
	Sunet.reda(SUNET_SCUT, Sunet.VOLUM_EFECTE - 1.0)
	var aura := OmniLight3D.new()
	aura.light_color = MOV
	aura.light_energy = 4.0
	aura.omni_range = 4.0
	get_tree().current_scene.add_child(aura)
	aura.global_position = piept
	var urca := VrajaAtac.particule(get_tree().current_scene, 60, 1.2, 0.04, [Color(1, 0.9, 1, 1), Color(MOV, 0.8), Color(MOV, 0.0)])
	urca.global_position = jucator.global_position + Vector3.UP * 0.2
	urca.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	urca.emission_ring_axis = Vector3.UP
	urca.emission_ring_radius = 0.7
	urca.emission_ring_inner_radius = 0.5
	urca.emission_ring_height = 0.1
	urca.direction = Vector3.UP
	urca.spread = 10.0
	urca.initial_velocity_min = 1.0
	urca.initial_velocity_max = 1.8
	urca.gravity = Vector3.ZERO
	urca.one_shot = true
	urca.explosiveness = 0.3
	urca.emitting = true
	var stinge := create_tween()
	stinge.tween_property(aura, "light_energy", 0.0, 1.4).set_trans(Tween.TRANS_SINE)
	stinge.tween_callback(aura.queue_free)
	get_tree().create_timer(2.0).timeout.connect(urca.queue_free)
	# lasă mâna jos
	var jos := create_tween().set_trans(Tween.TRANS_SINE)
	jos.tween_property(brat, "rotation:x", repaus.x, 0.8)
	await get_tree().create_timer(0.9).timeout
	lumina.queue_free()
	scantei.queue_free()
	c.queue_free()
	Stare.meniu_deschis = false
