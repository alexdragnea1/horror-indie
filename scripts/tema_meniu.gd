class_name TemaMeniu
extends RefCounted
## Aspectul comun al meniurilor (meniul principal, meniul cu numele): culori din paleta jocului
## și sunetele butoanelor.
##   centru.theme = TemaMeniu.creeaza()
##   TemaMeniu.buton(parinte, "OK", functie)

const SUNET_PESTE := preload("res://sunete/ui_peste.ogg")
const SUNET_CLIC := preload("res://sunete/ui_clic.ogg")

const TEXT := Color("83b3b0")
const ACCENT := Color("a18463")
const STINS := Color("5e5356")
const FUNDAL := Color("262d2f")


static func creeaza() -> Theme:
	var tema := Theme.new()
	tema.default_font_size = 12
	tema.set_color("font_color", "Label", TEXT)
	tema.set_color("font_color", "Button", TEXT)
	for stare_buton in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		tema.set_color(stare_buton, "Button", ACCENT)
	tema.set_color("font_disabled_color", "Button", STINS)
	tema.set_color("font_color", "LineEdit", TEXT)
	tema.set_color("font_placeholder_color", "LineEdit", STINS)
	tema.set_color("caret_color", "LineEdit", ACCENT)
	tema.set_stylebox("panel", "PanelContainer", cutie(FUNDAL, ACCENT, 10))
	tema.set_stylebox("normal", "LineEdit", cutie(Color("2a3c3d"), STINS, 4))
	tema.set_stylebox("focus", "LineEdit", cutie(Color(0, 0, 0, 0), ACCENT, 4))
	tema.set_stylebox("normal", "Button", cutie(Color("48313b"), STINS, 3))
	tema.set_stylebox("hover", "Button", cutie(Color("655269"), ACCENT, 3))
	tema.set_stylebox("pressed", "Button", cutie(Color("553e4d"), ACCENT, 3))
	tema.set_stylebox("hover_pressed", "Button", cutie(Color("655269"), ACCENT, 3))
	tema.set_stylebox("focus", "Button", cutie(Color(0, 0, 0, 0), ACCENT, 3))
	tema.set_stylebox("disabled", "Button", cutie(FUNDAL, Color("48313b"), 3))
	# glisorul de volum: șina închisă, partea plină în accent, mânerul un pătrățel
	var sina := cutie(Color("2a3c3d"), STINS, 0)
	sina.content_margin_top = 2
	sina.content_margin_bottom = 2
	tema.set_stylebox("slider", "HSlider", sina)
	tema.set_stylebox("grabber_area", "HSlider", cutie(Color("904a40"), ACCENT, 0))
	tema.set_stylebox("grabber_area_highlight", "HSlider", cutie(ACCENT, ACCENT, 0))
	tema.set_icon("grabber", "HSlider", _patrat(TEXT))
	tema.set_icon("grabber_highlight", "HSlider", _patrat(ACCENT))
	tema.set_icon("grabber_disabled", "HSlider", _patrat(STINS))
	return tema


static func cutie(fundal: Color, margine: Color, spatiu: int) -> StyleBoxFlat:
	var c := StyleBoxFlat.new()
	c.bg_color = fundal
	c.border_color = margine
	c.set_border_width_all(1)
	c.set_content_margin_all(spatiu)
	return c


## Buton cu sunet la trecerea mouse-ului și la apăsare.
static func buton(parinte: Control, text: String, la_apasare: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.x = 56
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void: Sunet.reda(SUNET_CLIC, Sunet.VOLUM_EFECTE, 0.05, &"Interfata"))
	b.pressed.connect(la_apasare)
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			Sunet.reda(SUNET_PESTE, Sunet.VOLUM_EFECTE, 0.05, &"Interfata"))
	parinte.add_child(b)
	return b


static func _patrat(culoare: Color) -> ImageTexture:
	var imagine := Image.create(6, 10, false, Image.FORMAT_RGBA8)
	imagine.fill(culoare)
	return ImageTexture.create_from_image(imagine)
