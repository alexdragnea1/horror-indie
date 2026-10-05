extends "res://scripts/sefa_vrajitoare.gd"
## Head Witch la sediul coven-ului (conac.tscn, nodul `HeadWitchConac`). Nodul stă unde rămâne ea după aterizare.
## Prima dată (fără `marcaj_sosire`) scena începe în aer, cum s-a luminat ecranul după zborul de la bloc: stai în
## spatele ei pe mătură, veniți de departe peste pădure, ocoliți dealul și coborâți în curte (`drum` = punctele
## zborului, ultimul e chiar înainte de aterizare). Privirea ta stă pe conac (`priveste_spre`). Mătura se oprește
## lângă fântână, ea sare jos, tu cobori, iar mătura îi dispare din mână într-un fum mov. Apoi se întoarce spre tine.
## La Continue e deja jos.

@export var marcaj_sosire := "a_ajuns_la_conac"
## Punctele zborului (în lume). Între ele mătura merge lin (Catmull-Rom), tot mai încet spre aterizare.
@export var drum := PackedVector3Array([Vector3(70, 26, 160), Vector3(45, 22, 100), Vector3(-8, 18, 66),
	Vector3(-24, 11, 38), Vector3(-12, 5.5, 24), Vector3(-0.8, 2.0, 17.0)])
## Cât durează zborul (secunde).
@export var durata_zbor := 12.0
## Încotro te uiți cât zburați (conacul) și la sfârșit (ușa).
@export var priveste_spre := Vector3(0, 11, -14)
@export var priveste_la_final := Vector3(0, 3, -9)
## Încotro e întoarsă mătura când aterizează (spre conac).
@export var directie_aterizare := Vector3(0, 0, -1)
## Cât de mult în dreapta ei stai pe mătură și cât de sus îți sunt ochii deasupra cozii (metri).
@export var lateral_zbor := 0.55
@export var ochi_zbor := 0.86

const SUNET_PAS := preload("res://sunete/pas_poteca_2.ogg")

var _c: Cutscena
var _inclinare := 0.0


func _ready() -> void:
	super()
	await get_tree().process_frame
	var jucator := _jucator()
	if jucator == null or Stare.e_marcat(marcaj_sosire):
		return
	await _aterizare()


func poate_fi_folosit() -> bool:
	return false


func _process(delta: float) -> void:
	super(delta)
	if _pe_matura:
		var camera: Camera3D = _jucator().get_node("Cap/Camera3D")
		camera.rotation.z += _inclinare


func _aterizare() -> void:
	_vorbeste = true
	var jucator := _jucator() as CharacterBody3D
	var cap_jucator: Node3D = jucator.get_node("Cap")
	var camera: Camera3D = cap_jucator.get_node("Camera3D")
	_c = Cutscena.porneste(self)
	jucator.seteaza_purtat(true)
	var sol := global_position.y
	var d := Vector3(directie_aterizare.x, 0.0, directie_aterizare.z).normalized()
	var unde_sta := global_position
	# cât zburați nu se uită înapoi la tine (ești în spatele ei)
	var privire_dupa := distanta_privire
	distanta_privire = 0.0

	# unde stați pe mătură, socotit cu mătura în poziția de aterizare (ca la decolarea de la coven)
	_matura = model_matura.instantiate() as Node3D
	_matura.set_script(SCRIPT_MODEL)
	_matura.set("material", MATERIAL)
	get_tree().current_scene.add_child(_matura)
	var final := Transform3D(Basis.looking_at(d, Vector3.UP), Vector3(unde_sta.x, sol + inaltime_matura, unde_sta.z) - d * loc_ea)
	_matura.global_transform = final
	_ea_pe_matura = _matura.to_local(unde_sta + Vector3.UP * 0.12)
	# tu stai în spatele ei, mai într-o parte și mai sus decât la decolarea din pădure: altfel spatele ei acoperă conacul
	var loc := final.origin - d * loc_tu + d.cross(Vector3.UP) * lateral_zbor
	_tu_pe_matura = _matura.to_local(Vector3(loc.x, loc.y + ochi_zbor - cap_jucator.position.y, loc.z))
	brat.rotation = Vector3(-0.45, 0.0, 0.0)

	# drumul: Catmull-Rom prin puncte, cu aterizarea la capăt
	var puncte := Array(drum)
	puncte.append(final.origin)
	var curba := Curve3D.new()
	curba.bake_interval = 0.5
	for i in puncte.size():
		var p: Vector3 = puncte[i]
		var inainte: Vector3 = puncte[maxi(i - 1, 0)]
		var dupa: Vector3 = puncte[mini(i + 1, puncte.size() - 1)]
		var tangenta := (dupa - inainte) / 6.0
		curba.add_point(p, -tangenta, tangenta)
	var lungime := curba.get_baked_length()
	_pune_pe_drum(curba, 0.0, lungime, final, camera)
	_pe_matura = true

	# vântul (tare la început, se stinge la aterizare) și FOV-ul mai larg cât zburați repede
	var vant := AudioStreamPlayer.new()
	vant.stream = SUNET_VANT
	vant.bus = &"Efecte"
	vant.volume_db = Sunet.VOLUM_EFECTE
	add_child(vant)
	vant.play()
	var fov := camera.fov
	camera.fov = fov + 10.0
	_tremur = 0.8
	while Tranzitie.activa:
		await get_tree().process_frame
	var zbor := create_tween()
	zbor.tween_method(func(t: float) -> void:
		# repede la început, tot mai încet spre aterizare
		var s := lungime * (1.0 - pow(1.0 - t, 2.2))
		_pune_pe_drum(curba, s, lungime, final, camera)
		_tremur = lerpf(0.8, 0.15, t)
		camera.fov = lerpf(fov + 10.0, fov, smoothstep(0.5, 1.0, t))
		vant.volume_db = lerpf(Sunet.VOLUM_EFECTE, -24.0, smoothstep(0.6, 1.0, t)), 0.0, 1.0, durata_zbor)
	await zbor.finished
	vant.queue_free()
	_inclinare = 0.0
	_tremur = 0.0

	# plutește o clipă, apoi coboară până ating picioarele ei pământul
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_matura, "global_position:y", final.origin.y + 0.06, 0.35)
	tween.tween_property(_matura, "global_position:y", final.origin.y, 0.4)
	await tween.finished
	await get_tree().create_timer(0.3).timeout

	# ea sare jos și face un pas în față
	_pe_matura = false
	var pasi := create_tween().set_trans(Tween.TRANS_SINE)
	pasi.tween_property(self, "global_position", unde_sta + Vector3.UP * 0.18 + d * 0.15, 0.22).set_ease(Tween.EASE_OUT)
	pasi.tween_property(self, "global_position", unde_sta + d * 0.3, 0.22).set_ease(Tween.EASE_IN)
	Sunet.reda_la(SUNET_PAS, unde_sta, Sunet.VOLUM_EFECTE, 0.05)
	await pasi.finished
	unde_sta += d * 0.3
	# cobori și tu, într-o parte
	var jos := jucator.global_position
	jos.y = sol
	jos += d.cross(Vector3.UP) * 0.45
	var coborare := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	coborare.tween_property(jucator, "global_position", jos, 0.6)
	_c.priveste(unde_sta + Vector3.UP * 1.5, 0.6)
	await coborare.finished
	Sunet.reda(SUNET_PAS, Sunet.VOLUM_EFECTE, 0.05)
	camera.position = Vector3.ZERO
	camera.rotation.z = 0.0
	jucator.seteaza_purtat(false)

	# ia mătura în mână, în picioare, și o face să dispară
	var mana := brat.global_transform * MANA
	var bratul := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bratul.tween_property(brat, "rotation", Vector3(-0.5, 0.0, -0.6), 0.45)
	var in_picioare := Basis(Vector3.RIGHT, PI / 2.0).rotated(Vector3.UP, rotation.y)
	var q_start := _matura.global_basis.get_rotation_quaternion()
	var q_sus := in_picioare.get_rotation_quaternion()
	var start := _matura.global_position
	tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(t: float) -> void:
		_matura.global_basis = Basis(q_start.slerp(q_sus, t))
		_matura.global_position = start.lerp(brat.global_transform * MANA + Vector3.UP * 0.25, t), 0.0, 1.0, 0.6)
	await tween.finished
	mana = brat.global_transform * MANA
	Sunet.reda_la(SUNET_MATURA, mana, Sunet.VOLUM_EFECTE, 0.05)
	_fum(mana + Vector3.UP * 0.25)
	tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_matura, "scale", Vector3.ONE * 0.05, 0.3)
	await tween.finished
	_matura.queue_free()
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(brat, "rotation", Vector3.ZERO, 0.6)
	distanta_privire = privire_dupa
	await intoarce_spre(jucator).finished
	await _c.priveste(cap.global_position, 0.5)
	Stare.marcheaza(marcaj_sosire)
	if sarcina_noua != "":
		Stare.seteaza_sarcina(sarcina_noua)
	_vorbeste = false
	await _c.opreste()


## Mătura la distanța `s` pe drum: poziția, încotro e îndreptată (cu nasul după pantă), aplecarea în viraje;
## privirea ta pe conac (iar spre capăt pe ușă).
func _pune_pe_drum(curba: Curve3D, s: float, lungime: float, final: Transform3D, camera: Camera3D) -> void:
	var poz := curba.sample_baked(s, true)
	var inainte := curba.sample_baked(minf(s + 1.5, lungime), true) - poz
	var inapoi := poz - curba.sample_baked(maxf(s - 1.5, 0.0), true)
	if inainte.length() < 0.01:
		inainte = -final.basis.z
	var baza := Basis.looking_at(inainte.normalized(), Vector3.UP)
	# virajul: cât se schimbă direcția pe orizontală
	var cotitura := 0.0
	if inapoi.length() > 0.01 and inainte.length() > 0.01:
		cotitura = Vector2(inapoi.x, inapoi.z).angle_to(Vector2(inainte.x, inainte.z))
	var aplecare := clampf(cotitura * 4.0, -0.45, 0.45)
	baza = baza * Basis(Vector3.FORWARD, aplecare)
	# ultimii metri: se îndreaptă exact pe direcția de aterizare
	var spre_final := smoothstep(lungime - 8.0, lungime, s)
	var q := baza.get_rotation_quaternion().slerp(final.basis.get_rotation_quaternion(), spre_final)
	_matura.global_transform = Transform3D(Basis(q), poz)
	_inclinare = -aplecare * 0.6 * (1.0 - spre_final)
	# privirea
	var jucator := _jucator()
	if jucator == null:
		return
	jucator.global_position = _matura.to_global(_tu_pe_matura)
	global_position = _matura.to_global(_ea_pe_matura)
	var fata := -_matura.global_basis.z
	rotation.y = atan2(fata.x, fata.z)
	var ochi := camera.global_position
	var tinta := priveste_spre.lerp(priveste_la_final, smoothstep(lungime * 0.55, lungime, s))
	var dir := tinta - ochi
	var cap_jucator: Node3D = jucator.get_node("Cap")
	jucator.rotation.y = atan2(-dir.x, -dir.z)
	cap_jucator.rotation.x = clampf(atan2(dir.y, Vector2(dir.x, dir.z).length()), -1.2, 0.6)
