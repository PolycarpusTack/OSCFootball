extends SceneTree
## Not a test: plays AI-vs-AI matches at high speed and prints how the match engine behaves
## (decisions by line, shots by line and distance, who wins the ball back, passes found), to
## compare the AI before and after a change.
## godot --headless --path game -s res://tests/engine_probe.gd -- matches=3 seed=1

const DECISIONS := ["shoot", "pass", "pass wide", "cross", "skill move", "thunder", "fireball", "banana"]

var counts := {}  # "what|line" -> n
var shot_m := {}  # line -> [distances in m]
var fifths := [0, 0, 0, 0, 0]  # open-play frames with the ball in each fifth of the pitch's length
var won_at := [0, 0, 0, 0, 0]  # balls won in each fifth, from the winner's own goal
var passes := {}  # "short|found" etc. -> n: AI passes by length (under / over 15 m) and what became of them
var mean_spot := {}  # line -> [sum of x from own goal as a pitch fraction, frames]: where each line stands


func _initialize() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var matches := int(args.get("matches", "3"))
	seed(int(args.get("seed", "1")))
	Engine.max_physics_steps_per_frame = 64
	Engine.time_scale = 16.0
	for i in matches:
		await _play()
	_report(matches)
	quit()


func _play() -> void:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)
	var states := {}
	var holder = null
	var loose_from = null
	var pass_from := Vector2.INF  # where the pass in flight left from
	m.event.connect(func(kind, team):
		if kind == "shot" and m.ball.last_touch:
			var p = m.ball.last_touch
			_add("shots", p.role)
			shot_m.get_or_add(p.role, []).append(p.position.distance_to(p.team.goal_attacked()) / Pitch.PX_PER_M)
		elif kind == "goal" and m.ball.last_touch and m.ball.last_touch.team == team:
			_add("goals", m.ball.last_touch.role))
	var t0 := Time.get_ticks_msec()
	while m.state != 6 and Time.get_ticks_msec() - t0 < 180000:
		await physics_frame
		if m.state != 1:  # open play only
			if pass_from != Vector2.INF:
				_pass("out of play", 0.0)
				pass_from = Vector2.INF
			holder = m.ball.holder
			loose_from = null
			continue
		var fx: float = m.ball.position.x / Pitch.field_rect().size.x
		fifths[clampi(int(fx * 5.0), 0, 4)] += 1
		for t in [m.home, m.away]:
			for p in t.players:
				var px: float = p.position.x / Pitch.field_rect().size.x
				var acc: Array = mean_spot.get_or_add(p.role, [0.0, 0])
				acc[0] += px if t.side > 0 else 1.0 - px
				acc[1] += 1
				var s: String = p.ai_state
				if s != states.get(p, "") and s in DECISIONS:
					_add(s, p.role)
				states[p] = s
		var h = m.ball.holder
		if h != holder:
			if h == null:
				loose_from = holder
				pass_from = holder.position if m.ball.kick_kind == "pass" else Vector2.INF
			else:
				if pass_from != Vector2.INF:
					var mine: bool = loose_from != null and h.team == loose_from.team
					_pass("found" if mine else "lost", pass_from.distance_to(h.position) / Pitch.PX_PER_M)
					pass_from = Vector2.INF
				var before = holder if holder else loose_from
				if before and before != h:
					if before.team == h.team:
						_add("passes found", before.role)
					else:
						_add("ball won", h.role)
						var up: float = fx if h.team.side > 0 else 1.0 - fx
						won_at[clampi(int(up * 5.0), 0, 4)] += 1
						_add("ball lost", before.role)
				loose_from = null
			holder = h
	m.queue_free()
	await process_frame


func _pass(what: String, metres: float) -> void:
	var key := ("long" if metres > 15.0 else "short") + "|" + what if what != "out of play" else "out of play"
	passes[key] = passes.get(key, 0) + 1


func _add(what: String, line: String) -> void:
	counts[what + "|" + line] = counts.get(what + "|" + line, 0) + 1


func _report(matches: int) -> void:
	print("per match, by line (G D M F):")
	for what in DECISIONS + ["shots", "goals", "passes found", "ball won", "ball lost"]:
		var row := []
		var total := 0
		for line in ["G", "D", "M", "F"]:
			var n: int = counts.get(what + "|" + line, 0)
			total += n
			row.append("%5.1f" % (float(n) / matches))
		if total > 0:
			print("  %-13s %s" % [what, " ".join(row)])
	print("  AI passes per match: %s" % [passes.keys().map(func(k): return "%s %.1f" % [k, float(passes[k]) / matches])])
	var total := 0
	for n in fifths:
		total += n
	print("  ball in each fifth of the pitch: %s %%" % [fifths.map(func(n): return roundi(100.0 * n / maxf(total, 1)))])
	print("  balls won per fifth, from the winner's goal: %s" % [won_at.map(func(n): return snappedf(float(n) / matches, 0.1))])
	for line in ["G", "D", "M", "F"]:
		if mean_spot.has(line):
			print("  %s stand on average %.2f up the pitch" % [line, mean_spot[line][0] / mean_spot[line][1]])
	for line in ["D", "M", "F"]:
		var d: Array = shot_m.get(line, [])
		if not d.is_empty():
			d.sort()
			print("  shot distance %s: median %.0f m, max %.0f m (%d shots)" % [line, d[d.size() / 2], d[-1], d.size()])
