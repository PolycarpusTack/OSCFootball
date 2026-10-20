extends Node
## Player animations from FIFA 96, built by tools/build_godot_assets.py, and the referee's
## own art ("ref_*", RGBA, drawn without the kit shader), built by tools/pack_oscf_referee.gd.
##
## The original draws five directions (away, up-right, right, down-right,
## toward camera); the three left-facing ones are the right-facing frames
## mirrored. Facing here is 0..7 clockwise from "up".

const SHEET_DIR := "res://assets/sprites/players/"
const REFEREE_DIR := "res://assets/sprites/oscf_roles/referee/"
const TICKS_PER_SECOND := 30.0
const DRAWN_DIR := [0, 2, 4, 6, 8, 6, 4, 2]
const FACING_VECTORS := [
	Vector2(0, -1), Vector2(0.7071, -0.7071), Vector2(1, 0), Vector2(0.7071, 0.7071),
	Vector2(0, 1), Vector2(-0.7071, 0.7071), Vector2(-1, 0), Vector2(-0.7071, -0.7071),
]

# anim name -> { drawn direction (int) -> Array of frames {tex, ax, ay, w, t} }
var _anims := {}


func _ready() -> void:
	_load(SHEET_DIR)
	_load(REFEREE_DIR)


## Every animation in `dir`: animations.json plus one sheet <anim>.png per animation.
func _load(dir: String) -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "animations.json"))
	for anim in meta:
		var sheet: Texture2D = load(dir + anim + ".png")
		var dirs := {}
		for d in meta[anim]:
			var frames := []
			for f in meta[anim][d]:
				var tex := AtlasTexture.new()
				tex.atlas = sheet
				tex.region = Rect2(f.x, f.y, f.w, f.h)
				frames.append({"tex": tex, "ax": f.ax, "ay": f.ay, "w": f.w, "t": f.t})
			dirs[int(d)] = frames
		_anims[anim] = dirs


func has(anim: String) -> bool:
	return _anims.has(anim)


func names() -> Array:
	return _anims.keys()


func length_seconds(anim: String) -> float:
	return _length_ticks(anim) / TICKS_PER_SECOND


func facing_from(v: Vector2) -> int:
	# angle 0 = up, clockwise
	var a := fposmod(atan2(v.x, -v.y), TAU)
	return int(round(a / (TAU / 8.0))) % 8


## Frame to show for `anim` at `seconds` into it. Returns {tex, offset, flip};
## offset puts the player's feet on the node's origin.
func frame_at(anim: String, facing: int, seconds: float, loop := true) -> Dictionary:
	var frames: Array = _frames_for(anim, DRAWN_DIR[facing])
	var tick := seconds * TICKS_PER_SECOND
	if loop:
		tick = fmod(tick, _length_ticks(anim))
	var f: Dictionary = frames[0]
	for fr in frames:
		if fr.t <= tick:
			f = fr
	var flip := facing >= 5
	var off := Vector2(-(f.w - f.ax) if flip else -f.ax, -f.ay)
	return {"tex": f.tex, "offset": off, "flip": flip}


## Some animations were only drawn for a few directions (e.g. goalkeeper dives
## to one side); use the nearest one that exists.
func _frames_for(anim: String, drawn_dir: int) -> Array:
	var dirs: Dictionary = _anims[anim]
	var best: int = dirs.keys()[0]
	for d in dirs:
		if absi(d - drawn_dir) < absi(best - drawn_dir):
			best = d
	return dirs[best]


func _length_ticks(anim: String) -> float:
	var frames: Array = _frames_for(anim, 8)
	var last: float = frames[-1].t
	var step: float = last - frames[-2].t if frames.size() > 1 else 4.0
	return last + step
