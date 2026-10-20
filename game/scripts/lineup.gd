class_name Lineup
extends RefCounted
## A club's team sheet: the starting XI, one player per slot of its formation (Team.FORMATIONS),
## and a bench of seven, as EA player ids from data/squads.json. Picked on the team management
## screen, saved per club in user://lineups.json, and handed to the match through Match's static
## vars (the match itself never reads the save, so tests always play the default XI).

const SQUADS := "res://data/squads.json"
const SAVE := "user://lineups.json"
const BENCH := 7
## Squad positions that suit a slot almost as well as its own (CM3 rates every player for every
## position; EA gives one position, so this stands in for the rest).
const GOOD_FIT := {
	"GK": [],
	"RB": ["RM", "CB"], "LB": ["LM", "CB"], "CB": ["CDM", "RB", "LB"],
	"RWB": ["RB", "RM", "RW"], "LWB": ["LB", "LM", "LW"],
	"CDM": ["CM", "CB"], "CM": ["CDM", "CAM"], "CAM": ["CM", "ST"],
	"RM": ["RW", "RB", "CM"], "LM": ["LW", "LB", "CM"], "RW": ["RM", "ST"], "LW": ["LM", "ST"],
	"ST": ["CAM", "RW", "LW"],
}


static func squads() -> Dictionary:
	if not FileAccess.file_exists(SQUADS):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(SQUADS))
	return data if data is Dictionary else {}


## How well a player listed at `pos` suits a slot played at `slot_pos`, 0..1. Only keepers keep
## goal, and keepers play nowhere else.
static func fit(pos: String, slot_pos: String) -> float:
	if pos == slot_pos:
		return 1.0
	if pos == "GK" or slot_pos == "GK":
		return 0.0
	return 0.85 if pos in GOOD_FIT.get(slot_pos, []) else 0.6


## The sheet a club starts with: for the default formation the squad file's own first eleven
## (data/squads.json lists the best 4-4-2 first), otherwise the best fit slot by slot; the bench
## the best keeper left plus the six best others.
static func auto_pick(squad: Array, formation: String) -> Dictionary:
	var xi: Array = []
	if formation == Team.DEFAULT_FORMATION and squad.size() >= 11:
		for i in 11:
			xi.append(int(squad[i].id))
	else:
		xi = _fill(squad, formation, [])
	return {"xi": xi, "bench": _best_bench(squad, xi)}


## The same eleven moved to the slots of another formation, each to where he fits best.
static func refit(squad: Array, xi: Array, formation: String) -> Array:
	var eleven := squad.filter(func(e): return int(e.id) in xi)
	return _fill(eleven, formation, [])


## `sheet` checked against the squad (it may be from an older squads.json): the XI and bench as
## given when every id is still there, else a fresh auto_pick.
static func checked(squad: Array, formation: String, sheet: Dictionary) -> Dictionary:
	var ids := squad.map(func(e): return int(e.id))
	var xi: Array = sheet.get("xi", [])
	var bench: Array = sheet.get("bench", [])
	var all := xi + bench
	var unique := {}
	for id in all:
		unique[int(id)] = true
	if xi.size() != 11 or bench.size() > BENCH or unique.size() != all.size() \
			or not all.all(func(id): return int(id) in ids):
		return auto_pick(squad, formation)
	return {"xi": xi.map(func(id): return int(id)), "bench": bench.map(func(id): return int(id))}


## The squad entries for `ids`, in that order.
static func entries(squad: Array, ids: Array) -> Array:
	var by_id := {}
	for e in squad:
		by_id[int(e.id)] = e
	return ids.map(func(id): return by_id[int(id)])


## The saved sheet for `club`: {"formation", "xi", "bench"}, or {} when there is none.
static func load_saved(club: String) -> Dictionary:
	if not FileAccess.file_exists(SAVE):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	return data.get(club, {}) if data is Dictionary else {}


static func save(club: String, formation: String, sheet: Dictionary) -> void:
	var data := {}
	if FileAccess.file_exists(SAVE):
		var old = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if old is Dictionary:
			data = old
	data[club] = {"formation": formation, "xi": sheet.xi, "bench": sheet.bench}
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))


## Slot by slot (keeper first, then in slot order), the unused player who suits it best:
## overall rating times fit.
static func _fill(squad: Array, formation: String, taken: Array) -> Array:
	var used := taken.duplicate()
	var xi: Array = []
	for slot in Team.slots_of(formation):
		var best = null
		var best_score := -1.0
		for e in squad:
			if int(e.id) in used:
				continue
			var score: float = float(e.overall) * fit(e.position, slot.pos)
			if score > best_score:
				best = e
				best_score = score
		if best == null:
			break
		xi.append(int(best.id))
		used.append(int(best.id))
	return xi


static func _best_bench(squad: Array, xi: Array) -> Array:
	var rest := squad.filter(func(e): return not int(e.id) in xi)
	rest.sort_custom(func(a, b): return a.overall > b.overall)
	var bench: Array = []
	for e in rest:
		if e.position == "GK":
			bench.append(int(e.id))
			break
	for e in rest:
		if bench.size() >= BENCH:
			break
		if e.position != "GK" and not int(e.id) in bench:
			bench.append(int(e.id))
	return bench
