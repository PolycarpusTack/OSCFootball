class_name AI
extends RefCounted
## Decision-making for players not under human control. Sets `wish` (movement)
## and occasionally triggers a pass or shot. Off the ball: hold a formation spot
## that shifts with the ball, send the nearest player to the ball. On it: weigh
## shooting (within his own range), passing, crossing, dribbling and a skill move,
## CM3-style, and take the best, more surely the better his decisions. Forwards
## attack the near and far post when a teammate can cross.

const RANGE_M := [16.0, 28.0]  # how far out he'll shoot, metres: longShots 40 .. 95
const NOISE := [45.0, 6.0]  # the doubt added to each option's worth: poor .. great decisions
const PRESSURE := 45.0
const KEEPER_HOLD := 0.8
const COVER_M := 2.0  # how far goal-side of the man on the ball the covering defender stands
const COVER_FROM_M := 22.0  # how close a defender has to be to step up and cover
## How far a player's spot follows the ball, by role, [without the ball, with it]: x along the
## pitch, y across, per unit of the ball's pitch fraction. Defenders follow it up and down least
## (the back line stays together) and the whole side slides across more without the ball.
const PULL := {
	"G": [Vector2(0.5, 0.3), Vector2(0.5, 0.3)],
	"D": [Vector2(0.35, 0.40), Vector2(0.45, 0.20)],
	"M": [Vector2(0.45, 0.40), Vector2(0.50, 0.25)],
	"F": [Vector2(0.50, 0.30), Vector2(0.50, 0.20)],
}


static var _pressers := {}  # Team -> [physics frame, presser]: worked out once a frame
static var _receivers := {}  # Team -> [physics frame, receiver]


static func think(p: Footballer, m: Match, delta: float) -> void:
	if p.sent_off:
		return
	p.think_timer = maxf(0.0, p.think_timer - delta)
	if p.role == "G":
		_keeper(p, m)
	elif p.has_ball():
		_with_ball(p, m)
	elif not in_possession(p.team, m):
		if presser(p.team, m) == p:
			p.ai_state = "chase"
			p.wish = ((chase_spot(m) - p.position) / 10.0).limit_length(1.0)
			_maybe_body_check(p, m)
			_maybe_slide(p, m)
		elif cover(p.team, m) == p:
			p.ai_state = "cover"
			var h := m.ball.holder
			var goal_side := h.position + (p.team.goal_defended() - h.position).normalized() * Pitch.m(COVER_M)
			p.wish = ((goal_side - p.position) / 15.0).limit_length(1.0)
		elif _marking(p, m):
			p.ai_state = "mark"
			var mark := p.marking.position
			var goal_side := mark + (p.team.goal_defended() - mark).normalized() * Pitch.m(1.5)
			p.wish = ((goal_side - p.position) / 20.0).limit_length(1.0)
		else:
			p.ai_state = "defend"
			_hold_position(p, m, false)
	elif m.ball.holder == null and receiver(p.team, m) == p:  # our pass on its way: go and meet it
		p.ai_state = "receive"
		p.wish = ((chase_spot(m) - p.position) / 10.0).limit_length(1.0)
	else:
		var run := _box_run(p, m)
		if run != Vector2.INF:
			p.ai_state = "box run"
			p.wish = ((_onside(p, m, run) - p.position) / 30.0).limit_length(1.0)
		else:
			p.ai_state = "support"
			_hold_position(p, m, true)


## Is `t` the side on the ball (CM3's phase): one of its players has it, or its own pass or
## cross is on the way.
static func in_possession(t: Team, m: Match) -> bool:
	var b := m.ball
	if b.holder:
		return b.holder.team == t
	return b.last_touch != null and b.last_touch.team == t and b.kick_kind in ["pass", "cross"]


## Who goes for the ball (the AI's; the human's switching uses Match.chaser): the nearest,
## counting each line's distance more where the ball is out of its zone, so forwards don't
## chase back into their own half and defenders don't leave the back line for the far end.
static func presser(t: Team, m: Match) -> Footballer:
	var frame := Engine.get_physics_frames()
	if _pressers.get(t, [-1])[0] == frame:
		return _pressers[t][1]
	var at := m.ball_target()
	var up := _up(t, at)
	var best: Footballer = null
	var best_cost := INF
	for p in t.players:
		if p.role == "G" or p.sent_off:
			continue
		var cost := p.position.distance_to(at) * _zone_cost(p.role, up)
		if cost < best_cost:
			best = p
			best_cost = cost
	_pressers[t] = [frame, best]
	return best


## Who goes to meet our pass on its way: the teammate nearest where it's going, not the man
## who played it.
static func receiver(t: Team, m: Match) -> Footballer:
	var frame := Engine.get_physics_frames()
	if _receivers.get(t, [-1])[0] == frame:
		return _receivers[t][1]
	var at := m.ball_target()
	var best: Footballer = null
	for p in t.players:
		if p.role != "G" and not p.sent_off and p != m.ball.last_touch \
				and (best == null or p.position.distance_squared_to(at) < best.position.distance_squared_to(at)):
			best = p
	_receivers[t] = [frame, best]
	return best


## The second man in (CM3's challengers): with an opponent on the ball in our half, the
## defender nearest him, if he's close enough, steps up goal-side of him.
static func cover(t: Team, m: Match) -> Footballer:
	var h := m.ball.holder
	if h == null or h.team == t or _up(t, h.position) > 0.5:
		return null
	var first := presser(t, m)
	var best: Footballer = null
	for p in t.players:
		if p.role == "D" and p != first and not p.sent_off and p.position.distance_to(h.position) < Pitch.m(COVER_FROM_M) \
				and (best == null or p.position.distance_to(h.position) < best.position.distance_to(h.position)):
			best = p
	return best


## How far up the pitch `at` is for `t`: 0 its own goal line .. 1 the other.
static func _up(t: Team, at: Vector2) -> float:
	var fx := at.x / Pitch.field_rect().size.x
	return fx if t.side > 0 else 1.0 - fx


## How much a line's distance to the ball counts when the ball is `up` the pitch (see presser).
static func _zone_cost(role: String, up: float) -> float:
	match role:
		"F":
			return 1.0 if up > 0.5 else 1.0 + (0.5 - up) * 4.0  # 3.0 at our goal line
		"D":
			return 1.0 if up < 0.4 else 1.0 + (up - 0.4) * 3.5  # 3.1 at theirs
		"M":
			return 1.0 if up > 0.3 else 1.0 + (0.3 - up) * 2.0  # 1.6 at our goal line: the back line's ball
	return 1.0


## Where a chaser runs to get to the ball: a little ahead of it, or where it comes down.
static func chase_spot(m: Match) -> Vector2:
	if m.ball.z > 12.0 or m.ball.vz > 0.0:  # in the air: where it comes down
		return m.ball_target()
	return m.ball.position + m.ball.velocity * 0.25


## Man-marking someone who is in our half?
static func _marking(p: Footballer, m: Match) -> bool:
	var mark := p.marking
	if mark == null or mark.sent_off or not mark in mark.team.players:
		return false
	return mark.position.distance_to(p.team.goal_defended()) < Pitch.field_rect().size.x / 2.0


## Where `p` runs to meet a cross from a teammate out wide in the opponents' half: the forwards to the near
## and far post, the far-side winger to the penalty spot. INF when he doesn't.
static func _box_run(p: Footballer, m: Match) -> Vector2:
	var crosser := m.ball.holder
	if not m.wide_within(crosser, Pitch.LENGTH_M / 2.0):  # a winger with it in their half: get into the box early
		return Vector2.INF
	var goal := p.team.goal_attacked()
	var near := signf(crosser.position.y - goal.y)  # the side the cross comes from
	var i := p.team.players.find(p)
	if i == 9:
		return goal + Vector2(-p.team.side * Pitch.m(7.0), near * Pitch.m(2.5))
	if i == 10:
		return goal + Vector2(-p.team.side * Pitch.m(9.0), -near * Pitch.m(3.0))
	if _winger(p) and signf(p.position.y - goal.y) != near:
		return goal + Vector2(-p.team.side * Pitch.m(11.0), -near * Pitch.m(1.0))
	return Vector2.INF


## `target` pulled back level with the offside line (half a metre short of it), so an
## attacker waiting for the ball doesn't stand offside.
static func _onside(p: Footballer, m: Match, target: Vector2) -> Vector2:
	if not Match.offside_on:
		return target
	var goal_x := p.team.goal_attacked().x
	var depth := m.onside_depth(p.team) - Pitch.m(0.5)
	if absf(goal_x - target.x) < depth:
		target.x = goal_x + p.team.side * -depth
	return target


## A wide midfielder or forward (4-4-2: the right and left midfielders; 4-3-3: the wingers).
static func _winger(p: Footballer) -> bool:
	return p.role in ["M", "F"] and absf(p.home.y - 0.5) > 0.3


## Chaos: a chaser stronger than the dribbler, close and facing him, sometimes barges him.
static func _maybe_body_check(p: Footballer, m: Match) -> void:
	var h := m.ball.holder
	if h == null or h.team == p.team or p.position.distance_to(h.position) > 45.0:
		return
	if p.skill("strength", 0.0, 1.0) > h.skill("strength", 0.0, 1.0) and randf() < 0.02:
		p.facing = Anims.facing_from(h.position - p.position)
		m.body_check(p)


## A chaser right on the dribbler sometimes goes to ground: the more aggressive, the more
## often (from behind it's a foul).
static func _maybe_slide(p: Footballer, m: Match) -> void:
	var h := m.ball.holder
	if h == null or h.team == p.team or p.busy() or p.position.distance_to(h.position) > 40.0:
		return
	if randf() < p.skill("aggression", 0.002, 0.012):
		p.facing = Anims.facing_from(m.ball.position - p.position)
		p.slide()


static func _hold_position(p: Footballer, m: Match, attacking: bool) -> void:
	p.wish = ((hold_spot(p, m, attacking) - p.position) / 40.0).limit_length(1.0)


## Where `p` stands off the ball (pixels): his formation spot for the phase, shifted with the ball.
static func hold_spot(p: Footballer, m: Match, attacking: bool) -> Vector2:
	var t := p.team
	var field := Pitch.field_rect()
	var fx := m.ball.position.x / field.size.x
	var fy := m.ball.position.y / field.size.y
	if t.side < 0:
		fx = 1.0 - fx
	else:
		fy = 1.0 - fy
	var base := p.attack_spot if attacking else p.defend_spot
	var pull: Vector2 = PULL[p.role][1 if attacking else 0]
	var spot := base + Vector2((fx - 0.5) * pull.x, (fy - 0.5) * pull.y)
	spot.x = clampf(spot.x, 0.06, 0.94)
	var target := t.to_pitch(spot)
	if attacking:
		target = _onside(p, m, target)
	return target


## On the ball, CM3's way: every so often (quicker with better reactions) he weighs his
## options (shoot, pass, cross, dribble, a skill move), each worth so much, plus a random
## doubt that shrinks the better his decisions (vision, composure, reactions), and takes the
## best. In between he dribbles at goal.
static func _with_ball(p: Footballer, m: Match) -> void:
	if p.think_timer <= 0.0:
		p.think_timer = p.skill("reactions", 0.35, 0.15)
		var choice := choose(p, m)
		match choice[0]:
			"shoot":
				p.ai_state = "shoot"
				var goal := p.team.goal_attacked()
				var spread := 15.0 + goal.distance_to(p.position) * 0.18  # less accurate from further out; finishing adds its own miss
				var target := goal + Vector2(0, randf_range(-spread, spread))
				if not _try_super(p, m, target):
					p.shoot(target)
				return
			"pass":
				p.ai_state = "pass"
				p.pass_to(choice[1])
				return
			"cross":
				p.ai_state = "cross"
				p.cross_to(choice[1])
				return
			"skill move":
				if m.skill_move(p, "nutmeg" if randf() < 0.5 else "rainbow"):
					p.ai_state = "skill move"
					return
	_dribble(p)


## [the option he takes, its target or null]: the best of options() after each is given
## its doubt.
static func choose(p: Footballer, m: Match) -> Array:
	var doubt := lerpf(NOISE[0], NOISE[1], decisions(p))
	var best := ["dribble", null]
	var best_value := -INF
	for o in options(p, m):
		var v: float = o[1] + randf() * doubt
		if v > best_value:
			best_value = v
			best = [o[0], o[2]]
	return best


## How good his decisions are, 0..1: vision, composure and reactions.
static func decisions(p: Footballer) -> float:
	return (p.skill("vision", 0.0, 1.0) + p.skill("composure", 0.0, 1.0) + p.skill("reactions", 0.0, 1.0)) / 3.0


## How far out he'll shoot (pixels): longShots decides.
static func shooting_range(p: Footballer) -> float:
	return Pitch.m(p.skill("longShots", RANGE_M[0], RANGE_M[1]))


## [option, worth, target] for everything `p` could do with the ball now.
static func options(p: Footballer, m: Match) -> Array:
	var out := []
	var goal := p.team.goal_attacked()
	var d := p.position.distance_to(goal)
	var pressed := m.nearest_opponent_distance(p) < PRESSURE
	var reach := shooting_range(p)
	if d <= reach:
		var q := 1.0 - (d / reach) * (d / reach)
		var stat := p.skill("finishing" if d < Pitch.m(16.0) else "longShots", 0.7, 1.1)
		var worth := 100.0 * q * stat + (20.0 if d < Pitch.m(11.0) else 0.0) - 25.0 * _blockers(p, goal, m)
		out.append(["shoot", worth, null])
	var passing := pass_option(p, m, Vector2.ZERO)
	if passing[0]:
		out.append(["pass", clampf(passing[1] * 0.3, -40.0, 90.0) + (20.0 if pressed else 0.0), passing[0]])
	if m.wide_in_final_third(p):
		var target := _cross_target(p, m)
		if target:
			out.append(["cross", 55.0 + minf(m.nearest_opponent_distance(target), 120.0) / 6.0, target])
	var space := minf(m.nearest_opponent_distance(p), 150.0)
	var dribble := 20.0 + space / 5.0 - (25.0 if pressed else 0.0)
	if _winger(p) and m.wide_within(p, Pitch.LENGTH_M / 2.0):
		dribble += 15.0  # down the line, to cross
	out.append(["dribble", dribble, null])
	var o := m.opponent_ahead(p)
	if o and o.position.distance_to(p.position) < Pitch.m(3.0):
		out.append(["skill move", 50.0 * p.skill("dribbling", 0.0, 1.0) - 5.0, null])
	return out


## Opponents (not the keeper) standing in the way of a shot from `p` at `target`.
static func _blockers(p: Footballer, target: Vector2, m: Match) -> int:
	var line := target - p.position
	var n := 0
	for o in m.opponent(p.team).players:
		if o.role == "G" or o.sent_off:
			continue
		var along := clampf((o.position - p.position).dot(line) / line.length_squared(), 0.0, 1.0)
		if along > 0.05 and along < 0.95 and o.position.distance_to(p.position + line * along) < 18.0:
			n += 1
	return n


## Dribble at goal, drifting toward the middle; a winger out wide goes down the line to cross.
static func _dribble(p: Footballer) -> void:
	p.ai_state = "dribble"
	var goal := p.team.goal_attacked()
	var dir := (goal - p.position).normalized()
	dir.y += (Pitch.field_rect().size.y / 2.0 - p.position.y) / 900.0
	if _winger(p) and absf(p.position.y - goal.y) > Match.BOX_HALF_WIDTH * 0.7:
		dir = Vector2(p.team.side, 0.0)
	p.wish = dir.normalized()


## The teammate in the box with the most room, for a cross; null if nobody's there.
static func _cross_target(p: Footballer, m: Match) -> Footballer:
	var best: Footballer = null
	for mate in p.team.players:
		if mate != p and m.is_cross(p, mate) and (best == null
				or m.nearest_opponent_distance(mate) > m.nearest_opponent_distance(best)):
			best = mate
	return best


## Spend the bar when it's worth it: a full bar usually goes on a Thunder Strike.
static func _try_super(p: Footballer, m: Match, target: Vector2) -> bool:
	var e := p.team.energy
	var kind := ""
	if e >= Supers.cost("thunder") and randf() < 0.5:
		kind = "thunder"
	elif e >= Supers.cost("fireball") and randf() < 0.4:
		kind = "fireball" if p.role == "F" and randf() < 0.5 else "banana"  # ↓↘→ is a Fireball for strikers only
	if kind == "" or not m.try_super(p, kind, target):
		return false
	p.ai_state = kind
	return true


static func _keeper(p: Footballer, m: Match) -> void:
	var goal := p.team.goal_defended()
	if p.has_ball():
		p.ai_state = "keeper: hold"
		p.wish = Vector2.ZERO
		if p.think_timer <= 0.0:
			p.think_timer = KEEPER_HOLD
		elif not m.keeper_may_release(p):
			p.think_timer = maxf(p.think_timer, 0.2)  # wait for opponents to clear the box
		elif p.think_timer < 0.05:
			var mate := best_pass(p, m, Vector2.ZERO)
			if mate:
				p.pass_to(mate)
		return
	var b := m.ball.position
	if not p.busy() and m.ball.holder == null:
		var dive := dive_for_shot(p, m)
		if dive != Vector2.ZERO:
			p.ai_state = "keeper: dive"
			p.dive(dive, m.ball.z > 20.0 or m.ball.vz > 60.0)
			return
	p.ai_state = "keeper: guard"
	var target := Vector2(goal.x + p.team.side * 18.0, clampf(b.y, goal.y - 55.0, goal.y + 55.0))
	# come out for loose balls near the goal
	if m.ball.holder == null and b.distance_to(goal) < 160.0:
		p.ai_state = "keeper: come out"
		target = b
	p.wish = ((target - p.position) / 20.0).limit_length(1.0)


## Direction to dive for a shot heading for goal, or ZERO when no dive is needed.
static func dive_for_shot(p: Footballer, m: Match) -> Vector2:
	var b := m.ball
	var toward_goal := -p.team.side  # x direction a shot on this keeper's goal travels
	if signf(b.velocity.x) != toward_goal or absf(b.velocity.x) < 150.0:
		return Vector2.ZERO
	var t := (p.position.x - b.position.x) / b.velocity.x
	if t < 0.0 or t > 0.55:
		return Vector2.ZERO
	var miss := b.position.y + b.velocity.y * t - p.position.y
	if absf(miss) < 14.0 or absf(miss) > Match.GOAL_HALF_WIDTH + 30.0:
		return Vector2.ZERO
	return Vector2(0.0, signf(miss))


## An opponent standing in the line of a pass from `p` to `mate`?
static func _lane_blocked(p: Footballer, mate: Footballer, m: Match) -> bool:
	var line := mate.position - p.position
	for o in m.opponent(p.team).players:
		var along := clampf((o.position - p.position).dot(line) / line.length_squared(), 0.0, 1.0)
		if along > 0.0 and along < 0.95 and o.position.distance_to(p.position + line * along) < 22.0:
			return true
	return false


## Best teammate to pass to. With a non-zero `aim`, only mates within 60 degrees
## of it count (used for the human pass button).
static func best_pass(p: Footballer, m: Match, aim: Vector2) -> Footballer:
	return pass_option(p, m, aim)[0]


## [best teammate to pass to or null, his score] (see best_pass).
static func pass_option(p: Footballer, m: Match, aim: Vector2) -> Array:
	var goal := p.team.goal_attacked()
	var best: Footballer = null
	var best_score := -INF
	var offside: Array = m.offside_players(p) if Match.offside_on else []
	for mate in p.team.players:
		if mate == p or mate.role == "G":
			continue
		var offset := mate.position - p.position
		var dist := offset.length()
		if dist < 50.0 or dist > 480.0:
			continue
		if aim != Vector2.ZERO and absf(aim.angle_to(offset)) > PI / 3.0:
			continue
		var progress := p.position.distance_to(goal) - mate.position.distance_to(goal)
		var space := minf(m.nearest_opponent_distance(mate), 120.0)
		var score := progress * 0.6 + space - dist * 0.15
		if _winger(mate) and m.wide_within(mate, Pitch.LENGTH_M / 2.0) and not _winger(p):
			score += 60.0  # get it out wide: a winger in their half can go down the line and cross
		if _lane_blocked(p, mate, m):
			score -= 250.0
		if mate in offside:
			score -= 400.0  # he'd be flagged
		if score > best_score:
			best_score = score
			best = mate
	return [best, best_score]
