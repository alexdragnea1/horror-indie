extends Node3D
## Perechea din spatele blocului (scenes/pereche.tscn, în afara_bloc.tscn, la ușa garajului cu bec). Comedie, fără
## nimic obscen: sunt îmbrăcați complet; ea se sprijină cu mâinile de ușa garajului, el e în spatele ei, iar tabla
## ușii bufnește în ritm (`garaj_bufnit`) peste gâfâitul lor (`Gafait`, buclă 3D). Când te apropii (`raza_prins`)
## îngheață, se uită la tine, „gasp”, apoi o iau la fugă pe lângă garaje, departe de tine (el își trage fermoarul din
## fugă, cu o mână la pantaloni) și se topesc în ceață, ca omul din pădure. O singură dată (`marcaj`): la Continue
## sau la a doua trecere nu mai sunt acolo.
## Nodul privește spre garaj (+Z local = spre ușă); `Ea` stă în origine, `El` în spatele ei.
## Modelele (pereche_ea.glb / pereche_el.glb, `afara.py` → `pereche`) au `Corp` (originea în bazin) → `Cap`, `BratD/S`
## → `AntebratD/S`, și `PiciorD/S` (originea în șold).

@export var marcaj := "perechea_a_fugit"
## Cât de aproape trebuie să vii ca să te vadă și să fugă (m).
@export var raza_prins := 6.5
## De la ce distanță se aud bufniturile din ușa garajului (m): mai departe (în fața blocului) e liniște.
@export var raza_auzit := 17.0
## Ritmul (bufnituri pe secundă).
@export var ritm := 1.7
## Cât de aplecată e ea în față (grade).
@export var aplecare := 34.0
@export_group("Fuga")
@export var viteza := 5.0
@export var durata_fuga := 4.2
## Cât de departe de ușa garajului fug (m, spre tine), ca să nu treacă prin garaje.
@export var departare_usa := 1.6
@export_group("Sunete")
@export var bufnit: AudioStream
@export var gasp_el: AudioStream
@export var gasp_ea: AudioStream
@export var fermoar: AudioStream
@export var pasi: Array[AudioStream] = []

enum { IMPREUNA, INGHETAT, FUG, PLECAT }
var _stare := IMPREUNA
var _timp := 0.0
var _faza := 0.0
var _ultimul_pas := 0
var _directie := Vector3.RIGHT
var _el_spre := 0.0  # unde se oprește el în spatele ei

@onready var _ea: Node3D = $Ea
@onready var _el: Node3D = $El
@onready var _gafait: AudioStreamPlayer3D = $Gafait


class Om:
	var nod: Node3D
	var model: Node3D
	var corp: Node3D
	var cap: Node3D
	var brate: Array[Node3D] = []
	var antebrate: Array[Node3D] = []
	var picioare: Array[Node3D] = []
	var corp_repaus: Basis
	var brate_repaus: Array[Basis] = []

	func _init(n: Node3D) -> void:
		nod = n
		model = n.get_node("Model")
		corp = model.find_child("Corp") as Node3D
		cap = model.find_child("Cap") as Node3D
		for l in ["D", "S"]:
			brate.append(model.find_child("Brat" + l) as Node3D)
			antebrate.append(model.find_child("Antebrat" + l) as Node3D)
			picioare.append(model.find_child("Picior" + l) as Node3D)
		corp_repaus = corp.basis
		for b in brate:
			brate_repaus.append(b.basis)


var _o_ea: Om
var _o_el: Om


func _ready() -> void:
	if Stare.e_marcat(marcaj):
		queue_free()
		return
	_o_ea = Om.new(_ea)
	_o_el = Om.new(_el)
	_el_spre = _el.position.z
	_gafait.volume_db = -80.0
	_gafait.play()


func _process(delta: float) -> void:
	_timp += delta
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	match _stare:
		IMPREUNA:
			_impreuna(delta, jucator)
			if jucator and _distanta(jucator) < raza_prins:
				_prinsi(jucator)
		INGHETAT:
			if jucator:
				_priveste(_o_ea, jucator, delta)
				_priveste(_o_el, jucator, delta)
		FUG:
			_alearga(delta)


func _distanta(jucator: Node3D) -> float:
	return Vector2(jucator.global_position.x - global_position.x, jucator.global_position.z - global_position.z).length()


## Ritmul: el vine în față și se trage înapoi, ea se leagănă spre ușă; la fiecare împinsă bufnește tabla.
## Fără jucător (curtea ca fundal în meniul principal) tace.
func _impreuna(delta: float, jucator: Node3D) -> void:
	var inainte := _faza
	_faza += delta * ritm * TAU
	var u := sin(_faza)
	var impins := maxf(u, 0.0)
	_o_el.model.position.z = 0.05 * u
	_o_el.corp.basis = _o_el.corp_repaus.rotated(Vector3.RIGHT, deg_to_rad(4.0 + 3.0 * u))
	_o_el.cap.rotation = Vector3(deg_to_rad(-12.0 - 6.0 * impins), sin(_timp * 0.5) * 0.2, 0.0)
	_o_ea.model.position.z = 0.025 * impins
	_o_ea.corp.basis = _o_ea.corp_repaus.rotated(Vector3.RIGHT, deg_to_rad(aplecare + 2.5 * u))
	_o_ea.cap.rotation = Vector3(deg_to_rad(-25.0 + 10.0 * impins), sin(_timp * 0.7) * 0.25, 0.0)
	var aproape := jucator != null and _distanta(jucator) < raza_auzit
	_gafait.volume_db = lerpf(_gafait.volume_db, -6.0 if aproape else -80.0, minf(delta * 2.0, 1.0))
	# o bufnitură pe fiecare împinsă (când sinusul trece prin vârf)
	if aproape and fmod(inainte, TAU) < PI * 0.5 and fmod(_faza, TAU) >= PI * 0.5:
		Sunet.reda_la(bufnit, global_position + global_basis.z * 0.7 + Vector3.UP * 1.3, -4.0, 0.08)


func _prinsi(jucator: Node3D) -> void:
	_stare = INGHETAT
	Stare.marcheaza(marcaj)
	_gafait.stop()
	_o_el.model.position.z = 0.0
	Sunet.reda_la(gasp_ea, _o_ea.cap.global_position, 0.0, 0.05)
	await get_tree().create_timer(0.15).timeout
	Sunet.reda_la(gasp_el, _o_el.cap.global_position, -2.0, 0.05)
	# ea se îndreaptă de spate, el face un pas înapoi
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_o_ea.corp, "basis", _o_ea.corp_repaus, 0.35)
	t.tween_property(_o_el.nod, "position:z", _el_spre - 0.35, 0.35)
	await get_tree().create_timer(0.75).timeout
	_fugi(jucator)


## Capul se întoarce spre tine (cât poate).
func _priveste(om: Om, jucator: Node3D, delta: float) -> void:
	var spre := om.cap.global_position.direction_to(jucator.global_position + Vector3.UP * 1.5)
	var local := om.nod.global_basis.inverse() * spre
	var yaw := clampf(atan2(local.x, local.z), -1.4, 1.4)
	var pitch := clampf(-asin(clampf(local.y, -1.0, 1.0)), -0.5, 0.4)
	om.cap.rotation.y = lerp_angle(om.cap.rotation.y, yaw, minf(delta * 8.0, 1.0))
	om.cap.rotation.x = lerpf(om.cap.rotation.x, pitch, minf(delta * 8.0, 1.0))


func _fugi(jucator: Node3D) -> void:
	_stare = FUG
	_timp = 0.0
	# de-a lungul garajelor (axa X a nodului), în partea opusă ție; un pas înapoi de la uși, ca să nu treacă prin ele
	var dreapta := global_basis.x
	dreapta.y = 0.0
	dreapta = dreapta.normalized()
	var spre_tine := jucator.global_position - global_position
	var semn := -signf(spre_tine.dot(dreapta))
	if semn == 0.0:
		semn = 1.0
	_directie = dreapta * semn
	var unghi := atan2(_directie.x, _directie.z)
	for om in [_o_ea, _o_el]:
		om.cap.rotation = Vector3.ZERO
		var t := create_tween().set_parallel()
		t.tween_property(om.nod, "global_rotation:y", unghi, 0.25)
		t.tween_property(om.nod, "global_position", om.nod.global_position - global_basis.z * departare_usa, 0.45)
		t.tween_property(om.corp, "basis", om.corp_repaus.rotated(Vector3.RIGHT, deg_to_rad(16.0)), 0.3)
	# el își trage fermoarul din fugă
	await get_tree().create_timer(0.45).timeout
	if is_inside_tree():
		Sunet.reda_la(fermoar, _o_el.corp.global_position, 0.0, 0.05)


## Fuga: picioarele se balansează, ea dă din brațe, el aleargă cu mâna dreaptă la pantaloni; el e cu un pas în urmă.
func _alearga(delta: float) -> void:
	var accel := clampf((_timp - 0.3) / 0.5, 0.0, 1.0)
	_faza += delta * TAU * 3.0
	for i in 2:
		var om: Om = [_o_ea, _o_el][i]
		var faza := _faza + i * 1.3
		var u := sin(faza)
		if _timp > 0.45 + i * 0.25:
			om.nod.global_position += _directie * viteza * accel * delta
		om.picioare[0].rotation.x = deg_to_rad(38.0) * u * accel
		om.picioare[1].rotation.x = -deg_to_rad(38.0) * u * accel
		om.model.position.y = absf(cos(faza)) * 0.06 * accel
		if om == _o_ea:
			# brațele de pe ușă în jos, apoi dau din ele
			for k in 2:
				var semn := 1.0 if k == 0 else -1.0
				om.brate[k].basis = om.brate_repaus[k].rotated(Vector3.RIGHT, deg_to_rad(105.0) * minf(_timp / 0.3, 1.0)
					+ deg_to_rad(35.0) * u * semn * accel)
		else:
			# mâna stângă dă din ea, dreapta ține pantalonii
			om.brate[1].basis = om.brate_repaus[1].rotated(Vector3.RIGHT, deg_to_rad(-40.0) * u * accel)
		var pas := int(faza / PI)
		if pas != _ultimul_pas and i == 0 and accel > 0.5:
			_ultimul_pas = pas
			Sunet.reda_la(pasi.pick_random(), om.nod.global_position, Sunet.VOLUM_PASI, 0.1)
	if _timp > durata_fuga:
		# se topesc în ceață (pe pixeli, ca celelalte modele PS2)
		_stare = PLECAT
		var topeste := func(v: float) -> void:
			ModelPS2.disparitie(_ea, v)
			ModelPS2.disparitie(_el, v)
		var t := create_tween()
		t.tween_method(topeste, 0.0, 1.0, 0.8)
		t.tween_callback(queue_free)
		set_process(false)
