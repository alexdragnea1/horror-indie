extends Node3D
## Ce e în jurul conacului (conac.tscn), pus din cod (`saminta`):
##  - gardul de fier (gard_fier.glb) în cerc pe marginea platoului (`centru_gard`, `raza_gard`), cu poarta închisă
##    (poarta_conac.glb) în față, spre potecă; fiecare bucată are o cutie de coliziune (gardul e limita scenei);
##  - felinarele de pe alee și de la scară (felinar_conac.glb + OmniLight caldă, care pâlpâie ușor ca o flacără);
##  - mormintele familiei în stânga curții, câțiva copaci morți pe platou;
##  - pădurea de pe coaste (brazi, copaci goi și morți), un MultiMesh pe fiecare bucată de model, ocolind poteca.

const MATERIAL := preload("res://shaders/material_model.tres")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const GARD := preload("res://models/gard_fier.glb")
const POARTA := preload("res://models/poarta_conac.glb")
const FELINAR := preload("res://models/felinar_conac.glb")
const MORMINTE := [preload("res://models/mormant_1.glb"), preload("res://models/mormant_2.glb"), preload("res://models/mormant_3.glb"),
	preload("res://models/cruce.glb")]
const COPACI_PLATOU := [preload("res://models/copac_mort_1.glb"), preload("res://models/copac_mort_2.glb")]
const COPACI_COASTA := [preload("res://models/brad_1.glb"), preload("res://models/brad_2.glb"), preload("res://models/brad_1.glb"),
	preload("res://models/copac_gol.glb"), preload("res://models/copac_mort_1.glb"), preload("res://models/copac_mort_2.glb")]
const LUNGIME_GARD := 2.4

@export var deal: DealConac
@export var saminta := 712
@export var centru_gard := Vector2(0.0, -0.5)
@export var raza_gard := 31.7
## Jumătate din lățimea porții, cu stâlpi cu tot (acolo se oprește gardul).
@export var jumatate_poarta := 2.2
## Felinarele (X, Z): pe aleea dintre fântână și poartă și la picioarele scării.
@export var felinare := PackedVector2Array([Vector2(-2.6, 15), Vector2(2.6, 15), Vector2(-2.6, 23), Vector2(2.6, 23),
	Vector2(-2.6, 30), Vector2(2.6, 30), Vector2(-4.4, -3.6), Vector2(4.4, -3.6)])
@export var culoare_felinar := Color(1.0, 0.72, 0.42)
@export var energie_felinar := 1.6
## Mormintele: unde e micul cimitir al familiei (colțul din stânga față al curții).
@export var cimitir := Rect2(-25, 4, 8, 13)
## Grosimea trunchiului copacilor morți de pe platou (raza, la mărimea 1), pentru coliziune.
@export var raza_trunchi := 0.25
## Pădurea de pe coaste: de la ce rază începe, până unde merge și cât de deasă e.
@export var padure_de_la := 41.0
@export var padure_pana_la := 200.0
@export var distanta_copaci := 5.5
@export_range(0.0, 1.0) var densitate := 0.62

var _r := RandomNumberGenerator.new()
var _instante: Dictionary = {}
var _corp: StaticBody3D
var _flacari: Array[OmniLight3D] = []
var _modele_felinare: Array[Node3D] = []
var _poarta: Node3D


func _ready() -> void:
	_r.seed = saminta
	_corp = StaticBody3D.new()
	_corp.name = "Coliziuni"
	add_child(_corp)
	_gardul()
	_felinare()
	_cimitirul()
	_padurea()
	_construieste_multimesh()


func _process(_delta: float) -> void:
	# flăcările din felinare: tremură puțin, fiecare în ritmul ei
	var t := Time.get_ticks_msec() * 0.001
	for i in _flacari.size():
		_flacari[i].light_energy = energie_felinar * (0.88 + 0.08 * sin(t * 7.0 + i * 1.7) + 0.05 * sin(t * 13.3 + i * 4.1))


func _pune(scena: PackedScene, pozitie: Vector3, unghi: float, stralucitoare := PackedStringArray()) -> Node3D:
	var nod := scena.instantiate() as Node3D
	nod.set_script(SCRIPT_MODEL)
	nod.set("material", MATERIAL)
	if not stralucitoare.is_empty():
		nod.set("stralucitoare", stralucitoare)
	add_child(nod)
	nod.position = pozitie
	nod.rotation.y = unghi
	return nod


func _cutie(marime: Vector3, transform: Transform3D) -> void:
	var forma := CollisionShape3D.new()
	var cutie := BoxShape3D.new()
	cutie.size = marime
	forma.shape = cutie
	forma.transform = transform
	_corp.add_child(forma)


func _punct_gard(a: float) -> Vector3:
	return Vector3(centru_gard.x + sin(a) * raza_gard, 0.0, centru_gard.y + cos(a) * raza_gard)


func _gardul() -> void:
	# poarta, în față (a = 0)
	var la_poarta := _punct_gard(0.0)
	_poarta = _pune(POARTA, la_poarta, 0.0)
	_cutie(Vector3(jumatate_poarta * 2.0, 3.2, 0.8), Transform3D(Basis(), la_poarta + Vector3.UP * 1.6))
	# gardul: coarde egale de la un stâlp al porții la celălalt, de jur împrejur
	var a0 := asin(jumatate_poarta / raza_gard)
	var a1 := TAU - a0
	var bucati := ceili((a1 - a0) * raza_gard / LUNGIME_GARD)
	for i in bucati:
		var p := _punct_gard(a0 + (a1 - a0) * i / bucati)
		var q := _punct_gard(a0 + (a1 - a0) * (i + 1) / bucati)
		var d := q - p
		var unghi := atan2(-d.z, d.x)  # +X-ul bucății spre punctul următor
		var bucata := _pune(GARD, p, unghi)
		bucata.scale.x = d.length() / LUNGIME_GARD
		var baza := Basis(Vector3.UP, unghi)
		_cutie(Vector3(d.length(), 3.0, 0.12), Transform3D(baza, (p + q) * 0.5 + Vector3.UP * 1.5))


func _felinare() -> void:
	for f in felinare:
		var poz := Vector3(f.x, 0.0, f.y)
		_modele_felinare.append(_pune(FELINAR, poz, _r.randf_range(-0.2, 0.2), PackedStringArray(["Lumini"])))
		var lumina := OmniLight3D.new()
		lumina.light_color = culoare_felinar
		lumina.light_energy = energie_felinar
		lumina.omni_range = 7.5
		lumina.omni_attenuation = 1.4
		lumina.light_volumetric_fog_energy = 1.5
		add_child(lumina)
		lumina.position = poz + Vector3.UP * 2.85
		_flacari.append(lumina)
		var forma := CollisionShape3D.new()
		var cilindru := CylinderShape3D.new()
		cilindru.radius = 0.2
		cilindru.height = 3.2
		forma.shape = cilindru
		forma.position = poz + Vector3.UP * 1.6
		_corp.add_child(forma)


## Atacul Warlock-ului (atac_conac.gd): flăcările din felinare se sting (`animat` = una câte una, cu pâlpâit și un fum mic).
func stinge_felinarele(animat: bool) -> void:
	for i in _flacari.size():
		if animat:
			await get_tree().create_timer(randf_range(0.12, 0.3)).timeout
			for k in 3:  # pâlpâie de câteva ori înainte să se stingă
				_flacari[i].visible = k % 2 == 1
				await get_tree().create_timer(0.06).timeout
		_flacari[i].visible = false
		var model := _modele_felinare[i]
		var flacara := model.get_node_or_null("Lumini") as GeometryInstance3D
		if flacara:
			flacara.visible = false


## Prima vrajă a Warlock-ului sparge poarta: dispare (coliziunea rămâne, acolo e molozul ei).
func strica_poarta() -> void:
	if is_instance_valid(_poarta):
		_poarta.hide()


func _cimitirul() -> void:
	# trei rânduri strâmbe de morminte vechi, cu fața spre alee
	for rand in 3:
		for k in 3:
			if _r.randf() < 0.15:
				continue
			var x := cimitir.position.x + 1.3 + k * 2.6 + _r.randf_range(-0.3, 0.3)
			var z := cimitir.position.y + 1.5 + rand * 4.0 + _r.randf_range(-0.3, 0.3)
			var nod := _pune(MORMINTE[_r.randi() % MORMINTE.size()], Vector3(x, 0.0, z), PI * 0.5 + _r.randf_range(-0.15, 0.15))
			nod.rotation.z = _r.randf_range(-0.05, 0.05)
			ColiziuneModel.pentru_nod(nod, false)
	# copaci morți pe platou, lângă gard; coliziune doar cât trunchiul (un cilindru cât toată coroana ar fi un perete
	# nevăzut de câțiva metri între curte și gard)
	for p in [Vector3(-26, 0, 1), Vector3(-21, 0, 21), Vector3(24, 0, 14), Vector3(26, 0, -14), Vector3(-25, 0, -18)]:
		var copac := _pune(COPACI_PLATOU[_r.randi() % COPACI_PLATOU.size()], p, _r.randf_range(0, TAU))
		copac.scale = Vector3.ONE * _r.randf_range(1.1, 1.5)
		var forma := CollisionShape3D.new()
		var trunchi := CylinderShape3D.new()
		trunchi.radius = raza_trunchi * copac.scale.x
		trunchi.height = 4.0
		forma.shape = trunchi
		forma.position = p + Vector3.UP * 2.0
		_corp.add_child(forma)


func _padurea() -> void:
	var pas := distanta_copaci
	var n := int(padure_pana_la / pas)
	for j in range(-n, n + 1):
		for i in range(-n, n + 1):
			if _r.randf() > densitate:
				continue
			var x := i * pas + _r.randf_range(-pas * 0.45, pas * 0.45)
			var z := j * pas + _r.randf_range(-pas * 0.45, pas * 0.45)
			var r := Vector2(x, z).length()
			if r < padure_de_la or r > padure_pana_la:
				continue
			if deal and deal.distanta_poteca(x, z) < deal.latime_poteca + 1.5:
				continue
			# mai rari chiar sub gard, ca să se vadă coasta
			if r < padure_de_la + 6.0 and _r.randf() < 0.5:
				continue
			var h := deal.inaltime(x, z) if deal else 0.0
			var scena: PackedScene = COPACI_COASTA[_r.randi() % COPACI_COASTA.size()]
			var marime := _r.randf_range(0.85, 1.45)
			var t := Transform3D(Basis(Vector3.UP, _r.randf_range(0, TAU)).scaled(Vector3.ONE * marime), Vector3(x, h - 0.15, z))
			if not _instante.has(scena):
				_instante[scena] = []
			_instante[scena].append(t)


func _construieste_multimesh() -> void:
	for scena in _instante:
		var lista: Array = _instante[scena]
		var model := (scena as PackedScene).instantiate()
		for nod in model.find_children("*", "MeshInstance3D", true, false):
			var mi := nod as MeshInstance3D
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mi.mesh
			mm.instance_count = lista.size()
			for i in lista.size():
				mm.set_instance_transform(i, lista[i] * _transform_in_model(mi, model))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = MATERIAL
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
		model.free()


func _transform_in_model(nod: Node3D, radacina: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = nod
	while n != radacina and n is Node3D:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
