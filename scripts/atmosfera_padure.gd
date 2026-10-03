extends Node
## Atmosfera pădurii, care se schimbă după unde ești (ca zonele de ambianță dintr-un joc mare):
##   - în pădure: ceață deasă, lună slabă, vânt, din când în când o bufniță;
##   - pe platou (dreapta, sus): ceața se ridică, se văd stelele și luna, greieri;
##   - în vale (stânga, jos): tot mai întuneric, ceață roșiatică și grea, vântul tace,
##     crește un huruit jos și se aud lucruri (ciocănit, crengi, ceva care respiră).
## Valorile se amestecă lin după `TerenPadure.platou()` și `TerenPadure.creepy()` ale poziției tale.
## Tot de aici se schimbă și pe ce calci (potecă / frunze / asfalt).

@export var teren: TerenPadure
@export var mediu: WorldEnvironment
@export var luna: DirectionalLight3D
@export var greieri: AudioStreamPlayer
@export var drone: AudioStreamPlayer
@export var vant: AudioStreamPlayer
## Sunetele de groază din vale (sunete_aleatorii.gd): le crește volumul și le scurtează pauzele.
@export var sperieturi_vale: Node

@export_group("Pădure")
@export var ceata_padure := 0.055
@export var culoare_ceata_padure := Color(0.15, 0.17, 0.2)
@export var lumina_padure := 0.35
@export var luna_padure := 0.22
@export var cer_padure := 0.97

@export_group("Platou")
@export var ceata_platou := 0.012
@export var culoare_ceata_platou := Color(0.18, 0.21, 0.27)
@export var lumina_platou := 0.45
@export var luna_platou := 0.45
## 0 = cerul nu e acoperit deloc de ceață (stelele se văd).
@export var cer_platou := 0.0

@export_group("Vale")
@export var ceata_vale := 0.12
@export var culoare_ceata_vale := Color(0.13, 0.07, 0.08)
@export var lumina_vale := 0.12
@export var luna_vale := 0.04

var _p := 0.0
var _c := 0.0
var _volum_vant := 0.0


func _ready() -> void:
	if vant:
		_volum_vant = vant.volume_db


func _process(delta: float) -> void:
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	if jucator == null or teren == null:
		return
	var poz := jucator.global_position
	# lin: nu sare dintr-o atmosferă în alta
	var k := 1.0 - exp(-delta * 1.5)
	_p = lerpf(_p, teren.platou(poz.x, poz.z), k)
	_c = lerpf(_c, teren.creepy(poz.x, poz.z), k)
	var env := mediu.environment
	env.fog_density = lerpf(lerpf(ceata_padure, ceata_platou, _p), ceata_vale, _c)
	env.fog_light_color = culoare_ceata_padure.lerp(culoare_ceata_platou, _p).lerp(culoare_ceata_vale, _c)
	env.fog_sky_affect = lerpf(lerpf(cer_padure, cer_platou, _p), 1.0, _c)
	env.ambient_light_energy = lerpf(lerpf(lumina_padure, lumina_platou, _p), lumina_vale, _c)
	luna.light_energy = lerpf(lerpf(luna_padure, luna_platou, _p), luna_vale, _c)
	if greieri:
		greieri.volume_db = linear_to_db(maxf(_p, 0.001)) - 10.0
	if drone:
		drone.volume_db = linear_to_db(maxf(_c, 0.001)) - 4.0
	if vant:
		vant.volume_db = _volum_vant + linear_to_db(maxf(1.0 - _c * 0.85, 0.001))
	if sperieturi_vale:
		sperieturi_vale.set("volum_db", lerpf(-40.0, -6.0, _c))
		sperieturi_vale.set("pauza_minima", lerpf(40.0, 6.0, _c))
		sperieturi_vale.set("pauza_maxima", lerpf(80.0, 14.0, _c))
	_suprafata(jucator, poz)


func _suprafata(jucator: Node3D, poz: Vector3) -> void:
	var s := "frunze"
	if poz.z > -4.0:
		s = "beton"
	elif teren.distanta_poteca(poz.x, poz.z) < teren.latime_poteca * 0.5 + 0.2 or poz.z > -7.0:
		s = "poteca"
	jucator.set("suprafata", s)
