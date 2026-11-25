class_name Sala
extends Node
## Sala de forță „Iron Pump” (sala.tscn, owner 25.11), unde te trimite Mom după vrăjitor („Go to the gym.”):
##  - când cobori din autobuz în fața ei primești sarcina „Work out.” (`sarcina`), până faci primul set
##    (exercitiu_sala.gd pune `marcaj_antrenat`);
##  - day pass-ul ($5, de la fata de la recepție, receptionista_sala.gd): până îl ai, în golul turnichetului e un
##    perete invizibil (`turnichet`). Ține o zi: e pus cu numărul nopții (`marcaj_nopti`), deci după somn îl iei iar.

const MARCAJ_PASS := "day_pass_sala"
const MARCAJ_NOPTI := "nopti_dupa_final"

## Peretele invizibil din golul turnichetului (Interactabil: „You: I need a day pass first.”).
@export var turnichet: Interactabil
@export var marcaj_venit := "vrea_la_sala"
@export var marcaj_antrenat := "s_a_antrenat"
@export var sarcina := "Work out."
## Cât după ce s-a luminat ecranul apare sarcina (secunde; autobuzul pleacă între timp).
@export var intarziere_sarcina := 2.5


static func are_pass() -> bool:
	return Stare.e_marcat(MARCAJ_PASS) \
		and int(Stare.valoare_marcaj(MARCAJ_PASS, -1)) == int(Stare.valoare_marcaj(MARCAJ_NOPTI, 0))


static func da_pass() -> void:
	Stare.marcheaza(MARCAJ_PASS, int(Stare.valoare_marcaj(MARCAJ_NOPTI, 0)))


func _ready() -> void:
	add_to_group("sala")
	deschide(are_pass())
	if not Stare.e_marcat(marcaj_venit) or Stare.e_marcat(marcaj_antrenat):
		return
	await get_tree().process_frame
	while Tranzitie.activa:
		await get_tree().process_frame
	await get_tree().create_timer(intarziere_sarcina).timeout
	if not Stare.e_marcat(marcaj_antrenat) and Stare.sarcina != sarcina:
		Stare.seteaza_sarcina(sarcina)


## Deschide (sau închide) trecerea prin turnichet.
func deschide(da := true) -> void:
	if not is_instance_valid(turnichet):
		return
	turnichet.activ = not da
	for c in turnichet.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred("disabled", da)
