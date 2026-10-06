class_name Carti
extends RefCounted
## Texturile „pixel art” pentru cărțile de joc și pentru simbolurile de la păcănele, desenate din cod, doar cu culori din
## paleta jocului (cifre 3x5, culori 7x7, simboluri 12x12). Se fac o singură dată și se țin minte.
## O carte = un număr 0..51: valoarea = c % 13 (0 = 2 … 8 = 10, 9 = J, 10 = Q, 11 = K, 12 = A), culoarea = c / 13
## (0 = pică, 1 = inimă, 2 = romb, 3 = treflă).
## Mărimea unei cărți: `LATIME` x `INALTIME` pixeli (pe ecran le mărești cu filtrul „nearest”).

const LATIME := 28
const INALTIME := 40

const ALB := Color("83b3b0")
const MARGINE := Color("6f6d7f")
const ROSU := Color("7b383a")
const NEGRU := Color("262d2f")
const SPATE := Color("7b383a")
const SPATE_MODEL := Color("5e363e")
const AUR := Color("a18463")

const VALORI := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const NUME_VALORI := ["Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Jack", "Queen", "King", "Ace"]

const CIFRE := {
	"0": ["###", "#.#", "#.#", "#.#", "###"],
	"1": [".#", "##", ".#", ".#", ".#"],
	"2": ["##.", "..#", ".#.", "#..", "###"],
	"3": ["##.", "..#", ".#.", "..#", "##."],
	"4": ["#.#", "#.#", "###", "..#", "..#"],
	"5": ["###", "#..", "##.", "..#", "##."],
	"6": [".##", "#..", "###", "#.#", "###"],
	"7": ["###", "..#", ".#.", ".#.", ".#."],
	"8": ["###", "#.#", "###", "#.#", "###"],
	"9": ["###", "#.#", "###", "..#", "##."],
	"A": [".#.", "#.#", "###", "#.#", "#.#"],
	"J": ["..#", "..#", "..#", "#.#", ".#."],
	"Q": [".#.", "#.#", "#.#", "##.", ".##"],
	"K": ["#.#", "##.", "#..", "##.", "#.#"],
}

const CULORI_CARTI := [
	["...#...", "..###..", ".#####.", "#######", "##.#.##", "...#...", "..###.."],  # pică
	[".##.##.", "#######", "#######", ".#####.", "..###..", "...#...", "......."],  # inimă
	["...#...", "..###..", ".#####.", "#######", ".#####.", "..###..", "...#..."],  # romb
	["..###..", "..###..", "##.#.##", "#######", "##.#.##", "...#...", "..###.."],  # treflă
]

## Simbolurile păcănelei (12x12): fiecare literă e o culoare din `CULORI_SIMBOL`, punctul = transparent.
const SIMBOLURI := {
	"cirese": [
		"........gg..", ".......g..g.", "......g...g.", ".....g....g.", "....g.....g.", "...g......g.",
		".rrr....rrr.", "rrwrr..rrwrr", "rrrrr..rrrrr", "rrrrR..rrrrR", ".rRR....rRR.", "............"],
	"lamaie": [
		"............", "....yyyy....", "..yyyyyyyy..", ".yywyyyyyyy.", "yywyyyyyyyyy", "yyyyyyyyyyyY",
		"yyyyyyyyyyYY", ".yyyyyyyyYY.", "..yyyyyyYY..", "....YYYY....", "............", "............"],
	"portocala": [
		"......g.....", ".....ggg....", "...oooooo...", "..oooooooo..", ".oowoooooOo.", ".owooooooOO.",
		".ooooooooOO.", ".oooooooOOO.", "..ooooooOO..", "...ooooOO...", "............", "............"],
	"pruna": [
		".....g......", "....gg......", "...pppppp...", "..pwppppppp.", ".pwpppppppP.", ".ppppppppPP.",
		".ppppppppPP.", ".pppppppPPP.", "..ppppPPPP..", "...pPPPPP...", "............", "............"],
	"struguri": [
		".....gg.....", "....g..gg...", "..vvvvvvv...", ".vwvvwvvvV..", ".vvvVvvvVV..", "..vwvvwvVV..",
		"..vvvVvvV...", "...vwvvV....", "...vvvVV....", "....vvV.....", ".....V......", "............"],
	"pepene": [
		"............", "............", "GggggggggggG", ".Grrrrrrrrr.", ".Grrkrrrkrr.", "..Grrrrrrr..",
		"..Grrkrrkr..", "...Grrrrr...", "....Grrr....", ".....GG.....", "............", "............"],
	"sapte": [
		"yyyyyyyyyyyy", "yrrrrrrrrrry", "yrrrrrrrrrry", "yyyyyyyrrryy", "......yrrry.", ".....yrrry..",
		"....yrrry...", "....yrrry...", "...yrrry....", "...yrrry....", "...yrrry....", "...yyyyy...."],
	"stea": [
		".....yy.....", ".....yy.....", "....ywyy....", "yyyyywyyyyyy", ".yyyyyyyyyY.", "..yyyyyyyY..",
		"...yyyyyyY..", "...yyyyyYY..", "..yyyY.YYY..", "..yyY...YY..", ".yyY.....Y..", "............"],
	"clopot": [
		".....yy.....", "....yyyy....", "...ywyyyy...", "...wyyyyY...", "..ywyyyyyY..", "..yyyyyyyY..",
		"..yyyyyyyY..", ".yyyyyyyyyY.", "yyyyyyyyyyYY", "YYYYYYYYYYYY", ".....kk.....", "............"],
}
const CULORI_SIMBOL := {
	"r": Color("7b383a"), "R": Color("5e363e"), "g": Color("5b6d4e"), "G": Color("445d46"), "w": Color("83b3b0"),
	"y": Color("a18463"), "Y": Color("a56850"), "o": Color("904a40"), "O": Color("7b383a"), "p": Color("655269"),
	"P": Color("553e4d"), "v": Color("655269"), "V": Color("48313b"), "k": Color("262d2f"),
}

static var _cache := {}


static func valoare(c: int) -> int:
	return c % 13


static func culoare(c: int) -> int:
	return c / 13


static func e_rosie(c: int) -> bool:
	return culoare(c) == 1 or culoare(c) == 2


## „Ace of Spades”.
static func nume(c: int) -> String:
	return "%s of %s" % [NUME_VALORI[valoare(c)], ["Spades", "Hearts", "Diamonds", "Clubs"][culoare(c)]]


## Fața cărții `c`.
static func textura(c: int) -> ImageTexture:
	var cheie := "c%d" % c
	if _cache.has(cheie):
		return _cache[cheie]
	var img := Image.create(LATIME, INALTIME, false, Image.FORMAT_RGBA8)
	img.fill(ALB)
	_rama(img, MARGINE)
	var cul := ROSU if e_rosie(c) else NEGRU
	var text: String = VALORI[valoare(c)]
	var semn: Array = CULORI_CARTI[culoare(c)]
	# colțul din stânga sus: valoarea și culoarea mică; colțul din dreapta jos, întors
	_scrie(img, text, 2, 2, cul, 1)
	_bitmap(img, semn, 2, 8, cul, 1, false)
	var lat := _latime_text(text)
	_scrie_intors(img, text, LATIME - 3 - lat + 1, INALTIME - 7, cul)
	_bitmap(img, semn, LATIME - 9, INALTIME - 15, cul, 1, true)
	if valoare(c) >= 9 and valoare(c) <= 11:
		# figurile: litera mare, cu o ramă aurie
		_dreptunghi(img, 7, 9, LATIME - 14, INALTIME - 18, AUR)
		_dreptunghi(img, 8, 10, LATIME - 16, INALTIME - 20, ALB)
		var l := _latime_text(text) * 3
		_scrie(img, text, (LATIME - l) / 2, (INALTIME - 15) / 2, cul, 3)
	else:
		_bitmap(img, semn, (LATIME - 14) / 2, (INALTIME - 14) / 2, cul, 2, false)
	var tex := ImageTexture.create_from_image(img)
	_cache[cheie] = tex
	return tex


## Spatele cărților: roșu cu romburi, ramă albă.
static func spate() -> ImageTexture:
	if _cache.has("spate"):
		return _cache["spate"]
	var img := Image.create(LATIME, INALTIME, false, Image.FORMAT_RGBA8)
	img.fill(ALB)
	_rama(img, MARGINE)
	for y in range(3, INALTIME - 3):
		for x in range(3, LATIME - 3):
			var model := (x + y) % 6 == 0 or (x - y + 60) % 6 == 0
			img.set_pixel(x, y, SPATE_MODEL if model else SPATE)
	var tex := ImageTexture.create_from_image(img)
	_cache["spate"] = tex
	return tex


## Un simbol de păcănea (12x12, fundal transparent), mărit de `marire` ori.
static func simbol(nume_simbol: String, marire := 1) -> ImageTexture:
	var cheie := "s%s%d" % [nume_simbol, marire]
	if _cache.has(cheie):
		return _cache[cheie]
	var randuri: Array = SIMBOLURI[nume_simbol]
	var img := Image.create(12 * marire, 12 * marire, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in randuri.size():
		var rand: String = randuri[y]
		for x in rand.length():
			var ch := rand[x]
			if ch == ".":
				continue
			var col: Color = CULORI_SIMBOL[ch]
			for dy in marire:
				for dx in marire:
					img.set_pixel(x * marire + dx, y * marire + dy, col)
	var tex := ImageTexture.create_from_image(img)
	_cache[cheie] = tex
	return tex


static func _rama(img: Image, cul: Color) -> void:
	for x in img.get_width():
		img.set_pixel(x, 0, cul)
		img.set_pixel(x, img.get_height() - 1, cul)
	for y in img.get_height():
		img.set_pixel(0, y, cul)
		img.set_pixel(img.get_width() - 1, y, cul)
	# colțurile rotunjite
	for p in [Vector2i(1, 1), Vector2i(img.get_width() - 2, 1), Vector2i(1, img.get_height() - 2),
			Vector2i(img.get_width() - 2, img.get_height() - 2)]:
		img.set_pixelv(p, cul)
	for p in [Vector2i(0, 0), Vector2i(img.get_width() - 1, 0), Vector2i(0, img.get_height() - 1),
			Vector2i(img.get_width() - 1, img.get_height() - 1)]:
		img.set_pixelv(p, Color(0, 0, 0, 0))


static func _dreptunghi(img: Image, x: int, y: int, w: int, h: int, cul: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), cul)


static func _bitmap(img: Image, randuri: Array, x0: int, y0: int, cul: Color, marire: int, intors: bool) -> void:
	var h := randuri.size()
	for y in h:
		var rand: String = randuri[y]
		for x in rand.length():
			if rand[x] != "#":
				continue
			var px := x
			var py := y
			if intors:
				px = rand.length() - 1 - x
				py = h - 1 - y
			for dy in marire:
				for dx in marire:
					var fx := x0 + px * marire + dx
					var fy := y0 + py * marire + dy
					if fx >= 0 and fy >= 0 and fx < img.get_width() and fy < img.get_height():
						img.set_pixel(fx, fy, cul)


static func _latime_text(text: String) -> int:
	var l := 0
	for ch in text:
		l += (CIFRE[ch][0] as String).length() + 1
	return l - 1


static func _scrie(img: Image, text: String, x: int, y: int, cul: Color, marire: int) -> void:
	for ch in text:
		var g: Array = CIFRE[ch]
		_bitmap(img, g, x, y, cul, marire, false)
		x += ((g[0] as String).length() + 1) * marire


static func _scrie_intors(img: Image, text: String, x: int, y: int, cul: Color) -> void:
	# textul întors cu 180° (colțul de jos): literele în ordine inversă, fiecare întoarsă
	var litere := []
	for ch in text:
		litere.push_front(ch)
	for ch: String in litere:
		var g: Array = CIFRE[ch]
		_bitmap(img, g, x, y, cul, 1, true)
		x += (g[0] as String).length() + 1
