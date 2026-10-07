extends Node3D
## O vrăjitoare din cercul din jurul cazanului (scenes/vrajitoare.tscn). Stă aplecată spre cazan cu brațele
## întinse peste el și descântă: se leagănă, mâinile fac cercuri mici, capul se uită în cazan.
## La vrajă (cazan.gd) își ridică brațele și capul spre cer: ridica_bratele(true / false).
## Modelul are `Brate` (originea între umeri) și `Cap` (originea în gât), vezi tools/blender/coven.py.
## După ce bețivul ți-a cerut asta (`marcaj_omorabila`), le poți împușca (nu și pe Head Witch): cade pe spate ca un
## ragdoll (doar una, și doar dacă n-ai omorât deja bețivul: vezi Personaj.MARCAJ_CRIMA), apoi o iei în inventar
## cu E (`nume_cadavru`) și o poți arunca în cazan în locul bețivului (cazan.gd).
## Marcajele și id-ul din inventar vin din numele nodului (ex. Vrajitoare3: „vrajitoare3_moarta”, „cadavru_vrajitoare3”).

## Ca să nu se miște toate la fel (secunde).
@export var faza := 0.0
## Cât de repede descântă.
@export var viteza := 1.0

@export_group("Moarte")
@export var marcaj_omorabila := "betivul_a_cerut_o_vrajitoare"
@export var nume_cadavru := "Witch"
@export var indiciu_cadavru := "[E] Pick up the witch"
## Cât de tare o împinge glonțul (N·s).
@export var forta_glont := 110.0
@export var sunet_cadere: AudioStream = preload("res://sunete/corp_cazut.ogg")
@export var sunet_luat: AudioStream = preload("res://sunete/corp_luat.ogg")

var mort := false
var id_cadavru := ""
var _cadavru: Ragdoll
var _cale_model := ""

var _timp := 0.0
var _ridicare := 0.0  # 0 = peste cazan, 1 = brațele la cer
var _tween: Tween

@onready var _model: Node3D = $Model
@onready var _brate: Node3D = $Model/Brate
@onready var _cap: Node3D = $Model/Cap


func _ready() -> void:
	CapTinta.adauga(self, _cap)
	_timp = faza
	var nume := String(name).to_lower()
	id_cadavru = "cadavru_" + nume
	_cale_model = _model.scene_file_path
	add_to_group("cadavre")  # cazanul o caută aici
	if Stare.e_marcat(nume + "_luata"):
		# ai luat-o deja (în inventar sau în cazan): nu mai e aici
		mort = true
		Stare.marcheaza(Personaj.MARCAJ_CRIMA)  # salvările de dinainte de marcaj
		remove_from_group("vrajitoare_cerc")
		hide()
		_dezactiveaza_coliziunea()
	elif Stare.e_marcat(nume + "_moarta"):
		await get_tree().process_frame
		_moare(Vector3.ZERO, 0.0)


func _process(delta: float) -> void:
	if mort:
		return  # acum e un ragdoll
	_timp += delta * viteza
	# se leagănă încet, din tot corpul
	_model.rotation.z = sin(_timp * 0.8) * 0.035
	_model.rotation.x = sin(_timp * 0.55 + 1.0) * 0.02
	# mâinile fac cercuri mici peste cazan; la vrajă urcă spre cer (-X = în sus pentru brațele întinse înainte)
	var cerc := Vector2(sin(_timp * 1.7), cos(_timp * 1.7)) * 0.07 * (1.0 - _ridicare * 0.5)
	_brate.rotation = Vector3(cerc.y - _ridicare * 1.25, cerc.x * 0.6, 0.0)
	# capul: în cazan, apoi pe spate, spre cer
	_cap.rotation = Vector3(0.25 - _ridicare * 0.75 + sin(_timp * 1.1) * 0.04, sin(_timp * 0.4) * 0.12, sin(_timp * 0.7) * 0.06)


func ridica_bratele(sus: bool, durata := 0.8) -> void:
	if mort:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "_ridicare", 1.0 if sus else 0.0, durata)


## Modelul aruncat în cazan (același .glb ca al ei).
func model_cadavru() -> PackedScene:
	return load(_cale_model) if _cale_model != "" else null


## O lovește un glonț (pistol.gd). Moare doar după ce ți-a cerut-o bețivul și dacă n-ai mai omorât pe nimeni.
func impuscat(directie: Vector3, _punct := Vector3.ZERO) -> void:
	if not mort and Stare.e_marcat(marcaj_omorabila) and not Stare.e_marcat(Personaj.MARCAJ_CRIMA):
		_moare(directie, forta_glont)


## Cade pe spate (în afara cercului), iar după ce se oprește o poți lua cu E. Ca Personaj.omoara.
func _moare(directie: Vector3, forta: float) -> void:
	mort = true
	Stare.marcheaza(Personaj.MARCAJ_CRIMA)
	remove_from_group("vrajitoare_cerc")
	_dezactiveaza_coliziunea()
	Stare.marcheaza(String(name).to_lower() + "_moarta")
	_model.rotation = Vector3.ZERO
	var spate := -global_transform.basis.z  # modelele privesc spre +Z (spre cazan)
	var orizontal := Vector3(directie.x, 0.0, directie.z).normalized()
	var impuls := (spate * 0.8 + orizontal * 0.2 + Vector3.UP * 0.15).normalized() * forta
	_cadavru = Ragdoll.din_model(_model, impuls, ["Ochi"])
	if forta > 0.0:
		await get_tree().create_timer(0.45).timeout
		if is_instance_valid(_cadavru):
			Sunet.reda_la(sunet_cadere, _cadavru.centru(), Sunet.VOLUM_EFECTE, 0.05)
	var asteptat := 0.0
	while is_instance_valid(_cadavru) and asteptat < 3.0 and not (asteptat > 0.6 and _cadavru.s_a_oprit()):
		await get_tree().create_timer(0.2).timeout
		asteptat += 0.2
	if is_instance_valid(_cadavru):
		_cadavru.pune_ridicare(id_cadavru, nume_cadavru, indiciu_cadavru).folosit.connect(_luata)


func _luata() -> void:
	Stare.marcheaza(String(name).to_lower() + "_luata")
	Sunet.reda(sunet_luat, Sunet.VOLUM_EFECTE, 0.05)
	_cadavru.queue_free()
	hide()


func _dezactiveaza_coliziunea() -> void:
	for copil in get_children():
		if copil is CollisionShape3D:
			copil.set_deferred("disabled", true)
