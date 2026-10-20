class_name AI
extends RefCounted
## Decision-making for players not under human control. Sets `wish` (movement)
## and occasionally triggers a pass or shot. Kept deliberately simple: hold a
## formation spot that shifts with the ball, send the nearest player to the
## ball, run at goal with it, pass when pressed, shoot when in range.

const SHOOT_RANGE := 330.0
const PRESSURE := 45.0
const KEEPER_HOLD := 0.8


static func think(p: Footballer, m: Match, delta: float) -> void:
	p.think_timer = maxf(0.0, p.think_timer - delta)
	if p.role == "G":
		_keeper(p, m)
	elif p.has_ball():
		_with_ball(p, m)
	elif m.ball.holder == null or m.ball.holder.team != p.team:
		if m.chaser(p.team) == p:
			var lead := m.ball.position + m.ball.velocity * 0.25
			p.wish = (lead - p.position).normalized()
		else:
			_hold_position(p, m, false)
	else:
		_hold_position(p, m, true)


static func _hold_position(p: Footballer, m: Match, attacking: bool) -> void:
	var t := p.team
	var field := Pitch.field_rect()
	var fx := m.ball.position.x / field.size.x
	if t.side < 0:
		fx = 1.0 - fx
	var fy := m.ball.position.y / field.size.y
	var spot := p.home + Vector2((fx - 0.5) * 0.5 + (0.12 if attacking else -0.04), (fy - 0.5) * 0.3)
	spot.x = clampf(spot.x, 0.06, 0.94)
	var target := t.to_pitch(spot)
	p.wish = ((target - p.position) / 40.0).limit_length(1.0)


static func _with_ball(p: Footballer, m: Match) -> void:
	var goal := p.team.goal_attacked()
	var to_goal := goal - p.position
	if p.think_timer <= 0.0:
		p.think_timer = 0.25
		if to_goal.length() < SHOOT_RANGE:
			var spread := 40.0 + to_goal.length() * 0.25  # less accurate from further out
			var target := goal + Vector2(0, randf_range(-spread, spread))
			if not _try_super(p, m, target):
				p.shoot(target)
			return
		if m.nearest_opponent_distance(p) < PRESSURE and randf() < 0.6:
			var mate := best_pass(p, m, Vector2.ZERO)
			if mate:
				p.pass_to(mate)
				return
	# dribble at goal, drifting toward the middle
	var dir := to_goal.normalized()
	dir.y += (Pitch.field_rect().size.y / 2.0 - p.position.y) / 900.0
	p.wish = dir.normalized()


## Spend the bar when it's worth it: a full bar usually goes on a Thunder Strike.
static func _try_super(p: Footballer, m: Match, target: Vector2) -> bool:
	var e := p.team.energy
	if e >= Supers.cost("thunder") and randf() < 0.5:
		return m.try_super(p, "thunder", target)
	if e >= Supers.cost("fireball") and randf() < 0.4:
		return m.try_super(p, ["fireball", "banana"][randi() % 2], target)
	return false


static func _keeper(p: Footballer, m: Match) -> void:
	var goal := p.team.goal_defended()
	if p.has_ball():
		p.wish = Vector2.ZERO
		if p.think_timer <= 0.0:
			p.think_timer = KEEPER_HOLD
		elif p.think_timer < 0.05:
			var mate := best_pass(p, m, Vector2.ZERO)
			if mate:
				p.pass_to(mate)
		return
	var b := m.ball.position
	if not p.busy() and m.ball.holder == null:
		var dive := dive_for_shot(p, m)
		if dive != Vector2.ZERO:
			p.dive(dive, m.ball.z > 20.0 or m.ball.vz > 60.0)
			return
	var target := Vector2(goal.x + p.team.side * 18.0, clampf(b.y, goal.y - 55.0, goal.y + 55.0))
	# come out for loose balls near the goal
	if m.ball.holder == null and b.distance_to(goal) < 160.0:
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


## Best teammate to pass to. With a non-zero `aim`, only mates within 60 degrees
## of it count (used for the human pass button).
static func best_pass(p: Footballer, m: Match, aim: Vector2) -> Footballer:
	var goal := p.team.goal_attacked()
	var best: Footballer = null
	var best_score := -INF
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
		if score > best_score:
			best_score = score
			best = mate
	return best
