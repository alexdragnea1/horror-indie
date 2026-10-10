class_name PianConac
extends Interactabil
## Pianul cu coadă din sala conacului (conac_interior.tscn): „[E] Play the piano” → te așezi pe banchetă, te uiți la
## clape și se deschide claviatura de pe ecran (UIPian): două octave, de la do3 la do5, cu tastatura sau cu mouse-ul.
## Space ținut = pedala (notele sună mai departe după ce ridici degetul), Esc = te ridici.
## Notele vin din trei fișiere (pian_do3/do4/do5, sintetizate în sunete.sh), restul cu pitch_scale; fiecare notă e un
## AudioStreamPlayer3D din clape, deci sala o face să răsune (busul Efecte are reverb). Cât cânți, muzica sălii se
## retrage (Muzica.cedeaza = pianul, prin `acoperire`).

const NOTE := [preload("res://sunete/pian_do3.ogg"), preload("res://sunete/pian_do4.ogg"), preload("res://sunete/pian_do5.ogg")]
const DURATA_STINGERE := 0.22

## Unde stai pe banchetă (doar x și z; înălțimea rămâne a podelei), cu fața spre `clape`.
@export var loc_bancheta := Vector3(4.12, 0.0, -12.0)
## Mijlocul claviaturii.
@export var clape := Vector3(4.79, 0.77, -12.0)
## Înălțimea ochilor cât stai jos.
@export var ochi_jos := 1.22
@export var volum := 0.0

## Cât acoperă pianul muzica sălii (0..1, citit de MuzicaLoc prin `cedeaza`).
var acoperire := 0.0
var _in_curs := false
var _pedala := false
## nota (0..24) -> AudioStreamPlayer3D care sună acum
var _suna := {}
## notele ridicate cât era pedala apăsată: le stinge când ridici pedala
var _tinute := {}


func _ready() -> void:
	indiciu = "[E] Play the piano"


func poate_fi_folosit() -> bool:
	return activ and not _in_curs


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	var jucator := get_tree().get_first_node_in_group("jucator") as CharacterBody3D
	var cap: Node3D = jucator.get_node("Cap")
	var inaltime := cap.position.y
	var de_unde := jucator.global_position
	var c := Cutscena.porneste(self)
	jucator.seteaza_purtat(true)
	var loc := Vector3(loc_bancheta.x, jucator.global_position.y, loc_bancheta.z)
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(jucator, "global_position", loc, 0.8)
	t.tween_property(cap, "position:y", ochi_jos, 0.8)
	t.tween_property(self, "acoperire", 0.85, 1.5)
	await get_tree().create_timer(0.3).timeout
	await c.priveste(clape, 0.6)
	await t.finished
	c.queue_free()
	Stare.meniu_deschis = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var ui := UIPian.new()
	ui.apasata.connect(_apasa)
	ui.ridicata.connect(_ridica)
	ui.pedala.connect(_seteaza_pedala)
	get_tree().current_scene.add_child(ui)
	await ui.inchis
	_seteaza_pedala(false)
	for n in _suna.keys():
		_stinge(n, 0.8)
	# te ridici și te dai un pas înapoi, de unde ai venit
	var inapoi := loc + (de_unde - loc).normalized() * 0.55
	inapoi.y = loc.y
	t = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(jucator, "global_position", inapoi, 0.6)
	t.tween_property(cap, "position:y", inaltime, 0.6)
	t.tween_property(cap, "rotation:x", 0.0, 0.6)
	t.tween_property(self, "acoperire", 0.0, 3.0)
	await get_tree().create_timer(0.6).timeout
	jucator.seteaza_purtat(false)
	Stare.meniu_deschis = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_in_curs = false


## Nota `n` (0 = do3 ... 24 = do5): din fișierul cel mai apropiat (do3 / do4 / do5), cu pitch_scale.
func _apasa(n: int) -> void:
	if _suna.has(n):
		_stinge(n, 0.05)
	_tinute.erase(n)
	var baza := 0 if n <= 5 else (1 if n <= 17 else 2)
	var s := AudioStreamPlayer3D.new()
	s.stream = NOTE[baza]
	s.pitch_scale = pow(2.0, (n - baza * 12) / 12.0)
	s.bus = &"Efecte"
	s.volume_db = volum
	s.unit_size = 6.0
	s.max_distance = 40.0
	s.finished.connect(s.queue_free)
	add_child(s)
	# basul în stânga, sus în dreapta (claviatura merge de-a lungul lui Z: stai cu fața spre +X)
	s.global_position = clape + Vector3(0.0, 0.0, (n / 24.0 - 0.5) * 1.2)
	s.play()
	_suna[n] = s


func _ridica(n: int) -> void:
	if _pedala:
		_tinute[n] = true
	else:
		_stinge(n, DURATA_STINGERE)


func _seteaza_pedala(apasata: bool) -> void:
	_pedala = apasata
	if not apasata:
		for n in _tinute.keys():
			_stinge(n, DURATA_STINGERE * 2.0)
		_tinute.clear()


## Amortizorul cade pe coardă: nota se stinge în `durata` secunde.
func _stinge(n: int, durata: float) -> void:
	var s: AudioStreamPlayer3D = _suna.get(n)
	_suna.erase(n)
	if s == null or not is_instance_valid(s):
		return
	var t := s.create_tween()
	t.tween_property(s, "volume_db", s.volume_db - 40.0, durata).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_callback(s.queue_free)
