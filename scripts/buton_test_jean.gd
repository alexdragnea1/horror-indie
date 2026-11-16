extends Interactabil
## DOAR PENTRU TESTE (owner 16.11): butonul roșu de lângă ușa lui Jean (`ButonTest` în casa_jean.tscn). E pe el =
## câștigi meciul de șah pe loc (`MasaSah.debug_castiga`). După ce a murit Jean nu mai face nimic.
## Ca să-l scoți: șterge nodul `ButonTest` din casa_jean.tscn (și fișierul ăsta, și `debug_castiga` din masa_sah.gd).

@export var masa: MasaSah

var _buton: MeshInstance3D


func _ready() -> void:
	indiciu = "[E] DEBUG: win the chess match"
	# un stâlp negru cu o cutie și un buton roșu mare deasupra, făcute din cod
	_cutie(Vector3(0.12, 0.95, 0.12), Vector3(0, 0.475, 0), Color(0.08, 0.08, 0.09))
	_cutie(Vector3(0.24, 0.1, 0.24), Vector3(0, 1.0, 0), Color(0.6, 0.55, 0.15))
	_buton = MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.07
	c.bottom_radius = 0.07
	c.height = 0.05
	_buton.mesh = c
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.08, 0.06)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.02, 0.02)
	_buton.material_override = mat
	add_child(_buton)
	_buton.position = Vector3(0, 1.075, 0)
	var forma := CollisionShape3D.new()
	var cutie := BoxShape3D.new()
	cutie.size = Vector3(0.26, 1.12, 0.26)
	forma.shape = cutie
	forma.position.y = 0.56
	add_child(forma)


func _cutie(marime: Vector3, poz: Vector3, culoare: Color) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = marime
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = culoare
	m.material_override = mat
	add_child(m)
	m.position = poz


func poate_fi_folosit() -> bool:
	return masa != null and masa.poate_fi_folosit()


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	var t := create_tween()
	t.tween_property(_buton, "position:y", 1.055, 0.06)
	t.tween_property(_buton, "position:y", 1.075, 0.12)
	Sunet.reda_la(preload("res://sunete/ui_clic.ogg"), global_position + Vector3.UP, Sunet.VOLUM_EFECTE, 0.0)
	masa.debug_castiga()
