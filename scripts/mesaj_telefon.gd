extends Node
## Un mesaj pe telefon (Telefon, ca într-o aplicație de mesaje): telefonul vibrează și vezi conversația.
## Vine la `intarziere` secunde după ce e îndeplinită condiția: `marcaj_dupa_care` pus SAU (dacă e completat)
## ai unul din `obiecte_oricare` (în inventar, aruncat sau pe raft). Cu `doar_afara`, abia când ești în fața
## clădirii (`global_position.z` > `afara_de_la_z`; fațada e la z = 0, interiorul spre -Z).
## După el: `marcaj_gata` și `sarcina_noua`. La Continue, dacă n-ai apucat să vezi mesajul, vine din nou.
##  - `MesajLexy` (afara_bloc.tscn): după antrenamentul cu mătura, Lexy („School Whore”).
##  - `MesajSefa` (magazin_arme.tscn, casino.tscn, casa_lexy.tscn): după ce ai cumpărat o armă de la Gun Store,
##    Head Witch („Coven Retard”): imediat ce ieși din magazin; după el, „Home” din orar te duce la bloc la apus.
## Replicile sunt ale owner-ului: nu le corecta. Prefixul („Her:” / „You:”) nu apare pe telefon.

@export var marcaj_dupa_care := "antrenament_cu_matura"
## Gol = nu contează. Altfel ajunge și unul singur din obiectele astea (ex. armele de la Gun Store, pentru salvările
## de dinainte de marcajul `a_cumparat_arma`).
@export var obiecte_oricare: PackedStringArray = []
@export var marcaj_gata := "a_primit_mesajul_lexy"
@export var intarziere := 10.0
## Bifat = vine abia când ești afară, în fața clădirii (vezi `afara_de_la_z`).
@export var doar_afara := false
@export var afara_de_la_z := 0.4
## Numele de sus din aplicație (cum e salvată ea în telefonul tău).
@export var contact := "School Whore"
@export var ora := "1:02"
@export_multiline var mesaje: PackedStringArray = []
@export var sarcina_noua := "Take the bus to her place."

var _pornit := false
var _jucator: Node3D


func _ready() -> void:
	set_process(false)
	await get_tree().process_frame
	_jucator = get_tree().get_first_node_in_group("jucator") as Node3D
	if _jucator == null or Stare.e_marcat(marcaj_gata):
		return
	set_process(true)


## Verifică de câteva ori pe secundă (condiția de „afară” ține de unde ești, nu doar de Stare).
func _process(_delta: float) -> void:
	if _pornit or Engine.get_process_frames() % 6 != 0 or not _conditie():
		return
	_pornit = true
	set_process(false)
	await get_tree().create_timer(intarziere).timeout
	# nu în mijlocul unui dialog, al unui meniu sau al unei tranziții
	while Dialog.activ or Stare.meniu_deschis or Tranzitie.activa:
		await get_tree().create_timer(0.3).timeout
	if not is_inside_tree():
		return
	await Telefon.conversatie(self, contact, mesaje, ora)
	Stare.marcheaza(marcaj_gata)
	if sarcina_noua != "":
		Stare.seteaza_sarcina(sarcina_noua)


func _conditie() -> bool:
	var are := Stare.e_marcat(marcaj_dupa_care)
	for id in obiecte_oricare:
		if Stare.are_obiect(id) or Stare.e_aruncat(id) or Stare.e_pe_raft(id):
			are = true
	if not are:
		return false
	return not doar_afara or (is_instance_valid(_jucator) and _jucator.global_position.z > afara_de_la_z)
