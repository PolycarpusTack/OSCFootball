extends Node2D
## Standalone preview. Does not replace the match's indexed player art.

const FRAMES = preload("res://assets/sprites/oscf_starter/footballer.tres")
const ACTIONS := ["idle", "run", "kick"]
const DIRS := ["n", "ne", "e", "se", "s", "se", "e", "ne"]
const LABELS := ["N", "NE", "E", "SE", "S", "SW (mirror)", "W (mirror)", "NW (mirror)"]
var _sprites: Array[AnimatedSprite2D] = []
var _small: Array[AnimatedSprite2D] = []
var _action := 0
var _speed := 1.0
var _paused := false
var _status := Label.new()

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#17252b"))
	_add_label("OSCF • ORIGINAL PLAYER SPRITES", Vector2(35, 28), 30)
	_add_label("1 Standing   2 Running   3 Kicking   Space Pause   ← / → Speed   Esc Quit", Vector2(35, 77), 18)
	_add_label("3× inspection view", Vector2(35, 139), 18)
	_add_label("1× game-size view", Vector2(35, 480), 18)
	for i in 8:
		var x := 80.0 + i * 158.0
		for small in [false, true]:
			var sprite := AnimatedSprite2D.new()
			sprite.sprite_frames = FRAMES
			sprite.centered = false
			sprite.offset = Vector2(-32, -58)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.position = Vector2(x, 565 if small else 380)
			sprite.scale = Vector2.ONE * (1.0 if small else 3.0)
			sprite.flip_h = i > 4
			# Mirroring a non-centred sprite also mirrors its offset.
			add_child(sprite)
			if small:
				_small.append(sprite)
			else:
				_sprites.append(sprite)
			sprite.animation_finished.connect(func(): if ACTIONS[_action] == "kick": sprite.play())
		_add_label(LABELS[i], Vector2(x - 30, 407), 15)
	_status.position = Vector2(35, 625)
	add_child(_status)
	_play()

func _add_label(text: String, at: Vector2, size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	add_child(label)

func _play() -> void:
	for group in [_sprites, _small]:
		for i in group.size():
			var sprite: AnimatedSprite2D = group[i]
			sprite.play(ACTIONS[_action] + "_" + DIRS[i])
			sprite.speed_scale = 0.0 if _paused else _speed
	_status.text = "%s • %.2f× speed%s\nRGBA starter art; match palette conversion and final animation polish are still required." % [
		ACTIONS[_action].to_upper(), _speed, " • PAUSED" if _paused else ""]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	match event.physical_keycode:
		KEY_1: _action = 0
		KEY_2: _action = 1
		KEY_3: _action = 2
		KEY_SPACE: _paused = not _paused
		KEY_LEFT: _speed = maxf(0.25, _speed / 2.0)
		KEY_RIGHT: _speed = minf(2.0, _speed * 2.0)
		KEY_ESCAPE: get_tree().quit()
	_play()
