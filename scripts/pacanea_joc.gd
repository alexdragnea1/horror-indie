class_name PacaneaJoc
extends Interactabil
## O păcănea din camera de joc (`pacanea.tscn`: modelul `pacanea.glb` + cutia asta). Toate sunt la fel (același model,
## duplicat). Pe ecranele lor rulează aceeași animație (un singur SubViewport pentru toată scena, `_ecran_comun`):
## simboluri care se învârt din când în când, „INSERT CREDIT”, iar sus jackpot-ul care tot crește.
## Cu jetoane: „[E] Play” → te apropii de ecran și se deschide jocul (UIPacanea). Leave / Esc = te dai înapoi.

## Cât de departe de păcănea stai cât joci și înălțimea ochilor.
@export var distanta_joc := 0.72
@export var ochi_joc := 1.42

static var _ecran_comun: SubViewport
static var _ecran_sus_comun: SubViewport

var _in_curs := false


func _ready() -> void:
	indiciu = "[E] Play the slot machine"
	await get_tree().process_frame
	_pune_ecranele()


func poate_fi_folosit() -> bool:
	return not _in_curs and Jetoane.suma() > 0


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	var jucator := get_tree().get_first_node_in_group("jucator") as CharacterBody3D
	var cap: Node3D = jucator.get_node("Cap")
	var inaltime := cap.position.y
	var c := Cutscena.porneste(self)
	jucator.seteaza_purtat(true)
	var loc := global_position + global_basis.z * distanta_joc
	loc.y = jucator.global_position.y
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(jucator, "global_position", loc, 0.6)
	t.tween_property(cap, "position:y", ochi_joc, 0.6)
	c.priveste(_punct_ecran(), 0.6)
	await t.finished
	await c.priveste(_punct_ecran(), 0.1)
	c.queue_free()
	Stare.meniu_deschis = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var ui := UIPacanea.new()
	get_tree().current_scene.add_child(ui)
	await ui.inchis
	t = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(jucator, "global_position", loc + global_basis.z * 0.35, 0.5)
	t.tween_property(cap, "position:y", inaltime, 0.5)
	t.tween_property(cap, "rotation:x", 0.0, 0.5)
	await t.finished
	jucator.seteaza_purtat(false)
	Stare.meniu_deschis = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_in_curs = false


func _punct_ecran() -> Vector3:
	var e := find_child("Ecran", true, false) as Node3D
	return e.global_position if e else global_position + Vector3.UP * 1.25


## Pune pe ecranele modelului câte o placă cu imaginea comună.
func _pune_ecranele() -> void:
	if _ecran_comun == null or not is_instance_valid(_ecran_comun):
		_ecran_comun = _viewport(Vector2i(96, 72), EcranPacanea.new())
		var sus := EcranPacanea.new()
		sus.sus = true
		_ecran_sus_comun = _viewport(Vector2i(96, 42), sus)
	for date: Array in [["Ecran", Vector2(0.5, 0.38), _ecran_comun, -0.15], ["EcranSus", Vector2(0.5, 0.22), _ecran_sus_comun, 0.0]]:
		var punct := find_child(date[0], true, false) as Node3D
		if punct == null:
			continue
		var placa := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = date[1]
		placa.mesh = q
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = (date[2] as SubViewport).get_texture()
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		placa.material_override = mat
		placa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		punct.add_child(placa)
		placa.rotation.x = date[3]
		placa.position.z = 0.005
		# o lumină slabă, colorată, din ecran (luminează scaunul și fața ta)
		if date[0] == "Ecran":
			var l := OmniLight3D.new()
			l.light_color = Color("a18463")
			l.light_energy = 0.35
			l.omni_range = 1.4
			l.light_volumetric_fog_energy = 0.0
			punct.add_child(l)
			l.position.z = 0.25


func _viewport(marime: Vector2i, continut: Control) -> SubViewport:
	var v := SubViewport.new()
	v.size = marime
	v.transparent_bg = false
	v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	v.disable_3d = true
	get_tree().current_scene.add_child(v)
	continut.size = Vector2(marime)
	v.add_child(continut)
	return v
