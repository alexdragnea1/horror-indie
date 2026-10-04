extends CharacterBody3D
## Jucătorul la persoana întâi: WASD, Shift = fugi, mouse = privești,
## E = interacționezi, F = lanterna, Esc = eliberează mouse-ul.

@export var viteza_mers := 2.5
@export var viteza_fuga := 4.5
@export var sensibilitate_mouse := 0.0025
## Clătinarea capului când mergi. Un pas = o clătinare completă (pasul se aude când capul e jos).
@export var balans_frecventa := 4.2
@export var balans_amplitudine := 0.04
## Cât de înaltă poate fi o treaptă pe care o urci fără să sari (bordura, pragul, rampa).
## Fără asta, corpul (un cilindru) se oprește în orice muchie, oricât de joasă.
@export var inaltime_treapta := 0.25

@export_group("Sunete")
## Pașii pe fiecare suprafață. Se alege la întâmplare, niciodată același de două ori la rând.
@export var pasi_lemn: Array[AudioStream] = []
@export var pasi_covor: Array[AudioStream] = []
@export var pasi_beton: Array[AudioStream] = []
@export var pasi_frunze: Array[AudioStream] = []
## Pe poteca din pădure (pământ bătătorit și pietriș).
@export var pasi_poteca: Array[AudioStream] = []
## 0 = volumul comun al efectelor (Sunet.VOLUM_EFECTE); schimbă doar dacă vrei intenționat altfel.
@export var volum_pasi_db := 0.0
## Scârțâitul podelei vechi, care se aude uneori peste pași (doar pe lemn).
@export var scartait_podea: AudioStream
@export_range(0.0, 1.0) var sansa_scartait := 0.07
@export var lanterna_pornita: AudioStream
@export var lanterna_oprita: AudioStream

## Pe ce calci când nu ești într-o ZonaSuprafata ("lemn" în casă, "frunze" afară).
@export var suprafata_implicita := "lemn"

## Pe ce calci acum ("lemn", "covor", "beton", "frunze", "poteca"). O schimbă ZonaSuprafata (în pădure, atmosfera_padure.gd).
var suprafata := "lemn"

@onready var _cap: Node3D = $Cap
@onready var _camera: Camera3D = $Cap/Camera3D
@onready var _raza: RayCast3D = $Cap/Camera3D/RazaInteractiune
@onready var _lanterna: SpotLight3D = $Cap/Camera3D/Lanterna
@onready var _indiciu: Label = $HUD/Indiciu

var _gravitatie: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _distanta_mersa := 0.0
var _numar_pas := 0
var _ultimul_pas: AudioStream
## Cât a sărit corpul la ultima treaptă; camera rămâne în urmă și ajunge din urmă lin.
var _decalaj_treapta := 0.0


func _ready() -> void:
	suprafata = suprafata_implicita
	# pistolul roz: se vede doar cât îl ai în inventar (vezi pistol.gd)
	_camera.add_child(Pistol.new())
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Salvare.jucator_pregatit(self)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _ocupat():
			return
		# screen_relative = mișcarea în pixeli reali (nu în rezoluția mică a jocului)
		rotate_y(-event.screen_relative.x * sensibilitate_mouse)
		_cap.rotate_x(-event.screen_relative.y * sensibilitate_mouse)
		_cap.rotation.x = clamp(_cap.rotation.x, deg_to_rad(-85), deg_to_rad(85))
	elif event is InputEventMouseButton and event.pressed and not Stare.meniu_deschis:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("lanterna"):
		_lanterna.visible = not _lanterna.visible
		Sunet.reda(lanterna_pornita if _lanterna.visible else lanterna_oprita, Sunet.VOLUM_EFECTE, 0.05)
	elif event.is_action_pressed("interact") and not _ocupat():
		var tinta := _tinta_privita()
		if tinta:
			tinta.interactioneaza()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravitatie * delta

	var intrare := Vector2.ZERO
	if not _ocupat():
		intrare = Input.get_vector("stanga", "dreapta", "inainte", "inapoi")
	var directie := (transform.basis * Vector3(intrare.x, 0, intrare.y)).normalized()
	var viteza := viteza_fuga if Input.is_action_pressed("alearga") else viteza_mers
	velocity.x = move_toward(velocity.x, directie.x * viteza, viteza * 10.0 * delta)
	velocity.z = move_toward(velocity.z, directie.z * viteza, viteza * 10.0 * delta)
	var y_inainte := global_position.y
	var era_pe_podea := is_on_floor()
	_urca_treapta(delta)
	move_and_slide()
	# urcat sau coborât brusc o treaptă: corpul sare, dar camera rămâne în urmă și ajunge lin
	var salt := global_position.y - y_inainte
	if era_pe_podea and is_on_floor() and absf(salt) > 0.02:
		_decalaj_treapta = clampf(_decalaj_treapta + salt, -0.3, 0.3)
	_decalaj_treapta = move_toward(_decalaj_treapta, 0.0, delta * 1.2)

	var viteza_orizontala := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and viteza_orizontala > 0.1:
		_distanta_mersa += viteza_orizontala * delta
	_camera.position.y = sin(_distanta_mersa * balans_frecventa) * balans_amplitudine - _decalaj_treapta
	_camera.position.x = cos(_distanta_mersa * balans_frecventa * 0.5) * balans_amplitudine
	# un pas nou de fiecare dată când capul trece prin punctul cel mai de jos al clătinării
	var pas := floori(_distanta_mersa * balans_frecventa / TAU + 0.25)
	if pas != _numar_pas:
		_numar_pas = pas
		_pas(viteza_orizontala > viteza_mers + 0.5)

	var tinta := _tinta_privita()
	_indiciu.text = tinta.indiciu if tinta and not _ocupat() else ""


## Dacă în față e o muchie joasă (bordură, prag), ridică jucătorul pe ea.
## Încearcă: sus cu inaltime_treapta, înainte cu cât ar merge cadrul ăsta, apoi jos până dă de podea.
## Urcă doar dacă acolo sus e podea adevărată (nu perete, nu pantă prea abruptă).
func _urca_treapta(delta: float) -> void:
	var miscare := Vector3(velocity.x, 0, velocity.z) * delta
	if not is_on_floor() or miscare.length() < 0.001:
		return
	var t := global_transform
	if not test_move(t, miscare):
		return  # nimic în față, merge normal
	var sus := Vector3.UP * inaltime_treapta
	var lovire := KinematicCollision3D.new()
	if test_move(t, sus, lovire):
		sus = lovire.get_travel()  # tavan jos: urcă doar cât se poate
	t.origin += sus
	if test_move(t, miscare):
		return  # e perete, nu treaptă
	t.origin += miscare
	if not test_move(t, -sus, lovire):
		return  # dincolo e gol, nu treaptă
	if lovire.get_normal().angle_to(Vector3.UP) > floor_max_angle:
		return
	t.origin += lovire.get_travel()
	if t.origin.y - global_position.y <= 0.01:
		return
	global_position = t.origin
	velocity.y = 0.0


func _pas(_fuge: bool) -> void:
	var lista: Array[AudioStream] = pasi_lemn
	match suprafata:
		"covor": lista = pasi_covor
		"beton": lista = pasi_beton
		"frunze": lista = pasi_frunze
		"poteca": lista = pasi_poteca
	if lista.is_empty():
		return
	var sunet: AudioStream = lista.pick_random()
	while lista.size() > 1 and sunet == _ultimul_pas:
		sunet = lista.pick_random()
	_ultimul_pas = sunet
	var volum := volum_pasi_db  # și la fugă la fel de tare (toate efectele au același volum)
	Sunet.reda(sunet, volum, 0.07)
	if suprafata == "lemn" and randf() < sansa_scartait:
		Sunet.reda(scartait_podea, volum, 0.15)


## Cât e true, jucătorul nu mai are fizică (gravitate, coliziuni, pași): îl mută o scenă din cod
## (ex. zborul pe mătură, sefa_vrajitoare.gd). Mersul și privitul le oprește oricum Stare.meniu_deschis.
func seteaza_purtat(purtat: bool) -> void:
	set_physics_process(not purtat)
	$Coliziune.set_deferred("disabled", purtat)
	velocity = Vector3.ZERO
	_camera.position = Vector3.ZERO


## Adevărat cât rulează un dialog, e deschis un meniu sau e ecranul negru: jucătorul stă pe loc.
func _ocupat() -> bool:
	return Dialog.activ or Stare.meniu_deschis or Tranzitie.activa


func _tinta_privita() -> Interactabil:
	var obiect := _raza.get_collider()
	if obiect is Interactabil and obiect.poate_fi_folosit():
		return obiect
	return null
