class_name InManaVizibil
extends RefCounted
## Ce ții în mână se vede mereu, și când ești lipit de un perete sau de frigider (owner 17.11: „obiectele din mână trec
## prin pereți … vreau arma sau obiectul din mână mereu să fie vizibil”). Tot ce stă sub camera jucătorului (armele,
## obiectele, mâinile, vraja) primește o copie a materialului:
##  - materialul PS2 (shaders/ps2.gdshader) cu `in_mana` = true: adâncimea strânsă spre cameră, deci peste pereți, dar
##    cu bucățile obiectului în ordinea lor corectă;
##  - un StandardMaterial3D (flacăra de la țeavă, runele sabiei, arcul de tăietură) cu `no_depth_test`.
## Umbrele lor se opresc (umbra ar fi la adâncimea mutată, în aer). Dacă un nod pleacă de sub cameră (ex. aruncat în
## lume), primește înapoi materialul și umbra lui. Folosit din Jucator: `verifica` la fiecare nod nou din scenă
## (SceneTree.node_added, amânat după _ready-ul lui, unde ModelPS2 își pune materialul) și `aplica` din când în când
## (dacă un script schimbă materialul unui obiect din mână fără să-l scoată din scenă).

const SHADER_PS2 := preload("res://shaders/ps2.gdshader")
const META := &"in_mana_original"  # [material_override, cast_shadow] de dinainte

## material original → copia „în mână” (o singură copie pentru fiecare material, nu una pe obiect)
static var _copii := {}


## Trece prin tot ce e sub `radacina` (idempotent: ce e deja schimbat rămâne așa).
static func aplica(radacina: Node) -> void:
	for nod in radacina.find_children("*", "GeometryInstance3D", true, false):
		_schimba(nod as GeometryInstance3D)


static func verifica(nod: Variant, camera: Variant) -> void:
	# amânat: între timp nodul (sau camera, la schimbarea scenei) poate fi șters
	if not is_instance_valid(nod) or not is_instance_valid(camera) or not nod is GeometryInstance3D:
		return
	if not (nod as Node).is_inside_tree():
		return
	if camera.is_ancestor_of(nod):
		_schimba(nod as GeometryInstance3D)
	else:
		_pune_inapoi(nod as GeometryInstance3D)


static func _schimba(nod: GeometryInstance3D) -> void:
	var mat := nod.material_override
	if mat == null or _copii.values().has(mat):
		return
	var copie := _copie(mat)
	if copie == null:
		return
	if not nod.has_meta(META):
		nod.set_meta(META, [mat, nod.cast_shadow])
	nod.material_override = copie
	nod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _pune_inapoi(nod: GeometryInstance3D) -> void:
	if not nod.has_meta(META):
		return
	var vechi: Array = nod.get_meta(META)
	nod.remove_meta(META)
	if _copii.values().has(nod.material_override):
		nod.material_override = vechi[0]
	nod.cast_shadow = vechi[1]


static func _copie(mat: Material) -> Material:
	if _copii.has(mat):
		return _copii[mat]
	var copie: Material = null
	if mat is ShaderMaterial and (mat as ShaderMaterial).shader == SHADER_PS2:
		copie = mat.duplicate()
		(copie as ShaderMaterial).set_shader_parameter("in_mana", true)
	elif mat is StandardMaterial3D:
		copie = mat.duplicate()
		(copie as StandardMaterial3D).no_depth_test = true
		copie.render_priority = 10
	if copie:
		_copii[mat] = copie
	return copie
