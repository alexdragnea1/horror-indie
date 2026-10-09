class_name Explozie
extends Node3D
## Explozia rachetei de bazooka („super powerful”, cerută de owner). Totul pornește odată, în straturi, ca la film:
##  1. fulgerul: o lumină albă-portocalie uriașă care luminează tot în jur o clipă (și ceața);
##  2. mingea de foc: sfere aditive (alb → galben → portocaliu → roșu) care se umflă și se sting;
##  3. flăcările care țâșnesc în toate părțile, scânteile, bucățile (moloz) aruncate sus care cad înapoi;
##  4. unda de șoc: un inel pe jos care fuge până la `raza` × 1,8, praful ridicat în cerc;
##  5. fumul negru care urcă în coloană și rămâne câteva secunde, focul mic care mai arde pe jos, urma arsă;
##  6. pe tine: camera zgâlțâită, ecranul alb, țiuitul în urechi (cu cât ești mai aproape, cu atât mai tare);
##  7. în jur (`raza`): cine are `lovit_de_foc` / `impuscat` îl primește (o dată), corpurile (RigidBody3D) sunt aruncate.
##   Explozie.creeaza(nod, punct, normala, 1.0)

const SUNET_BUM := preload("res://sunete/bazooka_explozie.ogg")
const SUNET_TIUIT := preload("res://sunete/tiuit.ogg")
const MIEZ := Color(1.0, 0.95, 0.8)
const GALBEN := Color(1.0, 0.8, 0.4)
const PORTOCALIU := Color(1.0, 0.5, 0.2)
const ROSU := Color(0.75, 0.22, 0.12)
const FUM := Color(0.2, 0.19, 0.2)

var putere := 1.0
var normala := Vector3.UP
var deja: Array = []
## Cât de departe ajunge suflul (metri).
var raza := 7.0

var _lumina: OmniLight3D


static func creeaza(nod: Node, punct: Vector3, normala_: Vector3, putere_ := 1.0, deja_: Array = []) -> Explozie:
	var e := Explozie.new()
	e.putere = putere_
	e.normala = normala_.normalized() if normala_.length() > 0.01 else Vector3.UP
	e.deja = deja_
	e.raza = 7.0 * putere_
	nod.get_tree().current_scene.add_child(e)
	e.global_position = punct + e.normala * 0.15
	return e


func _ready() -> void:
	var jucator := get_tree().get_first_node_in_group("jucator") as Node3D
	var distanta := jucator.global_position.distance_to(global_position) if jucator else 100.0
	# sunetul: din locul exploziei (3D, se aude departe), iar aproape și „în piept” (ne-poziționat)
	var s := AudioStreamPlayer3D.new()
	s.stream = SUNET_BUM
	s.bus = &"Efecte"
	s.volume_db = Sunet.VOLUM_EFECTE + 6.0
	s.unit_size = 14.0
	s.max_distance = 300.0
	add_child(s)
	s.play()
	if distanta < 30.0:
		Sunet.reda(SUNET_BUM, Sunet.VOLUM_EFECTE - 2.0 - distanta * 0.6, 0.0)
	if distanta < 12.0:
		Sunet.reda(SUNET_TIUIT, Sunet.VOLUM_EFECTE - 6.0 - distanta, 0.0)
	_fulger()
	_minge_de_foc()
	_flacari()
	_scantei()
	_moloz()
	_unda()
	_praf_cerc()
	_fum.call_deferred()
	_urma()
	_suflu()
	if jucator:
		_pe_jucator(jucator, distanta)
	get_tree().create_timer(12.0).timeout.connect(queue_free)


# ---------------------------------------------------------------- straturile

func _fulger() -> void:
	_lumina = OmniLight3D.new()
	_lumina.light_color = Color(1.0, 0.78, 0.5)
	_lumina.light_energy = 16.0 * putere
	_lumina.omni_range = 26.0 * putere
	_lumina.omni_attenuation = 1.4
	_lumina.light_volumetric_fog_energy = 4.0
	_lumina.shadow_enabled = true
	add_child(_lumina)
	_lumina.position = normala * 1.2
	var t := create_tween()
	t.tween_property(_lumina, "light_energy", 5.0 * putere, 0.12)
	t.tween_property(_lumina, "light_energy", 0.0, 1.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_lumina, "light_color", Color(1.0, 0.45, 0.2), 1.0)


func _minge_de_foc() -> void:
	# miezul: o strălucire alb-galbenă care se umflă într-o clipă și se stinge (lumina „orbitoare” din primul cadru).
	# Un cerc moale întors spre cameră, nu o sferă: sfera plină de 10 laturi ieșea ca un disc alb cu colțuri (09.10)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.6, 2.6)
	mi.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(MIEZ, 0.95)
	mat.albedo_texture = _stralucire()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.proximity_fade_enabled = true  # unde taie peretele lovit se stinge lin (fără muchie dreaptă)
	mat.proximity_fade_distance = 1.2
	mat.disable_fog = true
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = normala * 0.6 * putere
	mi.scale = Vector3.ONE * 0.2
	var t := create_tween()
	t.tween_property(mi, "scale", Vector3.ONE * 1.7 * putere, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	t.tween_callback(mi.queue_free)
	# mingea de foc: nori mari de foc (cercuri moi, aditive) care se umflă, se ridică și se fac fum
	var p := _particule(34, 1.0, 2.3 * putere, true)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.35, 0.6, 1.0])
	g.colors = PackedColorArray([Color(MIEZ, 1.0), Color(GALBEN, 0.95), Color(PORTOCALIU, 0.8), Color(ROSU, 0.45), Color(FUM, 0.0)])
	p.color_ramp = g
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.9 * putere
	p.direction = normala
	p.spread = 180.0
	p.initial_velocity_min = 2.0 * putere
	p.initial_velocity_max = 6.0 * putere
	p.damping_min = 5.0
	p.damping_max = 8.0
	p.gravity = Vector3(0, 3.0, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	p.scale_amount_curve = _curba(0.5, 1.6)
	_porneste(p)
	# o coajă de aer fierbinte (o sferă aproape transparentă) care fuge în afară: suflul se vede și pe un zid
	var coaja := MeshInstance3D.new()
	var sf := SphereMesh.new()
	sf.radius = 1.0
	sf.height = 2.0
	sf.radial_segments = 28  # ajunge până la ~12 m: cu puține laturi i se vedeau colțurile pe margine
	sf.rings = 14
	coaja.mesh = sf
	var mc := StandardMaterial3D.new()
	mc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mc.albedo_color = Color(1.0, 0.9, 0.75, 0.22)
	mc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mc.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mc.disable_fog = true
	mc.cull_mode = BaseMaterial3D.CULL_FRONT  # doar interiorul: un inel luminos pe margine, nu un disc plin
	coaja.material_override = mc
	coaja.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(coaja)
	coaja.scale = Vector3.ONE * 0.5
	var tc := create_tween().set_parallel()
	tc.tween_property(coaja, "scale", Vector3.ONE * raza * 1.3, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tc.tween_property(mc, "albedo_color:a", 0.0, 0.35)
	tc.chain().tween_callback(coaja.queue_free)


func _flacari() -> void:
	var p := _particule(110, 1.2, 0.9 * putere, true)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 0.4, 0.7, 1.0])
	g.colors = PackedColorArray([Color(MIEZ, 1.0), Color(GALBEN, 0.95), Color(PORTOCALIU, 0.8), Color(ROSU, 0.5), Color(FUM, 0.0)])
	p.color_ramp = g
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6 * putere
	p.direction = normala
	p.spread = 95.0
	p.initial_velocity_min = 4.0 * putere
	p.initial_velocity_max = 13.0 * putere
	p.damping_min = 7.0
	p.damping_max = 11.0
	p.gravity = Vector3(0, 2.5, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	p.scale_amount_curve = _curba(0.6, 1.8)
	_porneste(p)


func _scantei() -> void:
	var p := _particule(70, 1.1, 0.07, true)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	g.colors = PackedColorArray([Color(MIEZ, 1.0), Color(GALBEN, 0.9), Color(PORTOCALIU, 0.0)])
	p.color_ramp = g
	p.direction = normala
	p.spread = 80.0
	p.initial_velocity_min = 8.0 * putere
	p.initial_velocity_max = 22.0 * putere
	p.gravity = Vector3(0, -12.0, 0)
	p.damping_min = 1.0
	p.damping_max = 2.0
	_porneste(p)


## Bucățile (moloz, asfalt, lemn): cutii mici, luminate, aruncate sus, care se rotesc și cad.
func _moloz() -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	var cutie := BoxMesh.new()
	cutie.size = Vector3(0.12, 0.08, 0.1)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	cutie.material = mat
	p.mesh = cutie
	p.amount = 40
	p.lifetime = 2.8
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.direction = normala
	p.spread = 70.0
	p.initial_velocity_min = 6.0 * putere
	p.initial_velocity_max = 16.0 * putere
	p.gravity = Vector3(0, -14.0, 0)
	p.angular_velocity_min = -720.0
	p.angular_velocity_max = 720.0
	p.particle_flag_rotate_y = true
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.8
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color("48313b"), Color("5e5356"), Color("262d2f")])
	p.color_initial_ramp = g
	_porneste(p, 4.0)


## Unda de șoc: un inel alb-portocaliu, culcat pe sol, care fuge în afară și se stinge (doar pe sol: pe un zid ar fi
## un arc mare în aer; acolo suflul e coaja din `_minge_de_foc`).
func _unda() -> void:
	if normala.y < 0.6:
		return
	var mi := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.85
	tor.outer_radius = 1.0
	tor.rings = 24
	tor.ring_segments = 4
	mi.mesh = tor
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.65, 0.45)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.disable_fog = true
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_aliniaza(mi, normala)
	mi.position = normala * 0.1
	mi.scale = Vector3(0.3, 0.3, 0.3)
	var mare := raza * 1.8
	var t := create_tween().set_parallel()
	t.tween_property(mi, "scale", Vector3(mare, 0.6, mare), 0.55).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(mi.queue_free)


func _praf_cerc() -> void:
	var p := _particule(48, 2.2, 1.1 * putere, false)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(0.55, 0.5, 0.47, 0.6), Color(0.55, 0.5, 0.47, 0.0)])
	p.color_ramp = g
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = normala
	p.emission_ring_radius = 0.8
	p.emission_ring_inner_radius = 0.6
	p.emission_ring_height = 0.1
	p.direction = normala
	p.spread = 5.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.8
	p.radial_accel_min = 30.0 * putere
	p.radial_accel_max = 45.0 * putere
	p.damping_min = 12.0
	p.damping_max = 16.0
	p.scale_amount_curve = _curba(0.6, 2.4)
	_porneste(p, 3.0)


## Coloana de fum negru care urcă (pornește puțin după foc) și focul mic care mai arde pe jos.
func _fum() -> void:
	await get_tree().create_timer(0.12).timeout
	var p := _particule(46, 6.0, 1.6 * putere, false)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	g.colors = PackedColorArray([Color(0.35, 0.28, 0.25, 0.0), Color(FUM, 0.75), Color(0.35, 0.34, 0.35, 0.0)])
	p.color_ramp = g
	p.explosiveness = 1.0  # one_shot sub 1,0 = pătrate negre la sursă (particulele nepornite); eșalonarea vine din viață
	p.lifetime_randomness = 0.35
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.4 * putere
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.0
	p.damping_min = 0.6
	p.damping_max = 1.0
	p.gravity = Vector3(0, 0.7, 0)
	p.scale_amount_curve = _curba(0.7, 2.6)
	_porneste(p, 8.0)
	var foc := _particule(24, 0.8, 0.45, true)
	var gf := Gradient.new()
	gf.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gf.colors = PackedColorArray([Color(GALBEN, 0.9), Color(PORTOCALIU, 0.6), Color(FUM, 0.0)])
	foc.color_ramp = gf
	foc.one_shot = false
	foc.explosiveness = 0.0
	foc.preprocess = foc.lifetime  # continuu: fără preprocess, particulele nepornite fac un pătrat negru pe jos
	foc.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	foc.emission_sphere_radius = 0.9 * putere
	foc.direction = Vector3.UP
	foc.spread = 15.0
	foc.initial_velocity_min = 0.5
	foc.initial_velocity_max = 1.5
	foc.gravity = Vector3(0, 1.5, 0)
	foc.scale_amount_curve = _curba(1.0, 0.2)
	_porneste(foc, 7.0)
	await get_tree().create_timer(4.5).timeout
	if is_instance_valid(foc):
		foc.emitting = false


## Urma arsă de pe suprafața lovită: o pată neagră, aproape lipită, mai deasă la mijloc și ștearsă spre margine (un
## disc plin de 14 laturi ieșea ca un cerc negru tăiat cu foarfeca), care se stinge încet.
func _urma() -> void:
	var mi := MeshInstance3D.new()
	var c := PlaneMesh.new()
	c.size = Vector2.ONE * 4.2 * putere
	mi.mesh = c
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.07, 0.07, 0.85)
	mat.albedo_texture = _stralucire()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(mi)
	mi.global_position = global_position - normala * 0.13
	_aliniaza(mi, normala)
	var t := mi.create_tween()
	t.tween_interval(20.0)
	t.tween_property(mat, "albedo_color:a", 0.0, 6.0)
	t.tween_callback(mi.queue_free)


## Suflul: ce e în `raza` primește lovitura (o dată), corpurile sunt aruncate departe.
func _suflu() -> void:
	var forma := SphereShape3D.new()
	forma.radius = raza
	var cerere := PhysicsShapeQueryParameters3D.new()
	cerere.shape = forma
	cerere.transform = Transform3D(Basis.IDENTITY, global_position)
	cerere.collision_mask = 1 | Ragdoll.STRAT
	for r in get_world_3d().direct_space_state.intersect_shape(cerere, 64):
		var tinta: Object = r.collider
		if tinta == null or tinta in deja:
			continue
		var unde: Vector3 = (tinta as Node3D).global_position if tinta is Node3D else global_position
		var dir := unde - global_position
		var d := dir.length()
		dir = (dir + Vector3.UP * 0.6).normalized()
		var k := clampf(1.0 - d / raza, 0.0, 1.0)
		if tinta is CharacterBody3D and (tinta as Node).is_in_group("jucator"):
			continue
		if tinta.has_method("lovit_de"):
			deja.append(tinta)
			tinta.lovit_de("bazooka", dir, unde)  # doar racheta face Explozie
		elif tinta.has_method("lovit_de_foc"):
			deja.append(tinta)
			tinta.lovit_de_foc(dir, unde)
		elif tinta.has_method("impuscat"):
			deja.append(tinta)
			tinta.impuscat(dir, unde)
		elif tinta is RigidBody3D:
			(tinta as RigidBody3D).apply_central_impulse(dir * 60.0 * k * putere)


func _pe_jucator(jucator: Node3D, distanta: float) -> void:
	var camera := jucator.get_node("Cap/Camera3D") as Camera3D
	var k := clampf(1.0 - distanta / 45.0, 0.0, 1.0)
	Zguduire.porneste(camera, 0.22 * k * k * putere, 0.6 + 1.4 * k)
	if distanta < 25.0:
		# ecranul alb, o clipă (cu cât ești mai aproape, cu atât mai alb și mai lung)
		var strat := CanvasLayer.new()
		strat.layer = 8
		var alb := ColorRect.new()
		alb.color = Color(1.0, 0.92, 0.8, 0.9 * (1.0 - distanta / 25.0))
		alb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		alb.set_anchors_preset(Control.PRESET_FULL_RECT)
		strat.add_child(alb)
		get_tree().current_scene.add_child(strat)
		var t := strat.create_tween()
		t.tween_property(alb, "color:a", 0.0, 0.25 + 0.6 * (1.0 - distanta / 25.0)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_callback(strat.queue_free)


# ---------------------------------------------------------------- ajutoare

static var _textura_stralucire: GradientTexture2D


## Strălucirea miezului: un cerc mare (64 px, filtrat) care se stinge lin spre margine, fără muchie.
static func _stralucire() -> Texture2D:
	if _textura_stralucire == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.3), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 64
		t.height = 64
		_textura_stralucire = t
	return _textura_stralucire


func _particule(cate: int, viata: float, marime: float, aditiv: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * marime
	quad.material = Arma.material_particule(aditiv, 2.2)  # lângă cameră se sting (explozie în fața ta)
	p.mesh = quad
	p.amount = cate
	p.lifetime = viata
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _porneste(p: CPUParticles3D, cat_traieste := 3.0) -> void:
	add_child(p)
	p.emitting = true
	get_tree().create_timer(cat_traieste + p.lifetime).timeout.connect(p.queue_free)


func _curba(de_la: float, pana_la: float) -> Curve:
	var c := Curve.new()
	c.max_value = maxf(de_la, pana_la)
	c.add_point(Vector2(0.0, de_la))
	c.add_point(Vector2(1.0, pana_la))
	return c


## Întoarce un nod culcat (inelul, discul: axa lor e Y) cu axa pe `n`.
func _aliniaza(nod: Node3D, n: Vector3) -> void:
	var y := n.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	var s := nod.scale
	nod.basis = Basis(x, y, z)
	nod.scale = s
