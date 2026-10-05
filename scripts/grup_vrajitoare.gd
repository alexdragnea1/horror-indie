extends Node3D
## Un grup de vrăjitoare care stau la povești în living room-ul conacului (conac_interior.tscn, nodurile `Grup...`).
## Copiii nodului sunt vrăjitoarele (StaticBody3D cu un `Model` vrajitoare_salon_N.glb). Pe rând, câte una vorbește:
## gesticulează cu brațul drept (`BratDrept`), dă din cap și i se aud „vorbele” (bipurile vocii din dialog, la ea în
## poziție, fiecare cu vocea ei), iar celelalte se uită la ea, mai dau din cap, mai sorb din pocal (`BratStang`).
## Când treci pe lângă ele (`distanta_privire`), se mai uită și la tine. Peste tot, un murmur încet (`murmur`).
## Cu ele nu se vorbește (nu sunt Interactabil): sunt prea ocupate.

@export var murmur: AudioStream
@export var volum_murmur := -18.0
## Cât vorbește una până îi ia vorba alta (secunde, între cele două valori).
@export var replica_minima := 2.2
@export var replica_maxima := 4.8
@export var distanta_privire := 3.0
@export var volum_voce := -16.0

const VOCE := preload("res://sunete/dialog_voce.ogg")

var _vrajitoare: Array[Node3D] = []
var _voci: Array[float] = []
var _vorbeste := 0
var _pana_la_schimbare := 0.0
var _pana_la_bip := 0.0
var _timp := 0.0
var _sorb: Array[float] = []


func _ready() -> void:
	var centru := Vector3.ZERO
	for copil in get_children():
		if copil is Node3D and copil.has_node("Model/Cap"):
			_vrajitoare.append(copil)
			centru += (copil as Node3D).position
	if _vrajitoare.is_empty():
		return
	centru /= _vrajitoare.size()
	for v in _vrajitoare:
		# fiecare stă cu fața spre mijlocul grupului (modelele privesc spre +Z)
		var d := centru - v.position
		v.rotation.y = atan2(d.x, d.z) + randf_range(-0.25, 0.25)
		_voci.append(randf_range(0.62, 0.95))
		_sorb.append(randf_range(3.0, 12.0))
	_vorbeste = randi() % _vrajitoare.size()
	_timp = randf() * 10.0
	if murmur:
		var p := AudioStreamPlayer3D.new()
		p.stream = murmur
		p.bus = &"Ambianta"
		p.volume_db = volum_murmur
		p.unit_size = 2.5
		p.max_distance = 14.0
		add_child(p)
		p.position = centru + Vector3.UP * 1.5
		p.play(randf() * 8.0)


func _process(delta: float) -> void:
	if _vrajitoare.is_empty():
		return
	_timp += delta
	_pana_la_schimbare -= delta
	if _pana_la_schimbare <= 0.0:
		var alta := randi() % _vrajitoare.size()
		if alta == _vorbeste and _vrajitoare.size() > 1:
			alta = (alta + 1) % _vrajitoare.size()
		_vorbeste = alta
		_pana_la_schimbare = randf_range(replica_minima, replica_maxima)
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	for i in _vrajitoare.size():
		_anima(i, delta, jucator)
	# vorbele: bipuri scurte, în rafale, cu pauze între cuvinte
	_pana_la_bip -= delta
	if _pana_la_bip <= 0.0:
		var v := _vrajitoare[_vorbeste]
		var cap: Node3D = v.get_node("Model/Cap")
		Sunet.reda_la(VOCE, cap.global_position, volum_voce, 0.0, _voci[_vorbeste] * randf_range(0.92, 1.08))
		_pana_la_bip = randf_range(0.08, 0.13) if randf() > 0.12 else randf_range(0.3, 0.55)


func _anima(i: int, delta: float, jucator: Node3D) -> void:
	var v := _vrajitoare[i]
	var model: Node3D = v.get_node("Model")
	var cap: Node3D = model.get_node("Cap")
	var brat := model.get_node_or_null("BratDrept") as Node3D
	var pocal := model.get_node_or_null("BratStang") as Node3D
	var t := _timp + i * 1.7
	var vorbeste := i == _vorbeste
	# se legănă ușor de pe un picior pe altul
	model.rotation.z = sin(t * 0.9) * 0.015
	# la cine se uită: la cea care vorbește (cea care vorbește se uită prin grup), uneori la tine
	var tinta: Vector3 = _vrajitoare[_vorbeste].get_node("Model/Cap").global_position
	if vorbeste:
		var alta := _vrajitoare[(i + 1 + int(t * 0.3) % maxi(_vrajitoare.size() - 1, 1)) % _vrajitoare.size()]
		tinta = alta.get_node("Model/Cap").global_position
	if jucator and v.global_position.distance_to(jucator.global_position) < distanta_privire and sin(t * 0.7) > 0.2:
		tinta = jucator.global_position + Vector3.UP * 1.5
	var local := v.to_local(tinta)
	var unghi := clampf(atan2(local.x, local.z), -1.1, 1.1)
	cap.rotation.y = lerp_angle(cap.rotation.y, unghi, 1.0 - exp(-delta * 4.0))
	var dat_din_cap := sin(t * 5.0) * 0.06 if vorbeste else maxf(sin(t * 1.3), 0.0) * 0.05
	cap.rotation.x = lerpf(cap.rotation.x, dat_din_cap, 1.0 - exp(-delta * 6.0))
	if brat:
		var gest := Vector3.ZERO
		if vorbeste:
			gest = Vector3(-0.55 - 0.25 * sin(t * 3.1), 0.0, -0.25 - 0.15 * sin(t * 2.3 + 1.0))
		brat.rotation = brat.rotation.lerp(gest, 1.0 - exp(-delta * 5.0))
	if pocal:
		_sorb[i] -= delta
		var sus := 0.0
		if _sorb[i] < 0.0:
			sus = -0.9
			if _sorb[i] < -1.6:
				_sorb[i] = randf_range(6.0, 14.0)
		pocal.rotation.x = lerpf(pocal.rotation.x, sus, 1.0 - exp(-delta * 3.0))
