class_name Effects
extends Node2D
## One-shot effects in our own art (assets/sprites/oscf_roles/effects, packed by
## tools/pack_oscf_referee.gd): impact burst, dust puff, yellow and red card spins, whistle
## ring. Each plays at a pitch spot and is drawn through the stadium camera, at the players'
## scale, so it follows the pitch as the camera moves.

const DIR := "res://assets/sprites/oscf_roles/effects/"

var match_game: Node
var playing := []  # {name, at, height, size, tint, loops, time}
var _sheet: Texture2D
var _anims: Dictionary  # name -> {fps, frames: [{x, y, w, h, ax, ay}]}


func _init(m: Node) -> void:
	match_game = m
	_sheet = load(DIR + "effects.png")
	_anims = JSON.parse_string(FileAccess.get_file_as_string(DIR + "effects.json"))
	top_level = true
	z_index = 2001  # over the players, as the Chaos actions


## Play `effect` at pitch point `at`, `height` pixels above the grass, `size` times the art's
## scale, tinted `tint`, `loops` times over.
func play(effect: String, at: Vector2, height := 0.0, size := 1.0, tint := Color.WHITE, loops := 1) -> void:
	playing.append({"name": effect, "at": at, "height": height, "size": size, "tint": tint, "loops": loops, "time": 0.0})


func length_seconds(effect: String) -> float:
	return _anims[effect].frames.size() / float(_anims[effect].fps)


func _process(delta: float) -> void:
	for e in playing:
		e.time += delta
	playing = playing.filter(func(e): return e.time < length_seconds(e.name) * e.loops)
	queue_redraw()


func _draw() -> void:
	for e in playing:
		var a: Dictionary = _anims[e.name]
		var f: Dictionary = a.frames[int(e.time * a.fps) % a.frames.size()]
		var v: Vector3 = match_game.stadium.to_screen(e.at, e.height)
		var scale: float = v.z * e.size
		var spot := Vector2(v.x, v.y) - Vector2(f.ax, f.ay) * scale
		draw_texture_rect_region(_sheet, Rect2(spot, Vector2(f.w, f.h) * scale), Rect2(f.x, f.y, f.w, f.h), e.tint)
