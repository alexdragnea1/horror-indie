extends Node
## Autoload "Setari": ecranul, volumul și tastele, ținute minte în user://setari.cfg.
## Se aplică singure la pornirea jocului. Le schimbă meniul principal (Settings):
##   Setari.seteaza_ecran_complet(true)
##   Setari.seteaza_volum("muzica", 0.5)      -> "muzica" sau "efecte", 0..1
##   Setari.schimba_tasta("lanterna", eveniment)
## F11 trece oricând între fereastră și ecran complet.

const CALE := "user://setari.cfg"
## Tastele care se pot schimba, în ordinea din meniu: [acțiune, nume afișat].
const ACTIUNI := [
	["inainte", "Move forward"],
	["inapoi", "Move back"],
	["stanga", "Move left"],
	["dreapta", "Move right"],
	["alearga", "Run"],
	["interact", "Interact"],
	["lanterna", "Flashlight"],
	["inventar", "Inventory"],
	["scut", "Shield"],
]
## Ce controlează glisorul „Effects”: tot ce nu e muzică.
const CANALE_EFECTE: Array[StringName] = [&"Efecte", &"Ambianta", &"Interfata"]
const CANAL_MUZICA := &"Muzica"
## Mărimea ferestrei când ieși din ecran complet (ca în Project Settings).
const MARIME_FEREASTRA := Vector2i(1440, 810)

var ecran_complet := false
## 0..1 (0 = oprit).
var volum_muzica := 0.7
var volum_efecte := 1.0
## Fișierul de salvare ales în meniu (1..Salvare.LOCURI).
var slot := 1

## Tastele din project.godot, pentru „Reset controls”.
var _implicite := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for pereche in ACTIUNI:
		_implicite[pereche[0]] = InputMap.action_get_events(pereche[0])
	_incarca()
	_aplica_ecran()
	_aplica_volum()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		seteaza_ecran_complet(not ecran_complet)


func seteaza_ecran_complet(da: bool) -> void:
	ecran_complet = da
	_aplica_ecran()
	salveaza()


func seteaza_volum(tip: String, valoare: float) -> void:
	if tip == "muzica":
		volum_muzica = clampf(valoare, 0.0, 1.0)
	else:
		volum_efecte = clampf(valoare, 0.0, 1.0)
	_aplica_volum()
	salveaza()


func seteaza_slot(nou: int) -> void:
	slot = nou
	salveaza()


## Numele tastei de la o acțiune, cum apare în meniu ("W", "Shift", "Left Click").
func nume_tasta(actiune: String) -> String:
	var evenimente := InputMap.action_get_events(actiune)
	return _nume_eveniment(evenimente[0]) if not evenimente.is_empty() else "---"


## Pune tasta nouă pe acțiune. Dacă o mai folosea altă acțiune, cele două își schimbă tastele
## între ele (ca să nu rămână nimic fără tastă). Întoarce numele afișat al acelei acțiuni ("" = niciuna).
func schimba_tasta(actiune: String, eveniment: InputEvent) -> String:
	var nou := _curat(eveniment)
	if nou == null:
		return ""
	var vechi: InputEvent = InputMap.action_get_events(actiune)[0] if not InputMap.action_get_events(actiune).is_empty() else null
	var schimbata := ""
	for pereche in ACTIUNI:
		var alta: String = pereche[0]
		if alta == actiune:
			continue
		for ev in InputMap.action_get_events(alta):
			if _la_fel(ev, nou):
				InputMap.action_erase_events(alta)
				if vechi:
					InputMap.action_add_event(alta, vechi)
				schimbata = pereche[1]
	InputMap.action_erase_events(actiune)
	InputMap.action_add_event(actiune, nou)
	salveaza()
	return schimbata


func reseteaza_tastele() -> void:
	for actiune in _implicite:
		InputMap.action_erase_events(actiune)
		for ev in _implicite[actiune]:
			InputMap.action_add_event(actiune, ev)
	salveaza()


func salveaza() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ecran", "complet", ecran_complet)
	cfg.set_value("volum", "muzica", volum_muzica)
	cfg.set_value("volum", "efecte", volum_efecte)
	cfg.set_value("joc", "slot", slot)
	for pereche in ACTIUNI:
		var evenimente := InputMap.action_get_events(pereche[0])
		if not evenimente.is_empty():
			cfg.set_value("taste", pereche[0], _in_text(evenimente[0]))
	cfg.save(CALE)


func _incarca() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CALE) != OK:
		return
	ecran_complet = cfg.get_value("ecran", "complet", ecran_complet)
	volum_muzica = cfg.get_value("volum", "muzica", volum_muzica)
	volum_efecte = cfg.get_value("volum", "efecte", volum_efecte)
	slot = cfg.get_value("joc", "slot", slot)
	for pereche in ACTIUNI:
		var ev := _din_text(cfg.get_value("taste", pereche[0], ""))
		if ev:
			InputMap.action_erase_events(pereche[0])
			InputMap.action_add_event(pereche[0], ev)


func _aplica_ecran() -> void:
	if ecran_complet:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(MARIME_FEREASTRA)
		var ecran := DisplayServer.screen_get_usable_rect()
		DisplayServer.window_set_position(ecran.position + (ecran.size - MARIME_FEREASTRA) / 2)


func _aplica_volum() -> void:
	_volum_canal(CANAL_MUZICA, volum_muzica)
	for canal in CANALE_EFECTE:
		_volum_canal(canal, volum_efecte)


func _volum_canal(nume: StringName, valoare: float) -> void:
	var i := AudioServer.get_bus_index(nume)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, valoare <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(valoare, 0.001)))


## O tastă / un buton de mouse, fără Shift/Ctrl lipite de el.
func _curat(eveniment: InputEvent) -> InputEvent:
	if eveniment is InputEventKey:
		var tasta := InputEventKey.new()
		tasta.physical_keycode = eveniment.physical_keycode if eveniment.physical_keycode != KEY_NONE \
			else eveniment.keycode
		return tasta
	if eveniment is InputEventMouseButton:
		var buton := InputEventMouseButton.new()
		buton.button_index = eveniment.button_index
		return buton
	return null


func _la_fel(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return a.physical_keycode == b.physical_keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	return false


func _nume_eveniment(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var cod := DisplayServer.keyboard_get_keycode_from_physical(ev.physical_keycode)
		return OS.get_keycode_string(cod if cod != KEY_NONE else ev.physical_keycode)
	if ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_LEFT: return "Left Click"
			MOUSE_BUTTON_RIGHT: return "Right Click"
			MOUSE_BUTTON_MIDDLE: return "Middle Click"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
		return "Mouse %d" % ev.button_index
	return "---"


# în fișier: "k87" = tasta fizică 87 (W), "m1" = butonul 1 al mouse-ului
func _in_text(ev: InputEvent) -> String:
	if ev is InputEventKey:
		return "k%d" % ev.physical_keycode
	if ev is InputEventMouseButton:
		return "m%d" % ev.button_index
	return ""


func _din_text(text: String) -> InputEvent:
	if text.length() < 2 or not text.substr(1).is_valid_int():
		return null
	var numar := text.substr(1).to_int()
	if text[0] == "k":
		var tasta := InputEventKey.new()
		tasta.physical_keycode = numar as Key
		return tasta
	if text[0] == "m":
		var buton := InputEventMouseButton.new()
		buton.button_index = numar as MouseButton
		return buton
	return null
