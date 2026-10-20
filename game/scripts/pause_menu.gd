class_name PauseMenu
extends CanvasLayer
## Esc (gamepad Start) pauses the match: the whole tree stops (clock, AI, ball, wind-ups)
## while this layer keeps running. Up / Down picks, Space / Enter (A) chooses, Esc / Start
## (B) resumes.

const TITLE := "res://scenes/title.tscn"
const ITEMS := ["RESUME", "RESTART MATCH", "QUIT TO TITLE"]

var _pick := 0
var _box := Control.new()  # the menu: shown and hidden as one
var _rows: Array[Label] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(shade)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 14)
	shade.add_child(column)
	column.add_child(_label("PAUSED", 56, Color(1, 0.85, 0.2)))
	for text in ITEMS:
		var row := _label(text, 30, Color.WHITE)
		column.add_child(row)
		_rows.append(row)
	_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.visible = false
	add_child(_box)
	_refresh()


func _label(text: String, font_size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	return l


func _refresh() -> void:
	for i in _rows.size():
		_rows[i].text = ("▶  %s  ◀" if i == _pick else "%s") % ITEMS[i]
		_rows[i].modulate.a = 1.0 if i == _pick else 0.7


func set_paused(on: bool) -> void:
	get_tree().paused = on
	_box.visible = on
	_pick = 0
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	var button: bool = event is InputEventJoypadButton and event.pressed
	if not key and not button:
		return
	var toggle: bool = (key and event.physical_keycode == KEY_ESCAPE) or (button and event.button_index == JOY_BUTTON_START)
	if not get_tree().paused:
		if toggle:
			set_paused(true)
			get_viewport().set_input_as_handled()
		return
	get_viewport().set_input_as_handled()
	if toggle or (button and event.button_index == JOY_BUTTON_B):
		set_paused(false)
	elif (key and event.physical_keycode in [KEY_UP, KEY_W]) or (button and event.button_index == JOY_BUTTON_DPAD_UP):
		_pick = (_pick + ITEMS.size() - 1) % ITEMS.size()
		_refresh()
	elif (key and event.physical_keycode in [KEY_DOWN, KEY_S]) or (button and event.button_index == JOY_BUTTON_DPAD_DOWN):
		_pick = (_pick + 1) % ITEMS.size()
		_refresh()
	elif (key and event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]) or (button and event.button_index == JOY_BUTTON_A):
		_choose()


func _choose() -> void:
	match _pick:
		0:
			set_paused(false)
		1:
			get_tree().paused = false
			get_tree().reload_current_scene()
		2:
			get_tree().paused = false
			get_tree().change_scene_to_file(TITLE)
