extends Control
## Boot sequence: the PTE intro video and its end card (any key skips), then the title screen
## with the title music until Space / Enter (gamepad A, B or Start) goes to team select.
## Left / Right picks Chaos or Classic Football (Match.chaos), Up / Down one or two
## players (Match.players). The menu sits in the dark band along the title card's bottom.

const INTRO := "res://brand/intro.ogv"
const INTRO_END := "res://brand/intro_end.png"
const INTRO_END_SECONDS := 3.0  # the end card stays up this long after the video
const TITLE := "res://brand/title.png"
const MUSIC := "res://brand/title_music.ogg"  # "Stadium Breakbeat", cut to end on bar 40 of the loop
const MUSIC_LOOP_FROM := 52.722  # seconds: after the build-up, 160 beats before the end (139.8 BPM)
const TEAM_SELECT := "res://scenes/team_select.tscn"

var _video := VideoStreamPlayer.new()
var _end_card := TextureRect.new()
var _title := TextureRect.new()
var _prompt := Label.new()
var _mode := Label.new()
var _music := AudioStreamPlayer.new()
var _time := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	for c: Control in [_video, _end_card, _title]:
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(c)
	_video.expand = true
	_video.stream = load(INTRO)
	_video.finished.connect(_show_end_card)
	_end_card.texture = load(INTRO_END)
	_end_card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_end_card.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_end_card.visible = false
	_title.texture = load(TITLE)
	_title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title.visible = false
	_prompt.text = "PRESS SPACE TO KICK OFF"
	_prompt.add_theme_font_size_override("font_size", 26)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 8)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.position.y -= 14
	_prompt.visible = false
	add_child(_prompt)
	_mode.add_theme_font_size_override("font_size", 22)
	_mode.add_theme_color_override("font_outline_color", Color.BLACK)
	_mode.add_theme_constant_override("outline_size", 8)
	_mode.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mode.position.y -= 52
	_mode.visible = false
	add_child(_mode)
	_show_mode()
	var music: AudioStreamOggVorbis = load(MUSIC)
	music.loop = true
	music.loop_offset = MUSIC_LOOP_FROM
	_music.stream = music
	add_child(_music)
	_video.play()


func _process(delta: float) -> void:
	_time += delta
	# the 16:9 video fitted to the window
	var w := minf(size.x, size.y * 16.0 / 9.0)
	_video.size = Vector2(w, w * 9.0 / 16.0)
	_video.position = (size - _video.size) / 2.0
	_prompt.modulate.a = 0.35 + 0.65 * absf(sin(_time * 3.0))


func _show_end_card() -> void:
	_video.visible = false
	_end_card.visible = true
	await get_tree().create_timer(INTRO_END_SECONDS).timeout
	if _end_card.visible:  # not skipped meanwhile
		_show_title()


func _show_title() -> void:
	_video.stop()
	_video.visible = false
	_end_card.visible = false
	_title.visible = true
	_prompt.visible = true
	_mode.visible = true
	_music.play()


func _show_mode() -> void:
	_mode.text = "◀  %s  ▶        ▲  %s  ▼" % ["CHAOS FOOTBALL" if Match.chaos else "CLASSIC FOOTBALL",
		"1 PLAYER" if Match.players == 1 else "2 PLAYERS"]
	_mode.add_theme_color_override("font_color", Color(1, 0.85, 0.2) if Match.chaos else Color.WHITE)


func _unhandled_input(event: InputEvent) -> void:
	var key: bool = event is InputEventKey and event.pressed and not event.echo
	var button: bool = event is InputEventJoypadButton and event.pressed
	if not key and not button and not (event is InputEventMouseButton and event.pressed):
		return
	if _video.visible or _end_card.visible:
		_show_title()
	elif (key and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D]) \
			or (button and event.button_index in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]):
		Match.chaos = not Match.chaos
		_show_mode()
	elif (key and event.keycode in [KEY_UP, KEY_DOWN, KEY_W, KEY_S]) \
			or (button and event.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]):
		Match.players = 3 - Match.players
		_show_mode()
	elif event is InputEventMouseButton or (key and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]) \
			or (button and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START]):
		get_tree().change_scene_to_file(TEAM_SELECT)
