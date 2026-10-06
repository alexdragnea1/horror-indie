class_name ManaPoker
extends RefCounted
## Matematica pokerului (Texas Hold'em): evaluarea mâinilor și cât de bună e o mână pentru adversarii conduși de calculator.
## Cărțile sunt numere 0..51 (vezi Carti). `scor(carti)` = cea mai bună mână de 5 din 5–7 cărți, ca număr: mai mare =
## mai bună (categoria * 15^5 + valorile care departajează), deci două mâini se compară direct.

const NUME_CATEGORII := ["High Card", "Pair", "Two Pair", "Three of a Kind", "Straight", "Flush", "Full House",
	"Four of a Kind", "Straight Flush"]
const BAZA := 759375  # 15^5


## Cea mai bună mână de 5 din `carti` (5, 6 sau 7 cărți).
static func scor(carti: Array) -> int:
	var n := carti.size()
	if n < 5:
		return _scor_partial(carti)
	var cel_mai_bun := -1
	var mana: Array = [0, 0, 0, 0, 0]
	for a in n:
		for b in range(a + 1, n):
			for c in range(b + 1, n):
				for d in range(c + 1, n):
					for e in range(d + 1, n):
						mana[0] = carti[a]
						mana[1] = carti[b]
						mana[2] = carti[c]
						mana[3] = carti[d]
						mana[4] = carti[e]
						var s := _scor5(mana)
						if s > cel_mai_bun:
							cel_mai_bun = s
	return cel_mai_bun


static func categorie(s: int) -> int:
	return s / BAZA


## „Two Pair”, „Royal Flush” etc.
static func nume(s: int) -> String:
	var cat := categorie(s)
	if cat == 8 and (s % BAZA) / 50625 == 12:
		return "Royal Flush"
	return NUME_CATEGORII[cat]


static func _scor5(mana: Array) -> int:
	var valori: Array[int] = []
	var culori := {}
	var numar := {}
	for c: int in mana:
		var v := c % 13
		valori.append(v)
		culori[c / 13] = true
		numar[v] = int(numar.get(v, 0)) + 1
	valori.sort()
	valori.reverse()
	var culoare := culori.size() == 1
	# chinta (cu A-2-3-4-5, unde asul e mic)
	var chinta := numar.size() == 5 and valori[0] - valori[4] == 4
	var varf_chinta := valori[0]
	if numar.size() == 5 and valori[0] == 12 and valori[1] == 3 and valori[4] == 0:
		chinta = true
		varf_chinta = 3
	if chinta and culoare:
		return 8 * BAZA + varf_chinta * 50625
	# grupele: întâi după câte sunt, apoi după valoare
	var grupe: Array = []
	for v: int in numar:
		grupe.append([int(numar[v]), v])
	grupe.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0] or (x[0] == y[0] and x[1] > y[1]))
	var ordine: Array[int] = []
	for g: Array in grupe:
		for k in g[0]:
			ordine.append(g[1])
	var cat := 0
	if grupe[0][0] == 4:
		cat = 7
	elif grupe[0][0] == 3 and grupe[1][0] == 2:
		cat = 6
	elif culoare:
		cat = 5
		ordine = valori
	elif chinta:
		return 4 * BAZA + varf_chinta * 50625
	elif grupe[0][0] == 3:
		cat = 3
	elif grupe[0][0] == 2 and grupe[1][0] == 2:
		cat = 2
	elif grupe[0][0] == 2:
		cat = 1
	else:
		cat = 0
	return cat * BAZA + ordine[0] * 50625 + ordine[1] * 3375 + ordine[2] * 225 + ordine[3] * 15 + ordine[4]


## Cu mai puțin de 5 cărți (doar pentru „cât de bună e mâna” înainte de flop): perechea sau cartea mare.
static func _scor_partial(carti: Array) -> int:
	var v: Array[int] = []
	for c: int in carti:
		v.append(c % 13)
	v.sort()
	v.reverse()
	while v.size() < 5:
		v.append(0)
	if carti.size() >= 2 and v[0] == v[1]:
		return BAZA + v[0] * 50625
	return v[0] * 50625 + v[1] * 3375


## Cât de bună e mâna unui adversar acum (0..1), din cărțile lui și ce e pe masă. Folosit de AI.
static func putere(mana: Array, masa: Array) -> float:
	var a: int = mana[0] % 13
	var b: int = mana[1] % 13
	if masa.is_empty():
		# înainte de flop: perechea contează cel mai mult, apoi cărțile mari, aceeași culoare, cărțile apropiate
		var mare := maxi(a, b)
		var mica := mini(a, b)
		if a == b:
			return 0.5 + float(a) / 24.0
		var p := float(mare + mica) / 24.0 * 0.55 + float(mare) / 12.0 * 0.12
		if mana[0] / 13 == mana[1] / 13:
			p += 0.06
		if mare - mica == 1:
			p += 0.04
		elif mare - mica == 2:
			p += 0.02
		return clampf(p, 0.05, 0.75)
	var toate := mana.duplicate()
	toate.append_array(masa)
	var s := scor(toate)
	var cat := categorie(s)
	var p := 0.0
	match cat:
		0:
			p = 0.08 + float(maxi(a, b)) / 12.0 * 0.12
		1:
			# perechea mare (cu cea mai mare carte de pe masă) e mult mai bună decât una mică
			var pereche := (s % BAZA) / 50625
			var maxim_masa := 0
			for c: int in masa:
				maxim_masa = maxi(maxim_masa, c % 13)
			p = 0.3 + (0.15 if pereche >= maxim_masa else 0.0) + float(pereche) / 12.0 * 0.08
			# perechea doar de pe masă (n-ai nimic în mână) nu valorează
			if a != pereche and b != pereche:
				p = 0.18
		2:
			p = 0.6
		3:
			p = 0.72
		4:
			p = 0.8
		5:
			p = 0.85
		6:
			p = 0.92
		_:
			p = 0.98
	return p
