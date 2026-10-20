class_name AI
extends RefCounted
## Decision-making for players not under human control. Sets `wish` (movement)
## and occasionally triggers a pass or shot. Kept deliberately simple: hold a
## formation spot that shifts with the ball, send the nearest player to the
## ball, run at goal with it, pass when pressed, cross from out wide, shoot when
## in range. Forwards attack the near and far post when a teammate can cross.

const SHOOT_RANGE := 330.0
const PRESSURE := 45.0
const KEEPER_HOLD := 0.8
const THROUGH_SPACE := 108.0  # px (6 m) ahead of a runner a through ball is played
const LANE_WATCH := 150.0  # px: an opponent this close to a defender's spot is his to cut off
const SWERVE_SEE := 90.0  # px: an opponent this close in a dribbler's way is gone around
## How far a player's spot follows the ball, by role, [without the ball, with it]: x along the
## pitch, y across, per unit of the ball's pitch fraction. Defenders follow it up and down least
## (the back line stays together) and the whole side slides across more without the ball.
const PULL := {
	"G": [Vector2(0.5, 0.3), Vector2(0.5, 0.3)],
	"D": [Vector2(0.35, 0.40), Vector2(0.45, 0.20)],
	"M": [Vector2(0.45, 0.40), Vector2(0.50, 0.25)],
	"F": [Vector2(0.50, 0.30), Vector2(0.50, 0.20)],
}


static func think(p: Footballer, m: Match, delta: float) -> void:
	if p.sent_off:
		return
	p.think_timer = maxf(0.0, p.think_timer - delta)
	if p.role == "G":
		_keeper(p, m)
	elif p.has_ball():
		_with_ball(p, m)
	elif m.ball.holder == null or m.ball.holder.team != p.team:
		if m.chaser(p.team) == p:
			p.ai_state = "chase"
			p.wish = ((chase_spot(m) - p.position) / 10.0).limit_length(1.0)
			_maybe_body_check(p, m)
			_maybe_slide(p, m)
		elif _marking(p, m):
			p.ai_state = "mark"
			p.wish = ((mark_spot(p) - p.position) / 20.0).limit_length(1.0)
		else:
			p.ai_state = "defend"
			p.wish = ((defend_spot(p, m) - p.position) / 40.0).limit_length(1.0)
	else:
		var run := _box_run(p, m)
		if run != Vector2.INF:
			p.ai_state = "box run"
			p.wish = ((_onside(p, m, run) - p.position) / 30.0).limit_length(1.0)
		else:
			p.ai_state = "support"
			_hold_position(p, m, true)


## Where a chaser runs to get to the ball: a little ahead of it, or where it comes down.
static func chase_spot(m: Match) -> Vector2:
	if m.ball.z > 12.0 or m.ball.vz > 0.0:  # in the air: where it comes down
		return m.ball_target()
	return m.ball.position + m.ball.velocity * 0.25


## Goal-side of the man `p` marks. defensiveAwareness: how tight (2.5 m off him, 0.5 m at
## 95) and how he reads the run (behind it, where the man was 0.3 s ago, up to where he'll
## be in 0.3 s).
static func mark_spot(p: Footballer) -> Vector2:
	var mark := p.marking.position + p.marking.velocity * p.skill("defensiveAwareness", -0.3, 0.3)
	return mark + (p.team.goal_defended() - mark).normalized() * Pitch.m(p.skill("defensiveAwareness", 2.5, 0.5))


## Where `p` defends off the ball: his spot, stepped toward the line of a pass from the man on
## the ball to the opponent nearest that spot (within LANE_WATCH). interceptions: how far,
## not at all (40) to half way (95), never more than 4 m off his spot.
static func defend_spot(p: Footballer, m: Match) -> Vector2:
	var spot := hold_spot(p, m, false)
	var h := m.ball.holder
	var step := p.skill("interceptions", 0.0, 0.5)
	if h == null or h.team == p.team or step <= 0.0:
		return spot
	var target: Footballer = null
	for o in h.team.players:
		if o != h and not o.sent_off and o.position.distance_to(spot) < LANE_WATCH \
				and (target == null or o.position.distance_to(spot) < target.position.distance_to(spot)):
			target = o
	if target == null:
		return spot
	var line := target.position - h.position
	var along := clampf((spot - h.position).dot(line) / line.length_squared(), 0.2, 0.8)
	return spot + ((h.position + line * along - spot) * step).limit_length(Pitch.m(4.0))


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


## `target` pulled back level with the offside line, so an attacker waiting for the ball
## doesn't stand offside: positioning decides how tight to it (0.9 m short, 0.1 m at 95).
static func _onside(p: Footballer, m: Match, target: Vector2) -> Vector2:
	if not Match.offside_on:
		return target
	var goal_x := p.team.goal_attacked().x
	var depth := m.onside_depth(p.team) + Pitch.m(p.skill("positioning", 0.9, 0.1))
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


static func _with_ball(p: Footballer, m: Match) -> void:
	var goal := p.team.goal_attacked()
	var to_goal := goal - p.position
	if p.think_timer <= 0.0:
		p.think_timer = p.skill("reactions", 0.35, 0.15)
		if m.wide_in_final_third(p) and randf() < 0.5:
			var target := _cross_target(p, m)
			if target:
				p.ai_state = "cross"
				p.cross_to(target)
				return
		if not _winger(p) and to_goal.length() > SHOOT_RANGE and randf() < p.skill("vision", 0.03, 0.13):
			var wide := _free_winger(p, m)
			if wide:
				p.ai_state = "pass wide"
				p.pass_to(wide)
				return
		if to_goal.length() < shoot_range(p):
			var target := _shot_target(p, m)
			p.ai_state = "shoot"
			if not _try_super(p, m, target):
				p.shoot(target)
			return
		var runner := through_ball(p, m)
		if runner and randf() < p.skill("vision", 0.0, 0.3):
			p.ai_state = "through ball"
			p.pass_to(runner, THROUGH_SPACE)
			return
		var stars := int(p.entry.get("skill_moves", 3))
		if m.opponent_ahead(p) and randf() < p.skill("dribbling", 0.05, 0.3) * stars / 3.0 \
				and m.skill_move(p, "rainbow" if stars >= Match.SKILL_STARS.rainbow and randf() < 0.5 else "nutmeg"):
			p.ai_state = "skill move"
			return
		var down_the_line := _winger(p) and m.wide_within(p, Pitch.LENGTH_M / 2.0)
		if m.nearest_opponent_distance(p) < PRESSURE and randf() < (0.3 if down_the_line else 0.6):
			var mate := best_pass(p, m, Vector2.ZERO)
			if mate:
				p.ai_state = "pass"
				p.pass_to(mate)
				return
	# dribble at goal, drifting toward the middle; a winger out wide goes down the line to cross
	p.ai_state = "dribble"
	var dir := to_goal.normalized()
	dir.y += (Pitch.field_rect().size.y / 2.0 - p.position.y) / 900.0
	if _winger(p) and absf(p.position.y - goal.y) > Match.BOX_HALF_WIDTH * 0.7:
		dir = Vector2(p.team.side, 0.0)
	p.wish = swerve(p, m, dir)


## `dir` bent away from the nearest opponent in the way (within SWERVE_SEE, 50 degrees
## either side): dribbling decides how far, 0.2 rad (40) to 0.9 (95), more the closer he is.
static func swerve(p: Footballer, m: Match, dir: Vector2) -> Vector2:
	dir = dir.normalized()
	var block: Footballer = null
	for o in m.opponent(p.team).players:
		var off := o.position - p.position
		if off.length() < SWERVE_SEE and off.normalized().dot(dir) > 0.64 \
				and (block == null or off.length() < block.position.distance_to(p.position)):
			block = o
	if block == null:
		return dir
	var off := block.position - p.position
	var away := -signf(dir.cross(off)) if dir.cross(off) != 0.0 else 1.0
	var closeness := 1.0 - off.length() / SWERVE_SEE
	return dir.rotated(away * p.skill("dribbling", 0.2, 0.9) * (0.5 + 0.5 * closeness))


## How far out `p` shoots from: SHOOT_RANGE (18 m), up to 25 m for a curler (curve 95).
static func shoot_range(p: Footballer) -> float:
	return maxf(SHOOT_RANGE, SHOOT_RANGE + p.skill("curve", -120.0, 120.0))


## Where `p` aims: around the middle, wider from further out (finishing adds its own miss).
## From beyond 20 m a curler goes for the corner the keeper is furthest from (curve 40
## never, 95 always).
static func _shot_target(p: Footballer, m: Match) -> Vector2:
	var goal := p.team.goal_attacked()
	var dist := p.position.distance_to(goal)
	if dist > Pitch.m(20.0) and randf() < p.skill("curve", 0.0, 1.0):
		var k := m.opponent(p.team).keeper()
		var away := -signf(k.position.y - goal.y) if k and k.position.y != goal.y else (1.0 if randf() < 0.5 else -1.0)
		return goal + Vector2(0, away * Match.GOAL_HALF_WIDTH * 0.75)
	var spread := 15.0 + dist * 0.18
	return goal + Vector2(0, randf_range(-spread, spread))


## A forward or winger ahead of `p`, onside, in sight, with a clear lane and room in front
## of him toward goal to run onto a ball played there (pass_to with THROUGH_SPACE); null if none.
static func through_ball(p: Footballer, m: Match) -> Footballer:
	var goal := p.team.goal_attacked()
	var offside: Array = m.offside_players(p) if Match.offside_on else []
	var sight := p.skill("vision", 400.0, 560.0)
	for mate in p.team.players:
		if mate == p or not (mate.role == "F" or _winger(mate)) or mate in offside or mate.sent_off:
			continue
		var dist := p.position.distance_to(mate.position)
		if dist > sight or p.position.distance_to(goal) - mate.position.distance_to(goal) < Pitch.m(5.0):
			continue
		var space := mate.position + (goal - mate.position).normalized() * THROUGH_SPACE
		var crowded := false
		for o in m.opponent(p.team).players:
			crowded = crowded or o.position.distance_to(space) < 90.0
		if not crowded and not _lane_blocked(p, mate, m):
			return mate
	return null


## A winger of `p`'s team in the opponents' half with room and a clear lane; null if none.
static func _free_winger(p: Footballer, m: Match) -> Footballer:
	for mate in p.team.players:
		if mate != p and _winger(mate) and m.wide_within(mate, Pitch.LENGTH_M / 2.0) \
				and m.nearest_opponent_distance(mate) > 70.0 and not _lane_blocked(p, mate, m):
			return mate
	return null


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
		kind = ["fireball", "banana"][randi() % 2]
	if kind == "" or not m.try_super(p, kind, target):
		return false
	p.ai_state = kind
	return true


static func _keeper(p: Footballer, m: Match) -> void:
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
	if not p.busy() and m.ball.holder == null:
		var dive := dive_for_shot(p, m)
		if dive != Vector2.ZERO:
			p.ai_state = "keeper: dive"
			p.dive(dive, m.ball.z > 20.0 or m.ball.vz > 60.0)
			return
	p.ai_state = "keeper: guard"
	var target := keeper_spot(p, m)
	if target == m.ball.position:
		p.ai_state = "keeper: come out"
	p.wish = ((target - p.position) / 20.0).limit_length(1.0)


## Where keeper `p` goes without the ball: off his line (gkPositioning: 8 px, cutting the
## angle down to 28 px), across with the ball, and out to a loose ball near goal (within
## 120 px, a good one 200 px).
static func keeper_spot(p: Footballer, m: Match) -> Vector2:
	var goal := p.team.goal_defended()
	var b := m.ball.position
	if m.ball.holder == null and b.distance_to(goal) < p.skill("gkPositioning", 120.0, 200.0):
		return b
	return Vector2(goal.x + p.team.side * p.skill("gkPositioning", 8.0, 28.0), clampf(b.y, goal.y - 55.0, goal.y + 55.0))


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
		if along > 0.1 and along < 0.95 and o.position.distance_to(p.position + line * along) < 22.0:
			return true
	return false


## Best teammate to pass to. With a non-zero `aim`, only mates within 45-75 degrees
## of it count (used for the human pass button). The passer's vision: how far he sees
## (400-560 px), how wide around his aim and how surely he spots a pass that's cut off.
static func best_pass(p: Footballer, m: Match, aim: Vector2) -> Footballer:
	var goal := p.team.goal_attacked()
	var best: Footballer = null
	var best_score := -INF
	var offside: Array = m.offside_players(p) if Match.offside_on else []
	var sight := p.skill("vision", 400.0, 560.0)
	for mate in p.team.players:
		if mate == p or mate.role == "G":
			continue
		var offset := mate.position - p.position
		var dist := offset.length()
		if dist < 50.0 or dist > sight:
			continue
		if aim != Vector2.ZERO and absf(aim.angle_to(offset)) > p.skill("vision", PI / 4.0, PI * 5.0 / 12.0):
			continue
		var progress := p.position.distance_to(goal) - mate.position.distance_to(goal)
		var space := minf(m.nearest_opponent_distance(mate), 120.0)
		var score := progress * 0.6 + space - dist * 0.15
		if _winger(mate) and m.wide_within(mate, Pitch.LENGTH_M / 2.0) and not _winger(p):
			score += 60.0  # get it out wide: a winger in their half can go down the line and cross
		if _lane_blocked(p, mate, m):
			score -= p.skill("vision", 150.0, 350.0)
		if mate in offside:
			score -= 400.0  # he'd be flagged
		if score > best_score:
			best_score = score
			best = mate
	return best
