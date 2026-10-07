extends Node3D
## Sperietura de pe poteca spre vale (spre vrăjitoare): când te apropii de una din păpușile de paie din partea de jos
## (de la `raza_vedere` m, dacă o ai în fața ochilor, ca s-o vezi cum cade și când alergi; altfel la `raza`),
## pădurea tace o clipă, sfoara scârțâie și se rupe, păpușa cade pe potecă (bubuitura + „sting”-ul, camera
## tresare), iar prin fața ta creatura trece în goană prin pădure, dintr-o parte în alta, cu un țipăt. După ea îți
## bate inima. O singură dată (`marcaj`); la Continue păpușa e deja pe jos.
## Sunetele sunt făcute în tools/sunete.sh (secțiunea „pădurea, poteca spre vale”).

@export var semne: Node
@export var teren: TerenPadure
@export var creatura: PackedScene
## Care păpușă se rupe (`SemneVale.papusa_atarnata(index)`, în ordinea din SEMNE): 2 = cea de la 0,71 din poteca spre vale.
@export var papusa := 2
## De la ce distanță (pe orizontală) se rupe, dacă păpușa e în fața ta: din timp, ca s-o vezi cum cade
## și dacă alergi (cu 4,5 m/s, până bufnește pe jos mai ai ~5 m până la ea).
@export var raza_vedere := 9.0
## Cât de departe de mijlocul privirii poate fi păpușa (grade, pe orizontală) ca să zică „e în fața ta”.
@export var unghi_vedere := 30.0
## Dacă ajungi atât de aproape fără s-o fi privit (ai venit cu spatele), se rupe oricum.
@export var raza := 2.6
@export var marcaj := "papusa_a_cazut"
## Pe unde trece creatura: la câți metri în fața ta, cât de lung e drumul ei și cât de repede aleargă.
@export var distanta_fata := 6.0
@export var lungime_goana := 28.0
@export var viteza_creatura := 13.0

@export_group("Sunete")
@export var sunet_sfoara: AudioStream
@export var sunet_cade: AudioStream
@export var sunet_sting: AudioStream
@export var sunet_goana: AudioStream
@export var sunet_tipat: AudioStream
@export var sunet_crengi: AudioStream
@export var sunet_inima: AudioStream

## În papusa_sfoara.ogg sfoara pocnește la 0,29 s: atunci începe să cadă păpușa.
const RUPERE := 0.29
## Cât coboară lumea (canalele Ambianta și Muzica) cât ține sperietura (dB).
const LINISTE := -24.0
## Păpușa (din papusa.glb): de la nod până la mijlocul ei și cât e de lungă pe jumătate.
const MIJLOC := 1.5
const JUMATATE := 0.31

var _papusa: Node3D
var _pivot: Node3D
var _activa := false
var _duck: Array = []


func _ready() -> void:
	_papusa = semne.papusa_atarnata(papusa)
	if _papusa == null:
		set_process(false)
		return
	if Stare.e_marcat(marcaj):
		var p := _desprinde()
		_pivot.global_position = Vector3(p.x + 0.3, teren.inaltime(p.x + 0.3, p.z) + 0.12, p.z)
		_pivot.rotation = Vector3(PI / 2.0, randf() * TAU, 0.0)
		set_process(false)


func _process(_delta: float) -> void:
	if _activa:
		return
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	if jucator == null or Stare.meniu_deschis:
		return
	var d := Vector2(jucator.global_position.x - _papusa.global_position.x, jucator.global_position.z - _papusa.global_position.z)
	if d.length() < raza or (d.length() < raza_vedere and _in_fata(d)):
		_activa = true
		_sperie(jucator)


## d = de la păpușă la jucător (pe orizontală). Adevărat dacă privirea (camera) e îndreptată spre păpușă.
func _in_fata(d: Vector2) -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var privire := Vector2(-camera.global_basis.z.x, -camera.global_basis.z.z)
	if privire.length() < 0.01:
		return false
	return absf(rad_to_deg(privire.angle_to(-d))) < unghi_vedere


func _sperie(jucator: Node3D) -> void:
	Stare.marcheaza(marcaj)
	# 1. pădurea tace, sfoara scârțâie și se rupe
	_coboara_lumea(true, 0.3)
	var nod := _papusa.global_position
	Sunet.reda_la(sunet_sfoara, nod + Vector3.DOWN * 0.6)
	await get_tree().create_timer(RUPERE).timeout
	# 2. cade (cu o răsucire), bufnește în frunze: lovitura
	_desprinde()
	var viteza := 0.0
	var rotire := Vector3(randf_range(-2.0, 2.0), randf_range(-3.0, 3.0), randf_range(-2.0, 2.0))
	var jos := teren.inaltime(nod.x, nod.z)
	while _pivot.global_position.y - JUMATATE > jos:
		var dt := get_process_delta_time()
		await get_tree().process_frame
		viteza += 9.8 * dt
		_pivot.global_position.y -= viteza * dt
		_pivot.rotation += rotire * dt
	_pivot.global_position.y = jos + JUMATATE
	Sunet.reda_la(sunet_cade, _pivot.global_position)
	Sunet.reda(sunet_sting)
	var camera := get_viewport().get_camera_3d()
	if camera:
		var t := create_tween()
		t.tween_property(camera, "rotation:x", -0.06, 0.05)
		t.tween_property(camera, "rotation:x", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	# se prăvălește pe o parte, cu un mic salt
	var culcat := create_tween().set_parallel()
	culcat.tween_property(_pivot, "rotation", Vector3(PI / 2.0 * signf(randf() - 0.5), _pivot.rotation.y, 0.0), 0.35) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	culcat.tween_property(_pivot, "global_position:y", jos + 0.12, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	# 3. prin fața ta, creatura trece în goană prin pădure
	await get_tree().create_timer(0.35).timeout
	Sunet.reda(sunet_inima, -4.0)
	await _goana(jucator)
	# 4. lumea revine încet
	await _coboara_lumea(false, 6.0)
	set_process(false)


## Desprinde păpușa de sfoară (sfoara rămâne în cracă) și o pune într-un pivot la mijlocul ei; întoarce nodul sforii.
func _desprinde() -> Vector3:
	var corp := _papusa.get_node_or_null("Papusa") as Node3D
	var nod := _papusa.global_position
	_pivot = Node3D.new()
	add_child(_pivot)
	_pivot.global_position = nod + Vector3.DOWN * MIJLOC
	if corp:
		var t := corp.global_transform
		corp.get_parent().remove_child(corp)
		_pivot.add_child(corp)
		corp.global_transform = t
	return nod


func _goana(jucator: Node3D) -> void:
	var camera := get_viewport().get_camera_3d()
	var inainte := -(camera.global_basis.z if camera else jucator.global_basis.z)
	inainte.y = 0.0
	inainte = inainte.normalized()
	var dreapta := inainte.cross(Vector3.UP).normalized() * (1.0 if randf() < 0.5 else -1.0)
	var centru := jucator.global_position + inainte * distanta_fata
	var start := centru - dreapta * lungime_goana * 0.5
	var c := creatura.instantiate() as Node3D
	add_child(c)
	c.set("pasi_pe_secunda", 8.0)
	c.set("alearga", true)
	c.global_position = _pe_teren(start)
	c.look_at(c.global_position - dreapta, Vector3.UP)  # modelul privește spre +Z
	var goana := AudioStreamPlayer3D.new()
	goana.stream = sunet_goana
	goana.unit_size = 8.0
	goana.max_distance = 60.0
	goana.bus = &"Efecte"
	c.add_child(goana)
	goana.play()
	Sunet.reda_la(sunet_crengi, c.global_position + Vector3.UP)
	var parcurs := 0.0
	var a_tipat := false
	while parcurs < lungime_goana:
		await get_tree().process_frame
		parcurs += viteza_creatura * get_process_delta_time()
		c.global_position = _pe_teren(start + dreapta * parcurs)
		if not a_tipat and parcurs > lungime_goana * 0.45:
			a_tipat = true
			var tipat := AudioStreamPlayer3D.new()
			tipat.stream = sunet_tipat
			tipat.unit_size = 8.0
			tipat.max_distance = 60.0
			tipat.bus = &"Efecte"
			c.add_child(tipat)
			tipat.play()
	Sunet.reda_la(sunet_crengi, c.global_position + Vector3.UP)
	c.set("alearga", false)
	c.visible = false
	# sunetele de pe ea se mai aud o clipă
	get_tree().create_timer(2.0).timeout.connect(c.queue_free)


func _pe_teren(p: Vector3) -> Vector3:
	return Vector3(p.x, teren.inaltime(p.x, p.z), p.z)


## Coboară (sau ridică la loc) canalele Ambianta și Muzica, ca în cazan.gd: un AudioEffectAmplify pus pe canal.
func _coboara_lumea(jos: bool, durata: float) -> void:
	if jos and _duck.is_empty():
		for nume: StringName in [&"Ambianta", &"Muzica"]:
			var i := AudioServer.get_bus_index(nume)
			if i >= 0:
				var a := AudioEffectAmplify.new()
				AudioServer.add_bus_effect(i, a)
				_duck.append([i, a])
	var t := create_tween()
	t.tween_method(func(db: float) -> void:
		for x in _duck:
			(x[1] as AudioEffectAmplify).volume_db = db, 0.0 if jos else LINISTE, LINISTE if jos else 0.0, durata)
	await t.finished
	if not jos:
		_scoate_duck()


func _scoate_duck() -> void:
	for x in _duck:
		var i: int = x[0]
		for k in range(AudioServer.get_bus_effect_count(i) - 1, -1, -1):
			if AudioServer.get_bus_effect(i, k) == x[1]:
				AudioServer.remove_bus_effect(i, k)
	_duck.clear()


func _exit_tree() -> void:
	_scoate_duck()
