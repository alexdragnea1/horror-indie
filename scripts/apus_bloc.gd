class_name ApusBloc
extends Node
## Curtea blocului la apus (7:24 PM): după mesajul lui Head Witch de la Gun Store (`marcaj_apus`, mesaj_telefon.gd)
## te duce acasă „Home” din orar. Cerul e shaders/cer_apus.gdshader (soarele pe jumătate sub orizont, nori aprinși
## portocaliu și roz, centura roz în partea cealaltă), soarele jos și portocaliu aruncă umbre lungi, ceața e caldă și
## prinde lumina soarelui (`fog_sun_scatter`). Felinarele și geamurile s-au aprins deja. Sperieturile de noapte tac.
## Head Witch te așteaptă la scară (`HeadWitchApus`, sefa_apus.gd). Are întâietate față de ZiBloc și SearaBloc.
## Fără `Jucator` (fundalul din meniul principal) nu face nimic.

const CER := preload("res://shaders/cer_apus.gdshader")

@export var marcaj_apus := "a_primit_mesajul_sefei"
## Prima sosire: după titlu primești `sarcina_sosire` (o dată, `marcaj_sosit`), dacă n-ai învățat încă scutul.
@export var marcaj_sosit := "a_ajuns_la_bloc_la_apus"
@export var sarcina_sosire := "Talk to the Head Witch."
@export var mediu: WorldEnvironment
## `Luna` din scenă: la apus e soarele de la orizont.
@export var soare: DirectionalLight3D
## Ce tace la apus (sperieturile, fantoma).
@export var de_oprit: Array[Node] = []
## Cine nu e în curte la apus (baba de pe bancă): Head Witch te așteaptă singură.
@export var scoase: Array[Node] = []
## Ce se poate examina doar la miezul nopții (covorul de pe bătător).
@export var doar_noaptea: Array[Interactabil] = []
## Unde apari când ieși din bloc (ZiBloc.din_casa) și încotro te uiți (PI = spre stradă).
@export var loc_iesire := Vector3(0.0, 0.1, 2.9)
@export var unghi_iesire := PI

@export_group("Culori apus")
## Încotro e soarele (y = cât de sus; mic = la orizont). În stânga străzii, cum te uiți dinspre bloc.
@export var directie_soare := Vector3(-1.0, 0.035, 0.32)
@export var soare_culoare := Color(1.0, 0.56, 0.3)
@export var soare_energie := 1.25
@export var ambient := Color(0.62, 0.45, 0.62)
@export var ambient_energie := 0.62
@export var ceata := Color(0.66, 0.44, 0.46)
@export var ceata_densitate := 0.018
## Cât acoperă ceața cerul (0 = deloc, 1 = tot): puțin, ca să se vadă culorile.
@export var ceata_pe_cer := 0.12
## Cât se aprinde ceața spre soare.
@export var ceata_spre_soare := 0.35
@export var ceata_volum := Color(1.0, 0.72, 0.6)
@export var ceata_volum_densitate := 0.008
## Cât de mult acoperă norii cerul (0..1).
@export_range(0.0, 1.0) var nori := 0.52


func _ready() -> void:
	var jucator := get_parent().get_node_or_null("Jucator") as Node3D
	if jucator == null or not Stare.e_marcat(marcaj_apus):
		return
	_fa_apus()
	await get_tree().process_frame
	if ZiBloc.din_casa:
		ZiBloc.din_casa = false
		jucator.global_position = loc_iesire
		jucator.rotation.y = unghi_iesire
		jucator.get_node("Cap").rotation.x = 0.0
	if not Stare.e_marcat(marcaj_sosit):
		Stare.marcheaza(marcaj_sosit)
		while Tranzitie.activa:
			await get_tree().process_frame
		# cât se citește titlul cu ora
		await get_tree().create_timer(3.5).timeout
		if sarcina_sosire != "" and not Stare.e_marcat(ScutJucator.MARCAJ):
			Stare.seteaza_sarcina(sarcina_sosire)


func _fa_apus() -> void:
	var s := directie_soare.normalized()
	if mediu:
		# o copie: resursa e comună cu scena din meniul principal, care trebuie să rămână noapte
		var env := mediu.environment.duplicate() as Environment
		var material := ShaderMaterial.new()
		material.shader = CER
		material.set_shader_parameter("directie_soare", s)
		material.set_shader_parameter("acoperire_nori", nori)
		var cer := Sky.new()
		cer.sky_material = material
		cer.radiance_size = Sky.RADIANCE_SIZE_32
		env.background_mode = Environment.BG_SKY
		env.sky = cer
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		env.ambient_light_color = ambient
		env.ambient_light_energy = ambient_energie
		env.fog_light_color = ceata
		env.fog_density = ceata_densitate
		env.fog_sky_affect = ceata_pe_cer
		env.fog_sun_scatter = ceata_spre_soare
		env.volumetric_fog_albedo = ceata_volum
		env.volumetric_fog_density = ceata_volum_densitate
		mediu.environment = env
	if soare:
		# lumina vine dinspre soare: -Z al luminii privește în sens opus
		soare.global_basis = Basis.looking_at(-s, Vector3.UP)
		soare.light_color = soare_culoare
		soare.light_energy = soare_energie
		soare.light_volumetric_fog_energy = 1.2
	for nod in de_oprit:
		nod.process_mode = Node.PROCESS_MODE_DISABLED
	for nod in scoase:
		if is_instance_valid(nod):
			nod.queue_free()
	for obiect in doar_noaptea:
		obiect.activ = false
