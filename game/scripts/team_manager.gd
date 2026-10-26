class_name TeamManager
extends Control
## Team management, between team select and the match options: CM3's squad and tactics screens
## in OSCF's colours. Each human sets up their club (player 1, then player 2 when two play); the
## CPU plays its default sheet. Sheets are saved per club (Lineup) and handed to the match
## through Match's static vars.
##
## SQUAD page: ↑/↓ (W/S, d-pad) choose a player; SPACE (A) picks him and SPACE on another swaps
## the two, so a reserve can go into the XI or onto the bench; ←/→ (A/D, gamepad Y) change the
## stats shown. TACTICS page: ↑/↓ choose a formation or one of the Team Instructions below them,
## SPACE (A) plays the formation, ←/→ change the instruction, B (gamepad X) shows the shape with or
## without the ball. TAB (LB/RB) switches page, ENTER (Start) is done, ESC (gamepad
## B) goes back. EA's 1-99 ratings are shown out of 50.

const OPTIONS := "res://scenes/match_options.tscn"
const TEAM_SELECT := "res://scenes/team_select.tscn"
const BACKGROUND := "res://brand/title.png"
const PORTRAITS := "res://assets/portraits/"
const CRESTS := "res://assets/clubs/"
const YELLOW := Color(1, 0.85, 0.2)
const GREY := Color(0.8, 0.8, 0.8)
const ROW := 16.0
const LIST_TOP := 138.0
const COL := 44.0  # width of a stat column
const PAGES := ["SQUAD", "TACTICS"]
## The squad list's column sets (CM3's View menu) and the player card's groups: EA stat, heading.
const VIEWS := [
	["GENERAL", []],
	["PHYSICAL", [["acceleration", "ACC"], ["sprintSpeed", "SPD"], ["agility", "AGI"], ["balance", "BAL"],
		["jumping", "JMP"], ["stamina", "STA"], ["strength", "STR"]]],
	["MENTAL", [["aggression", "AGG"], ["composure", "CMP"], ["reactions", "REA"], ["vision", "VIS"],
		["positioning", "POS"]]],
	["ATTACKING", [["finishing", "FIN"], ["shotPower", "POW"], ["longShots", "LNG"], ["volleys", "VOL"],
		["curve", "CUR"], ["freeKickAccuracy", "FK"], ["penalties", "PEN"]]],
	["TECHNIQUE", [["crossing", "CRO"], ["shortPassing", "SPA"], ["longPassing", "LPA"], ["dribbling", "DRI"],
		["ballControl", "CTL"], ["headingAccuracy", "HEA"]]],
	["DEFENDING", [["interceptions", "INT"], ["defensiveAwareness", "AWA"], ["standingTackle", "STK"],
		["slidingTackle", "SLD"]]],
	["GOALKEEPING", [["gkDiving", "DIV"], ["gkHandling", "HAN"], ["gkKicking", "KIC"], ["gkPositioning", "POS"],
		["gkReflexes", "REF"]]],
]
const CARD_COLUMNS := [[1, 2, 5], [3, 4, 6]]  # VIEWS groups in the card's left and right columns

var _side := 0  # 0: player 1's club (home), 1: player 2's (away)
var _club := ""
var _short := ""
var _shirt := Color.WHITE
var _squad: Array = []
var _by_id := {}
var _order: Array = []  # player ids: 0-10 the XI by formation slot, then the bench, then reserves
var _formation := Team.DEFAULT_FORMATION
var _page := 0
var _view := 0
var _row := 0
var _picked := -1  # row picked for a swap
var _tactic_row := 0
var _with_ball := false
var _tactics: Array = []  # the 4 Tactic Slots (Lineup.tactics); the first is the sheet's own
var _slot := 0  # the slot the TACTICS page edits (keys 1-4)
var _instructions := {}  # the edited slot's instructions: Team.INSTRUCTIONS key -> level
var _dyn: Control  # everything that changes, rebuilt on each refresh


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var back := TextureRect.new()
	back.texture = load(BACKGROUND)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	back.modulate = Color(0.15, 0.15, 0.18)
	add_child(back)
	_dyn = Control.new()
	_dyn.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dyn)
	_open(0)


## Ratings are EA's 1-99, shown out of 50.
static func fifty(value) -> int:
	return clampi(roundi(float(value) / 2.0), 1, 50)


## Colour for a rating out of 50.
static func band(v: int) -> Color:
	if v >= 40:
		return Color(0.45, 1, 0.45)
	if v >= 30:
		return Color.WHITE
	if v >= 20:
		return Color(0.95, 0.75, 0.35)
	return Color(1, 0.45, 0.4)


func _open(side: int) -> void:
	_side = side
	_club = Match.home_club if side == 0 else Match.away_club
	for d in Team.league():
		if d.name == _club:
			_short = d.short
			_shirt = Color(d.kit.shirt)
	_squad = Lineup.squads().get(_club, [])
	_by_id.clear()
	for e in _squad:
		_by_id[int(e.id)] = e
	var saved := Lineup.load_saved(_club)
	_formation = saved.get("formation", Team.DEFAULT_FORMATION)
	if not Team.FORMATIONS.has(_formation):
		_formation = Team.DEFAULT_FORMATION
	_set_order(Lineup.checked(_squad, _formation, saved))
	_row = 0
	_picked = -1
	_page = 0
	_tactic_row = Team.FORMATIONS.keys().find(_formation)
	_tactics = Lineup.tactics(saved, _formation)
	_pick_slot(0)
	_refresh()


func _set_order(sheet: Dictionary) -> void:
	_order = sheet.xi + sheet.bench
	var rest := _squad.filter(func(e): return not int(e.id) in _order)
	rest.sort_custom(func(a, b): return a.overall > b.overall)
	for e in rest:
		_order.append(int(e.id))


func _sheet() -> Dictionary:
	return {"xi": _order.slice(0, 11), "bench": _order.slice(11, 11 + Lineup.BENCH),
		"instructions": _tactics[0].instructions.duplicate(), "tactics": _tactics.duplicate(true)}


func _entry(row: int) -> Dictionary:
	return _by_id[int(_order[row])]


func _done() -> void:
	Lineup.save(_club, _formation, _sheet())
	if _side == 0:
		Match.home_formation = _formation
		Match.home_sheet = _sheet()
	else:
		Match.away_formation = _formation
		Match.away_sheet = _sheet()
	if _side == 0 and Match.players == 2:
		_open(1)
		return
	if Match.players == 1:  # the CPU plays its default sheet
		Match.away_formation = Team.DEFAULT_FORMATION
		Match.away_sheet = {}
	get_tree().change_scene_to_file(OPTIONS)


func _back() -> void:
	if _side == 1:
		_open(0)
	else:
		get_tree().change_scene_to_file(TEAM_SELECT)


func _swap(a: int, b: int) -> void:
	var id = _order[a]
	_order[a] = _order[b]
	_order[b] = id


func _select() -> void:
	if _page == 1:
		if _tactic_row >= Team.FORMATIONS.size():
			return  # an instruction: ←/→
		var f: String = Team.FORMATIONS.keys()[_tactic_row]
		if _slot > 0:  # another slot's formation: the XI is lined up in it when it's switched to
			_tactics[_slot].formation = f
		elif f != _formation:
			var xi := Lineup.refit(_squad, _order.slice(0, 11), f)
			_formation = f
			_tactics[0].formation = f
			for i in 11:
				_order[i] = xi[i]
	elif _picked < 0:
		_picked = _row
	else:
		if _picked != _row:
			_swap(_picked, _row)
		_picked = -1
	_refresh()


func _move(step: int) -> void:
	if _page == 0:
		_row = clampi(_row + step, 0, _order.size() - 1)
	else:
		_tactic_row = clampi(_tactic_row + step, 0, Team.FORMATIONS.size() + Team.INSTRUCTIONS.size() - 1)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_W, KEY_UP: _move(-1)
			KEY_S, KEY_DOWN: _move(1)
			KEY_A, KEY_LEFT: _change_view(-1)
			KEY_D, KEY_RIGHT: _change_view(1)
			KEY_V: _change_view(1)
			KEY_B: _toggle_ball()
			KEY_TAB: _switch_page()
			KEY_SPACE: _select()
			KEY_1, KEY_2, KEY_3, KEY_4:
				if _page == 1:
					_pick_slot(event.physical_keycode - KEY_1)
		if event.echo:
			return
		match event.physical_keycode:
			KEY_ENTER, KEY_KP_ENTER: _done()
			KEY_ESCAPE: _back()
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_UP: _move(-1)
			JOY_BUTTON_DPAD_DOWN: _move(1)
			JOY_BUTTON_DPAD_LEFT: _change_view(-1)
			JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_Y: _change_view(1)
			JOY_BUTTON_X: _toggle_ball()
			JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER: _switch_page()
			JOY_BUTTON_A: _select()
			JOY_BUTTON_START: _done()
			JOY_BUTTON_B, JOY_BUTTON_BACK: _back()


func _change_view(step: int) -> void:
	if _page == 0:
		_view = (_view + step + VIEWS.size()) % VIEWS.size()
		_refresh()
	elif _tactic_row >= Team.FORMATIONS.size():  # the instruction's level, one up or down
		var key: String = Team.INSTRUCTIONS.keys()[_tactic_row - Team.FORMATIONS.size()]
		var levels: Array = Team.INSTRUCTIONS[key]
		_instructions[key] = levels[clampi(levels.find(_instructions[key]) + step, 0, levels.size() - 1)]
		_refresh()


## The TACTICS page edits Tactic Slot `i` from now on.
func _pick_slot(i: int) -> void:
	_slot = i
	_instructions = _tactics[i].instructions  # the same Dictionary: edits go to the slot
	if is_inside_tree():
		_refresh()


func _toggle_ball() -> void:
	if _page == 1:
		_with_ball = not _with_ball
		_refresh()


func _switch_page() -> void:
	_page = 1 - _page
	_picked = -1
	_refresh()


func _label(text: String, font_size: int, colour: Color, pos: Vector2, width := 0.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := UiText.label(text, font_size, colour, 5)
	l.position = pos
	if width > 0.0:
		l.size.x = width
		l.horizontal_alignment = align
		l.clip_text = true
	_dyn.add_child(l)
	return l


func _rect(pos: Vector2, size: Vector2, colour: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = size
	r.color = colour
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dyn.add_child(r)
	return r


func _refresh() -> void:
	for c in _dyn.get_children():
		c.free()
	_header()
	if _page == 0:
		_squad_page()
		_card(_entry(_row), _row)
	else:
		_tactics_page()


func _header() -> void:
	var crest := CRESTS + "%s.png" % _short
	if ResourceLoader.exists(crest):
		var t := TextureRect.new()
		t.texture = load(crest)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.position = Vector2(40, 22)
		t.size = Vector2(44, 44)
		_dyn.add_child(t)
	_label(_club.to_upper(), 30, YELLOW, Vector2(96, 18))
	var who := "PLAYER %d" % (_side + 1)
	_label("%s  ·  TEAM SHEET  ·  %s" % [who, _formation], 16, GREY, Vector2(98, 56))
	var x := 820.0
	for i in PAGES.size():
		var on := i == _page
		if on:
			_rect(Vector2(x - 8, 28), Vector2(132, 34), Color(YELLOW, 0.22))
		_label(PAGES[i], 22, YELLOW if on else GREY, Vector2(x, 30), 116, HORIZONTAL_ALIGNMENT_CENTER)
		x += 150
	var hint := UiText.hint([["↑/↓", "choose"], ["SPACE", "pick / swap"], ["←/→", "stats"], ["TAB", "tactics"], ["ENTER", "done"],
		["ESC", "back"]]) if _page == 0 else UiText.hint([["1-4", "tactic slot"], ["↑/↓", "choose"], ["SPACE", "play the formation"],
		["←/→", "instruction"], ["B", "with / without the ball"], ["TAB", "squad"], ["ENTER", "done"], ["ESC", "back"]])
	_label(hint, 15, GREY, Vector2(0, 690), 1280, HORIZONTAL_ALIGNMENT_CENTER)


func _squad_page() -> void:
	var view: Array = VIEWS[_view]
	_label("◀  %s  ▶" % view[0], 16, YELLOW, Vector2(400, 92), 360, HORIZONTAL_ALIGNMENT_CENTER)
	var head := LIST_TOP - 22
	_label("NO", 13, GREY, Vector2(92, head))
	_label("NAME", 13, GREY, Vector2(126, head))
	_label("POS", 13, GREY, Vector2(316, head))
	var columns := _columns(view)
	for c in columns.size():
		_label(columns[c][1], 13, GREY, Vector2(360 + c * COL, head), COL, HORIZONTAL_ALIGNMENT_CENTER)
	var slots: Array = Team.FORMATIONS[_formation]
	for r in _order.size():
		var y := LIST_TOP + r * ROW
		if r == 11 or r == 11 + Lineup.BENCH:
			_rect(Vector2(40, y - 1), Vector2(760, 1), Color(YELLOW, 0.5))
		if r == _row:
			_rect(Vector2(36, y), Vector2(768, ROW), Color(YELLOW, 0.25))
		if r == _picked:
			_rect(Vector2(36, y), Vector2(768, ROW), Color(0.3, 0.8, 1, 0.35))
		var e := _entry(r)
		var tag := ""
		var tag_colour := GREY
		if r < 11:
			tag = slots[r].pos
			var f := Lineup.fit(e.position, slots[r].pos)
			tag_colour = Color(0.45, 1, 0.45) if f >= 1.0 else Color.WHITE if f >= 0.8 else Color(1, 0.45, 0.4)
		elif r < 11 + Lineup.BENCH:
			tag = "SUB"
		_label(tag, 13, tag_colour, Vector2(44, y - 2))
		_label("%d" % e.number, 13, GREY, Vector2(92, y - 2), 26, HORIZONTAL_ALIGNMENT_RIGHT)
		_label(e.name, 13, Color.WHITE if r < 11 + Lineup.BENCH else GREY, Vector2(126, y - 2), 184)
		_label(e.position, 13, GREY, Vector2(316, y - 2))
		var values := _values(e, view)
		for c in values.size():
			_label(values[c][0], 13, values[c][1], Vector2(360 + c * COL, y - 2), COL, HORIZONTAL_ALIGNMENT_CENTER)


## Column headings for a view: the GENERAL view's own, else the view's stats.
func _columns(view: Array) -> Array:
	if view[1].is_empty():
		return [["", "OVR"], ["pac", "PAC"], ["sho", "SHO"], ["pas", "PAS"], ["dri", "DRI"], ["def", "DEF"],
			["phy", "PHY"], ["", "FT"], ["", "WF"], ["", "SKL"]]
	return view[1]


## [text, colour] per column for one player.
func _values(e: Dictionary, view: Array) -> Array:
	if view[1].is_empty():
		var row := [fifty(e.overall)]
		for s in ["pac", "sho", "pas", "dri", "def", "phy"]:
			row.append(fifty(e.stats.get(s, 1)))
		var out := row.map(func(v): return ["%d" % v, band(v)])
		return out + [[str(e.preferred_foot).left(1).to_upper(), Color.WHITE], ["%d" % e.weak_foot, Color.WHITE],
			["%d" % e.skill_moves, Color.WHITE]]
	var out := []
	for s in view[1]:
		var v := fifty(e.stats.get(s[0], 1))
		out.append(["%d" % v, band(v)])
	return out


## The player card (CM3's player profile, cut to what OSCF knows): who he is, where he plays
## in this sheet and every rating out of 50.
func _card(e: Dictionary, row: int) -> void:
	var x := 830.0
	_rect(Vector2(x, 96), Vector2(420, 584), Color(0, 0, 0, 0.45))
	var path := PORTRAITS + ("%d.png" % int(e.id) if e.get("portrait", false) else "unknown.png")
	if ResourceLoader.exists(path):
		var t := TextureRect.new()
		t.texture = load(path)
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.position = Vector2(x + 16, 110)
		t.size = Vector2(80, 80)
		_dyn.add_child(t)
	_label(e.name, 24, Color.WHITE, Vector2(x + 110, 104), 230)
	_label(e.get("full_name", e.name), 14, GREY, Vector2(x + 110, 136), 230)
	_label("#%d   %s   %s FOOT" % [e.number, e.position, str(e.preferred_foot).to_upper()], 14, Color.WHITE,
		Vector2(x + 110, 158))
	_label("WEAK FOOT %d/5   SKILL MOVES %d/5" % [e.weak_foot, e.skill_moves], 14, Color.WHITE, Vector2(x + 110, 178))
	var o := fifty(e.overall)
	_label("%d" % o, 40, band(o), Vector2(x + 340, 100), 64, HORIZONTAL_ALIGNMENT_RIGHT)
	_label("/50", 13, GREY, Vector2(x + 370, 150), 34, HORIZONTAL_ALIGNMENT_RIGHT)
	var where := "RESERVES"
	if row < 11:
		var slot: String = Team.FORMATIONS[_formation][row].pos
		var f := Lineup.fit(e.position, slot)
		where = "PLAYING %s  ·  %s" % [slot, "NATURAL POSITION" if f >= 1.0 else "CAN PLAY THERE" if f >= 0.8
			else "OUT OF POSITION"]
	elif row < 11 + Lineup.BENCH:
		where = "ON THE BENCH"
	_label(where, 14, YELLOW, Vector2(x + 16, 202))
	for col in CARD_COLUMNS.size():
		var cx := x + 16 + col * 204
		var y := 232.0
		for g in CARD_COLUMNS[col]:
			var group: Array = VIEWS[g]
			_label(group[0], 13, YELLOW, Vector2(cx, y))
			y += 19
			for s in group[1]:
				var v := fifty(e.stats.get(s[0], 1))
				_label(s[1], 12, GREY, Vector2(cx, y - 3))
				_rect(Vector2(cx + 38, y + 4), Vector2(120, 7), Color(1, 1, 1, 0.12))
				_rect(Vector2(cx + 38, y + 4), Vector2(120.0 * v / 50.0, 7), band(v))
				_label("%d" % v, 12, band(v), Vector2(cx + 160, y - 3), 26, HORIZONTAL_ALIGNMENT_RIGHT)
				y += 15
			y += 8


func _tactics_page() -> void:
	for i in Team.TACTICS.size():  # the Tactic Slots, the edited one lit
		var x := 450.0 + i * 200
		if i == _slot:
			_rect(Vector2(x, 68), Vector2(190, 24), Color(YELLOW, 0.25))
		_label("%d  %s" % [i + 1, Team.TACTICS[i]], 15, YELLOW if i == _slot else GREY, Vector2(x, 70), 190,
			HORIZONTAL_ALIGNMENT_CENTER)
	var formation: String = _tactics[_slot].formation
	_label("FORMATION", 16, YELLOW, Vector2(60, 96))
	var names: Array = Team.FORMATIONS.keys()
	for i in names.size():
		var y := 120.0 + i * 34
		if i == _tactic_row:
			_rect(Vector2(52, y), Vector2(280, 32), Color(YELLOW, 0.25))
		var playing: bool = names[i] == formation
		_label(names[i], 22, YELLOW if playing else Color.WHITE, Vector2(70, y))
		if playing:
			_label("PLAYING", 13, YELLOW, Vector2(200, y + 8))
	var y0 := 120.0 + names.size() * 34 + 14
	_label("INSTRUCTIONS", 16, YELLOW, Vector2(60, y0))
	var keys: Array = Team.INSTRUCTIONS.keys()
	for i in keys.size():
		var y := y0 + 26 + i * 28
		var row := names.size() + i
		if row == _tactic_row:
			_rect(Vector2(52, y - 2), Vector2(280, 26), Color(YELLOW, 0.25))
		var level: String = _instructions[keys[i]]
		_label(keys[i].to_upper(), 15, GREY, Vector2(60, y))
		var arrows := "◀  %s  ▶" if row == _tactic_row else "%s"
		_label(arrows % level.to_upper(), 15, Color.WHITE if level == "normal" else YELLOW, Vector2(160, y), 170,
			HORIZONTAL_ALIGNMENT_CENTER)
	var y1 := y0 + 26 + keys.size() * 28 + 14
	_label("SHAPE", 16, YELLOW, Vector2(60, y1))
	_label("WITH THE BALL" if _with_ball else "WITHOUT THE BALL", 18, Color.WHITE, Vector2(60, y1 + 24))
	_label("B: show the other", 13, GREY, Vector2(60, y1 + 50))
	var view := PitchView.new()
	view.position = Vector2(370, 96)
	view.size = Vector2(880, 572)
	view.shirt = _shirt
	var slots: Array = Team.FORMATIONS[formation]
	var xi: Array = _order.slice(0, 11) if formation == _formation else Lineup.refit(_squad, _order.slice(0, 11), formation)
	for i in 11:
		var e: Dictionary = _by_id[int(xi[i])]
		view.players.append({
			"at": slots[i].attack if _with_ball else slots[i].defend,
			"ghost": slots[i].defend if _with_ball else slots[i].attack,
			"pos": slots[i].pos, "number": e.number, "name": e.name,
		})
	_dyn.add_child(view)


## The pitch from the side, own goal on the left, with the XI on its formation spots; the other
## phase's spots as faint rings.
class PitchView extends Control:
	var players: Array = []
	var shirt := Color.WHITE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		for i in 12:  # mown stripes
			draw_rect(Rect2(w * i / 12.0, 0, w / 12.0, h), Color("2e7d32") if i % 2 == 0 else Color("348a38"))
		var line := Color(1, 1, 1, 0.75)
		var m := func(metres: float) -> float: return metres / Pitch.LENGTH_M * w
		var across := func(metres: float) -> float: return metres / 68.0 * h
		draw_rect(Rect2(0, 0, w, h), line, false, 2.0)
		draw_line(Vector2(w / 2, 0), Vector2(w / 2, h), line, 2.0)
		draw_arc(Vector2(w / 2, h / 2), m.call(9.15), 0, TAU, 48, line, 2.0)
		for end in [0.0, w]:
			var dir := 1.0 if end == 0.0 else -1.0
			var box_w: float = m.call(16.5)
			var box_h: float = across.call(40.3)
			var six_w: float = m.call(5.5)
			var six_h: float = across.call(18.3)
			draw_rect(Rect2(end if dir > 0 else end - box_w, (h - box_h) / 2, box_w, box_h), line, false, 2.0)
			draw_rect(Rect2(end if dir > 0 else end - six_w, (h - six_h) / 2, six_w, six_h), line, false, 2.0)
		var font := ThemeDB.fallback_font
		for p in players:
			var g := _at(p.ghost)
			draw_arc(g, 9, 0, TAU, 20, Color(1, 1, 1, 0.35), 1.5)
			draw_line(g, _at(p.at), Color(1, 1, 1, 0.18), 1.0)
		for p in players:
			var c := _at(p.at)
			draw_circle(c, 13, Color.BLACK)
			draw_circle(c, 11, shirt)
			var ink := Color.BLACK if shirt.get_luminance() > 0.55 else Color.WHITE
			draw_string(font, c + Vector2(-20, 5), "%d" % p.number, HORIZONTAL_ALIGNMENT_CENTER, 40, 13, ink)
			draw_string_outline(font, c + Vector2(-60, -18), p.pos, HORIZONTAL_ALIGNMENT_CENTER, 120, 12, 4, Color.BLACK)
			draw_string(font, c + Vector2(-60, -18), p.pos, HORIZONTAL_ALIGNMENT_CENTER, 120, 12, Color(1, 0.85, 0.2))
			draw_string_outline(font, c + Vector2(-70, 32), p.name, HORIZONTAL_ALIGNMENT_CENTER, 140, 13, 4, Color.BLACK)
			draw_string(font, c + Vector2(-70, 32), p.name, HORIZONTAL_ALIGNMENT_CENTER, 140, 13, Color.WHITE)

	## A formation spot on this drawing: attacking to the right, so the right flank is at the bottom.
	func _at(spot: Vector2) -> Vector2:
		return Vector2(clampf(spot.x, 0.02, 0.98) * size.x, (1.0 - spot.y) * size.y)
