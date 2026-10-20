extends SceneTree
## Super-shot reel, AI vs AI: a Brugge fireball through two defenders, an Anderlecht
## banana shot from the wing, and a Brugge Thunder Strike.
## godot --path game -s res://tests/supers_demo.gd --write-movie supers.avi --fixed-fps 30 -- seed=1

var m: Node
var log_lines: Array[String] = []


func _initialize() -> void:
	var seed_value := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			seed_value = int(a.substr(5))
	seed(seed_value)
	m = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)
	m.event.connect(func(kind, team): log_lines.append("%s:%s" % [kind, team.short]))
	var field: Rect2 = Pitch.field_rect()
	var mid := field.size.y / 2.0
	await create_timer(1.5).timeout

	# 1. Fireball: two Anderlecht defenders stand in the line of fire
	var s = _stage(m.home, Vector2(1380, mid + 10))
	await _fill(m.home, 50.0)
	m.away.players[2].position = Vector2(1520, mid + 8)
	m.away.players[3].position = Vector2(1640, mid - 4)
	await create_timer(0.4).timeout
	m.try_super(s, "fireball", m.home.goal_attacked() + Vector2(0, 30))
	await _until_event(4.0)
	await create_timer(3.5).timeout

	# 2. Banana: Anderlecht winger far out wide, bending it in
	s = _stage(m.away, Vector2(330, mid - 330))
	await _fill(m.away, 50.0)
	m.try_super(s, "banana", m.away.goal_attacked() + Vector2(0, 40))
	await _until_event(4.0)
	await create_timer(3.5).timeout

	# 3. Thunder Strike: full bar, overhead kick from the edge of the box
	s = _stage(m.home, Vector2(1520, mid + 120))
	await _fill(m.home, 100.0)
	m.try_super(s, "thunder", m.home.goal_attacked() - Vector2(0, 50))
	await _until_event(5.0)
	await create_timer(4.0).timeout

	print("seed %d events: %s" % [seed_value, ", ".join(log_lines)])
	quit()


## Put `team`'s striker on the ball at `pos`, everyone else at kick-off spots.
func _stage(team, pos: Vector2):
	m.kickoff(team)
	m.state = 1  # PLAY
	var striker = team.players[9]
	striker.position = pos
	striker.facing = 2 if team.side > 0 else 6
	striker.think_timer = 99.0  # the reel decides when it shoots
	m.ball.stop_at(striker.feet_front())
	m.ball.take(striker)
	return striker


## Visibly fill the team's bar over ~1 s.
func _fill(team, to: float) -> void:
	while team.energy < to:
		team.energy = minf(to, team.energy + 3.0)
		await process_frame


func _until_event(timeout: float) -> void:
	var n := log_lines.size()
	var waited := 0.0
	while log_lines.size() <= n + 1 and waited < timeout:  # the super's own event, then its outcome
		await process_frame
		waited += 1.0 / 30.0  # run with --fixed-fps 30
