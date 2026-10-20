class_name MatchStats
extends RefCounted
## The match's numbers for the full-time screen: counted from the match's `event` signal
## (who did it is read off the ball at that moment), plus possession, timed in open play.
## And a match rating out of 10 per player, CM3's way (our numbers): everyone starts at 6,
## goals, assists, saves, shots, passes that find a teammate and winning the ball push it up,
## giving it away, fouls, cards and (keepers) goals let in pull it down; a scorer never rates
## under 5.5 + his goals. Man of the Match: the best rating of everyone who played.

const COUNTED := {  # event -> stat
	"goal": "goals", "shot": "shots", "save": "saves", "foul": "fouls",
	"yellow card": "yellow cards", "red card": "red cards", "offside": "offsides", "corner": "corners",
}
const ROWS := ["goals", "shots", "saves", "fouls", "yellow cards", "red cards", "offsides", "corners"]
const RATING_START := 6.0
const RATING := {  # rating points per player for what he does
	"goal": 0.45, "own goal": -0.4, "assist": 0.25, "save": 0.4, "conceded": -0.4,
	"yellow card": -0.25, "red card": -1.0,
	# the small things, for 3-minute halves: they happen more in a longer match, so count less
	"shot": 0.1, "pass": 0.06, "pass lost": -0.08, "won ball": 0.12, "lost ball": -0.1,
	"header": 0.08, "volley": 0.08, "clearance": 0.08, "foul": -0.1,
}
const SMALL_THINGS_HALF := 3.0  # real minutes per half the small things' points are for

var counts := {}  # Team -> {stat: int}
var possession := {}  # Team -> seconds the ball was theirs in open play
var points := {}  # Footballer -> rating points (see RATING) on top of RATING_START
var goals := {}  # Footballer -> goals
var _m  # the Match
var _holder: Footballer  # who had the ball last frame
var _released_by: Footballer  # who had it last, while it's loose
var _released_kind := ""  # how it left him: the ball's kick_kind then (taking the ball clears it)
var _assist := []  # [passer, receiver] of the last pass that found a teammate


func _init(m) -> void:
	_m = m
	for t in [m.home, m.away]:
		counts[t] = {}
		for stat in ROWS:
			counts[t][stat] = 0
		possession[t] = 0.0
	m.event.connect(_on_event)
	m.player_event.connect(_rate)


func _on_event(kind: String, team: Team) -> void:
	if not _m.shootout.is_empty():  # shoot-out kicks don't count
		return
	if COUNTED.has(kind):
		counts[team][COUNTED[kind]] += 1
	var ball = _m.ball
	var who: Footballer = ball.holder if kind == "save" and ball.holder else ball.last_touch
	if kind == "goal":
		_rate("conceded", _m.opponent(team).keeper())
		if who == null or who.team != team:
			_rate("own goal", who)
			return
		goals[who] = goals.get(who, 0) + 1
		var passer: Footballer = _assist[0] if _released_by == who and _assist.size() == 2 and _assist[1] == who \
			else _released_by
		if passer and passer != who and passer.team == team:
			_rate("assist", passer)
	if kind in ["goal", "shot", "save", "header", "volley", "clearance"] and who and who.team == team:
		_rate(kind, who)


func _rate(kind: String, p: Footballer) -> void:
	if p == null or not _m.shootout.is_empty():
		return
	var add: float = RATING[kind]
	if not kind in ["goal", "own goal", "assist", "save", "conceded", "yellow card", "red card"]:
		add *= SMALL_THINGS_HALF / _m.half_seconds * 60.0
	points[p] = points.get(p, 0.0) + add


## `p`'s match rating, 1-10.
func rating(p: Footballer) -> float:
	var r: float = RATING_START + points.get(p, 0.0)
	if goals.get(p, 0) > 0:
		r = maxf(r, 5.5 + goals[p])
	return clampf(r, 1.0, 10.0)


## Who has the ball, frame to frame: a pass that found a teammate, a ball won or lost.
func _possession() -> void:
	var h: Footballer = _m.ball.holder
	if h == _holder:
		return
	if h == null:
		_released_by = _holder
		_released_kind = _m.ball.kick_kind
	else:
		var before: Footballer = _holder if _holder else _released_by
		if before and before != h:
			var kick := _released_kind if _holder == null else ""
			var passed := _holder == null and kick in ["pass", "cross"]
			if before.team == h.team:
				if passed:
					_rate("pass", before)
					_assist = [before, h]
			elif kick != "shot" and not Supers.LIST.has(kick):  # a shot saved or blocked is no giveaway
				_rate("won ball", h)
				_rate("pass lost" if passed else "lost ball", before)
		_released_by = null
	_holder = h


## Open play: the side on the ball (or that touched it last) has it.
func tick(delta: float) -> void:
	_possession()
	var p: Footballer = _m.ball.holder if _m.ball.holder else _m.ball.last_touch
	if p and possession.has(p.team):
		possession[p.team] += delta


## `t`'s share of possession, 0-100 (50 before anyone's had it).
func possession_percent(t: Team) -> int:
	var total: float = possession[_m.home] + possession[_m.away]
	return 50 if total <= 0.0 else roundi(100.0 * possession[t] / total)


## The best rating; level, the winners' man; null if nobody rose above the start.
func man_of_the_match() -> Footballer:
	var winner: Team = _m.match_winner()
	var best: Footballer = null
	for p in points:
		var r := rating(p)
		if best == null or r > rating(best) or (r == rating(best) and p.team == winner and best.team != winner):
			best = p
	return best if best and rating(best) > RATING_START else null
