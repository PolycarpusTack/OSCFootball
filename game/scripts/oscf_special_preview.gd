extends Node2D
## Art review only: no possession, save reach, or combat gameplay changes.

const FRAMES = preload("res://assets/sprites/oscf_specials/special_actions.tres")
const MOVES := ["elastic_save", "rubber_boot", "rising_steal", "flying_intercept"]
const TITLES := ["ELASTIC SAVE", "RUBBER BOOT", "RISING STEAL", "FLYING INTERCEPT"]
var _actors: Array[AnimatedSprite2D] = []
var _paused := false
var _flipped := false
var _speed := 1.0
var _status := Label.new()

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#14252b"))
	_label("OSCF • CHAOS SPECIAL ACTIONS", Vector2(30, 25), 30)
	_label("Space: pause   R: replay   F: mirror   ← / →: speed   Esc: quit", Vector2(30, 75), 19)
	_label("2× view", Vector2(30, 135), 17)
	_label("Game-size view", Vector2(30, 470), 17)
	var preview_frames: SpriteFrames = FRAMES.duplicate()
	for action: String in MOVES:
		preview_frames.set_animation_loop(action, true)
	for i in MOVES.size():
		var x := 85.0 + i * 305.0
		_label(TITLES[i], Vector2(x - 40, 405), 19)
		for small in [false, true]:
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames = preview_frames
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.centered = false
			sprite.offset = Vector2(-64, -168)
			sprite.position = Vector2(x, 570 if small else 380)
			sprite.scale = Vector2.ONE if small else Vector2.ONE * 2.0
			add_child(sprite)
			_actors.append(sprite)
			sprite.play(MOVES[i])
	_status.position = Vector2(30, 630)
	add_child(_status)
	_update()

func _label(text: String, position: Vector2, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	add_child(label)

func _update() -> void:
	for sprite in _actors:
		sprite.speed_scale = 0.0 if _paused else _speed
		sprite.flip_h = _flipped
		sprite.offset = Vector2(-128 if _flipped else -64, -168)
	_status.text = "%.2f× • %s%s\nSide-view art prototypes. Match integration, other directions and kit recolouring remain separate." % [
		_speed, "LEFT" if _flipped else "RIGHT", " • PAUSED" if _paused else ""]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	match event.physical_keycode:
		KEY_SPACE: _paused = not _paused
		KEY_F: _flipped = not _flipped
		KEY_R:
			for sprite in _actors:
				sprite.set_frame_and_progress(0, 0)
		KEY_LEFT: _speed = maxf(0.25, _speed / 2.0)
		KEY_RIGHT: _speed = minf(2.0, _speed * 2.0)
		KEY_ESCAPE: get_tree().quit()
	_update()
