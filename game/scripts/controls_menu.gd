class_name ControlsMenu
extends Control
## The Controls screen, over the title screen (C): both players' keys, one per action.
## ↑ / ↓ picks an action, ← / → the player, Enter / Space waits for the new key (Esc: keep
## the old one). A key another action has is swapped over (Human.rebind). The last row puts
## every key back. Esc / B closes. The gamepad's buttons are fixed and listed below.

const NAMES := {"move_up": "Up", "move_down": "Down", "move_left": "Left", "move_right": "Right",
	"shoot": "Shoot / tackle", "pass": "Pass", "switch": "Switch / dodge / skill", "special": "Special (hold, + a button)",
	"tactic_1": "Tactic 1: balanced", "tactic_2": "Tactic 2: attack", "tactic_3": "Tactic 3: defend", "tactic_4": "Tactic 4: all out"}
const RESET := "RESET TO DEFAULTS"
const TOP := 150.0
const ROW := 30.0

var row := 0  # an index of Human.ACTIONS, or ACTIONS.size() for the reset row
var player := 0
var waiting := false  # for the key to bind
var _labels: Array = []  # per row: [name, player 1's key, player 2's]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := ColorRect.new()
	back.color = Color(0.02, 0.06, 0.05, 0.94)
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	_add_label(Vector2(60, 24), 40).text = "[color=#ffd933]CONTROLS[/color]"
	_add_label(Vector2(420, 105), 20).text = "[color=#bbbbbb]PLAYER 1[/color]"
	_add_label(Vector2(760, 105), 20).text = "[color=#bbbbbb]PLAYER 2[/color]"
	for i in Human.ACTIONS.size() + 1:
		_labels.append([60.0, 420.0, 760.0].map(func(x): return _add_label(Vector2(x, TOP + i * ROW), 22)))
	_add_label(Vector2(60, 560), 16).text = ("[color=#bbbbbb]Gamepad (fixed): d-pad or stick move, B shoot, A pass, X / LB switch, Y special; tactics on the keyboard only.\n"
		+ "Playing alone, player 1 moves with player 2's keys too.[/color]")
	_add_label(Vector2(60, 680), 14).text = "[color=#bbbbbb]%s[/color]" % UiText.hint([["↑/↓", "action"], ["←/→", "player"], ["ENTER", "change"], ["ESC / B", "back"]])
	visible = false


func _add_label(at: Vector2, font_size: int) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.position = at
	l.size = Vector2(1160, 0)
	l.add_theme_font_size_override("normal_font_size", font_size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func open() -> void:
	row = 0
	player = 0
	waiting = false
	visible = true
	_refresh()


## A key or gamepad press while shown. False when it closes the screen.
func handle(event: InputEvent) -> bool:
	var key: bool = event is InputEventKey
	var code: Key = event.physical_keycode if key else KEY_NONE
	if waiting:
		if key:
			waiting = false
			if code != KEY_ESCAPE:
				Human.rebind(player, Human.ACTIONS[row], code)
			_refresh()
		return true
	if (key and code == KEY_ESCAPE) or (not key and event.button_index == JOY_BUTTON_B):
		visible = false
		return false
	var rows := Human.ACTIONS.size() + 1
	if (key and code in [KEY_UP, KEY_W]) or (not key and event.button_index == JOY_BUTTON_DPAD_UP):
		row = (row + rows - 1) % rows
	elif (key and code in [KEY_DOWN, KEY_S]) or (not key and event.button_index == JOY_BUTTON_DPAD_DOWN):
		row = (row + 1) % rows
	elif (key and code in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D]) \
			or (not key and event.button_index in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]):
		player = 1 - player
	elif (key and code in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]) or (not key and event.button_index == JOY_BUTTON_A):
		if row == Human.ACTIONS.size():
			Human.reset_keys()
		elif key:  # a key to bind needs the keyboard
			waiting = true
	_refresh()
	return true


func _refresh() -> void:
	for i in _labels.size():
		var selected := i == row
		var name: String = RESET if i == Human.ACTIONS.size() else NAMES[Human.ACTIONS[i]].to_upper()
		_labels[i][0].text = "[color=%s]%s%s[/color]" % ["#ffe34d" if selected else "#ffffff", "▶ " if selected else "   ", name]
		for p in 2:
			var cell: RichTextLabel = _labels[i][p + 1]
			if i == Human.ACTIONS.size():
				cell.text = ""
				continue
			var k := "PRESS A KEY" if selected and p == player and waiting else Human.button_name(p, Human.ACTIONS[i], false)
			cell.text = "[bgcolor=%s] %s [/bgcolor]" % ["#ffe34d70" if selected and p == player else "#ffffff38", k]
