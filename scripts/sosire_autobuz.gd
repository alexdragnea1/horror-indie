extends Node
## Autobuzul de noapte vine în stație după ce ai vorbit cu baba.
## Pornește de departe (din ceață, doar farurile), frânează, își deschide ușile și așteaptă.
## Când urci ([E] la o ușă), pornește scena din autobuz (`scena_drum`), prin Tranzitie.
## Dacă pornești jocul cu marcajul deja pus (Continue), autobuzul vine din nou după `intarziere`.
## Al doilea nod (`AutobuzLexy`, ziua): vine după mesajul de pe telefon și te duce la Lexy (`scena_drum` = casa ei).

## Autobuzul din scenă (scenes/autobuz.tscn), cu fața spre direcția din care vine.
@export var autobuz: Autobuz
## Marcajul după care vine (îl pune baba la sfârșitul primei conversații).
@export var marcaj := "a_vorbit_cu_baba"
## După marcajul ăsta nu mai vine deloc (te-a adus Head Witch acasă pe mătură).
@export var marcaj_oprire := "a_zburat_acasa"
## La câte secunde după conversație apare.
@export var intarziere := 5.0
## Unde oprește (ușa din mijloc în dreptul stației).
@export var loc_oprire := Vector3(9.5, 0.02, 16.9)  # y = fața asfaltului (roțile stau pe el)
## De cât de departe vine (metri, din spatele locului de oprire).
@export var distanta_start := 75.0
## Viteza de mers (m/s; 10 ≈ 36 km/h) și cât de tare frânează (m/s²).
@export var viteza_mers := 10.0
@export var decelerare := 2.6
## După câte secunde de la oprire se deschid ușile.
@export var pauza_usi := 0.8

@export_group("La urcare")
@export_file("*.tscn") var scena_drum := "res://scenes/autobuz_drum.tscn"
## Marcajul pus când urci.
@export var marcaj_urcare := "a_urcat_in_autobuz"
## Numele locului, arătat după tranziție.
@export_multiline var titlu := "Night line 13\n11:59 PM"
## Ce se aude pe negru: urci treptele, ușile se închid, pornește.
@export var sunete_urcare: Array[AudioStream] = []
@export var sunet_frana: AudioStream

enum { ASTEAPTA, VINE, OPRIT, PLECAT }
var _stare := ASTEAPTA
var _viteza := 0.0
var _directie := Vector3.ZERO
var _frana_pornita := false

func _ready() -> void:
	autobuz.visible = false
	autobuz.process_mode = Node.PROCESS_MODE_DISABLED
	# în meniul principal scena e doar fundal: acolo autobuzul nu vine
	await get_tree().process_frame
	if get_tree().get_first_node_in_group("jucator") == null:
		return
	if Stare.e_marcat(marcaj_oprire):
		return
	autobuz.urcare.connect(_urca)
	if Stare.e_marcat(marcaj):
		_porneste()
	else:
		Stare.schimbat.connect(_verifica)

func _verifica() -> void:
	if _stare == ASTEAPTA and Stare.e_marcat(marcaj):
		Stare.schimbat.disconnect(_verifica)
		_porneste()

func _porneste() -> void:
	_stare = VINE
	# trebuie să treacă și dialogul (marcajul se pune după ultima replică, dar ne asigurăm)
	while Dialog.activ:
		await Dialog.terminat
	await get_tree().create_timer(intarziere).timeout
	_directie = autobuz.global_transform.basis.z.normalized()
	_directie.y = 0.0
	_directie = _directie.normalized()
	autobuz.process_mode = Node.PROCESS_MODE_INHERIT
	autobuz.visible = true
	autobuz.teleporteaza(loc_oprire - _directie * distanta_start)
	_viteza = viteza_mers
	_frana_pornita = false

func _process(delta: float) -> void:
	if _stare != VINE or not autobuz.visible:
		return
	var ramas := (loc_oprire - autobuz.global_position).dot(_directie)
	# frânează la timp ca să se oprească exact în stație: v² = 2·a·d
	var distanta_franare := _viteza * _viteza / (2.0 * decelerare)
	if ramas <= distanta_franare + 0.05:
		if not _frana_pornita:
			_frana_pornita = true
			if sunet_frana:
				var p := AudioStreamPlayer3D.new()
				p.stream = sunet_frana
				p.unit_size = 6.0
				p.max_distance = 80.0
				p.volume_db = Sunet.VOLUM_EFECTE
				p.finished.connect(p.queue_free)
				autobuz.add_child(p)
				p.play()
		_viteza = sqrt(maxf(2.0 * decelerare * maxf(ramas, 0.0), 0.0))
	if ramas <= 0.02 or _viteza < 0.05:
		autobuz.global_position = Vector3(loc_oprire.x, autobuz.global_position.y, loc_oprire.z)
		_stare = OPRIT
		_opreste()
		return
	autobuz.global_position += _directie * minf(_viteza * delta, ramas)

func _opreste() -> void:
	await get_tree().create_timer(pauza_usi).timeout
	await autobuz.deschide_usi()

func _urca() -> void:
	if _stare != OPRIT or Tranzitie.activa:
		return
	_stare = PLECAT
	Stare.marcheaza(marcaj_urcare)
	Tranzitie.mergi_la(scena_drum, titlu, sunete_urcare)
