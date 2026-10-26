class_name SubsMenu
extends CanvasLayer
## SUBSTITUTIONS from the pause menu: the eleven on the pitch with how fresh they are, then the
## bench. SPACE (A) on a player on the pitch, then SPACE on a sub: he comes on at the next
## stoppage (Match.request_sub). DEL / BACKSPACE (X) calls a substitution off. TAB (LB/RB)
## shows the other human's side when two play. ESC (B) goes back to the pause menu.
## Ratings out of 50, as on the team sheet.

const YELLOW := Color(1, 0.85, 0.2)
const GREY := Color(0.8, 0.8, 0.8)
const ROW := 22.0
const TOP := 150.0

var on_close: Callable  # called when it closes
var _m  # the Match
var _teams: Array = []  # the human sides
var _team_index := 0
var _row := 0
var _picked := -1  # slot picked to go off
var _dyn := Control.new()


func _init(match_game, teams: Array) -> void:
	_m = match_game
	_teams = teams


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 11
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.05, 0.07, 0.93)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_dyn.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dyn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dyn)
	_refresh()


func _team() -> Team:
	return _teams[_team_index]


## Players on the pitch side: eleven, or five indoors.
func _xi() -> int:
	return _team().players.size()


func _rows() -> int:
	return _xi() + _team().bench.size()


## The pending substitution for `slot`, or [].
func _pending(slot: int) -> Array:
	for s in _team().pending:
		if s[0] == slot:
			return s
	return []


func _unhandled_input(event: InputEvent) -> void:
	var key: bool = event is InputEventKey and event.pressed
	var button: bool = event is InputEventJoypadButton and event.pressed
	if not key and not button:
		return
	get_viewport().set_input_as_handled()
	if key:
		match event.physical_keycode:
			KEY_W, KEY_UP: _move(-1)
			KEY_S, KEY_DOWN: _move(1)
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER: _select()
			KEY_DELETE, KEY_BACKSPACE: _cancel()
			KEY_TAB: _switch_team()
			KEY_ESCAPE: _close()
	else:
		match event.button_index:
			JOY_BUTTON_DPAD_UP: _move(-1)
			JOY_BUTTON_DPAD_DOWN: _move(1)
			JOY_BUTTON_A: _select()
			JOY_BUTTON_X: _cancel()
			JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER: _switch_team()
			JOY_BUTTON_B, JOY_BUTTON_START, JOY_BUTTON_BACK: _close()


func _move(step: int) -> void:
	_row = clampi(_row + step, 0, _rows() - 1)
	_refresh()


func _select() -> void:
	var t := _team()
	if _row < _xi():
		var p: Footballer = t.players[_row]
		_picked = -1 if _picked == _row or p.sent_off or not _pending(_row).is_empty() else _row
		if _picked >= 0:
			_row = _xi() if t.bench.size() > 0 else _row  # straight down to the bench
	elif _picked >= 0:
		if _m.request_sub(t, _picked, t.bench[_row - _xi()]):
			_row = _picked
		_picked = -1
	_refresh()


func _cancel() -> void:
	if _row < _xi():
		_team().pending.erase(_pending(_row))
	_picked = -1
	_refresh()


func _switch_team() -> void:
	if _teams.size() > 1:
		_team_index = 1 - _team_index
		_row = 0
		_picked = -1
		_refresh()


func _close() -> void:
	queue_free()
	if on_close.is_valid():
		on_close.call()


func _label(text: String, font_size: int, colour: Color, pos: Vector2, width := 0.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var l := UiText.label(text, font_size, colour, 5)
	l.position = pos
	if width > 0.0:
		l.size.x = width
		l.horizontal_alignment = align
		l.clip_text = true
	_dyn.add_child(l)


func _rect(pos: Vector2, size: Vector2, colour: Color) -> void:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = colour
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dyn.add_child(r)


func _refresh() -> void:
	for c in _dyn.get_children():
		c.free()
	var t := _team()
	_label("SUBSTITUTIONS  ·  %s" % t.name.to_upper(), 30, YELLOW, Vector2(0, 40), 1280, HORIZONTAL_ALIGNMENT_CENTER)
	var left := t.subs_left - t.pending.size()
	_label("%d LEFT   ·   THEY COME ON AT THE NEXT STOPPAGE" % left, 16, GREY, Vector2(0, 84), 1280,
		HORIZONTAL_ALIGNMENT_CENTER)
	var x := 210.0
	var head := TOP - 26
	for c in [["NO", 0, 30], ["NAME", 40, 0], ["POS", 280, 0], ["OVR", 330, 40], ["STA", 380, 40],
			["CONDITION", 440, 0], ["RATING", 620, 60]]:
		_label(c[0], 13, GREY, Vector2(x + c[1], head), c[2], HORIZONTAL_ALIGNMENT_CENTER if c[2] > 0 else HORIZONTAL_ALIGNMENT_LEFT)
	for r in _rows():
		var y := TOP + r * ROW + (8.0 if r >= _xi() else 0.0)
		if r == _xi():
			_rect(Vector2(x - 70, y - 5), Vector2(940, 1), Color(YELLOW, 0.5))
		if r == _row:
			_rect(Vector2(x - 70, y), Vector2(940, ROW), Color(YELLOW, 0.25))
		if r == _picked:
			_rect(Vector2(x - 70, y), Vector2(940, ROW), Color(0.3, 0.8, 1, 0.35))
		if r < _xi():
			_pitch_row(t.players[r], r, x, y)
		else:
			_bench_row(t.bench[r - _xi()], x, y)
	var hint := UiText.hint([["↑/↓", "choose"], ["SPACE", "player off, then a sub on"], ["DEL", "call it off"], ["ESC", "back"]])
	if _teams.size() > 1:
		hint += "   TAB other side"
	_label(hint, 15, GREY, Vector2(0, 690), 1280, HORIZONTAL_ALIGNMENT_CENTER)


func _pitch_row(p: Footballer, slot: int, x: float, y: float) -> void:
	var colour := GREY if p.sent_off else Color.WHITE
	_label(Team.slots_of(_team().formation)[slot].pos, 14, YELLOW, Vector2(x - 64, y))
	_player(p.entry, p.number, p.display_name, x, y, colour)
	if p.sent_off:
		_label("SENT OFF", 14, Color(1, 0.4, 0.4), Vector2(x + 440, y))
		return
	var c := p.condition
	var bar := Color(0.45, 1, 0.45) if c >= 0.75 else Color(0.95, 0.75, 0.35) if c >= 0.5 else Color(1, 0.45, 0.4)
	_rect(Vector2(x + 440, y + 7), Vector2(120, 8), Color(1, 1, 1, 0.12))
	_rect(Vector2(x + 440, y + 7), Vector2(120 * c, 8), bar)
	_label("%d%%" % roundi(c * 100.0), 14, bar, Vector2(x + 566, y), 44, HORIZONTAL_ALIGNMENT_RIGHT)
	var r: float = _m.stats.rating(p)
	_label("%.1f" % r, 14, Color(0.45, 1, 0.45) if r >= 7.0 else Color.WHITE if r >= 6.0 else Color(1, 0.45, 0.4),
		Vector2(x + 620, y), 60, HORIZONTAL_ALIGNMENT_CENTER)
	if p.yellow:
		_rect(Vector2(x + 690, y + 4), Vector2(10, 14), Color(1, 0.9, 0.1))
	var s := _pending(slot)
	if not s.is_empty():
		_label("◀ %s ON" % s[1].name, 14, Color(0.4, 0.9, 1), Vector2(x + 710, y), 150)


func _bench_row(e: Dictionary, x: float, y: float) -> void:
	var going_on := false
	for s in _team().pending:
		going_on = going_on or s[1] == e
	var colour := Color(0.4, 0.9, 1) if going_on else Color.WHITE
	_label("SUB", 14, GREY, Vector2(x - 64, y))
	_player(e, e.number, e.name, x, y, colour)
	_label("FRESH", 14, Color(0.45, 1, 0.45), Vector2(x + 440, y))


## Number, name, position, overall and stamina (out of 50) from a squad entry.
func _player(e: Dictionary, number: int, who: String, x: float, y: float, colour: Color) -> void:
	_label("%d" % number, 14, colour, Vector2(x, y), 30, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(who, 14, colour, Vector2(x + 40, y), 230)
	_label(e.get("position", ""), 14, GREY, Vector2(x + 280, y))
	if e.is_empty():
		return
	var o := TeamManager.fifty(e.overall)
	_label("%d" % o, 14, TeamManager.band(o), Vector2(x + 330, y), 40, HORIZONTAL_ALIGNMENT_CENTER)
	var st := TeamManager.fifty(e.stats.get("stamina", 1))
	_label("%d" % st, 14, TeamManager.band(st), Vector2(x + 380, y), 40, HORIZONTAL_ALIGNMENT_CENTER)
