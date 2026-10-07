extends Area3D
## Înăuntru (casa lui Lexy) ceața de afară se subțiază, ca să nu fie pâclă în camere: când intri în zona asta,
## ceața din `mediu` scade încet la valorile „înăuntru”, iar când ieși revine la cât era.

@export var mediu: WorldEnvironment
@export var ceata_inauntru := 0.004
@export var ceata_volum_inauntru := 0.0
@export var durata := 1.2

var _ceata := 0.0
var _ceata_volum := 0.0
var _tween: Tween


func _ready() -> void:
	if mediu == null:  # pusă într-o scenă instanțiată (amanet.tscn): mediul e al scenei mari în care stă
		var sus: Node = self
		while sus.get_parent() != get_tree().root:
			sus = sus.get_parent()
		mediu = sus.find_children("*", "WorldEnvironment", true, false)[0]
	_ceata = mediu.environment.fog_density
	_ceata_volum = mediu.environment.volumetric_fog_density
	body_entered.connect(func(corp: Node3D) -> void:
		if corp.is_in_group("jucator"):
			_spre(ceata_inauntru, ceata_volum_inauntru))
	body_exited.connect(func(corp: Node3D) -> void:
		if corp.is_in_group("jucator"):
			_spre(_ceata, _ceata_volum))


func _spre(ceata: float, volum: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(mediu.environment, "fog_density", ceata, durata)
	_tween.tween_property(mediu.environment, "volumetric_fog_density", volum, durata)
