class_name PauseMenu
extends CanvasLayer
## Esc (gamepad Start) pauses the match: the whole tree stops (clock, AI, ball, wind-ups)
## while this layer keeps running. Up / Down picks, Space / Enter (A) chooses, Esc / Start
## (B) resumes. MOVES shows the command list (MoveList), REPLAY the last 10 s (Replay, stepped),
## SUBSTITUTIONS the human sides' SubsMenu,
## PLAYERS switches the player art (Pixel / Rendered).

const TITLE := "res://scenes/title.tscn"
const ITEMS := ["RESUME", "MOVES", "REPLAY", "SUBSTITUTIONS", "PLAYERS", "RESTART MATCH", "QUIT TO TITLE"]

var _pick := 0
var _box := Control.new()  # the menu: shown and hidden as one
var _rows: Array[Label] = []
var _moves := MoveList.new()  # the command list, over the menu while it's open
var _pad := false  # the last menu input came from a gamepad
var _subs_open := false  # the substitutions screen (its own layer, its own input) is up


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(shade)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 14)
	shade.add_child(column)
	column.add_child(_label("PAUSED", 56, Color(1, 0.85, 0.2)))
	for text in ITEMS:
		var row := _label(text, 30, Color.WHITE)
		column.add_child(row)
		_rows.append(row)
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.visible = false
	add_child(_box)
	add_child(_moves)
	_refresh()


func _label(text: String, font_size: int, colour: Color) -> Label:
	var l := UiText.label(text, font_size, colour, 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _refresh() -> void:
	for i in _rows.size():
		var text: String = ITEMS[i]
		if text == "PLAYERS":  # the player art, switched on the spot
			text = "PLAYERS: %s" % Match.PLAYER_ART[Match.player_art()]
		elif text == "QUIT TO TITLE" and Match.competition:  # the cup is saved as it was before this tie
			text = "QUIT TO TITLE (THIS %s IS LOST)" % ("TIE" if Match.competition is Cup else "MATCH")
		_rows[i].text = ("▶  %s  ◀" if i == _pick else "%s") % text
		_rows[i].modulate.a = 1.0 if i == _pick else 0.7


## Paused straight into SUBSTITUTIONS (a man badly hurt: Match._injury_subs).
func open_subs() -> void:
	set_paused(true)
	_pick = ITEMS.find("SUBSTITUTIONS")
	_choose()


func set_paused(on: bool) -> void:
	get_tree().paused = on
	_box.visible = on
	_moves.visible = false
	_pick = 0
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	var button: bool = event is InputEventJoypadButton and event.pressed
	if not key and not button or get_parent().replay.playing:  # a replay takes the keys
		return
	var toggle: bool = (key and event.physical_keycode == KEY_ESCAPE) or (button and event.button_index == JOY_BUTTON_START)
	if not get_tree().paused:
		if toggle:
			set_paused(true)
			get_viewport().set_input_as_handled()
		return
	if _subs_open:  # the substitutions screen takes the keys
		return
	get_viewport().set_input_as_handled()
	_pad = button
	var back: bool = toggle or (button and event.button_index == JOY_BUTTON_B)
	if _moves.visible:
		if back:
			_moves.visible = false
			_box.visible = true
		else:
			_moves.handle(event)
		return
	if back:
		set_paused(false)
	elif (key and event.physical_keycode in [KEY_UP, KEY_W]) or (button and event.button_index == JOY_BUTTON_DPAD_UP):
		_pick = (_pick + ITEMS.size() - 1) % ITEMS.size()
		_refresh()
	elif (key and event.physical_keycode in [KEY_DOWN, KEY_S]) or (button and event.button_index == JOY_BUTTON_DPAD_DOWN):
		_pick = (_pick + 1) % ITEMS.size()
		_refresh()
	elif (key and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]) or (button and event.button_index == JOY_BUTTON_A):
		_choose()


func _choose() -> void:
	match ITEMS[_pick]:
		"RESUME":
			set_paused(false)
		"MOVES":
			_box.visible = false
			_open_moves()
		"REPLAY":  # the last 10 s, stepped; Esc comes back here
			_box.visible = false
			get_parent().replay.play(Replay.SECONDS, 0.5, false, func(): _box.visible = true)
		"SUBSTITUTIONS":
			var menu := SubsMenu.new(get_parent(), get_parent().humans.map(func(h): return h.team))
			menu.on_close = func():
				_subs_open = false
				_box.visible = true
			_subs_open = true
			_box.visible = false
			add_sibling(menu)
		"PLAYERS":
			Match.set_player_art((Match.player_art() + 1) % Match.PLAYER_ART.size())
			_refresh()
		"RESTART MATCH":
			get_tree().paused = false
			get_tree().reload_current_scene()
		"QUIT TO TITLE":
			get_tree().paused = false
			get_tree().change_scene_to_file(TITLE)


## The move list for player 1's controlled player (all lines in autoplay), in his kit.
func _open_moves() -> void:
	var m := get_parent() as Match
	var h: Human = m.humans[0] if m and not m.humans.is_empty() and not m.autoplay else null
	var p := h.controlled if h else null
	_moves.open(p.role if p else "", h.team if h else (m.home if m else null), _pad)
