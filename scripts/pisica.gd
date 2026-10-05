extends Interactabil
## Pisica neagră din dormitorul conacului (scenes/pisica.tscn; modelul pisica.glb din tools/blender/conac_interior.py).
## Stă pe covor: dă încet din coadă, clipește, își întoarce capul după tine când ești aproape.
## La E o mângâi: se întoarce spre tine, privirea ta coboară spre ea, mâna ta (mana_jucator.glb, ca la Fireball, cu
## palma în jos) o mângâie de `mangaieri` ori pe creștet și pe ceafă, ea își ridică fruntea în palmă, închide ochii și
## toarce (`sunete/pisica_tors.ogg`); torsul se stinge la `tors_dupa` secunde după ce iei mâna.

const MANA := preload("res://models/mana_jucator.glb")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")
const TORS := preload("res://sunete/pisica_tors.ogg")
## Drumul palmei la o mângâiere (față de pisică: privește spre +Z), de pe frunte, peste creștet, până pe ceafă.
const DRUM := [Vector3(0.0, 0.445, 0.1), Vector3(0.0, 0.442, 0.02), Vector3(0.0, 0.41, -0.05)]

@export var mangaieri := 3
## Cât ține o mângâiere (de pe frunte până pe ceafă).
@export var durata_mangaiere := 0.7
## Cât mai toarce după ce iei mâna.
@export var tors_dupa := 4.0
## De la ce distanță se uită după tine.
@export var distanta_privire := 4.5
## Cât de aproape vii de ea ca s-o mângâi și cât cobori capul (te lași pe vine).
@export var aproape := 0.62
@export var pe_vine := 0.75

@onready var _model: Node3D = $Model
@onready var _cap: Node3D = $Model/Cap
@onready var _ochi: Node3D = $Model/Cap/Ochi
@onready var _coada: Node3D = $Model/Coada

var _timp := 0.0
var _placere := 0.0  # 0 = stă, 1 = toarce cu ochii închiși
var _ocupata := false
var _pana_la_clipit := 3.0
var _clipit := 0.0
var _mangaiere := 0  # numărul mângâierii de acum (o mângâiere nouă oprește stingerea torsului de la cea veche)
var _tors: AudioStreamPlayer3D
var _mana: Node3D  # mâna ta, cât o mângâi
var _umar := Vector3.ZERO  # de unde vine brațul (global)
var _indoire := 0.0  # 0 = degetele înainte, 1 = îndoite în jos pe ceafă


func _ready() -> void:
	if indiciu == "[E] Examine":
		indiciu = "[E] Pet the cat"
	_tors = AudioStreamPlayer3D.new()
	_tors.stream = TORS
	_tors.bus = &"Efecte"
	_tors.unit_size = 1.0
	_tors.max_distance = 6.0
	_tors.volume_db = -60.0
	_tors.position = Vector3(0, 0.3, 0.05)
	add_child(_tors)
	_timp = randf() * 10.0


func _process(delta: float) -> void:
	_timp += delta
	# coada: un leagăn lent, cu vârful care se ridică puțin; cât toarce, mai lent
	var v := lerpf(1.0, 0.45, _placere)
	_coada.rotation = Vector3(-0.03 - 0.04 * (0.5 + 0.5 * sin(_timp * v * 2.3)), sin(_timp * v) * 0.08, 0.0)
	# capul: după tine, cât ești aproape (dar nu la spate); cât o mângâi, cu fruntea sus în palma ta, frecându-se
	var spre_y := 0.0
	var spre_x := 0.0
	var frecat := 0.0
	if _ocupata:
		spre_x = -0.45 * _placere
		frecat = sin(_timp * 3.5) * 0.14 * _placere
	else:
		var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
		if jucator:
			var d := _model.to_local(jucator.global_position + Vector3.UP * 1.55) - _cap.position
			var orizontal := Vector2(d.x, d.z).length()
			if d.length() < distanta_privire and d.z > -0.2 * orizontal:
				spre_y = clampf(atan2(d.x, d.z), -1.1, 1.1)
				spre_x = clampf(-atan2(d.y, orizontal), -0.7, 0.25)
	var k := 1.0 - exp(-delta * 4.0)
	_cap.rotation.y = lerp_angle(_cap.rotation.y, spre_y, k)
	_cap.rotation.x = lerpf(_cap.rotation.x, spre_x, k)
	_cap.rotation.z = lerpf(_cap.rotation.z, frecat, k)
	# ochii: clipește rar; cât toarce, îi ține strânși
	_pana_la_clipit -= delta
	if _pana_la_clipit <= 0.0:
		_clipit = 0.14
		_pana_la_clipit = randf_range(2.5, 6.5)
	_clipit -= delta
	var deschisi := 0.08 if _clipit > 0.0 else 1.0 - 0.88 * _placere
	_ochi.scale.y = lerpf(_ochi.scale.y, deschisi, 1.0 - exp(-delta * 20.0))
	if _mana:
		_mana.global_basis = _orientare_mana(_mana.global_position, _indoire)


func interactioneaza() -> void:
	if _ocupata or not poate_fi_folosit():
		return
	_mangaie()


func _mangaie() -> void:
	_ocupata = true
	_mangaiere += 1
	var a_mea := _mangaiere
	Stare.meniu_deschis = true  # nu te miști, ce ții în mână coboară
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	var cap_j: Node3D = jucator.get_node("Cap")
	var camera: Camera3D = cap_j.get_node("Camera3D")
	# se întoarce spre tine; tu te apropii la `aproape` m de ea, te lași pe vine (capul coboară cu `pe_vine` m) și te
	# uiți la ea: de sus, de la 1,5 m, n-ai vedea decât o pată neagră și mâneca
	var spre := jucator.global_position - global_position
	spre.y = 0.0
	var loc_nou := global_position + spre.normalized() * minf(aproape, spre.length())
	loc_nou.y = jucator.global_position.y
	var cap_y := cap_j.position.y
	var ochi := loc_nou + Vector3.UP * (cap_y - pe_vine)
	var d := global_position + Vector3.UP * 0.34 - ochi
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "rotation:y", rotation.y + angle_difference(rotation.y, atan2(spre.x, spre.z)), 0.45)
	t.tween_property(jucator, "global_position", loc_nou, 0.6)
	t.tween_property(cap_j, "position:y", cap_y - pe_vine, 0.6)
	t.tween_property(jucator, "rotation:y", jucator.rotation.y + angle_difference(jucator.rotation.y, atan2(-d.x, -d.z)), 0.6)
	t.tween_property(cap_j, "rotation:x", clampf(atan2(d.y, Vector2(d.x, d.z).length()), deg_to_rad(-85), deg_to_rad(85)), 0.6)
	await t.finished
	# mâna: brațul vine din colțul din dreapta-jos (umărul tău e sub cameră, în dreapta), ca la Fireball; dacă ar
	# veni drept dinspre cameră, mâneca neagră ar acoperi jumătate din ecran
	_umar = camera.global_position + camera.global_basis.x * 0.24 + Vector3.DOWN * 0.34 + camera.global_basis.z * 0.05
	var mana := MANA.instantiate() as Node3D
	mana.set_script(SCRIPT_MODEL)
	mana.set("material", MATERIAL)
	mana.set("stralucitoare", PackedStringArray(["Mana"]))
	mana.set("stralucire", 0.08)
	mana.set("umbre", false)  # lanterna e lângă braț: umbra lui ar acoperi tot ecranul
	add_child(mana)
	_mana = mana
	_indoire = 0.0
	var de_la := to_local(_umar.lerp(to_global(DRUM[0]), 0.25))
	mana.position = de_la
	mana.global_basis = _orientare_mana(mana.global_position, 0.0)
	var ti := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	ti.tween_property(mana, "position", DRUM[0], 0.45)
	await ti.finished
	_tors.play()
	var tp := create_tween().set_parallel()
	tp.tween_property(self, "_placere", 1.0, 1.0)
	tp.tween_property(_tors, "volume_db", -6.0, 0.8)
	for i in mangaieri:
		var tm := create_tween()
		tm.tween_method(_pe_drum, 0.0, 1.0, durata_mangaiere).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# ridici palma și o duci înapoi pe frunte, pe sus
		tm.tween_property(mana, "position", DRUM[0] + Vector3(0, 0.07, -0.03), 0.18).set_trans(Tween.TRANS_SINE)
		tm.parallel().tween_property(self, "_indoire", 0.0, 0.18)
		tm.tween_property(mana, "position", DRUM[0], 0.14).set_trans(Tween.TRANS_SINE)
		await tm.finished
	var tf := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tf.tween_property(mana, "position", de_la, 0.4)
	await tf.finished
	_mana = null
	mana.queue_free()
	# te ridici
	var tr := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tr.tween_property(cap_j, "position:y", cap_y, 0.5)
	await tr.finished
	Stare.meniu_deschis = false
	_ocupata = false
	# mai toarce puțin, apoi se oprește (dacă nu o mângâi din nou între timp)
	await get_tree().create_timer(tors_dupa).timeout
	if a_mea != _mangaiere or _ocupata:
		return
	var ts := create_tween().set_parallel()
	ts.tween_property(self, "_placere", 0.0, 2.0)
	ts.tween_property(_tors, "volume_db", -60.0, 2.0)
	await ts.finished
	if a_mea == _mangaiere and not _ocupata:
		_tors.stop()


## Palma la fracția `f` (0..1) din DRUM; spre ceafă degetele se îndoaie în jos, după cum curge blana.
func _pe_drum(f: float) -> void:
	var n := DRUM.size() - 1
	var i := mini(int(f * n), n - 1)
	_mana.position = (DRUM[i] as Vector3).lerp(DRUM[i + 1], f * n - i)
	_indoire = ease(f, 1.6)


## Cum e întoarsă mâna (dreaptă, palma pe blană) ca antebrațul să meargă spre `_umar`. În model, antebrațul nu e
## chiar în prelungirea degetelor: urcă ~24° spre dosul palmei, așa că direcția degetelor se coboară cu atât.
func _orientare_mana(palma_poz: Vector3, indoire: float) -> Basis:
	var antebrat := (_umar - palma_poz).normalized()
	var jos := (Vector3.DOWN - antebrat * antebrat.dot(Vector3.DOWN)).normalized()
	var degete := -(antebrat * cos(0.41) + jos * sin(0.41))
	degete = (degete + Vector3.DOWN * 0.3 * indoire).normalized()  # fără încheietură: mai mult ar ridica tot antebrațul
	var palma := (Vector3.DOWN - degete * degete.dot(Vector3.DOWN)).normalized()
	return VrajaFoc.orientare(degete, palma)
