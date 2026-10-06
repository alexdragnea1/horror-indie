extends Node
## Autoload "Sunet": sunete scurte, de oriunde din cod.
##   Sunet.reda(stream)                    -> fără poziție (pașii tăi, lanterna, interfața)
##   Sunet.reda_la(stream, pozitie)        -> vine dintr-un loc din lume (ușă, scârțâit)
## Canale (Audio, jos în editor): "Efecte" (cu ecou de cameră), "Ambianta", "Interfata".

## Cât de repede se pierde un sunet 3D cu distanța (mai mic = se aude doar de aproape).
const MARIME_SUNET_3D := 3.0
## Volumul TUTUROR efectelor (pași, uși, interfață, voci, sperieturi). Fișierele din sunete/ au toate
## aceeași tărie (-20 LUFS, vezi tools/sunete.sh), deci aici un singur număr le reglează pe toate.
const VOLUM_EFECTE := 0.0
## Volumul buclelor de fundal (vânt, bâzâit, frigider, ceas, motor, greieri, huruit): toate la fel între ele,
## dar mai jos decât efectele, ca să nu le acopere. În scene, `volume_db` al buclelor = valoarea asta.
const VOLUM_AMBIANTA := -14.0
## Volumul TUTUROR muzicilor (meniu, fața blocului, boombox-ul): cerut de owner, la fel de tare ca efectele.
const VOLUM_MUZICA := VOLUM_EFECTE
## Pașii TĂI (jucător, și în cutscene): 65% din amplitudinea de acum (cerut de owner) = -3,74 dB. Se aud tot timpul,
## deci stau sub restul efectelor, ca să nu obosească urechea.
const VOLUM_PASI := VOLUM_EFECTE - 3.74


## variatie = cât de mult se schimbă înălțimea la întâmplare (0,05 = ±5%), ca să nu sune identic.
func reda(stream: AudioStream, volum_db := 0.0, variatie := 0.0, bus := &"Efecte", inaltime := 1.0) -> void:
	if stream == null:
		return
	var sursa := AudioStreamPlayer.new()
	_pregateste(sursa, stream, volum_db, variatie, bus, inaltime)
	if bus == &"Interfata":
		sursa.process_mode = Node.PROCESS_MODE_ALWAYS  # se aude și în meniul de pauză
	add_child(sursa)
	sursa.play()


func reda_la(stream: AudioStream, pozitie: Vector3, volum_db := 0.0, variatie := 0.0, inaltime := 1.0) -> void:
	if stream == null:
		return
	var sursa := AudioStreamPlayer3D.new()
	_pregateste(sursa, stream, volum_db, variatie, &"Efecte", inaltime)
	sursa.unit_size = MARIME_SUNET_3D
	sursa.max_distance = 25.0
	add_child(sursa)
	sursa.global_position = pozitie
	sursa.play()


func _pregateste(sursa: Node, stream: AudioStream, volum_db: float, variatie: float, bus: StringName, inaltime: float) -> void:
	sursa.stream = stream
	sursa.volume_db = volum_db
	sursa.bus = bus
	sursa.pitch_scale = inaltime * (1.0 + randf_range(-variatie, variatie))
	sursa.finished.connect(sursa.queue_free)
