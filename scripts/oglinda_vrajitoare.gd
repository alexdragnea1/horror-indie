extends Interactabil
## Oglinda ovală de pe măsuța de toaletă din dormitorul conacului (camera cu pisica; owner 12.10).
## E → te apropii, oglinda se întunecă și din adâncul ei se apropie fața unei vrăjitoare (randată într-un SubViewport
## cu lumea ei, deci se vede „în” oglindă, nu lipită pe ea), îți spune replica, îi răspunzi și fața se stinge.
## Nodul stă în centrul oglinzii, cu +Z spre cameră (spre jucător).

const SUNET_APARITIE := preload("res://sunete/stinger_aparitie.ogg")
const SUNET_STINGERE := preload("res://sunete/vraja_unda.ogg")
const SHADER_OGLINDA := preload("res://shaders/oglinda_vrajitoare.gdshader")

## Vrăjitoarea din oglindă (fața ei e la `inaltime_fata`, cu fața spre +Z).
@export var model_vrajitoare: PackedScene = preload("res://models/vrajitoare_1.glb")
@export var material: ShaderMaterial = preload("res://shaders/material_model.tres")
@export var inaltime_fata := 1.57
## Lumina de lângă oglindă (Toaleta): se face verde și pâlpâie cât e fața acolo.
@export var lumina: OmniLight3D
## Semiaxele oglinzii (m): ovalul în care se vede fața.
@export var raza := Vector2(0.36, 0.36)
## Cât de departe de oglindă stai cât vorbește (m).
@export var departare_jucator := 0.95
@export var replici_oglinda := PackedStringArray(["Witch: You're an ugly ass bitch.", "You: Kill yourself."])

var _vedere: SubViewport
var _vrajitoare: Node3D
var _ecran: MeshInstance3D
var _mat: ShaderMaterial
var _vizibil := 0.0
var _ocupat := false
var _culoare_lumina := Color.WHITE
var _energie_lumina := 1.0


func _ready() -> void:
	if indiciu == "[E] Examine":
		indiciu = "[E] Look in the mirror"
	if lumina:
		_culoare_lumina = lumina.light_color
		_energie_lumina = lumina.light_energy
	_fa_vederea()
	_fa_ecranul()


func poate_fi_folosit() -> bool:
	return activ and not _ocupat


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_ocupat = true
	folosit.emit()
	_scena()


## Lumea din oglindă: vrăjitoarea, o lumină verde de jos și o cameră fixă pe fața ei. Se randează doar cât se vede.
func _fa_vederea() -> void:
	_vedere = SubViewport.new()
	_vedere.size = Vector2i(roundi(96 * raza.x / raza.y), 96)
	_vedere.own_world_3d = true
	_vedere.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vedere.msaa_3d = Viewport.MSAA_DISABLED
	add_child(_vedere)
	var mediu := Environment.new()
	mediu.background_mode = Environment.BG_COLOR
	mediu.background_color = Color("0d1410")
	mediu.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	mediu.ambient_light_color = Color("3a5a48")
	mediu.ambient_light_energy = 0.35
	mediu.fog_enabled = true
	mediu.fog_light_color = Color("0d1410")
	mediu.fog_density = 0.6
	var we := WorldEnvironment.new()
	we.environment = mediu
	_vedere.add_child(we)
	_vrajitoare = model_vrajitoare.instantiate()
	_vrajitoare.set_script(load("res://scripts/model_ps2.gd"))
	_vrajitoare.set("material", material)
	_vrajitoare.set("umbre", false)
	_vedere.add_child(_vrajitoare)
	# lumina de dedesubt, verde (ca o lanternă sub bărbie), și una slabă din spate pe contur
	var jos := OmniLight3D.new()
	jos.position = Vector3(0, inaltime_fata - 0.45, 0.45)
	jos.light_color = Color("7fd18a")
	jos.light_energy = 2.2
	jos.omni_range = 1.6
	_vedere.add_child(jos)
	var spate := OmniLight3D.new()
	spate.position = Vector3(0.3, inaltime_fata + 0.4, -0.5)
	spate.light_color = Color("61a19f")
	spate.light_energy = 1.2
	spate.omni_range = 1.5
	_vedere.add_child(spate)
	var cam := Camera3D.new()
	cam.position = Vector3(0, inaltime_fata + 0.07, 0.72)
	cam.fov = 38.0
	cam.current = true
	_vedere.add_child(cam)
	cam.look_at(Vector3(0, inaltime_fata, 0))


## Placa ovală lipită de sticla oglinzii, pe care se vede ce „filmează” camera din lumea oglinzii.
func _fa_ecranul() -> void:
	var q := QuadMesh.new()
	q.size = raza * 2.0
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER_OGLINDA
	_mat.set_shader_parameter("vedere", _vedere.get_texture())
	_mat.set_shader_parameter("vizibil", 0.0)
	_ecran = MeshInstance3D.new()
	_ecran.mesh = q
	_ecran.material_override = _mat
	_ecran.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ecran.position = Vector3(0, 0, 0.012)
	_ecran.visible = false
	add_child(_ecran)


func _seteaza_vizibil(v: float) -> void:
	_vizibil = v
	_mat.set_shader_parameter("vizibil", v)


func _process(_delta: float) -> void:
	if not _ecran.visible:
		return
	# respiră și se clatină puțin, ca în apă
	var t := Time.get_ticks_msec() / 1000.0
	_vrajitoare.rotation = Vector3(sin(t * 0.9) * 0.03, sin(t * 0.6) * 0.06, sin(t * 0.7) * 0.04)
	if lumina:
		var palpaire := 0.75 + 0.25 * sin(t * 23.0) * sin(t * 7.0)
		lumina.light_color = _culoare_lumina.lerp(Color("7fd18a"), _vizibil)
		lumina.light_energy = lerpf(_energie_lumina, _energie_lumina * 1.4 * palpaire, _vizibil)


func _jucator() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("jucator") as CharacterBody3D


func _scena() -> void:
	while Dialog.activ:
		await get_tree().process_frame
	var jucator := _jucator()
	var c := Cutscena.porneste(self)
	if jucator:
		jucator.seteaza_purtat(true)
		# te apropii de oglindă, drept în fața ei
		var loc := global_position + global_basis.z * departare_jucator
		loc.y = jucator.global_position.y
		var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(jucator, "global_position", loc, 0.7)
	await c.priveste(global_position, 0.7)
	await get_tree().create_timer(0.6).timeout
	# apare: oglinda se întunecă pe pixeli, iar fața vine din adânc spre sticlă
	_vedere.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_ecran.visible = true
	_vrajitoare.position = Vector3(0, 0, -1.6)
	Sunet.reda_la(SUNET_APARITIE, global_position, Sunet.VOLUM_EFECTE)
	var ap := create_tween().set_parallel()
	ap.tween_method(_seteaza_vizibil, 0.0, 1.0, 0.9)
	ap.tween_property(_vrajitoare, "position:z", 0.0, 1.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await ap.finished
	await get_tree().create_timer(0.3).timeout
	Dialog.spune(replici_oglinda)
	await Dialog.terminat
	# dispare: se trage înapoi în adânc și se stinge pe pixeli
	Sunet.reda_la(SUNET_STINGERE, global_position, Sunet.VOLUM_EFECTE - 6.0, 0.0, 0.8)
	var dis := create_tween().set_parallel()
	dis.tween_property(_vrajitoare, "position:z", -1.2, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	dis.tween_method(_seteaza_vizibil, 1.0, 0.0, 1.0).set_delay(0.2)
	await dis.finished
	_ecran.visible = false
	_vedere.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if lumina:
		lumina.light_color = _culoare_lumina
		lumina.light_energy = _energie_lumina
	await get_tree().create_timer(0.4).timeout
	if jucator:
		jucator.seteaza_purtat(false)
	await c.opreste()
	_ocupat = false
