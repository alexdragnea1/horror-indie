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
## Mocheta subțire pe beton (primăria). Goală = se folosesc pașii de covor.
@export var pasi_mocheta: Array[AudioStream] = []
## Implicit Sunet.VOLUM_PASI (65% din volumul de înainte); schimbă doar dacă vrei intenționat altfel.
@export var volum_pasi_db := Sunet.VOLUM_PASI
## Scârțâitul podelei vechi, care se aude uneori peste pași (doar pe lemn).
@export var scartait_podea: AudioStream
@export_range(0.0, 1.0) var sansa_scartait := 0.07
@export var lanterna_pornita: AudioStream
@export var lanterna_oprita: AudioStream

## Pe ce calci când nu ești într-o ZonaSuprafata ("lemn" în casă, "frunze" afară).
@export var suprafata_implicita := "lemn"

## Pe ce calci acum ("lemn", "covor", "mocheta", "beton", "frunze", "poteca"). O schimbă ZonaSuprafata (în pădure, atmosfera_padure.gd).
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
## Pentru Unstuck (meniul de pauză, owner 17.11): locurile pe unde ai stat pe podea, cel mai nou la sfârșit.
## Primul e locul unde ai apărut în scenă și nu se șterge niciodată (ultima soluție).
var _locuri_sigure: Array[Vector3] = []
var _ceas_loc_sigur := 0.0
var _ceas_in_mana := 0.0
## Avântul (furca, owner 24.11): cât mai ține și cu ce viteză (orizontală) te duce înainte, peste mersul tău.
var _avant_timp := 0.0
var _avant_viteza := Vector3.ZERO
const PAS_LOC_SIGUR := 0.5  # s între două locuri notate
const LOCURI_SIGURE_MAX := 60  # ~30 s de mers în urmă


func _ready() -> void:
	suprafata = suprafata_implicita
	# fiecare scenă are un jucător nou: lanterna rămâne cum ai lăsat-o
	_lanterna.visible = Stare.lanterna
	# ce ții în mână (ales din inventar): pistolul roz și cel de aur, vraja Fireball au scriptul lor, restul (mătura) ObiectInMana
	_camera.add_child(Pistol.new())
	_camera.add_child(Pistol.auriu())
	var vraja := VrajaFoc.new()
	vraja.name = "VrajaFoc"  # helga.gd o caută după nume (lecția)
	_camera.add_child(vraja)
	_camera.add_child(ObiectInMana.new())
	# scutul (Ctrl), după ce te-a învățat Head Witch (sefa_apus.gd): o sferă în jurul tău, nu ceva ținut în mână
	add_child(ScutJucator.new())
	# armele de la Gun Store (magazin_arme.tscn), fiecare cu animația ei de tras
	_camera.add_child(Cutit.new())
	_camera.add_child(Katana.new())  # (din parcarea barului URBAN, katana_jos.gd)
	_camera.add_child(SabieBlestemata.new())  # (din piatra din curtea barului URBAN, sabie_piatra.gd)
	_camera.add_child(Shotgun.new())
	_camera.add_child(AK47.new())
	_camera.add_child(Bazooka.new())
	_camera.add_child(Gauntlet.new())  # (roata din pivnița lui Jean, roata_noroc.gd)
	_camera.add_child(Furca.new())  # (din spatele casei din dreapta primăriei, furca_jos.gd)
	# ce ții în mână se vede și când ești lipit de perete (owner 17.11): tot ce apare sub cameră, de acum încolo
	get_tree().node_added.connect(_nod_adaugat)
	InManaVizibil.aplica.call_deferred(_camera)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Salvare.jucator_pregatit(self)
	# ce ai aruncat pe jos aici data trecută
	Stare.pune_aruncate.call_deferred()


## Orice nod nou din scenă: dacă e un model sub cameră (ce ții în mână), primește materialul „în mână”; dacă a plecat
## de sub ea (aruncat în lume), îl primește înapoi pe al lui. Amânat, după _ready-ul nodului.
func _nod_adaugat(nod: Node) -> void:
	if nod is GeometryInstance3D:
		InManaVizibil.verifica.call_deferred(nod, _camera)


func _process(delta: float) -> void:
	# din când în când: un script poate schimba materialul unui obiect din mână fără să-l scoată din scenă
	_ceas_in_mana += delta
	if _ceas_in_mana > 0.5:
		_ceas_in_mana = 0.0
		InManaVizibil.aplica(_camera)


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
		Stare.lanterna = _lanterna.visible
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
	# Swift Boots (roata din pivnița lui Jean, owner 16.11): cât le ai în inventar, mergi și fugi cu 30% mai repede
	var bonus := RoataNoroc.BONUS_GHETE if Stare.are_obiect(RoataNoroc.ID_GHETE) else 1.0
	# țigara (owner 18.11): un minut după ce tragi din ea, încă 10% (nu se adună dacă fumezi mai multe)
	bonus *= Tigari.bonus_viteza()
	var viteza := (viteza_fuga if Input.is_action_pressed("alearga") else viteza_mers) * bonus
	velocity.x = move_toward(velocity.x, directie.x * viteza, viteza * 10.0 * delta)
	velocity.z = move_toward(velocity.z, directie.z * viteza, viteza * 10.0 * delta)
	if _avant_timp > 0.0:
		_avant_timp -= delta
		velocity.x = _avant_viteza.x
		velocity.z = _avant_viteza.z
		if _avant_timp <= 0.0:
			# la capăt te oprești (altfel mai alunecai încă 2 m până frânai), mersul pornește iar de la tine
			velocity.x = directie.x * viteza
			velocity.z = directie.z * viteza
	var y_inainte := global_position.y
	var era_pe_podea := is_on_floor()
	if _urca_treapta(delta):
		# treapta te-a dus deja înainte cu pasul cadrului ăstuia: move_and_slide face doar restul (gravitația),
		# altfel pe scări ai merge de două ori mai repede
		var viteza_plan := Vector2(velocity.x, velocity.z)
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		velocity.x = viteza_plan.x
		velocity.z = viteza_plan.y
	else:
		var de_unde := global_position
		var viteza_dorita := Vector2(velocity.x, velocity.z)
		move_and_slide()
		# blocat de un „perete” la o muchie fantomă (îmbinarea pantă–podea, sus pe treptele lui Lexy): fizica oprește
		# corpul deși drumul e liber; încearcă trecerea ca la o treaptă, fără verificarea de pantă
		if is_on_wall() and viteza_dorita.length() > 0.5 \
				and Vector2(global_position.x - de_unde.x, global_position.z - de_unde.z).length() < 0.002:
			velocity.x = viteza_dorita.x
			velocity.z = viteza_dorita.y
			var vy := velocity.y
			if not _urca_treapta(delta, true):
				velocity = Vector3(0.0, vy, 0.0)
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
		_pas(viteza_orizontala > viteza_mers * bonus + 0.5)

	var tinta := _tinta_privita()
	_indiciu.text = tinta.indiciu if tinta and not _ocupat() else ""
	_noteaza_loc_sigur(delta)


## Notează din când în când unde stai pe podea (pentru Unstuck). Primul loc e cel de la intrarea în scenă.
## Un avânt scurt înainte (furca): `viteza` = viteza orizontală (m/s), timp de `durata` secunde, în locul mersului.
## Zidurile și oamenii te opresc (move_and_slide), deci nu treci prin nimic.
func avant(viteza: Vector3, durata: float) -> void:
	_avant_viteza = Vector3(viteza.x, 0.0, viteza.z)
	_avant_timp = durata
	if durata <= 0.0:
		# oprit (ai lovit ceva): stai pe loc, nu mai aluneci
		velocity.x = 0.0
		velocity.z = 0.0


func _noteaza_loc_sigur(delta: float) -> void:
	_ceas_loc_sigur += delta
	if not is_on_floor() or (_ceas_loc_sigur < PAS_LOC_SIGUR and not _locuri_sigure.is_empty()):
		return
	_ceas_loc_sigur = 0.0
	var aici := global_position
	if not _locuri_sigure.is_empty() and _locuri_sigure.back().distance_to(aici) < 0.4:
		return  # stai pe loc (sau te freci de un perete): nimic nou
	if not _loc_liber(aici):
		return
	_locuri_sigure.append(aici)
	if _locuri_sigure.size() > LOCURI_SIGURE_MAX:
		_locuri_sigure.remove_at(1)  # păstrează locul de la intrare


## Corpul încape aici (nu intră în nimic) și dedesubt e podea?
func _loc_liber(p: Vector3) -> bool:
	var spatiu := get_world_3d().direct_space_state
	var forma := PhysicsShapeQueryParameters3D.new()
	forma.shape = ($Coliziune as CollisionShape3D).shape
	# puțin deasupra podelei, ca să nu atingă podeaua însăși
	forma.transform = Transform3D(Basis(), p + Vector3(0.0, 0.85 + 0.06, 0.0))
	forma.collision_mask = collision_mask
	forma.exclude = [get_rid()]
	if not spatiu.intersect_shape(forma, 1).is_empty():
		return false
	var raza := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.3, p + Vector3.DOWN * 1.0, collision_mask, [get_rid()])
	return not spatiu.intersect_ray(raza).is_empty()


## Cel mai apropiat loc liber în jurul lui `p` (fără `p` însuși), sau null. Pe fiecare inel, direcțiile încep cu
## cea în care privești, ca la egalitate să te mute înainte.
func _loc_liber_aproape(p: Vector3) -> Variant:
	var spatiu := get_world_3d().direct_space_state
	var inceput := -global_basis.z
	inceput.y = 0.0
	for inel in range(1, 13):
		var raza := inel * 0.25
		for k in 16:
			var dir := inceput.rotated(Vector3.UP, TAU * k / 16.0).normalized()
			var c := p + dir * raza
			var q := PhysicsRayQueryParameters3D.create(c + Vector3.UP * 0.5, c + Vector3.DOWN * 1.0, collision_mask, [get_rid()])
			var lovit := spatiu.intersect_ray(q)
			if lovit.is_empty() or (lovit.normal as Vector3).angle_to(Vector3.UP) > floor_max_angle:
				continue
			var pe_podea: Vector3 = lovit.position
			if _loc_liber(pe_podea):
				return pe_podea
	return null


## Se poate folosi Unstuck acum? Nu cât te mută o scenă din cod (zbor, cutscene) și nu în dialog.
func poate_desbloca() -> bool:
	return is_physics_processing() and not Dialog.activ and not Tranzitie.activa


## Unstuck (meniul de pauză, owner 17.11: „doar să te miște puțin într-o parte unde vede că e liber”): caută cel mai
## apropiat loc liber din jur (inele la 0,25 m, până la 3 m, 16 direcții; podeaua căutată cu o rază de la +0,5 m la
## -1 m: nu te urcă pe mese sau bănci),
## în afară de locul unde ești. Doar dacă nu e niciunul (ex. ai căzut sub hartă), te întoarce la cel mai recent loc
## sigur pe unde ai mers, apoi la locul unde ai intrat în scenă.
func desblocheaza() -> void:
	if not poate_desbloca():
		return
	var aproape: Variant = _loc_liber_aproape(global_position)
	if aproape != null:
		global_position = aproape
		velocity = Vector3.ZERO
		_decalaj_treapta = 0.0
		return
	var tinta: Variant = null
	for i in range(_locuri_sigure.size() - 1, -1, -1):
		var p := _locuri_sigure[i]
		if p.distance_to(global_position) >= 1.0 and _loc_liber(p):
			tinta = p
			break
	if tinta == null:
		if _locuri_sigure.is_empty():
			return
		tinta = _locuri_sigure[0]
	global_position = tinta
	velocity = Vector3.ZERO
	_decalaj_treapta = 0.0
	# locurile de după cel ales ar putea fi chiar locul blocat: le uităm
	var k := _locuri_sigure.find(tinta)
	if k >= 0:
		_locuri_sigure.resize(k + 1)
	_ceas_loc_sigur = 0.0


## Dacă în față e o muchie joasă (bordură, prag), ridică jucătorul pe ea.
## Încearcă: sus cu inaltime_treapta, înainte cu cât ar merge cadrul ăsta, apoi jos până dă de podea.
## Urcă doar dacă acolo sus e podea adevărată (nu perete, nu pantă prea abruptă). Tot de aici treci peste muchiile
## „fantomă” de la același nivel (fizica le vede ca pe un perete).
## O pantă pe care se poate merge nu e treaptă: pe ea te duce move_and_slide (altfel, pe fiecare pantă, treapta te
## muta înainte și move_and_slide încă o dată: viteză dublă la urcare). Întoarce true dacă te-a urcat.
## `muchie_fantoma` = move_and_slide te-a oprit deja deși în față e o pantă/podea: sari peste verificarea de pantă.
func _urca_treapta(delta: float, muchie_fantoma := false) -> bool:
	var miscare := Vector3(velocity.x, 0, velocity.z) * delta
	if not is_on_floor() or miscare.length() < 0.001:
		return false
	var t := global_transform
	var lovire := KinematicCollision3D.new()
	if not test_move(t, miscare, lovire):
		return false  # nimic în față, merge normal
	if lovire.get_normal().angle_to(Vector3.UP) <= floor_max_angle and not muchie_fantoma:
		return false  # pantă, nu treaptă
	var sus := Vector3.UP * inaltime_treapta
	if test_move(t, sus, lovire):
		sus = lovire.get_travel()  # tavan jos: urcă doar cât se poate
	t.origin += sus
	if test_move(t, miscare):
		return false  # e perete, nu treaptă
	t.origin += miscare
	if not test_move(t, -sus, lovire):
		return false  # dincolo e gol, nu treaptă
	if lovire.get_normal().angle_to(Vector3.UP) > floor_max_angle:
		return false
	t.origin += lovire.get_travel()
	# dincolo e tot la nivelul tău (±1 cm): nu e treaptă, ci o muchie „fantomă” (îmbinarea dintre o pantă și o podea,
	# ca sus pe treptele lui Lexy, unde fizica raportează un perete și oprește corpul). Te duce peste ea, nu te lasă blocat.
	if t.origin.y - global_position.y < -0.01:
		return false
	global_position = t.origin
	velocity.y = 0.0
	return true


func _pas(_fuge: bool) -> void:
	var lista: Array[AudioStream] = pasi_lemn
	match suprafata:
		"covor": lista = pasi_covor
		"beton": lista = pasi_beton
		"frunze": lista = pasi_frunze
		"poteca": lista = pasi_poteca
		"mocheta": lista = pasi_mocheta if not pasi_mocheta.is_empty() else pasi_covor
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
	if purtat:
		_indiciu.text = ""
	$Coliziune.set_deferred("disabled", purtat)
	velocity = Vector3.ZERO
	_camera.position = Vector3.ZERO


## Adevărat cât rulează un dialog, e deschis un meniu sau e ecranul negru: jucătorul stă pe loc.
func _ocupat() -> bool:
	return Dialog.activ or Stare.meniu_deschis or Tranzitie.activa


func _tinta_privita() -> Interactabil:
	var obiect := _raza.get_collider()
	# o zonă de E mai mare decât obiectul (pe stratul 4, ex. barmanul din spatele scaunului): meta „interactabil”
	if obiect and obiect.has_meta("interactabil"):
		obiect = obiect.get_meta("interactabil")
	if obiect is Interactabil and obiect.poate_fi_folosit():
		return obiect
	return null
