extends Node
## Autobuzul care te-a adus pleacă din stație: ușile se închid, motorul turează și dispare în ceață.
## Pornește după ce se termină tranziția (ecranul negru). După ce a plecat o dată (marcajul de mai jos),
## la „Continue” nu mai e acolo.

@export var autobuz: Autobuz
## Cât așteaptă după ce s-a luminat ecranul (secunde).
@export var intarziere := 1.6
## Accelerația (m/s²), viteza maximă (m/s) și după câți metri dispare de tot.
@export var acceleratie := 1.8
@export var viteza_maxima := 13.0
@export var distanta := 120.0
@export var marcaj := "autobuzul_a_plecat_din_padure"
## Sarcina primită după ce pleacă autobuzul (gol = niciuna).
@export var sarcina_noua := "Find the coven in Trivale Forest."
## Gol = mereu. Altfel autobuzul e în stație doar cu marcajul ăsta pus (și doar cu Jucator în scenă), ex. seara la bloc,
## când te întorci de la Lexy (curtea blocului mai e și fundalul din meniu, ziua și noaptea).
@export var marcaj_necesar := ""
## Bifat = autobuzul e în stație doar când ai venit cu un autobuz chemat de la orar (`OrarAutobuz.cu_autobuzul`),
## de câte ori se întâmplă (fără `marcaj`); atunci te pune și pe tine în stație, la `loc_jucator`.
@export var doar_din_orar := false
@export var loc_jucator := Vector3.ZERO
## Încotro te uiți (radiani; 0 = spre -Z).
@export var unghi_jucator := 0.0

var _pleaca := false
var _v := 0.0
var _mers := 0.0


func _ready() -> void:
	if doar_din_orar:
		var jucator := get_parent().get_node_or_null("Jucator") as Node3D
		if jucator == null or not OrarAutobuz.cu_autobuzul:
			autobuz.queue_free()
			set_process(false)
			return
		OrarAutobuz.cu_autobuzul = false
		await get_tree().process_frame
		jucator.global_position = loc_jucator
		jucator.rotation.y = unghi_jucator
		jucator.get_node("Cap").rotation.x = 0.0
		await _pleaca_din_statie()
		return
	if marcaj_necesar != "" and (not Stare.e_marcat(marcaj_necesar) or not get_parent().has_node("Jucator")):
		autobuz.queue_free()
		set_process(false)
		return
	if Stare.e_marcat(marcaj):
		autobuz.queue_free()
		return
	await get_tree().process_frame
	await _pleaca_din_statie()


func _pleaca_din_statie() -> void:
	autobuz.usi_deschise_deja()
	while Tranzitie.activa:
		await get_tree().process_frame
	await get_tree().create_timer(intarziere).timeout
	await autobuz.inchide_usi()
	await get_tree().create_timer(0.7).timeout
	_pleaca = true


func _process(delta: float) -> void:
	if not _pleaca:
		return
	_v = minf(_v + acceleratie * delta, viteza_maxima)
	var pas := _v * delta
	autobuz.global_position += autobuz.global_transform.basis.z.normalized() * Vector3(1, 0, 1) * pas
	_mers += pas
	if _mers > distanta:
		_pleaca = false
		if marcaj != "":
			Stare.marcheaza(marcaj)
		if sarcina_noua != "":
			Stare.seteaza_sarcina(sarcina_noua)
		autobuz.queue_free()
