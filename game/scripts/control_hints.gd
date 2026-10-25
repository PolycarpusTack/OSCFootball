class_name ControlHints
extends CanvasLayer
## The prompts along the bottom of the match: for each human, the 3-5 things his player can do
## right now (with the ball, without it, a ball in the air coming, a keeper holding it), in
## the buttons of the keyboard or gamepad he's using, with Chaos costs greyed when the bar
## is short. In front, the combo directions he's just entered (F2 hides them).

const ARROWS := {1: "↙", 2: "↓", 3: "↘", 4: "←", 6: "→", 7: "↖", 8: "↑", 9: "↗"}
const NOTICE_SECONDS := 1.4

static var show_trail := true  # F2; kept between matches

var match_game: Match
var _lines: Array[RichTextLabel] = []
var _pad: Array[bool] = [false, false]  # each human's last input came from a gamepad
var _notice: Array[String] = ["", ""]  # a short message in front of his prompts ...
var _notice_left: Array[float] = [0.0, 0.0]  # ... for this many more seconds


func _init(m: Match) -> void:
	match_game = m


func _ready() -> void:
	var two := match_game.humans.size() == 2
	for h in match_game.humans:
		var line := RichTextLabel.new()
		line.bbcode_enabled = true
		line.fit_content = true
		line.scroll_active = false
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)  # a second line grows upward, on screen
		line.grow_vertical = Control.GROW_DIRECTION_BEGIN
		line.offset_left = 12.0 + (h.index * 640.0 if two else 0.0)
		line.offset_right = line.offset_left + (616.0 if two else 1256.0)
		line.offset_top = -8.0
		line.offset_bottom = -8.0
		line.add_theme_font_size_override("normal_font_size", 13 if two else 14)
		line.add_theme_color_override("font_outline_color", Color.BLACK)
		line.add_theme_constant_override("outline_size", 4)
		add_child(line)
		_lines.append(line)


## The ↓↘→ move `p` would make: {name, cost}. A striker's is the Fireball.
static func line_move(p: Footballer) -> Dictionary:
	var move := LineMoves.for_line(p)
	if move.is_empty():
		return {"name": Supers.LIST.fireball.title.trim_suffix("!"), "cost": Supers.cost("fireball")}
	return {"name": move.title.trim_suffix("!"), "cost": move.cost}


## What `h`'s player can do now: [{input, text, short, cost}] (short: the label for half a line;
## cost 0: free). Empty outside play.
func prompts(h: Human) -> Array:
	var m := match_game
	var p := h.controlled
	if p == null or m.autoplay or m.state != Match.State.PLAY:
		return []
	var out := []
	if p.has_ball() and p.role == "G" and not m.keeper_may_release(p):
		out.append({"input": [], "text": "Holding it: opponents must leave the box", "short": "Wait: box clearing"})
	elif p.has_ball() and p.role == "G":
		out.append({"input": ["@shoot"], "text": "Kick upfield", "short": "Kick"})
		out.append({"input": ["@pass"], "text": "Throw to a teammate", "short": "Throw"})
	elif p.has_ball():
		out.append({"input": ["@shoot"], "text": "Shoot (hold: power)", "short": "Shoot"})
		var cross := h.pass_target != null and m.is_cross(p, h.pass_target)
		out.append({"input": ["@pass"], "text": "Cross" if cross else "Pass"})
		out.append({"input": ["@switch"], "text": "Dodge / skill move", "short": "Dodge"})
	elif m._ball_coming_in_air(p):
		out.append({"input": ["@shoot"], "text": "Header / volley at goal", "short": "Header"})
		out.append({"input": ["@pass"], "text": "... to a teammate", "short": "To a mate"})
	else:
		out.append({"input": ["@shoot"], "text": "Slide tackle", "short": "Slide"})
		out.append({"input": ["@switch"], "text": "Switch player", "short": "Switch"})
	if Match.chaos and p.has_ball() and (p.role != "G" or m.keeper_may_release(p)):
		var lm := line_move(p)
		out.append({"input": ["@special", "+", "@shoot"], "text": lm.name, "cost": lm.cost})
		if p.role != "G" and p.team.energy >= Supers.cost("thunder"):
			out.append({"input": ["hold", "@shoot"], "text": "THUNDER STRIKE", "short": "THUNDER", "cost": Supers.cost("thunder")})
	elif Match.chaos and not p.has_ball() and not m._ball_coming_in_air(p):
		out.append({"input": ["→", "→", "@shoot"], "text": "Body check", "cost": Match.BODY_CHECK_COST})
	if not compact() or (h.index == 0 and out.size() <= 4):  # two players: one pause prompt, room allowing
		out.append({"input": ["!Start" if _pad[h.index] else "!Esc"], "text": "Pause · moves", "short": "Pause"})
	return out


## Two players share the line: each gets half, so the prompts use their short labels.
func compact() -> bool:
	return match_game.humans.size() == 2


## The bottom line for `h`: his notice or input trail, then his prompts.
func line_text(h: Human) -> String:
	var parts := []
	for pr: Dictionary in prompts(h):
		var label: String = pr.get("short", pr.text) if compact() else pr.text
		var text := "%s %s" % [MoveList.input_bbcode(pr.input, h.index, _pad[h.index]), label]
		var cost: float = pr.get("cost", 0.0)
		if cost > 0.0:
			var short := h.team.energy < cost
			text = "[color=%s]%s [color=%s]%d[/color][/color]" % ["#9a9a9a" if short else "#ffffff", text,
				"#ff8a6b" if short else "#8fd8ff", int(cost)]
		parts.append(text)
	var lead := ""
	if _notice_left[h.index] > 0.0:
		lead = "[b][color=#ff8a6b]%s[/color][/b]     " % _notice[h.index]
	elif show_trail:
		var dirs := h.combo.recent(match_game.clock).map(func(d): return ARROWS[d])
		if not dirs.is_empty():
			lead = "[b][color=#9fe8ff]%s[/color][/b]     " % " ".join(dirs)
	return lead + ("  " if compact() else "    ").join(parts)


## A ↓↘→ or ←→ combo `h` entered but couldn't afford: says what it needs, in front of his prompts.
func combo_short(h: Human, p: Footballer, kind: String) -> void:
	var move := line_move(p) if kind == "fireball" else {"name": Supers.LIST[kind].title.trim_suffix("!"), "cost": Supers.cost(kind)}
	if Match.chaos and p.team.energy < move.cost:
		notice(h, "%s: NEED %d" % [move.name, move.cost])


func notice(h: Human, text: String) -> void:
	_notice[h.index] = text
	_notice_left[h.index] = NOTICE_SECONDS


func _process(delta: float) -> void:
	for h in match_game.humans:
		_notice_left[h.index] = maxf(0.0, _notice_left[h.index] - delta)
		var text := line_text(h)
		if _lines[h.index].text != text:
			_lines[h.index].text = text


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and absf(event.axis_value) < 0.5:
		return  # stick drift isn't someone switching to the gamepad
	for h in match_game.humans:
		if h.owns(event):
			_pad[h.index] = event is InputEventJoypadButton or event is InputEventJoypadMotion
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F2:
		show_trail = not show_trail
