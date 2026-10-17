extends Interactabil
## O maimuță de la Taxe (primarie.tscn, MaimutaTaxe1..6, în biroul din aripa stângă; owner 11.10: „maimuțe cu ochelari
## care au spreadsheet-uri deschise la calculator”). Stă pe scaunul de birou (OmLaMasa: respiră, mâinile cu IK) și:
##  - tastează: mâinile sar pe rând pe taste (rafale de 6–18 taste), cu sunetul `tastatura` (3D, în buclă, doar cât
##    tastează); în fiecare rafală celula selectată din spreadsheet se umple și cursorul trece la următoarea;
##  - între rafale se uită la ecran, uneori dă click cu mouse-ul (mâna dreaptă), uneori se uită la tine dacă ești
##    aproape (`raza_privire`);
##  - pe monitor: spreadsheet-ul (ImageTexture făcută din cod, cu culorile paletei: bara verde de sus, capul de tabel,
##    liniile grilei, „textul” din celule, celula selectată); când se umple foaia, o ia de la capăt.
## Fără E (owner, 17.10: „la camera de taxe nu vreau nicio interacțiune”): `activ` e pus pe false, doar corpul
## (coliziunea) a rămas de la Interactabil.
## Monitorul din model e în `primarie.py` (MONITOR; fața lui dinspre ea e la 0,6 m, rama neagră a ecranului la 0,589):
## ecranul de aici stă la 4 mm în fața ramei, spre ea (z mai mic = mai aproape de ea).

const SUNET_TASTATURA := preload("res://sunete/tastatura.ogg")
## Culorile paletei (textures/paleta culori.hex).
const ALB := Color("83b3b0")
const GRILA := Color("6f6d7f")
const CAP_TABEL := Color("438b88")
const BARA := Color("295555")
const TEXT := Color("262d2f")
const ROSU := Color("7b383a")
const VERDE := Color("445d46")
## Mărimea texturii și a celulelor (pixeli): 6 coloane × 6 rânduri de celule sub bara de sus și capul de tabel.
const L := 40
const H := 30
const CELULA := Vector2i(6, 4)
const SUS := 5  # bara verde (2 px) + capul de tabel (3 px)
const STANGA := 4  # coloana cu numerele rândurilor
## Ecranul, în coordonatele omului (privește spre +Z): centrul și mărimea (m).
const ECRAN := Vector3(0.0, 0.95, 0.585)
const MARIME_ECRAN := Vector2(0.3, 0.23)

@export var om: OmLaMasa
## Cât de aproape trebuie să fii ca să se uite la tine între rafale.
@export var raza_privire := 3.0
@export var volum := -14.0  # ca buclele de fundal (Sunet.VOLUM_AMBIANTA)

var _img: Image
var _tex: ImageTexture
var _cursor := Vector2i.ZERO
var _sunet: AudioStreamPlayer3D
var _baza := {}
var _jucator: Node3D


func _ready() -> void:
	activ = false
	_ecran()
	_sunet = AudioStreamPlayer3D.new()
	_sunet.stream = SUNET_TASTATURA
	_sunet.bus = &"Efecte"
	_sunet.volume_db = volum
	_sunet.unit_size = 1.5
	_sunet.max_distance = 14.0
	_sunet.pitch_scale = randf_range(0.92, 1.08)
	om.add_child(_sunet)
	_sunet.position = Vector3(0, 0.78, 0.5)
	await get_tree().process_frame
	_jucator = get_tree().get_first_node_in_group("jucator") as Node3D
	om.priveste_punct = om.to_global(ECRAN)
	_baza = {"D": om._tinta_globala("D"), "S": om._tinta_globala("S")}
	_lucreaza()


# ------------------------------------------------------------------ munca

func _lucreaza() -> void:
	while is_inside_tree():
		await _rafala()
		# pauza dintre rafale: se uită la ecran, la tine sau dă click
		var r := randf()
		if r < 0.3:
			await _click()
		elif r < 0.55 and _aproape():
			om.privire = _jucator.get_node("Cap")
			await get_tree().create_timer(randf_range(1.2, 2.5)).timeout
			om.privire = null
		else:
			await get_tree().create_timer(randf_range(0.6, 2.2)).timeout


func _rafala() -> void:
	_sunet.play(randf_range(0.0, 2.5))
	var n := randi_range(6, 18)
	for i in n:
		if not is_inside_tree():
			break
		var l := "D" if i % 2 == 0 else "S"
		# o tastă: deasupra ei, apoi jos (dreapta = -X la om, în față = +Z)
		var tasta: Vector3 = _baza[l] + om.global_basis.x * randf_range(-0.05, 0.05) + om.global_basis.z * randf_range(-0.02, 0.03)
		om.du_mana(l, tasta + Vector3.UP * 0.035, 0.05)
		await get_tree().create_timer(0.06).timeout
		om.du_mana(l, tasta, 0.04)
		await get_tree().create_timer(randf_range(0.04, 0.1)).timeout
		if i % 3 == 2:
			_scrie()
	_sunet.stop()
	_urmatoarea_celula()
	om.du_mana("D", _baza["D"], 0.15)
	await om.du_mana("S", _baza["S"], 0.15)


## Mâna dreaptă pe mouse (în dreapta tastaturii), un click (sau două), apoi înapoi pe taste.
func _click() -> void:
	var mouse := om.to_global(Vector3(-0.36, 0.8, 0.48))
	await om.du_mana("D", mouse, 0.3)
	for k in randi_range(1, 2):
		await om.du_mana("D", mouse + Vector3.DOWN * 0.012, 0.05)
		await om.du_mana("D", mouse, 0.05)
		_cursor = Vector2i(randi() % _coloane(), randi() % _randuri())
		_deseneaza_cursor()
		await get_tree().create_timer(0.25).timeout
	await get_tree().create_timer(randf_range(0.3, 0.9)).timeout
	await om.du_mana("D", _baza["D"], 0.3)


func _aproape() -> bool:
	return _jucator != null and om.global_position.distance_to(_jucator.global_position) < raza_privire


# ------------------------------------------------------------------ spreadsheet-ul

func _ecran() -> void:
	_img = Image.create(L, H, false, Image.FORMAT_RGB8)
	_foaie_noua()
	_tex = ImageTexture.create_from_image(_img)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = _tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var q := QuadMesh.new()
	q.size = MARIME_ECRAN
	var e := MeshInstance3D.new()
	e.name = "Ecran"
	e.mesh = q
	e.material_override = m
	e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	om.add_child(e)
	e.position = ECRAN
	e.rotation.y = PI  # fața spre maimuță (-Z)


func _coloane() -> int:
	return (L - STANGA) / CELULA.x


func _randuri() -> int:
	return (H - SUS) / CELULA.y


func _foaie_noua() -> void:
	_img.fill(ALB)
	_img.fill_rect(Rect2i(0, 0, L, 2), BARA)
	_img.fill_rect(Rect2i(0, 2, L, 3), CAP_TABEL)
	_img.fill_rect(Rect2i(0, SUS, STANGA - 1, H - SUS), CAP_TABEL)
	# grila
	for c in _coloane() + 1:
		var x := STANGA - 1 + c * CELULA.x
		if x < L:
			_img.fill_rect(Rect2i(x, 2, 1, H - 2), GRILA)
	for r in _randuri() + 1:
		var y := SUS - 1 + r * CELULA.y
		if y < H:
			_img.fill_rect(Rect2i(0, y, L, 1), GRILA)
	# rândul de titluri, deja scris
	for c in _coloane():
		_img.fill_rect(Rect2i(STANGA + c * CELULA.x + 1, SUS + 1, randi_range(2, 4), 1), TEXT)
	_cursor = Vector2i(0, 1)
	_deseneaza_cursor()


## „Scrie” în celula selectată: o bucată de text (un rând de pixeli), uneori roșu (minus) sau verde.
func _scrie() -> void:
	var o := _origine(_cursor)
	var cul := TEXT
	var r := randf()
	if r < 0.12:
		cul = ROSU
	elif r < 0.2:
		cul = VERDE
	var lung := randi_range(2, CELULA.x - 2)
	_img.fill_rect(Rect2i(o.x + 1, o.y + 1, lung, 1), cul)
	_tex.update(_img)


func _urmatoarea_celula() -> void:
	_sterge_cursor()
	_cursor.x += 1
	if _cursor.x >= _coloane():
		_cursor = Vector2i(0, _cursor.y + 1)
	if _cursor.y >= _randuri():
		_foaie_noua()
	_deseneaza_cursor()


func _origine(c: Vector2i) -> Vector2i:
	return Vector2i(STANGA - 1 + c.x * CELULA.x, SUS - 1 + c.y * CELULA.y)


## Celula selectată: chenarul verde închis (ca în Excel), peste liniile grilei.
func _deseneaza_cursor() -> void:
	_chenar(_cursor, BARA)


func _sterge_cursor() -> void:
	_chenar(_cursor, GRILA)


func _chenar(c: Vector2i, cul: Color) -> void:
	var o := _origine(c)
	var w := mini(CELULA.x + 1, L - o.x)
	var h := mini(CELULA.y + 1, H - o.y)
	_img.fill_rect(Rect2i(o.x, o.y, w, 1), cul)
	_img.fill_rect(Rect2i(o.x, o.y + h - 1, w, 1), cul)
	_img.fill_rect(Rect2i(o.x, o.y, 1, h), cul)
	_img.fill_rect(Rect2i(o.x + w - 1, o.y, 1, h), cul)
	if _tex:
		_tex.update(_img)
