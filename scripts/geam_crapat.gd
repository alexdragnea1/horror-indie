class_name GeamCrapat
extends StaticBody3D
## Un geam prin care poți trage (owner 18.11: ghișeul funcționarei de la primărie). Pune nodul cu originea în mijlocul
## sticlei, cu Z-ul local perpendicular pe ea, și o CollisionShape3D subțire cât geamul (puțin în fața coliziunii din model).
## La glonț (`impuscat`), minge de foc (`lovit_de_foc`) sau explozie: în locul lovit apare o crăpătură (stea de fisuri cu
## o gaură mică în mijloc, desenată din cod, culorile PS2), se aude sticla, iar glonțul merge mai departe prin geam și
## lovește ce e dincolo (funcționara). Crăpăturile stau în marcajul `marcaj` (intră în salvare): la Continue sunt tot acolo.

## Ce mai primește glonțul după geam (gol = nimeni). Ex. Angajata, al cărei hitbox de geam e chiar în fața ăstuia.
@export var exclude_noduri: Array[Node] = []
@export var marcaj := "geam_primarie_crapat"
## Cât de departe merge glonțul după geam.
@export var bataie_dupa := 6.0
## Bucățile fără sticlă (în planul geamului, local; ex. golul ghișeului de jos): acolo glonțul trece fără crăpătură.
@export var goluri: Array[Rect2] = []
@export var culoare_fisuri := Color(0.86, 0.92, 0.9, 0.9)

const SUNET := preload("res://sunete/geam_crapat.ogg")
const MAX_CRAPATURI := 14
## Crăpăturile stau la 14 mm în fața planului geamului (spre tine), ca să nu pâlpâie cu sticla.
const DEPARTARE := 0.014

static var _texturi: Array[Texture2D] = []

var _ultima_ms := -1000


func _ready() -> void:
	var salvate: Variant = Stare.valoare_marcaj(marcaj, [])
	if salvate is Array:
		for c: Variant in salvate:
			if c is Array and (c as Array).size() >= 4:
				_pune(Vector2(c[0], c[1]), float(c[2]), int(c[3]), float(c[4]) if c.size() > 4 else 0.0)


func impuscat(directie: Vector3, punct := Vector3.ZERO) -> void:
	_lovit(directie, punct, "impuscat")


func lovit_de_foc(directie: Vector3, punct := Vector3.ZERO) -> void:
	_lovit(directie, punct, "lovit_de_foc")


## Crapă geamul în `punct` (global) și trimite lovitura mai departe pe `directie`.
func _lovit(directie: Vector3, punct: Vector3, metoda: String) -> void:
	if punct == Vector3.ZERO:
		punct = global_position
	# unde taie glonțul planul sticlei (lovitura poate veni de pe o formă din fața geamului, ex. a funcționarei)
	var plan := Plane(global_basis.z.normalized(), global_position)
	var taiat: Variant = plan.intersects_ray(punct - directie.normalized() * 2.0, directie.normalized())
	if taiat is Vector3 and (taiat as Vector3).distance_to(punct) < 1.0:
		punct = taiat
	var local := to_local(punct)
	# la o alică (shotgun) vin mai multe lovituri în același cadru: o singură crăpătură mare
	var acum := Time.get_ticks_msec()
	var in_gol := goluri.any(func(g: Rect2) -> bool: return g.has_point(Vector2(local.x, local.y)))
	if acum - _ultima_ms > 60 and not in_gol:
		var marime := randf_range(0.26, 0.38) if metoda == "impuscat" else 0.55
		crapa(Vector2(local.x, local.y), marime)
	_ultima_ms = acum
	_mai_departe(directie, punct, metoda)


## O crăpătură nouă la (x, y) în planul geamului (local), cu sunet; o ține minte în salvare.
func crapa(unde: Vector2, marime: float) -> void:
	var model := randi() % 4
	var unghi := randf() * TAU
	_pune(unde, marime, model, unghi)
	Sunet.reda_la(SUNET, to_global(Vector3(unde.x, unde.y, 0.0)), Sunet.VOLUM_EFECTE, 0.08)
	var salvate: Array = (Stare.valoare_marcaj(marcaj, []) as Array).duplicate() if Stare.valoare_marcaj(marcaj, []) is Array else []
	salvate.append([snappedf(unde.x, 0.001), snappedf(unde.y, 0.001), snappedf(marime, 0.01), model, snappedf(unghi, 0.01)])
	while salvate.size() > MAX_CRAPATURI:
		salvate.pop_front()
	Stare.marcheaza(marcaj, salvate)


func _pune(unde: Vector2, marime: float, model: int, unghi: float) -> void:
	var crapaturi := get_children().filter(func(n: Node) -> bool: return n.is_in_group("crapatura"))
	if crapaturi.size() >= MAX_CRAPATURI:
		crapaturi[0].queue_free()
	var m := MeshInstance3D.new()
	m.add_to_group("crapatura")
	var q := QuadMesh.new()
	q.size = Vector2.ONE * marime
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_texture = _textura(model)
	mat.albedo_color = culoare_fisuri
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.position = Vector3(unde.x, unde.y, DEPARTARE)
	m.rotation.z = unghi


## Glonțul trece prin geam: o rază de dincolo de sticlă, pe aceeași direcție.
func _mai_departe(directie: Vector3, punct: Vector3, metoda: String) -> void:
	var normala := global_basis.z.normalized()
	var cos_ := absf(directie.normalized().dot(normala))
	var de_la := punct + directie.normalized() * (0.12 / maxf(cos_, 0.2))
	var cerere := PhysicsRayQueryParameters3D.create(de_la, de_la + directie.normalized() * bataie_dupa, 1 | Ragdoll.STRAT)
	var excluse: Array[RID] = [get_rid()]
	for n in exclude_noduri:
		if n is CollisionObject3D:
			excluse.append((n as CollisionObject3D).get_rid())
	var jucator := get_tree().get_first_node_in_group("jucator") as CollisionObject3D
	if jucator:
		excluse.append(jucator.get_rid())
	cerere.exclude = excluse
	var lovit := get_world_3d().direct_space_state.intersect_ray(cerere)
	if lovit.is_empty():
		return
	var tinta: Object = lovit.collider
	if tinta == self or tinta in exclude_noduri:
		return
	if tinta.has_method(metoda):
		tinta.call(metoda, directie, lovit.position)
	elif tinta.has_method("impuscat"):
		tinta.impuscat(directie, lovit.position)
	elif tinta is RigidBody3D:
		(tinta as RigidBody3D).apply_impulse(directie.normalized() * 9.0, lovit.position - (tinta as RigidBody3D).global_position)


# ---------------------------------------------------------------- textura crăpăturii (din cod, o dată pe joc)

static func _textura(model: int) -> Texture2D:
	if _texturi.is_empty():
		for i in 4:
			_texturi.append(_deseneaza(i))
	return _texturi[model % _texturi.size()]


## O stea de fisuri: 7–10 raze care se frâng în zigzag, două inele strâmbe care le leagă și gaura din mijloc.
static func _deseneaza(samanta: int) -> Texture2D:
	const N := 96
	var rng := RandomNumberGenerator.new()
	rng.seed = 7717 + samanta * 131
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var c := Vector2(N, N) * 0.5
	var raze := rng.randi_range(7, 10)
	var varfuri: Array = []  # pentru inele: [unghi, puncte pe rază]
	for r in raze:
		var unghi := TAU * r / raze + rng.randf_range(-0.25, 0.25)
		var lung := rng.randf_range(0.6, 1.0) * N * 0.48
		var p := c
		var puncte: Array[Vector2] = [p]
		var pasi := 6
		for k in pasi:
			var a := unghi + rng.randf_range(-0.35, 0.35)
			var q := p + Vector2(cos(a), sin(a)) * lung / pasi
			_linie(img, p, q, 1.0 - 0.5 * k / pasi)
			p = q
			puncte.append(p)
			# o ramură mică din când în când
			if k > 1 and rng.randf() < 0.3:
				var b := a + rng.randf_range(0.5, 0.9) * (1 if rng.randf() < 0.5 else -1)
				_linie(img, p, p + Vector2(cos(b), sin(b)) * lung * 0.18, 0.5)
		varfuri.append(puncte)
	# inelele: leagă punctele de pe raze vecine (la a doua și a patra treaptă)
	for treapta: int in [2, 4]:
		for r in raze:
			if rng.randf() < 0.2:
				continue
			var a: Vector2 = varfuri[r][mini(treapta, varfuri[r].size() - 1)]
			var b: Vector2 = varfuri[(r + 1) % raze][mini(treapta + rng.randi_range(-1, 0), varfuri[(r + 1) % raze].size() - 1)]
			_linie(img, a, b, 0.7 if treapta == 2 else 0.45)
	# gaura: un cerc mic opac, mai închis, cu marginea albă
	for y in N:
		for x in N:
			var d := Vector2(x, y).distance_to(c)
			if d < 2.6:
				img.set_pixel(x, y, Color(0.15, 0.18, 0.18, 0.95))
			elif d < 4.2:
				img.set_pixel(x, y, Color(1, 1, 1, 0.95))
	return ImageTexture.create_from_image(img)


static func _linie(img: Image, a: Vector2, b: Vector2, alfa: float) -> void:
	var pasi := int(ceil(a.distance_to(b))) + 1
	for i in pasi + 1:
		var p := a.lerp(b, float(i) / pasi)
		var x := int(p.x)
		var y := int(p.y)
		if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
			continue
		var vechi := img.get_pixel(x, y)
		img.set_pixel(x, y, Color(1, 1, 1, maxf(vechi.a, alfa)))
