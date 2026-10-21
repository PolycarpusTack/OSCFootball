extends Control
## Match options, between the team sheet and kick-off: Up / Down (W / S, d-pad) picks a row,
## Left / Right (A / D) changes it, Space / Enter / Start kicks off, Esc goes back. The
## choices live in Match's static vars, so they're kept for the next match.

const MATCH := "res://scenes/main.tscn"
const TEAM_MANAGER := "res://scenes/team_manager.tscn"
const BACKGROUND := "res://brand/title.png"
const HALF_LENGTHS := [2, 3, 5, 10, 20, 45]  # real minutes per half
const TOP := 180.0
const ROW := 40.0
const ROWS := 8  # the rows before the Chaos modifiers, shown in Chaos Football only

var _row := 0
var _labels: Array[Label] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var back := TextureRect.new()
	back.texture = load(BACKGROUND)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back.modulate = Color(0.15, 0.15, 0.18)
	add_child(back)
	var heading := _label("MATCH OPTIONS", 30, Color(1, 0.85, 0.2))
	heading.position.y = 40
	var fixture := _label("%s  v  %s" % [Match.home_club, Match.away_club], 22, Color.WHITE)
	fixture.position.y = 96
	var hint := _label("↑ / ↓: choose        ← / →: change        SPACE: kick off        ESC: back", 16, Color(0.85, 0.85, 0.85))
	hint.position.y = 140
	for i in ROWS + Match.MODIFIERS.size():
		var l := _label("", 26, Color.WHITE)
		l.position.y = TOP + i * ROW
		_labels.append(l)
	_refresh()


func _label(text: String, font_size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.size.x = 1280
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


## [name, current value as shown] per row.
func _rows() -> Array:
	return [
		["MODE", "CHAOS FOOTBALL" if Match.chaos else "CLASSIC FOOTBALL"],
		["PITCH", "INDOOR (5 A SIDE)" if Pitch.indoor else "OUTDOOR (11 A SIDE)"],
		["HALF LENGTH", "%d MIN" % Match.half_minutes],
		["OFFSIDE", "NONE INDOORS" if Pitch.indoor else ("ON" if Match.offside_on else "OFF")],
		["FOULS", "ON" if Match.fouls_on else "OFF"],
		["CARDS", "ON" if Match.cards_on else "OFF"],
		["MATCH", "KNOCKOUT (EXTRA TIME, PENALTIES)" if Match.knockout else "FRIENDLY"],
		["REFEREE", Match.STRICTNESS[Match.strictness][0]],
	] + (Match.MODIFIERS.map(func(m): return [m.to_upper(), "ON" if m in Match.modifiers else "OFF"]) if Match.chaos else [])


func _refresh() -> void:
	var rows := _rows()
	_row = mini(_row, rows.size() - 1)
	for i in _labels.size():
		_labels[i].visible = i < rows.size()
		if i >= rows.size():
			continue
		var picked := i == _row
		_labels[i].text = ("%s:   ◀  %s  ▶" if picked else "%s:   %s") % rows[i]
		_labels[i].add_theme_color_override("font_color", Color(1, 0.85, 0.2) if picked else Color(0.8, 0.8, 0.8))


## Change the picked row's value one step.
func _change(step: int) -> void:
	match _row:
		0: Match.chaos = not Match.chaos
		1: Pitch.indoor = not Pitch.indoor
		2:
			var i := HALF_LENGTHS.find(Match.half_minutes)
			Match.half_minutes = HALF_LENGTHS[posmod((i if i >= 0 else 1) + step, HALF_LENGTHS.size())]
		3: Match.offside_on = not Match.offside_on
		4: Match.fouls_on = not Match.fouls_on
		5: Match.cards_on = not Match.cards_on
		6: Match.knockout = not Match.knockout
		7: Match.strictness = clampi(Match.strictness + step, 0, Match.STRICTNESS.size() - 1)
		_:
			var m: String = Match.MODIFIERS[_row - ROWS]
			if m in Match.modifiers:
				Match.modifiers.erase(m)
			else:
				Match.modifiers.append(m)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	var button: bool = event is InputEventJoypadButton and event.pressed
	var n := _rows().size()
	if (key and event.physical_keycode in [KEY_UP, KEY_W]) or (button and event.button_index == JOY_BUTTON_DPAD_UP):
		_row = posmod(_row - 1, n)
		_refresh()
	elif (key and event.physical_keycode in [KEY_DOWN, KEY_S]) or (button and event.button_index == JOY_BUTTON_DPAD_DOWN):
		_row = posmod(_row + 1, n)
		_refresh()
	elif (key and event.physical_keycode in [KEY_LEFT, KEY_A]) or (button and event.button_index == JOY_BUTTON_DPAD_LEFT):
		_change(-1)
	elif (key and event.physical_keycode in [KEY_RIGHT, KEY_D]) or (button and event.button_index == JOY_BUTTON_DPAD_RIGHT):
		_change(1)
	elif (key and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]) or (button and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_START]):
		get_tree().change_scene_to_file(MATCH)
	elif (key and event.physical_keycode == KEY_ESCAPE) or (button and event.button_index in [JOY_BUTTON_B, JOY_BUTTON_BACK]):
		get_tree().change_scene_to_file(TEAM_MANAGER)
