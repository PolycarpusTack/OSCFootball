extends SceneTree
## The Controls screen and rebinding (Human.rebind): swaps, what's saved, reading it back,
## binding it, and the screen's keys. Saves to its own file, not the player's.
## godot --headless --path game -s res://tests/controls_menu_test.gd
const TEST_SAVE := "user://controls_test.cfg"
var failed := 0


func check(value: bool, message: String) -> void:
	if not value:
		failed += 1
		push_error(message)


func key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	return e


func _initialize() -> void:
	var human = load("res://scripts/human.gd")  # loaded, not named: the autoloads aren't up when a test compiles
	human.save_path = TEST_SAVE
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	human._keys = []
	check(human.keys()[0].shoot == [KEY_SPACE] and human.keys()[0].pass == [KEY_X, KEY_K], "No save: the defaults")

	human.rebind(0, "shoot", KEY_J)
	check(human.keys()[0].shoot == [KEY_J], "Shoot on J")
	var cfg := ConfigFile.new()
	check(cfg.load(TEST_SAVE) == OK and cfg.get_value("player1", "shoot") == KEY_J and not cfg.has_section_key("player1", "pass"), "Only the change is saved")
	human.rebind(0, "pass", KEY_J)
	check(human.keys()[0].pass == [KEY_J] and human.keys()[0].shoot == [KEY_X], "J taken: shoot gets pass's old key")
	human.rebind(0, "switch", KEY_K)  # K was pass's second key: pass keeps J
	check(human.keys()[0].switch == [KEY_K] and human.keys()[0].pass == [KEY_J], "A second key moves without a swap")
	human.rebind(0, "special", KEY_UP)  # player 2's up
	check(human.keys()[1].move_up == [KEY_E], "Across players: player 2's up gets E")

	human._keys = []  # read back from the file
	check(human.keys()[0].shoot == [KEY_X] and human.keys()[0].pass == [KEY_J] and human.keys()[1].move_up == [KEY_E], "Read back from the save")
	check(human.keys()[1].shoot == [KEY_ENTER, KEY_KP_ENTER], "Untouched keys keep both defaults")
	human.bind_inputs(2)
	var bound: Array = InputMap.action_get_events("pass").filter(func(e): return e is InputEventKey).map(func(e): return e.physical_keycode)
	check(bound == [KEY_J], "Bound in the match: %s" % [bound])
	check(human.button_name(0, "special", false) == "Up" and human.button_name(1, "pass", false) == "Right Shift", "Prompts show the new keys")

	# the screen: down to Down, Enter, then the key
	human.reset_keys()
	var menu = load("res://scripts/controls_menu.gd").new()
	root.add_child(menu)
	await process_frame
	menu.open()
	menu.handle(key(KEY_DOWN))
	menu.handle(key(KEY_ENTER))
	check(menu.waiting and menu._labels[1][1].text.contains("PRESS A KEY"), "Waiting for player 1's down")
	menu.handle(key(KEY_G))
	check(not menu.waiting and human.keys()[0].move_down == [KEY_G] and menu._labels[1][1].text.contains(" G "), "Down on G")
	menu.handle(key(KEY_RIGHT))
	menu.handle(key(KEY_ENTER))
	menu.handle(key(KEY_ESCAPE))
	check(not menu.waiting and human.keys()[1].move_down == [KEY_DOWN] and menu.visible, "Esc while waiting keeps the key")
	for i in human.ACTIONS.size() - 1:
		menu.handle(key(KEY_DOWN))
	menu.handle(key(KEY_ENTER))
	check(menu.row == human.ACTIONS.size() and human.keys() == human.KEYS, "The last row resets every key")
	check(not menu.handle(key(KEY_ESCAPE)) and not menu.visible, "Esc closes it")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	print("CONTROLS MENU TEST %s" % ("PASSED" if failed == 0 else "FAILED (%d)" % failed))
	quit(0 if failed == 0 else 1)
