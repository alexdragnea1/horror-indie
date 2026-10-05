extends StaticBody3D
## Manechinul de antrenament din camera lui Helga (manechin.glb, cu dovleac în loc de cap). Când îl lovește ceva
## (mingea de foc, un glonț: `impuscat`), se clatină pe stâlp ca un arc (`Model/Corp`, originea jos pe stâlp) și
## dovleacul se aprinde mai tare o clipă.

## Cât de tare îl împinge o lovitură (radiani pe secundă) și cât de repede se oprește.
@export var forta := 2.6
@export var arc := 60.0
@export var amortizare := 4.5

var _unghi := Vector2.ZERO  # aplecarea pe X și pe Z
var _viteza := Vector2.ZERO
var _sclipire := 0.0

@onready var _corp: Node3D = $Model/Corp
@onready var _fata: GeometryInstance3D = $Model/Corp/Lumini


func impuscat(directie: Vector3, _punct := Vector3.ZERO) -> void:
	# în coordonatele manechinului: împins dinspre lovitură
	var d := global_basis.inverse() * directie
	_viteza += Vector2(d.z, -d.x) * forta
	_sclipire = 1.0


func _process(delta: float) -> void:
	_viteza += -_unghi * arc * delta
	_viteza *= exp(-amortizare * delta)
	_unghi += _viteza * delta
	_unghi = _unghi.limit_length(0.5)
	_corp.rotation = Vector3(_unghi.x, 0.0, _unghi.y)
	_sclipire = move_toward(_sclipire, 0.0, delta * 1.5)
	_fata.set_instance_shader_parameter("stralucire", 1.6 + _sclipire * 2.5)
