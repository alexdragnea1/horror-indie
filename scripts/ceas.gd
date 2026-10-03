extends Node3D
## Ceasul de perete: arată ora oprită de mai jos, iar secundarul sare la fiecare tic
## din sunet (bucla ceas.ogg are exact 4 tic-tacuri, la 0,05 s după fiecare secundă).

## Ora și minutul la care stau limbile (ceasul „merge”, dar ora nu se schimbă — e casa asta).
@export_range(0, 11) var ora := 11
@export_range(0, 59) var minut := 55

const DECALAJ_TIC := 0.05

@onready var _tic_tac: AudioStreamPlayer3D = $TicTac
@onready var _secundar: Node3D = $Model/Secundar

var _secunda := -1
var _bucle := 0
var _pozitie_anterioara := 0.0


func _ready() -> void:
	# limbile se învârt în jurul axei Z a modelului; minus = în sensul acelor de ceasornic
	$Model/Orar.rotation.z = -TAU * (ora + minut / 60.0) / 12.0
	$Model/Minutar.rotation.z = -TAU * minut / 60.0


func _process(_delta: float) -> void:
	if not _tic_tac.playing:
		return
	var pozitie := _tic_tac.get_playback_position()
	if pozitie < _pozitie_anterioara:
		_bucle += 1
	_pozitie_anterioara = pozitie
	var secunda := _bucle * 4 + floori(pozitie - DECALAJ_TIC)
	if secunda != _secunda:
		_secunda = secunda
		_secundar.rotation.z = -TAU * (secunda % 60) / 60.0
