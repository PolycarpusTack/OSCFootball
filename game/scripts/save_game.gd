class_name SaveGame
extends RefCounted
## Saved competitions: three slots, one JSON file each in user://saves/ (ADR-002,
## docs/gpm/backlog-player.md): {version, saved (the date), competition (Competition.to_dict())}. A save
## is written to a .tmp file first and then renamed over the slot, so a write that breaks off
## leaves the old save. A file that doesn't read (bad JSON, another version) is refused: null.

const SLOTS := 3
const VERSION := 1

static var dir := "user://saves"  # tests point it elsewhere
static var fail_writes := false  # tests: the next writes break off halfway


static func path(slot: int) -> String:
	return "%s/slot_%d.json" % [dir, slot]


static func save(slot: int, competition: Competition) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var text := JSON.stringify({"version": VERSION, "saved": Time.get_datetime_string_from_system(false, true),
		"competition": competition.to_dict()}, "\t")
	var tmp := path(slot) + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("SaveGame: can't write %s" % tmp)
		return false
	if fail_writes:
		f.store_string(text.left(text.length() / 2))
		f.close()
		return false
	f.store_string(text)
	f.close()
	return DirAccess.rename_absolute(tmp, path(slot)) == OK


## The competition in `slot` (a Cup or a Season), or null: no file, or one that doesn't read.
static func load_slot(slot: int) -> Competition:
	var d := _read(slot)
	return Competition.from_dict(d.competition) if d.get("competition") is Dictionary else null


## Per slot, for the CONTINUE list: {} when empty, {unreadable: true}, or
## {name, club, round, date}.
static func list() -> Array:
	var slots: Array = []
	for slot in range(1, SLOTS + 1):
		if not FileAccess.file_exists(path(slot)):
			slots.append({})
			continue
		var c := load_slot(slot)
		if c == null:
			slots.append({"unreadable": true})
			continue
		slots.append({"name": c.name, "club": c.humans[0] if not c.humans.is_empty() else "",
			"round": c.status(), "date": _read(slot).saved})
	return slots


static func delete(slot: int) -> void:
	for p in [path(slot), path(slot) + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


static func _read(slot: int) -> Dictionary:
	if not FileAccess.file_exists(path(slot)):
		return {}
	var json := JSON.new()  # not JSON.parse_string: a bad file is expected here, not an error to print
	if json.parse(FileAccess.get_file_as_string(path(slot))) != OK:
		return {}
	var d = json.data
	if not d is Dictionary or int(d.get("version", 0)) != VERSION:
		return {}
	return d
