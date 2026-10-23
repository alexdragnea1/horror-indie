class_name OmOmorabil
extends Node
## Face un OmLaMasa omorâbil (owner 23.10: boschetarii de la grătarul de pe recepția motelului). Primul glonț
## (pistol, arme, Fireball, explozii; hitbox-ul TintaOm de pe trunchi și cap) îl omoară: cade moale (Ragdoll), ca
## Big Mike de la bar. Marcajul `marcaj` ține minte moartea: la Continue e iar cadavru, căzut pe loc.
##   OmOmorabil.adauga(om, "boschetarul_de_la_gratar_a_murit")
## Cadavrul nu se ia (pe acoperiș nu se ajunge).

const SUNET_CADERE := preload("res://sunete/corp_cazut.ogg")

## Cât de tare îl împinge glonțul.
const FORTA_GLONT := 9.0

var om: OmLaMasa
var marcaj := ""
var mort := false

var _cadavru: Ragdoll


static func adauga(om_la_masa: OmLaMasa, marcaj_mort: String) -> OmOmorabil:
	var o := OmOmorabil.new()
	o.name = "Omorabil"
	o.om = om_la_masa
	o.marcaj = marcaj_mort
	om_la_masa.add_child(o)
	return o


func _ready() -> void:
	# după _ready-ul omului (îi trebuie bucata `Corp` din model)
	await get_tree().process_frame
	if Stare.e_marcat(marcaj):
		_moare(Vector3.ZERO, 0.0)
		return
	var tinta := TintaOm.adauga(om)
	if tinta:
		tinta.stapan = self


## Hitbox-ul (TintaOm.stapan): orice glonț îl omoară.
func lovit_om(directie: Vector3, _punct: Vector3) -> bool:
	if mort:
		return true
	_moare(directie, FORTA_GLONT)
	return true


func _moare(directie: Vector3, forta: float) -> void:
	mort = true
	Stare.marcheaza(marcaj)
	om.set_process(false)
	om.privire = null
	var hitbox := om.get_node_or_null("Hitbox")
	if hitbox:
		hitbox.queue_free()
	var spate := -om.global_basis.z  # modelele privesc spre +Z
	var orizontal := Vector3(directie.x, 0.0, directie.z).normalized()
	var impuls := (spate * 0.7 + orizontal * 0.3 + Vector3.UP * 0.15).normalized() * forta
	_cadavru = Ragdoll.din_model(om.get_node("Model"), impuls, [], 30.0)
	if forta > 0.0:
		await get_tree().create_timer(0.45).timeout
		if is_instance_valid(_cadavru):
			Sunet.reda_la(SUNET_CADERE, _cadavru.centru(), Sunet.VOLUM_EFECTE, 0.05)
