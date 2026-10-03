class_name Tablou
extends Interactabil
## Tablou pe perete. Rama e modelul copil (`Model`, din tools/blender/bucatarie.py),
## iar pânza cu poza o face scriptul, din `imagine`, la 1,4 cm în fața peretelui.
## Originea nodului = centrul pânzei, pe perete; tabloul privește spre +Z.

@export var imagine: Texture2D
## Mărimea pânzei, în metri (trebuie să fie cea a ramei: 0,55 × 0,55 la rama aurie, 0,74 × 0,48 la cea de lemn, 0,74 × 0,475 la cea albă).
@export var marime := Vector2(0.55, 0.55)


func _ready() -> void:
	var panza := MeshInstance3D.new()
	panza.name = "Panza"
	var quad := QuadMesh.new()
	quad.size = marime
	panza.mesh = quad
	panza.position = Vector3(0, 0, 0.014)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/ps2.gdshader")
	material.set_shader_parameter("textura", imagine)
	panza.material_override = material
	add_child(panza)
