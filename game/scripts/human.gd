class_name Human
extends RefCounted
## One person at the controls: their team, their input actions ("move_left", "shoot"...
## for player 1, the same with "p2_" for player 2), the footballer they control and
## their shot / combo state. Controls are bound by bind_inputs(), with the keys from keys():
## KEYS, or as rebound on the Controls screen (ControlsMenu) and saved in save_path.

const ACTIONS := ["move_up", "move_down", "move_left", "move_right", "shoot", "pass", "switch", "special"]
const KEYS := [  # the defaults
	{  # player 1; arrows too when playing alone
		"move_up": [KEY_W], "move_down": [KEY_S], "move_left": [KEY_A], "move_right": [KEY_D],
		"shoot": [KEY_SPACE], "pass": [KEY_X, KEY_K], "switch": [KEY_Q],
		"special": [KEY_E],
	},
	{  # player 2: arrows, Enter, Right Shift
		"move_up": [KEY_UP], "move_down": [KEY_DOWN], "move_left": [KEY_LEFT], "move_right": [KEY_RIGHT],
		"shoot": [KEY_ENTER, KEY_KP_ENTER], "pass": [KEY_SHIFT], "switch": [KEY_CTRL],  # the right-hand Shift and Ctrl
		"special": [KEY_COMMA],
	},
]
const PAD_BUTTONS := {
	"move_up": [JOY_BUTTON_DPAD_UP], "move_down": [JOY_BUTTON_DPAD_DOWN],
	"move_left": [JOY_BUTTON_DPAD_LEFT], "move_right": [JOY_BUTTON_DPAD_RIGHT],
	"shoot": [JOY_BUTTON_B], "pass": [JOY_BUTTON_A], "switch": [JOY_BUTTON_X, JOY_BUTTON_LEFT_SHOULDER],
	"special": [JOY_BUTTON_Y],
}
const PAD_STICK := {  # left stick: [axis, direction]
	"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
}
const PAD_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB"}
const MARKERS := [Footballer.MARKER, Color(0.3, 0.95, 1.0)]  # control ring: yellow, cyan

var team: Team
var index := 0  # 0 = player 1, 1 = player 2
var controlled: Footballer
var combo := ComboInput.new()
var charging := false
var charge_time := 0.0
var pending_combo := ""
var switch_lock := 0.0  # seconds the automatic switching leaves a manual choice alone
var pass_target: Footballer  # who a pass would go to now (marked on the pitch)
var air_request := ""  # "shoot" or "pass" pressed just before a ball in the air arrives
var air_request_left := 0.0  # seconds it still counts
static var save_path := "user://controls.cfg"  # the keys rebound on the Controls screen
static var _keys: Array = []  # each player's {action: [keys]}, once read; see keys()
var special_used := false  # a button went with the special button this press: letting go of it does nothing


func _init(t: Team, i: int) -> void:
	team = t
	index = i


func action(name: String) -> String:
	return name if index == 0 else "p2_" + name


func stick() -> Vector2:
	return Input.get_vector(action("move_left"), action("move_right"), action("move_up"), action("move_down"))


func marker() -> Color:
	return MARKERS[index]


## For on-screen prompts: the first key player `i` (0 or 1) has for `action`, or the gamepad
## button when `pad`. "move" is the keys or the stick.
static func button_name(i: int, action: String, pad: bool) -> String:
	if action == "move":
		return "stick" if pad else ["WASD", "arrows"][i]
	if pad:
		return PAD_NAMES.get(PAD_BUTTONS[action][0], "?")
	var k: Key = keys()[i][action][0]
	return ("Right " if k in [KEY_SHIFT, KEY_CTRL] and i == 1 else "") + OS.get_keycode_string(k)


## Whether `event` is one of this human's controls (keys or their gamepad).
func owns(event: InputEvent) -> bool:
	for a: String in ACTIONS:
		if event.is_action(action(a)):
			return true
	return false


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
			var bound: Array = keys()[i][name].duplicate()
			if players == 1 and i == 0 and name.begins_with("move"):
				bound += keys()[1][name]
			for k in bound:
				var e := InputEventKey.new()
				e.physical_keycode = k
				if k in [KEY_SHIFT, KEY_CTRL] and i == 1:  # player 2's: the right-hand ones
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


## Both players' keys, {action: [keys]} each: KEYS with what the Controls screen rebound
## (read from save_path the first time).
static func keys() -> Array:
	if _keys.is_empty():
		_keys = KEYS.duplicate(true)
		var cfg := ConfigFile.new()
		if cfg.load(save_path) == OK:
			for i in 2:
				for name: String in ACTIONS:
					var k: Variant = cfg.get_value("player%d" % (i + 1), name, KEY_NONE)
					if k is int and k != KEY_NONE:
						_keys[i][name] = [k]
	return _keys


## Player `i`'s `action` on `key` alone. Another action (of either player) that had the key
## loses it, and takes this action's old key if that leaves it none: the two swap. Saved;
## bind_inputs() again for it to take effect.
static func rebind(i: int, action: String, key: Key) -> void:
	var all := keys()
	var old: Key = all[i][action][0]
	for j in 2:
		for name: String in ACTIONS:
			if key in all[j][name] and not (j == i and name == action):
				all[j][name] = all[j][name].filter(func(k): return k != key)
				if all[j][name].is_empty():
					all[j][name] = [old]
	all[i][action] = [key]
	_save()


## Back to KEYS, for both players.
static func reset_keys() -> void:
	_keys = KEYS.duplicate(true)
	_save()


## Only what differs from KEYS, so the defaults' second keys (K, keypad Enter) stay.
static func _save() -> void:
	var cfg := ConfigFile.new()
	for i in 2:
		for name: String in ACTIONS:
			if _keys[i][name] != KEYS[i][name]:
				cfg.set_value("player%d" % (i + 1), name, _keys[i][name][0])
	cfg.save(save_path)
