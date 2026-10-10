extends JocBar
## „Fast Eddie”, omul de la masa de biliard din barul „URBAN” (bar.tscn). Pariul, plecarea cu E și moartea sunt în
## JocBar. O partidă de 8-ball (reguli simplificate, de bar):
##  - tu spargi; masa e „deschisă” până bagă cineva o bilă (după spargere): atunci el are grupa ei (plinele 1–7 sau cele
##    cu dungă 9–15), celălalt cealaltă;
##  - joci cât timp bagi bile de-ale tale fără fault; fault = albă în buzunar, n-ai atins nimic sau ai atins întâi altă
##    grupă (sau pe 8 înainte de vreme) → la rând celălalt (albă băgată revine la „head spot”);
##  - 8 la final, după toate ale tale = ai câștigat; 8 băgat mai devreme sau cu fault = ai pierdut.
## Rândul tău: mouse-ul rotește tacul (Shift = fin), linia arată unde lovește albă și încotro pleacă bila atinsă; click
## stânga ținut = forța (urcă și coboară), dai drumul = lovești; click dreapta ținut = masa de sus. Băutura (`Betie`)
## mișcă puțin tacul la lovire. Rândul lui: își alege cea mai bună lovitură (bila, buzunarul, unghiul tăieturii, drumul
## liber), se teleportează în spatele albei (mersul în jurul mesei trecea prin ea: owner 10.10) și o trage cu `precizie`
## (abaterea, radiani). Fizica e în `FizicaBiliard`.
## Replicile lui Eddie sunt ale lui Claude (owner-ul le poate schimba).

signal _tras

const MODEL_BILE := preload("res://models/bile_biliard.glb")
const MODEL_TAC := preload("res://models/tac_biliard.glb")
const SCRIPT_MODEL := preload("res://scripts/model_ps2.gd")
const MATERIAL := preload("res://shaders/material_model.tres")
const SUNET_BILE := preload("res://sunete/biliard_bile.ogg")
const SUNET_MANTA := preload("res://sunete/biliard_manta.ogg")
const SUNET_BUZUNAR := preload("res://sunete/biliard_buzunar.ogg")
const SUNET_TAC := preload("res://sunete/biliard_tac.ogg")
const SUNET_CASTIG := preload("res://sunete/poker_castig.ogg")
const SUNET_PIERDERE := preload("res://sunete/poker_pierdere.ogg")
const CULORI := {1: "a18463", 2: "295555", 3: "7b383a", 4: "655269", 5: "904a40", 6: "445d46", 7: "5e363e", 8: "262d2f"}
const R := FizicaBiliard.R

## Mijlocul suprafeței de joc, la nivelul postavului; X local = lungimea mesei, Z local = lățimea.
@export var masa: Marker3D
## Cât de bine trage el (abaterea unghiului, radiani; 0,008 ≈ jumătate de grad).
@export var precizie := 0.009
@export var viteza_maxima := 4.6

var _f: FizicaBiliard
var _rng := RandomNumberGenerator.new()
var _bile: Array[Node3D] = []
var _cazute: Array[bool] = []
var _tac: Node3D
var _cam: Camera3D
var _linie: MeshInstance3D
var _linie_mesh: ImmediateMesh
var _hud: CanvasLayer
var _eticheta_sus: Label
var _eticheta_mesaj: Label
var _ajutor: Label
var _bara: ColorRect
var _bara_plina: ColorRect
var _randuri_bile: Array[HBoxContainer] = []
## Grupa fiecăruia (0 = tu, 1 = el): 0 = încă nu, 1 = plinele, 2 = cele cu dungă.
var _grup := [0, 0]
var _simuleaza := false
var _ochesti := false
var _incarci := false
var _de_sus := false
var _unghi := 0.0
var _putere := 0.0
var _putere_t := 0.0
var _cam_tinta := Transform3D.IDENTITY
var _cam_lina := false
## Pe ce latură a mesei e camera de ansamblu acum (vezi _vedere_ansamblu).
var _parte_cam := 1.0


func _init() -> void:
	nume_el = "Fast Eddie"
	marcaj_castig = "a_castigat_la_biliard"
	marcaj_pierdut = "a_pierdut_la_biliard"
	marcaj_mort = "fast_eddie_mort"
	marcaj_luat = "fast_eddie_luat"
	id_cadavru = "cadavru_fast_eddie"
	nume_cadavru = "Fast Eddie"
	indiciu_cadavru = "[E] Pick up Fast Eddie"
	replica_oferta = "Fast Eddie: Rack 'em up? Loser pays."
	replici_fara_bani = ["Fast Eddie: No cash, no game."]
	replici_reguli = ["Fast Eddie: Eight-ball. You break."]
	replici_refuz = ["Fast Eddie: Your loss."]
	replici_castigi = ["Fast Eddie: ...", "Fast Eddie: Hustled by a kid. Take it."]
	replici_pierzi = ["Fast Eddie: Thanks for the donation, sweetheart."]
	replici_parasit = ["Fast Eddie: Leaving in the middle of a game? That's a forfeit, sweetheart.", "Fast Eddie: Pay up."]


func _ready() -> void:
	super()
	_rng.randomize()
	# bilele stau pe masă și când nu jucați (în triunghi)
	_f = FizicaBiliard.new()
	_f.aseaza(_rng)
	_pune_bilele()


# ---------------------------------------------------------------- partida

func _joaca() -> bool:
	_jucator.seteaza_purtat(true)
	Stare.meniu_deschis = true
	om.privire = null
	_grup = [0, 0]
	_f.aseaza(_rng)
	for b in _bile:
		b.visible = true
	_cazute.fill(false)
	_actualizeaza_bile(0.0)
	_cam = Camera3D.new()
	_cam.fov = 60.0
	get_tree().current_scene.add_child(_cam)
	_parte_cam = 1.0
	_cam.global_transform = _vedere_ansamblu()
	_cam.make_current()
	_tac = _model(MODEL_TAC)
	masa.add_child(_tac)
	_tac.hide()
	_linie_mesh = ImmediateMesh.new()
	_linie = MeshInstance3D.new()
	_linie.mesh = _linie_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("83b3b0")
	_linie.material_override = mat
	_linie.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	masa.add_child(_linie)
	_fa_hud()
	var la_rand := 0
	var spargere := true
	var castigator := -1
	while castigator == -1 and not _parasit:
		_arata_sus()
		var curata := _grupa_terminata(la_rand)
		if la_rand == 0:
			await _lovitura_ta(spargere)
		else:
			await _lovitura_lui()
		while _f.se_misca() and not _parasit:
			await get_tree().physics_frame
		if _parasit:
			break
		_simuleaza = false
		await _asteapta(0.5)
		# ce s-a întâmplat
		var intrate := _f.intrate.duplicate()
		var alba := intrate.has(0)
		var prima := _f.prima_atinsa
		var grupa: int = _grup[la_rand]
		var fault := alba or prima == -1
		if not spargere and not fault:
			if grupa == 0:
				fault = prima == 8
			elif curata:
				fault = prima != 8
			else:
				fault = _grupa(prima) != grupa
		if intrate.has(8):
			castigator = la_rand if (curata and not fault and not spargere) else 1 - la_rand
			break
		if grupa == 0 and not fault and not spargere:
			for n: int in intrate:
				if _grupa(n) != 0:
					_grup[la_rand] = _grupa(n)
					_grup[1 - la_rand] = 3 - _grupa(n)
					break
		var ale_mele := 0
		for n: int in intrate:
			if n != 0 and _grupa(n) != 0 and (_grup[la_rand] == 0 or _grupa(n) == _grup[la_rand]):
				ale_mele += 1
		var continua := not fault and ale_mele > 0
		if alba:
			_repune_alba()
		if fault:
			_mesaj("Foul!" + (" Scratch." if alba else ""))
		elif continua:
			_mesaj("Nice." if la_rand == 0 else "%s keeps going." % nume_el)
		elif intrate.is_empty():
			_mesaj("Nothing.")
		_arata_sus()
		await _asteapta(1.1)
		spargere = false
		if not continua:
			la_rand = 1 - la_rand
			if la_rand == 0 and not om.transform.is_equal_approx(_repaus_om):
				# rândul tău: el se întoarce la locul lui, din calea camerei tale
				await _teleporteaza_om(_repaus_om)
	var castigat := castigator == 0 and not _parasit
	if not _parasit:
		_mesaj("You win!" if castigat else "%s wins." % nume_el)
		Sunet.reda(SUNET_CASTIG if castigat else SUNET_PIERDERE, Sunet.VOLUM_EFECTE - 2.0)
		await _asteapta(2.5)
	_simuleaza = false
	_ochesti = false
	_incarci = false
	_de_sus = false
	_cam_lina = false
	_hud.queue_free()
	_linie.queue_free()
	_tac.queue_free()
	_cam.queue_free()
	(_jucator.get_node("Cap/Camera3D") as Camera3D).make_current()
	om.priveste_punct = Vector3.INF
	om.lasa_mana("D", 0.3)
	om.lasa_mana("S", 0.3)
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(om, "aplecare", 0.0, 0.3)
	await t.finished
	if not om.transform.is_equal_approx(_repaus_om):
		await _teleporteaza_om(_repaus_om)
	om.privire = _jucator.get_node("Cap")
	_jucator.seteaza_purtat(false)
	Stare.meniu_deschis = false
	# bilele rămase se pun la loc în triunghi pentru partida următoare
	_f.aseaza(_rng)
	for b in _bile:
		b.visible = true
	_cazute.fill(false)
	_actualizeaza_bile(0.0)
	return castigat


func _lovitura_ta(spargere: bool) -> void:
	_mesaj("Break!" if spargere else "Your shot.")
	_ajutor.text = "Mouse: aim (Shift: fine)   Hold left click: power   Right click: top view"
	_ajutor.show()
	_unghi = 0.0 if spargere else _unghi_spre_cea_mai_apropiata(0)
	_putere = 0.0
	_bara.show()
	_tac.show()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_ochesti = true
	_cam_lina = false
	await _tras
	_ajutor.hide()
	_linie.hide()
	if _parasit:
		_bara.hide()
		_tac.hide()
		return
	var unghi := _unghi + randfn(0.0, 0.006 * Betie.nivel())
	await _loveste(unghi, _putere)
	_bara.hide()
	_misca_camera(_vedere_ansamblu(_parte_cam), true)


func _lovitura_lui() -> void:
	_mesaj("%s's shot." % nume_el)
	var alegere := _alege()
	var unghi: float = alegere[0]
	var putere: float = alegere[1]
	var dir := Vector2.from_angle(unghi)
	# se teleportează în spatele albei (mersul în jurul mesei trecea prin ea), se apleacă, mâinile pe tac
	var spate := _loc_in_spate(dir)
	# camera de pe partea cealaltă a mesei: de pe partea lui stătea cu pălăria în fața ei
	# (trecerea pe partea cealaltă = tăietură, nu alunecare: altfel camera trecea prin lampa mesei)
	var parte := -signf(spate.y) if absf(spate.y) > 0.3 else 1.0
	_misca_camera(_vedere_ansamblu(parte), parte == _parte_cam)
	_parte_cam = parte
	var spre := masa.global_basis * (_local_3d(_f.poz[0]) - _local_3d(spate))
	spre.y = 0.0
	var tinta_om := Transform3D(Basis.looking_at(-spre.normalized(), Vector3.UP),
		masa.global_transform * Vector3(spate.x, 0.0, spate.y))
	tinta_om.origin.y = _repaus_om.origin.y + (om.get_parent() as Node3D).global_position.y
	await _asteapta(0.5)
	await _teleporteaza_om((om.get_parent() as Node3D).global_transform.affine_inverse() * tinta_om)
	if _parasit:
		return
	await _asteapta(0.2)
	_tac.show()
	_pune_tacul(dir, 0.12)
	var prinza_s := Marker3D.new()
	var prinza_d := Marker3D.new()
	_tac.add_child(prinza_s)
	_tac.add_child(prinza_d)
	prinza_s.position = Vector3(0.0, 0.0, 0.3)
	prinza_d.position = Vector3(0.0, 0.0, 1.18)
	var t := create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(om, "aplecare", 0.55, 0.6)
	om.du_mana("S", prinza_s, 0.6)
	await om.du_mana("D", prinza_d, 0.6)
	om.priveste_punct = masa.global_transform * _local_3d(_f.poz[0] + dir * 0.4)
	# ochește: tacul vine de două ori înainte-înapoi, apoi lovește
	for k in 2:
		await _tween_tac(dir, 0.04, 0.35)
		await _tween_tac(dir, 0.16, 0.35)
	if not _parasit:
		unghi += randfn(0.0, precizie)
		await _loveste(unghi, putere)
		await _asteapta(0.4)
	om.priveste_punct = Vector3.INF
	t = create_tween().set_trans(Tween.TRANS_SINE)
	t.tween_property(om, "aplecare", 0.0, 0.5)
	om.lasa_mana("S", 0.5)
	om.lasa_mana("D", 0.5)
	await _asteapta(0.5)
	_tac.hide()
	prinza_s.queue_free()
	prinza_d.queue_free()


## E în timpul jocului (JocBar): dacă ochești, renunți la lovitură.
func _la_parasire() -> void:
	if _ochesti:
		_ochesti = false
		_incarci = false
		_tras.emit()


## Tacul lovește albă: înapoi cât e forța, înainte repede, apoi albă pleacă.
func _loveste(unghi: float, putere: float) -> void:
	var dir := Vector2.from_angle(unghi)
	await _tween_tac(dir, 0.04 + putere * 0.22, 0.25)
	await _tween_tac(dir, -0.005, 0.07)
	var v := lerpf(0.35, viteza_maxima, pow(putere, 1.3))
	_f.incepe_lovitura(dir * v)
	Sunet.reda_la(SUNET_TAC, masa.global_transform * _local_3d(_f.poz[0]), Sunet.VOLUM_EFECTE - 6.0 + putere * 6.0, 0.08)
	_simuleaza = true
	await _asteapta(0.25)
	_tac.hide()


func _tween_tac(dir: Vector2, inapoi: float, durata: float) -> void:
	var de_la := _tac_inapoi
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_method(func(v: float) -> void: _pune_tacul(dir, v), de_la, inapoi, durata)
	await t.finished


var _tac_inapoi := 0.12


## Tacul în spatele albei, pe direcția `dir`, la `inapoi` metri de ea, puțin ridicat la capăt.
func _pune_tacul(dir: Vector2, inapoi: float) -> void:
	_tac_inapoi = inapoi
	var c := _local_3d(_f.poz[0])
	var d3 := Vector3(dir.x, 0.0, dir.y)
	var varf := c - d3 * (R + 0.004 + inapoi)
	var inainte := (d3 * cos(0.1) + Vector3.DOWN * sin(0.1)).normalized()
	_tac.transform = Transform3D(Basis.looking_at(inainte, Vector3.UP), varf)


# ---------------------------------------------------------------- AI

## Cea mai bună lovitură pentru `cine` (1 = el; 0 = tu, pentru teste): [unghi, forță 0..1].
func _alege(cine := 1) -> Array:
	var ale_lui := _bile_de_tras(cine)
	var cea_mai_buna := -1.0
	var rez := []
	for t: int in ale_lui:
		var pt: Vector2 = _f.poz[t]
		for b: Vector2 in FizicaBiliard.buzunare():
			var gura := b.lerp(Vector2(0, 0), 0.02)
			var spre_buz := gura - pt
			var d2 := spre_buz.length()
			var dir_bila := spre_buz / d2
			if absf(b.x) < 0.01 and absf(dir_bila.y) < 0.55:
				continue  # în buzunarele de la mijloc intră doar bilele care vin cam drept spre ele
			var fantoma := pt - dir_bila * 2.0 * R
			if absf(fantoma.x) > FizicaBiliard.L / 2 - R or absf(fantoma.y) > FizicaBiliard.W / 2 - R:
				continue
			var spre_f: Vector2 = fantoma - _f.poz[0]
			var d1 := spre_f.length()
			if d1 < 0.01:
				continue
			var dir_alba := spre_f / d1
			var taietura := acos(clampf(dir_alba.dot(dir_bila), -1.0, 1.0))
			if taietura > deg_to_rad(76.0):
				continue
			if not _f.drum_liber(_f.poz[0], fantoma, [0, t]) or not _f.drum_liber(pt, gura, [t]):
				continue
			var scor := pow(cos(taietura), 2.0) / (1.0 + d1 * 0.45 + d2 * 0.8)
			if scor > cea_mai_buna:
				cea_mai_buna = scor
				var v_bila := sqrt(2.0 * (FizicaBiliard.FRECARE + 0.25) * (d2 + 0.2)) + 0.3
				var v := v_bila / maxf(cos(taietura), 0.35) * 1.08 + d1 * 0.25
				rez = [dir_alba.angle(), _putere_pentru(v)]
	if rez.is_empty():
		# nicio bilă liberă spre un buzunar: lovește-o pe cea mai apropiată, potrivit de tare (nu face fault)
		return [_unghi_spre_cea_mai_apropiata(cine), 0.42]
	return rez


func _putere_pentru(v: float) -> float:
	return clampf(pow(clampf((v - 0.35) / (viteza_maxima - 0.35), 0.0, 1.0), 1.0 / 1.3), 0.1, 0.95)


## Bilele pe care are voie să le lovească `cine` acum.
func _bile_de_tras(cine: int) -> Array[int]:
	var rez: Array[int] = []
	if _grupa_terminata(cine):
		rez.append(8)
		return rez
	for n in range(1, 16):
		if n != 8 and _f.in_joc[n] and (_grup[cine] == 0 or _grupa(n) == _grup[cine]):
			rez.append(n)
	return rez


func _unghi_spre_cea_mai_apropiata(cine: int) -> float:
	var cea := -1
	var d := INF
	for n: int in _bile_de_tras(cine):
		var dist: float = _f.poz[n].distance_to(_f.poz[0])
		if dist < d:
			d = dist
			cea = n
	if cea < 0:
		return 0.0
	return (_f.poz[cea] - _f.poz[0]).angle()


func _grupa(n: int) -> int:
	if n >= 1 and n <= 7:
		return 1
	if n >= 9 and n <= 15:
		return 2
	return 0


func _grupa_terminata(cine: int) -> bool:
	if _grup[cine] == 0:
		return false
	for n in range(1, 16):
		if n != 8 and _f.in_joc[n] and _grupa(n) == _grup[cine]:
			return false
	return true


func _repune_alba() -> void:
	var p := Vector2(-FizicaBiliard.L / 4, 0.0)
	for k in 40:
		var liber := true
		for j in range(1, 16):
			if _f.in_joc[j] and _f.poz[j].distance_to(p) < 2.0 * R + 0.002:
				liber = false
		if liber:
			break
		p.x -= 0.02
	_f.poz[0] = p
	_f.vit[0] = Vector2.ZERO
	_f.in_joc[0] = true
	_cazute[0] = false
	_bile[0].visible = true
	_bile[0].position = _local_3d(p)


## Unde stă el ca să tragă pe `dir`: în spatele albei, dar în afara mesei.
func _loc_in_spate(dir: Vector2) -> Vector2:
	var c: Vector2 = _f.poz[0]
	var ex := FizicaBiliard.L / 2 + 0.36
	var ey := FizicaBiliard.W / 2 + 0.36
	var t := 0.8
	while t < 3.0:
		var p := c - dir * t
		if absf(p.x) > ex or absf(p.y) > ey:
			return p
		t += 0.05
	return c - dir * 3.0


# ---------------------------------------------------------------- în fiecare cadru

func _physics_process(delta: float) -> void:
	if not _simuleaza or _f == null:
		return
	_f.avanseaza(delta)
	_actualizeaza_bile(delta)
	var redate := 0
	for s: Array in _f.sunete:
		if redate >= 3:
			break
		var viteza: float = s[1]
		if viteza < 0.05 and int(s[2]) != 2:
			continue
		var unde := masa.global_transform * _local_3d(s[0])
		match int(s[2]):
			0:
				Sunet.reda_la(SUNET_BILE, unde, Sunet.VOLUM_EFECTE - 14.0 + clampf(viteza * 5.0, 0.0, 13.0), 0.12)
			1:
				Sunet.reda_la(SUNET_MANTA, unde, Sunet.VOLUM_EFECTE - 14.0 + clampf(viteza * 5.0, 0.0, 11.0), 0.1)
			2:
				Sunet.reda_la(SUNET_BUZUNAR, unde, Sunet.VOLUM_EFECTE - 3.0, 0.1)
		redate += 1
	_f.sunete.clear()


func _process(delta: float) -> void:
	if _cam and _cam_lina:
		_cam.global_transform = _cam.global_transform.interpolate_with(_cam_tinta, clampf(delta * 3.0, 0.0, 1.0))
	if _cam:
		# vederea de sus: lampa lungă de deasupra mesei (cu abajururile) acoperea mijlocul mesei; camera nu vede ce e
		# mai aproape de SUS_TAIE (lampa, lanțurile), doar masa de sub ea
		_cam.near = SUS_TAIE if _ochesti and _de_sus else 0.05
	if not _ochesti:
		return
	if _incarci:
		_putere_t += delta
		_putere = pingpong(_putere_t / 0.9, 1.0)
	_bara_plina.size.x = (_bara.size.x - 2.0) * _putere
	var dir := Vector2.from_angle(_unghi)
	_pune_tacul(dir, 0.03 + _putere * 0.22)
	_deseneaza_linia(dir)
	if _de_sus:
		_cam.global_transform = _vedere_de_sus()
	else:
		var c := _local_3d(_f.poz[0])
		var d3 := Vector3(dir.x, 0.0, dir.y)
		var poz := masa.global_transform * (c - d3 * 0.85 + Vector3.UP * 0.36)
		var spre := masa.global_transform * (c + d3 * 0.55)
		_cam.global_transform = Transform3D(Basis.looking_at(spre - poz, Vector3.UP), poz)


func _input(event: InputEvent) -> void:
	super(event)  # E = pleci (JocBar)
	if not _ochesti:
		return
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		var fin := Input.is_key_pressed(KEY_SHIFT)
		_unghi -= m.screen_relative.x * (0.0005 if fin else 0.0025) * (-1.0 if _de_sus else 1.0)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var b := event as InputEventMouseButton
		if b.button_index == MOUSE_BUTTON_LEFT:
			if b.pressed:
				_incarci = true
				_putere_t = 0.0
			elif _incarci:
				_incarci = false
				if _putere > 0.02:
					_ochesti = false
					_tras.emit()
			get_viewport().set_input_as_handled()
		elif b.button_index == MOUSE_BUTTON_RIGHT:
			_de_sus = b.pressed
			get_viewport().set_input_as_handled()


func _actualizeaza_bile(delta: float) -> void:
	for i in 16:
		var b := _bile[i]
		if not _f.in_joc[i]:
			if not _cazute[i]:
				_cazute[i] = true
				_cade(i)
			continue
		var nou := _local_3d(_f.poz[i])
		var d := nou - b.position
		d.y = 0.0
		if d.length() > 0.00001:
			# se rostogolește: axa = sus × direcția, unghiul = drumul / rază
			var axa := Vector3.UP.cross(d).normalized()
			b.basis = (Basis(axa, d.length() / R) * b.basis).orthonormalized()
		b.position = nou


## O bilă intrată cade în buzunarul cel mai apropiat și dispare.
func _cade(i: int) -> void:
	var b := _bile[i]
	var cel := Vector2.ZERO
	var d := INF
	for p: Vector2 in FizicaBiliard.buzunare():
		if p.distance_to(_f.poz[i]) < d:
			d = p.distance_to(_f.poz[i])
			cel = p
	var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(b, "position", _local_3d(cel) + Vector3.DOWN * 0.12, 0.25)
	t.tween_callback(func() -> void: b.visible = false)
	_arata_sus()


func _deseneaza_linia(dir: Vector2) -> void:
	_linie.show()
	_linie_mesh.clear_surfaces()
	_linie_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var contact := _f.primul_contact(dir)
	var c: Vector2 = _f.poz[0]
	var unde: Vector2 = contact[1]
	# linia punctată până la contact
	var lung := c.distance_to(unde)
	var s := 0.0
	while s < lung:
		_linie_mesh.surface_add_vertex(_local_3d(c + dir * s, 0.002 - R))
		_linie_mesh.surface_add_vertex(_local_3d(c + dir * minf(s + 0.04, lung), 0.002 - R))
		s += 0.07
	if int(contact[0]) >= 0:
		# cercul „bilei fantomă” și direcția în care pleacă bila atinsă
		for k in 16:
			var a := TAU * k / 16.0
			var b := TAU * (k + 1) / 16.0
			_linie_mesh.surface_add_vertex(_local_3d(unde + Vector2.from_angle(a) * R, 0.002 - R))
			_linie_mesh.surface_add_vertex(_local_3d(unde + Vector2.from_angle(b) * R, 0.002 - R))
		var tinta: Vector2 = _f.poz[int(contact[0])]
		var pleaca := (tinta - unde).normalized()
		_linie_mesh.surface_add_vertex(_local_3d(tinta, 0.002 - R))
		_linie_mesh.surface_add_vertex(_local_3d(tinta + pleaca * 0.22, 0.002 - R))
	_linie_mesh.surface_end()


# ---------------------------------------------------------------- unelte

## Un punct de pe postav în coordonatele mesei (x, înălțimea centrului bilei, y).
func _local_3d(p: Vector2, peste := 0.0) -> Vector3:
	return Vector3(p.x, R + peste, p.y)


func _pune_bilele() -> void:
	var toate := MODEL_BILE.instantiate() as Node3D
	toate.set_script(SCRIPT_MODEL)
	toate.set("material", MATERIAL)
	toate.set("umbre", false)
	masa.add_child(toate)
	_bile.resize(16)
	_cazute.resize(16)
	for i in 16:
		var b := toate.find_child("Bila%d" % i, true, false) as Node3D
		b.reparent(masa, false)
		b.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, 0.0)
		_bile[i] = b
		_cazute[i] = false
	_actualizeaza_bile(0.0)


## Masa de pe o latură lungă: `parte` 1 = partea obișnuită, -1 = cea de vizavi (Eddie trage de pe partea obișnuită).
func _vedere_ansamblu(parte := 1.0) -> Transform3D:
	var poz := masa.global_transform * Vector3(-0.35 * parte, 1.45, 1.55 * parte)
	var spre := masa.global_position
	return Transform3D(Basis.looking_at(spre - poz, Vector3.UP), poz)


## Vederea de sus (click dreapta cât ochești): cât de sus deasupra postavului stă camera și de la ce distanță începe să
## vadă (lampa mesei e la ~0,9–1,2 m deasupra postavului: rămâne mai aproape de cameră, deci nu se vede).
const SUS_INALTIME := 1.75
const SUS_TAIE := 0.97


func _vedere_de_sus() -> Transform3D:
	var poz := masa.global_position + Vector3.UP * SUS_INALTIME
	return Transform3D(Basis.looking_at(Vector3.DOWN, masa.global_basis.z), poz)


func _misca_camera(tinta: Transform3D, lin: bool) -> void:
	_cam_tinta = tinta
	_cam_lina = lin
	if not lin:
		_cam.global_transform = tinta


func _model(scena: PackedScene) -> Node3D:
	var n := scena.instantiate() as Node3D
	n.set_script(SCRIPT_MODEL)
	n.set("material", MATERIAL)
	n.set("umbre", false)
	return n


func _fa_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 7
	add_child(_hud)
	var radacina := Control.new()
	radacina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	radacina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radacina.theme = TemaMeniu.creeaza()
	_hud.add_child(radacina)
	var sus := VBoxContainer.new()
	sus.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	sus.offset_top = 5
	sus.alignment = BoxContainer.ALIGNMENT_CENTER
	sus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radacina.add_child(sus)
	_eticheta_sus = _eticheta(sus, 10, Color("83b3b0"))
	_randuri_bile.clear()
	var randuri := HBoxContainer.new()
	randuri.alignment = BoxContainer.ALIGNMENT_CENTER
	randuri.add_theme_constant_override("separation", 30)
	randuri.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sus.add_child(randuri)
	for k in 2:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 2)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		randuri.add_child(r)
		_randuri_bile.append(r)
	_eticheta_mesaj = _eticheta(sus, 10, Color("61a19f"))
	_ajutor = _eticheta(radacina, 8, Color("7e8d87"))
	_ajutor.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_ajutor.offset_top = -16
	_ajutor.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bara = ColorRect.new()
	_bara.color = Color("262d2f")
	_bara.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_bara.offset_left = 10
	_bara.offset_top = -30
	_bara.offset_right = 90
	_bara.offset_bottom = -24
	_bara.mouse_filter = Control.MOUSE_FILTER_IGNORE
	radacina.add_child(_bara)
	_bara_plina = ColorRect.new()
	_bara_plina.color = Color("904a40")
	_bara_plina.position = Vector2(1, 1)
	_bara_plina.size = Vector2(0, 4)
	_bara.add_child(_bara_plina)
	var scris := _eticheta(_bara, 8, Color("83b3b0"))
	scris.text = "POWER"
	scris.position = Vector2(0, -12)
	_bara.hide()
	_arata_sus()


func _arata_sus() -> void:
	if _eticheta_sus == null or not is_instance_valid(_eticheta_sus):
		return
	var nume := ["", "Solids", "Stripes"]
	_eticheta_sus.text = "Open table" if _grup[0] == 0 else "You: %s   -   %s: %s" % [nume[_grup[0]], nume_el, nume[_grup[1]]]
	for k in 2:
		var r := _randuri_bile[k]
		for c in r.get_children():
			c.queue_free()
		if _grup[k] == 0:
			continue
		for n: int in (range(1, 8) if _grup[k] == 1 else range(9, 16)):
			if _f.in_joc[n]:
				var p := ColorRect.new()
				p.custom_minimum_size = Vector2(5, 5)
				p.color = Color(String(CULORI[n if n < 8 else n - 8]))
				p.mouse_filter = Control.MOUSE_FILTER_IGNORE
				r.add_child(p)


func _eticheta(parinte: Control, marime: int, cul: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", marime)
	l.add_theme_color_override("font_color", cul)
	l.add_theme_color_override("font_outline_color", Color("262d2f"))
	l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parinte.add_child(l)
	return l


func _mesaj(text: String) -> void:
	if _eticheta_mesaj and is_instance_valid(_eticheta_mesaj):
		_eticheta_mesaj.text = text

