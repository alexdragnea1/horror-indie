extends Interactabil
## „8 Ball Enjoyer” din baia barului URBAN (owner, 11.10): stă la blatul cu chiuvetele și trage linii de pe telefon. În
## buclă: le „taie” cu cardul pe ecranul telefonului, ia bancnota rulată, se apleacă și trage una (linia se micșorează
## sub bancnotă), se ridică brusc, trage pe nas, se șterge la nas; trage cel mult două, apoi taie altele (rămâne mereu
## măcar una pentru tine). E → se îndreaptă, se uită la tine și îți întinde bancnota: „8 Ball Enjoyer: Do you want one?”
## Yes / Nah. Nah = gata, nimic altceva (owner). Yes = „You: Don't mind if I do”, el se dă un pas într-o parte, tu te
## apleci peste telefon cu bancnota (la persoana întâi) și tragi o linie, apoi capul îți sare înapoi (FOV, tremur,
## inima). Recuzita (`recuzita_8ball.glb`: Telefon, Linie1..3, Card, Bancnota) stă în nodul `recuzita`.

const SUNET_PRIZA := preload("res://sunete/priza_trasa.ogg")
const SUNET_SNIFF := preload("res://sunete/nas_sniff.ogg")
const SUNET_CARD := preload("res://sunete/card_tocat.ogg")
const SUNET_INIMA := preload("res://sunete/inima_rapida.ogg")
const SUNET_BANCNOTA := preload("res://sunete/bancnota.ogg")

@export var om: OmLaMasa
@export var recuzita: Node3D
## Unde stai tu cât tragi (pe podea, în fața telefonului, cu -Z spre el).
@export var loc_tu: Marker3D
## Cât se dă el într-o parte (global) ca să-ți facă loc la telefon.
@export var pas_lateral := Vector3(0.0, 0.0, -0.62)
## Cât se apleacă peste telefon (radiani, `OmLaMasa.aplecare`).
@export var aplecare_trage := 1.0

var _linii: Array[Node3D] = []
var _card: Node3D
var _bancnota: Node3D
var _repaus_card: Transform3D
var _repaus_bancnota: Transform3D
var _repaus_eu: Transform3D
## Ce ține acum în mâna dreaptă (îl mută _process după mână): null, _card sau _bancnota.
var _in_mana: Node3D
## Bancnota spre ce punct arată cu celălalt capăt (nasul lui, cât trage); INF = culcată ca pe blat.
var _bancnota_spre := Vector3.INF
var _cu_tine := false
var _in_pas := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	indiciu = "[E] Talk"
	for i in 3:
		_linii.append(recuzita.find_child("Linie%d" % (i + 1), true, false) as Node3D)
	_card = recuzita.find_child("Card", true, false) as Node3D
	_bancnota = recuzita.find_child("Bancnota", true, false) as Node3D
	_repaus_card = _card.global_transform
	_repaus_bancnota = _bancnota.global_transform
	_repaus_eu = global_transform
	om.privire = null
	_bucla.call_deferred()


func _process(_delta: float) -> void:
	if _in_mana == _card:
		_card.global_position = om.punct_mana("D") + Vector3.DOWN * 0.012
	elif _in_mana == _bancnota:
		var mana := om.punct_mana("D")
		if _bancnota_spre != Vector3.INF:
			# un capăt în nas, celălalt pe linie (bancnota e pe X-ul ei)
			var ax := (_bancnota_spre - mana).normalized()
			var b := Basis(Quaternion(Vector3.RIGHT, ax))
			_bancnota.global_transform = Transform3D(b, mana + ax * 0.03)
		else:
			_bancnota.global_transform = Transform3D(_repaus_bancnota.basis, mana)


# ---------------------------------------------------------------- bucla lui

func _bucla() -> void:
	await _asteapta(_rng.randf_range(0.5, 2.0))
	var trase := 0
	while is_inside_tree():
		if _cu_tine:
			await _asteapta(0.3)
			continue
		_in_pas = true
		if trase >= 2 or _linii_ramase().is_empty():
			await _taie()
			trase = 0
		else:
			await _trage()
			trase += 1
		_in_pas = false
		# se uită prin baie, își freacă nasul, iar se uită la telefon
		var pauza := _rng.randf_range(2.5, 5.0)
		while pauza > 0.0 and not _cu_tine:
			await _asteapta(0.25)
			pauza -= 0.25


func _linii_ramase() -> Array[Node3D]:
	var r: Array[Node3D] = []
	for l in _linii:
		if l.visible and l.scale.x > 0.05:
			r.append(l)
	return r


## Taie liniile cu cardul: mâna dreaptă ia cardul și îl trage încolo și încoace pe ecran, liniile cresc; apoi îl pune la loc.
func _taie() -> void:
	var tel := _centru_telefon()
	om.priveste_punct = tel
	await om.du_mana("D", _repaus_card.origin + Vector3.UP * 0.01, 0.5)
	_in_mana = _card
	for l in _linii:
		if not l.visible or l.scale.x < 0.05:
			l.scale.x = 0.001
			l.show()
	var lateral := _card.global_basis.z.normalized() * 0.035
	for k in 8:
		if _cu_tine:
			break
		var p := tel + Vector3.UP * 0.02 + lateral * (1.0 if k % 2 == 0 else -1.0)
		await om.du_mana("D", p, 0.13)
		Sunet.reda_la(SUNET_CARD, p, Sunet.VOLUM_EFECTE - 4.0, 0.15)
		for l in _linii:
			l.scale.x = maxf(l.scale.x, (k + 1) / 8.0)
	for l in _linii:
		l.scale.x = 1.0
	await om.du_mana("D", _repaus_card.origin + Vector3.UP * 0.012, 0.35)
	_in_mana = null
	_card.global_transform = _repaus_card
	om.lasa_mana("D", 0.45)
	om.priveste_punct = Vector3.INF


## Trage o linie: ia bancnota, se apleacă, o trage de la un capăt la altul, se ridică brusc și trage pe nas.
func _trage() -> void:
	var linie: Node3D = _linii_ramase()[0]
	var aproape := _capat_aproape(linie)
	var departe := linie.global_position
	om.priveste_punct = aproape
	await om.du_mana("D", _repaus_bancnota.origin + Vector3.UP * 0.008, 0.5)
	_in_mana = _bancnota
	if _cu_tine:
		await _lasa_bancnota()
		return
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(om, "aplecare", aplecare_trage, 0.7)
	_bancnota_spre = Vector3.INF
	# mâna urmărește un punct pe care îl mutăm de-a lungul liniei
	var tinta := Marker3D.new()
	add_child(tinta)
	tinta.global_position = aproape + Vector3.UP * 0.035
	await om.du_mana("D", tinta, 0.7)
	_bancnota_spre = _nas()
	if _cu_tine:
		await _ridica()
		await _lasa_bancnota()
		tinta.queue_free()
		return
	# trage: mâna (și bancnota) merge de-a lungul liniei, linia se scurtează în urma ei
	Sunet.reda_la(SUNET_PRIZA, aproape, Sunet.VOLUM_EFECTE - 2.0, 0.08)
	var lung := linie.scale.x
	t = create_tween().set_parallel()
	t.tween_property(linie, "scale:x", 0.001, 0.85)
	t.tween_property(tinta, "global_position", aproape.lerp(departe, lung) + Vector3.UP * 0.035, 0.85)
	t.tween_method(func(_v: float) -> void: _bancnota_spre = _nas(), 0.0, 1.0, 0.85)
	await t.finished
	linie.hide()
	om.du_mana("D", tinta.global_position, 0.01)
	tinta.queue_free()
	await _ridica()
	await _lasa_bancnota()
	await _asteapta(0.25)
	Sunet.reda_la(SUNET_SNIFF, om.gura(), Sunet.VOLUM_EFECTE - 4.0, 0.1)
	# se șterge la nas cu mâna stângă
	await om.du_mana("S", _nas() + om.global_basis.z * 0.05, 0.35)
	await _asteapta(0.3)
	om.lasa_mana("S", 0.4)
	om.priveste_punct = Vector3.INF


## Se îndreaptă brusc, cu capul pe spate o clipă.
func _ridica() -> void:
	om.priveste_punct = om.global_position + Vector3.UP * 3.0 + om.global_basis.z * 0.6
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(om, "aplecare", 0.0, 0.3)
	await t.finished


func _lasa_bancnota() -> void:
	_bancnota_spre = Vector3.INF
	await om.du_mana("D", _repaus_bancnota.origin + Vector3.UP * 0.008, 0.45)
	_in_mana = null
	_bancnota.global_transform = _repaus_bancnota
	om.lasa_mana("D", 0.45)


func _nas() -> Vector3:
	return om.gura() + Vector3.UP * 0.035


func _centru_telefon() -> Vector3:
	return recuzita.find_child("Telefon", true, false).global_position


## Capătul liniei dinspre el (originea liniei e capătul dinspre perete; linia e pe X-ul ei, lungă de 0,1 m).
func _capat_aproape(linie: Node3D) -> Vector3:
	return linie.global_transform * Vector3(0.1, 0.0, 0.0)


func _asteapta(s: float) -> void:
	await get_tree().create_timer(s).timeout


# ---------------------------------------------------------------- cu tine

func interactioneaza() -> void:
	if not poate_fi_folosit() or _cu_tine:
		return
	folosit.emit()
	_cu_tine = true
	while _in_pas:
		await get_tree().process_frame
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	var cap: Node3D = jucator.get_node("Cap")
	om.priveste_punct = Vector3.INF
	om.privire = cap
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(om, "aplecare", 0.0, 0.3)
	if _linii_ramase().is_empty():
		await _taie()
	# îți întinde bancnota rulată
	await om.du_mana("D", _repaus_bancnota.origin + Vector3.UP * 0.008, 0.4)
	_in_mana = _bancnota
	Sunet.reda_la(SUNET_BANCNOTA, _bancnota.global_position, Sunet.VOLUM_EFECTE - 10.0, 0.1)
	await om.du_mana("D", _spre_tine(cap), 0.55)
	var ales := await Dialog.intreaba("8 Ball Enjoyer: Do you want one?", PackedStringArray(["Yes", "Nah"]))
	if ales == 0:
		Dialog.spune(PackedStringArray(["You: Don't mind if I do"]))
		if Dialog.activ:
			await Dialog.terminat
		await _tragi_tu(jucator)
	else:
		await _lasa_bancnota()
	om.privire = null
	_cu_tine = false


## Punctul în care îți ține bancnota: la 0,45 m de el spre tine, la înălțimea pieptului.
func _spre_tine(cap: Node3D) -> Vector3:
	var spre := cap.global_position - om.global_position
	spre.y = 0.0
	return om.global_position + spre.normalized() * 0.45 + Vector3.UP * 1.25


func _tragi_tu(jucator: Node3D) -> void:
	var cap: Node3D = jucator.get_node("Cap")
	var camera: Camera3D = cap.get_node("Camera3D")
	var inaltime := cap.position.y
	var start := jucator.global_position
	var fov := camera.fov
	var c := Cutscena.porneste(self)
	jucator.seteaza_purtat(true)
	var linie: Node3D = _linii_ramase()[0]
	var aproape := _capat_aproape(linie)
	var departe := linie.global_position
	# el se dă un pas într-o parte, tu vii în fața telefonului
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(self, "global_position", _repaus_eu.origin + pas_lateral, 0.7)
	var loc := loc_tu.global_position
	t.tween_property(jucator, "global_position", loc, 0.8)
	var d := aproape - (loc + Vector3.UP * inaltime)
	await c.roteste(atan2(-d.x, -d.z), atan2(d.y, Vector2(d.x, d.z).length()), 0.8)
	if t.is_running():
		await t.finished
	# bancnota trece din mâna lui în a ta (în fața camerei, cu capătul spre nas)
	_in_mana = null
	_bancnota_spre = Vector3.INF
	_bancnota.reparent(camera, true)
	om.lasa_mana("D", 0.5)
	om.privire = cap
	Sunet.reda(SUNET_BANCNOTA, Sunet.VOLUM_EFECTE - 8.0, 0.1)
	# din josul ecranului (de la nas) până aproape de linie: urcă spre ce privești
	var poza_bancnota := Transform3D(Basis(Vector3.RIGHT, 0.66) * Basis(Vector3.UP, PI / 2.0), Vector3(0.0, -0.03, -0.08))
	t = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_bancnota, "transform", poza_bancnota, 0.5)
	await t.finished
	# te apleci: ochii la 12 cm deasupra capătului liniei, puțin înapoi spre tine, cu privirea în jos pe linie
	var inapoi := (loc - aproape)
	inapoi.y = 0.0
	inapoi = inapoi.normalized()
	var ochi := aproape + inapoi * 0.06 + Vector3.UP * 0.1
	t = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(jucator, "global_position", Vector3(ochi.x, loc.y, ochi.z), 0.9)
	t.tween_property(cap, "position:y", ochi.y - loc.y, 0.9)
	t.tween_property(cap, "rotation:x", atan2(-0.1, 0.06), 0.9)
	await t.finished
	# tragi: alunecă de-a lungul liniei, linia dispare sub bancnotă
	Sunet.reda(SUNET_PRIZA, Sunet.VOLUM_EFECTE, 0.05)
	var drum := departe - aproape
	drum.y = 0.0
	t = create_tween().set_parallel()
	t.tween_property(linie, "scale:x", 0.001, 0.9)
	t.tween_property(jucator, "global_position", Vector3(ochi.x, loc.y, ochi.z) + drum, 0.9)
	await t.finished
	linie.hide()
	# capul îți sare înapoi: FOV, sclipire, tremur, inima
	t = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(jucator, "global_position", loc, 0.35)
	t.tween_property(cap, "position:y", inaltime, 0.35)
	t.tween_property(cap, "rotation:x", 0.3, 0.35)
	t.tween_property(camera, "fov", fov + 14.0, 0.35)
	_sclipire()
	Sunet.reda(SUNET_INIMA, Sunet.VOLUM_EFECTE - 6.0)
	await t.finished
	# bancnota înapoi la el; capul îți revine cât încă tremură totul
	_bancnota.reparent(recuzita, true)
	var b := create_tween().set_trans(Tween.TRANS_SINE)
	b.tween_property(_bancnota, "global_transform", _repaus_bancnota, 0.6)
	t = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(cap, "rotation:x", 0.0, 0.9).set_delay(0.5)
	t.tween_property(camera, "fov", fov, 1.4).set_delay(0.3)
	get_tree().create_timer(0.25).timeout.connect(func() -> void: Sunet.reda(SUNET_SNIFF, Sunet.VOLUM_EFECTE - 2.0, 0.05))
	await _tremura(camera, 1.5)
	if t.is_running():
		await t.finished
	# te dai înapoi de unde ai venit (altfel el s-ar întoarce la locul lui prin tine), cu fața la el; el revine la blat
	var d2 := _repaus_eu.origin - start
	t = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(jucator, "global_position", start, 0.7)
	t.tween_method(func(v: float) -> void: jucator.rotation.y = v, jucator.rotation.y,
		jucator.rotation.y + angle_difference(jucator.rotation.y, atan2(-d2.x, -d2.z)), 0.7)
	t.tween_property(self, "global_position", _repaus_eu.origin, 0.8).set_delay(0.5)
	await t.finished
	camera.position = Vector3.ZERO
	jucator.seteaza_purtat(false)
	await c.opreste()


## Ecranul se albește o clipă.
func _sclipire() -> void:
	var strat := CanvasLayer.new()
	strat.layer = 8
	var alb := ColorRect.new()
	alb.color = Color(0.85, 0.92, 0.9, 0.55)
	alb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alb.set_anchors_preset(Control.PRESET_FULL_RECT)
	strat.add_child(alb)
	get_tree().current_scene.add_child(strat)
	var t := strat.create_tween()
	t.tween_property(alb, "color:a", 0.0, 0.7)
	t.tween_callback(strat.queue_free)


## Camera tremură mărunt `durata` secunde, tot mai încet.
func _tremura(camera: Camera3D, durata: float) -> void:
	var timp := 0.0
	while timp < durata:
		var k := 1.0 - timp / durata
		camera.position = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), 0.0) * 0.012 * k
		await get_tree().process_frame
		timp += get_process_delta_time()
	camera.position = Vector3.ZERO
