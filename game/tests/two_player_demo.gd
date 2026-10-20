extends SceneTree
## Two-player reel: both humans' controls are driven by script, as if two people were
## playing. Open play from the kick-off, a Brugge (P1) attack with Anderlecht (P2)
## chasing and sliding, a P2 fireball by combo, a P1 Thunder Strike.
## godot --path game -s res://tests/two_player_demo.gd --write-movie 2p.avi --fixed-fps 30 -- seed=1

const FRAME := 1.0 / 30.0  # run with --fixed-fps 30

var m: Node
var log_lines: Array[String] = []


func _initialize() -> void:
	var seed_value := 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			seed_value = int(a.substr(5))
	seed(seed_value)
	m = load("res://scenes/main.tscn").instantiate()
	m.get_script().players = 2  # Match.players; the class can't be named here before the Anims autoload exists
	root.add_child(m)
	m.event.connect(func(kind, team): log_lines.append("%s:%s" % [kind, team.short]))
	await create_timer(1.6).timeout  # kick-off pause

	# 1. Open play: both chase the ball; whoever has it runs at goal; slide when close
	await _play(9.0, [_chase_or_attack(0), _chase_or_attack(1)])

	# 2. P1 breaks forward; P2 chases and slides in
	await _wait_play()
	var p1 = _give(0, Vector2(1150, 640))
	await _play(1.6, [func(): return Vector2(1, 0.15), _chase_or_attack(1)])
	if m.ball.holder == m.humans[0].controlled:
		await _shoot(0, 0.35)
	await create_timer(4.0).timeout

	# 3. P2 fireball: down, down-forward, forward (forward = left for Anderlecht), shoot
	await _wait_play()
	_give(1, Vector2(620, 480))
	m.away.energy = 50.0
	for o in m.home.players.slice(1):
		o.position.x = maxf(o.position.x, 800.0)  # Brugge caught upfield
	await _play(0.3, [_still(), _still()])
	for dir in [Vector2(0, 1), Vector2(-1, 1), Vector2(-1, 0)]:
		await _play(0.1, [_still(), func(): return dir])
	await _shoot(1, 0.05)
	await create_timer(4.5).timeout

	# 4. P1 Thunder Strike: full bar, hold shoot
	await _wait_play()
	p1 = _give(0, Vector2(1450, 560))
	m.home.energy = 100.0
	for o in m.away.players.slice(1):
		o.position.x = minf(o.position.x, 1200.0)
	await _play(0.4, [func(): return Vector2(1, 0), _still()])
	await _shoot(0, 1.0)
	await create_timer(5.0).timeout

	print("seed %d events: %s   score %d-%d" % [seed_value, ", ".join(log_lines), m.home.score, m.away.score])
	quit()


## Run `seconds` of play with each player's stick given by a Callable -> Vector2.
func _play(seconds: float, sticks: Array) -> void:
	var t := 0.0
	while t < seconds:
		for i in 2:
			_steer(i, sticks[i].call())
		await process_frame
		t += FRAME
	for i in 2:
		_steer(i, Vector2.ZERO)


func _steer(i: int, dir: Vector2) -> void:
	var pre := "" if i == 0 else "p2_"
	for pair in [["move_left", -dir.x], ["move_right", dir.x], ["move_up", -dir.y], ["move_down", dir.y]]:
		if pair[1] > 0.05:
			Input.action_press(pre + pair[0], minf(pair[1], 1.0))
		else:
			Input.action_release(pre + pair[0])


## Stick for player i: run at the ball, slide when an opponent has it within reach,
## and with the ball dribble at goal and shoot from range.
func _chase_or_attack(i: int) -> Callable:
	return func() -> Vector2:
		var h = m.humans[i]
		var p = h.controlled
		if p == null or m.state != 1:
			return Vector2.ZERO
		if p.has_ball():
			var goal: Vector2 = h.team.goal_attacked()
			if p.position.distance_to(goal) < 330.0 and not h.charging:
				_shoot(i, 0.3)
			return (goal - p.position).normalized()
		var holder = m.ball.holder
		if holder and holder.team != h.team and p.position.distance_to(m.ball.position) < 40.0 and randf() < 0.1:
			_tap(i, "shoot")  # slide tackle
		return (m.ball.position - p.position).normalized()


func _still() -> Callable:
	return func() -> Vector2: return Vector2.ZERO


func _shoot(i: int, hold: float) -> void:
	var a := "shoot" if i == 0 else "p2_shoot"
	Input.action_press(a)
	await create_timer(hold).timeout
	Input.action_release(a)


func _tap(i: int, action: String) -> void:
	var a := action if i == 0 else "p2_" + action
	Input.action_press(a)
	await process_frame
	Input.action_release(a)


## Give player i's team the ball at `pos`, with that human controlling the receiver.
func _give(i: int, pos: Vector2):
	var team = m.humans[i].team
	var p = team.players[9]
	p.position = pos
	p.velocity = Vector2.ZERO
	p.facing = 2 if team.side > 0 else 6
	m.ball.stop_at(p.feet_front())
	m.ball.take(p)
	return p


func _wait_play() -> void:
	while m.state != 1:
		await process_frame
