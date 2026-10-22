extends Interactabil
## Ușa camerei 666 de la Paradise Motel, sus pe pasarelă (owner 22.10). Nodul = balamaua (originea lui
## `usa_666.glb`), foaia e spre +X și se deschide spre înăuntru (+`unghi_deschidere`). „[E] Knock” → bați la ușă,
## se aude ceva înăuntru, ușa se deschide și în prag e demonul (`demon.tscn`), la jumătatea skincare-ului: prosop
## pe cap, mască verde pe față, felii de castravete pe ochi. Spune `replici_demon` (owner) și trântește ușa.
## Se poate de câte ori vrei. Camera din spate e în `motel_cladire.glb` (`_camera_666` din tools/blender/motel.py).

const DEMON := preload("res://scenes/demon.tscn")
const SUNET_CIOCANIT := preload("res://sunete/usa_ciocanit.ogg")
const SUNET_SCARTAIT := preload("res://sunete/usa_scartait.ogg")
const SUNET_TRANTIT := preload("res://sunete/usa_inchisa.ogg")
const SUNET_VOCE_DEMON := preload("res://sunete/demon_voce.ogg")

@export_multiline var replici_demon: PackedStringArray = ["Demon: Can I fucking help you?",
	"Demon: I'm doing my skincare routine.."]
@export var unghi_deschidere := 80.0
## Unde stă demonul, față de balama (înăuntru = -Z), și cât de mare e (în prag trebuie să încapă sub toc).
@export var loc_demon := Vector3(0.5, 0.0, -0.85)
@export var marime_demon := 0.8
## Cât așteaptă după ce bați până deschide (secunde).
@export var asteptare := 1.4

var _in_curs := false
var _demon: Demon
var _lumina: OmniLight3D
var _rot_inchisa := 0.0


func _ready() -> void:
	indiciu = "[E] Knock"
	_rot_inchisa = rotation.y
	_demon = DEMON.instantiate() as Demon
	_demon.transform = transform * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * marime_demon), loc_demon)
	_demon.visible = false
	_demon.collision_layer = 0
	_lumina = OmniLight3D.new()
	_lumina.light_color = Color(1.0, 0.75, 0.55)
	_lumina.light_energy = 0.0
	_lumina.omni_range = 3.0
	_lumina.position = transform * Vector3(0.5, 2.0, -1.4)
	get_parent().add_child.call_deferred(_demon)
	get_parent().add_child.call_deferred(_lumina)
	_skincare.call_deferred()


func poate_fi_folosit() -> bool:
	return activ and not _in_curs


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	var c := Cutscena.porneste(self)
	var usa := to_global(Vector3(0.48, 1.45, 0.0))
	Sunet.reda_la(SUNET_CIOCANIT, usa, Sunet.VOLUM_EFECTE, 0.05)
	await c.priveste(usa, 0.5)
	await get_tree().create_timer(asteptare).timeout
	# se deschide: lumina de la oglinda de machiaj, demonul în prag
	_demon.visible = true
	_demon.privire = get_tree().get_first_node_in_group("jucator").get_node("Cap")
	Sunet.reda_la(SUNET_SCARTAIT, usa, Sunet.VOLUM_EFECTE, 0.05)
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "rotation:y", _rot_inchisa + deg_to_rad(unghi_deschidere), 0.9)
	t.tween_property(_lumina, "light_energy", 1.2, 0.6)
	await c.priveste(_demon.global_position + Vector3.UP * 2.0 * marime_demon, 0.6)  # puțin sub ochi (la 2,1 m pe modelul mare)
	for replica in replici_demon:
		_demon.vorbeste = true
		Dialog.spune([replica])
		Sunet.reda_la(SUNET_VOCE_DEMON, _demon.global_position + Vector3.UP * 1.7, Sunet.VOLUM_EFECTE, 0.0)
		var taci := func() -> void: _demon.vorbeste = false
		get_tree().create_timer(replica.length() / 45.0).timeout.connect(taci)
		await Dialog.terminat
		_demon.vorbeste = false
	# trântește ușa
	t = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(self, "rotation:y", _rot_inchisa, 0.22)
	await t.finished
	Sunet.reda_la(SUNET_TRANTIT, usa, Sunet.VOLUM_EFECTE + 3.0, 0.05)
	_lumina.light_energy = 0.0
	_demon.visible = false
	await get_tree().create_timer(0.35).timeout
	c.opreste()
	_in_curs = false


## Prosopul pe cap, masca verde și castraveții pe ochi, lipite de capul demonului (`Model/Cap`, se mișcă odată cu el).
func _skincare() -> void:
	var cap := _demon.get_node("Model/Cap") as Node3D
	var ochi := _demon.get_node("Model/Cap/Ochi") as MeshInstance3D
	var cutie := ochi.get_aabb()
	var mat := load("res://shaders/material_model.tres") as ShaderMaterial
	var centru_ochi := ochi.position + cutie.get_center()
	var fata := cutie.end.z + 0.012  # în fața ochilor (modelul privește spre +Z)
	for semn in [-1.0, 1.0]:
		var felie := _bucata(CylinderMesh.new(), Color("5b6d4e"), mat)
		(felie.mesh as CylinderMesh).top_radius = 0.045
		(felie.mesh as CylinderMesh).bottom_radius = 0.045
		(felie.mesh as CylinderMesh).height = 0.012
		(felie.mesh as CylinderMesh).radial_segments = 10
		felie.rotation.x = PI / 2
		felie.position = Vector3(centru_ochi.x + semn * cutie.size.x * 0.3, centru_ochi.y, ochi.position.z + fata)
		cap.add_child(felie)
	var masca := _bucata(SphereMesh.new(), Color("445d46"), mat)
	(masca.mesh as SphereMesh).radius = 0.13
	(masca.mesh as SphereMesh).height = 0.2
	masca.scale = Vector3(1.0, 1.0, 0.45)
	masca.position = Vector3(centru_ochi.x, centru_ochi.y - 0.04, ochi.position.z + cutie.end.z - 0.035)
	cap.add_child(masca)
	var prosop := _bucata(SphereMesh.new(), Color("83b3b0"), mat)
	(prosop.mesh as SphereMesh).radius = 0.17
	(prosop.mesh as SphereMesh).height = 0.22
	prosop.position = Vector3(centru_ochi.x, centru_ochi.y + 0.17, ochi.position.z + cutie.get_center().z - 0.06)
	cap.add_child(prosop)


func _bucata(mesh: PrimitiveMesh, culoare: Color, mat: ShaderMaterial) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := mat.duplicate() as ShaderMaterial
	m.set_shader_parameter("culoare", culoare)  # primitivele n-au culori în vârfuri (COLOR = alb)
	mi.material_override = m
	return mi
