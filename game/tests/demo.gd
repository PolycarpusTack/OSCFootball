extends SceneTree
## Demo reel, AI vs AI: a Brugge attack, an Anderlecht shot, then a foul in the box
## and the penalty. Each situation is staged, then played out by the AI.
## godot --path game -s res://tests/demo.gd --write-movie demo.avi --fixed-fps 30 -- seed=7

var m: Node
var log_lines: Array[String] = []


func _initialize() -> void:
	var seed_value := 7
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			seed_value = int(a.substr(5))
	seed(seed_value)
	m = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)
	m.event.connect(func(kind, team): log_lines.append("%s:%s" % [kind, team.short]))
	await create_timer(2.0).timeout

	# 1. Brugge striker breaks into the Anderlecht half
	_stage(m.home, Vector2(1640, 560), 0.0)
	await _until_event(6.0)
	await create_timer(4.0).timeout

	# 2. Anderlecht striker bears down on the Brugge goal
	_stage(m.away, Vector2(260, 680), 0.0)
	await _until_event(6.0)
	await create_timer(2.5).timeout

	# 3. Brugge striker in the box, Anderlecht defender slides in from behind
	var striker = _stage(m.home, Vector2(1690, 700), 1.0)
	var defender = m.away.players[2]
	defender.position = striker.position - Vector2(30, 0)
	defender.facing = 2
	defender.slide()
	await _until_event(3.0)  # foul
	await _until_event(6.0)  # penalty
	await _until_event(6.0)  # goal or save
	await create_timer(4.0).timeout

	print("seed %d events: %s" % [seed_value, ", ".join(log_lines)])
	quit()


## Put `team`'s striker on the ball at `pos`, everyone else at kick-off spots.
func _stage(team, pos: Vector2, hold_shot: float):
	m.kickoff(team)
	m.state = 1  # PLAY
	var striker = team.players[9]
	striker.position = pos
	striker.facing = 2 if team.side > 0 else 6
	striker.think_timer = hold_shot
	m.ball.stop_at(striker.feet_front())
	m.ball.take(striker)
	return striker


func _until_event(timeout: float) -> void:
	var n := log_lines.size()
	var waited := 0.0
	while log_lines.size() == n and waited < timeout:
		await process_frame
		waited += 1.0 / 30.0  # run with --fixed-fps 30
