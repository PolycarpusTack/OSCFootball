class_name MoveList
extends Control
## The pause menu's command list: every move, its input in the buttons of the device in use,
## its cost and what it does, a page per kind. The moves the controlled player's line can do
## come first; the rest are dimmed. The selected move loops its animation on the right.
## Left / Right: page, Up / Down: move (PauseMenu passes the input on; Esc / B goes back).

## Rows: "name", "input" (directions, or "@action" for a button), "text", and "anim" and
## "lines" (who can: G, D, M, F). A row with "super", "line" or "special" takes its name,
## cost and animation from Supers, LineMoves or ChaosActions.
const PAGES := [
	{"title": "BASICS", "chaos": false, "rows": [
		{"name": "Move", "input": ["@move"], "text": "Run. You control the player nearest the ball, ringed; the ring empties as he tires.", "anim": "run"},
		{"name": "Shoot", "input": ["@shoot"], "text": "With the ball: shoots on release, hold for power. Aims at goal when you face it.", "anim": "shoot"},
		{"name": "Pass / cross", "input": ["@pass"], "text": "To the teammate marked with the arrow. Out wide in the last third: a cross into the box.", "anim": "kick"},
		{"name": "Slide tackle", "input": ["@shoot"], "text": "Without the ball. From behind it's a foul.", "anim": "slide", "lines": "DMF"},
		{"name": "Switch player", "input": ["@switch"], "text": "Without the ball: the next teammate nearest the ball.", "lines": "DMF"},
		{"name": "Dodge", "input": ["@switch"], "text": "With the ball: hop over a slide tackle. Time it as it comes in.", "anim": "jump", "lines": "DMF"},
		{"name": "Header / volley", "input": ["@shoot"], "text": "As a ball in the air comes to you: at goal. The pass button heads or volleys it to a teammate.", "anim": "header", "lines": "DMF"},
		{"name": "Nutmeg", "input": ["→", "→", "@switch"], "text": "Double-tap any direction, then switch, with the ball: through the legs of the man in front.", "anim": "nutmeg", "lines": "DMF"},
		{"name": "Rainbow flick", "input": ["↓", "↑", "@switch"], "text": "Over everyone's head, to land 5 m on.", "anim": "rainbow", "lines": "DMF"},
		{"name": "Backheel", "input": ["→", "←", "@switch"], "text": "To the teammate behind you.", "anim": "bckheel", "lines": "DMF"},
	]},
	{"title": "SHOTS & LINE MOVES", "chaos": true, "rows": [
		{"super": "fireball", "input": ["↓", "↘", "→", "@shoot"], "text": "Strikers: a flat rocket that bowls over anyone in the way.", "lines": "F"},
		{"line": "D", "input": ["↓", "↘", "→", "@shoot"], "text": "Defenders: charge with the ball, flattening whoever's in the way, then hoof it upfield."},
		{"line": "M", "input": ["↓", "↘", "→", "@shoot"], "text": "Midfielders: a flat, fast pass straight to the man. Hard to cut out."},
		{"line": "G", "input": ["↓", "↘", "→", "@shoot"], "text": "Keepers: from the hands, far upfield, once the box is clear."},
		{"super": "banana", "input": ["←", "→", "@shoot"], "text": "Bends hard toward the far post.", "lines": "DMF"},
		{"super": "thunder", "input": ["hold", "@shoot"], "text": "Hold shoot 0.8 s with a full bar: bicycle kick, slow motion, a ball nobody can hold.", "lines": "DMF"},
		{"name": "Body check", "cost": Match.BODY_CHECK_COST, "input": ["→", "→", "@shoot"], "text": "Double-tap a direction, then shoot, without the ball: a shoulder charge at the dribbler.", "anim": "bodychk", "lines": "DMF"},
	]},
	{"title": "CHAOS SPECIALS", "chaos": true, "rows": [
		{"special": "ghost", "text": "Push the ball loose and burst after it."},
		{"special": "magnet", "text": "Pull a slow loose ball within 1.5 m to your boot."},
		{"special": "pinball", "text": "A fast ground pass that rebounds once off an opponent."},
		{"special": "stego", "text": "Sweep the carrier in front: the ball spills, he stumbles."},
		{"special": "bass", "text": "Stomp: stuns up to two opponents contesting the ball nearby."},
		{"special": "wall", "text": "You and a teammate plant and deflect one low ball."},
		{"special": "spring", "text": "Jump to meet a high ball and head it where you aim."},
		{"special": "boomerang", "text": "A lofted cross that curves back toward its wing."},
		{"special": "cyclone", "text": "An inverted spinning kick at a ball in the air."},
		{"special": "grapple", "text": "Grab the carrier right by you, spin once, come away with the ball."},
		{"special": "stepover", "text": "Rapid stepovers: the man in front freezes for a second."},
		{"special": "whirlwind", "text": "Spin away from pressure with the ball; nobody gets a foot in."},
		{"special": "rocket", "text": "Your keeper throws it long and fast to a teammate."},
		{"special": "palm", "text": "Your keeper parries everything in front of him for 0.7 s."},
		{"special": "fist", "text": "Your keeper leaps and punches a high ball in his box clear."},
	]},
	{"title": "REFEREE", "chaos": true, "rows": [
		{"name": "Sorry, ref!", "input": ["@special"], "text": "Just after a foul he's called on you: talks a booking down to a warning. For nothing, it angers him.", "lines": "GDMF"},
		{"special": "dive", "text": "Go down by an opponent: if the referee buys it, a free kick. If not, you're in trouble."},
		{"special": "captain", "text": "Your captain calms an angry referee down."},
		{"special": "bribe", "text": "Full bar, right by him: he leans your way for 30 s. The linesman may see it."},
	]},
]
const LINE_NAMES := {"G": "keepers", "D": "defenders", "M": "midfielders", "F": "strikers"}
const FACING_RIGHT := 2
const ROW_HEIGHT := 30

var page := 0
var pick := 0
var pad := false  # show the gamepad's buttons, not the keyboard's
var role := ""  # the controlled player's line; "" highlights everything
var outfield_kit: Material  # what the preview wears: an outfielder's kit ...
var keeper_kit: Material  # ... or a keeper's
var outfield_rendered: Material  # the same kits for the Rendered player art (Team.rendered_material)
var keeper_rendered: Material
var _tabs := RichTextLabel.new()
var _rows := VBoxContainer.new()
var _text := Label.new()
var _who := Label.new()
var _preview := Sprite2D.new()
var _time := 0.0
var _shown: Array = []  # this page's rows, in the order shown


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := ColorRect.new()
	back.color = Color(0.02, 0.06, 0.05, 0.92)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var title := _label("MOVES", 40, Color(1, 0.85, 0.2))
	title.position = Vector2(60, 24)
	add_child(title)
	_tabs.bbcode_enabled = true
	_tabs.fit_content = true
	_tabs.position = Vector2(60, 84)
	_tabs.size = Vector2(1160, 0)
	_tabs.add_theme_font_size_override("normal_font_size", 18)
	add_child(_tabs)
	_rows.position = Vector2(60, 130)
	_rows.add_theme_constant_override("separation", 2)
	add_child(_rows)
	var panel := ColorRect.new()
	panel.color = Color(1, 1, 1, 0.06)
	panel.position = Vector2(880, 130)
	panel.size = Vector2(340, 500)
	add_child(panel)
	_preview.centered = false
	_preview.scale = Vector2.ONE * 3.0
	_preview.position = Vector2(1050, 420)
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_preview)
	_text.position = Vector2(900, 450)
	_text.size = Vector2(300, 0)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 16)
	add_child(_text)
	_who.position = Vector2(900, 590)
	_who.size = Vector2(300, 0)
	_who.add_theme_font_size_override("font_size", 14)
	_who.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	add_child(_who)
	var help := _label("←/→ page   ↑/↓ move   Esc / B back   Directions: → is toward the goal you attack", 14, Color(0.75, 0.75, 0.75))
	help.position = Vector2(60, 680)
	add_child(help)
	visible = false


## Shown for `player_role`'s line ("" for none), in `kit_team`'s kit (null: none), with the
## gamepad's buttons when `use_pad`.
func open(player_role: String, kit_team: Team, use_pad: bool) -> void:
	role = player_role
	outfield_kit = kit_team.outfield_material if kit_team else null
	keeper_kit = kit_team.keeper_material if kit_team else null
	outfield_rendered = Team.rendered_material(outfield_kit) if kit_team else null
	keeper_rendered = Team.rendered_material(keeper_kit) if kit_team else null
	pad = use_pad
	page = 0
	pick = 0
	visible = true
	_refresh()


## Up / Down / Left / Right; anything else is the pause menu's.
func handle(event: InputEvent) -> void:
	var key: bool = event is InputEventKey
	if event is InputEventJoypadButton:
		pad = true
	elif key:
		pad = false
	var pages := pages_shown()
	if (key and event.physical_keycode in [KEY_LEFT, KEY_A]) or (not key and event.button_index == JOY_BUTTON_DPAD_LEFT):
		page = (page + pages.size() - 1) % pages.size()
		pick = 0
	elif (key and event.physical_keycode in [KEY_RIGHT, KEY_D]) or (not key and event.button_index == JOY_BUTTON_DPAD_RIGHT):
		page = (page + 1) % pages.size()
		pick = 0
	elif (key and event.physical_keycode in [KEY_UP, KEY_W]) or (not key and event.button_index == JOY_BUTTON_DPAD_UP):
		pick = (pick + _shown.size() - 1) % _shown.size()
	elif (key and event.physical_keycode in [KEY_DOWN, KEY_S]) or (not key and event.button_index == JOY_BUTTON_DPAD_DOWN):
		pick = (pick + 1) % _shown.size()
	_refresh()


## The pages for this mode: Classic has no energy moves.
static func pages_shown() -> Array:
	return PAGES.filter(func(pg): return Match.chaos or not pg.chaos)


## `row` with its name, cost, animation, input and lines filled in from the move tables.
static func resolve(row: Dictionary) -> Dictionary:
	var r := {"cost": 0, "anim": "", "lines": "GDMF"}
	if row.has("super"):
		var s: Dictionary = Supers.LIST[row.super]
		r.merge({"name": s.title.trim_suffix("!"), "cost": int(s.cost), "anim": s.anim}, true)
	elif row.has("line"):
		var l: Dictionary = LineMoves.LIST[row.line]
		r.merge({"name": l.title.trim_suffix("!"), "cost": int(l.cost), "anim": l.anim, "lines": row.line}, true)
	elif row.has("special"):
		var c: Dictionary = ChaosActions.MOVES[row.special]
		r.merge({"name": c.name, "cost": c.cost, "anim": c.anim, "input": ["@special"],
			"lines": ChaosActions.LINES.get(row.special, "DMF")}, true)
	r.merge(row, true)
	return r


## Whether the controlled player's line can do `r`.
func usable(r: Dictionary) -> bool:
	return role == "" or role in r.lines


## The input in player 1's buttons (see input_bbcode).
func input_text(input: Array) -> String:
	return input_bbcode(input, 0, pad)


## An input as bbcode: "@action" is player `i`'s button for it (the gamepad's when `use_pad`),
## "!Esc" a fixed key; both boxed. Directions stay as they are.
static func input_bbcode(input: Array, i: int, use_pad: bool) -> String:
	var parts := []
	for t: String in input:
		if t.begins_with("@"):
			parts.append("[bgcolor=#ffffff38] %s [/bgcolor]" % Human.button_name(i, t.substr(1), use_pad))
		elif t.begins_with("!"):
			parts.append("[bgcolor=#ffffff38] %s [/bgcolor]" % t.substr(1))
		else:
			parts.append(t)
	return " ".join(parts)


func _refresh() -> void:
	var pages := pages_shown()
	page = clampi(page, 0, pages.size() - 1)
	var tabs := []
	for i in pages.size():
		tabs.append("[color=%s]%s[/color]" % ["#ffe34d" if i == page else "#8a8a8a", pages[i].title])
	_tabs.text = "◀  " + "    ".join(tabs) + "  ▶"
	var rows: Array = pages[page].rows.map(resolve)
	_shown = rows.filter(usable) + rows.filter(func(r): return not usable(r))
	pick = clampi(pick, 0, _shown.size() - 1)
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for i in _shown.size():
		_rows.add_child(_row(_shown[i], i == pick))
	var r: Dictionary = _shown[pick]
	_text.text = r.text
	_who.text = who_can(r) + ("" if usable(r) else ": not your player's line")
	_time = 0.0
	_preview.visible = r.anim != "" and Anims.has(r.anim)
	if _preview.visible:
		var keeper: bool = r.lines == "G"
		if Anims.rendered(r.anim):
			_preview.material = keeper_rendered if keeper else outfield_rendered
		else:
			_preview.material = keeper_kit if keeper else outfield_kit


## "Everyone", "Outfield players" or e.g. "Midfielders and strikers".
static func who_can(r: Dictionary) -> String:
	if r.lines == "GDMF":
		return "Everyone"
	if r.lines == "DMF":
		return "Outfield players"
	var names := []
	for l: String in r.lines:
		names.append(LINE_NAMES[l])
	var text := " and ".join(names)
	return text[0].to_upper() + text.substr(1)


func _row(r: Dictionary, selected: bool) -> Control:
	var line := HBoxContainer.new()
	line.custom_minimum_size = Vector2(800, ROW_HEIGHT)
	var name_label := _label(("▶ " if selected else "   ") + r.name.to_upper(), 18, Color(1, 0.89, 0.3) if selected else Color.WHITE)
	name_label.custom_minimum_size = Vector2(300, 0)
	line.add_child(name_label)
	var input := RichTextLabel.new()
	input.bbcode_enabled = true
	input.fit_content = true
	input.scroll_active = false
	input.custom_minimum_size = Vector2(360, 0)
	input.add_theme_font_size_override("normal_font_size", 18)
	input.text = input_text(r.get("input", []))
	line.add_child(input)
	var cost := _label("%d" % r.cost if r.cost > 0 else "", 18, Color(0.55, 0.85, 1.0))
	cost.custom_minimum_size = Vector2(60, 0)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(cost)
	line.modulate.a = 1.0 if usable(r) else 0.4
	return line


func _process(delta: float) -> void:
	if not visible or not _preview.visible:
		return
	_time += delta
	var f: Dictionary = Anims.frame_at(_shown[pick].anim, FACING_RIGHT, _time, true)
	_preview.texture = f.tex
	_preview.offset = f.offset
	_preview.flip_h = f.flip


func _label(text: String, font_size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l
