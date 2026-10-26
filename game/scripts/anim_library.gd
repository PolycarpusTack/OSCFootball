extends Node
## Player animations from FIFA 96, built by tools/build_godot_assets.py, and the referee's
## own art ("ref_*", RGBA, drawn without the kit shader), built by tools/pack_oscf_referee.gd.
## With the Rendered player art (Match.rendered) the animations rendered by tools/blender
## (assets/sprites/oscf_rendered, palette-indexed with their own palette) stand in for the
## FIFA 96 ones of the same name; the rest stay FIFA 96's.
## The Chaos line moves (brand/sprites/line_actions/manifest.json) are rendered too; in the
## Pixel view each plays the nearest FIFA 96 animation (PIXEL_LINE_MOVES) instead, so a
## special looks like the rest of the match. Either way it lasts as long as its drawn art,
## which the move's timing is tuned to.
##
## The original draws five directions (away, up-right, right, down-right,
## toward camera); the three left-facing ones are the right-facing frames
## mirrored. Facing here is 0..7 clockwise from "up".

const SHEET_DIR := "res://assets/sprites/players/"
const REFEREE_DIR := "res://assets/sprites/oscf_roles/referee/"
const LINE_ACTIONS_DIR := "res://brand/sprites/line_actions/"
const RENDERED_DIR := "res://assets/sprites/oscf_rendered/"
const LINE_ACTIONS_FPS := 10.0  # the manifest's frame durations are weights at this rate
const PIXEL_LINE_MOVES := {
	"power_strike": "shoot", "bulldozer_clear": "divehed", "grapple_tackle": "push",
	"laser_pass": "kick", "whirlwind_turn": "rainbow", "cannon_punt": "vollkck",
	"rising_fist": "gpunchu", "stepover_storm": "dummyrf",
}
const TICKS_PER_SECOND := 30.0
const DRAWN_DIR := [0, 2, 4, 6, 8, 6, 4, 2]
const FACING_HOLD := deg_to_rad(8.0)  # past the line between two directions before the facing turns
const FACING_VECTORS := [
	Vector2(0, -1), Vector2(0.7071, -0.7071), Vector2(1, 0), Vector2(0.7071, 0.7071),
	Vector2(0, 1), Vector2(-0.7071, 0.7071), Vector2(-1, 0), Vector2(-0.7071, -0.7071),
]

# anim name -> { drawn direction (int) -> Array of frames {tex, ax, ay, w, t} }
var _anims := {}
var _own_art := {}  # anim names drawn already coloured (no kit shader)
var _lengths := {}  # anim name -> length in ticks, where the last frame's own length is known
var _rendered := {}  # anim name -> { drawn direction -> frames }, the Rendered player art


func _ready() -> void:
	_load(SHEET_DIR)
	_load(REFEREE_DIR, true)
	_load_line_actions()  # before the Rendered art: it times its stand-ins on FIFA 96's frames
	_rendered = _read(RENDERED_DIR)


## Every animation in `dir`: animations.json plus one sheet <anim>.png per animation.
func _load(dir: String, own := false) -> void:
	var anims := _read(dir)
	_anims.merge(anims, true)
	if own:
		for anim in anims:
			_own_art[anim] = true


## { anim name -> { drawn direction -> frames } } from `dir`.
func _read(dir: String) -> Dictionary:
	var out := {}
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
		out[anim] = dirs
	return out


## The line moves for the Pixel view: their FIFA 96 stand-in, its frames spread over the
## length of the drawn art (the sum of the manifest's frame durations).
func _load_line_actions() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LINE_ACTIONS_DIR + "manifest.json"))
	for anim: String in manifest.moves:
		var length := 0.0
		for d: float in manifest.moves[anim].duration:
			length += d / LINE_ACTIONS_FPS * TICKS_PER_SECOND
		var standin: String = PIXEL_LINE_MOVES[anim]
		var stretch := length / _length_ticks(standin)
		var dirs := {}
		for d: int in _anims[standin]:
			dirs[d] = _anims[standin][d].map(func(f): return f.merged({"t": f.t * stretch}, true))
		_anims[anim] = dirs
		_lengths[anim] = length


func own_art(anim: String) -> bool:
	return _own_art.has(anim)


## `anim` is drawn from the Rendered player art (the setting is on and it's been rendered).
func rendered(anim: String) -> bool:
	return Match.rendered and _rendered.has(anim)


func has(anim: String) -> bool:
	return _anims.has(anim)


func names() -> Array:
	return _anims.keys()


func length_seconds(anim: String) -> float:
	return _length_ticks(anim) / TICKS_PER_SECOND


## The nearest of the 8 directions to `v`; or `held` until `v` is well past the line between
## them (FACING_HOLD), so a heading on that line doesn't flicker.
func facing_from(v: Vector2, held := -1) -> int:
	# angle 0 = up, clockwise
	var a := fposmod(atan2(v.x, -v.y), TAU)
	if held >= 0 and absf(angle_difference(a, held * TAU / 8.0)) < TAU / 16.0 + FACING_HOLD:
		return held
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
	var dirs: Dictionary = _rendered[anim] if rendered(anim) else _anims[anim]
	var best: int = dirs.keys()[0]
	for d in dirs:
		if absi(d - drawn_dir) < absi(best - drawn_dir):
			best = d
	return dirs[best]


func _length_ticks(anim: String) -> float:
	if _lengths.has(anim):
		return _lengths[anim]
	var frames: Array = _frames_for(anim, 8)
	var last: float = frames[-1].t
	var step: float = last - frames[-2].t if frames.size() > 1 else 4.0
	return last + step
