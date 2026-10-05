extends Node3D
## Ceasul cu pendul din living room-ul conacului (ceas_pendul.glb): pendulul (`Model/Pendul`, originea în prindere)
## se leagănă o dată pe secundă, în ritmul tic-tacului.

@export var amplitudine_grade := 6.0

@onready var _pendul: Node3D = $Model/Pendul


func _process(_delta: float) -> void:
	_pendul.rotation.z = sin(Time.get_ticks_msec() * 0.001 * PI) * deg_to_rad(amplitudine_grade)
