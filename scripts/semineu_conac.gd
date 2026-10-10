extends ChemareDemon
## Șemineul din sala conacului (scenes/conac_interior.tscn, nodul `SemineuDemon`: cutia din fața gurii șemineului).
## Cu pisica moartă în inventar (owner, 11.10: „s-o poți arunca și în fireplace la Manor și să se summoneze demonul
## acolo cu aceeași interacțiune”), „[E] Throw the cat in the fire” pornește scena (cu benzi negre, vezi Cutscena):
##   1. treci pe lângă măsuță până în fața focului și arunci pisica în flăcări; ea se înroșește și se topește în foc;
##   2. focul se face roșu ca sângele și crește, vuiește, scântei, camera tremură tot mai tare; tu te dai înapoi, în
##      mijlocul sălii (`loc_jucator`), cu ochii pe el;
##   3. flăcările țâșnesc din șemineu în sală: bubuitură, fulger, scântei, fum, toate luminile sălii se fac mici, îți
##      țiuie urechile; în vatră rămâne focul roșu;
##   4. pe covorul mare, pe pentagramă (`centru_chemare`), se aprinde un cerc de flăcări roșii, un inel de fum și un
##      stâlp de lumină, iar **demonul** urcă prin podea, se uită la tine și răcnește;
##   5. aceeași replică și același final ca acasă (ChemareDemon._vorbeste_cu_demonul): cu pistol îl împuști, fără el
##      se teleportează.
## Apoi focul revine la culoarea lui și luminile sălii se aprind la loc. Marcajul `marcaj_demon` (al lui, nu cel de
## acasă) = „dezintegrat” / „teleportat”. Pisica e una singură: ori în ceaunul de acasă, ori aici.

## Focul din vatră (unde cade pisica) și locul chemării (centrul pentagramei de pe covorul mare), în coordonatele scenei.
@export var foc := Vector3(0.0, 0.35, -13.45)
@export var centru_chemare := Vector3(0.0, 0.0, -5.6)
@export var raza_pentagrama := 1.5
## Unde stai cât crește focul și de unde vezi demonul (între masa din fața șemineului și covorul mare).
@export var loc_jucator := Vector3(0.0, 0.0, -9.3)
## Cât crește focul până țâșnește (secunde; sunetul `ceaun_incins` e cam atât de lung).
@export var durata_crestere := 3.6
@export var culoare_foc := Color(1.0, 0.12, 0.06)
@export var lumina_semineu: OmniLight3D
@export var sunet_foc: AudioStreamPlayer3D
## Luminile sălii (le ia pe toate de sub nodul ăsta, de la parter): se fac mici la bubuitură, revin la sfârșit.
@export var lumini: Node3D

const SUNET_INCINS := preload("res://sunete/ceaun_incins.ogg")
const SUNET_EXPLOZIE := preload("res://sunete/ceaun_explozie.ogg")
const SUNET_FOC := preload("res://sunete/minge_foc_aprinsa.ogg")

var _in_curs := false
var _culoare_initiala := Color.WHITE
var _energie_initiala := 1.0
var _flacari: CPUParticles3D  # focul roșu din vatră, cât ține scena


func _ready() -> void:
	indiciu = "[E] Throw the cat in the fire"
	if lumina_semineu:
		_culoare_initiala = lumina_semineu.light_color
		_energie_initiala = lumina_semineu.get("energie") if lumina_semineu.get("energie") != null else lumina_semineu.light_energy


func poate_fi_folosit() -> bool:
	return activ and not _in_curs and Stare.valoare_marcaj(marcaj_demon) == null and Stare.are_obiect(ID_PISICA)


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	Stare.scoate_obiect(ID_PISICA)
	var c := Cutscena.porneste(self)
	_jucator = get_tree().get_first_node_in_group("jucator") as CharacterBody3D
	_camera = _jucator.get_node("Cap/Camera3D")
	_jucator.seteaza_purtat(true)
	# pe lângă măsuță (în partea în care ești), până în fața focului
	var parte := signf(_jucator.global_position.x - foc.x)
	if parte == 0.0:
		parte = 1.0
	var loc := Vector3(foc.x + parte * 0.95, _jucator.global_position.y, foc.z + 1.35)
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(_jucator, "global_position", loc, 0.7)
	await c.priveste(foc + Vector3.UP * 0.1, 0.7)

	# 1. arunci pisica în foc
	await _pisica_in_foc()
	await get_tree().create_timer(0.4).timeout

	# 2. focul se face roșu și crește
	await _creste_focul(c)

	# 3. țâșnește în sală
	_tasneste()
	await get_tree().create_timer(2.6).timeout

	# 4. demonul, pe pentagrama de pe covorul mare
	var demon := await _cheama_demonul(c)
	await get_tree().create_timer(0.5).timeout

	# 5. ce-i spune și ce-i răspunzi
	await _vorbeste_cu_demonul(c, demon)

	await _stinge_chemarea()
	_jucator.seteaza_purtat(false)
	_in_curs = false
	await c.opreste()


## Pisica zboară în vatră, se înroșește ca jarul și se topește în flăcări (pe pixeli); focul pufăie scântei.
func _pisica_in_foc() -> void:
	var pisica := await _arunca_pisica(foc + Vector3.UP * 0.12, 0.5, 0.65)
	Sunet.reda_la(SUNET_FOC, foc, Sunet.VOLUM_EFECTE, 0.05, 0.85)
	var scantei := _particule(40, 1.1, 0.03, PackedColorArray([Color(1.0, 0.85, 0.5), Color(1.0, 0.45, 0.15), Color(1.0, 0.3, 0.1, 0.0)]), true, true)
	scantei.direction = Vector3.UP
	scantei.spread = 35.0
	scantei.initial_velocity_min = 1.5
	scantei.initial_velocity_max = 3.5
	scantei.gravity = Vector3(0, -2.0, 0)
	_unic(scantei, foc)
	var incinge := func(v: float) -> void:
		for mesh in pisica.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).set_instance_shader_parameter("incins", Color(culoare_foc, v))
	var topeste := func(v: float) -> void: ModelPS2.disparitie(pisica, v)
	var t := create_tween().set_parallel()
	t.tween_property(pisica, "global_position", foc + Vector3.DOWN * 0.1, 1.2).set_trans(Tween.TRANS_SINE)
	t.tween_method(incinge, 0.0, 1.0, 0.8)
	t.tween_method(topeste, 0.0, 1.0, 1.4).set_delay(0.5)
	t.chain().tween_callback(pisica.queue_free)


## Focul se înroșește și crește, vuiește, aruncă scântei; camera tremură tot mai tare. Tu te dai înapoi, cu ochii pe el.
func _creste_focul(c: Cutscena) -> void:
	Sunet.reda_la(SUNET_INCINS, foc, Sunet.VOLUM_EFECTE, 0.0)
	_flacari = _particule(70, 0.9, 0.28, PackedColorArray([Color(1.0, 0.75, 0.4, 0.0), Color(1.0, 0.35, 0.1, 0.9),
		Color(culoare_foc, 0.7), Color(0.25, 0.05, 0.04, 0.0)]), true, true)
	_flacari.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_flacari.emission_box_extents = Vector3(0.6, 0.05, 0.2)
	_flacari.direction = Vector3.UP
	_flacari.spread = 12.0
	_flacari.initial_velocity_min = 0.6
	_flacari.initial_velocity_max = 1.2
	_flacari.gravity = Vector3(0, 1.0, 0)
	_flacari.preprocess = _flacari.lifetime  # pornește plin: altfel particulele care n-au pornit fac un pătrat negru
	var mat := (_flacari.mesh as QuadMesh).material as StandardMaterial3D
	mat.albedo_color.a = 0.0
	get_tree().current_scene.add_child(_flacari)
	_flacari.global_position = foc
	_flacari.emitting = true
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	t.tween_property(mat, "albedo_color:a", 1.0, durata_crestere * 0.4)
	t.tween_property(_flacari, "speed_scale", 2.2, durata_crestere)
	t.tween_property(_flacari, "scale_amount_max", 1.8, durata_crestere)
	if lumina_semineu:
		t.tween_property(lumina_semineu, "light_color", culoare_foc, durata_crestere * 0.5)
		_seteaza_energie(t, _energie_initiala * 2.6, durata_crestere)
	if sunet_foc:
		t.tween_property(sunet_foc, "pitch_scale", 1.5, durata_crestere)
		t.tween_property(sunet_foc, "volume_db", sunet_foc.volume_db + 10.0, durata_crestere)
	# tremurul tot mai tare
	var tremura := func(v: float) -> void:
		_camera.h_offset = randf_range(-1.0, 1.0) * 0.012 * v
		_camera.v_offset = randf_range(-1.0, 1.0) * 0.012 * v
	t.tween_method(tremura, 0.0, 1.0, durata_crestere).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	# după o clipă te dai înapoi, cu ochii pe foc
	await get_tree().create_timer(durata_crestere * 0.25).timeout
	var loc := Vector3(loc_jucator.x, _jucator.global_position.y, loc_jucator.z)
	create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT).tween_property(_jucator, "global_position", loc, 1.6)
	var pana := Time.get_ticks_msec() + int(durata_crestere * 750.0)
	while Time.get_ticks_msec() < pana:
		await c.priveste(foc + Vector3.UP * 0.4, 0.1)
	if t.is_running():  # await pe un tween terminat așteaptă la nesfârșit
		await t.finished
	_camera.h_offset = 0.0
	_camera.v_offset = 0.0


## Bubuitura: flăcările țâșnesc din șemineu în sală, fulger, scântei, fum; luminile sălii se fac mici.
func _tasneste() -> void:
	var gura := foc + Vector3(0.0, 0.4, 0.5)
	Sunet.reda(SUNET_EXPLOZIE, Sunet.VOLUM_EFECTE)  # stereo, cu ecoul sălii: 2D
	if lumina_semineu:
		lumina_semineu.set("energie", _energie_initiala * 7.0)
		lumina_semineu.light_energy = _energie_initiala * 7.0
		var t := create_tween()
		_seteaza_energie(t, _energie_initiala * 1.6, 1.4)
	var spre_sala := Vector3.BACK  # +Z: din șemineu spre sală
	var flacari := _particule(80, 0.8, 0.45, PackedColorArray([Color(1.0, 0.9, 0.6, 0.95), Color(1.0, 0.4, 0.15, 0.85),
		Color(culoare_foc, 0.5), Color(0.2, 0.15, 0.15, 0.0)]), true, true)
	flacari.direction = spre_sala + Vector3.UP * 0.25
	flacari.spread = 35.0
	flacari.initial_velocity_min = 4.0
	flacari.initial_velocity_max = 8.0
	flacari.damping_min = 5.0
	flacari.damping_max = 7.0
	flacari.gravity = Vector3(0, 2.0, 0)
	_unic(flacari, gura)
	var scantei := _particule(70, 1.4, 0.035, PackedColorArray([Color(1.0, 0.85, 0.5), Color(1.0, 0.3, 0.1), Color(1.0, 0.3, 0.1, 0.0)]), true, true)
	scantei.direction = spre_sala
	scantei.spread = 60.0
	scantei.initial_velocity_min = 4.0
	scantei.initial_velocity_max = 10.0
	scantei.gravity = Vector3(0, -6.0, 0)
	_unic(scantei, gura)
	var fum := _particule(50, 4.0, 0.6, PackedColorArray([Color(0.2, 0.18, 0.18, 0.0), Color(0.2, 0.17, 0.17, 0.4),
		Color(0.15, 0.14, 0.14, 0.2), Color(0.12, 0.12, 0.12, 0.0)]), false, true)
	fum.direction = spre_sala + Vector3.UP * 0.5
	fum.spread = 40.0
	fum.initial_velocity_min = 1.0
	fum.initial_velocity_max = 3.0
	fum.damping_min = 0.8
	fum.damping_max = 1.4
	fum.gravity = Vector3(0, 0.25, 0)
	_unic(fum, gura)
	if _flacari:
		_flacari.speed_scale = 1.0
		_flacari.scale_amount_max = 1.0
	if sunet_foc:
		create_tween().tween_property(sunet_foc, "pitch_scale", 1.15, 1.5)
	_lumini_sala(0.15, 0.25)
	_zguduie(1.0, 1.2)
	_asurzeste(3.5)


## Pentagrama de pe covorul mare se aprinde: cercul de flăcări roșii, inelul de fum, lumina, stâlpul; demonul urcă.
func _cheama_demonul(c: Cutscena) -> Demon:
	c.priveste(centru_chemare + Vector3.UP * 0.2, 1.4)
	Sunet.reda(SUNET_CHEMARE, Sunet.VOLUM_EFECTE)
	var lumina := OmniLight3D.new()
	lumina.name = "LuminaChemare"
	lumina.light_color = culoare_foc
	lumina.light_energy = 0.0
	lumina.omni_range = 7.0
	lumina.shadow_enabled = true
	get_parent().add_child(lumina)
	lumina.global_position = centru_chemare + Vector3.UP * 0.4
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(lumina, "light_energy", 3.0, 2.0)
	# cercul de flăcări de pe marginea pentagramei, apoi inelul de fum
	for i in 2:
		var cerc := _particule(90 if i == 0 else 50, 0.8 if i == 0 else 2.4, 0.16 if i == 0 else 0.3,
			PackedColorArray([Color(1.0, 0.7, 0.4, 0.0), Color(culoare_foc, 0.9), Color(0.3, 0.05, 0.04, 0.0)]) if i == 0 else
			PackedColorArray([Color(0.3, 0.06, 0.05, 0.0), Color(0.3, 0.07, 0.06, 0.55), Color(0.15, 0.08, 0.09, 0.0)]), i == 0, true)
		cerc.name = "CercFoc" if i == 0 else "InelFum"
		cerc.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		cerc.emission_ring_axis = Vector3.UP
		cerc.emission_ring_radius = raza_pentagrama
		cerc.emission_ring_inner_radius = raza_pentagrama - 0.1
		cerc.emission_ring_height = 0.02
		cerc.direction = Vector3.UP
		cerc.spread = 10.0
		cerc.initial_velocity_min = 0.3 if i == 0 else 0.2
		cerc.initial_velocity_max = 0.8 if i == 0 else 0.5
		cerc.gravity = Vector3(0, 1.2 if i == 0 else 0.2, 0)
		cerc.preprocess = cerc.lifetime
		var mat := (cerc.mesh as QuadMesh).material as StandardMaterial3D
		mat.albedo_color.a = 0.0
		get_parent().add_child(cerc)
		cerc.global_position = centru_chemare + Vector3.UP * 0.05
		cerc.emitting = true
		create_tween().tween_property(mat, "albedo_color:a", 1.0, 1.2)
		Sunet.reda_la(SUNET_LUMANARE, centru_chemare, Sunet.VOLUM_EFECTE - 4.0, 0.1, 0.7)
		await get_tree().create_timer(1.0).timeout
	# stâlpul de lumină până sub candelabru
	var raza := _stalp_lumina(culoare_foc, 5.0, raza_pentagrama * 0.95)
	get_parent().add_child(raza)
	raza.global_position = centru_chemare + Vector3.UP * 2.52
	var mat_raza: ShaderMaterial = raza.material_override
	var t := create_tween()
	t.tween_method(func(v: float) -> void: mat_raza.set_shader_parameter("putere", v), 0.0, 1.0, 0.25)
	t.tween_method(func(v: float) -> void: mat_raza.set_shader_parameter("putere", v), 1.0, 0.0, 3.0)
	t.tween_callback(raza.queue_free)
	return await _ridica_demonul(c, centru_chemare, get_parent())


## După demon: cercul și fumul se sting, focul revine la culoarea lui, luminile sălii se aprind la loc.
func _stinge_chemarea() -> void:
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	for nume in ["CercFoc", "InelFum"]:
		var p := get_parent().get_node_or_null(nume) as CPUParticles3D
		if p:
			p.emitting = false
			get_tree().create_timer(3.0).timeout.connect(p.queue_free)
	var lumina := get_parent().get_node_or_null("LuminaChemare") as OmniLight3D
	if lumina:
		t.tween_property(lumina, "light_energy", 0.0, 2.5)
		t.chain().tween_callback(lumina.queue_free)
	if _flacari:
		_flacari.emitting = false
		get_tree().create_timer(2.0).timeout.connect(_flacari.queue_free)
	if lumina_semineu:
		t.tween_property(lumina_semineu, "light_color", _culoare_initiala, 3.0)
		_seteaza_energie(t, _energie_initiala, 3.0)
	if sunet_foc:
		t.tween_property(sunet_foc, "pitch_scale", 1.0, 3.0)
		t.tween_property(sunet_foc, "volume_db", sunet_foc.volume_db - 10.0, 3.0)
	_lumini_sala(1.0, 2.5)
	await get_tree().create_timer(2.5).timeout


## Energia luminii din șemineu (cu flacara.gd pâlpâie din `energie`; altfel direct `light_energy`).
func _seteaza_energie(t: Tween, cat: float, durata: float) -> void:
	if lumina_semineu.get("energie") != null:
		t.tween_property(lumina_semineu, "energie", cat, durata)
	else:
		t.tween_property(lumina_semineu, "light_energy", cat, durata)


## Luminile sălii (parterul, fără șemineu) la `cat` din energia lor obișnuită, în `durata` secunde.
func _lumini_sala(cat: float, durata: float) -> void:
	if lumini == null:
		return
	var t := create_tween().set_parallel()
	for l in lumini.get_children():
		if not l is OmniLight3D or l == lumina_semineu or (l as Node3D).global_position.y > 3.4:
			continue
		if not l.has_meta("energie_sala"):
			l.set_meta("energie_sala", l.get("energie") if l.get("energie") != null else (l as OmniLight3D).light_energy)
		var plin: float = l.get_meta("energie_sala")
		t.tween_property(l, "energie" if l.get("energie") != null else "light_energy", plin * cat, durata)
