extends SceneTree
## Formations: every one is a full side with the keeper in slot 0 and the two most advanced
## players in slots 9 and 10; a side lines up in the formation it was given; off the ball it is
## wide and high with the ball and narrow and deep without, slides toward the ball, and the
## back line follows the ball up and down less than the forwards.
## godot --headless --path game -s res://tests/formations_test.gd

func _initialize() -> void:
	var match_script: GDScript = load("res://scripts/main.gd")  # Match; the class can't be named here
	var team_script: GDScript = load("res://scripts/team.gd")
	var ai = load("res://scripts/ai.gd")
	var ok := true

	# the data: 11 slots, keeper first, slots 9 and 10 at least as far up as anyone
	for f in team_script.FORMATIONS:
		var slots: Array = team_script.FORMATIONS[f]
		var keeper_first: bool = slots.size() == 11 and slots[0].role == "G"
		var front := true
		for i in range(1, 9):
			front = front and slots[i].spot.x <= minf(slots[9].spot.x, slots[10].spot.x) + 0.001
		print("%s: 11 with the keeper first %s, slots 9 and 10 the most advanced %s" % [f, keeper_first, front])
		ok = ok and keeper_first and front

	# a side lines up in its formation
	match_script.home_formation = "4-3-3"
	match_script.offside_on = false  # spots as they are, not pulled back level with the line
	var m: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await create_timer(1.6).timeout
	m.state = 5  # HALF_TIME with a long pause: freeze the AI
	m._state_left = 1e9
	var roles := {}
	for p in m.home.players:
		roles[p.role] = roles.get(p.role, 0) + 1
	var home_right: bool = m.home.players[1].position.y > Pitch.field_rect().size.y / 2.0
	var away_right: bool = m.away.players[1].position.y < Pitch.field_rect().size.y / 2.0
	print("4-3-3 lines up as %s, slot 9 is %s; right backs on their right flank: home %s, away %s" % [
		roles, m.home.players[9].role, home_right, away_right])
	ok = ok and roles == {"G": 1, "D": 4, "M": 3, "F": 3} and m.home.players[9].role == "F" \
		and home_right and away_right

	# off-the-ball shape, for every formation (the home side's players take its spots)
	var field: Rect2 = Pitch.field_rect()
	var at := func(fx: float, fy: float) -> void: m.ball.position = Vector2(fx * field.size.x, fy * field.size.y)
	for f in team_script.FORMATIONS:
		var slots: Array = team_script.FORMATIONS[f]
		var outfield: Array = m.home.players.slice(1)
		for i in 11:
			var p = m.home.players[i]
			p.role = slots[i].role
			p.home = slots[i].spot
			p.attack_spot = slots[i].attack
			p.defend_spot = slots[i].defend
		at.call(0.5, 0.5)
		var with_ball := _shape(outfield, m, ai, true, field)
		var without := _shape(outfield, m, ai, false, field)
		var wider_higher: bool = with_ball.width > without.width and with_ball.depth > without.depth
		# ball out on slot 1's touchline (the home side attacks right, so its right flank is at the bottom)
		var slides := true
		for p in outfield:
			at.call(0.5, 0.9)
			var flank: Vector2 = _spot(p, m, ai, false, field)
			slides = slides and flank.y < _centre_spot(p, m, ai, field).y
		# ball from 30 % to 70 % up the pitch: the defenders' spots move less than the forwards'
		var moved := {"D": [], "F": []}
		for p in outfield:
			if p.role in moved:
				at.call(0.3, 0.5)
				var back: Vector2 = _spot(p, m, ai, false, field)
				at.call(0.7, 0.5)
				moved[p.role].append(_spot(p, m, ai, false, field).x - back.x)
		var back_line_stays: bool = moved.D.max() < moved.F.min()
		print("%s: with the ball %.2f wide, %.2f up; without %.2f wide, %.2f up; slides across %s; back line follows less %s" % [
			f, with_ball.width, with_ball.depth, without.width, without.depth, slides, back_line_stays])
		ok = ok and wider_higher and slides and back_line_stays

	match_script.home_formation = "4-4-2"
	match_script.offside_on = true
	print("FORMATIONS TEST PASSED" if ok else "FORMATIONS TEST FAILED")
	quit(0 if ok else 1)


## Spot of `p` as a pitch fraction from his own end (x up the pitch, y across from his right flank).
func _spot(p, m, ai, attacking: bool, field: Rect2) -> Vector2:
	var s: Vector2 = ai.hold_spot(p, m, attacking) / field.size
	return Vector2(s.x, 1.0 - s.y) if p.team.side > 0 else Vector2(1.0 - s.x, s.y)


## Spot of `p` without the ball, the ball in the centre circle.
func _centre_spot(p, m, ai, field: Rect2) -> Vector2:
	m.ball.position = field.size / 2.0
	return _spot(p, m, ai, false, field)


## Width (across) and mean depth (up the pitch) of the outfield players' spots.
func _shape(outfield: Array, m, ai, attacking: bool, field: Rect2) -> Dictionary:
	var ys := []
	var depth := 0.0
	for p in outfield:
		var s: Vector2 = _spot(p, m, ai, attacking, field)
		ys.append(s.y)
		depth += s.x / outfield.size()
	return {"width": ys.max() - ys.min(), "depth": depth}
