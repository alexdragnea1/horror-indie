extends Node
## Genericul de final (scenes/credite.tscn), după „Fuck magic” din City Center (lupta_head_witch.gd): pe negru urcă
## încet titlul (`titlu`) și rândurile (`randuri`), cu muzica din meniu. Orice tastă / click / buton de controller
## (după `blocat_primele` secunde, ca să nu-l sari din greșeală) sau sfârșitul lui te duce în meniul principal.
## Textul e al owner-ului (10.10): se păstrează exact cum l-a scris.

const SCENA_MENIU := "res://scenes/meniu_principal.tscn"
const MUZICA := preload("res://sunete/muzica_meniu.ogg")

@export var titlu := "Unlucky Spells - 2026"
## Rândurile, în ordine (gol = spațiu). Cele cu „ - ” sunt rolurile (stânga = rolul, dreapta = cine).
@export_multiline var randuri: PackedStringArray = [
	"Developer - Me",
	"3D Modeler - Me",
	"Animations - Me",
	"Script - Also me",
	"Gameplay - You, but you played very bad",
	"",
	"",
	"Like seriously you could've done so much better..why were you such a bitch?",
	"Also you should've pet the cat more..she deserves it.",
	"",
	"",
	"",
	"Hope you enjoyed this little game and don't you fucking refund the game or I'll send my goons after you. Okay, bye!",
]
## Cât de repede urcă textul (pixeli din cei 270 ai ecranului, pe secundă).
@export var viteza := 16.0
## În primele secunde tastele nu te scot (încă ții apăsat ce apăsai în joc).
@export var blocat_primele := 1.5
## Cât mai stă pe negru după ce a ieșit ultimul rând, până la meniu.
@export var pauza_final := 2.5

const AURIU := Color("a18463")
const TEXT := Color("83b3b0")
const STINS := Color("7e8d87")

var _coloana: VBoxContainer
var _muzica: AudioStreamPlayer
var _timp := 0.0
var _plecat := false


func _ready() -> void:
	Salvare.in_joc = false
	Stare.meniu_deschis = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var strat := CanvasLayer.new()
	strat.layer = 4
	add_child(strat)
	var negru := ColorRect.new()
	negru.color = Color.BLACK
	negru.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	negru.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strat.add_child(negru)
	_coloana = VBoxContainer.new()
	_coloana.add_theme_constant_override("separation", 5)
	_coloana.position = Vector2(60, 280)
	_coloana.custom_minimum_size = Vector2(360, 0)
	_coloana.size = Vector2(360, 0)
	strat.add_child(_coloana)
	_eticheta(titlu, 20, AURIU)
	_spatiu(26)
	for r in randuri:
		if r == "":
			_spatiu(10)
		elif " - " in r:
			_rol(r)
		else:
			_eticheta(r, 10, STINS)
	_muzica = AudioStreamPlayer.new()
	_muzica.stream = MUZICA
	_muzica.bus = &"Muzica"
	_muzica.volume_db = -40.0
	add_child(_muzica)
	_muzica.play()
	create_tween().tween_property(_muzica, "volume_db", Sunet.VOLUM_MUZICA, 3.0)


func _eticheta(text: String, marime: int, culoare: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(360, 0)
	l.add_theme_font_size_override("font_size", marime)
	l.add_theme_color_override("font_color", culoare)
	l.add_theme_color_override("font_shadow_color", Color("262d2f"))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	_coloana.add_child(l)
	return l


## „Developer - Me”: rolul mic și stins deasupra, numele mai mare dedesubt (ca într-un generic de film).
func _rol(rand: String) -> void:
	var i := rand.find(" - ")
	_eticheta(rand.substr(0, i).to_upper(), 8, AURIU)
	_eticheta(rand.substr(i + 3), 12, TEXT)
	_spatiu(6)


func _spatiu(inaltime: int) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, inaltime)
	_coloana.add_child(c)


func _process(delta: float) -> void:
	_timp += delta
	_coloana.position.y -= viteza * delta
	# după ce a ieșit de tot ultimul rând pe sus
	if not _plecat and _coloana.position.y + _coloana.size.y < -10.0:
		_plecat = true
		await get_tree().create_timer(pauza_final).timeout
		_la_meniu()


func _input(event: InputEvent) -> void:
	if _timp < blocat_primele:
		return
	var apasat: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed)
	if apasat:
		get_viewport().set_input_as_handled()
		_plecat = true
		_la_meniu()


func _la_meniu() -> void:
	if Tranzitie.activa:
		return
	set_process_input(false)
	create_tween().tween_property(_muzica, "volume_db", -40.0, 0.9)
	Stare.meniu_deschis = false
	Tranzitie.mergi_la(SCENA_MENIU)
