class_name Sah
extends RefCounted
## Regulile șahului și „creierul” lui Jean (casa_jean.tscn, MasaSah). Fără nimic 3D: doar tabla și mutările.
##   var s := Sah.new()            -> poziția de început, mută albul (jucătorul)
##   s.mutari_legale()              -> Array[int] (mutările codate, vezi `muta`)
##   s.muta(m) / s.anuleaza()       -> joacă / ia înapoi ultima mutare
##   s.rezultat()                   -> REZ_NIMIC / REZ_MAT / REZ_PAT / REZ_REMIZA
##   s.cea_mai_buna(adancime)       -> mutarea aleasă de calculator pentru cine e la mutare
## Tabla: 64 de pătrate, index = rand * 8 + coloana; randul 0 = randul 1 al albului (jos, la jucător).
## Piesele: 0 = gol; 1..6 = alb (pion, cal, nebun, tura, regina, rege); 7..12 = negru (aceleași + 6).
## Mutarea e un int: de_la | (la << 6) | (promovare << 12) | (fel << 16), cu `fel` = FEL_*.
## Totul e regulă de șah adevărată: rocada (nu prin șah, nu din șah), en passant, promovarea (mereu în regină:
## pe ecran nu întrebăm), mat, pat, remiză la material insuficient, la 50 de mutări și la poziție repetată de 3 ori.

const PION := 1
const CAL := 2
const NEBUN := 3
const TURA := 4
const REGINA := 5
const REGE := 6
const ALB := 0
const NEGRU := 1

const FEL_NORMAL := 0
const FEL_DUBLU := 1  # pionul sare două pătrate
const FEL_EN_PASSANT := 2
const FEL_ROCADA := 3

const REZ_NIMIC := 0
const REZ_MAT := 1  # cel la mutare e mat
const REZ_PAT := 2
const REZ_REMIZA := 3  # material insuficient, 50 de mutări, repetiție

## Valoarea pieselor (centipioni), după tip.
const VALOARE := [0, 100, 320, 330, 500, 900, 0]
const MAT := 100000

## Tabelele de poziție (pentru alb, rândul 7 primul, ca pe hârtie): unde îi place fiecărei piese.
const PST_PION := [
	0, 0, 0, 0, 0, 0, 0, 0,
	50, 50, 50, 50, 50, 50, 50, 50,
	10, 10, 20, 30, 30, 20, 10, 10,
	5, 5, 10, 25, 25, 10, 5, 5,
	0, 0, 0, 20, 20, 0, 0, 0,
	5, -5, -10, 0, 0, -10, -5, 5,
	5, 10, 10, -20, -20, 10, 10, 5,
	0, 0, 0, 0, 0, 0, 0, 0]
const PST_CAL := [
	-50, -40, -30, -30, -30, -30, -40, -50,
	-40, -20, 0, 0, 0, 0, -20, -40,
	-30, 0, 10, 15, 15, 10, 0, -30,
	-30, 5, 15, 20, 20, 15, 5, -30,
	-30, 0, 15, 20, 20, 15, 0, -30,
	-30, 5, 10, 15, 15, 10, 5, -30,
	-40, -20, 0, 5, 5, 0, -20, -40,
	-50, -40, -30, -30, -30, -30, -40, -50]
const PST_NEBUN := [
	-20, -10, -10, -10, -10, -10, -10, -20,
	-10, 0, 0, 0, 0, 0, 0, -10,
	-10, 0, 5, 10, 10, 5, 0, -10,
	-10, 5, 5, 10, 10, 5, 5, -10,
	-10, 0, 10, 10, 10, 10, 0, -10,
	-10, 10, 10, 10, 10, 10, 10, -10,
	-10, 5, 0, 0, 0, 0, 5, -10,
	-20, -10, -10, -10, -10, -10, -10, -20]
const PST_TURA := [
	0, 0, 0, 0, 0, 0, 0, 0,
	5, 10, 10, 10, 10, 10, 10, 5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	-5, 0, 0, 0, 0, 0, 0, -5,
	0, 0, 0, 5, 5, 0, 0, 0]
const PST_REGINA := [
	-20, -10, -10, -5, -5, -10, -10, -20,
	-10, 0, 0, 0, 0, 0, 0, -10,
	-10, 0, 5, 5, 5, 5, 0, -10,
	-5, 0, 5, 5, 5, 5, 0, -5,
	0, 0, 5, 5, 5, 5, 0, -5,
	-10, 5, 5, 5, 5, 5, 0, -10,
	-10, 0, 5, 0, 0, 0, 0, -10,
	-20, -10, -10, -5, -5, -10, -10, -20]
const PST_REGE := [
	-30, -40, -40, -50, -50, -40, -40, -30,
	-30, -40, -40, -50, -50, -40, -40, -30,
	-30, -40, -40, -50, -50, -40, -40, -30,
	-30, -40, -40, -50, -50, -40, -40, -30,
	-20, -30, -30, -40, -40, -30, -30, -20,
	-10, -20, -20, -20, -20, -20, -20, -10,
	20, 20, 0, 0, 0, 0, 20, 20,
	20, 30, 10, 0, 0, 10, 30, 20]

const DIR_CAL := [[1, 2], [2, 1], [2, -1], [1, -2], [-1, -2], [-2, -1], [-2, 1], [-1, 2]]
const DIR_NEBUN := [[1, 1], [1, -1], [-1, 1], [-1, -1]]
const DIR_TURA := [[1, 0], [-1, 0], [0, 1], [0, -1]]
const DIR_REGE := [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]

var tabla: PackedInt32Array
var la_mutare := ALB
## Rocadele încă posibile: 1 = alb mic, 2 = alb mare, 4 = negru mic, 8 = negru mare.
var rocade := 15
## Pătratul pe care se poate lua en passant (-1 = niciunul).
var en_passant := -1
## Mutări de la ultima captură sau mutare de pion (pentru regula de 50).
var semi_mutari := 0
## Ultima mutare jucată (pentru 3D: ce s-a mișcat), -1 = niciuna.
var ultima := -1

var _istoric: Array = []  # [mutare, capturat, rocade, en_passant, semi_mutari]
var _pozitii: Array[String] = []
var _noduri := 0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	reseteaza()


func reseteaza() -> void:
	tabla = PackedInt32Array()
	tabla.resize(64)
	var spate := [TURA, CAL, NEBUN, REGINA, REGE, NEBUN, CAL, TURA]
	for c in 8:
		tabla[c] = spate[c]
		tabla[8 + c] = PION
		tabla[48 + c] = PION + 6
		tabla[56 + c] = spate[c] + 6
	la_mutare = ALB
	rocade = 15
	en_passant = -1
	semi_mutari = 0
	ultima = -1
	_istoric.clear()
	_pozitii = [_cheie()]


func copie() -> Sah:
	var s := Sah.new()
	s.tabla = tabla.duplicate()
	s.la_mutare = la_mutare
	s.rocade = rocade
	s.en_passant = en_passant
	s.semi_mutari = semi_mutari
	s._pozitii = _pozitii.duplicate()
	return s


# ------------------------------------------------------------------ ajutoare

static func culoare(piesa: int) -> int:
	return -1 if piesa == 0 else (ALB if piesa <= 6 else NEGRU)


static func tip(piesa: int) -> int:
	return 0 if piesa == 0 else ((piesa - 1) % 6) + 1


static func de_la(m: int) -> int:
	return m & 63


static func la(m: int) -> int:
	return (m >> 6) & 63


static func promovare(m: int) -> int:
	return (m >> 12) & 15


static func fel(m: int) -> int:
	return (m >> 16) & 3


static func _m(a: int, b: int, promo := 0, f := FEL_NORMAL) -> int:
	return a | (b << 6) | (promo << 12) | (f << 16)


## Ce piesă e luată de mutarea `m` (0 = nimic), înainte s-o joci.
func capturat_de(m: int) -> int:
	if fel(m) == FEL_EN_PASSANT:
		return PION + (6 if la_mutare == ALB else 0)
	return tabla[la(m)]


## Pătratul piesei luate (la en passant nu e cel pe care ajungi).
func patrat_capturat(m: int) -> int:
	if fel(m) == FEL_EN_PASSANT:
		return la(m) + (-8 if la_mutare == ALB else 8)
	return la(m)


func _cheie() -> String:
	return "%s|%d|%d|%d" % [str(tabla), la_mutare, rocade, en_passant]


# ------------------------------------------------------------------ atacuri

## E pătratul `p` atacat de culoarea `de`?
func atacat(p: int, de: int) -> bool:
	var r := p >> 3
	var c := p & 7
	var baza := 0 if de == ALB else 6
	# pioni
	var dr := -1 if de == ALB else 1  # pionul alb atacă în sus, deci vine de jos
	for dc in [-1, 1]:
		var rr := r + dr
		var cc: int = c + dc
		if rr >= 0 and rr < 8 and cc >= 0 and cc < 8 and tabla[rr * 8 + cc] == PION + baza:
			return true
	for d in DIR_CAL:
		var rr: int = r + d[0]
		var cc: int = c + d[1]
		if rr >= 0 and rr < 8 and cc >= 0 and cc < 8 and tabla[rr * 8 + cc] == CAL + baza:
			return true
	for d in DIR_REGE:
		var rr: int = r + d[0]
		var cc: int = c + d[1]
		if rr >= 0 and rr < 8 and cc >= 0 and cc < 8 and tabla[rr * 8 + cc] == REGE + baza:
			return true
	for d in DIR_NEBUN:
		if _raza_atinge(r, c, d, NEBUN + baza, REGINA + baza):
			return true
	for d in DIR_TURA:
		if _raza_atinge(r, c, d, TURA + baza, REGINA + baza):
			return true
	return false


func _raza_atinge(r: int, c: int, d: Array, a: int, b: int) -> bool:
	var rr: int = r + d[0]
	var cc: int = c + d[1]
	while rr >= 0 and rr < 8 and cc >= 0 and cc < 8:
		var x := tabla[rr * 8 + cc]
		if x != 0:
			return x == a or x == b
		rr += d[0]
		cc += d[1]
	return false


func patrat_rege(cine: int) -> int:
	return tabla.find(REGE + (0 if cine == ALB else 6))


func in_sah(cine := -1) -> bool:
	if cine < 0:
		cine = la_mutare
	var p := patrat_rege(cine)
	return p >= 0 and atacat(p, 1 - cine)


# ------------------------------------------------------------------ mutări

func _pseudo(doar_capturi := false) -> Array[int]:
	var lista: Array[int] = []
	var eu := la_mutare
	var baza := 0 if eu == ALB else 6
	for p in 64:
		var x := tabla[p]
		if x == 0 or culoare(x) != eu:
			continue
		var t := x - baza
		var r := p >> 3
		var c := p & 7
		match t:
			PION:
				var sus := 1 if eu == ALB else -1
				var ultim := 7 if eu == ALB else 0
				var start := 1 if eu == ALB else 6
				var r1 := r + sus
				if r1 >= 0 and r1 < 8:
					if not doar_capturi or r1 == ultim:
						if tabla[r1 * 8 + c] == 0:
							_pion(lista, p, r1 * 8 + c, r1 == ultim)
							if r == start and tabla[(r1 + sus) * 8 + c] == 0 and not doar_capturi:
								lista.append(_m(p, (r1 + sus) * 8 + c, 0, FEL_DUBLU))
					for dc in [-1, 1]:
						var cc: int = c + dc
						if cc < 0 or cc > 7:
							continue
						var tinta := r1 * 8 + cc
						var y := tabla[tinta]
						if y != 0 and culoare(y) != eu:
							_pion(lista, p, tinta, r1 == ultim)
						elif tinta == en_passant:
							lista.append(_m(p, tinta, 0, FEL_EN_PASSANT))
			CAL:
				_salturi(lista, p, r, c, DIR_CAL, doar_capturi)
			NEBUN:
				_raze(lista, p, r, c, DIR_NEBUN, doar_capturi)
			TURA:
				_raze(lista, p, r, c, DIR_TURA, doar_capturi)
			REGINA:
				_raze(lista, p, r, c, DIR_NEBUN, doar_capturi)
				_raze(lista, p, r, c, DIR_TURA, doar_capturi)
			REGE:
				_salturi(lista, p, r, c, DIR_REGE, doar_capturi)
				if not doar_capturi:
					_rocade(lista, eu)
	return lista


func _pion(lista: Array[int], a: int, b: int, promoveaza: bool) -> void:
	lista.append(_m(a, b, REGINA if promoveaza else 0))


func _salturi(lista: Array[int], p: int, r: int, c: int, dirs: Array, doar_capturi: bool) -> void:
	for d in dirs:
		var rr: int = r + d[0]
		var cc: int = c + d[1]
		if rr < 0 or rr > 7 or cc < 0 or cc > 7:
			continue
		var y := tabla[rr * 8 + cc]
		if y == 0:
			if not doar_capturi:
				lista.append(_m(p, rr * 8 + cc))
		elif culoare(y) != la_mutare:
			lista.append(_m(p, rr * 8 + cc))


func _raze(lista: Array[int], p: int, r: int, c: int, dirs: Array, doar_capturi: bool) -> void:
	for d in dirs:
		var rr: int = r + d[0]
		var cc: int = c + d[1]
		while rr >= 0 and rr < 8 and cc >= 0 and cc < 8:
			var y := tabla[rr * 8 + cc]
			if y == 0:
				if not doar_capturi:
					lista.append(_m(p, rr * 8 + cc))
			else:
				if culoare(y) != la_mutare:
					lista.append(_m(p, rr * 8 + cc))
				break
			rr += d[0]
			cc += d[1]


func _rocade(lista: Array[int], eu: int) -> void:
	var rand := 0 if eu == ALB else 56
	var mic := 1 if eu == ALB else 4
	var mare := 2 if eu == ALB else 8
	var dusman := 1 - eu
	if tabla[rand + 4] != REGE + (0 if eu == ALB else 6) or atacat(rand + 4, dusman):
		return
	if rocade & mic and tabla[rand + 5] == 0 and tabla[rand + 6] == 0 \
			and not atacat(rand + 5, dusman) and not atacat(rand + 6, dusman):
		lista.append(_m(rand + 4, rand + 6, 0, FEL_ROCADA))
	if rocade & mare and tabla[rand + 3] == 0 and tabla[rand + 2] == 0 and tabla[rand + 1] == 0 \
			and not atacat(rand + 3, dusman) and not atacat(rand + 2, dusman):
		lista.append(_m(rand + 4, rand + 2, 0, FEL_ROCADA))


func mutari_legale() -> Array[int]:
	var bune: Array[int] = []
	var eu := la_mutare
	for m in _pseudo():
		muta(m, false)
		if not in_sah(eu):
			bune.append(m)
		anuleaza()
	return bune


## Joacă mutarea (trebuie să fie legală). `tine_minte` = o pune la repetiții (în căutare nu e nevoie).
func muta(m: int, tine_minte := true) -> void:
	var a := de_la(m)
	var b := la(m)
	var f := fel(m)
	var piesa := tabla[a]
	var capturat := tabla[b]
	var p_capt := b
	if f == FEL_EN_PASSANT:
		p_capt = b + (-8 if la_mutare == ALB else 8)
		capturat = tabla[p_capt]
		tabla[p_capt] = 0
	_istoric.append([m, capturat, rocade, en_passant, semi_mutari, ultima])
	tabla[b] = piesa
	tabla[a] = 0
	if promovare(m) != 0:
		tabla[b] = promovare(m) + (0 if la_mutare == ALB else 6)
	if f == FEL_ROCADA:
		if b > a:  # mică: tura de pe h vine pe f
			tabla[b - 1] = tabla[b + 1]
			tabla[b + 1] = 0
		else:  # mare: tura de pe a vine pe d
			tabla[b + 1] = tabla[b - 2]
			tabla[b - 2] = 0
	en_passant = (a + b) / 2 if f == FEL_DUBLU else -1
	# rocadele se pierd când pleacă regele / tura, sau când o tură e luată pe loc
	for p in [a, b]:
		match p:
			0: rocade &= ~2
			4: rocade &= ~3
			7: rocade &= ~1
			56: rocade &= ~8
			60: rocade &= ~12
			63: rocade &= ~4
	semi_mutari = 0 if (tip(piesa) == PION or capturat != 0) else semi_mutari + 1
	la_mutare = 1 - la_mutare
	ultima = m
	if tine_minte:
		_pozitii.append(_cheie())


func anuleaza() -> void:
	var h: Array = _istoric.pop_back()
	var m: int = h[0]
	var a := de_la(m)
	var b := la(m)
	var f := fel(m)
	la_mutare = 1 - la_mutare
	var piesa := tabla[b]
	if promovare(m) != 0:
		piesa = PION + (0 if la_mutare == ALB else 6)
	tabla[a] = piesa
	tabla[b] = 0
	if f == FEL_EN_PASSANT:
		tabla[b + (-8 if la_mutare == ALB else 8)] = h[1]
	else:
		tabla[b] = h[1]
	if f == FEL_ROCADA:
		if b > a:
			tabla[b + 1] = tabla[b - 1]
			tabla[b - 1] = 0
		else:
			tabla[b - 2] = tabla[b + 1]
			tabla[b + 1] = 0
	rocade = h[2]
	en_passant = h[3]
	semi_mutari = h[4]
	ultima = h[5]
	if _pozitii.size() > _istoric.size() + 1:
		_pozitii.pop_back()


# ------------------------------------------------------------------ rezultat

func rezultat() -> int:
	if mutari_legale().is_empty():
		return REZ_MAT if in_sah() else REZ_PAT
	if semi_mutari >= 100 or _material_insuficient() or _pozitii.count(_pozitii[-1]) >= 3:
		return REZ_REMIZA
	return REZ_NIMIC


func _material_insuficient() -> bool:
	var mici := 0
	for x in tabla:
		var t := tip(x)
		if t == PION or t == TURA or t == REGINA:
			return false
		if t == CAL or t == NEBUN:
			mici += 1
	return mici <= 1


# ------------------------------------------------------------------ calculatorul

## Scorul poziției din punctul de vedere al celui la mutare (centipioni).
func evalueaza() -> int:
	var scor := 0
	for p in 64:
		var x := tabla[p]
		if x == 0:
			continue
		var t := tip(x)
		var alb := x <= 6
		# tabelele sunt scrise pentru alb, rândul 7 primul
		var i := ((7 - (p >> 3)) * 8 + (p & 7)) if alb else p
		var v: int = VALOARE[t]
		match t:
			PION: v += PST_PION[i]
			CAL: v += PST_CAL[i]
			NEBUN: v += PST_NEBUN[i]
			TURA: v += PST_TURA[i]
			REGINA: v += PST_REGINA[i]
			REGE: v += PST_REGE[i]
		scor += v if alb else -v
	return scor if la_mutare == ALB else -scor


## Mutarea unui începător de ~100 elo (owner 24.11, ca boții cei mai slabi de pe site-urile de șah): nu se uită
## deloc înainte. Vede doar ce e chiar acum pe tablă: un mat la o mutare îl dă de multe ori (`sansa_mat`), o piesă
## de luat o ia des, mereu pe cea mai mare (`sansa_lacom`), fără să se întrebe dacă e apărată; altfel mută la
## întâmplare. Așa lasă piese în priză, nu-și apără regele și ia „otrava”.
func mutare_incepator(sansa_mat := 0.5, sansa_lacom := 0.55, saminta := 0) -> int:
	_rng.seed = saminta if saminta != 0 else Time.get_ticks_usec()
	var mutari := mutari_legale()
	if mutari.is_empty():
		return -1
	if _rng.randf() < sansa_mat:
		for m in mutari:
			muta(m, false)
			var mat := mutari_legale().is_empty() and in_sah()
			anuleaza()
			if mat:
				return m
	if _rng.randf() < sansa_lacom:
		var cea_lacoma := -1
		var cel_mai_mult := 0
		for m in mutari:
			var luat := capturat_de(m)
			if luat != 0 and VALOARE[tip(luat)] > cel_mai_mult:
				cel_mai_mult = VALOARE[tip(luat)]
				cea_lacoma = m
		if cea_lacoma != -1:
			return cea_lacoma
	return mutari[_rng.randi_range(0, mutari.size() - 1)]


## Mutarea aleasă pentru cel la mutare. `adancime` = câte mutări înainte se uită (plus capturile până se liniștesc);
## `zgomot` = câți centipioni de „gust” la întâmplare primește fiecare mutare (0 = mereu cea mai bună).
func cea_mai_buna(adancime: int, zgomot := 0, saminta := 0) -> int:
	_rng.seed = saminta if saminta != 0 else Time.get_ticks_usec()
	_noduri = 0
	var mutari := mutari_legale()
	if mutari.is_empty():
		return -1
	_ordoneaza(mutari)
	var cea_buna := mutari[0]
	var maxim := -MAT * 2
	for m in mutari:
		muta(m, false)
		var scor := -_negamax(adancime - 1, -MAT * 2, -maxim + zgomot, 1)
		anuleaza()
		if zgomot > 0:
			scor += _rng.randi_range(0, zgomot)
		if scor > maxim:
			maxim = scor
			cea_buna = m
	return cea_buna


func _negamax(adancime: int, alfa: int, beta: int, ply: int) -> int:
	_noduri += 1
	if adancime <= 0:
		return _linistire(alfa, beta, 0)
	var eu := la_mutare
	var mutari := _pseudo()
	_ordoneaza(mutari)
	var legale := 0
	for m in mutari:
		muta(m, false)
		if in_sah(eu):
			anuleaza()
			continue
		legale += 1
		var scor := -_negamax(adancime - 1, -beta, -alfa, ply + 1)
		anuleaza()
		if scor >= beta:
			return beta
		if scor > alfa:
			alfa = scor
	if legale == 0:
		return -MAT + ply if in_sah(eu) else 0
	return alfa


## Capturile, până nu mai e nimic de luat (altfel se oprește la mijlocul unui schimb și „vede” greșit).
func _linistire(alfa: int, beta: int, adanc: int) -> int:
	_noduri += 1
	var pe_loc := evalueaza()
	if pe_loc >= beta:
		return beta
	if pe_loc > alfa:
		alfa = pe_loc
	if adanc >= 4:
		return alfa
	var eu := la_mutare
	var mutari := _pseudo(true)
	_ordoneaza(mutari)
	for m in mutari:
		muta(m, false)
		if in_sah(eu):
			anuleaza()
			continue
		var scor := -_linistire(-beta, -alfa, adanc + 1)
		anuleaza()
		if scor >= beta:
			return beta
		if scor > alfa:
			alfa = scor
	return alfa


## Capturile întâi (cea mai valoroasă victimă cu cel mai ieftin atacator), apoi promovările.
func _ordoneaza(mutari: Array[int]) -> void:
	mutari.sort_custom(func(x: int, y: int) -> bool: return _prioritate(x) > _prioritate(y))


func _prioritate(m: int) -> int:
	var v := 0
	var capt := capturat_de(m)
	if capt != 0:
		v += VALOARE[tip(capt)] * 10 - VALOARE[tip(tabla[de_la(m)])]
	if promovare(m) != 0:
		v += 8000
	return v
