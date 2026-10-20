extends SceneTree
## The effects sheet in play (Effects): a booking spins its card over the player, a player
## knocked down raises dust, the whistle stun sends out a ring, and each effect ends.
## godot --headless --path game -s res://tests/effects_test.gd
var failed := 0


func check(value: bool, message: String) -> void:
	if not value:
		failed += 1
		push_error(message)


## The effects now playing, by name.
func names(fx: Node) -> Array:
	return fx.playing.map(func(e): return e.name)


func _initialize() -> void:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)
	await create_timer(0.3).timeout
	var fx: Node = m.effects
	check(fx._anims.keys().size() == 5 and fx._sheet != null, "The five effects load: %s" % [fx._anims.keys()])

	fx.playing.clear()
	var p = m.away.players[7]
	var at: Vector2 = p.position
	m.book(p, false)
	var card: Dictionary = fx.playing.filter(func(e): return e.name == "yellow_card_spin").front()
	check(card.at == at and card.height > 0.0, "A yellow card spins over the booked player")
	m.book(p, false)  # a second yellow
	check(names(fx).has("red_card_spin"), "A red card spins for the second yellow, though he's off the pitch")

	fx.playing.clear()
	var q = m.home.players[5]
	m.knock_down(q, "fall")
	check(names(fx) == ["dust_puff"] and fx.playing[0].at == q.position, "A player knocked down raises dust")

	fx.playing.clear()
	m._whistle_stun(m.home)
	var ring: Array = fx.playing.filter(func(e): return e.name == "whistle_ring" and e.size > 1.0)
	check(ring.size() == 1 and ring[0].at == m.referee.position, "The whistle stun sends a ring out from the referee")

	fx.playing.clear()
	fx.play("impact_burst", Vector2(500, 300))
	check(fx.length_seconds("impact_burst") > 0.2, "The burst lasts its four frames at 12 fps")
	await create_timer(fx.length_seconds("impact_burst") + 0.15).timeout
	check(not names(fx).has("impact_burst"), "An effect ends after its frames")

	print("EFFECTS TEST %s" % ("PASSED" if failed == 0 else "FAILED (%d)" % failed))
	quit(0 if failed == 0 else 1)
