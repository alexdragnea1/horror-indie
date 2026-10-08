extends "res://scripts/sefa_conac.gd"
## Head Witch la motelul din orașul vecin (motel.tscn, nodul `HeadWitchMotel`): prima dată scena începe în aer, pe
## mătură (aterizarea e cea din sefa_conac.gd: `drum`, `priveste_spre`, `priveste_la_final` = geamul roșu al camerei 122),
## coborâți în parcare, mătura îi dispare din mână. Apoi, la E: `replici_motel` (owner). Nu dispare și nu intră nicăieri
## (`marcaj_intrat` gol); după ce afli camera de la receptioneră (`marcaj_camera`) nu mai are ce să-ți spună și te
## așteaptă lângă ușa camerei 122 (`loc_la_usa`; o mută acolo cât ești în recepție, deci n-o vezi plecând).
## Lupta cu Warlock-ul (lupta_warlock.gd) o comandă de aici încolo: o doboară (`cade`), zace (`culca_te`), se ridică
## (`ridica_te`), îi absoarbe puterile și dispare. După `marcaj_plecata` nu mai e la motel.
## Replicile sunt ale owner-ului: nu le corecta.

@export_multiline var replici_motel: PackedStringArray = []
## După el (pus de receptionera.gd) nu mai vorbește cu tine aici.
@export var marcaj_camera := "stie_camera_warlock"
## Unde te așteaptă după ce afli camera (lângă ușa 122, în dreapta ta când bați la ușă) și încotro privește (radiani; -2,4 =
## spre ușă și spre tine).
@export var loc_la_usa := Vector3(1.85, 0.15, -8.75)
@export var unghi_la_usa := -2.4
## După lupta cu Warlock-ul (i-a luat puterile și a dispărut).
@export var marcaj_plecata := "head_witch_a_plecat_de_la_motel"


func _ready() -> void:
	super()
	if Stare.e_marcat(marcaj_plecata):
		hide()
		_dezactiveaza_coliziunea()
		return
	if Stare.e_marcat(marcaj_camera):
		pune_la_usa()
	else:
		Stare.schimbat.connect(_la_schimbare)


func _la_schimbare() -> void:
	if Stare.e_marcat(marcaj_camera):
		Stare.schimbat.disconnect(_la_schimbare)
		pune_la_usa()


func pune_la_usa() -> void:
	global_position = loc_la_usa
	rotation.y = unghi_la_usa


func poate_fi_folosit() -> bool:
	return not _vorbeste and not mort and Stare.e_marcat(marcaj_sosire) and not Stare.e_marcat(marcaj_camera)


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_vorbeste = true
	folosit.emit()
	var intoarcere := intoarce_spre(_jucator())
	if intoarcere:
		await intoarcere.finished
	Dialog.spune(replici_motel)
	if Dialog.activ:
		await Dialog.terminat
	_vorbeste = false


## Mâna ei dreaptă (în lume): de aici trage puterile Warlock-ului.
func palma() -> Vector3:
	return brat.global_transform * MANA


## Ridică brațul drept spre `punct` (în lume), cu palma spre el.
func intinde_bratul(punct: Vector3, durata: float) -> Tween:
	var umar := brat.global_position
	var d := (brat.get_parent() as Node3D).global_basis.orthonormalized().inverse() * (punct - umar).normalized()
	# brațul atârnă pe -Y; rotația pe X îl duce înainte (+Z), cea pe Z în lături
	var x := -atan2(d.z, -d.y)
	var z := atan2(d.x, Vector2(d.y, d.z).length())
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(brat, "rotation", Vector3(x, 0.0, z), durata)
	return t


## Dispare cu totul: fum (`culoare`), un fulger de lumină, se strânge pe verticală. Apoi nu mai e la motel.
func dispari_de_tot(culoare: Color) -> void:
	var unde := global_position + Vector3.UP * 1.0
	Sunet.reda_la(SUNET_MATURA, unde, Sunet.VOLUM_EFECTE, 0.05)
	for k in 4:
		_fum(unde + Vector3(randf_range(-0.3, 0.3), k * 0.4 - 0.5, randf_range(-0.3, 0.3)))
	var fulger := OmniLight3D.new()
	fulger.light_color = culoare
	fulger.light_energy = 5.0
	fulger.omni_range = 7.0
	get_tree().current_scene.add_child(fulger)
	fulger.global_position = unde
	var stinge := fulger.create_tween()
	stinge.tween_property(fulger, "light_energy", 0.0, 0.9)
	stinge.tween_callback(fulger.queue_free)
	var dispare := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	dispare.tween_property(_model, "scale", Vector3(0.05, 1.3, 0.05), 0.3)
	await dispare.finished
	hide()
	_dezactiveaza_coliziunea()
	Stare.marcheaza(marcaj_plecata)
