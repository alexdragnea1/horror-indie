class_name Autobuz
extends AnimatableBody3D
## Autobuzul de noapte (linia 13). Îl muți din alt script (global_position); el face singur restul:
## roțile se învârt cât a mers, motorul turează după viteză, caroseria se leagănă pe drum
## și „se apleacă” în față la frână. Ușile: `await deschide_usi()` / `await inchide_usi()`.
## Fața lui e spre +Z local, ușile pe partea -X.

signal urcare

## Cât se leagănă caroseria în mers (grade).
@export var leganare := 0.6
## Cât se apleacă în față când frânează (grade la 1 m/s²).
@export var aplecare_frana := 0.55
## Turația motorului: pitch la ralanti și cât crește la fiecare m/s.
@export var turatie_ralanti := 0.72
@export var turatie_pe_viteza := 0.045
## Cât de mult se deschid foile ușilor (grade).
@export var unghi_usi := 82.0
@export var durata_usi := 0.9

@export_group("Sunete")
@export var sunet_usi_deschise: AudioStream
@export var sunet_usi_inchise: AudioStream

## Viteza de acum, înainte (m/s). O calculează singur din cât s-a mutat.
var viteza := 0.0
var usi_deschise := false

const RAZA_ROATA := 0.5

@onready var _model: Node3D = $Model
@onready var _motor: AudioStreamPlayer3D = $Motor
var _roti: Array[Node3D] = []
var _foi: Array[Node3D] = []
var _semne_foi: Array[float] = []
var _intrari: Array[IntrareAutobuz] = []
var _ultima_pozitie := Vector3.ZERO
var _baza: Basis
var _timp := 0.0
var _aplecare := 0.0
var _viteza_neteda := 0.0


func _ready() -> void:
	_baza = transform.basis
	_ultima_pozitie = global_position
	for nume in ["RoataFS", "RoataFD", "RoataSS", "RoataSD"]:
		var r := _model.find_child(nume) as Node3D
		if r:
			_roti.append(r)
	for n in range(1, 4):
		for litera in ["A", "B"]:
			var foaie := _model.find_child("Usa%d%s" % [n, litera]) as Node3D
			if foaie == null:
				continue
			_foi.append(foaie)
			# foaia se rotește spre interior (+X): semnul ține de partea balamalei în care stă foaia
			var mesh := foaie as MeshInstance3D
			var centru := mesh.get_aabb().get_center().z if mesh else 1.0
			_semne_foi.append(signf(centru))
	for copil in find_children("*", "IntrareAutobuz", true, false):
		var intrare := copil as IntrareAutobuz
		_intrari.append(intrare)
		intrare.folosit.connect(func() -> void: urcare.emit())


## Mută autobuzul fără să se învârtă roțile (când îl pui la locul de start).
func teleporteaza(pozitie: Vector3) -> void:
	global_position = pozitie
	_ultima_pozitie = pozitie
	viteza = 0.0
	_viteza_neteda = 0.0


func deschide_usi() -> void:
	if usi_deschise:
		return
	usi_deschise = true
	_sunet_usi(sunet_usi_deschise)
	await _misca_usi(1.0)
	for intrare in _intrari:
		intrare.deschisa = true


func inchide_usi() -> void:
	if not usi_deschise:
		return
	usi_deschise = false
	for intrare in _intrari:
		intrare.deschisa = false
	_sunet_usi(sunet_usi_inchise)
	await _misca_usi(0.0)


func _misca_usi(cat: float) -> void:
	if _foi.is_empty():
		return
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for i in _foi.size():
		# pistonul împinge: o mică întârziere între uși, nu se mișcă toate deodată
		tween.tween_property(_foi[i], "rotation:y", deg_to_rad(unghi_usi) * _semne_foi[i] * cat, durata_usi) \
			.set_delay(0.08 * (i / 2))
	await tween.finished


func _sunet_usi(sunet: AudioStream) -> void:
	if sunet == null:
		return
	# câte un șuierat la fiecare ușă, puțin decalat (se aude de unde ești)
	for intrare in _intrari:
		var p := AudioStreamPlayer3D.new()
		p.stream = sunet
		p.volume_db = -4.0
		p.unit_size = 4.0
		p.pitch_scale = randf_range(0.95, 1.05)
		p.bus = &"Efecte"
		p.finished.connect(p.queue_free)
		intrare.add_child(p)
		p.play()


func _process(delta: float) -> void:
	if delta <= 0.0:
		return
	_timp += delta
	var mutare := global_position - _ultima_pozitie
	_ultima_pozitie = global_position
	var inainte := global_transform.basis.z.normalized()
	var v_noua := mutare.dot(inainte) / delta
	viteza = v_noua
	# accelerația din viteza netezită: cadrele au durate diferite, iar din viteza brută ar ieși zgomot
	var viteza_inainte := _viteza_neteda
	_viteza_neteda = lerpf(_viteza_neteda, viteza, 1.0 - exp(-delta * 6.0))
	var acceleratie := (_viteza_neteda - viteza_inainte) / delta

	for r in _roti:
		r.rotation.x += mutare.dot(inainte) / RAZA_ROATA

	# la frână se apleacă în față, apoi revine cu un mic balans (arcurile)
	var tinta_aplecare := clampf(-acceleratie * aplecare_frana, -3.0, 3.0) if absf(acceleratie) < 40.0 else 0.0
	_aplecare = lerpf(_aplecare, tinta_aplecare, 1.0 - exp(-delta * 4.0))
	var mers := clampf(absf(_viteza_neteda) / 10.0, 0.0, 1.0)
	var ruliu := (sin(_timp * 1.3) * 0.6 + sin(_timp * 3.7) * 0.25 + sin(_timp * 9.0) * 0.1) * leganare * mers
	var tangaj := _aplecare + (sin(_timp * 2.1) * 0.3 + sin(_timp * 7.3) * 0.12) * leganare * mers
	# ralanti: motorul diesel scutură tot autobuzul, puțin
	ruliu += sin(_timp * 70.0) * 0.04 * (1.0 - mers)
	var rotire := Basis.from_euler(Vector3(deg_to_rad(tangaj), 0.0, deg_to_rad(ruliu)))
	transform.basis = _baza * rotire

	if _motor:
		_motor.pitch_scale = turatie_ralanti + absf(_viteza_neteda) * turatie_pe_viteza
