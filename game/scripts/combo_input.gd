class_name ComboInput
extends RefCounted
## Fighting-game style input buffer. Directions are numpad notation relative to
## the goal being attacked: 6 = toward goal, 4 = away, 8 = up the screen, 2 = down,
## 5 = neutral. Only changes of direction are recorded.

const WINDOW := 0.7  # seconds a combo's inputs must fit in, ending at the button press

const COMBOS := [
	["fireball", [2, 3, 6]],  # down, down-forward, forward
	["fireball", [8, 9, 6]],  # mirrored for players on the other wing
	["banana", [4, 6]],       # back, forward
]
const SKILL_COMBOS := [  # with the switch button, with the ball
	["rainbow", [2, 8]],  # down, up: a rising flick
	["rainbow", [8, 2]],
	["bckheel", [6, 4]],  # forward, back
]

var _history: Array = []  # [direction, time]


static func direction(stick: Vector2, attack_side: int) -> int:
	var fx := stick.x * attack_side
	var col := 1 if fx < -0.5 else (3 if fx > 0.5 else 2)
	var row := 0 if stick.y < -0.5 else (2 if stick.y > 0.5 else 1)
	return [[7, 8, 9], [4, 5, 6], [1, 2, 3]][row][col - 1]


func feed(dir: int, now: float) -> void:
	if _history.is_empty() or _history[-1][0] != dir:
		_history.append([dir, now])
	while _history.size() > 12:
		_history.pop_front()


## The combo just completed (checked when the shoot button goes down), or "".
func detect(now: float, combos := COMBOS) -> String:
	var recent: Array[int] = []
	for e in _history:
		if e[1] >= now - WINDOW and e[0] != 5:
			recent.append(e[0])
	for c in combos:
		var seq: Array = c[1]
		if recent.size() >= seq.size() and recent.slice(recent.size() - seq.size()) == seq:
			return c[0]
	return ""


## A double tap: the same direction twice with neutral in between, just now (a dash).
## Letting go of the stick before the button doesn't spoil it.
func double_tap(now: float) -> bool:
	var recent: Array = _history.filter(func(e): return e[1] >= now - WINDOW)
	while not recent.is_empty() and recent[-1][0] == 5:
		recent.pop_back()
	if recent.size() < 3:
		return false
	var a: int = recent[-3][0]
	return a != 5 and recent[-2][0] == 5 and recent[-1][0] == a


## The skill move just entered (checked when switch goes down with the ball): a double
## tap is a nutmeg, else one of SKILL_COMBOS; "" for none (a dodge).
func skill_move(now: float) -> String:
	return "nutmeg" if double_tap(now) else detect(now, SKILL_COMBOS)


func clear() -> void:
	_history.clear()
