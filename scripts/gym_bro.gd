extends Interactabil
## Gym Bro, „Mr. Olympia” de la sala „Iron Pump” (sala.tscn, owner 25.11): uriaș, culcat pe bancă, împinge 500 kg
## (bara_500.glb, câte 240 kg de discuri pe fiecare parte). Modelul (gym_bro.glb, OmLaMasa) e făcut în picioare și
## culcat din cod (`om.rotation.x` = -90°); palmele stau mereu pe bară (IK), deci urmăresc bara oriunde o duce.
## Ciclul: pauză → scoate bara de pe suporturi → 3–6 împinse ușor (icnește jos) → o pune la loc, cu zăngănit.
## La E: își termină împinsa, pune bara pe suporturi, se uită la tine și vorbește: prima dată `replici`, apoi
## `replici_dupa` (ale owner-ului: nu le corecta).

@export var om: OmLaMasa
@export var bara: Node3D
## Unde stă bara (global): pe suporturi, sus (brațele întinse) și jos, pe piept.
@export var bara_suport := Vector3(3.3, 1.19, -5.66)
@export var bara_sus := Vector3(3.3, 1.29, -5.28)
@export var bara_jos := Vector3(3.3, 0.98, -5.16)
## Cât de lată e priza (de la mijlocul barei).
@export var priza := 0.42
@export var pauza := Vector2(2.5, 5.0)
@export var marcaj_dupa := "a_vorbit_cu_gym_bro"
@export_multiline var replici_dupa: PackedStringArray = ["Gym Bro: You mirin' brah?"]

const SUNETE_ICNET := [preload("res://sunete/om_icnit_1.ogg"), preload("res://sunete/om_icnit_2.ogg")]
const SUNET_BARA := preload("res://sunete/bara_pusa.ogg")

var _vrea_vorba := false
var _pe_suport := true
var _in_curs := false


func _ready() -> void:
	indiciu = "[E] Talk to Gym Bro"
	if replici.is_empty():
		replici = PackedStringArray(["Gym Bro: Hey, do you need some help?", "You: Are you a pedophile?", "Gym Bro: What the fuck?"])
	om.rotation.x = -PI / 2.0
	bara.global_position = bara_suport
	await get_tree().process_frame
	for s in [-1.0, 1.0]:
		var mana := Node3D.new()
		bara.add_child(mana)
		mana.position = Vector3(s * priza, 0.0, 0.0)
		om.du_mana("D" if s < 0.0 else "S", mana, 0.05)
	_ciclu()


func poate_fi_folosit() -> bool:
	return activ and not _in_curs


func interactioneaza() -> void:
	if not poate_fi_folosit():
		return
	_in_curs = true
	folosit.emit()
	_vrea_vorba = true
	var c := Cutscena.porneste(self)
	# își termină împinsa și pune bara jos
	while not _pe_suport:
		await get_tree().process_frame
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	var cap: Node3D = jucator.get_node("Cap")
	om.privire = cap
	await c.priveste(om.gura() + Vector3.UP * 0.05, 0.5)
	var prima := not Stare.e_marcat(marcaj_dupa)
	Dialog.spune(replici if prima else replici_dupa)
	if Dialog.activ:
		await Dialog.terminat
	if prima:
		Stare.marcheaza(marcaj_dupa)
	om.privire = null
	await c.opreste()
	_vrea_vorba = false
	_in_curs = false


func _ciclu() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(pauza.x, pauza.y)).timeout
		while _vrea_vorba:
			await get_tree().process_frame
		_pe_suport = false
		await _bara_la(bara_sus, 0.7)
		for i in randi_range(3, 6):
			await _bara_la(bara_jos, 1.2)
			Sunet.reda_la(SUNETE_ICNET.pick_random(), om.gura(), Sunet.VOLUM_EFECTE - 9.0, 0.15, 0.7)
			await _bara_la(bara_sus, 0.8)
			if _vrea_vorba:
				break
		await _bara_la(bara_suport, 0.6)
		Sunet.reda_la(SUNET_BARA, bara.global_position, Sunet.VOLUM_EFECTE - 1.0, 0.1, 0.8)
		_pe_suport = true


func _bara_la(unde: Vector3, durata: float) -> void:
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(bara, "global_position", unde, durata)
	await t.finished
