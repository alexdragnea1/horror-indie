class_name FizicaBiliard
extends RefCounted
## Fizica mesei de biliard de la „URBAN”, în 2D, pe postav (metri): x = lungimea mesei (±L/2), y = lățimea (±W/2).
## Bila 0 e cea albă. Fără Godot physics: pași mici (`PAS`), frecare de rostogolire, ciocniri elastice între bile,
## mantinelele (cu „gurile” buzunarelor tăiate în ele și colțurile lor, de care bilele se lovesc ca de un punct) și
## cele 6 buzunare (o bilă care trece de linia mantinelei în dreptul unei guri cade).
## După o lovitură: `prima_atinsa` (prima bilă lovită de albă, -1 = niciuna), `intrate` (în ordine), `sunete`
## ([punct, viteză, fel]: 0 = bilă de bilă, 1 = mantinelă, 2 = buzunar; jocul le consumă și le golește).

const R := 0.0286
const L := 2.24
const W := 1.12
## Cât de largi sunt gurile buzunarelor de-a lungul mantinelei (ca în bar.py: colțurile 7,5 cm, mijlocul 6,5 cm).
const GURA_COLT := 0.075
const GURA_MIJLOC := 0.065
## Frânarea: constantă (m/s²) + proporțională cu viteza (1/s).
const FRECARE := 0.28
const AMORTIZARE := 0.1
const ELASTIC_BILE := 0.95
const ELASTIC_MANTA := 0.75
const PAS := 1.0 / 300.0
const OPRIT := 0.006

var poz: Array[Vector2] = []
var vit: Array[Vector2] = []
var in_joc: Array[bool] = []
var prima_atinsa := -1
var intrate: Array[int] = []
var sunete: Array = []

## Colțurile mantinelelor de la gurile buzunarelor („fălcile”).
var _falci: Array[Vector2] = []


func _init() -> void:
	for i in 16:
		poz.append(Vector2.ZERO)
		vit.append(Vector2.ZERO)
		in_joc.append(true)
	for sy: float in [-1.0, 1.0]:
		for x: float in [-(L / 2 - GURA_COLT), -GURA_MIJLOC, GURA_MIJLOC, L / 2 - GURA_COLT]:
			_falci.append(Vector2(x, sy * W / 2))
		for sx: float in [-1.0, 1.0]:
			_falci.append(Vector2(sx * L / 2, sy * (W / 2 - GURA_COLT)))


## Centrul fiecărui buzunar (pentru AI și pentru animația de căzut), în aceeași ordine ca în bar.py.
static func buzunare() -> Array[Vector2]:
	return [Vector2(-L / 2 - 0.01, -W / 2 - 0.01), Vector2(L / 2 + 0.01, -W / 2 - 0.01), Vector2(-L / 2 - 0.01, W / 2 + 0.01),
		Vector2(L / 2 + 0.01, W / 2 + 0.01), Vector2(0.0, -W / 2 - 0.03), Vector2(0.0, W / 2 + 0.03)]


## Așază bilele: albă la „head spot”, triunghiul cu vârful la „foot spot”, 8 în mijlocul rândului al treilea, în colțurile
## din spate o plină și una cu dungă, restul la întâmplare.
func aseaza(rng: RandomNumberGenerator) -> void:
	for i in 16:
		in_joc[i] = true
		vit[i] = Vector2.ZERO
	poz[0] = Vector2(-L / 4, 0.0)
	var restul: Array[int] = []
	for n in range(1, 16):
		if n != 8:
			restul.append(n)
	# amestecat cu generatorul primit (testele pot repeta exact aceeași așezare)
	for k in range(restul.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp := restul[k]
		restul[k] = restul[j]
		restul[j] = tmp
	var plina := restul.filter(func(n: int) -> bool: return n < 8)[0] as int
	var dunga := restul.filter(func(n: int) -> bool: return n > 8)[0] as int
	restul.erase(plina)
	restul.erase(dunga)
	var colturi := [plina, dunga] if rng.randf() < 0.5 else [dunga, plina]
	var dx := 2.0 * R * cos(PI / 6.0) + 0.0004
	var k_rest := 0
	for rand in 5:
		for m in rand + 1:
			var p := Vector2(L / 4 + rand * dx, (m - rand / 2.0) * (2.0 * R + 0.0004))
			var n := 0
			if rand == 2 and m == 1:
				n = 8
			elif rand == 4 and m == 0:
				n = colturi[0]
			elif rand == 4 and m == 4:
				n = colturi[1]
			else:
				n = restul[k_rest]
				k_rest += 1
			poz[n] = p


func incepe_lovitura(viteza: Vector2) -> void:
	vit[0] = viteza
	prima_atinsa = -1
	intrate.clear()


func se_misca() -> bool:
	for i in 16:
		if in_joc[i] and vit[i] != Vector2.ZERO:
			return true
	return false


## Înaintează `secunde` (în pași de `PAS`).
func avanseaza(secunde: float) -> void:
	var n := maxi(1, int(round(secunde / PAS)))
	for k in n:
		_pas(PAS)


func _pas(dt: float) -> void:
	for i in 16:
		if not in_joc[i] or vit[i] == Vector2.ZERO:
			continue
		poz[i] += vit[i] * dt
		var v := vit[i].length()
		var nou := v - (FRECARE + AMORTIZARE * v) * dt
		vit[i] = Vector2.ZERO if nou <= OPRIT else vit[i] * (nou / v)
	for i in 16:
		if in_joc[i]:
			_margini(i)
	for i in 16:
		if not in_joc[i]:
			continue
		for j in range(i + 1, 16):
			if not in_joc[j]:
				continue
			var d := poz[j] - poz[i]
			var dist := d.length()
			if dist >= 2.0 * R or dist < 0.000001:
				continue
			var n := d / dist
			var adanc := 2.0 * R - dist
			poz[i] -= n * adanc * 0.5
			poz[j] += n * adanc * 0.5
			var rel := (vit[i] - vit[j]).dot(n)
			if rel <= 0.0:
				continue
			var impuls := rel * (1.0 + ELASTIC_BILE) * 0.5
			vit[i] -= n * impuls
			vit[j] += n * impuls
			if prima_atinsa == -1 and (i == 0 or j == 0):
				prima_atinsa = j if i == 0 else i
			sunete.append([(poz[i] + poz[j]) * 0.5, rel, 0])


## Mantinelele, fălcile buzunarelor și căderea în buzunare.
func _margini(i: int) -> void:
	var p := poz[i]
	var v := vit[i]
	var in_gura_lunga := absf(p.x) > L / 2 - GURA_COLT or absf(p.x) < GURA_MIJLOC
	var in_gura_scurta := absf(p.y) > W / 2 - GURA_COLT
	# a trecut de linia mantinelei în dreptul unei guri: cade în buzunar
	if (absf(p.y) > W / 2 - R * 0.25 and in_gura_lunga) or (absf(p.x) > L / 2 - R * 0.25 and in_gura_scurta) \
			or absf(p.x) > L / 2 + 0.08 or absf(p.y) > W / 2 + 0.08:
		in_joc[i] = false
		sunete.append([p, v.length(), 2])
		vit[i] = Vector2.ZERO
		intrate.append(i)
		return
	# mantinelele lungi (y = ±W/2) și scurte (x = ±L/2), cu golurile gurilor
	var lim_y := W / 2 - R
	if absf(p.y) > lim_y and not in_gura_lunga:
		var s := signf(p.y)
		p.y = s * lim_y
		if v.y * s > 0.0:
			sunete.append([p, absf(v.y), 1])
			v.y = -v.y * ELASTIC_MANTA
			v.x *= 0.96
	var lim_x := L / 2 - R
	if absf(p.x) > lim_x and not in_gura_scurta:
		var s := signf(p.x)
		p.x = s * lim_x
		if v.x * s > 0.0:
			sunete.append([p, absf(v.x), 1])
			v.x = -v.x * ELASTIC_MANTA
			v.y *= 0.96
	# fălcile (colțurile mantinelelor de la guri)
	for f in _falci:
		var d := p - f
		var dist := d.length()
		if dist < R and dist > 0.000001:
			var n := d / dist
			p = f + n * R
			var vn := v.dot(n)
			if vn < 0.0:
				sunete.append([p, -vn, 1])
				v -= n * vn * (1.0 + ELASTIC_MANTA)
	poz[i] = p
	vit[i] = v


# ---------------------------------------------------------------- pentru AI și pentru linia de ochire

## Prima bilă lovită de albă trasă pe `directie` (unitar): [index, punctul albei la contact] sau [-1, punctul unde
## lovește mantinela].
func primul_contact(directie: Vector2) -> Array:
	var c := poz[0]
	var cel_mai_aproape := INF
	var gasit := -1
	for j in range(1, 16):
		if not in_joc[j]:
			continue
		var t := _contact(c, directie, poz[j], 2.0 * R)
		if t >= 0.0 and t < cel_mai_aproape:
			cel_mai_aproape = t
			gasit = j
	if gasit >= 0:
		return [gasit, c + directie * cel_mai_aproape]
	# până la mantinelă
	var tx := INF
	var ty := INF
	if absf(directie.x) > 0.0001:
		tx = ((signf(directie.x) * (L / 2 - R)) - c.x) / directie.x
	if absf(directie.y) > 0.0001:
		ty = ((signf(directie.y) * (W / 2 - R)) - c.y) / directie.y
	return [-1, c + directie * minf(tx, ty)]


## Distanța pe care o parcurge un punct de la `a` pe `d` până ajunge la `raza` de `b` (-1 = nu ajunge).
static func _contact(a: Vector2, d: Vector2, b: Vector2, raza: float) -> float:
	var ab := b - a
	var proiectie := ab.dot(d)
	if proiectie <= 0.0:
		return -1.0
	var perp2 := ab.length_squared() - proiectie * proiectie
	if perp2 > raza * raza:
		return -1.0
	return proiectie - sqrt(raza * raza - perp2)


## E liber drumul unei bile de la `a` la `b` (nicio bilă din joc, în afară de `fara`, mai aproape de 2R de segment)?
func drum_liber(a: Vector2, b: Vector2, fara: Array[int]) -> bool:
	var ab := b - a
	var lung := ab.length()
	if lung < 0.0001:
		return true
	var d := ab / lung
	for j in 16:
		if not in_joc[j] or fara.has(j):
			continue
		var t := clampf((poz[j] - a).dot(d), 0.0, lung)
		if (a + d * t).distance_to(poz[j]) < 2.0 * R - 0.001:
			return false
	return true
