class_name MatchStats
extends RefCounted
## The match's numbers for the full-time screen: counted from the match's `event` signal
## (who did it is read off the ball at that moment), plus possession, timed in open play.

const COUNTED := {  # event -> stat
	"goal": "goals", "shot": "shots", "save": "saves", "foul": "fouls",
	"yellow card": "yellow cards", "red card": "red cards", "offside": "offsides", "corner": "corners",
}
const ROWS := ["goals", "shots", "saves", "fouls", "yellow cards", "red cards", "offsides", "corners"]
const MOTM_POINTS := {"goals": 4.0, "shots": 1.0, "saves": 2.0}  # per player

var counts := {}  # Team -> {stat: int}
var possession := {}  # Team -> seconds the ball was theirs in open play
var points := {}  # Footballer -> Man of the Match points
var _m  # the Match


func _init(m) -> void:
	_m = m
	for t in [m.home, m.away]:
		counts[t] = {}
		for stat in ROWS:
			counts[t][stat] = 0
		possession[t] = 0.0
	m.event.connect(_on_event)


func _on_event(kind: String, team: Team) -> void:
	if not COUNTED.has(kind) or not _m.shootout.is_empty():  # shoot-out kicks don't count
		return
	var stat: String = COUNTED[kind]
	counts[team][stat] += 1
	var who: Footballer = _m.ball.holder if kind == "save" else _m.ball.last_touch
	if MOTM_POINTS.has(stat) and who and who.team == team:  # not an own goal
		points[who] = points.get(who, 0.0) + MOTM_POINTS[stat]


## Open play: the side on the ball (or that touched it last) has it.
func tick(delta: float) -> void:
	var p: Footballer = _m.ball.holder if _m.ball.holder else _m.ball.last_touch
	if p and possession.has(p.team):
		possession[p.team] += delta


## `t`'s share of possession, 0-100 (50 before anyone's had it).
func possession_percent(t: Team) -> int:
	var total: float = possession[_m.home] + possession[_m.away]
	return 50 if total <= 0.0 else roundi(100.0 * possession[t] / total)


## Most points; level, the winners' man; null if nobody scored a point.
func man_of_the_match() -> Footballer:
	var winner: Team = _m.match_winner()
	var best: Footballer = null
	for p in points:
		if best == null or points[p] > points[best] or (points[p] == points[best] and p.team == winner and best.team != winner):
			best = p
	return best
