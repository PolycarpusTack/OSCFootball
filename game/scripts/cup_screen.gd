class_name CupScreen
extends Control
## The cup (title screen ▲/▼ to CUP): first the setup (how many clubs, yours, the save slot), then
## the bracket; or (▲/▼ to CONTINUE) the three save slots, Space loading one (a saved season goes
## on to SeasonScreen).
## Enter on the bracket plays your next tie (start_tie: a knockout match, your club at home);
## at full time the match hands its result back (Competition.finish, from Match._leave_full_time), the
## other ties are simulated (ResultSim) and the bracket shows the next round. Knocked out,
## Enter simulates the rest. ↑/↓ picks a setup row, ←/→ changes it; Esc goes back to the title.
## The cup is saved (SaveGame, its slot) every time the bracket shows, so quitting anywhere
## keeps it as it was before the tie being played.

const SCENE := "res://scenes/cup.tscn"
const TITLE := "res://scenes/title.tscn"
const MATCH := "res://scenes/main.tscn"
const BACKGROUND := "res://brand/title.png"
const YELLOW := Color("ffe34d")
const GREY := Color(0.62, 0.62, 0.62)
const TOP := 130.0
const BOTTOM := 640.0

static var slot := 1  # the cup's save slot
static var continuing := false  # opened from CONTINUE: the slot list instead of the setup

var _size_index := 1  # into Cup.SIZES
var _club := 0  # into _clubs
var _row := 0  # setup: 0 clubs, 1 your club, 2 slot, 3 start; continuing: the slot
var _clubs: Array = []
var _setup: Array[Label] = []
var _prompt: Label
var _heading: Label
var _bracket := Control.new()
var _back: TextureRect


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_clubs = Team.league().map(func(d): return d.name)
	_back = TextureRect.new()
	_back.texture = load(BACKGROUND)
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_back)
	_heading = _label("OSCF CUP", 30, YELLOW, Vector2(0, 40), 1280)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt = _label("", 18, Color(0.85, 0.85, 0.85), Vector2(0, 670), 1280)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_bracket)
	_club = maxi(0, _clubs.find(Match.home_club))
	_row = slot - 1 if continuing else 0
	if not continuing and Match.competition == null:  # a new cup goes in the first empty slot, if any
		var saves := SaveGame.list()
		var empty := range(SaveGame.SLOTS).filter(func(i): return saves[i].is_empty())
		if not empty.is_empty():
			slot = empty[0] + 1
	for i in 4:
		var l := _label("", 26, Color.WHITE, Vector2(0, 230 + i * 60), 1280)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_setup.append(l)
	_refresh()


func _label(text: String, font_size: int, colour: Color, at: Vector2, width := 0.0, parent: Node = self) -> Label:
	var l := UiText.label(text, font_size, colour)
	l.position = at
	if width > 0.0:
		l.size.x = width
	parent.add_child(l)
	return l


## Starts the human's next tie in `cup`: a knockout match with his club at home.
static func start_tie(cup: Cup) -> void:
	Match.play_fixture(cup, cup.next_fixture(), true)


static func leave_cup() -> void:
	Match.leave_competition()


func _refresh() -> void:
	var cup := Match.competition as Cup
	for l in _setup:
		l.visible = cup == null
	_bracket.visible = cup != null
	_back.modulate = Color(0.15, 0.15, 0.18) if cup == null else Color(0.07, 0.07, 0.09)  # the bracket needs it darker
	if cup == null:
		var saves := SaveGame.list()
		var rows: Array
		if continuing:
			rows = range(SaveGame.SLOTS).map(func(i): return "SLOT %d   %s" % [i + 1, describe(saves[i])])
			_heading.text = "CONTINUE"
			_prompt.text = UiText.hint([["↑/↓", "choose"], ["SPACE", "load"], ["ESC", "back"]])
		else:
			rows = ["CLUBS   ◀  %d  ▶" % Cup.SIZES[_size_index], "YOUR CLUB   ◀  %s  ▶" % _clubs[_club],
				"SAVE IN   ◀  SLOT %d: %s  ▶" % [slot, describe(saves[slot - 1])], "START"]
			_heading.text = "OSCF CUP"
			_prompt.text = UiText.hint([["↑/↓", "choose"], ["←/→", "change"], ["SPACE", "start"], ["ESC", "back"]])
		for i in _setup.size():
			_setup[i].text = ("▶  " if i == _row else "") + (rows[i] if i < rows.size() else "")
			_setup[i].add_theme_color_override("font_color", YELLOW if i == _row else Color.WHITE)
		return
	SaveGame.save(slot, cup)
	_draw_bracket(cup)
	if cup.done:
		_heading.text = "%s WIN THE %s!" % [cup.winner.to_upper(), cup.name]
		_prompt.text = UiText.hint([["SPACE", "back to the title"]])
	elif cup.knocked_out():
		_heading.text = "%s · KNOCKED OUT" % cup.round_name()
		_prompt.text = UiText.hint([["SPACE", "simulate to the end"], ["ESC", "title (saved)"]])
	else:
		var f := cup.next_fixture()
		_heading.text = "%s · %s" % [cup.name, cup.round_name()]  # the bracket's first column says the round too
		_prompt.text = UiText.hint([["SPACE", "play %s v %s" % [f.home, f.away]], ["ESC", "title (saved)"]])


## One column per round, each tie as two lines (the winner in white, the loser grey, the
## human's club yellow); rounds not drawn yet are empty slots.
func _draw_bracket(cup: Cup) -> void:
	for c in _bracket.get_children():
		c.queue_free()
	var columns := int(round(log(cup.clubs.size()) / log(2.0)))
	var width := 1280.0 / columns
	var font := 18 if cup.clubs.size() <= 8 else 14
	for col in columns:
		var ties := cup.clubs.size() / int(pow(2, col + 1))
		var step := (BOTTOM - TOP) / ties
		var round_ties: Array = cup.rounds[col] if col < cup.rounds.size() else []
		_label(Cup.ROUND_NAMES.get(ties, ""), 14, GREY if col != cup.rounds.size() - 1 or cup.done else YELLOW,
			Vector2(col * width + 24.0, TOP - 34.0), 0.0, _bracket)
		for i in ties:
			var y := TOP + step * (i + 0.5) - font
			var x := col * width + 24.0
			if i >= round_ties.size():
				for line in 2:
					_label("· · ·", font, GREY, Vector2(x, y + (font + 6) * line), 0.0, _bracket)
				continue
			var f: Dictionary = round_ties[i]
			var r: Dictionary = f.result
			for side in ["home", "away"]:
				var club: String = f[side]
				var text := club
				if not r.is_empty():
					text += "  %d" % r[side + "_goals"]
					if not r.pens.is_empty():
						text += " (%d)" % r.pens[0 if side == "home" else 1]
				var colour := YELLOW if club in cup.humans else Color.WHITE
				if not r.is_empty() and r.winner != club:
					colour = colour.darkened(0.45) if club in cup.humans else GREY
				_label(text, font, colour, Vector2(x, y + (font + 6) * (0 if side == "home" else 1)), 0.0, _bracket)


func _start_cup() -> void:
	var size: int = Cup.SIZES[_size_index]
	var mine: String = _clubs[_club]
	var others: Array = _clubs.filter(func(c): return c != mine)
	others.shuffle()
	var cup := Cup.create([mine] + others.slice(0, size - 1), [mine], randi())
	if cup:
		Match.enter_competition(cup)
	_refresh()


func _load(from_slot: int) -> void:
	var saved := SaveGame.load_slot(from_slot)
	if saved == null:
		return
	continuing = false
	Match.enter_competition(saved)
	if saved is Season:
		SeasonScreen.slot = from_slot
		get_tree().change_scene_to_file(SeasonScreen.SCENE)
		return
	slot = from_slot
	_refresh()


## A save slot's line: empty, unreadable, or club, round and date.
static func describe(save: Dictionary) -> String:
	if save.is_empty():
		return "EMPTY"
	if save.get("unreadable", false):
		return "CAN'T READ THIS SAVE"
	return "%s · %s · %s" % [save.club, save.round, save.date.left(16)]


## Any save to continue (the title screen offers CONTINUE then).
static func any_saved() -> bool:
	return SaveGame.list().any(func(s): return not s.is_empty() and not s.get("unreadable", false))


func _unhandled_input(event: InputEvent) -> void:
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	var button: bool = event is InputEventJoypadButton and event.pressed
	if not key and not button:
		return
	var code: Key = event.physical_keycode if key else KEY_NONE
	var pad: int = event.button_index if button else -1
	var go := code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] or pad in [JOY_BUTTON_A, JOY_BUTTON_START]
	var back := code == KEY_ESCAPE or pad in [JOY_BUTTON_B, JOY_BUTTON_BACK]
	var cup := Match.competition as Cup
	if back:
		leave_cup()
		continuing = false
		get_tree().change_scene_to_file(TITLE)
	elif cup == null:
		var rows := SaveGame.SLOTS if continuing else 4
		var step := -1 if code in [KEY_LEFT, KEY_A] or pad == JOY_BUTTON_DPAD_LEFT else \
			1 if code in [KEY_RIGHT, KEY_D] or pad == JOY_BUTTON_DPAD_RIGHT else 0
		if code in [KEY_UP, KEY_W] or pad == JOY_BUTTON_DPAD_UP:
			_row = (_row + rows - 1) % rows
		elif code in [KEY_DOWN, KEY_S] or pad == JOY_BUTTON_DPAD_DOWN:
			_row = (_row + 1) % rows
		elif continuing and go:
			_load(_row + 1)
		elif step != 0 and _row == 0:
			_size_index = (_size_index + step + Cup.SIZES.size()) % Cup.SIZES.size()
		elif step != 0 and _row == 1:
			_club = (_club + step + _clubs.size()) % _clubs.size()
		elif step != 0 and _row == 2:
			slot = (slot - 1 + step + SaveGame.SLOTS) % SaveGame.SLOTS + 1
		elif go:
			_start_cup()
			return
		_refresh()
	elif go:
		if cup.done:
			leave_cup()
			get_tree().change_scene_to_file(TITLE)
		elif cup.knocked_out():
			while not cup.done:
				cup.close_round()
			_refresh()
		else:
			start_tie(cup)
			get_tree().change_scene_to_file(MATCH)
