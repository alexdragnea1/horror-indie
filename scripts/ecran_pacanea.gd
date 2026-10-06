class_name EcranPacanea
extends Control
## Ce se vede pe ecranul păcănelelor cât nu joacă nimeni (desenat într-un SubViewport mic, vezi PacaneaJoc):
## jos (`sus = false`) 5x3 simboluri, din când în când câte o rolă se învârte, „INSERT CREDIT” clipește;
## sus (`sus = true`) numele jocului și jackpot-ul care crește încet.

var sus := false

const SIMBOLURI := ["cirese", "lamaie", "portocala", "pruna", "struguri", "pepene", "clopot", "sapte", "stea"]
const FUNDAL := Color("262d2f")
const ROSU := Color("7b383a")
const AUR := Color("a18463")
const TEXT := Color("83b3b0")

var _grila: Array = []
var _timp := 0.0
var _pana_la_rotire := 1.0
var _rola_rotita := -1
var _rotire := 0.0
var _jackpot := 0.0


func _ready() -> void:
	for r in 5:
		_grila.append([SIMBOLURI.pick_random(), SIMBOLURI.pick_random(), SIMBOLURI.pick_random()])
	_jackpot = randf_range(1200.0, 1900.0)


func _process(delta: float) -> void:
	_timp += delta
	_jackpot += delta * 0.37
	if not sus:
		_pana_la_rotire -= delta
		if _pana_la_rotire <= 0.0:
			_pana_la_rotire = randf_range(0.4, 1.4)
			_rola_rotita = randi() % 5
			_rotire = 0.5
		if _rotire > 0.0:
			_rotire -= delta
			if fmod(_timp, 0.08) < delta:
				(_grila[_rola_rotita] as Array).push_front(SIMBOLURI.pick_random())
				(_grila[_rola_rotita] as Array).pop_back()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), FUNDAL)
	var font := get_theme_default_font()
	if sus:
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), ROSU, false, 2.0)
		draw_string(font, Vector2(0, 15), "40 BURNING 7s", HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, AUR)
		var bani := "JACKPOT  $%.2f" % _jackpot
		draw_string(font, Vector2(0, 32), bani, HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, TEXT if fmod(_timp, 1.0) < 0.7 else AUR)
		return
	# rolele
	var celula := 17.0
	var start := Vector2((size.x - celula * 5) / 2.0, 6)
	for r in 5:
		draw_rect(Rect2(start + Vector2(r * celula, 0), Vector2(celula - 1, celula * 3)), Color("553e4d"))
		for k in 3:
			var tex := Carti.simbol(_grila[r][k], 1)
			draw_texture(tex, start + Vector2(r * celula + 2, k * celula + 2))
	if fmod(_timp, 1.2) < 0.75:
		draw_string(font, Vector2(0, size.y - 5), "INSERT CREDIT", HORIZONTAL_ALIGNMENT_CENTER, size.x, 9, AUR)
