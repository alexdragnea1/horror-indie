extends CharacterBody3D
## Jucătorul la persoana întâi: WASD, Shift = fugi, mouse = privești,
## E = interacționezi, F = lanterna, Esc = eliberează mouse-ul.

@export var viteza_mers := 2.5
@export var viteza_fuga := 4.5
@export var sensibilitate_mouse := 0.0025
## Clătinarea capului când mergi.
@export var balans_frecventa := 2.4
@export var balans_amplitudine := 0.04

@onready var _cap: Node3D = $Cap
@onready var _camera: Camera3D = $Cap/Camera3D
@onready var _raza: RayCast3D = $Cap/Camera3D/RazaInteractiune
@onready var _lanterna: SpotLight3D = $Cap/Camera3D/Lanterna
@onready var _indiciu: Label = $HUD/Indiciu

var _gravitatie: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _distanta_mersa := 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if Dialog.activ:
			return
		# screen_relative = mișcarea în pixeli reali (nu în rezoluția mică a jocului)
		rotate_y(-event.screen_relative.x * sensibilitate_mouse)
		_cap.rotate_x(-event.screen_relative.y * sensibilitate_mouse)
		_cap.rotation.x = clamp(_cap.rotation.x, deg_to_rad(-85), deg_to_rad(85))
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("lanterna"):
		_lanterna.visible = not _lanterna.visible
	elif event.is_action_pressed("interact") and not Dialog.activ:
		var tinta := _tinta_privita()
		if tinta:
			tinta.interactioneaza()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravitatie * delta

	var intrare := Vector2.ZERO
	if not Dialog.activ:
		intrare = Input.get_vector("stanga", "dreapta", "inainte", "inapoi")
	var directie := (transform.basis * Vector3(intrare.x, 0, intrare.y)).normalized()
	var viteza := viteza_fuga if Input.is_action_pressed("alearga") else viteza_mers
	velocity.x = move_toward(velocity.x, directie.x * viteza, viteza * 10.0 * delta)
	velocity.z = move_toward(velocity.z, directie.z * viteza, viteza * 10.0 * delta)
	move_and_slide()

	var viteza_orizontala := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and viteza_orizontala > 0.1:
		_distanta_mersa += viteza_orizontala * delta
	_camera.position.y = sin(_distanta_mersa * balans_frecventa) * balans_amplitudine
	_camera.position.x = cos(_distanta_mersa * balans_frecventa * 0.5) * balans_amplitudine

	var tinta := _tinta_privita()
	_indiciu.text = tinta.indiciu if tinta and not Dialog.activ else ""


func _tinta_privita() -> Interactabil:
	var obiect := _raza.get_collider()
	if obiect is Interactabil and obiect.poate_fi_folosit():
		return obiect
	return null
