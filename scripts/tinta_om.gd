class_name TintaOm
extends StaticBody3D
## Hitbox-ul unui OmLaMasa (jucătorii de la masa de poker): o cutie pe trunchi (cât bucata `Corp` din model) și o sferă
## pe cap (CapTinta). Te oprește când mergi și oprește gloanțele (pistol, arme, Fireball, explozii): omul nu moare,
## doar tresare (OmLaMasa.tresare) și se aude glonțul în carne.
## Pune-l din cod: `TintaOm.adauga(om)`.

const SUNET_CARNE := preload("res://sunete/cutit_carne.ogg")

var om: OmLaMasa


static func adauga(om_la_masa: OmLaMasa) -> TintaOm:
	var corp := om_la_masa.find_child("Corp", true, false) as MeshInstance3D
	if corp == null:
		return null
	var t := TintaOm.new()
	t.name = "Hitbox"
	t.om = om_la_masa
	om_la_masa.add_child(t)
	# cutia trunchiului, în coordonatele omului (modelul nu e rotit față de el)
	var cutie: AABB = om_la_masa.global_transform.affine_inverse() * corp.global_transform * corp.get_aabb()
	var forma := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = cutie.size
	forma.shape = box
	forma.position = cutie.get_center()
	t.add_child(forma)
	CapTinta.adauga(t, om_la_masa.find_child("Cap", true, false) as Node3D)
	return t


func impuscat(directie: Vector3, punct := Vector3.ZERO) -> void:
	om.tresare(directie)
	Sunet.reda_la(SUNET_CARNE, punct if punct != Vector3.ZERO else global_position, Sunet.VOLUM_EFECTE, 0.1)


func lovit_de_foc(directie: Vector3, punct := Vector3.ZERO) -> void:
	impuscat(directie, punct)
