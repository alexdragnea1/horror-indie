class_name Voma
extends Node3D
## Voma (owner 11.10): bomboana din tomberon te face să vomiți (ObiectInMana), iar Johnny de la amanet, care o
## mănâncă pe loc, vomită în magazin (johnny_amanet.gd).
##   var v := Voma.porneste(scena, [rid_de_exclus])
##   await v.jet(gura, viteza, 1.4)   # un val: jetul de particule + balta care crește unde cade
##   v.opreste()                      # particulele se sting; balta rămâne pe jos
## Unde cade se află din traiectorie (aruncare oblică, cu raze pe bucăți), deci jetul se oprește exact pe podea /
## tejghea, iar balta stă lipită de ea, întoarsă după normala suprafeței. Toate valurile umplu ACEEAȘI baltă (una
## singură, dintr-o bucată: discuri suprapuse în același plan s-ar bate pe ecran).

const SUNET_STOMAC := preload("res://sunete/voma_stomac.ogg")
const SUNET_GREATA := preload("res://sunete/voma_greata.ogg")
const SUNET_JET := preload("res://sunete/voma_jet.ogg")
const SUNET_TUSE := preload("res://sunete/voma_tuse.ogg")
const MATERIAL := preload("res://shaders/material_model.tres")
const GRAVITATIE := 9.8
## Culorile: lichidul (galben-verzui), bucățile (mai deschise, morcov) și bomboana roșie.
const LICHID := Color(0.46, 0.44, 0.15)
const MARGINE := Color(0.34, 0.3, 0.08)
const BUCATI := [Color(0.78, 0.66, 0.32), Color(0.85, 0.45, 0.14), Color(0.62, 0.08, 0.08)]
## Cât de mare se face balta (rază, m) după un val de o secundă; valurile următoare o lățesc mai puțin.
const RAZA_PE_SECUNDA := 0.32

var _exclus: Array[RID] = []
var _jet: CPUParticles3D
var _stropi: CPUParticles3D
var _balta: Node3D
var _raza := 0.0
## Cât de mare poate fi balta fără să iasă în aer peste marginea suprafeței (tejgheaua lui Johnny e îngustă).
var _raza_max := 1.0


static func porneste(parinte: Node, exclus: Array[RID] = []) -> Voma:
	var v := Voma.new()
	v._exclus = exclus
	parinte.add_child(v)
	return v


## Un val: jetul pleacă din `gura` cu `viteza` (m/s, global) cât `durata` secunde; balta crește unde cade.
func jet(gura: Vector3, viteza: Vector3, durata: float) -> void:
	var lovit := _unde_cade(gura, viteza)
	if lovit.is_empty():
		return
	var timp: float = lovit.timp
	if _jet == null:
		_jet = _particule(90, 0.035, [LICHID.lightened(0.05), LICHID, MARGINE, BUCATI[1].darkened(0.2)])
		_stropi = _particule(24, 0.025, [LICHID, MARGINE])
		_stropi.spread = 70.0
		_stropi.initial_velocity_min = 0.6
		_stropi.initial_velocity_max = 1.4
		_stropi.lifetime = 0.35
	_jet.global_position = gura
	_jet.direction = viteza.normalized()
	_jet.initial_velocity_min = viteza.length() * 0.85
	_jet.initial_velocity_max = viteza.length() * 1.1
	_jet.lifetime = timp  # se sting exact când ajung jos
	_jet.emitting = true
	_stropi.global_position = lovit.punct + lovit.normala * 0.03
	_stropi.direction = lovit.normala
	get_tree().create_timer(timp).timeout.connect(func() -> void: if is_instance_valid(_stropi): _stropi.emitting = true)
	# balta: apare când ajunge primul strop jos și se lățește cât curge
	if _balta == null:
		_balta = _fa_balta(lovit.punct, lovit.normala)
		_raza_max = _cat_incape(lovit.punct, lovit.normala)
	var raza_noua := minf(_raza + RAZA_PE_SECUNDA * durata * (1.0 if _raza == 0.0 else 0.5), _raza_max)
	var t := create_tween()
	t.tween_interval(timp)
	t.tween_method(_creste, _raza, raza_noua, durata).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_raza = raza_noua
	await get_tree().create_timer(durata).timeout
	if is_instance_valid(_jet):
		_jet.emitting = false
		_stropi.emitting = false


## Gata: particulele se sting, balta rămâne în scenă (urcă la părinte).
func opreste() -> void:
	await get_tree().create_timer(1.0).timeout
	if _balta:
		_balta.reparent(get_parent(), true)
	queue_free()


## Sunetele, ca să le folosească și scenele: din cap (pozitie = Vector3.INF) sau 3D (Johnny, mai grav).
static func sunet(stream: AudioStream, pozitie := Vector3.INF, volum := 0.0, inaltime := 1.0) -> void:
	if pozitie == Vector3.INF:
		Sunet.reda(stream, Sunet.VOLUM_EFECTE + volum, 0.03, &"Efecte", inaltime)
	else:
		Sunet.reda_la(stream, pozitie, Sunet.VOLUM_EFECTE + volum, 0.03, inaltime)


## Urmărește traiectoria (pași de 1/60 s, o rază pe fiecare bucată): {punct, normala, timp} sau {} dacă nu cade nicăieri.
func _unde_cade(start: Vector3, viteza: Vector3) -> Dictionary:
	var spatiu := get_world_3d().direct_space_state
	var p := start
	var v := viteza
	var dt := 1.0 / 60.0
	var t := 0.0
	while t < 2.0:
		var urm := p + v * dt
		v.y -= GRAVITATIE * dt
		var q := PhysicsRayQueryParameters3D.create(p, urm)
		q.exclude = _exclus
		var r := spatiu.intersect_ray(q)
		if not r.is_empty():
			var poz: Vector3 = r.position
			var bucata := (poz - p).length() / maxf((urm - p).length(), 0.0001)
			return {"punct": poz, "normala": r.normal, "timp": t + dt * bucata}
		p = urm
		t += dt
	return {}


## Cea mai mare rază (din 5 în 5 cm) la care sub toată marginea bălții (8 direcții, cu 25% loc pentru marginea
## neregulată) e tot suprafața pe care a căzut (nu mai jos de 2 cm).
func _cat_incape(punct: Vector3, normala: Vector3) -> float:
	var spatiu := get_world_3d().direct_space_state
	var lateral := normala.cross(Vector3.FORWARD if absf(normala.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var fata := lateral.cross(normala)
	var raza := 0.05
	while raza < 1.0:
		var urm := raza + 0.05
		for k in 8:
			var a := TAU * k / 8.0
			var p := punct + (lateral * cos(a) + fata * sin(a)) * urm * 1.25
			var q := PhysicsRayQueryParameters3D.create(p + normala * 0.05, p - normala * 0.02)
			q.exclude = _exclus
			if spatiu.intersect_ray(q).is_empty():
				return maxf(raza, 0.08)
		raza = urm
	return raza


func _particule(cate: int, marime: float, culori: Array) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * marime
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	p.mesh = quad
	p.amount = cate
	p.local_coords = false
	p.emitting = false
	p.spread = 7.0
	p.gravity = Vector3(0, -GRAVITATIE, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for i in culori.size():
		offsets.append(float(i) / (culori.size() - 1))
		colors.append(culori[i])
	gradient.offsets = offsets
	gradient.colors = colors
	p.color_initial_ramp = gradient  # fiecare strop are culoarea lui, nu se schimbă în zbor
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


## Balta: o pată neregulată dintr-o singură bucată (evantai de triunghiuri, marginea mai închisă), plus câteva bucăți
## (cubulețe turtite, 3 mm deasupra) pe ea. Începe de mărimea 0 și crește din `_creste`.
func _fa_balta(punct: Vector3, normala: Vector3) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	var sus := normala.normalized()
	var lateral := sus.cross(Vector3.FORWARD if absf(sus.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	n.global_transform = Transform3D(Basis(lateral, sus, lateral.cross(sus)).orthonormalized(), punct + sus * 0.006)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var laturi := 22
	var raze: Array[float] = []
	var faza := randf() * TAU
	for i in laturi:
		var a := TAU * i / laturi
		raze.append(1.0 + 0.22 * sin(a * 3.0 + faza) + 0.12 * sin(a * 5.0 + faza * 2.0) + randf_range(-0.08, 0.08))
	for i in laturi:
		var a0 := TAU * i / laturi
		var a1 := TAU * (i + 1) / laturi
		st.set_normal(Vector3.UP)
		st.set_color(LICHID)
		st.add_vertex(Vector3.ZERO)
		st.set_color(MARGINE)
		st.add_vertex(Vector3(cos(a0), 0, sin(a0)) * raze[i])
		st.set_color(MARGINE)
		st.add_vertex(Vector3(cos(a1), 0, sin(a1)) * raze[(i + 1) % laturi])
	var pata := MeshInstance3D.new()
	pata.name = "Pata"
	pata.mesh = st.commit()
	pata.material_override = MATERIAL
	pata.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(pata)
	for k in 9:
		var b := MeshInstance3D.new()
		b.name = "Bucata"
		var cub := BoxMesh.new()
		cub.size = Vector3(randf_range(0.012, 0.028), 0.004, randf_range(0.012, 0.028))
		b.mesh = cub
		var mat := StandardMaterial3D.new()
		mat.albedo_color = BUCATI[k % BUCATI.size()]
		b.material_override = mat
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a := randf() * TAU
		# poziția e în unități de rază (balta crește din `_creste`), bucățile își păstrează mărimea
		b.set_meta("loc", Vector3(cos(a), 0, sin(a)) * randf_range(0.0, 0.7))
		b.rotation.y = randf() * TAU
		n.add_child(b)
	_balta = n
	_creste(0.0)
	return n


func _creste(raza: float) -> void:
	if _balta == null:
		return
	_balta.visible = raza > 0.005
	for c in _balta.get_children():
		if c.name == "Pata":
			c.scale = Vector3(raza, 1.0, raza)
		else:
			c.position = (c.get_meta("loc") as Vector3) * raza + Vector3.UP * 0.003
