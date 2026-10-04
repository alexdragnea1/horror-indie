extends Node
## Mesajul de pe telefon după antrenamentul cu Head Witch (nodul `MesajLexy` din afara_bloc.tscn):
## la `intarziere` secunde după `marcaj_dupa_care` (pus când pleacă Head Witch), telefonul vibrează și vezi
## conversația (Telefon, ca într-o aplicație de mesaje). După ea: `marcaj_gata` (după care vine autobuzul, vezi
## nodul `AutobuzLexy`) și `sarcina_noua`. La Continue, dacă n-ai apucat să vezi mesajul, vine din nou.
## Replicile sunt ale owner-ului: nu le corecta. Prefixul („Her:” / „You:”) nu apare pe telefon.

@export var marcaj_dupa_care := "antrenament_cu_matura"
@export var marcaj_gata := "a_primit_mesajul_lexy"
@export var intarziere := 10.0
## Numele de sus din aplicație (cum e salvată ea în telefonul tău).
@export var contact := "School Whore"
@export var ora := "9:21"
@export_multiline var mesaje: PackedStringArray = []
@export var sarcina_noua := "Take the bus to her place."

var _pornit := false


func _ready() -> void:
	await get_tree().process_frame
	if get_tree().get_first_node_in_group("jucator") == null or Stare.e_marcat(marcaj_gata):
		return
	Stare.schimbat.connect(_verifica)
	_verifica()


func _verifica() -> void:
	if _pornit or not Stare.e_marcat(marcaj_dupa_care):
		return
	_pornit = true
	Stare.schimbat.disconnect(_verifica)
	await get_tree().create_timer(intarziere).timeout
	# nu în mijlocul unui dialog, al unui meniu sau al unei tranziții
	while Dialog.activ or Stare.meniu_deschis or Tranzitie.activa:
		await get_tree().create_timer(0.3).timeout
	await Telefon.conversatie(self, contact, mesaje, ora)
	Stare.marcheaza(marcaj_gata)
	if sarcina_noua != "":
		Stare.seteaza_sarcina(sarcina_noua)
