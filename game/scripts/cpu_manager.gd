class_name CpuManager
extends RefCounted
## The CPU side's manager. It watches the match (where the ball is, how the human side attacks,
## which of their players hurts it) and at stoppages, CM3's way, now and then takes a look: how
## hard to go at it (score, men on the pitch, territory, strength, the clock), which formation
## (that style, and the human's wing or middle play), who to bring on (tired or out of place
## players), and who man-marks the human's danger man. Its decisions go up on the banner.
## The style sum follows CM3's computer manager (see the CM3 research notes); the numbers are ours.

const CHECK_GAP := 5.0  # match minutes at least between two looks
const THREAT := {"shot": 2.0, "goal": 4.0}  # a human player's danger points per event
const THREAT_ON_BALL := 0.4  # danger points per second on the ball in our third
const MARK_AT := 6.0  # danger points that earn a man-marker
const SCOUTED := 20.0  # seconds of the human attacking our half before their style counts
const WINGS := 0.65  # share of that time down the flanks: play wing-backs (5-3-2)
const MIDDLE := 0.5  # ... through the middle: pack it (4-5-1)
const SUBS_PER_LOOK := 2
const SUB_GAIN := 3.0  # how much better (rating x fit x freshness) a sub has to be

var team: Team
var style := "normal"  # attack, normal, defend or sit back
var decisions: Array[String] = []  # everything it did, for tests and the debug overlay
var thirds := [0.0, 0.0, 0.0]  # seconds of open play the ball spent in our third, the middle, theirs
var lanes := [0.0, 0.0, 0.0]  # seconds the human side had it in our half: top, middle, bottom of the screen
var threat := {}  # human Footballer -> danger points
var _m  # the Match
var _need := -1.0
var _last_look := -INF
var _start_formation := ""


func _init(match_game, t: Team) -> void:
	_m = match_game
	team = t
	_start_formation = t.formation
	_m.event.connect(_on_event)


func _on_event(kind: String, t: Team) -> void:
	if kind == "red card" and t == team:
		_last_look = -INF  # look again at the next stoppage
	if t == team or not THREAT.has(kind) or not _m.shootout.is_empty():
		return
	var who: Footballer = _m.ball.last_touch
	if who and who.team == t:
		threat[who] = threat.get(who, 0.0) + THREAT[kind]


## Open play, every frame.
func tick(delta: float) -> void:
	var field: Rect2 = Pitch.field_rect()
	var at: Vector2 = _m.ball.position / field.size
	var up := at.x if team.side > 0 else 1.0 - at.x  # 0 our goal line .. 1 theirs
	thirds[clampi(int(up * 3.0), 0, 2)] += delta
	var holder: Footballer = _m.ball.holder
	if holder and holder.team != team and up < 0.5:
		lanes[clampi(int(at.y * 3.0), 0, 2)] += delta
		if up < 1.0 / 3.0:
			threat[holder] = threat.get(holder, 0.0) + THREAT_ON_BALL * delta


func minute() -> float:
	return _m.clock / _m.half_seconds * 45.0


## Called at every stoppage, before the substitutions waiting for it are made: the lines for the
## banner (substitutions it asks for are announced with them).
func at_stoppage() -> Array:
	var now := minute()
	var keeper_off := team.players[0].sent_off
	if not keeper_off and (now - _last_look < CHECK_GAP or randi() % 50 + 10 >= now):
		return []
	_last_look = now
	var lines := []
	if keeper_off:
		_replace_keeper()
	_choose_style(now)
	var f := _formation()
	if f[0] != team.formation:
		_m.change_formation(team, f[0])
		_note(lines, "%s GO %s\n%s" % [team.short, f[0], f[1]])
	_pick_subs(now)
	_mark(lines)
	return lines


func _note(lines: Array, text: String) -> void:
	lines.append(text)
	decisions.append("%d' %s" % [int(minute()), text.replace("\n", " ")])


## CM3's attack need: strength and territory, weighed by how far the match has gone; the score,
## with a man down worth two goals; pushing on when behind, cooling off when ahead.
func _choose_style(now: float) -> void:
	var other: Team = _m.opponent(team)
	var strength := 1.0 + (_rating(team) - _rating(other)) / 20.0
	var r: float = (thirds[2] + 1.0) / (thirds[0] + 1.0)
	var territory := clampf(1.29 * r - 0.29 if r <= 1.0 else 2.0 * r - 1.0, 0.05, 6.0)
	var t := minf(20.0, now * 20.0 / 45.0)
	var need := (t * territory + (25.0 - t) * strength) * 0.04
	var lead := team.score - other.score + 2 * (_men(team) - _men(other))
	need *= maxf(0.1, 1.0 - 0.1 * lead)
	var home: bool = team == _m.home
	if lead > 0 or (lead == 0 and not home):
		need *= minf(1.0, 30.0 / maxf(now, 1.0))
	else:
		need *= maxf(1.0, now / 30.0)
	if lead <= -3:
		need *= maxf(0.05, 1.01 - 0.2 * (-lead - 2))  # it's gone
	if _need >= 0.0 and absf(need - _need) < 0.5:
		return  # not enough of a change to change anything
	_need = need
	if lead >= 2 and now >= 60.0:
		style = "sit back"
	elif need <= 0.5:
		style = "defend"
	elif need < 2.0:
		style = "normal"
	else:
		style = "attack"


## [formation, why] for the style and what it has seen of the human's attacking.
func _formation() -> Array:
	var seen: float = lanes[0] + lanes[1] + lanes[2]
	var wings: float = (lanes[0] + lanes[2]) / seen if seen >= SCOUTED else 0.0
	var middle: float = lanes[1] / seen if seen >= SCOUTED else 0.0
	match style:
		"attack":
			return ["4-3-3", "CHASING THE GAME"]
		"defend", "sit back":
			var why := "SHUTTING UP SHOP" if team.score > _m.opponent(team).score else "DIGGING IN"
			if wings >= WINGS:
				return ["5-3-2", why + ", WING-BACKS FOR YOUR WING PLAY"]
			return ["4-5-1", why]
	if wings >= WINGS:
		return ["5-3-2", "WING-BACKS TO STOP YOUR WING PLAY"]
	if middle >= MIDDLE:
		return ["4-5-1", "PACKING THE MIDDLE"]
	return [_start_formation, "BACK TO THEIR GAME PLAN"]


## Every slot against the best sub for it, CM3's way: rating x fit, the man on the pitch
## discounted for how tired he is, the bench held back before the hour; full-backs facing the
## human's danger man count double.
func _pick_subs(now: float) -> void:
	var slots: Array = Team.FORMATIONS[team.formation]
	var danger := _danger()
	var options := []
	for i in range(1, 11):
		var p: Footballer = team.players[i]
		if p.sent_off:
			continue
		var on_pitch := _value(p.entry, slots[i].pos) * (0.55 + 0.45 * p.condition)
		for e in team.bench:
			if e.position == "GK":
				continue
			var gain := _value(e, slots[i].pos) - maxf(0.0, 60.0 - now) * 0.8 - on_pitch
			if danger and slots[i].role == "D" and _same_flank(p, danger):
				gain *= 2.0
			options.append([gain, i, e])
	options.sort_custom(func(a, b): return a[0] > b[0])
	var made := 0
	for o in options:
		if made >= SUBS_PER_LOOK or o[0] < SUB_GAIN:
			break
		if _m.request_sub(team, o[1], o[2]):
			made += 1
			decisions.append("%d' sub %s for %s" % [int(now), o[2].name, team.players[o[1]].display_name])


## Keeper sent off: an outfield player makes way for the keeper on the bench.
func _replace_keeper() -> void:
	var keeper = null
	for e in team.bench:
		if e.position == "GK":
			keeper = e
	if keeper == null or team.subs_left - team.pending.size() <= 0:
		return
	var weakest := -1
	for i in range(1, 11):
		var p: Footballer = team.players[i]
		if not p.sent_off and (weakest < 0 or float(p.entry.get("overall", 0)) < float(team.players[weakest].entry.get("overall", 0))):
			weakest = i
	if weakest < 0:
		return
	_m.swap_slots(team, 0, weakest)  # he takes the keeper's slot, to go off from it
	_m.request_sub(team, 0, keeper)
	decisions.append("%d' keeper %s on" % [int(minute()), keeper.name])


## The human's most dangerous player gets the CPU's best defender on him.
func _mark(lines: Array) -> void:
	var danger := _danger()
	if danger == null:
		return
	var marker: Footballer = null
	var best := -INF
	for p in team.players:
		if p.sent_off or p.role == "G" or p.role == "F":
			continue
		if p.marking == danger:
			return  # already on him
		var score: float = p.stats.get("defensiveAwareness", 50) + p.stats.get("standingTackle", 50) \
			+ 0.5 * p.stats.get("sprintSpeed", 50) + (20.0 if p.role == "D" else 0.0)
		if score > best:
			best = score
			marker = p
	for p in team.players:
		p.marking = null
	marker.marking = danger
	_note(lines, "%s: %s MAN-MARKS %s" % [team.short, marker.display_name, danger.display_name])


## The human player with the most danger points, if he has enough and is still on.
func _danger() -> Footballer:
	var best: Footballer = null
	for p in threat:
		if p in p.team.players and not p.sent_off and threat[p] >= MARK_AT \
				and (best == null or threat[p] > threat[best]):
			best = p
	return best


func _same_flank(p: Footballer, danger: Footballer) -> bool:
	var mid := Pitch.field_rect().size.y / 2.0
	var his: Vector2 = danger.team.to_pitch(danger.home)
	return signf(team.to_pitch(p.home).y - mid) == signf(his.y - mid)


static func _value(entry: Dictionary, slot_pos: String) -> float:
	return float(entry.get("overall", 60)) * Lineup.fit(entry.get("position", ""), slot_pos)


static func _men(t: Team) -> int:
	return t.players.filter(func(p): return not p.sent_off).size()


## Mean overall of the side on the pitch.
static func _rating(t: Team) -> float:
	var on: Array = t.players.filter(func(p): return not p.sent_off)
	var sum := 0.0
	for p in on:
		sum += float(p.entry.get("overall", 67.5))
	return sum / maxf(1.0, on.size())
