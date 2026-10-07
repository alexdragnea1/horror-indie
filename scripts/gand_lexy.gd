extends Area3D
## Afară, în fața ușii spălătoriei: dacă ai fost la bătrâna de la casă (`marcaj_casa`), dar n-ai avut bani (n-ai jefuit-o
## pe Lexy, nici n-ai împrumutat de la ea și n-ai jetoane), când ieși îți vine ideea (`replici`, ale owner-ului) și
## primești `sarcina`. O singură dată (`marcaj_gata`).

@export var marcaj_casa := "a_vorbit_cu_batrana_casino"
@export var marcaj_gata := "gand_imprumut_lexy"
@export_multiline var replici: PackedStringArray = ["You: Maybe Lexy could lend me some money.."]
## Sarcina de după (scrisă de Claude; gol = niciuna).
@export var sarcina := "Ask Lexy for money."


func _ready() -> void:
	body_entered.connect(_intrat)


func _intrat(corp: Node3D) -> void:
	if not corp.is_in_group("jucator") or Stare.e_marcat(marcaj_gata) or not Stare.e_marcat(marcaj_casa):
		return
	if Stare.e_marcat("a_jefuit_lexy") or Stare.e_marcat("a_imprumutat_de_la_lexy") or Bani.suma() > 0:
		return
	if Jetoane.suma() > 0 or Stare.e_marcat("lexy_moarta"):
		return
	Stare.marcheaza(marcaj_gata)
	Dialog.spune(replici)
	if Dialog.activ:
		await Dialog.terminat
	if sarcina != "":
		Stare.seteaza_sarcina(sarcina)
