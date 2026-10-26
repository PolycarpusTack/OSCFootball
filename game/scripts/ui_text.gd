class_name UiText
extends RefCounted
## The menus' text: a Label in OSCF's style, its colour on a black outline. Each screen places it
## (position, width, alignment, parent) as its layout needs. The font is the edition's (apply_font).

const PIXEL_FONT := "res://fonts/OSCFJersey.ttf"  # Jersey 10, scaled (fonts/README.md). OFL 1.1: fonts/Jersey10-OFL.txt
const PIXEL_HEADING := "res://fonts/PixelifySans.ttf"  # OFL 1.1: fonts/PixelifySans-OFL.txt. Blocky, for big text only
const RENDERED_FONT := "res://fonts/Exo2-Italic.ttf"  # OFL 1.1: fonts/Exo2-OFL.txt
const HEADING := 28  # font size from which label() is a heading ("Heading", a Label variation)


## Every text without a font of its own in the edition's font. Pixel: Jersey 10, and Pixelify Sans
## for headings (it isn't readable small). Rendered (and the 3D edition to come): a bold italic
## Exo 2. Called at the title and whenever the PLAYERS option flips (Match.rendered). Controls read
## the default theme's font (and cache it: the notification makes those already shown read it
## again); draw_string callers read ThemeDB.fallback_font.
static func apply_font(rendered: bool) -> void:
	var body := _font(RENDERED_FONT, 800) if rendered else load(PIXEL_FONT)
	var theme := ThemeDB.get_default_theme()
	theme.default_font = body
	theme.set_type_variation("Heading", "Label")
	theme.set_font("font", "Heading", body if rendered else _font(PIXEL_HEADING, 500))
	ThemeDB.fallback_font = body
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		tree.root.propagate_notification(Control.NOTIFICATION_THEME_CHANGED)


static func _font(path: String, weight: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = load(path)
	font.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return font


## A line of key hints, the same on every screen: [[key, what it does], ...] ->
## "KEY: what it does     KEY: ...".
static func hint(pairs: Array) -> String:
	return "     ".join(pairs.map(func(p): return "%s: %s" % p))


static func label(text: String, font_size: int, colour: Color, outline := 6) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", outline)
	if font_size >= HEADING:
		l.theme_type_variation = "Heading"
	return l
