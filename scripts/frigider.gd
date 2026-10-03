extends Interactabil
## Frigiderul: la E se deschide ușa, se aprinde lumina dinăuntru, se spun "replici",
## iar după ultima replică ușa se închide la loc.

## Ușa care se rotește (originea ei e balamaua).
@export var usa: Node3D
## Lumina dinăuntru (se aprinde doar cât e ușa deschisă).
@export var lumina: Light3D
## Cu cât se deschide ușa (grade, minus = spre jucător).
@export var unghi_deschidere := -105.0
## Cât durează deschiderea (secunde).
@export var durata := 0.6
## Bâzâitul compresorului (se aude mai tare cât e ușa deschisă).
@export var bazait: AudioStreamPlayer3D
## Garnitura care se dezlipește la deschidere și borcanele care zornăie la închidere.
@export var sunet_deschidere: AudioStream
@export var sunet_inchidere: AudioStream

var _deschis := false
var _energie_lumina := 0.0
var _volum_bazait := 0.0


func _ready() -> void:
	if lumina:
		_energie_lumina = lumina.light_energy
		lumina.light_energy = 0.0
	if bazait:
		_volum_bazait = bazait.volume_db


func poate_fi_folosit() -> bool:
	return not _deschis


func interactioneaza() -> void:
	if _deschis:
		return
	_deschis = true
	folosit.emit()
	Sunet.reda_la(sunet_deschidere, _loc_usa(), Sunet.VOLUM_EFECTE, 0.05)
	await _misca_usa(unghi_deschidere, _energie_lumina, 5.0)
	if not replici.is_empty():
		Dialog.spune(replici)
		await Dialog.terminat
	await _misca_usa(0.0, 0.0, 0.0)
	Sunet.reda_la(sunet_inchidere, _loc_usa(), Sunet.VOLUM_EFECTE, 0.05)
	_deschis = false


func _misca_usa(unghi: float, energie: float, bazait_in_plus_db: float) -> void:
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	if usa:
		tween.tween_property(usa, "rotation:y", deg_to_rad(unghi), durata)
	if lumina:
		tween.tween_property(lumina, "light_energy", energie, durata * 0.3)
	if bazait:
		tween.tween_property(bazait, "volume_db", _volum_bazait + bazait_in_plus_db, durata)
	await tween.finished


func _loc_usa() -> Vector3:
	return global_position + Vector3.UP
