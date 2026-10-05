class_name SearaBloc
extends Node
## Curtea blocului seara, la „blue hour” (6:57 PM): după ce te-ai întors de la Lexy cu autobuzul (`marcaj_seara`).
## Cerul e un degrade albastru (shaders/cer_amurg.gdshader: o dungă caldă unde a apus soarele, primele stele, luna),
## lumina e albastră și rece, iar felinarele, becul scării și geamurile sunt deja aprinse (ca noaptea).
## Prima dată (fără `marcaj_coborat`) te pune în stație, cum cobori din autobuz (autobuzul pleacă: `AutobuzSeara`);
## Head Witch te așteaptă la scară (`HeadWitchSeara`, sefa_seara.gd). Are întâietate față de ZiBloc.
## Fără `Jucator` (fundalul din meniul principal) nu face nimic.

const CER := preload("res://shaders/cer_amurg.gdshader")

@export var marcaj_seara := "a_urcat_spre_casa"
@export var marcaj_coborat := "a_coborat_seara_la_bloc"
@export var mediu: WorldEnvironment
## `Luna` din scenă: seara e lumina rece a cerului.
@export var luna: DirectionalLight3D
## Ce se poate examina doar la miezul nopții (covorul de pe bătător).
@export var doar_noaptea: Array[Interactabil] = []
## Unde cobori din autobuz și încotro te uiți (radiani; 0 = spre bloc).
@export var loc_coborare := Vector3(6.8, 0.12, 14.7)
@export var unghi_coborare := 0.5

@export_group("Culori blue hour")
@export var cer_sus := Color(0.03, 0.05, 0.18)
@export var cer_mijloc := Color(0.08, 0.15, 0.42)
@export var cer_orizont := Color(0.26, 0.36, 0.66)
@export var cer_apus := Color(0.66, 0.46, 0.5)
## Încotro a apus soarele: dunga caldă de pe cer (pe orizontală).
@export var directie_apus := Vector3(-1.0, 0.0, 0.35)
@export var ambient := Color(0.3, 0.44, 0.92)
@export var ambient_energie := 0.64
@export var ceata := Color(0.15, 0.22, 0.46)
@export var ceata_densitate := 0.03
## Cât acoperă ceața cerul (0 = deloc, 1 = tot).
@export var ceata_pe_cer := 0.3
@export var ceata_volum := Color(0.5, 0.58, 0.82)
@export var ceata_volum_densitate := 0.014
@export var luna_culoare := Color(0.5, 0.62, 1.0)
@export var luna_energie := 0.3


func _ready() -> void:
	var jucator := get_parent().get_node_or_null("Jucator") as Node3D
	if jucator == null or not Stare.e_marcat(marcaj_seara):
		return
	_fa_seara()
	await get_tree().process_frame
	if not Stare.e_marcat(marcaj_coborat):
		jucator.global_position = loc_coborare
		jucator.rotation.y = unghi_coborare
		jucator.get_node("Cap").rotation.x = 0.0
		Stare.marcheaza(marcaj_coborat)


func _fa_seara() -> void:
	if mediu:
		# o copie: resursa e comună cu scena din meniul principal, care trebuie să rămână noapte
		var env := mediu.environment.duplicate() as Environment
		var material := ShaderMaterial.new()
		material.shader = CER
		material.set_shader_parameter("culoare_sus", cer_sus)
		material.set_shader_parameter("culoare_mijloc", cer_mijloc)
		material.set_shader_parameter("culoare_orizont", cer_orizont)
		material.set_shader_parameter("culoare_apus", cer_apus)
		material.set_shader_parameter("directie_apus", directie_apus)
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
		env.volumetric_fog_albedo = ceata_volum
		env.volumetric_fog_density = ceata_volum_densitate
		mediu.environment = env
	if luna:
		luna.light_color = luna_culoare
		luna.light_energy = luna_energie
	for obiect in doar_noaptea:
		obiect.activ = false
