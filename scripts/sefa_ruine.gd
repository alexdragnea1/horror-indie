extends "res://scripts/sefa_vrajitoare.gd"
## Head Witch în curtea conacului, în atacul Warlock-ului și după el (conac.tscn, nodul `HeadWitchRuine`).
##  - În atac (atac_conac.gd o comandă): apare lângă tine într-un fum mov (`apari_langa`), ține scutul cu brațul întins
##    (`brat_scut`), iar la bubuitura vrăjii mari suflul o aruncă pe spate (`cade`).
##  - După atac (`marcaj_atac`) zace leșinată unde a căzut (`culca_te`); după ce te ridici tu, se ridică și ea, plutind
##    (`ridica_te`, o cheamă atac_conac.gd), iar de la `marcaj_trezit` poți vorbi cu ea: `replici` (ale owner-ului).
##  - Apoi scoate mătura și te duce acasă: decolați de lângă ruină, ocoliți conacul care arde (te uiți la el), apoi
##    plecați peste pădure (`drum_acasa`, `durata_drum`); spre capăt, negru și fața blocului (`scena_acasa`,
##    `titlu_acasa`; marcajul `marcaj_zbor`, vezi intoarcere_noaptea.gd). Acolo ea nu mai e.
## Replicile sunt ale owner-ului: nu le corecta.

@export var marcaj_atac := "conacul_atacat"
@export var marcaj_trezit := "s_a_trezit_dupa_atac"
## Punctele zborului spre casă (în lume): sus peste ruină, un ocol în jurul ei, apoi departe peste pădure.
@export var drum_acasa := PackedVector3Array([Vector3(9, 7, -2), Vector3(18, 15, -16), Vector3(6, 20, -34), Vector3(-14, 21, -30),
	Vector3(-22, 22, -10), Vector3(-12, 25, 16), Vector3(8, 30, 60), Vector3(30, 36, 130)])
## Cât durează zborul până se face negru (secunde).
@export var durata_drum := 17.0
## Încotro te uiți cât ocoliți ruina (mijlocul ei).
@export var priveste_ruina := Vector3(0, 6, -13)
## Cât stă culcată mai sus de pământ (spatele robei), ca să nu intre în pietriș.
@export var inaltime_culcata := 0.24
## În zbor: cât te muți într-o parte (minus = în stânga ei, spre ruina pe care o ocoliți) și cât mai sus pe mătură (metri),
## ca să vezi pe lângă ea (din dreapta ei, ea stătea între tine și conac).
@export var lateral_zbor := -0.8
@export var ridicare_zbor := 0.3

const SUNET_SCUT := preload("res://sunete/scut.ogg")

var _culcata := false
var _privire_normala := 0.0


func _ready() -> void:
	super()
	_privire_normala = distanta_privire
	if not get_parent().has_node("Jucator") or not Stare.e_marcat(marcaj_atac) or Stare.e_marcat(marcaj_zbor):
		# până la atac nu e aici (atac_conac.gd o aduce în curte cu `apari_langa`), iar după zbor a plecat
		hide()
		_dezactiveaza_coliziunea()
		return
	if not Stare.e_marcat(marcaj_trezit):
		culca_te()


func poate_fi_folosit() -> bool:
	return visible and not _vorbeste and not _culcata and Stare.e_marcat(marcaj_trezit) and not Stare.e_marcat(marcaj_zbor)


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_vorbeste = true
	folosit.emit()
	await intoarce_spre(_jucator()).finished
	Dialog.spune(replici)
	if Dialog.activ:
		await Dialog.terminat
	Stare.seteaza_sarcina("")
	await _zbor_acasa_lung()


# ---------------------------------------------------------------------------------------------------------------
# În atac
# ---------------------------------------------------------------------------------------------------------------

## Apare la `poz` (cu fața spre `spre`) dintr-un fum mov și un fulger de lumină, ca atunci când dispare.
func apari_langa(poz: Vector3, spre: Vector3) -> void:
	global_position = poz
	var d := spre - poz
	rotation.y = atan2(d.x, d.z)
	_model.scale = Vector3(0.05, 1.3, 0.05)
	show()
	var unde := poz + Vector3.UP * 1.0
	Sunet.reda_la(SUNET_MATURA, unde, Sunet.VOLUM_EFECTE, 0.05)
	for k in 3:
		_fum(unde + Vector3(randf_range(-0.3, 0.3), k * 0.45 - 0.4, randf_range(-0.3, 0.3)))
	var fulger := OmniLight3D.new()
	fulger.light_color = Color(0.75, 0.5, 0.95)
	fulger.light_energy = 4.0
	fulger.omni_range = 6.0
	get_tree().current_scene.add_child(fulger)
	fulger.global_position = unde
	var stinge := fulger.create_tween()
	stinge.tween_property(fulger, "light_energy", 0.0, 0.7)
	stinge.tween_callback(fulger.queue_free)
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_model, "scale", Vector3.ONE, 0.35)
	await t.finished


## Întinde brațul (scutul) sau îl lasă jos.
func brat_scut(sus: bool, durata := 0.5) -> Tween:
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(brat, "rotation", Vector3(-1.55, 0.0, 0.25) if sus else Vector3.ZERO, durata)
	return t


## Suflul o aruncă pe spate, `departe` metri pe direcția `spre` (orizontal): zboară puțin și cade culcată.
func cade(spre: Vector3, departe := 2.2) -> void:
	distanta_privire = 0.0
	var d := Vector3(spre.x, 0.0, spre.z).normalized()
	# cade pe spate = cu fața în sus, cu capul pe direcția în care a fost aruncată
	rotation.y = atan2(-d.x, -d.z)
	var start := global_position
	var t := create_tween().set_parallel()
	t.tween_method(func(k: float) -> void:
		global_position = start + d * departe * k + Vector3.UP * 0.9 * 4.0 * k * (1.0 - k), 0.0, 1.0, 0.7)
	t.tween_property(_model, "rotation:x", -PI / 2.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_model, "position:y", inaltime_culcata, 0.6)
	t.tween_property(brat, "rotation", Vector3(0.25, 0.0, 0.55), 0.5)
	await t.finished
	Sunet.reda_la(SUNET_ATERIZARE, global_position, Sunet.VOLUM_EFECTE, 0.05)
	_culcata = true


## Culcată pe spate, pe loc (după atac, cât ești leșinat; la Continue).
func culca_te() -> void:
	show()
	distanta_privire = 0.0
	_model.rotation.x = -PI / 2.0
	_model.position.y = inaltime_culcata
	brat.rotation = Vector3(0.25, 0.0, 0.55)
	_culcata = true


## Se ridică: plutește în sus, se îndreaptă (cu scântei mov), coboară în picioare, se clatină puțin și se întoarce spre tine.
func ridica_te() -> void:
	if not _culcata:
		return
	var inainte := global_transform.basis.z * -1.0  # culcată, capul e spre -Z-ul nodului
	inainte.y = 0.0
	inainte = inainte.normalized()
	var start := global_position
	var unde := start + inainte * 0.9  # se ridică cam din dreptul șoldurilor
	Sunet.reda_la(SUNET_SCUT, start + Vector3.UP * 0.5, Sunet.VOLUM_EFECTE - 6.0, 0.05, 0.7)
	for k in 3:
		_fum(start + inainte * (0.4 + k * 0.5) + Vector3.UP * 0.3)
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(func(k: float) -> void:
		global_position = start.lerp(unde, k) + Vector3.UP * 0.35 * sin(k * PI), 0.0, 1.0, 2.2)
	t.tween_property(_model, "rotation:x", 0.0, 2.2)
	t.tween_property(_model, "position:y", 0.0, 2.2)
	t.tween_property(brat, "rotation", Vector3.ZERO, 1.6)
	await t.finished
	_culcata = false
	# se clatină puțin, încă amețită
	var clatina := create_tween().set_trans(Tween.TRANS_SINE)
	clatina.tween_property(_model, "rotation:z", 0.08, 0.35)
	clatina.tween_property(_model, "rotation:z", -0.05, 0.4)
	clatina.tween_property(_model, "rotation:z", 0.0, 0.4)
	await clatina.finished
	distanta_privire = _privire_normala
	var jucator := _jucator()
	if jucator:
		await intoarce_spre(jucator).finished


# ---------------------------------------------------------------------------------------------------------------
# Zborul spre casă
# ---------------------------------------------------------------------------------------------------------------

func _zbor_acasa_lung() -> void:
	var jucator := _jucator() as CharacterBody3D
	var c := Cutscena.porneste(self)
	var camera: Camera3D = jucator.get_node("Cap/Camera3D")
	var cap_jucator: Node3D = jucator.get_node("Cap")
	var d := drum_acasa[0] - global_position
	d.y = 0.0
	d = d.normalized()
	var mijloc := await _urcati_pe_matura(c, d)
	# plutește o clipă; tu te muți mai într-o parte și mai sus pe mătură (ca la sosirea la conac, sefa_conac.gd): stând
	# drept în spatele ei, spatele ei ar acoperi tot ce e de văzut
	var de_la := _tu_pe_matura
	var la := de_la + _matura.global_basis.inverse() * (d.cross(Vector3.UP) * lateral_zbor + Vector3.UP * ridicare_zbor)
	var tween := create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(_matura, "global_position:y", mijloc.y + 0.12, 0.45)
	tween.parallel().tween_property(self, "_tu_pe_matura", la, 0.8)
	tween.tween_property(_matura, "global_position:y", mijloc.y - 0.05, 0.4)
	await tween.finished
	Sunet.reda(SUNET_DECOLARE, Sunet.VOLUM_EFECTE)
	var vant := AudioStreamPlayer.new()
	vant.stream = SUNET_VANT
	vant.bus = &"Efecte"
	vant.volume_db = -30.0
	add_child(vant)
	vant.play()
	create_tween().tween_property(vant, "volume_db", Sunet.VOLUM_EFECTE - 3.0, 3.0)
	var fov := camera.fov
	create_tween().set_trans(Tween.TRANS_SINE).tween_property(camera, "fov", fov + 10.0, 3.0)

	# drumul: Catmull-Rom de la mătură prin `drum_acasa`
	var puncte: Array[Vector3] = [_matura.global_position]
	puncte.append_array(Array(drum_acasa))
	var curba := Curve3D.new()
	curba.bake_interval = 0.5
	for i in puncte.size():
		var p: Vector3 = puncte[i]
		var inainte: Vector3 = puncte[maxi(i - 1, 0)]
		var dupa: Vector3 = puncte[mini(i + 1, puncte.size() - 1)]
		var tangenta := (dupa - inainte) / 6.0
		curba.add_point(p, -tangenta, tangenta)
	_plecat = false
	create_tween().tween_method(_zbor_pas.bind(curba, curba.get_baked_length(), cap_jucator), 0.0, 1.0, durata_drum)


var _plecat := false


func _zbor_pas(t: float, curba: Curve3D, lungime: float, cap_jucator: Node3D) -> void:
	# pornește încet, apoi tot mai repede
	_pe_drum(curba, lungime * pow(t, 1.45), lungime, t, cap_jucator)
	_tremur = lerpf(0.3, 1.0, minf(t * 3.0, 1.0))
	# spre capăt: negru și fața blocului (ecranul se întunecă în 0,9 s, deci pornește puțin înainte)
	if t > 0.88 and not _plecat:
		_plecat = true
		Stare.marcheaza(marcaj_zbor)
		Stare.meniu_deschis = false
		var sunete: Array[AudioStream] = [SUNET_DECOLARE]
		Tranzitie.mergi_la(scena_acasa, titlu_acasa, sunete)


## Mătura la distanța `s` pe drum (îndreptată după drum, aplecată în viraje), iar privirea ta: pe ruina care arde cât
## o ocoliți, apoi înainte, spre pădure.
func _pe_drum(curba: Curve3D, s: float, lungime: float, t: float, cap_jucator: Node3D) -> void:
	if not is_instance_valid(_matura):
		return
	var poz := curba.sample_baked(s, true)
	var inainte := curba.sample_baked(minf(s + 2.0, lungime), true) - poz
	var inapoi := poz - curba.sample_baked(maxf(s - 2.0, 0.0), true)
	if inainte.length() < 0.01:
		inainte = inapoi
	var baza := Basis.looking_at(inainte.normalized(), Vector3.UP)
	var cotitura := 0.0
	if inapoi.length() > 0.01:
		cotitura = Vector2(inapoi.x, inapoi.z).angle_to(Vector2(inainte.x, inainte.z))
	var aplecare := clampf(cotitura * 5.0, -0.5, 0.5)
	_matura.global_transform = Transform3D(baza * Basis(Vector3.FORWARD, aplecare), poz)
	var jucator := _jucator()
	if jucator == null:
		return
	jucator.global_position = _matura.to_global(_tu_pe_matura)
	global_position = _matura.to_global(_ea_pe_matura)
	var fata := -_matura.global_basis.z
	rotation.y = atan2(fata.x, fata.z)
	var ochi := cap_jucator.global_position
	var spre_ruina := priveste_ruina - ochi
	# înainte, dar puțin în partea în care stai (pe lângă ea) și în jos, spre pădure
	var dreapta := inainte.normalized().cross(Vector3.UP).normalized()
	var spre_drum := (inainte.normalized() + dreapta * signf(lateral_zbor) * 0.5) * 20.0 + Vector3.DOWN * 5.0
	# întâi la ruina pe care o ocoliți, apoi înainte, iar la sfârșit, o ultimă privire înapoi, la conacul care arde
	var dir := spre_ruina.lerp(spre_drum, smoothstep(0.45, 0.6, t))
	dir = dir.lerp(spre_ruina, smoothstep(0.7, 0.82, t))
	jucator.rotation.y = lerp_angle(jucator.rotation.y, atan2(-dir.x, -dir.z), 0.12)
	cap_jucator.rotation.x = lerpf(cap_jucator.rotation.x, clampf(atan2(dir.y, Vector2(dir.x, dir.z).length()), -1.2, 0.6), 0.12)
