class_name Fulger
extends Node3D
## Un fulger (atacul asupra conacului): o linie frântă de la `sus` la `jos`, cu ramificații, care pâlpâie de 3 ori și se
## stinge într-o jumătate de secundă; jos, o lumină puternică (luminează tot locul o clipă) și scântei pe pământ.
## Fiecare bucată a liniei e făcută din două plăci încrucișate, ca să se vadă din orice parte.
##   Fulger.loveste(self, cer, pamant, Color(1, 0.4, 0.35))

const SUNET := preload("res://sunete/atac_fulger.ogg")
## Cât de tare (dB în plus) și de departe (`unit_size`) se aude pocnetul fulgerului. Atacul asupra conacului le ridică
## (fulgerele cad la 30-40 m de tine și nu se auzeau deloc) și le pune la loc când pleacă; luptele le lasă așa.
static var volum_sunet := 0.0
static var marime_sunet := 18.0

var culoare := Color(1.0, 0.45, 0.4)
var grosime := 0.22

var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _lumina: OmniLight3D


static func loveste(nod: Node, sus: Vector3, jos: Vector3, culoare_ := Color(1.0, 0.45, 0.4), grosime_ := 0.22, sunet := true,
		putere_lumina := 1.0) -> Fulger:
	var f := Fulger.new()
	f.culoare = culoare_
	f.grosime = grosime_
	nod.get_tree().current_scene.add_child(f)
	f._construieste(sus, jos, putere_lumina)
	if sunet:
		VrajaAtac.sunet_la(f, SUNET, jos, Sunet.VOLUM_EFECTE + volum_sunet, marime_sunet, 0.15)
	return f


func _construieste(sus: Vector3, jos: Vector3, putere_lumina: float) -> void:
	var im := ImmediateMesh.new()
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.disable_fog = true
	_mat.no_depth_test = false
	_mat.albedo_color = culoare.lerp(Color.WHITE, 0.45)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat)
	var drum := _drum(sus, jos, 16, 0.07)
	_linie(im, drum, grosime)
	# ramificațiile: pornesc din drum, mai subțiri, în jos și într-o parte
	for k in randi_range(2, 4):
		var i := randi_range(2, drum.size() - 5)
		var de_la: Vector3 = drum[i]
		var lung := (sus - jos).length() * randf_range(0.15, 0.3)
		var lateral := Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)).normalized()
		var la := de_la + (lateral * 0.8 + Vector3.DOWN).normalized() * lung
		_linie(im, _drum(de_la, la, 6, 0.12), grosime * 0.5)
	im.surface_end()
	_mesh = MeshInstance3D.new()
	_mesh.mesh = im
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	_lumina = OmniLight3D.new()
	_lumina.light_color = culoare.lerp(Color.WHITE, 0.3)
	_lumina.light_energy = 0.0
	_lumina.omni_range = 40.0
	_lumina.omni_attenuation = 0.9
	_lumina.light_volumetric_fog_energy = 0.6
	add_child(_lumina)
	_lumina.global_position = jos + Vector3.UP * 3.0
	# scântei pe pământ
	var c := culoare.lerp(Color.WHITE, 0.5)
	var scantei := VrajaAtac.particule(self, 30, 0.6, 0.08, [Color(c, 1.0), Color(culoare, 1.0), Color(culoare, 0.0)])
	scantei.global_position = jos + Vector3.UP * 0.1
	scantei.one_shot = true
	scantei.explosiveness = 1.0
	scantei.direction = Vector3.UP
	scantei.spread = 70.0
	scantei.initial_velocity_min = 3.0
	scantei.initial_velocity_max = 8.0
	scantei.gravity = Vector3(0, -9.8, 0)
	scantei.emitting = true
	_pilpaie(putere_lumina)


## Puncte de la `a` la `b`, împinse la întâmplare într-o parte (cât `abatere` din lungime), capetele rămân pe loc.
func _drum(a: Vector3, b: Vector3, n: int, abatere: float) -> PackedVector3Array:
	var puncte := PackedVector3Array()
	var lung := (b - a).length()
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(b, t)
		if i > 0 and i < n:
			p += Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1)) * lung * abatere
		puncte.append(p)
	return puncte


func _linie(im: ImmediateMesh, drum: PackedVector3Array, gros: float) -> void:
	for i in drum.size() - 1:
		var a := drum[i]
		var b := drum[i + 1]
		var d := (b - a).normalized()
		var u := d.cross(Vector3.RIGHT if absf(d.x) < 0.9 else Vector3.FORWARD).normalized()
		var v := d.cross(u).normalized()
		var g := gros * (1.0 - 0.5 * float(i) / drum.size())
		for axa in [u, v]:
			var o: Vector3 = axa * g * 0.5
			im.surface_add_vertex(a - o)
			im.surface_add_vertex(a + o)
			im.surface_add_vertex(b + o)
			im.surface_add_vertex(a - o)
			im.surface_add_vertex(b + o)
			im.surface_add_vertex(b - o)


func _pilpaie(putere: float) -> void:
	var e := 22.0 * putere
	for pas in [[true, e, 0.06], [false, e * 0.2, 0.05], [true, e * 0.8, 0.07], [false, e * 0.1, 0.04], [true, e * 0.6, 0.05]]:
		_mesh.visible = pas[0]
		_lumina.light_energy = pas[1]
		await get_tree().create_timer(pas[2]).timeout
	var t := create_tween().set_parallel()
	t.tween_property(_lumina, "light_energy", 0.0, 0.4)
	t.tween_property(_mat, "albedo_color:a", 0.0, 0.3)
	await t.finished
	await get_tree().create_timer(0.5).timeout
	queue_free()
