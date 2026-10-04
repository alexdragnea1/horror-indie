class_name ZiBloc
extends Node
## Curtea blocului dimineața (`marcaj_dimineata`, pus de pat.gd după somn): cer alb de ceață, lumină de zi rece,
## felinarele, becul scării și geamurile aprinse se sting, sperieturile de noapte tac. Ceața rămâne (owner-ul: „tot
## mai e ceață”). Dacă ai ieșit pe ușa de la intrare a casei (`din_casa`, pus de acasa_noaptea.gd), te pune în fața
## scării, cu spatele la bloc. Fără `Jucator` (fundalul din meniul principal) e mereu noapte.

## Adevărat de la deschiderea ușii de la intrare până te pune curtea la scară.
static var din_casa := false

@export var marcaj_dimineata := "e_dimineata"
@export var mediu: WorldEnvironment
## `Luna` din scenă: ziua e soarele (aceeași direcție, altă culoare și putere).
@export var soare: DirectionalLight3D
## Stâlpii cu felinare (`stalp.tscn`: `Lumina` cu `lumina_palpaie.gd`, `Model/Sticla`).
@export var stalpi: Array[Node3D] = []
## Modelele blocurilor (bucata `Lumini` = geamurile aprinse).
@export var blocuri: Array[Node3D] = []
@export var bec_scara: Light3D
## Ce tace ziua (sperieturile, fantoma).
@export var de_oprit: Array[Node] = []
## Unde apari când ieși din bloc și încotro te uiți (PI = spre stradă).
@export var loc_iesire := Vector3(0.0, 0.1, 2.9)
@export var unghi_iesire := PI

@export_group("Culori zi")
@export var cer := Color(0.66, 0.68, 0.7)
@export var ambient := Color(0.78, 0.8, 0.84)
@export var ambient_energie := 0.85
@export var ceata := Color(0.64, 0.66, 0.69)
@export var ceata_densitate := 0.045
@export var ceata_volum := Color(0.86, 0.87, 0.89)
@export var ceata_volum_densitate := 0.012
@export var soare_culoare := Color(1.0, 0.95, 0.88)
@export var soare_energie := 0.9


func _ready() -> void:
	var jucator := get_parent().get_node_or_null("Jucator") as Node3D
	if jucator == null or not Stare.e_marcat(marcaj_dimineata):
		din_casa = false
		return
	_fa_zi()
	await get_tree().process_frame
	if din_casa:
		din_casa = false
		jucator.global_position = loc_iesire
		jucator.rotation.y = unghi_iesire
		jucator.get_node("Cap").rotation.x = 0.0


func _fa_zi() -> void:
	if mediu:
		# o copie: resursa e comună cu scena din meniul principal, care trebuie să rămână noapte
		var env := mediu.environment.duplicate() as Environment
		env.background_color = cer
		env.ambient_light_color = ambient
		env.ambient_light_energy = ambient_energie
		env.fog_light_color = ceata
		env.fog_density = ceata_densitate
		env.volumetric_fog_albedo = ceata_volum
		env.volumetric_fog_density = ceata_volum_densitate
		mediu.environment = env
	if soare:
		soare.light_color = soare_culoare
		soare.light_energy = soare_energie
		soare.light_volumetric_fog_energy = 0.4
	for stalp in stalpi:
		var lumina := stalp.get_node_or_null("Lumina") as Light3D
		if lumina:
			lumina.set_process(false)
			lumina.visible = false
			var bazait := lumina.get_node_or_null("Bazait") as AudioStreamPlayer3D
			if bazait:
				bazait.stop()
				bazait.autoplay = false
		var sticla := stalp.get_node_or_null("Model/Sticla") as GeometryInstance3D
		if sticla:
			sticla.set_instance_shader_parameter("stralucire", 0.0)
	for bloc in blocuri:
		for geam in bloc.find_children("Lumini*", "GeometryInstance3D", true, false):
			(geam as GeometryInstance3D).set_instance_shader_parameter("stralucire", 0.0)
	if bec_scara:
		bec_scara.visible = false
	for nod in de_oprit:
		nod.process_mode = Node.PROCESS_MODE_DISABLED
