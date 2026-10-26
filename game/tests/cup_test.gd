extends SceneTree
## The cup (Cup): the draw, rounds closed with the other ties simulated, a winner, saving.
## godot --headless --path game -s res://tests/cup_test.gd

func _initialize() -> void:
	var CupScript = load("res://scripts/cup.gd")  # loaded at run time: see classic_test.gd
	var ok := true
	var clubs: Array = ["Club Brugge", "Anderlecht", "KAA Gent", "Union", "KRC Genk", "Standard", "Antwerp", "Charleroi"]

	# AC1: 8 clubs, 4 ties, every club once, the human's club in one of them
	var cup = CupScript.create(clubs, ["Club Brugge"], 42)
	var first: Array = cup.rounds[0]
	var seen := {}
	for f in first:
		seen[f.home] = true
		seen[f.away] = true
	print("round 1 (%s): %s" % [cup.round_name(), first.map(func(f): return "%s-%s" % [f.home, f.away])])
	ok = ok and first.size() == 4 and seen.size() == 8 and seen.has("Club Brugge")

	# AC4: the human's tie is never simulated; the round can't close until it's played
	var mine: Dictionary = cup.next_fixture()
	print("next: %s v %s" % [mine.home, mine.away])
	ok = ok and "Club Brugge" in [mine.home, mine.away] and not cup.close_round()
	ok = ok and first.all(func(f): return f.result.is_empty())

	# the human wins his tie (a forced result), the round closes, the others are simulated
	var won := {"home": mine.home, "away": mine.away, "home_goals": 2 if mine.home == "Club Brugge" else 0,
		"away_goals": 0 if mine.home == "Club Brugge" else 2, "scorers": [], "cards": [], "extra_time": false,
		"pens": [], "winner": "Club Brugge"}
	cup.record(mine, won)
	ok = ok and cup.close_round()
	ok = ok and first.all(func(f): return not f.result.is_empty() and f.result.winner != "")

	# AC2: round 2 pairs the winners in bracket order: tie 1's winner against tie 2's
	var second: Array = cup.rounds[1]
	print("round 2 (%s): %s" % [cup.round_name(), second.map(func(f): return "%s-%s" % [f.home, f.away])])
	ok = ok and second.size() == 2 and cup.round_name() == "SEMI-FINALS"
	ok = ok and [second[0].home, second[0].away] == [first[0].result.winner, first[1].result.winner]
	ok = ok and [second[1].home, second[1].away] == [first[2].result.winner, first[3].result.winner]

	# saving: the cup goes through a Dictionary and back, the random draws to come included
	var saved: String = JSON.stringify(cup.to_dict())
	var copy = CupScript.from_dict(JSON.parse_string(saved))
	# (compared after a JSON round trip each: JSON reads every number back as a float)
	ok = ok and copy != null \
		and JSON.stringify(JSON.parse_string(JSON.stringify(copy.to_dict()))) == JSON.stringify(JSON.parse_string(saved))

	# the human loses the semi: knocked out, the rest is simulated to a winner
	var semi: Dictionary = cup.next_fixture()
	var other: String = semi.away if semi.home == "Club Brugge" else semi.home
	var lost := {"home": semi.home, "away": semi.away, "home_goals": 0 if semi.home == "Club Brugge" else 1,
		"away_goals": 1 if semi.home == "Club Brugge" else 0, "scorers": [], "cards": [], "extra_time": false,
		"pens": [], "winner": other}
	cup.record(semi, lost)
	ok = ok and cup.close_round() and cup.knocked_out() and cup.next_fixture().is_empty()
	# AC3: the final, simulated, gives the winner
	ok = ok and cup.round_name() == "FINAL" and cup.close_round()
	print("winner: %s, done %s, knocked out %s" % [cup.winner, cup.done, cup.knocked_out()])
	ok = ok and cup.done and cup.winner != "" and cup.winner != "Club Brugge"
	# ... and the copy, closed the same way, gets the same winner: the same random draws
	copy.record(copy.next_fixture(), lost)
	copy.close_round()
	copy.close_round()
	print("the saved copy's winner: %s" % copy.winner)
	ok = ok and copy.winner == cup.winner

	# AC4 (alt): two humans, both flagged, neither simulated
	var two = CupScript.create(clubs.slice(0, 4), ["Club Brugge", "Anderlecht"], 1)
	var humans_ties: int = two.rounds[0].filter(func(f): return two.is_human(f)).size()
	ok = ok and humans_ties >= 1 and not two.close_round()

	# AC5: a size other than 4, 8 or 16 is refused
	var bad = CupScript.create(clubs.slice(0, 6), [], 1)
	print("6 clubs: %s" % bad)
	ok = ok and bad == null

	print("CUP TEST PASSED" if ok else "CUP TEST FAILED")
	quit(0 if ok else 1)
