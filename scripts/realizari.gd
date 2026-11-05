class_name Realizari
extends RefCounted
## Achievement-urile de pe Steam (owner 05.11; puse în Steamworks, AppID `APP_ID`). API Name-ul fiecăruia = numele
## iconiței lui (ex. "13_pisica"). Merge prin GodotSteam (addons/godotsteam, GDExtension): dacă pluginul lipsește sau
## Steam nu e pornit, `deblocheaza` doar notează în consolă, jocul merge la fel.
##
## Două feluri de deblocare:
##  - din starea jocului (`verifica`, legată de `Stare.schimbat` și chemată la încărcarea unei salvări): marcaje,
##    obiecte din inventar, banii. Așa se deblochează și din salvările vechi, unde le-ai făcut deja;
##  - direct, din scriptul acțiunii, unde nu există marcaj: mângâiatul pisicii (pisica.gd), berea cu bețivul
##    (betiv.gd), primul jet de spray (graffiti.gd), camera de tortură (spanzurat.gd).

const APP_ID := 5496760

const BANI := "24_teanc_bani"            # Get $5000. (cash în buzunar deodată, nu jetoane)
const TORTURA := "17_spanzurat"          # Find the coven's secret. (camera de tortură din subsolul conacului)
const SICRIU := "15_schelet"             # Find the coffin. (sicriul din spatele casei lui Lexy)
const PISICA := "13_pisica"              # Pet the cat.
const BETIV := "03_betiv"                # Drink with him.
const HEAD_WITCH := "30_palaria_sefei"   # Defeat the Head Witch.
const SPRAY := "29_spray"                # Spray paint the wall.
const BOOMBOX := "26_boombox"            # Destroy the boombox.
const LEXY := "10_lexy"                  # Rob Lexy.
const BAZOOKA := "19_bazooka"            # Get the bazooka.
const KATANA := "22_katana"              # Get the katana.
const SABIE := "32_lumanare"             # Get the cursed sword. (iconița cu lumânarea e alegerea owner-ului)

## $5000 în cenți (Bani ține suma în cenți).
const PRAG_BANI := 500000

## marcaj din Stare → achievement
const DUPA_MARCAJ := {
	"scheletul_a_fugit": SICRIU,
	"head_witch_moarta": HEAD_WITCH,
	"boombox_stricat": BOOMBOX,
	"a_jefuit_lexy": LEXY,
	"a_luat_katana": KATANA,
	"a_scos_sabia": SABIE,
}
## obiect din inventar → achievement
const DUPA_OBIECT := {
	"bazooka": BAZOOKA,
	"katana": KATANA,
	"sabie_blestemata": SABIE,
}

static var _steam: Object
static var _pornit := false
static var _deblocate := {}


## Chemat o dată, din Stare._ready (Stare e primul autoload care poate s-o facă; nu e nevoie de autoload nou).
static func porneste() -> void:
	if _pornit:
		return
	_pornit = true
	if not Engine.has_singleton("Steam"):
		print("Achievements: GodotSteam lipsește, doar le notez în consolă.")
		return
	var steam := Engine.get_singleton("Steam")
	# true = GodotSteam cheamă singur run_callbacks în fiecare cadru
	var r: Dictionary = steam.steamInitEx(APP_ID, true)
	if int(r.get("status", -1)) == 0:
		_steam = steam
		print("Achievements: Steam pornit.")
	else:
		print("Achievements: Steam nu a pornit (", r.get("verbal", r), ").")


static func deblocheaza(api: String) -> void:
	if _deblocate.has(api):
		return
	_deblocate[api] = true
	print("Achievement: ", api)
	if _steam:
		_steam.setAchievement(api)
		_steam.storeStats()


## Ce se vede din starea jocului (marcaje, inventar, bani).
static func verifica() -> void:
	for marcaj in DUPA_MARCAJ:
		if Stare.e_marcat(marcaj):
			deblocheaza(DUPA_MARCAJ[marcaj])
	for id in DUPA_OBIECT:
		if Stare.are_obiect(id):
			deblocheaza(DUPA_OBIECT[id])
	if Bani.suma() >= PRAG_BANI:
		deblocheaza(BANI)
