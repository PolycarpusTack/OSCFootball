extends SceneTree
## The commentary: a goal's line says what kind of goal it was; a shot waits for its save and
## the two are said in order, or "missed" follows; the big moments clear the chatter waiting;
## a line isn't picked again while it's one of the last two; a foul names both men; goals and
## red cards go in the report; and every line's tokens are known.
## godot --headless --path game -s res://tests/commentary_test.gd

const LINES := preload("res://scripts/commentary_lines.gd")
const TOKENS := ["{p1}", "{p2}", "{t}", "{opp}", "{score}", "{min}"]

var m: Node
var c


func _initialize() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await create_timer(1.6).timeout
	m.state = 5  # HALF_TIME with a long pause: freeze the play
	m._state_left = 1e9
	c = m.commentary
	var ok: bool = c != null
	var bru = m.home
	var and_ = m.away
	var scorer = bru.players[9]

	# what kind of goal (the score already counted)
	var kinds := {}
	kinds["opener"] = _goal(1, 0, 20.0, scorer)
	kinds["equaliser"] = _goal(1, 1, 30.0, scorer)
	kinds["late equaliser"] = _goal(2, 2, 86.0, scorer)
	kinds["back"] = _goal(1, 2, 50.0, scorer)
	kinds["late"] = _goal(2, 1, 84.0, scorer)
	kinds["clincher"] = _goal(3, 1, 70.0, scorer)
	kinds["plain"] = _goal(2, 0, 30.0, scorer)
	kinds["own"] = _goal(1, 0, 30.0, and_.players[3])
	m.book(bru.players[4], true)
	kinds["a man down"] = _goal(1, 1, 40.0, scorer)
	bru.players[4].sent_off = false
	m.ball.power = "fireball"
	kinds["fireball"] = _goal(1, 0, 40.0, scorer)
	m.ball.power = ""
	m.half = 3
	kinds["golden"] = _goal(1, 0, 95.0, scorer)
	m.half = 1
	print("goals: %s" % kinds)
	ok = ok and kinds == {"opener": "goal.opener", "equaliser": "goal.equaliser", "late equaliser": "goal.equaliser.late",
		"back": "goal.back", "late": "goal.late", "clincher": "goal.clincher", "plain": "goal", "own": "goal.own",
		"a man down": "goal.equaliser.short", "fireball": "goal.fireball", "golden": "goal.golden"}

	# a shot, then its save: said in that order
	_reset()
	m.ball.last_touch = scorer
	m.event.emit("shot", bru)
	await _ticks(0.3)
	var keeper = and_.keeper()
	m.ball.take(keeper)
	m.event.emit("save", and_)
	var said := await _lines(4.0)
	var in_order: bool = said.size() >= 2 and scorer.display_name in said[0] and keeper.display_name in said[1]
	print("shot then save: %s" % [said])
	ok = ok and in_order

	# a shot that comes to nothing: "missed" follows
	_reset()
	m.ball.release()
	m.ball.last_touch = scorer
	m.event.emit("shot", bru)
	said = await _lines(5.0)
	var missed: bool = said.size() == 2 and said[1] in LINES.LINES["shot.missed"].lines + LINES.LINES["shot.missed"].get("chaos", [])
	print("shot, nothing: %s" % [said])
	ok = ok and missed

	# the big moment clears the chatter waiting
	_reset()
	c._queue_line(1, "a foul", "foul")
	c._queue_line(0, "chatter one", "header")
	c._queue.append([0, "chatter two"])
	c._queue_line(2, "a red card", "red card")
	var left: Array = c._queue.map(func(q): return q[1])
	print("queue after a priority-2 line: %s" % [left])
	ok = ok and left == ["a foul", "a red card"]

	# no line again while it's one of the last two picked
	_reset()
	var last := []
	var repeats := 0
	for i in 40:
		var text: String = c._pick("foul", {})
		if text in last:
			repeats += 1
		last.append(text)
		last = last.slice(-2)
	print("40 foul lines: %d repeats of the last two" % repeats)
	ok = ok and repeats == 0

	# a foul names both men
	_reset()
	var hacker = and_.players[6]
	var victim = bru.players[6]
	m.detail = {"kind": "foul", "p1": hacker, "p2": victim}
	m.event.emit("foul", and_)
	var foul_line: String = c._queue[0][1] if not c._queue.is_empty() else ""
	print("foul: %s" % foul_line)
	ok = ok and hacker.display_name in foul_line and victim.display_name in foul_line

	# the report: goals and red cards, with the minute
	c.report.clear()
	m.clock = m.half_seconds * 12.0 / 45.0
	bru.score = 1
	and_.score = 0
	m.ball.last_touch = scorer
	m.event.emit("goal", bru)
	m.book(and_.players[2], true)
	print("report: %s" % [c.report])
	ok = ok and c.report.size() == 2 and c.report[0].begins_with("13'") and "GOAL" in c.report[0] \
		and scorer.display_name in c.report[0] and "RED CARD" in c.report[1]

	# every token in every line is one the commentary fills in
	var unknown := []
	for key in LINES.LINES:
		for text in LINES.LINES[key].lines + LINES.LINES[key].get("chaos", []):
			var rest: String = text
			for t in TOKENS:
				rest = rest.replace(t, "")
			if "{" in rest or "}" in rest:
				unknown.append(key)
	print("lines with unknown tokens: %s" % [unknown])
	ok = ok and unknown.is_empty()


	# P-3-AC1: the main moments have at least 6 serious lines each
	var thin := ["goal", "goal.opener", "goal.equaliser", "shot", "shot.missed", "save", "foul", "yellow card", "lull"].filter(
		func(k): return LINES.LINES[k].lines.size() < 6)
	print("main keys with fewer than 6 serious lines: %s" % [thin])
	ok = ok and thin.is_empty()

	# P-4-AC3: Classic football never says a Chaos line; Chaos football does
	var match_script: GDScript = load("res://scripts/main.gd")
	var chaos_lines := {}
	for key in LINES.LINES:
		for text in LINES.LINES[key].get("chaos", []):
			chaos_lines[text] = true
	var seen := {false: 0, true: 0}
	for mode in [false, true]:
		match_script.chaos = mode
		for i in 300:
			for key in ["foul", "shot.missed", "lull", "save", "corner"]:
				if c._pick(key, {}) in chaos_lines:
					seen[mode] += 1
	match_script.chaos = true
	print("Chaos lines in 1,500 picks: Classic %d, Chaos %d" % [seen[false], seen[true]])
	ok = ok and seen[false] == 0 and seen[true] > 300

	# P-3-AC2: LULL seconds of open play with nothing said: a lull line about the side on the ball
	_reset()
	var holder = m.home.players[6]
	m.ball.take(holder)
	m.state = 1  # PLAY, for one tick
	c._quiet = c.LULL
	c.tick(0.0)
	m.state = 5
	var lull: String = c.line  # nothing else waiting: it goes straight up
	print("lull: %s" % lull)
	ok = ok and lull != "" and not "{" in lull
	_reset()

	print("COMMENTARY TEST PASSED" if ok else "COMMENTARY TEST FAILED")
	quit(0 if ok else 1)


func _goal(ours: int, theirs: int, minute: float, p1) -> String:
	m.home.score = ours
	m.away.score = theirs
	m.clock = m.half_seconds * minute / 45.0
	m.ball.last_touch = p1
	m.stats.goals.clear()
	return c.goal_key(m.home, p1)


func _reset() -> void:
	c._queue.clear()
	c._shot = {}
	c._said.clear()
	c._left = 0.0
	c.line = ""


## Tick the commentary for `seconds` (the match is frozen, its own ticks too).
func _ticks(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		await physics_frame
		t += 1.0 / 60.0


## Every line that goes up in the next `seconds`.
func _lines(seconds: float) -> Array:
	var out := []
	var t := 0.0
	var showing := ""
	while t < seconds:
		await physics_frame
		t += 1.0 / 60.0
		if c.line != "" and c.line != showing:
			out.append(c.line)
		showing = c.line
	return out
