class_name Calator
extends Node3D
## Tu, așezat pe scaun într-o scenă (autobuzul): nu te miști, doar te uiți în jur cu mouse-ul,
## în limitele de mai jos. Camera tremură puțin odată cu vehiculul.
## Pune nodul la ochii personajului, cu -Z spre „înainte”; copilul lui e Camera3D.

@export var sensibilitate_mouse := 0.0025
## Cât te poți întoarce (grade): stânga e pozitiv, dreapta negativ.
@export var limita_stanga := 125.0
@export var limita_dreapta := -100.0
@export var limita_sus := 45.0
@export var limita_jos := -60.0
## Cât tremură camera din cauza drumului (metri). 0 = deloc.
@export var tremur := 0.006

## Unghiurile privirii, în grade (0, 0 = drept înainte).
var unghi_orizontal := 0.0
var unghi_vertical := 0.0

@onready var _camera: Camera3D = $Camera3D
var _timp := 0.0
var _zguduire := 0.0
var _tween: Tween
var _baza_y := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_camera.current = true
	_baza_y = rotation.y  # încotro e „înainte” (nodul poate fi întors în scenă)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _ocupat():
			return
		unghi_orizontal = clampf(unghi_orizontal - event.screen_relative.x * sensibilitate_mouse * 57.3,
			limita_dreapta, limita_stanga)
		unghi_vertical = clampf(unghi_vertical - event.screen_relative.y * sensibilitate_mouse * 57.3,
			limita_jos, limita_sus)
	elif event is InputEventMouseButton and event.pressed and not Stare.meniu_deschis:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	_timp += delta
	_zguduire = move_toward(_zguduire, 0.0, delta * 1.5)
	rotation = Vector3(deg_to_rad(unghi_vertical), _baza_y + deg_to_rad(unghi_orizontal), 0.0)
	var t := tremur + _zguduire * 0.05
	_camera.position = Vector3(sin(_timp * 23.0) * 0.4 + sin(_timp * 37.0) * 0.3, sin(_timp * 29.0) * 0.6 + sin(_timp * 11.0) * 0.4, 0.0) * t


## Întoarce privirea singură (scena vrea să vezi ceva). Cât durează, mouse-ul nu mai mișcă privirea.
func priveste_spre(orizontal: float, vertical: float, durata := 1.0) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "unghi_orizontal", orizontal, durata)
	_tween.tween_property(self, "unghi_vertical", vertical, durata)
	await _tween.finished
	_tween = null


## Smucitură de cameră (o sperietură, o groapă în drum). 1 = tare.
func zguduie(cat := 1.0) -> void:
	_zguduire = maxf(_zguduire, cat)


func _ocupat() -> bool:
	return Stare.meniu_deschis or Tranzitie.activa or _tween != null
