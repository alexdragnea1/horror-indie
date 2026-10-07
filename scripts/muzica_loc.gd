extends AudioStreamPlayer
## Muzica unui loc (fața blocului, pădurea, curtea și interiorul conacului, casa lui Lexy): pornește încet și merge
## în buclă (bucla vine din importul .ogg-ului: loop = true). Canalul e „Muzica”, deci o reglează glisorul Music din
## setări. Se oprește singură când pleci: Tranzitie stinge sunetul și schimbă scena.
## Dacă scena e doar fundal (meniul principal folosește curtea blocului fără Jucator), tace.
##  - `zona`: se aude doar cât ești în zona asta (ex. înăuntrul casei lui Lexy): urcă la intrare, se stinge la ieșire
##    și, când revii, continuă de unde a rămas.
##  - `marcaje_liniste`: cu oricare dintre ele pus, aici nu se mai aude (ex. curtea conacului de la atac încolo).
##  - `opreste(durata)`: o oprește de tot în scena asta (ex. la jaful de la Lexy, lexy_masa.gd).
##  - `cedeaza`: cât se aude un alt sunet care are `acoperire` (0..1, ex. Boombox), atât coboară ea, ca să nu se bată.

## Cât de tare: 0 = Sunet.VOLUM_MUZICA, la fel ca efectele (fișierele au toate -20 LUFS).
@export var volum_db := 0.0
## În câte secunde urcă de la liniște la volum_db.
@export var intrare := 4.0
## În câte secunde se stinge când ieși din `zona`.
@export var iesire := 3.0
@export var zona: Area3D
@export var marcaje_liniste: PackedStringArray = []
@export var cedeaza: Node

## De unde pornește fade-ul (dB sub volum_db): ca înainte, urcă din -40 dB.
const JOS := -40.0

## 0 = tăcere, 1 = plin (pe scara în dB, de la JOS la volum_db).
var nivel := 0.0
var _oprita := false
var _tween: Tween


func _ready() -> void:
	bus = &"Muzica"
	set_process(false)
	if not get_parent().has_node("Jucator"):
		return
	for m in marcaje_liniste:
		if Stare.e_marcat(m):
			return
	set_process(true)
	_aplica()
	if zona:
		# un corp care e deja în zonă la încărcare (Continue înăuntru) dă și el body_entered, la primul pas de fizică
		zona.body_entered.connect(_zona.bind(true))
		zona.body_exited.connect(_zona.bind(false))
	else:
		_spre(1.0, intrare)


func _process(_delta: float) -> void:
	_aplica()


## O oprește de tot (în `durata` secunde) până pleci din scenă.
func opreste(durata := 0.3) -> void:
	_oprita = true
	_spre(0.0, durata)


func _zona(corp: Node3D, intra: bool) -> void:
	if not corp.is_in_group("jucator") or _oprita:
		return
	var forma := corp.get_node_or_null("Coliziune") as CollisionShape3D
	if not intra and forma and forma.disabled:
		# într-o scenă din cod (ex. conversația de pe canapea) jucătorul e „purtat”, fără coliziune, iar zona îl
		# pierde: muzica merge mai departe și se stinge doar dacă, la final, chiar nu mai ești în zonă
		while is_instance_valid(forma) and forma.disabled:
			await get_tree().physics_frame
		await get_tree().physics_frame
		await get_tree().physics_frame
		if not is_instance_valid(corp) or _oprita or zona.overlaps_body(corp):
			return
	_spre(1.0 if intra else 0.0, intrare if intra else iesire)


func _spre(tinta: float, durata: float) -> void:
	if _tween:
		_tween.kill()
	if tinta > 0.0:
		# pe pauză `playing` e false: play() ar lua piesa de la capăt
		if stream_paused:
			stream_paused = false
		elif not playing:
			play()
	_tween = create_tween().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "nivel", tinta, durata)
	if tinta <= 0.0:
		# pe pauză, nu oprită: când revii în zonă continuă de unde a rămas
		_tween.tween_callback(func() -> void: stream_paused = true)


func _aplica() -> void:
	if nivel <= 0.001:
		volume_db = -80.0
		return
	var db := lerpf(JOS, volum_db, nivel)
	if cedeaza:
		db += linear_to_db(maxf(1.0 - float(cedeaza.get("acoperire")), 0.0001))
	volume_db = maxf(db, -80.0)
