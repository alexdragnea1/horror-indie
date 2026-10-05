class_name Lexy
extends Node3D
## Lexy (models/lexy.glb, copilul `Model`), animată din cod. Nodul ăsta stă la podea, sub șoldurile ei; modelul privește
## spre +Z. Ce știe să facă (le folosește canapea_lexy.gd):
##  - `sezut` (0 = în picioare, 1 = așezată): coapsele în față, gambele în jos, modelul coboară;
##  - brațele ajung singure unde le spui (IK cu două oase: umăr → cot → mână), ex. `await du_mana("D", punct, 0.6)`;
##    `lasa_mana("D")` le duce înapoi în poală (sau pe lângă corp, în picioare);
##  - `privire` = spre ce se uită (un Node3D; null = drept înainte), doar cu capul;
##  - `fumeaza = true`: din când în când trage din joint (mâna la gură, jarul se aprinde, apoi suflă fumul);
##  - `ridica_te()`, `mergi(drum)`, `asaza_te(loc, unghi)`; `mananca = true` (la masă, cu felia de pizza);
##  - la jaf (lexy_masa.gd): `maini_sus()` / `maini_jos()` (tremură cât `frica` > 0), `scoate_bancnota(spre)`,
##    `lasa_felia()`; `omoara(impuls)` = ragdoll (vezi Ragdoll).
## Mâna dreaptă e `D` (spre -X), stânga `S`.

signal a_tras

const MODEL_JOINT := preload("res://models/joint.glb")
const MODEL_FELIE := preload("res://models/felie_pizza.glb")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")
const SUNET_TRAS := preload("res://sunete/fum_tras.ogg")
const SUNET_SUFLAT := preload("res://sunete/fum_suflat.ogg")
const SUNET_MUSCATURA := preload("res://sunete/pizza_muscatura.ogg")
const MODEL_BANCNOTA := preload("res://models/bancnota.glb")
const SUNET_BANCNOTA := preload("res://sunete/bancnota.ogg")
const SUNET_MAINI_SUS := preload("res://sunete/maini_sus.ogg")
## Unde ajung palmele când ridică mâinile (față de umăr, în coordonatele corpului; x e în afară, spre mâna ei).
const MAINI_SUS := Vector3(0.21, 0.4, 0.07)
## Buzunarul mare din fața hanoracului (în coordonatele corpului; originea corpului e în bazin).
const BUZUNAR := Vector3(0.06, 0.09, 0.19)

## Punctul dintre degete (unde ține jointul / felia), în coordonatele antebrațului (originea în cot).
const MANA := {"D": Vector3(-0.011, -0.335, 0.082), "S": Vector3(0.011, -0.335, 0.082)}
## Gura, în coordonatele capului (originea în gât).
const GURA := Vector3(0.0, 0.1, 0.12)
## Încotro ies coatele (în coordonatele corpului).
const POL := {"D": Vector3(-1.0, -0.8, -0.6), "S": Vector3(1.0, -0.8, -0.6)}
## Cât coboară modelul când stă jos și cât de tare își îndoaie picioarele.
const COBORARE := 0.32
const UNGHI_COAPSA := 1.3

@export var fumeaza := false
@export var privire: Node3D
## Cât de departe te urmărește cu privirea (dacă `privire` e null).
@export var distanta_privire := 4.0

var sezut := 0.0
var mananca := false
var joint: Node3D
var felie: Node3D
## Cât de speriată e (0..1): mâinile ridicate tremură, respiră repede.
var frica := 0.0
## Moartă (ragdoll): nu se mai animă nimic.
var mort := false

var _model: Node3D
var _corp: Node3D
var _cap: Node3D
var _brat := {}
var _antebrat := {}
var _coapsa := {}
var _gamba := {}
var _jar: GeometryInstance3D
var _lumina_jar: OmniLight3D
var _fum_jar: Timer
## Pentru fiecare mână: unde stă în repaus (în coordonatele corpului), spre ce merge (Node3D sau punct global) și cât (0..1).
var _repaus := {}
var _spre := {"D": null, "S": null}
var _cat := {"D": 0.0, "S": 0.0}
var _ocupata := {"D": false, "S": false}
var _aplecare := 0.0
var _mers := 0.0
var _merge := false
var _timp := 0.0
var _pana_la_fum := 4.0
var _pana_la_muscatura := 2.0
var _jar_aprins := 0.0
## Tween-ul care mișcă acum fiecare mână (unul nou îl oprește pe cel vechi).
var _tw := {"D": null, "S": null}
## Pusă când o întrerupe jaful: mușcatul din pizza nu mai continuă.
var _oprita := false
## Punctele spre care merg palmele când ridică mâinile (copii ai corpului).
var _sus := {}


func _ready() -> void:
	_model = $Model
	_corp = _model.find_child("Corp", true, false)
	_cap = _model.find_child("Cap", true, false)
	for l in ["D", "S"]:
		_brat[l] = _model.find_child("Brat" + l, true, false)
		_antebrat[l] = _model.find_child("Antebrat" + l, true, false)
		_coapsa[l] = _model.find_child("Coapsa" + l, true, false)
		_gamba[l] = _model.find_child("Gamba" + l, true, false)
	_actualizeaza_repaus()


func _actualizeaza_repaus() -> void:
	# în poală (așezată) sau pe lângă corp (în picioare), în coordonatele corpului
	var jos_d := Vector3(-0.06, -0.55, 0.03)
	var poala_d := Vector3(-0.12, -0.28, 0.24)
	_repaus["D"] = jos_d.lerp(poala_d, sezut)
	_repaus["S"] = Vector3(-jos_d.x, jos_d.y, jos_d.z).lerp(Vector3(0.1, -0.29, 0.22), sezut)


# ---------------------------------------------------------------- obiecte în mână

## Pune jointul aprins în mâna dreaptă (cu jarul și firul de fum).
func da_joint() -> Node3D:
	joint = MODEL_JOINT.instantiate()
	joint.set_script(SCRIPT_MODEL)
	joint.set("material", MATERIAL)
	joint.set("umbre", false)
	joint.set("stralucitoare", PackedStringArray(["Jar"]))
	joint.set("stralucire", 0.8)
	tine_in_mana(joint, "D")
	_pregateste_jar(joint)
	return joint


func _pregateste_jar(j: Node3D) -> void:
	await get_tree().process_frame
	_jar = j.find_child("Jar", true, false) as GeometryInstance3D
	_lumina_jar = OmniLight3D.new()
	_lumina_jar.light_color = Color(1.0, 0.5, 0.25)
	_lumina_jar.light_energy = 0.25
	_lumina_jar.omni_range = 0.7
	_lumina_jar.light_volumetric_fog_energy = 0.0  # o lumină atât de mică și de aproape face pătrate negre în ceață
	j.add_child(_lumina_jar)
	_lumina_jar.position = Vector3(0.105, 0, 0)
	_fum_jar = Lexy.fir_de_fum(j, Vector3(0.11, 0, 0))
	jar(0.0)


## Cât de tare arde jarul (0 = mocnește, 1 = tragi din el). Merge și pe jointul din mâna jucătorului.
func jar(cat: float) -> void:
	_jar_aprins = cat
	if is_instance_valid(_jar):
		_jar.set_instance_shader_parameter("stralucire", lerpf(0.8, 3.0, cat))
	if is_instance_valid(_lumina_jar):
		_lumina_jar.light_energy = lerpf(0.25, 1.4, cat)


## Stinge jarul de tot (în scrumieră): fără lumină, fără fum.
func stinge_jar() -> void:
	if is_instance_valid(_jar):
		_jar.set_instance_shader_parameter("stralucire", 0.0)
	if is_instance_valid(_lumina_jar):
		_lumina_jar.queue_free()
	if is_instance_valid(_fum_jar):
		_fum_jar.stop()


## Pune `obiect` între degetele mâinii `l` (îl mută din locul unde era).
func tine_in_mana(obiect: Node3D, l: String) -> void:
	if obiect.get_parent():
		obiect.get_parent().remove_child(obiect)
	_antebrat[l].add_child(obiect)
	obiect.position = MANA[l]
	# jointul / felia ies înainte dintre degete, puțin în afară
	obiect.basis = Basis(Vector3.UP, -PI / 2.0 + (0.4 if l == "D" else -0.4)) * Basis(Vector3.FORWARD, 0.3)


## Unde e acum punctul dintre degete (global).
func punct_mana(l: String) -> Vector3:
	return _antebrat[l].global_transform * MANA[l]


func gura() -> Vector3:
	return _cap.global_transform * GURA


# ---------------------------------------------------------------- brațe (IK)

## Duce mâna `l` la `tinta` (un Node3D urmărit sau un punct global) în `durata` secunde. Dacă mâna era deja
## întinsă spre altceva, alunecă de acolo până la noua țintă (nu sare).
func du_mana(l: String, tinta: Variant, durata: float) -> void:
	_ocupata[l] = true
	var t := _tween_mana(l)
	if _cat[l] > 0.01:
		var de_la := _tinta_globala(l)
		_cat[l] = 1.0
		_spre[l] = de_la
		t.tween_method(func(v: float) -> void: _spre[l] = de_la.lerp(_punct(tinta), v), 0.0, 1.0, durata)
		await t.finished
		_spre[l] = tinta
		return
	_spre[l] = tinta
	t.tween_method(func(v: float) -> void: _cat[l] = v, _cat[l], 1.0, durata)
	await t.finished


## Lasă mâna `l` înapoi în repaus.
func lasa_mana(l: String, durata := 0.6) -> void:
	var t := _tween_mana(l)
	t.tween_method(func(v: float) -> void: _cat[l] = v, _cat[l], 0.0, durata)
	await t.finished
	_ocupata[l] = false


## Un tween nou pentru mâna `l`; îl oprește pe cel de dinainte (altfel s-ar trage de mână în două părți).
func _tween_mana(l: String) -> Tween:
	var vechi: Tween = _tw[l]
	if vechi and vechi.is_valid():
		vechi.kill()
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tw[l] = t
	return t


func _punct(tinta: Variant) -> Vector3:
	return (tinta as Node3D).global_position if tinta is Node3D else tinta


func _tinta_globala(l: String) -> Vector3:
	var repaus: Vector3 = _corp.global_transform * (_brat[l].position + _repaus[l])
	var spre: Variant = _spre[l]
	if _cat[l] <= 0.0 or spre == null or (spre is Object and not is_instance_valid(spre)):
		return repaus
	return repaus.lerp(_punct(spre), _cat[l])


## IK cu două oase: întoarce brațul și antebrațul ca mâna să ajungă în `tinta` (globală).
func _ik(l: String, tinta: Vector3) -> void:
	var brat: Node3D = _brat[l]
	var antebrat: Node3D = _antebrat[l]
	var t := _corp.global_transform.affine_inverse() * tinta - brat.position
	var v1 := antebrat.position
	var v2: Vector3 = MANA[l]
	var l1 := v1.length()
	var l2 := v2.length()
	var d := clampf(t.length(), absf(l1 - l2) + 0.01, l1 + l2 - 0.005)
	var dir := t.normalized() if t.length() > 0.001 else Vector3.DOWN
	var cos_a := (l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d)
	var a := acos(clampf(cos_a, -1.0, 1.0))
	var axa := dir.cross(POL[l]).normalized()
	if axa.length() < 0.5:
		axa = Vector3.RIGHT
	var u := dir.rotated(axa, a)
	var cot := u * l1
	var f := (dir * d - cot).normalized()
	var r1 := Basis(Quaternion(v1.normalized(), u))
	var r2 := Basis(Quaternion(v2.normalized(), f))
	brat.basis = r1
	antebrat.basis = r1.inverse() * r2


# ---------------------------------------------------------------- mers, așezat

## Se ridică în picioare: se apleacă în față, picioarele se îndreaptă, pasul înainte (`inainte`, metri).
func ridica_te(durata := 1.1, inainte := 0.32) -> void:
	var start := global_position
	var fata := global_basis.z
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(func(v: float) -> void:
		sezut = 1.0 - v
		_aplecare = sin(v * PI) * 0.5
		global_position = start + fata * inainte * v, 0.0, 1.0, durata)
	await t.finished
	_aplecare = 0.0
	_actualizeaza_repaus()


## Se așază pe scaunul de la `loc` (global, sub șolduri), cu fața spre `unghi` (rotation.y).
func asaza_te(loc: Vector3, unghi: float, durata := 1.1) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "rotation:y", rotation.y + angle_difference(rotation.y, unghi), 0.4)
	await tw.finished
	var start := global_position
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(func(v: float) -> void:
		sezut = v
		_aplecare = sin(v * PI) * 0.4
		global_position = start.lerp(loc, v), 0.0, 1.0, durata)
	await t.finished
	_aplecare = 0.0
	_actualizeaza_repaus()


## Merge pe `drum` (puncte globale), cu viteza dată; se întoarce spre fiecare punct.
func mergi(drum: Array[Vector3], viteza := 1.1) -> void:
	_merge = true
	for punct in drum:
		punct.y = global_position.y
		var d := punct - global_position
		var unghi := atan2(d.x, d.z)
		var rot := create_tween().set_trans(Tween.TRANS_SINE)
		rot.tween_property(self, "rotation:y", rotation.y + angle_difference(rotation.y, unghi), 0.3)
		var t := create_tween()
		t.tween_property(self, "global_position", punct, d.length() / viteza)
		await t.finished
	_merge = false


# ---------------------------------------------------------------- în fiecare cadru

func _process(delta: float) -> void:
	_timp += delta
	# picioarele: așezată (coapsele în față) + mersul
	var leg := 0.0
	if _merge:
		_mers += delta * 7.0
		leg = 1.0
	var balans := sin(_mers) * 0.45 * leg
	for l in ["D", "S"]:
		var s := 1.0 if l == "D" else -1.0
		var faza := balans * s
		_coapsa[l].rotation.x = -UNGHI_COAPSA * sezut + faza
		# genunchiul se îndoaie cât piciorul e în spate
		_gamba[l].rotation.x = UNGHI_COAPSA * sezut + maxf(0.0, faza) * 1.4 * leg
	_model.position.y = -COBORARE * sezut + absf(sin(_mers)) * 0.025 * leg
	# corpul: respiră, se apleacă când se ridică / se așază, se lasă pe spătar când stă
	_corp.rotation.x = _aplecare - 0.12 * sezut * (1.0 - _aplecare * 2.0) + sin(_timp * lerpf(1.6, 5.5, frica)) * lerpf(0.01, 0.018, frica)
	_actualizeaza_repaus()
	# speriată, cu mâinile sus: palmele tremură puțin
	for l: String in _sus:
		var s := -1.0 if l == "D" else 1.0
		var tremur := Vector3(sin(_timp * 31.0 + s), sin(_timp * 26.0 + s * 2.0), sin(_timp * 23.0)) * 0.006 * frica
		(_sus[l] as Node3D).position = _brat[l].position + Vector3(MAINI_SUS.x * s, MAINI_SUS.y, MAINI_SUS.z) + tremur
	# brațele: legănate la mers, altfel spre ținta lor
	for l in ["D", "S"]:
		var tinta := _tinta_globala(l)
		if _merge and not _ocupata[l]:
			var s := 1.0 if l == "D" else -1.0
			tinta += global_basis.z * sin(_mers) * -s * 0.12
		_ik(l, tinta)
	_priveste(delta)
	if fumeaza and not _merge:
		_pana_la_fum -= delta
		if _pana_la_fum <= 0.0 and not _ocupata["D"] and is_instance_valid(joint) and joint.get_parent() == _antebrat["D"]:
			_pana_la_fum = randf_range(6.0, 9.0)
			trage_un_fum()
	if mananca and not _merge:
		_pana_la_muscatura -= delta
		if _pana_la_muscatura <= 0.0 and not _ocupata["D"]:
			_pana_la_muscatura = randf_range(2.5, 4.0)
			_musca()


func _priveste(delta: float) -> void:
	var tinta := Vector2.ZERO  # (în sus, într-o parte), radiani
	var nod := privire
	if nod == null:
		var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
		if jucator and jucator.global_position.distance_to(global_position) < distanta_privire:
			nod = jucator.get_node("Cap") as Node3D
	if nod:
		var local := _corp.global_transform.affine_inverse() * nod.global_position - _cap.position
		tinta.y = clampf(atan2(local.x, local.z), -1.2, 1.2)
		tinta.x = clampf(-atan2(local.y, Vector2(local.x, local.z).length()), -0.5, 0.6)
	_cap.rotation.y = lerp_angle(_cap.rotation.y, tinta.y, 1.0 - exp(-delta * 4.0))
	_cap.rotation.x = lerp_angle(_cap.rotation.x, tinta.x, 1.0 - exp(-delta * 4.0))


# ---------------------------------------------------------------- fumatul, mâncatul

## Trage un fum: mâna la gură, jarul se aprinde, ține fumul, lasă mâna, suflă.
func trage_un_fum() -> void:
	var gura_nod := Node3D.new()
	_cap.add_child(gura_nod)
	gura_nod.position = GURA + Vector3(0.02, -0.01, 0.03)
	await du_mana("D", gura_nod, 0.8)
	Sunet.reda_la(SUNET_TRAS, gura(), Sunet.VOLUM_EFECTE - 8.0, 0.05)
	var t := create_tween()
	t.tween_method(jar, 0.0, 1.0, 0.5)
	t.tween_interval(0.6)
	t.tween_method(jar, 1.0, 0.0, 0.8)
	await get_tree().create_timer(1.1).timeout
	await lasa_mana("D", 0.8)
	gura_nod.queue_free()
	await get_tree().create_timer(0.3).timeout
	sufla()
	a_tras.emit()


## Suflă fumul pe gură (un nor care iese înainte și se ridică).
func sufla() -> void:
	Sunet.reda_la(SUNET_SUFLAT, gura(), Sunet.VOLUM_EFECTE - 8.0, 0.05)
	var p := Lexy.fum(get_tree().current_scene, 1.0)
	p.global_position = gura()
	p.direction = global_basis.z + Vector3.UP * 0.2
	p.emitting = true
	p.finished.connect(p.queue_free)


## Fumul: un nor de particule cenușii care iese dintr-o dată (0 = un pufuleț mic, ca firul de la jar; 1 = un fum
## suflat). Particulele pornesc toate odată (one_shot, explosiveness 1): emise treptat, cele care încă n-au ieșit
## se desenau ca un pătrat negru la sursă. Pune `emitting = true` când vrei să iasă.
static func fum(parinte: Node, putere: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * lerpf(0.03, 0.09, putere)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat
	p.mesh = quad
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.75, 0.78, 0.78, 0.0), Color(0.75, 0.78, 0.78, 0.35 + 0.2 * putere),
		Color(0.7, 0.72, 0.74, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	p.color_ramp = gradient
	p.local_coords = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime_randomness = 0.5
	p.emitting = false
	if putere <= 0.0:
		p.amount = 2
		p.lifetime = 2.2
		p.direction = Vector3.UP
		p.spread = 10.0
		p.initial_velocity_min = 0.03
		p.initial_velocity_max = 0.07
		p.gravity = Vector3(0.02, 0.08, 0.0)
		p.scale_amount_min = 0.6
		p.scale_amount_max = 2.2
	else:
		p.amount = 36
		p.lifetime = 2.6
		p.spread = 20.0
		p.initial_velocity_min = 0.1
		p.initial_velocity_max = 0.6
		p.damping_min = 0.3
		p.damping_max = 0.5
		p.gravity = Vector3(0, 0.12, 0)
		p.scale_amount_min = 0.8
		p.scale_amount_max = 3.0
	var curba := Curve.new()
	curba.add_point(Vector2(0.0, 0.4))
	curba.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = curba
	parinte.add_child(p)
	return p


## Firul subțire de fum care urcă din jar: un pufuleț la fiecare 0,3 s din punctul `decalaj` al lui `nod`.
## Îl oprești cu `.stop()` pe timerul întors.
static func fir_de_fum(nod: Node3D, decalaj: Vector3) -> Timer:
	var ceas := Timer.new()
	ceas.wait_time = 0.3
	ceas.autostart = true
	nod.add_child(ceas)
	ceas.timeout.connect(func() -> void:
		if not nod.is_inside_tree():
			return
		var p := Lexy.fum(nod.get_tree().current_scene, 0.0)
		p.global_position = nod.global_transform * decalaj
		p.emitting = true
		p.finished.connect(p.queue_free))
	return ceas


## Ia o felie de pizza (din cutia de la `cutie`, punct global) și o ține în mâna dreaptă.
func ia_felie(cutie: Vector3) -> void:
	await du_mana("D", cutie + Vector3.UP * 0.06, 0.7)
	if _oprita:
		return
	felie = MODEL_FELIE.instantiate()
	felie.set_script(SCRIPT_MODEL)
	felie.set("material", MATERIAL)
	felie.set("umbre", false)
	tine_in_mana(felie, "D")
	await lasa_mana("D", 0.6)


var _cutie_pizza := Vector3.ZERO
var _muscaturi := 0


## Începe să mănânce pizza de la masă (cutia la `cutie`, global).
func incepe_pizza(cutie: Vector3) -> void:
	if _oprita:
		return
	_cutie_pizza = cutie
	await ia_felie(cutie)
	if _oprita:
		return
	_muscaturi = 0
	mananca = true


func _musca() -> void:
	var gura_nod := Node3D.new()
	_cap.add_child(gura_nod)
	gura_nod.position = GURA + Vector3(0.0, -0.02, 0.05)
	await du_mana("D", gura_nod, 0.6)
	if _oprita:
		gura_nod.queue_free()
		return
	Sunet.reda_la(SUNET_MUSCATURA, gura(), Sunet.VOLUM_EFECTE - 6.0, 0.08)
	_muscaturi += 1
	if is_instance_valid(felie):
		felie.scale.x = maxf(1.0 - _muscaturi * 0.22, 0.1)
	await get_tree().create_timer(0.25).timeout
	if _oprita:
		gura_nod.queue_free()
		return
	await lasa_mana("D", 0.6)
	gura_nod.queue_free()
	if _oprita:
		return
	if _muscaturi >= 4 and is_instance_valid(felie):
		# a terminat felia: coaja o lasă în cutie și ia alta
		mananca = false
		var coaja := felie
		felie = null
		await du_mana("D", _cutie_pizza + Vector3(0.08, 0.04, 0.0), 0.7)
		coaja.queue_free()
		await lasa_mana("D", 0.5)
		await get_tree().create_timer(1.5).timeout
		await incepe_pizza(_cutie_pizza)


## Se apleacă în față (0 = dreaptă) în `durata` secunde (ex. ca să ajungă la scrumieră).
func apleaca(cat: float, durata: float) -> void:
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "_aplecare", cat, durata)
	await t.finished


## Adevărat cât mâna `l` face ceva (trage un fum, mușcă, ia ceva).
func mana_ocupata(l: String) -> bool:
	return _ocupata[l]


# ---------------------------------------------------------------- jaful (lexy_masa.gd)

## Se sperie și ridică mâinile, cu palmele lângă cap (felia rămâne în mâna dreaptă). Nu mai mănâncă.
func maini_sus(durata := 0.35) -> void:
	_oprita = true
	mananca = false
	frica = 1.0
	Sunet.reda_la(SUNET_MAINI_SUS, gura(), Sunet.VOLUM_EFECTE - 4.0, 0.05)
	for l in ["D", "S"]:
		if not _sus.has(l):
			var m := Node3D.new()
			m.name = "MainaSus" + l
			_corp.add_child(m)
			_sus[l] = m
		du_mana(l, _sus[l], durata)
	await get_tree().create_timer(durata).timeout


## Lasă mâinile jos, încet (încă speriată).
func maini_jos(durata := 1.2) -> void:
	for l in ["D", "S"]:
		lasa_mana(l, durata)
	await get_tree().create_timer(durata).timeout
	for l: String in _sus:
		(_sus[l] as Node3D).queue_free()
	_sus.clear()


## Bagă mâna stângă în buzunarul hanoracului, scoate o bancnotă de 5 dolari și ți-o întinde până la `spre`
## (punct global). Întoarce bancnota (încă în mâna ei).
func scoate_bancnota(spre: Vector3) -> Node3D:
	var buzunar := Node3D.new()
	_corp.add_child(buzunar)
	buzunar.position = BUZUNAR
	await du_mana("S", buzunar, 0.6)
	# scotocește puțin în buzunar
	for i in 2:
		await du_mana("S", _corp.global_transform * (BUZUNAR + Vector3(0.025, -0.02, -0.02)), 0.15)
		await du_mana("S", buzunar, 0.15)
	var b := MODEL_BANCNOTA.instantiate() as Node3D
	b.set_script(SCRIPT_MODEL)
	b.set("material", MATERIAL)
	b.set("umbre", false)
	tine_in_mana(b, "S")
	# o ține de un capăt, în picioare (bancnota e culcată în planul XZ al modelului)
	b.basis = Basis(Vector3.UP, 0.25) * Basis(Vector3.RIGHT, PI / 2.0)
	b.position = MANA["S"] + Vector3(0.0, -0.035, 0.0)
	Sunet.reda_la(SUNET_BANCNOTA, punct_mana("S"), Sunet.VOLUM_EFECTE - 4.0, 0.05)
	await get_tree().create_timer(0.15).timeout
	buzunar.queue_free()
	await du_mana("S", spre, 0.85)
	return b


## Pune felia de pizza (sau ce a rămas din ea) înapoi în cutie, cu mâna dreaptă.
func lasa_felia() -> void:
	var felii: Array[Node3D] = []
	for copil in _antebrat["D"].get_children():
		if copil is Node3D and copil.scene_file_path == MODEL_FELIE.resource_path:
			felii.append(copil)
	felie = null
	if felii.is_empty():
		return
	await du_mana("D", _cutie_pizza + Vector3(0.05, 0.04, 0.0), 0.8)
	for f in felii:
		# rămâne în cutie, culcată
		f.reparent(get_tree().current_scene, true)
		f.global_position = _cutie_pizza + Vector3(0.05, 0.015, 0.02)
		f.global_basis = Basis(Vector3.UP, randf() * TAU)
	await lasa_mana("D", 0.7)


## Moare: tot corpul devine ragdoll (bucățile modelului trec în corpuri fizice). Întoarce ragdoll-ul.
func omoara(impuls: Vector3) -> Ragdoll:
	mort = true
	mananca = false
	_oprita = true
	frica = 0.0
	set_process(false)
	for l in ["D", "S"]:
		var t: Tween = _tw[l]
		if t and t.is_valid():
			t.kill()
	return Ragdoll.din_model(_model, impuls, [])
