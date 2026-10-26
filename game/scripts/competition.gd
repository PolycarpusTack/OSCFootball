class_name Competition
extends RefCounted
## What a cup (Cup) and a league season (Season) have in common: clubs, the humans' clubs (their
## fixtures are played on the pitch, the rest simulated by ResultSim), rounds of fixtures, the
## random state that simulates them, and a winner when it's done. A fixture is
## {home, away, result}; the result is {} until played (see ResultSim for its shape). Saved
## through to_dict(); Competition.from_dict() gives back the right kind.

var name := ""
var clubs: Array = []
var humans: Array = []  # the clubs people play: their fixtures are never simulated
var winner := ""
var done := false
var rng := RandomNumberGenerator.new()
var injuries := {}  # club -> {player name: fixtures still to miss}


func is_human(f: Dictionary) -> bool:
	return f.home in humans or f.away in humans


## This round's fixtures.
func current() -> Array:
	return []


## The next fixture a human plays in this round, or {} when there's none left.
func next_fixture() -> Dictionary:
	return {}


## The result of a fixture played on the pitch; false when it isn't one this competition takes.
func record(_f: Dictionary, _result: Dictionary) -> bool:
	return false


## Simulates the round's other fixtures and goes on to the next round (or ends). False while a
## human's fixture is still to be played.
func close_round() -> bool:
	return false


## A fixture played on the pitch: its result in, then the round closed.
func finish(f: Dictionary, result: Dictionary) -> void:
	if record(f, result):
		close_round()


## The names of `club`'s players who can't play this round: injured (and, in a Season, suspended).
func unavailable(club: String) -> Array:
	return injuries.get(club, {}).keys()


## After a round: the injured of the clubs that played it have missed one more fixture, then
## this round's injuries (Result.injuries) are added.
func _book_injuries(fixtures: Array) -> void:
	for f in fixtures:
		for club in [f.home, f.away]:
			var out: Dictionary = injuries.get(club, {})
			for player in out.keys():
				out[player] -= 1
				if out[player] <= 0:
					out.erase(player)
	for f in fixtures:
		for i in f.result.get("injuries", []):
			if int(i.fixtures) > 0:
				var out: Dictionary = injuries.get_or_add(f.result[i.side], {})
				out[i.name] = maxi(out.get(i.name, 0), int(i.fixtures))


## {club: {name: count}} from a save: JSON gives the counts back as floats.
static func _counts(saved: Dictionary) -> Dictionary:
	var out := {}
	for club in saved:
		out[club] = {}
		for player in saved[club]:
			out[club][player] = int(saved[club][player])
	return out


## Where it stands, for the save slots: the round, or who won it.
func status() -> String:
	return ""


func to_dict() -> Dictionary:
	return {}


static func from_dict(d: Dictionary) -> Competition:
	match d.get("kind"):
		"cup":
			return Cup.from_dict(d)
		"season":
			return Season.from_dict(d)
	return null
