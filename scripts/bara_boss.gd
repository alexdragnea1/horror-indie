class_name BaraBoss
extends CanvasLayer
## Interfața luptei cu un boss, ca în Dark Souls (lupta_warlock.gd):
##  - jos, pe mijloc: numele boss-ului și bara lui lungă și subțire; ce pierde se vede întâi aurie (`_urma`), apoi se
##    scurge după o clipă; în dreapta, deasupra barei, damage-ul adunat din loviturile de acum (dispare dacă nu mai dai);
##  - sus în stânga: viața ta (roșie, la fel cu urma aurie), doar cât ține lupta;
##  - pe tot ecranul, o clipă roșu când te lovește ceva (`ranit`);
##  - mesajele mari pe o bandă neagră: „YOU DIED” (roșu), „WARLOCK DEFEATED” (auriu);
##  - indicația cu tasta scutului și cât timp mai ai (`indicatie_scut`).
## Culorile sunt din paleta jocului.

const ROSU := Color("7b383a")
const ROSU_DESCHIS := Color("904a40")
const AURIU := Color("a18463")
const FUNDAL := Color("262d2f")
const MARGINE := Color("5e5356")
const TEXT := Color("83b3b0")

## Cât de lată e bara boss-ului (pixeli din cei 480 ai ecranului) și cât de jos stă.
const LATIME := 300.0
const DE_JOS := 26.0

var _radacina: Control
var _boss: Control
var _nume: Label
var _plin: ColorRect
var _urma: ColorRect
var _numar: Label
var _jucator_bara: Control
var _jucator_plin: ColorRect
var _jucator_urma: ColorRect
var _rosu: ColorRect
var _banda: ColorRect
var _mesaj: Label
var _indicatie: Control
var _indicatie_text: Label
var _indicatie_timp: ColorRect

var _fractie := 1.0
var _fractie_urma := 1.0
var _pauza_urma := 0.0
var _jucator_fractie := 1.0
var _jucator_fractie_urma := 1.0
var _jucator_pauza := 0.0
var _adunat := 0
var _pauza_numar := 0.0


func _ready() -> void:
	layer = 7
	_radacina = Control.new()
	_radacina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_radacina.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_radacina)
	_rosu = _dreptunghi(_radacina, Color(ROSU_DESCHIS, 0.0))
	_rosu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fa_bara_boss()
	_fa_bara_jucator()
	_fa_mesajul()
	_fa_indicatia()


func _dreptunghi(parinte: Control, culoare: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = culoare
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parinte.add_child(r)
	return r


func _eticheta(parinte: Control, marime: int, culoare: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", marime)
	l.add_theme_color_override("font_color", culoare)
	l.add_theme_color_override("font_shadow_color", Color(FUNDAL, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	parinte.add_child(l)
	return l


func _fa_bara_boss() -> void:
	_boss = Control.new()
	_boss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss.anchor_left = 0.5
	_boss.anchor_right = 0.5
	_boss.anchor_top = 1.0
	_boss.anchor_bottom = 1.0
	_boss.offset_left = -LATIME / 2.0
	_boss.offset_right = LATIME / 2.0
	_boss.offset_top = -DE_JOS - 14.0
	_boss.offset_bottom = -DE_JOS + 5.0
	_boss.modulate.a = 0.0
	_radacina.add_child(_boss)
	_nume = _eticheta(_boss, 10, TEXT)
	_nume.position = Vector2(1, 0)
	_numar = _eticheta(_boss, 9, TEXT)
	_numar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_numar.position = Vector2(LATIME - 61, 1)
	_numar.size = Vector2(60, 12)
	var rama := _dreptunghi(_boss, MARGINE)
	rama.position = Vector2(-1, 13)
	rama.size = Vector2(LATIME + 2, 6)
	var fundal := _dreptunghi(_boss, FUNDAL)
	fundal.position = Vector2(0, 14)
	fundal.size = Vector2(LATIME, 4)
	_urma = _dreptunghi(_boss, AURIU)
	_urma.position = Vector2(0, 14)
	_urma.size = Vector2(LATIME, 4)
	_plin = _dreptunghi(_boss, ROSU)
	_plin.position = Vector2(0, 14)
	_plin.size = Vector2(LATIME, 4)
	var luciu := _dreptunghi(_plin, ROSU_DESCHIS)
	luciu.size = Vector2(LATIME, 1)
	luciu.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	luciu.offset_bottom = 1


func _fa_bara_jucator() -> void:
	_jucator_bara = Control.new()
	_jucator_bara.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_jucator_bara.position = Vector2(12, 12)
	_jucator_bara.modulate.a = 0.0
	_radacina.add_child(_jucator_bara)
	var rama := _dreptunghi(_jucator_bara, MARGINE)
	rama.position = Vector2(-1, -1)
	rama.size = Vector2(102, 6)
	var fundal := _dreptunghi(_jucator_bara, FUNDAL)
	fundal.size = Vector2(100, 4)
	_jucator_urma = _dreptunghi(_jucator_bara, AURIU)
	_jucator_urma.size = Vector2(100, 4)
	_jucator_plin = _dreptunghi(_jucator_bara, ROSU_DESCHIS)
	_jucator_plin.size = Vector2(100, 4)


func _fa_mesajul() -> void:
	_banda = _dreptunghi(_radacina, Color(0, 0, 0, 0))
	_banda.anchor_left = 0.0
	_banda.anchor_right = 1.0
	_banda.anchor_top = 0.5
	_banda.anchor_bottom = 0.5
	_banda.offset_top = -26
	_banda.offset_bottom = 26
	_mesaj = _eticheta(_radacina, 30, ROSU_DESCHIS)
	_mesaj.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mesaj.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mesaj.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mesaj.pivot_offset = Vector2(240, 135)
	_mesaj.modulate.a = 0.0


func _fa_indicatia() -> void:
	_indicatie = Control.new()
	_indicatie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_indicatie.anchor_left = 0.5
	_indicatie.anchor_right = 0.5
	_indicatie.anchor_top = 0.5
	_indicatie.anchor_bottom = 0.5
	_indicatie.offset_left = -90
	_indicatie.offset_right = 90
	_indicatie.offset_top = 34
	_indicatie.offset_bottom = 60
	_indicatie.modulate.a = 0.0
	_radacina.add_child(_indicatie)
	var fundal := _dreptunghi(_indicatie, Color(FUNDAL, 0.75))
	fundal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_indicatie_text = _eticheta(_indicatie, 13, TEXT)
	_indicatie_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_indicatie_text.position = Vector2(0, 2)
	_indicatie_text.size = Vector2(180, 16)
	_indicatie_timp = _dreptunghi(_indicatie, Color("61a19f"))
	_indicatie_timp.position = Vector2(4, 21)
	_indicatie_timp.size = Vector2(172, 2)


func _process(delta: float) -> void:
	# urma aurie stă o clipă, apoi se scurge până la bara roșie
	_pauza_urma -= delta
	if _pauza_urma <= 0.0:
		_fractie_urma = move_toward(_fractie_urma, _fractie, delta * 0.35)
	_urma.size.x = LATIME * _fractie_urma
	_plin.size.x = LATIME * _fractie
	_jucator_pauza -= delta
	if _jucator_pauza <= 0.0:
		_jucator_fractie_urma = move_toward(_jucator_fractie_urma, _jucator_fractie, delta * 0.5)
	_jucator_urma.size.x = 100.0 * _jucator_fractie_urma
	_jucator_plin.size.x = 100.0 * _jucator_fractie
	_pauza_numar -= delta
	if _pauza_numar <= 0.0 and _adunat > 0:
		_adunat = 0
		create_tween().tween_property(_numar, "modulate:a", 0.0, 0.4)


## Arată bara boss-ului (și pe a ta), plină.
func arata(nume: String) -> void:
	_nume.text = nume
	_fractie = 1.0
	_fractie_urma = 1.0
	_jucator_fractie = 1.0
	_jucator_fractie_urma = 1.0
	_numar.modulate.a = 0.0
	_adunat = 0
	var t := create_tween().set_parallel()
	t.tween_property(_boss, "modulate:a", 1.0, 0.8)
	t.tween_property(_jucator_bara, "modulate:a", 1.0, 0.8)


func ascunde(durata := 0.8) -> void:
	var t := create_tween().set_parallel()
	t.tween_property(_boss, "modulate:a", 0.0, durata)
	t.tween_property(_jucator_bara, "modulate:a", 0.0, durata)


## Viața boss-ului s-a schimbat; `damage` > 0 = o lovitură (se adună în numărul din dreapta).
func viata_boss(viata: float, maxim: float, damage := 0) -> void:
	var noua := clampf(viata / maxim, 0.0, 1.0)
	if noua < _fractie:
		_pauza_urma = 0.7
	_fractie = noua
	if _fractie_urma < _fractie:
		_fractie_urma = _fractie
	if damage > 0:
		_adunat += damage
		_numar.text = str(_adunat)
		_numar.modulate.a = 1.0
		_pauza_numar = 1.6


func viata_jucator(viata: float, maxim: float) -> void:
	var noua := clampf(viata / maxim, 0.0, 1.0)
	if noua < _jucator_fractie:
		_jucator_pauza = 0.6
	_jucator_fractie = noua
	if _jucator_fractie_urma < _jucator_fractie:
		_jucator_fractie_urma = _jucator_fractie


## Te-a lovit ceva: ecranul se înroșește o clipă.
func ranit(putere := 1.0) -> void:
	_rosu.color.a = 0.45 * putere
	create_tween().tween_property(_rosu, "color:a", 0.0, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


## Un mesaj mare pe o bandă neagră („YOU DIED”, „WARLOCK DEFEATED”): apare încet, crește puțin, stă `durata` s și
## se stinge. Se poate aștepta (await).
func mesaj(text: String, culoare: Color, durata: float) -> void:
	_mesaj.text = text
	_mesaj.add_theme_color_override("font_color", culoare)
	_mesaj.scale = Vector2.ONE * 0.94
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	t.tween_property(_banda, "color:a", 0.7, 1.2)
	t.tween_property(_mesaj, "modulate:a", 1.0, 1.6)
	t.tween_property(_mesaj, "scale", Vector2.ONE * 1.04, durata + 1.6)
	t.chain().tween_interval(maxf(durata - 1.6, 0.0))
	t.chain().tween_property(_mesaj, "modulate:a", 0.0, 1.0)
	t.parallel().tween_property(_banda, "color:a", 0.0, 1.0)
	await t.finished


## Indicația scutului: „Press Ctrl to shield” și o bară care se golește în `timp` secunde. `timp` 0 = o ascunde.
func indicatie_scut(timp: float) -> void:
	if timp <= 0.0:
		create_tween().tween_property(_indicatie, "modulate:a", 0.0, 0.25)
		return
	_indicatie_text.text = "Press %s to shield!" % Setari.nume_tasta("scut")
	_indicatie_timp.size.x = 172.0
	var t := create_tween()
	t.tween_property(_indicatie, "modulate:a", 1.0, 0.15)
	create_tween().tween_property(_indicatie_timp, "size:x", 0.0, timp)


## Bara boss-ului se umple de la gol la plin în `durata` s, cu alt nume (faza a doua a lui Head Witch).
func umple(nume: String, durata: float) -> void:
	_nume.text = nume
	_numar.modulate.a = 0.0
	_adunat = 0
	var t := create_tween().set_parallel()
	t.tween_property(_boss, "modulate:a", 1.0, 0.5)
	t.tween_property(_jucator_bara, "modulate:a", 1.0, 0.5)
	t.tween_method(func(v: float) -> void:
		_fractie = v
		_fractie_urma = v, 0.0, 1.0, durata).set_trans(Tween.TRANS_SINE)
