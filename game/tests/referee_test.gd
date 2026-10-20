extends SceneTree
## Chaos referee: the view cone (unseen fouls go unpunished), the discipline meter (seen
## fouls and body checks fill it; full is a booking), his mood with each side (angry, he
## books faster), "Sorry, ref!" (special just after your foul: half of it taken back), the
## dive, the captain, the whistle stun and the bribe.
## godot --headless --path game -s res://tests/referee_test.gd

var m: Node
var events := []


func _initialize() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	m.autoplay = true
	root.add_child(m)
	m.event.connect(func(kind, t): events.append("%s:%s" % [kind, t.short]))
	await create_timer(1.6).timeout
	var ok := true
	var c: Vector2 = Pitch.field_rect().get_center()
	var hacker = m.away.players[6]
	var victim = m.home.players[6]

	# his gaze turns to the ball
	await _play()
	m.referee_gaze = (m.referee.position - m.ball.position).normalized()  # looking away from it
	await create_timer(1.5).timeout
	var off := rad_to_deg(absf(m.referee_gaze.angle_to(m.ball.position - m.referee.position)))
	print("looking away from the ball, 1.5 s later his gaze is %.0f° off it" % off)
	ok = ok and off < 20.0

	# a foul he sees: a free kick, and 30 on the meter for a foul from the front
	await _play()
	_look_at(c)
	victim.position = c
	events.clear()
	m._foul(hacker, victim, false)
	print("seen foul from the front: events %s, discipline %.0f" % [events, hacker.discipline])
	ok = ok and events.has("foul:AND") and events.has("free kick:BRU") and is_equal_approx(hacker.discipline, 30.0)

	# a foul behind his back, 20 m away: play on, nothing on the meter
	await _play()
	var before: float = hacker.discipline
	m.referee.position = c + Vector2(Pitch.m(20.0), 0.0)
	m.referee_gaze = Vector2.RIGHT  # away from the centre spot
	victim.position = c
	events.clear()
	m._foul(hacker, victim, false)
	print("foul behind his back: events %s, state %d (1 = play on), discipline %.0f -> %.0f" % [events, m.state, before, hacker.discipline])
	ok = ok and events == ["unseen foul:AND"] and m.state == 1 and is_equal_approx(hacker.discipline, before)

	# ... but right next to him he sees it whichever way he looks
	m.referee.position = c + Vector2(Pitch.m(4.0), 0.0)
	m.referee_gaze = Vector2.RIGHT
	print("4 m from him, looking away: sees it %s" % m.referee_sees(c))
	ok = ok and m.referee_sees(c)

	# a seen body check fills it too
	await _play()
	m.ref_mood.clear()  # calm: the meter fills at the plain rate
	_look_at(c)
	var barger = m.away.players[7]
	var holder = m.home.players[9]
	holder.position = c
	m.ball.stop_at(holder.feet_front())
	m.ball.take(holder)
	m._body_check_hits(barger, holder)
	print("seen body check: discipline %.0f" % barger.discipline)
	ok = ok and is_equal_approx(barger.discipline, 20.0)

	# the meter full: a yellow, and it starts again; full again: the second yellow, off
	await _play()
	_look_at(c)
	victim.position = c
	hacker.discipline = 80.0
	events.clear()
	m._foul(hacker, victim, false)
	var first := events.filter(func(e): return "card" in e)
	var after_first: float = hacker.discipline
	await _play()
	_look_at(c)
	victim.position = c
	hacker.discipline = 80.0
	events.clear()
	m._foul(hacker, victim, false)
	var second := events.filter(func(e): return "card" in e)
	print("meter full: %s, then at %.0f; full again: %s, sent off %s" % [first, after_first, second, hacker.sent_off])
	ok = ok and first == ["yellow card:AND"] and after_first == 0.0 and second == ["red card:AND"] and hacker.sent_off

	# it cools down in play
	var cooler = m.away.players[8]
	cooler.discipline = 50.0
	await _play()
	await create_timer(2.0).timeout
	print("cooling: 50 -> %.1f after 2 s of play" % cooler.discipline)
	ok = ok and cooler.discipline < 48.5 and cooler.discipline > 45.0

	# his mood: a seen foul makes him angrier with that side, and the next one counts for more
	await _play()
	m.ref_mood.clear()
	var rough = m.away.players[3]
	_look_at(c)
	victim.position = c
	m._foul(rough, victim, false)
	var mood: float = m.ref_mood.get(m.away, 0.0)
	await _play()
	_look_at(c)
	victim.position = c
	var before_second: float = rough.discipline
	m._foul(rough, victim, false)
	print("mood with AND after a foul: %.0f; the next foul adds %.1f (30 when calm)" % [mood, rough.discipline - before_second])
	ok = ok and is_equal_approx(mood, 15.0) and rough.discipline - before_second > 30.0

	# "Sorry, ref!" in time: a booking he'd earned becomes a warning (Brugge is the human side)
	m.autoplay = false
	var sorry = m.home.players[6]
	var foe = m.away.players[6]
	await _play()
	m.ref_mood.clear()
	_look_at(c)
	foe.position = c
	sorry.discipline = 90.0
	events.clear()
	m._foul(sorry, foe, false)
	await _press("special")
	await create_timer(0.8).timeout
	print("sorry in time: events %s, discipline %.0f, booked %s" % [events, sorry.discipline, sorry.yellow])
	ok = ok and events.has("sorry ref:BRU") and not sorry.yellow and is_equal_approx(sorry.discipline, m.WARNING_AT)

	# too slow: booked; and "sorry" at a stoppage with nothing to be sorry for is dissent
	var late = m.home.players[7]
	await _play()
	m.ref_mood.clear()
	_look_at(c)
	foe.position = c
	late.discipline = 90.0
	events.clear()
	m._foul(late, foe, false)
	await create_timer(0.8).timeout
	var calm: float = m.ref_mood.get(m.home, 0.0)
	await _press("special")
	print("no sorry: events %s; then sorry too late: mood with BRU %.0f -> %.0f" % [events, calm, m.ref_mood.get(m.home, 0.0)])
	ok = ok and events.has("yellow card:BRU") and late.yellow and events.has("dissent:BRU") \
		and is_equal_approx(m.ref_mood.get(m.home, 0.0), calm + m.DISSENT)
	m.autoplay = true
	m.chaos_actions.ai_enabled = false  # from here the moods he's set to would send the AI's captain

	# the dive: unseen, nothing but the ball rolling free
	var diver = m.home.players[8]
	var marker = m.away.players[8]
	await _play()
	m.ref_mood.clear()
	diver.position = c
	marker.position = c + Vector2(Pitch.m(1.5), 0.0)
	m.referee.position = c + Vector2(Pitch.m(20.0), 0.0)
	m.referee_gaze = Vector2.RIGHT
	events.clear()
	m.dive(diver)
	print("unseen dive: events %s, state %d" % [events, m.state])
	ok = ok and events.is_empty() and m.state == 1

	# seen, and he falls for it: a foul on the diver by the man next to him
	_look_at(c)
	_seed_for(diver, true)
	m.dive(diver)
	print("dive bought (odds %.2f): events %s" % [m.dive_odds(diver), events])
	ok = ok and events.has("dive bought:BRU") and events.has("foul:AND") and events.has("free kick:BRU")

	# seen through: a yellow for diving, the free kick the other way, and he's angrier
	await _play()
	m.ref_mood.clear()
	diver.position = c
	marker.position = c + Vector2(Pitch.m(1.5), 0.0)
	_look_at(c)
	events.clear()
	_seed_for(diver, false)
	m.dive(diver)
	print("dive seen through: events %s, mood with BRU %.0f" % [events, m.ref_mood.get(m.home, 0.0)])
	ok = ok and events.has("dive:BRU") and events.has("free kick:AND") and events.has("yellow card:BRU") \
		and diver.yellow and m.ref_mood.get(m.home, 0.0) > 0.0

	# an angry referee is harder to fool; nobody near, no dive
	var calm_odds: float = m.dive_odds(diver)
	m.ref_mood[m.home] = m.MOOD_FULL
	print("dive odds calm %.2f, furious %.2f" % [calm_odds, m.dive_odds(diver)])
	ok = ok and m.dive_odds(diver) < calm_odds * 0.5
	await _play()
	diver.position = c
	for o in m.away.players:
		o.position = c + Vector2(0.0, Pitch.m(10.0))
	print("dive with nobody near: '%s'" % m.chaos_actions.unavailable(diver, "dive"))
	ok = ok and m.chaos_actions.unavailable(diver, "dive") != ""

	# the captain: the steadiest head on the pitch, and near the referee he calms him down
	var cap = m.captain(m.home)
	var best := 0.0
	for q in m.home.players.slice(1):
		best = maxf(best, q.stats.get("composure", 67.5))
	print("BRU captain %s, composure %s (best outfield %s)" % [cap.display_name, cap.stats.get("composure"), best])
	ok = ok and cap.role != "G" and cap.stats.get("composure", 67.5) == best
	m.ref_mood[m.home] = 60.0
	cap.position = m.referee.position + Vector2(Pitch.m(40.0), 0.0)
	var far: String = m.chaos_actions.unavailable(cap, "captain")
	cap.position = m.referee.position + Vector2(Pitch.m(10.0), 0.0)
	var near: String = m.chaos_actions.unavailable(cap, "captain")
	m.calm_referee(m.home)
	print("captain 40 m away: '%s'; 10 m: '%s'; after a word, mood 60 -> %.0f" % [far, near, m.ref_mood.get(m.home, 0.0)])
	ok = ok and far != "" and near == "" and is_equal_approx(m.ref_mood.get(m.home, 0.0), 60.0 - m.CAPTAIN_CALMS)
	m.ref_mood[m.home] = 0.0
	print("calm referee, captain has nothing to do: '%s'" % m.chaos_actions.unavailable(cap, "captain"))
	ok = ok and m.chaos_actions.unavailable(cap, "captain") != ""

	# furious with a side, he fumes for all to see, then blows his top: that side's players
	# near him are stunned, the others (and the other side) aren't
	await _play()
	var near_mate = m.home.players[7]
	var far_mate = m.home.players[5]
	var near_foe = m.away.players[7]
	near_mate.position = m.referee.position + Vector2(Pitch.m(3.0), 0.0)
	near_foe.position = m.referee.position + Vector2(-Pitch.m(3.0), 0.0)
	far_mate.position = m.referee.position + Vector2(Pitch.m(45.0), 0.0)
	m.ref_mood.clear()
	m.ref_mood[m.home] = m.MOOD_FULL
	events.clear()
	await create_timer(0.5).timeout
	var fuming: bool = events.has("ref fuming:BRU") and not events.has("whistle stun:BRU") and not m.chaos_actions.stuns.has(near_mate)
	await create_timer(m.BLOW_UP_TELL).timeout
	var stunned: Dictionary = m.chaos_actions.stuns
	print("furious with BRU: fuming first %s; then events %s, stunned: near %s, far %s, AND near %s; mood %.0f" % [
		fuming, events, stunned.has(near_mate), stunned.has(far_mate), stunned.has(near_foe), m.ref_mood.get(m.home, 0.0)])
	ok = ok and fuming and events.has("whistle stun:BRU") and stunned.has(near_mate) and not stunned.has(far_mate) \
		and not stunned.has(near_foe) and absf(m.ref_mood.get(m.home, 0.0) - m.BLOWN_MOOD) < 1.0  # cooling since

	# the captain talks him down in time: no stun
	await _play()
	m.ref_mood[m.home] = m.MOOD_FULL
	events.clear()
	await create_timer(0.3).timeout
	m.calm_referee(m.home)
	await create_timer(m.BLOW_UP_TELL + 0.3).timeout
	print("fuming, then the captain: events %s" % [events])
	ok = ok and events.has("ref fuming:BRU") and not events.has("whistle stun:BRU")

	# the bribe: needs a full bar and an envelope's distance
	await _play()
	var briber = m.home.players[7]
	m.home.energy = 100.0
	briber.position = m.referee.position + Vector2(Pitch.m(20.0), 0.0)
	var too_far: String = m.chaos_actions.unavailable(briber, "bribe")
	briber.position = m.referee.position + Vector2(Pitch.m(5.0), 0.0)
	var close: String = m.chaos_actions.unavailable(briber, "bribe")
	print("bribe from 20 m: '%s'; from 5 m: '%s'" % [too_far, close])
	ok = ok and too_far != "" and close == ""

	# bought: he forgets his anger, misses the briber's offences, waves its fouls on and
	# falls for its dives
	m.ref_mood[m.home] = 60.0
	_seed_bribe(false)
	m.bribe(m.home)
	events.clear()
	var bruiser = m.home.players[6]
	var hacked = m.away.players[6]
	bruiser.discipline = 0.0
	hacked.position = c
	bruiser.position = c - Vector2(16.0, 0.0)
	_look_at(c)
	m.offence(bruiser, c, "body check")
	m._foul(bruiser, hacked)
	print("bribed: mood %.0f, discipline after a body check %.0f, foul: events %s, state %d, dive odds %.2f, again: '%s'" % [
		m.ref_mood.get(m.home, 0.0), bruiser.discipline, events, m.state, m.dive_odds(diver), m.chaos_actions.unavailable(briber, "bribe")])
	ok = ok and m.ref_mood.get(m.home, 0.0) == 0.0 and bruiser.discipline == 0.0 and events.has("bribed call:BRU") \
		and not events.has("free kick:AND") and m.state == 1 and m.dive_odds(diver) == 1.0 \
		and m.chaos_actions.unavailable(briber, "bribe") != ""
	m.bribed[m.home] = 0.1
	await create_timer(0.3).timeout
	print("bribe run out: %s" % [m.bribed])
	ok = ok and not m.bribed.has(m.home)

	# caught: the linesman flags it, a penalty against the briber and a furious referee
	await _play()
	_seed_bribe(true)
	m.bribe(m.home)
	var flagged: bool = m._bribe_flag.has(m.home)
	m._bribe_flag[m.home] = 0.05  # not BRIBE_FLAG: a goal meanwhile would stop the clock
	events.clear()
	await create_timer(0.3).timeout
	print("bribe flagged: events %s, state %d, still bribed %s, mood %.0f" % [events, m.state, m.bribed.has(m.home), m.ref_mood.get(m.home, 0.0)])
	ok = ok and flagged and events.has("bribe caught:BRU") and events.has("penalty:AND") and m.state == 3 \
		and not m.bribed.has(m.home) and m.ref_mood.get(m.home, 0.0) == m.MOOD_FULL

	print("REFEREE TEST ", "PASSED" if ok else "FAILED")
	quit(0 if ok else 1)


## The referee 10 m from `pos`, looking straight at it.
func _look_at(pos: Vector2) -> void:
	m.referee.position = pos + Vector2(0.0, -Pitch.m(10.0))
	m.referee_gaze = Vector2.DOWN


## Wait for open play.
func _play() -> void:
	while m.state != 1:
		await physics_frame
	await physics_frame


## Press and release one of player 1's buttons.
func _press(action: String) -> void:
	Input.action_press(action)
	await physics_frame
	Input.action_release(action)
	await physics_frame


## Seed the random numbers so the next one does (`fooled`) or doesn't fool the referee
## with `diver`'s dive.
func _seed_for(diver, fooled: bool) -> void:
	for s in 1000:
		seed(s)
		if (randf() < m.dive_odds(diver)) == fooled:
			seed(s)
			return


## Seed the random numbers so the next bribe is (`caught`) or isn't flagged by the linesman.
func _seed_bribe(caught: bool) -> void:
	for s in 1000:
		seed(s)
		if (randf() < m.BRIBE_CAUGHT) == caught:
			seed(s)
			return
