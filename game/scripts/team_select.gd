extends Control
## Pick the two clubs from the league table (data/league.json): player 1 with W/S
## (or the first gamepad's d-pad), the opponent (AI or player 2) with the Up/Down
## arrows (or the second gamepad). Space / Enter / Start kicks off; Esc goes back.

const MATCH := "res://scenes/main.tscn"
const TITLE := "res://scenes/title.tscn"
const BACKGROUND := "res://assets/ui/title/000_0000.png"
const ROW := 30.0
const TOP := 118.0

var _clubs: Array = []
var _pick := [0, 0]  # row of player 1's club, of the opponent's
var _rows: Array[Label] = []
var _cursors: Array[Label] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_clubs = Team.league()
	var back := TextureRect.new()
	back.texture = load(BACKGROUND)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back.modulate = Color(0.25, 0.25, 0.3)
	add_child(back)
	var heading := _label("JUPILER PRO LEAGUE", 30, Color(1, 0.85, 0.2))
	heading.position = Vector2(0, 40)
	heading.size.x = 1280
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var opponent := "PLAYER 2" if Match.players == 2 else "CPU"
	var hint := _label("P1: W / S        %s: ↑ / ↓        SPACE: kick off        ESC: back" % opponent, 16, Color(0.85, 0.85, 0.85))
	hint.position = Vector2(0, 84)
	hint.size.x = 1280
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in _clubs.size():
		var d: Dictionary = _clubs[i]
		var y := TOP + i * ROW
		var swatch := ColorRect.new()
		swatch.color = Color(d.kit.shirt)
		swatch.position = Vector2(470, y + 6)
		swatch.size = Vector2(12, 18)
		add_child(swatch)
		var stripe := ColorRect.new()  # second shirt colour (stripes) and shorts
		stripe.color = Color(d.kit.shirt2)
		stripe.position = Vector2(482, y + 6)
		stripe.size = Vector2(6, 18)
		add_child(stripe)
		var place := _label("%d" % (i + 1), 20, Color(0.8, 0.8, 0.8))
		place.position = Vector2(436, y)
		var row := _label(d.name, 20, Color.WHITE)
		row.position = Vector2(500, y)
		_rows.append(row)
		var points := _label("%d pts" % d.points, 20, Color(0.8, 0.8, 0.8))
		points.position = Vector2(720, y)
	for i in 2:
		_cursors.append(_label("", 20, Human.MARKERS[i]))
	_pick = [_index_of(Match.home_club), _index_of(Match.away_club)]
	_refresh()


func _label(text: String, font_size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func _index_of(club: String) -> int:
	for i in _clubs.size():
		if _clubs[i].name == club:
			return i
	return 0


func _refresh() -> void:
	var labels := ["P1 ▶", "◀ P2" if Match.players == 2 else "◀ CPU"]
	for i in 2:
		_cursors[i].text = labels[i]
		_cursors[i].position = Vector2(370 if i == 0 else 810, TOP + _pick[i] * ROW)
	for r in _rows.size():
		var picked: bool = r == _pick[0] or r == _pick[1]
		_rows[r].add_theme_color_override("font_color", Human.MARKERS[0] if r == _pick[0]
			else Human.MARKERS[1] if r == _pick[1] else Color(0.8, 0.8, 0.8))
		_rows[r].modulate.a = 1.0 if picked else 0.75
	Match.home_club = _clubs[_pick[0]].name
	Match.away_club = _clubs[_pick[1]].name


## Move player `who`'s cursor by `step`, skipping the other player's club.
func _move(who: int, step: int) -> void:
	var n := _clubs.size()
	var r: int = (_pick[who] + step + n) % n
	if r == _pick[1 - who]:
		r = (r + step + n) % n
	_pick[who] = r
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_W: _move(0, -1)
			KEY_S: _move(0, 1)
			KEY_UP: _move(1, -1)
			KEY_DOWN: _move(1, 1)
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER: get_tree().change_scene_to_file(MATCH)
			KEY_ESCAPE: get_tree().change_scene_to_file(TITLE)
	elif event is InputEventJoypadButton and event.pressed:
		# same pads as in the match (Human.bind_inputs): alone, every pad is player 1's;
		# two players with one pad, it's player 2's; with two, the second is
		var pads := Input.get_connected_joypads()
		var who := 0
		if Match.players == 2 and (pads.size() == 1 or (pads.size() >= 2 and event.device == pads[1])):
			who = 1
		match event.button_index:
			JOY_BUTTON_DPAD_UP: _move(who, -1)
			JOY_BUTTON_DPAD_DOWN: _move(who, 1)
			JOY_BUTTON_A, JOY_BUTTON_START: get_tree().change_scene_to_file(MATCH)
			JOY_BUTTON_B, JOY_BUTTON_BACK: get_tree().change_scene_to_file(TITLE)
