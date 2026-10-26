class_name Replay
extends Node
## Replays (ADR-004: record what's drawn, don't re-simulate). Every other physics frame (HZ) the
## match's look is kept, the last SECONDS of it: the camera's focus, the ball's look and each
## player's and the referee's (Footballer.look: where he is, his animation and how far into it,
## his facing). A replay pauses the match and draws those looks (show_look) without touching
## anything in it, then draws the live frame again and lets the match go on.
## Three ways in: the instant replay after a goal (Match, at half speed, any key skips it), the
## pause menu's REPLAY (stepped: SPACE plays / pauses, ←/→ a frame, S the speed, Esc back) and
## the highlights (each goal and save, CLIP long, H on the full-time screen).

const HZ := 30
const SECONDS := 10.0
const CLIP := 6.0  # a highlight: seconds, ending AFTER seconds after the goal or save
const AFTER := 1.0
const SPEEDS := [0.25, 0.5, 1.0]

var frames: Array = []  # [camera focus, Ball.look(), [[actor, Footballer.look()], ...]], oldest first
var highlights: Array = []  # of clips (Arrays of frames), in the order they happened
var clip: Array = []  # the frames being replayed
var at := 0.0  # where in the clip, in frames
var speed := 0.5
var playing := false
var running := true  # false: stepped through (the pause menu's replay)
var mark: Label  # "R", top left, while replaying
var _m  # the Match
var _count := 0  # frames recorded in all
var _tick := 0
var _due: Array = []  # _count at which a highlight is cut (AFTER past its goal or save)
var _live: Array = []  # the frame when the replay started, drawn again at the end
var _auto := true  # any key ends it (else: the stepped controls)
var _was_paused := false
var _on_done: Callable


func _init(match_game) -> void:
	_m = match_game


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 12
	add_child(layer)
	mark = UiText.label("R", 40, Color(1, 0.85, 0.2), 8)
	mark.position = Vector2(32, 24)
	mark.visible = false
	layer.add_child(mark)
	_m.event.connect(_on_event)


func _on_event(kind: String, _t) -> void:
	if kind in ["goal", "save"]:
		_due.append(_count + int(AFTER * HZ))


## Every physics frame of the match: every other one is kept.
func record() -> void:
	_tick += 1
	if _tick % (Engine.physics_ticks_per_second / HZ) == 0:
		record_frame()


func record_frame() -> void:
	frames.append(_frame())
	_count += 1
	if frames.size() > int(SECONDS * HZ):
		frames.pop_front()
	while not _due.is_empty() and _count >= _due[0]:
		_due.pop_front()
		highlights.append(frames.slice(-int(CLIP * HZ)))


func _frame() -> Array:
	var actors := []
	for t in [_m.home, _m.away]:
		for p in t.players + t.subbed_off:
			actors.append([p, p.look()])
	actors.append([_m.referee, _m.referee.look()])
	return [_m.camera_focus(), _m.ball.look(), actors]


## The last `seconds` replayed at `spd`; `auto`: any key ends it (else stepped).
func play(seconds: float, spd: float, auto: bool, on_done := Callable()) -> void:
	play_clip(frames.slice(-int(seconds * HZ)), spd, auto, on_done)


func play_clip(frames_to_show: Array, spd: float, auto: bool, on_done := Callable()) -> void:
	if frames_to_show.is_empty():
		if on_done.is_valid():
			on_done.call()
		return
	clip = frames_to_show
	at = 0.0
	speed = spd
	_auto = auto
	running = auto
	_on_done = on_done
	_live = _frame()
	_was_paused = get_tree().paused
	get_tree().paused = true
	playing = true
	mark.visible = true
	_show(clip[0], 0.0)


func stop() -> void:
	if not playing:
		return
	playing = false
	mark.visible = false
	_show(_live, 0.0)
	get_tree().paused = _was_paused
	if _on_done.is_valid():
		_on_done.call()


func _process(delta: float) -> void:
	if not playing or not running:
		return
	at += delta / maxf(Engine.time_scale, 0.01) * HZ * speed  # real time, whatever the slow-mo
	if at >= clip.size() - 1:
		if _auto:
			stop()
			return
		at = clip.size() - 1
		running = false
	_show(clip[int(at)], delta)


func _show(frame: Array, delta: float) -> void:
	_m.stadium.follow(frame[0], delta)
	_m.ball.show_look(frame[1], _m.stadium.to_screen)
	for a in frame[2]:
		a[0].show_look(a[1], _m.stadium.to_screen(a[1][0]))


func _unhandled_input(event: InputEvent) -> void:
	if not playing or not event.is_pressed() or (event.is_echo() and _auto):  # holding ←/→ steps on
		return
	if not (event is InputEventKey or event is InputEventJoypadButton):
		return
	get_viewport().set_input_as_handled()
	if _auto:
		stop()
		return
	var code: int = event.physical_keycode if event is InputEventKey else -1
	var pad: int = event.button_index if event is InputEventJoypadButton else -1
	if code == KEY_ESCAPE or pad in [JOY_BUTTON_B, JOY_BUTTON_START]:
		stop()
	elif code == KEY_SPACE or pad == JOY_BUTTON_A:
		running = not running
		if running and at >= clip.size() - 1:
			at = 0.0
	elif code in [KEY_LEFT, KEY_RIGHT] or pad in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
		running = false
		at = clampf(floorf(at) + (1.0 if code == KEY_RIGHT or pad == JOY_BUTTON_DPAD_RIGHT else -1.0), 0.0, clip.size() - 1)
		_show(clip[int(at)], 0.0)
	elif code == KEY_S or pad == JOY_BUTTON_Y:
		speed = SPEEDS[(SPEEDS.find(speed) + 1) % SPEEDS.size()]
