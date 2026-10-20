class_name Human
extends RefCounted
## One person at the controls: their team, their input actions ("move_left", "shoot"...
## for player 1, the same with "p2_" for player 2), the footballer they control and
## their shot / combo state. Controls are bound by bind_inputs().

const ACTIONS := ["move_up", "move_down", "move_left", "move_right", "shoot", "pass"]
const KEYS := [
	{  # player 1; arrows too when playing alone
		"move_up": [KEY_W], "move_down": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
		"shoot": [KEY_SPACE], "pass": [KEY_X, KEY_K],
	},
	{  # player 2: arrows, Enter, Right Shift
		"move_up": [KEY_UP], "move_down": [KEY_DOWN], "move_left": [KEY_LEFT], "move_right": [KEY_RIGHT],
		"shoot": [KEY_ENTER, KEY_KP_ENTER], "pass": [KEY_SHIFT],
	},
]
const PAD_BUTTONS := {
	"move_up": [JOY_BUTTON_DPAD_UP], "move_down": [JOY_BUTTON_DPAD_DOWN],
	"move_left": [JOY_BUTTON_DPAD_LEFT], "move_right": [JOY_BUTTON_DPAD_RIGHT],
	"shoot": [JOY_BUTTON_B], "pass": [JOY_BUTTON_A],
}
const PAD_STICK := {  # left stick: [axis, direction]
	"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
}
const MARKERS := [Footballer.MARKER, Color(0.3, 0.95, 1.0)]  # control ring: yellow, cyan

var team: Team
var index := 0  # 0 = player 1, 1 = player 2
var controlled: Footballer
var combo := ComboInput.new()
var charging := false
var charge_time := 0.0
var pending_combo := ""


func _init(t: Team, i: int) -> void:
	team = t
	index = i


func action(name: String) -> String:
	return name if index == 0 else "p2_" + name


func stick() -> Vector2:
	return Input.get_vector(action("move_left"), action("move_right"), action("move_up"), action("move_down"))


func marker() -> Color:
	return MARKERS[index]


## (Re)bind both players' actions for `players` people (1 or 2). Alone, player 1 has
## WASD and the arrows and every gamepad. Two players: player 1 has WASD, player 2
## the arrows; with one gamepad it goes to player 2, with two the first is player 1's.
static func bind_inputs(players: int) -> void:
	var pads := Input.get_connected_joypads()
	for i in 2:
		var device := -2  # -2: no gamepad, -1: every gamepad
		if players == 1:
			device = -1 if i == 0 else -2
		elif pads.size() >= 2:
			device = pads[i]
		elif pads.size() == 1 and i == 1:
			device = pads[0]
		for name: String in ACTIONS:
			var a: String = name if i == 0 else "p2_" + name
			if not InputMap.has_action(a):
				InputMap.add_action(a, 0.25)
			InputMap.action_erase_events(a)
			var keys: Array = KEYS[i][name].duplicate()
			if players == 1 and i == 0 and name.begins_with("move"):
				keys += KEYS[1][name]
			for k in keys:
				var e := InputEventKey.new()
				e.physical_keycode = k
				if k == KEY_SHIFT:
					e.location = KEY_LOCATION_RIGHT
				InputMap.action_add_event(a, e)
			if device == -2:
				continue
			for b in PAD_BUTTONS[name]:
				var e := InputEventJoypadButton.new()
				e.button_index = b
				e.device = device
				InputMap.action_add_event(a, e)
			if PAD_STICK.has(name):
				var e := InputEventJoypadMotion.new()
				e.axis = PAD_STICK[name][0]
				e.axis_value = PAD_STICK[name][1]
				e.device = device
				InputMap.action_add_event(a, e)
