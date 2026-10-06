extends CanvasLayer
## Autoload "Salvare": fișierele de salvare (3 locuri, user://salvare_1.json ...).
## Jocul se salvează singur, în fișierul ales în meniu (Setari.slot):
##   - când intri într-o scenă (după ușă / tranziție),
##   - când se schimbă ceva în poveste (Stare.schimbat: un marcaj, o sarcină, un obiect),
##   - la fiecare minut (doar poziția, fără mesaj) și când închizi fereastra.
## Jos în dreapta apare „Saving...” cât se salvează.
##   Salvare.joc_nou()      -> șterge starea și pornește din camera ta
##   Salvare.continua()     -> încarcă fișierul ales și te pune unde ai rămas
##   Salvare.info(2)        -> ce e în fișierul 2 ({} = gol)

const LOCURI := 3
const SCENA_START := "res://scenes/nivel_test.tscn"
## Numele locului, pentru meniu și pentru titlul de la „Continue”.
const NUME_LOCURI := {
	"res://scenes/nivel_test.tscn": "Home",
	"res://scenes/afara_bloc.tscn": "Block M7",
	"res://scenes/padure.tscn": "Trivale Forest",
	"res://scenes/casa_lexy.tscn": "Lexy's place",
	"res://scenes/conac.tscn": "Coven Headquarters",
	"res://scenes/conac_interior.tscn": "Coven Headquarters",
	"res://scenes/casino.tscn": "Sketchy Laundromat",
}
## La câte secunde se salvează singur, fără mesaj.
const PAUZA_SALVARE := 60.0

## Adevărat cât ești în joc (nu în meniu): doar atunci se salvează și curge timpul jucat.
var in_joc := false
var timp_jucat := 0.0

var _pozitie_de_pus: Dictionary = {}
var _de_salvat := false
var _ceas := 0.0
var _mesaj: Label
var _tween: Tween


func _ready() -> void:
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mesaj = Label.new()
	_mesaj.text = "Saving..."
	_mesaj.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_mesaj.offset_left = -70
	_mesaj.offset_top = -20
	_mesaj.offset_right = -8
	_mesaj.offset_bottom = -6
	_mesaj.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mesaj.add_theme_font_size_override("font_size", 9)
	_mesaj.add_theme_color_override("font_color", Color("a18463"))
	_mesaj.add_theme_color_override("font_shadow_color", Color("262d2fe6"))
	_mesaj.add_theme_constant_override("shadow_offset_x", 1)
	_mesaj.add_theme_constant_override("shadow_offset_y", 1)
	_mesaj.modulate.a = 0.0
	add_child(_mesaj)
	Stare.schimbat.connect(func() -> void: _de_salvat = in_joc)


func _process(delta: float) -> void:
	if not in_joc or get_tree().paused:
		return
	timp_jucat += delta
	_ceas += delta
	if _de_salvat and not Tranzitie.activa:
		_de_salvat = false
		salveaza(true)
	elif _ceas >= PAUZA_SALVARE:
		salveaza(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and in_joc:
		salveaza(false)


func cale(loc: int) -> String:
	return "user://salvare_%d.json" % loc


func exista(loc: int) -> bool:
	return FileAccess.file_exists(cale(loc))


## Tot ce e în fișier ({} dacă e gol sau stricat).
func info(loc: int) -> Dictionary:
	if not exista(loc):
		return {}
	var date = JSON.parse_string(FileAccess.get_file_as_string(cale(loc)))
	return date if date is Dictionary else {}


func sterge(loc: int) -> void:
	if exista(loc):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cale(loc)))


func joc_nou() -> void:
	Stare.reseteaza()
	timp_jucat = 0.0
	_pozitie_de_pus = {}
	sterge(Setari.slot)
	Tranzitie.mergi_la(SCENA_START)


func continua() -> void:
	var date := info(Setari.slot)
	if date.is_empty():
		joc_nou()
		return
	Stare.reseteaza()
	Stare.importa(date.get("stare", {}))
	timp_jucat = date.get("timp", 0.0)
	_pozitie_de_pus = date.get("jucator", {})
	Tranzitie.mergi_la(date.get("scena", SCENA_START), NUME_LOCURI.get(date.get("scena", ""), ""))


## O cheamă jucătorul când apare într-o scenă: îl pune unde a rămas (dacă vine din „Continue”)
## și salvează (ai ajuns într-un loc nou).
func jucator_pregatit(jucator: Node3D) -> void:
	if not _pozitie_de_pus.is_empty():
		var p := _pozitie_de_pus
		jucator.global_position = Vector3(p.get("x", 0.0), p.get("y", 0.0), p.get("z", 0.0))
		jucator.rotation.y = p.get("unghi", 0.0)
		jucator.get_node("Cap").rotation.x = p.get("privire", 0.0)
		_pozitie_de_pus = {}
	in_joc = true
	_de_salvat = true


func salveaza(cu_mesaj: bool) -> void:
	_ceas = 0.0
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	var scena := get_tree().current_scene
	if not in_joc or jucator == null or scena == null:
		return
	var date := {
		"versiune": 1,
		"scena": scena.scene_file_path,
		"loc": NUME_LOCURI.get(scena.scene_file_path, ""),
		"jucator": {
			"x": jucator.global_position.x, "y": jucator.global_position.y, "z": jucator.global_position.z,
			"unghi": jucator.rotation.y, "privire": jucator.get_node("Cap").rotation.x,
		},
		"stare": Stare.exporta(),
		"timp": timp_jucat,
		"data": Time.get_datetime_string_from_system(false, true),
	}
	var fisier := FileAccess.open(cale(Setari.slot), FileAccess.WRITE)
	if fisier == null:
		push_warning("Nu pot salva în " + cale(Setari.slot))
		return
	fisier.store_string(JSON.stringify(date, "\t"))
	fisier.close()
	if cu_mesaj:
		_arata_mesaj()


func _arata_mesaj() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_mesaj, "modulate:a", 1.0, 0.2)
	# pâlpâie de două ori, ca un led de memory card
	for i in 2:
		_tween.tween_property(_mesaj, "modulate:a", 0.35, 0.25)
		_tween.tween_property(_mesaj, "modulate:a", 1.0, 0.25)
	_tween.tween_property(_mesaj, "modulate:a", 0.0, 0.6)


## „12:05” sau „1:02:30”.
static func timp_ca_text(secunde: float) -> String:
	var s := int(secunde)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]
