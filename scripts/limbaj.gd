class_name Limbaj
## Varianta „family friendly” (owner 22.10): dacă la jocul nou ai ales Yes (`Stare.familie`), cuvintele urâte se
## schimbă în ceva PG chiar când apar pe ecran (Dialog, telefonul, televizorul, sarcina, genericul, „Fuck magic”...).
## Replicile din scene și scripturi rămân cum le-a scris owner-ul; doar ce se arată e schimbat.
##   eticheta.text = Limbaj.curata("Drunkard: Nah nigga.")   -> „Drunkard: Nah man.” (cu varianta PG)
## Textul de pe modelele 3D (panoul din pădure, cartonul de la conac) îl schimbă ModelPS2 (modelele `*_pg.glb`).

## [ce cauți (regex, fără să conteze literele mari), cu ce înlocuiești]. Ordinea contează: întâi expresiile întregi
## („old bitch”, „the fuck”), abia apoi cuvintele singure. Literele mari se păstrează (Bitch -> Jerk, FUCK -> FRICK).
const INLOCUIRI := [
	# nume de personaje / contacte
	["old bitch", "old lady"],
	["school whore", "school bestie"],
	["coven retard", "coven weirdo"],
	["(?m)^old ass$", "old geezer"],  # jucătorul de la poker
	# expresii
	["bitch ass", "lame"],
	["ugly ass", "ugly"],
	["old ass", "old"],
	["yo ass", "yo butt"],
	["my dick", "my fists"],
	["kill yourself", "get lost"],
	["shut the fuck up", "shut up"],
	["the fuck", "the heck"],
	["give a fuck", "give a hoot"],
	["piece of shit", "piece of junk"],
	["idgaf", "idc"],
	["gaf", "care"],
	# cuvintele singure
	["bullshit", "nonsense"],
	["motherfuckers?", "jerk"],
	["fucking", "freaking"],
	["fucked", "fricked"],
	["fuck", "frick"],
	["shit", "crap"],
	["niggas", "men"],
	["nigga", "man"],
	["retarded", "stupid"],
	["retards?", "idiot"],
	["bitches", "jerks"],
	["bitch", "jerk"],
	["whores?", "jerk"],
	["assholes?", "jerk"],
	["dick", "butt"],
	["ass", "butt"],
]

static var _reguli: Array = []


## `text` cu cuvintele urâte schimbate, dacă jocul e pe varianta family friendly; altfel exact `text`.
static func curata(text: String) -> String:
	if text.is_empty() or not Stare.familie:
		return text
	if _reguli.is_empty():
		for pereche in INLOCUIRI:
			var tipar: String = pereche[0]
			var steag := ""
			if tipar.begins_with("(?m)"):
				steag = "m"
				tipar = tipar.substr(4)
			_reguli.append([RegEx.create_from_string("(?i%s)\\b%s\\b" % [steag, tipar]), pereche[1]])
	for regula in _reguli:
		text = _inlocuieste(text, regula[0], regula[1])
	return text


static func _inlocuieste(text: String, tipar: RegEx, cu: String) -> String:
	var rezultat := ""
	var de_la := 0
	for gasit in tipar.search_all(text):
		var vechi := gasit.get_string()
		rezultat += text.substr(de_la, gasit.get_start() - de_la) + _ca_literele(vechi, cu)
		de_la = gasit.get_end()
	return rezultat + text.substr(de_la)


## `nou` scris cu literele mari ca `vechi`: TOT MARE, Fiecare Cuvânt Mare (numele: „Coven Retard”), cu Prima mare
## sau mic.
static func _ca_literele(vechi: String, nou: String) -> String:
	var litere := vechi.replace(" ", "")
	if litere.length() > 1 and litere == litere.to_upper():
		return nou.to_upper()
	var cuvinte := vechi.split(" ")
	if cuvinte.size() > 1 and Array(cuvinte).all(func(c: String) -> bool: return c.left(1) == c.left(1).to_upper()):
		return " ".join(PackedStringArray(Array(nou.split(" ")).map(func(c: String) -> String: return c.left(1).to_upper() + c.substr(1))))
	if vechi.left(1) == vechi.left(1).to_upper():
		return nou.left(1).to_upper() + nou.substr(1)
	return nou
