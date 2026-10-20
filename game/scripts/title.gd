extends Control
## Boot sequence as in FIFA 96: the intro FMV (any key skips), then the title screen
## with the title music until Space / Enter kicks off. Left / Right picks Chaos or
## Classic Football (Match.chaos).

const INTRO := "res://assets/video/intro.ogv"
const TITLE := "res://assets/ui/title/000_0000.png"
const MUSIC := "res://assets/audio/music/QUE_TITL.wav"
const MATCH := "res://scenes/main.tscn"

var _video := VideoStreamPlayer.new()
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
	for c: Control in [_video, _title]:
		c.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(c)
	_video.expand = true
	_video.stream = load(INTRO)
	_video.finished.connect(_show_title)
	_title.texture = load(TITLE)
	_title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title.visible = false
	_prompt.text = "PRESS SPACE TO KICK OFF"
	_prompt.add_theme_font_size_override("font_size", 28)
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 8)
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.position.y -= 40
	_prompt.visible = false
	add_child(_prompt)
	_mode.add_theme_font_size_override("font_size", 24)
	_mode.add_theme_color_override("font_outline_color", Color.BLACK)
	_mode.add_theme_constant_override("outline_size", 8)
	_mode.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mode.position.y -= 90
	_mode.visible = false
	add_child(_mode)
	_show_mode()
	var music: AudioStreamWAV = load(MUSIC)
	music.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.loop_end = int(music.get_length() * music.mix_rate)
	_music.stream = music
	add_child(_music)
	_video.play()


func _process(delta: float) -> void:
	_time += delta
	# the 4:3 video letterboxed in the 16:9 window
	var h := size.y
	_video.size = Vector2(h * 4.0 / 3.0, h)
	_video.position = Vector2((size.x - _video.size.x) / 2.0, 0)
	_prompt.modulate.a = 0.35 + 0.65 * absf(sin(_time * 3.0))


func _show_title() -> void:
	_video.stop()
	_video.visible = false
	_title.visible = true
	_prompt.visible = true
	_mode.visible = true
	_music.play()


func _show_mode() -> void:
	_mode.text = "◀  %s  ▶" % ("CHAOS FOOTBALL" if Match.chaos else "CLASSIC FOOTBALL")
	_mode.add_theme_color_override("font_color", Color(1, 0.85, 0.2) if Match.chaos else Color.WHITE)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo) and not (event is InputEventMouseButton and event.pressed):
		return
	if _video.visible:
		_show_title()
	elif event is InputEventKey and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_A, KEY_D]:
		Match.chaos = not Match.chaos
		_show_mode()
	elif event is InputEventMouseButton or event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		get_tree().change_scene_to_file(MATCH)
