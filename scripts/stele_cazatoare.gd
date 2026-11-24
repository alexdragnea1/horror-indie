extends Node
## Stele căzătoare deasupra platoului din pădure (owner 24.11). Cât ești sus pe platou (`TerenPadure.platou()` peste
## `prag_platou`), din când în când (între `pauza_min` și `pauza_max` secunde) trece una pe cer, prin fața ta: pornește
## cam unde te uiți (la `raspandire` radiani în jur, dar mereu între `inaltime_min` și `inaltime_max` deasupra
## orizontului, ca să nu se ascundă după copaci) și cade în diagonală, într-o parte. O desenează cer_noapte.gdshader
## (uniformele `sc_*`); aici doar alegi când, unde și încotro. În pădure și în vale nu pornește (acolo ceața acoperă cerul).

@export var teren: TerenPadure
@export var mediu: WorldEnvironment
## Cât de „pe platou” trebuie să fii (0..1, vezi TerenPadure.platou).
@export var prag_platou := 0.6
## Pauza dintre două stele căzătoare (secunde, la întâmplare între ele).
@export var pauza_min := 3.0
@export var pauza_max := 8.0
## Cât ține una (secunde).
@export var durata := 0.85
## Cât de departe de mijlocul privirii poate porni (radiani) și între ce înălțimi pe cer (radiani deasupra orizontului).
@export var raspandire := 0.45
@export var inaltime_min := 0.35
@export var inaltime_max := 1.15

var _cer: ShaderMaterial
var _pana_la_urmatoarea := 2.0
var _progres := -1.0


func _ready() -> void:
	if mediu and mediu.environment and mediu.environment.sky:
		_cer = mediu.environment.sky.sky_material as ShaderMaterial
	_pana_la_urmatoarea = randf_range(1.5, pauza_max)


func _process(delta: float) -> void:
	if _cer == null:
		return
	if _progres >= 0.0:
		_progres += delta / durata
		if _progres > 1.0:
			_progres = -1.0
		_cer.set_shader_parameter("sc_progres", _progres)
		return
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	if jucator == null or teren == null:
		return
	if teren.platou(jucator.global_position.x, jucator.global_position.z) < prag_platou:
		return
	_pana_la_urmatoarea -= delta
	if _pana_la_urmatoarea <= 0.0:
		_porneste()
		_pana_la_urmatoarea = randf_range(pauza_min, pauza_max)


func _porneste() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var inainte := -camera.global_basis.z
	# unghiul pe orizontală al privirii, plus puțin într-o parte; înălțimea pe cer: aproape de privire, dar sus
	var az := atan2(inainte.x, -inainte.z) + randf_range(-raspandire, raspandire)
	var el := clampf(asin(clampf(inainte.y, -1.0, 1.0)) + randf_range(0.05, raspandire), inaltime_min, inaltime_max)
	var start := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
	# încotro: tangent la cer, într-o parte (stânga sau dreapta) și în jos
	var dreapta := Vector3.UP.cross(start).normalized()
	var sus := start.cross(dreapta)
	var directie := (dreapta * (1.0 if randf() < 0.5 else -1.0) * randf_range(0.6, 1.0) - sus * randf_range(0.35, 0.7)).normalized()
	_cer.set_shader_parameter("sc_start", start)
	_cer.set_shader_parameter("sc_dir", directie)
	_progres = 0.0
	_cer.set_shader_parameter("sc_progres", 0.0)
