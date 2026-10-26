extends SceneTree
## Team Instructions (EPIC C): every side has the 8 instructions at "normal", and "normal" plays
## as the AI did before there were instructions: the golden values below were taken from the
## code before C-2 (2026-10-26; Brugge v Anderlecht, 4-4-2, offside off so the spots don't
## depend on where the others stand).
## godot --headless --path game -s res://tests/instructions_test.gd

const GOLDEN_SPOTS := '[[264.6,612.0],[113.4,612.0],[642.6,1101.6],[264.6,930.24],[510.3,783.36],[245.7,722.16],[510.3,440.64],[245.7,501.84],[642.6,122.4],[264.6,293.76],[1096.2,1101.6],[680.4,930.24],[945.0,758.88],[604.8,709.92],[945.0,465.12],[604.8,514.08],[1096.2,122.4],[680.4,293.76],[1398.6,734.4],[982.8,685.44],[1398.6,489.6],[982.8,538.56],[1625.4,612.0],[1776.6,612.0],[1247.4,122.4],[1625.4,293.76],[1379.7,440.64],[1644.3,501.84],[1379.7,783.36],[1644.3,722.16],[1247.4,1101.6],[1625.4,930.24],[793.8,122.4],[1209.6,293.76],[945.0,465.12],[1285.2,514.08],[945.0,758.88],[1285.2,709.92],[793.8,1101.6],[1209.6,930.24],[491.4,489.6],[907.2,538.56],[491.4,734.4],[907.2,685.44],[113.4,722.16],[113.4,722.16],[387.45,1175.04],[113.4,1077.12],[255.15,856.8],[113.4,869.04],[255.15,514.08],[113.4,648.72],[387.45,195.84],[113.4,440.64],[812.7,1193.4],[425.25,1077.12],[661.5,850.68],[349.65,856.8],[661.5,556.92],[349.65,660.96],[812.7,214.2],[425.25,440.64],[1115.1,807.84],[699.3,795.6],[1115.1,563.04],[699.3,648.72],[1341.9,722.16],[1644.3,722.16],[992.25,195.84],[1426.95,440.64],[1124.55,514.08],[1445.85,648.72],[1124.55,856.8],[1445.85,869.04],[992.25,1175.04],[1426.95,1077.12],[510.3,214.2],[954.45,440.64],[661.5,556.92],[1030.05,660.96],[661.5,850.68],[1030.05,856.8],[510.3,1193.4],[954.45,1077.12],[207.9,563.04],[623.7,648.72],[207.9,807.84],[623.7,795.6],[595.35,538.56],[292.95,538.56],[940.28,1052.64],[496.12,832.32],[807.98,734.4],[477.23,624.24],[807.98,391.68],[477.23,403.92],[940.28,73.44],[496.12,195.84],[1426.95,1040.4],[978.08,832.32],[1275.75,697.68],[902.47,612.0],[1275.75,403.92],[902.47,416.16],[1426.95,61.2],[978.08,195.84],[1729.35,685.44],[1313.55,612.0],[1729.35,440.64],[1313.55,465.12],[1776.6,538.56],[1776.6,538.56],[1545.07,73.44],[1776.6,195.84],[1677.38,391.68],[1776.6,403.92],[1677.38,734.4],[1776.6,624.24],[1545.07,1052.64],[1776.6,832.32],[1124.55,61.2],[1507.28,195.84],[1275.75,403.92],[1582.88,416.16],[1275.75,697.68],[1582.88,612.0],[1124.55,1040.4],[1507.28,832.32],[822.15,440.64],[1237.95,465.12],[822.15,685.44],[1237.95,612.0]]'  # AI.hold_spot, both sides, with and without the ball, ball at 3 places
const GOLDEN_RANGES := '[288.0,366.55,288.0,288.0,288.0,401.89,429.38,405.82,417.6,394.04,374.4]'  # AI.shooting_range, the home side


func _initialize() -> void:
	var match_script: GDScript = load("res://scripts/main.gd")  # Match; the class can't be named here
	var team_script: GDScript = load("res://scripts/team.gd")
	var ai = load("res://scripts/ai.gd")
	var ok := true
	match_script.offside_on = false
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true  # both sides the AI's (C-3 plays a little of the second half)
	root.add_child(m)
	await create_timer(1.6).timeout
	m.state = 5  # HALF_TIME with a long pause: freeze the AI
	m._state_left = 1e9

	# C-1-AC1: a Team has the 8 instructions, all at "normal"
	var keys: Array = team_script.INSTRUCTIONS.keys()
	print("instructions: %s" % [m.home.instructions])
	ok = ok and keys.size() == 8 and m.home.instructions.keys() == keys and m.away.instructions.keys() == keys
	for k in keys:
		ok = ok and m.home.instructions[k] == "normal" and m.home.instruction(k) == 0 \
			and "normal" in team_script.INSTRUCTIONS[k]
	m.home.instructions.line = "offside trap"
	m.home.instructions.mentality = "attacking"
	m.home.instructions.tempo = "slow"
	print("offside trap %d, attacking %d, slow %d" % [m.home.instruction("line"), m.home.instruction("mentality"),
		m.home.instruction("tempo")])
	ok = ok and m.home.instruction("line") == 2 and m.home.instruction("mentality") == 1 and m.home.instruction("tempo") == -1
	for k in keys:
		m.home.instructions[k] = "normal"

	# C-1-AC2: at "normal", the AI's spots and shooting range are what they were
	var field: Rect2 = Pitch.field_rect()
	var spots := []
	for at in [Vector2(0.5, 0.5), Vector2(0.2, 0.8), Vector2(0.85, 0.3)]:
		m.ball.position = Vector2(at.x * field.size.x, at.y * field.size.y)
		for t in [m.home, m.away]:
			for p in t.players:
				for attacking in [true, false]:
					var s: Vector2 = ai.hold_spot(p, m, attacking)
					spots.append([snappedf(s.x, 0.01), snappedf(s.y, 0.01)])
	var ranges := []
	for p in m.home.players:
		ranges.append(snappedf(ai.shooting_range(p), 0.01))
	var same_spots := JSON.stringify(spots) == GOLDEN_SPOTS
	var same_ranges := JSON.stringify(ranges) == GOLDEN_RANGES
	print("at normal: spots as before %s, shooting range as before %s" % [same_spots, same_ranges])
	ok = ok and same_spots and same_ranges

	# C-2-AC1: attacking moves each line's average spot at least 8 m up, defensive 8 m back
	m.ball.position = field.size / 2.0
	var t = m.home
	var normal := _lines(t, m, ai)
	for level in ["attacking", "defensive"]:
		t.instructions.mentality = level
		var moved := _lines(t, m, ai)
		var by := {}
		for line in normal:
			by[line] = snappedf((moved[line] - normal[line]) * (1 if level == "attacking" else -1), 0.1)
		print("%s: each line's average spot moves %s m" % [level, by])
		for line in by:
			ok = ok and by[line] >= 8.0
	t.instructions.mentality = "normal"

	# C-2-AC2: wide and narrow change the side's spread across the pitch by 15 % or more
	var spread := _spread(t, m, ai)
	t.instructions.width = "wide"
	var wide := _spread(t, m, ai)
	t.instructions.width = "narrow"
	var narrow := _spread(t, m, ai)
	t.instructions.width = "normal"
	print("spread across: narrow %.0f, normal %.0f, wide %.0f m" % [narrow, spread, wide])
	ok = ok and wide >= spread * 1.15 and narrow <= spread * 0.85

	# C-2-AC3: a high line holds the back four 10 m higher without the ball; a deep one a little
	# deeper (it's deep already: not into its own six-yard box)
	t.instructions.line = "high"
	var high: float = _lines(t, m, ai, false).D
	t.instructions.line = "deep"
	var deep: float = _lines(t, m, ai, false).D
	t.instructions.line = "normal"
	var level_line: float = _lines(t, m, ai, false).D
	print("back four without the ball: deep %.1f, normal %.1f, high %.1f m up" % [deep, level_line, high])
	ok = ok and high - level_line >= 10.0 and level_line - deep >= 3.5 and deep >= 9.0

	# C-2-AC4: with the offside trap, the back four steps up further as the other side's pass is
	# played (no one on the ball, their pass on its way)
	t.instructions.line = "high"
	m.ball.holder = null
	m.ball.last_touch = m.away.players[6]
	m.ball.kick_kind = "pass"
	var no_trap: float = _lines(t, m, ai, false).D
	t.instructions.line = "offside trap"
	var trap: float = _lines(t, m, ai, false).D
	m.ball.last_touch = null
	var trap_still: float = _lines(t, m, ai, false).D
	t.instructions.line = "normal"
	print("their pass on its way: high line %.1f, trap %.1f m up; no pass, trap %.1f" % [no_trap, trap, trap_still])
	ok = ok and trap - no_trap >= 4.0 and absf(trap_still - no_trap) < 0.1

	# C-3-AC1: direct's passes (through balls and crosses included) are on average at least 1.5 times
	# as long as short's, normal's in between. Where everyone stands at 6 moments of open play; at
	# each, each home outfield player in turn on the ball, deciding 20 times (seeded).
	m.ball.position = field.size / 2.0
	m._state_left = 0.0  # on to the second half
	var moments := []
	for i in 6:
		await create_timer(2.5).timeout
		moments.append((m.home.players + m.away.players).map(func(q): return q.position))
	m.state = 5
	m._state_left = 1e9
	var length := {}
	for level in ["short", "normal", "direct"]:
		t.instructions.passing = level
		seed(7)
		var metres := 0.0
		var passes := 0
		for at in moments:
			for i in 22:
				(m.home.players + m.away.players)[i].position = at[i]
			for p in t.players.slice(1):
				m.ball.holder = p
				m.ball.position = p.position
				for j in 20:
					var choice: Array = ai.choose(p, m)
					if choice[0] in ["pass", "through ball", "cross"]:
						metres += p.position.distance_to(choice[1].position) / Pitch.m(1.0)
						passes += 1
		length[level] = metres / maxf(passes, 1.0)
	t.instructions.passing = "normal"
	print("average pass: short %.1f, normal %.1f, direct %.1f m" % [length.short, length.normal, length.direct])
	ok = ok and length.direct >= 1.5 * length.short and length.short < length.normal and length.normal < length.direct

	# C-3-AC2: fast tempo cuts the time on the ball before a decision, slow adds to it
	var p6 = t.players[6]
	var times := []
	for level in ["slow", "normal", "fast"]:
		t.instructions.tempo = level
		times.append(ai.think_time(p6))
	t.instructions.tempo = "normal"
	print("time on the ball before deciding: slow %.2f, normal %.2f, fast %.2f s" % times)
	ok = ok and times[0] > times[1] and times[2] < times[1] * 0.8

	# C-3-AC3: shoot on sight stretches the shooting range, patient shortens it
	var ranges_by := []
	for level in ["patient", "normal", "on sight"]:
		t.instructions.shooting = level
		ranges_by.append(ai.shooting_range(t.players[10]) / Pitch.m(1.0))
	t.instructions.shooting = "normal"
	print("shooting range: patient %.1f, normal %.1f, on sight %.1f m" % ranges_by)
	ok = ok and ranges_by[2] >= ranges_by[1] * 1.15 and ranges_by[0] <= ranges_by[1] * 0.85
	m.ball.holder = null

	# C-4: their man on the ball deep in their half; one home player 4 m off him, another 10 m
	var park := Vector2(-5000, -5000)  # out of everything
	for q in m.home.players + m.away.players:
		q.position = park
	var holder = m.away.players[6]
	var centre: Vector2 = field.size / 2.0
	holder.position = centre + (m.home.goal_attacked() - centre) * 0.6
	m.ball.take(holder)
	m.ball.position = holder.position
	var near = t.players[9]
	var next = t.players[10]
	near.position = holder.position + Vector2(0, Pitch.m(4.0))
	next.position = holder.position - Vector2(0, Pitch.m(10.0))
	var states := {}
	for level in ["stand off", "normal", "high"]:
		t.instructions.pressing = level
		ai._pressers.clear()
		ai.think(near, m, 0.016)
		ai.think(next, m, 0.016)
		states[level] = [near.ai_state, next.ai_state]
	t.instructions.pressing = "normal"
	# C-4-AC1: the high press sends a second man; normal one; AC2: stand off none, in their half
	print("their man in his half, ours 4 m and 10 m off: %s" % [states])
	ok = ok and states.normal == ["chase", "defend"] and states.high == ["chase", "chase"] \
		and not "chase" in states["stand off"]
	# ... and stand off still presses him in our half
	holder.position = centre + (m.home.goal_defended() - centre) * 0.6
	m.ball.position = holder.position
	near.position = holder.position + Vector2(0, Pitch.m(4.0))
	t.instructions.pressing = "stand off"
	ai._pressers.clear()
	ai.think(near, m, 0.016)
	t.instructions.pressing = "normal"
	print("stand off, their man in our half: %s" % near.ai_state)
	ok = ok and near.ai_state == "chase"
	m.ball.holder = null

	# C-4-AC3: hard tackling goes to ground and barges more often, easy less
	var odds := []
	for level in ["easy", "normal", "hard"]:
		t.instructions.tackling = level
		odds.append([ai.slide_chance(near), ai.body_check_chance(near)])
	t.instructions.tackling = "normal"
	print("slide, body-check chance a frame: easy %s, normal %s, hard %s" % odds)
	ok = ok and odds[2][0] >= odds[1][0] * 1.5 and odds[0][0] <= odds[1][0] / 1.5 \
		and odds[2][1] >= odds[1][1] * 1.5 and odds[0][1] <= odds[1][1] / 1.5

	match_script.offside_on = true
	print("INSTRUCTIONS TEST PASSED" if ok else "INSTRUCTIONS TEST FAILED")
	quit(0 if ok else 1)


## Each outfield line's average hold_spot, metres up the pitch the way `t` attacks; both phases,
## or the one asked for.
func _lines(t, m: Node, ai, attacking = null) -> Dictionary:
	var sum := {}
	var n := {}
	for p in t.players:
		if p.role == "G":
			continue
		for phase in ([true, false] if attacking == null else [attacking]):
			sum[p.role] = sum.get(p.role, 0.0) + ai.hold_spot(p, m, phase).x * t.side / Pitch.m(1.0)
			n[p.role] = n.get(p.role, 0) + 1
	for line in sum:
		sum[line] /= n[line]
	return sum


## How far apart across the pitch (metres) the outfield players stand, with and without the ball.
func _spread(t, m: Node, ai) -> float:
	var total := 0.0
	for phase in [true, false]:
		var ys := []
		for p in t.players:
			if p.role != "G":
				ys.append(ai.hold_spot(p, m, phase).y)
		total += (ys.max() - ys.min()) / Pitch.m(1.0)
	return total / 2.0
