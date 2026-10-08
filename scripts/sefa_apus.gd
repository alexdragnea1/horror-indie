extends "res://scripts/sefa_vrajitoare.gd"
## Head Witch în fața blocului, la apus (afara_bloc.tscn, nodul `HeadWitchApus`): după mesajul ei de pe telefon
## (`marcaj_apus`, după ce ai cumpărat o armă de la Gun Store) te așteaptă la scară. La E:
##  1. `replici` (ea vine să-ți spună unde se ascunde Warlock-ul, dar întâi te învață magie defensivă);
##  2. răspunsul tău, după ce ai la tine (în inventar): cu bazooka scoți bazooka și `replica_bazooka`; altfel scoți
##     cea mai tare armă (AK-47 → Shotgun → pistolul) și `replica_arma`; fără arme (doar Fireball) `replica_fara_arme`;
##  3. ea îți arată scutul: ridică brațul, energia mov i se adună în palmă, scutul crește din palma ei în jurul ei
##     (cu o undă mov pe asfalt), îl ține, apoi îl lasă să se destrame; arma ta rămâne ridicată spre ea;
##  4. `replici_dupa_scut`, apoi marcajul `ScutJucator.MARCAJ`: pe ecran apare „Press Ctrl to use shield”.
## După lecție, E pe ea: `replici_motel` (Warlock-ul e în orașul vecin), apoi plecați pe mătură spre stradă
## (`directie_zbor`), negru și aterizați la motel (`scena_motel`, `titlu_motel`; aterizarea e în sefa_motel.gd).
## Replicile sunt ale owner-ului: nu le corecta.

@export var marcaj_apus := "a_primit_mesajul_sefei"
## După zborul spre motel nu mai e aici.
@export var marcaj_plecare := "a_zburat_la_motel"
@export_file("*.tscn") var scena_motel := "res://scenes/motel.tscn"
@export_multiline var titlu_motel := "Paradise Motel\n8:03 PM"
@export_multiline var replici_motel: PackedStringArray = []
## Sarcina după lecție (a lui Claude).
@export var sarcina_dupa_lectie := "Talk to the Head Witch."
@export_multiline var replica_arma := "You: I got offensive magic right here."
@export_multiline var replica_bazooka := "You: Do I look like I need defensive magic?"
@export_multiline var replica_fara_arme := "You: Teach me bitch."
@export_multiline var replici_dupa_scut: PackedStringArray = []
## La ce distanță de ea stai cât îți arată scutul (te dă puțin înapoi dacă ești mai aproape), ca să-l vezi tot.
@export var distanta_lectie := 3.4
## Raza scutului ei (metri) și cât ține ridicat (secunde).
@export var raza_scut := 1.3
@export var durata_scut := 2.2

const SHADER_SCUT := preload("res://shaders/scut.gdshader")
const SUNET_SCUT := preload("res://sunete/scut.ogg")
const SUNET_ADUNARE := preload("res://sunete/scantei_matura.ogg")
const CULOARE_SCUT := Color(0.7, 0.42, 1.0)
## Armele, de la cea mai tare la cea mai slabă (bazooka are replica ei).
const ARME := ["bazooka", "ak47", "shotgun", "pistol_aur", "pistol_roz"]

var _c: Cutscena


func _ready() -> void:
	super()
	if not get_parent().has_node("Jucator") or not Stare.e_marcat(marcaj_apus) or Stare.e_marcat(marcaj_plecare):
		queue_free()
		return
	indiciu = "[E] Talk to the Head Witch"
	# salvare făcută după lecție, dar înainte să fi apăsat Ctrl: sarcina vine abia după scut
	if Stare.e_marcat(ScutJucator.MARCAJ) and not Stare.e_marcat(ScutJucator.MARCAJ_FOLOSIT):
		Stare.seteaza_sarcina("")
		_sarcina_dupa_scut()


## După lecție nu vorbește cu tine până nu ridici o dată scutul (Ctrl) (owner).
func poate_fi_folosit() -> bool:
	if Stare.e_marcat(ScutJucator.MARCAJ) and not Stare.e_marcat(ScutJucator.MARCAJ_FOLOSIT):
		return false
	return not _vorbeste and not mort and not Stare.e_marcat(marcaj_plecare)


## Așteaptă prima folosire a scutului, apoi pune sarcina „Talk to the Head Witch.”.
func _sarcina_dupa_scut() -> void:
	while not Stare.e_marcat(ScutJucator.MARCAJ_FOLOSIT):
		await get_tree().process_frame
		if not is_inside_tree():
			return
	if sarcina_dupa_lectie != "":
		Stare.seteaza_sarcina(sarcina_dupa_lectie)


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_vorbeste = true
	folosit.emit()
	var intoarcere := intoarce_spre(_jucator())
	if intoarcere:
		await intoarcere.finished
	if Stare.e_marcat(ScutJucator.MARCAJ):
		await _spune(replici_motel)
		Stare.seteaza_sarcina("")
		var sunete: Array[AudioStream] = [SUNET_DECOLARE]
		await _zboara_cu_tine(scena_motel, titlu_motel, sunete, marcaj_plecare)
		return
	await _spune(replici)
	# răspunsul tău, cu arma scoasă
	var arma := _arma_de_scos()
	if arma != "":
		Stare.tine_in_mana(arma)
		await get_tree().create_timer(0.5).timeout  # cât urcă arma în cadru
	var raspuns := replica_bazooka if arma == "bazooka" else (replica_arma if arma != "" else replica_fara_arme)
	await _spune(PackedStringArray([raspuns]))
	# îți arată scutul (arma ta rămâne ridicată spre ea)
	Arma.in_scena = true
	Pistol.in_scena = true
	_c = Cutscena.porneste(self)
	await _arata_scutul()
	await _spune(replici_dupa_scut)
	Arma.in_scena = false
	Pistol.in_scena = false
	Stare.seteaza_sarcina("")
	await _c.opreste()
	_vorbeste = false
	Stare.marcheaza(ScutJucator.MARCAJ)
	_sarcina_dupa_scut()


func _spune(linii: PackedStringArray) -> void:
	Dialog.spune(linii)
	if Dialog.activ:
		await Dialog.terminat


## Cea mai tare armă pe care o ai în inventar (pistolul pe care îl ții deja în mână are întâietate față de celălalt).
func _arma_de_scos() -> String:
	for id in ARME:
		if id.begins_with("pistol") and Stare.in_mana.begins_with("pistol") and Stare.are_obiect(Stare.in_mana):
			return Stare.in_mana
		if Stare.are_obiect(id):
			return id
	return ""


func _arata_scutul() -> void:
	var jucator := _jucator() as Node3D
	var piept := global_position + Vector3.UP * 1.25
	# te dă puțin înapoi, ca să vezi tot scutul (nu stai în el)
	var spre_tine := jucator.global_position - global_position
	spre_tine.y = 0.0
	if spre_tine.length() < distanta_lectie:
		var unde := global_position + spre_tine.normalized() * distanta_lectie
		unde.y = jucator.global_position.y
		var pas := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pas.tween_property(jucator, "global_position", unde, 0.6)
	await _c.priveste(piept, 0.7)
	# 1. ridică brațul spre cer, cu palma deschisă
	var ridica := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ridica.tween_property(brat, "rotation", Vector3(-2.3, 0.0, 0.2), 0.55)
	await ridica.finished
	# 2. energia mov se adună în palmă
	var palma := Node3D.new()
	brat.add_child(palma)
	palma.position = MANA
	var adunare := VrajaAtac.particule(palma, 36, 0.5, 0.07, [Color(CULOARE_SCUT, 0.0), Color(0.85, 0.7, 1.0, 1.0), Color(1, 1, 1, 0.0)])
	adunare.local_coords = true
	adunare.emission_sphere_radius = 0.7
	adunare.radial_accel_min = -10.0
	adunare.radial_accel_max = -7.0
	adunare.gravity = Vector3.ZERO
	adunare.emitting = true
	var lumina := OmniLight3D.new()
	lumina.light_color = CULOARE_SCUT
	lumina.light_energy = 0.0
	lumina.omni_range = 4.0
	palma.add_child(lumina)
	Sunet.reda_la(SUNET_ADUNARE, palma.global_position, Sunet.VOLUM_EFECTE - 3.0, 0.05)
	create_tween().tween_property(lumina, "light_energy", 1.4, 0.9)
	_c.priveste(palma.global_position.lerp(piept, 0.5), 0.9)
	await get_tree().create_timer(1.0).timeout
	adunare.emitting = false
	# 3. scutul crește din palma ei până o învelește
	var scut := _sfera_scut()
	scut.global_position = palma.global_position
	scut.scale = Vector3.ONE * 0.05
	var mat := scut.material_override as ShaderMaterial
	Sunet.reda_la(SUNET_SCUT, piept, Sunet.VOLUM_EFECTE, 0.03)
	var creste := create_tween().set_parallel()
	creste.tween_property(scut, "scale", Vector3.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	creste.tween_property(scut, "global_position", global_position + Vector3.UP * 1.05, 0.45).set_trans(Tween.TRANS_SINE)
	creste.tween_method(func(v: float) -> void: mat.set_shader_parameter("putere", v), 0.0, 0.9, 0.4)
	creste.tween_method(func(v: float) -> void: mat.set_shader_parameter("lovit", v), 1.0, 0.0, 0.6)
	creste.tween_property(lumina, "light_energy", 0.6, 0.5)
	_c.priveste(piept + Vector3.UP * 0.1, 0.5)
	await get_tree().create_timer(0.3).timeout
	_unda(global_position + Vector3.UP * 0.04)
	# brațul coboară în față, cu palma spre tine: ține scutul
	var tine := create_tween().set_trans(Tween.TRANS_SINE)
	tine.tween_property(brat, "rotation", Vector3(-1.45, 0.0, 0.25), 0.5)
	await creste.finished
	# 4. îl ține; un puls, ca să vezi că e solid
	await get_tree().create_timer(durata_scut * 0.5).timeout
	var puls := create_tween()
	puls.tween_method(func(v: float) -> void: mat.set_shader_parameter("lovit", v), 0.0, 0.45, 0.12)
	puls.tween_method(func(v: float) -> void: mat.set_shader_parameter("lovit", v), 0.45, 0.0, 0.4)
	await get_tree().create_timer(durata_scut * 0.5).timeout
	# 5. îl lasă să se destrame și coboară brațul
	var stinge := create_tween().set_parallel()
	stinge.tween_method(func(v: float) -> void: mat.set_shader_parameter("putere", v), 0.9, 0.0, 0.7)
	stinge.tween_property(scut, "scale", Vector3.ONE * 1.08, 0.7)
	stinge.tween_property(lumina, "light_energy", 0.0, 0.7)
	stinge.tween_property(brat, "rotation", Vector3.ZERO, 0.7).set_trans(Tween.TRANS_SINE)
	await stinge.finished
	scut.queue_free()
	palma.queue_free()
	await _c.priveste(cap.global_position if cap else piept + Vector3.UP * 0.4, 0.5)


func _sfera_scut() -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = raza_scut
	mesh.height = raza_scut * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var mat := ShaderMaterial.new()
	mat.shader = SHADER_SCUT
	mat.set_shader_parameter("culoare", CULOARE_SCUT)
	mat.set_shader_parameter("putere", 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(mi)
	return mi


## O undă mov care fuge pe asfalt din jurul ei când se ridică scutul.
func _unda(centru: Vector3) -> void:
	var inel := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.92
	tor.outer_radius = 1.0
	tor.rings = 32
	tor.ring_segments = 4
	inel.mesh = tor
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.disable_fog = true
	mat.albedo_color = Color(CULOARE_SCUT, 1.0)
	inel.material_override = mat
	inel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(inel)
	inel.global_position = centru
	inel.scale = Vector3(0.5, 0.05, 0.5)
	var t := create_tween().set_parallel()
	t.tween_property(inel, "scale", Vector3(3.2, 0.05, 3.2), 0.7).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.7)
	t.chain().tween_callback(inel.queue_free)
