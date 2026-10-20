class_name Commentary
extends RefCounted
## The match commentary: a line along the top of the screen for what happens, from the
## match's `event` signal (who did it from Match.detail, else off the ball, as MatchStats).
## Lines (commentary_lines.gd) are picked at random, never the same as either of the last two
## for that key. A goal's line says what kind of goal: opener, equaliser (late, or a man
## down), late, pulled one back, clincher, hat-trick, own goal, golden goal, super-shot. A
## shot waits up to SHOT_WAIT for what became of it, so the two are said together. At most
## QUEUE_MAX lines wait; the big moments (priority 2) clear the chatter; chatter is dropped
## when lines are waiting or it was said just now. Goals and red cards go in the report.
## The structure follows CM3's match commentary (see the CM3 research notes); every line is ours.

const LINES_SCRIPT := preload("res://scripts/commentary_lines.gd")
const SHOW := [2.2, 2.8, 3.4]  # seconds a line stays up, by priority
const QUEUE_MAX := 3
const QUIET := 4.0  # chatter of a kind said this recently isn't said again
const SHOT_WAIT := 1.6  # seconds a shot waits for its save, goal or woodwork
const LONG_SHOT_M := 22.0
const LATE_MINUTE := 80.0
const OUTCOMES := ["save", "woodwork", "goal"]

var line := ""  # what's up now
var report: Array[String] = []  # "23' GOAL  Vanaken (BRU)": goals and red cards, for full time
var _m  # the Match
var _queue := []  # [priority, text], oldest first
var _left := 0.0  # seconds the current line has left
var _time := 0.0
var _said := {}  # key -> _time it was last said
var _recent := {}  # key -> the last two lines picked for it
var _shot := {}  # a shot waiting for its outcome: priority, text, left, age


func _init(m) -> void:
	_m = m
	m.event.connect(_on_event)


func tick(delta: float) -> void:
	_time += delta
	if not _shot.is_empty():
		_shot.age += delta
		_shot.left -= delta
		if _shot.left <= 0.0:  # nothing came of it
			var s := _shot
			_shot = {}
			_queue_line(s.priority, s.text, "shot")
			_queue_line(0, _pick("shot.missed", {}), "shot.missed", true)
	if _left > 0.0:
		_left -= delta
		if _left > 0.0:
			return
		line = ""
	if not _queue.is_empty():
		var next: Array = _queue.pop_front()
		line = next[1]
		_left = SHOW[next[0]]


func _on_event(kind: String, team: Team) -> void:
	if not _m.shootout.is_empty() and kind != "shoot-out":
		return
	var detail: Dictionary = _m.detail if _m.detail.get("kind") == kind else {}
	var ball = _m.ball
	var p1: Footballer = detail.get("p1", ball.holder if kind == "save" and ball.holder else ball.last_touch)
	var tokens := {
		"p1": p1.display_name if p1 else team.name, "p2": detail.p2.display_name if detail.get("p2") else "him",
		"t": team.name, "opp": _m.opponent(team).name, "score": "%d-%d" % [_m.home.score, _m.away.score],
		"min": str(int(minute()) + 1),
	}
	var key := kind
	if kind == "goal":
		key = goal_key(team, p1)
		report.append("%d'  GOAL  %s (%s)%s" % [int(minute()) + 1, tokens.p1, (p1.team if p1 else team).short,
			"  own goal" if key == "goal.own" else ""])
	elif kind == "red card":
		if detail.get("second"):
			key = "red card.second"
		report.append("%d'  RED CARD  %s (%s)" % [int(minute()) + 1, tokens.p1, team.short])
	elif kind == "shot" and p1 and p1.position.distance_to(p1.team.goal_attacked()) > Pitch.m(LONG_SHOT_M):
		key = "shot.long"
	var entry := _entry(key)
	if entry.is_empty():
		return
	var text := _pick(key, tokens)
	if kind == "shot" or Supers.LIST.has(kind):
		if kind == "shot" and not _shot.is_empty() and _shot.age < 0.1:
			return  # the super-shot just said is this shot
		_flush_shot()
		_shot = {"priority": entry.p, "text": text, "left": SHOT_WAIT, "age": 0.0}
		return
	if kind in OUTCOMES:
		_flush_shot()
	_queue_line(entry.p, text, key)


## What kind of goal `team` just scored, the score already counted (`p1` last touched it).
func goal_key(team: Team, p1: Footballer) -> String:
	if p1 and p1.team != team:
		return "goal.own"
	if _m.half > 2:
		return "goal.golden"
	if Supers.LIST.has(_m.ball.kick_kind) or Supers.LIST.has(_m.ball.power):
		return "goal." + (_m.ball.power if Supers.LIST.has(_m.ball.power) else _m.ball.kick_kind)
	var other: Team = _m.opponent(team)
	if p1 and _m.stats and _m.stats.goals.get(p1, 0) == 3:
		return "goal.hat_trick"
	var late := minute() >= LATE_MINUTE
	if team.score == other.score:
		if CpuManager._men(team) < CpuManager._men(other):
			return "goal.equaliser.short"
		return "goal.equaliser.late" if late else "goal.equaliser"
	if team.score < other.score:
		return "goal.back"
	if team.score + other.score == 1:
		return "goal.opener"
	if late and team.score - other.score == 1:
		return "goal.late"
	if team.score - other.score >= 2 and minute() >= 60.0:
		return "goal.clincher"
	return "goal"


func minute() -> float:
	return _m.clock / _m.half_seconds * 45.0


## A shot still waiting for its outcome goes up first.
func _flush_shot() -> void:
	if _shot.is_empty():
		return
	var s := _shot
	_shot = {}
	_queue_line(s.priority, s.text, "shot", true)


func _queue_line(priority: int, text: String, key: String, follow_on := false) -> void:
	if priority == 0 and not follow_on and (not _queue.is_empty() or _time - _said.get(key, -INF) < QUIET):
		return
	if priority == 2:
		_queue = _queue.filter(func(q): return q[0] > 0)
	if _queue.size() >= QUEUE_MAX:
		var lowest := 0
		for i in _queue.size():
			if _queue[i][0] < _queue[lowest][0]:
				lowest = i
		if _queue[lowest][0] >= priority and not follow_on:
			return
		_queue.remove_at(lowest)
	_queue.append([priority, text])
	_said[key] = _time


## The line for `key` (or the nearest key it falls back to), tokens filled in.
func _pick(key: String, tokens: Dictionary) -> String:
	var k := _resolve(key)
	if k == "":
		return ""
	var lines: Array = LINES_SCRIPT.LINES[k].lines
	var recent: Array = _recent.get(k, [])
	var fresh := range(lines.size()).filter(func(i): return not i in recent)
	var i: int = fresh[randi() % fresh.size()] if not fresh.is_empty() else randi() % lines.size()
	recent.append(i)
	_recent[k] = recent.slice(-2)
	var text: String = lines[i]
	for t in tokens:
		text = text.replace("{%s}" % t, tokens[t])
	return text


func _entry(key: String) -> Dictionary:
	var k := _resolve(key)
	return LINES_SCRIPT.LINES[k] if k != "" else {}


static func _resolve(key: String) -> String:
	while key != "":
		if LINES_SCRIPT.LINES.has(key):
			return key
		var cut := key.rfind(".")
		key = key.substr(0, cut) if cut > 0 else ""
	return ""

