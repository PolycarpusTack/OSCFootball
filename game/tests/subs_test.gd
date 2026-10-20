extends SceneTree
## Condition and substitutions: running wears a player's condition down over the match (more
## with poor stamina) and his fatigue can't recover past it; the substitutions screen asks for
## a sub, who comes on at the next stoppage in his man's slot, fresh, while the man is parked
## off the pitch; three per side, none for a sent-off player.
## godot --headless --path game -s res://tests/subs_test.gd

func _initialize() -> void:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await create_timer(1.6).timeout
	var ok := true

	# condition: 45 match minutes of running
	var fit = m.home.players[6]
	var unfit = m.home.players[7]
	fit.stats = {"stamina": 95}
	unfit.stats = {"stamina": 40}
	for p in [fit, unfit]:
		p.velocity = Vector2(200, 0)
		p.wear(45.0)
		p.fatigue = 0.0
		p.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame
	var floor_kept: bool = unfit.fatigue >= 1.0 - unfit.condition - 0.001
	print("45 minutes running: condition %.2f with stamina 95, %.2f with 40; fatigue held at %.2f" % [
		fit.condition, unfit.condition, unfit.fatigue])
	ok = ok and fit.condition > unfit.condition and fit.condition < 1.0 and floor_kept

	# the screen: right back off, the first sub on
	var t = m.home
	var bench_before: int = t.bench.size()
	var going_off = t.players[1]
	var coming_on: Dictionary = t.bench[0]
	var menu = load("res://scripts/subs_menu.gd").new(m, [t])
	root.add_child(menu)
	await process_frame
	menu._row = 1
	menu._select()
	menu._select()  # first bench row is where the cursor went
	var asked: bool = t.pending.size() == 1 and t.pending[0][0] == 1 and t.pending[0][1] == coming_on
	menu._close()
	print("screen: substitution asked for %s" % asked)
	ok = ok and asked

	# it happens at the next stoppage
	var role: String = going_off.role
	m._award_restart("throw-in", t, Vector2(400, 0))
	var on = t.players[1]
	var made: bool = on != going_off and on.display_name == coming_on.name and on.role == role \
		and on.condition == 1.0 and not going_off.visible and going_off in t.subbed_off \
		and t.bench.size() == bench_before - 1 and t.subs_left == 2 and t.pending.is_empty()
	print("at the throw-in: %s on for %s %s, %d subs left" % [on.display_name, going_off.display_name, made, t.subs_left])
	ok = ok and made

	# no sub for a sent-off man; and only three
	m.book(t.players[8], true)
	var refused: bool = not m.request_sub(t, 8, t.bench[0])
	var allowed := 0
	for slot in [2, 3, 4]:
		if m.request_sub(t, slot, t.bench[slot - 2]):
			allowed += 1
	print("sent-off man refused %s; %d more allowed with 2 left" % [refused, allowed])
	ok = ok and refused and allowed == 2

	print("SUBS TEST PASSED" if ok else "SUBS TEST FAILED")
	quit(0 if ok else 1)
