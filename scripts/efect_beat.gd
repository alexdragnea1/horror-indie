class_name EfectBeat
extends CanvasLayer
## „Ești beat” câteva secunde: ecranul se unduiește și vezi dublu (shaders/beat.gdshader), camera se înclină
## și se leagănă, câmpul vizual respiră, iar privirea fuge singură puțin în lateral. Te poți mișca normal.
##   EfectBeat.porneste(jucator, 5.0)
## Se șterge singur la final și pune camera la loc.

## Cât de repede se instalează și cât durează revenirea (secunde, incluse în durată).
const INTRARE := 0.8
const IESIRE := 1.6

var putere := 0.0

var _jucator: Node3D
var _camera: Camera3D
var _material: ShaderMaterial
var _fov := 75.0
var _timp := 0.0


static func porneste(jucator: Node3D, durata: float) -> EfectBeat:
	var efect := EfectBeat.new()
	efect._jucator = jucator
	jucator.get_tree().root.add_child(efect)
	efect._ruleaza(durata)
	return efect


func _ready() -> void:
	layer = 2  # peste filtrul PS2 (1), sub HUD (5)
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/beat.gdshader")
	var ecran := ColorRect.new()
	ecran.set_anchors_preset(Control.PRESET_FULL_RECT)
	ecran.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ecran.material = _material
	add_child(ecran)
	_camera = _jucator.get_node("Cap/Camera3D")
	_fov = _camera.fov
	# dacă pleci din scenă în timpul efectului, pleacă și el
	_jucator.tree_exiting.connect(queue_free)


func _ruleaza(durata: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "putere", 1.0, INTRARE).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(maxf(durata - INTRARE - IESIRE, 0.0))
	tween.tween_property(self, "putere", 0.0, IESIRE).set_trans(Tween.TRANS_SINE)
	await tween.finished
	_pune_camera_la_loc()
	queue_free()


func _process(delta: float) -> void:
	_timp += delta
	_material.set_shader_parameter("putere", putere)
	if not is_instance_valid(_camera):
		return
	_camera.rotation.z = sin(_timp * 0.9) * 0.09 * putere
	_camera.fov = _fov + sin(_timp * 1.4) * 4.0 * putere
	# privirea fuge singură, încet, stânga-dreapta (nu te lasă să ții ținta)
	if not Stare.meniu_deschis and not get_tree().paused:
		_jucator.rotate_y(sin(_timp * 0.75) * 0.22 * putere * delta)


func _pune_camera_la_loc() -> void:
	if is_instance_valid(_camera):
		_camera.rotation.z = 0.0
		_camera.fov = _fov
