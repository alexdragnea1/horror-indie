class_name EcranIncarcare
extends CanvasLayer
## Loading screen-ul de la pornirea jocului (owner 23.10: „doar când intri în joc prima dată, înainte de meniul
## principal”): ecran negru, jos în dreapta o mătură pixelată care zboară (saltă, lasă scântei în urmă) și
## „Loading...”. Scenele se încarcă pe alt fir (ResourceLoader.load_threaded_request), deci animația nu îngheață.
##   var ecran := EcranIncarcare.new()
##   add_child(ecran)
##   await ecran.incarca(["res://scenes/afara_bloc.tscn"])
##   ... construiești scena (load() pe aceleași căi ia din cache) ...
##   ecran.dispare()

## Cât stă pe ecran măcar (secunde), ca să nu fie doar o clipire.
const DURATA_MINIMA := 1.6
## Cât ține stingerea la sfârșit.
const DURATA_STINGERE := 0.8
## Mătura, pixel cu pixel (cu fața spre dreapta, paiele în stânga). „.” = gol.
const MATURA := [
	"bb............................",
	"BBbb..........................",
	"BBBBbb........................",
	"BBBbBBBR......................",
	"BBBBBbBRRhhhhhhhhhhhhhhhhhhhh.",
	"BbBBBBBRRHHHHHHHHHHHHHHHHHHHHH",
	"BBBBbBBRR.....................",
	"BBbBBBBR......................",
	"BBBBbb........................",
	"BBbb..........................",
	"bb............................",
]
const CULORI := {
	"B": Color("c49a52"), "b": Color("8d6a35"), "R": Color("7b383a"), "H": Color("6b4a2e"), "h": Color("8a6440"),
}
const MARGINE := 14
## Cât de mare e un pixel al măturii și al scânteilor.
const PIXEL := 2.0

var _desen: Control
var _text: Label
var _timp := 0.0
var _scantei: Array = []  # [poziție, viață 0..1, culoare]
var _resurse: Array = []  # ținute în viață până la `dispare`, ca load() să le ia din cache


func _ready() -> void:
	layer = 30  # peste meniu și peste Tranzitie
	process_mode = Node.PROCESS_MODE_ALWAYS
	var negru := ColorRect.new()
	negru.color = Color.BLACK
	negru.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(negru)
	_desen = Control.new()
	_desen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_desen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desen.draw.connect(_deseneaza)
	negru.add_child(_desen)
	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 12)
	_text.add_theme_color_override("font_color", TemaMeniu.TEXT)
	_text.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_text.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_text.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_text.offset_right = -MARGINE
	_text.offset_bottom = -MARGINE + 4
	_text.text = "Loading"
	# lățimea fixă (cât „Loading...”), ca textul și mătura să nu se miște când apar punctele
	_text.custom_minimum_size.x = _text.get_theme_font("font").get_string_size("Loading...",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	negru.add_child(_text)


## Încarcă `cai` pe alt fir; se termină când sunt toate gata și a trecut DURATA_MINIMA.
func incarca(cai: Array) -> void:
	for cale: String in cai:
		ResourceLoader.load_threaded_request(cale)
	var start := Time.get_ticks_msec()
	for cale: String in cai:
		while ResourceLoader.load_threaded_get_status(cale) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			await get_tree().process_frame
		var resursa := ResourceLoader.load_threaded_get(cale)
		if resursa == null:
			push_error("EcranIncarcare: nu s-a putut încărca " + cale)
		_resurse.append(resursa)
	while Time.get_ticks_msec() - start < DURATA_MINIMA * 1000.0:
		await get_tree().process_frame


## Se stinge (după câteva cadre, ca sacadarea primului cadru al scenei noi să rămână ascunsă) și dispare.
func dispare() -> void:
	for i in 6:
		await get_tree().process_frame
	var t := create_tween()
	t.tween_property(get_child(0), "modulate:a", 0.0, DURATA_STINGERE).set_trans(Tween.TRANS_SINE)
	await t.finished
	_resurse.clear()
	queue_free()


func _process(delta: float) -> void:
	_timp += delta
	_text.text = "Loading" + ".".repeat(int(_timp / 0.35) % 4)
	# scântei din coada măturii: 1 pixel, se duc înapoi și puțin în jos, se sting
	if randf() < delta * 22.0:
		var culoare := TemaMeniu.ACCENT if randf() < 0.6 else TemaMeniu.TEXT
		_scantei.append([_coada() + Vector2(randf_range(-2, 2), randf_range(-6, 6)), 1.0, culoare])
	for s in _scantei:
		s[0] += Vector2(-40.0, 8.0) * delta
		s[1] -= delta * 1.4
	_scantei = _scantei.filter(func(s: Array) -> bool: return s[1] > 0.0)
	_desen.queue_redraw()


## Colțul din stânga-sus al măturii (pe pixeli întregi, ca jocul), saltă încet.
func _pozitie() -> Vector2:
	var marime := _desen.size
	var latime: int = MATURA[0].length()
	var x := marime.x - MARGINE - latime * PIXEL - _text.size.x - 8.0
	var y := marime.y - MARGINE - 22.0 + roundf(sin(_timp * 4.2) * 2.0) * PIXEL
	return Vector2(roundf(x), y)


func _coada() -> Vector2:
	return _pozitie() + Vector2(0, 5) * PIXEL


func _deseneaza() -> void:
	for s in _scantei:
		var p: Vector2 = s[0]
		_desen.draw_rect(Rect2((p / PIXEL).round() * PIXEL, Vector2.ONE * PIXEL), Color(s[2], s[1]))
	var poz := _pozitie()
	for y in MATURA.size():
		var rand: String = MATURA[y]
		for x in rand.length():
			var c := rand[x]
			if c != ".":
				_desen.draw_rect(Rect2(poz + Vector2(x, y) * PIXEL, Vector2.ONE * PIXEL), CULORI[c])
