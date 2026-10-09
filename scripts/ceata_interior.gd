extends Area3D
## Înăuntru (casa lui Lexy) ceața de afară se subțiază, ca să nu fie pâclă în camere: când intri în zona asta,
## ceața din `mediu` scade încet la valorile „înăuntru”, iar când ieși revine la cât era.
## `lumina_inauntru` (≥ 0) = și lumina ambientală scade/crește la valoarea asta înăuntru (barul „URBAN”, puțin întunecat);
## -1 = rămâne cea de afară.
## Într-o scenă din cod jucătorul e „purtat”, fără coliziune (ex. pe scaunul de la bar), iar zona îl pierde: atunci nu
## schimbă nimic, decât dacă la final chiar nu mai e în zonă (ca la muzica_loc.gd).

@export var mediu: WorldEnvironment
@export var ceata_inauntru := 0.004
@export var ceata_volum_inauntru := 0.0
@export var lumina_inauntru := -1.0
@export var durata := 1.2

var _ceata := 0.0
var _ceata_volum := 0.0
var _lumina := 1.0
var _tween: Tween


func _ready() -> void:
	if mediu == null:  # pusă într-o scenă instanțiată (amanet.tscn): mediul e al scenei mari în care stă
		var sus: Node = self
		while sus.get_parent() != get_tree().root:
			sus = sus.get_parent()
		mediu = sus.find_children("*", "WorldEnvironment", true, false)[0]
	_ceata = mediu.environment.fog_density
	_ceata_volum = mediu.environment.volumetric_fog_density
	_lumina = mediu.environment.ambient_light_energy
	body_entered.connect(func(corp: Node3D) -> void:
		if corp.is_in_group("jucator"):
			_spre(ceata_inauntru, ceata_volum_inauntru, lumina_inauntru if lumina_inauntru >= 0.0 else _lumina))
	body_exited.connect(_iesit)


func _iesit(corp: Node3D) -> void:
	if not corp.is_in_group("jucator"):
		return
	var forma := corp.get_node_or_null("Coliziune") as CollisionShape3D
	if forma and forma.disabled:
		while is_instance_valid(forma) and forma.disabled:
			await get_tree().physics_frame
		await get_tree().physics_frame
		await get_tree().physics_frame
		if not is_instance_valid(corp) or overlaps_body(corp):
			return
	_spre(_ceata, _ceata_volum, _lumina)


func _spre(ceata: float, volum: float, lumina: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(mediu.environment, "fog_density", ceata, durata)
	_tween.tween_property(mediu.environment, "volumetric_fog_density", volum, durata)
	_tween.tween_property(mediu.environment, "ambient_light_energy", lumina, durata)
