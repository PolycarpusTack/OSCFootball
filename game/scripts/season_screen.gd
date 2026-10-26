class_name SeasonScreen
extends Control
## The league season (title screen ▲/▼ to SEASON): first the setup (your club, the save slot),
## then the season itself: the table, this round's fixtures and results, your next match and who's
## suspended for it. SPACE plays your match (Match.play_fixture; the round's other fixtures are
## simulated first, so their goals come in during it), S simulates it; TAB shows the scorers,
## cards and best-rated tables. At full time the match hands its result back
## (Competition.finish, from Match._leave_full_time) and this screen shows the next round. Saved
## (SaveGame, its slot) every time it shows; Esc goes back to the title.

const SCENE := "res://scenes/season.tscn"
const TITLE := "res://scenes/title.tscn"
const MATCH := "res://scenes/main.tscn"
const BACKGROUND := "res://brand/title.png"
const YELLOW := Color("ffe34d")
const GREY := Color(0.62, 0.62, 0.62)
const COLUMNS := [["", 40], ["CLUB", 76], ["P", 330], ["W", 370], ["D", 410], ["L", 450], ["GF", 490], ["GA", 535],
	["GD", 580], ["PTS", 630]]  # the table: heading, x
const LIST := 10  # rows in each stats table

static var slot := 1  # the season's save slot

var _club := 0  # into _clubs
var _row := 0  # setup: 0 your club, 1 slot, 2 start
var _stats := false  # TAB: the stats tables instead of the table and fixtures
var _clubs: Array = []
var _page := Control.new()  # everything that changes, rebuilt on each refresh
var _heading: Label
var _prompt: Label
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
	add_child(_page)
	_heading = _label("", 30, YELLOW, Vector2(0, 30), 1280, self)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt = _label("", 18, Color(0.85, 0.85, 0.85), Vector2(0, 670), 1280, self)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_club = maxi(0, _clubs.find(Match.home_club))
	if Match.competition == null:  # a new season goes in the first empty slot, if any
		var saves := SaveGame.list()
		var empty := range(SaveGame.SLOTS).filter(func(i): return saves[i].is_empty())
		if not empty.is_empty():
			slot = empty[0] + 1
	_refresh()


func _label(text: String, font_size: int, colour: Color, at: Vector2, width := 0.0, parent: Node = _page) -> Label:
	var l := UiText.label(text, font_size, colour)
	l.position = at
	if width > 0.0:
		l.size.x = width
	parent.add_child(l)
	return l


func _refresh() -> void:
	for c in _page.get_children():
		c.free()
	var season := Match.competition as Season
	_back.modulate = Color(0.15, 0.15, 0.18) if season == null else Color(0.07, 0.07, 0.09)
	if season == null:
		_setup()
		return
	SaveGame.save(slot, season)
	if _stats:
		_stats_page(season)
	else:
		_table(season)
		_fixtures(season)
	if season.done:
		_heading.text = "%s ARE CHAMPIONS!" % season.winner.to_upper()
		_prompt.text = UiText.hint([["TAB", "table" if _stats else "stats"], ["SPACE", "back to the title"]])
	else:
		_heading.text = "%s · ROUND %d OF %d" % [season.name, season.round + 1, season.rounds.size()]
		_prompt.text = UiText.hint([["SPACE", "play"], ["S", "simulate my match"], ["TAB", "table" if _stats else "stats"],
			["ESC", "title (saved)"]])


func _setup() -> void:
	var saves := SaveGame.list()
	var rows := ["YOUR CLUB   ◀  %s  ▶" % _clubs[_club],
		"SAVE IN   ◀  SLOT %d: %s  ▶" % [slot, CupScreen.describe(saves[slot - 1])], "START"]
	for i in rows.size():
		_label(("▶  " if i == _row else "") + rows[i], 26, YELLOW if i == _row else Color.WHITE,
			Vector2(0, 250 + i * 60), 1280).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.text = "LEAGUE SEASON"
	_prompt.text = UiText.hint([["↑/↓", "choose"], ["←/→", "change"], ["SPACE", "start"], ["ESC", "back"]])


## The table, top first; the humans' clubs in yellow.
func _table(season: Season) -> void:
	for c in COLUMNS:
		_label(c[0], 14, GREY, Vector2(c[1], 92))
	var rows := season.table()
	for i in rows.size():
		var r: Dictionary = rows[i]
		var y := 114.0 + i * 29
		var colour := YELLOW if r.club in season.humans else Color.WHITE
		var cells := [str(i + 1), r.club, r.played, r.won, r.drawn, r.lost, r.gf, r.ga, ("+%d" % r.gd) if r.gd > 0 else str(r.gd), r.points]
		for c in COLUMNS.size():
			_label(str(cells[c]), 17, colour, Vector2(COLUMNS[c][1], y))


## This round's fixtures and results, your next match, who's suspended for it.
func _fixtures(season: Season) -> void:
	var x := 720.0
	_label("ROUND %d" % mini(season.round + 1, season.rounds.size()), 16, YELLOW, Vector2(x, 92))
	var shown: Array = season.current()
	for i in shown.size():
		var f: Dictionary = shown[i]
		var r: Dictionary = f.result
		var colour := YELLOW if season.is_human(f) else Color.WHITE
		var y := 118.0 + i * 30
		_label(f.home, 17, colour, Vector2(x, y), 220).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_label("%d - %d" % [r.home_goals, r.away_goals] if not r.is_empty() else "v", 17, colour, Vector2(x + 225, y), 70) \
			.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label(f.away, 17, colour, Vector2(x + 300, y))
	if season.done:
		return
	var mine := season.next_fixture()
	var y0 := 118.0 + shown.size() * 30 + 30
	if not mine.is_empty():
		_label("YOUR MATCH", 16, YELLOW, Vector2(x, y0))
		_label("%s v %s" % [mine.home, mine.away], 22, Color.WHITE, Vector2(x, y0 + 24))
		var club: String = mine.home if mine.home in season.humans else mine.away
		var banned: Array = season.bans.get(club, {}).keys()
		_label("SUSPENDED: %s" % (", ".join(banned) if not banned.is_empty() else "nobody"), 15,
			Color(1, 0.45, 0.4) if not banned.is_empty() else GREY, Vector2(x, y0 + 60), 520).autowrap_mode = TextServer.AUTOWRAP_WORD
		var hurt: Dictionary = season.injuries.get(club, {})
		_label("INJURED: %s" % (", ".join(hurt.keys().map(func(n): return "%s (%d)" % [n, hurt[n]])) if not hurt.is_empty() else "nobody"), 15,
			Color(1, 0.45, 0.4) if not hurt.is_empty() else GREY, Vector2(x, y0 + 84), 520).autowrap_mode = TextServer.AUTOWRAP_WORD


## TAB: the top scorers, the cards and the best rated (from the matches played on the pitch).
func _stats_page(season: Season) -> void:
	var tables := [
		["TOP SCORERS", season.scorers(), func(r): return str(r.goals)],
		["CARDS (YELLOW / RED)", season.cards(), func(r): return "%d / %d" % [r.yellow, r.red]],
		["BEST RATED (YOUR MATCHES)", season.ratings(), func(r): return "%.1f" % r.rating],
	]
	for t in tables.size():
		var x := 40.0 + t * 410
		_label(tables[t][0], 16, YELLOW, Vector2(x, 92))
		var rows: Array = tables[t][1]
		if rows.is_empty():
			_label("nobody yet", 16, GREY, Vector2(x, 124))
		for i in mini(LIST, rows.size()):
			var r: Dictionary = rows[i]
			var colour := YELLOW if r.club in season.humans else Color.WHITE
			var y := 124.0 + i * 50
			_label(r.name, 17, colour, Vector2(x, y), 300).clip_text = true
			_label(r.club, 13, GREY, Vector2(x, y + 22))
			_label(tables[t][2].call(r), 17, colour, Vector2(x + 300, y), 80).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _start_season() -> void:
	var season := Season.create(_clubs, [_clubs[_club]], randi())
	if season:
		Match.enter_competition(season)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	var button: bool = event is InputEventJoypadButton and event.pressed
	if not key and not button:
		return
	var code: Key = event.physical_keycode if key else KEY_NONE
	var pad: int = event.button_index if button else -1
	var go := code in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] or pad in [JOY_BUTTON_A, JOY_BUTTON_START]
	var back := code == KEY_ESCAPE or pad in [JOY_BUTTON_B, JOY_BUTTON_BACK]
	var season := Match.competition as Season
	if back:
		Match.leave_competition()
		get_tree().change_scene_to_file(TITLE)
	elif season == null:
		var step := -1 if code in [KEY_LEFT, KEY_A] or pad == JOY_BUTTON_DPAD_LEFT else \
			1 if code in [KEY_RIGHT, KEY_D] or pad == JOY_BUTTON_DPAD_RIGHT else 0
		if code in [KEY_UP, KEY_W] or pad == JOY_BUTTON_DPAD_UP:
			_row = (_row + 2) % 3
		elif code in [KEY_DOWN, KEY_S] or pad == JOY_BUTTON_DPAD_DOWN:
			_row = (_row + 1) % 3
		elif step != 0 and _row == 0:
			_club = (_club + step + _clubs.size()) % _clubs.size()
		elif step != 0 and _row == 1:
			slot = (slot - 1 + step + SaveGame.SLOTS) % SaveGame.SLOTS + 1
		elif go:
			_start_season()
			return
		_refresh()
	elif code == KEY_TAB or pad in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		_stats = not _stats
		_refresh()
	elif season.done:
		if go:
			Match.leave_competition()
			get_tree().change_scene_to_file(TITLE)
	elif code == KEY_S or pad == JOY_BUTTON_Y:
		simulate_mine(season)
		_refresh()
	elif go:
		play_mine(season)
		get_tree().change_scene_to_file(MATCH)


## S: the human's fixture simulated, the round closed.
static func simulate_mine(season: Season) -> void:
	season.simulate(season.next_fixture())
	season.close_round()


## SPACE: the round's other fixtures simulated (their goals come in during the match), then the
## human's set up to play: a league match, so no extra time.
static func play_mine(season: Season) -> void:
	season.simulate_others()
	Match.play_fixture(season, season.next_fixture(), false)
