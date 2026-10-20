class_name ChaosActions
extends Node2D
## Explicit wind-up / active / recovery windows. Only Match calls tick(), before possession.
## All distances are pitch pixels; ball contacts still pass through normal match rules.

const MOVES := {
	"ghost": {"name": "GHOST STEP", "cost": 20, "wind": 0.12, "active": 0.22, "recovery": 0.25, "anim": "nutmeg", "hint": "carry the ball"},
	"magnet": {"name": "MAGNET SOLE", "cost": 25, "wind": 0.18, "active": 0.35, "recovery": 0.2, "anim": "mark", "hint": "near a slow loose ball"},
	"pinball": {"name": "PINBALL PASS", "cost": 40, "wind": 0.22, "active": 0.1, "recovery": 0.3, "anim": "kick", "hint": "carry the ball; aim pass"},
	"stego": {"name": "STEGO SWEEP", "cost": 30, "wind": 0.25, "active": 0.12, "recovery": 0.4, "anim": "tackle", "hint": "face a nearby carrier"},
	"bass": {"name": "BASS DROP", "cost": 50, "wind": 0.45, "active": 0.1, "recovery": 0.4, "anim": "gpound", "hint": "contest a nearby ball"},
	"wall": {"name": "PHALANX WALL", "cost": 40, "wind": 0.28, "active": 0.8, "recovery": 0.3, "anim": "mark", "hint": "near an available teammate"},
	"spring": {"name": "SPRING HEADER", "cost": 30, "wind": 0.2, "active": 0.35, "recovery": 0.3, "anim": "header", "hint": "under an aerial ball"},
	"boomerang": {"name": "BOOMERANG CROSS", "cost": 40, "wind": 0.28, "active": 0.1, "recovery": 0.35, "anim": "vollkck", "hint": "carry the ball; aim cross"},
	"rocket": {"name": "ROCKET THROW", "cost": 35, "wind": 0.45, "active": 0.1, "recovery": 0.35, "anim": "glwthrw", "hint": "keeper holding the ball"},
	"palm": {"name": "PALM BARRAGE", "cost": 40, "wind": 0.12, "active": 0.7, "recovery": 0.4, "anim": "gpunchu", "hint": "keeper faces incoming shot"},
	"cyclone": {"name": "CYCLONE SCISSOR", "cost": 40, "wind": 0.25, "active": 0.4, "recovery": 0.45, "anim": "bicycle", "hint": "under an aerial ball"},
	"dive": {"name": "DIVE", "cost": 10, "wind": 0.1, "active": 0.1, "recovery": 0.7, "anim": "fall", "hint": "an opponent right by you"},
	"captain": {"name": "CAPTAIN", "cost": 30, "wind": 0.3, "active": 0.1, "recovery": 0.3, "anim": "mark", "hint": "captain near an angry referee"},
	"bribe": {"name": "BRIBE", "cost": 100, "wind": 0.4, "active": 0.1, "recovery": 0.3, "anim": "mark", "hint": "full bar, right by the referee"},
}
const COLOUR := Color("67f4ef")
var match_game: Match
var active: Array[Dictionary] = []
var stuns: Dictionary = {}  # footballer -> {left, token}; own timer independent of animation duration
var immunity: Dictionary = {}
var cooldown: Dictionary = {}  # per-team: stops rapid swapping between players bypassing cooldown
var flight: Dictionary = {}
var ai_left := 1.5
var ai_enabled := true
var labels: Array[Label] = []

func _init(m: Match) -> void:
	match_game = m

func _ready() -> void:
	top_level = true
	z_index = 2001
	var layer := CanvasLayer.new()
	add_child(layer)
	if not Match.chaos:
		return
	for h in match_game.humans:
		var label := Label.new()
		label.position = Vector2(16 + h.index * 640, 108)
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 5)
		layer.add_child(label)
		labels.append(label)

func chosen(h: Human) -> String:
	return MOVES.keys()[h.special_index]

func actor(h: Human, id: String) -> Footballer:
	if id == "captain":
		return match_game.captain(h.team)
	return h.team.keeper() if id in ["rocket", "palm"] else h.controlled

func activate(h: Human, aim: Vector2) -> bool:
	var id := chosen(h)
	var p := actor(h, id)
	var why := unavailable(p, id)
	if why != "":
		match_game.flash(why, 0.8)
		return false
	return start(p, id, aim)

func partner(p: Footballer) -> Footballer:
	var best: Footballer
	for q in p.team.players:
		if q == p or q.role == "G" or q.sent_off or q.busy() or q.has_ball() or match_game._human_controls(q):
			continue
		var d := p.position.distance_to(q.position)
		if d >= 16.0 and d <= 48.0 and (best == null or d < p.position.distance_to(best.position)):
			best = q
	return best

func slow_loose() -> bool:
	var b := match_game.ball
	return b.holder == null and b.power == "" and b.z <= 8.0 and b.velocity.length() <= 220.0

func unavailable(p: Footballer, id: String) -> String:
	if not Match.chaos or match_game.state != Match.State.PLAY or not MOVES.has(id):
		return "Chaos actions need live Chaos play"
	if p == null or p.sent_off or p.busy() or p.dizzy_left > 0.0:
		return "Player recovering"
	if float(cooldown.get(p.team, 0.0)) > 0.0:
		return "Special cooling down"
	var d: Dictionary = MOVES[id]
	if p.team.energy < d.cost:
		return "Need %d energy" % d.cost
	var b := match_game.ball
	var near := p.position.distance_to(b.position)
	var valid := true
	if id in ["rocket", "palm"]:
		valid = p.role == "G"
	else:
		valid = p.role != "G"
	match id:
		"ghost", "pinball", "boomerang", "rocket": valid = valid and p.has_ball()
		"magnet": valid = valid and slow_loose() and near <= 27.0
		"stego": valid = valid and b.holder != null and b.holder.team != p.team and near <= 40.0
		"bass": valid = valid and near <= 36.0
		"wall": valid = valid and not p.has_ball() and partner(p) != null
		"spring", "cyclone": valid = valid and b.holder == null and b.power == "" and b.z > 12.0 and near <= 45.0
		"palm": valid = valid and b.holder == null and match_game.in_penalty_area(p.position, p.team)
		"dive": valid = valid and match_game.nearest_opponent_distance(p) <= Match.DIVE_RANGE
		"captain": valid = valid and match_game.ref_mood.get(p.team, 0.0) > 0.0 \
			and p.position.distance_to(match_game.referee.position) <= Match.CAPTAIN_RANGE
		"bribe": valid = valid and not match_game.bribed.has(p.team) \
			and p.position.distance_to(match_game.referee.position) <= Match.BRIBE_RANGE
	if id == "rocket":  # a keeper's throw waits for the box to clear, like any release
		valid = valid and match_game.keeper_may_release(p)
	if id in ["stego", "bass"] and b.holder != null and b.holder.role == "G" \
			and match_game.in_penalty_area(b.holder.position, b.holder.team):  # nobody challenges a keeper with the ball in his hands
		valid = false
	return "" if valid else d.hint.capitalize()

func lock(p: Footballer, anim: String) -> int:
	p.perform(anim)
	p.chaos_lock = true
	p.wish = Vector2.ZERO
	p.velocity = Vector2.ZERO
	return p._actions

func unlock(p: Footballer, token: int) -> void:
	p.chaos_lock = false
	p.chaos_lift = 0.0
	p.chaos_rotation = 0.0
	if p._actions == token:
		p._action_left = 0.0

func start(p: Footballer, id: String, aim: Vector2) -> bool:
	if unavailable(p, id) != "":
		return false
	var d: Dictionary = MOVES[id]
	var q: Footballer = partner(p) if id == "wall" else null
	if aim.length_squared() < 0.01:
		aim = Vector2(p.team.side, 0)
	aim = aim.normalized()
	p.facing = Anims.facing_from(aim)
	var a := {"p": p, "id": id, "aim": aim, "time": 0.0, "done": false,
		"token": lock(p, d.anim), "q": q, "q_token": 0, "origin": p.position}
	if q:
		q.facing = p.facing
		a.q_token = lock(q, "mark")
	active.append(a)
	p.team.energy -= d.cost
	cooldown[p.team] = 2.0 + d.wind + d.active + d.recovery
	match_game.event.emit(id, p.team)
	match_game.flash(d.name, 0.8)
	return true

func clear() -> void:
	for a in active:
		unlock(a.p, a.token)
		if a.q: unlock(a.q, a.q_token)
	active.clear()
	for p in stuns: unlock(p, stuns[p].token)
	stuns.clear()
	immunity.clear()
	flight.clear()
	cooldown.clear()

func _exit_tree() -> void:
	clear()

func tick(dt: float) -> void:
	if not Match.chaos or match_game.state != Match.State.PLAY:
		clear()
		update_labels()
		queue_redraw()
		return
	for t in cooldown: cooldown[t] = maxf(0.0, cooldown[t] - dt)
	for p in immunity: immunity[p] = maxf(0.0, immunity[p] - dt)
	for p in stuns.keys():
		stuns[p].left -= dt
		if stuns[p].left <= 0.0:
			unlock(p, stuns[p].token)
			stuns.erase(p)
	for a in active.duplicate():
		if not active.has(a):  # an earlier action can cancel this one by stunning its actor
			continue
		var p: Footballer = a.p
		var d: Dictionary = MOVES[a.id]
		a.time += dt
		var interrupted: bool = p.sent_off or p._actions != a.token or (a.q != null and (a.q.sent_off or a.q._actions != a.q_token))
		if interrupted or a.time >= d.wind + d.active + d.recovery:
			unlock(p, a.token)
			if a.q: unlock(a.q, a.q_token)
			active.erase(a)
			continue
		if a.time >= d.wind and a.time < d.wind + d.active:
			var phase: float = (a.time - d.wind) / d.active
			if a.id == "spring":
				p.chaos_lift = sin(phase * PI) * 30.0
			elif a.id == "cyclone":
				# An inverted volley, turning through the eight existing kit directions.
				p.chaos_rotation = PI
				p.chaos_lift = 18.0 + sin(phase * PI) * 10.0
				p.facing = (Anims.facing_from(a.aim) + int(phase * 16)) % 8
				p._anim = "vollkck"
				p._anim_time = 0.25
			apply_move(a, dt)
		elif a.time >= d.wind + d.active:
			p.chaos_lift = 0.0
			p.chaos_rotation = 0.0
		if match_game.state != Match.State.PLAY:
			clear()
			break
	update_flight(dt)
	if ai_enabled:
		ai_left -= dt
		if ai_left <= 0.0:
			ai_left = 0.5
			think_ai()
	update_labels()
	queue_redraw()

func strike(p: Footballer, aim: Vector2, speed: float, lift: float, kind: String) -> void:
	var b := match_game.ball
	b.release()
	b.in_hands = false
	b.last_touch = p
	b.kick(aim * speed, lift)
	b.kick_kind = kind
	p.touch_cooldown = 0.5

func stun(p: Footballer, seconds: float) -> bool:
	if p.sent_off or p.dodging() or float(immunity.get(p, 0.0)) > 0.0:
		return false
	# Cancel his special before taking ownership of the movement lock.
	for a in active.duplicate():
		if a.p == p or a.q == p:
			unlock(a.p, a.token)
			if a.q: unlock(a.q, a.q_token)
			active.erase(a)
	stuns[p] = {"left": seconds, "token": lock(p, "stumble")}
	immunity[p] = seconds + 1.5
	p.touch_cooldown = maxf(p.touch_cooldown, seconds)
	return true

func apply_move(a: Dictionary, dt: float) -> void:
	var p: Footballer = a.p
	var b := match_game.ball
	var aim: Vector2 = a.aim
	if a.id == "ghost":
		if not a.done:
			a.done = true
			if not p.has_ball(): return
			strike(p, aim, 260.0, 0.0, "dribble")
			a.moving = true
		if a.get("moving", false):
			p.position = (p.position + aim * 260.0 * dt).clamp(Pitch.field_rect().position, Pitch.field_rect().end)
		return
	if a.id == "magnet":
		if slow_loose() and p.position.distance_to(b.position) <= 27.0:
			b.velocity = (p.feet_front() - b.position).normalized() * 95.0
			if p.feet_front().distance_to(b.position) < 12.0:
				match_game._take(p)
		return
	if a.id == "wall":
		if b.holder == null and b.power == "" and b.z <= 20.0 and not a.done:
			var q: Footballer = a.q
			var point := Geometry2D.get_closest_point_to_segment(b.position, p.position, q.position)
			if swept_near(point, 12.0):
				var normal := (q.position - p.position).orthogonal().normalized()
				var v := b.velocity.bounce(normal) * 0.75
				b.last_touch = p if point.distance_to(p.position) < point.distance_to(q.position) else q
				b.kick(v, 40.0)
				b.kick_kind = "deflection"
				a.done = true
		return
	if a.id == "palm":
		if b.holder == null and b.power != "thunder" and b.z <= 60.0 and b.velocity.dot(aim) < 0.0:
			var relative := b.position - p.position
			if relative.dot(aim) >= -4.0 and swept_near(p.position + aim * 10.0, 32.0):
				strike(p, (aim + aim.orthogonal() * (0.65 if relative.dot(aim.orthogonal()) >= 0.0 else -0.65)).normalized(), 380.0, 100.0, "save")
				p.team.gain(Supers.GAIN.save)
				match_game.event.emit("save", p.team)
		return
	if a.done: return
	if a.id in ["spring", "cyclone"]:
		var reach := 82.0 if a.id == "spring" else 66.0
		if b.holder != null or b.power != "" or b.z < 16.0 or b.z > reach or not swept_near(p.position, 22.0): return
		if match_game._caught_offside(p): return
		a.done = true
		strike(p, aim, 510.0 if a.id == "spring" else 610.0, 100.0, "shot")
		return
	a.done = true
	match a.id:
		"dive":
			match_game.dive(p)
		"captain":
			match_game.calm_referee(p.team)
		"bribe":
			match_game.bribe(p.team)
		"pinball", "boomerang", "rocket":
			if not p.has_ball(): return
			if a.id == "rocket": b.z = Footballer.HEAD_HEIGHT
			strike(p, aim, 720.0 if a.id == "rocket" else 540.0, 430.0 if a.id == "boomerang" else 120.0 if a.id == "rocket" else 0.0, "cross" if a.id == "boomerang" else "pass")
			if a.id != "rocket":
				flight = {"id": a.id, "p": p, "revision": b.touch_revision, "time": 0.0, "turned": false, "origin": a.origin}
		"stego", "bass":
			if p.position.distance_to(b.position) > 38.0: return
			var hits := 0
			for o in match_game.opponent(p.team).players:
				var offset := o.position - p.position
				if offset.length() > (32.0 if a.id == "stego" else 36.0) or o.position.distance_to(b.position) > 36.0: continue
				if a.id == "stego" and (b.holder != o or offset.normalized().dot(aim) < 0.3): continue
				if stun(o, 0.4 if a.id == "stego" else 0.45):
					match_game.offence(p, o.position, "chaos")
					if b.holder == o: strike(p, aim, 150.0, 45.0, "tackle")
					hits += 1
					if hits >= (1 if a.id == "stego" else 2): break

func swept_near(point: Vector2, radius: float) -> bool:
	var b := match_game.ball
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, b.prev_position, b.position)) <= radius

func update_flight(dt: float) -> void:
	if flight.is_empty(): return
	var b := match_game.ball
	if b.holder != null or b.power != "" or b.touch_revision != flight.revision or not Pitch.field_rect().has_point(b.position):
		flight.clear()
		return
	flight.time += dt
	if flight.time > 2.5:
		flight.clear()
		return
	if flight.id == "pinball" and b.z <= 12.0:
		for o in match_game.opponent(flight.p.team).players:
			if o.sent_off or o.touch_cooldown > 0.0 or not swept_near(o.position, Footballer.REACH): continue
			var closest := Geometry2D.get_closest_point_to_segment(o.position, b.prev_position, b.position)
			var normal := (closest - o.position).normalized()
			if normal == Vector2.ZERO: normal = -b.velocity.normalized()
			var v := b.velocity.bounce(normal)
			if v.dot(normal) < 0.0: v = -v
			b.last_touch = o
			b.kick(v, 30.0)
			b.kick_kind = "deflection"
			o.touch_cooldown = 0.25
			flight.clear()
			return
	elif flight.id == "boomerang" and flight.time >= 0.65:
		if not flight.turned:
			# Lock a return direction once: never track players or a moving target.
			flight.return_dir = (Vector2(b.position.x + flight.p.team.side * 120.0, flight.origin.y) - b.position).normalized()
			flight.turned = true
		b.velocity = b.velocity.move_toward(flight.return_dir * 430.0, 650.0 * dt)

func think_ai() -> void:
	for t in [match_game.home, match_game.away]:
		if not match_game.autoplay and match_game.human_for(t) != null: continue
		if float(cooldown.get(t, 0.0)) > 0.0: continue
		var b := match_game.ball
		var p: Footballer = b.holder if b.holder != null and b.holder.team == t else match_game.chaser(t)
		var ids: Array = []
		if b.holder == t.keeper(): ids = ["rocket"]
		elif b.holder == null and b.position.distance_to(t.keeper().position) < 110.0 and b.velocity.x * t.side < 0.0:
			p = t.keeper()
			ids = ["palm"]
		elif p.has_ball(): ids = ["ghost", "pinball", "boomerang"]
		elif b.holder == null and b.z > 12.0: ids = ["spring", "cyclone"]
		else: ids = ["stego", "magnet", "bass", "wall"]
		ids.shuffle()
		for id: String in ids:
			var aim: Vector2 = (t.goal_attacked() - p.position).normalized()
			if id == "rocket":  # only to a teammate with a clear lane; otherwise he distributes it as usual
				var mate := AI.best_pass(p, match_game, Vector2.ZERO)
				if mate == null or AI._lane_blocked(p, mate, match_game):
					continue
				aim = (mate.position - p.position).normalized()
			if start(p, id, aim): break

func update_labels() -> void:
	for i in labels.size():
		var h := match_game.humans[i]
		var id := chosen(h)
		var why := unavailable(actor(h, id), id)
		labels[i].text = "%s / %d energy\n%s\n%s" % [MOVES[id].name, MOVES[id].cost,
			"E use · R next / Pad Y · RB" if i == 0 else ", use · . next / Pad Y · RB",
			"READY" if why == "" else why]
		labels[i].visible = Match.chaos and not match_game.autoplay

func screen(at: Vector2, height := 0.0) -> Vector2:
	var v := match_game.stadium.to_screen(at, height)
	return Vector2(v.x, v.y)

func _draw() -> void:
	if not Match.chaos: return
	for a in active:
		var p: Footballer = a.p
		var d: Dictionary = MOVES[a.id]
		var at := screen(p.position)
		var phase: float = clampf((a.time - d.wind) / d.active, 0.0, 1.0)
		var c := Color(COLOUR, 0.45 if a.time < d.wind else 0.85)
		draw_arc(at, 20.0, 0, TAU * minf(a.time / d.wind, 1.0), 28, c, 2.0)
		match a.id:
			"ghost":
				for i in 3:
					var spot := screen(p.position - a.aim * (i + 1) * 12.0)
					draw_line(spot, spot + Vector2(0, -35), Color(COLOUR, 0.4 - i * 0.1), 8.0)
			"magnet":
				draw_line(screen(p.feet_front()), screen(match_game.ball.position, match_game.ball.z), c, 2.0)
			"wall":
				draw_line(screen(p.position, 18), screen(a.q.position, 18), Color("eac76a"), 6.0)
			"bass", "stego":
				for i in 2:
					draw_arc(at, 12 + phase * 40 + i * 7, -PI if a.id == "stego" else 0.0, PI, 32, Color("f8ae49"), 2.0)
			"palm":
				for i in 6:
					var angle := -PI + i * PI / 5.0 + sin(a.time * 40 + i) * 0.12
					var glove := at + Vector2(cos(angle) * 30, -25 + sin(angle) * 22)
					draw_line(at + Vector2(0, -25), glove, Color(COLOUR, 0.5), 3)
					draw_rect(Rect2(glove - Vector2(4, 3), Vector2(8, 6)), c)
			"spring", "cyclone":
				draw_arc(at + Vector2(0, -32), 27.0, a.time * 14, a.time * 14 + PI * 1.5, 24, c, 4)
			_:
				draw_line(at, screen(p.position + a.aim * 35), c, 3)
	for p in stuns:
		for i in 3:
			draw_circle(screen(p.position, 52) + Vector2((i - 1) * 8, sin(stuns[p].left * 30 + i) * 3), 2.5, Color.YELLOW)
	if not flight.is_empty():
		var b := match_game.ball
		draw_line(screen(b.position, b.z), screen(b.position - b.velocity.normalized() * 32, b.z), Color("f5a1ef"), 4)
