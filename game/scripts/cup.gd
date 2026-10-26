class_name Cup
extends Competition
## A knockout cup of 4, 8 or 16 clubs: a random draw, then rounds of ties. The humans' ties
## are played on the pitch (record()), the others simulated (ResultSim) when the round closes;
## the winners meet in bracket order (tie 1's winner against tie 2's, ...). Goes through a
## Dictionary for the save (to_dict / from_dict), the random state with it, so a loaded cup
## draws the same results as the one saved.

const SIZES := [4, 8, 16]
const ROUND_NAMES := {1: "FINAL", 2: "SEMI-FINALS", 4: "QUARTER-FINALS", 8: "ROUND OF 16"}

var rounds: Array = []  # of Arrays of fixtures; the last is the one being played


## A drawn cup, or null when `clubs` isn't 4, 8 or 16 different clubs.
static func create(cup_clubs: Array, human_clubs: Array, seed: int) -> Cup:
	var unique := {}
	for c in cup_clubs:
		unique[c] = true
	if cup_clubs.size() not in SIZES or unique.size() != cup_clubs.size():
		push_error("Cup: needs 4, 8 or 16 different clubs, got %d" % cup_clubs.size())
		return null
	var cup := Cup.new()
	cup.name = "OSCF CUP"
	cup.clubs = cup_clubs.duplicate()
	cup.humans = human_clubs.filter(func(c): return c in cup_clubs)
	cup.rng.seed = seed
	var drawn := cup_clubs.duplicate()
	for i in range(drawn.size() - 1, 0, -1):  # Fisher-Yates with the cup's own rng
		var j := cup.rng.randi_range(0, i)
		var t = drawn[i]
		drawn[i] = drawn[j]
		drawn[j] = t
	cup.rounds.append(_pair(drawn))
	return cup


static func _pair(order: Array) -> Array:
	var ties: Array = []
	for i in range(0, order.size(), 2):
		ties.append({"home": order[i], "away": order[i + 1], "result": {}})
	return ties


func current() -> Array:
	return rounds[-1]


func round_name() -> String:
	return ROUND_NAMES.get(current().size(), "ROUND %d" % rounds.size())


## The next tie a human plays in this round, or {} when there's none left.
func next_fixture() -> Dictionary:
	if done:
		return {}
	for f in current():
		if f.result.is_empty() and is_human(f):
			return f
	return {}


## The result of a tie played on the pitch; refused (false) without a winner.
func record(f: Dictionary, result: Dictionary) -> bool:
	if result.get("winner", "") == "":
		push_error("Cup: a tie needs a winner: %s v %s" % [f.home, f.away])
		return false
	f.result = result
	return true


func status() -> String:
	return "WON BY %s" % winner.to_upper() if done else round_name()


## Every human still in the cup has been knocked out (false when nobody is human).
func knocked_out() -> bool:
	if humans.is_empty():
		return false
	for f in current():
		if is_human(f) and (f.result.is_empty() or f.result.winner in humans):
			return false
	return true


## Simulates the round's other ties and draws the next round, or sets the winner after the
## final. False (and nothing changes) while a human's tie is still to be played.
func close_round() -> bool:
	if done or not next_fixture().is_empty():
		return false
	for f in current():
		if f.result.is_empty():
			f.result = ResultSim.play(f.home, f.away, true, rng, {}, {f.home: unavailable(f.home), f.away: unavailable(f.away)})
	_book_injuries(current())
	var winners: Array = current().map(func(f): return f.result.winner)
	if winners.size() == 1:
		winner = winners[0]
		done = true
	else:
		rounds.append(_pair(winners))
	return true


func to_dict() -> Dictionary:
	return {"version": 1, "kind": "cup", "name": name, "clubs": clubs, "humans": humans, "rounds": rounds,
		"winner": winner, "done": done, "injuries": injuries, "seed": str(rng.seed), "state": str(rng.state)}


static func from_dict(d: Dictionary) -> Cup:
	if d.get("kind") != "cup" or int(d.get("version", 0)) != 1:
		return null
	var cup := Cup.new()
	cup.name = d.name
	cup.clubs = d.clubs
	cup.humans = d.humans
	cup.rounds = d.rounds
	cup.winner = d.winner
	cup.done = d.done
	cup.injuries = _counts(d.get("injuries", {}))
	cup.rng.seed = int(d.seed)  # 64-bit, kept as text: JSON numbers are doubles
	cup.rng.state = int(d.state)
	return cup
